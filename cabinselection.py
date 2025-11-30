import tkinter as tk
from tkinter import filedialog, ttk
import os
import glob
from pathlib import Path
from ffmpeg import FFmpeg
import shutil
import subprocess
from functools import wraps

__old_Popen = subprocess.Popen
@wraps(__old_Popen)
def new_Popen(*args, startupinfo=None, **kwargs):
    if startupinfo is None:
        startupinfo = subprocess.STARTUPINFO()

    # way 1, as SO suggests:
    # create window
    startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    # and hide it immediately
    startupinfo.wShowWindow = subprocess.SW_HIDE

    # way 2, I cann't test it but you may try just:
    # startupinfo.dwFlags = subprocess.CREATE_NO_WINDOW

    return __old_Popen(*args, startupinfo=startupinfo, **kwargs)


# monkey-patch/replace Popen
subprocess.Popen = new_Popen

class FolderBrowserApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Cabin Announcements")
        self.geometry("800x450")
        
        # Configure the main window grid
        self.grid_rowconfigure(0, weight=1)
        self.grid_columnconfigure(0, weight=1)

        # Initialize the main UI component: SelectFolderPage
        self.main_page = SelectCabinAnnouncementSource(parent=self)
        # self.main_page = SelectCabinAnnouncementDestination(parent=self)
        self.main_page.grid(row=0, column=0, sticky="nsew")


