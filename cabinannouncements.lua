local LIP = require("LIP")

if not SUPPORTS_FLOATING_WINDOWS then
    -- to make sure the script doesn't stop old FlyWithLua versions
    logMsg("imgui not supported by your FlyWithLua version")
    return
end

local toliss_announcements_dir = SCRIPT_DIRECTORY .. "Toliss_Announcements/"

-- VARIABLES FOR CONTROLLING THE SOUND. THESE ARE THE DEFAULT VALUES AND CAN BE CHANGED VIA SLIDERS IN THE IMGUI WINDOW
-- Range : +/- 20 dB
local capt_master_volume = -3
local capt_boarding_complete = -3  -- BoardingComplete [MANUAL]
local capt_gate_departure = -3     -- ArmDoors [MANUAL]
local capt_before_takeoff = -3     -- CallCabinSecureTakeoff [MANUAL]
local capt_crew_seats_takeoff = -3 -- CrewSeatsTakeoff [MANUAL]
local capt_before_landing = -3     -- CallCabinSecureLanding [AUTOMATIC]
local capt_crew_seats_landing = -3 -- CrewSeatsLanding [AUTOMATIC]

local flight_attendent_master_volume = -15
local boarding_music = -15      -- BoardingMusic [MANUAL]
local welcome = -15             -- BoardingWelcome [MANUAL]
local safety_briefing = -15     -- Safety Briefing [MANUAL]
local after_takeoff = -15       -- AfterTakeoff [AUTOMATIC]
local descent_seatbelts = -15   -- DescentSeatBelts [AUTOMATIC]
local turbulence = -15          -- Turbulence [MANUAL]
local pre_safety_briefing = -15 -- PreSafetyBriefing [MANUAL]
local after_landing = -15       -- AfterLanding [MANUAL]

local settings_filename = ""
local airline_icao_code = ""
local settings_read = true
-- END DEFAULT VARIABLES

local function LogMsg(Message)
    logMsg(string.format("Cabin Announcements: %s", Message))
end

local function GetRandomTableValue(Table)
    --[[
Function to get a random value from a table acting as a dictionary or as an array.
]]

    local len_table = 0
    local keyset_table = {}

    for i in pairs(Table) do
        len_table = len_table + 1
        table.insert(keyset_table, i)
    end

    local table_value = Table[keyset_table[math.random(len_table)]]

    return table_value
end

local function PlayAnnouncement(announcement, volume, loop)
    loop = loop or false
    local gain = math.min(10 ^ (volume / 20), 1.0)
    set_sound_gain(announcement, gain)

    if loop then
        let_sound_loop(announcement, true)
    end
    play_sound(announcement)
end

local function StopAnnouncement(announcement, stop_flag)
    if stop_flag == "pause" then
        pause_sound(announcement)
    else
        stop_sound(announcement)
    end
end

local function getDirectoryFiles(input_path)
    local dir_filenames = directory_to_table(input_path)

    return dir_filenames
end

local function getFilteredFiles(input_filenames, input_regex)
    local filtered_filenames = {}
    local file_check = false
    for _, name in ipairs(input_filenames) do
        if string.match(name, input_regex) then
            table.insert(filtered_filenames, name)
            file_check = true
        end
    end

    return filtered_filenames, file_check
end

local toliss_announcements_files = getDirectoryFiles(toliss_announcements_dir)

local function GetSoundFile(input_regex)
    -- Function to get the sound file for a specific regex, can be linked to any call within a Fenix announcements soundpack

    local sound_files, sound_check = getFilteredFiles(toliss_announcements_files, input_regex)
    local load_sound = nil

    LogMsg(" Logging all filenames found by regex")
    for _, value in pairs(sound_files) do
        LogMsg(" Logging Filename " .. value)
    end

    if sound_check then
        local sound_file = GetRandomTableValue(sound_files) -- Get a random file if there are multiple files present
        load_sound = load_WAV_file(toliss_announcements_dir .. sound_file)
    else
        load_sound = nil
    end

    return load_sound, sound_check
end

