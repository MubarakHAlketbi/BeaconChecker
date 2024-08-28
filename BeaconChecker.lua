local addonName, addon = ...
local AceGUI = LibStub("AceGUI-3.0")
local AceAddon = LibStub("AceAddon-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")
local ADDON_VERSION = "@project-version@"
local BeaconChecker = AceAddon:NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

-- Quest Data
local questData = {
    {id = 79216, name = "Web of Manipulation", npc = "Erol Ellimoore", map = "2215:6320:2940"},
    {id = 78915, name = "Squashing the Threat", npc = "Seraphine Seedheart", map = "2215:6360:3379.9999999999995"},
    {id = 81632, name = "Lizard Looters", npc = "Attica Whiskervale", map = "2215:6440.000000000001:1880"},
    {id = 79346, name = "Chew On That", npc = "Taerry Bilgestone", map = "2215:6580:2440"},
    {id = 76394, name = "Shadows of Flavor", npc = "Chef Dinaire", map = "2215:6440.000000000001:3100"},
    {id = 78933, name = "The Sweet Eclipse", npc = "Chef Dinaire", map = "2215:6440.000000000001:3100"},
    {id = 79158, name = "Seeds of Salvation", npc = "Auebry Irongear", map = "2215:6520:2800"},
    {id = 76600, name = "Right Between the Gyro-Optics", npc = "Auebry Irongear", map = "2215:6520:2800"},
    {id = 81574, name = "Sporadic Growth", npc = "Yorvas Flintstrike", map = "2215:6459.999999999999:3060"},
    {id = 78972, name = "Harvest Havoc", npc = "Seraphine Seedheart", map = "2215:6360:3379.9999999999995"},
    {id = 79173, name = "Supply the Effort", npc = "Erol Ellimoore", map = "2215:6320:2940"},
    {id = 76169, name = "Glow in the Dark", npc = "Attica Whiskervale", map = "2215:6440.000000000001:1880"},
    {id = 78656, name = "Hose It Down", npc = "Taerry Bilgestone", map = "2215:6580:2440"},
    {id = 80004, name = "Crab Grab", npc = "Empty Crab Cage", map = "2215:6150:1750"},
    {id = 80562, name = "Blossoming Delight", npc = "Unknown", map = "Unknown"},
    {id = 76733, name = "Tater Trawl", npc = "Unknown", map = "Unknown"},
    {id = 76997, name = "Lost in Shadows", npc = "Yorvas Flintstrike", map = "2215:6459.999999999999:3060"},
}

local ACHIEVEMENT_ID = 40308
local playerRegion = GetCurrentRegion()
local regionName = (playerRegion == 1 and "US") or (playerRegion == 2 and "KR") or (playerRegion == 3 and "EU") or (playerRegion == 4 and "TW") or (playerRegion == 5 and "CN") or "Unknown"

local isTomTomLoaded = false

local defaults = {
    profile = {
        minimap = {
            hide = false,
        },
    }
}


function BeaconChecker:OnInitialize()
    self.db = AceDB:New("BeaconCheckerDB", defaults, true)
    
    self:RegisterChatCommand("beacons", "SlashCommand")
    
    self:SetupOptions()
    self:CreateMinimapButton()
    
    print(addonName .. " addon loaded. Type /beacons to open the window or use the minimap button.")
end


function BeaconChecker:CheckForTomTom()
    isTomTomLoaded = _G.TomTom ~= nil
end

function BeaconChecker:OnEnable()
    self:RegisterEvent("QUEST_TURNED_IN", "UpdateContent")
    self:RegisterEvent("ACHIEVEMENT_EARNED", "UpdateContent")
    self:CheckForTomTom()

    -- Refresh the minimap button
    if self.minimapIcon then
        self.minimapIcon:Refresh("BeaconChecker", self.db.profile.minimap)
    end
end



function BeaconChecker:OnDisable()
    self:UnregisterAllEvents()
end

function BeaconChecker:SetupOptions()
    local options = {
        name = "BeaconChecker",
        handler = BeaconChecker,
        type = 'group',
        args = {
            minimap = {
                type = "toggle",
                name = "Show Minimap Button",
                desc = "Toggle the minimap button",
                get = function() return not self.db.profile.minimap.hide end,
                set = function(_, val)
                    self.db.profile.minimap.hide = not val
                    if val then
                        self.minimapIcon:Show("BeaconChecker")
                    else
                        self.minimapIcon:Hide("BeaconChecker")
                    end
                end,
            },
        },
    }
    
    AceConfig:RegisterOptionsTable("BeaconChecker", options)
    self.optionsFrame = AceConfigDialog:AddToBlizOptions("BeaconChecker", "BeaconChecker")
end