# --- Main Page: Select Folder and Display Contents ---
class SelectCabinAnnouncementSource(ttk.Frame):
    def __init__(self, parent):
        super().__init__(parent, padding="15")
        self.parent = parent
        self.current_folder_path = "" # Tracks the currently displayed root path
        self.source_folder_path = "" # Tracks the source folder path
        self.destination_folder_path = "" # Tracks the destination folder path
        
        # Configure grid for the page
        self.grid_rowconfigure(3, weight=1) # Row for the Treeview
        self.grid_columnconfigure(0, weight=1)
        
        # 1. Title Label
        title_label = ttk.Label(self, text="Cabin Announcements", font=("Arial", 14, "bold"))
        title_label.grid(row=0, column=0, pady=(0, 10), sticky="w")

        # 2. Selection Button and Path Display Frame
        path_frame = ttk.Frame(self)
        path_frame.grid(row=1, column=0, pady=(0, 10), sticky="ew")
        path_frame.grid_columnconfigure(1, weight=1)
        
        source_button = ttk.Button(path_frame, text="Select Cabin Announcements Source Folder", command=self.select_source_folder)
        source_button.grid(row=0, column=0, padx=(0, 10), sticky="w")

        self.source_path = tk.StringVar(value="No folder selected.")
        path_label = ttk.Label(path_frame, textvariable=self.source_path, wraplength=450)
        path_label.grid(row=0, column=1, sticky="ew")

        destination_button = ttk.Button(path_frame, text="Select Cabin Announcements Destination Folder", command=self.select_destination_folder)
        destination_button.grid(row=1, column=0, padx=(0, 10), sticky="w")
        
        self.destination_path = tk.StringVar(value="No folder selected.")
        path_label = ttk.Label(path_frame, textvariable=self.destination_path, wraplength=450)
        path_label.grid(row=1, column=1, sticky="ew")

        self.destination_path.trace_add("write", lambda *args: self.load_folder_contents(*args, folder_path=self.source_folder_path))

        # if self.destination_folder_path:

        #     if self.source_folder_path:
        #         self.load_folder_contents(self.source_folder_path)
        #     else:
        #         self.load_folder_contents(None) # Clear the view

        # 3. Selection Feedback Label
        self.selection_var = tk.StringVar(value="Double-click a subfolder below to select it.")
        selection_label = ttk.Label(self, textvariable=self.selection_var, foreground="green")
        selection_label.grid(row=3, column=0, pady=(5, 5), sticky="w")

        # 4. Treeview for Subfolders (The core display)
        self._setup_treeview()

    def _setup_treeview(self):
        """Sets up the Treeview widget and its scrollbars."""
        
        tree_frame = ttk.Frame(self)
        tree_frame.grid(row=3, column=0, sticky="nsew")
        tree_frame.grid_rowconfigure(0, weight=1)
        tree_frame.grid_columnconfigure(0, weight=1)

        # Scrollbars
        y_scrollbar = ttk.Scrollbar(tree_frame, orient="vertical")
        x_scrollbar = ttk.Scrollbar(tree_frame, orient="horizontal")

        # Treeview Widget
        self.content_tree = ttk.Treeview(tree_frame, show='tree headings', 
                                         yscrollcommand=y_scrollbar.set, 
                                         xscrollcommand=x_scrollbar.set)
        
        self.content_tree.column('#0', width=500, stretch=tk.YES, anchor='w')
        self.content_tree.heading('#0', text='Subfolders of Selected Path', anchor='w')

        # Link Scrollbars
        y_scrollbar.config(command=self.content_tree.yview)
        x_scrollbar.config(command=self.content_tree.xview)
        
        # Place Treeview and Scrollbars
        self.content_tree.grid(row=0, column=0, sticky="nsew")
        y_scrollbar.grid(row=0, column=1, sticky="ns")
        x_scrollbar.grid(row=1, column=0, sticky="ew")

        # Bind the double-click event for selection
        self.content_tree.bind('<Double-1>', self.on_subfolder_double_click)
        self.content_tree.tag_configure('folder', foreground='blue')
        self.content_tree.tag_configure('error', foreground='red')

    def select_source_folder(self):
        """Opens a dialog to select a directory and loads its contents."""
        folder_path = filedialog.askdirectory()
        if folder_path:
            self.source_folder_path = folder_path
            self.source_path.set(f"Root: {folder_path}")
        else:
            self.source_path.set("Folder selection cancelled.")

    def select_destination_folder(self):
        """Opens a dialog to select a directory and loads its contents."""
        folder_path = filedialog.askdirectory()
        if folder_path:
            self.destination_folder_path = folder_path
            self.destination_path.set(f"Root: {folder_path}")
        else:
            self.destination_path.set("Folder selection cancelled.")

    def load_folder_contents(self, *args, folder_path):
        """Clears the tree and populates it ONLY with subdirectories."""
        
        # Clear existing content
        for item in self.content_tree.get_children():
            self.content_tree.delete(item)

        if not folder_path:
            self.selection_var.set("Select a root folder to begin browsing.")
            return

        self.selection_var.set("Double-click a subfolder below to select it.")

        # Populate the Treeview with FOLDERS ONLY
        try:
            # Filter for directories and sort them
            items = [Path(item).name for item in glob.glob(folder_path + "/*/", recursive=True)]
            
            items.sort(key=str.lower)
            
            if not items:
                self.content_tree.insert('', 'end', text="No subfolders found in this directory.", tags=('empty',))
                self.content_tree.tag_configure('empty', foreground='gray')
            else:
                for item in items:
                    # Insert only folders
                    self.content_tree.insert('', 'end', text=f"📁 {item}", tags=('folder',))
            
        except Exception as e:
            self.content_tree.insert('', 'end', text=f"Error reading folder: {e}", tags=('error',))
            self.selection_var.set(f"Error accessing folder: {e}")


    def on_subfolder_double_click(self, event):
        """Handles the double-click event on a subfolder to register a selection."""
        
        item_id = self.content_tree.selection()
        if not item_id:
            return

        # Get the text (folder name with emoji)
        item_text_with_emoji = self.content_tree.item(item_id, 'text')
        
        # Extract just the folder name (remove the emoji and leading space)
        folder_name = item_text_with_emoji.lstrip("📁 ").strip()

        if folder_name and "No subfolders" not in folder_name and "Error" not in folder_name:
            # Construct the full path
            selected_full_path = os.path.join(self.source_folder_path, folder_name)
            
            # Update the feedback label
            self.selection_var.set(f"SELECTED: {selected_full_path}")
            
            # Placeholder for your final action (e.g., passing the path to a function)
            self.handle_final_selection(selected_full_path)

    def handle_final_selection(self, selected_path):
        """Action performed when a subfolder is finalized."""
        # print(f"Final Folder Selected: {selected_path}")
        files = glob.glob(selected_path + "/*.ogg")

        _= [os.remove(file) for file in glob.glob(self.destination_folder_path + "/*.wav")]

        for filepath in files:
            input_filepath = Path(filepath)
            input_filename = input_filepath.stem
            output_filepath = str(input_filepath.parent / input_filename) + ".wav"
            output_filename = input_filename + ".wav"
            destination_filepath = str(Path(self.destination_folder_path) / output_filename)
            ffmpeg = (FFmpeg().option("y").input(filepath).output(output_filepath))
            ffmpeg.execute()

            # print(destination_filepath)
            shutil.move(output_filepath, destination_filepath)
        
        tk.messagebox.showinfo("Process Complete", f"Finished creating ogg files from {Path(selected_path).name} and transferred to destination folder {Path(self.destination_folder_path).name}")


if __name__ == "__main__":
    app = FolderBrowserApp()
    app.mainloop()