local function storeSettings(settings_filename)
    -- Function to save the volume settings for flight attendant and captain calls.
    LogMsg(" Saving Volumes for Calls")
    local newSettings = {}
    newSettings.captain = {}
    newSettings.captain.masterVolume = capt_master_volume
    newSettings.captain.captBoardingComplete = capt_boarding_complete
    newSettings.captain.captBeforeTakeoff = capt_before_takeoff
    newSettings.captain.captCrewSeatsTakeoff = capt_crew_seats_takeoff
    newSettings.captain.captBeforeLanding = capt_before_landing
    newSettings.captain.captCrewSeatsLanding = capt_crew_seats_landing

    newSettings.flightAttendant = {}
    newSettings.flightAttendant.flightAttendentMasterVolume = flight_attendent_master_volume
    newSettings.flightAttendant.boardingMusic = boarding_music
    newSettings.flightAttendant.welcome = welcome
    newSettings.flightAttendant.safetyBriefing = safety_briefing
    newSettings.flightAttendant.afterTakeoff = after_takeoff
    newSettings.flightAttendant.descentSeatbelts = descent_seatbelts
    newSettings.flightAttendant.turbulence = turbulence
    newSettings.flightAttendant.preSafetyBriefing = pre_safety_briefing
    newSettings.flightAttendant.afterLanding = after_landing

    LIP.save(toliss_announcements_dir .. settings_filename, newSettings)

    LogMsg(" Saved Volume Settings to " .. toliss_announcements_dir .. settings_filename .. ".ini")
end

local function readSettings(settings_filename)
    -- Function to read the stored volume settings for both captain and flight attendant calls.
    LogMsg(" Reading Settings at " .. toliss_announcements_dir .. settings_filename)

    local file = io.open(toliss_announcements_dir .. settings_filename)
    if file == nil then
        return false
    end

    file:close()
    local settings = LIP.load(toliss_announcements_dir .. settings_filename)

    settings.captain = settings.captain or {}
    settings.flightAttendant = settings.flightAttendant or {}

    capt_master_volume = settings.captain.masterVolume
    capt_boarding_complete = settings.captain.captBoardingComplete
    capt_before_takeoff = settings.captain.captBeforeTakeoff
    capt_crew_seats_takeoff = settings.captain.captCrewSeatsTakeoff
    capt_before_landing = settings.captain.captBeforeLanding
    capt_crew_seats_landing = settings.captain.captCrewSeatsLanding

    flight_attendent_master_volume = settings.flightAttendant.flightAttendentMasterVolume
    boarding_music = settings.flightAttendant.boardingMusic
    welcome = settings.flightAttendant.welcome
    safety_briefing = settings.flightAttendant.safetyBriefing
    after_takeoff = settings.flightAttendant.afterTakeoff
    descent_seatbelts = settings.flightAttendant.descentSeatbelts
    turbulence = settings.flightAttendant.turbulence
    pre_safety_briefing = settings.flightAttendant.preSafetyBriefing
    after_landing = settings.flightAttendant.afterLanding

    LogMsg(" Loaded stored volume settings.")

    return false
end

-- START of Sound Variables
-- Flight Attendant Variables
local boarding_music_sound, boarding_music_check = GetSoundFile("BoardingMusic%[?%w*%]?.wav$")
local welcome_sound, welcome_sound_check = GetSoundFile("BoardingWelcome%[?%w*%]?.wav$")
local presafety_briefing_sound, presafety_briefing_sound_check = GetSoundFile("PreSafetyBriefing%[?%w*%]?.wav$")
local safety_briefing_sound, safety_briefing_sound_check = GetSoundFile("SafetyBriefing%[?%w*%]?.wav$")
local turbulence_sound, turbulence_sound_check = GetSoundFile("Turbulence%[?%w*%]?.wav$")
local after_landing_sound, after_landing_sound_check = GetSoundFile("AfterLanding%[?%w*%]?.wav$")
local after_takeoff_sound, after_takeoff_sound_check = GetSoundFile("AfterTakeoff%[?%w*%]?.wav")
local descent_seatbelts_sound, descent_seatbelts_sound_check = GetSoundFile("DescentSeatbelts%[?%w*%]?.wav$")