function BeaconChecker:CreateMinimapButton()
    local LDB = LibStub("LibDataBroker-1.1")
    local icon = LDB:NewDataObject("BeaconChecker", {
        type = "launcher",
        icon = "Interface\\Icons\\inv_misc_spyglass_03",
        OnClick = function(_, button)
            if button == "LeftButton" then
                self:ToggleMainFrame()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Beacon Checker")
            tooltip:AddLine("Left-click to open the main window")
            tooltip:AddLine("or type /beacons")
        end,
    })
    
    local minimapIcon = LibStub("LibDBIcon-1.0")
    minimapIcon:Register("BeaconChecker", icon, self.db.profile.minimap)
    self.minimapIcon = minimapIcon

    -- Refresh the button to apply saved position
    minimapIcon:Refresh("BeaconChecker", self.db.profile.minimap)
end

function BeaconChecker:OnDisable()
    self:UnregisterAllEvents()
    
    -- Save the minimap button position
    local button = self.minimapIcon:GetMinimapButton("BeaconChecker")
    if button and button.db then
        self.db.profile.minimap.minimapPos = button.db.minimapPos
    end
end

-- Helper function to calculate the angle from coordinates
function BeaconChecker:GetMinimapAngle(x, y)
    local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local mapRadius = (minimapShape == "ROUND") and 80 or 70
    local dx, dy = x / mapRadius, y / mapRadius
    return math.deg(math.atan2(dy, dx)) % 360
end


-- Add a function to save the minimap position
function BeaconChecker:SaveMinimapPosition()
    local button = self.minimapIcon:GetMinimapButton("BeaconChecker")
    local angle = button:GetDragAngle() or 225
    self.db.profile.minimap.minimapPos = angle
end

function BeaconChecker:SlashCommand(input)
    self:ToggleMainFrame()
end

function BeaconChecker:ToggleMainFrame()
    if not self.mainFrame then
        self:CreateMainFrame()
    end
    
    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
    else
        self.mainFrame:Show()
        self:UpdateContent()
    end
end

function BeaconChecker:UpdateContent()
    if self.mainFrame and self.mainFrame:IsShown() then
        local tabGroup = self.mainFrame:GetUserData("tabGroup")
        if tabGroup then
            local selectedTab
            if tabGroup.GetValue and type(tabGroup.GetValue) == "function" then
                selectedTab = tabGroup:GetValue()
            else
                selectedTab = tabGroup.localstatus.selected
            end
            if selectedTab then
                self:SelectGroup(tabGroup, selectedTab)
            else
                -- If no tab is selected, default to the first tab
                tabGroup:SelectTab("weeklyQuests")
            end
        else
            -- If tabGroup is not found, recreate the main frame
            self.mainFrame:Release()
            self.mainFrame = nil
            self:CreateMainFrame()
            self.mainFrame:Show()
        end
    end
end

function BeaconChecker:CreateMainFrame()
    self.mainFrame = AceGUI:Create("Frame")
    self.mainFrame:SetTitle("Beacon Checker")
    self.mainFrame:SetLayout("Fill")
    self.mainFrame:SetCallback("OnClose", function(widget) widget:Hide() end)
    self.mainFrame:SetWidth(800)
    self.mainFrame:SetHeight(650)

    -- Disable resizing
    self.mainFrame.frame:SetResizable(false)
    if self.mainFrame.sizer_se then self.mainFrame.sizer_se:Hide() end
    if self.mainFrame.sizer_s then self.mainFrame.sizer_s:Hide() end
    if self.mainFrame.sizer_e then self.mainFrame.sizer_e:Hide() end

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetLayout("Flow")
    tabGroup:SetTabs({
        {text="Weekly Quests", value="weeklyQuests"},
        {text="Weekly Elites", value="weeklyElites"},
        {text="World Quests", value="worldQuests"}
    })
    
    -- Set up the callback for tab selection
    tabGroup:SetCallback("OnGroupSelected", function(container, event, group)
        self:SelectGroup(container, group)
    end)

    -- Select the initial tab
    tabGroup:SelectTab("weeklyQuests")

    self.mainFrame:AddChild(tabGroup)

    -- Ensure the frame can't be moved off-screen
    self.mainFrame.frame:SetClampedToScreen(true)

    -- Add a custom OnMouseDown handler to allow frame dragging from anywhere
    self.mainFrame.frame:SetMovable(true)
    self.mainFrame.frame:EnableMouse(true)
    self.mainFrame.frame:RegisterForDrag("LeftButton")
    self.mainFrame.frame:SetScript("OnDragStart", function(frame) frame:StartMoving() end)
    self.mainFrame.frame:SetScript("OnDragStop", function(frame) frame:StopMovingOrSizing() end)

    -- Add an escape key handler to close the frame
    _G["BeaconCheckerFrame"] = self.mainFrame.frame
    tinsert(UISpecialFrames, "BeaconCheckerFrame")

    -- Store the tabGroup reference in the mainFrame's user data
    self.mainFrame:SetUserData("tabGroup", tabGroup)

    -- Initially hide the frame
    self.mainFrame:Hide()
end

function BeaconChecker:SelectGroup(container, group)
    container:ReleaseChildren()
    if group == "weeklyQuests" then
        self:CreateWeeklyQuestsContent(container)
    elseif group == "weeklyElites" then
        self:CreateWeeklyElitesContent(container)
    elseif group == "worldQuests" then
        self:CreateWorldQuestsContent(container)
    end