-- Captain Variables
local boarding_complete_sound, boarding_complete_sound_check = GetSoundFile("BoardingComplete%[?%w*%]?.wav$")
local arm_doors_sound, arm_doors_check = GetSoundFile("ArmDoors%[?%w*%]?.wav$")
local before_takeoff_sound, before_takeoff_sound_check = GetSoundFile("CallCabinSecureTakeoff%[?%w*%]?.wav$")
local crew_seats_takeoff_sound, crew_seats_takeoff_sound_check = GetSoundFile("CrewSeatsTakeoff%[?%w*%]?.wav$")
local before_landing_sound, before_landing_sound_check = GetSoundFile("CallCabinSecureLanding%[?%w*%]?.wav$")
local crew_seats_landing_sound, crew_seats_landing_sound_check = GetSoundFile("CrewSeatsLanding%[?%w*%]?.wav$")
-- END of Sound Variables

function CabinAnnouncements(wnd, x, y)
    local win_width = imgui.GetWindowWidth()
    local win_height = imgui.GetWindowHeight()

    local heading = "Cabin Announcements Helper"
    local heading_width, heading_height = imgui.CalcTextSize(heading)
    imgui.SetCursorPos(win_width / 2 - heading_width / 2, imgui.GetCursorPosY())
    imgui.TextUnformatted(heading)

    if imgui.Button("Get Simbrief Data") then
        DataRef("icao_airline", "sbh/icao_airline")

        if icao_airline == "" then
            settings_filename = "cabin_announcements_volume.ini"
        else
            settings_filename = icao_airline .. "_volume.ini"
        end
        LogMsg(" Airline ICAO Code : " .. icao_airline)
        settings_read = readSettings(settings_filename)

        LogMsg(" Settings Read : " .. tostring(settings_read))

        if settings_read then
            settings_filename = "cabin_announcements_volume.ini"
            LogMsg(" No airline config file found. Defaulting to " .. settings_filename)
            settings_read = readSettings(settings_filename)
        end
    end

    imgui.Separator()

    -- START Volume Settings
    if not settings_read then
        if imgui.TreeNode("Announcement Volume Control") then
            if imgui.TreeNode("Flight Attendant Volume") then
                -- Flight Attendant Master Volume
                local fa_master_changed, fa_master_newval = imgui.SliderInt("Master Volume",
                    flight_attendent_master_volume, -20, 20, "Value: %.0f")
                if fa_master_changed then
                    flight_attendent_master_volume = fa_master_newval
                end

                -- Boarding Music Volume
                local bm_changed, bm_newval = imgui.SliderInt("Boarding Music Volume", boarding_music, -20, 20,
                    "Value :%.0f")
                if bm_changed then
                    boarding_music = bm_newval
                end

                -- Welcome Volume
                local wel_changed, wel_newval = imgui.SliderInt("Welcome Volume", welcome, -20, 20, "Value :%.0f")
                if wel_changed then
                    welcome = wel_newval
                end

                -- Safety Briefing Volume
                local sb_changed, sb_newval = imgui.SliderInt("Safety Briefing Volume", safety_briefing, -20, 20,
                    "Value :%.0f")
                if sb_changed then
                    safety_briefing = sb_newval
                end

                -- After Takeoff Volume
                local at_changed, at_newval = imgui.SliderInt("After Takeoff Volume", after_takeoff, -20, 20,
                    "Value :%.0f")
                if at_changed then
                    after_takeoff = at_newval
                end

                -- Descent Seatbelts Volume
                local ds_changed, ds_newval = imgui.SliderInt("Descent Seatbelts Volume", descent_seatbelts, -20, 20,
                    "Value :%.0f")
                if ds_changed then
                    descent_seatbelts = ds_newval
                end

                -- Turbulence Volume
                local tv_changed, tv_newval = imgui.SliderInt("Turbulence Volume", turbulence, -20, 20, "Value :%.0f")
                if tv_changed then
                    turbulence = tv_newval
                end

                -- Pre Safety Briefing Volume
                local psb_changed, psb_newval = imgui.SliderInt("Pre Safety Briefing Volume", pre_safety_briefing, -20,
                    20, "Value :%.0f")
                if psb_changed then
                    pre_safety_briefing = psb_newval
                end

                -- After Landing Volume
                local al_changed, al_newval = imgui.SliderInt("After Landing Volume", after_landing, -20, 20,
                    "Value :%.0f")
                if al_changed then
                    after_landing = al_newval
                end
                imgui.TreePop()
            end

            if imgui.TreeNode("Captin Volume") then
                -- Captain Master Volume
                local cap_master_changed, cap_master_newval = imgui.SliderInt("Captain Master Volumme",
                    capt_master_volume, -20, 20, "Value: %.0f")
                if cap_master_changed then
                    capt_master_volume = cap_master_newval
                end

                -- Boarding Complete Volume
                local cap_bc_changed, cap_bc_newval = imgui.SliderInt("Boarding Complete Volume", capt_boarding_complete,
                    -20, 20, "Value :%.0f")
                if cap_bc_changed then
                    capt_boarding_complete = cap_bc_newval
                end

                -- Gate Departure Volume
                local cap_gd_changed, cap_gd_newval = imgui.SliderInt("Gate Departure Volume", capt_gate_departure, -20,
                    20, "Value :%.0f")
                if cap_gd_changed then
                    capt_gate_departure = cap_gd_newval
                end

                -- Before Takeoff Volume
                local cap_bt_changed, cap_bt_newval = imgui.SliderInt("Before Takeoff Volume", capt_before_takeoff, -20,
                    20, "Value :%.0f")
                if cap_bt_changed then
                    capt_before_takeoff = cap_bt_newval
                end

                -- Crew Seats Takeoff Volume
                local cap_cst_changed, cap_cst_newval = imgui.SliderInt("Crew Seats Takeoff Volume",
                    capt_crew_seats_takeoff, -20, 20, "Value :%.0f")
                if cap_cst_changed then
                    capt_crew_seats_takeoff = cap_cst_newval
                end

                -- Before Landing Volume
                local cap_bl_changed, cap_bl_newval = imgui.SliderInt("Before Landing Volume", capt_before_landing, -20,
                    20, "Value :%.0f")
                if cap_bl_changed then
                    capt_before_landing = cap_bl_newval
                end

                -- Crew Seats Landing Volume
                local cap_csl_changed, cap_csl_newval = imgui.SliderInt("Crew Seats Landing Volume",
                    capt_crew_seats_landing, -20, 20, "Value :%.0f")
                if cap_csl_changed then
                    capt_crew_seats_landing = cap_csl_newval
                end
                imgui.TreePop()
            end

            if imgui.Button("Save Settings") then
                if settings_filename == "cabin_announcements_volume.ini" then
                    local airline_settings_filename = icao_airline .. "_volume.ini"
                    storeSettings(airline_settings_filename)
                    LogMsg(" New Airline volume config. Airline ICAO: " .. icao_airline)
                else
                    storeSettings(settings_filename)
                end
            end
            imgui.TreePop()
        end
    end
    -- END Volume Settings

    -- START Flight Attendant Announcements
    if not settings_read then
        if imgui.TreeNode("Flight Attendent Calls") then
            if boarding_music_check then
                if imgui.TreeNode("Boarding Music") then
                    -- boarding_music_sound = GetBoardingMusic()
                    if imgui.Button("Play Boarding Music") then
                        PlayAnnouncement(boarding_music_sound, flight_attendent_master_volume + boarding_music, true)
                    end

                    imgui.SameLine()
                    imgui.SetCursorPosX(150 * 2)

                    if imgui.Button("Stop Boarding Music") then
                        StopAnnouncement(boarding_music_sound, "stop")
                    end
                    imgui.TreePop()
                end
            end

            if welcome_sound_check then
                if imgui.TreeNode("Welcome Aboard") then
                    -- welcome_sound = GetWelcomeSound()
                    if imgui.Button("Play Welcome Aboard") then
                        PlayAnnouncement(welcome_sound, flight_attendent_master_volume + welcome, false)
                    end

                    imgui.SameLine()
                    imgui.SetCursorPosX(150 * 2)
                    if imgui.Button("Stop Welcome Aboard") then
                        StopAnnouncement(welcome_sound)
                    end
                    imgui.TreePop()
                end
            end

            if imgui.TreeNode("Safety Briefing") then
                -- presafety_briefing_sound = GetPreSafetyBriefing()
                if presafety_briefing_sound_check then
                    if imgui.Button("Play Pre-Safety Briefing") then
                        PlayAnnouncement(presafety_briefing_sound, flight_attendent_master_volume + pre_safety_briefing,
                            false)
                    end

                    imgui.SameLine()
                    imgui.SetCursorPosX(150 * 2)

                    if imgui.Button("Stop Pre-Safety Briefing") then
                        StopAnnouncement(presafety_briefing_sound)
                    end
                end

                if safety_briefing_sound_check then
                    -- safety_briefing_sound = GetSafetyBriefing()
                    if imgui.Button("Play Safety Briefing") then
                        PlayAnnouncement(safety_briefing_sound, flight_attendent_master_volume + safety_briefing, false)
                    end

                    imgui.SameLine()
                    imgui.SetCursorPosX(150 * 2)

                    if imgui.Button("Stop Safey Briefing") then
                        StopAnnouncement(safety_briefing_sound)
                    end
                end
                imgui.TreePop()
            end

            if after_takeoff_sound_check then
                if imgui.TreeNode("After Takeoff") then
                    if imgui.Button("Play After Takeoff") then
                        PlayAnnouncement(after_takeoff_sound, flight_attendent_master_volume + after_takeoff, false)
                    end

                    imgui.SameLine()
                    imgui.SetCursorPosX(150 * 2)

                    if imgui.Button("Stop After Takeoff") then
                        StopAnnouncement(after_takeoff_sound, "stop")
                    end
                    imgui.TreePop()
                end
            end

            if descent_seatbelts_sound_check then
                if imgui.TreeNode("Descent") then
                    if imgui.Button("Play Descent & Seatbelts") then
                        PlayAnnouncement(descent_seatbelts_sound, flight_attendent_master_volume + descent_seatbelts,
                            false)
                    end

                    imgui.SameLine()
                    imgui.SetCursorPosX(150 * 2)

                    if imgui.Button("Stop Descent & Seatbelts") then
                        StopAnnouncement(descent_seatbelts_sound, "stop")
                    end
                    imgui.TreePop()
                end
            end

            if turbulence_sound_check then
                if imgui.TreeNode("Turbulence") then
                    -- turbulence_sound = GetTurbulence()
                    if imgui.Button("Play Turbulence") then
                        PlayAnnouncement(turbulence_sound, flight_attendent_master_volume + turbulence, false)
                    end

                    imgui.SameLine()
                    imgui.SetCursorPosX(150 * 2)

                    if imgui.Button("Stop Turbulence") then
                        StopAnnouncement(turbulence_sound, flight_attendent_master_volume + turbulence, false)
                    end
                    imgui.TreePop()
                end
            end

            if after_landing_sound_check then
                if imgui.TreeNode("After Landing") then
                    -- after_landing_sound = GetAfterLanding()

                    if imgui.Button("Play After Landing") then
                        PlayAnnouncement(after_landing_sound, flight_attendent_master_volume + after_landing, false)
                    end

                    imgui.SameLine()
                    imgui.SetCursorPosX(150 * 2)

                    if imgui.Button(" Stop After Landing") then
                        StopAnnouncement(after_landing_sound)
                    end
                    imgui.TreePop()
                end
            end

            imgui.TreePop()
        end
    end
    -- END Flight Attendant Announcements

    -- START Captain Announcements
    if not settings_read then
        if imgui.TreeNode("CAPT Calls") then
            if boarding_complete_sound_check then
                if imgui.TreeNode("Boarding Complete") then
                    -- boarding_complete_sound = GetBoardingComplete()

                    if imgui.Button("Play Boarding Complete") then
                        PlayAnnouncement(boarding_complete_sound, capt_master_volume + capt_boarding_complete, false)
                    end

                    imgui.SameLine()
                    imgui.SetCursorPosX(150 * 2)

                    if imgui.Button("Stop Boarding Complete") then
                        StopAnnouncement(boarding_complete_sound)
                    end
                    imgui.TreePop()
                end
            end

            if arm_doors_check then
                if imgui.TreeNode("Arm Doors") then
                    -- arm_doors_sound = GetArmDoors()

                    if imgui.Button("Play Arm Doors") then
                        PlayAnnouncement(arm_doors_sound, capt_master_volume + capt_gate_departure, false)
                    end

                    imgui.SameLine()
                    imgui.SetCursorPosX(150 * 2)

                    if imgui.Button("Stop Arm Doors") then
                        StopAnnouncement(arm_doors_sound)
                    end
                    imgui.TreePop()
                end
            end

            if imgui.TreeNode("Takeoff") then
                if before_takeoff_sound_check then
                    if imgui.Button("Play Cabin Secure for Takeoff") then
                        PlayAnnouncement(before_takeoff_sound, capt_master_volume + capt_before_takeoff, false)
                    end

                    imgui.SameLine()
                    imgui.SetCursorPosX(150 * 2)

                    if imgui.Button("Stop Cabin Secure for Takeoff") then
                        StopAnnouncement(before_takeoff_sound)
                    end
                end

                if crew_seats_takeoff_sound_check then
                    if imgui.Button("Play Crew Stations") then
                        PlayAnnouncement(crew_seats_takeoff_sound, capt_master_volume + capt_crew_seats_takeoff, false)
                    end

                    imgui.SameLine()
                    imgui.SetCursorPosX(150 * 2)

                    if imgui.Button("Stop Crew Stations") then
                        StopAnnouncement(crew_seats_takeoff_sound)
                    end
                end
                imgui.TreePop()
            end

            if imgui.TreeNode("Landing") then
                if before_landing_sound_check then
                    if imgui.Button("Play Cabin Secure for Landing") then
                        PlayAnnouncement(before_landing_sound, capt_master_volume + capt_before_landing, false)
                    end

                    imgui.SameLine()
                    imgui.SetCursorPosX(150 * 2)

                    if imgui.Button("Stop Cabin Secure for Landing") then
                        StopAnnouncement(before_landing_sound, "stop")
                    end
                end

                if crew_seats_landing_sound_check then
                    if imgui.Button("Play Crew Stations Landing") and crew_seats_landing_sound_check then
                        PlayAnnouncement(crew_seats_landing_sound, capt_master_volume + capt_crew_seats_landing, false)
                    end

                    imgui.SameLine()
                    imgui.SetCursorPosX(150 * 2)

                    if imgui.Button("Stop Crew Stations Landing") and crew_seats_landing_sound_check then
                        StopAnnouncement(crew_seats_landing_sound, "stop")
                    end
                end
                imgui.TreePop()
            end
            imgui.TreePop()
        end
    end
    -- END Captain Announcements