end


function BeaconChecker:CreateWeeklyQuestsContent(container)
    local scrollContainer = AceGUI:Create("SimpleGroup")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetFullHeight(true)
    scrollContainer:SetLayout("Fill")
    container:AddChild(scrollContainer)

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scrollContainer:AddChild(scroll)

    -- Add headers
    local headerLine = AceGUI:Create("SimpleGroup")
    headerLine:SetFullWidth(true)
    headerLine:SetLayout("Flow")

    local headers = {"Quest Name", "Weekly Status", "Achievement Status", "In-game Pin"}
    local widths = {220, 100, 120, 100}
    
    if isTomTomLoaded then
        table.insert(headers, "TomTom Arrow")
        table.insert(widths, 100)
    end

    -- Add extra space between the last two columns
    widths[#widths - 1] = widths[#widths - 1] + 20
    if isTomTomLoaded then
        widths[#widths] = widths[#widths] + 20
    end

    for i, header in ipairs(headers) do
        local headerLabel = AceGUI:Create("InteractiveLabel")
        headerLabel:SetText(header)
        headerLabel:SetWidth(widths[i])
        headerLabel:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        headerLabel:SetJustifyH("CENTER")  -- Center the header text
        headerLine:AddChild(headerLabel)
    end

    scroll:AddChild(headerLine)

    -- Add a separator
    local separator = AceGUI:Create("Heading")
    separator:SetFullWidth(true)
    scroll:AddChild(separator)

    for i, quest in ipairs(questData) do
        local questLine = AceGUI:Create("SimpleGroup")
        questLine:SetFullWidth(true)
        questLine:SetLayout("Flow")

        local name = AceGUI:Create("InteractiveLabel")
        name:SetText(quest.name)
        name:SetWidth(220)
        questLine:AddChild(name)

        local status = AceGUI:Create("InteractiveLabel")
        local completed = C_QuestLog.IsQuestFlaggedCompleted(quest.id)
        status:SetText(completed and "Completed" or "Incomplete")
        status:SetWidth(100)
        status:SetColor(completed and 0 or 1, completed and 1 or 0, 0)
        status:SetJustifyH("CENTER")  -- Center the status text
        questLine:AddChild(status)

        local achievement = AceGUI:Create("InteractiveLabel")
        local achievementCompleted = self:IsAchievementCriteriaComplete(ACHIEVEMENT_ID, i)
        achievement:SetText(achievementCompleted and "Earned" or "Not Earned")
        achievement:SetWidth(120)
        achievement:SetColor(achievementCompleted and 0 or 1, achievementCompleted and 1 or 0, 0)
        achievement:SetJustifyH("CENTER")  -- Center the achievement text
        questLine:AddChild(achievement)

        local location = AceGUI:Create("Button")
        location:SetText("Location")
        location:SetWidth(120)  -- Increased width
        if quest.map ~= "Unknown" then
            local mapID, x, y = strsplit(":", quest.map)
            mapID, x, y = tonumber(mapID), tonumber(x)/100, tonumber(y)/100
            location:SetCallback("OnClick", function()
                C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
                WorldMapFrame:SetMapID(mapID)
                WorldMapFrame:Show()
            end)
        else
            location:SetDisabled(true)
        end
        questLine:AddChild(location)

        if isTomTomLoaded then
            local tomtom = AceGUI:Create("Button")
            tomtom:SetText("TomTom")
            tomtom:SetWidth(120)  -- Increased width
            if quest.map ~= "Unknown" then
                local mapID, x, y = strsplit(":", quest.map)
                mapID, x, y = tonumber(mapID), tonumber(x)/100, tonumber(y)/100
                tomtom:SetCallback("OnClick", function()
                    TomTom:AddWaypoint(mapID, x, y, {
                        title = quest.name,
                        from = "BeaconChecker",
                        persistent = false
                    })
                end)
            else
                tomtom:SetDisabled(true)
            end
            questLine:AddChild(tomtom)
        end

        scroll:AddChild(questLine)

        -- Add a thin line as a separator
        local lineSeparator = AceGUI:Create("Heading")
        lineSeparator:SetFullWidth(true)
        lineSeparator:SetHeight(1)
        scroll:AddChild(lineSeparator)
    end
end

function BeaconChecker:CreateWeeklyElitesContent(container)
    local label = AceGUI:Create("Label")
    label:SetText("Beacon weekly Elites content coming soon!")
    label:SetFullWidth(true)
    container:AddChild(label)
end

function BeaconChecker:CreateWorldQuestsContent(container)
    local label = AceGUI:Create("Label")
    label:SetText("Beacon Weekly world quests content coming soon!")
    label:SetFullWidth(true)
    container:AddChild(label)
end

function BeaconChecker:IsAchievementCriteriaComplete(achievementID, criteriaIndex)
    local _, _, completed, _, _, _, _, _, _, _, _, _, _ = GetAchievementCriteriaInfo(achievementID, criteriaIndex)
    return completed
end