end

function CloseCabinAnnouncements(wnd)
    -- Placeholder function for closing the cabin announcements window
end

-- CREATES A TOGGABLE WINDOW FOR THE CABIN ANNOUNCEMENTS
cabin_menu_wnd = nil -- flag for toggling the window on and off.

function cabin_menu_show_wnd()
    cabin_menu_wnd = float_wnd_create(600, 280, 1, true)
    float_wnd_set_title(cabin_menu_wnd, "Cabin Announcements")
    float_wnd_set_imgui_builder(cabin_menu_wnd, "CabinAnnouncements")
    float_wnd_set_onclose(cabin_menu_wnd, "CloseCabinAnnouncements")
end

function cabin_menu_hide_wnd()
    if cabin_menu_wnd then
        float_wnd_destroy(cabin_menu_wnd)
    end
end

cabin_menu_show_only_once = 0
cabin_menu_hide_only_once = 0

function toggle_cabin_wnd_command()
    cabin_show_wnd = not cabin_show_wnd
    if cabin_show_wnd then
        if cabin_menu_show_only_once == 0 then
            cabin_menu_show_wnd()
            cabin_menu_show_only_once = 1
            cabin_menu_hide_only_once = 0
        end
    else
        if cabin_menu_hide_only_once == 0 then
            cabin_menu_hide_wnd()
            cabin_menu_show_only_once = 0
            cabin_menu_hide_only_once = 1
        end
    end
end

-- readSettings() -- Loading saved volume settings.

add_macro("Cabin Announcements", "cabin_menu_show_wnd()", "cabin_menu_hide_wnd()", "deactivate")
create_command("FlyWithLua/Cabin Announcement Window/show-toggle", "Open/Close the GUI for cabin announcements",
    "toggle_cabin_wnd_command()", "", "")

-- END OF WINDOW CREATION

-- do_sometimes("AutomaticCabinAnnouncements()")
