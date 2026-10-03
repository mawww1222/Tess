--[[
    Mawww Hub • MEGA MERGED V9
    Base: supplied Mawww Hub V6 integrated build.
    Consolidates overlapping W424 / L2 / K4N3K1 / ALF-derived modules
    already present in the base; adds the remaining Gluto Gate Bypass
    as a single reload-safe patch. Zilux/ModernV2 is intentionally not
    embedded as a second UI framework to avoid duplicate ScreenGui/event
    systems; Mawww's current UI is retained as the primary shell.
]]

--[[
    Mawww Hub - Video Style 2 Column Layout (FIXED V5 + W424 Camera)
    Standalone Roblox UI (no external library required)

    Layout:
      Every tab (except Home) has:
        Left GroupBox
        Right GroupBox

    Exposed helpers:
      VDUI:AddTab(name, icon)
      tab:AddGroupbox(side, title)
      group:AddToggle(id, text, default, callback)
      group:AddButton(text, callback)
      group:AddSlider(id, text, min, max, default, callback)
      group:AddDropdown(id, text, options, default, callback)
      group:AddLabel(text)
      group:AddDivider()
      VDUI:Notify(title, message, duration)

    Intended for inserting your VD script logic without changing UI layout.

    Performance pass: cached player enumeration, throttled visual/polling loops,
    and cached UIStroke animation targets to reduce idle CPU/GPU work.
]]

Players = game:GetService("Players")
UserInputService = game:GetService("UserInputService")
TweenService = game:GetService("TweenService")
RunService = game:GetService("RunService")
Workspace = game:GetService("Workspace")

LocalPlayer = Players.LocalPlayer
PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
CoreGui = game:GetService("CoreGui")

--// Performance: reuse one player list instead of allocating a fresh array
--// every time a feature scans MawwwGetPlayers(). It is kept current by
--// PlayerAdded/PlayerRemoving and is safe for the feature polling loops below.
MAWWW_PlayerCache = Players:GetPlayers()
Players.PlayerAdded:Connect(function(player)
    table.insert(MAWWW_PlayerCache, player)
end)
Players.PlayerRemoving:Connect(function(player)
    for i = #MAWWW_PlayerCache, 1, -1 do
        if MAWWW_PlayerCache[i] == player then
            table.remove(MAWWW_PlayerCache, i)
            break
        end
    end
end)
function MawwwGetPlayers()
    return MAWWW_PlayerCache
end

-- Prefer the executor's hidden UI container when available. This prevents game
-- scripts from clearing the hub when PlayerGui is rebuilt during loading/respawn.
function getMawwwGuiParent()
    local hidden = nil
    if type(gethui) == "function" then
        pcall(function() hidden = gethui() end)
    end
    if hidden then return hidden end
    if CoreGui then return CoreGui end
    return LocalPlayer:FindFirstChildOfClass("PlayerGui") or PlayerGui
end
MAWWW_GUI_PARENT = getMawwwGuiParent()

-- Executor compatibility: some environments do not expose getgenv().
if type(getgenv) ~= "function" then
    getgenv = function() return _G end
end

-- Cleanup the previous Stun Indicator runtime when the script is re-executed.
pcall(function()
    local genv = getgenv()
    if genv and type(genv.MAWWW_StunIndicatorShutdown) == "function" then
        genv.MAWWW_StunIndicatorShutdown()
    end
end)

pcall(function()
    local genv = getgenv()
    local oldV5 = genv and genv.MAWWW_AutoParryV5
    if oldV5 and type(oldV5.Destroy) == "function" then
        oldV5:Destroy()
    end
end)

--// Cleanup previous instance from all common GUI containers.
for _, container in ipairs({MAWWW_GUI_PARENT, PlayerGui, CoreGui}) do
    pcall(function()
        local existing = container and container:FindFirstChild("MawwwHub")
        if existing then existing:Destroy() end
    end)
end

--// Theme
ICON_ID = "rbxassetid://88250532753444"
HOME_ICON_ID = "rbxassetid://893565094168"
HOME_PHOTO_ID = "rbxassetid://97815205163579"
-- Survivor HUD replacement uses the exact same Roblox asset as the hub button/logo.
SURVIVOR_HIDE_ICON_URL = ICON_ID
ICON_URL = SURVIVOR_HIDE_ICON_URL

-- TikTok source requested for the UI background. Roblox GUI objects cannot directly
-- stream a TikTok URL. Upload the desired video/image to Roblox and put its asset
-- id in BACKGROUND_ASSET_ID below. The UI keeps a blue/purple animated fallback.
-- Roblox cannot stream a TikTok URL directly. Put a Roblox image/video asset id here
-- if you upload the video/background to Roblox. The supplied Home photo is used as
-- the visual fallback so the UI keeps the same anime/video-like look.
BACKGROUND_ASSET_ID = "97815205163579"
BACKGROUND_VIDEO_ID = "" -- Disabled so the requested image is the visible UI background.

Theme = {
    Background = Color3.fromRGB(8, 10, 18),
    Surface = Color3.fromRGB(15, 18, 30),
    Surface2 = Color3.fromRGB(21, 24, 39),
    Surface3 = Color3.fromRGB(27, 30, 49),
    Border = Color3.fromRGB(46, 52, 78),
    Text = Color3.fromRGB(245, 247, 255),
    SubText = Color3.fromRGB(158, 166, 190),
    Accent = Color3.fromRGB(82, 125, 255),
    Accent2 = Color3.fromRGB(165, 92, 255),
    Blue = Color3.fromRGB(65, 146, 255),
    Purple = Color3.fromRGB(166, 77, 255),
    Green = Color3.fromRGB(71, 205, 132),
    Red = Color3.fromRGB(237, 93, 93),
    Slider = Color3.fromRGB(100, 112, 255),
}

function New(className, props, parent)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    obj.Parent = parent

    -- Input safety: interactive Roblox GUI objects should never be left
    -- non-interactable or underneath a container/ScrollingFrame layer.
    -- Keep existing explicit high ZIndex values untouched.
    if obj:IsA("GuiButton") then
        pcall(function() obj.Active = true end)
        pcall(function() obj.Interactable = true end)
        pcall(function()
            if obj.ZIndex < 20 then
                obj.ZIndex = 20
            end
        end)
    elseif obj:IsA("TextBox") then
        pcall(function() obj.Active = true end)
        pcall(function() obj.Interactable = true end)
        pcall(function()
            if obj.ZIndex < 20 then
                obj.ZIndex = 20
            end
        end)
    end

    return obj
end

function Corner(parent, radius)
    return New("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
    }, parent)
end

function Stroke(parent, color, thickness, transparency)
    return New("UIStroke", {
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
    }, parent)
end

function Tween(obj, info, props)
    return TweenService:Create(obj, info, props)
end

function formatRounding(step)
    step = tonumber(step)
    if not step or step >= 1 then
        return 0
    end
    local n = 0
    local x = math.abs(step)
    while x < 1 and n < 6 do
        x = x * 10
        n = n + 1
    end
    return n
end

-- Main UI layer
for _, container in ipairs({MAWWW_GUI_PARENT, PlayerGui, CoreGui}) do
    pcall(function()
        local existing = container and container:FindFirstChild("MawwwHubPopupLayer")
        if existing then existing:Destroy() end
    end)
end

ScreenGui = New("ScreenGui", {
    Name = "MawwwHub",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    DisplayOrder = 100,
}, MAWWW_GUI_PARENT)

-- Dedicated overlay layer.  Dropdowns/color pickers are placed here instead of
-- inside a GroupBox row so they are never clipped by GroupBox/ScrollingFrame parents.
PopupLayer = New("ScreenGui", {
    Name = "MawwwHubPopupLayer",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    DisplayOrder = 10000,
}, MAWWW_GUI_PARENT)

--// Main window
Main = New("Frame", {
    Name = "Main",
    Size = UDim2.new(0.82, 0, 0.80, 0),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Theme.Background,
    BackgroundTransparency = 0.20,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 1,
    Visible = false,
}, ScreenGui)

New("UISizeConstraint", {
    -- Allow the main window to actually collapse to the minimize bar height.
    -- The normal window size remains constrained by the same width/height limits.
    MinSize = Vector2.new(560, 44),
    MaxSize = Vector2.new(760, 520),
}, Main)

-- Animated background layer. If BACKGROUND_ASSET_ID is set, it is used as the image.
BackgroundImage = New("ImageLabel", {
    Name = "Background",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Image = (BACKGROUND_ASSET_ID ~= "" and ("rbxassetid://" .. BACKGROUND_ASSET_ID) or ""),
    ImageTransparency = 0.94,
    ScaleType = Enum.ScaleType.Crop,
    ZIndex = 0,
    Active = false,
}, Main)

BackgroundVideo = New("VideoFrame", {
    Name = "BackgroundVideo",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Video = BACKGROUND_VIDEO_ID ~= "" and ("rbxassetid://" .. BACKGROUND_VIDEO_ID) or "",
    Volume = 0,
    Looped = true,
    Playing = false,
    Visible = BACKGROUND_VIDEO_ID ~= "",
    ZIndex = 0,
    Active = false,
}, Main)

if BACKGROUND_VIDEO_ID ~= "" then
    BackgroundVideo.Loaded:Connect(function()
        pcall(function() BackgroundVideo:Play() end)
    end)
    task.delay(8, function()
        if not BackgroundVideo.IsLoaded then
            BackgroundVideo.Visible = false
            BackgroundImage.ImageTransparency = 0.12
        end
    end)
end

BackgroundTint = New("Frame", {
    Name = "BackgroundTint",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(5, 6, 15),
    BackgroundTransparency = 0.58,
    BorderSizePixel = 0,
    ZIndex = 0,
    Active = false,
}, Main)

BackgroundGradient = New("UIGradient", {
    Rotation = 35,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 28, 65)),
        ColorSequenceKeypoint.new(0.48, Color3.fromRGB(10, 12, 25)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(48, 18, 70)),
    }),
}, BackgroundImage)

Corner(Main, 14)
Stroke(Main, Theme.Border, 1)

--// Top accent line
AccentLine = New("Frame", {
    Name = "AccentLine",
    Size = UDim2.new(1, 0, 0, 3),
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0,
}, Main)

Header = New("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundTransparency = 1,
}, Main)

Logo = New("ImageButton", {
    Size = UDim2.fromOffset(38, 38),
    Position = UDim2.fromOffset(8, 3),
    BackgroundColor3 = Theme.Surface3,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Image = HOME_PHOTO_ID,
    ImageColor3 = Color3.new(1, 1, 1),
    ScaleType = Enum.ScaleType.Crop,
}, Header)
Corner(Logo, 11)
Stroke(Logo, Theme.Accent, 1)

New("TextLabel", {
    Position = UDim2.fromOffset(56, 5),
    Size = UDim2.fromOffset(210, 22),
    BackgroundTransparency = 1,
    Text = "MAWWW HUB",
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Theme.Text,
}, Header)

New("TextLabel", {
    Position = UDim2.fromOffset(56, 26),
    Size = UDim2.fromOffset(270, 15),
    BackgroundTransparency = 1,
    Text = "Premium Interface  •  Fast  •  Clean  •  Lightweight",
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Theme.SubText,
}, Header)

CloseButton = New("TextButton", {
    Name = "Close",
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -36, 0, 9),
    BackgroundColor3 = Theme.Surface2,
    BorderSizePixel = 0,
    Text = "×",
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    TextColor3 = Theme.SubText,
    AutoButtonColor = false,
}, Header)
Corner(CloseButton, 9)
Stroke(CloseButton, Theme.Border, 1)

HeaderStatus = New("TextLabel", {
    Name = "Status",
    Size = UDim2.fromOffset(110, 24),
    Position = UDim2.new(1, -226, 0, 11),
    BackgroundColor3 = Theme.Surface2,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    Text = "●  READY",
    Font = Enum.Font.GothamBold,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextColor3 = Theme.Accent,
}, Header)
Corner(HeaderStatus, 8)
Stroke(HeaderStatus, Theme.Border, 1)

MinimizeButton = New("TextButton", {
    Name = "Minimize",
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -70, 0, 9),
    BackgroundColor3 = Theme.Surface2,
    BorderSizePixel = 0,
    Text = "—",
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextColor3 = Theme.SubText,
    AutoButtonColor = false,
}, Header)
Corner(MinimizeButton, 9)
Stroke(MinimizeButton, Theme.Border, 1)

--// Content containers
Sidebar = New("Frame", {
    Name = "Sidebar",
    Size = UDim2.new(0, 124, 1, -48),
    Position = UDim2.fromOffset(7, 45),
    BackgroundColor3 = Theme.Surface,
    BackgroundTransparency = 0.10,
    BorderSizePixel = 0,
}, Main)
Corner(Sidebar, 10)
Stroke(Sidebar, Theme.Border, 1)

-- Photo header: intentionally limited to the upper section of the sidebar,
-- so the photo sits above the tabs instead of covering the whole UI.
SidebarPhoto = New("ImageLabel", {
    Name = "SidebarPhoto",
    Size = UDim2.new(1, -12, 0, 82),
    Position = UDim2.fromOffset(6, 6),
    BackgroundColor3 = Theme.Surface2,
    BackgroundTransparency = 0,
    BorderSizePixel = 0,
    Image = HOME_PHOTO_ID,
    ImageColor3 = Color3.new(1, 1, 1),
    ImageTransparency = 0,
    ScaleType = Enum.ScaleType.Crop,
    ZIndex = 6,
    Active = false,
}, Sidebar)
Corner(SidebarPhoto, 10)
Stroke(SidebarPhoto, Theme.Border, 1)

local sidebarPhotoShade = New("Frame", {
    Name = "PhotoShade",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(6, 8, 16),
    BackgroundTransparency = 0.38,
    BorderSizePixel = 0,
    ZIndex = 7,
    Active = false,
}, SidebarPhoto)
Corner(sidebarPhotoShade, 10)

New("TextLabel", {
    Name = "PhotoTitle",
    Size = UDim2.new(1, -18, 0, 20),
    Position = UDim2.fromOffset(9, 8),
    BackgroundTransparency = 1,
    Text = "MAWWW HUB",
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Theme.Text,
    ZIndex = 8,
}, SidebarPhoto)

New("TextLabel", {
    Name = "PhotoSubtitle",
    Size = UDim2.new(1, -18, 0, 28),
    Position = UDim2.fromOffset(9, 31),
    BackgroundTransparency = 1,
    Text = "Clean controls  •  Fast access",
    Font = Enum.Font.GothamMedium,
    TextSize = 9,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextColor3 = Color3.fromRGB(230, 235, 255),
    ZIndex = 8,
}, SidebarPhoto)

TabsScroll = New("ScrollingFrame", {
    Name = "Tabs",
    Size = UDim2.new(1, -10, 1, -100),
    Position = UDim2.fromOffset(5, 96),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = Theme.Accent,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ZIndex = 3,
    Active = true,
}, Sidebar)

New("UIPadding", {
    PaddingTop = UDim.new(0, 4),
    PaddingBottom = UDim.new(0, 4),
    PaddingLeft = UDim.new(0, 4),
    PaddingRight = UDim.new(0, 4),
}, TabsScroll)

New("UIListLayout", {
    Padding = UDim.new(0, 5),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, TabsScroll)

PageHolder = New("Frame", {
    Name = "PageHolder",
    Size = UDim2.new(1, -140, 1, -48),
    Position = UDim2.fromOffset(140, 45),
    BackgroundTransparency = 1,
    ZIndex = 2,
}, Main)

-- Feature search bar. It stays above the active page and filters GroupBoxes
-- by their title and visible text, making large Aim/Survival tabs much easier
-- to navigate on both mouse and touch devices.
FeatureSearch = New("TextBox", {
    Name = "FeatureSearch",
    Size = UDim2.new(1, -10, 0, 30),
    Position = UDim2.fromOffset(2, 2),
    BackgroundColor3 = Theme.Surface,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    PlaceholderText = "Search features or categories...",
    PlaceholderColor3 = Theme.SubText,
    Text = "",
    TextColor3 = Theme.Text,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 40,
    Active = true,
}, PageHolder)
Corner(FeatureSearch, 8)
Stroke(FeatureSearch, Theme.Border, 1)
New("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, FeatureSearch)

FeatureSearchClear = New("TextButton", {
    Name = "Clear",
    Size = UDim2.fromOffset(24, 24),
    Position = UDim2.new(1, -28, 0, 5),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "×",
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextColor3 = Theme.SubText,
    AutoButtonColor = false,
    ZIndex = 45,
}, FeatureSearch)

pages = {}
tabButtons = {}
currentPage = nil
currentTabButton = nil

local function featureMatchesQuery(groupbox, query)
    query = tostring(query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" then return true end
    local pieces = {}
    if groupbox and groupbox:IsA("GuiObject") then
        table.insert(pieces, tostring(groupbox.Name or ""))
        local titleBar = groupbox:FindFirstChild("TitleBar")
        local titleLabel = titleBar and titleBar:FindFirstChildWhichIsA("TextLabel")
        if titleLabel then table.insert(pieces, tostring(titleLabel.Text or "")) end
        for _, obj in ipairs(groupbox:GetDescendants()) do
            if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                table.insert(pieces, tostring(obj.Text or ""))
            end
        end
    end
    return table.concat(pieces, " "):lower():find(query, 1, true) ~= nil
end

local function applyFeatureSearch(query)
    query = tostring(query or "")
    for _, tabData in pairs(pages) do
        local columns = tabData and tabData.columns
        if columns then
            for _, column in ipairs({tabData.left, tabData.right}) do
                if column and column.Parent then
                    for _, child in ipairs(column:GetChildren()) do
                        if child:IsA("GuiObject") and child.Name ~= "BottomSpacer" then
                            child.Visible = featureMatchesQuery(child, query)
                        end
                    end
                end
            end
        end
        if tabData and tabData.RefreshLayout then
            pcall(tabData.RefreshLayout)
        end
    end
end

FeatureSearch:GetPropertyChangedSignal("Text"):Connect(function()
    applyFeatureSearch(FeatureSearch.Text)
end)
FeatureSearchClear.MouseButton1Click:Connect(function()
    FeatureSearch.Text = ""
    FeatureSearch:CaptureFocus()
end)

--========================================================--
-- DISPLAY NAME / UI STYLE LAYER
-- Visual-only formatter: internal flags, callbacks and remotes remain untouched.
--========================================================--
local DISPLAY_TAB_NAMES = {
    Settings = "Settings",
    Player = "Player",
    Survivor = "Survivor",
    Killer = "Killer",
    Aim = "Aim Assist",
    ESP = "ESP",
    Visuals = "Visuals",
    Utilities = "Utilities",
    Automation = "Automation",
    UI = "Interface",
}

local DISPLAY_WORDS = {
    ["SURV"] = "Survivor",
    ["KILLER"] = "Killer",
    ["ESP"] = "ESP",
    ["FOV"] = "FOV",
    ["TOF"] = "ToF",
    ["UI"] = "UI",
    ["TP"] = "TP",
    ["AFK"] = "AFK",
    ["FPS"] = "FPS",
    ["HUD"] = "HUD",
    ["SCP"] = "SCP",
    ["GEN"] = "Gen",
    ["V1"] = "V1",
    ["V2"] = "V2",
    ["V3"] = "V3",
    ["V4"] = "V4",
    ["V5"] = "V5",
    ["RGB"] = "RGB",
}

local DISPLAY_RENAMES = {
    ["Auto Parry • V1"] = "Auto Parry · V1",
    ["Auto Parry • V2"] = "Auto Parry · V2",
    ["Auto Parry • V3"] = "Auto Parry · V3",
    ["Auto Parry • V4"] = "Auto Parry · V4",
    ["Auto Parry • V5"] = "Auto Parry · V5",
    ["Veil Aim • V1"] = "Veil Aim · V1",
    ["Veil Aim • V2"] = "Veil Aim · V2",
    ["Veil Aim • V3"] = "Veil Aim · V3",
    ["Veil Aim • V4"] = "Veil Aim · V4",
    ["Veil Aim • V5"] = "Veil Aim · V5",
    ["ToF Aim • V1"] = "ToF Aim · V1",
    ["ToF Aim • V2"] = "ToF Aim · V2",
    ["ToF Aim • V3"] = "ToF Aim · V3",
    ["ToF Aim • V4"] = "ToF Aim · V4",
    ["ToF Aim • V5"] = "ToF Aim · V5",
    ["Flashlight Aim"] = "Flashlight Assist",
    ["Flask & Cure"] = "Flask & Cure",
    ["Player & Object ESP"] = "Player & Object ESP",
    ["ESP Settings"] = "ESP Settings",
    ["HUD & Indicators"] = "HUD & Indicators",
    ["Teleport & Quick Actions"] = "Teleport & Quick Actions",
    ["Server Hop"] = "Server Hop",
    ["Configuration"] = "Configuration",
    ["Keybinds"] = "Keybinds",
    ["Movement"] = "Movement",
    ["Avatar"] = "Avatar",
    ["Bypass"] = "Bypass",
    ["Defense"] = "Defense",
    ["Utility"] = "Utilities",
    ["Prediction"] = "Prediction",
    ["Quick Actions"] = "Quick Actions",
    ["Movement Helpers"] = "Movement Helpers",
    ["Dodge & Skillcheck"] = "Dodge & Skillcheck",
    ["Fake & Utility"] = "Fake & Utilities",
    ["Lighting & HUD"] = "Lighting & HUD",
    ["HUD & Indicators"] = "HUD & Indicators",
    ["AutoFarm"] = "Auto Farm",
    ["NoSlow"] = "No Slow",
    ["SilentAim"] = "Silent Aim",
    ["SkillCheck"] = "Skill Check",
}

local function prettyDisplayName(value)
    local original = tostring(value or "")
    if DISPLAY_RENAMES[original] then return DISPLAY_RENAMES[original] end
    if original == "" then return original end

    local text = original
    text = text:gsub("([a-z%d])([A-Z])", "%1 %2")
    text = text:gsub("[_%-]+", " ")
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")

    local parts = {}
    for token in text:gmatch("[^%s]+") do
        local raw = token
        local lead, core, tail = raw:match("^([^%w]*)([%w]+)([^%w]*)$")
        lead, core, tail = lead or "", core or raw, tail or ""
        local upper = core:upper()
        if DISPLAY_WORDS[upper] then
            core = DISPLAY_WORDS[upper]
        elseif core:match("^%d+$") then
            core = core
        elseif core:match("^[Vv]%d+$") then
            core = core:upper()
        else
            core = core:sub(1,1):upper() .. core:sub(2):lower()
        end
        table.insert(parts, lead .. core .. tail)
    end
    return table.concat(parts, " ")
end

local function featureButtonGlyph(text)
    local s = tostring(text or ""):lower()
    if s:find("teleport", 1, true) or s:match("%ctp%c") then return "↗" end
    if s:find("save", 1, true) or s:find("export", 1, true) then return "⇩" end
    if s:find("load", 1, true) or s:find("import", 1, true) then return "⇧" end
    if s:find("reset", 1, true) or s:find("clear", 1, true) then return "↻" end
    if s:find("kill", 1, true) or s:find("attack", 1, true) then return "⚔" end
    if s:find("parry", 1, true) or s:find("dodge", 1, true) then return "◈" end
    if s:find("aim", 1, true) or s:find("target", 1, true) then return "⌖" end
    if s:find("esp", 1, true) or s:find("visual", 1, true) then return "◉" end
    if s:find("farm", 1, true) or s:find("generator", 1, true) or s:find("repair", 1, true) then return "⚙" end
    if s:find("copy", 1, true) then return "⧉" end
    return "›"
end

local function tabDisplayName(name)
    return DISPLAY_TAB_NAMES[name] or prettyDisplayName(name)
end

function MakeLogicTab(group)
    local proxy = {_box = group}
    function proxy:Toggle(config)
        config = config or {}
        local flag = config.Flag or config.Idx or ("Toggle_" .. tostring(os.clock()))
        local default = config.Value
        if default == nil then default = config.Default end
        local obj = self._box:AddToggle(flag, config.Title or config.Text or flag, default == true, config.Callback)
        return setmetatable({
            _obj = obj,
            SetValue = function(_,v) obj.Set(v) end,
            Set = function(_,v) obj.Set(v) end,
            Get = function() return obj.Get() end,
        }, {__index = obj})
    end
    function proxy:Slider(config)
        config = config or {}
        local flag = config.Flag or config.Idx or ("Slider_" .. tostring(os.clock()))
        local default = config.Default
        if default == nil then default = config.Value end
        local obj = self._box:AddSlider(flag, config.Title or config.Text or flag, tonumber(config.Min) or 0, tonumber(config.Max) or 100, tonumber(default) or 0, config.Callback, config.Step)
        return {SetValue=function(_,v) obj.Set(v) end, Set=function(_,v) obj.Set(v) end, Get=function() return obj.Get() end}
    end
    function proxy:Dropdown(config)
        config = config or {}
        local flag = config.Flag or config.Idx or ("Dropdown_" .. tostring(os.clock()))
        local default = config.Value
        if default == nil then default = config.Default end
        return self._box:AddDropdown(flag, config.Title or config.Text or flag, config.Values or {}, default, config.Callback, config.Multi == true)
    end
    function proxy:Button(config, callback)
        if type(config) == "string" then return self._box:AddButton(config, callback) end
        config = config or {}
        return self._box:AddButton(config.Title or config.Text or "Button", config.Callback)
    end
    function proxy:Input(config)
        config = config or {}
        local flag = config.Flag or config.Idx or ("Input_" .. tostring(os.clock()))
        local default = config.Value
        if default == nil then default = config.Default end
        return self._box:AddInput(flag, config.Title or config.Text or flag, default, config.Callback)
    end
    function proxy:Label(text)
        return self._box:AddLabel(text)
    end
    function proxy:Divider()
        return self._box:AddDivider()
    end
    function proxy:Keybind(config)
        config = config or {}
        local flag = config.Flag or config.Idx or ("Keybind_" .. tostring(os.clock()))
        return self._box:AddKeybind(flag, config.Title or config.Text or flag, config.Default or config.Value, config.Callback, config.Mode)
    end
    function proxy:Colorpicker(config)
        config = config or {}
        local flag = config.Flag or config.Idx or ("Color_" .. tostring(os.clock()))
        return self._box:AddColorpicker(flag, config.Title or config.Text or flag, config.Default, config.Callback)
    end
    return proxy
end

function CreateTabButton(name, order)
    local button = New("TextButton", {
        Name = name .. "TabButton",
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = order,
        ZIndex = 20,
    }, TabsScroll)
    Corner(button, 10)
    Stroke(button, Theme.Border, 1)

    local selection = New("Frame", {
        Name = "SelectionGlow",
        Size = UDim2.new(1, -8, 1, -8),
        Position = UDim2.fromOffset(4, 4),
        BackgroundColor3 = Theme.Surface2,
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 21,
    }, button)
    Corner(selection, 8)

    local indicator = New("Frame", {
        Name = "Indicator",
        Size = UDim2.fromOffset(3, 22),
        Position = UDim2.fromOffset(2, 7),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 23,
    }, button)
    Corner(indicator, 2)

    local iconPlate = New("Frame", {
        Name = "IconPlate",
        Size = UDim2.fromOffset(24, 24),
        Position = UDim2.fromOffset(8, 6),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        ZIndex = 22,
    }, button)
    Corner(iconPlate, 7)
    Stroke(iconPlate, Theme.Border, 1)

    local iconGlyphs = {
        Home = "⌂",
        Settings = "⚙",
        Player = "●",
        Survivor = "♙",
        Killer = "⚔",
        Aim = "⌖",
        ESP = "◉",
        Visuals = "◌",
        Utilities = "⚡",
        Automation = "⟳",
        UI = "▦",
        Interface = "▦",
        Combat = "⚔",
        Misc = "⋯",
    }

    local normalizedName = tostring(name or "")
    local iconGlyph = iconGlyphs[normalizedName]
    if not iconGlyph then
        local lowerName = normalizedName:lower()
        if lowerName:find("aim", 1, true) then
            iconGlyph = "⌖"
        elseif lowerName:find("surviv", 1, true) then
            iconGlyph = "♙"
        elseif lowerName:find("kill", 1, true) or lowerName:find("combat", 1, true) then
            iconGlyph = "⚔"
        elseif lowerName:find("esp", 1, true) or lowerName:find("visual", 1, true) then
            iconGlyph = "◉"
        elseif lowerName:find("auto", 1, true) or lowerName:find("farm", 1, true) then
            iconGlyph = "⟳"
        elseif lowerName:find("util", 1, true) or lowerName:find("tool", 1, true) then
            iconGlyph = "⚡"
        else
            iconGlyph = "◆"
        end
    end

    local icon = New("TextLabel", {
        Name = "TabIcon",
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0, 0),
        BackgroundTransparency = 1,
        Text = iconGlyph,
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextColor3 = Theme.SubText,
        ZIndex = 23,
    }, iconPlate)

    local label = New("TextLabel", {
        Name = "TabLabel",
        Size = UDim2.new(1, -72, 1, 0),
        Position = UDim2.fromOffset(40, 0),
        BackgroundTransparency = 1,
        Text = tabDisplayName(name),
        Font = Enum.Font.GothamSemibold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Theme.SubText,
        ZIndex = 22,
    }, button)

    local chevron = New("TextLabel", {
        Name = "TabChevron",
        Size = UDim2.fromOffset(18, 18),
        Position = UDim2.new(1, -24, 0.5, -9),
        BackgroundTransparency = 1,
        Text = "›",
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextColor3 = Theme.SubText,
        ZIndex = 22,
    }, button)

    button.MouseEnter:Connect(function()
        if currentTabButton ~= button then
            Tween(button, TweenInfo.new(0.14), {BackgroundColor3 = Theme.Surface2}):Play()
            Tween(iconPlate, TweenInfo.new(0.14), {BackgroundColor3 = Theme.Surface3}):Play()
            Tween(icon, TweenInfo.new(0.14), {TextColor3 = Theme.Text}):Play()
            Tween(chevron, TweenInfo.new(0.14), {TextColor3 = Theme.Text}):Play()
        end
    end)

    button.MouseLeave:Connect(function()
        if currentTabButton ~= button then
            Tween(button, TweenInfo.new(0.14), {BackgroundColor3 = Theme.Surface}):Play()
            Tween(iconPlate, TweenInfo.new(0.14), {BackgroundColor3 = Theme.Surface2}):Play()
            Tween(icon, TweenInfo.new(0.14), {TextColor3 = Theme.SubText}):Play()
            Tween(chevron, TweenInfo.new(0.14), {TextColor3 = Theme.SubText}):Play()
        end
    end)

    return button, indicator, label, icon
end

GroupMethods = {}
GroupMethods.__index = GroupMethods

--========================================================--
-- GLOBAL POPUP / OVERLAY LAYER
-- Popups live outside Main/Page/GroupBox/ScrollingFrame so they cannot disappear
-- because an ancestor ClipsDescendants=true.  Their position follows the anchor
-- button every frame, so scrolling and dragging the menu keep the popup aligned.
--========================================================--
local ACTIVE_POPUP = nil

local function getViewportSize()
    local camera = Workspace and Workspace.CurrentCamera
    if camera then
        local ok, size = pcall(function() return camera.ViewportSize end)
        if ok and size and size.X > 0 and size.Y > 0 then
            return size
        end
    end
    return Vector2.new(1920, 1080)
end

local function positionPopup(popup, anchor)
    if not popup or not popup.Parent or not anchor or not anchor.Parent then return end

    local okPos, aPos = pcall(function() return anchor.AbsolutePosition end)
    local okSize, aSize = pcall(function() return anchor.AbsoluteSize end)
    local okPSize, pSize = pcall(function() return popup.AbsoluteSize end)
    if not (okPos and okSize and okPSize and aPos and aSize and pSize) then return end

    -- Dropdown width follows the actual control width.  This avoids the popup
    -- becoming a 0-pixel object during the first frame after creation.
    if pSize.X < 2 then
        local popupWidth = math.max(140, math.floor(aSize.X + 0.5))
        popup.Size = UDim2.fromOffset(popupWidth, math.max(28, pSize.Y))
        pSize = popup.AbsoluteSize
    end

    local viewport = getViewportSize()
    local margin = 4
    local x = aPos.X
    local y = aPos.Y + aSize.Y + 4

    if pSize.X > 0 then
        x = math.clamp(x, margin, math.max(margin, viewport.X - pSize.X - margin))
    end

    if pSize.Y > 0 and (y + pSize.Y) > (viewport.Y - margin) then
        y = aPos.Y - pSize.Y - 4
    end
    y = math.max(margin, y)

    popup.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
end

local function closeActivePopup()
    if ACTIVE_POPUP then
        if ACTIVE_POPUP.connection then
            pcall(function() ACTIVE_POPUP.connection:Disconnect() end)
            ACTIVE_POPUP.connection = nil
        end
        if ACTIVE_POPUP.popup and ACTIVE_POPUP.popup.Parent then
            ACTIVE_POPUP.popup.Visible = false
        end
        ACTIVE_POPUP = nil
    end
end

local function openPopup(groupFrame, popup, anchor)
    if not popup or not popup.Parent then return end

    if ACTIVE_POPUP and ACTIVE_POPUP.popup ~= popup then
        closeActivePopup()
    end

    popup.Parent = PopupLayer
    popup.Visible = true
    popup.ZIndex = 100
    positionPopup(popup, anchor)

    local state = {
        group = groupFrame,
        popup = popup,
        anchor = anchor,
        connection = nil,
    }
    ACTIVE_POPUP = state

    state.connection = RunService.RenderStepped:Connect(function()
        if not ACTIVE_POPUP or ACTIVE_POPUP.popup ~= popup then return end
        if not Main.Visible then
            closeActivePopup()
            return
        end
        if not popup.Parent or not anchor or not anchor.Parent
            or (not anchor:IsDescendantOf(ScreenGui) and not anchor:IsDescendantOf(PopupLayer)) then
            closeActivePopup()
            return
        end
        positionPopup(popup, anchor)
    end)
end

local function closePopup(groupFrame, popup)
    if ACTIVE_POPUP and ACTIVE_POPUP.popup == popup then
        closeActivePopup()
        return
    end
    if popup and popup.Parent then
        popup.Visible = false
    end
end

function makeRow(parent, height)
    return New("Frame", {
        Size = UDim2.new(1, 0, 0, height or 36),
        BackgroundTransparency = 1,
    }, parent)
end

function GroupMethods:AddLabel(text)
    local row = makeRow(self.content, 28)
    New("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Theme.SubText,
    }, row)
    return row
end

function GroupMethods:AddDivider()
    local row = makeRow(self.content, 12)
    local line = New("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
    }, row)
    return line
end

function GroupMethods:AddButton(text, callback)
    local row = makeRow(self.content, 34)
    local button = New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, row)
    Corner(button, 9)
    Stroke(button, Theme.Border, 1)

    local accent = New("Frame", {
        Name = "Accent",
        Size = UDim2.fromOffset(3, 18),
        Position = UDim2.fromOffset(7, 8),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
    }, button)
    Corner(accent, 2)

    local glyph = New("TextLabel", {
        Name = "Glyph",
        Size = UDim2.fromOffset(22, 22),
        Position = UDim2.fromOffset(14, 6),
        BackgroundTransparency = 1,
        Text = featureButtonGlyph(text),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextColor3 = Theme.Accent2,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, button)

    New("TextLabel", {
        Size = UDim2.new(1, -56, 1, 0),
        Position = UDim2.fromOffset(39, 0),
        BackgroundTransparency = 1,
        Text = prettyDisplayName(text),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, button)

    New("TextLabel", {
        Name = "Arrow",
        Size = UDim2.fromOffset(18, 18),
        Position = UDim2.new(1, -24, 0.5, -9),
        BackgroundTransparency = 1,
        Text = "›",
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = Theme.SubText,
    }, button)

    button.MouseEnter:Connect(function()
        Tween(button, TweenInfo.new(0.12), {BackgroundColor3 = Theme.Surface3}):Play()
        Tween(accent, TweenInfo.new(0.12), {BackgroundColor3 = Theme.Accent2}):Play()
        Tween(glyph, TweenInfo.new(0.12), {TextColor3 = Theme.Text}):Play()
    end)
    button.MouseLeave:Connect(function()
        Tween(button, TweenInfo.new(0.12), {BackgroundColor3 = Theme.Surface2}):Play()
        Tween(accent, TweenInfo.new(0.12), {BackgroundColor3 = Theme.Accent}):Play()
        Tween(glyph, TweenInfo.new(0.12), {TextColor3 = Theme.Accent2}):Play()
    end)
    button.MouseButton1Click:Connect(function()
        if typeof(callback) == "function" then
            local ok, err = pcall(callback)
            if not ok then
                warn("[Mawww Hub] Button error:", err)
            end
        end
    end)
    return button
end

function GroupMethods:AddToggle(id, text, default, callback)
    local row = makeRow(self.content, 36)
    local state = default == true

    local click = New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, row)
    Corner(click, 9)
    Stroke(click, Theme.Border, 1)

    local dot = New("Frame", {
        Name = "StateDot",
        Size = UDim2.fromOffset(6, 6),
        Position = UDim2.fromOffset(8, 15),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
    }, click)
    Corner(dot, 3)

    local featureLabel = New("TextLabel", {
        Name = "FeatureName",
        Size = UDim2.new(1, -118, 1, 0),
        Position = UDim2.fromOffset(20, 0),
        BackgroundTransparency = 1,
        Text = prettyDisplayName(text),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Theme.Text,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, click)
    featureLabel:SetAttribute("FeatureDisplayName", featureLabel.Text)

    local stateBadge = New("Frame", {
        Name = "StateBadge",
        Size = UDim2.fromOffset(45, 20),
        Position = UDim2.new(1, -89, 0.5, -10),
        BackgroundColor3 = Theme.Surface3,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
    }, click)
    Corner(stateBadge, 7)
    Stroke(stateBadge, Theme.Border, 1, 0.25)

    local stateText = New("TextLabel", {
        Name = "StateText",
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0, 0),
        BackgroundTransparency = 1,
        Text = "OFF",
        Font = Enum.Font.GothamBold,
        TextSize = 8,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextColor3 = Theme.SubText,
    }, stateBadge)

    local track = New("Frame", {
        Size = UDim2.fromOffset(38, 20),
        Position = UDim2.new(1, -40, 0.5, -10),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
    }, click)
    Corner(track, 10)

    local knob = New("Frame", {
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = Theme.Text,
        BorderSizePixel = 0,
    }, track)
    Corner(knob, 8)

    local function setState(value, fire)
        state = value == true
        local targetColor = state and Theme.Accent or Theme.Border
        Tween(track, TweenInfo.new(0.15), {BackgroundColor3 = targetColor}):Play()
        Tween(knob, TweenInfo.new(0.15), {
            Position = state and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2),
        }):Play()
        Tween(dot, TweenInfo.new(0.15), {BackgroundColor3 = state and Theme.Green or Theme.Border}):Play()
        stateText.Text = state and "ON" or "OFF"
        stateText.TextColor3 = state and Theme.Green or Theme.SubText
        stateBadge.BackgroundColor3 = state and Color3.fromRGB(18, 48, 39) or Theme.Surface3
        if fire and typeof(callback) == "function" then
            local ok, err = pcall(callback, state)
            if not ok then
                warn("[Mawww Hub] Toggle error:", id, err)
            end
        end
    end

    click.MouseEnter:Connect(function()
        Tween(click, TweenInfo.new(0.12), {BackgroundColor3 = Theme.Surface3}):Play()
    end)
    click.MouseLeave:Connect(function()
        Tween(click, TweenInfo.new(0.12), {BackgroundColor3 = Theme.Surface2}):Play()
    end)
    click.MouseButton1Click:Connect(function()
        setState(not state, true)
    end)

    setState(state, false)

    return {
        Get = function() return state end,
        Set = function(value) setState(value, true) end,
        SetValue = function(_, value) setState(value, true) end,
        GetValue = function() return state end,
        Button = click,
    }
end

function GroupMethods:AddSlider(id, text, min, max, default, callback, step)
    min = tonumber(min) or 0
    max = tonumber(max) or 100
    if max < min then min, max = max, min end
    step = tonumber(step)
    if step and step <= 0 then step = nil end
    local initial = math.clamp(tonumber(default) or min, min, max)
    if step then
        initial = min + math.floor(((initial - min) / step) + 0.5) * step
        initial = math.clamp(initial, min, max)
    end
    local state = initial

    local row = makeRow(self.content, 50)

    New("TextLabel", {
        Size = UDim2.new(1, -78, 0, 21),
        BackgroundTransparency = 1,
        Text = prettyDisplayName(text),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Theme.Text,
    }, row)

    local valuePill = New("Frame", {
        Size = UDim2.fromOffset(62, 20),
        Position = UDim2.new(1, -62, 0, 0),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
    }, row)
    Corner(valuePill, 7)
    Stroke(valuePill, Theme.Border, 1)

    local valueLabel = New("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = tostring(state),
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextColor3 = Theme.Accent2,
    }, valuePill)

    local bar = New("Frame", {
        Size = UDim2.new(1, 0, 0, 6),
        Position = UDim2.fromOffset(0, 36),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        ZIndex = 20,
        Active = true,
    }, row)
    Corner(bar, 3)

    local fill = New("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.Slider,
        BorderSizePixel = 0,
    }, bar)
    Corner(fill, 3)

    local marker = New("Frame", {
        Size = UDim2.fromOffset(10, 10),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Theme.Text,
        BorderSizePixel = 0,
        ZIndex = 21,
    }, bar)
    Corner(marker, 5)

    local dragging = false
    local function setValue(v, fire)
        v = tonumber(v) or min
        state = math.clamp(v, min, max)
        if step then
            state = min + math.floor(((state - min) / step) + 0.5) * step
            state = math.clamp(state, min, max)
        end
        local alpha = (state - min) / math.max(max - min, 0.0001)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        marker.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = string.format("%.2f", state):gsub("%.00$", "")
        if fire and typeof(callback) == "function" then
            local ok, err = pcall(callback, state)
            if not ok then warn("[Mawww Hub] Slider error:", id, err) end
        end
    end

    local function updateFromMouse(x)
        local alpha = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        setValue(min + (max - min) * alpha, true)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromMouse(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromMouse(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    setValue(state, false)
    return {
        Get = function() return state end,
        Set = function(value) setValue(tonumber(value) or min, true) end,
        SetValue = function(_, value) setValue(tonumber(value) or min, true) end,
        GetValue = function() return state end,
    }
end

TabMethods = {}
TabMethods.__index = TabMethods

GROUPBOX_SEQUENCE = 0

function TabMethods:AddGroupbox(side, title)
    GROUPBOX_SEQUENCE = GROUPBOX_SEQUENCE + 1
    side = string.lower(side or "left")
    local holder = self.left
    if side == "right" then holder = self.right end

    local box = New("Frame", {
        Name = ((title ~= nil and title ~= "") and title or "Group") .. "Groupbox",
        Size = UDim2.new(1, 0, 0, 30),
        AutomaticSize = Enum.AutomaticSize.None,
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        ZIndex = 4,
        -- Prevent normal controls from overflowing into the next GroupBox.
        -- Popups temporarily disable this while open.
        ClipsDescendants = true,
        LayoutOrder = GROUPBOX_SEQUENCE,
    }, holder)
    Corner(box, 10)
    Stroke(box, Theme.Border, 1)

    local titleBar = New("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
    }, box)

    local titleLabel = New("TextLabel", {
        Position = UDim2.fromOffset(9, 0),
        Size = UDim2.new(1, -18, 1, 0),
        BackgroundTransparency = 1,
        Text = prettyDisplayName(title or ""),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Theme.Text,
    }, titleBar)

    New("Frame", {
        Name = "TitleAccent",
        Size = UDim2.fromOffset(3, 14),
        Position = UDim2.fromOffset(3, 8),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
    }, titleBar)

    local content = New("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -14, 0, 0),
        Position = UDim2.fromOffset(7, 32),
        AutomaticSize = Enum.AutomaticSize.None,
        BackgroundTransparency = 1,
        ClipsDescendants = false,
    }, box)

    local contentLayout = New("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, content)

    New("UIPadding", {
        PaddingBottom = UDim.new(0, 7),
    }, content)

    local refreshQueued = false
    local function refreshBox()
        if refreshQueued then return end
        refreshQueued = true
        task.defer(function()
            refreshQueued = false
            if not box.Parent then return end
            -- Safety gutter keeps the final row (e.g. Silent Aim Key) fully inside
            -- the GroupBox even if Roblox settles layout one frame later.
            local h = math.max(0, contentLayout.AbsoluteContentSize.Y) + 18
            content.Size = UDim2.new(1, -14, 0, h)
            box.Size = UDim2.new(1, 0, 0, 32 + h)
        end)
    end

    contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshBox)
    content.ChildAdded:Connect(function(child)
        if child:IsA("GuiObject") then
            child:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshBox)
            child:GetPropertyChangedSignal("Visible"):Connect(refreshBox)
        end
        refreshBox()
    end)
    content.ChildRemoved:Connect(refreshBox)
    refreshBox()

    return setmetatable({
        tab = self,
        frame = box,
        content = content,
        title = title,
        _layout = contentLayout,
        _refresh = refreshBox,
    }, GroupMethods)
end

function TabMethods:AddDefaultColumns(leftTitle, rightTitle)
    local left = self:AddGroupbox("left", leftTitle or "Main")
    local right = self:AddGroupbox("right", rightTitle or "Utility")
    return left, right
end

function CreatePage(name)
    local page = New("ScrollingFrame", {
        Name = name .. "Page",
        Size = UDim2.new(1, 0, 1, -38),
        Position = UDim2.fromOffset(0, 38),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Active = true,
        ClipsDescendants = true,
        Visible = false,
        ScrollingEnabled = true,
        ZIndex = 3,
    }, PageHolder)

    New("UIPadding", {
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 18),
        PaddingLeft = UDim.new(0, 2),
        PaddingRight = UDim.new(0, 10),
    }, page)

    local columns = New("Frame", {
        Name = "Columns",
        Size = UDim2.new(1, -8, 0, 1),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ClipsDescendants = false,
    }, page)

    local left = New("Frame", {
        Name = "LeftColumn",
        Size = UDim2.new(0.5, -4, 0, 1),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ClipsDescendants = false,
    }, columns)

    local right = New("Frame", {
        Name = "RightColumn",
        Size = UDim2.new(0.5, -4, 0, 1),
        Position = UDim2.new(0.5, 4, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ClipsDescendants = false,
    }, columns)

    -- Real bottom spacer: makes the last GroupBox reachable on every tab even
    -- when Roblox settles nested AutomaticSize one render frame later.
    local leftBottomSpacer = New("Frame", {
        Name = "BottomSpacer",
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1000000,
        Active = false,
    }, left)
    local rightBottomSpacer = New("Frame", {
        Name = "BottomSpacer",
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 1000000,
        Active = false,
    }, right)

    local leftLayout = New("UIListLayout", {
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, left)
    local rightLayout = New("UIListLayout", {
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, right)

    local data = {frame=page, columns=columns, left=left, right=right, _lastCanvasHeight=-1}
    local isHomePage = (name == "Home")
    local refreshing = false

    local function measureColumn(column)
        local layout = column == left and leftLayout or rightLayout
        local measured = tonumber(layout.AbsoluteContentSize.Y) or 0
        local maxBottom = 0
        local baseY = column.AbsolutePosition.Y
        for _, child in ipairs(column:GetChildren()) do
            if child:IsA("GuiObject") and child.Visible then
                local bottom = (child.AbsolutePosition.Y - baseY) + child.AbsoluteSize.Y
                if bottom > maxBottom then maxBottom = bottom end
            end
        end
        return math.max(measured, maxBottom, 0)
    end

    local function refreshCanvas()
        if refreshing then return end
        refreshing = true
        task.defer(function()
            refreshing = false
            if not page.Parent or not page.Visible then return end

            local leftHeight = measureColumn(left)
            local rightHeight = right.Visible and measureColumn(right) or 0
            local contentHeight = math.max(leftHeight, rightHeight, 1)

            -- AutomaticSize owns the real column height. Keep a manual CanvasSize
            -- fallback as well; this covers clients/executors that do not immediately
            -- propagate nested AutomaticSize changes through a ScrollingFrame.
            -- Home is intentionally a single full-width column. Do not let the
            -- generic 50/50 refresh below overwrite that layout.
            if isHomePage then
                pcall(function()
                    left.Size = UDim2.new(1, 0, 0, math.max(leftHeight, left.AbsoluteSize.Y))
                    left.Position = UDim2.fromOffset(0, 0)
                    right.Visible = false
                    right.Size = UDim2.new(0, 0, 0, 0)
                    columns.Size = UDim2.new(1, -8, 0, math.max(leftHeight, columns.AbsoluteSize.Y))
                    columns.Position = UDim2.fromOffset(0, 0)
                end)
            else
                pcall(function() left.Size = UDim2.new(0.5, -4, 0, math.max(leftHeight, left.AbsoluteSize.Y)) end)
                pcall(function() right.Size = UDim2.new(0.5, -4, 0, math.max(rightHeight, right.AbsoluteSize.Y)) end)
                pcall(function() columns.Size = UDim2.new(1, -8, 0, math.max(contentHeight, columns.AbsoluteSize.Y)) end)
            end

            local viewportH = math.max(1, page.AbsoluteWindowSize.Y)
            local automaticCanvas = page.AbsoluteCanvasSize.Y
            local fallbackCanvas = contentHeight + 48
            local canvasHeight = math.max(automaticCanvas, fallbackCanvas, viewportH + 1)
            if math.abs(canvasHeight - (data._lastCanvasHeight or -1)) > 0.5 then
                data._lastCanvasHeight = canvasHeight
                pcall(function() page.CanvasSize = UDim2.new(0, 0, 0, canvasHeight) end)
            end

            local maxScroll = math.max(0, canvasHeight - viewportH)
            local currentY = page.CanvasPosition.Y
            if currentY > maxScroll then
                page.CanvasPosition = Vector2.new(page.CanvasPosition.X, maxScroll)
            end
        end)
    end

    local function hookColumn(column)
        column:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshCanvas)
        column.ChildAdded:Connect(function(child)
            if child:IsA("GuiObject") then
                child:GetPropertyChangedSignal("AbsoluteSize"):Connect(refreshCanvas)
                child:GetPropertyChangedSignal("Visible"):Connect(refreshCanvas)
                child:GetPropertyChangedSignal("LayoutOrder"):Connect(refreshCanvas)
            end
            refreshCanvas()
        end)
        column.ChildRemoved:Connect(refreshCanvas)
    end

    hookColumn(left)
    hookColumn(right)
    leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshCanvas)
    rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshCanvas)
    page:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(refreshCanvas)
    page:GetPropertyChangedSignal("Visible"):Connect(function()
        if page.Visible then
            task.defer(refreshCanvas)
        end
    end)
    task.defer(refreshCanvas)

    function data:RefreshLayout()
        refreshCanvas()
    end
    return data
end

VDUI = {}
VDUI.Tabs = {}
tabCount = 0

function VDUI:AddTab(name, icon)
    assert(type(name) == "string" and name ~= "", "VDUI:AddTab requires a tab name")
    if self.Tabs[name] then
        return self.Tabs[name]
    end

    local pageData = CreatePage(name)
    if name == "Home" then
        pageData.left.Size = UDim2.new(1, 0, 0, 0)
        pageData.left.Position = UDim2.fromOffset(0, 0)
        pageData.right.Visible = false
    end
    tabCount = tabCount + 1
    local button, indicator, label, tabIcon = CreateTabButton(name, tabCount)

    -- Tab icons are intentionally default/glyph-based and matched to each tab name.
    -- The former Home photo is displayed globally in the top header on every tab.
    if tabIcon:IsA("TextLabel") then
        tabIcon:SetAttribute("IconAssetId", tostring(icon or (name == "Home" and HOME_ICON_ID or "")))
    end

    local tab = setmetatable({
        name = name,
        icon = icon,
        frame = pageData.frame,
        left = pageData.left,
        right = pageData.right,
        button = button,
        indicator = indicator,
        label = label,
        iconObject = tabIcon,
    }, TabMethods)

    self.Tabs[name] = tab
    pages[name] = pageData

    button.MouseButton1Click:Connect(function()
        self:SelectTab(name)
    end)

    if not currentPage then
        self:SelectTab(name)
    end

    return tab
end

function VDUI:SelectTab(name)
    local tab = self.Tabs[name]
    if not tab then return end

    -- Never leave a popup from the previous tab floating over the new page.
    pcall(closeActivePopup)

    if currentPage then
        currentPage.Visible = false
    end
    if currentTabButton then
        currentTabButton.BackgroundColor3 = Theme.Surface
        local oldIndicator = currentTabButton:FindFirstChild("Indicator")
        if oldIndicator then oldIndicator.Visible = false end
        local oldSelection = currentTabButton:FindFirstChild("SelectionGlow")
        if oldSelection then oldSelection.Visible = false end
        local oldLabel = currentTabButton:FindFirstChild("TabLabel")
        if oldLabel then oldLabel.TextColor3 = Theme.SubText end
        local oldIcon = currentTabButton:FindFirstChild("TabIcon")
        if oldIcon then oldIcon.TextColor3 = Theme.SubText end
        local oldChevron = currentTabButton:FindFirstChild("TabChevron")
        if oldChevron then oldChevron.TextColor3 = Theme.SubText end
    end

    tab.frame.Visible = true
    pcall(function()
        if name ~= "Home" then
            tab.right.Visible = true
        end
    end)
    tab.button.BackgroundColor3 = Theme.Surface2
    tab.indicator.Visible = true
    local selection = tab.button:FindFirstChild("SelectionGlow")
    if selection then selection.Visible = true end
    tab.label.TextColor3 = Theme.Text
    if tab.iconObject then tab.iconObject.TextColor3 = Theme.Text end
    local chevron = tab.button:FindFirstChild("TabChevron")
    if chevron then chevron.TextColor3 = Theme.Accent end

    currentPage = tab.frame
    currentTabButton = tab.button

    -- Every tab starts at the top; do not reset CanvasSize here because
    -- AutomaticCanvasSize is responsible for measuring the page contents.
    pcall(function() tab.frame.CanvasPosition = Vector2.new(0, 0) end)
    pcall(function()
        local pageObject = pages[name]
        if pageObject and pageObject.RefreshLayout then pageObject:RefreshLayout() end
    end)
    task.defer(function()
        pcall(function()
            local pageObject = pages[name]
            if pageObject and pageObject.RefreshLayout then pageObject:RefreshLayout() end
        end)
    end)
end

function VDUI:Notify(title, message, duration)
    duration = tonumber(duration) or 3
    -- Never show feature/toast notifications while the key gate is on screen.
    if rawget(_G, "SUPPRESS_NOTIFY") == true then return end
    if rawget(_G, "KeyGate") and KeyGate.Visible then return end

    local holder = ScreenGui:FindFirstChild("Notifications")
    if not holder then
        holder = New("Frame", {
            Name = "Notifications",
            Size = UDim2.fromOffset(320, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Position = UDim2.new(1, -340, 1, -16),
            AnchorPoint = Vector2.new(0, 1),
            BackgroundTransparency = 1,
        }, ScreenGui)
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, holder)
    end

    local card = New("Frame", {
        Size = UDim2.fromOffset(310, 68),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
    }, holder)
    Corner(card, 10)
    Stroke(card, Theme.Border, 1)

    local bar = New("Frame", {
        Size = UDim2.fromOffset(3, 48),
        Position = UDim2.fromOffset(8, 10),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
    }, card)
    Corner(bar, 2)

    New("TextLabel", {
        Size = UDim2.new(1, -30, 0, 23),
        Position = UDim2.fromOffset(20, 9),
        BackgroundTransparency = 1,
        Text = tostring(title or "VD"),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Theme.Text,
    }, card)

    New("TextLabel", {
        Size = UDim2.new(1, -30, 0, 29),
        Position = UDim2.fromOffset(20, 31),
        BackgroundTransparency = 1,
        Text = tostring(message or ""),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextColor3 = Theme.SubText,
    }, card)

    task.delay(duration, function()
        if card and card.Parent then
            local tween = Tween(card, TweenInfo.new(0.2), {BackgroundTransparency = 1})
            tween:Play()
            tween.Completed:Wait()
            if card then card:Destroy() end
        end
    end)
end

--// Background helpers
function VDUI:SetBackgroundAsset(assetId)
    local id = tostring(assetId or "")
    if id == "" then
        BackgroundImage.Image = ""
        return false
    end
    if not id:match("rbxassetid://") then
        id = "rbxassetid://" .. id
    end
    BackgroundImage.Image = id
    return true
end

function VDUI:SetBackgroundVideo(assetId)
    local id = tostring(assetId or "")
    if id == "" then
        BackgroundVideo.Visible = false
        BackgroundVideo.Playing = false
        BackgroundVideo.Video = ""
        return false
    end
    if not id:match("rbxassetid://") then
        id = "rbxassetid://" .. id
    end
    BackgroundVideo.Video = id
    BackgroundVideo.Visible = true
    BackgroundVideo.Playing = false
    local conn
    conn = BackgroundVideo.Loaded:Connect(function()
        if conn then conn:Disconnect() end
        pcall(function() BackgroundVideo:Play() end)
    end)
    return true
end

function VDUI:GetBackgroundSource()
    return BACKGROUND_ASSET_ID
end

--// Dragging (main UI + floating icon)
function makeDraggable(handle, target, onClick)
    local dragging = false
    local dragMoved = false
    local dragStart
    local startPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragMoved = false
            dragStart = input.Position
            startPos = target.Position
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            -- Keep touch/mouse movement tracking on UserInputService below.
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        if math.abs(delta.X) > 3 or math.abs(delta.Y) > 3 then
            dragMoved = true
        end
        target.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        if dragging and not dragMoved and typeof(onClick) == "function" then
            onClick()
        end
        dragging = false
    end)
end

-- Drag from empty/header areas. Controls keep their normal click actions.
makeDraggable(Header, Main)
makeDraggable(Logo, Main)

--// Minimize / restore
minimized = false
fullSize = Main.Size
compactSize = UDim2.fromOffset(680, 44)
previousSize = fullSize

local function applyMinimizedState(nextState, keepVisible)
    minimized = nextState == true
    if minimized then
        pcall(closeActivePopup)
        if not keepVisible then
            previousSize = Main.Size
        end
        MinimizeButton.Text = "+"
        Main.Size = compactSize
        Sidebar.Visible = false
        PageHolder.Visible = false
    else
        MinimizeButton.Text = "−"
        Main.Size = previousSize or fullSize
        Sidebar.Visible = true
        PageHolder.Visible = true
    end
end

MinimizeButton.MouseButton1Click:Connect(function()
    applyMinimizedState(not minimized, false)
end)

OpenButton = New("ImageButton", {
    Name = "FloatingOpen",
    Size = UDim2.fromOffset(40, 40),
    Position = UDim2.new(0, 14, 1, -58),
    BackgroundColor3 = Theme.Surface2,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Image = ICON_ID,
    ImageColor3 = Theme.Text,
    Visible = false,
}, ScreenGui)
Corner(OpenButton, 12)
Stroke(OpenButton, Theme.Accent, 1.2)

CloseButton.InputBegan:Connect(function() end)

CloseButton.MouseButton1Click:Connect(function()
    pcall(closeActivePopup)
    MAWWW_UI_WANTED_VISIBLE = false
    Main.Visible = false
    OpenButton.Visible = true
end)

-- Floating icon can be moved anywhere and still opens on a simple tap/click.
makeDraggable(OpenButton, OpenButton, function()
    MAWWW_UI_WANTED_VISIBLE = true
    Main.Visible = true
    OpenButton.Visible = false
    if minimized then
        applyMinimizedState(false, true)
    end
end)

--// ===== Key System • Jnkie Premium =====
-- Jnkie is used to validate Mawww keys. Only PREMIUM keys unlock this hub.
-- Do NOT put a Jnkie API secret/token in this client-side script.
HttpService = game:GetService("HttpService")

JUNKIE_SDK_URL = "https://jnkie.com/sdk/library.lua"
JUNKIE_KEY_URL = "https://jnkie.com/get-key/mawww"

function trimString(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

-- Jnkie configuration.
-- Service and Identifier are required by the Jnkie SDK. Provider is your
-- provider name shown in the Jnkie dashboard (Mawww in your screenshot).
-- You may set these before running the hub: 
-- getgenv().JUNKIE_SERVICE = "YOUR_SERVICE"
-- getgenv().JUNKIE_IDENTIFIER = "YOUR_JNKIE_USER_ID"
-- getgenv().JUNKIE_PROVIDER = "Mawww"
local __JunkieEnv = (type(getgenv) == "function" and getgenv()) or _G
JUNKIE_SERVICE = trimString((__JunkieEnv and __JunkieEnv.JUNKIE_SERVICE) or "Mawww")
JUNKIE_IDENTIFIER = trimString((__JunkieEnv and __JunkieEnv.JUNKIE_IDENTIFIER) or "1210892")
JUNKIE_PROVIDER = trimString((__JunkieEnv and __JunkieEnv.JUNKIE_PROVIDER) or "Mawww")

KEY_PAGE_URL = JUNKIE_KEY_URL
KEY_STORAGE_PATH = "MawwwHub/activated_key.txt"
KEY_STORAGE_LEGACY_PATH = "MawwwHub_activated_key.txt"

JUNKIE = nil
JUNKIE_LOAD_ERROR = nil

function ensureKeyFolder()
    local folder = "MawwwHub"
    pcall(function()
        if type(isfolder) == "function" then
            if not isfolder(folder) and type(makefolder) == "function" then
                makefolder(folder)
            end
        elseif type(makefolder) == "function" then
            makefolder(folder)
        end
    end)
end

function getSavedKey()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then
        return ""
    end
    for _, path in ipairs({KEY_STORAGE_PATH, KEY_STORAGE_LEGACY_PATH}) do
        local ok, value = pcall(function()
            if isfile(path) then
                return trimString(readfile(path))
            end
            return ""
        end)
        if ok and value ~= "" then
            return value
        end
    end
    return ""
end

function saveKey(value)
    if type(writefile) ~= "function" then
        return false
    end
    value = trimString(value)
    if value == "" then
        return false
    end
    ensureKeyFolder()
    local ok = pcall(function()
        writefile(KEY_STORAGE_PATH, value)
    end)
    if ok then
        pcall(function()
            writefile(KEY_STORAGE_LEGACY_PATH, value)
        end)
    end
    return ok
end

function clearSavedKey()
    if type(delfile) ~= "function" or type(isfile) ~= "function" then
        return
    end
    for _, path in ipairs({KEY_STORAGE_PATH, KEY_STORAGE_LEGACY_PATH}) do
        pcall(function()
            if isfile(path) then
                delfile(path)
            end
        end)
    end
end

function openExternal(url)
    url = trimString(url)
    if url == "" then
        return
    end
    if type(setclipboard) == "function" then
        pcall(function()
            setclipboard(url)
        end)
    elseif type(toclipboard) == "function" then
        pcall(function()
            toclipboard(url)
        end)
    end
end

function loadJunkie()
    if JUNKIE then
        return true, JUNKIE
    end
    if JUNKIE_LOAD_ERROR then
        return false, JUNKIE_LOAD_ERROR
    end

    if JUNKIE_SERVICE == "" or JUNKIE_IDENTIFIER == "" or JUNKIE_PROVIDER == "" then
        JUNKIE_LOAD_ERROR = "Jnkie configuration missing: set JUNKIE_IDENTIFIER to the user ID shown in your Jnkie dashboard."
        return false, JUNKIE_LOAD_ERROR
    end

    local loader = loadstring or load
    if type(loader) ~= "function" then
        JUNKIE_LOAD_ERROR = "This executor does not support loadstring/load."
        return false, JUNKIE_LOAD_ERROR
    end

    local ok, lib = pcall(function()
        local source = game:HttpGet(JUNKIE_SDK_URL)
        return loader(source)()
    end)
    if not ok or type(lib) ~= "table" then
        JUNKIE_LOAD_ERROR = tostring(lib or "Unable to load Jnkie SDK.")
        return false, JUNKIE_LOAD_ERROR
    end

    local configured = pcall(function()
        lib.service = JUNKIE_SERVICE
        lib.identifier = JUNKIE_IDENTIFIER
        lib.provider = JUNKIE_PROVIDER
    end)
    if not configured then
        JUNKIE_LOAD_ERROR = "Unable to configure Jnkie SDK."
        return false, JUNKIE_LOAD_ERROR
    end

    if type(lib.check_key) ~= "function" then
        JUNKIE_LOAD_ERROR = "Jnkie SDK check_key() was not found."
        return false, JUNKIE_LOAD_ERROR
    end

    JUNKIE = lib
    return true, JUNKIE
end

function getJunkiePremiumState(result)
    local env = (type(getgenv) == "function" and getgenv()) or _G

    -- Prefer explicit premium flags when the SDK exposes them.
    if type(result) == "table" then
        if result.premium == true or result.is_premium == true or result.premium_key == true then
            return true
        end
        if result.premium == false or result.is_premium == false or result.premium_key == false then
            return false
        end
    end

    -- Jnkie documents JD_IS_PREMIUM as a runtime value after successful validation.
    if env then
        if env.JD_IS_PREMIUM == true then return true end
        if tostring(env.JD_IS_PREMIUM):lower() == "true" then return true end
        if env.JD_IS_PREMIUM == false then return false end
        if tostring(env.JD_IS_PREMIUM):lower() == "false" then return false end
    end

    return nil
end

function verifyJunkiePremiumKey(key)
    key = trimString(key)
    if key == "" then
        return false, "KEY NOT ACTIVATED", "enter your key."
    end

    local loaded, junkieOrError = loadJunkie()
    if not loaded then
        return false, "KEY SYSTEM ERROR", tostring(junkieOrError)
    end

    -- Clear a stale premium flag before validation so an earlier key cannot unlock
    -- the hub after a later non-premium/invalid key attempt.
    local env = (type(getgenv) == "function" and getgenv()) or _G
    pcall(function()
        if env then
            env.JD_IS_PREMIUM = nil
        end
    end)

    local ok, result = pcall(function()
        return junkieOrError.check_key(key)
    end)

    if not ok or type(result) ~= "table" then
        return false, "KEY NOT ACTIVATED", "Junkie validation failed."
    end

    local isValid = (result.valid == true) or (result.success == true)
    if not isValid then
        local reason = trimString(result.error or result.message or "Invalid key.")
        if string.upper(reason) == "PREMIUM_REQUIRED" then
            return false, "PREMIUM KEY REQUIRED", "This service requires a Premium key."
        end
        return false, "KEY NOT ACTIVATED", reason
    end

    local premium = getJunkiePremiumState(result)
    if premium == false then
        return false, "PREMIUM KEY REQUIRED", "This key is valid, but it is not a Premium key."
    end

    -- When the SDK/backend accepts the key and does not expose a separate
    -- premium flag, trust the successful validation response instead of
    -- falsely rejecting a valid Premium key.
    return true, "KEY ACTIVATED", premium == true and "Premium key verified." or "Key verified by Jnkie."
end

KeyGate = New("Frame", {
    Name = "KeySystem",
    Size = UDim2.fromOffset(390, 250),
    Position = UDim2.new(0.5, -195, 0.5, -125),
    BackgroundColor3 = Theme.Background,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 50,
}, ScreenGui)
Corner(KeyGate, 14)
Stroke(KeyGate, Theme.Border, 1)

pcall(function()
    local existing = ScreenGui:FindFirstChild("Notifications")
    if existing then existing:Destroy() end
end)

KeyBackground = New("ImageLabel", {
    Name = "Background",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Image = "rbxassetid://97815205163579",
    ImageTransparency = 0.02,
    ScaleType = Enum.ScaleType.Crop,
    ZIndex = 50,
}, KeyGate)
Corner(KeyBackground, 14)

New("Frame", {
    Name = "Tint",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(5, 6, 15),
    BackgroundTransparency = 0.36,
    BorderSizePixel = 0,
    ZIndex = 51,
}, KeyGate)

New("TextLabel", {
    Name = "Title",
    Position = UDim2.fromOffset(20, 18),
    Size = UDim2.new(1, -40, 0, 26),
    BackgroundTransparency = 1,
    Text = "MAWWW HUB • JNKIE PREMIUM KEY SYSTEM",
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextColor3 = Theme.Text,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 52,
}, KeyGate)

KeyStatus = New("TextLabel", {
    Name = "KeyStatus",
    Position = UDim2.fromOffset(20, 46),
    Size = UDim2.new(1, -40, 0, 20),
    BackgroundTransparency = 1,
    Text = "KEY NOT ACTIVATED",
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextColor3 = Theme.Red,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 52,
}, KeyGate)

KeyLoading = New("TextLabel", {
    Name = "Loading",
    Position = UDim2.fromOffset(20, 69),
    Size = UDim2.new(1, -40, 0, 18),
    BackgroundTransparency = 1,
    Text = "Loading Jnkie key system...",
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextColor3 = Theme.SubText,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 52,
}, KeyGate)

KeyInput = New("TextBox", {
    Name = "KeyInput",
    Size = UDim2.new(1, -40, 0, 38),
    Position = UDim2.fromOffset(20, 94),
    BackgroundColor3 = Theme.Surface2,
    BackgroundTransparency = 0.05,
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    PlaceholderText = "enter your key.",
    PlaceholderColor3 = Theme.SubText,
    Text = "",
    TextColor3 = Theme.Text,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 52,
}, KeyGate)
Corner(KeyInput, 9)
Stroke(KeyInput, Theme.Border, 1)
New("UIPadding", {PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 11)}, KeyInput)

GetKeyButton = New("TextButton", {
    Name = "GetKey",
    Size = UDim2.new(0.5, -25, 0, 38),
    Position = UDim2.new(0, 20, 0, 145),
    BackgroundColor3 = Theme.Surface3,
    BorderSizePixel = 0,
    Text = "GET KEY",
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextColor3 = Theme.Text,
    AutoButtonColor = false,
    ZIndex = 52,
}, KeyGate)
Corner(GetKeyButton, 9)
Stroke(GetKeyButton, Theme.Accent, 1)

VerifyKeyButton = New("TextButton", {
    Name = "VerifyKey",
    Size = UDim2.new(0.5, -25, 0, 38),
    Position = UDim2.new(0.5, 5, 0, 145),
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0,
    Text = "VERIFY KEY",
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextColor3 = Color3.new(1, 1, 1),
    AutoButtonColor = false,
    ZIndex = 52,
}, KeyGate)
Corner(VerifyKeyButton, 9)
Stroke(VerifyKeyButton, Theme.Accent, 1)

LoadingBar = New("Frame", {
    Name = "LoadingBar",
    Size = UDim2.new(1, -40, 0, 4),
    Position = UDim2.fromOffset(20, 191),
    BackgroundColor3 = Theme.Surface3,
    BorderSizePixel = 0,
    ZIndex = 52,
}, KeyGate)
Corner(LoadingBar, 3)

LoadingFill = New("Frame", {
    Name = "Fill",
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0,
    ZIndex = 53,
}, LoadingBar)
Corner(LoadingFill, 3)

KeyHint = New("TextLabel", {
    Name = "Hint",
    Position = UDim2.fromOffset(20, 205),
    Size = UDim2.new(1, -40, 0, 26),
    BackgroundTransparency = 1,
    Text = "get your key from jnkie.",
    Font = Enum.Font.Gotham,
    TextSize = 9,
    TextColor3 = Theme.SubText,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 52,
}, KeyGate)

function setKeyLoading(active, message)
    KeyLoading.Text = message or (active and "verifying key..." or "ready.")
    if active then
        KeyLoading.TextColor3 = Theme.Accent
        Tween(LoadingFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0.72, 0, 1, 0)
        }):Play()
    else
        KeyLoading.TextColor3 = Theme.SubText
        Tween(LoadingFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 1, 0)
        }):Play()
    end
end

function showKeyState(activated, statusText, detail)
    KeyStatus.Text = statusText or (activated and "KEY ACTIVATED" or "KEY NOT ACTIVATED")
    KeyStatus.TextColor3 = activated and Theme.Green or Theme.Red
    KeyLoading.Text = detail or (activated and "Premium key verified. Loading Mawww Hub..." or "Key not activated.")
end

function activateHub(key)
    SUPPRESS_NOTIFY = false
    saveKey(key)
    showKeyState(true, "KEY ACTIVATED", "Premium key verified. Loading Mawww Hub...")
    setKeyLoading(false, "Premium key verified. Loading Mawww Hub...")
    task.wait(0.65)
    MAWWW_UI_UNLOCKED = true
    MAWWW_UI_WANTED_VISIBLE = true
    KeyGate.Visible = false
    Main.Visible = true
    OpenButton.Visible = false
    task.wait(0.15)
end

function attemptVerify(inputKey, autoCheck)
    inputKey = trimString(inputKey)
    if inputKey == "" then
        showKeyState(false, "KEY NOT ACTIVATED", "enter your key.")
        setKeyLoading(false, "Key not activated.")
        return false
    end

    setKeyLoading(true, autoCheck and "checking save mawww Key System." or "verifying premium key...")
    local valid, status, detail = verifyJunkiePremiumKey(inputKey)
    if valid then
        activateHub(inputKey)
        return true
    end

    local detailUpper = string.upper(tostring(detail or ""))
    if status == "KEY NOT ACTIVATED" and (string.find(detailUpper, "KEY_INVALID", 1, true) or string.find(detailUpper, "KEY_EXPIRED", 1, true) or string.find(detailUpper, "KEY_INVALIDATED", 1, true) or string.find(detailUpper, "KEY_NOT_FOUND", 1, true) or string.find(detailUpper, "HWID_", 1, true) or string.find(detailUpper, "SERVICE_MISMATCH", 1, true)) then
        clearSavedKey()
    end
    KeyInput.Text = autoCheck and "" or inputKey
    showKeyState(false, status, detail)
    setKeyLoading(false, detail)
    return false
end

GetKeyButton.MouseButton1Click:Connect(function()
    openExternal(KEY_PAGE_URL)
    KeyHint.Text = "Jnkie key link copied to clipboard."
end)

VerifyKeyButton.MouseButton1Click:Connect(function()
    attemptVerify(KeyInput.Text, false)
end)

KeyInput.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        attemptVerify(KeyInput.Text, false)
    end
end)

MAWWW_UI_UNLOCKED = false
MAWWW_UI_WANTED_VISIBLE = false
KeyGate.Visible = true
Main.Visible = false
OpenButton.Visible = false
showKeyState(false, "KEY NOT ACTIVATED", "loading mawww Key System...")
setKeyLoading(true, "loading mawww Key System...")

task.spawn(function()
    task.wait(0.35)
    local saved = getSavedKey()
    if saved ~= "" then
        KeyInput.Text = saved
        attemptVerify(saved, true)
    else
        showKeyState(false, "KEY NOT ACTIVATED", "no activated key found.")
        setKeyLoading(false, "Key not activated.")
    end
end)

--========================================================--
-- MAWWW HUB • V3/V4 LOGIC ADAPTER ON CURRENT UI
-- Home + Settings/Interface stay from the current UI.
-- All feature logic/registrations come from the V3/V4 source.
--========================================================--

-- Safe executor fallback for environments without getgenv().
if type(getgenv) ~= "function" then
    getgenv = function() return _G end
end

-- V3 logic expects a Library notification surface. Route it to the current UI.
Library = {
    _configFlags = {},
    Scheme = {},
    ShowCustomCursor = false,
}
function Library:Notify(payload)
    payload = payload or {}
    local title = payload.Title or payload.title or "Mawww Hub"
    local message = payload.Description or payload.Content or payload.message or ""
    local duration = tonumber(payload.Time or payload.Duration) or 4
    pcall(function() VDUI:Notify(title, message, duration) end)
end
function Library:Unload()
    pcall(function()
        Main.Visible = false
        OpenButton.Visible = true
    end)
end
function Library:Toggle()
    local visible = false
    pcall(function() visible = Main.Visible end)
    getgenv().MAWWW_SetUIVisible(not visible)
end
function Library:MakeDraggable(handle, target)
    if handle and target then
        pcall(function() makeDraggable(handle, target) end)
    else
        pcall(function() makeDraggable(Header, Main) end)
    end
end
function Library:RefreshCursor() end
function Library:SetNotifySide(side)
    local holder = ScreenGui:FindFirstChild("Notifications")
    if not holder then return end
    side = tostring(side or "right"):lower()
    if side == "left" then
        holder.Position = UDim2.new(0, 16, 1, -16)
        holder.AnchorPoint = Vector2.new(0, 1)
    else
        holder.Position = UDim2.new(1, -16, 1, -16)
        holder.AnchorPoint = Vector2.new(1, 1)
    end
end

-- Keep feature runtime visibility under the key gate until the key is valid.
getgenv().MAWWW_SetUIVisible = function(visible)
    visible = visible == true
    MAWWW_UI_WANTED_VISIBLE = visible
    if KeyGate and KeyGate.Visible then
        Main.Visible = false
        OpenButton.Visible = false
        return
    end
    Main.Visible = visible
    OpenButton.Visible = not visible
    if visible and minimized then
        applyMinimizedState(true, true)
    end
end
getgenv().MAWWW_MawwwHub_Library = Library

-- Extend the current lightweight controls with the methods required by V3/V4.
function _safeText(v)
    return tostring(v == nil and "" or v)
end

function GroupMethods:AddInput(id, text, default, callback)
    local row = makeRow(self.content, 44)
    local label = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 17),
        BackgroundTransparency = 1,
        Text = prettyDisplayName(text),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local box = New("TextBox", {
        Size = UDim2.new(1, 0, 0, 25),
        Position = UDim2.fromOffset(0, 18),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        PlaceholderText = "Enter value...",
        PlaceholderColor3 = Theme.SubText,
        Text = _safeText(default),
        TextColor3 = Theme.Text,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    Corner(box, 7)
    Stroke(box, Theme.Border, 1)
    New("UIPadding", {PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9)}, box)

    local state = _safeText(default)
    local function setValue(value, fire)
        state = _safeText(value)
        box.Text = state
        if fire and typeof(callback) == "function" then
            pcall(callback, state)
        end
    end
    box.FocusLost:Connect(function()
        setValue(box.Text, true)
    end)

    return {
        Get = function() return state end,
        Set = function(_, value) setValue(value, true) end,
        SetValue = function(_, value) setValue(value, true) end,
        GetValue = function() return state end,
        TextBox = box,
    }
end

function GroupMethods:AddDropdown(id, text, options, default, callback, multi)
    options = options or {}
    local multiMode = multi == true
    local selected
    if multiMode then
        selected = {}
        if type(default) == "table" then
            for _,v in ipairs(default) do selected[v] = true end
        elseif default ~= nil then
            selected[default] = true
        end
    else
        selected = default
        if selected == nil then selected = options[1] end
    end

    local row = makeRow(self.content, 36)
    local button = New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, row)
    Corner(button, 8)
    Stroke(button, Theme.Border, 1)

    New("TextLabel", {
        Size = UDim2.new(0.48, -8, 1, 0),
        Position = UDim2.fromOffset(9, 0),
        BackgroundTransparency = 1,
        Text = prettyDisplayName(text),
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Theme.Text,
    }, button)

    local valuePill = New("Frame", {
        Name = "ValuePill",
        Size = UDim2.new(0.52, -24, 0, 22),
        Position = UDim2.new(0.48, 3, 0.5, -11),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
    }, button)
    Corner(valuePill, 7)
    Stroke(valuePill, Theme.Border, 1)

    local valueLabel = New("TextLabel", {
        Size = UDim2.new(1, -10, 1, 0),
        Position = UDim2.fromOffset(5, 0),
        BackgroundTransparency = 1,
        Text = "",
        Font = Enum.Font.GothamMedium,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = Theme.Accent2,
    }, valuePill)

    New("TextLabel", {
        Name = "Chevron",
        Size = UDim2.fromOffset(14, 18),
        Position = UDim2.new(1, -20, 0.5, -9),
        BackgroundTransparency = 1,
        Text = "⌄",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Theme.SubText,
    }, button)

    local popup = New("Frame", {
        Visible = false,
        Size = UDim2.new(0, 0, 0, math.min(math.max(#options, 1) * 28 + 8, 190)),
        Position = UDim2.fromOffset(0, 0),
        AnchorPoint = Vector2.new(0, 0),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        ZIndex = 100,
        Active = true,
    }, PopupLayer)
    Corner(popup, 8)
    Stroke(popup, Theme.Border, 1)

    local list = New("ScrollingFrame", {
        Size = UDim2.new(1, -8, 1, -8),
        Position = UDim2.fromOffset(4, 4),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 101,
        Active = true,
    }, popup)
    New("UIListLayout", {Padding = UDim.new(0, 2)}, list)

    local optionButtons = {}

    local function displayValue()
        if multiMode then
            local vals = {}
            for _,opt in ipairs(options) do if selected[opt] then table.insert(vals, tostring(opt)) end end
            return #vals > 0 and table.concat(vals, ", ") or "None"
        end
        return tostring(selected == nil and "" or selected)
    end

    local function fire()
        if typeof(callback) ~= "function" then return end
        if multiMode then
            local vals = {}
            for _,opt in ipairs(options) do if selected[opt] then table.insert(vals, opt) end end
            pcall(callback, vals)
        else
            pcall(callback, selected)
        end
    end

    local function updateLabel()
        valueLabel.Text = displayValue()
    end

    local function rebuild(newOptions)
        options = type(newOptions) == "table" and newOptions or (options or {})
        for _,child in ipairs(list:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        optionButtons = {}
        if multiMode then
            local allowed = {}
            for _, option in ipairs(options) do allowed[option] = true end
            for key in pairs(selected) do
                if not allowed[key] then selected[key] = nil end
            end
        end
        for _, option in ipairs(options) do
            local opt = New("TextButton", {
                Size = UDim2.new(1, 0, 0, 26),
                BackgroundColor3 = Theme.Surface2,
                BorderSizePixel = 0,
                Text = prettyDisplayName(option),
                Font = Enum.Font.Gotham,
                TextSize = 10,
                TextColor3 = Theme.Text,
                AutoButtonColor = false,
                ZIndex = 102,
            }, list)
            Corner(opt, 6)
            optionButtons[option] = opt
            opt.MouseEnter:Connect(function() opt.BackgroundColor3 = Theme.Surface3 end)
            opt.MouseLeave:Connect(function() opt.BackgroundColor3 = Theme.Surface2 end)
            opt.MouseButton1Click:Connect(function()
                if multiMode then
                    selected[option] = not selected[option]
                else
                    selected = option
                    closePopup(self.frame, popup)
                end
                updateLabel()
                fire()
            end)
        end
        if not multiMode and selected ~= nil then
            local still = false
            for _,o in ipairs(options) do if o == selected then still = true break end end
            if not still then selected = options[1] end
        end
        updateLabel()
    end

    button.MouseButton1Click:Connect(function()
        if popup.Visible then
            closePopup(self.frame, popup)
        else
            openPopup(self.frame, popup, button)
        end
    end)
    rebuild(options)

    local obj = {
        Get = function()
            if multiMode then
                local vals = {}
                for _,opt in ipairs(options) do if selected[opt] then table.insert(vals,opt) end end
                return vals
            end
            return selected
        end,
        Set = function(_, value)
            if multiMode then
                selected = {}
                if type(value) == "table" then for _,v in ipairs(value) do selected[v] = true end else selected[value] = true end
            else
                selected = value
            end
            updateLabel()
            fire()
        end,
        SetValue = function(_, value)
            if multiMode then
                selected = {}
                if type(value) == "table" then for _,v in ipairs(value) do selected[v] = true end else if value ~= nil then selected[value] = true end end
            else selected = value end
            updateLabel()
            fire()
        end,
        GetValue = function()
            if multiMode then
                local vals = {}
                for _,opt in ipairs(options) do if selected[opt] then table.insert(vals,opt) end end
                return vals
            end
            return selected
        end,
        Refresh = function(_, values)
            rebuild(values or {})
        end,
        SetValues = function(_, values)
            rebuild(values or {})
        end,
        Button = button,
    }
    return obj
end

function GroupMethods:AddKeybind(id, title, default, callback, mode)
    local keyName = tostring(default or "Unknown")
    local keyCode
    pcall(function() keyCode = typeof(default) == "EnumItem" and default or Enum.KeyCode[keyName] end)
    local active = false
    local row = makeRow(self.content, 34)
    local button = New("TextButton", {
        Size = UDim2.fromScale(1,1),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextColor3 = Theme.Text,
        Text = "",
    }, row)
    local keyTitle = New("TextLabel", {
        Size = UDim2.new(1, -92, 1, 0),
        Position = UDim2.fromOffset(11, 0),
        BackgroundTransparency = 1,
        Text = prettyDisplayName(title),
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Theme.Text,
    }, button)
    local keyPill = New("TextLabel", {
        Size = UDim2.fromOffset(62, 22),
        Position = UDim2.new(1, -70, 0.5, -11),
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Text = "[ " .. keyName .. " ]",
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextColor3 = Theme.Accent2,
    }, button)
    Corner(keyPill, 7)
    Stroke(keyPill, Theme.Border, 1)
    Corner(button, 8); Stroke(button, Theme.Border, 1)

    local function fire(value)
        if typeof(callback) == "function" then pcall(callback, value) end
    end
    button.MouseButton1Click:Connect(function()
        active = not active
        fire(active)
    end)

    local inputConn, endedConn
    if keyCode then
        inputConn = UserInputService.InputBegan:Connect(function(input, processed)
            if processed or input.KeyCode ~= keyCode then return end
            if tostring(mode or "Toggle"):lower() == "hold" then active = true else active = not active end
            fire(active)
        end)
        if tostring(mode or "Toggle"):lower() == "hold" then
            endedConn = UserInputService.InputEnded:Connect(function(input)
                if input.KeyCode == keyCode then active = false; fire(false) end
            end)
        end
    end
    local obj = {
        Get = function() return active end,
        Set = function(_, value) active = value == true; fire(active) end,
        SetValue = function(_, value) active = value == true; fire(active) end,
        GetValue = function() return active end,
        Button = button,
        KeyCode = keyCode,
        Destroy = function()
            pcall(function() if inputConn then inputConn:Disconnect() end end)
            pcall(function() if endedConn then endedConn:Disconnect() end end)
            pcall(function() row:Destroy() end)
        end,
    }
    return obj
end

function GroupMethods:AddColorpicker(id, title, default, callback)
    local current = typeof(default) == "Color3" and default or Color3.new(1,1,1)
    local row = makeRow(self.content, 36)
    local swatch = New("TextButton", {
        Size = UDim2.new(1,0,1,0),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, row)
    Corner(swatch,8); Stroke(swatch, Theme.Border,1)
    New("TextLabel", {
        Size = UDim2.new(1,-48,1,0), Position = UDim2.fromOffset(10,0),
        BackgroundTransparency=1, Text=prettyDisplayName(title), Font=Enum.Font.Gotham, TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left, TextColor3=Theme.Text,
    }, swatch)
    local preview = New("Frame", {Size=UDim2.fromOffset(24,18), Position=UDim2.new(1,-32,0.5,-9), BackgroundColor3=current, BorderSizePixel=0}, swatch)
    Corner(preview,5)

    local popup = New("Frame", {Visible=false, Size=UDim2.fromOffset(240,120), Position=UDim2.fromOffset(0,0), AnchorPoint=Vector2.new(0,0), BackgroundColor3=Theme.Surface, BorderSizePixel=0, ZIndex=110}, PopupLayer)
    Corner(popup,8); Stroke(popup,Theme.Border,1)
    local boxes={}
    local names={"R","G","B"}
    local vals={math.floor(current.R*255),math.floor(current.G*255),math.floor(current.B*255)}
    for i,nm in ipairs(names) do
        New("TextLabel", {Size=UDim2.fromOffset(22,22),Position=UDim2.fromOffset(8,8+(i-1)*33),BackgroundTransparency=1,Text=nm,Font=Enum.Font.GothamBold,TextSize=11,TextColor3=Theme.Text,ZIndex=111}, popup)
        local tb=New("TextBox", {Size=UDim2.fromOffset(70,24),Position=UDim2.fromOffset(34,7+(i-1)*33),BackgroundColor3=Theme.Surface2,BorderSizePixel=0,Text=tostring(vals[i]),TextColor3=Theme.Text,Font=Enum.Font.Gotham,TextSize=11,ZIndex=111}, popup)
        Corner(tb,6); New("UIPadding",{PaddingLeft=UDim.new(0,7),PaddingRight=UDim.new(0,7)},tb)
        boxes[i]=tb
    end
    local apply=New("TextButton",{Size=UDim2.fromOffset(105,26),Position=UDim2.fromOffset(120,44),BackgroundColor3=Theme.Accent,BorderSizePixel=0,Text="APPLY",Font=Enum.Font.GothamBold,TextSize=10,TextColor3=Color3.new(1,1,1),ZIndex=111},popup)
    Corner(apply,6)

    local function setValue(c,fire)
        if typeof(c) ~= "Color3" then return end
        current=c; preview.BackgroundColor3=c
        vals={math.floor(c.R*255+0.5),math.floor(c.G*255+0.5),math.floor(c.B*255+0.5)}
        for i,tb in ipairs(boxes) do tb.Text=tostring(vals[i]) end
        if fire and typeof(callback)=="function" then pcall(callback,c) end
    end
    apply.MouseButton1Click:Connect(function()
        local r=math.clamp(tonumber(boxes[1].Text) or vals[1],0,255)
        local g=math.clamp(tonumber(boxes[2].Text) or vals[2],0,255)
        local b=math.clamp(tonumber(boxes[3].Text) or vals[3],0,255)
        setValue(Color3.fromRGB(r,g,b),true)
        closePopup(self.frame, popup)
    end)
    swatch.MouseButton1Click:Connect(function()
        if popup.Visible then
            closePopup(self.frame, popup)
        else
            openPopup(self.frame, popup, swatch)
        end
    end)
    return {
        Get=function() return current end,
        Set=function(_,v) setValue(v,true) end,
        SetValue=function(_,v) setValue(v,true) end,
        GetValue=function() return current end,
        Button=swatch,
    }
end

-- Compatibility proxy matching the V3/V4 source API.
local function normalizeMainUIInteraction()
    if not Main or not Main.Parent then return end

    for _, obj in ipairs(Main:GetDescendants()) do
        if obj:IsA("GuiButton") or obj:IsA("TextBox") then
            pcall(function() obj.Interactable = true end)
            pcall(function()
                if obj.ZIndex < 20 then obj.ZIndex = 20 end
            end)
        elseif obj:IsA("ScrollingFrame") then
            -- ScrollingFrame remains usable, but should not cover child buttons.
            pcall(function() obj.ZIndex = math.min(obj.ZIndex, 3) end)
            pcall(function() obj.InputSink = Enum.InputSink.None end)
        end
    end
end

task.defer(normalizeMainUIInteraction)


--========================================================--
-- SIDEBAR PHOTO HEADER
-- Photo is intentionally kept above the tab list and limited to the sidebar.
--========================================================--

--========================================================--
-- PRESERVED SETTINGS TAB / INTERFACE (exactly from current UI)
--========================================================--
Settings = VDUI:AddTab("Settings", ICON_ID)
do
    local left = Settings:AddGroupbox("left", "Interface")
    left:AddDropdown("Theme", "Theme", {"Purple", "Blue", "Neon"}, "Purple", function(value)
        if value == "Blue" then
            Theme.Accent = Color3.fromRGB(70, 150, 255)
        elseif value == "Neon" then
            Theme.Accent = Color3.fromRGB(180, 70, 255)
        else
            Theme.Accent = Color3.fromRGB(112, 85, 255)
        end
        AccentLine.BackgroundColor3 = Theme.Accent
        if currentTabButton then
            currentTabButton.Indicator.BackgroundColor3 = Theme.Accent
        end
    end)

    local right = Settings:AddGroupbox("right", "Information")
    right:AddLabel("Mawww Hub • Interface")
    right:AddLabel("Semua tab memiliki GroupBox kiri dan kanan.")
end

--========================================================--
-- V3/V4 FEATURE TABS AND GROUPBOX ROUTING
--========================================================--
PlayerTab = VDUI:AddTab("Player", ICON_ID)
SurvivalTab = VDUI:AddTab("Survivor", ICON_ID)
KillerTab = VDUI:AddTab("Killer", ICON_ID)
AimTab = VDUI:AddTab("Aim", ICON_ID)
ESPTab = VDUI:AddTab("ESP", ICON_ID)
VisualTab = VDUI:AddTab("Visuals", ICON_ID)
UtilityTab = VDUI:AddTab("Utilities", ICON_ID)
AutoFarmTab = VDUI:AddTab("Automation", ICON_ID)
UISettingsTab = VDUI:AddTab("UI", ICON_ID)

FeatureBoxes = {
    PlayerLeft = PlayerTab:AddGroupbox("left", "Movement"),
    PlayerRight = PlayerTab:AddGroupbox("right", "Avatar"),

    SurvivalParryV1 = SurvivalTab:AddGroupbox("left", "Auto Parry • V1"),
    SurvivalParryV2 = SurvivalTab:AddGroupbox("right", "Auto Parry • V2"),
    SurvivalParryV3 = SurvivalTab:AddGroupbox("left", "Auto Parry • V3"),
    SurvivalParryV4 = SurvivalTab:AddGroupbox("right", "Auto Parry • V4"),
    SurvivalParryV5 = SurvivalTab:AddGroupbox("left", "Auto Parry • V5"),
    SurvivalVault = SurvivalTab:AddGroupbox("right", "Vault & Escape"),
    SurvivalEscape = SurvivalTab:AddGroupbox("right", "Survivor Tools"),
    SurvivalAbilities = SurvivalTab:AddGroupbox("left", "Abilities"),
    SurvivalFake = SurvivalTab:AddGroupbox("right", "Fake & Utility"),
    SurvivalDodge = SurvivalTab:AddGroupbox("left", "Dodge & Skillcheck"),
    SurvivalNoSlow = SurvivalTab:AddGroupbox("right", "Movement Helpers"),

    KillerLeft = KillerTab:AddGroupbox("left", "Combat"),
    KillerRight = KillerTab:AddGroupbox("right", "Abilities"),
    KillerBypass = KillerTab:AddGroupbox("right", "Bypass"),
    KillerCounter = KillerTab:AddGroupbox("left", "Defense"),
    KillerUtility2 = KillerTab:AddGroupbox("left", "Utility"),

    -- Aim sections are intentionally ordered so visual helpers cannot visually overlap the Silent Veil groups.
    AimVeilV1 = AimTab:AddGroupbox("left", "Veil Aim • V1"),
    AimVeilV2 = AimTab:AddGroupbox("right", "Veil Aim • V2"),
    AimVeilV3 = AimTab:AddGroupbox("left", "Veil Aim • V3"),
    AimVeilV4 = AimTab:AddGroupbox("right", "Veil Aim • V4"),
    AimVeilV5 = AimTab:AddGroupbox("left", "Veil Aim • V5"),
    AimTOFV1 = AimTab:AddGroupbox("left", "ToF Aim • V1"),
    AimTOFV2 = AimTab:AddGroupbox("right", "ToF Aim • V2"),
    AimTOFV4 = AimTab:AddGroupbox("right", "ToF Aim • V4"),
    AimTOFV5 = AimTab:AddGroupbox("right", "ToF Aim • V5"),
    AimTOFV3 = AimTab:AddGroupbox("left", "ToF Aim • V3"),
    AimFlash = AimTab:AddGroupbox("right", "Flashlight Aim"),
    AimFlask = AimTab:AddGroupbox("left", "Flask & Cure"),
    AimUtility = AimTab:AddGroupbox("right", "Aim Utilities"),

    -- Dedicated visual helpers, deliberately kept after all aim engines.
    AimCrosshair = AimTab:AddGroupbox("left", "Crosshair"),
    AimCrosshairOffset = AimTab:AddGroupbox("right", "Crosshair Layout"),

    ESPLeft = ESPTab:AddGroupbox("left", "Player & Object ESP"),
    ESPRight = ESPTab:AddGroupbox("right", "ESP Settings"),

    VisualCamera = VisualTab:AddGroupbox("left", "Camera"),
    VisualInvisible = VisualTab:AddGroupbox("right", "Visibility"),
    VisualLighting = VisualTab:AddGroupbox("left", "Lighting & HUD"),
    VisualHUD = VisualTab:AddGroupbox("right", "HUD & Indicators"),

    UtilityLeft = UtilityTab:AddGroupbox("left", "Utility"),
    UtilityRight = UtilityTab:AddGroupbox("right", "Teleport & Quick Actions"),
    UtilityPredict = UtilityTab:AddGroupbox("left", "Prediction"),
    UtilityQuick = UtilityTab:AddGroupbox("right", "Quick Actions"),

    AutoFarmLeft = AutoFarmTab:AddGroupbox("left", "Automation"),
    AutoFarmRight = AutoFarmTab:AddGroupbox("right", "Server Hop"),

    UILeft = UISettingsTab:AddGroupbox("left", "Menu"),
    UIRight = UISettingsTab:AddGroupbox("right", "Keybinds"),
    UIConfigBox = UISettingsTab:AddGroupbox("left", "Configuration"),

}

Tabs = {
    Player = MakeLogicTab(FeatureBoxes.PlayerLeft),
    PlayerRight = MakeLogicTab(FeatureBoxes.PlayerRight),

    Survival = MakeLogicTab(FeatureBoxes.SurvivalParryV1),
    SurvivalVault = MakeLogicTab(FeatureBoxes.SurvivalVault),
    SurvivalEscape = MakeLogicTab(FeatureBoxes.SurvivalEscape),
    SurvivalParryV1 = MakeLogicTab(FeatureBoxes.SurvivalParryV1),
    SurvivalParryV2 = MakeLogicTab(FeatureBoxes.SurvivalParryV2),
    SurvivalParryV3 = MakeLogicTab(FeatureBoxes.SurvivalParryV3),
    SurvivalParryV4 = MakeLogicTab(FeatureBoxes.SurvivalParryV4),
    SurvivalParryV5 = MakeLogicTab(FeatureBoxes.SurvivalParryV5),
    SurvivalAbilities = MakeLogicTab(FeatureBoxes.SurvivalAbilities),
    SurvivalFake = MakeLogicTab(FeatureBoxes.SurvivalFake),
    SurvivalDodge = MakeLogicTab(FeatureBoxes.SurvivalDodge),
    SurvivalNoSlow = MakeLogicTab(FeatureBoxes.SurvivalNoSlow),

    Killer = MakeLogicTab(FeatureBoxes.KillerLeft),
    KillerExtra = MakeLogicTab(FeatureBoxes.KillerCounter),
    KillerRight = MakeLogicTab(FeatureBoxes.KillerRight),
    KillerAbilities = MakeLogicTab(FeatureBoxes.KillerRight),
    KillerBypass = MakeLogicTab(FeatureBoxes.KillerBypass),
    KillerUtility = MakeLogicTab(FeatureBoxes.KillerUtility2),

    Aim = MakeLogicTab(FeatureBoxes.AimVeilV1),
    AimRight = MakeLogicTab(FeatureBoxes.AimVeilV2),
    AimVeilV1 = MakeLogicTab(FeatureBoxes.AimVeilV1),
    AimVeilV2 = MakeLogicTab(FeatureBoxes.AimVeilV2),
    AimTOFV1 = MakeLogicTab(FeatureBoxes.AimTOFV1),
    AimTOFV2 = MakeLogicTab(FeatureBoxes.AimTOFV2),
    AimTOFV4 = MakeLogicTab(FeatureBoxes.AimTOFV4),
    AimVeilV3 = MakeLogicTab(FeatureBoxes.AimVeilV3),
    AimVeilV4 = MakeLogicTab(FeatureBoxes.AimVeilV4),
    AimVeilV5 = MakeLogicTab(FeatureBoxes.AimVeilV5),
    AimTOFV3 = MakeLogicTab(FeatureBoxes.AimTOFV3),
    AimTOFV5 = MakeLogicTab(FeatureBoxes.AimTOFV5),
    AimFlash = MakeLogicTab(FeatureBoxes.AimFlash),
    AimFlask = MakeLogicTab(FeatureBoxes.AimFlask),
    AimUtility = MakeLogicTab(FeatureBoxes.AimUtility),
    AimCrosshair = MakeLogicTab(FeatureBoxes.AimCrosshair),
    AimCrosshairOffset = MakeLogicTab(FeatureBoxes.AimCrosshairOffset),

    ESP = MakeLogicTab(FeatureBoxes.ESPLeft),
    ESPOptions = MakeLogicTab(FeatureBoxes.ESPRight),

    Visual = MakeLogicTab(FeatureBoxes.VisualCamera),
    VisualCamera = MakeLogicTab(FeatureBoxes.VisualCamera),
    VisualInvisible = MakeLogicTab(FeatureBoxes.VisualInvisible),
    VisualLighting = MakeLogicTab(FeatureBoxes.VisualLighting),
    VisualHUD = MakeLogicTab(FeatureBoxes.VisualHUD),

    Utility = MakeLogicTab(FeatureBoxes.UtilityLeft),
    UtilityPredict = MakeLogicTab(FeatureBoxes.UtilityPredict),
    UtilityTeleport = MakeLogicTab(FeatureBoxes.UtilityRight),
    UtilityGenBoost = MakeLogicTab(FeatureBoxes.UtilityLeft),
    UtilityQuick = MakeLogicTab(FeatureBoxes.UtilityQuick),

    AutoFarm = MakeLogicTab(FeatureBoxes.AutoFarmLeft),
    AutoFarmHop = MakeLogicTab(FeatureBoxes.AutoFarmRight),
    Avatar = MakeLogicTab(FeatureBoxes.PlayerRight),

    UISettings = MakeLogicTab(FeatureBoxes.UILeft),
    UIConfig = MakeLogicTab(FeatureBoxes.UIConfigBox),
    UIKeybinds = MakeLogicTab(FeatureBoxes.UIRight),
}

-- Shared runtime values used by config/logic and exposed for debugging.
VD_Elements = {}
_G.MAWWW_V3_Elements = VD_Elements



-- SERVICES / PLAYER REFERENCES
--========================================================--
Players = game:GetService("Players")
UserInputService = game:GetService("UserInputService")
RunService = game:GetService("RunService")
ReplicatedStorage = game:GetService("ReplicatedStorage")
VirtualInputManager = game:GetService("VirtualInputManager")
Lighting = game:GetService("Lighting")
CollectionService = game:GetService("CollectionService")
TweenService = game:GetService("TweenService")
SoundService = game:GetService("SoundService")
HttpService = game:GetService("HttpService")
TeleportService = game:GetService("TeleportService")
VirtualUser = game:GetService("VirtualUser")
GuiService = game:GetService("GuiService")
Stats = game:GetService("Stats")

Player = Players.LocalPlayer
if not Player then
    return
end
-- Compatibility alias used by imported feature modules.
LocalPlayer = Player
CoreGui = game:GetService("CoreGui")
PlayerGui = Player:WaitForChild("PlayerGui")
isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled


-- Keep notifications hidden until a key is verified.
SUPPRESS_NOTIFY = true
function notify(title, content, duration)
    if SUPPRESS_NOTIFY then
        return
    end

    local payload = {
        Title = tostring(title or "Mawww Hub"),
        Description = tostring(content or ""),
        Time = tonumber(duration) or 4,
        Icon = "info",
    }

    pcall(function()
        Library:Notify(payload)
    end)
end

--========================================================--
-- HELPERS
--========================================================--
function getRoot() local c = Player.Character; return c and c:FindFirstChild("HumanoidRootPart") end
function getHum() local c = Player.Character; return c and c:FindFirstChildOfClass("Humanoid") end
function isDowned() local h = getHum(); return (not h) or h.Health <= 0 end
function teamMatches(teamName, keyword)
    if not teamName then return false end
    return string.find(string.lower(teamName), keyword, 1, true) ~= nil
end
function GetRole()
    local teamName = Player.Team and Player.Team.Name or ""
    if teamMatches(teamName, "killer") then return "Killer" end
    if teamMatches(teamName, "survivor") then return "Survivor" end

    local role = Player:GetAttribute("Role")
    if role == "Killer" or role == "Survivor" then return role end
    if Player:GetAttribute("IsKiller") == true or Player:GetAttribute("IsKillerRole") == true then return "Killer" end
    if Player:GetAttribute("IsSurvivor") == true then return "Survivor" end

    local char = Player.Character
    if char then
        role = char:GetAttribute("Role")
        if role == "Killer" or role == "Survivor" then return role end
        if char:GetAttribute("IsKiller") == true or char:GetAttribute("IsKillerRole") == true then return "Killer" end
        if char:GetAttribute("IsSurvivor") == true then return "Survivor" end
    end

    return teamName == "" and "Unknown" or "Lobby"
end
VD_KILLER_TEAM_KEYWORDS = {
    "killer", "killers", "the killer", "the killers",
    "murderer", "slasher", "hunter", "monster", "stalker",
}
VD_SURVIVOR_TEAM_KEYWORDS = {
    "survivor", "survivors", "the survivor", "the survivors",
}

function VD_IsKillerPlayer(p)
    if not p or p == Player then return false end

    local method = tostring((VD and VD.TOF_KillerDetectMethod) or "Auto")
    if method ~= "Attribute-Only" then
        local teamName = string.lower((p.Team and p.Team.Name) or "")
        for _, kw in ipairs(VD_KILLER_TEAM_KEYWORDS) do
            if teamName:find(kw, 1, true) then return true end
        end
    end

    if method ~= "Team-Only" then
        if p:GetAttribute("IsKiller") == true then return true end
        if p:GetAttribute("Role") == "Killer" then return true end
        if p:GetAttribute("IsKillerRole") == true then return true end

        local ch = p.Character
        if ch then
            if ch:GetAttribute("IsKiller") == true then return true end
            if ch:GetAttribute("KillerType") ~= nil then return true end
            if ch:GetAttribute("KillerWeapon") ~= nil then return true end
            if ch:FindFirstChild("Killer") then return true end
        end
    end

    return false
end

function VD_IsSurvivorPlayer(p)
    if not p or p == Player then return false end

    local teamName = string.lower((p.Team and p.Team.Name) or "")
    for _, kw in ipairs(VD_SURVIVOR_TEAM_KEYWORDS) do
        if teamName:find(kw, 1, true) then return true end
    end

    if p:GetAttribute("IsSurvivor") == true then return true end
    if p:GetAttribute("Role") == "Survivor" then return true end

    return false
end

function IsKiller(p) return VD_IsKillerPlayer(p) end
function IsSurvivor(p) return VD_IsSurvivorPlayer(p) end
function GetRemotes() return ReplicatedStorage:FindFirstChild("Remotes") end

function VD_WallCheckVisible(originPos, targetPos, targetChar, extraExcludes)
    if typeof(originPos) ~= "Vector3" or typeof(targetPos) ~= "Vector3" then return false end
    local distance = (targetPos - originPos).Magnitude
    if distance <= 0.1 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    pcall(function() params.RespectCanCollide = true end)
    local excludes = {}
    if Player.Character then table.insert(excludes, Player.Character) end
    if targetChar then table.insert(excludes, targetChar) end
    if type(extraExcludes) == "table" then
        for _, inst in ipairs(extraExcludes) do if inst then table.insert(excludes, inst) end end
    end
    params.FilterDescendantsInstances = excludes
    local samples = { targetPos }
    if targetChar then
        local seen = {}
        for _, part in ipairs({targetChar:FindFirstChild("Head"), targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso"), targetChar:FindFirstChild("HumanoidRootPart")}) do
            if part and part:IsA("BasePart") and not seen[part] then seen[part] = true; table.insert(samples, part.Position) end
        end
    end
    for _, samplePos in ipairs(samples) do
        local ray = samplePos - originPos
        local rayDist = ray.Magnitude
        if rayDist <= 0.1 then return true end
        local hit = Workspace:Raycast(originPos, ray.Unit * rayDist, params)
        if hit == nil then return true end
        if targetChar and hit.Instance and hit.Instance:IsDescendantOf(targetChar) then return true end
    end
    return false
end

--========================================================--
-- GLOBAL STATE
--========================================================--
getgenv().VD = getgenv().VD or {}
VD = getgenv().VD

-- Reload safety: a previous run may have marked the shared state as destroyed.
-- Start this run with a live state table.
VD.Destroyed = false

-- Reload safety for merged source modules.  Destroy old instances before
-- registering new Heartbeat/RenderStepped/Input connections.
pcall(function()
    local env = (getgenv and getgenv()) or _G
    local oldSpear = env.MAWWW_ReplacedModules and env.MAWWW_ReplacedModules.AutoDodgeSpear
    if oldSpear and type(oldSpear.Destroy) == "function" then
        pcall(oldSpear.Destroy)
    end
    local oldFarm = env.MAWWW_ReplacedModules and env.MAWWW_ReplacedModules.AutoFarmGenerator
    if oldFarm and type(oldFarm.Destroy) == "function" then
        pcall(oldFarm.Destroy)
    end
    if env.MAWWW_SourcePlayerESP and type(env.MAWWW_SourcePlayerESP.Destroy) == "function" then
        pcall(env.MAWWW_SourcePlayerESP.Destroy)
    end
    env.MAWWW_ReplacedModules = nil
end)

pcall(function()
    local pg = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        for _, name in ipairs({"BypassGenUI", "DODGE_PillUI"}) do
            local ui = pg:FindFirstChild(name)
            if ui then ui:Destroy() end
        end
    end
end)

defaults = {
    AntiKnockdown=false, AutoCrouch=false, AutoCrouchDodge=false,
    PalletReflex=false, PalletReflexRange=20,
    FastVaultEnabled=false, FastVaultRadius=8, FastVaultSpeedMult=2.0,
    FastVaultInstant=false,
    Moonwalk=false, MoonwalkSpam=30, MoonwalkIntensity=35,
    ShowMoonwalkIcon=false, LockMoonwalkIcon=false,
    AutoSkillcheck=false, AutoSkillcheckMode="NORMAL", AutoSkillcheckBossGen=false,
    AutoParryV1=false, SURV_AutoParry=false, SURV_ParryDistance=8,
    SURV_ParryAggressive=false, SURV_AggressivenessV1=100, SURV_ShowParryCircle=false,
    PARRY_V1_WallCheck=true, PARRY_V1_IgnoreDown=true,
    PARRY_V1_AntiFake=true, PARRY_V1_FakeWindow=3, PARRY_V1_FakeDistance=2.5,
    PARRY_V1_MinFacing=0.5, PARRY_V1_MinVelocity=2, PARRY_V1_IgnoreFacing=false,
    PARRY_V1_Raycast=true, PARRY_V1_RaycastRange=20, PARRY_V1_Safety=true, ParryAutoDetect=true, ParryNotifyUnknown=false, ParryAbbySpam=true, ParrySpamDuration=0.4,
    Config_Select="default", Config_CustomName="my_config",
    Config_AutoSaveEnabled=true, Config_AutoLoadEnabled=true, Config_AutoSaveInterval=3,
    PARRY_Enabled=false, PARRY_Aggressive=false, PARRY_Aggressiveness=100, PARRY_IgnoreFacing=false, PARRY_AutoFace=false, PARRY_Distance=10,
    PARRY_ShowCircle=false, PARRY_SilentParry=false, PARRY_Usemawww=true,
    PARRY_WallCheck=true, PARRY_IgnoreDown=true, PARRY_AntiFake=true, PARRY_MinVelocity=2, PARRY_Safety=true, PARRY_Facing=0.35,
    AutoDodgeAbyss=false, AbyssDodgeDistance=20, AbyssDodgeMode="Crouch", AbyssUltOnly=false, AbyssTeleportDist=16,
    AutoDodgeSpearVeil=false, SURV_AutoDodgeSpear=false, SpearVeilDodgeMode="Strafe",
    SpearVeilDetectRange=50, SpearVeilDodgeDistance=18,
    SpearVeilUseRemote=true, SpearVeilShowIndicator=false,
    TOF_SilentAim=false, TOF_Laser=true, TOF_WallCheck=false, TOF_Predict=false, TOF_WallCheckSource=false, TOF_SourceLaser=true,
    TOF_BlockKnocked=true, TOF_TargetMode="Killer", TOF_Key="None", TOF_KillerDetectMethod="Auto",
    TOF_FOV=220, TOF_MaxDist=650, TOF_HideUI=false, TOF_Minimized=false,
    -- TOF V1 upgrade defaults
    TOF_AimPart="UpperTorso",
    TOF_ProjectileSpeed=400,
    TOF_PredictIterations=3,
    TOF_LeadMult=1.0,
    TOF_PingComp=true,
    TOF_ShowFOV=false,
    TOF_ShowLockMarker=true,
    TOF_FaceTarget=true,
    TOF_LaserR=255, TOF_LaserG=50, TOF_LaserB=50,
    -- TOF V2 / Silent Pistol V2 (imported from maww hub no bug 24 september)
    TOF2_Enabled=false, TOF2_AutoFire=false, TOF2_Predict=true,
    TOF2_PredictIterations=3, TOF2_WallCheck=true,
    TOF2_MaxDist=600, TOF2_FOV=180, TOF2_TargetMode="Killer", TOF2_AimPart="Torso",
    TOF2_FireRate=0.18, TOF2_ShowLaser=true, TOF2_LaserColorR=255,
    TOF2_LaserColorG=40, TOF2_LaserColorB=40, TOF2_Key="None",
    TOF2_IgnoreDown=true, TOF2_BlockKnocked=true,
    ShowParryRangeV1=false, ShowParryRangeV2=false,
    -- Auto Parry V3/V4 (cloned from the existing V1/V2 engines)
    SURV_AutoParryV3=false, SURV_ParryDistanceV3=10, SURV_ParryAggressiveV3=false, SURV_AggressivenessV3=100, SURV_ShowParryCircleV3=false, SURV_SilentParryV3=false,
    PARRY_V3_WallCheck=true, PARRY_V3_IgnoreDown=true, PARRY_V3_AntiFake=true, PARRY_V3_FakeWindow=3, PARRY_V3_FakeDistance=2.5,
    PARRY_V3_MinFacing=0.5, PARRY_V3_MinVelocity=2, PARRY_V3_IgnoreFacing=false, PARRY_V3_Raycast=true, PARRY_V3_RaycastRange=20, PARRY_V3_Safety=true,
    PARRY_V4_Enabled=false, PARRY_V4_Aggressive=false, PARRY_V4_Aggressiveness=100, PARRY_V4_IgnoreFacing=false, PARRY_V4_AutoFace=false, PARRY_V4_Distance=10,
    PARRY_V4_ShowCircle=false, PARRY_V4_SilentParry=false, PARRY_V4_Usemawww=true, PARRY_V4_WallCheck=true, PARRY_V4_IgnoreDown=true,
    PARRY_V4_AntiFake=true, PARRY_V4_MinVelocity=2, PARRY_V4_Safety=true, PARRY_V4_Facing=0.35,
    -- Auto Parry V5 (imported from supplied A2 Parry AI extract)
    SURV_AutoParryV5=false,
    SURV_ParrySafetyV5=false,
    SURV_ParryAggressiveV5=false,
    SURV_ParryCircleV5=true,
    SURV_ParryRadiusV5=15,
    SURV_ParryFaceV5=0.7,
    SURV_SilentParryV5=true,
    SURV_AutoCrouchV5=false,
    SURV_ParryAntiFakeV5=true,
    SURV_ParryFacingAngleV5=60,
    SURV_PARRY_V5_Ignore_Skills={},
    APV5_IgnoreHiddenS1=false, APV5_IgnoreAbyssalS1=false,
    ParryV5Enabled=false, ParryV5Radius=15, ParryV5Face=0.7,
    ParryV2WallCheck=true, ParryV2IgnoreDown=true,
    PredictMap=false, PredictKiller=false,
    Speed=false, SpeedValue=16,
    Noclip=false,
    AutoFlee=false, AutoFleeDist=50,
    InstantHealSelf=false, AutoHealAll=false,
    FirstPersonCamera=false,
    Invisible=false, InvisibleHideIcon=false,
    -- DBD Camera (replaced with supplied W424 camera)
    DBDCamera=false,
    DBDCameraDistance=25,
    DBDCameraFOV=120,
    DBDCameraHeight=0,
    DBDCameraCharScale=0.05,
    DBDCameraUseCharScale=true,
    -- Legacy DBD fields kept for config compatibility.
    DBDCameraMode="Killer",
    DBDCameraSideOffset=0, DBDCameraSmooth=0.12,
    DBDCameraSurvHeight=0, DBDCameraSurvDistance=25,
    DBDCameraSurvSide=0, DBDCameraSurvFOV=120,
    DBDCameraSurvSmooth=0.25,
    DBDCameraMouseSens=0.5,
    DBDCameraMobileSens=1.2,
    DBDCameraTouchZone=0.35,
    DBDCameraMobileInvertY=false,
    DBDCameraSurvCollision=true, DBDCameraSurvFOVLerp=true,
    DBDCameraMobileDeadzone=3, DBDCameraSurvSmoothSpeed=18,
    DBDCameraSurvAutoPauseDown=true,

    -- Silent Veil V5 (imported from supplied homing-spear source)
    VeilV5Enabled=false, VeilV5ShowFOV=true, VeilV5ShowMarkers=true,
    VeilV5RunToTarget=true, VeilV5StickyLock=true, VeilV5PingCompensation=true,
    VeilV5AutoGravity=true, VeilV5AutoPredict=true, VeilV5LongRangeArc=true,
    VeilV5StrictFOV=true, VeilV5TargetPart="Torso",
    VeilV5FOV=300, VeilV5SpearSpeed=165, VeilV5Gravity=98.1,
    VeilV5LeadMultiplier=1.0, VeilV5ExtraLeadTime=0.06, VeilV5CloseRange=15,
    VeilV5MaxDist=1000, VeilV5HomingDuration=1.4, VeilV5HomingHitDist=4,
    VeilV5HomingRate=0.02, VeilV5ArcHomingDelay=0.18, VeilV5ArcStartRange=65,
    VeilV5CloseLockRange=60, VeilV5DistanceBias=0.75, VeilV5MarkerSize=1500,

    -- Silent Pistol V5 (imported from supplied ToF source)
    PistolV5Enabled=false, PistolV5Laser=true, PistolV5WallCheck=false,
    PistolV5BlockKnocked=true, PistolV5BypassCarry=true,
    PistolV5TargetMode="Killer", PistolV5Key="None",
    KillerAutoAttack=false, KillerAttackRange=12,
    KillerAutoSpam=false, KillerAttackDelay=0.45,
    KillerAutoStalk=false, KillerKillAll=false,
    KillerHitbox=false, KillerHitboxSize=15,
    KillerInfLunge=false, KillerInfFrenzy=false,
    KillerInfLakeMist=false, KillerInfPursuit=false,
    KillerInfGrab=false, KillerInfAbyss=false,
    KillerInfSkill=false, KillerBypassCD=false,
    KillerBypassSkill=false,
    FakeAttack=false, FakeParry=false, FakeParryAnim="Enten",
    FakeGenEnabled=false, FakeGenPlaying=false,
    KillerDestroyPallets=false, KillerAutoKickGen=false,
    KillerCounterAutoParry=false,
    AimLockHidden=false, AimLockHiddenKey="E",
    AimLockAttack=false, AimLockAttackFOV=250, AimLockAttackStrength=1,
    AimLockAttackPredict=true, AimLockAttackPredictStrength=0.12,
    AimLockAttackVisibility=true, AimLockAttackPart="HumanoidRootPart",
    BypassSelfUnhook=false, SelfUnhookFollowDuration=30, SelfUnhookFollowDistance=20,
    UnlockSkillWhileCarrying=false,
    KillerAutoHook=false, KillerNoSlowdown=false, KillerAntiBlind=false,
    KillerCustomMasked="Richard",
    KillerBlockAllVaults=false, KillerAutoDropAllPallets=false, KillerBreakAllPallets=false,
    -- Silent Veil V3/V4
    VeilV3Enabled=false, VeilShowFOVV3=true, VeilShowTrackerV3=false,
    VeilAutoPredictV3=true, VeilAutoThrowV3=false, VeilFireDelayV3=0.08, VeilFOVV3=150, VeilMaxDistV3=400,
    VeilSpearSpeedV3=165, VeilGravityV3=103, VeilAuraSpearSpeedV3=165, VeilAuraSpearGravityV3=96.5, VeilLeadMultiplierV3=1.4,
    VeilWallCheckV3=false, VeilIgnoreDownV3=true, VeilShowPlayerMarkersV3=true, VeilShowTargetMarkerV3=true,
    VeilShowTracerV3=true, VeilShowNameLabelsV3=true,
    VeilV4Enabled=false, VeilV4AimLock=true, VeilV4AutoThrow=true, VeilV4UseInterceptor=true, VeilV4WallCheck=false, VeilV4IgnoreDown=true,
    VeilV4ShowFOV=true, VeilV4ShowTracker=true, VeilV4FOV=180, VeilV4MaxDist=600, VeilV4SpearSpeed=170, VeilV4SpearGravity=100,
    VeilV4AuraSpearSpeed=170, VeilV4AuraSpearGravity=95, VeilV4LeadMultiplier=1.35, VeilV4Iterations=3, VeilV4FireDelay=0.05,
    VeilV4ShowPlayerMarkers=true, VeilV4ShowTargetMarker=true, VeilV4ShowTracer=true, VeilV4ShowNameLabels=true,
    VeilEnabled=false, VeilShowFOV=true, VeilShowTracker=false,
    VeilAutoPredict=true, VeilAutoThrow=false, VeilFireDelay=0.08, VeilFOV=150, VeilMaxDist=400,
    VeilSpearSpeed=165, VeilGravity=103,
    VeilAuraSpearSpeed=165, VeilAuraSpearGravity=96.5,
    VeilLeadMultiplier=1.4, VeilWallCheck=false, VeilIgnoreDown=true,
    VeilShowPlayerMarkers=true, VeilShowTargetMarker=true,
    VeilShowTracer=true, VeilShowNameLabels=true,
    VeilV2Enabled=false, VeilV2ShowFOV=true, VeilV2ShowTracker=true,
    VeilV2AutoThrow=true, VeilV2WallCheck=false, VeilV2IgnoreDown=true,
    VeilV2FOV=180, VeilV2MaxDist=600,
    VeilV2SpearSpeed=170, VeilV2SpearGravity=100,
    VeilV2AuraSpearSpeed=170, VeilV2AuraSpearGravity=95,
    VeilV2LeadMultiplier=1.35, VeilV2Iterations=3,
    VeilV2FireDelay=0.05, VeilV2UseInterceptor=true,
    VeilV2ShowPlayerMarkers=true, VeilV2ShowTargetMarker=true,
    VeilV2ShowTracer=true, VeilV2ShowNameLabels=true,
    -- Silent Pistol V3 / TOF V3
    TOF3_SilentAim=false, TOF3_Laser=true, TOF3_WallCheck=false, TOF3_Predict=false, TOF3_WallCheckSource=false,
    TOF3_BlockKnocked=true, TOF3_TargetMode="Killer", TOF3_Key="None", TOF3_KillerDetectMethod="Auto",
    TOF3_FOV=220, TOF3_MaxDist=650, TOF3_HideUI=false, TOF3_Minimized=false,
    TOF3_AimPart="UpperTorso", TOF3_ProjectileSpeed=400, TOF3_PredictIterations=3, TOF3_LeadMult=1.0,
    TOF3_PingComp=true, TOF3_ShowFOV=false, TOF3_ShowLockMarker=true, TOF3_FaceTarget=true,
    TOF3_LaserR=255, TOF3_LaserG=50, TOF3_LaserB=50,
    PistolEnabled=false, PistolLaser=true, PistolWallCheck=false,
    PistolBlockKnocked=true, PistolTargetMode="KILLER",
    PistolAutoFire=false, PistolFireRate=0.2, PistolFOV=180,
    PistolMaxDist=500, PistolShowTracker=true,
    FlashSilentAim=false, FlashAutoFire=true, FlashFOV=200,
    FlashMaxDist=400, FlashWallCheck=false, FlashTargetMode="Killer",
    FlaskSilentAim=false, FlaskLaser=false,
    ESP_Killer=false, ESP_Survivor=false, ESP_Lobby=true, ESP_SCP=false,
    ESP_Generator=false, ESP_Window=false, ESP_Pallet=false,
    ESP_Hook=false, ESP_Distance=250, ESP_ShowName=false,
    ESP_ShowGenProgress=false, ESP_FillTransparency=70, ESP_OutlineTransparency=20,
    UnlimitedZoom=false, MaxZoomDistance=1000,
    FOVEnabled=true, FOV=90,
    Fullbright=false, NO_Fog=false, WeatherTheme="Default",
    -- Stun Indicator
    StunIndicatorEnabled=false, StunIndicatorRange=500,
    StunIndicatorSoundEnabled=true, StunIndicatorSoundVolume=1.5,
    StunIndicatorSoundRange=500, StunIndicatorSelectedSound="an anime",
    ShowPingFPS=false, HideSurvIcon=false, ShowHookCounter=false,
    MawwwtKiller=false, SpectatorCounter=false, KillerPerks=false,
    CrossEnabled=false, CrossStyle="Dot", CrossSize=3,
    CrossThickness=4, CrossGap=6, CrossPosX=0, CrossPosY=0,
    CrossColorR=255, CrossColorG=255, CrossColorB=255,
    FlingEnabled=false, FlingStrength=10000, BeatSurvivor=false, BeatKiller=false,
    AF_Enabled=false, AF_Mode="Auto",
    AF_AutoReady=true, AF_AutoRequeue=true, AF_AutoEscapeNow=true,
    AF_AutoHeal=true, AF_AutoAttack=true, AF_AutoHook=true,
    AF_StartTime=0, AF_MatchesPlayed=0, AF_LastEscapeTry=0, AF_EscapeCooldown=2, AF_Status="Idle",
    -- Auto Farm Generator (replacement source)
    AFG_Enabled=false, AFG_Mode="SUCCESS", AFG_AutoTP=true, AFG_AutoRepair=true, AFG_AutoSkill=true,
    AFG_TPDelay=0.35, AFG_LoopDelay=0.8, AFG_FleeOnKiller=true, AFG_FleeDistance=28,
    AFG_RepairRadius=10, AFG_TriggerDelay=0.035,
    SH_Enabled=false, SH_HopAfterMatch=true, SH_RandomHop=true,
    SH_WaitingTimeout=60, SH_MinPlayers=3, SH_HopCooldown=15,
    SH_MaxRetries=5, SH_SkipVisited=true, SH_AutoResetWhenAllVisited=true,
    SH_IsHopping=false, SH_HopCount=0, SH_LastHopTime=0,
    SH_LobbyEnterTime=0, SH_LastRole="Unknown", SH_VisitedServers={},
    GenBoost=false, ShowGenBossIcon=false, LockGenBossIcon=false,
    ShowInfiniteMyersIcon=false, LockInfiniteMyersIcon=false,
    ShowBypassSkillIcon=false, LockBypassSkillIcon=false,
    TP_Offset=3, AntiAFK=false,
    QuickMoonwalkPosition=nil, QuickGenBossPosition=nil,
    QuickInfiniteMyersPosition=nil, QuickBypassSkillPosition=nil,
    -- NEW: Fake Perks
    FP_Flowstate=false, FP_QuickRecovery=false, FP_PerfectLanding=false,
    FP_AdrenalineRush=false, FP_Cooldown=10,
    -- NEW: Spoof
    SPOOF_Level="0", SPOOF_Gears="0", SPOOF_Screws="0",
    -- NEW: Streamer
    StreamerHideName=false,
    -- NEW: Emote
    EmoteEnabled=false, SelectedEmote="Friday Night",
    -- Mawww source additions (kept separate to avoid conflicts with existing movement code)
    L2_AutoRunMobile=false, L2_AutoRunPC=false,
    L2_SpeedBoost=false, L2_Speed=30,
    L2_GodMode=false,
    -- PATCH: Anti Fake Window
    AntiFakeWindow=true,
    AntiFakeWindowRange=12,
    AntiFakeWindowCooldown=0.8,
    AntiFakeWindowDebug=false,
    -- Compatibility defaults for features referenced by imported logic.
    NoCutscene=false, NoSlowPatchEnabled=true, ShiftLock=false, ThirdPerson=false,
    VeilV2AimLock=true, SURV_SilentParry=false, ShowParryRangeV3=false, ShowParryRangeV4=false,
    VIS_KillerPerks=false, HiddenLeapBypass=false, BypassLakeMist=false, BypassPursuit=false,
    BypassFrenzy=false, BypassAbyss=false,
    SwiftVault=false, SwiftVaultV2=false, AutoWindowsVault=false, AutoDropPallet=false,
    ShowPalletDropRange=false, SURV_AntiKnock=false, AntiFallSlowdown=false, InfinityZoom=false,
    Destroyed=false,
}
-- Backward compatibility for older saved configs.
for k, v in pairs(defaults) do
    if VD[k] == nil then VD[k] = v end
end

--========================================================--
-- UI / FEATURE CLEANUP: disable removed legacy duplicates.
-- The active replacements are Fast Vault, Pallet Reflex,
-- Anti Knockdown, No-Slowdown+, and Unlimited Zoom Out.
--========================================================--
VD.SwiftVault = false
VD.SwiftVaultV2 = false
VD.AutoWindowsVault = false
VD.AutoDropPallet = false
VD.ShowPalletDropRange = false
VD.SURV_AntiKnock = false
VD.AntiFallSlowdown = false
VD.InfinityZoom = false

-- Keep the public V1 display flag synchronized with the original toggle.
if VD.ShowParryRangeV1 == nil then
    VD.ShowParryRangeV1 = VD.SURV_ShowParryCircle == true
end

if game.JobId and game.JobId ~= "" and VD.SH_VisitedServers then
    VD.SH_VisitedServers[game.JobId] = tick()
end
originalLighting = {
    Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
    GlobalShadows = Lighting.GlobalShadows, OutdoorAmbient = Lighting.OutdoorAmbient,
}
-- VD_Elements is supplied by the current UI adapter above.

function RegToggle(tab, text, desc, default, vdKey, extraCallback)
    if not tab then return nil end
    if vdKey and VD_Elements[vdKey] then return VD_Elements[vdKey] end

    local ok, obj = pcall(function()
        local initial = (vdKey and VD[vdKey] ~= nil) and VD[vdKey] or default
        return tab:Toggle({
            Title = text,
            Desc = desc or "",
            Flag = vdKey,
            Value = initial,
            Callback = function(v)
                if vdKey then VD[vdKey] = v end
                if extraCallback then pcall(extraCallback, v) end
            end,
        })
    end)

    if not ok then
        warn("[Purple X Hub] Toggle failed:", text, obj)
        return nil
    end

    if obj and vdKey then
        VD_Elements[vdKey] = obj
    end

    return obj
end

function RegSlider(tab, text, desc, default, min, max, step, vdKey, extraCallback)
    if not tab then return nil end
    if vdKey and VD_Elements[vdKey] then return VD_Elements[vdKey] end

    local ok, obj = pcall(function()
        return tab:Slider({
            Title = text,
            Desc = desc or "",
            Flag = vdKey,
            Default = (vdKey and VD[vdKey] ~= nil) and VD[vdKey] or default,
            Min = min,
            Max = max,
            Step = step,
            Rounding = formatRounding(step),
            Callback = function(v)
                if vdKey then VD[vdKey] = v end
                if extraCallback then pcall(extraCallback, v) end
            end,
        })
    end)

    if not ok then
        warn("[Purple X Hub] Slider failed:", text, obj)
        return nil
    end

    if obj and vdKey then
        VD_Elements[vdKey] = obj
    end

    return obj
end

function RegDropdown(tab, text, desc, values, default, multi, vdKey, extraCallback)
    if not tab then return nil end
    if vdKey and VD_Elements[vdKey] then return VD_Elements[vdKey] end

    local ok, obj = pcall(function()
        return tab:Dropdown({
            Title = text,
            Desc = desc or "",
            Flag = vdKey,
            Values = values or {},
            Value = (vdKey and VD[vdKey] ~= nil) and VD[vdKey] or default,
            Default = (vdKey and VD[vdKey] ~= nil) and VD[vdKey] or default,
            Multi = multi == true,
            Callback = function(v)
                if vdKey then VD[vdKey] = v end
                if extraCallback then pcall(extraCallback, v) end
            end,
        })
    end)

    if not ok then
        warn("[Purple X Hub] Dropdown failed:", text, obj)
        return nil
    end

    if obj and vdKey then
        -- Mawww source uses :Refresh() on some dropdowns; Obsidian uses :SetValues().
        pcall(function()
            if type(obj.Refresh) ~= "function" and type(obj.SetValues) == "function" then
                obj.Refresh = function(self, values)
                    return self:SetValues(values)
                end
            end
        end)
        VD_Elements[vdKey] = obj
    end

    return obj
end

function RegButton(tab, text, desc, callback)
    if not tab then return nil end
    local ok, obj = pcall(function()
        return tab:Button({
            Title = text,
            Desc = desc or "",
            Callback = callback,
        })
    end)
    if not ok then
        warn("[Purple X Hub] Button failed:", text, obj)
        return nil
    end
    return obj
end

function RegInput(tab, text, desc, default, vdKey, extraCallback)
    if not tab then return nil end
    if vdKey and VD_Elements[vdKey] then return VD_Elements[vdKey] end
    local ok, obj = pcall(function()
        return tab:Input({
            Title = text,
            Desc = desc or "",
            Flag = vdKey,
            Value = (vdKey and VD[vdKey] ~= nil) and VD[vdKey] or default,
            Default = (vdKey and VD[vdKey] ~= nil) and VD[vdKey] or default,
            Placeholder = default,
            Callback = function(v)
                if vdKey then VD[vdKey] = v end
                if extraCallback then pcall(extraCallback, v) end
            end,
        })
    end)
    if not ok then
        warn("[Purple X Hub] Input failed:", text, obj)
        return nil
    end
    if obj and vdKey then VD_Elements[vdKey] = obj end
    return obj
end

function RegDivider(tab, title)
    if not tab then return end
    pcall(function()
        tab:Divider(type(title) == "table" and title or nil)
    end)
end

function RegLabel(tab, text)
    if not tab then return end
    pcall(function()
        tab:Label(text)
    end)
end
--========================================================--
-- OPEN THE ALF UI
--========================================================--
pcall(function()
    MAWWW_SetUIVisible(true)
end)
VD_TogglePingFPS, VD_ToggleHideSurvIcon, VD_ToggleHookCounter = nil
VD_ApplyHideSurvIcon, VD_RestoreHideSurvIcon, VD_UpdateHookCounter = nil


--========================================================--
-- [REPLACED] DBD CAMERA — supplied W424 implementation
-- Uses the exact camera behavior from the uploaded cameradbd.lua:
-- distance, FOV, height/camera offset and character scale.
-- The standalone pill UI is intentionally not created because
-- Mawww Hub already provides the controlling UI.
--========================================================--
-- DBD Camera + Distance (W424)
-- UI: Speed custom style (pill ON/OFF + settings panel +/-)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local DBD_Config = {
    Enabled = false,
    Distance = 25,
    FOV = 120,
    Height = 0,
    CharScale = 0.05,
    UseCharScale = true,
}

local DBD_DefaultFOV = 70
local DBD_DefaultMinZoom = 0.5
local DBD_DefaultMaxZoom = 128
local DBD_Conn = nil

task.spawn(function()
    while not workspace.CurrentCamera do task.wait(0.1) end
    DBD_DefaultFOV = workspace.CurrentCamera.FieldOfView
    DBD_DefaultMinZoom = LocalPlayer.CameraMinZoomDistance
    DBD_DefaultMaxZoom = LocalPlayer.CameraMaxZoomDistance
end)

local function DBD_ApplyCharScale()
    if not DBD_Config.UseCharScale then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local s = DBD_Config.CharScale
    pcall(function()
        hum.BodyHeightScale = s
        hum.BodyWidthScale = s
        hum.BodyDepthScale = s
        hum.HeadScale = s
    end)
end

local function DBD_ResetAll()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function()
                hum.BodyHeightScale = 1
                hum.BodyWidthScale = 1
                hum.BodyDepthScale = 1
                hum.HeadScale = 1
                hum.CameraOffset = Vector3.new(0, 0, 0)
            end)
        end
    end
    local cam = workspace.CurrentCamera
    if cam then cam.FieldOfView = DBD_DefaultFOV end
    LocalPlayer.CameraMaxZoomDistance = DBD_DefaultMaxZoom
    LocalPlayer.CameraMinZoomDistance = DBD_DefaultMinZoom
end

local function DBD_StartLoop()
    if DBD_Conn then return end
    DBD_Conn = RunService.RenderStepped:Connect(function()
        if not DBD_Config.Enabled then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        cam.FieldOfView = DBD_Config.FOV
        local d = DBD_Config.Distance
        LocalPlayer.CameraMaxZoomDistance = d + 0.5
        LocalPlayer.CameraMinZoomDistance = math.max(0.1, d - 0.5)
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.CameraOffset.Y ~= DBD_Config.Height then
                hum.CameraOffset = Vector3.new(0, DBD_Config.Height, 0)
            end
        end
    end)
end

local function DBD_StopLoop()
    if DBD_Conn then
        DBD_Conn:Disconnect()
        DBD_Conn = nil
    end
end

local function DBD_W424_SetEnabled(on)
    DBD_Config.Enabled = on and true or false
    if DBD_Config.Enabled then
        DBD_ApplyCharScale()
        DBD_StartLoop()
        print("[DBD Camera] ON | Dist:", DBD_Config.Distance, "FOV:", DBD_Config.FOV, "H:", DBD_Config.Height)
    else
        DBD_StopLoop()
        DBD_ResetAll()
        print("[DBD Camera] OFF")
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.35)
    if DBD_Config.Enabled then
        DBD_ApplyCharScale()
        DBD_StartLoop()
    end
end)

getgenv().GANKZ_SetDBDCamera = DBD_W424_SetEnabled


    local function DBD_W424_SyncFromVD()
        DBD_Config.Distance = math.max(1, tonumber(VD.DBDCameraDistance) or 25)
        DBD_Config.FOV = math.clamp(tonumber(VD.DBDCameraFOV) or 120, 50, 120)
        DBD_Config.Height = tonumber(VD.DBDCameraHeight) or 0
        DBD_Config.CharScale = math.clamp(tonumber(VD.DBDCameraCharScale) or 0.05, 0.01, 1)
        DBD_Config.UseCharScale = VD.DBDCameraUseCharScale ~= false
    end

    function DBD_Start()
        DBD_W424_SyncFromVD()
        DBD_W424_SetEnabled(true)
    end

    function DBD_Restore()
        DBD_W424_SetEnabled(false)
    end

    getgenv().GANKZ_SetDBDCamera = DBD_W424_SetEnabled

-- Keep the W424 behavior in sync when the hub sliders change.
DBD_W424_ConfigSync = DBD_W424_SyncFromVD

--========================================================--
-- UI: DBD CAMERA — W424
--========================================================--
RegToggle(
    Tabs.Visual,
    "DBD Camera",
    "W424 camera: distance + FOV + height + character scale.",
    false,
    "DBDCamera",
    function(v)
        if v then
            DBD_Start()
            notify("DBD Camera", "ON — W424 camera active.", 3)
        else
            DBD_Restore()
            notify("DBD Camera", "OFF — camera restored.", 3)
        end
    end
)

RegSlider(
    Tabs.Visual,
    "Camera Distance",
    "W424 camera distance.",
    25,
    1,
    60,
    1,
    "DBDCameraDistance",
    function(v)
        VD.DBDCameraDistance = tonumber(v) or 25
        if VD.DBDCamera then
            DBD_W424_ConfigSync()
            DBD_ApplyCharScale()
        end
    end
)

RegSlider(
    Tabs.Visual,
    "Camera FOV",
    "W424 camera FOV.",
    120,
    50,
    120,
    5,
    "DBDCameraFOV",
    function(v)
        VD.DBDCameraFOV = tonumber(v) or 120
        if VD.DBDCamera then DBD_W424_ConfigSync() end
    end
)

RegSlider(
    Tabs.Visual,
    "Camera Height",
    "W424 camera height offset.",
    0,
    -5,
    10,
    0.5,
    "DBDCameraHeight",
    function(v)
        VD.DBDCameraHeight = tonumber(v) or 0
        if VD.DBDCamera then DBD_W424_ConfigSync() end
    end
)

RegToggle(
    Tabs.Visual,
    "Character Scale",
    "Apply the W424 character scale.",
    true,
    "DBDCameraUseCharScale",
    function(v)
        VD.DBDCameraUseCharScale = v == true
        if VD.DBDCamera then
            DBD_W424_ConfigSync()
            if VD.DBDCameraUseCharScale then
                DBD_ApplyCharScale()
            end
        end
    end
)

RegSlider(
    Tabs.Visual,
    "Character Scale Value",
    "W424 character scale.",
    0.05,
    0.01,
    1,
    0.01,
    "DBDCameraCharScale",
    function(v)
        VD.DBDCameraCharScale = tonumber(v) or 0.05
        if VD.DBDCamera and VD.DBDCameraUseCharScale ~= false then
            DBD_W424_ConfigSync()
            DBD_ApplyCharScale()
        end
    end
)

-- Respawn handling is already provided by the supplied W424 camera
-- implementation above. Do not reference the legacy DBDState here;
-- that state belongs to the removed legacy camera and caused a fatal
-- nil-index runtime error which prevented the remaining feature tabs
-- from registering.

--========================================================--
-- INVISIBLE — imported from invisible code L2hub
-- Robust state/respawn handling + floating button hide support
--========================================================--
MAWWW_InvisibleModule = nil
MAWWW_InvisibleOn = false
MAWWW_InvisibleDesired = false
MAWWW_InvisibleGui = nil
MAWWW_InvisibleToggleRef = nil
MAWWW_InvisibleLoading = false
MAWWW_InvisibleSyncing = false
MAWWW_InvisibleLoadToken = 0

function MAWWW_GetInvisibleEnvironment()
    local a = _G
    local b = (getgenv and getgenv()) or _G
    return a, b
end

function MAWWW_FindInvisibleModule()
    local a, b = MAWWW_GetInvisibleEnvironment()
    if a and a.MengHub and a.MengHub.Invisible then
        return a.MengHub.Invisible
    end
    if b and b.MengHub and b.MengHub.Invisible then
        return b.MengHub.Invisible
    end
    return nil
end

function MAWWW_ForceCleanupInvisible()
    pcall(function()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "invischair" then
                pcall(function() obj:Destroy() end)
            end
        end
    end)
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("Decal") then
                if part.Name ~= "Hurtbox"
                    and part.Name ~= "HumanoidRootPart"
                    and part.Name ~= "HRP_Clone" then
                    part.Transparency = 0
                end
            end
        end
    end)
end

function MAWWW_UpdateInvisibleButton()
    if not MAWWW_InvisibleGui then return end
    local btn = MAWWW_InvisibleGui:FindFirstChild("InvisButton")
    if not btn then return end
    local stroke = btn:FindFirstChildOfClass("UIStroke")
    if MAWWW_InvisibleOn then
        btn.Text = "INVISIBLE  •  ON"
        btn.TextColor3 = Color3.fromRGB(200, 255, 200)
        btn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
        if stroke then stroke.Color = Color3.fromRGB(50, 50, 50); stroke.Thickness = 1 end
    else
        btn.Text = "INVISIBLE  •  OFF"
        btn.TextColor3 = Color3.fromRGB(180, 180, 180)
        btn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
        if stroke then stroke.Color = Color3.fromRGB(45, 45, 45); stroke.Thickness = 1 end
    end
end

function MAWWW_UpdateInvisibleIconVisibility()
    pcall(function()
        if MAWWW_InvisibleGui then
            MAWWW_InvisibleGui.Enabled = not (VD.InvisibleHideIcon == true)
        end
    end)
end

function MAWWW_SyncInvisibleToggle(state)
    if not MAWWW_InvisibleToggleRef or MAWWW_InvisibleSyncing then return end
    MAWWW_InvisibleSyncing = true
    pcall(function()
        if type(MAWWW_InvisibleToggleRef.SetValue) == "function" then
            MAWWW_InvisibleToggleRef:SetValue(state)
        elseif type(MAWWW_InvisibleToggleRef.Set) == "function" then
            MAWWW_InvisibleToggleRef:Set(state)
        end
    end)
    MAWWW_InvisibleSyncing = false
end

function MAWWW_EnableInvisibleRuntime(showNotify)
    local module = MAWWW_InvisibleModule or MAWWW_FindInvisibleModule()
    if not module then return false end
    MAWWW_InvisibleModule = module

    -- Reset a stale state first. This prevents the imported module from
    -- remaining half-enabled after a respawn/toggle cycle.
    pcall(function() module.disable() end)
    task.wait(0.05)

    local ok, err = pcall(function() module.enable() end)
    if not ok then
        warn("[Mawww Hub] Invisible enable error: " .. tostring(err))
        MAWWW_InvisibleOn = false
        VD.Invisible = false
        MAWWW_InvisibleDesired = false
        MAWWW_ForceCleanupInvisible()
        MAWWW_UpdateInvisibleButton()
        MAWWW_SyncInvisibleToggle(false)
        return false
    end

    MAWWW_InvisibleOn = true
    VD.Invisible = true
    MAWWW_InvisibleDesired = true
    MAWWW_UpdateInvisibleButton()
    MAWWW_UpdateInvisibleIconVisibility()
    if showNotify then notify("Invisible", "Invisible Aktif!", 2) end
    return true
end

function MAWWW_DisableInvisibleRuntime(showNotify)
    MAWWW_InvisibleDesired = false
    MAWWW_InvisibleOn = false
    VD.Invisible = false
    local module = MAWWW_InvisibleModule or MAWWW_FindInvisibleModule()
    if module then
        MAWWW_InvisibleModule = module
        pcall(function() module.disable() end)
    end
    MAWWW_ForceCleanupInvisible()
    MAWWW_UpdateInvisibleButton()
    MAWWW_UpdateInvisibleIconVisibility()
    MAWWW_SyncInvisibleToggle(false)
    if showNotify then notify("Invisible", "Invisible Nonaktif!", 2) end
end

function MAWWW_SetInvisibleState(state, fromButton)
    state = state == true
    if MAWWW_InvisibleSyncing then return end

    MAWWW_InvisibleDesired = state
    VD.Invisible = state

    if state then
        if not MAWWW_InvisibleModule then
            MAWWW_InvisibleModule = MAWWW_FindInvisibleModule()
        end
        if not MAWWW_InvisibleModule then
            MAWWW_InvisibleOn = false
            MAWWW_SyncInvisibleToggle(false)
            if not MAWWW_InvisibleLoading then
                notify("Invisible", "Memuat engine Invisible...", 2)
            end
            return
        end
        MAWWW_EnableInvisibleRuntime(not fromButton)
    else
        MAWWW_DisableInvisibleRuntime(not fromButton)
    end
end

function MAWWW_CreateInvisibleMobileButton()
    if not isMobile then return end

    local parent = CoreGui
    pcall(function()
        if gethui then
            local hui = gethui()
            if hui then parent = hui end
        end
    end)
    if not parent then parent = LocalPlayer:FindFirstChild("PlayerGui") end
    if not parent then return end

    local old = parent:FindFirstChild("InvisButtonGui")
    if old then pcall(function() old:Destroy() end) end

    local gui = Instance.new("ScreenGui")
    gui.Name = "InvisButtonGui"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999998
    gui.Parent = parent

    local btn = Instance.new("TextButton")
    btn.Name = "InvisButton"
    btn.Size = UDim2.fromOffset(130, 34)
    btn.Position = UDim2.new(0.65, 0, 0.87, 0)
    btn.AnchorPoint = Vector2.new(0.5, 0.5)
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    btn.BorderSizePixel = 0
    btn.Text = "INVISIBLE  •  OFF"
    btn.TextColor3 = Color3.fromRGB(180, 180, 180)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.AutoButtonColor = false
    btn.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(45, 45, 45)
    stroke.Thickness = 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = btn

    local touchId, dragStart, startPos, hasMoved = nil, nil, nil, false
    local THRESHOLD = 8

    btn.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch
            and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if touchId then return end
        touchId, dragStart, startPos, hasMoved = input, input.Position, btn.Position, false
    end)

    btn.InputChanged:Connect(function(input)
        if input ~= touchId then return end
        if input.UserInputType ~= Enum.UserInputType.Touch
            and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local delta = input.Position - dragStart
        if delta.Magnitude >= THRESHOLD then hasMoved = true end
        if hasMoved then
            btn.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    btn.InputEnded:Connect(function(input)
        if input ~= touchId then return end
        if input.UserInputType ~= Enum.UserInputType.Touch
            and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if not hasMoved then
            MAWWW_SetInvisibleState(not MAWWW_InvisibleDesired, true)
            MAWWW_SyncInvisibleToggle(MAWWW_InvisibleDesired)
        end
        touchId, dragStart, startPos, hasMoved = nil, nil, nil, false
    end)

    MAWWW_InvisibleGui = gui
    MAWWW_UpdateInvisibleButton()
    MAWWW_UpdateInvisibleIconVisibility()
end

task.spawn(function()
    MAWWW_InvisibleLoading = true
    MAWWW_InvisibleLoadToken = MAWWW_InvisibleLoadToken + 1
    local token = MAWWW_InvisibleLoadToken
    local ok, err = pcall(function()
        local module = MAWWW_FindInvisibleModule()
        if not module then
            local chunk = loadstring(game:HttpGet("https://leekguy.vercel.app/roblox/menghub/crack_obf_invisible_93978595733734.lua"))
            if not chunk then error("Invisible loader compile failed") end
            chunk()
            module = MAWWW_FindInvisibleModule()
        end
        if not module then error("Invisible module was not registered") end
        MAWWW_InvisibleModule = module
    end)
    MAWWW_InvisibleLoading = false

    if not ok then
        warn("[Mawww Hub] Invisible load failed: " .. tostring(err))
        return
    end

    if token ~= MAWWW_InvisibleLoadToken then return end
    if MAWWW_InvisibleDesired then
        task.defer(function()
            MAWWW_EnableInvisibleRuntime(false)
            MAWWW_SyncInvisibleToggle(true)
        end)
    end
end)

RegLabel(Tabs.VisualInvisible, "Invisible Mode")
RegLabel(Tabs.VisualInvisible, "Bukan visual: karakter benar-benar dibuat tidak terlihat.")
MAWWW_InvisibleToggleRef = RegToggle(
    Tabs.VisualInvisible,
    "Invisible Mode",
    "Engine Invisible dari invisible code L2hub.",
    false,
    "Invisible",
    function(v)
        if MAWWW_InvisibleSyncing then return end
        MAWWW_SetInvisibleState(v, false)
    end
)

RegToggle(
    Tabs.VisualInvisible,
    "Hide Invisible Icon",
    "Sembunyikan tombol floating Invisible; toggle UI tetap aktif.",
    false,
    "InvisibleHideIcon",
    function(v)
        VD.InvisibleHideIcon = v == true
        MAWWW_UpdateInvisibleIconVisibility()
    end
)


if isMobile then
    task.delay(0.5, function()
        if not MAWWW_InvisibleGui then pcall(MAWWW_CreateInvisibleMobileButton) end
    end)
end

MAWWW_InvisibleCharacterConn = LocalPlayer.CharacterAdded:Connect(function()
    task.delay(1.5, function()
        if isMobile then
            pcall(MAWWW_CreateInvisibleMobileButton)
        end
        MAWWW_UpdateInvisibleIconVisibility()

        if MAWWW_InvisibleDesired and MAWWW_InvisibleModule then
            -- Reinitialize against the fresh character while keeping the user's state.
            MAWWW_EnableInvisibleRuntime(false)
            MAWWW_SyncInvisibleToggle(true)
        else
            MAWWW_InvisibleOn = false
            VD.Invisible = false
            MAWWW_UpdateInvisibleButton()
            MAWWW_SyncInvisibleToggle(false)
        end
    end)
end)

-- [NEW FROM] FIRST PERSON CAMERA (SURVIVOR)
--========================================================--
FPState = { WasSet = false, Original = nil }
function RestoreFirstPerson()
    if not FPState.WasSet then return end
    FPState.WasSet = false
    pcall(function()
        if FPState.Original then
            Player.CameraMode = FPState.Original.CameraMode or Enum.CameraMode.Classic
            Player.CameraMaxZoomDistance = FPState.Original.CameraMaxZoomDistance or 128
            Player.CameraMinZoomDistance = FPState.Original.CameraMinZoomDistance or 0.5
        else
            Player.CameraMode = Enum.CameraMode.Classic
            Player.CameraMaxZoomDistance = 128
        end
    end)
    local char = Player.Character
    if char then
        local head = char:FindFirstChild("Head")
        if head then head.LocalTransparencyModifier = 0 end
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Accessory") then
                local handle = obj:FindFirstChild("Handle")
                if handle then handle.LocalTransparencyModifier = 0 end
            end
        end
    end
    FPState.Original = nil
end
local FP_LastUpdate = 0
RunService.RenderStepped:Connect(function()
    local now = os.clock()
    if now - FP_LastUpdate < 0.08 then return end
    FP_LastUpdate = now
    pcall(function()
        if VD.FirstPersonCamera then
            local isSurvivor = Player.Team and Player.Team.Name == "Survivors"
            if isSurvivor then
                if not FPState.WasSet then
                    FPState.Original = {
                        CameraMode = Player.CameraMode,
                        CameraMaxZoomDistance = Player.CameraMaxZoomDistance,
                        CameraMinZoomDistance = Player.CameraMinZoomDistance,
                    }
                end
                if Player.CameraMode ~= Enum.CameraMode.LockFirstPerson then
                    Player.CameraMode = Enum.CameraMode.LockFirstPerson
                end
                if Player.CameraMaxZoomDistance ~= 0 then
                    Player.CameraMaxZoomDistance = 0
                end
                local char = Player.Character
                if char then
                    local head = char:FindFirstChild("Head")
                    if head then head.LocalTransparencyModifier = 1 end
                    for _, obj in ipairs(char:GetChildren()) do
                        if obj:IsA("Accessory") then
                            local handle = obj:FindFirstChild("Handle")
                            if handle then handle.LocalTransparencyModifier = 1 end
                        end
                    end
                end
                FPState.WasSet = true
            elseif FPState.WasSet then
                RestoreFirstPerson()
            end
        elseif FPState.WasSet then
            RestoreFirstPerson()
        end
    end)
end)
RegToggle(Tabs.VisualCamera, "First Person Camera (Survivor)", "Paksa kamera first person", false, "FirstPersonCamera", function(v)
    if not v then RestoreFirstPerson() end
end)

--========================================================--
-- VAULT AUTOMATION
-- Fast Vault is the single active vault engine in the UI.
--========================================================--

--========================================================--
-- [NEW] FAST VAULT — Full Implementation
-- Remotes:
--   VaultEvent, Vaultbindable, fastvault,
--   VaultCompleteEventpart1, VaultCompleteEvent
--========================================================--
FastVault = FastVault or {
    _vaultedCache = {},
    _lastScan = 0,
    _scanCooldown = 0.08,
    _lastFire = 0,
    _fireCooldown = 0.45,
    _vaultRadius = tonumber(VD.FastVaultRadius) or 8,
    _instantMode = VD.FastVaultInstant == true,
    _speedMult = tonumber(VD.FastVaultSpeedMult) or 1.0,
    _activeTrack = nil,
    _lastInstant = 0,
}

VAULT_ANIM_IDS = {
    "rbxassetid://74705617908505",
    "rbxassetid://80552139463944",
    "rbxassetid://96328361165090",
}

function FastVault_GetRemotes()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local window = remotes and remotes:FindFirstChild("Window")
    if not window then return nil end

    return {
        VaultEvent = window:FindFirstChild("VaultEvent"),
        VaultBindable = window:FindFirstChild("Vaultbindable"),
        FastVaultRemote = window:FindFirstChild("fastvault"),
        VaultComplete1 = window:FindFirstChild("VaultCompleteEventpart1"),
        VaultComplete = window:FindFirstChild("VaultCompleteEvent"),
    }
end

function FastVault_GetPosition(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then
        return obj.Position
    end
    if obj:IsA("Model") then
        if obj.PrimaryPart then
            return obj.PrimaryPart.Position
        end
        local bp = obj:FindFirstChildWhichIsA("BasePart", true)
        return bp and bp.Position or nil
    end
    return nil
end

function FastVault_FindRootWindow(vt)
    if not vt then return nil end
    local node = vt
    for _ = 1, 4 do
        if not node or not node.Parent then
            return nil
        end
        if node:IsA("Model") and node.Name == "Window" then
            return node
        end
        node = node.Parent
    end
    return vt.Parent
end

function FastVault_ScanWindows()
    local groups = {}
    local map = Workspace:FindFirstChild("Map") or Workspace

    for _, obj in ipairs(map:GetDescendants()) do
        if obj:IsA("BasePart")
            and (obj.Name == "VaultTrigger"
                or obj.Name == "VaultPoint"
                or obj.Name == "WindowVault") then
            local root = FastVault_FindRootWindow(obj)
            if root then
                groups[root] = groups[root] or {}
                table.insert(groups[root], obj)
            end
        end
    end

    return groups
end

function FastVault_FireRemote(targetPart, rootWindow)
    local R = FastVault_GetRemotes()
    if not R or not targetPart then return false end

    local now = tick()
    if now - (FastVault._lastFire or 0) < (FastVault._fireCooldown or 0.45) then
        return false
    end
    FastVault._lastFire = now

    local fired = false

    if R.VaultEvent and R.VaultEvent:IsA("RemoteEvent") then
        pcall(function()
            R.VaultEvent:FireServer(targetPart, true)
        end)
        fired = true
    end

    if R.VaultBindable and R.VaultBindable:IsA("BindableEvent") then
        pcall(function()
            R.VaultBindable:Fire(targetPart, true)
        end)
    end

    if R.FastVaultRemote and R.FastVaultRemote:IsA("RemoteEvent") then
        pcall(function()
            R.FastVaultRemote:FireServer(Player)
        end)
    end

    if R.VaultComplete1 and R.VaultComplete1:IsA("RemoteEvent") then
        pcall(function()
            R.VaultComplete1:FireServer()
        end)
    end

    if R.VaultComplete and R.VaultComplete:IsA("RemoteEvent") then
        pcall(function()
            R.VaultComplete:FireServer(targetPart, false)
        end)
    end

    if rootWindow then
        FastVault._vaultedCache[rootWindow] = now
    end

    return fired
end

function FastVault_ApplyAnimSpeed(mult)
    local char = Player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end

    pcall(function()
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            local id = track.Animation and track.Animation.AnimationId or ""
            local lowerId = string.lower(id)
            local isKnownVaultAnim = false
            for _, vaultId in ipairs(VAULT_ANIM_IDS) do
                if id == vaultId then
                    isKnownVaultAnim = true
                    break
                end
            end
            if isKnownVaultAnim
                or lowerId:find("vault", 1, true)
                or lowerId:find("climb", 1, true)
                or lowerId:find("window", 1, true) then
                track:AdjustSpeed(math.clamp(tonumber(mult) or 1, 1, 5))
                FastVault._activeTrack = track
            end
        end
    end)
end

task.spawn(function()
    while not VD.Destroyed do
        if not VD.FastVaultEnabled then
            task.wait(0.2)
        elseif GetRole() ~= "Survivor" then
            task.wait(0.2)
        else
            local now = tick()
            if now - (FastVault._lastScan or 0) < (FastVault._scanCooldown or 0.08) then
                task.wait(0.03)
            else
                FastVault._lastScan = now

                local speedMult = tonumber(FastVault._speedMult) or 1
                if speedMult ~= 1 then
                    pcall(function()
                        local char = Player.Character
                        if char then
                            char:SetAttribute("vaultspeed", speedMult)
                        end
                    end)
                end

                if not FastVault._instantMode then
                    FastVault_ApplyAnimSpeed(speedMult * 1.5)
                end

                local char = Player.Character
                local myRoot = char and char:FindFirstChild("HumanoidRootPart")
                local myHum = char and char:FindFirstChildOfClass("Humanoid")

                if myRoot and myHum and myHum.Health > 0 then
                    local groups = FastVault_ScanWindows()
                    local bestPart, bestRoot, bestDist = nil, nil, FastVault._vaultRadius or 8

                    for rootWindow, parts in pairs(groups) do
                        local lastUsed = FastVault._vaultedCache[rootWindow] or 0
                        if tick() - lastUsed > 1.5 then
                            for _, p in ipairs(parts) do
                                local pos = FastVault_GetPosition(p)
                                if pos then
                                    local d = (myRoot.Position - pos).Magnitude
                                    if d < bestDist then
                                        bestDist = d
                                        bestPart = p
                                        bestRoot = rootWindow
                                    end
                                end
                            end
                        end
                    end

                    if bestPart and bestRoot then
                        FastVault_FireRemote(bestPart, bestRoot)

                        if FastVault._instantMode then
                            local targetPos = FastVault_GetPosition(bestPart)
                            if targetPos then
                                pcall(function()
                                    local orig = myRoot.CFrame
                                    -- [FIXED] Offset 1 stud dan cooldown agar tidak teleport berulang.
                                    local now = tick()
                                    if FastVault._lastInstant and now - FastVault._lastInstant < 0.8 then
                                        return
                                    end
                                    FastVault._lastInstant = now

                                    myRoot.CFrame = CFrame.new(targetPos + Vector3.new(0, 1, 0))
                                    task.wait(0.05)

                                    local R = FastVault_GetRemotes()
                                    if R and R.VaultComplete then
                                        pcall(function()
                                            R.VaultComplete:FireServer(bestPart, false)
                                        end)
                                    end

                                    task.wait(0.05)
                                    if myRoot and myRoot.Parent then
                                        myRoot.CFrame = orig
                                    end
                                end)
                            end
                        end
                    end
                end

                task.wait(0.05)
            end
        end
    end
end)

-- Manual Fast Vault hotkey: V
pcall(function()
    local genv = getgenv and getgenv() or _G
    if genv and genv.MAWWW_FastVaultInputConn then
        pcall(function()
            genv.MAWWW_FastVaultInputConn:Disconnect()
        end)
        genv.MAWWW_FastVaultInputConn = nil
    end

    if genv then
        genv.MAWWW_FastVaultInputConn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode ~= Enum.KeyCode.V then return end
            if not VD.FastVaultEnabled then return end
            if GetRole() ~= "Survivor" then return end

            local char = Player.Character
            local myRoot = char and char:FindFirstChild("HumanoidRootPart")
            if not myRoot then return end

            local groups = FastVault_ScanWindows()
            local bestPart, bestRoot, bestDist = nil, nil, FastVault._vaultRadius or 8

            for rootWindow, parts in pairs(groups) do
                for _, p in ipairs(parts) do
                    local pos = FastVault_GetPosition(p)
                    if pos then
                        local d = (myRoot.Position - pos).Magnitude
                        if d < bestDist then
                            bestDist = d
                            bestPart = p
                            bestRoot = rootWindow
                        end
                    end
                end
            end

            if bestPart and bestRoot then
                FastVault._lastFire = 0
                FastVault_FireRemote(bestPart, bestRoot)
                notify("Fast Vault", "Manual vault fired!", 1)
            else
                notify("Fast Vault", "Tidak ada vault dalam radius.", 1)
            end
        end)
    end
end)

--========================================================--
-- UI: FAST VAULT
--========================================================--
RegDivider(Tabs.SurvivalVault)
RegLabel(Tabs.SurvivalVault, "Vault Automation")

RegToggle(
    Tabs.SurvivalVault,
    "Fast Vault",
    "Auto-detect vault terdekat dan fire remote vault.",
    false,
    "FastVaultEnabled",
    function(v)
        if v then
            notify(
                "Fast Vault",
                "ON — Auto fire aktif (radius "
                    .. tostring(FastVault._vaultRadius or 8) .. " studs)",
                3
            )
        else
            pcall(function()
                local char = Player.Character
                if char then
                    char:SetAttribute("vaultspeed", 1)
                end
            end)
            notify("Fast Vault", "OFF", 2)
        end
    end
)

RegSlider(
    Tabs.SurvivalVault,
    "Fast Vault Radius",
    "Jarak maksimum deteksi vault.",
    8, 3, 20, 1,
    "FastVaultRadius",
    function(v)
        FastVault._vaultRadius = tonumber(v) or 8
    end
)

RegSlider(
    Tabs.SurvivalVault,
    "Fast Vault Speed Multiplier",
    "Pengali kecepatan animasi vault.",
    2.0, 1, 5, 0.25,
    "FastVaultSpeedMult",
    function(v)
        FastVault._speedMult = tonumber(v) or 1
    end
)

RegToggle(
    Tabs.SurvivalVault,
    "Instant Vault Commit",
    "Mode instant dengan commit tambahan setelah teleport.",
    false,
    "FastVaultInstant",
    function(v)
        FastVault._instantMode = v == true
        notify("Fast Vault", v and "INSTANT MODE aktif" or "Mode normal", 2)
    end
)

RegButton(
    Tabs.SurvivalVault,
    "Reset Fast Vault State",
    "Bersihkan cache vault dan reset attribute.",
    function()
        FastVault._vaultedCache = {}
        FastVault._lastFire = 0
        FastVault._lastScan = 0
        pcall(function()
            local char = Player.Character
            if char then
                char:SetAttribute("vaultspeed", 1)
            end
        end)
        notify("Fast Vault", "State di-reset.", 2)
    end
)

--========================================================--
-- PALLET REFLEX
--========================================================--
RegDivider(Tabs.SurvivalVault)
RegLabel(Tabs.SurvivalVault, "Pallet Reflex")
RegToggle(Tabs.SurvivalVault, "Pallet Reflex", "Auto drop pallet saat killer dekat (reflex)", false, "PalletReflex")
RegSlider(Tabs.SurvivalVault, "Pallet Reflex Range", "Radius reflex", 20, 5, 50, 1, "PalletReflexRange")

_lastPalletDrop = 0
_lastPalletScan = 0
_usedPallets    = {}
RunService.Heartbeat:Connect(function()
    if not VD.PalletReflex then return end
    if GetRole() ~= "Survivor" then return end
    if tick() - _lastPalletScan < 0.2 then return end
    _lastPalletScan = tick()
    if tick() - _lastPalletDrop < 2.5 then return end
    pcall(function()
        local char   = Player.Character
        local myRoot = char and char:FindFirstChild("HumanoidRootPart")
        local hum    = char and char:FindFirstChildOfClass("Humanoid")
        if not myRoot or not hum or hum.Health <= 0 then return end
        local killerRoot = nil
        for _, plr in ipairs(MawwwGetPlayers()) do
            if plr ~= Player and IsKiller(plr) and plr.Character then
                local kr = plr.Character:FindFirstChild("HumanoidRootPart")
                if kr then killerRoot = kr; break end
            end
        end
        if not killerRoot then return end
        if (myRoot.Position - killerRoot.Position).Magnitude > (VD.PalletReflexRange or 20) then return end
        local remotes    = ReplicatedStorage:FindFirstChild("Remotes")
        local palletFold = remotes and remotes:FindFirstChild("Pallet")
        local dropEvent  = palletFold and palletFold:FindFirstChild("PalletDropEvent")
        if not dropEvent then return end
        local bestPalletwrong, bestDist = nil, 8
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "Palletwrong" and (obj:IsA("Model") or obj:IsA("Folder")) and not _usedPallets[obj] then
                local refPart = obj:FindFirstChild("PalletPoint") or obj:FindFirstChild("PalletPointSlide")
                if refPart and refPart:IsA("BasePart") then
                    local d = (myRoot.Position - refPart.Position).Magnitude
                    if d < bestDist then bestDist = d; bestPalletwrong = obj end
                end
            end
        end
        if bestPalletwrong then
            local fireTarget = bestPalletwrong:FindFirstChild("PalletPointSlide") or bestPalletwrong:FindFirstChild("PalletPoint")
            if fireTarget then
                pcall(function() dropEvent:FireServer(fireTarget) end)
                _usedPallets[bestPalletwrong] = true
                _lastPalletDrop = tick()
            end
        end
    end)
end)

--========================================================--
-- KNOCKDOWN RECOVERY
-- Anti Knockdown below is the single recovery control.
--========================================================--

--========================================================--
-- [NEW FROM] FAKE PERKS (Flowstate, Quick Recovery, Perfect Landing, Adrenaline Rush)
--========================================================--
RegDivider(Tabs.SurvivalFake)

RegLabel(Tabs.SurvivalFake, "Fake Perks")

FP = { Conns = {}, ActiveBuffs = {}, HB = nil, LastBuffEnd = 0, CooldownTime = 10 }
function FP_Char() return Player.Character end
function FP_Hum()
    local c = FP_Char()
    return c and c:FindFirstChildOfClass("Humanoid")
end
function FP_GetTotalSpeedBuff()
    local total = 0
    for _, b in pairs(FP.ActiveBuffs) do
        if tick() < b.endTime then total = total + b.amt end
    end
    return total
end
function FP_ApplySpeedToCharacter()
    local char = FP_Char()
    local hum = FP_Hum()
    local totalBuff = FP_GetTotalSpeedBuff()
    if char then
        if totalBuff > 0 then
            char:SetAttribute("speedboost", 1 + (totalBuff / 14))
        else
            char:SetAttribute("speedboost", 1)
        end
    end
    if hum and totalBuff > 0 then hum.WalkSpeed = 16 + totalBuff end
end
function FP_EnsureHB()
    if FP.HB then return end
    FP.HB = RunService.Heartbeat:Connect(function()
        local expired = {}
        for name, b in pairs(FP.ActiveBuffs) do
            if tick() >= b.endTime then table.insert(expired, name) end
        end
        for _, name in ipairs(expired) do FP.ActiveBuffs[name] = nil end
        if #expired > 0 and FP_GetTotalSpeedBuff() <= 0 then FP.LastBuffEnd = tick() end
        FP_ApplySpeedToCharacter()
        if next(FP.ActiveBuffs) == nil then
            if FP.HB then FP.HB:Disconnect(); FP.HB = nil end
            local char = FP_Char()
            if char then char:SetAttribute("speedboost", 1) end
        end
    end)
end
function FP_TryBuff(name, amt, dur)
    if FP.ActiveBuffs[name] then return end
    if tick() - FP.LastBuffEnd < FP.CooldownTime and next(FP.ActiveBuffs) == nil then return end
    FP.ActiveBuffs[name] = { amt = amt, endTime = tick() + dur }
    FP_ApplySpeedToCharacter()
    FP_EnsureHB()
    notify("Fake Perks", "[" .. name .. "] Aktif! +" .. amt .. " Speed (" .. dur .. "s)", 3)
end
function FP_Clean(name)
    if FP.Conns[name] then
        for _, c in ipairs(FP.Conns[name]) do pcall(function() c:Disconnect() end) end
        FP.Conns[name] = nil
    end
end
function FP_Reg(name, conn)
    if not FP.Conns[name] then FP.Conns[name] = {} end
    table.insert(FP.Conns[name], conn)
end

RegSlider(Tabs.SurvivalFake, "Fake Perk Cooldown", "Cooldown semua fake perk", 10, 0, 60, 1, "FP_Cooldown", function(v) FP.CooldownTime = v end)

-- Flowstate
RegToggle(Tabs.SurvivalFake, "Fake Flowstate", "+5 speed 3s setelah vault/slide", false, "FP_Flowstate", function(val)
    if val then
        local r = ReplicatedStorage:FindFirstChild("Remotes")
        local w = r and r:FindFirstChild("Window")
        local p = r and r:FindFirstChild("Pallet")
        local function onVaultAction()
            if not VD.FP_Flowstate then return end
            task.delay(0.5, function()
                if VD.FP_Flowstate then FP_TryBuff("Flowstate", 5, 3) end
            end)
        end
        if w then
            local vb = w:FindFirstChild("Vaultbindable")
            if vb and vb:IsA("BindableEvent") then FP_Reg("Flowstate", vb.Event:Connect(onVaultAction)) end
        end
        if p then
            local sb = p:FindFirstChild("Slidebindable")
            if sb and sb:IsA("BindableEvent") then FP_Reg("Flowstate", sb.Event:Connect(onVaultAction)) end
        end
    else
        FP_Clean("Flowstate"); FP.ActiveBuffs["Flowstate"] = nil
    end
end)

-- Quick Recovery
RegToggle(Tabs.SurvivalFake, "Fake Quick Recovery", "+6 speed 3s setelah di-heal", false, "FP_QuickRecovery", function(val)
    if val then
        local function onHealed()
            if not VD.FP_QuickRecovery then return end
            FP_TryBuff("QuickRecovery", 6, 3)
        end
        local r = ReplicatedStorage:FindFirstChild("Remotes")
        local healFolder = r and r:FindFirstChild("Healing")
        if healFolder then
            local hd = healFolder:FindFirstChild("Healdone")
            if hd and hd:IsA("BindableEvent") then FP_Reg("QuickRecovery", hd.Event:Connect(onHealed)) end
            local scv = healFolder:FindFirstChild("Skillcheckvalidated")
            if scv and scv:IsA("BindableEvent") then FP_Reg("QuickRecovery", scv.Event:Connect(onHealed)) end
        end
        local function hookHealth(c)
            if not c then return end
            local hum = c:FindFirstChildOfClass("Humanoid")
            if hum then
                local lastHP = hum.Health
                local conn = hum.HealthChanged:Connect(function(newHP)
                    if not VD.FP_QuickRecovery then return end
                    if newHP > lastHP and (newHP >= hum.MaxHealth or (newHP - lastHP) >= 15) then onHealed() end
                    lastHP = newHP
                end)
                FP_Reg("QuickRecovery", conn)
            end
        end
        hookHealth(Player.Character)
        FP_Reg("QuickRecovery", Player.CharacterAdded:Connect(hookHealth))
    else
        FP_Clean("QuickRecovery"); FP.ActiveBuffs["QuickRecovery"] = nil
    end
end)

-- Perfect Landing
RegToggle(Tabs.SurvivalFake, "Fake Perfect Landing", "+8 speed 3s setelah landing", false, "FP_PerfectLanding", function(val)
    if val then
        local function hookFall(c)
            if not c then return end
            local hum = c:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            local wasFalling = false
            local fallStart = 0
            local conn = hum.StateChanged:Connect(function(old, new)
                if not VD.FP_PerfectLanding then return end
                if new == Enum.HumanoidStateType.Freefall then
                    wasFalling = true; fallStart = tick()
                end
                if wasFalling and (new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running) then
                    local fallTime = tick() - fallStart
                    wasFalling = false
                    if fallTime >= 0.25 then FP_TryBuff("PerfectLanding", 8, 3) end
                end
            end)
            FP_Reg("PerfectLanding", conn)
        end
        hookFall(Player.Character)
        FP_Reg("PerfectLanding", Player.CharacterAdded:Connect(hookFall))
    else
        FP_Clean("PerfectLanding"); FP.ActiveBuffs["PerfectLanding"] = nil
    end
end)

-- Adrenaline Rush
RegToggle(Tabs.SurvivalFake, "Fake Adrenaline Rush", "+4 speed 5s saat HP drop <=50", false, "FP_AdrenalineRush", function(val)
    if val then
        local function hookDamage(c)
            if not c then return end
            local hum = c:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            local lastHP = hum.Health
            local conn = hum.HealthChanged:Connect(function(newHP)
                if not VD.FP_AdrenalineRush then return end
                if newHP < lastHP and newHP <= 50 and newHP > 0 then FP_TryBuff("AdrenalineRush", 4, 5) end
                lastHP = newHP
            end)
            FP_Reg("AdrenalineRush", conn)
        end
        hookDamage(Player.Character)
        FP_Reg("AdrenalineRush", Player.CharacterAdded:Connect(hookDamage))
    else
        FP_Clean("AdrenalineRush"); FP.ActiveBuffs["AdrenalineRush"] = nil
    end
end)

--========================================================--
-- [NEW FROM] FAKE GENERATOR
--========================================================--
RegDivider(Tabs.SurvivalFake)
RegLabel(Tabs.SurvivalFake, "Fake Generator")

getgenv().MAWWW_FakeGenTrack = nil
function VD_ToggleFakeGen()
    if not VD.FakeGenEnabled then
        if getgenv().MAWWW_FakeGenTrack then
            pcall(function() getgenv().MAWWW_FakeGenTrack:Stop() end)
            getgenv().MAWWW_FakeGenTrack = nil
        end
        return
    end
    if getgenv().MAWWW_FakeGenTrack then
        pcall(function() getgenv().MAWWW_FakeGenTrack:Stop() end)
        getgenv().MAWWW_FakeGenTrack = nil
    else
        pcall(function()
            local char = Player.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            local animator = hum:FindFirstChildOfClass("Animator")
            if not animator then animator = Instance.new("Animator"); animator.Parent = hum end
            local animation = Instance.new("Animation")
            animation.AnimationId = "rbxassetid://83160743983246"
            local track = animator:LoadAnimation(animation)
            track.Looped = true
            track.Priority = Enum.AnimationPriority.Action
            track:Play()
            getgenv().MAWWW_FakeGenTrack = track
        end)
    end
end

FakeGenButtonState = { UI=nil, Button=nil, DragLocked=false, Dragging=false, DragStart=nil, DragStartPos=nil }
function setupFakeGenBtn()
    local oldUI = PlayerGui:FindFirstChild("FakeGenUI")
    if oldUI then oldUI:Destroy() end
    FakeGenButtonState.UI = Instance.new("ScreenGui")
    FakeGenButtonState.UI.Name = "FakeGenUI"
    FakeGenButtonState.UI.ResetOnSpawn = false
    FakeGenButtonState.UI.IgnoreGuiInset = true
    FakeGenButtonState.UI.Parent = PlayerGui
    local btn = Instance.new("ImageButton")
    btn.Name = "FakeGenButton"
    btn.Size = UDim2.new(0, 60, 0, 60)
    btn.Position = UDim2.new(0.4, 0, 0.75, 0)
    btn.AnchorPoint = Vector2.new(0.5, 0.5)
    btn.BackgroundColor3 = Color3.fromRGB(20, 30, 0)
    btn.BackgroundTransparency = 0.15
    btn.Visible = VD.FakeGenEnabled
    btn.ZIndex = 10
    btn.Parent = FakeGenButtonState.UI
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
    local s = Instance.new("UIStroke", btn); s.Color = Color3.fromRGB(150, 255, 70); s.Thickness = 2; s.Transparency = 0.2
    local lbl = Instance.new("TextLabel", btn)
    lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
    lbl.Text = "FAKE\nGEN"; lbl.TextColor3 = Color3.fromRGB(200, 255, 150)
    lbl.TextScaled = true; lbl.Font = Enum.Font.GothamBlack; lbl.ZIndex = 11
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if FakeGenButtonState.DragLocked then return end
            FakeGenButtonState.Dragging = true
            FakeGenButtonState.DragStart = input.Position
            FakeGenButtonState.DragStartPos = btn.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if FakeGenButtonState.Dragging and not FakeGenButtonState.DragLocked and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - FakeGenButtonState.DragStart
            btn.Position = UDim2.new(FakeGenButtonState.DragStartPos.X.Scale, FakeGenButtonState.DragStartPos.X.Offset + delta.X, FakeGenButtonState.DragStartPos.Y.Scale, FakeGenButtonState.DragStartPos.Y.Offset + delta.Y)
        end
    end)
    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            FakeGenButtonState.Dragging = false
        end
    end)
    btn.MouseButton1Click:Connect(VD_ToggleFakeGen)
    FakeGenButtonState.Button = btn
end
RegToggle(Tabs.SurvivalFake, "Fake Generator", "Animasi fake gen (Press B)", false, "FakeGenEnabled", function(v)
    setupFakeGenBtn()
    if FakeGenButtonState.Button then FakeGenButtonState.Button.Visible = v end
end)
Player.CharacterAdded:Connect(function()
    if getgenv().MAWWW_FakeGenTrack then pcall(function() getgenv().MAWWW_FakeGenTrack:Stop() end); getgenv().MAWWW_FakeGenTrack = nil end
    task.wait(0.5)
    setupFakeGenBtn()
    if FakeGenButtonState.Button then FakeGenButtonState.Button.Visible = VD.FakeGenEnabled end
end)
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.B then VD_ToggleFakeGen() end
end)

--========================================================--
-- [NEW FROM] AURA HEAL
--========================================================--
InstantHealConn = nil
AutoHealAllConn = nil
function doSelfHealTrue()
    local char = Player.Character; if not char then return end
    local healRemote = ReplicatedStorage.Remotes.Healing.HealEvent
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    pcall(function() healRemote:FireServer(hrp, true) end)
end
function doSelfHealFalse()
    local char = Player.Character; if not char then return end
    local healRemote = ReplicatedStorage.Remotes.Healing.HealEvent
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    pcall(function() healRemote:FireServer(hrp, false) end)
end
function doOthersHealTrue(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart"); if not targetHRP then return end
    local healRemote = ReplicatedStorage.Remotes.Healing.HealEvent
    pcall(function() healRemote:FireServer(targetHRP, true) end)
end
function doOthersHealFalse(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart"); if not targetHRP then return end
    local healRemote = ReplicatedStorage.Remotes.Healing.HealEvent
    pcall(function() healRemote:FireServer(targetHRP, false) end)
end
function setInstantHealSelf(v)
    if v then
        local healActive = false
        if InstantHealConn then InstantHealConn:Disconnect() end
        InstantHealConn = RunService.Heartbeat:Connect(function()
            if not VD.InstantHealSelf then return end
            local myChar = Player.Character
            local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
            if not myHum then return end
            if myHum.Health >= myHum.MaxHealth * 0.9 then
                if healActive then healActive = false; doSelfHealFalse() end
                return
            end
            if healActive then
                local ci = myChar:FindFirstChild("CheckInterractable")
                if ci and not ci:GetAttribute("isHealing") then healActive = false end
            end
            if not healActive then healActive = true; doSelfHealTrue() end
        end)
    else
        if InstantHealConn then InstantHealConn:Disconnect(); InstantHealConn = nil end
        pcall(doSelfHealFalse)
    end
end
function setAutoHealAll(v)
    if v then
        local activeHeals = {}
        if AutoHealAllConn then AutoHealAllConn:Disconnect() end
        AutoHealAllConn = RunService.Heartbeat:Connect(function()
            if not VD.AutoHealAll then return end
            for _, player in ipairs(MawwwGetPlayers()) do
                if player ~= Player and player.Character then
                    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    local hum = player.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 and hum.Health < hum.MaxHealth * 0.9 and hrp then
                        if not activeHeals[player] then activeHeals[player] = true; doOthersHealTrue(player) end
                    else
                        if activeHeals[player] then activeHeals[player] = nil; doOthersHealFalse(player) end
                    end
                elseif activeHeals[player] then
                    activeHeals[player] = nil
                    pcall(function() doOthersHealFalse(player) end)
                end
            end
        end)
    else
        if AutoHealAllConn then AutoHealAllConn:Disconnect(); AutoHealAllConn = nil end
    end
end
RegDivider(Tabs.SurvivalEscape)
RegLabel(Tabs.SurvivalEscape, "Self Unhook")
RegToggle(Tabs.SurvivalEscape, "Self Unhook Bypass", "Automatically run the K4N3K1 self-unhook routine when hooked", false, "BypassSelfUnhook", function(v)
    local api = getgenv().MAWWW_K4N3K1
    if api and api.SetSelfUnhook then
        api.SetSelfUnhook(v)
    else
        VD.BypassSelfUnhook = v
    end
    notify("Bypass Self Unhook", v and "Enabled" or "Disabled", 2)
end)
RegSlider(Tabs.SurvivalEscape, "Unhook Follow Duration", "How long to stay in the source routine", 30, 5, 120, 5, "SelfUnhookFollowDuration", function(v)
    local api = getgenv().MAWWW_K4N3K1
    if api and api.SetSelfUnhookFollowDuration then api.SetSelfUnhookFollowDuration(v) end
end)
RegSlider(Tabs.SurvivalEscape, "Unhook Follow Distance", "Distance below the killer while following", 20, 5, 60, 1, "SelfUnhookFollowDistance", function(v)
    local api = getgenv().MAWWW_K4N3K1
    if api and api.SetSelfUnhookFollowDistance then api.SetSelfUnhookFollowDistance(v) end
end)

RegLabel(Tabs.SurvivalEscape, "Aura Heal")
RegToggle(Tabs.SurvivalEscape, "Heal Self", "Instant heal self (Mawww Hub style)", false, "InstantHealSelf", function(v)
    setInstantHealSelf(v)
end)
RegToggle(Tabs.SurvivalEscape, "Heal All Survivors", "Instant heal semua survivor", false, "AutoHealAll", function(v)
    setAutoHealAll(v)
end)

--========================================================--
-- [NEW FROM Mawww Hub] KORLESS MORPH
--========================================================--
KorlessMorph = { Connection = nil }
function ApplyKorless()
    local function Morph()
        repeat task.wait() until Player.Character
            and Player.Character:FindFirstChild("HumanoidRootPart")
            and Player.Character:FindFirstChild("Right Leg")
        task.wait(0.1)
        local char = Player.Character
        pcall(function()
            char.Head.Transparency = 1
            local face = char.Head:FindFirstChild("face")
            if face then face:Destroy() end
            char["Right Leg"].Transparency = 1
            local mesh = Instance.new("MeshPart")
            mesh.Name = "KorlessHead"
            mesh.Size = Vector3.new(1.5, 1.5, 1.5)
            mesh.CanCollide = false
            mesh.MeshId = "rbxassetid://902942096"
            mesh.TextureID = "rbxassetid://902843398"
            mesh.CFrame = char["Right Leg"].CFrame * CFrame.new(0, 0.5, 0)
            mesh.Parent = char
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = char["Right Leg"]
            weld.Part1 = mesh
            weld.Parent = mesh
        end)
    end
    Morph()
    if KorlessMorph.Connection then KorlessMorph.Connection:Disconnect() end
    KorlessMorph.Connection = Player.CharacterAdded:Connect(function() task.wait(1); Morph() end)
end
RegLabel(Tabs.Avatar, "Korless Morph")
RegButton(Tabs.Avatar, "Apply Korless", "Morph korless ke karakter", function()
    ApplyKorless()
    notify("Korless Morph", "Applied successfully!", 3)
end)
RegButton(Tabs.Avatar, "Reset Korless", "Reset korless morph", function()
    if KorlessMorph.Connection then pcall(function() KorlessMorph.Connection:Disconnect() end); KorlessMorph.Connection = nil end
    pcall(function()
        local kh = Player.Character and Player.Character:FindFirstChild("KorlessHead")
        if kh then kh:Destroy() end
    end)
    notify("Korless Morph", "Direset!", 3)
end)

--========================================================--
-- [NEW FROM Mawww Hub] COPY AVATAR
--========================================================--
RegLabel(Tabs.Avatar, "Copy Avatar")

selectedAvatarPlayer = nil
copyAvatarDropdown = RegDropdown(Tabs.Avatar, "Select Player to Copy", "Pilih player yang ingin dicopy avatarnya", (function()
    local list = {}
    for _, p in ipairs(MawwwGetPlayers()) do if p ~= Player then table.insert(list, p.Name) end end
    if #list == 0 then table.insert(list, "No players") end
    return list
end)(), "No players", false, "CopyAvatarTarget", function(v) selectedAvatarPlayer = v end)

originalAvatarCache = {}
originalAvatarSaved = false
originalHeadMeshScale = nil
standardParts = {
    Head=true, Torso=true, ["Left Arm"]=true, ["Right Arm"]=true, ["Left Leg"]=true, ["Right Leg"]=true, HumanoidRootPart=true,
    UpperTorso=true, LowerTorso=true, LeftUpperArm=true, LeftLowerArm=true, LeftHand=true,
    RightUpperArm=true, RightLowerArm=true, RightHand=true, LeftUpperLeg=true, LeftLowerLeg=true,
    LeftFoot=true, RightUpperLeg=true, RightLowerLeg=true, RightFoot=true
}
function AddAccessoryLocal(char, accessory)
    local handle = accessory:FindFirstChild("Handle")
    if not handle then return end
    local accAtt = nil
    for _, v in ipairs(handle:GetChildren()) do
        if v:IsA("Attachment") then accAtt = v; break end
    end
    if not accAtt then return end
    local charAtt, targetPart = nil, nil
    local fh = char:FindFirstChild("FakeCopiedHead")
    if fh then
        local att = fh:FindFirstChild(accAtt.Name)
        if att and att:IsA("Attachment") then charAtt = att; targetPart = fh end
    end
    if not charAtt then
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "FakeCopiedHead" then
                local att = part:FindFirstChild(accAtt.Name)
                if att and att:IsA("Attachment") then charAtt = att; targetPart = part; break end
            end
        end
    end
    if not charAtt then return end
    for _, v in ipairs(handle:GetChildren()) do
        if v:IsA("JointInstance") or v:IsA("WeldConstraint") or v:IsA("Constraint") or v:IsA("Script") or v:IsA("LocalScript") then
            v:Destroy()
        end
    end
    accessory.Parent = char
    local weld = Instance.new("Weld")
    weld.Name = "AccessoryWeld"
    weld.Part0 = handle; weld.Part1 = targetPart
    weld.C0 = accAtt.CFrame; weld.C1 = charAtt.CFrame
    weld.Parent = handle
end
function SaveOriginalAvatar()
    if originalAvatarSaved then return end
    local char = Player.Character; if not char then return end
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Accessory") or obj:IsA("Hat") or obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") or obj:IsA("CharacterMesh") or obj:IsA("BodyColors") then
            table.insert(originalAvatarCache, obj:Clone())
        elseif obj:IsA("BasePart") and not standardParts[obj.Name] and obj.Name ~= "FakeCopiedHead" then
            table.insert(originalAvatarCache, obj:Clone())
        end
    end
    local head = char:FindFirstChild("Head")
    if head then
        local sm = head:FindFirstChildOfClass("SpecialMesh")
        if sm then originalHeadMeshScale = sm.Scale end
        for _, v in ipairs(head:GetChildren()) do
            if v:IsA("Decal") or v:IsA("Texture") then table.insert(originalAvatarCache, v:Clone()) end
        end
    end
    originalAvatarSaved = true
end
function ApplyTargetAvatar(targetChar)
    local myChar = Player.Character
    if not myChar or not targetChar then return false end
    for _, obj in ipairs(myChar:GetChildren()) do
        if obj:IsA("Accessory") or obj:IsA("Hat") or obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") or obj:IsA("CharacterMesh") or obj:IsA("BodyColors") then
            obj:Destroy()
        elseif obj:IsA("BasePart") and not standardParts[obj.Name] and obj.Name ~= "FakeCopiedHead" then
            obj:Destroy()
        end
    end
    local myHead = myChar:FindFirstChild("Head")
    if myHead then
        for _, v in ipairs(myHead:GetChildren()) do
            if v:IsA("Decal") or v:IsA("Texture") then v:Destroy() end
        end
    end
    local targetHead = targetChar:FindFirstChild("Head")
    if targetHead and myHead then
        myHead.Transparency = 1
        local oldFake = myChar:FindFirstChild("FakeCopiedHead")
        if oldFake then oldFake:Destroy() end
        local fakeHead = targetHead:Clone()
        fakeHead.Name = "FakeCopiedHead"
        fakeHead.CanCollide = false; fakeHead.Massless = true
        local targetBc = targetChar:FindFirstChildOfClass("BodyColors")
        if targetBc then fakeHead.Color = targetBc.HeadColor3 else fakeHead.Color = targetHead.Color end
        local mySm = myHead:FindFirstChildOfClass("SpecialMesh")
        if mySm then mySm.Scale = Vector3.new(0, 0, 0) end
        myHead.LocalTransparencyModifier = 1
        for _, v in ipairs(fakeHead:GetChildren()) do
            if v:IsA("Motor6D") or v:IsA("Weld") or v:IsA("WeldConstraint") or v:IsA("Script") or v:IsA("LocalScript") then v:Destroy() end
        end
        fakeHead.Parent = myChar
        local hw = Instance.new("Weld")
        hw.Name = "FakeHeadWeld"
        hw.Part0 = myHead; hw.Part1 = fakeHead
        hw.C0 = CFrame.new(); hw.C1 = CFrame.new()
        hw.Parent = fakeHead
    end
    for _, obj in ipairs(targetChar:GetChildren()) do
        if obj:IsA("Accessory") or obj:IsA("Hat") then AddAccessoryLocal(myChar, obj:Clone())
        elseif obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") or obj:IsA("CharacterMesh") or obj:IsA("BodyColors") then
            obj:Clone().Parent = myChar
        elseif obj:IsA("BasePart") and not standardParts[obj.Name] and obj.Name ~= "FakeCopiedHead" then
            local clone = obj:Clone()
            for _, v in ipairs(clone:GetDescendants()) do
                if v:IsA("JointInstance") or v:IsA("WeldConstraint") or v:IsA("Constraint") or v:IsA("Script") or v:IsA("LocalScript") then v:Destroy() end
            end
            local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Torso") or targetChar:FindFirstChild("UpperTorso")
            local myRoot = myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso") or myChar:FindFirstChild("UpperTorso")
            if targetRoot and myRoot then
                local offset = targetRoot.CFrame:Inverse() * obj.CFrame
                clone.CFrame = myRoot.CFrame * offset
                local wc = Instance.new("WeldConstraint")
                wc.Part0 = clone; wc.Part1 = myRoot
                wc.Parent = clone
            end
            clone.Parent = myChar
        end
    end
    return true
end
RegButton(Tabs.Avatar, "Apply Copy Avatar", "Copy avatar player yang dipilih", function()
    if not selectedAvatarPlayer or selectedAvatarPlayer == "" or selectedAvatarPlayer == "No players" then
        notify("Copy Avatar", "Pilih player dulu!", 3); return
    end
    local targetPlayer = Players:FindFirstChild(selectedAvatarPlayer)
    if targetPlayer and targetPlayer.Character then
        pcall(SaveOriginalAvatar)
        if ApplyTargetAvatar(targetPlayer.Character) then
            notify("Copy Avatar", "Berhasil copy avatar " .. targetPlayer.Name .. "!", 3)
        else
            notify("Copy Avatar", "Gagal mengcopy avatar!", 3)
        end
    else
        notify("Copy Avatar", "Player / Character tidak ditemukan!", 3)
    end
end)
RegButton(Tabs.Avatar, "Reset Copy Avatar", "Kembalikan avatar original", function()
    local char = Player.Character
    if not char or not originalAvatarSaved then
        notify("Reset Avatar", "Tidak ada data original avatar tersimpan!", 3); return
    end
    pcall(function()
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Accessory") or obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") or obj:IsA("CharacterMesh") or obj:IsA("BodyColors") then
                obj:Destroy()
            end
        end
        local head = char:FindFirstChild("Head")
        if head then
            local face = head:FindFirstChildOfClass("Decal")
            if face then face:Destroy() end
            local oldFake = char:FindFirstChild("FakeCopiedHead")
            if oldFake then oldFake:Destroy() end
            head.Transparency = 0; head.LocalTransparencyModifier = 0
            local mySm = head:FindFirstChildOfClass("SpecialMesh")
            if mySm and originalHeadMeshScale then mySm.Scale = originalHeadMeshScale
            elseif mySm then mySm.Scale = Vector3.new(1.25, 1.25, 1.25) end
        end
        for _, obj in ipairs(originalAvatarCache) do
            local clone = obj:Clone()
            if clone:IsA("Decal") then if head then clone.Parent = head end
            elseif clone:IsA("Accessory") then AddAccessoryLocal(char, clone)
            else clone.Parent = char end
        end
    end)
    notify("Copy Avatar", "Avatar dikembalikan ke semula!", 3)
end)

--========================================================--
-- [NEW FROM Mawww Hub] SPOOF STATS + STREAMER MODE + EMOTE
--========================================================--
RegLabel(Tabs.Avatar, "Spoof Stats")
spoofLevel, spoofGears, spoofScrews = "0", "0", "0"
RegButton(Tabs.Avatar, "Set Level", "Spoof level (default 0)", function()
    VD.SPOOF_Level = tostring(tonumber(VD.SPOOF_Level or 0) + 10)
    notify("Spoof Level", "Set ke: " .. VD.SPOOF_Level, 2)
end)
RegButton(Tabs.Avatar, "Set Gears", "Spoof gears (default 0)", function()
    VD.SPOOF_Gears = tostring(tonumber(VD.SPOOF_Gears or 0) + 10)
    notify("Spoof Gears", "Set ke: " .. VD.SPOOF_Gears, 2)
end)
RegButton(Tabs.Avatar, "Set Screws", "Spoof screws (default 0)", function()
    VD.SPOOF_Screws = tostring(tonumber(VD.SPOOF_Screws or 0) + 10)
    notify("Spoof Screws", "Set ke: " .. VD.SPOOF_Screws, 2)
end)
RegButton(Tabs.Avatar, "Apply Spoof", "Terapkan spoof", function()
    pcall(function()
        Player:SetAttribute("Level", tonumber(VD.SPOOF_Level) or 0)
        Player:SetAttribute("Gears", tonumber(VD.SPOOF_Gears) or 0)
        Player:SetAttribute("Screws", tonumber(VD.SPOOF_Screws) or 0)
        notify("Spoof Data", "Level, Gears, Screws diperbarui", 3)
    end)
end)

RegLabel(Tabs.Avatar, "Streamer Mode")
StreamerHideNameConn = nil
function shouldHideNameObject(object)
    local ok, isTextObj = pcall(function() return object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") end)
    if not ok or not isTextObj then return false end
    local text = ""; pcall(function() text = tostring(object.Text or "") end)
    return text == Player.Name or text == Player.DisplayName or text:find(Player.Name, 1, true) ~= nil
end
RegToggle(Tabs.Avatar, "Hide Own Name", "Sembunyikan nama sendiri di UI", false, "StreamerHideName", function(enabled)
    if StreamerHideNameConn then pcall(function() StreamerHideNameConn:Disconnect() end); StreamerHideNameConn = nil end
    local pg = Player:FindFirstChildOfClass("PlayerGui"); if not pg then return end
    local function process(object)
        if shouldHideNameObject(object) then object.Visible = not enabled end
    end
    for _, descendant in ipairs(pg:GetDescendants()) do process(descendant) end
    if enabled then
        StreamerHideNameConn = pg.DescendantAdded:Connect(function(object) task.defer(process, object) end)
    end
end)

-- Emote
RegLabel(Tabs.Avatar, "Player Emotes")
EmoteOptions = {"Friday Night","WarCry","24 Hour Cinderella","Applause","Arm Swing","Backflip","California Girls","Christmas Spirit","Floating Rest","Ghoul","Griddy","Kyoufuu","OnePlays","Vulnerable"}
SelectedAnim, SelectedSound = "rbxassetid://83229063951016", "rbxassetid://85355610204255"
currentTrack, currentSound = nil, nil
function SelectEmoteData(value)
    if value == "Friday Night" then SelectedAnim = "rbxassetid://83229063951016"; SelectedSound = "rbxassetid://85355610204255"
    elseif value == "WarCry" then SelectedAnim = "rbxassetid://82600868380136"; SelectedSound = "rbxassetid://120101930689931"
    elseif value == "24 Hour Cinderella" then SelectedAnim = "rbxassetid://137195203725366"; SelectedSound = "rbxassetid://121099446613414"
    elseif value == "Applause" then SelectedAnim = "rbxassetid://96328361165090"; SelectedSound = "rbxassetid://115490787020749"
    elseif value == "Arm Swing" then SelectedAnim = "rbxassetid://80552139463944"; SelectedSound = "rbxassetid://74216458932348"
    elseif value == "Backflip" then SelectedAnim = "rbxassetid://74705617908505"; SelectedSound = nil
    elseif value == "California Girls" then SelectedAnim = "rbxassetid://123552803041504"; SelectedSound = "rbxassetid://87899327891544"
    elseif value == "Christmas Spirit" then SelectedAnim = "rbxassetid://137859761110514"; SelectedSound = nil
    elseif value == "Floating Rest" then SelectedAnim = "rbxassetid://114593021219597"; SelectedSound = nil
    elseif value == "Ghoul" then SelectedAnim = "rbxassetid://130415594909401"; SelectedSound = "rbxassetid://123004139176580"
    elseif value == "Griddy" then SelectedAnim = "rbxassetid://75586690784894"; SelectedSound = nil
    elseif value == "Kyoufuu" then SelectedAnim = "rbxassetid://137322894494527"; SelectedSound = "rbxassetid://129064643026442"
    elseif value == "OnePlays" then SelectedAnim = "rbxassetid://140625405103474"; SelectedSound = "rbxassetid://94749073728335"
    elseif value == "Vulnerable" then SelectedAnim = "rbxassetid://121773684313913"; SelectedSound = "rbxassetid://135265751184744" end
end
function PlayEmote()
    local char = Player.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end
    if currentTrack then currentTrack:Stop(); currentTrack = nil end
    if currentSound then currentSound:Destroy(); currentSound = nil end
    if SelectedAnim then
        local anim = Instance.new("Animation"); anim.AnimationId = SelectedAnim
        currentTrack = hum:LoadAnimation(anim); currentTrack.Looped = true; currentTrack:Play()
    end
    if SelectedSound then
        currentSound = Instance.new("Sound"); currentSound.SoundId = SelectedSound
        currentSound.Looped = true; currentSound.Volume = 2; currentSound.Parent = hrp; currentSound:Play()
    end
end
function StopEmote()
    if currentTrack then currentTrack:Stop(); currentTrack = nil end
    if currentSound then currentSound:Destroy(); currentSound = nil end
end
RegToggle(Tabs.Avatar, "Emote", "Play selected emote", false, "EmoteEnabled", function(v)
    if v then PlayEmote() else StopEmote() end
end)
RegDropdown(Tabs.Avatar, "Select Emote", "Pilih emote", EmoteOptions, "Friday Night", false, "SelectedEmote", function(v)
    VD.SelectedEmote = v
    SelectEmoteData(v)
    if VD.EmoteEnabled then PlayEmote() end
end)

--========================================================--
-- [NEW FROM Mawww Hub] ADVANCED CROSSHAIR OFFSET
--========================================================--
RegDivider(Tabs.AimCrosshairOffset)
RegLabel(Tabs.AimCrosshairOffset, "Crosshair Position")
RegSlider(Tabs.AimCrosshairOffset, "X Offset", "Horizontal offset", 0, -500, 500, 1, "CrossPosX", function(v)
    VD.CrossPosX = v
    pcall(VD_UpdateCrosshair)
end)
RegSlider(Tabs.AimCrosshairOffset, "Y Offset", "Vertical offset", 0, -500, 500, 1, "CrossPosY", function(v)
    VD.CrossPosY = v
    pcall(VD_UpdateCrosshair)
end)

-- [NEW FROM Mawww Hub] KILLER UTILITIES - BLOCK VAULTS / DROP ALL PALLETS / BREAK ALL PALLETS / BEAT KILLER
--========================================================--
RegDivider(Tabs.KillerUtility)
RegLabel(Tabs.KillerUtility, "Killer / Utility")
RegToggle(Tabs.KillerUtility, "Block Vaults", "Fire VaultEvent ke semua vault", false, "KillerBlockAllVaults")
RegToggle(Tabs.KillerUtility, "Auto Drop Pallets", "Fire PalletDropEvent ke semua pallet", false, "KillerAutoDropAllPallets")
RegToggle(Tabs.KillerUtility, "Break All Pallets", "TP ke semua pallet dan hancurkan", false, "KillerBreakAllPallets")

getgenv().MAWWW_LastVaultBlockTime = 0
getgenv().MAWWW_LastPalletBlockTime = 0
getgenv().MAWWW_LastPalletBlockDropTime = 0
getgenv().MAWWW_IsBlockingPallets = false

function MAWWW_BlockAllVaults()
    if not VD.KillerBlockAllVaults or GetRole() ~= "Killer" then return end
    local now = tick()
    if now - getgenv().MAWWW_LastVaultBlockTime < 1.5 then return end
    getgenv().MAWWW_LastVaultBlockTime = now
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local vaultEvent = remotes and remotes:FindFirstChild("Window") and remotes.Window:FindFirstChild("VaultEvent")
        if not vaultEvent then return end
        local map = Workspace:FindFirstChild("Map")
        local vaultsFolder = map and map:FindFirstChild("Vaults")
        if vaultsFolder then
            for _, vault in ipairs(vaultsFolder:GetChildren()) do
                for _, part in ipairs(vault:GetChildren()) do
                    if part:IsA("BasePart") then
                        pcall(function() vaultEvent:FireServer(part, true) end)
                    end
                end
            end
        end
    end)
end

function MAWWW_BlockAllPalletDrops()
    if not VD.KillerAutoDropAllPallets or GetRole() ~= "Killer" then return end
    local now = tick()
    if now - getgenv().MAWWW_LastPalletBlockTime < 2 then return end
    getgenv().MAWWW_LastPalletBlockTime = now
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local palletFold = remotes and remotes:FindFirstChild("Pallet")
        local dropEvent = palletFold and palletFold:FindFirstChild("PalletDropEvent")
        if not dropEvent then return end
        local map = Workspace:FindFirstChild("Map")
        if not map then return end
        for _, obj in ipairs(map:GetDescendants()) do
            if obj.Name == "Palletwrong" and (obj:IsA("Model") or obj:IsA("Folder")) then
                local target = obj:FindFirstChild("PalletPointSlide") or obj:FindFirstChild("PalletPoint")
                if target then pcall(function() dropEvent:FireServer(target) end) end
            end
        end
    end)
end

function MAWWW_ForceUnstuck(char)
    pcall(function()
        char:SetAttribute("Immobile", nil)
        char:SetAttribute("immobile", nil)
        char:SetAttribute("IsStunned", nil)
        char:SetAttribute("isStunned", nil)
        char:SetAttribute("Pursuit", nil)
        char:SetAttribute("pursuit", nil)
    end)
    pcall(function()
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed <= 0 then hum.WalkSpeed = 16 end
    end)
end

function MAWWW_BlockPalletDrop()
    if not VD.KillerBreakAllPallets or GetRole() ~= "Killer" then return end
    if getgenv().MAWWW_IsBlockingPallets then return end
    local now = tick()
    if now - getgenv().MAWWW_LastPalletBlockDropTime < 4 then return end
    getgenv().MAWWW_LastPalletBlockDropTime = now
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local stunned = char:GetAttribute("IsStunned") or char:GetAttribute("isStunned")
    local immobile = char:GetAttribute("Immobile") or char:GetAttribute("immobile")
    local carrying = char:GetAttribute("IsCarrying") or char:GetAttribute("isCarrying")
    if stunned or immobile or carrying then return end
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local palletFold = remotes and remotes:FindFirstChild("Pallet")
        local dropEvent = palletFold and palletFold:FindFirstChild("PalletDropEvent")
        local jasonFold = palletFold and palletFold:FindFirstChild("Jason")
        local destroyGlobal = jasonFold and jasonFold:FindFirstChild("Destroy-Global")
        local breakCommit = jasonFold and jasonFold:FindFirstChild("PalletBreakCommit")
        local destroySingle = jasonFold and jasonFold:FindFirstChild("Destroy")
        if not dropEvent or not destroyGlobal or not breakCommit then return end
        local map = Workspace:FindFirstChild("Map")
        if not map then return end
        local function collectTargets()
            local targets, seen = {}, {}
            for _, obj in ipairs(map:GetDescendants()) do
                if obj.Name == "Palletwrong" and (obj:IsA("Model") or obj:IsA("Folder")) then
                    local target = obj:FindFirstChild("PalletPointSlide") or obj:FindFirstChild("PalletPoint")
                    if target and target:IsA("BasePart") and not seen[target] then
                        table.insert(targets, target); seen[target] = true
                    end
                end
            end
            return targets
        end
        local targets = collectTargets()
        if #targets == 0 then return end
        getgenv().MAWWW_IsBlockingPallets = true
        local hum = char:FindFirstChildOfClass("Humanoid")
        local origWalkSpeed = hum and hum.WalkSpeed or 16
        task.spawn(function()
            pcall(function()
                local originalCF = root.CFrame
                local function processPallet(target)
                    if not target or not target.Parent then return end
                    pcall(function()
                        dropEvent:FireServer(target); task.wait(0.12)
                        root.CFrame = target.CFrame + Vector3.new(0, 2, 0); task.wait(0.15)
                        destroyGlobal:FireServer(target); breakCommit:FireServer(target)
                        if destroySingle then destroySingle:FireServer(target) end
                        task.wait(0.12); MAWWW_ForceUnstuck(char)
                    end)
                end
                for _, target in ipairs(targets) do processPallet(target) end
                task.wait(0.1); pcall(function() root.CFrame = originalCF end)
                MAWWW_ForceUnstuck(char)
                task.wait(0.5)
                local remaining = collectTargets()
                if #remaining > 0 then
                    originalCF = root.CFrame
                    for _, target in ipairs(remaining) do processPallet(target) end
                    task.wait(0.1); pcall(function() root.CFrame = originalCF end)
                end
                task.wait(0.1); MAWWW_ForceUnstuck(char)
                if hum then pcall(function() hum.WalkSpeed = origWalkSpeed end) end
            end)
            task.spawn(function()
                for i = 1, 10 do
                    task.wait(0.1)
                    if char and char.Parent then
                        MAWWW_ForceUnstuck(char)
                        if hum and hum.WalkSpeed <= 0 then pcall(function() hum.WalkSpeed = origWalkSpeed end) end
                    end
                end
            end)
            getgenv().MAWWW_IsBlockingPallets = false
        end)
    end)
end

-- Beat Killer
RegToggle(Tabs.KillerUtility, "Beat Killer", "Auto chase & kill survivor", false, "BeatKiller")
function MAWWW_BeatGameKiller()
    if not VD.BeatKiller then VD._KillerTarget = nil; return end
    if GetRole() ~= "Killer" then VD._KillerTarget = nil; return end
    local root = getRoot(); if not root then return end
    local target = VD._KillerTarget
    local needNewTarget = true
    if target and target.Character then
        local tr = target.Character:FindFirstChild("HumanoidRootPart")
        local th = target.Character:FindFirstChildOfClass("Humanoid")
        if tr and th and th.MaxHealth > 0 and (th.Health / th.MaxHealth) > 0.25 then
            needNewTarget = false
        else VD._KillerTarget = nil end
    end
    if needNewTarget then
        local survivors = {}
        for _, plr in ipairs(MawwwGetPlayers()) do
            if plr ~= Player and IsSurvivor(plr) and plr.Character then
                local pr = plr.Character:FindFirstChild("HumanoidRootPart")
                local ph = plr.Character:FindFirstChildOfClass("Humanoid")
                if pr and ph and ph.MaxHealth > 0 and (ph.Health / ph.MaxHealth) > 0.25 then table.insert(survivors, plr) end
            end
        end
        if #survivors > 0 then
            local closest, closestDist = nil, math.huge
            for _, plr in ipairs(survivors) do
                local pr = plr.Character:FindFirstChild("HumanoidRootPart")
                local dist = (pr.Position - root.Position).Magnitude
                if dist < closestDist then closestDist = dist; closest = plr end
            end
            VD._KillerTarget = closest; target = closest
        else VD._KillerTarget = nil; return end
    end
    if not target or not target.Character then return end
    local tr = target.Character:FindFirstChild("HumanoidRootPart")
    local th = target.Character:FindFirstChildOfClass("Humanoid")
    if not tr or not th then VD._KillerTarget = nil; return end
    if th.MaxHealth <= 0 or (th.Health / th.MaxHealth) <= 0.25 then VD._KillerTarget = nil; return end
    for _, part in ipairs(Player.Character:GetDescendants()) do
        if part:IsA("BasePart") then pcall(function() part.CanCollide = false end) end
    end
    local dir = (root.Position - tr.Position).Unit
    if dir.Magnitude ~= dir.Magnitude then dir = Vector3.new(1, 0, 0) end
    root.CFrame = CFrame.new(tr.Position + dir * 3 + Vector3.new(0, 1, 0), tr.Position)
    pcall(function()
        local r = GetRemotes()
        local a = r and r:FindFirstChild("Attacks")
        local ba = a and a:FindFirstChild("BasicAttack")
        if ba then ba:FireServer(false) end
    end)
end

-- Main loop untuk fitur baru Killer
task.spawn(function()
    while not VD.Destroyed do
        pcall(MAWWW_BlockAllVaults)
        pcall(MAWWW_BlockAllPalletDrops)
        pcall(MAWWW_BlockPalletDrop)
        pcall(MAWWW_BeatGameKiller)
        task.wait(0.15)
    end
end)

--========================================================--
-- [NEW FROM Mawww Hub] INFINITE LUNGE (Basic Attack)
--========================================================--
VD_OriginalLungeBoost = nil
task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.3)
        local char = Player.Character
        if char then
            if VD.KillerInfLunge then
                if char:GetAttribute("lungeboost") ~= 999999 then
                    VD_OriginalLungeBoost = char:GetAttribute("lungeboost") or 1
                    pcall(function() char:SetAttribute("lungeboost", 999999) end)
                end
            else
                if VD_OriginalLungeBoost then
                    pcall(function() char:SetAttribute("lungeboost", VD_OriginalLungeBoost) end)
                    VD_OriginalLungeBoost = nil
                end
            end
        end
    end
end)

--========================================================--
-- [NEW FROM Mawww Hub] FAKE PARRY UI IS KEPT IN KILLER EXTRA
--========================================================--

--========================================================--
-- [NEW FROM Mawww Hub] BEAT SURVIVOR exists, but also ESCAPE GATE
--========================================================--
-- (Sudah ada BeatSurvivor di Survival tab, jadi skip)

--========================================================--
-- [NEW FROM Mawww Hub] KILLER PERKS DISPLAY (Info Overlay)
--========================================================--
-- (Sudah ada InfoOverlay di bagian Visual, tambahkan KillerPerks real dari Mawww Hub)
MAWWW_KillerPerkNames = {
    MawwwtInLine = "Mawwwt in Line", ["Mawwwt in Line"] = "Mawwwt in Line",
    EchoLocation = "Echo Location", ["Echo Location"] = "Echo Location",
    KingsScourge = "King's Scourge", KingScourge = "King's Scourge", ["King's Scourge"] = "King's Scourge",
    Kings = "King's Scourge", Scourge = "King's Scourge", -- Tambahan deteksi
}
function MAWWW_EscapeRichText(text)
    text = tostring(text or "")
    text = text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    return text
end
function MAWWW_FormatPerkName(name)
    name = tostring(name or "")
    if MAWWW_KillerPerkNames[name] then return MAWWW_KillerPerkNames[name] end
    local lower = name:lower()
    if lower:find("king") and lower:find("scourge") then return "King's Scourge" end -- Deteksi berbasis kata kunci
    local clean = name:gsub("_", " "):gsub("-", " ")
    clean = clean:gsub("(%l)(%u)", "%1 %2"):gsub("(%a)(%d)", "%1 %2"):gsub("(%d)(%a)", "%1 %2")
    clean = clean:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return clean ~= "" and clean or "Unknown Perk"
end
function MAWWW_GetKillerPlayer()
    for _, plr in ipairs(MawwwGetPlayers()) do
        local tn = plr.Team and plr.Team.Name
        if tn and tn:lower():find("killer") then return plr end
    end
    return nil
end
function MAWWW_ParseWorkspacePerkName(name)
    name = tostring(name or "")
    local perkName, level = name:match("^(.+)%s+(%d+)$")
    if not perkName then return nil end
    perkName = perkName:gsub("^%s+", ""):gsub("%s+$", "")
    if perkName == "" then return nil end
    local lower = perkName:lower()
    local excluded = { head=true, torso=true, humanoid=true, ["left arm"]=true, ["right arm"]=true, ["left leg"]=true, ["right leg"]=true, humanoidrootpart=true }
    if excluded[lower] then return nil end
    return perkName, level
end
function MAWWW_ReadPerksFromWorkspace(killer)
    if not killer then return {} end
    local char = killer.Character or Workspace:FindFirstChild(killer.Name) or Workspace:FindFirstChild(killer.DisplayName)
    if not char then return {} end
    local result, seen = {}, {}
    local function addPerk(raw, displayName, level)
        if not raw then return end
        raw = tostring(raw)
        if raw == "" or raw == "nil" or seen[raw] then return end
        if raw:lower():find("template") then return end
        seen[raw] = true
        table.insert(result, { Raw=raw, Name=displayName and tostring(displayName) or MAWWW_FormatPerkName(raw), Level=level and tostring(level) or nil })
    end
    local function scanAttrs(inst)
        if not inst.GetAttributes then return end
        local attrs = inst:GetAttributes()
        for key, value in pairs(attrs) do
            local lowerKey = tostring(key):lower()
            if lowerKey:find("perk") then
                if type(value) == "string" then addPerk(value)
                elseif value == true then addPerk(key)
                elseif type(value) == "number" and lowerKey:find("level") then
                    local baseName = tostring(key):gsub("[Ll]evel", ""):gsub("[Pp]erk", "")
                    if baseName ~= "" then addPerk(baseName, nil, value) end
                end
            end
        end
    end
    local function readValueObject(inst)
        if inst:IsA("StringValue") then return inst.Value
        elseif inst:IsA("IntValue") or inst:IsA("NumberValue") then return inst.Name, inst.Value
        elseif inst:IsA("BoolValue") and inst.Value == true then return inst.Name end
        return nil
    end
    local function isPerkContainer(inst)
        local name = inst.Name:lower()
        return name == "perks" or name == "killerperks" or name == "equippedperks" or name == "equippedkillerperks" or name:find("perkfolder") ~= nil or name:find("perklist") ~= nil
    end
    scanAttrs(char)
    for _, child in ipairs(char:GetChildren()) do
        local perkName, level = MAWWW_ParseWorkspacePerkName(child.Name)
        if perkName then addPerk(child.Name, perkName, level) end
    end
    for _, inst in ipairs(char:GetDescendants()) do
        scanAttrs(inst)
        if isPerkContainer(inst) then
            for _, child in ipairs(inst:GetChildren()) do
                local value, level = readValueObject(child)
                addPerk(value or child.Name, nil, level)
            end
        else
            local lowerName = inst.Name:lower()
            if lowerName:find("perk") then
                local value, level = readValueObject(inst)
                addPerk(value or inst.Name, nil, level)
            end
        end
    end
    table.sort(result, function(a, b) return tostring(a.Name) < tostring(b.Name) end)
    return result
end
function MAWWW_BuildKillerPerksText()
    local killer = MAWWW_GetKillerPlayer()
    local killerName = killer and (killer.DisplayName or killer.Name) or "Unknown"
    local perks = MAWWW_ReadPerksFromWorkspace(killer)
    if #perks == 0 then
        for _, plr in ipairs(MawwwGetPlayers()) do
            local candidatePerks = MAWWW_ReadPerksFromWorkspace(plr)
            if #candidatePerks > 0 then
                killer = plr; killerName = plr.DisplayName or plr.Name; perks = candidatePerks; break
            end
        end
    end
    local lines = { 'Killer Perks [<font color="rgb(255,80,80)">' .. MAWWW_EscapeRichText(killerName) .. '</font>]' }
    if #perks == 0 then
        table.insert(lines, '<font color="rgb(255,204,80)">- Waiting for perk data...</font>')
    else
        for i = 1, math.min(#perks, 4) do
            local perk = perks[i]
            local levelText = perk.Level and (" lvl " .. tostring(perk.Level)) or ""
            table.insert(lines, '<font color="rgb(255,204,80)">- ' .. MAWWW_EscapeRichText(perk.Name) .. MAWWW_EscapeRichText(levelText) .. '</font>')
        end
    end
    return table.concat(lines, "\n"), #perks
end
getgenv().MAWWW_KillerPerksRunning = false
getgenv().MAWWW_KillerPerksGui = nil
function StartKillerPerksDisplay()
    if getgenv().MAWWW_KillerPerksRunning then return end
    getgenv().MAWWW_KillerPerksRunning = true
    task.spawn(function()
        while VD.VIS_KillerPerks and getgenv().MAWWW_KillerPerksRunning do
            local text = MAWWW_BuildKillerPerksText()
            if getgenv().MAWWW_UpdateInfoOverlayKillerPerks then
                pcall(getgenv().MAWWW_UpdateInfoOverlayKillerPerks, text)
            end
            task.wait(1)
        end
    end)
end
function StopKillerPerksDisplay()
    getgenv().MAWWW_KillerPerksRunning = false
end
-- Note: existing UI toggle "KillerPerks" di Visual tab akan memanggil StartKillerPerksDisplay jika diinginkan
-- (Already exists in Visual tab as KillerPerks)

--========================================================--
-- [NEW FROM Mawww Hub] REMOTE NAMECALL HOOK (via __namecall)
--========================================================--
if typeof(hookmetamethod) == "function" then
    pcall(function()
        local mt = getrawmetatable(game)
        if mt and mt.__namecall then
            local oldNamecall = mt.__namecall
            if setreadonly then setreadonly(mt, false) end
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if method == "FireServer" and not checkcaller() then
                    if VD.FlaskSilentAim then
                        local ok, name = pcall(function() return self.Name end)
                        if ok and name == "ThrowFlask" then
                            local args = {...}
                            local closest = nil
                            local minDst = math.huge
                            local myPos = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") and Player.Character.HumanoidRootPart.Position
                            if myPos then
                                for _, v in pairs(MawwwGetPlayers()) do
                                    if v ~= Player and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                                        if not v.Character:GetAttribute("IsKiller") then
                                            local dst = (v.Character.HumanoidRootPart.Position - myPos).Magnitude
                                            if dst < minDst then minDst = dst; closest = v end
                                        end
                                    end
                                end
                            end
                            if closest then
                                local targetPos = closest.Character.HumanoidRootPart.Position
                                if args[2] and typeof(args[2]) == "Vector3" then
                                    args[1] = (targetPos - args[2]).Unit
                                end
                                setnamecallmethod(method)
                                return oldNamecall(self, unpack(args))
                            end
                        end
                    end
                end
                return oldNamecall(self, ...)
            end)
            if setreadonly then setreadonly(mt, true) end
        end
    end)
end

--========================================================--
-- [NEW FROM Mawww Hub] ADDITIONAL PLAYER LOGIC LOOPS
--========================================================--
--========================================================--
-- PLAYER TAB (EXISTING, unchanged)
--========================================================--

RegLabel(Tabs.SurvivalAbilities, "Survivor Tools")
RegToggle(Tabs.SurvivalAbilities, "Anti Knockdown", "Auto recover dari knockdown", false, "AntiKnockdown")
task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.1)
        if VD.AntiKnockdown then
            local hum = getHum()
            if hum then
                if hum.Health < hum.MaxHealth then pcall(function() hum.Health = hum.MaxHealth end) end
                local st = hum:GetState()
                if st == Enum.HumanoidStateType.Dead or st == Enum.HumanoidStateType.FallingDown or st == Enum.HumanoidStateType.Ragdoll then
                    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
                end
            end
        end
    end
end)
--========================================================--
-- AUTO CROUCH DODGE — SOURCE: text 5 / mawww HUB
--========================================================--
-- The source behavior is preserved; names are prefixed to avoid collisions
-- with other Mawww modules. The existing UI flag AutoCrouchDodge is mirrored
-- to the source-style VD.AutoCrouch flag.
VD.AutoCrouch = VD.AutoCrouch == true or VD.AutoCrouchDodge == true

AutoCrouchState = {
    Attached = setmetatable({}, { __mode = "k" }),
}

function AC_IsDowned(char)
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return true end
    local state = char:GetAttribute("State")
    return state == "Downed" or state == "Dead"
end

function AC_TriggerCrouch()
    local startT = tick()
    task.spawn(function()
        local char = Player.Character
        if not char then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid")

        pcall(function()
            char:SetAttribute("Crouching", true)
        end)
        pcall(function()
            ReplicatedStorage.Remotes.Mechanics.ChangeAttribute:FireServer("Crouchingserver", true)
        end)
        pcall(function()
            ReplicatedStorage.Remotes.Chase.Runevent:FireServer(char, false)
        end)
        if humanoid then
            pcall(function()
                humanoid:ChangeState(Enum.HumanoidStateType.Landed)
            end)
        end

        pcall(function()
            local pGui = Player:FindFirstChildOfClass("PlayerGui")
            local survMob = pGui and pGui:FindFirstChild("Survivor-mob")
            if survMob then
                local controls = survMob:FindFirstChild("Controls")
                if controls then
                    local crouchBtn = controls:FindFirstChild("crouch")
                    if crouchBtn and typeof(firesignal) == "function" then
                        firesignal(crouchBtn.MouseButton1Click)
                    end
                end
            end
        end)

        while tick() - startT < 1.2 do
            if not (VD.AutoCrouch or VD.AutoCrouchDodge) then break end
            pcall(function()
                ReplicatedStorage.Remotes.Mechanics.ChangeAttribute:FireServer("Crouchingserver", true)
            end)
            task.wait(0.1)
        end

        pcall(function()
            char:SetAttribute("Crouching", false)
        end)
        pcall(function()
            ReplicatedStorage.Remotes.Mechanics.ChangeAttribute:FireServer("Crouchingserver", false)
        end)
        if humanoid then
            pcall(function()
                humanoid:ChangeState(Enum.HumanoidStateType.Landed)
            end)
        end

        pcall(function()
            local pGui = Player:FindFirstChildOfClass("PlayerGui")
            local survMob = pGui and pGui:FindFirstChild("Survivor-mob")
            if survMob then
                local controls = survMob:FindFirstChild("Controls")
                if controls then
                    local crouchBtn = controls:FindFirstChild("crouch")
                    if crouchBtn and typeof(firesignal) == "function" then
                        firesignal(crouchBtn.MouseButton1Click)
                    end
                end
            end
        end)
    end)
end

-- Preserve the older public name because other Mawww features use it.
TriggerCrouch = AC_TriggerCrouch

function AC_IsSafeToParry(char)
    return not AC_IsDowned(char)
end
IsSafeToParry = AC_IsSafeToParry

function AC_IsKiller(p)
    return p and p.Team and p.Team.Name == "Killer"
end

function AC_AttachParrySensor(kChar)
    if not kChar or AutoCrouchState.Attached[kChar] then return end
    AutoCrouchState.Attached[kChar] = true

    local humanoid = kChar:FindFirstChild("Humanoid")
    if not humanoid then
        humanoid = kChar:WaitForChild("Humanoid", 5)
        if not humanoid then
            AutoCrouchState.Attached[kChar] = nil
            return
        end
    end

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = humanoid:WaitForChild("Animator", 5)
        if not animator then
            AutoCrouchState.Attached[kChar] = nil
            return
        end
    end

    humanoid.ChildAdded:Connect(function(child)
        if child:IsA("Animator") then
            AutoCrouchState.Attached[kChar] = nil
            task.defer(function()
                AC_AttachParrySensor(kChar)
            end)
        end
    end)

    kChar.AncestryChanged:Connect(function(_, parent)
        if not parent then
            AutoCrouchState.Attached[kChar] = nil
        end
    end)

    animator.AnimationPlayed:Connect(function(track)
        local animId = track.Animation and track.Animation.AnimationId or ""
        local id = animId:match("%d+")

        if id == "80411309607666" and (VD.AutoCrouch or VD.AutoCrouchDodge) then
            local myChar = Player.Character
            if AC_IsDowned(myChar) then return end
            local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local kHRP = kChar:FindFirstChild("HumanoidRootPart")
            if myHRP and kHRP then
                local dist = (myHRP.Position - kHRP.Position).Magnitude
                if dist <= 40 then
                    AC_TriggerCrouch()
                end
            end
            return
        end
    end)
end

function AC_TryAttach(p)
    if p ~= Player and AC_IsKiller(p) and p.Character then
        AC_AttachParrySensor(p.Character)
    end
end

function AC_SetupPlayer(p)
    if p == Player then return end
    p.CharacterAdded:Connect(function()
        task.wait(0.1)
        AC_TryAttach(p)
    end)
    p:GetPropertyChangedSignal("Team"):Connect(function()
        AC_TryAttach(p)
    end)
    if p.Character then
        AC_TryAttach(p)
    end
end

for _, p in ipairs(MawwwGetPlayers()) do
    AC_SetupPlayer(p)
end
Players.PlayerAdded:Connect(AC_SetupPlayer)

task.spawn(function()
    while not VD.Destroyed do
        task.wait(5)
        for _, p in ipairs(MawwwGetPlayers()) do
            AC_TryAttach(p)
        end
    end
end)

RegToggle(Tabs.SurvivalAbilities, "Auto Crouch Dodge", "Auto crouch saat killer attack", false, "AutoCrouchDodge", function(v)
    VD.AutoCrouch = v
end)

AntiFallState = { lastFreefall = 0, restoring = false, lastRemoteFire = 0 }
FALL_SLOW_ATTRS = {"FallSlow","FallingSlow","FallingSlowdown","FallSlowdown","SlowdownActive","StunFall","LandSlow","LandSlowdown","FallingStun","FallStun","LandingSlow","IsSlowed","Slowed","Slow","FallStunActive","LandingRecovery"}
FALL_SLOW_REMOTE_NAMES = {"CancelFall","FallRecover","LandRecover","ResetSlow","ClearSlow","CancelStun","LandingRecover","Recover","FallCancel","CancelSlowdown","RemoveSlow","ClearStun","LandingCancel","FallStun","EndFall"}
FALL_SLOW_FOLDERS = { "Player","Movement","Character","PlayerActions","Game","Actions","Status","Effects","Slowdown" }
function ClearFallSlowdown(hum, char)
    if hum then
        if hum.WalkSpeed > 0 and hum.WalkSpeed < 16 then hum.WalkSpeed = 16 end
    end
    if char then
        pcall(function()
            for _, a in ipairs(FALL_SLOW_ATTRS) do
                if char:GetAttribute(a) == true then char:SetAttribute(a, false) end
            end
        end)
    end
end
function FireFallRecoveryRemotes()
    local now = tick()
    if now - AntiFallState.lastRemoteFire < 0.8 then return end
    AntiFallState.lastRemoteFire = now
    pcall(function()
        local remotes = GetRemotes(); if not remotes then return end
        for _, folderName in ipairs(FALL_SLOW_FOLDERS) do
            local folder = remotes:FindFirstChild(folderName)
            if folder then
                for _, evName in ipairs(FALL_SLOW_REMOTE_NAMES) do
                    local ev = folder:FindFirstChild(evName)
                    if ev and ev:IsA("RemoteEvent") then pcall(function() ev:FireServer() end) end
                end
            end
        end
        for _, evName in ipairs(FALL_SLOW_REMOTE_NAMES) do
            local ev = remotes:FindFirstChild(evName)
            if ev and ev:IsA("RemoteEvent") then pcall(function() ev:FireServer() end) end
        end
    end)
end
-- Legacy Anti Fall Slowdown removed: No-Slowdown+ is the single slowdown recovery engine.

--========================================================--
--========================================================--
-- IMPORTED MISSING FEATURES FROM aja.lua
-- Kept separate from the existing Mawww Auto Parry / TOF engines.
--========================================================--

ABYSS_ANIM_ID = "103714321340288"
hookedAbyss = setmetatable({}, {__mode = "k"})

-- Deteksi animasi abyss (ID + nama sebagai fallback)
-- [FIX] Expanded ultimate/abyss animation detection. Includes known ult IDs
-- and name patterns for "ulti", "ultimate", "ult", "burst", "abyss".
ABYSS_ULT_ANIM_IDS = {
    ["103714321340288"] = true,  -- base abyssal burst
    ["80411309607666"]  = true,  -- Abyssal S1
    ["118907603246885"] = true,  -- Abyssal lunge
}
function MAWWW_IsAbyssAnimation(track)
    if not track or not track.Animation then return false end
    local animId = track.Animation.AnimationId or ""
    local numId = animId:match("%d+")
    if numId and ABYSS_ULT_ANIM_IDS[numId] then return true end
    local name = string.lower(track.Animation.Name or "")
    if name:find("abyss", 1, true)
        or name:find("abyssal", 1, true)
        or name:find("burst", 1, true)
        or name:find("ult", 1, true)
        or name:find("ulti", 1, true)
        or name:find("ultimate", 1, true)
        or name:find("enrage", 1, true) then
        -- If "Ult Only" mode is on, require ult/ultimate/ulti keyword specifically.
        if VD.AbyssUltOnly == true then
            return name:find("ult", 1, true) ~= nil or name:find("ulti", 1, true) ~= nil or name:find("ultimate", 1, true) ~= nil
        end
        return true
    end
    return false
end

-- [REPLACED FROM deepseek_lua_20260923_958b5c.lua]
MAWWW_AbyssDodging = false
function MAWWW_TriggerCrouch()
    pcall(function()
        local sm = PlayerGui:FindFirstChild("Survivor-mob")
        local ctrl = sm and sm:FindFirstChild("Controls")
        local crouchBtn = ctrl and ctrl:FindFirstChild("Crouch")
        if crouchBtn then
            pcall(function() crouchBtn:Activate() end)
            if typeof(firesignal) == "function" then
                pcall(function() firesignal(crouchBtn.MouseButton1Down) end)
                task.wait(0.05)
                pcall(function() firesignal(crouchBtn.MouseButton1Up) end)
            end
            return true
        end
    end)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.C, false, game)
        task.wait(0.06)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.C, false, game)
    end)
    return true
end
function MAWWW_ExecuteAbyssDodge()
    if MAWWW_AbyssDodging then return end
    local myChar = Player.Character
    if not myChar then return end
    -- Skip when downed/hooked/carried — dodge won't help and may bug state.
    if myChar:GetAttribute("Knocked") == true
        or myChar:GetAttribute("IsHooked") == true
        or myChar:GetAttribute("HookProgressDepleting") == true
        or myChar:GetAttribute("IsCarried") == true then
        return
    end
    local myHum = myChar:FindFirstChildOfClass("Humanoid")
    if myHum and myHum.Health <= 0 then return end
    MAWWW_AbyssDodging = true
    task.spawn(function()
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then MAWWW_AbyssDodging = false; return end

        local mode = VD.AbyssDodgeMode or "Crouch"

        if mode == "Teleport" then
            -- Dodge by teleporting perpendicular to killer direction.
            local bestKiller, bestDist = nil, math.huge
            for _, p in ipairs(MawwwGetPlayers()) do
                if p ~= Player and IsKiller(p) and p.Character then
                    local kr = p.Character:FindFirstChild("HumanoidRootPart")
                    if kr then
                        local d = (kr.Position - myRoot.Position).Magnitude
                        if d < bestDist then bestDist = d; bestKiller = kr end
                    end
                end
            end
            local awayDir
            if bestKiller then
                awayDir = (myRoot.Position - bestKiller.Position)
                awayDir = Vector3.new(awayDir.X, 0, awayDir.Z)
                if awayDir.Magnitude < 0.1 then awayDir = myRoot.CFrame.LookVector end
            else
                awayDir = myRoot.CFrame.LookVector
            end
            awayDir = awayDir.Unit
            local perp = Vector3.new(-awayDir.Z, 0, awayDir.X)
            local dist = tonumber(VD.AbyssTeleportDist) or 16
            local target = myRoot.Position + perp * dist + awayDir * 4
            pcall(function() myRoot.CFrame = CFrame.new(target + Vector3.new(0, 2, 0)) end)
            task.wait(0.4)
        elseif mode == "Strafe" then
            -- Strafe quickly perpendicular + crouch.
            local bestKiller, bestDist = nil, math.huge
            for _, p in ipairs(MawwwGetPlayers()) do
                if p ~= Player and IsKiller(p) and p.Character then
                    local kr = p.Character:FindFirstChild("HumanoidRootPart")
                    if kr then
                        local d = (kr.Position - myRoot.Position).Magnitude
                        if d < bestDist then bestDist = d; bestKiller = kr end
                    end
                end
            end
            local awayDir
            if bestKiller then
                awayDir = (myRoot.Position - bestKiller.Position)
                awayDir = Vector3.new(awayDir.X, 0, awayDir.Z)
                if awayDir.Magnitude < 0.1 then awayDir = myRoot.CFrame.LookVector end
            else
                awayDir = myRoot.CFrame.LookVector
            end
            awayDir = awayDir.Unit
            local perp = Vector3.new(-awayDir.Z, 0, awayDir.X)
            if math.random() < 0.5 then perp = -perp end
            local origSpeed = myHum.WalkSpeed
            myHum.WalkSpeed = 90
            local t0 = tick()
            while tick() - t0 < 0.35 do
                if not myRoot.Parent or not myHum.Parent then break end
                myRoot.CFrame = myRoot.CFrame + perp * 2.5
                task.wait()
            end
            if myHum and myHum.Parent then myHum.WalkSpeed = origSpeed end
            MAWWW_TriggerCrouch()
            task.wait(0.3)
        else
            -- Crouch mode (default).
            MAWWW_TriggerCrouch()
            task.wait(0.4)
            -- Second crouch pulse to ensure server registers.
            MAWWW_TriggerCrouch()
            task.wait(0.25)
        end
        MAWWW_AbyssDodging = false
    end)
end


task.spawn(function()
    while not VD.Destroyed do
        task.wait(1)
        if VD.AutoDodgeAbyss then
            for _, p in ipairs(MawwwGetPlayers()) do
                if p ~= Player and IsKiller(p) and p.Character then
                    local char = p.Character
                    local hum  = char:FindFirstChildOfClass("Humanoid")
                    local anim = hum and hum:FindFirstChildOfClass("Animator")

                    if hum and not anim then
                        -- Animator belum ada → tunggu sebentar, jangan tandai hooked
                        pcall(function() anim = hum:WaitForChild("Animator", 1) end)
                    end

                    if anim and not hookedAbyss[char] then
                        hookedAbyss[char] = true
                        char.AncestryChanged:Connect(function(_, parent)
                            if not parent then hookedAbyss[char] = nil end
                        end)
                        anim.AnimationPlayed:Connect(function(track)
                            if not VD.AutoDodgeAbyss then return end
                            if not MAWWW_IsAbyssAnimation(track) then return end
                            local myRoot = getRoot()
                            local kRoot  = char:FindFirstChild("HumanoidRootPart")
                            if myRoot and kRoot
                                and (kRoot.Position - myRoot.Position).Magnitude
                                    <= (VD.AbyssDodgeDistance or 20) then
                                MAWWW_ExecuteAbyssDodge()
                            end
                        end)
                    end
                end
            end
        else
            -- Saat OFF, bersihkan marker supaya ON berikutnya re-hook dengan bersih
            for char in pairs(hookedAbyss) do
                if not char or not char.Parent then
                    hookedAbyss[char] = nil
                end
            end
        end
    end
end)

RegToggle(Tabs.SurvivalAbilities, "Auto Dodge Abyss", "Dodge abyssal burst", false, "AutoDodgeAbyss")
RegSlider(Tabs.SurvivalAbilities, "Abyss Dodge Distance", "Trigger distance", 20, 5, 50, 1, "AbyssDodgeDistance")
RegDropdown(Tabs.SurvivalAbilities, "Abyss / Ultimate Dodge Mode", "Dodge style for ult", {"Crouch", "Strafe", "Teleport"}, "Crouch", false, "AbyssDodgeMode")
RegToggle(Tabs.SurvivalAbilities, "Ultimate Only", "Only dodge ultimate anims", false, "AbyssUltOnly")
RegSlider(Tabs.SurvivalAbilities, "Abyss Teleport Distance", "Teleport dodge distance", 16, 5, 40, 1, "AbyssTeleportDist")

--========================================================--
-- REPLACED: AUTO DODGE SPEAR
-- Source: autohindaritombakveil.lua.txt
-- Integrated into existing Mawww UI flag: AutoDodgeSpearVeil.
--========================================================--
SpearVeil = (function()
    local State = {
        LastDodge = 0,
        Dodging = false,
    }

    local function enabled()
        return VD.AutoDodgeSpearVeil == true or VD.SURV_AutoDodgeSpear == true
    end

    local function isSurvivor()
        local team = LocalPlayer.Team and LocalPlayer.Team.Name or ""
        return team:lower():find("survivor", 1, true) ~= nil
    end

    local function getRoot()
        local char = LocalPlayer.Character
        return char and char:FindFirstChild("HumanoidRootPart") or nil
    end

    local function doDodge()
        local now = tick()
        if now - State.LastDodge < 1 or State.Dodging then return end

        local root = getRoot()
        if not root then return end

        State.LastDodge = now
        State.Dodging = true

        local originalCFrame = root.CFrame
        local rightVector = root.CFrame.RightVector

        pcall(function()
            root.CFrame = root.CFrame + (rightVector * 8)
        end)

        pcall(function()
            if notify then
                notify("Auto Dodge", "Spear terdeteksi! Menghindar otomatis...", 2)
            end
        end)

        task.delay(1, function()
            pcall(function()
                local currentRoot = getRoot()
                if currentRoot and currentRoot.Parent then
                    currentRoot.CFrame = originalCFrame
                elseif root and root.Parent then
                    root.CFrame = originalCFrame
                end
            end)
            State.Dodging = false
        end)
    end

    local function processProjectile(child)
        if not child or not child.Parent or not enabled() then return end
        if child.Name ~= "Spearprojectile" then return end

        task.spawn(function()
            if not enabled() or State.Dodging then return end

            local root = getRoot()
            if not root then return end

            task.wait(0.05)
            if not child.Parent or not enabled() then return end

            local mainPart
            pcall(function()
                mainPart = child:FindFirstChild("Hitbox", true)
                    or child:FindFirstChild("Spear1", true)
                    or child.PrimaryPart
                    or child:FindFirstChildWhichIsA("BasePart", true)
            end)
            if not mainPart or not mainPart:IsA("BasePart") then return end

            task.wait()

            root = getRoot()
            if not root then return end

            local originPos = mainPart.Position
            local spearDir = mainPart.CFrame.UpVector
            local toPlayer = root.Position - originPos
            if toPlayer.Magnitude < 0.1 then return end

            local dot = spearDir:Dot(toPlayer.Unit)
            if dot > 0.85 and enabled() then
                doDodge()
            end
        end)
    end

    local conn = Workspace.ChildAdded:Connect(function(child)
        if enabled() and isSurvivor() then
            processProjectile(child)
        end
    end)

    -- Cover projectile models that are inserted into containers instead of directly under Workspace.
    local descConn = Workspace.DescendantAdded:Connect(function(obj)
        if not enabled() or not isSurvivor() then return end
        if obj:IsA("Model") and obj.Name == "Spearprojectile" then
            processProjectile(obj)
        end
    end)

    LocalPlayer.CharacterAdded:Connect(function()
        State.Dodging = false
    end)

    return {
        State = State,
        HookSpearRemote = function() end,
        Destroy = function()
            pcall(function() conn:Disconnect() end)
            pcall(function() descConn:Disconnect() end)
            State.Dodging = false
        end,
    }
end)()

RegDivider(Tabs.SurvivalDodge)
RegToggle(Tabs.SurvivalDodge, "Auto Dodge • Veil Spear", "Source auto-dodge: Spearprojectile + arah projectile.", false, "AutoDodgeSpearVeil", function(v)
    VD.SURV_AutoDodgeSpear = v == true
    notify("Auto Dodge Spear Veil", v and "AKTIF — source logic" or "Nonaktif", 2)
end)
RegDropdown(Tabs.SurvivalDodge, "Spear Veil Dodge Mode", "Dodge style", {"Strafe", "Crouch", "Teleport"}, "Strafe", false, "SpearVeilDodgeMode")
RegSlider(Tabs.SurvivalDodge, "Spear Detection Range", "Detection radius", 50, 4, 400, 1, "SpearVeilDetectRange")
RegSlider(Tabs.SurvivalDodge, "Dodge Distance", "Teleport distance", 18, 5, 50, 1, "SpearVeilDodgeDistance")
RegToggle(Tabs.SurvivalDodge, "Spear Remote Interception", "Hook spear remote", true, "SpearVeilUseRemote")
RegToggle(Tabs.SurvivalDodge, "Detection Range", "Show range indicator", false, "SpearVeilShowIndicator")

-- Pallet Drop
LastPalletDrop = 0
ActionLock = { lastParry = 0, lastPallet = 0, parryBusy = false }
PalletCache = { List = {}, Timer = 0 }
function GetActiveParryRange()
    if VD.SURV_AutoParry then return tonumber(VD.SURV_ParryDistance) or 8 end
    return 0
end
function GetCachedPalletPoints()
    local now = tick()
    if now - PalletCache.Timer < 3 then return PalletCache.List end
    PalletCache.List = {}; PalletCache.Timer = now
    local map = Workspace:FindFirstChild("Map") or Workspace
    for _, obj in ipairs(map:GetDescendants()) do
        if obj.Name == "Palletwrong" and (obj:IsA("Model") or obj:IsA("Folder")) then
            local t = obj:FindFirstChild("PalletPointSlide") or obj:FindFirstChild("PalletPoint")
            if t and t:IsA("BasePart") then table.insert(PalletCache.List, t) end
        end
    end
    return PalletCache.List
end
function ActivatePalletAction()
    local sm = PlayerGui:FindFirstChild("Survivor-mob")
    local ctrl = sm and sm:FindFirstChild("Controls")
    local btn = ctrl and (ctrl:FindFirstChild("action") or ctrl:FindFirstChild("Action"))
    if btn then
        pcall(function() btn:Activate() end)
        if typeof(firesignal) == "function" then
            pcall(function() firesignal(btn.MouseButton1Down) end)
            task.wait(0.01)
            pcall(function() firesignal(btn.MouseButton1Up) end)
        end
        return true
    end
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    return true
end
function FirePalletDropRemote(palletPoint)
    if not palletPoint then return false end
    local fired = false
    pcall(function()
        local remotes = GetRemotes()
        local pallet = remotes and remotes:FindFirstChild("Pallet")
        local dropEvent = pallet and pallet:FindFirstChild("PalletDropEvent")
        if dropEvent then dropEvent:FireServer(palletPoint); fired = true end
    end)
    return fired
end
-- Legacy Auto Pallet Dropdown removed: Pallet Reflex is the single auto-pallet system.
-- Legacy Pallet Drop Range indicator removed with the duplicate Auto Pallet system.

-- Legacy Auto Windows Vault removed: Fast Vault is the single active vault feature.


-- Dedicated Survival > Dodge & Skillcheck routing.

-- Auto Skillcheck
SC = { busy=false, lastGoal=nil, active=false, lastLine=nil, lastTick=nil, randomMode=nil, randomGoal=nil, instantGoal=nil, instantBusy=false }
AutoSkillcheckRandomPool = {"NORMAL", "PERFECT", "INSTANT"}
BossSC = { checks = {}, lastCleanup = 0, enabled = false }
function SC_Press()
    local pressed = false
    local sm = PlayerGui:FindFirstChild("Survivor-mob")
    local controls = sm and sm:FindFirstChild("Controls")
    local action = controls and controls:FindFirstChild("action")

    if action and action:IsA("GuiButton") and action.Visible then
        -- Hanya gunakan tombol action saat prompt skillcheck memang tampil.
        pcall(function()
            action:Activate()
            pressed = true
        end)
        if typeof(firesignal) == "function" then
            pcall(function()
                firesignal(action.MouseButton1Down)
                task.wait(0.008)
                firesignal(action.MouseButton1Up)
                pressed = true
            end)
        end
    end

    -- [FIX] Gunakan E sebagai input keyboard alternatif.
    if not pressed then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.008)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            pressed = true
        end)
    end

    return pressed
end
function SC_Get()
    for _, name in ipairs({"SkillCheckPromptGui", "SkillCheckPromptGui-con"}) do
        local gui = PlayerGui:FindFirstChild(name, true)
        if gui then
            local check = gui:FindFirstChild("Check", true)
            if check and check.Visible then
                local line = check:FindFirstChild("Line", true)
                local goal = check:FindFirstChild("Goal", true)
                if line and goal then return line, goal end
            end
        end
    end
end
function SC_GetAll()
    local checks = {}
    -- Memperluas pencarian nama GUI untuk berbagai varian skillcheck
    local guiNames = {"SkillCheckPromptGui", "SkillCheckPromptGui-con", "SkillCheck", "Skillcheck", "BossSkillcheck", "KingScourgeCheck"}
    for _, name in ipairs(guiNames) do
        local gui = PlayerGui:FindFirstChild(name, true)
        if gui then
            for _, desc in ipairs(gui:GetDescendants()) do
                if desc.Name == "Check" and desc.Visible then
                    local line = desc:FindFirstChild("Line", true)
                    local goal = desc:FindFirstChild("Goal", true)
                    if line and goal then
                        table.insert(checks, { key = tostring(desc:GetFullName()), line = line, goal = goal, frame = desc })
                    end
                end
            end
        end
    end
    return checks
end
function SC_Delta(a,b) local d=(b-a)%360; if d>180 then d=d-360 end; return d end
function SC_InZone(r,a,b) r=r%360; a=a%360; b=b%360; if a<=b then return r>=a and r<=b end; return r>=a or r<=b end
function SC_Crossed(prev,now,a,b)
    if SC_InZone(now,a,b) then return true end
    if prev==nil then return false end
    local d=SC_Delta(prev,now)
    local steps=math.max(2,math.min(60,math.ceil(math.abs(d))))
    for i=1,steps do if SC_InZone((prev+d*i/steps)%360,a,b) then return true end end
    return false
end
function SC_Reset() SC.active=false; SC.busy=false; SC.lastGoal=nil; SC.lastLine=nil; SC.lastTick=nil; SC.randomMode=nil; SC.randomGoal=nil; SC.instantGoal=nil; SC.instantBusy=false end
function SC_SelectRandom(gr)
    if SC.randomGoal == nil or math.abs(SC_Delta(SC.randomGoal,gr)) > 5 then
        SC.randomMode = AutoSkillcheckRandomPool[math.random(1,#AutoSkillcheckRandomPool)]
        SC.randomGoal = gr
    end
    return SC.randomMode
end
function SC_Normal(line,goal,lr,gr,now)
    if not SC.active then SC.active=true; SC.lastGoal=gr; SC.lastLine=lr; SC.lastTick=now; return end
    if SC.lastGoal and math.abs(SC_Delta(SC.lastGoal,gr))>5 then SC.lastGoal=gr; SC.lastLine=nil; SC.lastTick=nil; SC.busy=false; return end
    SC.lastGoal=gr
    if SC.busy then SC.lastLine=lr; SC.lastTick=now; return end
    if SC.lastLine and SC.lastTick then
        if SC_Crossed(SC.lastLine,lr,gr+104,gr+109) then
            SC.busy=true
            task.spawn(function() task.wait(0.025); SC_Press(); task.delay(0.08,function() SC.busy=false end) end)
        end
    end
    SC.lastLine=lr; SC.lastTick=now
end
function SC_Perfect(line,goal,lr,gr,now)
    if not SC.active then SC.active=true; SC.lastGoal=gr; SC.lastLine=lr; SC.lastTick=now; return end
    if SC.lastGoal and math.abs(SC_Delta(SC.lastGoal,gr))>5 then SC.lastGoal=gr; SC.lastLine=nil; SC.lastTick=nil; SC.busy=false; return end
    SC.lastGoal=gr
    if SC.busy then SC.lastLine=lr; SC.lastTick=now; return end
    if SC.lastLine and SC.lastTick then
        if SC_Crossed(SC.lastLine,lr,gr+104,gr+108) then
            SC.busy=true; SC_Press(); task.delay(0.08,function() SC.busy=false end)
        end
    end
    SC.lastLine=lr; SC.lastTick=now
end
function SC_Instant(line,goal,lr,gr)
    if SC.instantGoal and math.abs(SC_Delta(SC.instantGoal,gr))<=5 then return end
    if SC.instantBusy then return end
    SC.instantGoal=gr; SC.instantBusy=true
    pcall(function() line.Rotation=goal.Rotation+109 end)
    task.spawn(function() SC_Press(); task.wait(0.18); SC.instantBusy=false end)
end
function BossSC_ProcessCheck(check, mode)
    local key, line, goal = check.key, check.line, check.goal
    if not BossSC.checks[key] then BossSC.checks[key] = { lastLine = nil, lastTick = nil, busy = false, goalSnapshot = nil } end
    local st = BossSC.checks[key]
    local lr = (tonumber(line.Rotation) or 0) % 360
    local gr = (tonumber(goal.Rotation) or 0) % 360
    if st.goalSnapshot and math.abs(SC_Delta(st.goalSnapshot, gr)) > 5 then st.lastLine, st.lastTick, st.busy, st.goalSnapshot = nil, nil, false, gr; return end
    st.goalSnapshot = gr
    if st.busy then st.lastLine = lr; st.lastTick = os.clock(); return end
    local effectiveMode = (mode == "RANDOM") and "PERFECT" or mode
    if effectiveMode == "INSTANT" then
        if st.lastLine and st.lastTick and SC_Crossed(st.lastLine, lr, gr + 104, gr + 108) then
            st.busy = true
            pcall(function() line.Rotation = goal.Rotation + 109 end)
            task.spawn(function() SC_Press(); task.wait(0.18); if BossSC.checks[key] then BossSC.checks[key].busy = false end end)
        end
        st.lastLine = lr; st.lastTick = os.clock(); return
    end
    local zoneStart = gr + 104
    local zoneEnd = (effectiveMode == "PERFECT") and (gr + 108) or (gr + 109)
    if st.lastLine and st.lastTick and SC_Crossed(st.lastLine, lr, zoneStart, zoneEnd) then
        st.busy = true
        task.spawn(function()
            SC_Press()
            task.wait(0.05) -- Delay ditambahkan agar game tidak keburu merespon spam
            if BossSC.checks[key] then BossSC.checks[key].busy = false end
        end)
    end
    st.lastLine = lr; st.lastTick = os.clock()
end
function BossSC_Cleanup(activeKeys)
    local now = os.clock()
    if now - BossSC.lastCleanup < 0.5 then return end
    BossSC.lastCleanup = now
    for key, _ in pairs(BossSC.checks) do if not activeKeys[key] then BossSC.checks[key] = nil end end
end
function BossSC_ResetAll() BossSC.checks = {} end
local SkillcheckLastUpdate = 0
RunService.RenderStepped:Connect(function()
    local now = os.clock()
    if now - SkillcheckLastUpdate < 0.05 then return end
    SkillcheckLastUpdate = now
    if not VD.AutoSkillcheck then
        -- Skillcheck mati total → reset semua state
        SC_Reset()
        BossSC_ResetAll()
        return
    end

    if VD.AutoSkillcheckBossGen then
        -- MODE BOSS: handle semua check sekaligus, TIDAK pakai SC_Get tunggal
        local allChecks = SC_GetAll()
        if #allChecks > 0 then
            local activeKeys = {}
            for _, check in ipairs(allChecks) do
                activeKeys[check.key] = true
                pcall(BossSC_ProcessCheck, check, VD.AutoSkillcheckMode)
            end
            BossSC_Cleanup(activeKeys)
            SC_Reset() -- pastikan state normal tidak nyangkut
        else
            BossSC_ResetAll()
            SC_Reset()
        end
    else
        -- MODE NORMAL: hanya check pertama
        local line, goal = SC_Get()
        if line and goal then
            local lr = (tonumber(line.Rotation) or 0) % 360
            local gr = (tonumber(goal.Rotation) or 0) % 360
            local mode = VD.AutoSkillcheckMode
            if mode == "RANDOM" then mode = SC_SelectRandom(gr) end
            if mode == "INSTANT" then
                SC_Instant(line, goal, lr, gr)
            elseif mode == "PERFECT" then
                SC_Perfect(line, goal, lr, gr, os.clock())
            else
                SC_Normal(line, goal, lr, gr, os.clock())
            end
        else
            SC_Reset()
        end
        BossSC_ResetAll()
    end
end)
RegToggle(Tabs.SurvivalDodge, "Auto Skill Check", "Auto press skillcheck", false, "AutoSkillcheck")
RegDropdown(Tabs.SurvivalDodge, "Skillcheck Mode", "Press mode", {"NORMAL", "PERFECT", "INSTANT", "RANDOM"}, "NORMAL", false, "AutoSkillcheckMode")
RegToggle(Tabs.SurvivalDodge, "Boss Generator / Kings Scourge", "Multi skillcheck support", false, "AutoSkillcheckBossGen")

--========================================================--
-- PATCH: ANTI FAKE WINDOW
--========================================================--
do
    --======================================================--
    -- BAGIAN A: ANTI FAKE WINDOW
    -- Deteksi animasi window/vault killer → set cooldown
    -- → Auto Parry V1 akan skip selama cooldown aktif.
    --======================================================--
    local FakeWinState = {
        Active   = {},
        Attached = setmetatable({}, {__mode = "k"}),
    }

    local FAKE_WINDOW_PATTERNS = {
        "window", "vault", "climb", "mantle", "slide",
        "windowvault", "fakevault", "fakewindow", "windowjump",
        "windowvaultanim", "window_vault",
    }

    local function IsWindowVaultAnim(track)
        if not track or not track.Animation then return false end
        local name = string.lower(tostring(track.Animation.Name or ""))
        if name == "" then return false end
        for _, pat in ipairs(FAKE_WINDOW_PATTERNS) do
            if name:find(pat, 1, true) then return true end
        end
        return false
    end

    function MAWWW_MarkFakeWindow(kChar)
        if not kChar then return end
        FakeWinState.Active[kChar] = tick() + (tonumber(VD.AntiFakeWindowCooldown) or 0.8)
    end

    function MAWWW_IsFakeWindowActive(kChar)
        if not kChar then return false end
        local expire = FakeWinState.Active[kChar]
        if not expire then return false end
        if tick() >= expire then
            FakeWinState.Active[kChar] = nil
            return false
        end
        return true
    end

    getgenv().MAWWW_IsFakeWindowActive = MAWWW_IsFakeWindowActive
    getgenv().MAWWW_MarkFakeWindow = MAWWW_MarkFakeWindow

    local function AttachFakeWindowSensor(kChar)
        if not kChar or FakeWinState.Attached[kChar] then return end

        local hum = kChar:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then return end

        FakeWinState.Attached[kChar] = true

        kChar.AncestryChanged:Connect(function(_, parent)
            if not parent then
                FakeWinState.Attached[kChar] = nil
                FakeWinState.Active[kChar] = nil
            end
        end)

        animator.AnimationPlayed:Connect(function(track)
            if not VD.AntiFakeWindow then return end
            if not IsWindowVaultAnim(track) then return end

            local myChar = Player.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local kRoot = kChar:FindFirstChild("HumanoidRootPart")
            if not myRoot or not kRoot then return end

            local dist = (myRoot.Position - kRoot.Position).Magnitude
            if dist <= (tonumber(VD.AntiFakeWindowRange) or 12) then
                MAWWW_MarkFakeWindow(kChar)
                if VD.AntiFakeWindowDebug then
                    print(("[AntiFakeWindow] Marked killer (%d studs)"):format(math.floor(dist)))
                end
            end
        end)
    end

    local function SetupFakeWindowPlayer(p)
        if p == Player then return end
        if not IsKiller(p) then return end

        if p.Character then AttachFakeWindowSensor(p.Character) end

        p.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            AttachFakeWindowSensor(c)
        end)

        p:GetPropertyChangedSignal("Team"):Connect(function()
            task.wait(0.1)
            if IsKiller(p) and p.Character then
                AttachFakeWindowSensor(p.Character)
            end
        end)
    end

    for _, p in ipairs(MawwwGetPlayers()) do
        SetupFakeWindowPlayer(p)
    end
    Players.PlayerAdded:Connect(SetupFakeWindowPlayer)

end

--========================================================--
-- AUTO PARRY V1
-- Namespace dipindah ke SURV_* agar tidak bentrok dengan V2.
--========================================================--
AutoParryModule = (function()
    local Players           = game:GetService("Players")
    local RunService        = game:GetService("RunService")
    local UserInputService  = game:GetService("UserInputService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Workspace         = game:GetService("Workspace")
    local CollectionService = game:GetService("CollectionService")
    local TweenService      = game:GetService("TweenService")
    local VirtualInputManager = nil
    pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)
    local LocalPlayer = Players.LocalPlayer
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local W = getgenv and getgenv() or _G
    local ShowNotify = notify or function() end
    local VD_Notify = ShowNotify
    local ForceNotify = ShowNotify
    -- Default V1 vars (SURV_* namespace)
    VD.SURV_AutoParry       = VD.SURV_AutoParry or false
    VD.SURV_ParryAggressive = VD.SURV_ParryAggressive or false
    VD.SURV_ParryDistance   = VD.SURV_ParryDistance or 10
    VD.SURV_ShowParryCircle = VD.SURV_ShowParryCircle or false
    VD.SURV_SilentParry     = VD.SURV_SilentParry or false

        -- AUTO PARRY
        --====================================================--
        local ParryState = {
            LastParry = 0, ActiveAttackers = {},
            CircleFolder = nil, CircleDashes = {}, CircleRotCFs = {}, CircleOffsets = {},
            CircleRadius = 0, CircleBuiltForDagger = false,
            CircleLastX = math.huge, CircleLastY = math.huge, CircleLastZ = math.huge,
            CircleSpawnTime = 0, CircleSpawnDuration = 0.55,
        }
        local ParryCooldown = {
            OnCooldown = false, CooldownEnd = 0,
            WaitingForResult = false, WaitingStart = 0, WaitTimeout = 2.0,
            FallbackCooldown = 60, MaxCooldown = 90, LastFiredAt = 0,
            IsSilenced = false, JustFired = false, ManualDetect = false, ManualIgnoreWindow = 0.35
        }
        local parryResultRemote, parryFireRemote
        pcall(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local items = remotes and remotes:FindFirstChild("Items")
            local dagger = items and items:FindFirstChild("Parrying Dagger")
            if dagger then
                parryResultRemote = dagger:FindFirstChild("parryResult")
                parryFireRemote = dagger:FindFirstChild("parry")
            end
        end)
        local KillerAttackAnims = {
            ["78432063483146"]="attack",["121216847022485"]="attack",["74968262036854"]="attack",
            ["132817836308238"]="attack",["82666958311998"]="attack",["111920872708571"]="attack",
            ["106871536134254"]="attack",["109402730355822"]="attack",["130593238885843"]="attack",
            ["138720291317243"]="attack",["139369275981139"]="attack",["133963973694098"]="attack",
            ["78935059863801"]="attack",
            ["118907603246885"]="lungehold",["135002183282873"]="lungehold",["113255068724446"]="lungehold",
            ["129784271201071"]="lungehold",["105374834496520"]="lungehold",["117070354890871"]="lungehold",
            ["115244153053858"]="lungehold",["110355011987939"]="lungehold",["117042998468241"]="lungehold",
            ["122812055447896"]="lungehold"
        }
        local function ParryStartCooldown(d)
            d = math.clamp(tonumber(d) or 0, 0, ParryCooldown.MaxCooldown)
            if d <= 0 then d = ParryCooldown.FallbackCooldown end
            ParryCooldown.OnCooldown = true
            ParryCooldown.CooldownEnd = os.clock() + d
            ParryCooldown.WaitingForResult = false
            ParryCooldown.JustFired = false
            ParryCooldown.ManualDetect = false
        end
        local function ParryClearCooldown()
            ParryCooldown.OnCooldown = false
            ParryCooldown.CooldownEnd = 0
            ParryCooldown.WaitingForResult = false
            ParryCooldown.JustFired = false
            ParryCooldown.ManualDetect = false
        end
        local function ParryIsOnCooldown()
            if not ParryCooldown.OnCooldown then return false end
            if os.clock() >= ParryCooldown.CooldownEnd then ParryClearCooldown(); return false end
            return true
        end
        if parryResultRemote then
            parryResultRemote.OnClientEvent:Connect(function(success, cd)
                if not ParryCooldown.WaitingForResult and not ParryCooldown.JustFired then return end
                local c = tonumber(cd) or 0
                if success and c > 0 then ParryStartCooldown(math.min(c, ParryCooldown.MaxCooldown))
                else ParryStartCooldown(ParryCooldown.FallbackCooldown) end
            end)
        end
        local function ParryHookSilenced(char)
            if not char then return end
            ParryCooldown.IsSilenced = CollectionService:HasTag(char, "Silenced")
        end
        CollectionService:GetInstanceAddedSignal("Silenced"):Connect(function(i)
            if i == LocalPlayer.Character then ParryCooldown.IsSilenced = true end
        end)
        CollectionService:GetInstanceRemovedSignal("Silenced"):Connect(function(i)
            if i == LocalPlayer.Character then ParryCooldown.IsSilenced = false end
        end)
        LocalPlayer.CharacterAdded:Connect(function(c) task.wait(0.5); ParryHookSilenced(c) end)
        if LocalPlayer.Character then ParryHookSilenced(LocalPlayer.Character) end

        local ParryCharCache = { Char=nil, Root=nil, Hum=nil, UpperTorso=nil, CheckInt=nil }
        local function ParryGetCharCache()
            local char = LocalPlayer.Character
            if char ~= ParryCharCache.Char then
                ParryCharCache.Char = char
                ParryCharCache.Root = nil; ParryCharCache.Hum = nil
                ParryCharCache.UpperTorso = nil; ParryCharCache.CheckInt = nil
            end
            if not char then return ParryCharCache end
            if not ParryCharCache.Root then ParryCharCache.Root = char:FindFirstChild("HumanoidRootPart") end
            if not ParryCharCache.Hum then ParryCharCache.Hum = char:FindFirstChildOfClass("Humanoid") end
            if not ParryCharCache.UpperTorso then
                ParryCharCache.UpperTorso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
            end
            if not ParryCharCache.CheckInt then ParryCharCache.CheckInt = char:FindFirstChild("CheckInterractable") end
            return ParryCharCache
        end
        local DaggerCache = { Value = false, LastCheck = 0, Interval = 0.15 }
        local function ParryIsDaggerModel(inst)
            if not inst then return false end
            return inst:IsA("Model") or inst:IsA("Tool") or inst:IsA("Accessory")
        end
        local function ParryIsEquippedDagger()
            local now = os.clock()
            if now - DaggerCache.LastCheck < DaggerCache.Interval then return DaggerCache.Value end
            DaggerCache.LastCheck = now
            local hasDagger = false
            local char = LocalPlayer.Character
            if char then
                local d = char:FindFirstChild("Parrying Dagger")
                if ParryIsDaggerModel(d) then hasDagger = true end
            end
            if not hasDagger then
                local wsChar = Workspace:FindFirstChild(LocalPlayer.Name)
                if wsChar then
                    local d = wsChar:FindFirstChild("Parrying Dagger")
                    if ParryIsDaggerModel(d) then hasDagger = true end
                end
            end
            DaggerCache.Value = hasDagger
            return hasDagger
        end
        LocalPlayer.CharacterAdded:Connect(function() DaggerCache.Value = false; DaggerCache.LastCheck = 0 end)

        local ParryCheckAttrs = {"isVaulting","isSliding","isDroppingPallet","isRepairing","isHealing","isUnhooking","isExiting"}
        local function ParryIsBusy()
            local cc = ParryGetCharCache()
            if not cc.Char then return true end
            if LocalPlayer:GetAttribute("IsDead") then return true end
            if cc.Char:GetAttribute("IsCarried") then return true end
            if cc.Char:GetAttribute("IsHooked") then return true end
            if cc.Root and CollectionService:HasTag(cc.Root, "doing action") then return true end
            if cc.CheckInt then
                for i = 1, #ParryCheckAttrs do
                    if cc.CheckInt:GetAttribute(ParryCheckAttrs[i]) then return true end
                end
            end
            return false
        end
        local function ParryIsLowHealth()
            local hum = ParryGetCharCache().Hum
            if not hum then return false end
            return hum.Health < hum.MaxHealth * 0.5
        end
        local function ParryCanFire()
            if not ParryIsEquippedDagger() then return false end
            if ParryCooldown.IsSilenced then return false end
            if ParryIsOnCooldown() then return false end
            if ParryCooldown.WaitingForResult then return false end
            if ParryIsBusy() then return false end
            if ParryIsLowHealth() then return false end
            return true
        end
        local function ParryExecuteMobile()
            local didFire = false
            local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            if pGui and type(firesignal) == "function" then
                local mobRoot = pGui:FindFirstChild("Survivor-mob")
                local controls = mobRoot and mobRoot:FindFirstChild("Controls")
                if controls then
                    for _, n in ipairs({"Gui-mob","action","Gui-mobile","Gui_mob","Parry","parry"}) do
                        local btn = controls:FindFirstChild(n)
                        if btn and btn:IsA("GuiButton") then
                            pcall(function()
                                firesignal(btn.MouseButton1Down)
                                task.delay(0.05, function()
                                    if btn and btn.Parent then
                                        firesignal(btn.MouseButton1Up)
                                        firesignal(btn.MouseButton1Click)
                                    end
                                end)
                            end)
                            didFire = true; break
                        end
                    end
                end
            end
            if not didFire then
                local remote = ReplicatedStorage:FindFirstChild("Remotes")
                local items = remote and remote:FindFirstChild("Items")
                local dagger = items and items:FindFirstChild("Parrying Dagger")
                local parry = dagger and dagger:FindFirstChild("parry")
                if parry then pcall(function() parry:FireServer() end) end
            end
        end
        local function ParryExecutePC()
            if not VirtualInputManager then return end
            pcall(function()
                VirtualInputManager:SendMouseMoveEvent(0, 0, game)
                task.wait(0.005)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 2, true, game, 0)
                task.wait(0.05)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 2, false, game, 0)
            end)
        end
        local function ParryExecuteSilent()
            if parryFireRemote then return pcall(function() parryFireRemote:FireServer() end) end
            return false
        end
        local function ParryExecute()
            if not ParryCanFire() then return end
            ParryState.LastParry = os.clock()
            ParryCooldown.LastFiredAt = os.clock()
            ParryCooldown.WaitingForResult = true
            ParryCooldown.WaitingStart = os.clock()
            ParryCooldown.JustFired = true
            ParryCooldown.ManualDetect = false
            if VD.SURV_SilentParry then ParryExecuteSilent(); return end
            if isMobile then ParryExecuteMobile() else ParryExecutePC() end
        end
        local function ParryMarkManual()
            if not ParryIsEquippedDagger() then return end
            if ParryCooldown.IsSilenced then return end
            if os.clock() - ParryCooldown.LastFiredAt < ParryCooldown.ManualIgnoreWindow then return end
            if ParryCooldown.OnCooldown or ParryCooldown.WaitingForResult then return end
            ParryCooldown.WaitingForResult = true
            ParryCooldown.WaitingStart = os.clock()
            ParryCooldown.JustFired = true
            ParryCooldown.ManualDetect = true
            ParryCooldown.LastFiredAt = os.clock()
        end
        UserInputService.InputBegan:Connect(function(input, gp)
            if input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
            if gp then return end
            ParryMarkManual()
        end)
        local parryHookedButtons = setmetatable({}, {__mode = "k"})
        local function ParryTryHookMobileButton(inst)
            if not inst or not inst:IsA("GuiButton") then return end
            if parryHookedButtons[inst] then return end
            local nm = inst.Name
            if nm ~= "Gui-mob" and nm ~= "action" and nm ~= "Gui-mobile"
                and nm ~= "Gui_mob" and nm ~= "Parry" and nm ~= "parry" then return end
            parryHookedButtons[inst] = true
            inst.MouseButton1Down:Connect(ParryMarkManual)
        end
        local function ParryScanForMobileButtons(root)
            if not root then return end
            for _, d in ipairs(root:GetDescendants()) do ParryTryHookMobileButton(d) end
        end
        local function ParryAttachPlayerGui(pGui)
            if not pGui then return end
            ParryScanForMobileButtons(pGui)
            pGui.DescendantAdded:Connect(ParryTryHookMobileButton)
        end
        local existingPGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if existingPGui then ParryAttachPlayerGui(existingPGui) end
        LocalPlayer.ChildAdded:Connect(function(c)
            if c:IsA("PlayerGui") then ParryAttachPlayerGui(c) end
        end)

        local function ParryGetHitboxPart(char)
            if not char then return nil end
            return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
        end
        --========================================================--
        -- [PATCH V1] SMART TRIGGER HELPERS — Anti false-trigger
        --========================================================--
        local function ParryV1_IsDowned(char)
            if not char then return true end
            if char:GetAttribute("Knocked") == true then return true end
            if char:GetAttribute("IsHooked") == true then return true end
            if char:GetAttribute("HookProgressDepleting") == true then return true end
            if char:GetAttribute("IsCarried") == true then return true end

            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return true end
            return false
        end

        local function ParryV1_WallBlocked(originPos, targetPos, killerChar)
            if VD.PARRY_V1_WallCheck == false then return false end
            if VD.PARRY_V1_Raycast == false then return false end

            local range = tonumber(VD.PARRY_V1_RaycastRange) or 20
            local offset = targetPos - originPos
            local dist = offset.Magnitude
            if dist > range or dist < 0.1 then return false end

            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.IgnoreWater = true

            local exclude = {}
            if LocalPlayer.Character then table.insert(exclude, LocalPlayer.Character) end
            if killerChar then table.insert(exclude, killerChar) end
            params.FilterDescendantsInstances = exclude

            local hit = Workspace:Raycast(originPos, offset.Unit * dist, params)
            return hit ~= nil
        end

        local function ParryV1_FacingUs(killerChar, myPos)
            if VD.PARRY_V1_IgnoreFacing == true then return true end

            local root = killerChar and killerChar:FindFirstChild("HumanoidRootPart")
            if not root then return true end

            local look = root.CFrame.LookVector
            local lookFlat = Vector3.new(look.X, 0, look.Z)
            local toMe = myPos - root.Position
            local toMeFlat = Vector3.new(toMe.X, 0, toMe.Z)

            if lookFlat.Magnitude < 0.01 or toMeFlat.Magnitude < 0.01 then
                return true
            end

            local minFacing = tonumber(VD.PARRY_V1_MinFacing) or 0.5
            return lookFlat.Unit:Dot(toMeFlat.Unit) >= minFacing
        end

        local function ParryV1_PredictPosition(killerPart, killerRoot)
            local ping = 0
            pcall(function()
                ping = math.clamp(LocalPlayer:GetNetworkPing(), 0, 0.3)
            end)

            local velocity = Vector3.zero
            pcall(function()
                velocity = (killerRoot and killerRoot.AssemblyLinearVelocity) or Vector3.zero
            end)

            local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
            local predictTime = ping + 0.08
            return killerPart.Position + flatVelocity * predictTime, flatVelocity, ping
        end

        --========================================================--
        -- [PATCH V1] PARryCheck — SMART TRIGGER + ANTI MISS
        --========================================================--
        local ParryV1_FakeLog = setmetatable({}, {__mode = "k"})

        local function ParryCheckAndParry(killerChar)
            -- Gate: cooldown, dagger, silenced
            if ParryIsOnCooldown() or ParryCooldown.WaitingForResult
                or ParryCooldown.IsSilenced or not ParryIsEquippedDagger() then return end

            local cc = ParryGetCharCache()
            local myRoot = cc.UpperTorso or cc.Root
            local killerPart = ParryGetHitboxPart(killerChar)
            if not myRoot or not killerPart then return end

            -- [ANTI FALSE-TRIGGER 1] Ignore downed/hooked/carried killer
            if VD.PARRY_V1_IgnoreDown ~= false then
                if ParryV1_IsDowned(killerChar) then return end
            end

            -- [ANTI FALSE-TRIGGER 2] Wall check (blocked by obstacle)
            if VD.PARRY_V1_WallCheck ~= false then
                if ParryV1_WallBlocked(killerPart.Position, myRoot.Position, killerChar) then return end
            end

            -- [ANTI FALSE-TRIGGER 3] Facing check (killer harus hadap ke kita)
            if not ParryV1_FacingUs(killerChar, myRoot.Position) then return end

            -- [ANTI MISS] Predict posisi + velocity + ping
            local killerRoot = killerChar:FindFirstChild("HumanoidRootPart") or killerPart
            local predictedPos, flatVel, ping = ParryV1_PredictPosition(killerPart, killerRoot)

            local maxDist = tonumber(VD.SURV_ParryDistance) or 10
            local dist = (myRoot.Position - killerPart.Position).Magnitude
            local predDist = (myRoot.Position - predictedPos).Magnitude

            -- [ANTI FALSE-TRIGGER 4] Minimum velocity unless already close.
            local minVel = tonumber(VD.PARRY_V1_MinVelocity) or 2
            if dist > (maxDist * 0.6) and flatVel.Magnitude < minVel then
                return
            end

            -- [ANTI FALSE-TRIGGER 5] Prevent immediate repeat on same killer.
            local now = os.clock()
            local lastParryForChar = ParryV1_FakeLog[killerChar]
            if lastParryForChar and (now - lastParryForChar) < 0.15 then
                return
            end

            -- [ANTI FALSE-TRIGGER 6] Skip suspicious stationary close windows.
            if VD.PARRY_V1_AntiFake ~= false then
                local fakeDist = tonumber(VD.PARRY_V1_FakeDistance) or 2.5
                if dist <= fakeDist and flatVel.Magnitude < (minVel * 0.8) then
                    return
                end
            end

            -- ============== DECISION ==============
            local shouldParry = false

            if VD.SURV_ParryAggressive then
                -- MODE AGRESIF: pakai prediksi penuh + arah lunge
                if predDist <= (maxDist + 2.5) and flatVel.Magnitude > 6 then
                    local dir = myRoot.Position - killerPart.Position
                    if dir.Magnitude > 0.1 and flatVel.Unit:Dot(dir.Unit) > 0.4 then
                        shouldParry = true
                    end
                end
            end

            -- Normal fallback: dalam range prediksi
            if not shouldParry and predDist <= maxDist then
                if VD.PARRY_V1_Safety ~= false then
                    -- [SAFETY] Butuh minimal velocity ATAU benar-benar dekat
                    local veryClose = dist <= (maxDist * 0.6)
                    if veryClose or flatVel.Magnitude >= minVel then
                        shouldParry = true
                    end
                else
                    shouldParry = true
                end
            end

            -- [ANTI MISS] Extended window for fast lunges.
            if not shouldParry and flatVel.Magnitude > 12 then
                local extendedRange = maxDist + (flatVel.Magnitude * ping)
                if predDist <= extendedRange then
                    shouldParry = true
                end
            end

            if shouldParry then
                ParryV1_FakeLog[killerChar] = now
                ParryExecute()
            end
        end
        local function ParryDestroyCircle()
            if ParryState.CircleFolder then
                pcall(function() if ParryState.CircleFolder.Parent then ParryState.CircleFolder:Destroy() end end)
            end
            ParryState.CircleFolder = nil
            ParryState.CircleDashes = {}
            ParryState.CircleRotCFs = {}
            ParryState.CircleOffsets = {}
            ParryState.CircleRadius = 0
            ParryState.CircleBuiltForDagger = false
            ParryState.CircleLastX = math.huge
            ParryState.CircleLastY = math.huge
            ParryState.CircleLastZ = math.huge
            ParryState.CircleSpawnTime = 0
        end
        getgenv()._Gluto_DestroyParryCircle = ParryDestroyCircle
        local function ParryBuildCircle(radius)
            ParryDestroyCircle()
            local folder = Instance.new("Folder")
            folder.Name = "MawwwParryV1Circle"
            local dashCount = math.clamp(math.floor(radius * 6), 24, 120)
            local slotLength = (2 * math.pi * radius) / dashCount
            local dashLength = slotLength * 0.55
            local dashThickness = 0.03
            local dashes, rotCFs, offsets = table.create(dashCount), table.create(dashCount), table.create(dashCount)
            for i = 1, dashCount do
                local part = Instance.new("Part")
                part.Name = "Dash" .. i
                part.Anchored = true; part.CanCollide = false
                part.CanTouch = false; part.CanQuery = false; part.CastShadow = false
                part.Material = Enum.Material.Neon
                part.Color = Color3.fromRGB(255, 255, 255)
                part.Transparency = 1
                part.Size = Vector3.new(dashThickness, dashThickness, dashLength)
                part.Parent = folder
                local angle = ((i - 1) / dashCount) * math.pi * 2
                local cosA, sinA = math.cos(angle), math.sin(angle)
                rotCFs[i] = CFrame.lookAt(Vector3.zero, Vector3.new(-sinA, 0, cosA))
                offsets[i] = Vector3.new(cosA * radius, 0, sinA * radius)
                dashes[i] = part
            end
            folder.Parent = Workspace
            ParryState.CircleFolder = folder
            ParryState.CircleDashes = dashes
            ParryState.CircleRotCFs = rotCFs
            ParryState.CircleOffsets = offsets
            ParryState.CircleRadius = radius
            ParryState.CircleBuiltForDagger = true
            ParryState.CircleSpawnTime = tick()
        end
        local function ParryUpdateCircle(myRoot)
            if not ParryState.CircleFolder or not ParryState.CircleFolder.Parent then return end
            local dashes = ParryState.CircleDashes
            local dashCount = #dashes
            if dashCount == 0 then return end
            local center = myRoot.Position - Vector3.new(0, (myRoot.Size.Y * 0.5) + 1.0, 0)
            local elapsed = tick() - (ParryState.CircleSpawnTime or 0)
            local spawnT = math.clamp(elapsed / (ParryState.CircleSpawnDuration or 0.55), 0, 1)
            local eased = 1 - (1 - spawnT)^3
            local scaleMult = eased
            if spawnT < 0.7 and spawnT > 0 then
                local bt = spawnT / 0.7
                scaleMult = eased + math.sin(bt * math.pi) * 0.1
            end
            local spinRot = (1 - eased) * math.pi * 2
            local spawnAlpha = 1 - eased
            local busy = ParryIsBusy()
            local onCD = ParryCooldown.OnCooldown
            local tc
            if busy then tc = Color3.fromRGB(255, 20, 20)
            elseif onCD then tc = Color3.fromRGB(255, 140, 0)
            else tc = Color3.fromRGB(255, 255, 255) end
            local targetT = 0
            if onCD then
                local period = 0.55
                local phase = (os.clock() % period) / period
                local pulse = (math.cos(phase * math.pi * 2) + 1) * 0.5
                targetT = (1 - pulse) * 0.85
            end
            local finalT = math.max(targetT, spawnAlpha)
            local dx = math.abs(center.X - ParryState.CircleLastX)
            local dy = math.abs(center.Y - ParryState.CircleLastY)
            local dz = math.abs(center.Z - ParryState.CircleLastZ)
            if dx < 0.01 and dy < 0.01 and dz < 0.01 and spawnT >= 1 then return end
            ParryState.CircleLastX = center.X
            ParryState.CircleLastY = center.Y
            ParryState.CircleLastZ = center.Z
            local rotCFs = ParryState.CircleRotCFs
            local offsets = ParryState.CircleOffsets
            local rotCF = CFrame.Angles(0, spinRot, 0)
            for i = 1, dashCount do
                local dash = dashes[i]
                if dash and dash.Parent then
                    local scaledOff = offsets[i] * scaleMult
                    local rotatedOff = rotCF:VectorToWorldSpace(scaledOff)
                    local worldPos = Vector3.new(center.X + rotatedOff.X, center.Y, center.Z + rotatedOff.Z)
                    dash.CFrame = (rotCF * rotCFs[i]) + worldPos
                    dash.Color = tc
                    dash.Transparency = finalT
                end
            end
        end
        local function ParryGetAnimType(track)
            if not track or not track.Animation then return nil end
            local animId = track.Animation.AnimationId or ""
            local numId = animId:match("%d+") or ""
            local name = string.lower(track.Animation.Name or "")
            local v = KillerAttackAnims[animId]
            if v then return v end
            if numId ~= "" then v = KillerAttackAnims[numId]; if v then return v end end
            if string.find(name, "lunge", 1, true) or string.find(name, "charge", 1, true) then return "lungehold" end
            if string.find(name, "attack", 1, true) or string.find(name, "slash", 1, true)
                or string.find(name, "swing", 1, true) or string.find(name, "stab", 1, true)
                or string.find(name, "melee", 1, true) then return "attack" end
            return nil
        end
        local function ParryHookAnimatorOnChar(plr, char)
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            local anim = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 3)
            if not anim then return end
            anim.AnimationPlayed:Connect(function(track)
                if not VD.SURV_AutoParry then return end
                if not ParryIsEquippedDagger() then return end
                local at = ParryGetAnimType(track)
                if at then
                    ParryState.ActiveAttackers[plr] = { char = char, track = track, type = at, registeredAt = os.clock() }
                end
            end)
        end
        local function ParryHookKillerPlayer(plr)
            if plr == LocalPlayer then return end
            if plr.Character then ParryHookAnimatorOnChar(plr, plr.Character) end
            plr.CharacterAdded:Connect(function(char) task.wait(0.5); ParryHookAnimatorOnChar(plr, char) end)
        end
        for _, p in ipairs(MawwwGetPlayers()) do ParryHookKillerPlayer(p) end
        Players.PlayerAdded:Connect(ParryHookKillerPlayer)
        local parryLastPoll = 0
        local function ParryPollAttacks()
            if not VD.SURV_AutoParry or not ParryIsEquippedDagger() then return end
            local now = os.clock()
            if now - parryLastPoll < 0.15 then return end
            parryLastPoll = now
            for _, plr in ipairs(MawwwGetPlayers()) do
                if plr ~= LocalPlayer then
                    local char = plr.Character
                    if char then
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if hum then
                            for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                                local at = ParryGetAnimType(track)
                                if at then
                                    local ex = ParryState.ActiveAttackers[plr]
                                    if not ex or ex.track ~= track then
                                        ParryState.ActiveAttackers[plr] = { char = char, track = track, type = at, registeredAt = now }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        local parryLastCleanup = 0
        local function ParryCleanupAttackers()
            local now = os.clock()
            if now - parryLastCleanup < 1.0 then return end
            parryLastCleanup = now
            for plr, data in pairs(ParryState.ActiveAttackers) do
                if not plr or not plr.Parent or not data.track or not data.track.IsPlaying then
                    ParryState.ActiveAttackers[plr] = nil
                end
            end
        end
        local function ParryUpdateLogic()
            if not VD.SURV_AutoParry then return end
            if not ParryIsEquippedDagger() then ParryState.ActiveAttackers = {}; return end
            if ParryCooldown.WaitingForResult then
                if os.clock() - ParryCooldown.WaitingStart > ParryCooldown.WaitTimeout then
                    if ParryCooldown.ManualDetect then
                        ParryCooldown.WaitingForResult = false
                        ParryCooldown.JustFired = false
                        ParryCooldown.ManualDetect = false
                    else
                        ParryStartCooldown(ParryCooldown.FallbackCooldown)
                    end
                end
            end
            if ParryIsOnCooldown() or ParryCooldown.WaitingForResult then return end
            ParryPollAttacks()
            ParryCleanupAttackers()
            for plr, data in pairs(ParryState.ActiveAttackers) do
                if plr and plr.Parent and data.track and data.track.IsPlaying then
                    local shouldCheck = false
                    if data.type == "attack" then
                        if data.track.TimePosition < 0.35 then shouldCheck = true end
                    elseif data.type == "lungehold" then
                        shouldCheck = true
                    end
                    if shouldCheck then
                        ParryCheckAndParry(data.char)
                        if ParryCooldown.WaitingForResult then break end
                    end
                else
                    ParryState.ActiveAttackers[plr] = nil
                end
            end
        end
        local function ParryUpdateCircleLogic()
            local char = LocalPlayer.Character
            local myRoot = char and char:FindFirstChild("HumanoidRootPart")
            if VD.SURV_ShowParryCircle and myRoot then
                if not ParryState.CircleFolder or ParryState.CircleRadius ~= (VD.SURV_ParryDistance or 10) or not ParryState.CircleFolder.Parent then
                    ParryBuildCircle(VD.SURV_ParryDistance or 10)
                end
                ParryUpdateCircle(myRoot)
            else
                if ParryState.CircleFolder then ParryDestroyCircle() end
            end
        end

    -- Main update loop (from text5 UPDATE LOOPS)
        local parryLastLogic, parryLastCircle = 0, 0
        RunService.Heartbeat:Connect(function()
            local now = os.clock()
            if now - parryLastCircle >= 0.033 then parryLastCircle = now; pcall(ParryUpdateCircleLogic) end
            if now - parryLastLogic >= 0.05 then parryLastLogic = now; pcall(ParryUpdateLogic) end
        end)

    return {
        DestroyCircle = ParryDestroyCircle,
        ForceRedraw = function()
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if VD.SURV_ShowParryCircle and root then
                local radius = math.clamp(tonumber(VD.SURV_ParryDistance) or 10, 1, 100)
                ParryBuildCircle(radius)
                ParryUpdateCircle(root)
            else
                ParryDestroyCircle()
            end
        end,
        State = ParryState,
        Cooldown = ParryCooldown,
    }
end)()

--========================================================--
-- UI: AUTO PARRY V1
--========================================================--
RegDivider(Tabs.SurvivalParryV1)
RegLabel(Tabs.SurvivalParryV1, "Auto Parry V1")
RegToggle(Tabs.SurvivalParryV1, "Auto Parry V1", "Auto parry engine dari Text5 (mawww).", false, "SURV_AutoParry", function(v)
    notify("Auto Parry V1", v and "Enabled — Text5 engine" or "Disabled", 2)
end)
RegToggle(Tabs.SurvivalParryV1, "Aggressive Prediction", "Prediksi lintasan killer + trigger dinamis berbasis kecepatan.", false, "SURV_ParryAggressive")
RegSlider(Tabs.SurvivalParryV1, "Parry Distance", "Jarak trigger parry. Default 10.", 10, 4, 30, 1, "SURV_ParryDistance")
RegToggle(Tabs.SurvivalParryV1, "Show Parry Range", "Tampilkan lingkaran radius parry V1.", VD.SURV_ShowParryCircle == true, "SURV_ShowParryCircle", function(v)
    VD.ShowParryRangeV1 = v and true or false
    if v then
        if AutoParryModule and AutoParryModule.ForceRedraw then pcall(AutoParryModule.ForceRedraw) end
    else
        if AutoParryModule and AutoParryModule.DestroyCircle then pcall(AutoParryModule.DestroyCircle) end
    end
end)
RegToggle(Tabs.SurvivalParryV1, "Silent Parry", "Parry via direct remote ONLY — tanpa simulasi input.", false, "SURV_SilentParry")
RegToggle(Tabs.SurvivalParryV1, "Wall Check",
    "Batalkan parry kalau ada dinding/objek antara kita dan killer.",
    true, "PARRY_V1_WallCheck")
RegToggle(Tabs.SurvivalParryV1, "Ignore Downed",
    "Jangan parry killer yang sedang downed/hooked/carried.",
    true, "PARRY_V1_IgnoreDown")
RegToggle(Tabs.SurvivalParryV1, "Anti-Fake Window",
    "Deteksi fake attack: skip parry saat killer diam sangat dekat tanpa velocity.",
    true, "PARRY_V1_AntiFake")
RegToggle(Tabs.SurvivalParryV1, "Ignore Facing",
    "Matikan facing check.",
    false, "PARRY_V1_IgnoreFacing")
RegToggle(Tabs.SurvivalParryV1, "Safety Check",
    "Parry hanya kalau killer bergerak cukup cepat atau sangat dekat.",
    true, "PARRY_V1_Safety")
RegSlider(Tabs.SurvivalParryV1, "Facing Threshold",
    "Seberapa menghadap killer harus ke kita.",
    0.5, 0.1, 0.9, 0.05, "PARRY_V1_MinFacing")
RegSlider(Tabs.SurvivalParryV1, "Minimum Velocity",
    "Velocity minimum killer agar parry dianggap valid.",
    2, 0.5, 15, 0.5, "PARRY_V1_MinVelocity")
RegSlider(Tabs.SurvivalParryV1, "Raycast Range",
    "Jarak maksimum raycast wall-check.",
    20, 5, 60, 1, "PARRY_V1_RaycastRange")
RegToggle(Tabs.SurvivalParryV1, "Raycast Wall Check",
    "Kalau OFF, wall check dinonaktifkan.",
    true, "PARRY_V1_Raycast")
RegSlider(Tabs.SurvivalParryV1, "Fake Distance",
    "Kalau killer sangat dekat dan velocity rendah, dianggap fake.",
    2.5, 0.5, 8, 0.5, "PARRY_V1_FakeDistance")

--========================================================--
-- AUTO PARRY V2 — SOURCE: maww hub (no bug 24 september)
--========================================================--
RegDivider(Tabs.SurvivalParryV2)
RegLabel(Tabs.SurvivalParryV2, "Auto Parry V2")
ParryV2 = (function()
    local LocalPlayer = Player
    local NEON_PURPLE_V2 = Color3.fromRGB(180, 60, 255)

    local State = {
        LastParry = 0,
        ActiveAttackers = {},
        CircleFolder = nil,
        CircleDashes = {},
        CircleRotCFs = {},
        CircleOffsets = {},
        CircleRadius = 0,
        CircleBuiltForDagger = false,
        CircleLastX = math.huge,
        CircleLastY = math.huge,
        CircleLastZ = math.huge,
        CircleLastAlpha = -1,
        CircleLastR = -1,
        CircleLastG = -1,
        CircleLastB = -1,
    }

    local Cooldown = {
        OnCooldown = false,
        CooldownEnd = 0,
        CooldownDuration = 0,
        WaitingForResult = false,
        WaitingStart = 0,
        WaitTimeout = 2.0,
        FallbackCooldown = 60,
        MaxCooldown = 90,
        LastFiredAt = 0,
        IsSilenced = false,
        JustFired = false,
        ManualDetect = false,
        ManualIgnoreWindow = 0.35,
    }

    local parryResultRemote, parryFireRemote
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            local items = remotes:FindFirstChild("Items")
            if items then
                local dagger = items:FindFirstChild("Parrying Dagger")
                if dagger then
                    parryResultRemote = dagger:FindFirstChild("parryResult")
                    parryFireRemote = dagger:FindFirstChild("parry")
                end
            end
        end
    end)

    local KillerAttackAnims = {
        ["78432063483146"] = "attack", ["121216847022485"] = "attack",
        ["74968262036854"] = "attack", ["132817836308238"] = "attack",
        ["82666958311998"] = "attack", ["111920872708571"] = "attack",
        ["106871536134254"] = "attack", ["109402730355822"] = "attack",
        ["130593238885843"] = "attack", ["138720291317243"] = "attack",
        ["139369275981139"] = "attack", ["133963973694098"] = "attack",
        ["78935059863801"] = "attack",
        ["118907603246885"] = "lungehold", ["135002183282873"] = "lungehold",
        ["113255068724446"] = "lungehold", ["129784271201071"] = "lungehold",
        ["105374834496520"] = "lungehold", ["117070354890871"] = "lungehold",
        ["115244153053858"] = "lungehold", ["110355011987939"] = "lungehold",
        ["117042998468241"] = "lungehold", ["122812055447896"] = "lungehold",
    }

    local function StartCooldown(duration)
        duration = math.clamp(tonumber(duration) or 0, 0, Cooldown.MaxCooldown)
        if duration <= 0 then duration = Cooldown.FallbackCooldown end
        Cooldown.OnCooldown = true
        Cooldown.CooldownDuration = duration
        Cooldown.CooldownEnd = os.clock() + duration
        Cooldown.WaitingForResult = false
        Cooldown.JustFired = false
        Cooldown.ManualDetect = false
    end

    local function ClearCooldown()
        Cooldown.OnCooldown = false
        Cooldown.CooldownEnd = 0
        Cooldown.CooldownDuration = 0
        Cooldown.WaitingForResult = false
        Cooldown.JustFired = false
        Cooldown.ManualDetect = false
    end

    local function IsOnCooldown()
        if not Cooldown.OnCooldown then return false end
        if os.clock() >= Cooldown.CooldownEnd then ClearCooldown(); return false end
        return true
    end

    if parryResultRemote then
        parryResultRemote.OnClientEvent:Connect(function(success, cooldown)
            if not Cooldown.WaitingForResult and not Cooldown.JustFired then return end
            local cd = tonumber(cooldown) or 0
            if success and cd > 0 then
                StartCooldown(math.min(cd, Cooldown.MaxCooldown))
            else
                StartCooldown(Cooldown.FallbackCooldown)
            end
        end)
    end

    local function HookSilenced(char)
        if not char then return end
        Cooldown.IsSilenced = CollectionService:HasTag(char, "Silenced")
    end
    CollectionService:GetInstanceAddedSignal("Silenced"):Connect(function(inst)
        if inst == LocalPlayer.Character then Cooldown.IsSilenced = true end
    end)
    CollectionService:GetInstanceRemovedSignal("Silenced"):Connect(function(inst)
        if inst == LocalPlayer.Character then Cooldown.IsSilenced = false end
    end)
    LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.5); HookSilenced(char)
    end)
    if LocalPlayer.Character then HookSilenced(LocalPlayer.Character) end

    local CharCache = { Char = nil, Root = nil, Hum = nil, UpperTorso = nil, CheckInt = nil }
    local function GetCharCache()
        local char = LocalPlayer.Character
        if char ~= CharCache.Char then
            CharCache.Char = char; CharCache.Root = nil; CharCache.Hum = nil
            CharCache.UpperTorso = nil; CharCache.CheckInt = nil
        end
        if not char then return CharCache end
        if not CharCache.Root then CharCache.Root = char:FindFirstChild("HumanoidRootPart") end
        if not CharCache.Hum then CharCache.Hum = char:FindFirstChildOfClass("Humanoid") end
        if not CharCache.UpperTorso then
            CharCache.UpperTorso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        end
        if not CharCache.CheckInt then CharCache.CheckInt = char:FindFirstChild("CheckInterractable") end
        return CharCache
    end

    local DaggerCache = { Value = false, LastCheck = 0, Interval = 0.15 }
    local function IsDaggerModel(inst)
        if not inst then return false end
        if inst:IsA("Model") or inst:IsA("Tool") or inst:IsA("Accessory") then return true end
        return false
    end
    local function IsEquippedDagger()
        local now = os.clock()
        if now - DaggerCache.LastCheck < DaggerCache.Interval then return DaggerCache.Value end
        DaggerCache.LastCheck = now
        local has = false
        local char = LocalPlayer.Character
        if char and IsDaggerModel(char:FindFirstChild("Parrying Dagger")) then has = true end
        if not has then
            local wsChar = Workspace:FindFirstChild(LocalPlayer.Name)
            if wsChar and IsDaggerModel(wsChar:FindFirstChild("Parrying Dagger")) then has = true end
        end
        DaggerCache.Value = has
        return has
    end
    LocalPlayer.CharacterAdded:Connect(function() DaggerCache.Value = false; DaggerCache.LastCheck = 0 end)

    local CheckAttrs = {"isVaulting","isSliding","isDroppingPallet","isRepairing","isHealing","isUnhooking","isExiting"}
    local function IsBusy()
        local cc = GetCharCache()
        if not cc.Char then return true end
        if LocalPlayer:GetAttribute("IsDead") then return true end
        if cc.Char:GetAttribute("IsCarried") then return true end
        if cc.Char:GetAttribute("IsHooked") then return true end
        local root = cc.Root
        if root and CollectionService:HasTag(root, "doing action") then return true end
        local ci = cc.CheckInt
        if ci then
            for i = 1, #CheckAttrs do
                if ci:GetAttribute(CheckAttrs[i]) then return true end
            end
        end
        return false
    end

    local function IsLowHealth()
        local cc = GetCharCache()
        local hum = cc.Hum
        if not hum then return false end
        return hum.Health < hum.MaxHealth * 0.5
    end

    local function CanFire()
        if not IsEquippedDagger() then return false end
        if Cooldown.IsSilenced then return false end
        if IsOnCooldown() then return false end
        if Cooldown.WaitingForResult then return false end
        if IsBusy() then return false end
        if IsLowHealth() then return false end
        return true
    end

    local function ExecuteMobile()
        local didFire = false
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        if pGui and type(firesignal) == "function" then
            local mobRoot = pGui:FindFirstChild("Survivor-mob")
            local controls = mobRoot and mobRoot:FindFirstChild("Controls")
            if controls then
                local candidatePaths = {"Gui-mob", "action", "Gui-mobile", "Gui_mob", "Parry", "parry"}
                for _, btnName in ipairs(candidatePaths) do
                    local btn = controls:FindFirstChild(btnName)
                    if btn and btn:IsA("GuiButton") then
                        pcall(function()
                            firesignal(btn.MouseButton1Down)
                            task.delay(0.05, function()
                                if btn and btn.Parent then
                                    firesignal(btn.MouseButton1Up)
                                    firesignal(btn.MouseButton1Click)
                                end
                            end)
                        end)
                        didFire = true
                        break
                    end
                end
            end
        end
        if not didFire and parryFireRemote then
            pcall(function() parryFireRemote:FireServer() end)
        end
    end

    local function ExecutePC()
        pcall(function()
            VirtualInputManager:SendMouseMoveEvent(0, 0, game)
            task.wait(0.005)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 2, true, game, 0)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 2, false, game, 0)
        end)
    end

    local function ExecuteSilent()
        if not parryFireRemote then
            pcall(function()
                local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                local items = remotes and remotes:FindFirstChild("Items")
                local dagger = items and items:FindFirstChild("Parrying Dagger")
                local remote = dagger and dagger:FindFirstChild("parry")
                if remote then parryFireRemote = remote end
            end)
        end
        if parryFireRemote then
            pcall(function() parryFireRemote:FireServer() end)
            return true
        end
        return false
    end

    local function Execute()
        if not CanFire() then return end
        State.LastParry = os.clock()
        Cooldown.LastFiredAt = os.clock()
        Cooldown.WaitingForResult = true
        Cooldown.WaitingStart = os.clock()
        Cooldown.JustFired = true
        Cooldown.ManualDetect = false
        if VD.PARRY_SilentParry then ExecuteSilent(); return end
        if isMobile then ExecuteMobile() else ExecutePC() end
    end

    local function DestroyCircle()
        if State.CircleFolder then
            pcall(function()
                if State.CircleFolder and State.CircleFolder.Parent then State.CircleFolder:Destroy() end
            end)
        end
        State.CircleFolder = nil
        State.CircleDashes = {}; State.CircleRotCFs = {}; State.CircleOffsets = {}
        State.CircleRadius = 0; State.CircleBuiltForDagger = false
        State.CircleLastX = math.huge; State.CircleLastY = math.huge; State.CircleLastZ = math.huge
        State.CircleLastAlpha = -1; State.CircleLastR = -1; State.CircleLastG = -1; State.CircleLastB = -1
    end

    local function ForceRedraw()
        -- Invalidate cache to force next UpdateCircle to fully redraw
        State.CircleLastX = math.huge
        State.CircleLastY = math.huge
        State.CircleLastZ = math.huge
        State.CircleLastAlpha = -1
        State.CircleLastR = -1
        State.CircleLastG = -1
        State.CircleLastB = -1
    end

    local function BuildCircle(radius)
        DestroyCircle()
        local folder = Instance.new("Folder")
        folder.Name = "MawwwParryV2Circle"
        local dashCount = math.clamp(math.floor(radius * 6), 24, 120)
        local slotLength = (2 * math.pi * radius) / dashCount
        local dashLength = slotLength * 0.55
        local dashThickness = 0.03
        local dashes = table.create(dashCount)
        local rotCFs = table.create(dashCount)
        local offsets = table.create(dashCount)
        for i = 1, dashCount do
            local part = Instance.new("Part")
            part.Name = "Dash" .. i
            part.Anchored = true; part.CanCollide = false
            part.CanTouch = false; part.CanQuery = false; part.CastShadow = false
            part.Material = Enum.Material.Neon
            part.Color = NEON_PURPLE_V2     -- NEON PURPLE
            part.Transparency = 0           -- fully visible from the start
            part.Size = Vector3.new(dashThickness, dashThickness, dashLength)
            part.TopSurface = Enum.SurfaceType.Smooth
            part.BottomSurface = Enum.SurfaceType.Smooth
            part.Parent = folder
            local angle = ((i - 1) / dashCount) * math.pi * 2
            local cosA = math.cos(angle); local sinA = math.sin(angle)
            local tangent = Vector3.new(-sinA, 0, cosA)
            rotCFs[i] = CFrame.lookAt(Vector3.zero, tangent)
            offsets[i] = Vector3.new(cosA * radius, 0, sinA * radius)
            dashes[i] = part
        end
        folder.Parent = Workspace
        State.CircleFolder = folder; State.CircleDashes = dashes
        State.CircleRotCFs = rotCFs; State.CircleOffsets = offsets
        State.CircleRadius = radius; State.CircleBuiltForDagger = true
        ForceRedraw()   -- ensure first UpdateCircle pass writes color/position
    end

    local function UpdateCircle(myRoot)
        if not State.CircleFolder or not State.CircleFolder.Parent then return end
        local dashes = State.CircleDashes
        local dashCount = #dashes
        if dashCount == 0 then return end
        local center = myRoot.Position - Vector3.new(0, (myRoot.Size.Y * 0.5) + 0.15, 0)
        local busy = IsBusy()
        local onCd = Cooldown.OnCooldown
        local targetColor
        if busy then targetColor = Color3.fromRGB(255, 20, 20)
        elseif onCd then targetColor = Color3.fromRGB(255, 140, 0)
        else targetColor = NEON_PURPLE_V2 end   -- IDLE = NEON PURPLE
        local targetTransparency = 0
        if onCd then
            local period = 0.55
            local phase = (os.clock() % period) / period
            local pulse = (math.cos(phase * math.pi * 2) + 1) * 0.5
            targetTransparency = (1 - pulse) * 0.85
        end
        local dx = math.abs(center.X - State.CircleLastX)
        local dy = math.abs(center.Y - State.CircleLastY)
        local dz = math.abs(center.Z - State.CircleLastZ)
        local dA = math.abs(targetTransparency - State.CircleLastAlpha)
        local r, g, b = targetColor.R * 255, targetColor.G * 255, targetColor.B * 255
        local dR = math.abs(r - State.CircleLastR)
        local dG = math.abs(g - State.CircleLastG)
        local dB = math.abs(b - State.CircleLastB)
        if dx < 0.01 and dy < 0.01 and dz < 0.01 and dA < 0.005
            and dR < 2 and dG < 2 and dB < 2 then return end
        State.CircleLastX = center.X; State.CircleLastY = center.Y; State.CircleLastZ = center.Z
        State.CircleLastAlpha = targetTransparency
        State.CircleLastR = r; State.CircleLastG = g; State.CircleLastB = b
        local rotCFs = State.CircleRotCFs
        local offsets = State.CircleOffsets
        for i = 1, dashCount do
            local dash = dashes[i]
            if dash and dash.Parent then
                local off = offsets[i]
                local worldPos = Vector3.new(center.X + off.X, center.Y, center.Z + off.Z)
                dash.CFrame = rotCFs[i] + worldPos
                dash.Color = targetColor
                dash.Transparency = targetTransparency
                dash.Material = Enum.Material.Neon
                dash.CanCollide = false
            end
        end
    end

    local function GetAnimType(track)
        if not track or not track.Animation then return nil end
        local animId = track.Animation.AnimationId or ""
        local numId = animId:match("%d+") or ""
        local name = string.lower(track.Animation.Name or "")
        local v = KillerAttackAnims[animId]
        if v then return v end
        if numId ~= "" then
            v = KillerAttackAnims[numId]
            if v then return v end
        end
        if string.find(name, "lunge", 1, true) or string.find(name, "charge", 1, true) then return "lungehold" end
        if string.find(name, "attack", 1, true) or string.find(name, "slash", 1, true)
            or string.find(name, "swing", 1, true) or string.find(name, "stab", 1, true)
            or string.find(name, "melee", 1, true) then return "attack" end
        return nil
    end

    local function HookAnimatorOnChar(plr, char)
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 3)
        if not animator then return end
        animator.AnimationPlayed:Connect(function(track)
            if not VD.PARRY_Enabled then return end
            if not IsEquippedDagger() then return end
            local animType = GetAnimType(track)
            if animType then
                State.ActiveAttackers[plr] = {
                    char = char, track = track, type = animType,
                    registeredAt = os.clock()
                }
            end
        end)
    end

    local function HookKillerPlayer(plr)
        if plr == LocalPlayer then return end
        if plr.Character then HookAnimatorOnChar(plr, plr.Character) end
        plr.CharacterAdded:Connect(function(char)
            task.wait(0.5); HookAnimatorOnChar(plr, char)
        end)
    end

    for _, plr in ipairs(MawwwGetPlayers()) do HookKillerPlayer(plr) end
    Players.PlayerAdded:Connect(HookKillerPlayer)

    local lastPoll = 0
    local POLL_INTERVAL = 0.15
    local function PollAttacks()
        if not VD.PARRY_Enabled then return end
        if not IsEquippedDagger() then return end
        local now = os.clock()
        if now - lastPoll < POLL_INTERVAL then return end
        lastPoll = now
        local allPlayers = MawwwGetPlayers()
        for i = 1, #allPlayers do
            local plr = allPlayers[i]
            if plr ~= LocalPlayer then
                local char = plr.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then
                        local tracks = hum:GetPlayingAnimationTracks()
                        for j = 1, #tracks do
                            local track = tracks[j]
                            local animType = GetAnimType(track)
                            if animType then
                                local existing = State.ActiveAttackers[plr]
                                if not existing or existing.track ~= track then
                                    State.ActiveAttackers[plr] = {
                                        char = char, track = track, type = animType, registeredAt = now
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local lastCleanup = 0
    local CLEANUP_INTERVAL = 1.0
    local function CleanupAttackers()
        local now = os.clock()
        if now - lastCleanup < CLEANUP_INTERVAL then return end
        lastCleanup = now
        for plr, data in pairs(State.ActiveAttackers) do
            if not plr or not plr.Parent or not data.track or not data.track.IsPlaying then
                State.ActiveAttackers[plr] = nil
            end
        end
    end

    local function CheckAndParry(killerChar)
        if IsOnCooldown() then return end
        if Cooldown.WaitingForResult then return end
        if Cooldown.IsSilenced then return end
        if not IsEquippedDagger() then return end
        local cc = GetCharCache()
        local myRoot = cc.UpperTorso or cc.Root
        local killerPart = killerChar and (killerChar:FindFirstChild("UpperTorso")
            or killerChar:FindFirstChild("Torso")
            or killerChar:FindFirstChild("HumanoidRootPart"))
        if not myRoot or not killerPart then return end
        local dist = (myRoot.Position - killerPart.Position).Magnitude
        if VD.PARRY_Aggressive then
            local ping = math.clamp(LocalPlayer:GetNetworkPing(), 0, 0.3)
            local killerRoot = killerChar:FindFirstChild("HumanoidRootPart") or killerPart
            local killerVel = killerRoot.AssemblyLinearVelocity
            local flatVel = Vector3.new(killerVel.X, 0, killerVel.Z)
            local predictedPos = killerPart.Position + (flatVel * ping)
            local predictedDist = (myRoot.Position - predictedPos).Magnitude
            if predictedDist <= ((VD.PARRY_Distance or 10) + 2.5) then
                local dirToMe = (myRoot.Position - killerPart.Position).Unit
                if flatVel.Magnitude > 6 and flatVel.Unit:Dot(dirToMe) > 0.4 then
                    Execute(); return
                end
            end
        end
        if dist <= (VD.PARRY_Distance or 10) then Execute() end
    end

    local function UpdateLogic()
        local myChar = LocalPlayer.Character
        if not myChar then return end
        if not VD.PARRY_Enabled then return end
        local hasDagger = IsEquippedDagger()
        if not hasDagger then
            if next(State.ActiveAttackers) then State.ActiveAttackers = {} end
            return
        end
        if Cooldown.WaitingForResult then
            if os.clock() - Cooldown.WaitingStart > Cooldown.WaitTimeout then
                if Cooldown.ManualDetect then
                    Cooldown.WaitingForResult = false
                    Cooldown.JustFired = false
                    Cooldown.ManualDetect = false
                else
                    StartCooldown(Cooldown.FallbackCooldown)
                end
            end
        end
        if IsOnCooldown() or Cooldown.WaitingForResult then return end
        PollAttacks(); CleanupAttackers()
        for plr, data in pairs(State.ActiveAttackers) do
            if plr and plr.Parent and data.track and data.track.IsPlaying then
                local shouldCheck = false
                if data.type == "attack" then
                    if data.track.TimePosition < 0.35 then shouldCheck = true end
                elseif data.type == "lungehold" then
                    shouldCheck = true
                end
                if shouldCheck then
                    CheckAndParry(data.char)
                    if Cooldown.WaitingForResult then break end
                end
            else
                State.ActiveAttackers[plr] = nil
            end
        end
    end

    -- === FIX: circle now shows with ShowCircle ONLY (no PARRY_Enabled, no dagger required) ===
    local function UpdateCircleLogic()
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if VD.PARRY_ShowCircle and myRoot then
            if not State.CircleFolder
                or State.CircleRadius ~= (VD.PARRY_Distance or 10)
                or not State.CircleFolder.Parent then
                BuildCircle(VD.PARRY_Distance or 10)
            end
            UpdateCircle(myRoot)
        else
            if State.CircleFolder then DestroyCircle() end
        end
    end

    local LOGIC_INTERVAL = 0.05
    local CIRCLE_INTERVAL = 0.067
    local lastLogic = 0
    local lastCircle = 0

    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - lastCircle >= CIRCLE_INTERVAL then
            lastCircle = now
            pcall(UpdateCircleLogic)
        end
        if now - lastLogic >= LOGIC_INTERVAL then
            lastLogic = now
            pcall(UpdateLogic)
        end
    end)

    return {
        DestroyCircle = DestroyCircle,
        ForceRedraw = ForceRedraw,
        State = State,
        Cooldown = Cooldown,
    }
end)()

RegToggle(Tabs.SurvivalParryV2, "Auto Parry V2", "Enable source V2 auto parry", false, "PARRY_Enabled", function(v)
    if not v and ParryV2 and ParryV2.DestroyCircle then
        pcall(ParryV2.DestroyCircle)
    end
    notify("Auto Parry V2", v and "Enabled — mawww mode" or "Disabled", 2)
end)
RegToggle(Tabs.SurvivalParryV2, "Aggressive Prediction", "Predictive parry", false, "PARRY_Aggressive")
RegSlider(Tabs.SurvivalParryV2, "Parry Distance", "Trigger distance", 10, 4, 20, 1, "PARRY_Distance")
RegToggle(Tabs.SurvivalParryV2, "Silent Parry", "Silent parry", false, "PARRY_SilentParry")
RegToggle(Tabs.SurvivalParryV2, "Show Parry Range", "Show range circle", VD.PARRY_ShowCircle == true, "PARRY_ShowCircle", function(v)
    VD.ShowParryRangeV2 = v and true or false
    if ParryV2 and ParryV2.DestroyCircle then
        pcall(ParryV2.DestroyCircle)
    end
    if v and ParryV2 and ParryV2.ForceRedraw then
        pcall(ParryV2.ForceRedraw)
    end
    notify("Parry Range V2", v and "Lingkaran neon UNGU ditampilkan!" or "Lingkaran disembunyikan", 2)
end)


--========================================================--
-- AUTO PARRY V3 / V4
--========================================================--
AutoParryV3Module = {}
do
    local okModule, moduleResult = pcall(function()
        return (function()
    local Players           = game:GetService("Players")
    local RunService        = game:GetService("RunService")
    local UserInputService  = game:GetService("UserInputService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Workspace         = game:GetService("Workspace")
    local CollectionService = game:GetService("CollectionService")
    local TweenService      = game:GetService("TweenService")
    local VirtualInputManager = nil
    pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)
    local LocalPlayer = Players.LocalPlayer
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local W = getgenv and getgenv() or _G
    local ShowNotify = notify or function() end
    local VD_Notify = ShowNotify
    local ForceNotify = ShowNotify
    -- Default V1 vars (SURV_* namespace)
    VD.SURV_AutoParryV3       = VD.SURV_AutoParryV3 or false
    VD.SURV_ParryAggressiveV3 = VD.SURV_ParryAggressiveV3 or false
    VD.SURV_ParryDistanceV3   = VD.SURV_ParryDistanceV3 or 10
    VD.SURV_ShowParryCircleV3 = VD.SURV_ShowParryCircleV3 or false
    VD.SURV_SilentParryV3     = VD.SURV_SilentParryV3 or false

        -- AUTO PARRY
        --====================================================--
        local ParryState = {
            LastParry = 0, ActiveAttackers = {},
            CircleFolder = nil, CircleDashes = {}, CircleRotCFs = {}, CircleOffsets = {},
            CircleRadius = 0, CircleBuiltForDagger = false,
            CircleLastX = math.huge, CircleLastY = math.huge, CircleLastZ = math.huge,
            CircleSpawnTime = 0, CircleSpawnDuration = 0.55,
        }
        local ParryCooldown = {
            OnCooldown = false, CooldownEnd = 0,
            WaitingForResult = false, WaitingStart = 0, WaitTimeout = 2.0,
            FallbackCooldown = 60, MaxCooldown = 90, LastFiredAt = 0,
            IsSilenced = false, JustFired = false, ManualDetect = false, ManualIgnoreWindow = 0.35
        }
        local parryResultRemote, parryFireRemote
        pcall(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            local items = remotes and remotes:FindFirstChild("Items")
            local dagger = items and items:FindFirstChild("Parrying Dagger")
            if dagger then
                parryResultRemote = dagger:FindFirstChild("parryResult")
                parryFireRemote = dagger:FindFirstChild("parry")
            end
        end)
        local KillerAttackAnims = {
            ["78432063483146"]="attack",["121216847022485"]="attack",["74968262036854"]="attack",
            ["132817836308238"]="attack",["82666958311998"]="attack",["111920872708571"]="attack",
            ["106871536134254"]="attack",["109402730355822"]="attack",["130593238885843"]="attack",
            ["138720291317243"]="attack",["139369275981139"]="attack",["133963973694098"]="attack",
            ["78935059863801"]="attack",
            ["118907603246885"]="lungehold",["135002183282873"]="lungehold",["113255068724446"]="lungehold",
            ["129784271201071"]="lungehold",["105374834496520"]="lungehold",["117070354890871"]="lungehold",
            ["115244153053858"]="lungehold",["110355011987939"]="lungehold",["117042998468241"]="lungehold",
            ["122812055447896"]="lungehold"
        }
        local function ParryStartCooldown(d)
            d = math.clamp(tonumber(d) or 0, 0, ParryCooldown.MaxCooldown)
            if d <= 0 then d = ParryCooldown.FallbackCooldown end
            ParryCooldown.OnCooldown = true
            ParryCooldown.CooldownEnd = os.clock() + d
            ParryCooldown.WaitingForResult = false
            ParryCooldown.JustFired = false
            ParryCooldown.ManualDetect = false
        end
        local function ParryClearCooldown()
            ParryCooldown.OnCooldown = false
            ParryCooldown.CooldownEnd = 0
            ParryCooldown.WaitingForResult = false
            ParryCooldown.JustFired = false
            ParryCooldown.ManualDetect = false
        end
        local function ParryIsOnCooldown()
            if not ParryCooldown.OnCooldown then return false end
            if os.clock() >= ParryCooldown.CooldownEnd then ParryClearCooldown(); return false end
            return true
        end
        if parryResultRemote then
            parryResultRemote.OnClientEvent:Connect(function(success, cd)
                if not ParryCooldown.WaitingForResult and not ParryCooldown.JustFired then return end
                local c = tonumber(cd) or 0
                if success and c > 0 then ParryStartCooldown(math.min(c, ParryCooldown.MaxCooldown))
                else ParryStartCooldown(ParryCooldown.FallbackCooldown) end
            end)
        end
        local function ParryHookSilenced(char)
            if not char then return end
            ParryCooldown.IsSilenced = CollectionService:HasTag(char, "Silenced")
        end
        CollectionService:GetInstanceAddedSignal("Silenced"):Connect(function(i)
            if i == LocalPlayer.Character then ParryCooldown.IsSilenced = true end
        end)
        CollectionService:GetInstanceRemovedSignal("Silenced"):Connect(function(i)
            if i == LocalPlayer.Character then ParryCooldown.IsSilenced = false end
        end)
        LocalPlayer.CharacterAdded:Connect(function(c) task.wait(0.5); ParryHookSilenced(c) end)
        if LocalPlayer.Character then ParryHookSilenced(LocalPlayer.Character) end

        local ParryCharCache = { Char=nil, Root=nil, Hum=nil, UpperTorso=nil, CheckInt=nil }
        local function ParryGetCharCache()
            local char = LocalPlayer.Character
            if char ~= ParryCharCache.Char then
                ParryCharCache.Char = char
                ParryCharCache.Root = nil; ParryCharCache.Hum = nil
                ParryCharCache.UpperTorso = nil; ParryCharCache.CheckInt = nil
            end
            if not char then return ParryCharCache end
            if not ParryCharCache.Root then ParryCharCache.Root = char:FindFirstChild("HumanoidRootPart") end
            if not ParryCharCache.Hum then ParryCharCache.Hum = char:FindFirstChildOfClass("Humanoid") end
            if not ParryCharCache.UpperTorso then
                ParryCharCache.UpperTorso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
            end
            if not ParryCharCache.CheckInt then ParryCharCache.CheckInt = char:FindFirstChild("CheckInterractable") end
            return ParryCharCache
        end
        local DaggerCache = { Value = false, LastCheck = 0, Interval = 0.15 }
        local function ParryIsDaggerModel(inst)
            if not inst then return false end
            return inst:IsA("Model") or inst:IsA("Tool") or inst:IsA("Accessory")
        end
        local function ParryIsEquippedDagger()
            local now = os.clock()
            if now - DaggerCache.LastCheck < DaggerCache.Interval then return DaggerCache.Value end
            DaggerCache.LastCheck = now
            local hasDagger = false
            local char = LocalPlayer.Character
            if char then
                local d = char:FindFirstChild("Parrying Dagger")
                if ParryIsDaggerModel(d) then hasDagger = true end
            end
            if not hasDagger then
                local wsChar = Workspace:FindFirstChild(LocalPlayer.Name)
                if wsChar then
                    local d = wsChar:FindFirstChild("Parrying Dagger")
                    if ParryIsDaggerModel(d) then hasDagger = true end
                end
            end
            DaggerCache.Value = hasDagger
            return hasDagger
        end
        LocalPlayer.CharacterAdded:Connect(function() DaggerCache.Value = false; DaggerCache.LastCheck = 0 end)

        local ParryCheckAttrs = {"isVaulting","isSliding","isDroppingPallet","isRepairing","isHealing","isUnhooking","isExiting"}
        local function ParryIsBusy()
            local cc = ParryGetCharCache()
            if not cc.Char then return true end
            if LocalPlayer:GetAttribute("IsDead") then return true end
            if cc.Char:GetAttribute("IsCarried") then return true end
            if cc.Char:GetAttribute("IsHooked") then return true end
            if cc.Root and CollectionService:HasTag(cc.Root, "doing action") then return true end
            if cc.CheckInt then
                for i = 1, #ParryCheckAttrs do
                    if cc.CheckInt:GetAttribute(ParryCheckAttrs[i]) then return true end
                end
            end
            return false
        end
        local function ParryIsLowHealth()
            local hum = ParryGetCharCache().Hum
            if not hum then return false end
            return hum.Health < hum.MaxHealth * 0.5
        end
        local function ParryCanFire()
            if not ParryIsEquippedDagger() then return false end
            if ParryCooldown.IsSilenced then return false end
            if ParryIsOnCooldown() then return false end
            if ParryCooldown.WaitingForResult then return false end
            if ParryIsBusy() then return false end
            if ParryIsLowHealth() then return false end
            return true
        end
        local function ParryExecuteMobile()
            local didFire = false
            local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            if pGui and type(firesignal) == "function" then
                local mobRoot = pGui:FindFirstChild("Survivor-mob")
                local controls = mobRoot and mobRoot:FindFirstChild("Controls")
                if controls then
                    for _, n in ipairs({"Gui-mob","action","Gui-mobile","Gui_mob","Parry","parry"}) do
                        local btn = controls:FindFirstChild(n)
                        if btn and btn:IsA("GuiButton") then
                            pcall(function()
                                firesignal(btn.MouseButton1Down)
                                task.delay(0.05, function()
                                    if btn and btn.Parent then
                                        firesignal(btn.MouseButton1Up)
                                        firesignal(btn.MouseButton1Click)
                                    end
                                end)
                            end)
                            didFire = true; break
                        end
                    end
                end
            end
            if not didFire then
                local remote = ReplicatedStorage:FindFirstChild("Remotes")
                local items = remote and remote:FindFirstChild("Items")
                local dagger = items and items:FindFirstChild("Parrying Dagger")
                local parry = dagger and dagger:FindFirstChild("parry")
                if parry then pcall(function() parry:FireServer() end) end
            end
        end
        local function ParryExecutePC()
            if not VirtualInputManager then return end
            pcall(function()
                VirtualInputManager:SendMouseMoveEvent(0, 0, game)
                task.wait(0.005)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 2, true, game, 0)
                task.wait(0.05)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 2, false, game, 0)
            end)
        end
        local function ParryExecuteSilent()
            if parryFireRemote then return pcall(function() parryFireRemote:FireServer() end) end
            return false
        end
        local function ParryExecute()
            if not ParryCanFire() then return end
            ParryState.LastParry = os.clock()
            ParryCooldown.LastFiredAt = os.clock()
            ParryCooldown.WaitingForResult = true
            ParryCooldown.WaitingStart = os.clock()
            ParryCooldown.JustFired = true
            ParryCooldown.ManualDetect = false
            if VD.SURV_SilentParryV3 then ParryExecuteSilent(); return end
            if isMobile then ParryExecuteMobile() else ParryExecutePC() end
        end
        local function ParryMarkManual()
            if not ParryIsEquippedDagger() then return end
            if ParryCooldown.IsSilenced then return end
            if os.clock() - ParryCooldown.LastFiredAt < ParryCooldown.ManualIgnoreWindow then return end
            if ParryCooldown.OnCooldown or ParryCooldown.WaitingForResult then return end
            ParryCooldown.WaitingForResult = true
            ParryCooldown.WaitingStart = os.clock()
            ParryCooldown.JustFired = true
            ParryCooldown.ManualDetect = true
            ParryCooldown.LastFiredAt = os.clock()
        end
        UserInputService.InputBegan:Connect(function(input, gp)
            if input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
            if gp then return end
            ParryMarkManual()
        end)
        local parryHookedButtons = setmetatable({}, {__mode = "k"})
        local function ParryTryHookMobileButton(inst)
            if not inst or not inst:IsA("GuiButton") then return end
            if parryHookedButtons[inst] then return end
            local nm = inst.Name
            if nm ~= "Gui-mob" and nm ~= "action" and nm ~= "Gui-mobile"
                and nm ~= "Gui_mob" and nm ~= "Parry" and nm ~= "parry" then return end
            parryHookedButtons[inst] = true
            inst.MouseButton1Down:Connect(ParryMarkManual)
        end
        local function ParryScanForMobileButtons(root)
            if not root then return end
            for _, d in ipairs(root:GetDescendants()) do ParryTryHookMobileButton(d) end
        end
        local function ParryAttachPlayerGui(pGui)
            if not pGui then return end
            ParryScanForMobileButtons(pGui)
            pGui.DescendantAdded:Connect(ParryTryHookMobileButton)
        end
        local existingPGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if existingPGui then ParryAttachPlayerGui(existingPGui) end
        LocalPlayer.ChildAdded:Connect(function(c)
            if c:IsA("PlayerGui") then ParryAttachPlayerGui(c) end
        end)

        local function ParryGetHitboxPart(char)
            if not char then return nil end
            return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
        end
        --========================================================--
        -- [PATCH V1] SMART TRIGGER HELPERS — Anti false-trigger
        --========================================================--
        local function ParryV1_IsDowned(char)
            if not char then return true end
            if char:GetAttribute("Knocked") == true then return true end
            if char:GetAttribute("IsHooked") == true then return true end
            if char:GetAttribute("HookProgressDepleting") == true then return true end
            if char:GetAttribute("IsCarried") == true then return true end

            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return true end
            return false
        end

        local function ParryV1_WallBlocked(originPos, targetPos, killerChar)
            if VD.PARRY_V3_WallCheck == false then return false end
            if VD.PARRY_V3_Raycast == false then return false end

            local range = tonumber(VD.PARRY_V3_RaycastRange) or 20
            local offset = targetPos - originPos
            local dist = offset.Magnitude
            if dist > range or dist < 0.1 then return false end

            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.IgnoreWater = true

            local exclude = {}
            if LocalPlayer.Character then table.insert(exclude, LocalPlayer.Character) end
            if killerChar then table.insert(exclude, killerChar) end
            params.FilterDescendantsInstances = exclude

            local hit = Workspace:Raycast(originPos, offset.Unit * dist, params)
            return hit ~= nil
        end

        local function ParryV1_FacingUs(killerChar, myPos)
            if VD.PARRY_V3_IgnoreFacing == true then return true end

            local root = killerChar and killerChar:FindFirstChild("HumanoidRootPart")
            if not root then return true end

            local look = root.CFrame.LookVector
            local lookFlat = Vector3.new(look.X, 0, look.Z)
            local toMe = myPos - root.Position
            local toMeFlat = Vector3.new(toMe.X, 0, toMe.Z)

            if lookFlat.Magnitude < 0.01 or toMeFlat.Magnitude < 0.01 then
                return true
            end

            local minFacing = tonumber(VD.PARRY_V3_MinFacing) or 0.5
            return lookFlat.Unit:Dot(toMeFlat.Unit) >= minFacing
        end

        local function ParryV1_PredictPosition(killerPart, killerRoot)
            local ping = 0
            pcall(function()
                ping = math.clamp(LocalPlayer:GetNetworkPing(), 0, 0.3)
            end)

            local velocity = Vector3.zero
            pcall(function()
                velocity = (killerRoot and killerRoot.AssemblyLinearVelocity) or Vector3.zero
            end)

            local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
            local predictTime = ping + 0.08
            return killerPart.Position + flatVelocity * predictTime, flatVelocity, ping
        end

        --========================================================--
        -- [PATCH V1] PARryCheck — SMART TRIGGER + ANTI MISS
        --========================================================--
        local ParryV1_FakeLog = setmetatable({}, {__mode = "k"})

        local function ParryCheckAndParry(killerChar)
            -- Gate: cooldown, dagger, silenced
            if ParryIsOnCooldown() or ParryCooldown.WaitingForResult
                or ParryCooldown.IsSilenced or not ParryIsEquippedDagger() then return end

            local cc = ParryGetCharCache()
            local myRoot = cc.UpperTorso or cc.Root
            local killerPart = ParryGetHitboxPart(killerChar)
            if not myRoot or not killerPart then return end

            -- [ANTI FALSE-TRIGGER 1] Ignore downed/hooked/carried killer
            if VD.PARRY_V3_IgnoreDown ~= false then
                if ParryV1_IsDowned(killerChar) then return end
            end

            -- [ANTI FALSE-TRIGGER 2] Wall check (blocked by obstacle)
            if VD.PARRY_V3_WallCheck ~= false then
                if ParryV1_WallBlocked(killerPart.Position, myRoot.Position, killerChar) then return end
            end

            -- [ANTI FALSE-TRIGGER 3] Facing check (killer harus hadap ke kita)
            if not ParryV1_FacingUs(killerChar, myRoot.Position) then return end

            -- [ANTI MISS] Predict posisi + velocity + ping
            local killerRoot = killerChar:FindFirstChild("HumanoidRootPart") or killerPart
            local predictedPos, flatVel, ping = ParryV1_PredictPosition(killerPart, killerRoot)

            local maxDist = tonumber(VD.SURV_ParryDistanceV3) or 10
            local dist = (myRoot.Position - killerPart.Position).Magnitude
            local predDist = (myRoot.Position - predictedPos).Magnitude

            -- [ANTI FALSE-TRIGGER 4] Minimum velocity unless already close.
            local minVel = tonumber(VD.PARRY_V3_MinVelocity) or 2
            if dist > (maxDist * 0.6) and flatVel.Magnitude < minVel then
                return
            end

            -- [ANTI FALSE-TRIGGER 5] Prevent immediate repeat on same killer.
            local now = os.clock()
            local lastParryForChar = ParryV1_FakeLog[killerChar]
            if lastParryForChar and (now - lastParryForChar) < 0.15 then
                return
            end

            -- [ANTI FALSE-TRIGGER 6] Skip suspicious stationary close windows.
            if VD.PARRY_V3_AntiFake ~= false then
                local fakeDist = tonumber(VD.PARRY_V3_FakeDistance) or 2.5
                if dist <= fakeDist and flatVel.Magnitude < (minVel * 0.8) then
                    return
                end
            end

            -- ============== DECISION ==============
            local shouldParry = false

            if VD.SURV_ParryAggressiveV3 then
                -- MODE AGRESIF: pakai prediksi penuh + arah lunge
                if predDist <= (maxDist + 2.5) and flatVel.Magnitude > 6 then
                    local dir = myRoot.Position - killerPart.Position
                    if dir.Magnitude > 0.1 and flatVel.Unit:Dot(dir.Unit) > 0.4 then
                        shouldParry = true
                    end
                end
            end

            -- Normal fallback: dalam range prediksi
            if not shouldParry and predDist <= maxDist then
                if VD.PARRY_V3_Safety ~= false then
                    -- [SAFETY] Butuh minimal velocity ATAU benar-benar dekat
                    local veryClose = dist <= (maxDist * 0.6)
                    if veryClose or flatVel.Magnitude >= minVel then
                        shouldParry = true
                    end
                else
                    shouldParry = true
                end
            end

            -- [ANTI MISS] Extended window for fast lunges.
            if not shouldParry and flatVel.Magnitude > 12 then
                local extendedRange = maxDist + (flatVel.Magnitude * ping)
                if predDist <= extendedRange then
                    shouldParry = true
                end
            end

            if shouldParry then
                ParryV1_FakeLog[killerChar] = now
                ParryExecute()
            end
        end
        local function ParryDestroyCircle()
            if ParryState.CircleFolder then
                pcall(function() if ParryState.CircleFolder.Parent then ParryState.CircleFolder:Destroy() end end)
            end
            ParryState.CircleFolder = nil
            ParryState.CircleDashes = {}
            ParryState.CircleRotCFs = {}
            ParryState.CircleOffsets = {}
            ParryState.CircleRadius = 0
            ParryState.CircleBuiltForDagger = false
            ParryState.CircleLastX = math.huge
            ParryState.CircleLastY = math.huge
            ParryState.CircleLastZ = math.huge
            ParryState.CircleSpawnTime = 0
        end
        getgenv().Mawww_DestroyParryV3Circle = ParryDestroyCircle
        local function ParryBuildCircle(radius)
            ParryDestroyCircle()
            local folder = Instance.new("Folder")
            folder.Name = "MawwwParryV3Circle"
            local dashCount = math.clamp(math.floor(radius * 6), 24, 120)
            local slotLength = (2 * math.pi * radius) / dashCount
            local dashLength = slotLength * 0.55
            local dashThickness = 0.03
            local dashes, rotCFs, offsets = table.create(dashCount), table.create(dashCount), table.create(dashCount)
            for i = 1, dashCount do
                local part = Instance.new("Part")
                part.Name = "Dash" .. i
                part.Anchored = true; part.CanCollide = false
                part.CanTouch = false; part.CanQuery = false; part.CastShadow = false
                part.Material = Enum.Material.Neon
                part.Color = Color3.fromRGB(255, 255, 255)
                part.Transparency = 1
                part.Size = Vector3.new(dashThickness, dashThickness, dashLength)
                part.Parent = folder
                local angle = ((i - 1) / dashCount) * math.pi * 2
                local cosA, sinA = math.cos(angle), math.sin(angle)
                rotCFs[i] = CFrame.lookAt(Vector3.zero, Vector3.new(-sinA, 0, cosA))
                offsets[i] = Vector3.new(cosA * radius, 0, sinA * radius)
                dashes[i] = part
            end
            folder.Parent = Workspace
            ParryState.CircleFolder = folder
            ParryState.CircleDashes = dashes
            ParryState.CircleRotCFs = rotCFs
            ParryState.CircleOffsets = offsets
            ParryState.CircleRadius = radius
            ParryState.CircleBuiltForDagger = true
            ParryState.CircleSpawnTime = tick()
        end
        local function ParryUpdateCircle(myRoot)
            if not ParryState.CircleFolder or not ParryState.CircleFolder.Parent then return end
            local dashes = ParryState.CircleDashes
            local dashCount = #dashes
            if dashCount == 0 then return end
            local center = myRoot.Position - Vector3.new(0, (myRoot.Size.Y * 0.5) + 1.0, 0)
            local elapsed = tick() - (ParryState.CircleSpawnTime or 0)
            local spawnT = math.clamp(elapsed / (ParryState.CircleSpawnDuration or 0.55), 0, 1)
            local eased = 1 - (1 - spawnT)^3
            local scaleMult = eased
            if spawnT < 0.7 and spawnT > 0 then
                local bt = spawnT / 0.7
                scaleMult = eased + math.sin(bt * math.pi) * 0.1
            end
            local spinRot = (1 - eased) * math.pi * 2
            local spawnAlpha = 1 - eased
            local busy = ParryIsBusy()
            local onCD = ParryCooldown.OnCooldown
            local tc
            if busy then tc = Color3.fromRGB(255, 20, 20)
            elseif onCD then tc = Color3.fromRGB(255, 140, 0)
            else tc = Color3.fromRGB(255, 255, 255) end
            local targetT = 0
            if onCD then
                local period = 0.55
                local phase = (os.clock() % period) / period
                local pulse = (math.cos(phase * math.pi * 2) + 1) * 0.5
                targetT = (1 - pulse) * 0.85
            end
            local finalT = math.max(targetT, spawnAlpha)
            local dx = math.abs(center.X - ParryState.CircleLastX)
            local dy = math.abs(center.Y - ParryState.CircleLastY)
            local dz = math.abs(center.Z - ParryState.CircleLastZ)
            if dx < 0.01 and dy < 0.01 and dz < 0.01 and spawnT >= 1 then return end
            ParryState.CircleLastX = center.X
            ParryState.CircleLastY = center.Y
            ParryState.CircleLastZ = center.Z
            local rotCFs = ParryState.CircleRotCFs
            local offsets = ParryState.CircleOffsets
            local rotCF = CFrame.Angles(0, spinRot, 0)
            for i = 1, dashCount do
                local dash = dashes[i]
                if dash and dash.Parent then
                    local scaledOff = offsets[i] * scaleMult
                    local rotatedOff = rotCF:VectorToWorldSpace(scaledOff)
                    local worldPos = Vector3.new(center.X + rotatedOff.X, center.Y, center.Z + rotatedOff.Z)
                    dash.CFrame = (rotCF * rotCFs[i]) + worldPos
                    dash.Color = tc
                    dash.Transparency = finalT
                end
            end
        end
        local function ParryGetAnimType(track)
            if not track or not track.Animation then return nil end
            local animId = track.Animation.AnimationId or ""
            local numId = animId:match("%d+") or ""
            local name = string.lower(track.Animation.Name or "")
            local v = KillerAttackAnims[animId]
            if v then return v end
            if numId ~= "" then v = KillerAttackAnims[numId]; if v then return v end end
            if string.find(name, "lunge", 1, true) or string.find(name, "charge", 1, true) then return "lungehold" end
            if string.find(name, "attack", 1, true) or string.find(name, "slash", 1, true)
                or string.find(name, "swing", 1, true) or string.find(name, "stab", 1, true)
                or string.find(name, "melee", 1, true) then return "attack" end
            return nil
        end
        local function ParryHookAnimatorOnChar(plr, char)
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            local anim = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 3)
            if not anim then return end
            anim.AnimationPlayed:Connect(function(track)
                if not VD.SURV_AutoParryV3 then return end
                if not ParryIsEquippedDagger() then return end
                local at = ParryGetAnimType(track)
                if at then
                    ParryState.ActiveAttackers[plr] = { char = char, track = track, type = at, registeredAt = os.clock() }
                end
            end)
        end
        local function ParryHookKillerPlayer(plr)
            if plr == LocalPlayer then return end
            if plr.Character then ParryHookAnimatorOnChar(plr, plr.Character) end
            plr.CharacterAdded:Connect(function(char) task.wait(0.5); ParryHookAnimatorOnChar(plr, char) end)
        end
        for _, p in ipairs(MawwwGetPlayers()) do ParryHookKillerPlayer(p) end
        Players.PlayerAdded:Connect(ParryHookKillerPlayer)
        local parryLastPoll = 0
        local function ParryPollAttacks()
            if not VD.SURV_AutoParryV3 or not ParryIsEquippedDagger() then return end
            local now = os.clock()
            if now - parryLastPoll < 0.15 then return end
            parryLastPoll = now
            for _, plr in ipairs(MawwwGetPlayers()) do
                if plr ~= LocalPlayer then
                    local char = plr.Character
                    if char then
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if hum then
                            for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                                local at = ParryGetAnimType(track)
                                if at then
                                    local ex = ParryState.ActiveAttackers[plr]
                                    if not ex or ex.track ~= track then
                                        ParryState.ActiveAttackers[plr] = { char = char, track = track, type = at, registeredAt = now }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        local parryLastCleanup = 0
        local function ParryCleanupAttackers()
            local now = os.clock()
            if now - parryLastCleanup < 1.0 then return end
            parryLastCleanup = now
            for plr, data in pairs(ParryState.ActiveAttackers) do
                if not plr or not plr.Parent or not data.track or not data.track.IsPlaying then
                    ParryState.ActiveAttackers[plr] = nil
                end
            end
        end
        local function ParryUpdateLogic()
            if not VD.SURV_AutoParryV3 then return end
            if not ParryIsEquippedDagger() then ParryState.ActiveAttackers = {}; return end
            if ParryCooldown.WaitingForResult then
                if os.clock() - ParryCooldown.WaitingStart > ParryCooldown.WaitTimeout then
                    if ParryCooldown.ManualDetect then
                        ParryCooldown.WaitingForResult = false
                        ParryCooldown.JustFired = false
                        ParryCooldown.ManualDetect = false
                    else
                        ParryStartCooldown(ParryCooldown.FallbackCooldown)
                    end
                end
            end
            if ParryIsOnCooldown() or ParryCooldown.WaitingForResult then return end
            ParryPollAttacks()
            ParryCleanupAttackers()
            for plr, data in pairs(ParryState.ActiveAttackers) do
                if plr and plr.Parent and data.track and data.track.IsPlaying then
                    local shouldCheck = false
                    if data.type == "attack" then
                        if data.track.TimePosition < 0.35 then shouldCheck = true end
                    elseif data.type == "lungehold" then
                        shouldCheck = true
                    end
                    if shouldCheck then
                        ParryCheckAndParry(data.char)
                        if ParryCooldown.WaitingForResult then break end
                    end
                else
                    ParryState.ActiveAttackers[plr] = nil
                end
            end
        end
        local function ParryUpdateCircleLogic()
            local char = LocalPlayer.Character
            local myRoot = char and char:FindFirstChild("HumanoidRootPart")
            -- Range display is a UI/visual feature and must not depend on
            -- Auto Parry V3 being enabled or the dagger being equipped.
            if VD.SURV_ShowParryCircleV3 and myRoot then
                local radius = math.clamp(tonumber(VD.SURV_ParryDistanceV3) or 10, 1, 100)
                if not ParryState.CircleFolder
                    or ParryState.CircleRadius ~= radius
                    or not ParryState.CircleFolder.Parent then
                    ParryBuildCircle(radius)
                end
                ParryUpdateCircle(myRoot)
            else
                if ParryState.CircleFolder then ParryDestroyCircle() end
            end
        end

    -- Main update loop (from text5 UPDATE LOOPS)
        local parryLastLogic, parryLastCircle = 0, 0
        RunService.Heartbeat:Connect(function()
            local now = os.clock()
            if now - parryLastCircle >= 0.033 then parryLastCircle = now; pcall(ParryUpdateCircleLogic) end
            if now - parryLastLogic >= 0.05 then parryLastLogic = now; pcall(ParryUpdateLogic) end
        end)

    return {
        DestroyCircle = ParryDestroyCircle,
        ForceRedraw = function()
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if VD.SURV_ShowParryCircleV3 and root then
                local radius = math.clamp(tonumber(VD.SURV_ParryDistanceV3) or 10, 1, 100)
                ParryBuildCircle(radius)
                ParryUpdateCircle(root)
            else
                ParryDestroyCircle()
            end
        end,
        State = ParryState,
        Cooldown = ParryCooldown,
    }
        end)()
    end)
    if okModule and type(moduleResult) == "table" then
        AutoParryV3Module = moduleResult
    else
        warn("[MawwwHub] Auto Parry V3 init failed:", moduleResult)
    end
end

ParryV4 = {}
do
    local okModule, moduleResult = pcall(function()
        return (function()
    local LocalPlayer = Player
    local NEON_PURPLE_V4 = Color3.fromRGB(180, 60, 255)

    local State = {
        LastParry = 0,
        ActiveAttackers = {},
        CircleFolder = nil,
        CircleDashes = {},
        CircleRotCFs = {},
        CircleOffsets = {},
        CircleRadius = 0,
        CircleBuiltForDagger = false,
        CircleLastX = math.huge,
        CircleLastY = math.huge,
        CircleLastZ = math.huge,
        CircleLastAlpha = -1,
        CircleLastR = -1,
        CircleLastG = -1,
        CircleLastB = -1,
    }

    local Cooldown = {
        OnCooldown = false,
        CooldownEnd = 0,
        CooldownDuration = 0,
        WaitingForResult = false,
        WaitingStart = 0,
        WaitTimeout = 2.0,
        FallbackCooldown = 60,
        MaxCooldown = 90,
        LastFiredAt = 0,
        IsSilenced = false,
        JustFired = false,
        ManualDetect = false,
        ManualIgnoreWindow = 0.35,
    }

    local parryResultRemote, parryFireRemote
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            local items = remotes:FindFirstChild("Items")
            if items then
                local dagger = items:FindFirstChild("Parrying Dagger")
                if dagger then
                    parryResultRemote = dagger:FindFirstChild("parryResult")
                    parryFireRemote = dagger:FindFirstChild("parry")
                end
            end
        end
    end)

    local KillerAttackAnims = {
        ["78432063483146"] = "attack", ["121216847022485"] = "attack",
        ["74968262036854"] = "attack", ["132817836308238"] = "attack",
        ["82666958311998"] = "attack", ["111920872708571"] = "attack",
        ["106871536134254"] = "attack", ["109402730355822"] = "attack",
        ["130593238885843"] = "attack", ["138720291317243"] = "attack",
        ["139369275981139"] = "attack", ["133963973694098"] = "attack",
        ["78935059863801"] = "attack",
        ["118907603246885"] = "lungehold", ["135002183282873"] = "lungehold",
        ["113255068724446"] = "lungehold", ["129784271201071"] = "lungehold",
        ["105374834496520"] = "lungehold", ["117070354890871"] = "lungehold",
        ["115244153053858"] = "lungehold", ["110355011987939"] = "lungehold",
        ["117042998468241"] = "lungehold", ["122812055447896"] = "lungehold",
    }

    local function StartCooldown(duration)
        duration = math.clamp(tonumber(duration) or 0, 0, Cooldown.MaxCooldown)
        if duration <= 0 then duration = Cooldown.FallbackCooldown end
        Cooldown.OnCooldown = true
        Cooldown.CooldownDuration = duration
        Cooldown.CooldownEnd = os.clock() + duration
        Cooldown.WaitingForResult = false
        Cooldown.JustFired = false
        Cooldown.ManualDetect = false
    end

    local function ClearCooldown()
        Cooldown.OnCooldown = false
        Cooldown.CooldownEnd = 0
        Cooldown.CooldownDuration = 0
        Cooldown.WaitingForResult = false
        Cooldown.JustFired = false
        Cooldown.ManualDetect = false
    end

    local function IsOnCooldown()
        if not Cooldown.OnCooldown then return false end
        if os.clock() >= Cooldown.CooldownEnd then ClearCooldown(); return false end
        return true
    end

    if parryResultRemote then
        parryResultRemote.OnClientEvent:Connect(function(success, cooldown)
            if not Cooldown.WaitingForResult and not Cooldown.JustFired then return end
            local cd = tonumber(cooldown) or 0
            if success and cd > 0 then
                StartCooldown(math.min(cd, Cooldown.MaxCooldown))
            else
                StartCooldown(Cooldown.FallbackCooldown)
            end
        end)
    end

    local function HookSilenced(char)
        if not char then return end
        Cooldown.IsSilenced = CollectionService:HasTag(char, "Silenced")
    end
    CollectionService:GetInstanceAddedSignal("Silenced"):Connect(function(inst)
        if inst == LocalPlayer.Character then Cooldown.IsSilenced = true end
    end)
    CollectionService:GetInstanceRemovedSignal("Silenced"):Connect(function(inst)
        if inst == LocalPlayer.Character then Cooldown.IsSilenced = false end
    end)
    LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.5); HookSilenced(char)
    end)
    if LocalPlayer.Character then HookSilenced(LocalPlayer.Character) end

    local CharCache = { Char = nil, Root = nil, Hum = nil, UpperTorso = nil, CheckInt = nil }
    local function GetCharCache()
        local char = LocalPlayer.Character
        if char ~= CharCache.Char then
            CharCache.Char = char; CharCache.Root = nil; CharCache.Hum = nil
            CharCache.UpperTorso = nil; CharCache.CheckInt = nil
        end
        if not char then return CharCache end
        if not CharCache.Root then CharCache.Root = char:FindFirstChild("HumanoidRootPart") end
        if not CharCache.Hum then CharCache.Hum = char:FindFirstChildOfClass("Humanoid") end
        if not CharCache.UpperTorso then
            CharCache.UpperTorso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        end
        if not CharCache.CheckInt then CharCache.CheckInt = char:FindFirstChild("CheckInterractable") end
        return CharCache
    end

    local DaggerCache = { Value = false, LastCheck = 0, Interval = 0.15 }
    local function IsDaggerModel(inst)
        if not inst then return false end
        if inst:IsA("Model") or inst:IsA("Tool") or inst:IsA("Accessory") then return true end
        return false
    end
    local function IsEquippedDagger()
        local now = os.clock()
        if now - DaggerCache.LastCheck < DaggerCache.Interval then return DaggerCache.Value end
        DaggerCache.LastCheck = now
        local has = false
        local char = LocalPlayer.Character
        if char and IsDaggerModel(char:FindFirstChild("Parrying Dagger")) then has = true end
        if not has then
            local wsChar = Workspace:FindFirstChild(LocalPlayer.Name)
            if wsChar and IsDaggerModel(wsChar:FindFirstChild("Parrying Dagger")) then has = true end
        end
        DaggerCache.Value = has
        return has
    end
    LocalPlayer.CharacterAdded:Connect(function() DaggerCache.Value = false; DaggerCache.LastCheck = 0 end)

    local CheckAttrs = {"isVaulting","isSliding","isDroppingPallet","isRepairing","isHealing","isUnhooking","isExiting"}
    local function IsBusy()
        local cc = GetCharCache()
        if not cc.Char then return true end
        if LocalPlayer:GetAttribute("IsDead") then return true end
        if cc.Char:GetAttribute("IsCarried") then return true end
        if cc.Char:GetAttribute("IsHooked") then return true end
        local root = cc.Root
        if root and CollectionService:HasTag(root, "doing action") then return true end
        local ci = cc.CheckInt
        if ci then
            for i = 1, #CheckAttrs do
                if ci:GetAttribute(CheckAttrs[i]) then return true end
            end
        end
        return false
    end

    local function IsLowHealth()
        local cc = GetCharCache()
        local hum = cc.Hum
        if not hum then return false end
        return hum.Health < hum.MaxHealth * 0.5
    end

    local function CanFire()
        if not IsEquippedDagger() then return false end
        if Cooldown.IsSilenced then return false end
        if IsOnCooldown() then return false end
        if Cooldown.WaitingForResult then return false end
        if IsBusy() then return false end
        if IsLowHealth() then return false end
        return true
    end

    local function ExecuteMobile()
        local didFire = false
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        if pGui and type(firesignal) == "function" then
            local mobRoot = pGui:FindFirstChild("Survivor-mob")
            local controls = mobRoot and mobRoot:FindFirstChild("Controls")
            if controls then
                local candidatePaths = {"Gui-mob", "action", "Gui-mobile", "Gui_mob", "Parry", "parry"}
                for _, btnName in ipairs(candidatePaths) do
                    local btn = controls:FindFirstChild(btnName)
                    if btn and btn:IsA("GuiButton") then
                        pcall(function()
                            firesignal(btn.MouseButton1Down)
                            task.delay(0.05, function()
                                if btn and btn.Parent then
                                    firesignal(btn.MouseButton1Up)
                                    firesignal(btn.MouseButton1Click)
                                end
                            end)
                        end)
                        didFire = true
                        break
                    end
                end
            end
        end
        if not didFire and parryFireRemote then
            pcall(function() parryFireRemote:FireServer() end)
        end
    end

    local function ExecutePC()
        pcall(function()
            VirtualInputManager:SendMouseMoveEvent(0, 0, game)
            task.wait(0.005)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 2, true, game, 0)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 2, false, game, 0)
        end)
    end

    local function ExecuteSilent()
        if not parryFireRemote then
            pcall(function()
                local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                local items = remotes and remotes:FindFirstChild("Items")
                local dagger = items and items:FindFirstChild("Parrying Dagger")
                local remote = dagger and dagger:FindFirstChild("parry")
                if remote then parryFireRemote = remote end
            end)
        end
        if parryFireRemote then
            pcall(function() parryFireRemote:FireServer() end)
            return true
        end
        return false
    end

    local function Execute()
        if not CanFire() then return end
        State.LastParry = os.clock()
        Cooldown.LastFiredAt = os.clock()
        Cooldown.WaitingForResult = true
        Cooldown.WaitingStart = os.clock()
        Cooldown.JustFired = true
        Cooldown.ManualDetect = false
        if VD.PARRY_V4_SilentParry then ExecuteSilent(); return end
        if isMobile then ExecuteMobile() else ExecutePC() end
    end

    local function DestroyCircle()
        if State.CircleFolder then
            pcall(function()
                if State.CircleFolder and State.CircleFolder.Parent then State.CircleFolder:Destroy() end
            end)
        end
        State.CircleFolder = nil
        State.CircleDashes = {}; State.CircleRotCFs = {}; State.CircleOffsets = {}
        State.CircleRadius = 0; State.CircleBuiltForDagger = false
        State.CircleLastX = math.huge; State.CircleLastY = math.huge; State.CircleLastZ = math.huge
        State.CircleLastAlpha = -1; State.CircleLastR = -1; State.CircleLastG = -1; State.CircleLastB = -1
    end

    local function ForceRedraw()
        -- Invalidate cache to force next UpdateCircle to fully redraw
        State.CircleLastX = math.huge
        State.CircleLastY = math.huge
        State.CircleLastZ = math.huge
        State.CircleLastAlpha = -1
        State.CircleLastR = -1
        State.CircleLastG = -1
        State.CircleLastB = -1
    end

    local function BuildCircle(radius)
        DestroyCircle()
        local folder = Instance.new("Folder")
        folder.Name = "MawwwParryV4Circle"
        local dashCount = math.clamp(math.floor(radius * 6), 24, 120)
        local slotLength = (2 * math.pi * radius) / dashCount
        local dashLength = slotLength * 0.55
        local dashThickness = 0.03
        local dashes = table.create(dashCount)
        local rotCFs = table.create(dashCount)
        local offsets = table.create(dashCount)
        for i = 1, dashCount do
            local part = Instance.new("Part")
            part.Name = "Dash" .. i
            part.Anchored = true; part.CanCollide = false
            part.CanTouch = false; part.CanQuery = false; part.CastShadow = false
            part.Material = Enum.Material.Neon
            part.Color = NEON_PURPLE_V4     -- NEON PURPLE
            part.Transparency = 0           -- fully visible from the start
            part.Size = Vector3.new(dashThickness, dashThickness, dashLength)
            part.TopSurface = Enum.SurfaceType.Smooth
            part.BottomSurface = Enum.SurfaceType.Smooth
            part.Parent = folder
            local angle = ((i - 1) / dashCount) * math.pi * 2
            local cosA = math.cos(angle); local sinA = math.sin(angle)
            local tangent = Vector3.new(-sinA, 0, cosA)
            rotCFs[i] = CFrame.lookAt(Vector3.zero, tangent)
            offsets[i] = Vector3.new(cosA * radius, 0, sinA * radius)
            dashes[i] = part
        end
        folder.Parent = Workspace
        State.CircleFolder = folder; State.CircleDashes = dashes
        State.CircleRotCFs = rotCFs; State.CircleOffsets = offsets
        State.CircleRadius = radius; State.CircleBuiltForDagger = true
        ForceRedraw()   -- ensure first UpdateCircle pass writes color/position
    end

    local function UpdateCircle(myRoot)
        if not State.CircleFolder or not State.CircleFolder.Parent then return end
        local dashes = State.CircleDashes
        local dashCount = #dashes
        if dashCount == 0 then return end
        local center = myRoot.Position - Vector3.new(0, (myRoot.Size.Y * 0.5) + 0.15, 0)
        local busy = IsBusy()
        local onCd = Cooldown.OnCooldown
        local targetColor
        if busy then targetColor = Color3.fromRGB(255, 20, 20)
        elseif onCd then targetColor = Color3.fromRGB(255, 140, 0)
        else targetColor = NEON_PURPLE_V4 end   -- IDLE = NEON PURPLE
        local targetTransparency = 0
        if onCd then
            local period = 0.55
            local phase = (os.clock() % period) / period
            local pulse = (math.cos(phase * math.pi * 2) + 1) * 0.5
            targetTransparency = (1 - pulse) * 0.85
        end
        local dx = math.abs(center.X - State.CircleLastX)
        local dy = math.abs(center.Y - State.CircleLastY)
        local dz = math.abs(center.Z - State.CircleLastZ)
        local dA = math.abs(targetTransparency - State.CircleLastAlpha)
        local r, g, b = targetColor.R * 255, targetColor.G * 255, targetColor.B * 255
        local dR = math.abs(r - State.CircleLastR)
        local dG = math.abs(g - State.CircleLastG)
        local dB = math.abs(b - State.CircleLastB)
        if dx < 0.01 and dy < 0.01 and dz < 0.01 and dA < 0.005
            and dR < 2 and dG < 2 and dB < 2 then return end
        State.CircleLastX = center.X; State.CircleLastY = center.Y; State.CircleLastZ = center.Z
        State.CircleLastAlpha = targetTransparency
        State.CircleLastR = r; State.CircleLastG = g; State.CircleLastB = b
        local rotCFs = State.CircleRotCFs
        local offsets = State.CircleOffsets
        for i = 1, dashCount do
            local dash = dashes[i]
            if dash and dash.Parent then
                local off = offsets[i]
                local worldPos = Vector3.new(center.X + off.X, center.Y, center.Z + off.Z)
                dash.CFrame = rotCFs[i] + worldPos
                dash.Color = targetColor
                dash.Transparency = targetTransparency
                dash.Material = Enum.Material.Neon
                dash.CanCollide = false
            end
        end
    end

    local function GetAnimType(track)
        if not track or not track.Animation then return nil end
        local animId = track.Animation.AnimationId or ""
        local numId = animId:match("%d+") or ""
        local name = string.lower(track.Animation.Name or "")
        local v = KillerAttackAnims[animId]
        if v then return v end
        if numId ~= "" then
            v = KillerAttackAnims[numId]
            if v then return v end
        end
        if string.find(name, "lunge", 1, true) or string.find(name, "charge", 1, true) then return "lungehold" end
        if string.find(name, "attack", 1, true) or string.find(name, "slash", 1, true)
            or string.find(name, "swing", 1, true) or string.find(name, "stab", 1, true)
            or string.find(name, "melee", 1, true) then return "attack" end
        return nil
    end

    local function HookAnimatorOnChar(plr, char)
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 3)
        if not animator then return end
        animator.AnimationPlayed:Connect(function(track)
            if not VD.PARRY_V4_Enabled then return end
            if not IsEquippedDagger() then return end
            local animType = GetAnimType(track)
            if animType then
                State.ActiveAttackers[plr] = {
                    char = char, track = track, type = animType,
                    registeredAt = os.clock()
                }
            end
        end)
    end

    local function HookKillerPlayer(plr)
        if plr == LocalPlayer then return end
        if plr.Character then HookAnimatorOnChar(plr, plr.Character) end
        plr.CharacterAdded:Connect(function(char)
            task.wait(0.5); HookAnimatorOnChar(plr, char)
        end)
    end

    for _, plr in ipairs(MawwwGetPlayers()) do HookKillerPlayer(plr) end
    Players.PlayerAdded:Connect(HookKillerPlayer)

    local lastPoll = 0
    local POLL_INTERVAL = 0.15
    local function PollAttacks()
        if not VD.PARRY_V4_Enabled then return end
        if not IsEquippedDagger() then return end
        local now = os.clock()
        if now - lastPoll < POLL_INTERVAL then return end
        lastPoll = now
        local allPlayers = MawwwGetPlayers()
        for i = 1, #allPlayers do
            local plr = allPlayers[i]
            if plr ~= LocalPlayer then
                local char = plr.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then
                        local tracks = hum:GetPlayingAnimationTracks()
                        for j = 1, #tracks do
                            local track = tracks[j]
                            local animType = GetAnimType(track)
                            if animType then
                                local existing = State.ActiveAttackers[plr]
                                if not existing or existing.track ~= track then
                                    State.ActiveAttackers[plr] = {
                                        char = char, track = track, type = animType, registeredAt = now
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local lastCleanup = 0
    local CLEANUP_INTERVAL = 1.0
    local function CleanupAttackers()
        local now = os.clock()
        if now - lastCleanup < CLEANUP_INTERVAL then return end
        lastCleanup = now
        for plr, data in pairs(State.ActiveAttackers) do
            if not plr or not plr.Parent or not data.track or not data.track.IsPlaying then
                State.ActiveAttackers[plr] = nil
            end
        end
    end

    local function CheckAndParry(killerChar)
        if IsOnCooldown() then return end
        if Cooldown.WaitingForResult then return end
        if Cooldown.IsSilenced then return end
        if not IsEquippedDagger() then return end
        local cc = GetCharCache()
        local myRoot = cc.UpperTorso or cc.Root
        local killerPart = killerChar and (killerChar:FindFirstChild("UpperTorso")
            or killerChar:FindFirstChild("Torso")
            or killerChar:FindFirstChild("HumanoidRootPart"))
        if not myRoot or not killerPart then return end
        local dist = (myRoot.Position - killerPart.Position).Magnitude
        if VD.PARRY_V4_Aggressive then
            local ping = math.clamp(LocalPlayer:GetNetworkPing(), 0, 0.3)
            local killerRoot = killerChar:FindFirstChild("HumanoidRootPart") or killerPart
            local killerVel = killerRoot.AssemblyLinearVelocity
            local flatVel = Vector3.new(killerVel.X, 0, killerVel.Z)
            local predictedPos = killerPart.Position + (flatVel * ping)
            local predictedDist = (myRoot.Position - predictedPos).Magnitude
            if predictedDist <= ((VD.PARRY_V4_Distance or 10) + 2.5) then
                local dirToMe = (myRoot.Position - killerPart.Position).Unit
                if flatVel.Magnitude > 6 and flatVel.Unit:Dot(dirToMe) > 0.4 then
                    Execute(); return
                end
            end
        end
        if dist <= (VD.PARRY_V4_Distance or 10) then Execute() end
    end

    local function UpdateLogic()
        local myChar = LocalPlayer.Character
        if not myChar then return end
        if not VD.PARRY_V4_Enabled then return end
        local hasDagger = IsEquippedDagger()
        if not hasDagger then
            if next(State.ActiveAttackers) then State.ActiveAttackers = {} end
            return
        end
        if Cooldown.WaitingForResult then
            if os.clock() - Cooldown.WaitingStart > Cooldown.WaitTimeout then
                if Cooldown.ManualDetect then
                    Cooldown.WaitingForResult = false
                    Cooldown.JustFired = false
                    Cooldown.ManualDetect = false
                else
                    StartCooldown(Cooldown.FallbackCooldown)
                end
            end
        end
        if IsOnCooldown() or Cooldown.WaitingForResult then return end
        PollAttacks(); CleanupAttackers()
        for plr, data in pairs(State.ActiveAttackers) do
            if plr and plr.Parent and data.track and data.track.IsPlaying then
                local shouldCheck = false
                if data.type == "attack" then
                    if data.track.TimePosition < 0.35 then shouldCheck = true end
                elseif data.type == "lungehold" then
                    shouldCheck = true
                end
                if shouldCheck then
                    CheckAndParry(data.char)
                    if Cooldown.WaitingForResult then break end
                end
            else
                State.ActiveAttackers[plr] = nil
            end
        end
    end

    -- === FIX: circle now shows with ShowCircle ONLY (no PARRY_V4_Enabled, no dagger required) ===
    local function UpdateCircleLogic()
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if VD.PARRY_V4_ShowCircle and myRoot then
            if not State.CircleFolder
                or State.CircleRadius ~= (VD.PARRY_V4_Distance or 10)
                or not State.CircleFolder.Parent then
                BuildCircle(VD.PARRY_V4_Distance or 10)
            end
            UpdateCircle(myRoot)
        else
            if State.CircleFolder then DestroyCircle() end
        end
    end

    local LOGIC_INTERVAL = 0.05
    local CIRCLE_INTERVAL = 0.067
    local lastLogic = 0
    local lastCircle = 0

    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - lastCircle >= CIRCLE_INTERVAL then
            lastCircle = now
            pcall(UpdateCircleLogic)
        end
        if now - lastLogic >= LOGIC_INTERVAL then
            lastLogic = now
            pcall(UpdateLogic)
        end
    end)

    return {
        DestroyCircle = DestroyCircle,
        ForceRedraw = ForceRedraw,
        State = State,
        Cooldown = Cooldown,
    }
        end)()
    end)
    if okModule and type(moduleResult) == "table" then
        ParryV4 = moduleResult
    else
        warn("[MawwwHub] Auto Parry V4 init failed:", moduleResult)
    end
end


-- UI: AUTO PARRY V3
RegDivider(Tabs.SurvivalParryV3)
RegLabel(Tabs.SurvivalParryV3, "Auto Parry V3")
RegToggle(Tabs.SurvivalParryV3, "Auto Parry V3", "Enable the V3 auto-parry engine.", false, "SURV_AutoParryV3", function(v)
    if v then
        VD.SURV_AutoParryV5 = false
        if AutoParryV5Module then pcall(AutoParryV5Module.SetEnabled, AutoParryV5Module, false); pcall(AutoParryV5Module.ForceRedraw, AutoParryV5Module) end
    end
    if not v and AutoParryV3Module and AutoParryV3Module.DestroyCircle then pcall(AutoParryV3Module.DestroyCircle) end
    if v and VD.SURV_ShowParryCircleV3 and AutoParryV3Module and AutoParryV3Module.ForceRedraw then pcall(AutoParryV3Module.ForceRedraw) end
    notify("Auto Parry V3", v and "Enabled" or "Disabled", 2)
end)
RegToggle(Tabs.SurvivalParryV3, "Aggressive Prediction", "Use predictive movement to parry incoming attacks earlier.", false, "SURV_ParryAggressiveV3")
RegSlider(Tabs.SurvivalParryV3, "Parry Distance", "Detection and range-circle radius.", 10, 4, 30, 1, "SURV_ParryDistanceV3", function()
    if VD.SURV_ShowParryCircleV3 and AutoParryV3Module and AutoParryV3Module.ForceRedraw then pcall(AutoParryV3Module.ForceRedraw) end
end)
RegToggle(Tabs.SurvivalParryV3, "Show Parry Range", "Display the V3 parry-range circle. Works independently of the auto-parry toggle.", VD.SURV_ShowParryCircleV3 == true, "SURV_ShowParryCircleV3", function(v)
    VD.ShowParryRangeV3 = v and true or false
    if v then
        if AutoParryV3Module and AutoParryV3Module.ForceRedraw then pcall(AutoParryV3Module.ForceRedraw) end
    else
        if AutoParryV3Module and AutoParryV3Module.DestroyCircle then pcall(AutoParryV3Module.DestroyCircle) end
    end
end)
RegToggle(Tabs.SurvivalParryV3, "Silent Parry", "Use the dagger remote directly instead of input simulation.", false, "SURV_SilentParryV3")
RegToggle(Tabs.SurvivalParryV3, "Wall Check", "Require clear line of sight before parrying.", true, "PARRY_V3_WallCheck")
RegToggle(Tabs.SurvivalParryV3, "Ignore Downed", "Ignore downed, hooked, or carried killer states.", true, "PARRY_V3_IgnoreDown")
RegToggle(Tabs.SurvivalParryV3, "Anti-Fake", "Reject suspicious stationary close-range attack windows.", true, "PARRY_V3_AntiFake")
RegToggle(Tabs.SurvivalParryV3, "Ignore Facing", "Disable the killer-facing validation.", false, "PARRY_V3_IgnoreFacing")
RegToggle(Tabs.SurvivalParryV3, "Safety Check", "Require sufficient velocity or close distance.", true, "PARRY_V3_Safety")
RegSlider(Tabs.SurvivalParryV3, "Facing Threshold", "Minimum facing dot product.", 0.5, 0.1, 0.9, 0.05, "PARRY_V3_MinFacing")
RegSlider(Tabs.SurvivalParryV3, "Minimum Velocity", "Minimum killer velocity for validation.", 2, 0.5, 15, 0.5, "PARRY_V3_MinVelocity")
RegToggle(Tabs.SurvivalParryV3, "Raycast Wall Check", "Enable the raycast-based wall validation.", true, "PARRY_V3_Raycast")
RegSlider(Tabs.SurvivalParryV3, "Raycast Range", "Maximum wall-check distance.", 20, 5, 60, 1, "PARRY_V3_RaycastRange")
RegSlider(Tabs.SurvivalParryV3, "Fake Distance", "Close-range threshold for fake-attack filtering.", 2.5, 0.5, 8, 0.5, "PARRY_V3_FakeDistance")


--========================================================--
-- AUTO PARRY V5 • Imported A2 Parry AI engine (UI-integrated)
-- Source: supplied autoparry.lua
-- No standalone popup/UI is created here; controls live in Mawww Hub.
--========================================================--
AutoParryV5Module = (function()
    local AP = {}

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local VirtualInputManager = nil
    pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TweenServiceLocal = game:GetService("TweenService")
    local CollectionServiceLocal = nil
    pcall(function() CollectionServiceLocal = game:GetService("CollectionService") end)
    local LocalPlayer = Players.LocalPlayer

    local ValidIds = {
        ["122812055447896"] = "Veil lunge",
        ["133963973694098"] = "Mayers Basic",
        ["117042998468241"] = "Mayers lunge",
        ["135002183282873"] = "cure lunge",
        ["121216847022485"] = "cure Basic",
        ["132817836308238"] = "Jeff Basic",
        ["129784271201071"] = "Jeff lunge",
        ["82666958311998"] = "Jeff Frenzy",
        ["78432063483146"] = "Abyssal Basic",
        ["118907603246885"] = "Abyssal lunge",
        ["139369275981139"] = "Jason Basic",
        ["110355011987939"] = "Jason lunge",
        ["111920872708571"] = "Masked Basic",
        ["105374834496520"] = "Masked lunge",
        ["138720291317243"] = "Masked Tony",
        ["106871536134254"] = "Masked Alex",
        ["130593238885843"] = "Masked Cobra",
        ["115244153053858"] = "Masked Cobra lunge",
        ["74968262036854"] = "Hidden Basic",
        ["113255068724446"] = "Hidden lunge",
        ["98163597193511"] = "Hidden S1",
        ["80411309607666"] = "Abyssal S1",
    }
    local IgnoreOptions = {"Hidden S1", "Abyssal S1"}

    local State = {
        ParryCooldown = false,
        ParryCooldownThread = nil,
        AutoParryAdornment = nil,
        InputConnectionsMade = false,
        TouchInput = nil,
        Attached = setmetatable({}, {__mode = "k"}),
        RenderClock = 0,
        Unloaded = false,
    }

    local function cfg(name, default)
        local value = VD[name]
        if value == nil then return default end
        return value
    end

    local function isEnabled()
        return cfg("SURV_AutoParryV5", false) == true
    end

    local function isKiller(player)
        if not player or player == LocalPlayer then return false end

        -- Reuse the hub-wide detector first when available.
        local okDetected, detected = pcall(function()
            return type(VD_IsKillerPlayer) == "function" and VD_IsKillerPlayer(player) == true
        end)
        if okDetected and detected then return true end

        local teamName = string.lower((player.Team and player.Team.Name) or "")
        if teamName == "killer" or teamName:find("killer", 1, true) then
            return true
        end

        if player:GetAttribute("IsKiller") == true
            or player:GetAttribute("IsKillerRole") == true
            or tostring(player:GetAttribute("Role") or ""):lower() == "killer" then
            return true
        end

        local char = player.Character
        if char then
            if char:GetAttribute("IsKiller") == true
                or char:GetAttribute("IsKillerRole") == true
                or tostring(char:GetAttribute("Role") or ""):lower() == "killer"
                or char:GetAttribute("KillerType") ~= nil
                or char:GetAttribute("KillerWeapon") ~= nil
                or char:FindFirstChild("Killer") ~= nil then
                return true
            end
        end

        return false
    end

    local function isDowned(char)
        if not char then return true end
        return char:GetAttribute("Knocked") == true
            or char:GetAttribute("IsHooked") == true
    end

    local function getRoot()
        local char = LocalPlayer.Character
        return char and char:FindFirstChild("HumanoidRootPart")
    end

    local function isKillerFacingMe(kHRP, myHRP, angleDeg, kChar)
        if not (kHRP and myHRP) then return false end
        local angle = math.rad(tonumber(angleDeg) or 60)
        local toMe = myHRP.Position - kHRP.Position
        if toMe.Magnitude < 0.05 then return true end
        toMe = Vector3.new(toMe.X, 0, toMe.Z)
        if toMe.Magnitude < 0.05 then return true end
        toMe = toMe.Unit
        local look = kHRP.CFrame.LookVector
        look = Vector3.new(look.X, 0, look.Z)
        if look.Magnitude <= 0.05 then return false end
        look = look.Unit
        local bodyDot = look:Dot(toMe)
        local head = kChar and kChar:FindFirstChild("Head")
        local headDot = bodyDot
        if head then
            local hLook = head.CFrame.LookVector
            hLook = Vector3.new(hLook.X, 0, hLook.Z)
            if hLook.Magnitude > 0.05 then
                headDot = hLook.Unit:Dot(toMe)
            end
        end
        return (bodyDot >= math.cos(angle)) or (headDot >= math.cos(angle))
    end

    local function isSafeToParry(char)
        if cfg("SURV_ParrySafetyV5", false) ~= true then return true end
        if not char then return false end
        local interactObj = char:FindFirstChild("CheckInterractable")
        if interactObj then
            if interactObj:GetAttribute("isVaulting") == true then return false end
            if interactObj:GetAttribute("isRepairing") == true then return false end
            if interactObj:GetAttribute("isUnhooking") == true then return false end
            if interactObj:GetAttribute("isHealing") == true then return false end
            if interactObj:GetAttribute("isSliding") == true then return false end
        end
        return true
    end

    local function triggerCrouch()
        pcall(function()
            local gui = LocalPlayer:FindFirstChild("PlayerGui")
            if not gui then return end
            local obj = gui
            for segment in string.gmatch("Survivor-mob.Controls.crouch.icon", "[^%.]+") do
                obj = obj and obj:FindFirstChild(segment)
            end
            local btn = obj and obj.Parent
            if btn and btn:IsA("GuiButton") and btn.Visible and type(firesignal) == "function" then
                firesignal(btn.MouseButton1Click)
                task.wait(2)
                if btn.Parent then firesignal(btn.MouseButton1Click) end
                return
            end
            if VirtualInputManager then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
                task.wait(2)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
            end
        end)
    end

    local function findParryButton()
        local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not gui then return nil end

        local survivorMob = gui:FindFirstChild("Survivor-mob")
        local controls = survivorMob and survivorMob:FindFirstChild("Controls")
        if not controls then return nil end

        local preferred = {"Gui-mob", "action", "Gui-mobile", "Gui_mob", "Parry", "parry", "attack", "Attack"}
        for _, name in ipairs(preferred) do
            local candidate = controls:FindFirstChild(name, true)
            if candidate and candidate:IsA("GuiButton") and candidate.Visible then
                return candidate
            end
        end

        for _, obj in ipairs(controls:GetDescendants()) do
            if obj:IsA("GuiButton") and obj.Visible then
                return obj
            end
        end

        return nil
    end

    local function tapMobileParryButton()
        local button = findParryButton()
        if not button then return false end

        if type(firesignal) == "function" then
            local ok = pcall(function()
                firesignal(button.MouseButton1Down)
                task.wait(0.01)
                firesignal(button.MouseButton1Up)
                pcall(function() firesignal(button.MouseButton1Click) end)
            end)
            return ok == true
        end

        if VirtualInputManager then
            local ok = pcall(function()
                local p = button.AbsolutePosition + button.AbsoluteSize / 2
                VirtualInputManager:SendMouseButtonEvent(p.X, p.Y, 0, true, game, 0)
                task.wait(0.01)
                VirtualInputManager:SendMouseButtonEvent(p.X, p.Y, 0, false, game, 0)
            end)
            return ok == true
        end

        return false
    end

    local function executeInputParry()
        if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
            return tapMobileParryButton()
        end

        if not VirtualInputManager then
            return false
        end

        local ok = pcall(function()
            VirtualInputManager:SendMouseMoveEvent(0, 0, game)
            task.wait(0.005)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 2, true, game, 0)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 2, false, game, 0)
        end)
        return ok == true
    end

    local function getParryRemote()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local items = remotes and remotes:FindFirstChild("Items")
        local dagger = items and items:FindFirstChild("Parrying Dagger")
        if dagger then
            local remote = dagger:FindFirstChild("parry")
            if remote and remote:IsA("RemoteEvent") then
                return remote
            end
            for _, obj in ipairs(dagger:GetDescendants()) do
                if obj.Name == "parry" and obj:IsA("RemoteEvent") then
                    return obj
                end
            end
        end
        return nil
    end

    local function executeSilentParry()
        local remote = getParryRemote()
        if not remote then return false end

        local sent = false
        for _ = 1, 10 do
            local ok = pcall(function() remote:FireServer() end)
            if ok then sent = true end
        end
        return sent
    end

    local function executeParry()
        if State.ParryCooldown or State.Unloaded or not isEnabled() then return false end

        -- ON: preserve the original V5 remote path that was working before
        -- the toggle was introduced.
        if cfg("SURV_SilentParryV5", true) == true then
            local didRemote = executeSilentParry()
            if didRemote then return true end
            -- Remote may not exist yet while the dagger is spawning. Fall back
            -- to the normal input path instead of silently doing nothing.
            return executeInputParry()
        end

        -- OFF: use the normal parry input path.
        return executeInputParry()
    end

    local function startCooldown(duration)
        local cdDur = math.max(0, tonumber(duration) or 0)
        if cdDur <= 0 then cdDur = 60 end
        State.ParryCooldown = true
        if State.ParryCooldownThread then pcall(task.cancel, State.ParryCooldownThread) end
        State.ParryCooldownThread = task.delay(cdDur, function()
            State.ParryCooldown = false
            State.ParryCooldownThread = nil
        end)
    end

    local function listenParryResult()
        task.spawn(function()
            local remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
            local items = remotes and remotes:WaitForChild("Items", 5)
            local dagger = items and items:WaitForChild("Parrying Dagger", 5)
            local resultRemote = dagger and dagger:WaitForChild("parryResult", 5)
            if not resultRemote or not resultRemote.OnClientEvent then return end
            resultRemote.OnClientEvent:Connect(function(arg1, arg2)
                local cdDur = tonumber(arg2) or ((arg1 == true) and 90 or 60)
                startCooldown(cdDur)
            end)
        end)
    end

    local function attachAnimator(kChar)
        if not kChar or State.Unloaded or State.Attached[kChar] then return end
        State.Attached[kChar] = true

        local humanoid = kChar:FindFirstChildOfClass("Humanoid") or kChar:WaitForChild("Humanoid", 5)
        if not humanoid then State.Attached[kChar] = nil; return end
        local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 5)
        if not animator then State.Attached[kChar] = nil; return end

        humanoid.ChildAdded:Connect(function(child)
            if child:IsA("Animator") and kChar.Parent and not State.Unloaded then
                State.Attached[kChar] = nil
                task.defer(attachAnimator, kChar)
            end
        end)

        kChar.AncestryChanged:Connect(function(_, parent)
            if not parent then State.Attached[kChar] = nil end
        end)

        animator.AnimationPlayed:Connect(function(track)
            if State.Unloaded or not isEnabled() then return end
            local anim = track and track.Animation
            if not anim then return end
            local id = tostring(anim.AnimationId or ""):match("%d+")
            local attackName = id and ValidIds[id]
            if not attackName then return end

            if id == "80411309607666" and cfg("SURV_AutoCrouchV5", false) == true then
                local myChar = LocalPlayer.Character
                if isDowned(myChar) then return end
                local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
                local kHRP = kChar:FindFirstChild("HumanoidRootPart")
                if myHRP and kHRP and (myHRP.Position - kHRP.Position).Magnitude <= 40 then
                    triggerCrouch()
                end
                return
            end

            if State.ParryCooldown or cfg("SURV_AutoParryV5", false) ~= true then return end
            local ignoreList = cfg("SURV_PARRY_V5_Ignore_Skills", {})
            if type(ignoreList) == "table" and ignoreList[attackName] then return end

            local myChar = LocalPlayer.Character
            if isDowned(myChar) or not isSafeToParry(myChar) then return end
            local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local kHRP = kChar:FindFirstChild("HumanoidRootPart")
            if not myHRP or not kHRP then return end

            local startDistance = (myHRP.Position - kHRP.Position).Magnitude
            if cfg("SURV_ParryAntiFakeV5", true) == true then
                if not isKillerFacingMe(kHRP, myHRP, tonumber(cfg("SURV_ParryFacingAngleV5", 60)), kChar) then return end
            end

            local radius = math.max(1, tonumber(cfg("SURV_ParryRadiusV5", 15)) or 15)
            local aggressive = cfg("SURV_ParryAggressiveV5", false) == true
            if aggressive then
                local detectionRadius = radius + 5
                if startDistance > detectionRadius then return end
                local aggressiveRadius = math.min(12, radius)
                if startDistance <= aggressiveRadius then
                    if executeParry() then startCooldown(60) end
                    return
                end

                local tracker
                local startTime = os.clock()
                tracker = RunService.Heartbeat:Connect(function()
                    if State.Unloaded or not isEnabled() or os.clock() - startTime >= 1.5 or State.ParryCooldown then
                        if tracker then tracker:Disconnect() end
                        return
                    end
                    local myRootNow = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    local kRootNow = kChar and kChar:FindFirstChild("HumanoidRootPart")
                    if not myRootNow or not kRootNow or isDowned(LocalPlayer.Character) then
                        if tracker then tracker:Disconnect() end
                        return
                    end
                    if cfg("SURV_ParryAntiFakeV5", true) == true and not isKillerFacingMe(kRootNow, myRootNow, tonumber(cfg("SURV_ParryFacingAngleV5", 60)), kChar) then
                        if tracker then tracker:Disconnect() end
                        return
                    end
                    if (myRootNow.Position - kRootNow.Position).Magnitude <= aggressiveRadius then
                        if executeParry() then startCooldown(60) end
                        if tracker then tracker:Disconnect() end
                    end
                end)
            else
                if startDistance > radius then return end
                local flatDelta = Vector3.new(myHRP.Position.X - kHRP.Position.X, 0, myHRP.Position.Z - kHRP.Position.Z)
                if flatDelta.Magnitude > 0.01 then
                    local flatDirection = flatDelta.Unit
                    local lookFlat = Vector3.new(kHRP.CFrame.LookVector.X, 0, kHRP.CFrame.LookVector.Z)
                    if lookFlat.Magnitude > 0.01 then
                        lookFlat = lookFlat.Unit
                        if lookFlat:Dot(flatDirection) < tonumber(cfg("SURV_ParryFaceV5", 0.7)) then return end
                    end
                end
                if executeParry() then startCooldown(60) end
            end
        end)
    end

    local function tryAttach(player)
        if State.Unloaded or player == LocalPlayer or not isKiller(player) then return end
        local char = player.Character
        if char then attachAnimator(char) end
    end

    local function setupPlayer(player)
        if player == LocalPlayer then return end
        player.CharacterAdded:Connect(function() task.defer(tryAttach, player) end)
        player:GetPropertyChangedSignal("Team"):Connect(function() task.defer(tryAttach, player) end)
        task.defer(tryAttach, player)
    end

    local function updateCircle()
        local now = os.clock()
        if now - State.RenderClock < 0.033 then return end
        State.RenderClock = now

        local hrp = getRoot()
        if not (cfg("SURV_ParryCircleV5", true) == true and isEnabled() and hrp) then
            if State.AutoParryAdornment then
                pcall(function() State.AutoParryAdornment:Destroy() end)
                State.AutoParryAdornment = nil
            end
            return
        end

        if not State.AutoParryAdornment or State.AutoParryAdornment.Parent ~= hrp then
            if State.AutoParryAdornment then pcall(function() State.AutoParryAdornment:Destroy() end) end
            local adorn = Instance.new("CylinderHandleAdornment")
            adorn.Name = "MawwwAutoParryV5Circle"
            adorn.Height = 0.05
            adorn.Transparency = 0.3
            adorn.Adornee = hrp
            adorn.AlwaysOnTop = false
            adorn.ZIndex = 0
            adorn.Parent = hrp
            State.AutoParryAdornment = adorn
        end

        local radius = math.max(1, tonumber(cfg("SURV_ParryRadiusV5", 15)) or 15)
        State.AutoParryAdornment.Radius = radius
        State.AutoParryAdornment.InnerRadius = math.max(0.1, radius - 0.15)
        State.AutoParryAdornment.CFrame = CFrame.new(0, -3, 0) * CFrame.Angles(math.rad(90), 0, 0)
        if State.ParryCooldown then
            State.AutoParryAdornment.Color3 = Color3.fromRGB(255, 128, 0)
        elseif cfg("SURV_ParryAggressiveV5", false) == true then
            State.AutoParryAdornment.Color3 = Color3.fromRGB(255, 0, 0)
        else
            State.AutoParryAdornment.Color3 = Color3.fromRGB(0, 255, 255)
        end
    end

    function AP:SetEnabled(v)
        VD.SURV_AutoParryV5 = v == true
        if not VD.SURV_AutoParryV5 then
            if State.AutoParryAdornment then pcall(function() State.AutoParryAdornment:Destroy() end); State.AutoParryAdornment = nil end
        end
    end

    function AP:ForceRedraw()
        State.RenderClock = 0
        updateCircle()
    end

    function AP:Destroy()
        State.Unloaded = true
        VD.SURV_AutoParryV5 = false
        if State.ParryCooldownThread then pcall(task.cancel, State.ParryCooldownThread) end
        State.ParryCooldownThread = nil
        State.ParryCooldown = false
        if State.AutoParryAdornment then pcall(function() State.AutoParryAdornment:Destroy() end) end
        State.AutoParryAdornment = nil
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        setupPlayer(plr)
    end
    Players.PlayerAdded:Connect(setupPlayer)
    listenParryResult()

    -- Some rounds create the killer character/Animator before assigning the
    -- Killer team. Keep a small watchdog so V5 attaches after those races too.
    task.spawn(function()
        while not State.Unloaded do
            task.wait(0.5)
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and isKiller(plr) and plr.Character and not State.Attached[plr.Character] then
                    pcall(tryAttach, plr)
                end
            end
        end
    end)

    RunService.Heartbeat:Connect(updateCircle)

    function AP:GetIgnoreOptions()
        return IgnoreOptions
    end

    return AP
end)()

getgenv().MAWWW_AutoParryV5 = AutoParryV5Module

-- UI: AUTO PARRY V4
RegDivider(Tabs.SurvivalParryV4)
RegLabel(Tabs.SurvivalParryV4, "Auto Parry V4")
RegToggle(Tabs.SurvivalParryV4, "Auto Parry V4", "Enable the V4 auto-parry engine.", false, "PARRY_V4_Enabled", function(v)
    if v then
        VD.SURV_AutoParryV5 = false
        if AutoParryV5Module then pcall(AutoParryV5Module.SetEnabled, AutoParryV5Module, false); pcall(AutoParryV5Module.ForceRedraw, AutoParryV5Module) end
    end
    if not v and ParryV4 and ParryV4.DestroyCircle then pcall(ParryV4.DestroyCircle) end
    if v and VD.PARRY_V4_ShowCircle and ParryV4 and ParryV4.ForceRedraw then pcall(ParryV4.ForceRedraw) end
    notify("Auto Parry V4", v and "Enabled" or "Disabled", 2)
end)
RegToggle(Tabs.SurvivalParryV4, "Aggressive Prediction", "Use predictive movement to parry incoming attacks earlier.", false, "PARRY_V4_Aggressive")
RegSlider(Tabs.SurvivalParryV4, "Parry Distance", "Detection and range-circle radius.", 10, 4, 20, 1, "PARRY_V4_Distance", function()
    if VD.PARRY_V4_ShowCircle and ParryV4 and ParryV4.ForceRedraw then pcall(ParryV4.ForceRedraw) end
end)
RegToggle(Tabs.SurvivalParryV4, "Silent Parry", "Use the dagger remote directly instead of input simulation.", false, "PARRY_V4_SilentParry")
RegToggle(Tabs.SurvivalParryV4, "Show Parry Range", "Display the V4 parry-range circle independently of the parry engine.", VD.PARRY_V4_ShowCircle == true, "PARRY_V4_ShowCircle", function(v)
    VD.ShowParryRangeV4 = v and true or false
    if v then
        if ParryV4 and ParryV4.ForceRedraw then pcall(ParryV4.ForceRedraw) end
    else
        if ParryV4 and ParryV4.DestroyCircle then pcall(ParryV4.DestroyCircle) end
    end
end)
RegToggle(Tabs.SurvivalParryV4, "Wall Check", "Require clear line of sight before parrying.", true, "PARRY_V4_WallCheck")
RegToggle(Tabs.SurvivalParryV4, "Ignore Downed", "Ignore invalid killer states.", true, "PARRY_V4_IgnoreDown")
RegToggle(Tabs.SurvivalParryV4, "Anti-Fake", "Reject suspicious fake attacks.", true, "PARRY_V4_AntiFake")
RegToggle(Tabs.SurvivalParryV4, "Safety Check", "Enable safety validation.", true, "PARRY_V4_Safety")
RegToggle(Tabs.SurvivalParryV4, "Ignore Facing", "Disable the facing validation.", false, "PARRY_V4_IgnoreFacing")
RegToggle(Tabs.SurvivalParryV4, "Auto Face", "Allow the V4 engine to face the attacker.", false, "PARRY_V4_AutoFace")
RegSlider(Tabs.SurvivalParryV4, "Facing Threshold", "Minimum facing dot product.", 0.35, 0, 1, 0.05, "PARRY_V4_Facing")
RegSlider(Tabs.SurvivalParryV4, "Minimum Velocity", "Minimum killer velocity for validation.", 2, 0, 15, 0.5, "PARRY_V4_MinVelocity")

-- UI: AUTO PARRY V5 (source autoparry.lua, integrated into main hub)
RegDivider(Tabs.SurvivalParryV5)
RegLabel(Tabs.SurvivalParryV5, "Auto Parry V5 • A2 Parry AI")
RegToggle(Tabs.SurvivalParryV5, "Auto Parry V5", "Animation-driven parry engine from the supplied A2 source.", false, "SURV_AutoParryV5", function(v)
    VD.SURV_AutoParryV5 = v == true
    if VD.SURV_AutoParryV5 then
        VD.SURV_AutoParry = false
        VD.SURV_AutoParryV3 = false
        VD.PARRY_V4_Enabled = false
        pcall(function() if AutoParryModule and AutoParryModule.DestroyCircle then AutoParryModule.DestroyCircle() end end)
        pcall(function() if ParryV4 and ParryV4.DestroyCircle then ParryV4.DestroyCircle() end end)
        pcall(function() if AutoParryV3Module and AutoParryV3Module.DestroyCircle then AutoParryV3Module.DestroyCircle() end end)
    end
    if AutoParryV5Module then pcall(AutoParryV5Module.SetEnabled, AutoParryV5Module, VD.SURV_AutoParryV5); pcall(AutoParryV5Module.ForceRedraw, AutoParryV5Module) end
    notify("Auto Parry V5", VD.SURV_AutoParryV5 and "Enabled" or "Disabled", 2)
end)
RegToggle(Tabs.SurvivalParryV5, "Silent Parry", "ON = direct dagger remote (original V5 path). OFF = normal parry input.", VD.SURV_SilentParryV5 == true, "SURV_SilentParryV5")
RegToggle(Tabs.SurvivalParryV5, "Aggressive Mode", "Start tracking slightly earlier before the parry radius.", false, "SURV_ParryAggressiveV5", function(v)
    VD.SURV_ParryAggressiveV5 = v == true
    if AutoParryV5Module then pcall(AutoParryV5Module.ForceRedraw, AutoParryV5Module) end
end)
RegToggle(Tabs.SurvivalParryV5, "Anti Fake Hit", "Require the killer to be facing you before parrying.", true, "SURV_ParryAntiFakeV5")
RegToggle(Tabs.SurvivalParryV5, "Safety Parry", "Skip parry during unsafe interactions.", false, "SURV_ParrySafetyV5")
RegToggle(Tabs.SurvivalParryV5, "Auto Crouch (Abyssal S1)", "Crouch for the Abyssal S1 special animation.", false, "SURV_AutoCrouchV5")
RegToggle(Tabs.SurvivalParryV5, "ESP Range Circle", "Show the V5 parry radius around your character.", true, "SURV_ParryCircleV5", function(v)
    VD.SURV_ParryCircleV5 = v == true
    if AutoParryV5Module then pcall(AutoParryV5Module.ForceRedraw, AutoParryV5Module) end
end)
RegSlider(Tabs.SurvivalParryV5, "Parry Radius", "Source radius used for normal parry detection.", 15, 5, 30, 1, "SURV_ParryRadiusV5", function()
    if AutoParryV5Module then pcall(AutoParryV5Module.ForceRedraw, AutoParryV5Module) end
end)
RegSlider(Tabs.SurvivalParryV5, "Face Sensitivity", "Minimum facing dot product for normal parry.", 0.7, -1, 1, 0.05, "SURV_ParryFaceV5")
RegSlider(Tabs.SurvivalParryV5, "Facing Angle", "Anti-fake facing angle in degrees.", 60, 15, 120, 5, "SURV_ParryFacingAngleV5")
RegToggle(Tabs.SurvivalParryV5, "Ignore Hidden S1", "Ignore the Hidden S1 animation.", false, "APV5_IgnoreHiddenS1", function(v)
    VD.SURV_PARRY_V5_Ignore_Skills = VD.SURV_PARRY_V5_Ignore_Skills or {}
    if v then VD.SURV_PARRY_V5_Ignore_Skills["Hidden S1"] = true else VD.SURV_PARRY_V5_Ignore_Skills["Hidden S1"] = nil end
end)
RegToggle(Tabs.SurvivalParryV5, "Ignore Abyssal S1", "Ignore the Abyssal S1 animation.", false, "APV5_IgnoreAbyssalS1", function(v)
    VD.SURV_PARRY_V5_Ignore_Skills = VD.SURV_PARRY_V5_Ignore_Skills or {}
    if v then VD.SURV_PARRY_V5_Ignore_Skills["Abyssal S1"] = true else VD.SURV_PARRY_V5_Ignore_Skills["Abyssal S1"] = nil end
end)

-- Movement & Moonwalk

RegDivider(Tabs.Player)
RegLabel(Tabs.Player, "Movement & Moonwalk")
MoonwalkConn = nil
function startMoonwalk()
    if MoonwalkConn then MoonwalkConn:Disconnect(); MoonwalkConn = nil end
    MoonwalkConn = RunService.RenderStepped:Connect(function()
        local char = Player.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not VD.Moonwalk or (not humanoid) or humanoid.Health <= 0 then
            if humanoid then
                if humanoid.AutoRotate == false then humanoid.AutoRotate = true end
                if humanoid.WalkSpeed == 13 then humanoid.WalkSpeed = 16 end
            end
            return
        end
        local cam = workspace.CurrentCamera
        if not (hrp and cam) then return end
        if humanoid.AutoRotate then humanoid.AutoRotate = false end
        local look = cam.CFrame.LookVector
        local flat = Vector3.new(look.X, 0, look.Z)
        if flat.Magnitude < 0.001 then return end
        flat = flat.Unit
        local spamSpeed = tonumber(VD.MoonwalkSpam) or 30
        local intensity = tonumber(VD.MoonwalkIntensity) or 35
        local angle = math.sin(tick() * spamSpeed) * intensity
        local baseCF = CFrame.new(hrp.Position, hrp.Position + flat)
        hrp.CFrame = baseCF * CFrame.Angles(0, math.rad(angle), 0)
    end)
end
getgenv().MAWWW_StartMoonwalk = startMoonwalk
RegToggle(Tabs.Player, "Moonwalk", "Enable moonwalk", false, "Moonwalk", function(v)
    if v then
        startMoonwalk()
    elseif MoonwalkConn then
        MoonwalkConn:Disconnect()
        MoonwalkConn = nil
        local h = getHum()
        if h then h.AutoRotate = true end
    end
end)
RegSlider(Tabs.Player, "Moonwalk Spam Speed", "Spam speed", 30, 1, 50, 1, "MoonwalkSpam")
RegSlider(Tabs.Player, "Moonwalk Intensity", "Rotation intensity", 35, 1, 50, 1, "MoonwalkIntensity")
RegToggle(Tabs.Player, "Show Moonwalk Icon", "Show quick toggle icon", false, "ShowMoonwalkIcon", function(v)
    if getgenv().MAWWW_QuickRefresh then pcall(getgenv().MAWWW_QuickRefresh) end
end)
RegToggle(Tabs.Player, "Lock Moonwalk Icon", "Lock icon position", false, "LockMoonwalkIcon", function(v)
    if getgenv().MAWWW_QuickRefresh then pcall(getgenv().MAWWW_QuickRefresh) end
end)

originalCanCollide = {}
local NoclipLastUpdate = 0
RunService.Stepped:Connect(function()
    if not VD.Noclip then return end
    local now = os.clock()
    if now - NoclipLastUpdate < 0.05 then return end
    NoclipLastUpdate = now
    if VD.Noclip then
        local char = Player.Character
        if char then
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") then
                    if originalCanCollide[d] == nil then originalCanCollide[d] = d.CanCollide end
                    d.CanCollide = false
                end
            end
        end
    end
end)
function VD_DisableNoclip()
    for part, cc in pairs(originalCanCollide) do if part and part.Parent then pcall(function() part.CanCollide = cc end) end end
    originalCanCollide = {}
end
local SpeedLastUpdate = 0
RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - SpeedLastUpdate < 0.05 then return end
    SpeedLastUpdate = now
    local hum = getHum()
    if hum then
        if VD.Speed and hum.WalkSpeed ~= VD.SpeedValue then hum.WalkSpeed = VD.SpeedValue end
    end
end)
RegToggle(Tabs.Player, "Speed Boost", "Custom walkspeed", false, "Speed", function(v) if not v then local hum = getHum(); if hum then hum.WalkSpeed = 16 end end end)
RegSlider(Tabs.Player, "WalkSpeed", "Speed value", 16, 16, 120, 1, "SpeedValue")
RegToggle(Tabs.Player, "Noclip", "Walk through walls", false, "Noclip", function(v) if not v then VD_DisableNoclip() end end)

-- Fling & Predict
RegDivider(Tabs.Utility)
RegLabel(Tabs.Utility, "Fling")
function VD_FlingNearest()
    if not VD.FlingEnabled then return end
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart"); if not root then return end
    local closest, closestDist = nil, math.huge
    for _, plr in ipairs(MawwwGetPlayers()) do
        if plr ~= Player and plr.Character then
            local tr = plr.Character:FindFirstChild("HumanoidRootPart")
            if tr then local d = (tr.Position - root.Position).Magnitude; if d < closestDist then closestDist = d; closest = plr end end
        end
    end
    if closest and closest.Character then
        local tr = closest.Character:FindFirstChild("HumanoidRootPart")
        if tr then
            local orig = root.CFrame
            for _ = 1, 10 do
                root.CFrame = tr.CFrame
                root.Velocity = Vector3.new(VD.FlingStrength, VD.FlingStrength/2, VD.FlingStrength)
                root.RotVelocity = Vector3.new(9999, 9999, 9999)
                task.wait()
            end
            root.CFrame = orig; root.Velocity = Vector3.zero; root.RotVelocity = Vector3.zero
        end
    end
end
function VD_FlingAll()
    if not VD.FlingEnabled then return end
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart"); if not root then return end
    local orig = root.CFrame
    for _, plr in ipairs(MawwwGetPlayers()) do
        if plr ~= Player and plr.Character then
            local tr = plr.Character:FindFirstChild("HumanoidRootPart")
            if tr then
                for _ = 1, 5 do
                    root.CFrame = tr.CFrame
                    root.Velocity = Vector3.new(VD.FlingStrength, VD.FlingStrength/2, VD.FlingStrength)
                    root.RotVelocity = Vector3.new(9999, 9999, 9999)
                    task.wait()
                end
            end
        end
    end
    root.CFrame = orig; root.Velocity = Vector3.zero; root.RotVelocity = Vector3.zero
end
RegToggle(Tabs.Utility, "Fling", "Fling nearby players", false, "FlingEnabled")
RegSlider(Tabs.Utility, "Fling Strength", "Fling power", 10000, 1000, 50000, 1000, "FlingStrength")
RegButton(Tabs.Utility, "Fling Nearest", "Fling closest player", function() pcall(VD_FlingNearest) end)
RegButton(Tabs.Utility, "Fling All", "Fling all players", function() pcall(VD_FlingAll) end)

RegDivider(Tabs.UtilityPredict)
RegLabel(Tabs.UtilityPredict, "Prediction")
PredictState = { CurrentMap = "Waiting...", CurrentKiller = "Waiting..." }
function GetMapNameFromWorkspace()
    local mapFolder = Workspace:FindFirstChild("Map"); if not mapFolder then return nil end
    local names = {"title", "Title", "MapName", "Name"}
    local attrs = mapFolder:GetAttributes()
    for _, n in ipairs(names) do if attrs[n] ~= nil then return tostring(attrs[n]) end end
    for _, child in ipairs(mapFolder:GetChildren()) do
        local cAttrs = child:GetAttributes()
        for _, n in ipairs(names) do if cAttrs[n] ~= nil then return tostring(cAttrs[n]) end end
    end
    return nil
end
function GetNextKillerFromAttributes()
    local candidates = {}
    for _, p in ipairs(MawwwGetPlayers()) do
        if p ~= Player then
            local allow = p:GetAttribute("AllowKiller")
            local chance = p:GetAttribute("KillerChance")
            local kystMark = p:GetAttribute("KystInLine")
            local score = 0
            if allow == true then score = score + 1000 end
            if typeof(chance) == "number" then score = score + chance end
            if kystMark == true then score = score + 500 end
            table.insert(candidates, {Player = p, Score = score})
        end
    end
    table.sort(candidates, function(a, b) return a.Score > b.Score end)
    if candidates[1] and candidates[1].Score > 0 then return candidates[1].Player end
    return nil
end
task.spawn(function()
    while not VD.Destroyed do
        task.wait(1)
        if VD.PredictMap then
            local mapName = GetMapNameFromWorkspace()
            if mapName and mapName ~= "" and mapName ~= PredictState.CurrentMap then PredictState.CurrentMap = mapName; notify("Predict Map", "Map: " .. mapName, 3) end
        end
        if VD.PredictKiller then
            local nextKiller = GetNextKillerFromAttributes()
            local name = nextKiller and (nextKiller.DisplayName or nextKiller.Name) or "Unknown"
            if name ~= PredictState.CurrentKiller then PredictState.CurrentKiller = name; notify("Next Killer", "Next Killer: " .. name, 3) end
        end
    end
end)
RegToggle(Tabs.UtilityPredict, "Predict Map", "Predict next map", false, "PredictMap")
RegToggle(Tabs.UtilityPredict, "Next Killer", "Predict next killer", false, "PredictKiller")
RegButton(Tabs.UtilityPredict, "Refresh Prediction", "Refresh prediction data", function()
    PredictState.CurrentMap = ""; PredictState.CurrentKiller = ""
    notify("Predict", "Prediction refreshed", 2)
end)
RegButton(Tabs.UtilityPredict, "Clear Prediction", "Clear prediction data", function()
    PredictState.CurrentMap = ""; PredictState.CurrentKiller = ""
    notify("Predict", "Prediction cleared", 2)
end)
RegLabel(Tabs.UtilityPredict, "Map: Waiting... | Killer: Waiting...")

--========================================================--

-- SURVIVAL TAB
--========================================================--

RegLabel(Tabs.SurvivalEscape, "Survivor Actions")
LastFlee = 0
RegToggle(Tabs.SurvivalEscape, "Auto Flee", "Auto flee from killer", false, "AutoFlee")
RegSlider(Tabs.SurvivalEscape, "Flee Distance", "Flee trigger distance", 50, 15, 80, 1, "AutoFleeDist")
task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.2)
        if VD.AutoFlee then
            local root = getRoot()
            if root then
                local kRoot
                for _, p in ipairs(MawwwGetPlayers()) do
                    if p ~= Player and IsKiller(p) and p.Character then kRoot = p.Character:FindFirstChild("HumanoidRootPart"); break end
                end
                if kRoot and (kRoot.Position - root.Position).Magnitude <= VD.AutoFleeDist and tick() - LastFlee > 0.1 then
                    local bestPoint, bestDist = nil, 0
                    for _, obj in ipairs(Workspace:GetDescendants()) do
                        if obj:IsA("BasePart") and string.match(obj.Name, "^GeneratorPoint%d+$") then
                            local d = (obj.Position - kRoot.Position).Magnitude
                            if d > bestDist then bestDist = d; bestPoint = obj end
                        end
                    end
                    if bestPoint then LastFlee = tick(); root.CFrame = bestPoint.CFrame + Vector3.new(0, 5, 0) end
                end
            end
        end
    end
end)
RegDivider(Tabs.SurvivalEscape)
RegLabel(Tabs.SurvivalEscape, "Healing / Aura Heal")

RegLabel(Tabs.SurvivalEscape, "Auto Escape")
function VD_FindFinishLine()
    for _, obj in ipairs(workspace:GetDescendants()) do
        local n = string.lower(obj.Name)
        if (n == "finishline" or n == "fininshline" or n == "exitgate" or n == "exitzone" or n:find("finish") or n:find("exit")) and obj:IsA("BasePart") then return obj end
    end
    return nil
end
function VD_DoEscape()
    local root = getRoot(); if not root then return false end
    local finish = VD_FindFinishLine()
    if finish then
        pcall(function() root.CFrame = CFrame.new(finish.Position + Vector3.new(0, 3, 0)) end)
        task.wait(0.05)
        if firetouchinterest then
            pcall(function() firetouchinterest(root, finish, 0) end)
            pcall(function() firetouchinterest(root, finish, 1) end)
        end
    end
    pcall(function()
        local r = GetRemotes()
        local g = r and r:FindFirstChild("Game")
        local ev = g and g:FindFirstChild("PlayerActionEvent")
        if ev then ev:FireServer("ESCAPED", 200); task.wait(0.05); ev:FireServer("ESCAPED", 200) end
    end)
    return true
end
task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.5)
        if VD.BeatSurvivor and GetRole() == "Survivor" then pcall(VD_DoEscape) end
    end
end)
RegToggle(Tabs.SurvivalEscape, "Beat Survivor", "Auto escape the map", false, "BeatSurvivor")
RegButton(Tabs.SurvivalEscape, "Escape Now", "Force escape now", function() pcall(VD_DoEscape); notify("Escape", "Trying to escape...", 2) end)

--========================================================--
--========================================================--
-- K4N3K1 FEATURE IMPORTS
-- Counter Auto Parry + Aim Lock Hidden + Aim Lock Attack
-- Destroy Pallet + Bypass Self Unhook
-- Source: K4N3K1_HUB.lua.txt
--========================================================--
do
    local K4 = getgenv().MAWWW_K4N3K1 or {}
    getgenv().MAWWW_K4N3K1 = K4

    --========================================================--
    -- COUNTER AUTO PARRY
    --========================================================--
    K4.CounterAutoParry = K4.CounterAutoParry or {
        Enabled = false,
        Range = 15,
        Interval = 0.5,
        LastRun = 0,
        Animations = {
            "78432063483146", "121216847022485", "74968262036854",
            "132817836308238", "82666958311998", "111920872708571",
            "106871536134254", "109402730355822", "130593238885843",
            "138720291317243", "139369275981139", "133963973694098",
            "78935059863801", "118907603246885", "135002183282873",
            "113255068724446", "129784271201071", "105374834496520",
            "117070354890871", "115244153053858", "110355011987939",
            "117042998468241", "122812055447896"
        },
        LastTrack = nil,
    }

    local Counter = K4.CounterAutoParry
    -- Keep imported state synchronized with the hub config on first load/reload.
    Counter.Enabled = VD.KillerCounterAutoParry == true
    local function CounterHasNearbySurvivor()
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return false end
        for _, p in ipairs(MawwwGetPlayers()) do
            if p ~= Player and IsSurvivor(p) and p.Character then
                local r = p.Character:FindFirstChild("HumanoidRootPart")
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if r and hum and hum.Health > 0 then
                    if (root.Position - r.Position).Magnitude <= (Counter.Range or 15) then
                        return true
                    end
                end
            end
        end
        return false
    end

    function K4.CounterAutoParryStep()
        if not Counter.Enabled or GetRole() ~= "Killer" then return end
        local now = os.clock()
        if now - Counter.LastRun < (Counter.Interval or 0.5) then return end
        Counter.LastRun = now
        if not CounterHasNearbySurvivor() then return end

        local char = Player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local animator = hum and hum:FindFirstChildOfClass("Animator")
        if not animator or #Counter.Animations == 0 then return end

        local id = Counter.Animations[math.random(1, #Counter.Animations)]
        local anim = Instance.new("Animation")
        anim.Name = "MAWWW_CounterAutoParry"
        anim.AnimationId = "rbxassetid://" .. id
        local track
        local ok = pcall(function()
            track = animator:LoadAnimation(anim)
            track.Priority = Enum.AnimationPriority.Action
            track:Play(0.01, 0, 1)
            track:AdjustWeight(0)
        end)
        if ok and track then
            Counter.LastTrack = track
            task.delay(0.06, function()
                pcall(function()
                    if track and track.IsPlaying then track:Stop(0.01) end
                end)
                pcall(function() anim:Destroy() end)
                if Counter.LastTrack == track then Counter.LastTrack = nil end
            end)
        else
            pcall(function() anim:Destroy() end)
        end
    end

    task.spawn(function()
        while not VD.Destroyed do
            task.wait(0.05)
            pcall(K4.CounterAutoParryStep)
        end
    end)

    function K4.SetCounterAutoParry(v)
        Counter.Enabled = v == true
        VD.KillerCounterAutoParry = Counter.Enabled
        if not Counter.Enabled and Counter.LastTrack then
            pcall(function() Counter.LastTrack:Stop(0.01) end)
            Counter.LastTrack = nil
        end
    end

    --========================================================--
    -- AIM LOCK HIDDEN
    --========================================================--
    K4.AimLockHidden = K4.AimLockHidden or {
        Enabled = false,
        Holding = false,
        HoldKey = Enum.KeyCode.E,
        Thread = nil,
        MobileConnections = {},
        HookedButtons = setmetatable({}, { __mode = "k" }),
    }
    local Hidden = K4.AimLockHidden
    Hidden.Enabled = VD.AimLockHidden == true
    do
        local saved = tostring(VD.AimLockHiddenKey or "E")
        for _, item in ipairs(Enum.KeyCode:GetEnumItems()) do
            if item.Name:lower() == saved:lower() then Hidden.HoldKey = item; break end
        end
    end

    local function HiddenDisconnectMobile()
        for _, c in ipairs(Hidden.MobileConnections) do
            pcall(function() c:Disconnect() end)
        end
        Hidden.MobileConnections = {}
        Hidden.HookedButtons = setmetatable({}, { __mode = "k" })
    end

    local function HiddenGetClosestTarget()
        local myChar = Player.Character
        local hrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end
        local role = GetRole()
        if role ~= "Killer" and role ~= "Survivor" then return nil end
        local myIsKiller = role == "Killer"
        local best, bestDist = nil, math.huge
        for _, p in ipairs(MawwwGetPlayers()) do
            if p ~= Player and p.Character then
                local targetRoot = p.Character:FindFirstChild("HumanoidRootPart")
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if targetRoot and hum and hum.Health > 0 then
                    local enemy = myIsKiller and IsSurvivor(p) or ((not myIsKiller) and IsKiller(p))
                    if enemy then
                        local d = (targetRoot.Position - hrp.Position).Magnitude
                        if d < bestDist then
                            bestDist, best = d, targetRoot
                        end
                    end
                end
            end
        end
        return best
    end

    local function HiddenStart()
        if Hidden.Thread then return end
        Hidden.Thread = task.spawn(function()
            while Hidden.Enabled and not VD.Destroyed do
                if Hidden.Holding then
                    local cam = Workspace.CurrentCamera
                    local target = HiddenGetClosestTarget()
                    if cam and target then
                        pcall(function()
                            cam.CFrame = CFrame.new(
                                cam.CFrame.Position,
                                target.Position + Vector3.new(0, 2.5, 0)
                            )
                        end)
                    end
                end
                RunService.RenderStepped:Wait()
            end
            Hidden.Thread = nil
        end)
    end

    local function HiddenSetHolding(v)
        Hidden.Holding = Hidden.Enabled and (v == true) or false
    end

    table.insert(Hidden.MobileConnections, UserInputService.InputBegan:Connect(function(input, gp)
        if gp or not Hidden.Enabled then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            HiddenSetHolding(true)
        elseif input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Hidden.HoldKey then
            HiddenSetHolding(true)
        end
    end))

    table.insert(Hidden.MobileConnections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            HiddenSetHolding(false)
        elseif input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Hidden.HoldKey then
            HiddenSetHolding(false)
        end
    end))

    local function HiddenIsMobileButton(obj)
        if not obj or not obj:IsA("GuiButton") then return false end
        local name = string.lower(obj.Name or "")
        local names = { "attack", "shoot", "fire", "basicattack", "tembak", "hidden", "skill", "ability", "power", "skill1", "ability1", "gui-mob" }
        for _, n in ipairs(names) do
            if name == n or string.find(name, n, 1, true) then return true end
        end
        return false
    end

    local function HiddenHookButton(btn)
        if not HiddenIsMobileButton(btn) or Hidden.HookedButtons[btn] then return end
        Hidden.HookedButtons[btn] = true
        table.insert(Hidden.MobileConnections, btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch and Hidden.Enabled then
                HiddenSetHolding(true)
            end
        end))
        table.insert(Hidden.MobileConnections, btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                HiddenSetHolding(false)
            end
        end))
        table.insert(Hidden.MobileConnections, btn:GetPropertyChangedSignal("Visible"):Connect(function()
            if not btn.Visible then HiddenSetHolding(false) end
        end))
    end

    local function HiddenSetupMobile()
        HiddenDisconnectMobile()
        -- Button connections are rebuilt after respawn/UI recreation.
        -- Reset the weak-key cache so existing buttons are hooked again.
        Hidden.HookedButtons = setmetatable({}, { __mode = "k" })
        -- Re-register the permanent user input handlers after cleanup.
        table.insert(Hidden.MobileConnections, UserInputService.InputBegan:Connect(function(input, gp)
            if gp or not Hidden.Enabled then return end
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                HiddenSetHolding(true)
            elseif input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Hidden.HoldKey then
                HiddenSetHolding(true)
            end
        end))
        table.insert(Hidden.MobileConnections, UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                HiddenSetHolding(false)
            elseif input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Hidden.HoldKey then
                HiddenSetHolding(false)
            end
        end))
        local pGui = Player:FindFirstChildOfClass("PlayerGui")
        if not pGui then return end
        local function scan()
            for _, root in ipairs(pGui:GetChildren()) do
                local controls = root:FindFirstChild("Controls")
                if controls then
                    for _, d in ipairs(controls:GetDescendants()) do
                        HiddenHookButton(d)
                    end
                end
            end
        end
        scan()
        table.insert(Hidden.MobileConnections, pGui.ChildAdded:Connect(function()
            task.defer(scan)
        end))
    end

    -- Avoid duplicate permanent input handlers when mobile hooks are rebuilt.
    HiddenDisconnectMobile()
    if UserInputService.TouchEnabled then
        HiddenSetupMobile()
    else
        table.insert(Hidden.MobileConnections, UserInputService.InputBegan:Connect(function(input, gp)
            if gp or not Hidden.Enabled then return end
            if input.UserInputType == Enum.UserInputType.MouseButton2 then HiddenSetHolding(true) end
            if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Hidden.HoldKey then HiddenSetHolding(true) end
        end))
        table.insert(Hidden.MobileConnections, UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton2 then HiddenSetHolding(false) end
            if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Hidden.HoldKey then HiddenSetHolding(false) end
        end))
    end

    function K4.SetAimLockHidden(v)
        Hidden.Enabled = v == true
        VD.AimLockHidden = Hidden.Enabled
        HiddenSetHolding(false)
        if Hidden.Enabled then
            HiddenStart()
        else
            if Hidden.Thread then
                pcall(function() task.cancel(Hidden.Thread) end)
                Hidden.Thread = nil
            end
        end
    end

    function K4.SetAimLockHiddenKey(keyCode)
        if typeof(keyCode) == "EnumItem" and keyCode.EnumType == Enum.KeyCode then
            Hidden.HoldKey = keyCode
            VD.AimLockHiddenKey = keyCode.Name
        end
    end

    Player.CharacterAdded:Connect(function()
        HiddenSetHolding(false)
        if UserInputService.TouchEnabled then
            task.delay(1, function()
                if Hidden.Enabled then HiddenSetupMobile() end
            end)
        end
    end)

    --========================================================--
    -- AIM LOCK ATTACK
    --========================================================--
    K4.AimLockAttack = K4.AimLockAttack or {
        Enabled = false,
        Holding = false,
        Strength = 1,
        Predict = true,
        PredictStrength = 0.12,
        FOV = 250,
        VisibilityCheck = true,
        AimPart = "HumanoidRootPart",
        Connection = nil,
        CurrentButton = nil,
        MobileConnection = nil,
    }
    local AttackAim = K4.AimLockAttack
    AttackAim.Enabled = VD.AimLockAttack == true
    AttackAim.FOV = tonumber(VD.AimLockAttackFOV) or AttackAim.FOV
    AttackAim.Strength = tonumber(VD.AimLockAttackStrength) or AttackAim.Strength
    AttackAim.Predict = VD.AimLockAttackPredict ~= false
    AttackAim.PredictStrength = tonumber(VD.AimLockAttackPredictStrength) or AttackAim.PredictStrength
    AttackAim.VisibilityCheck = VD.AimLockAttackVisibility ~= false
    AttackAim.AimPart = tostring(VD.AimLockAttackPart or AttackAim.AimPart)

    local AttackPaths = {
        "Slasher-mob.Controls.attack",
        "Masked-mob.Controls.attack",
        "Killer-mob.Controls.attack",
    }

    local function AttackAimVisible(part)
        local cam = Workspace.CurrentCamera
        if not cam or not part or not part.Parent then return false end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.IgnoreWater = true
        params.FilterDescendantsInstances = { Player.Character }
        local origin = cam.CFrame.Position
        local direction = part.Position - origin
        local hit = Workspace:Raycast(origin, direction, params)
        if not hit then return true end
        -- A valid target is visible when the ray reaches any descendant of it.
        return hit.Instance and part.Parent and hit.Instance:IsDescendantOf(part.Parent) or false
    end

    local function AttackGetButton()
        local pGui = Player:FindFirstChildOfClass("PlayerGui")
        if not pGui then return nil end
        for _, path in ipairs(AttackPaths) do
            local cur = pGui
            for seg in string.gmatch(path, "[^%.]+") do
                cur = cur and cur:FindFirstChild(seg)
            end
            if cur and cur:IsA("GuiButton") then return cur end
        end
        return nil
    end

    local function AttackGetClosestTarget()
        local cam = Workspace.CurrentCamera
        if not cam then return nil end
        local center = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5)
        local closest, shortest = nil, tonumber(AttackAim.FOV) or 250
        for _, p in ipairs(MawwwGetPlayers()) do
            if p ~= Player and IsSurvivor(p) and p.Character then
                local part = p.Character:FindFirstChild(AttackAim.AimPart) or p.Character:FindFirstChild("HumanoidRootPart")
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if part and hum and hum.Health > 0 then
                    local pos, onScreen = cam:WorldToViewportPoint(part.Position)
                    if onScreen and pos.Z > 0 then
                        local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                        if dist < shortest and (not AttackAim.VisibilityCheck or AttackAimVisible(part)) then
                            shortest = dist
                            closest = part
                        end
                    end
                end
            end
        end
        return closest
    end

    local function AttackDisconnect()
        if AttackAim.Connection then
            pcall(function() AttackAim.Connection:Disconnect() end)
            AttackAim.Connection = nil
        end
    end

    function K4.AttackAim_Start()
        if AttackAim.Connection then return end
        AttackAim.Connection = RunService.RenderStepped:Connect(function()
            if not AttackAim.Enabled or not AttackAim.Holding then return end
            local target = AttackGetClosestTarget()
            local cam = Workspace.CurrentCamera
            if not target or not cam then return end
            local pos = target.Position
            if AttackAim.Predict then
                pos = pos + (target.AssemblyLinearVelocity * (tonumber(AttackAim.PredictStrength) or 0.12))
            end
            local targetCF = CFrame.new(cam.CFrame.Position, pos)
            local strength = math.clamp(tonumber(AttackAim.Strength) or 1, 0.05, 1)
            cam.CFrame = cam.CFrame:Lerp(targetCF, strength)
        end)
    end

    function K4.SetAimLockAttack(v)
        AttackAim.Enabled = v == true
        VD.AimLockAttack = AttackAim.Enabled
        if not AttackAim.Enabled then
            AttackAim.Holding = false
            AttackDisconnect()
        else
            K4.AttackAim_Start()
        end
    end

    getgenv().AttackAim_Cfg = AttackAim
    getgenv().AttackAim_Start = K4.AttackAim_Start

    local attackInputBegan = UserInputService.InputBegan:Connect(function(input, gp)
        if gp or not AttackAim.Enabled then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then AttackAim.Holding = true end
    end)
    local attackInputEnded = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then AttackAim.Holding = false end
    end)
    K4.AimLockAttackInputBegan = attackInputBegan
    K4.AimLockAttackInputEnded = attackInputEnded

    local function HookAttackButton(btn)
        if not btn or not btn:IsA("GuiButton") then return end
        if btn == AttackAim.CurrentButton then return end
        AttackAim.CurrentButton = btn
        if AttackAim.MobileConnection then
            pcall(function() AttackAim.MobileConnection:Disconnect() end)
            AttackAim.MobileConnection = nil
        end
        local c1 = btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch and AttackAim.Enabled then
                AttackAim.Holding = true
            end
        end)
        local c2 = btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                AttackAim.Holding = false
            end
        end)
        local c3 = btn:GetPropertyChangedSignal("Visible"):Connect(function()
            if not btn.Visible then AttackAim.Holding = false end
        end)
        AttackAim.MobileConnection = {
            Disconnect = function()
                pcall(function() c1:Disconnect() end)
                pcall(function() c2:Disconnect() end)
                pcall(function() c3:Disconnect() end)
            end
        }
    end

    task.spawn(function()
        while not VD.Destroyed do
            task.wait(0.5)
            if UserInputService.TouchEnabled then
                local btn = AttackGetButton()
                if btn then HookAttackButton(btn) end
            end
        end
    end)

    Player.CharacterAdded:Connect(function()
        AttackAim.Holding = false
        AttackAim.CurrentButton = nil
        if AttackAim.MobileConnection then
            pcall(function() AttackAim.MobileConnection:Disconnect() end)
            AttackAim.MobileConnection = nil
        end
    end)

    --========================================================--
    -- DESTROY PALLET (SOURCE IMPLEMENTATION)
    --========================================================--
    getgenv().MAWWW_IsBreakingPallet = false
    function K4.DestroyNearestPallet()
        if not VD.KillerDestroyPallets or GetRole() ~= "Killer" then return false end
        if getgenv().MAWWW_IsBreakingPallet then return false end
        local char = Player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not char or not root then return false end

        local stunned = char:GetAttribute("IsStunned") or char:GetAttribute("isStunned")
        local immobile = char:GetAttribute("Immobile") or char:GetAttribute("immobile")
        local carrying = char:GetAttribute("IsCarrying") or char:GetAttribute("isCarrying")
        local ci = char:FindFirstChild("CheckInterractable")
        local action = ci and (ci:GetAttribute("action") or ci:GetAttribute("Action"))
        if stunned or immobile or carrying or action then return false end

        local nearest, minDist = nil, 6
        for _, p in ipairs(CollectionService:GetTagged("PalletPointSlide")) do
            if p:IsA("BasePart") and not CollectionService:HasTag(p, "doing action") then
                local d = (p.Position - root.Position).Magnitude
                if d < minDist then
                    minDist, nearest = d, p
                end
            end
        end
        if not nearest then return false end

        getgenv().MAWWW_IsBreakingPallet = true
        task.spawn(function()
            pcall(function()
                local r = ReplicatedStorage:FindFirstChild("Remotes")
                local pallet = r and r:FindFirstChild("Pallet")
                local jason = pallet and pallet:FindFirstChild("Jason")
                local dg = jason and jason:FindFirstChild("Destroy-Global")
                local commit = jason and jason:FindFirstChild("PalletBreakCommit")
                if dg and dg:IsA("RemoteEvent") then dg:FireServer(nearest) end
                if commit and commit:IsA("RemoteEvent") then commit:FireServer(nearest) end
            end)
            task.wait(0.2)
            local start = os.clock()
            while char and char.Parent and (char:GetAttribute("Immobile") or char:GetAttribute("immobile")) do
                if os.clock() - start > 3 then break end
                task.wait(0.1)
            end
            getgenv().MAWWW_IsBreakingPallet = false
        end)
        return true
    end

    getgenv().MAWWW_DestroyAllPallets = K4.DestroyNearestPallet

    task.spawn(function()
        while not VD.Destroyed do
            task.wait(0.1)
            pcall(K4.DestroyNearestPallet)
        end
    end)

    --========================================================--
    -- UNLOCK SKILL WHILE CARRYING (SOURCE IMPLEMENTATION)
    --========================================================--
    K4.UnlockSkillWhileCarrying = K4.UnlockSkillWhileCarrying or { Enabled = false, Hooked = false, OldNamecall = nil }
    local CarryCfg = K4.UnlockSkillWhileCarrying
    CarryCfg.Enabled = VD.UnlockSkillWhileCarrying == true

    local function SetupCarryHook()
        if CarryCfg.Hooked then return true end
        if type(getrawmetatable) ~= "function" or type(getnamecallmethod) ~= "function" or type(checkcaller) ~= "function" then
            warn("[MawwwHub] Unlock Skill: executor metatable helpers unavailable")
            return false
        end
        local ok = pcall(function()
            local mt = getrawmetatable(game)
            if not mt then error("game metatable unavailable") end
            if type(setreadonly) == "function" then setreadonly(mt, false) end
            local oldNamecall = mt.__namecall
            if type(oldNamecall) ~= "function" then
                if type(setreadonly) == "function" then setreadonly(mt, true) end
                error("__namecall unavailable")
            end
            local wrapper = function(self, ...)
                local method = getnamecallmethod()
                local args = { ... }
                if CarryCfg.Enabled and method == "GetAttribute" and not checkcaller() and args[1] == "IsCarrying" then
                    return false
                end
                return oldNamecall(self, table.unpack(args))
            end
            mt.__namecall = type(newcclosure) == "function" and newcclosure(wrapper) or wrapper
            if type(setreadonly) == "function" then setreadonly(mt, true) end
            CarryCfg.OldNamecall = oldNamecall
            CarryCfg.Hooked = true
        end)
        if not ok then
            CarryCfg.Hooked = false
            CarryCfg.OldNamecall = nil
        end
        return CarryCfg.Hooked
    end

    function K4.SetUnlockSkillWhileCarrying(v)
        CarryCfg.Enabled = v == true
        VD.UnlockSkillWhileCarrying = CarryCfg.Enabled
        if CarryCfg.Enabled and not CarryCfg.Hooked then SetupCarryHook() end
    end
    if CarryCfg.Enabled then SetupCarryHook() end

    --========================================================--
    -- BYPASS SELF UNHOOK (SOURCE IMPLEMENTATION)
    --========================================================--
    K4.SelfUnhook = K4.SelfUnhook or {
        Enabled = false,
        Following = false,
        FollowDuration = 30,
        FollowDistance = 20,
        MonitorConn = nil,
        TriggerCount = 0,
        LastTrigger = 0,
        Cooldown = 3,
        HookPos = nil,
        HookCFrame = nil,
        ActiveThread = nil,
        WasHooked = false,
    }
    local SU = K4.SelfUnhook
    SU.Enabled = VD.BypassSelfUnhook == true
    SU.FollowDuration = math.clamp(tonumber(VD.SelfUnhookFollowDuration) or 30, 5, 120)
    SU.FollowDistance = math.clamp(tonumber(VD.SelfUnhookFollowDistance) or 20, 5, 60)
    getgenv().MawwwSelfUnhook = SU

    local function SU_IsHooked()
        local char = Player.Character
        if not char then return false end
        return char:GetAttribute("IsHooked") == true
            or char:GetAttribute("isHooked") == true
            or char:GetAttribute("Hooked") == true
            or char:GetAttribute("HookedState") == true
    end
    K4.SU_IsHooked = SU_IsHooked

    local function SU_GetKillerHRP()
        for _, p in ipairs(MawwwGetPlayers()) do
            if p ~= Player and IsKiller(p) and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then return hrp end
            end
        end
        return nil
    end

    local function SU_GetRandomGeneratorPoint()
        local valid = {}
        local host = getgenv().MAWWW
        if type(host) == "table" and type(host.GB_GetAllGenerators) == "function" and type(host.GB_GetPoints) == "function" then
            local ok, gens = pcall(host.GB_GetAllGenerators)
            if ok and type(gens) == "table" then
                for _, g in ipairs(gens) do
                    if g and g.Parent then
                        local okPts, points = pcall(host.GB_GetPoints, g)
                        if okPts and type(points) == "table" then
                            for _, point in ipairs(points) do
                                if point and point.Parent then table.insert(valid, point) end
                            end
                        end
                    end
                end
            end
        end
        -- Fallback keeps the imported feature usable even before the main Gen Boost helper is initialized.
        if #valid == 0 then
            local map = Workspace:FindFirstChild("Map")
            if map then
                for _, g in ipairs(map:GetDescendants()) do
                    if g:IsA("Model") and g.Name == "Generator" then
                        for _, point in ipairs(g:GetChildren()) do
                            if point:IsA("BasePart") and string.find(point.Name, "GeneratorPoint", 1, true) then
                                table.insert(valid, point)
                            end
                        end
                    end
                end
            end
        end
        if #valid == 0 then return nil end
        return valid[math.random(1, #valid)]
    end

    local function SU_Abort()
        SU.Following = false
        if SU.ActiveThread then
            pcall(function() task.cancel(SU.ActiveThread) end)
        end
        SU.ActiveThread = nil
    end

    local function SU_Trigger()
        if SU.Following then return end
        local now = os.clock()
        if now - SU.LastTrigger < (SU.Cooldown or 3) then return end
        if not SU_IsHooked() then return end
        SU.LastTrigger = now
        SU.Following = true
        SU.TriggerCount = (SU.TriggerCount or 0) + 1

        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            SU.HookPos = hrp.Position
            SU.HookCFrame = hrp.CFrame
        end

        SU.ActiveThread = task.spawn(function()
            local currentChar = Player.Character
            local currentRoot = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
            if not currentChar or not currentRoot then
                SU.Following = false
                SU.ActiveThread = nil
                return
            end

            local host = getgenv().MAWWW
            local re
            pcall(function()
                re = ReplicatedStorage:FindFirstChild("Remotes")
                    and ReplicatedStorage.Remotes:FindFirstChild("Generator")
                    and ReplicatedStorage.Remotes.Generator:FindFirstChild("RepairEvent")
            end)

            if not SU_IsHooked() then
                SU.Following = false
                SU.ActiveThread = nil
                return
            end

            local tp = SU_GetRandomGeneratorPoint()
            if tp then
                pcall(function()
                    currentRoot.AssemblyLinearVelocity = Vector3.zero
                    currentRoot.CFrame = tp.CFrame + Vector3.new(0, 3, 0)
                end)
                task.wait(0.15)
                if re and re:IsA("RemoteEvent") then
                    pcall(function() re:FireServer(tp, true) end)
                    task.wait(0.35)
                    pcall(function() re:FireServer(tp, false) end)
                    task.wait(0.15)
                    pcall(function() re:FireServer(tp, true) end)
                    task.wait(0.35)
                    pcall(function() re:FireServer(tp, false) end)
                end
            end

            local followUntil = os.clock() + (tonumber(SU.FollowDuration) or 30)
            local backOffset = tonumber(SU.FollowDistance) or 20
            while os.clock() < followUntil and SU.Enabled and not VD.Destroyed do
                if not SU_IsHooked() then
                    SU.Following = false
                    SU.ActiveThread = nil
                    pcall(function() notify("Bypass Self Unhook", "Hook status ended — stopped.", 2) end)
                    return
                end
                local c = Player.Character
                local r = c and c:FindFirstChild("HumanoidRootPart")
                if not c or not r then break end
                local killerRoot = SU_GetKillerHRP()
                if killerRoot then
                    pcall(function()
                        r.AssemblyLinearVelocity = Vector3.zero
                        local tPos = Vector3.new(killerRoot.Position.X, killerRoot.Position.Y - backOffset, killerRoot.Position.Z)
                        r.CFrame = CFrame.new(tPos, tPos + Vector3.new(0, 0, -1))
                    end)
                end
                task.wait(0.03)
            end

            if SU_IsHooked() then
                local c2 = Player.Character
                local r2 = c2 and c2:FindFirstChild("HumanoidRootPart")
                if r2 then
                    if SU.HookCFrame then
                        pcall(function()
                            r2.AssemblyLinearVelocity = Vector3.zero
                            r2.CFrame = SU.HookCFrame
                        end)
                    elseif SU.HookPos then
                        pcall(function()
                            r2.AssemblyLinearVelocity = Vector3.zero
                            r2.CFrame = CFrame.new(SU.HookPos + Vector3.new(0, 3, 0))
                        end)
                    end
                end
            end
            SU.Following = false
            SU.ActiveThread = nil
        end)
    end

    local function SU_Start()
        if SU.MonitorConn then return end
        SU.WasHooked = false
        SU.MonitorConn = RunService.Heartbeat:Connect(function()
            if not SU.Enabled or GetRole() ~= "Survivor" then return end
            if not Player.Character then return end
            local hooked = SU_IsHooked()
            if not hooked then
                SU.WasHooked = false
                return
            end
            if not SU.WasHooked and not SU.Following then
                SU.WasHooked = true
                SU_Trigger()
            end
        end)
    end

    local function SU_Stop()
        if SU.MonitorConn then
            pcall(function() SU.MonitorConn:Disconnect() end)
            SU.MonitorConn = nil
        end
        SU_Abort()
        SU.WasHooked = false
    end

    function K4.SetSelfUnhook(v)
        SU.Enabled = v == true
        VD.BypassSelfUnhook = SU.Enabled
        SU.FollowDuration = math.clamp(tonumber(VD.SelfUnhookFollowDuration) or SU.FollowDuration or 30, 5, 120)
        SU.FollowDistance = math.clamp(tonumber(VD.SelfUnhookFollowDistance) or SU.FollowDistance or 20, 5, 60)
        if SU.Enabled then SU_Start() else SU_Stop() end
    end

    function K4.SetSelfUnhookFollowDuration(v)
        SU.FollowDuration = math.clamp(tonumber(v) or 30, 5, 120)
        VD.SelfUnhookFollowDuration = SU.FollowDuration
    end

    function K4.SetSelfUnhookFollowDistance(v)
        SU.FollowDistance = math.clamp(tonumber(v) or 20, 5, 60)
        VD.SelfUnhookFollowDistance = SU.FollowDistance
    end

    Player.CharacterAdded:Connect(function()
        SU.WasHooked = false
        SU.Following = false
        AttackAim.Holding = false
        HiddenSetHolding(false)
    end)

    -- Respect any values already present in VD, while keeping the UI controls optional.
    if Hidden.Enabled then HiddenStart() end
    if AttackAim.Enabled then K4.AttackAim_Start() end
    if SU.Enabled then SU_Start() end
end

-- KILLER TAB
--========================================================--
RegLabel(Tabs.Killer, "Killer Basics")
RegToggle(Tabs.Killer, "Auto Attack", "Auto attack nearby survivors", false, "KillerAutoAttack")
RegSlider(Tabs.Killer, "Attack Range", "Attack distance", 12, 5, 20, 1, "KillerAttackRange")
RegToggle(Tabs.Killer, "Auto Attack Spam", "Spam attack continuously", false, "KillerAutoSpam")
RegSlider(Tabs.Killer, "Attack Delay", "Delay between attacks", 0.45, 0.1, 1, 0.05, "KillerAttackDelay")
RegToggle(Tabs.Killer, "Auto Stalk", "Auto stalk nearest survivor", false, "KillerAutoStalk")
RegToggle(Tabs.Killer, "Auto Kill Survivors", "Auto kill all survivors", false, "KillerKillAll")
RegToggle(Tabs.Killer, "Hitbox Expand", "Expand hitbox for easier hits", false, "KillerHitbox")
RegSlider(Tabs.Killer, "Hitbox Size", "Hitbox size", 15, 5, 40, 1, "KillerHitboxSize")

task.spawn(function()
    while not VD.Destroyed do
        task.wait(VD.KillerAttackDelay)
        if VD.KillerAutoAttack and GetRole() == "Killer" then
            local root = getRoot()
            if root then
                for _, p in ipairs(MawwwGetPlayers()) do
                    if p ~= Player and IsSurvivor(p) and p.Character then
                        local tRoot = p.Character:FindFirstChild("HumanoidRootPart")
                        local tHum = p.Character:FindFirstChildOfClass("Humanoid")
                        if tRoot and tHum and tHum.Health > 0 and (tRoot.Position - root.Position).Magnitude <= VD.KillerAttackRange then
                            pcall(function()
                                local r = GetRemotes()
                                local a = r and r:FindFirstChild("Attacks")
                                local b = a and a:FindFirstChild("BasicAttack")
                                if b then b:FireServer(false) end
                            end)
                            break
                        end
                    end
                end
            end
        end
    end
end)
task.spawn(function()
    while not VD.Destroyed do
        task.wait(VD.KillerAttackDelay)
        if VD.KillerAutoSpam and GetRole() == "Killer" then
            pcall(function()
                local r = GetRemotes()
                local a = r and r:FindFirstChild("Attacks")
                local b = a and a:FindFirstChild("BasicAttack")
                if b then b:FireServer(false) end
            end)
        end
    end
end)
task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.5)
        if VD.KillerAutoStalk and GetRole() == "Killer" then
            local root = getRoot()
            if root then
                local closest, closestDist = nil, 150
                for _, p in ipairs(MawwwGetPlayers()) do
                    if p ~= Player and IsSurvivor(p) and p.Character then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and hum.Health > 30 then
                            local d = (hrp.Position - root.Position).Magnitude
                            if d < closestDist then closestDist = d; closest = p end
                        end
                    end
                end
                if closest then
                    pcall(function()
                        local r = GetRemotes()
                        local k = r and r:FindFirstChild("Killers")
                        local st = k and k:FindFirstChild("Stalker")
                        local ev = st and st:FindFirstChild("StartStalking")
                        if ev then ev:FireServer(closest) end
                    end)
                end
            end
        end
    end
end)
task.spawn(function()
    local KillerTarget = nil
    while not VD.Destroyed do
        task.wait(0.1)
        if VD.KillerKillAll and GetRole() == "Killer" then
            local root = getRoot()
            if root then
                if not KillerTarget or not KillerTarget:FindFirstChild("Humanoid") or KillerTarget.Humanoid.Health <= 35 then
                    local closest, shortest = nil, math.huge
                    for _, plr in ipairs(MawwwGetPlayers()) do
                        if plr ~= Player and IsSurvivor(plr) and plr.Character then
                            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                            if hum and hrp and hum.Health > 30 then
                                local d = (hrp.Position - root.Position).Magnitude
                                if d < shortest then shortest = d; closest = plr.Character end
                            end
                        end
                    end
                    KillerTarget = closest
                end
                if KillerTarget then
                    local targetHRP = KillerTarget:FindFirstChild("HumanoidRootPart")
                    if targetHRP then
                        local targetPos = targetHRP.Position + (targetHRP.AssemblyLinearVelocity * 0.15)
                        local behind = targetHRP.CFrame.LookVector * -3
                        root.CFrame = CFrame.new(targetPos + behind, targetPos)
                    end
                    pcall(function()
                        local r = GetRemotes()
                        local a = r and r:FindFirstChild("Attacks")
                        local b = a and a:FindFirstChild("BasicAttack")
                        if b then b:FireServer(false) end
                    end)
                end
            end
        end
    end
end)
OriginalHitboxSizes = {}
task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.2)
        if VD.KillerHitbox and GetRole() == "Killer" then
            for _, p in ipairs(MawwwGetPlayers()) do
                if p ~= Player and IsSurvivor(p) and p.Character then
                    local root = p.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        if not OriginalHitboxSizes[p] then OriginalHitboxSizes[p] = root.Size end
                        local sz = VD.KillerHitboxSize
                        root.Size = Vector3.new(sz, sz, sz); root.CanCollide = false; root.Transparency = 0.7
                    end
                elseif OriginalHitboxSizes[p] then
                    local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                    if root then root.Size = OriginalHitboxSizes[p]; root.Transparency = 1; root.CanCollide = true end
                    OriginalHitboxSizes[p] = nil
                end
            end
        else
            for p, orig in pairs(OriginalHitboxSizes) do
                local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if root then root.Size = orig; root.Transparency = 1; root.CanCollide = true end
            end
            OriginalHitboxSizes = {}
        end
    end
end)

RegDivider(Tabs.KillerAbilities)
RegLabel(Tabs.KillerAbilities, "Killer / Abilities")
RegToggle(Tabs.KillerAbilities, "Infinite Lunge", "Unlimited lunge boost", false, "KillerInfLunge")
RegToggle(Tabs.KillerAbilities, "Infinite Frenzy — Jeff", "Unlimited frenzy", false, "KillerInfFrenzy")
RegToggle(Tabs.KillerAbilities, "Infinite Lake Mist — Jason", "Unlimited lake mist", false, "KillerInfLakeMist")
RegToggle(Tabs.KillerAbilities, "Infinite Pursuit — Jason", "Unlimited pursuit", false, "KillerInfPursuit")
RegToggle(Tabs.KillerAbilities, "Infinite Grab — Myers", "Unlimited grab", false, "KillerInfGrab")
RegToggle(Tabs.KillerAbilities, "Show Infinite Myers Icon", "Show quick toggle icon", false, "ShowInfiniteMyersIcon", function(v)
    if getgenv().MAWWW_QuickRefresh then pcall(getgenv().MAWWW_QuickRefresh) end
end)
RegToggle(Tabs.KillerAbilities, "Lock Infinite Myers Icon", "Lock icon position", false, "LockInfiniteMyersIcon", function(v)
    if getgenv().MAWWW_QuickRefresh then pcall(getgenv().MAWWW_QuickRefresh) end
end)
RegToggle(Tabs.KillerAbilities, "Infinite Abyssal Burst", "Unlimited abyssal burst", false, "KillerInfAbyss")
RegToggle(Tabs.KillerAbilities, "Infinite Hidden Skill", "Unlimited hidden skill", false, "KillerInfSkill")
RegDivider(Tabs.KillerBypass)
RegLabel(Tabs.KillerBypass, "Cooldown / Bypass")
RegToggle(Tabs.KillerBypass, "Bypass All Cooldowns", "Bypass all killer cooldown attributes", false, "KillerBypassCD", function(v)
    VD.KillerBypassCD = v and true or false
    if v then notify("Cooldown / Bypass", "Enabled", 2) else notify("Cooldown / Bypass", "Disabled", 2) end
end)
--========================================================--
-- VD SOURCE ADDITION: CUSTOM MASKED
-- Added only because this feature/remote was absent from the
-- cleaned main hub.
-- Remote: ReplicatedStorage.Remotes.Killers.Masked.Activatepower
--========================================================--
MAWWW_CustomMaskedOptions = {
    "Richard", "Tony", "Brandon", "Jake", "Richter", "Graham", "Alex"
}

function MAWWW_ApplyCustomMasked(maskName)
    local selectedMask = maskName or VD.KillerCustomMasked or "Richard"
    if type(selectedMask) == "table" then
        selectedMask = selectedMask[1]
    end
    if type(selectedMask) ~= "string" or selectedMask == "" then
        selectedMask = "Richard"
    end

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local killers = remotes and remotes:FindFirstChild("Killers")
    local masked = killers and killers:FindFirstChild("Masked")
    local activatePower = masked and masked:FindFirstChild("Activatepower")

    if activatePower and activatePower:IsA("RemoteEvent") then
        local ok = pcall(function()
            activatePower:FireServer(selectedMask)
        end)
        if ok then
            VD.KillerCustomMasked = selectedMask
            return true
        end
    end

    return false
end

getgenv().MAWWW_ApplyCustomMasked = MAWWW_ApplyCustomMasked

RegToggle(Tabs.KillerAbilities, "Flashlight Anti-Blind", "Ignore flashlight blind", false, "KillerAntiBlind")
RegDivider(Tabs.KillerAbilities)
RegLabel(Tabs.KillerAbilities, "Custom Masked")
RegDropdown(
    Tabs.KillerAbilities,
    "Custom Mask",
    "Pilih mask yang akan dikirim ke remote Masked/Activatepower.",
    MAWWW_CustomMaskedOptions,
    VD.KillerCustomMasked or "Richard",
    false,
    "KillerCustomMasked",
    function(v)
        if type(v) == "table" then
            v = v[1]
        end
        if type(v) == "string" and v ~= "" then
            VD.KillerCustomMasked = v
        end
    end
)
RegButton(
    Tabs.KillerAbilities,
    "Apply Custom Mask",
    "Kirim mask yang dipilih ke remote.",
    function()
        local success = MAWWW_ApplyCustomMasked(VD.KillerCustomMasked)
        if success then
            notify("Custom Masked", "Remote apply berhasil dikirim.", 2)
        else
            notify("Custom Masked", "Remote Activatepower tidak ditemukan.", 3)
        end
    end
)
RegButton(
    Tabs.KillerAbilities,
    "Random Custom Mask",
    "Pilih dan kirim mask secara acak.",
    function()
        local mask = MAWWW_CustomMaskedOptions[math.random(1, #MAWWW_CustomMaskedOptions)]
        VD.KillerCustomMasked = mask
        local success = MAWWW_ApplyCustomMasked(mask)
        if success then
            notify("Custom Masked", "Applied: " .. mask, 2)
        else
            notify("Custom Masked", "Remote Activatepower tidak ditemukan.", 3)
        end
    end
)


-- ========================================================
-- [NEW] Bypass Skill quick toggle icons
-- ========================================================
RegToggle(Tabs.KillerAbilities, "Show Bypass Skill Icon", "Show Bypass Skill quick toggle icon", false, "ShowBypassSkillIcon", function(v)
    if getgenv().MAWWW_QuickRefresh then pcall(getgenv().MAWWW_QuickRefresh) end
end)
RegToggle(Tabs.KillerAbilities, "Lock Bypass Skill Icon", "Lock Bypass Skill icon position", false, "LockBypassSkillIcon", function(v)
    if getgenv().MAWWW_QuickRefresh then pcall(getgenv().MAWWW_QuickRefresh) end
end)

task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.5)
        local char = Player.Character
        if char then
            if VD.KillerInfLunge then pcall(function() char:SetAttribute("lungeboost", 999999) end)
            else pcall(function() if char:GetAttribute("lungeboost") == 999999 then char:SetAttribute("lungeboost", 1) end end) end
        end
    end
end)
task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.2)
        if VD.KillerInfFrenzy and GetRole() == "Killer" then
            local char = Player.Character
            if char and char:GetAttribute("Frenzy") ~= true then pcall(function() char:SetAttribute("Frenzy", true) end) end
        end
    end
end)
task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.35)
        if VD.KillerInfLakeMist and GetRole() == "Killer" then
            local char = Player.Character
            if char then
                pcall(function()
                    for _, attr in ipairs({"LakeMistCharges", "LakeMistUses", "MistCharges"}) do
                        local v = char:GetAttribute(attr)
                        if v ~= nil and type(v) == "number" and v < 999 then char:SetAttribute(attr, 999) end
                    end
                    for _, attr in ipairs({"LakeMistCooldown", "MistCooldown", "LakeMistCD"}) do
                        local v = char:GetAttribute(attr)
                        if v ~= nil and type(v) == "number" and v > 0 then char:SetAttribute(attr, 0) end
                    end
                    local remotes = GetRemotes()
                    local killers = remotes and remotes:FindFirstChild("Killers")
                    local jason = killers and (killers:FindFirstChild("Jason") or killers:FindFirstChild("LakeMist"))
                    if jason then
                        local cancel = jason:FindFirstChild("CancelLakeMist") or jason:FindFirstChild("RefreshLakeMist")
                        if cancel and cancel:IsA("RemoteEvent") then pcall(function() cancel:FireServer() end) end
                    end
                end)
            end
        end
    end
end)
task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.35)
        if VD.KillerInfPursuit and GetRole() == "Killer" then
            local char = Player.Character
            if char then
                pcall(function()
                    for _, attr in ipairs({"PursuitCharges", "PursuitUses", "PursuitActive", "PursuitCD"}) do
                        local v = char:GetAttribute(attr)
                        if v ~= nil then
                            if type(v) == "number" and v > 0 then char:SetAttribute(attr, 0)
                            elseif type(v) == "boolean" and v == false then char:SetAttribute(attr, true) end
                        end
                    end
                    for _, attr in ipairs({"PursuitCooldown", "PursuitCD"}) do
                        local v = char:GetAttribute(attr)
                        if v ~= nil and type(v) == "number" and v > 0 then char:SetAttribute(attr, 0) end
                    end
                end)
            end
        end
    end
end)
task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.35)
        if VD.KillerInfGrab and GetRole() == "Killer" then
            local char = Player.Character
            if char then
                pcall(function()
                    for _, attr in ipairs({"GrabCharges", "GrabUses", "GrabTier", "GrabLevel"}) do
                        local v = char:GetAttribute(attr)
                        if v ~= nil and type(v) == "number" and v < 3 then char:SetAttribute(attr, 3) end
                    end
                    for _, attr in ipairs({"GrabCooldown", "GrabCD"}) do
                        local v = char:GetAttribute(attr)
                        if v ~= nil and type(v) == "number" and v > 0 then char:SetAttribute(attr, 0) end
                    end
                    local remotes = GetRemotes()
                    local killers = remotes and remotes:FindFirstChild("Killers")
                    local myers = killers and (killers:FindFirstChild("Myers") or killers:FindFirstChild("Michael"))
                    if myers then
                        local tier = myers:FindFirstChild("SetTier") or myers:FindFirstChild("Upgrade")
                        if tier and tier:IsA("RemoteEvent") then pcall(function() tier:FireServer(3) end) end
                    end
                end)
            end
        end
    end
end)
task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.35)
        if VD.KillerInfAbyss and GetRole() == "Killer" then
            local char = Player.Character
            if char then
                pcall(function()
                    for _, attr in ipairs({"AbyssCharges", "AbyssalCharges", "BurstCharges", "AbyssalUses"}) do
                        local v = char:GetAttribute(attr)
                        if v ~= nil and type(v) == "number" and v < 999 then char:SetAttribute(attr, 999) end
                    end
                    for _, attr in ipairs({"AbyssCooldown", "AbyssalCooldown", "BurstCooldown"}) do
                        local v = char:GetAttribute(attr)
                        if v ~= nil and type(v) == "number" and v > 0 then char:SetAttribute(attr, 0) end
                    end
                end)
            end
        end
    end
end)
task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.5)
        if VD.KillerInfSkill and GetRole() == "Killer" then
            local char = Player.Character
            if char then
                pcall(function()
                    for _, attr in ipairs({"SkillCharges", "AbilityCharges", "SpecialCharges", "HiddenCharges"}) do
                        local v = char:GetAttribute(attr)
                        if v ~= nil and type(v) == "number" and v < 999 then char:SetAttribute(attr, 999) end
                    end
                    for _, attr in ipairs({"SkillCooldown", "AbilityCooldown", "SpecialCooldown", "HiddenCooldown"}) do
                        local v = char:GetAttribute(attr)
                        if v ~= nil and type(v) == "number" and v > 0 then char:SetAttribute(attr, 0) end
                    end
                end)
            end
        end
    end
end)
task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.25)
        if VD.KillerBypassCD and GetRole() == "Killer" then
            local char = Player.Character
            if char then
                pcall(function()
                    for _, attr in ipairs({"SkillCooldown","AbilityCooldown","SpecialCooldown","AttackCooldown","LungeCooldown","FrenzyCooldown","PursuitCooldown","LakeMistCooldown","GrabCooldown","AbyssCooldown","HookCooldown","StalkCooldown"}) do
                        local v = char:GetAttribute(attr)
                        if v ~= nil and type(v) == "number" and v > 0 then char:SetAttribute(attr, 0) end
                    end
                    for _, a in ipairs(char:GetAttributes()) do
                        if type(a) == "string" and a:lower():find("cooldown") then
                            local v = char:GetAttribute(a)
                            if type(v) == "number" and v > 0 then char:SetAttribute(a, 0) end
                        end
                    end
                end)
            end
        end
    end
end)
task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.1)
        if VD.KillerAntiBlind and GetRole() == "Killer" then
            pcall(function()
                local char = Player.Character
                if char then
                    char:SetAttribute("Blindness", 0); char:SetAttribute("Blind", false)
                    char:SetAttribute("IsBlinded", false); char:SetAttribute("FlashBlind", false)
                end
                local pg = Player:FindFirstChild("PlayerGui")
                if pg then
                    for _, gui in ipairs(pg:GetChildren()) do
                        if gui:IsA("ScreenGui") then
                            local ln = gui.Name:lower()
                            if ln:find("blind") or ln:find("flash") then gui.Enabled = false end
                        end
                    end
                end
                for _, v in ipairs(Lighting:GetChildren()) do
                    if v:IsA("ColorCorrectionEffect") and v.Brightness < -0.3 then v.Brightness = 0 end
                end
            end)
        end
    end
end)


RegDivider(Tabs.KillerRight)

getgenv().BYPASS_HiddenLeapBypassThread = nil
function BYPASS_StartHiddenCooldownBypass()
    if getgenv().BYPASS_HiddenLeapBypassThread then return end
    getgenv().BYPASS_HiddenLeapBypassThread = task.spawn(function()
        local leapFunction, m2Function
        local function scanGC()
            pcall(function()
                for _, v in pairs(getgc(true)) do
                    if type(v) == "function" and islclosure(v) then
                        local info
                        pcall(function() info = debug.getinfo(v) end)
                        if info then
                            if info.name == "tryActivate" then leapFunction = v
                            elseif info.name == "playM2Animation" then m2Function = v end
                        end
                    end
                    if leapFunction and m2Function then break end
                end
            end)
        end
        scanGC()
        local lastScan = os.clock()
        while task.wait(0.1) do
            if not (VD.KillerBypassSkill and VD.KillerInfSkill) then break end
            if not (leapFunction and m2Function) then
                local now = os.clock()
                if now - lastScan >= 2 then lastScan = now; scanGC() end
            end
            if leapFunction then
                pcall(function()
                    for i, val in pairs(debug.getupvalues(leapFunction)) do
                        if type(val) == "boolean" and val == true then debug.setupvalue(leapFunction, i, false) end
                    end
                end)
            end
            if m2Function then
                pcall(function()
                    for i, val in pairs(debug.getupvalues(m2Function)) do
                        if type(val) == "boolean" and val == true then debug.setupvalue(m2Function, i, false) end
                    end
                end)
            end
        end
        getgenv().BYPASS_HiddenLeapBypassThread = nil
    end)
end


-- =====================================================
-- INF GRAB (MYERS)
-- =====================================================
MyersGrabData = {
    Enabled = false,
    UI = nil,
    Button = nil,
    DragLocked = false,
    Dragging = false,
    DragStart = nil,
    DragStartPos = nil,
    HotkeyCode = Enum.KeyCode.H,
}

function getMyersTarget()
    local char = LocalPlayer.Character
    if not char then return nil end
    local myHRP = char:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end
    local candidates = {}
    for _, player in ipairs(MawwwGetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                table.insert(candidates, {
                    player = player,
                    dist   = (hrp.Position - myHRP.Position).Magnitude,
                    health = hum.Health
                })
            end
        end
    end
    table.sort(candidates, function(a, b) return a.dist < b.dist end)
    for _, c in ipairs(candidates) do
        return c.player
    end
    return nil
end

function doMyersGrab()
    if not MyersGrabData.Enabled then return end
    local target = getMyersTarget()
    if not target or not target.Character then return end
    pcall(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        ReplicatedStorage.Remotes.Killers.Stalker.grab:FireServer(target.Character)
    end)
end

function setupMyersGrabBtn()
    local oldUI = LocalPlayer.PlayerGui:FindFirstChild("MyersGrabUI")
    if oldUI then oldUI:Destroy() end

    MyersGrabData.UI = Instance.new("ScreenGui")
    MyersGrabData.UI.Name = "MyersGrabUI"
    MyersGrabData.UI.ResetOnSpawn = false
    MyersGrabData.UI.IgnoreGuiInset = true
    MyersGrabData.UI.Parent = LocalPlayer:WaitForChild("PlayerGui")

    MyersGrabData.Button = Instance.new("ImageButton")
    MyersGrabData.Button.Name = "MyersGrabButton"
    MyersGrabData.Button.Size = UDim2.new(0, 60, 0, 60)
    MyersGrabData.Button.Position = UDim2.new(0.7, 0, 0.75, 0)
    MyersGrabData.Button.AnchorPoint = Vector2.new(0.5, 0.5)
    MyersGrabData.Button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    MyersGrabData.Button.BackgroundTransparency = 0.15
    MyersGrabData.Button.AutoButtonColor = true
    MyersGrabData.Button.Visible = false
    MyersGrabData.Button.ZIndex = 10
    MyersGrabData.Button.Parent = MyersGrabData.UI
    Instance.new("UICorner", MyersGrabData.Button).CornerRadius = UDim.new(1, 0)

    local s = Instance.new("UIStroke", MyersGrabData.Button)
    s.Color = Color3.fromRGB(255, 255, 255)
    s.Thickness = 2; s.Transparency = 0.2

    local lbl = Instance.new("TextLabel", MyersGrabData.Button)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "GRAB"
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBlack
    lbl.ZIndex = 11

    local function applyShine(obj, baseColor)
        local grad = Instance.new("UIGradient", obj)
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, baseColor),
            ColorSequenceKeypoint.new(0.4, baseColor),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.6, baseColor),
            ColorSequenceKeypoint.new(1, baseColor)
        })
        grad.Rotation = 45
        grad.Offset = Vector2.new(-1, -1)

        task.spawn(function()
            local TweenService = game:GetService("TweenService")
            local ti = TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
            local tw = TweenService:Create(grad, ti, { Offset = Vector2.new(1, 1) })
            tw:Play()
        end)
    end

    applyShine(MyersGrabData.Button, Color3.fromRGB(45, 45, 45))
    applyShine(lbl, Color3.fromRGB(204, 204, 204))
    applyShine(s, Color3.fromRGB(204, 204, 204))

    MyersGrabData.Button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if MyersGrabData.DragLocked then return end
            MyersGrabData.Dragging = true
            MyersGrabData.DragStart = input.Position
            MyersGrabData.DragStartPos = MyersGrabData.Button.Position
        end
    end)

    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if MyersGrabData.Dragging and not MyersGrabData.DragLocked and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - MyersGrabData.DragStart
            MyersGrabData.Button.Position = UDim2.new(
                MyersGrabData.DragStartPos.X.Scale, MyersGrabData.DragStartPos.X.Offset + delta.X,
                MyersGrabData.DragStartPos.Y.Scale, MyersGrabData.DragStartPos.Y.Offset + delta.Y
            )
        end
    end)

    MyersGrabData.Button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            MyersGrabData.Dragging = false
        end
    end)

    MyersGrabData.Button.MouseButton1Click:Connect(doMyersGrab)
end

pcall(setupMyersGrabBtn)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    pcall(setupMyersGrabBtn)
    if MyersGrabData.Button then
        MyersGrabData.Button.Visible = MyersGrabData.Enabled
    end
end)

game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == MyersGrabData.HotkeyCode and MyersGrabData.Enabled then
        doMyersGrab()
    end
end)

function setMyersGrab(v)
    MyersGrabData.Enabled = v
    if MyersGrabData.Button then
        MyersGrabData.Button.Visible = v
    end
end

function setMyersDragLocked(v)
    MyersGrabData.DragLocked = v
end

-- Bypass Slasher


getgenv().MAWWW_SlasherCooldownBypassThread = nil

function MAWWW_StartSlasherCooldownBypass()
    if getgenv().MAWWW_SlasherCooldownBypassThread then return end

    -- BOOLEAN ARITHMETIC FAILSAFE FOR AWARDLOG
    pcall(function()
        local b = true
        local mt = debug.getmetatable(b)
        if not mt then
            mt = {}
            debug.setmetatable(b, mt)
        end
        if setreadonly then setreadonly(mt, false) end
        mt.__div = function() return 0 end
        mt.__mul = function() return 0 end
        mt.__add = function() return 0 end
        mt.__sub = function() return 0 end
        if setreadonly then setreadonly(mt, true) end
    end)

    getgenv().MAWWW_SlasherCooldownBypassThread = task.spawn(function()
        local toggleFunc = nil
        local pursuitHandler = nil

        local function scanGCForSlasher()
            pcall(function()
                for _, v in pairs(getgc(true)) do
                    if type(v) == "function" and islclosure(v) then
                        local consts = debug.getconstants(v)
                        local hasOffset, hasLinear, hasAction, hasTweenInfo = false, false, false, false
                        local hasPursuit, hasWalkSpeed = false, false

                        for _, c in pairs(consts) do
                            if c == "Offset" then hasOffset = true end
                            if c == "Linear" then hasLinear = true end
                            if c == "action" then hasAction = true end
                            if c == "TweenInfo" then hasTweenInfo = true end
                            if c == "Pursuit" then hasPursuit = true end
                            if c == "WalkSpeed" then hasWalkSpeed = true end
                        end

                        if hasOffset and hasLinear and hasAction and hasTweenInfo and not hasPursuit then
                            toggleFunc = v
                        end

                        if hasPursuit and hasTweenInfo and hasAction and hasWalkSpeed then
                            pursuitHandler = v
                        end
                    end
                    if toggleFunc and pursuitHandler then break end
                end
            end)
        end

        scanGCForSlasher()
        local lastScan = os.clock()
        local wasLakeMistActive = false
        local wasPursuitActive = false

        while task.wait(0.1) do
            if not VD.KillerInfLakeMist and not VD.KillerInfPursuit then
                break
            end

            if not (toggleFunc and pursuitHandler) then
                if os.clock() - lastScan >= 2 then
                    scanGCForSlasher()
                    lastScan = os.clock()
                end
            end

            if toggleFunc and VD.KillerInfLakeMist then
                pcall(function()
                    debug.setupvalue(toggleFunc, 6, false) -- v_u_13 (LakeMist cooldown)
                    debug.setupvalue(toggleFunc, 10, false) -- v_u_12 (Anti-spam)
                end)
            end

            if pursuitHandler and VD.KillerInfPursuit then
                pcall(function()
                    debug.setupvalue(pursuitHandler, 5, false) -- v_u_12 (Anti-spam)
                    debug.setupvalue(pursuitHandler, 6, false) -- v_u_14 (Pursuit cooldown)
                end)
            end
        end

        getgenv().MAWWW_SlasherCooldownBypassThread = nil
    end)
end

function MAWWW_StopSlasherCooldownBypass()
    -- Loop will exit automatically when both VD.KillerInfLakeMist and VD.KillerInfPursuit are false
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        local jason = rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild("Killers") and rs.Remotes.Killers:FindFirstChild("Jason")
        if jason then
            if not VD.KillerInfLakeMist then
                local lm = jason:FindFirstChild("LakeMist")
                if lm then lm:FireServer(false) end
            end
            if not VD.KillerInfPursuit then
                local ps = jason:FindFirstChild("Pursuit")
                if ps then ps:FireServer(false) end
            end
        end
    end)
end


-- =====================================================
-- BYPASS COOLDOWN (Abyss) (Killer)
-- =====================================================
getgenv().MAWWW_AbyssCooldownBypassConnection = nil
getgenv().MAWWW_CorruptHandlerFunc = nil

function MAWWW_StartAbyssCooldownBypass()
    if not getgenv().MAWWW_CorruptHandlerFunc then
        for _, v in pairs(getgc(true)) do
            if type(v) == "function" and islclosure(v) then
                local constants = debug.getconstants(v)
                if table.find(constants, "corrupt") and table.find(constants, "Immobile") then
                    getgenv().MAWWW_CorruptHandlerFunc = v
                    break
                end
            end
        end
    end

    if not getgenv().MAWWW_CorruptHandlerFunc then
        return
    end

    if getgenv().MAWWW_AbyssCooldownBypassConnection then
        getgenv().MAWWW_AbyssCooldownBypassConnection:Disconnect()
    end

    getgenv().MAWWW_AbyssCooldownBypassConnection = RunService.Heartbeat:Connect(function()
        if not VD.KillerInfAbyss then return end
        if getgenv().MAWWW_CorruptHandlerFunc then
            local upvalues = debug.getupvalues(getgenv().MAWWW_CorruptHandlerFunc)
            for idx, val in pairs(upvalues) do
                if type(val) == "boolean" then
                    if val == false then
                        debug.setupvalue(getgenv().MAWWW_CorruptHandlerFunc, idx, true)
                    end
                end
            end
        end
    end)
end

function MAWWW_StopAbyssCooldownBypass()
    if getgenv().MAWWW_AbyssCooldownBypassConnection then
        getgenv().MAWWW_AbyssCooldownBypassConnection:Disconnect()
        getgenv().MAWWW_AbyssCooldownBypassConnection = nil
    end
end

-- =====================================================
-- BYPASS COOLDOWN (Jeff / The Killer)
-- =====================================================
getgenv().MAWWW_JeffCooldownBypassThread = nil

function MAWWW_StartJeffCooldownBypass()
    if getgenv().MAWWW_JeffCooldownBypassThread then return end
    getgenv().MAWWW_JeffCooldownBypassThread = task.spawn(function()
        local rs = game:GetService("RunService")
        local player = game:GetService("Players").LocalPlayer

        while task.wait() do
            if not VD.KillerInfFrenzy then
                break
            end
            pcall(function()
                local char = player.Character
                if char and char:GetAttribute("Frenzy") ~= true then
                    char:SetAttribute("Frenzy", true)
                end
            end)
        end

        getgenv().MAWWW_JeffCooldownBypassThread = nil
    end)
end

function MAWWW_StopJeffCooldownBypass()
    pcall(function()
        local player = game:GetService("Players").LocalPlayer
        local char = player.Character
        if char and char:GetAttribute("Frenzy") == true then
            char:SetAttribute("Frenzy", false)

            -- Tell server we are deactivating so the real cooldown can start
            local killer = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes"):FindFirstChild("Killers"):FindFirstChild("Killer")
            if killer then
                local deact = killer:FindFirstChild("Deactivatefromclient")
                if deact then
                    deact:FireServer()
                end
            end
        end
    end)
end


-- Unified all-killer bypass switch. Each individual worker remains protected.
function SetAllKillerNoCooldown(enabled)
    enabled = enabled and true or false
    VD.KillerBypassSkill = enabled
    VD.KillerInfLunge = enabled
    VD.KillerInfFrenzy = enabled
    VD.KillerInfLakeMist = enabled
    VD.KillerInfPursuit = enabled
    VD.KillerInfGrab = enabled
    VD.KillerInfAbyss = enabled
    VD.KillerInfSkill = enabled

    if enabled then
        pcall(MAWWW_StartAbyssCooldownBypass)
        pcall(BYPASS_StartHiddenCooldownBypass)
        pcall(MAWWW_StartJeffCooldownBypass)
        pcall(MAWWW_StartSlasherCooldownBypass)
        pcall(setMyersGrab, true)
    else
        pcall(MAWWW_StopAbyssCooldownBypass)
        pcall(MAWWW_StopJeffCooldownBypass)
        pcall(MAWWW_StopSlasherCooldownBypass)
        pcall(setMyersGrab, false)
    end

    if getgenv().MAWWW_QuickRefresh then
        pcall(getgenv().MAWWW_QuickRefresh)
    end
end
getgenv().MAWWW_SetAllKillerNoCooldown = SetAllKillerNoCooldown

RegToggle(Tabs.KillerBypass, "All-Killer Skill Bypass", "Enable all killer bypasses", false, "KillerBypassSkill", function(v)
    pcall(SetAllKillerNoCooldown, v)
end)
RegToggle(Tabs.KillerBypass, "Leap Bypass", "Hidden leap cooldown bypass", false, "HiddenLeapBypass", function(v)
    VD.KillerInfSkill = v and true or false
    if v then
        pcall(BYPASS_StartHiddenCooldownBypass)
        notify("Bypass", "Hidden Leap: ON", 2)
    else
        notify("Bypass", "Hidden Leap: OFF", 2)
    end
end)
RegToggle(Tabs.KillerBypass, "Jason: Infinite Lake Mist", "Keep Jason Lake Mist available", false, "BypassLakeMist", function(v)
    VD.KillerInfLakeMist = v and true or false
    if v then pcall(MAWWW_StartSlasherCooldownBypass) elseif not VD.KillerInfPursuit then pcall(MAWWW_StopSlasherCooldownBypass) end
end)
RegToggle(Tabs.KillerBypass, "Jason: Infinite Pursuit", "Keep Jason Pursuit available", false, "BypassPursuit", function(v)
    VD.KillerInfPursuit = v and true or false
    if v then pcall(MAWWW_StartSlasherCooldownBypass) elseif not VD.KillerInfLakeMist then pcall(MAWWW_StopSlasherCooldownBypass) end
end)
RegToggle(Tabs.KillerBypass, "Jeff: Infinite Frenzy", "Keep Jeff Frenzy available", false, "BypassFrenzy", function(v)
    VD.KillerInfFrenzy = v and true or false
    if v then pcall(MAWWW_StartJeffCooldownBypass) else pcall(MAWWW_StopJeffCooldownBypass) end
end)
RegToggle(Tabs.KillerBypass, "Abyss: Cooldown Bypass", "Bypass Abyss cooldown", false, "BypassAbyss", function(v)
    VD.KillerInfAbyss = v and true or false
    if v then pcall(MAWWW_StartAbyssCooldownBypass) else pcall(MAWWW_StopAbyssCooldownBypass) end
end)
RegDivider(Tabs.KillerBypass)
RegLabel(Tabs.KillerBypass, "Safety / Reset")
RegButton(Tabs.KillerBypass, "Disable All Killer Bypass", "Turn off the unified bypass switches", function()
    pcall(SetAllKillerNoCooldown, false)
    VD.KillerBypassCD = false
    notify("Cooldown / Bypass", "All bypasses disabled", 2)
end)
RegButton(Tabs.KillerBypass, "Myers Grab Now", "Force Myers grab", function()
    if MyersGrabData and MyersGrabData.Enabled then
        pcall(doMyersGrab)
    else
        pcall(function() notify("Myers Grab", "Enable Bypass Skill first.", 3) end)
    end
end)

RegButton(Tabs.KillerRight, "Myers Grab Now (Hotkey H)", "Force Myers grab", function()
    if MyersGrabData.Enabled then
        pcall(doMyersGrab)
    else
        pcall(function() notify("Myers Grab", "Enable 'Bypass Skill (All Killers)' first.", 3) end)
    end
end)

-- Counter Hacks

RegDivider(Tabs.KillerRight)
RegLabel(Tabs.KillerRight, "Counter Hacks")
FakeParryAnims = {
    ["Enten"] = "rbxassetid://127096285501517", ["Stopwatch"] = "rbxassetid://81793464499285",
    ["Fih"] = "rbxassetid://123307242865945", ["BloodShield"] = "rbxassetid://75939529748815",
}
task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.3)
        if VD.FakeAttack and GetRole() == "Killer" then
            local char = Player.Character
            if char then
                local Animator = char:FindFirstChild("Humanoid") and char.Humanoid:FindFirstChild("Animator")
                if Animator then
                    local myRoot = char:FindFirstChild("HumanoidRootPart")
                    local near = false
                    if myRoot then
                        for _, p in ipairs(MawwwGetPlayers()) do
                            if p ~= Player and IsSurvivor(p) then
                                local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                                if r and (myRoot.Position - r.Position).Magnitude <= 15 then near = true; break end
                            end
                        end
                    end
                    if near then
                        pcall(function()
                            local bait = Instance.new("Animation")
                            bait.AnimationId = "rbxassetid://117042998468241"
                            local track = Animator:LoadAnimation(bait)
                            track:Play(); track:AdjustWeight(0); task.wait(0.05); track:Stop()
                        end)
                    end
                end
            end
        end
    end
end)
task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.4)
        if VD.FakeParry and GetRole() == "Survivor" then
            local char = Player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    local anim = hum:FindFirstChildOfClass("Animator")
                    if anim then
                        local animation = Instance.new("Animation")
                        animation.AnimationId = FakeParryAnims[VD.FakeParryAnim] or FakeParryAnims["Enten"]
                        pcall(function()
                            local track = anim:LoadAnimation(animation)
                            track.Priority = Enum.AnimationPriority.Action
                            track:Play()
                        end)
                    end
                end
            end
        end
    end
end)
RegToggle(Tabs.KillerRight, "Fake Attack", "Fake attack animation", false, "FakeAttack")
RegToggle(Tabs.KillerRight, "Fake Parry", "Fake parry animation", false, "FakeParry")
RegDropdown(Tabs.KillerRight, "Fake Parry Animation", "Animation style", {"Enten", "Stopwatch", "Fih", "BloodShield"}, "Enten", false, "FakeParryAnim")

--========================================================--
-- K4N3K1 IMPORTED KILLER FEATURES
--========================================================--
RegDivider(Tabs.KillerExtra)
RegLabel(Tabs.KillerExtra, "Counter & Aim")
RegToggle(Tabs.KillerExtra, "Counter Auto Parry", "Counter Auto Parry from K4N3K1 source", VD.KillerCounterAutoParry or false, "KillerCounterAutoParry", function(v)
    if getgenv().MAWWW_K4N3K1 and getgenv().MAWWW_K4N3K1.SetCounterAutoParry then
        getgenv().MAWWW_K4N3K1.SetCounterAutoParry(v)
    else
        VD.KillerCounterAutoParry = v
    end
    notify("Counter Auto Parry", v and "Enabled" or "Disabled", 2)
end)

RegToggle(Tabs.KillerExtra, "Aim Lock Hidden", "Hold M2 / configured key to lock camera to the nearest enemy", VD.AimLockHidden or false, "AimLockHidden", function(v)
    if getgenv().MAWWW_K4N3K1 and getgenv().MAWWW_K4N3K1.SetAimLockHidden then
        getgenv().MAWWW_K4N3K1.SetAimLockHidden(v)
    else
        VD.AimLockHidden = v
    end
    notify("Aim Lock Hidden", v and "Enabled" or "Disabled", 2)
end)
RegInput(Tabs.KillerExtra, "Aim Lock Hidden Key", "Default: E", VD.AimLockHiddenKey or "E", "AimLockHiddenKey", function(v)
    local input = tostring(v or ""):gsub("%s+", "")
    if input == "" then return end
    local keyMap = {
        leftshift=Enum.KeyCode.LeftShift, rightshift=Enum.KeyCode.RightShift,
        leftalt=Enum.KeyCode.LeftAlt, rightalt=Enum.KeyCode.RightAlt,
        leftctrl=Enum.KeyCode.LeftControl, rightctrl=Enum.KeyCode.RightControl,
        leftcontrol=Enum.KeyCode.LeftControl, rightcontrol=Enum.KeyCode.RightControl,
        space=Enum.KeyCode.Space, tab=Enum.KeyCode.Tab,
    }
    local key = keyMap[input:lower()]
    if not key then
        for _, item in ipairs(Enum.KeyCode:GetEnumItems()) do
            if item.Name:lower() == input:lower() then key = item; break end
        end
    end
    if key and getgenv().MAWWW_K4N3K1 and getgenv().MAWWW_K4N3K1.SetAimLockHiddenKey then
        getgenv().MAWWW_K4N3K1.SetAimLockHiddenKey(key)
    end
end)

RegDivider(Tabs.KillerRight)
RegLabel(Tabs.KillerRight, "Attack Aim")
RegToggle(Tabs.KillerRight, "Aim Lock Attack", "Hold M2 / attack button to lock to the closest survivor", VD.AimLockAttack or false, "AimLockAttack", function(v)
    if getgenv().MAWWW_K4N3K1 and getgenv().MAWWW_K4N3K1.SetAimLockAttack then
        getgenv().MAWWW_K4N3K1.SetAimLockAttack(v)
    elseif getgenv().AttackAim_Cfg then
        getgenv().AttackAim_Cfg.Enabled = v
    end
    notify("Aim Lock Attack", v and "Enabled" or "Disabled", 2)
end)
RegSlider(Tabs.KillerRight, "Aim Lock Attack FOV", "Screen-space target radius", VD.AimLockAttackFOV or 250, 50, 1000, 10, "AimLockAttackFOV", function(v)
    if getgenv().AttackAim_Cfg then getgenv().AttackAim_Cfg.FOV = tonumber(v) or 250 end
end)
RegSlider(Tabs.KillerRight, "Aim Lock Attack Smooth", "Camera smoothing amount", VD.AimLockAttackStrength or 1, 0.1, 1, 0.05, "AimLockAttackStrength", function(v)
    if getgenv().AttackAim_Cfg then getgenv().AttackAim_Cfg.Strength = tonumber(v) or 1 end
end)
RegSlider(Tabs.KillerRight, "Aim Lock Attack Predict", "Prediction lead", VD.AimLockAttackPredictStrength or 0.12, 0, 1, 0.01, "AimLockAttackPredictStrength", function(v)
    if getgenv().AttackAim_Cfg then getgenv().AttackAim_Cfg.PredictStrength = tonumber(v) or 0.12 end
end)
RegDropdown(Tabs.KillerRight, "Aim Lock Attack Part", "Target body part", {"Head", "HumanoidRootPart", "UpperTorso", "Torso"}, "HumanoidRootPart", false, "AimLockAttackPart", function(v)
    local value = type(v) == "table" and v[1] or v
    if getgenv().AttackAim_Cfg then getgenv().AttackAim_Cfg.AimPart = tostring(value or "HumanoidRootPart") end
end)
RegToggle(Tabs.KillerRight, "Aim Lock Wall Check", "Require clear camera line of sight", true, "AimLockAttackVisibility", function(v)
    if getgenv().AttackAim_Cfg then getgenv().AttackAim_Cfg.VisibilityCheck = v end
end)


RegDivider(Tabs.KillerUtility)
RegLabel(Tabs.KillerUtility, "Killer Tools")
RegToggle(Tabs.KillerUtility, "Destroy Pallets", "Auto destroy pallets", false, "KillerDestroyPallets", function(v)
    VD.KillerDestroyPallets = v
    if v then
        if getgenv().MAWWW_DestroyAllPallets then pcall(getgenv().MAWWW_DestroyAllPallets) end
        notify("Destroy Pallet", "Enabled", 2)
    else
        getgenv().MAWWW_IsBreakingPallet = false
        notify("Destroy Pallet", "Disabled", 2)
    end
end)
RegToggle(Tabs.KillerUtility, "Auto Kick Generator", "Auto kick generators", false, "KillerAutoKickGen")
RegToggle(Tabs.KillerUtility, "Auto Hook", "Auto-pickup downed survivors and hook them automatically", false, "KillerAutoHook")
RegToggle(Tabs.KillerUtility, "No Slowdown", "Ignore slowdown", false, "KillerNoSlowdown")
RegDivider(Tabs.KillerUtility)
RegLabel(Tabs.KillerUtility, "Carry Skill")
RegToggle(Tabs.KillerUtility, "Unlock Skill While Carrying", "Allow killer skill checks while carrying a survivor", VD.UnlockSkillWhileCarrying or false, "UnlockSkillWhileCarrying", function(v)
    local api = getgenv().MAWWW_K4N3K1
    if api and api.SetUnlockSkillWhileCarrying then
        api.SetUnlockSkillWhileCarrying(v)
    else
        VD.UnlockSkillWhileCarrying = v
    end
    notify("Unlock Skill", v and "Enabled" or "Disabled", 2)
end)

-- Destroy Pallet worker is provided by the K4N3K1 source implementation above.
IsBreakingGen = false
task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.3)
        if VD.KillerAutoKickGen and GetRole() == "Killer" and not IsBreakingGen then
            local char = Player.Character
            local root = getRoot()
            if char and root then
                local stunned = char:GetAttribute("IsStunned"); local immobile = char:GetAttribute("Immobile"); local carrying = char:GetAttribute("IsCarrying")
                if not (stunned or immobile or carrying) then
                    local pts = CollectionService:GetTagged("GeneratorPoint")
                    local nearest, minDist = nil, 6
                    for _, p in ipairs(pts) do
                        if p:IsA("BasePart") then
                            local genModel = p.Parent
                            if genModel then
                                local progress = genModel:GetAttribute("RepairProgress") or 0
                                local kickcount = genModel:GetAttribute("kickcount") or 0
                                if progress > 0 and progress < 100 and kickcount <= 7 then
                                    local d = (p.Position - root.Position).Magnitude
                                    if d < minDist then minDist = d; nearest = p end
                                end
                            end
                        end
                    end
                    if nearest then
                        IsBreakingGen = true
                        task.spawn(function()
                            pcall(function()
                                local r = GetRemotes()
                                local g = r and r:FindFirstChild("Generator")
                                if g then
                                    local ev = g:FindFirstChild("BreakGenEvent"); local cm = g:FindFirstChild("BreakGenCommit")
                                    if ev then ev:FireServer(nearest) end
                                    if cm then cm:FireServer(nearest) end
                                end
                            end)
                            task.wait(1); IsBreakingGen = false
                        end)
                    end
                end
            end
        end
    end
end)
-- =====================================================
-- AUTO HOOK (Killer) — REPAIRED
-- Flow: Downed Survivor -> Carry -> Empty Hook -> HookEvent/HookCommit
-- =====================================================
IsAutoHooking = false
AutoHookLastAction = 0
AutoHookCooldown = 0.75
AutoHookCarryWait = 0.85
AutoHookTeleportHeight = 3

function MAWWW_GetHookPoint(hookInfo)
    if not hookInfo then return nil end

    local model = hookInfo.model
    if model then
        local point = model:FindFirstChild("HookPoint", true)
            or model:FindFirstChild("HookHitbox", true)
        if point and point:IsA("BasePart") then
            return point
        end
    end

    local part = hookInfo.part
    if part and part:IsA("BasePart") then
        return part
    end

    return nil
end

function MAWWW_IsHookOccupied(hookPart)
    if not hookPart then return true end

    for _, player in ipairs(MawwwGetPlayers()) do
        if player ~= Player and player.Character then
            local char = player.Character
            local hooked = char:GetAttribute("IsHooked") == true
                or char:GetAttribute("isHooked") == true
                or char:GetAttribute("HookProgressDepleting") == true

            if hooked then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - hookPart.Position).Magnitude <= 10 then
                    return true
                end
            end
        end
    end

    return false
end

function MAWWW_FindBestEmptyHook(origin)
    if not origin then return nil end

    local best, bestDist = nil, math.huge
    local seen = {}

    local function considerHook(model, part)
        if not part or not part:IsA("BasePart") then return end
        if seen[part] then return end
        seen[part] = true
        if MAWWW_IsHookOccupied(part) then return end

        local d = (part.Position - origin).Magnitude
        if d < bestDist then
            bestDist = d
            best = { model = model, part = part, distance = d }
        end
    end

    -- The main hook cache is declared later in this file, so Auto Hook intentionally
    -- uses a local map scan here instead of referencing that later local.
    if not best then
        local map = Workspace:FindFirstChild("Map")
        if map then
            for _, obj in ipairs(map:GetDescendants()) do
                if obj:IsA("Model") and obj.Name == "Hook" then
                    local part = obj:FindFirstChildWhichIsA("BasePart", true)
                    considerHook(obj, part)
                end
            end
        end
    end

    return best
end

function MAWWW_FindClosestDownedSurvivor(origin)
    if not origin then return nil end

    local closest, closestDist = nil, math.huge

    for _, player in ipairs(MawwwGetPlayers()) do
        if player ~= Player and IsSurvivor(player) and player.Character then
            local char = player.Character
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")

            if root and hum and hum.Health > 0 then
                local maxHealth = hum.MaxHealth > 0 and hum.MaxHealth or 100
                local healthRatio = hum.Health / maxHealth
                local downed = healthRatio <= 0.25
                    or char:GetAttribute("IsDowned") == true
                    or char:GetAttribute("isDowned") == true
                    or char:GetAttribute("Downed") == true

                local alreadyHooked = char:GetAttribute("IsHooked") == true
                    or char:GetAttribute("isHooked") == true
                    or char:GetAttribute("IsCarried") == true

                if downed and not alreadyHooked then
                    local d = (root.Position - origin).Magnitude
                    if d < closestDist then
                        closest = player
                        closestDist = d
                    end
                end
            end
        end
    end

    return closest
end

function MAWWW_FireCarryRemote(targetCharacter)
    local remotes = GetRemotes()
    local carryFolder = remotes and remotes:FindFirstChild("Carry")
    local carryEvent = carryFolder and carryFolder:FindFirstChild("CarrySurvivorEvent")

    if not carryEvent or not carryEvent:IsA("RemoteEvent") then
        return false
    end

    local ok = pcall(function()
        carryEvent:FireServer(targetCharacter)
    end)
    return ok
end

function MAWWW_FireHookRemotes(hookInfo)
    local hookPoint = MAWWW_GetHookPoint(hookInfo)
    if not hookPoint then return false end

    local remotes = GetRemotes()
    local carryFolder = remotes and remotes:FindFirstChild("Carry")
    local event = carryFolder and carryFolder:FindFirstChild("HookEvent")
    local commit = carryFolder and carryFolder:FindFirstChild("HookCommit")

    local fired = false
    if event and event:IsA("RemoteEvent") then
        pcall(function() event:FireServer(hookPoint) end)
        fired = true
    end
    if commit and commit:IsA("RemoteEvent") then
        pcall(function() commit:FireServer(hookPoint) end)
        fired = true
    end

    return fired
end

function MAWWW_AutoHook()
    if not (VD.KillerAutoHook or (VD.AF_Enabled and VD.AF_AutoHook)) or GetRole() ~= "Killer" or IsAutoHooking then
        return
    end

    local now = tick()
    if now - AutoHookLastAction < AutoHookCooldown then
        return
    end

    local root = getRoot()
    local char = Player.Character
    if not root or not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end

    if char:GetAttribute("IsStunned") == true
        or char:GetAttribute("Immobile") == true then
        return
    end

    local isCarrying = char:GetAttribute("IsCarrying") == true
        or char:GetAttribute("isCarrying") == true

    IsAutoHooking = true
    AutoHookLastAction = now

    task.spawn(function()
        local ok, err = pcall(function()
            if not isCarrying then
                -- 1) Find a downed survivor.
                local targetPlayer = MAWWW_FindClosestDownedSurvivor(root.Position)
                if not targetPlayer or not targetPlayer.Character then
                    return
                end

                local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not targetRoot then return end

                -- 2) Find an empty hook near the survivor before moving.
                local hookInfo = MAWWW_FindBestEmptyHook(targetRoot.Position)
                if not hookInfo then return end

                -- 3) Move near survivor and perform pickup.
                root.CFrame = CFrame.new(
                    targetRoot.Position + Vector3.new(0, AutoHookTeleportHeight, 0),
                    targetRoot.Position
                )
                task.wait(0.3)

                if not (VD.KillerAutoHook or (VD.AF_Enabled and VD.AF_AutoHook)) or VD.Destroyed then return end
                if not MAWWW_FireCarryRemote(targetPlayer.Character) then return end

                -- 4) Verify pickup registered.
                task.wait(AutoHookCarryWait)

                char = Player.Character
                root = getRoot()
                if not char or not root then return end

                isCarrying = char:GetAttribute("IsCarrying") == true
                    or char:GetAttribute("isCarrying") == true

                if not isCarrying then
                    return
                end
            end

            -- 5) Re-select an empty hook using the current player position.
            root = getRoot()
            if not root then return end

            local hookInfo = MAWWW_FindBestEmptyHook(root.Position)
            if not hookInfo then return end

            local hookPoint = MAWWW_GetHookPoint(hookInfo)
            if not hookPoint then return end

            -- 6) Move to hook and fire both server-side hook remotes.
            root.CFrame = CFrame.new(
                hookPoint.Position + Vector3.new(0, AutoHookTeleportHeight, 0),
                hookPoint.Position
            )
            task.wait(0.4)

            if (VD.KillerAutoHook or (VD.AF_Enabled and VD.AF_AutoHook)) and not VD.Destroyed then
                MAWWW_FireHookRemotes(hookInfo)
            end
        end)

        if not ok then
            warn("[MawwwHub] Auto Hook error:", err)
        end

        task.wait(0.25)
        IsAutoHooking = false
    end)
end

-- Single Auto Hook worker; the old duplicate loop is intentionally replaced.
task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.2)
        if (VD.KillerAutoHook or (VD.AF_Enabled and VD.AF_AutoHook)) and GetRole() == "Killer" then
            MAWWW_AutoHook()
        end
    end
end)

task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.1)
        if VD.KillerNoSlowdown and GetRole() == "Killer" then
            local hum = getHum()
            if hum and hum.WalkSpeed < 16 then hum.WalkSpeed = 16 end
        end
    end
end)

--========================================================--
-- AIM TAB
--========================================================--

--========================================================--
-- SHARED VEIL VISUALS (V1 pakai Cyan)
--========================================================--
VeilSharedVisuals = (function()
    local V = { FOVOutline = nil, FOVFill = nil, TracerLine = nil, TargetOutline = nil, TargetFill = nil, PlayerCircles = {}, NameLabels = {}, HasDrawing = false, LastFovRadius = -1 }
    pcall(function() if (typeof(Drawing) == "table" or typeof(Drawing) == "userdata") and type(Drawing.new) == "function" then V.HasDrawing = true end end)
    local COLORS = { FOV = Color3.fromRGB(0, 220, 255), FOVFill = Color3.fromRGB(0, 220, 255), Player = Color3.fromRGB(255, 255, 255), Target = Color3.fromRGB(255, 0, 0), Tracer = Color3.fromRGB(255, 255, 255), Label = Color3.fromRGB(60, 255, 60), LabelEnemy = Color3.fromRGB(255, 90, 90) }
    local function InitDrawing()
        if not V.HasDrawing then return end
        if not V.FOVOutline then V.FOVOutline = Drawing.new("Circle"); V.FOVOutline.Color = COLORS.FOV; V.FOVOutline.Thickness = 2; V.FOVOutline.Filled = false; V.FOVOutline.Transparency = 0.85; V.FOVOutline.Visible = false end
        if not V.FOVFill then V.FOVFill = Drawing.new("Circle"); V.FOVFill.Color = COLORS.FOVFill; V.FOVFill.Thickness = 1; V.FOVFill.Filled = false; V.FOVFill.Transparency = 0.12; V.FOVFill.Visible = false end
        if not V.TracerLine then V.TracerLine = Drawing.new("Line"); V.TracerLine.Color = COLORS.Tracer; V.TracerLine.Thickness = 1.5; V.TracerLine.Transparency = 0.75; V.TracerLine.Visible = false end
        if not V.TargetOutline then V.TargetOutline = Drawing.new("Circle"); V.TargetOutline.Color = COLORS.Target; V.TargetOutline.Thickness = 2; V.TargetOutline.Filled = false; V.TargetOutline.Transparency = 1; V.TargetOutline.Visible = false end
        if not V.TargetFill then V.TargetFill = Drawing.new("Circle"); V.TargetFill.Color = COLORS.Target; V.TargetFill.Thickness = 1; V.TargetFill.Filled = false; V.TargetFill.Transparency = 0.4; V.TargetFill.Visible = false end
    end
    local function GetPlayerCircle(plr)
        if not V.HasDrawing then return nil end
        local c = V.PlayerCircles[plr]; if c then return c end
        local outline = Drawing.new("Circle"); outline.Color = COLORS.Player; outline.Thickness = 1.5; outline.Filled = false; outline.Transparency = 1; outline.Visible = false
        local fill = Drawing.new("Circle"); fill.Color = COLORS.Player; fill.Thickness = 1; fill.Filled = false; fill.Transparency = 0.25; fill.Visible = false
        c = { outline = outline, fill = fill }; V.PlayerCircles[plr] = c; return c
    end
    local function GetNameLabel(plr)
        local label = V.NameLabels[plr]; if label and label.Parent then return label end
        local char = plr.Character; if not char then return nil end
        local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"); if not head then return nil end
        local bb = Instance.new("BillboardGui")
        bb.Name = "Veil_NameLabel"; bb.Size = UDim2.new(0, 240, 0, 22); bb.StudsOffset = Vector3.new(0, 3.2, 0); bb.AlwaysOnTop = true; bb.Adornee = head; bb.Parent = head
        local lbl = Instance.new("TextLabel")
        lbl.Name = "Text"; lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
        lbl.TextColor3 = COLORS.Label; lbl.TextStrokeTransparency = 0.3; lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.TextSize = 14; lbl.Font = Enum.Font.GothamBold; lbl.Text = plr.Name; lbl.Parent = bb
        V.NameLabels[plr] = bb; return bb
    end
    function V.UpdateFOV(center, radius, visible)
        InitDrawing(); if not V.HasDrawing then return end
        if V.FOVOutline then V.FOVOutline.Position = center; V.FOVOutline.Radius = radius; V.FOVOutline.Visible = visible end
        if V.FOVFill then V.FOVFill.Position = center; V.FOVFill.Radius = radius; V.FOVFill.Visible = visible end
        V.LastFovRadius = radius
    end
    function V.UpdateTarget(screenPos, radius, visible)
        InitDrawing(); if not V.HasDrawing then return end
        if V.TargetOutline then V.TargetOutline.Position = screenPos; V.TargetOutline.Radius = radius; V.TargetOutline.Visible = visible end
        if V.TargetFill then V.TargetFill.Position = screenPos; V.TargetFill.Radius = radius; V.TargetFill.Visible = visible end
    end
    function V.UpdateTracer(fromPos, toPos, visible)
        InitDrawing(); if not V.HasDrawing then return end
        if V.TracerLine then V.TracerLine.From = fromPos; V.TracerLine.To = toPos; V.TracerLine.Visible = visible end
    end
    function V.UpdatePlayerMarker(plr, screenPos, radius, visible)
        local c = GetPlayerCircle(plr); if not c then return end
        if c.outline then c.outline.Position = screenPos; c.outline.Radius = radius; c.outline.Visible = visible end
        if c.fill then c.fill.Position = screenPos; c.fill.Radius = radius; c.fill.Visible = visible end
    end
    function V.HideAllPlayerMarkers()
        for _, c in pairs(V.PlayerCircles) do
            if c.outline then c.outline.Visible = false end
            if c.fill then c.fill.Visible = false end
        end
    end
    function V.UpdateNameLabel(plr, text, visible, isTarget)
        if not visible then local lbl = V.NameLabels[plr]; if lbl then lbl.Enabled = false end; return end
        local bb = GetNameLabel(plr); if not bb then return end
        bb.Enabled = true
        local lbl = bb:FindFirstChild("Text")
        if lbl then lbl.Text = text; lbl.TextColor3 = isTarget and COLORS.LabelEnemy or COLORS.Label end
    end
    function V.HideAllNameLabels() for _, bb in pairs(V.NameLabels) do if bb then bb.Enabled = false end end end
    function V.HideAll()
        if not V.HasDrawing then V.HideAllNameLabels(); return end
        if V.FOVOutline then V.FOVOutline.Visible = false end
        if V.FOVFill then V.FOVFill.Visible = false end
        if V.TracerLine then V.TracerLine.Visible = false end
        if V.TargetOutline then V.TargetOutline.Visible = false end
        if V.TargetFill then V.TargetFill.Visible = false end
        V.HideAllPlayerMarkers(); V.HideAllNameLabels()
    end
    function V.CleanupPlayer(plr)
        local c = V.PlayerCircles[plr]
        if c then
            if c.outline then pcall(function() c.outline:Remove() end) end
            if c.fill then pcall(function() c.fill:Remove() end) end
            V.PlayerCircles[plr] = nil
        end
        local bb = V.NameLabels[plr]
        if bb then pcall(function() bb:Destroy() end); V.NameLabels[plr] = nil end
    end
    Players.PlayerRemoving:Connect(function(p) V.CleanupPlayer(p) end)
    return V
end)()

--========================================================--
-- SILENT VEIL V1
--========================================================--
VeilState = { target = nil, lookVector = nil, velHistory = {}, lastThrow = 0 }

-- [FIX] Detect whether Veil killer has Aura active (spear speed/gravity differ).
function Veil_HasAura()
    local char = Player.Character
    if not char then return false end
    for _, key in ipairs({"AuraActive", "HasAura", "Aura", "Enraged", "UltimateActive"}) do
        local v = char:GetAttribute(key)
        if v == true then return true end
    end
    return false
end
function Veil_GetSpearProfile()
    if Veil_HasAura() then
        return {
            v0 = tonumber(VD.VeilAuraSpearSpeed) or 165,
            g = tonumber(VD.VeilAuraSpearGravity) or 96.5,
        }
    end
    return {
        v0 = tonumber(VD.VeilSpearSpeed) or 165,
        g = tonumber(VD.VeilGravity) or 103,
    }
end
-- [FIX] V1 spear remote lookup (multi-pattern).
function Veil_GetSpearRemote()
    local remotes = GetRemotes()
    local items = remotes and remotes:FindFirstChild("Items")
    local spear = items and items:FindFirstChild("Spear")
    if not spear then return nil end
    return spear:FindFirstChild("Spearthrow") or spear:FindFirstChild("Throw") or spear:FindFirstChildWhichIsA("RemoteEvent")
end
function Veil_IsSurvivorVeil(p) if not p or not p.Team or not p.Team.Name then return false end; return string.find(string.lower(p.Team.Name), "survivor", 1, true) ~= nil end
function Veil_solvePitch(p, d, dy)
    d = math.max(d, 0.1)
    local s2 = p.v0 * p.v0
    local root = s2 * s2 - p.g * (p.g * d * d + 2 * dy * s2)
    if root < 0 then root = 0 end
    local tanTheta = (s2 - math.sqrt(root)) / (p.g * d)
    local theta = math.atan(tanTheta)
    local cosT = math.max(math.cos(theta), 0.001)
    local t = d / (p.v0 * cosT)
    return theta, t
end
function Veil_getCharacterVelocity(char)
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
    if not root or not root:IsA("BasePart") then return Vector3.zero end
    local now = os.clock()
    local last = VeilState.velHistory[char]
    local measured = Vector3.zero
    if last and now - last.t > 0.02 then
        measured = (root.Position - last.pos) / (now - last.t)
        if measured.Magnitude > 150 then measured = last.smooth or Vector3.zero end
    end
    local smooth = last and last.smooth or measured
    smooth = smooth:Lerp(measured, 0.65)
    VeilState.velHistory[char] = { pos = root.Position, t = now, smooth = smooth }
    if smooth.Magnitude < 0.5 then return Vector3.zero end -- [FIX] threshold rendah agar pelan/crouch tetap diprediksi
    return Vector3.new(smooth.X, 0, smooth.Z)
end
Players.PlayerRemoving:Connect(function(p) if p.Character then VeilState.velHistory[p.Character] = nil end end)
function Veil_WallCheck(origin, targetPos, targetChar)
    if not VD.VeilWallCheck then return true end
    return VD_WallCheckVisible(origin, targetPos, targetChar)
end
function Veil_UpdateAimbot()
    if not VD.VeilEnabled then
        VeilState.target = nil
        VeilState.lookVector = nil
        VeilSharedVisuals.HideAll()
        return
    end

    if GetRole() ~= "Killer" then
        VeilState.target = nil
        VeilState.lookVector = nil
        VeilSharedVisuals.HideAll()
        return
    end

    local cam = Workspace.CurrentCamera
    if not cam then return end

    local viewport = cam.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
    local showFov = VD.VeilShowFOV and VD.VeilEnabled
    VeilSharedVisuals.UpdateFOV(center, VD.VeilFOV or 150, showFov)

    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        VeilSharedVisuals.HideAll()
        return
    end

    local nearest, bestScore = nil, math.huge
    local bestStudDist = VD.VeilMaxDist or 400
    local detected = {}

    for _, p in ipairs(MawwwGetPlayers()) do
        if p ~= Player and Veil_IsSurvivorVeil(p) and p.Character then
            local pc = p.Character
            local isDown = pc:GetAttribute("Knocked") == true
                or pc:GetAttribute("HookProgressDepleting") == true
                or pc:GetAttribute("IsHooked") == true

            local hum = pc:FindFirstChildOfClass("Humanoid")
            local targetPart = pc:FindFirstChild("UpperTorso")
                or pc:FindFirstChild("Torso")
                or pc:FindFirstChild("HumanoidRootPart")

            if hum and hum.Health > 0 and targetPart then
                local visible = true
                if VD.VeilIgnoreDown and isDown then visible = false end
                if visible and VD.VeilWallCheck then
                    if not Veil_WallCheck(hrp.Position, targetPart.Position, pc) then visible = false end
                end

                local sp, onScreen = cam:WorldToViewportPoint(targetPart.Position)
                if visible and onScreen and sp.Z > 0 then
                    local screenDist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    local studDist = (targetPart.Position - hrp.Position).Magnitude

                    if screenDist <= (VD.VeilFOV or 150) and studDist <= bestStudDist then
                        local maxHealth = math.max(hum.MaxHealth, 1)
                        local health = math.floor((hum.Health / maxHealth) * 100 + 0.5)
                        local score = screenDist * 0.7 + studDist * 0.3

                        table.insert(detected, {
                            plr = p, char = pc, hum = hum, targetPart = targetPart,
                            scrPos = Vector2.new(sp.X, sp.Y), studDist = studDist,
                            health = health, screenDist = screenDist, score = score,
                        })

                        if score < bestScore then bestScore = score; nearest = p end
                    end
                end
            end
        end
    end

    table.sort(detected, function(a, b) return a.score < b.score end)
    if detected[1] then nearest = detected[1].plr end

    local showMarkers = VD.VeilShowPlayerMarkers
    local showNames = VD.VeilShowNameLabels
    local showTarget = VD.VeilShowTargetMarker
    local showTracer = VD.VeilShowTracer
    local isTargetPlr = nearest

    for _, info in ipairs(detected) do
        local plr = info.plr
        local isTarget = (plr == isTargetPlr)

        if showMarkers then
            local rad = math.clamp(1500 / math.max(info.studDist, 1), 10, 55)
            VeilSharedVisuals.UpdatePlayerMarker(plr, info.scrPos, rad, true)
        else
            VeilSharedVisuals.UpdatePlayerMarker(plr, Vector2.new(0, 0), 0, false)
        end

        if showNames then
            local labelText = string.format("%s [%d%%] [%dm]", plr.DisplayName or plr.Name, info.health, math.floor(info.studDist))
            VeilSharedVisuals.UpdateNameLabel(plr, labelText, true, isTarget)
        else
            VeilSharedVisuals.UpdateNameLabel(plr, "", false, false)
        end
    end

    local detectedSet = {}
    for _, info in ipairs(detected) do detectedSet[info.plr] = true end
    for plr, _ in pairs(VeilSharedVisuals.PlayerCircles) do
        if not detectedSet[plr] then
            VeilSharedVisuals.UpdatePlayerMarker(plr, Vector2.new(0, 0), 0, false)
            VeilSharedVisuals.UpdateNameLabel(plr, "", false, false)
        end
    end

    if nearest and nearest.Character then
        local tpPart = nearest.Character:FindFirstChild("UpperTorso") or nearest.Character:FindFirstChild("Torso") or nearest.Character:FindFirstChild("HumanoidRootPart")
        if tpPart then
            local tp = tpPart.Position
            local hand = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
            local origin = (hand and hand:IsA("BasePart")) and hand.Position or hrp.Position
            local dir = tp - origin
            local dist = dir.Magnitude

            if dist > 0.1 and dist <= (VD.VeilMaxDist or 400) then
                local _sp = Veil_GetSpearProfile()
                local prof = {
                    v0 = _sp.v0,
                    g = _sp.g,
                    windup = 0.10, latency = 0.04,
                    maxlead = 45, scale = VD.VeilLeadMultiplier or 1.4,
                }

                local aimPoint = tp
                if VD.VeilAutoPredict then
                    local vel = Veil_getCharacterVelocity(nearest.Character)
                    if vel.Magnitude > 0.5 then
                        local h0 = Vector3.new(dir.X, 0, dir.Z)
                        local _, tFlight = Veil_solvePitch(prof, h0.Magnitude, dir.Y)
                        local ping = 0.08
                        pcall(function() ping = math.clamp(Player:GetNetworkPing(), 0, 0.35) end)
                        local delay = tFlight + prof.windup + ping + prof.latency
                        for _ = 1, 3 do
                            local lead = vel * delay * prof.scale
                            local maxLead = math.clamp(dist * 0.6, 3, prof.maxlead)
                            if lead.Magnitude > maxLead then lead = lead.Unit * maxLead end
                            aimPoint = tp + lead
                            local ad = aimPoint - origin
                            local ah = Vector3.new(ad.X, 0, ad.Z)
                            local _, t2 = Veil_solvePitch(prof, math.max(ah.Magnitude, 0.1), ad.Y)
                            delay = t2 + prof.windup + ping + prof.latency
                        end
                    end
                end

                if VD.VeilWallCheck then
                    if not VD_WallCheckVisible(origin, aimPoint, nil) then aimPoint = tp end
                    if not VD_WallCheckVisible(origin, aimPoint, nearest.Character) then
                        VeilState.target = nil; VeilState.lookVector = nil
                        VeilSharedVisuals.UpdateTarget(Vector2.new(0, 0), 0, false)
                        VeilSharedVisuals.UpdateTracer(Vector2.new(0, 0), Vector2.new(0, 0), false)
                        return
                    end
                end

                local adir = aimPoint - origin
                local ah = Vector3.new(adir.X, 0, adir.Z)
                local ahDist = ah.Magnitude
                local pitch = Veil_solvePitch(prof, ahDist, adir.Y)

                if ahDist > 0.001 then
                    VeilState.lookVector = ah.Unit * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)
                else
                    VeilState.lookVector = adir.Unit
                end
                VeilState.target = nearest

                if showTarget and tpPart then
                    local sp, vis = cam:WorldToViewportPoint(tpPart.Position)
                    if vis and sp.Z > 0 then
                        local rad = math.clamp(1500 / math.max(dist, 1), 14, 60)
                        VeilSharedVisuals.UpdateTarget(Vector2.new(sp.X, sp.Y), rad, true)
                        if showTracer then
                            local bottomCenter = Vector2.new(center.X, viewport.Y)
                            VeilSharedVisuals.UpdateTracer(bottomCenter, Vector2.new(sp.X, sp.Y), true)
                        else
                            VeilSharedVisuals.UpdateTracer(Vector2.new(0, 0), Vector2.new(0, 0), false)
                        end
                    else
                        VeilSharedVisuals.UpdateTarget(Vector2.new(0, 0), 0, false)
                        VeilSharedVisuals.UpdateTracer(Vector2.new(0, 0), Vector2.new(0, 0), false)
                    end
                else
                    VeilSharedVisuals.UpdateTarget(Vector2.new(0, 0), 0, false)
                    VeilSharedVisuals.UpdateTracer(Vector2.new(0, 0), Vector2.new(0, 0), false)
                end
            end
        end
    else
        VeilSharedVisuals.UpdateTarget(Vector2.new(0, 0), 0, false)
        VeilSharedVisuals.UpdateTracer(Vector2.new(0, 0), Vector2.new(0, 0), false)
        VeilState.target = nil
        VeilState.lookVector = nil
    end
end
VeilHookState = { remoteHooked = false }
function Veil_setupInterceptor()
    if VeilHookState.remoteHooked then return end
    if typeof(hookmetamethod) ~= "function" then return end
    task.spawn(function()
        pcall(function()
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                if not checkcaller() and method == "FireServer" then
                    local _n = self.Name or ""
                    if (_n == "Spearthrow" or _n == "Spear" or _n == "Throw") and VD.VeilEnabled and not VD.VeilV2Enabled and typeof(VeilState.lookVector) == "Vector3" and GetRole() == "Killer" then
                        local args = {...}
                        if typeof(args[1]) == "Vector3" then args[1] = VeilState.lookVector
                        elseif typeof(args[2]) == "Vector3" then args[2] = VeilState.lookVector end
                        return oldNamecall(self, unpack(args))
                    end
                end
                return oldNamecall(self, ...)
            end)
            VeilHookState.remoteHooked = true
        end)
    end)
end
Veil_setupInterceptor()
-- [FIX] V1 auto-throw: when enabled, fire spear at predicted target automatically.
VeilV1_AutoThrowConn = nil
function VeilV1_AutoThrowStep()
    if not VD.VeilEnabled or VD.VeilV2Enabled then return end
    if GetRole() ~= "Killer" then return end
    if typeof(VeilState.lookVector) ~= "Vector3" then return end
    if not VD.VeilAutoThrow then return end
    local now = os.clock()
    if now - VeilState.lastThrow < (tonumber(VD.VeilFireDelay) or 0.08) then return end
    VeilState.lastThrow = now
    pcall(function()
        local remote = Veil_GetSpearRemote()
        if not remote then return end
        local char = Player.Character
        local gun = char and (char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand"))
        local dir = VeilState.lookVector.Unit
        -- Multi-pattern fire.
        if gun then
            local ok = pcall(function() remote:FireServer(gun, dir) end)
            if ok then return end
        end
        pcall(function() remote:FireServer(dir) end)
    end)
end
local VeilV1LastUpdate = 0
RunService.RenderStepped:Connect(function()
    local now = os.clock()
    if now - VeilV1LastUpdate < 0.05 then return end
    VeilV1LastUpdate = now
    pcall(Veil_UpdateAimbot)
    pcall(VeilV1_AutoThrowStep)
end)

--========================================================--
-- UI: SILENT VEIL V1
--========================================================--

RegToggle(Tabs.AimVeilV1, "Silent Veil V1", "Silent spear aim", false, "VeilEnabled")
RegToggle(Tabs.AimVeilV1, "Show FOV Circle", "Show FOV circle", true, "VeilShowFOV")
RegToggle(Tabs.AimVeilV1, "Show Player Markers", "Show player markers", true, "VeilShowPlayerMarkers")
RegToggle(Tabs.AimVeilV1, "Show Target Marker", "Show target marker", true, "VeilShowTargetMarker")
RegToggle(Tabs.AimVeilV1, "Show Tracer", "Show tracer line", true, "VeilShowTracer")
RegToggle(Tabs.AimVeilV1, "Show Player Info", "Show name labels", true, "VeilShowNameLabels")
RegToggle(Tabs.AimVeilV1, "Auto Predict", "Auto predict movement", true, "VeilAutoPredict")
RegToggle(Tabs.AimVeilV1, "Auto Throw Spear", "Auto throw spear at target", false, "VeilAutoThrow")
RegSlider(Tabs.AimVeilV1, "Fire Delay (s)", "Auto throw interval", 0.08, 0.03, 1, 0.01, "VeilFireDelay")
RegToggle(Tabs.AimVeilV1, "Wall Check", "Require line of sight", false, "VeilWallCheck")
RegToggle(Tabs.AimVeilV1, "Ignore Downed", "Skip downed survivors", true, "VeilIgnoreDown")
RegSlider(Tabs.AimVeilV1, "FOV Size", "FOV radius", 150, 50, 500, 10, "VeilFOV")
RegSlider(Tabs.AimVeilV1, "Max Distance", "Max target distance", 400, 50, 400, 10, "VeilMaxDist")
RegSlider(Tabs.AimVeilV1, "Spear Speed", "Spear speed", 165, 50, 400, 5, "VeilSpearSpeed")
RegSlider(Tabs.AimVeilV1, "Spear Gravity", "Spear gravity", 103, 10, 300, 5, "VeilGravity")
RegSlider(Tabs.AimVeilV1, "Aura Spear Speed", "Aura spear speed", 165, 50, 400, 5, "VeilAuraSpearSpeed")
RegSlider(Tabs.AimVeilV1, "Aura Spear Gravity", "Aura spear gravity", 96, 10, 300, 5, "VeilAuraSpearGravity")
RegSlider(Tabs.AimVeilV1, "Lead Multiplier", "Lead multiplier", 1.4, 0.1, 5, 0.1, "VeilLeadMultiplier")

--========================================================--
-- AIM UTILITIES (dedicated groupbox)
--========================================================--
RegDivider(Tabs.AimUtility)
RegLabel(Tabs.AimUtility, "Aim / Utilities")

RegButton(Tabs.AimUtility, "Clear Aim Target", "Clear cached aim targets from all aim engines.", function()
    for _, key in ipairs({
        "CurrentTarget", "AimTarget", "Target",
        "VeilTarget", "VeilV2Target", "VeilV3Target", "VeilV4Target",
        "TOF_Target", "TOF2_Target", "TOF3_Target", "FlashTarget", "FlaskTarget"
    }) do
        pcall(function() VD[key] = nil end)
    end
    pcall(function() if VeilState then VeilState.target = nil end end)
    pcall(function() if VeilV2 and VeilV2.State then VeilV2.State.target = nil end end)
    pcall(function() if ToFV2 and ToFV2.State then ToFV2.State.Target = nil end end)
    pcall(function() if MAWWW_ToFState then MAWWW_ToFState.Target = nil end end)
    pcall(function() if MAWWW_ToFV3State then MAWWW_ToFV3State.Target = nil end end)
    pcall(function() if getgenv().MAWWW_SilentVeilV5Config then getgenv().MAWWW_SilentVeilV5Config.LockedPlayer = nil end end)
    notify("Aim / Utilities", "Aim targets cleared.", 2)
end)

RegButton(Tabs.AimUtility, "Clear Aim Lasers", "Hide active aim/laser visuals.", function()
    for _, fn in ipairs({
        getgenv().MAWWW_ToFClearLaser,
        getgenv().MAWWW_ToFV3ClearLaser,
        getgenv().MAWWW_ClearAimLasers,
    }) do
        if type(fn) == "function" then pcall(fn) end
    end
    pcall(function() if ToFV2 and ToFV2.ClearLaser then ToFV2.ClearLaser() end end)
    pcall(function() if ToFV3Module and ToFV3Module.ClearLaser then ToFV3Module.ClearLaser() end end)
    pcall(function()
        local part = getgenv().MAWWW_CureFlaskLaserPart
        if part then part.Transparency = 1 end
    end)
    notify("Aim / Utilities", "Aim lasers cleared.", 2)
end)

RegButton(Tabs.AimUtility, "Disable Aim Engines", "Disable active Silent Veil / Silent Pistol / Flashlight / Flask aim.", function()
    for _, key in ipairs({
        "VeilEnabled", "VeilV2Enabled", "VeilV3Enabled", "VeilV4Enabled", "VeilV5Enabled",
        "TOF_SilentAim", "TOF2_Enabled", "TOF3_SilentAim", "PistolV5Enabled",
        "FlashSilentAim", "FlaskSilentAim"
    }) do
        VD[key] = false
    end
    pcall(function() if MAWWW_SetToFSilentAim then MAWWW_SetToFSilentAim(false) end end)
    pcall(function() if MAWWW_SetToFV3SilentAim then MAWWW_SetToFV3SilentAim(false) end end)
    pcall(function() if ToFV2 and ToFV2.Stop then ToFV2.Stop() end end)
    pcall(function() if ToFV3Module and ToFV3Module.Stop then ToFV3Module.Stop() end end)
    pcall(function() if VeilV2 and VeilV2.Stop then VeilV2.Stop() end end)
    pcall(function() if getgenv().MAWWW_ToFClearLaser then getgenv().MAWWW_ToFClearLaser() end end)
    pcall(function() if getgenv().MAWWW_ToFV3ClearLaser then getgenv().MAWWW_ToFV3ClearLaser() end end)
    pcall(function() if getgenv().MAWWW_SilentVeilV5Hide then getgenv().MAWWW_SilentVeilV5Hide() end end)
    pcall(function() if getgenv().MAWWW_SilentPistolV5ClearLaser then getgenv().MAWWW_SilentPistolV5ClearLaser() end end)
    pcall(function() if getgenv().MAWWW_SetSilentVeilV5 then getgenv().MAWWW_SetSilentVeilV5(false) end end)
    pcall(function() if getgenv().MAWWW_SetSilentPistolV5 then getgenv().MAWWW_SetSilentPistolV5(false) end end)
    notify("Aim / Utilities", "Aim engines disabled.", 2)
end)

--========================================================--
-- CROSSHAIR
--========================================================--
CrosshairGui = nil
--========================================================--
-- [NEW FROM Mawww Hub] ADVANCED CROSSHAIR - offsets
-- FIX: Fungsi lama membungkus VD_UpdateCrosshair yang sudah ada,
-- sehingga offset CrossPosX/CrossPosY tidak pernah dipakai.
-- Sekarang kita PASANG ULANG fungsi secara langsung supaya
-- offset benar-benar berfungsi.
--========================================================--
do
    local function VD_UpdateCrosshairWithOffset()
        local CrosshairGuiNew = getgenv().MAWWW_CrosshairGui
        if CrosshairGuiNew and CrosshairGuiNew.Parent then
            pcall(function() CrosshairGuiNew:Destroy() end)
        end
        CrosshairGuiNew = nil
        getgenv().MAWWW_CrosshairGui = nil

        if not VD.CrossEnabled then return end

        local offsetX = tonumber(VD.CrossPosX) or 0
        local offsetY = tonumber(VD.CrossPosY) or 0
        local style   = VD.CrossStyle or "Dot"
        local size    = tonumber(VD.CrossSize) or 3
        local gap     = tonumber(VD.CrossGap) or 6
        local thick   = tonumber(VD.CrossThickness) or 4
        local color   = Color3.fromRGB(
            tonumber(VD.CrossColorR) or 255,
            tonumber(VD.CrossColorG) or 255,
            tonumber(VD.CrossColorB) or 255
        )

        CrosshairGuiNew = Instance.new("ScreenGui")
        CrosshairGuiNew.Name = "MAWWW_Crosshair"
        CrosshairGuiNew.DisplayOrder = 999999
        CrosshairGuiNew.IgnoreGuiInset = true
        CrosshairGuiNew.ResetOnSpawn = false
        CrosshairGuiNew.Parent = PlayerGui
        getgenv().MAWWW_CrosshairGui = CrosshairGuiNew

        local centerFrame = Instance.new("Frame")
        centerFrame.BackgroundTransparency = 1
        centerFrame.Position = UDim2.new(0.5, offsetX, 0.5, offsetY)
        centerFrame.Size = UDim2.new(0, 0, 0, 0)
        centerFrame.Parent = CrosshairGuiNew

        if style == "Dot" then
            local dot = Instance.new("Frame")
            dot.AnchorPoint = Vector2.new(0.5, 0.5)
            dot.Size = UDim2.new(0, size * 2, 0, size * 2)
            dot.BackgroundColor3 = color
            dot.BorderSizePixel = 0
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(1, 0)
            c.Parent = dot
            dot.Parent = centerFrame
        elseif style == "Plus" or style == "X" then
            local length = size * 3
            for i = 1, 4 do
                local line = Instance.new("Frame")
                line.AnchorPoint = Vector2.new(0.5, 0.5)
                line.BackgroundColor3 = color
                line.BorderSizePixel = 0
                local angle = (i - 1) * 90
                if style == "X" then angle = angle + 45 end
                line.Rotation = angle
                line.Size = UDim2.new(0, length, 0, thick)
                local rad = math.rad(angle)
                local dist = gap + (length / 2)
                line.Position = UDim2.new(
                    0, math.floor(math.cos(rad) * dist + 0.5),
                    0, math.floor(math.sin(rad) * dist + 0.5)
                )
                line.Parent = centerFrame
            end
        elseif style == "Box" then
            local half = gap + size * 2
            local t = Instance.new("Frame")
            t.BackgroundColor3 = color
            t.BorderSizePixel = 0
            t.AnchorPoint = Vector2.new(0.5, 0.5)
            t.Size = UDim2.new(0, half * 2 + thick, 0, thick)
            t.Position = UDim2.new(0, 0, 0, -half)
            t.Parent = centerFrame

            local b = t:Clone()
            b.Position = UDim2.new(0, 0, 0, half)
            b.Parent = centerFrame

            local l = Instance.new("Frame")
            l.BackgroundColor3 = color
            l.BorderSizePixel = 0
            l.AnchorPoint = Vector2.new(0.5, 0.5)
            l.Size = UDim2.new(0, thick, 0, half * 2 - thick)
            l.Position = UDim2.new(0, -half, 0, 0)
            l.Parent = centerFrame

            local r = l:Clone()
            r.Position = UDim2.new(0, half, 0, 0)
            r.Parent = centerFrame
        end
    end

    -- Pasang ulang, override fungsi lama (local & global).
    VD_UpdateCrosshair = VD_UpdateCrosshairWithOffset
    getgenv().VD_UpdateCrosshair = VD_UpdateCrosshairWithOffset

    -- Re-render dengan setting saat ini supaya perubahan langsung terlihat.
    pcall(VD_UpdateCrosshair)
end



-- Re-bind crosshair updates to new offset logic
pcall(function()
    if VD.CrossEnabled then
        pcall(getgenv().VD_UpdateCrosshair)
    end
end)
-- CROSSHAIR IS A STANDALONE AIM GROUPBOX (never registered inside Silent Veil V2/V4).
RegDivider(Tabs.AimCrosshair)
RegLabel(Tabs.AimCrosshair, "Crosshair")
RegToggle(Tabs.AimCrosshair, "Enable Crosshair", "Show a screen-center crosshair", false, "CrossEnabled", function(v) pcall(VD_UpdateCrosshair) end)
RegDropdown(Tabs.AimCrosshair, "Style", "Crosshair style", {"Dot", "Plus", "X", "Box"}, "Dot", false, "CrossStyle", function(v) pcall(VD_UpdateCrosshair) end)
RegSlider(Tabs.AimCrosshair, "Size", "Crosshair size", 3, 1, 30, 1, "CrossSize", function(v) pcall(VD_UpdateCrosshair) end)
RegSlider(Tabs.AimCrosshair, "Thickness", "Crosshair thickness", 4, 1, 20, 1, "CrossThickness", function(v) pcall(VD_UpdateCrosshair) end)
RegSlider(Tabs.AimCrosshair, "Gap", "Gap between center and arms", 6, 0, 50, 1, "CrossGap", function(v) pcall(VD_UpdateCrosshair) end)
pcall(function()
    Tabs.AimCrosshair:Colorpicker({
        Title = "Crosshair Color", Flag = "CrossColorPicker", Default = Color3.fromRGB(255, 255, 255),
        Callback = function(c)
            VD.CrossColorR = math.floor(c.R * 255); VD.CrossColorG = math.floor(c.G * 255); VD.CrossColorB = math.floor(c.B * 255)
            pcall(VD_UpdateCrosshair)
        end,
    })
end)

--========================================================--
-- SILENT VEIL V2 (dedicated visuals — no crosshair controls)
--========================================================--
VeilV2 = (function()
    -- Default settings
    if VD.VeilV2AimLock == nil then VD.VeilV2AimLock = true end
    if VD.VeilV2AutoThrow == nil then VD.VeilV2AutoThrow = true end
    if VD.VeilV2UseInterceptor == nil then VD.VeilV2UseInterceptor = true end

    -- =========================================================
    -- V2 DEDICATED VISUALS (WARNA BERBEDA DARI V1)
    -- =========================================================
    local V2_Visuals = (function()
        local V = { FOVOutline = nil, FOVFill = nil, TracerLine = nil, TargetOutline = nil, TargetFill = nil, PlayerCircles = {}, NameLabels = {}, HasDrawing = false }
        pcall(function() if (typeof(Drawing) == "table" or typeof(Drawing) == "userdata") and type(Drawing.new) == "function" then V.HasDrawing = true end end)

        -- Warna V2: Ungu, Hijau, Oranye, Magenta, Kuning
        local COLORS = {
            FOV = Color3.fromRGB(180, 60, 255),     -- Ungu Neon (FOV Circle)
            FOVFill = Color3.fromRGB(180, 60, 255),
            Player = Color3.fromRGB(0, 255, 100),    -- Hijau Neon (Player Marker)
            Target = Color3.fromRGB(255, 140, 0),    -- Oranye Neon (Target Marker)
            Tracer = Color3.fromRGB(255, 0, 200),    -- Magenta Neon (Tracer Line)
            Label = Color3.fromRGB(255, 255, 0),     -- Kuning Neon (Nama/Health/Jarak)
            LabelEnemy = Color3.fromRGB(255, 100, 100)
        }

        local function InitDrawing()
            if not V.HasDrawing then return end
            if not V.FOVOutline then
                V.FOVOutline = Drawing.new("Circle"); V.FOVOutline.Color = COLORS.FOV; V.FOVOutline.Thickness = 2; V.FOVOutline.Filled = false; V.FOVOutline.Transparency = 0.85; V.FOVOutline.Visible = false
            end
            if not V.FOVFill then
                V.FOVFill = Drawing.new("Circle"); V.FOVFill.Color = COLORS.FOVFill; V.FOVFill.Thickness = 1; V.FOVFill.Filled = false; V.FOVFill.Transparency = 0.12; V.FOVFill.Visible = false
            end
            if not V.TracerLine then
                V.TracerLine = Drawing.new("Line"); V.TracerLine.Color = COLORS.Tracer; V.TracerLine.Thickness = 2; V.TracerLine.Transparency = 0.85; V.TracerLine.Visible = false
            end
            if not V.TargetOutline then
                V.TargetOutline = Drawing.new("Circle"); V.TargetOutline.Color = COLORS.Target; V.TargetOutline.Thickness = 3; V.TargetOutline.Filled = false; V.TargetOutline.Transparency = 1; V.TargetOutline.Visible = false
            end
            if not V.TargetFill then
                V.TargetFill = Drawing.new("Circle"); V.TargetFill.Color = COLORS.Target; V.TargetFill.Thickness = 1; V.TargetFill.Filled = false; V.TargetFill.Transparency = 0.4; V.TargetFill.Visible = false
            end
        end

        local function GetPlayerCircle(plr)
            if not V.HasDrawing then return nil end
            local c = V.PlayerCircles[plr]; if c then return c end
            local outline = Drawing.new("Circle"); outline.Color = COLORS.Player; outline.Thickness = 2; outline.Filled = false; outline.Transparency = 1; outline.Visible = false
            local fill = Drawing.new("Circle"); fill.Color = COLORS.Player; fill.Thickness = 1; fill.Filled = false; fill.Transparency = 0.25; fill.Visible = false
            c = { outline = outline, fill = fill }; V.PlayerCircles[plr] = c; return c
        end

        local function GetNameLabel(plr)
            local label = V.NameLabels[plr]; if label and label.Parent then return label end
            local char = plr.Character; if not char then return nil end
            local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"); if not head then return nil end
            local bb = Instance.new("BillboardGui")
            bb.Name = "VeilV2_NameLabel"; bb.Size = UDim2.new(0, 240, 0, 22); bb.StudsOffset = Vector3.new(0, 3.2, 0); bb.AlwaysOnTop = true; bb.Adornee = head; bb.Parent = head
            local lbl = Instance.new("TextLabel")
            lbl.Name = "Text"; lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
            lbl.TextColor3 = COLORS.Label; lbl.TextStrokeTransparency = 0.3; lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            lbl.TextSize = 14; lbl.Font = Enum.Font.GothamBold; lbl.Text = plr.Name; lbl.Parent = bb
            V.NameLabels[plr] = bb; return bb
        end

        function V.UpdateFOV(center, radius, visible)
            InitDrawing(); if not V.HasDrawing then return end
            if V.FOVOutline then V.FOVOutline.Position = center; V.FOVOutline.Radius = radius; V.FOVOutline.Visible = visible end
            if V.FOVFill then V.FOVFill.Position = center; V.FOVFill.Radius = radius; V.FOVFill.Visible = visible end
        end

        function V.UpdateTarget(screenPos, radius, visible)
            InitDrawing(); if not V.HasDrawing then return end
            if V.TargetOutline then V.TargetOutline.Position = screenPos; V.TargetOutline.Radius = radius; V.TargetOutline.Visible = visible end
            if V.TargetFill then V.TargetFill.Position = screenPos; V.TargetFill.Radius = radius; V.TargetFill.Visible = visible end
        end

        function V.UpdateTracer(fromPos, toPos, visible)
            InitDrawing(); if not V.HasDrawing then return end
            if V.TracerLine then V.TracerLine.From = fromPos; V.TracerLine.To = toPos; V.TracerLine.Visible = visible end
        end

        function V.UpdatePlayerMarker(plr, screenPos, radius, visible)
            local c = GetPlayerCircle(plr); if not c then return end
            if c.outline then c.outline.Position = screenPos; c.outline.Radius = radius; c.outline.Visible = visible end
            if c.fill then c.fill.Position = screenPos; c.fill.Radius = radius; c.fill.Visible = visible end
        end

        function V.UpdateNameLabel(plr, text, visible, isTarget)
            if not visible then local lbl = V.NameLabels[plr]; if lbl then lbl.Enabled = false end; return end
            local bb = GetNameLabel(plr); if not bb then return end
            bb.Enabled = true
            local lbl = bb:FindFirstChild("Text")
            if lbl then lbl.Text = text; lbl.TextColor3 = isTarget and COLORS.LabelEnemy or COLORS.Label end
        end

        function V.HideAll()
            if not V.HasDrawing then
                for _, bb in pairs(V.NameLabels) do if bb then bb.Enabled = false end end
                return
            end
            if V.FOVOutline then V.FOVOutline.Visible = false end
            if V.FOVFill then V.FOVFill.Visible = false end
            if V.TracerLine then V.TracerLine.Visible = false end
            if V.TargetOutline then V.TargetOutline.Visible = false end
            if V.TargetFill then V.TargetFill.Visible = false end
            for _, c in pairs(V.PlayerCircles) do
                if c.outline then c.outline.Visible = false end
                if c.fill then c.fill.Visible = false end
            end
            for _, bb in pairs(V.NameLabels) do if bb then bb.Enabled = false end end
        end

        function V.CleanupPlayer(plr)
            local c = V.PlayerCircles[plr]
            if c then
                if c.outline then pcall(function() c.outline:Remove() end) end
                if c.fill then pcall(function() c.fill:Remove() end) end
                V.PlayerCircles[plr] = nil
            end
            local bb = V.NameLabels[plr]
            if bb then pcall(function() bb:Destroy() end); V.NameLabels[plr] = nil end
        end

        Players.PlayerRemoving:Connect(function(p) V.CleanupPlayer(p) end)
        return V
    end)()

    -- =========================================================
    -- V2 CORE LOGIC
    -- =========================================================
    local State = { target = nil, lookVector = nil, lastThrow = 0, velHistory = {} }

    local function IsSurvivorTarget(p)
        if not p or not p.Team or not p.Team.Name then return false end
        return string.find(string.lower(p.Team.Name), "survivor", 1, true) ~= nil
    end

    local function IsDownedChar(char)
        if not char then return false end
        if char:GetAttribute("Knocked") == true then return true end
        if char:GetAttribute("HookProgressDepleting") == true then return true end
        if char:GetAttribute("IsHooked") == true then return true end
        local s = char:GetAttribute("State")
        return s == "Downed" or s == "Dead"
    end

    local function WallCheck(origin, targetPos, targetChar)
        if not VD.VeilV2WallCheck then return true end
        return VD_WallCheckVisible(origin, targetPos, targetChar)
    end

    local function SolvePitch(v0, g, d, dy)
        d = math.max(d, 0.1)
        local s2 = v0 * v0
        local root = s2 * s2 - g * (g * d * d + 2 * dy * s2)
        if root < 0 then root = 0 end
        local tanTheta = (s2 - math.sqrt(root)) / (g * d)
        local theta = math.atan(tanTheta)
        local cosT = math.max(math.cos(theta), 0.001)
        local t = d / (v0 * cosT)
        return theta, t
    end

    local function GetVelocity(char)
        local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
        if not root or not root:IsA("BasePart") then return Vector3.zero end
        local now = os.clock()
        local last = State.velHistory[char]
        local measured = Vector3.zero
        if last and now - last.t > 0.02 then
            measured = (root.Position - last.pos) / (now - last.t)
            if measured.Magnitude > 150 then measured = last.smooth or Vector3.zero end
        end
        local smooth = last and last.smooth or measured
        smooth = smooth:Lerp(measured, 0.65)
        State.velHistory[char] = { pos = root.Position, t = now, smooth = smooth }
        if smooth.Magnitude < 1 then return Vector3.zero end
        return Vector3.new(smooth.X, 0, smooth.Z)
    end

    Players.PlayerRemoving:Connect(function(p)
        if p.Character then State.velHistory[p.Character] = nil end
    end)

    local function GetSpearRemote()
        local remotes = GetRemotes()
        local items = remotes and remotes:FindFirstChild("Items")
        local spear = items and items:FindFirstChild("Spear")
        if not spear then return nil end
        return spear:FindFirstChild("Spearthrow") or spear:FindFirstChild("Throw")
    end

    local function Update()
        if VD.VeilEnabled then -- V1 Prioritas
            State.target = nil
            State.lookVector = nil
            V2_Visuals.HideAll()
            return
        end

        if not VD.VeilV2Enabled then
            State.target = nil
            State.lookVector = nil
            V2_Visuals.HideAll()
            return
        end

        if GetRole() ~= "Killer" then
            State.target = nil
            State.lookVector = nil
            V2_Visuals.HideAll()
            return
        end

        local cam = Workspace.CurrentCamera
        if not cam then return end
        local viewport = cam.ViewportSize
        local center = Vector2.new(viewport.X / 2, viewport.Y / 2)

        V2_Visuals.UpdateFOV(center, VD.VeilV2FOV or 180, VD.VeilV2ShowFOV ~= false)

        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then V2_Visuals.HideAll(); return end

        -- Target Selection (Prioritas Crosshair 90%)
        local nearest, bestScore = nil, math.huge
        local detected = {}

        for _, p in ipairs(MawwwGetPlayers()) do
            if p ~= Player and IsSurvivorTarget(p) and p.Character then
                local pc = p.Character
                local isDown = IsDownedChar(pc)
                local hum = pc:FindFirstChildOfClass("Humanoid")
                local targetPart = pc:FindFirstChild("UpperTorso") or pc:FindFirstChild("Torso") or pc:FindFirstChild("HumanoidRootPart")

                if hum and hum.Health > 0 and targetPart then
                    local visible = true
                    if VD.VeilV2IgnoreDown and isDown then visible = false end

                    if visible and VD.VeilV2WallCheck then
                        if not WallCheck(hrp.Position, targetPart.Position, pc) then visible = false end
                    end

                    local sp, onScreen = cam:WorldToViewportPoint(targetPart.Position)
                    if visible and onScreen and sp.Z > 0 then
                        local screenDist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        local studDist = (targetPart.Position - hrp.Position).Magnitude
                        if screenDist <= (VD.VeilV2FOV or 180) and studDist <= (VD.VeilV2MaxDist or 600) then
                            local maxHealth = math.max(hum.MaxHealth, 1)
                            local health = math.floor((hum.Health / maxHealth) * 100 + 0.5)
                            local score = screenDist * 0.9 + studDist * 0.1
                            table.insert(detected, {
                                plr = p, char = pc, hum = hum, targetPart = targetPart,
                                scrPos = Vector2.new(sp.X, sp.Y), studDist = studDist,
                                health = health, score = score,
                            })
                            if score < bestScore then
                                bestScore = score
                                nearest = p
                            end
                        end
                    end
                end
            end
        end

        table.sort(detected, function(a, b) return a.score < b.score end)
        if detected[1] then nearest = detected[1].plr end

        -- =========================================================
        -- [FIX] Visuals V2 — bersihkan marker/label stale setiap frame
        -- =========================================================
        local isTargetPlr = nearest
        local showMarkers = VD.VeilV2ShowPlayerMarkers == true
        local showNames   = VD.VeilV2ShowNameLabels == true
        local detectedSet = {}

        for _, info in ipairs(detected) do
            local isTarget = (info.plr == isTargetPlr)
            local rad = math.clamp(1500 / math.max(info.studDist, 1), 10, 55)
            detectedSet[info.plr] = true

            -- Kirim visible=false bila toggle OFF supaya circle lama ikut hilang.
            V2_Visuals.UpdatePlayerMarker(info.plr, info.scrPos, rad, showMarkers)

            if showNames then
                local label = string.format(
                    "%s [%d%%] [%dm]",
                    info.plr.DisplayName or info.plr.Name,
                    info.health,
                    math.floor(info.studDist)
                )
                V2_Visuals.UpdateNameLabel(info.plr, label, true, isTarget)
            else
                V2_Visuals.UpdateNameLabel(info.plr, "", false, false)
            end
        end

        -- Hapus tampilan milik player yang tidak terdeteksi pada frame ini.
        -- Ini mencegah marker/label tertinggal saat keluar FOV, mati, atau downed.
        for plr, _ in pairs(V2_Visuals.PlayerCircles) do
            if not detectedSet[plr] then
                V2_Visuals.UpdatePlayerMarker(plr, Vector2.new(0, 0), 0, false)
                V2_Visuals.UpdateNameLabel(plr, "", false, false)
            end
        end

        if not nearest or not nearest.Character then
            State.target = nil
            State.lookVector = nil

            -- Early-return harus tetap membersihkan seluruh marker/label stale.
            for plr, _ in pairs(V2_Visuals.PlayerCircles) do
                V2_Visuals.UpdatePlayerMarker(plr, Vector2.new(0, 0), 0, false)
                V2_Visuals.UpdateNameLabel(plr, "", false, false)
            end

            V2_Visuals.UpdateTarget(Vector2.new(0, 0), 0, false)
            V2_Visuals.UpdateTracer(Vector2.new(0, 0), Vector2.new(0, 0), false)
            return
        end

        local tpPart = nearest.Character:FindFirstChild("UpperTorso") or nearest.Character:FindFirstChild("Torso") or nearest.Character:FindFirstChild("HumanoidRootPart")
        if not tpPart then State.target = nil; State.lookVector = nil; return end

        local hand = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
        local origin = (hand and hand:IsA("BasePart")) and hand.Position or hrp.Position
        local tp = tpPart.Position
        local dir = tp - origin
        local dist = dir.Magnitude

        if dist < 0.1 or dist > (VD.VeilV2MaxDist or 600) then
            State.target = nil; State.lookVector = nil
            return
        end

        -- Advanced Prediction (Gacor)
        local prof = {
            v0 = VD.VeilV2SpearSpeed or 170,
            g  = VD.VeilV2SpearGravity or 100,
            windup = 0.10, latency = 0.04, maxlead = 45,
            scale = VD.VeilV2LeadMultiplier or 1.35,
        }

        local aimPoint = tp
        local vel = GetVelocity(nearest.Character)
        if vel.Magnitude > 0.5 then
            local h0 = Vector3.new(dir.X, 0, dir.Z)
            local _, tFlight = SolvePitch(prof.v0, prof.g, h0.Magnitude, dir.Y)
            local ping = 0.08
            pcall(function() ping = math.clamp(Player:GetNetworkPing(), 0, 0.35) end)
            local delay = tFlight + prof.windup + ping + prof.latency

            local iters = math.max(1, tonumber(VD.VeilV2Iterations) or 10)
            for _ = 1, iters do
                local lead = vel * delay * prof.scale
                local maxLead = math.clamp(dist * 0.6, 3, prof.maxlead)
                if lead.Magnitude > maxLead then lead = lead.Unit * maxLead end
                aimPoint = tp + lead
                local ad = aimPoint - origin
                local ah = Vector3.new(ad.X, 0, ad.Z)
                local _, t2 = SolvePitch(prof.v0, prof.g, math.max(ah.Magnitude, 0.1), ad.Y)
                delay = t2 + prof.windup + ping + prof.latency
            end
        end

        if VD.VeilV2WallCheck then
            if not VD_WallCheckVisible(origin, aimPoint, nil) then aimPoint = tp end
            if not VD_WallCheckVisible(origin, aimPoint, nearest.Character) then
                State.target = nil; State.lookVector = nil
                V2_Visuals.UpdateTarget(Vector2.new(0, 0), 0, false)
                V2_Visuals.UpdateTracer(Vector2.new(0, 0), Vector2.new(0, 0), false)
                return
            end
        end

        local adir = aimPoint - origin
        local ah = Vector3.new(adir.X, 0, adir.Z)
        local ahDist = ah.Magnitude
        local pitch = SolvePitch(prof.v0, prof.g, ahDist, adir.Y)

        if ahDist > 0.001 then
            State.lookVector = ah.Unit * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)
        else
            State.lookVector = adir.Unit
        end
        State.target = nearest

        -- Aim Lock (Putar badan)
        if VD.VeilV2AimLock and not VD.VeilEnabled then
            local flat = Vector3.new(adir.X, 0, adir.Z)
            if flat.Magnitude > 0.05 then
                flat = flat.Unit
                pcall(function()
                    hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + flat)
                end)
            end
        end

        -- Target Marker & Tracer V2
        if VD.VeilV2ShowTargetMarker then
            local sp, vis = cam:WorldToViewportPoint(tpPart.Position)
            if vis and sp.Z > 0 then
                local rad = math.clamp(1500 / math.max(dist, 1), 14, 60)
                V2_Visuals.UpdateTarget(Vector2.new(sp.X, sp.Y), rad, true)
                if VD.VeilV2ShowTracer then
                    local bottomCenter = Vector2.new(center.X, viewport.Y)
                    V2_Visuals.UpdateTracer(bottomCenter, Vector2.new(sp.X, sp.Y), true)
                else
                    V2_Visuals.UpdateTracer(Vector2.new(0, 0), Vector2.new(0, 0), false)
                end
            else
                V2_Visuals.UpdateTarget(Vector2.new(0, 0), 0, false)
                V2_Visuals.UpdateTracer(Vector2.new(0, 0), Vector2.new(0, 0), false)
            end
        else
            V2_Visuals.UpdateTarget(Vector2.new(0, 0), 0, false)
            V2_Visuals.UpdateTracer(Vector2.new(0, 0), Vector2.new(0, 0), false)
        end

        -- Auto Throw (Gacor)
        if VD.VeilV2AutoThrow and not VD.VeilEnabled and typeof(State.lookVector) == "Vector3" then
            local now = os.clock()
            if now - State.lastThrow >= (VD.VeilV2FireDelay or 0.05) then
                State.lastThrow = now
                pcall(function()
                    local remote = GetSpearRemote()
                    if remote and remote:IsA("RemoteEvent") then
                        local gun = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
                        if gun then
                            remote:FireServer(gun, State.lookVector.Unit)
                        end
                    end
                end)
            end
        end
    end

    -- Namecall Interceptor (Silent Aim)
    if typeof(hookmetamethod) == "function" then
        pcall(function()
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                if not checkcaller() and method == "FireServer" then
                    local n = self.Name
                    if (n == "Spearthrow" or n == "Spear" or n == "Throw")
                        and VD.VeilV2Enabled
                        and not VD.VeilEnabled
                        and VD.VeilV2UseInterceptor
                        and typeof(State.lookVector) == "Vector3" then
                        local args = {...}
                        if typeof(args[1]) == "Vector3" then
                            args[1] = State.lookVector
                        elseif typeof(args[2]) == "Vector3" then
                            args[2] = State.lookVector
                        end
                        return oldNamecall(self, unpack(args))
                    end
                end
                return oldNamecall(self, ...)
            end)
        end)
    end

    local VeilV2LastUpdate = 0
    RunService.RenderStepped:Connect(function()
        local now = os.clock()
        if now - VeilV2LastUpdate < 0.05 then return end
        VeilV2LastUpdate = now
        pcall(Update)
    end)
    return { State = State, Visuals = V2_Visuals }
end)()

--========================================================--
-- UI: SILENT VEIL V2
--========================================================--
RegDivider(Tabs.AimVeilV2)
RegLabel(Tabs.AimVeilV2, "Silent Veil V2")
RegToggle(Tabs.AimVeilV2, "Silent Veil V2", "Silent spear aim + aim lock.", false, "VeilV2Enabled")
RegToggle(Tabs.AimVeilV2, "Aim Lock", "Putar badan agar tombak selalu mengejar survivor walau badan membelakangi.", true, "VeilV2AimLock")
RegToggle(Tabs.AimVeilV2, "Auto Throw", "Auto throw spears", true, "VeilV2AutoThrow")
RegToggle(Tabs.AimVeilV2, "Remote Interceptor", "Intercept remote calls", true, "VeilV2UseInterceptor")
RegToggle(Tabs.AimVeilV2, "Wall Check", "Require line of sight", false, "VeilV2WallCheck")
RegToggle(Tabs.AimVeilV2, "Ignore Downed", "Skip downed survivors", true, "VeilV2IgnoreDown")
RegToggle(Tabs.AimVeilV2, "Show FOV Circle", "Show FOV circle", true, "VeilV2ShowFOV")
RegToggle(Tabs.AimVeilV2, "Show Player Markers", "Show player markers", true, "VeilV2ShowPlayerMarkers")
RegToggle(Tabs.AimVeilV2, "Show Target Marker", "Show target marker", true, "VeilV2ShowTargetMarker")
RegToggle(Tabs.AimVeilV2, "Show Tracer", "Show tracer line", true, "VeilV2ShowTracer")
RegToggle(Tabs.AimVeilV2, "Show Player Info", "Show name labels", true, "VeilV2ShowNameLabels")
RegSlider(Tabs.AimVeilV2, "FOV", "FOV radius", 180, 50, 500, 10, "VeilV2FOV")
RegSlider(Tabs.AimVeilV2, "Max Distance", "Max target distance", 600, 50, 1000, 10, "VeilV2MaxDist")
RegSlider(Tabs.AimVeilV2, "Spear Speed", "Spear speed", 170, 50, 400, 5, "VeilV2SpearSpeed")
RegSlider(Tabs.AimVeilV2, "Spear Gravity", "Spear gravity", 100, 10, 300, 5, "VeilV2SpearGravity")
RegSlider(Tabs.AimVeilV2, "Aura Spear Speed", "Aura spear speed", 170, 50, 400, 5, "VeilV2AuraSpearSpeed")
RegSlider(Tabs.AimVeilV2, "Aura Spear Gravity", "Aura spear gravity", 95, 10, 300, 5, "VeilV2AuraSpearGravity")
RegSlider(Tabs.AimVeilV2, "Lead Multiplier", "Lead multiplier", 1.35, 0.1, 5, 0.05, "VeilV2LeadMultiplier")
RegSlider(Tabs.AimVeilV2, "Predict Iterations", "Prediction iterations", 3, 1, 6, 1, "VeilV2Iterations")
RegSlider(Tabs.AimVeilV2, "Fire Delay (s)", "Fire delay", 0.05, 0.02, 1, 0.01, "VeilV2FireDelay")

--========================================================--
-- =====================================================
--========================================================--
-- SILENT VEIL V3 / V4
--========================================================--
do
VeilV3SharedVisuals = (function()
    local V = { FOVOutline = nil, FOVFill = nil, TracerLine = nil, TargetOutline = nil, TargetFill = nil, PlayerCircles = {}, NameLabels = {}, HasDrawing = false, LastFovRadius = -1 }
    pcall(function() if (typeof(Drawing) == "table" or typeof(Drawing) == "userdata") and type(Drawing.new) == "function" then V.HasDrawing = true end end)
    local COLORS = { FOV = Color3.fromRGB(0, 220, 255), FOVFill = Color3.fromRGB(0, 220, 255), Player = Color3.fromRGB(255, 255, 255), Target = Color3.fromRGB(255, 0, 0), Tracer = Color3.fromRGB(255, 255, 255), Label = Color3.fromRGB(60, 255, 60), LabelEnemy = Color3.fromRGB(255, 90, 90) }
    local function InitDrawing()
        if not V.HasDrawing then return end
        if not V.FOVOutline then V.FOVOutline = Drawing.new("Circle"); V.FOVOutline.Color = COLORS.FOV; V.FOVOutline.Thickness = 2; V.FOVOutline.Filled = false; V.FOVOutline.Transparency = 0.85; V.FOVOutline.Visible = false end
        if not V.FOVFill then V.FOVFill = Drawing.new("Circle"); V.FOVFill.Color = COLORS.FOVFill; V.FOVFill.Thickness = 1; V.FOVFill.Filled = false; V.FOVFill.Transparency = 0.12; V.FOVFill.Visible = false end
        if not V.TracerLine then V.TracerLine = Drawing.new("Line"); V.TracerLine.Color = COLORS.Tracer; V.TracerLine.Thickness = 1.5; V.TracerLine.Transparency = 0.75; V.TracerLine.Visible = false end
        if not V.TargetOutline then V.TargetOutline = Drawing.new("Circle"); V.TargetOutline.Color = COLORS.Target; V.TargetOutline.Thickness = 2; V.TargetOutline.Filled = false; V.TargetOutline.Transparency = 1; V.TargetOutline.Visible = false end
        if not V.TargetFill then V.TargetFill = Drawing.new("Circle"); V.TargetFill.Color = COLORS.Target; V.TargetFill.Thickness = 1; V.TargetFill.Filled = false; V.TargetFill.Transparency = 0.4; V.TargetFill.Visible = false end
    end
    local function GetPlayerCircle(plr)
        if not V.HasDrawing then return nil end
        local c = V.PlayerCircles[plr]; if c then return c end
        local outline = Drawing.new("Circle"); outline.Color = COLORS.Player; outline.Thickness = 1.5; outline.Filled = false; outline.Transparency = 1; outline.Visible = false
        local fill = Drawing.new("Circle"); fill.Color = COLORS.Player; fill.Thickness = 1; fill.Filled = false; fill.Transparency = 0.25; fill.Visible = false
        c = { outline = outline, fill = fill }; V.PlayerCircles[plr] = c; return c
    end
    local function GetNameLabel(plr)
        local label = V.NameLabels[plr]; if label and label.Parent then return label end
        local char = plr.Character; if not char then return nil end
        local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"); if not head then return nil end
        local bb = Instance.new("BillboardGui")
        bb.Name = "VeilV3_NameLabel"; bb.Size = UDim2.new(0, 240, 0, 22); bb.StudsOffset = Vector3.new(0, 3.2, 0); bb.AlwaysOnTop = true; bb.Adornee = head; bb.Parent = head
        local lbl = Instance.new("TextLabel")
        lbl.Name = "Text"; lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
        lbl.TextColor3 = COLORS.Label; lbl.TextStrokeTransparency = 0.3; lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.TextSize = 14; lbl.Font = Enum.Font.GothamBold; lbl.Text = plr.Name; lbl.Parent = bb
        V.NameLabels[plr] = bb; return bb
    end
    function V.UpdateFOV(center, radius, visible)
        InitDrawing(); if not V.HasDrawing then return end
        if V.FOVOutline then V.FOVOutline.Position = center; V.FOVOutline.Radius = radius; V.FOVOutline.Visible = visible end
        if V.FOVFill then V.FOVFill.Position = center; V.FOVFill.Radius = radius; V.FOVFill.Visible = visible end
        V.LastFovRadius = radius
    end
    function V.UpdateTarget(screenPos, radius, visible)
        InitDrawing(); if not V.HasDrawing then return end
        if V.TargetOutline then V.TargetOutline.Position = screenPos; V.TargetOutline.Radius = radius; V.TargetOutline.Visible = visible end
        if V.TargetFill then V.TargetFill.Position = screenPos; V.TargetFill.Radius = radius; V.TargetFill.Visible = visible end
    end
    function V.UpdateTracer(fromPos, toPos, visible)
        InitDrawing(); if not V.HasDrawing then return end
        if V.TracerLine then V.TracerLine.From = fromPos; V.TracerLine.To = toPos; V.TracerLine.Visible = visible end
    end
    function V.UpdatePlayerMarker(plr, screenPos, radius, visible)
        local c = GetPlayerCircle(plr); if not c then return end
        if c.outline then c.outline.Position = screenPos; c.outline.Radius = radius; c.outline.Visible = visible end
        if c.fill then c.fill.Position = screenPos; c.fill.Radius = radius; c.fill.Visible = visible end
    end
    function V.HideAllPlayerMarkers()
        for _, c in pairs(V.PlayerCircles) do
            if c.outline then c.outline.Visible = false end
            if c.fill then c.fill.Visible = false end
        end
    end
    function V.UpdateNameLabel(plr, text, visible, isTarget)
        if not visible then local lbl = V.NameLabels[plr]; if lbl then lbl.Enabled = false end; return end
        local bb = GetNameLabel(plr); if not bb then return end
        bb.Enabled = true
        local lbl = bb:FindFirstChild("Text")
        if lbl then lbl.Text = text; lbl.TextColor3 = isTarget and COLORS.LabelEnemy or COLORS.Label end
    end
    function V.HideAllNameLabels() for _, bb in pairs(V.NameLabels) do if bb then bb.Enabled = false end end end
    function V.HideAll()
        if not V.HasDrawing then V.HideAllNameLabels(); return end
        if V.FOVOutline then V.FOVOutline.Visible = false end
        if V.FOVFill then V.FOVFill.Visible = false end
        if V.TracerLine then V.TracerLine.Visible = false end
        if V.TargetOutline then V.TargetOutline.Visible = false end
        if V.TargetFill then V.TargetFill.Visible = false end
        V.HideAllPlayerMarkers(); V.HideAllNameLabels()
    end
    function V.CleanupPlayer(plr)
        local c = V.PlayerCircles[plr]
        if c then
            if c.outline then pcall(function() c.outline:Remove() end) end
            if c.fill then pcall(function() c.fill:Remove() end) end
            V.PlayerCircles[plr] = nil
        end
        local bb = V.NameLabels[plr]
        if bb then pcall(function() bb:Destroy() end); V.NameLabels[plr] = nil end
    end
    Players.PlayerRemoving:Connect(function(p) V.CleanupPlayer(p) end)
    return V
end)()

VeilV3State = { target = nil, lookVector = nil, velHistory = {}, lastThrow = 0 }

-- [FIX] Detect whether Veil killer has Aura active (spear speed/gravity differ).
function VeilV3_HasAura()
    local char = Player.Character
    if not char then return false end
    for _, key in ipairs({"AuraActive", "HasAura", "Aura", "Enraged", "UltimateActive"}) do
        local v = char:GetAttribute(key)
        if v == true then return true end
    end
    return false
end
function VeilV3_GetSpearProfile()
    if VeilV3_HasAura() then
        return {
            v0 = tonumber(VD.VeilAuraSpearSpeedV3) or 165,
            g = tonumber(VD.VeilAuraSpearGravityV3) or 96.5,
        }
    end
    return {
        v0 = tonumber(VD.VeilSpearSpeedV3) or 165,
        g = tonumber(VD.VeilGravityV3) or 103,
    }
end
-- [FIX] V1 spear remote lookup (multi-pattern).
function VeilV3_GetSpearRemote()
    local remotes = GetRemotes()
    local items = remotes and remotes:FindFirstChild("Items")
    local spear = items and items:FindFirstChild("Spear")
    if not spear then return nil end
    return spear:FindFirstChild("Spearthrow") or spear:FindFirstChild("Throw") or spear:FindFirstChildWhichIsA("RemoteEvent")
end
function VeilV3_IsSurvivorVeil(p) if not p or not p.Team or not p.Team.Name then return false end; return string.find(string.lower(p.Team.Name), "survivor", 1, true) ~= nil end
function VeilV3_solvePitch(p, d, dy)
    d = math.max(d, 0.1)
    local s2 = p.v0 * p.v0
    local root = s2 * s2 - p.g * (p.g * d * d + 2 * dy * s2)
    if root < 0 then root = 0 end
    local tanTheta = (s2 - math.sqrt(root)) / (p.g * d)
    local theta = math.atan(tanTheta)
    local cosT = math.max(math.cos(theta), 0.001)
    local t = d / (p.v0 * cosT)
    return theta, t
end
function VeilV3_getCharacterVelocity(char)
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
    if not root or not root:IsA("BasePart") then return Vector3.zero end
    local now = os.clock()
    local last = VeilV3State.velHistory[char]
    local measured = Vector3.zero
    if last and now - last.t > 0.02 then
        measured = (root.Position - last.pos) / (now - last.t)
        if measured.Magnitude > 150 then measured = last.smooth or Vector3.zero end
    end
    local smooth = last and last.smooth or measured
    smooth = smooth:Lerp(measured, 0.65)
    VeilV3State.velHistory[char] = { pos = root.Position, t = now, smooth = smooth }
    if smooth.Magnitude < 0.5 then return Vector3.zero end -- [FIX] threshold rendah agar pelan/crouch tetap diprediksi
    return Vector3.new(smooth.X, 0, smooth.Z)
end
Players.PlayerRemoving:Connect(function(p) if p.Character then VeilV3State.velHistory[p.Character] = nil end end)
function VeilV3_WallCheck(origin, targetPos, targetChar)
    if not VD.VeilWallCheckV3 then return true end
    return VD_WallCheckVisible(origin, targetPos, targetChar)
end
function VeilV3_UpdateAimbot()
    if not VD.VeilV3Enabled then
        VeilV3State.target = nil
        VeilV3State.lookVector = nil
        VeilV3SharedVisuals.HideAll()
        return
    end

    if GetRole() ~= "Killer" then
        VeilV3State.target = nil
        VeilV3State.lookVector = nil
        VeilV3SharedVisuals.HideAll()
        return
    end

    local cam = Workspace.CurrentCamera
    if not cam then return end

    local viewport = cam.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
    local showFov = VD.VeilShowFOVV3 and VD.VeilV3Enabled
    VeilV3SharedVisuals.UpdateFOV(center, VD.VeilFOVV3 or 150, showFov)

    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        VeilV3SharedVisuals.HideAll()
        return
    end

    local nearest, bestScore = nil, math.huge
    local bestStudDist = VD.VeilMaxDistV3 or 400
    local detected = {}

    for _, p in ipairs(MawwwGetPlayers()) do
        if p ~= Player and VeilV3_IsSurvivorVeil(p) and p.Character then
            local pc = p.Character
            local isDown = pc:GetAttribute("Knocked") == true
                or pc:GetAttribute("HookProgressDepleting") == true
                or pc:GetAttribute("IsHooked") == true

            local hum = pc:FindFirstChildOfClass("Humanoid")
            local targetPart = pc:FindFirstChild("UpperTorso")
                or pc:FindFirstChild("Torso")
                or pc:FindFirstChild("HumanoidRootPart")

            if hum and hum.Health > 0 and targetPart then
                local visible = true
                if VD.VeilIgnoreDownV3 and isDown then visible = false end
                if visible and VD.VeilWallCheckV3 then
                    if not VeilV3_WallCheck(hrp.Position, targetPart.Position, pc) then visible = false end
                end

                local sp, onScreen = cam:WorldToViewportPoint(targetPart.Position)
                if visible and onScreen and sp.Z > 0 then
                    local screenDist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    local studDist = (targetPart.Position - hrp.Position).Magnitude

                    if screenDist <= (VD.VeilFOVV3 or 150) and studDist <= bestStudDist then
                        local maxHealth = math.max(hum.MaxHealth, 1)
                        local health = math.floor((hum.Health / maxHealth) * 100 + 0.5)
                        local score = screenDist * 0.7 + studDist * 0.3

                        table.insert(detected, {
                            plr = p, char = pc, hum = hum, targetPart = targetPart,
                            scrPos = Vector2.new(sp.X, sp.Y), studDist = studDist,
                            health = health, screenDist = screenDist, score = score,
                        })

                        if score < bestScore then bestScore = score; nearest = p end
                    end
                end
            end
        end
    end

    table.sort(detected, function(a, b) return a.score < b.score end)
    if detected[1] then nearest = detected[1].plr end

    local showMarkers = VD.VeilShowPlayerMarkersV3
    local showNames = VD.VeilShowNameLabelsV3
    local showTarget = VD.VeilShowTargetMarkerV3
    local showTracer = VD.VeilShowTracerV3
    local isTargetPlr = nearest

    for _, info in ipairs(detected) do
        local plr = info.plr
        local isTarget = (plr == isTargetPlr)

        if showMarkers then
            local rad = math.clamp(1500 / math.max(info.studDist, 1), 10, 55)
            VeilV3SharedVisuals.UpdatePlayerMarker(plr, info.scrPos, rad, true)
        else
            VeilV3SharedVisuals.UpdatePlayerMarker(plr, Vector2.new(0, 0), 0, false)
        end

        if showNames then
            local labelText = string.format("%s [%d%%] [%dm]", plr.DisplayName or plr.Name, info.health, math.floor(info.studDist))
            VeilV3SharedVisuals.UpdateNameLabel(plr, labelText, true, isTarget)
        else
            VeilV3SharedVisuals.UpdateNameLabel(plr, "", false, false)
        end
    end

    local detectedSet = {}
    for _, info in ipairs(detected) do detectedSet[info.plr] = true end
    for plr, _ in pairs(VeilV3SharedVisuals.PlayerCircles) do
        if not detectedSet[plr] then
            VeilV3SharedVisuals.UpdatePlayerMarker(plr, Vector2.new(0, 0), 0, false)
            VeilV3SharedVisuals.UpdateNameLabel(plr, "", false, false)
        end
    end

    if nearest and nearest.Character then
        local tpPart = nearest.Character:FindFirstChild("UpperTorso") or nearest.Character:FindFirstChild("Torso") or nearest.Character:FindFirstChild("HumanoidRootPart")
        if tpPart then
            local tp = tpPart.Position
            local hand = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
            local origin = (hand and hand:IsA("BasePart")) and hand.Position or hrp.Position
            local dir = tp - origin
            local dist = dir.Magnitude

            if dist > 0.1 and dist <= (VD.VeilMaxDistV3 or 400) then
                local _sp = VeilV3_GetSpearProfile()
                local prof = {
                    v0 = _sp.v0,
                    g = _sp.g,
                    windup = 0.10, latency = 0.04,
                    maxlead = 45, scale = VD.VeilLeadMultiplierV3 or 1.4,
                }

                local aimPoint = tp
                if VD.VeilAutoPredictV3 then
                    local vel = VeilV3_getCharacterVelocity(nearest.Character)
                    if vel.Magnitude > 0.5 then
                        local h0 = Vector3.new(dir.X, 0, dir.Z)
                        local _, tFlight = VeilV3_solvePitch(prof, h0.Magnitude, dir.Y)
                        local ping = 0.08
                        pcall(function() ping = math.clamp(Player:GetNetworkPing(), 0, 0.35) end)
                        local delay = tFlight + prof.windup + ping + prof.latency
                        for _ = 1, 3 do
                            local lead = vel * delay * prof.scale
                            local maxLead = math.clamp(dist * 0.6, 3, prof.maxlead)
                            if lead.Magnitude > maxLead then lead = lead.Unit * maxLead end
                            aimPoint = tp + lead
                            local ad = aimPoint - origin
                            local ah = Vector3.new(ad.X, 0, ad.Z)
                            local _, t2 = VeilV3_solvePitch(prof, math.max(ah.Magnitude, 0.1), ad.Y)
                            delay = t2 + prof.windup + ping + prof.latency
                        end
                    end
                end

                if VD.VeilWallCheckV3 then
                    if not VD_WallCheckVisible(origin, aimPoint, nil) then aimPoint = tp end
                    if not VD_WallCheckVisible(origin, aimPoint, nearest.Character) then
                        VeilV3State.target = nil; VeilV3State.lookVector = nil
                        VeilV3SharedVisuals.UpdateTarget(Vector2.new(0, 0), 0, false)
                        VeilV3SharedVisuals.UpdateTracer(Vector2.new(0, 0), Vector2.new(0, 0), false)
                        return
                    end
                end

                local adir = aimPoint - origin
                local ah = Vector3.new(adir.X, 0, adir.Z)
                local ahDist = ah.Magnitude
                local pitch = VeilV3_solvePitch(prof, ahDist, adir.Y)

                if ahDist > 0.001 then
                    VeilV3State.lookVector = ah.Unit * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)
                else
                    VeilV3State.lookVector = adir.Unit
                end
                VeilV3State.target = nearest

                if showTarget and tpPart then
                    local sp, vis = cam:WorldToViewportPoint(tpPart.Position)
                    if vis and sp.Z > 0 then
                        local rad = math.clamp(1500 / math.max(dist, 1), 14, 60)
                        VeilV3SharedVisuals.UpdateTarget(Vector2.new(sp.X, sp.Y), rad, true)
                        if showTracer then
                            local bottomCenter = Vector2.new(center.X, viewport.Y)
                            VeilV3SharedVisuals.UpdateTracer(bottomCenter, Vector2.new(sp.X, sp.Y), true)
                        else
                            VeilV3SharedVisuals.UpdateTracer(Vector2.new(0, 0), Vector2.new(0, 0), false)
                        end
                    else
                        VeilV3SharedVisuals.UpdateTarget(Vector2.new(0, 0), 0, false)
                        VeilV3SharedVisuals.UpdateTracer(Vector2.new(0, 0), Vector2.new(0, 0), false)
                    end
                else
                    VeilV3SharedVisuals.UpdateTarget(Vector2.new(0, 0), 0, false)
                    VeilV3SharedVisuals.UpdateTracer(Vector2.new(0, 0), Vector2.new(0, 0), false)
                end
            end
        end
    else
        VeilV3SharedVisuals.UpdateTarget(Vector2.new(0, 0), 0, false)
        VeilV3SharedVisuals.UpdateTracer(Vector2.new(0, 0), Vector2.new(0, 0), false)
        VeilV3State.target = nil
        VeilV3State.lookVector = nil
    end
end
VeilV3HookState = { remoteHooked = false }
function VeilV3_setupInterceptor()
    if VeilV3HookState.remoteHooked then return end
    if typeof(hookmetamethod) ~= "function" then return end
    task.spawn(function()
        pcall(function()
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                if not checkcaller() and method == "FireServer" then
                    local _n = self.Name or ""
                    if (_n == "Spearthrow" or _n == "Spear" or _n == "Throw") and VD.VeilV3Enabled and not VD.VeilV4Enabled and typeof(VeilV3State.lookVector) == "Vector3" and GetRole() == "Killer" then
                        local args = {...}
                        if typeof(args[1]) == "Vector3" then args[1] = VeilV3State.lookVector
                        elseif typeof(args[2]) == "Vector3" then args[2] = VeilV3State.lookVector end
                        return oldNamecall(self, unpack(args))
                    end
                end
                return oldNamecall(self, ...)
            end)
            VeilV3HookState.remoteHooked = true
        end)
    end)
end
VeilV3_setupInterceptor()
-- [FIX] V1 auto-throw: when enabled, fire spear at predicted target automatically.
VeilV3_AutoThrowConn = nil
function VeilV3_AutoThrowStep()
    if not VD.VeilV3Enabled or VD.VeilV4Enabled then return end
    if GetRole() ~= "Killer" then return end
    if typeof(VeilV3State.lookVector) ~= "Vector3" then return end
    if not VD.VeilAutoThrowV3 then return end
    local now = os.clock()
    if now - VeilV3State.lastThrow < (tonumber(VD.VeilFireDelayV3) or 0.08) then return end
    VeilV3State.lastThrow = now
    pcall(function()
        local remote = VeilV3_GetSpearRemote()
        if not remote then return end
        local char = Player.Character
        local gun = char and (char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand"))
        local dir = VeilV3State.lookVector.Unit
        -- Multi-pattern fire.
        if gun then
            local ok = pcall(function() remote:FireServer(gun, dir) end)
            if ok then return end
        end
        pcall(function() remote:FireServer(dir) end)
    end)
end
local VeilV3LastUpdate = 0
RunService.RenderStepped:Connect(function()
    local now = os.clock()
    if now - VeilV3LastUpdate < 0.05 then return end
    VeilV3LastUpdate = now
    pcall(VeilV3_UpdateAimbot)
    pcall(VeilV3_AutoThrowStep)
end)
end
VeilV4 = {}
do
    local okModule, moduleResult = pcall(function()
        return (function()
    -- Default settings
    if VD.VeilV4AimLock == nil then VD.VeilV4AimLock = true end
    if VD.VeilV4AutoThrow == nil then VD.VeilV4AutoThrow = true end
    if VD.VeilV4UseInterceptor == nil then VD.VeilV4UseInterceptor = true end

    -- =========================================================
    -- V2 DEDICATED VISUALS (WARNA BERBEDA DARI V1)
    -- =========================================================
    local V4_Visuals = (function()
        local V = { FOVOutline = nil, FOVFill = nil, TracerLine = nil, TargetOutline = nil, TargetFill = nil, PlayerCircles = {}, NameLabels = {}, HasDrawing = false }
        pcall(function() if (typeof(Drawing) == "table" or typeof(Drawing) == "userdata") and type(Drawing.new) == "function" then V.HasDrawing = true end end)

        -- Warna V2: Ungu, Hijau, Oranye, Magenta, Kuning
        local COLORS = {
            FOV = Color3.fromRGB(180, 60, 255),     -- Ungu Neon (FOV Circle)
            FOVFill = Color3.fromRGB(180, 60, 255),
            Player = Color3.fromRGB(0, 255, 100),    -- Hijau Neon (Player Marker)
            Target = Color3.fromRGB(255, 140, 0),    -- Oranye Neon (Target Marker)
            Tracer = Color3.fromRGB(255, 0, 200),    -- Magenta Neon (Tracer Line)
            Label = Color3.fromRGB(255, 255, 0),     -- Kuning Neon (Nama/Health/Jarak)
            LabelEnemy = Color3.fromRGB(255, 100, 100)
        }

        local function InitDrawing()
            if not V.HasDrawing then return end
            if not V.FOVOutline then
                V.FOVOutline = Drawing.new("Circle"); V.FOVOutline.Color = COLORS.FOV; V.FOVOutline.Thickness = 2; V.FOVOutline.Filled = false; V.FOVOutline.Transparency = 0.85; V.FOVOutline.Visible = false
            end
            if not V.FOVFill then
                V.FOVFill = Drawing.new("Circle"); V.FOVFill.Color = COLORS.FOVFill; V.FOVFill.Thickness = 1; V.FOVFill.Filled = false; V.FOVFill.Transparency = 0.12; V.FOVFill.Visible = false
            end
            if not V.TracerLine then
                V.TracerLine = Drawing.new("Line"); V.TracerLine.Color = COLORS.Tracer; V.TracerLine.Thickness = 2; V.TracerLine.Transparency = 0.85; V.TracerLine.Visible = false
            end
            if not V.TargetOutline then
                V.TargetOutline = Drawing.new("Circle"); V.TargetOutline.Color = COLORS.Target; V.TargetOutline.Thickness = 3; V.TargetOutline.Filled = false; V.TargetOutline.Transparency = 1; V.TargetOutline.Visible = false
            end
            if not V.TargetFill then
                V.TargetFill = Drawing.new("Circle"); V.TargetFill.Color = COLORS.Target; V.TargetFill.Thickness = 1; V.TargetFill.Filled = false; V.TargetFill.Transparency = 0.4; V.TargetFill.Visible = false
            end
        end

        local function GetPlayerCircle(plr)
            if not V.HasDrawing then return nil end
            local c = V.PlayerCircles[plr]; if c then return c end
            local outline = Drawing.new("Circle"); outline.Color = COLORS.Player; outline.Thickness = 2; outline.Filled = false; outline.Transparency = 1; outline.Visible = false
            local fill = Drawing.new("Circle"); fill.Color = COLORS.Player; fill.Thickness = 1; fill.Filled = false; fill.Transparency = 0.25; fill.Visible = false
            c = { outline = outline, fill = fill }; V.PlayerCircles[plr] = c; return c
        end

        local function GetNameLabel(plr)
            local label = V.NameLabels[plr]; if label and label.Parent then return label end
            local char = plr.Character; if not char then return nil end
            local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"); if not head then return nil end
            local bb = Instance.new("BillboardGui")
            bb.Name = "VeilV4_NameLabel"; bb.Size = UDim2.new(0, 240, 0, 22); bb.StudsOffset = Vector3.new(0, 3.2, 0); bb.AlwaysOnTop = true; bb.Adornee = head; bb.Parent = head
            local lbl = Instance.new("TextLabel")
            lbl.Name = "Text"; lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
            lbl.TextColor3 = COLORS.Label; lbl.TextStrokeTransparency = 0.3; lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            lbl.TextSize = 14; lbl.Font = Enum.Font.GothamBold; lbl.Text = plr.Name; lbl.Parent = bb
            V.NameLabels[plr] = bb; return bb
        end

        function V.UpdateFOV(center, radius, visible)
            InitDrawing(); if not V.HasDrawing then return end
            if V.FOVOutline then V.FOVOutline.Position = center; V.FOVOutline.Radius = radius; V.FOVOutline.Visible = visible end
            if V.FOVFill then V.FOVFill.Position = center; V.FOVFill.Radius = radius; V.FOVFill.Visible = visible end
        end

        function V.UpdateTarget(screenPos, radius, visible)
            InitDrawing(); if not V.HasDrawing then return end
            if V.TargetOutline then V.TargetOutline.Position = screenPos; V.TargetOutline.Radius = radius; V.TargetOutline.Visible = visible end
            if V.TargetFill then V.TargetFill.Position = screenPos; V.TargetFill.Radius = radius; V.TargetFill.Visible = visible end
        end

        function V.UpdateTracer(fromPos, toPos, visible)
            InitDrawing(); if not V.HasDrawing then return end
            if V.TracerLine then V.TracerLine.From = fromPos; V.TracerLine.To = toPos; V.TracerLine.Visible = visible end
        end

        function V.UpdatePlayerMarker(plr, screenPos, radius, visible)
            local c = GetPlayerCircle(plr); if not c then return end
            if c.outline then c.outline.Position = screenPos; c.outline.Radius = radius; c.outline.Visible = visible end
            if c.fill then c.fill.Position = screenPos; c.fill.Radius = radius; c.fill.Visible = visible end
        end

        function V.UpdateNameLabel(plr, text, visible, isTarget)
            if not visible then local lbl = V.NameLabels[plr]; if lbl then lbl.Enabled = false end; return end
            local bb = GetNameLabel(plr); if not bb then return end
            bb.Enabled = true
            local lbl = bb:FindFirstChild("Text")
            if lbl then lbl.Text = text; lbl.TextColor3 = isTarget and COLORS.LabelEnemy or COLORS.Label end
        end

        function V.HideAll()
            if not V.HasDrawing then
                for _, bb in pairs(V.NameLabels) do if bb then bb.Enabled = false end end
                return
            end
            if V.FOVOutline then V.FOVOutline.Visible = false end
            if V.FOVFill then V.FOVFill.Visible = false end
            if V.TracerLine then V.TracerLine.Visible = false end
            if V.TargetOutline then V.TargetOutline.Visible = false end
            if V.TargetFill then V.TargetFill.Visible = false end
            for _, c in pairs(V.PlayerCircles) do
                if c.outline then c.outline.Visible = false end
                if c.fill then c.fill.Visible = false end
            end
            for _, bb in pairs(V.NameLabels) do if bb then bb.Enabled = false end end
        end

        function V.CleanupPlayer(plr)
            local c = V.PlayerCircles[plr]
            if c then
                if c.outline then pcall(function() c.outline:Remove() end) end
                if c.fill then pcall(function() c.fill:Remove() end) end
                V.PlayerCircles[plr] = nil
            end
            local bb = V.NameLabels[plr]
            if bb then pcall(function() bb:Destroy() end); V.NameLabels[plr] = nil end
        end

        Players.PlayerRemoving:Connect(function(p) V.CleanupPlayer(p) end)
        return V
    end)()

    -- =========================================================
    -- V2 CORE LOGIC
    -- =========================================================
    local State = { target = nil, lookVector = nil, lastThrow = 0, velHistory = {} }

    local function IsSurvivorTarget(p)
        if not p or not p.Team or not p.Team.Name then return false end
        return string.find(string.lower(p.Team.Name), "survivor", 1, true) ~= nil
    end

    local function IsDownedChar(char)
        if not char then return false end
        if char:GetAttribute("Knocked") == true then return true end
        if char:GetAttribute("HookProgressDepleting") == true then return true end
        if char:GetAttribute("IsHooked") == true then return true end
        local s = char:GetAttribute("State")
        return s == "Downed" or s == "Dead"
    end

    local function WallCheck(origin, targetPos, targetChar)
        if not VD.VeilV4WallCheck then return true end
        return VD_WallCheckVisible(origin, targetPos, targetChar)
    end

    local function SolvePitch(v0, g, d, dy)
        d = math.max(d, 0.1)
        local s2 = v0 * v0
        local root = s2 * s2 - g * (g * d * d + 2 * dy * s2)
        if root < 0 then root = 0 end
        local tanTheta = (s2 - math.sqrt(root)) / (g * d)
        local theta = math.atan(tanTheta)
        local cosT = math.max(math.cos(theta), 0.001)
        local t = d / (v0 * cosT)
        return theta, t
    end

    local function GetVelocity(char)
        local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
        if not root or not root:IsA("BasePart") then return Vector3.zero end
        local now = os.clock()
        local last = State.velHistory[char]
        local measured = Vector3.zero
        if last and now - last.t > 0.02 then
            measured = (root.Position - last.pos) / (now - last.t)
            if measured.Magnitude > 150 then measured = last.smooth or Vector3.zero end
        end
        local smooth = last and last.smooth or measured
        smooth = smooth:Lerp(measured, 0.65)
        State.velHistory[char] = { pos = root.Position, t = now, smooth = smooth }
        if smooth.Magnitude < 1 then return Vector3.zero end
        return Vector3.new(smooth.X, 0, smooth.Z)
    end

    Players.PlayerRemoving:Connect(function(p)
        if p.Character then State.velHistory[p.Character] = nil end
    end)

    local function GetSpearRemote()
        local remotes = GetRemotes()
        local items = remotes and remotes:FindFirstChild("Items")
        local spear = items and items:FindFirstChild("Spear")
        if not spear then return nil end
        return spear:FindFirstChild("Spearthrow") or spear:FindFirstChild("Throw")
    end

    local function Update()
        if VD.VeilV3Enabled then -- V1 Prioritas
            State.target = nil
            State.lookVector = nil
            V4_Visuals.HideAll()
            return
        end

        if not VD.VeilV4Enabled then
            State.target = nil
            State.lookVector = nil
            V4_Visuals.HideAll()
            return
        end

        if GetRole() ~= "Killer" then
            State.target = nil
            State.lookVector = nil
            V4_Visuals.HideAll()
            return
        end

        local cam = Workspace.CurrentCamera
        if not cam then return end
        local viewport = cam.ViewportSize
        local center = Vector2.new(viewport.X / 2, viewport.Y / 2)

        V4_Visuals.UpdateFOV(center, VD.VeilV4FOV or 180, VD.VeilV4ShowFOV ~= false)

        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then V4_Visuals.HideAll(); return end

        -- Target Selection (Prioritas Crosshair 90%)
        local nearest, bestScore = nil, math.huge
        local detected = {}

        for _, p in ipairs(MawwwGetPlayers()) do
            if p ~= Player and IsSurvivorTarget(p) and p.Character then
                local pc = p.Character
                local isDown = IsDownedChar(pc)
                local hum = pc:FindFirstChildOfClass("Humanoid")
                local targetPart = pc:FindFirstChild("UpperTorso") or pc:FindFirstChild("Torso") or pc:FindFirstChild("HumanoidRootPart")

                if hum and hum.Health > 0 and targetPart then
                    local visible = true
                    if VD.VeilV4IgnoreDown and isDown then visible = false end

                    if visible and VD.VeilV4WallCheck then
                        if not WallCheck(hrp.Position, targetPart.Position, pc) then visible = false end
                    end

                    local sp, onScreen = cam:WorldToViewportPoint(targetPart.Position)
                    if visible and onScreen and sp.Z > 0 then
                        local screenDist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        local studDist = (targetPart.Position - hrp.Position).Magnitude
                        if screenDist <= (VD.VeilV4FOV or 180) and studDist <= (VD.VeilV4MaxDist or 600) then
                            local maxHealth = math.max(hum.MaxHealth, 1)
                            local health = math.floor((hum.Health / maxHealth) * 100 + 0.5)
                            local score = screenDist * 0.9 + studDist * 0.1
                            table.insert(detected, {
                                plr = p, char = pc, hum = hum, targetPart = targetPart,
                                scrPos = Vector2.new(sp.X, sp.Y), studDist = studDist,
                                health = health, score = score,
                            })
                            if score < bestScore then
                                bestScore = score
                                nearest = p
                            end
                        end
                    end
                end
            end
        end

        table.sort(detected, function(a, b) return a.score < b.score end)
        if detected[1] then nearest = detected[1].plr end

        -- =========================================================
        -- [FIX] Visuals V2 — bersihkan marker/label stale setiap frame
        -- =========================================================
        local isTargetPlr = nearest
        local showMarkers = VD.VeilV4ShowPlayerMarkers == true
        local showNames   = VD.VeilV4ShowNameLabels == true
        local detectedSet = {}

        for _, info in ipairs(detected) do
            local isTarget = (info.plr == isTargetPlr)
            local rad = math.clamp(1500 / math.max(info.studDist, 1), 10, 55)
            detectedSet[info.plr] = true

            -- Kirim visible=false bila toggle OFF supaya circle lama ikut hilang.
            V4_Visuals.UpdatePlayerMarker(info.plr, info.scrPos, rad, showMarkers)

            if showNames then
                local label = string.format(
                    "%s [%d%%] [%dm]",
                    info.plr.DisplayName or info.plr.Name,
                    info.health,
                    math.floor(info.studDist)
                )
                V4_Visuals.UpdateNameLabel(info.plr, label, true, isTarget)
            else
                V4_Visuals.UpdateNameLabel(info.plr, "", false, false)
            end
        end

        -- Hapus tampilan milik player yang tidak terdeteksi pada frame ini.
        -- Ini mencegah marker/label tertinggal saat keluar FOV, mati, atau downed.
        for plr, _ in pairs(V4_Visuals.PlayerCircles) do
            if not detectedSet[plr] then
                V4_Visuals.UpdatePlayerMarker(plr, Vector2.new(0, 0), 0, false)
                V4_Visuals.UpdateNameLabel(plr, "", false, false)
            end
        end

        if not nearest or not nearest.Character then
            State.target = nil
            State.lookVector = nil

            -- Early-return harus tetap membersihkan seluruh marker/label stale.
            for plr, _ in pairs(V4_Visuals.PlayerCircles) do
                V4_Visuals.UpdatePlayerMarker(plr, Vector2.new(0, 0), 0, false)
                V4_Visuals.UpdateNameLabel(plr, "", false, false)
            end

            V4_Visuals.UpdateTarget(Vector2.new(0, 0), 0, false)
            V4_Visuals.UpdateTracer(Vector2.new(0, 0), Vector2.new(0, 0), false)
            return
        end

        local tpPart = nearest.Character:FindFirstChild("UpperTorso") or nearest.Character:FindFirstChild("Torso") or nearest.Character:FindFirstChild("HumanoidRootPart")
        if not tpPart then State.target = nil; State.lookVector = nil; return end

        local hand = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
        local origin = (hand and hand:IsA("BasePart")) and hand.Position or hrp.Position
        local tp = tpPart.Position
        local dir = tp - origin
        local dist = dir.Magnitude

        if dist < 0.1 or dist > (VD.VeilV4MaxDist or 600) then
            State.target = nil; State.lookVector = nil
            return
        end

        -- Advanced Prediction (Gacor)
        local prof = {
            v0 = VD.VeilV4SpearSpeed or 170,
            g  = VD.VeilV4SpearGravity or 100,
            windup = 0.10, latency = 0.04, maxlead = 45,
            scale = VD.VeilV4LeadMultiplier or 1.35,
        }

        local aimPoint = tp
        local vel = GetVelocity(nearest.Character)
        if vel.Magnitude > 0.5 then
            local h0 = Vector3.new(dir.X, 0, dir.Z)
            local _, tFlight = SolvePitch(prof.v0, prof.g, h0.Magnitude, dir.Y)
            local ping = 0.08
            pcall(function() ping = math.clamp(Player:GetNetworkPing(), 0, 0.35) end)
            local delay = tFlight + prof.windup + ping + prof.latency

            local iters = math.max(1, tonumber(VD.VeilV4Iterations) or 10)
            for _ = 1, iters do
                local lead = vel * delay * prof.scale
                local maxLead = math.clamp(dist * 0.6, 3, prof.maxlead)
                if lead.Magnitude > maxLead then lead = lead.Unit * maxLead end
                aimPoint = tp + lead
                local ad = aimPoint - origin
                local ah = Vector3.new(ad.X, 0, ad.Z)
                local _, t2 = SolvePitch(prof.v0, prof.g, math.max(ah.Magnitude, 0.1), ad.Y)
                delay = t2 + prof.windup + ping + prof.latency
            end
        end

        if VD.VeilV4WallCheck then
            if not VD_WallCheckVisible(origin, aimPoint, nil) then aimPoint = tp end
            if not VD_WallCheckVisible(origin, aimPoint, nearest.Character) then
                State.target = nil; State.lookVector = nil
                V4_Visuals.UpdateTarget(Vector2.new(0, 0), 0, false)
                V4_Visuals.UpdateTracer(Vector2.new(0, 0), Vector2.new(0, 0), false)
                return
            end
        end

        local adir = aimPoint - origin
        local ah = Vector3.new(adir.X, 0, adir.Z)
        local ahDist = ah.Magnitude
        local pitch = SolvePitch(prof.v0, prof.g, ahDist, adir.Y)

        if ahDist > 0.001 then
            State.lookVector = ah.Unit * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)
        else
            State.lookVector = adir.Unit
        end
        State.target = nearest

        -- Aim Lock (Putar badan)
        if VD.VeilV4AimLock and not VD.VeilV3Enabled then
            local flat = Vector3.new(adir.X, 0, adir.Z)
            if flat.Magnitude > 0.05 then
                flat = flat.Unit
                pcall(function()
                    hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + flat)
                end)
            end
        end

        -- Target Marker & Tracer V2
        if VD.VeilV4ShowTargetMarker then
            local sp, vis = cam:WorldToViewportPoint(tpPart.Position)
            if vis and sp.Z > 0 then
                local rad = math.clamp(1500 / math.max(dist, 1), 14, 60)
                V4_Visuals.UpdateTarget(Vector2.new(sp.X, sp.Y), rad, true)
                if VD.VeilV4ShowTracer then
                    local bottomCenter = Vector2.new(center.X, viewport.Y)
                    V4_Visuals.UpdateTracer(bottomCenter, Vector2.new(sp.X, sp.Y), true)
                else
                    V4_Visuals.UpdateTracer(Vector2.new(0, 0), Vector2.new(0, 0), false)
                end
            else
                V4_Visuals.UpdateTarget(Vector2.new(0, 0), 0, false)
                V4_Visuals.UpdateTracer(Vector2.new(0, 0), Vector2.new(0, 0), false)
            end
        else
            V4_Visuals.UpdateTarget(Vector2.new(0, 0), 0, false)
            V4_Visuals.UpdateTracer(Vector2.new(0, 0), Vector2.new(0, 0), false)
        end

        -- Auto Throw (Gacor)
        if VD.VeilV4AutoThrow and not VD.VeilV3Enabled and typeof(State.lookVector) == "Vector3" then
            local now = os.clock()
            if now - State.lastThrow >= (VD.VeilV4FireDelay or 0.05) then
                State.lastThrow = now
                pcall(function()
                    local remote = GetSpearRemote()
                    if remote and remote:IsA("RemoteEvent") then
                        local gun = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
                        if gun then
                            remote:FireServer(gun, State.lookVector.Unit)
                        end
                    end
                end)
            end
        end
    end

    -- Namecall Interceptor (Silent Aim)
    if typeof(hookmetamethod) == "function" then
        pcall(function()
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                if not checkcaller() and method == "FireServer" then
                    local n = self.Name
                    if (n == "Spearthrow" or n == "Spear" or n == "Throw")
                        and VD.VeilV4Enabled
                        and not VD.VeilV3Enabled
                        and VD.VeilV4UseInterceptor
                        and typeof(State.lookVector) == "Vector3" then
                        local args = {...}
                        if typeof(args[1]) == "Vector3" then
                            args[1] = State.lookVector
                        elseif typeof(args[2]) == "Vector3" then
                            args[2] = State.lookVector
                        end
                        return oldNamecall(self, unpack(args))
                    end
                end
                return oldNamecall(self, ...)
            end)
        end)
    end

    local VeilV4LastUpdate = 0
    RunService.RenderStepped:Connect(function()
        local now = os.clock()
        if now - VeilV4LastUpdate < 0.05 then return end
        VeilV4LastUpdate = now
        pcall(Update)
    end)
    return { State = State, Visuals = V4_Visuals }
        end)()
    end)
    if okModule and type(moduleResult) == "table" then
        VeilV4 = moduleResult
    else
        warn("[MawwwHub] Silent Veil V4 init failed:", moduleResult)
    end
end

-- UI: SILENT VEIL V3
RegDivider(Tabs.AimVeilV3)
RegLabel(Tabs.AimVeilV3, "Silent Veil V3")
RegToggle(Tabs.AimVeilV3, "Silent Veil V3", "Independent V3 clone of Silent Veil V1.", false, "VeilV3Enabled")
RegToggle(Tabs.AimVeilV3, "Show FOV Circle", "Show V3 FOV circle.", true, "VeilShowFOVV3")
RegToggle(Tabs.AimVeilV3, "Show Player Markers", "Show player markers.", true, "VeilShowPlayerMarkersV3")
RegToggle(Tabs.AimVeilV3, "Show Target Marker", "Show target marker.", true, "VeilShowTargetMarkerV3")
RegToggle(Tabs.AimVeilV3, "Show Tracer", "Show tracer line.", true, "VeilShowTracerV3")
RegToggle(Tabs.AimVeilV3, "Show Player Info", "Show name labels.", true, "VeilShowNameLabelsV3")
RegToggle(Tabs.AimVeilV3, "Auto Predict", "Auto predict movement.", true, "VeilAutoPredictV3")
RegToggle(Tabs.AimVeilV3, "Auto Throw Spear", "Auto throw spear at selected target.", false, "VeilAutoThrowV3")
RegSlider(Tabs.AimVeilV3, "Fire Delay (s)", "Auto throw interval.", 0.08, 0.03, 1, 0.01, "VeilFireDelayV3")
RegToggle(Tabs.AimVeilV3, "Wall Check", "Require line of sight.", false, "VeilWallCheckV3")
RegToggle(Tabs.AimVeilV3, "Ignore Downed", "Skip downed survivors.", true, "VeilIgnoreDownV3")
RegSlider(Tabs.AimVeilV3, "FOV Size", "V3 FOV radius.", 150, 50, 500, 10, "VeilFOVV3")
RegSlider(Tabs.AimVeilV3, "Max Distance", "V3 maximum target distance.", 400, 50, 500, 10, "VeilMaxDistV3")
RegSlider(Tabs.AimVeilV3, "Spear Speed", "V3 spear speed.", 165, 50, 400, 5, "VeilSpearSpeedV3")
RegSlider(Tabs.AimVeilV3, "Spear Gravity", "V3 spear gravity.", 103, 10, 300, 5, "VeilGravityV3")
RegSlider(Tabs.AimVeilV3, "Aura Spear Speed", "V3 aura spear speed.", 165, 50, 400, 5, "VeilAuraSpearSpeedV3")
RegSlider(Tabs.AimVeilV3, "Aura Spear Gravity", "V3 aura spear gravity.", 96.5, 10, 300, 5, "VeilAuraSpearGravityV3")
RegSlider(Tabs.AimVeilV3, "Lead Multiplier", "V3 lead multiplier.", 1.4, 0.1, 5, 0.1, "VeilLeadMultiplierV3")

-- UI: SILENT VEIL V4
RegDivider(Tabs.AimVeilV4)
RegLabel(Tabs.AimVeilV4, "Silent Veil V4")
RegToggle(Tabs.AimVeilV4, "Silent Veil V4", "Independent V4 clone of Silent Veil V2.", false, "VeilV4Enabled")
RegToggle(Tabs.AimVeilV4, "Aim Lock", "Aim-lock behavior from V2.", true, "VeilV4AimLock")
RegToggle(Tabs.AimVeilV4, "Auto Throw", "Automatically throw spears.", true, "VeilV4AutoThrow")
RegToggle(Tabs.AimVeilV4, "Remote Interceptor", "Intercept spear remote direction.", true, "VeilV4UseInterceptor")
RegToggle(Tabs.AimVeilV4, "Wall Check", "Require line of sight.", false, "VeilV4WallCheck")
RegToggle(Tabs.AimVeilV4, "Ignore Downed", "Skip downed survivors.", true, "VeilV4IgnoreDown")
RegToggle(Tabs.AimVeilV4, "Show FOV Circle", "Show V4 FOV circle.", true, "VeilV4ShowFOV")
RegToggle(Tabs.AimVeilV4, "Show Player Markers", "Show player markers.", true, "VeilV4ShowPlayerMarkers")
RegToggle(Tabs.AimVeilV4, "Show Target Marker", "Show target marker.", true, "VeilV4ShowTargetMarker")
RegToggle(Tabs.AimVeilV4, "Show Tracer", "Show tracer line.", true, "VeilV4ShowTracer")
RegToggle(Tabs.AimVeilV4, "Show Player Info", "Show name labels.", true, "VeilV4ShowNameLabels")
RegSlider(Tabs.AimVeilV4, "FOV Size", "V4 FOV radius.", 180, 50, 600, 10, "VeilV4FOV")
RegSlider(Tabs.AimVeilV4, "Max Distance", "V4 target distance.", 600, 50, 800, 10, "VeilV4MaxDist")
RegSlider(Tabs.AimVeilV4, "Spear Speed", "V4 spear speed.", 170, 50, 400, 5, "VeilV4SpearSpeed")
RegSlider(Tabs.AimVeilV4, "Spear Gravity", "V4 spear gravity.", 100, 10, 300, 5, "VeilV4SpearGravity")
RegSlider(Tabs.AimVeilV4, "Aura Spear Speed", "V4 aura spear speed.", 170, 50, 400, 5, "VeilV4AuraSpearSpeed")
RegSlider(Tabs.AimVeilV4, "Aura Spear Gravity", "V4 aura spear gravity.", 95, 10, 300, 5, "VeilV4AuraSpearGravity")
RegSlider(Tabs.AimVeilV4, "Lead Multiplier", "V4 lead multiplier.", 1.35, 0.1, 5, 0.05, "VeilV4LeadMultiplier")
RegSlider(Tabs.AimVeilV4, "Iterations", "V4 prediction iterations.", 3, 1, 10, 1, "VeilV4Iterations")
RegSlider(Tabs.AimVeilV4, "Fire Delay (s)", "V4 auto throw interval.", 0.05, 0.02, 1, 0.01, "VeilV4FireDelay")

-- SILENT PISTOL / TOF V1 — imported from vd update maww
-- =====================================================
function MAWWW_GetSafeGuiParent()
    if gethui then
        local ok, gui = pcall(gethui)
        if ok and gui then return gui end
    end
    if CoreGui then return CoreGui end
    return LocalPlayer:FindFirstChild("PlayerGui")
end

-- =====================================================
-- SILENT AIM: TWIST OF FATE
-- =====================================================
(function()
MAWWW_ToFState = {
    Connection = nil,
    LaserBeam = nil,
    TargetGui = nil,
    InputBegan = nil,
    InputEnded = nil,
    TouchInput = nil,
    IsAiming = false,
    SavedUIPos = UDim2.new(0.5, -120, 0, 110),
    SCPCache = {},
    SCPCacheTimer = 0,
}

MAWWW_ToFKeyCodes = {
    None = nil,
    Q = Enum.KeyCode.Q,
    E = Enum.KeyCode.E,
    R = Enum.KeyCode.R,
    T = Enum.KeyCode.T,
    F = Enum.KeyCode.F,
    G = Enum.KeyCode.G,
    H = Enum.KeyCode.H,
    J = Enum.KeyCode.J,
    K = Enum.KeyCode.K,
    L = Enum.KeyCode.L,
    X = Enum.KeyCode.X,
    Z = Enum.KeyCode.Z,
}

function MAWWW_ToFGetEvent()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local items = remotes and remotes:FindFirstChild("Items")
    local tof = items and items:FindFirstChild("Twist of Fate")
    local fire = tof and tof:FindFirstChild("Fire")
    if fire and fire:IsA("RemoteEvent") then
        return fire
    end
    return nil
end

function MAWWW_ToFGetGunObject()
    local char = LocalPlayer.Character
    if not char then return nil end

    local baseToF = char:FindFirstChild("Twist of Fate", true)
    if not baseToF then return nil end

    local rightArm = baseToF:FindFirstChild("Right Arm")
    if rightArm then
        local gunPart = rightArm:FindFirstChild("gun")
        if gunPart then return gunPart end

        local emperorGun = rightArm:FindFirstChild("EmperorGun")
        if emperorGun then return emperorGun end
    end

    return baseToF
end

function MAWWW_ToFIsTargetVisible(originPos, targetPos, targetCharacter)
    local direction = targetPos - originPos
    local distance = direction.Magnitude
    if distance < 0.1 then return true end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local excludeList = {}
    local localChar = LocalPlayer.Character
    if localChar then table.insert(excludeList, localChar) end
    if targetCharacter and targetCharacter ~= localChar then table.insert(excludeList, targetCharacter) end
    if MAWWW_ToFState.LaserBeam then table.insert(excludeList, MAWWW_ToFState.LaserBeam) end

    rayParams.FilterDescendantsInstances = excludeList

    local result = Workspace:Raycast(originPos, direction.Unit * distance, rayParams)
    return result == nil
end

function MAWWW_ToFGetSCPs()
    if tick() - MAWWW_ToFState.SCPCacheTimer < 0.5 then
        return MAWWW_ToFState.SCPCache
    end

    local newTargets = {}
    local mapFolder = workspace:FindFirstChild("Map")
    if mapFolder then
        for _, container in pairs(mapFolder:GetDescendants()) do
            if container:IsA("Model") then
                local attributes = container:GetAttributes()
                if container:GetAttribute("CorpseCreated0492") or next(attributes) ~= nil then
                    local root = container:FindFirstChild("HumanoidRootPart")
                    if root then table.insert(newTargets, root) end
                end
            end
        end
    end

    MAWWW_ToFState.SCPCache = newTargets
    MAWWW_ToFState.SCPCacheTimer = tick()
    return MAWWW_ToFState.SCPCache
end

function MAWWW_ToFGetTargetPosition()
    local gunObj = MAWWW_ToFGetGunObject()
    local char = LocalPlayer.Character
    if not (gunObj and char) then return nil, nil, nil, nil end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil, nil, nil end

    local myPos = hrp.Position
    local originPos
    if char:GetAttribute("IsCarried") then
        originPos = hrp.Position + (hrp.CFrame.LookVector * 2)
    else
        pcall(function()
            originPos = gunObj:IsA("BasePart") and gunObj.Position
                or (gunObj:FindFirstChildOfClass("BasePart") and gunObj:FindFirstChildOfClass("BasePart").Position)
        end)
        originPos = originPos or Vector3.new(myPos.X, myPos.Y + 1.5, myPos.Z)
    end

    local function predictTarget(torso, targetCharacter)
        local targetPos = torso.Position
        if VD.TOF_WallCheck and not MAWWW_ToFIsTargetVisible(originPos, targetPos, targetCharacter) then
            return nil, nil, nil, nil
        end

        local targetVel = Vector3.new(0, 0, 0)
        local rootPart = targetCharacter and (targetCharacter:FindFirstChild("HumanoidRootPart") or torso)
        if rootPart then targetVel = rootPart.Velocity end

        local directionRaw = targetPos - originPos
        local distance = directionRaw.Magnitude
        if distance < 0.1 then return nil, nil, nil, nil end
        if distance < 5 then return directionRaw.Unit, gunObj, originPos, targetPos end

        local travelTime = distance / 400
        local predictedPos = targetPos + (targetVel * travelTime)
        for _ = 1, 2 do
            local newDist = (predictedPos - originPos).Magnitude
            travelTime = newDist / 400
            predictedPos = targetPos + (targetVel * travelTime)
        end

        local finalDirection = predictedPos - originPos
        if finalDirection.Magnitude < 0.1 then return nil, nil, nil, nil end

        return finalDirection.Unit, gunObj, originPos, predictedPos
    end

    local targetMode = VD.TOF_TargetMode or "Killer"
    if targetMode == "Killer" then
        local closestTorso, closestChar, shortestDist = nil, nil, math.huge
        for _, player in ipairs(MawwwGetPlayers()) do
            if player ~= LocalPlayer and player.Team and player.Team.Name == "Killer" and player.Character then
                local torso = player.Character:FindFirstChild("Torso")
                    or player.Character:FindFirstChild("UpperTorso")
                    or player.Character:FindFirstChild("HumanoidRootPart")
                if torso then
                    local dist = (myPos - torso.Position).Magnitude
                    if dist < shortestDist then
                        shortestDist = dist
                        closestTorso = torso
                        closestChar = player.Character
                    end
                end
            end
        end
        if not closestTorso then return nil, nil, nil, nil end
        return predictTarget(closestTorso, closestChar)
    elseif targetMode == "Survivors" then
        local bestTorso, bestChar, bestDot = nil, nil, -math.huge
        local cam = workspace.CurrentCamera
        local camLook = cam.CFrame.LookVector

        for _, player in ipairs(MawwwGetPlayers()) do
            if player ~= LocalPlayer and player.Team and player.Team.Name == "Survivors" and player.Character then
                local torso = player.Character:FindFirstChild("Torso")
                    or player.Character:FindFirstChild("UpperTorso")
                    or player.Character:FindFirstChild("HumanoidRootPart")
                if torso then
                    local dirToTarget = torso.Position - cam.CFrame.Position
                    if dirToTarget.Magnitude > 0.1 then
                        local dot = camLook:Dot(dirToTarget.Unit)
                        if dot > 0.5 and dot > bestDot then
                            bestDot = dot
                            bestTorso = torso
                            bestChar = player.Character
                        end
                    end
                end
            end
        end
        if not bestTorso then return nil, nil, nil, nil end
        return predictTarget(bestTorso, bestChar)
    elseif targetMode == "Zombie" then
        local bestPart, bestDot = nil, -math.huge
        local cam = workspace.CurrentCamera
        local camLook = cam.CFrame.LookVector

        for _, root in ipairs(MAWWW_ToFGetSCPs()) do
            if root and root.Parent then
                local dirToTarget = root.Position - cam.CFrame.Position
                if dirToTarget.Magnitude > 0.1 then
                    local dot = camLook:Dot(dirToTarget.Unit)
                    if dot > 0.5 and dot > bestDot then
                        bestDot = dot
                        bestPart = root
                    end
                end
            end
        end
        if not bestPart then return nil, nil, nil, nil end
        return predictTarget(bestPart, bestPart.Parent)
    end

    return nil, nil, nil, nil
end

function MAWWW_ToFUpdateLaser(originPos, targetPos)
    if not MAWWW_ToFState.LaserBeam then
        local laser = Instance.new("Part")
        laser.Name = "MawwwPistolV5_Laser"
        laser.Anchored = true
        laser.CanCollide = false
        laser.CanTouch = false
        laser.CastShadow = false
        laser.Material = Enum.Material.Neon
        laser.Color = Color3.fromRGB(255, 50, 50)
        laser.Parent = workspace
        MAWWW_ToFState.LaserBeam = laser
    end

    local dist = (targetPos - originPos).Magnitude
    MAWWW_ToFState.LaserBeam.Size = Vector3.new(0.05, 0.05, dist)
    MAWWW_ToFState.LaserBeam.CFrame = CFrame.new((originPos + targetPos) / 2, targetPos)
    MAWWW_ToFState.LaserBeam.Transparency = 0
end

function MAWWW_ToFClearLaser()
    if MAWWW_ToFState.LaserBeam then
        pcall(function() MAWWW_ToFState.LaserBeam:Destroy() end)
        MAWWW_ToFState.LaserBeam = nil
    end
end

MAWWW_ToFAimConfig = {
    Pistol_BlockKnocked = true,
}

function IsDowned(char)
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return true end
    local state = char:GetAttribute("State")
    return state == "Downed" or state == "Dead"
end

function MAWWW_ToFGetMobileShootButton()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local survivorMob = playerGui and playerGui:FindFirstChild("Survivor-mob")
    local controls = survivorMob and survivorMob:FindFirstChild("Controls")
    local guiMob = controls and controls:FindFirstChild("Gui-mob")
    if not guiMob then return nil end

    local directNames = { "attack", "Attack", "shoot", "Shoot", "fire", "Fire" }
    for _, name in ipairs(directNames) do
        local btn = guiMob:FindFirstChild(name, true)
        if btn and btn:IsA("GuiObject") then return btn end
    end

    for _, obj in ipairs(guiMob:GetDescendants()) do
        if obj:IsA("GuiButton") and obj.Visible then
            return obj
        end
    end

    return guiMob:IsA("GuiObject") and guiMob or nil
end

function MAWWW_ToFIsTouchOnShootButton(input)
    local shootButton = MAWWW_ToFGetMobileShootButton()
    if not (shootButton and shootButton.Visible) then return false end

    local pos = input.Position
    local absPos = shootButton.AbsolutePosition
    local absSize = shootButton.AbsoluteSize

    return pos.X >= absPos.X and pos.X <= absPos.X + absSize.X
        and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y
end

function MAWWW_ToFDoShoot()
    if not VD.TOF_SilentAim then return end

    MAWWW_ToFAimConfig.Pistol_BlockKnocked = VD.TOF_BlockKnocked ~= false
    local char = LocalPlayer.Character
    if char then
        if MAWWW_ToFAimConfig.Pistol_BlockKnocked and IsDowned(char) then
            return
        end
    end

    local targetDirection, gunObject, originPos, targetPos = MAWWW_ToFGetTargetPosition()
    if not (targetDirection and gunObject and targetPos and originPos) then return end

    local tofEvent = MAWWW_ToFGetEvent()
    if not tofEvent then return end

    local freshDirection = targetPos - originPos
    if freshDirection.Magnitude < 0.1 then return end

    pcall(function()
        tofEvent:FireServer(gunObject, freshDirection.Unit)
    end)
end

MAWWW_ToFModeButtons = {}
function MAWWW_ToFRefreshTargetButtons()
    local modes = {
        Killer = { Color3.fromRGB(180, 45, 45), Color3.fromRGB(255, 180, 180) },
        Survivors = { Color3.fromRGB(25, 80, 150), Color3.fromRGB(160, 210, 255) },
        Zombie = { Color3.fromRGB(120, 80, 10), Color3.fromRGB(255, 210, 100) },
    }

    for modeName, btn in pairs(MAWWW_ToFModeButtons) do
        if btn and btn.Parent then
            local active = modeName == (VD.TOF_TargetMode or "Killer")
            local colors = modes[modeName]
            btn.BackgroundColor3 = active and colors[1] or Color3.fromRGB(30, 32, 40)
            btn.TextColor3 = active and colors[2] or Color3.fromRGB(155, 160, 175)
        end
    end
end

function MAWWW_ToFSetTargetMode(modeName, notify)
    if modeName ~= "Killer" and modeName ~= "Survivors" and modeName ~= "Zombie" then return end
    VD.TOF_TargetMode = modeName
    MAWWW_ToFRefreshTargetButtons()
    if notify then notify("Target Mode", modeName, 1) end
end

function MAWWW_ToFCreateTargetSelectorUI()
    local parent = MAWWW_GetSafeGuiParent()
    if not parent then return end
    if MAWWW_ToFState.TargetGui and MAWWW_ToFState.TargetGui.Parent then return end

    local old = parent:FindFirstChild("ToFTargetSelector")
    if old then pcall(function() old:Destroy() end) end

    local gui = Instance.new("ScreenGui")
    gui.Name = "ToFTargetSelector"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = parent

    local frame = Instance.new("Frame")
    frame.Name = "Main"
    frame.Size = UDim2.new(0, 180, 0, 126)
    frame.Position = MAWWW_ToFState.SavedUIPos
    frame.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(96, 72, 160)
    stroke.Thickness = 1

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 28)
    header.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
    header.BorderSizePixel = 0
    header.Parent = frame
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)

    local headerFix = Instance.new("Frame")
    headerFix.Size = UDim2.new(1, 0, 0, 10)
    headerFix.Position = UDim2.new(0, 0, 1, -10)
    headerFix.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
    headerFix.BorderSizePixel = 0
    headerFix.Parent = header

    local headerDiv = Instance.new("Frame")
    headerDiv.Size = UDim2.new(1, 0, 0, 1)
    headerDiv.Position = UDim2.new(0, 0, 1, -1)
    headerDiv.BackgroundColor3 = Color3.fromRGB(48, 42, 72)
    headerDiv.BorderSizePixel = 0
    headerDiv.Parent = header

    local dragArea = Instance.new("Frame")
    dragArea.Size = UDim2.new(1, -34, 1, 0)
    dragArea.BackgroundTransparency = 1
    dragArea.Parent = header

    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 28, 1, 0)
    minimizeBtn.Position = UDim2.new(1, -30, 0, 0)
    minimizeBtn.BackgroundTransparency = 1
    minimizeBtn.Text = "-"
    minimizeBtn.TextColor3 = Color3.fromRGB(185, 190, 205)
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 14
    minimizeBtn.Parent = header

    local headerLbl = Instance.new("TextLabel")
    headerLbl.Size = UDim2.new(1, -44, 1, 0)
    headerLbl.Position = UDim2.new(0, 10, 0, 0)
    headerLbl.BackgroundTransparency = 1
    headerLbl.Text = "TOF  •  TARGET MODE"
    headerLbl.TextColor3 = Color3.fromRGB(210, 215, 230)
    headerLbl.Font = Enum.Font.GothamBold
    headerLbl.TextSize = 10
    headerLbl.TextXAlignment = Enum.TextXAlignment.Left
    headerLbl.Parent = header

    local btnContainer = Instance.new("Frame")
    btnContainer.Size = UDim2.new(1, -16, 0, 86)
    btnContainer.Position = UDim2.new(0, 8, 0, 34)
    btnContainer.BackgroundTransparency = 1
    btnContainer.Parent = frame

    local layout = Instance.new("UIListLayout", btnContainer)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)

    local isMinimized = false
    minimizeBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        minimizeBtn.Text = isMinimized and "+" or "-"
        btnContainer.Visible = not isMinimized
        frame.Size = isMinimized and UDim2.new(0, 180, 0, 28) or UDim2.new(0, 180, 0, 126)
    end)

    local modes = {
        { Internal = "Killer", Display = "KILLER        K" },
        { Internal = "Survivors", Display = "SURVIVOR      J" },
        { Internal = "Zombie", Display = "ZOMBIE        L" },
    }

    MAWWW_ToFModeButtons = {}
    for i, mode in ipairs(modes) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 25)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.Text = mode.Display
        btn.TextXAlignment = Enum.TextXAlignment.Center
        btn.LayoutOrder = i
        btn.Parent = btnContainer
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        local btnStroke = Instance.new("UIStroke", btn)
        btnStroke.Color = Color3.fromRGB(58, 62, 78)
        btnStroke.Thickness = 1

        btn.MouseButton1Click:Connect(function()
            MAWWW_ToFSetTargetMode(mode.Internal, false)
        end)
        btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                MAWWW_ToFSetTargetMode(mode.Internal, false)
            end
        end)

        MAWWW_ToFModeButtons[mode.Internal] = btn
    end
    MAWWW_ToFRefreshTargetButtons()

    local dragging = false
    local dragStart, startPos
    dragArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragStart = input.Position
            startPos = frame.Position
            dragging = true
        end
    end)
    dragArea.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            local newPos = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
            frame.Position = newPos
            MAWWW_ToFState.SavedUIPos = newPos
        end
    end)

    MAWWW_ToFState.TargetGui = gui
end

function MAWWW_ToFDestroyTargetSelectorUI()
    if MAWWW_ToFState.TargetGui then
        pcall(function() MAWWW_ToFState.TargetGui:Destroy() end)
        MAWWW_ToFState.TargetGui = nil
    end
    MAWWW_ToFModeButtons = {}
end

function MAWWW_ToFStartConnection()
    if MAWWW_ToFState.Connection then return end
    MAWWW_ToFState.Connection = RunService.Heartbeat:Connect(function()
        if not VD.TOF_SilentAim or not MAWWW_ToFState.IsAiming then
            if MAWWW_ToFState.LaserBeam then MAWWW_ToFState.LaserBeam.Transparency = 1 end
            return
        end

        local _, _, originPos, targetPos = MAWWW_ToFGetTargetPosition()
        if originPos and targetPos then
            pcall(function()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and not char:GetAttribute("IsCarried") then
                    hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z))
                end
            end)

            if VD.TOF_Laser then
                MAWWW_ToFUpdateLaser(originPos, targetPos)
            elseif MAWWW_ToFState.LaserBeam then
                MAWWW_ToFState.LaserBeam.Transparency = 1
            end
        elseif MAWWW_ToFState.LaserBeam then
            MAWWW_ToFState.LaserBeam.Transparency = 1
        end
    end)
end

function MAWWW_ToFStopConnection()
    if MAWWW_ToFState.Connection then
        pcall(function() MAWWW_ToFState.Connection:Disconnect() end)
        MAWWW_ToFState.Connection = nil
    end
    MAWWW_ToFState.IsAiming = false
    MAWWW_ToFClearLaser()
end

function MAWWW_ToFDisconnectInputs()
    if MAWWW_ToFState.InputBegan then pcall(function() MAWWW_ToFState.InputBegan:Disconnect() end) end
    if MAWWW_ToFState.InputEnded then pcall(function() MAWWW_ToFState.InputEnded:Disconnect() end) end
    MAWWW_ToFState.InputBegan = nil
    MAWWW_ToFState.InputEnded = nil
end

MAWWW_SetToFSilentAim = nil

function MAWWW_ToFEnsureInputs()
    if not MAWWW_ToFState.InputBegan then
        MAWWW_ToFState.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end

            local keyCode = MAWWW_ToFKeyCodes[VD.TOF_Key or "None"]
            if keyCode and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == keyCode then
                MAWWW_SetToFSilentAim(not VD.TOF_SilentAim)
                return
            end

            if not VD.TOF_SilentAim then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or (input.UserInputType == Enum.UserInputType.Touch and MAWWW_ToFIsTouchOnShootButton(input)) then
                MAWWW_ToFState.IsAiming = true
                if input.UserInputType == Enum.UserInputType.Touch then
                    MAWWW_ToFState.TouchInput = input
                end
                MAWWW_ToFDoShoot()
                return
            end

            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.K then
                    MAWWW_ToFSetTargetMode("Killer", true)
                elseif input.KeyCode == Enum.KeyCode.J then
                    MAWWW_ToFSetTargetMode("Survivors", true)
                elseif input.KeyCode == Enum.KeyCode.L then
                    MAWWW_ToFSetTargetMode("Zombie", true)
                end
            end
        end)
    end
    if not MAWWW_ToFState.InputEnded then
        MAWWW_ToFState.InputEnded = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or (input.UserInputType == Enum.UserInputType.Touch and input == MAWWW_ToFState.TouchInput) then
                MAWWW_ToFState.IsAiming = false
                if input == MAWWW_ToFState.TouchInput then MAWWW_ToFState.TouchInput = nil end
                if MAWWW_ToFState.LaserBeam then MAWWW_ToFState.LaserBeam.Transparency = 1 end
            end
        end)
    end
end

MAWWW_SetToFSilentAim = function(enabled)
    VD.TOF_SilentAim = enabled and true or false
    MAWWW_ToFEnsureInputs()
    if VD.TOF_SilentAim then
        MAWWW_ToFCreateTargetSelectorUI()
        MAWWW_ToFStartConnection()
    else
        MAWWW_ToFDestroyTargetSelectorUI()
        MAWWW_ToFStopConnection()
    end
end

MAWWW_ToFEnsureInputs()
getgenv().MAWWW_SetToFSilentAim = MAWWW_SetToFSilentAim
getgenv().MAWWW_ToFClearLaser = MAWWW_ToFClearLaser
getgenv().MAWWW_ToFSetTargetMode = MAWWW_ToFSetTargetMode
end)();


RegDivider(Tabs.AimTOFV1)
RegLabel(Tabs.AimTOFV1, "Silent Pistol / TOF V1")
RegToggle(Tabs.AimTOFV1, "Silent Pistol / TOF V1", "Imported vd update maww Twist of Fate engine.", false, "TOF_SilentAim", function(v)
    VD.TOF_SilentAim = v == true
    if getgenv().MAWWW_SetToFSilentAim then
        pcall(getgenv().MAWWW_SetToFSilentAim, VD.TOF_SilentAim)
    end
    notify("TOF V1", v and "ON" or "OFF", 2)
end)
RegDropdown(Tabs.AimTOFV1, "Target Mode", "Killer / Survivors / Zombie", {"Killer", "Survivors", "Zombie"}, "Killer", false, "TOF_TargetMode", function(v)
    VD.TOF_TargetMode = v or "Killer"
    if getgenv().MAWWW_ToFSetTargetMode then
        pcall(getgenv().MAWWW_ToFSetTargetMode, VD.TOF_TargetMode, false)
    end
end)
RegToggle(Tabs.AimTOFV1, "Wall Check", "Require clear line of sight.", false, "TOF_WallCheck")
RegToggle(Tabs.AimTOFV1, "Laser", "Show the source aim laser.", true, "TOF_Laser", function(v)
    VD.TOF_Laser = v == true
    if not VD.TOF_Laser and getgenv().MAWWW_ToFClearLaser then
        pcall(getgenv().MAWWW_ToFClearLaser)
    end
end)
RegToggle(Tabs.AimTOFV1, "Block When Downed", "Do not fire while downed/dead.", true, "TOF_BlockKnocked")
RegDropdown(Tabs.AimTOFV1, "Silent Aim Key", "Toggle key for Silent Pistol / TOF V1.", {"None", "Q", "E", "R", "T", "F", "G", "H", "J", "K", "L", "X", "Z"}, "None", false, "TOF_Key")

-- SILENT PISTOL / TOF V2 — Imported from VD-MAWWW-UPDATE
--========================================================--
RegDivider(Tabs.AimTOFV2)
RegLabel(Tabs.AimTOFV2, "Silent Pistol / TOF V2")

ToFV2 = (function()
    local State = {
        LastFire = 0,
        LaserBeam = nil,
        Target = nil,
        Aiming = false,
        scpCache = {},
        scpTimer = 0,
    }

    local function TeamHas(p, keyword)
        if not p or not p.Team or not p.Team.Name then return false end
        return string.find(string.lower(p.Team.Name), keyword, 1, true) ~= nil
    end

    local function GetToFRemote()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local items = remotes and remotes:FindFirstChild("Items")
        local tof = items and items:FindFirstChild("Twist of Fate")
        return tof and tof:FindFirstChild("Fire")
    end

    local function GetGunObject()
        local char = Player.Character
        if not char then return nil end
        local base = char:FindFirstChild("Twist of Fate", true)
        if not base then return nil end
        local rightArm = base:FindFirstChild("Right Arm")
        if rightArm then
            local gun = rightArm:FindFirstChild("gun")
            if gun then return gun end
            local emperor = rightArm:FindFirstChild("EmperorGun")
            if emperor then return emperor end
        end
        return base
    end

    local function GetOrigin(gunObj, char)
        if char:GetAttribute("IsCarried") then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then return hrp.Position + hrp.CFrame.LookVector * 2 end
        end
        if gunObj then
            if gunObj:IsA("BasePart") then return gunObj.Position end
            local primary = gunObj:FindFirstChildOfClass("BasePart")
            if primary then return primary.Position end
        end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then return Vector3.new(hrp.Position.X, hrp.Position.Y + 1.5, hrp.Position.Z) end
        return nil
    end

    local function IsDownedChar(c)
        if not c then return false end
        local s = c:GetAttribute("State")
        return s == "Downed" or s == "Dead"
    end

    local function WallCheck(origin, target)
        if not VD.TOF2_WallCheck then return true end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local excl = {}
        local myChar = Player.Character
        if myChar then table.insert(excl, myChar) end
        if State.LaserBeam then table.insert(excl, State.LaserBeam) end
        params.FilterDescendantsInstances = excl
        local dir = target - origin
        local dist = dir.Magnitude
        if dist < 0.1 then return true end
        local r = Workspace:Raycast(origin, dir.Unit * dist, params)
        return r == nil
    end

    local function PredictTarget(origin, targetPos, targetRoot)
        local vel = Vector3.zero
        if targetRoot and targetRoot:IsA("BasePart") then vel = targetRoot.Velocity end
        local dir = targetPos - origin
        local dist = dir.Magnitude
        if dist < 0.1 then return nil end
        if dist < 5 then return dir.Unit, targetPos end
        local speed = 400
        local t = dist / speed
        local pred = targetPos + vel * t
        local iters = math.max(1, tonumber(VD.TOF2_PredictIterations) or 3)
        for _ = 1, iters do
            local nd = (pred - origin).Magnitude
            t = nd / speed
            pred = targetPos + vel * t
        end
        return (pred - origin).Unit, pred
    end

    local function GetSCPTargets()
        local now = tick()
        if now - State.scpTimer < 0.5 then return State.scpCache end
        local list = {}
        local map = workspace:FindFirstChild("Map")
        if map then
            for _, container in pairs(map:GetDescendants()) do
                if container:IsA("Model") then
                    local attrs = container:GetAttributes()
                    if container:GetAttribute("CorpseCreated0492") or next(attrs) ~= nil then
                        local root = container:FindFirstChild("HumanoidRootPart")
                        if root then table.insert(list, root) end
                    end
                end
            end
        end
        State.scpCache = list
        State.scpTimer = now
        return list
    end

    local function PickTarget()
        local char = Player.Character
        if not char then return nil end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end
        local cam = Workspace.CurrentCamera
        if not cam then return nil end
        local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
        local mode = VD.TOF2_TargetMode or "Killer"
        local best = nil
        local bestMetric = math.huge

        if mode == "Killer" or mode == "Survivors" then
            local keyword = (mode == "Killer") and "killer" or "survivor"
            for _, p in ipairs(MawwwGetPlayers()) do
                if p ~= Player and p.Character and TeamHas(p, keyword) then
                    local pc = p.Character
                    if not (VD.TOF2_IgnoreDown and IsDownedChar(pc)) then
                        local hum = pc:FindFirstChildOfClass("Humanoid")
                        local part = pc:FindFirstChild("UpperTorso")
                            or pc:FindFirstChild("Torso")
                            or pc:FindFirstChild("HumanoidRootPart")
                        if hum and hum.Health > 0 and part then
                            local sp, on = cam:WorldToViewportPoint(part.Position)
                            if on and sp.Z > 0 then
                                local sd = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                                local stud = (part.Position - hrp.Position).Magnitude
                                if sd <= (VD.TOF2_FOV or 180) and stud <= (VD.TOF2_MaxDist or 600) and sd < bestMetric then
                                    bestMetric = sd
                                    best = { char = pc, part = part, hum = hum }
                                end
                            end
                        end
                    end
                end
            end
        elseif mode == "Zombie" then
            for _, root in ipairs(GetSCPTargets()) do
                if root and root.Parent then
                    local sp, on = cam:WorldToViewportPoint(root.Position)
                    if on and sp.Z > 0 then
                        local sd = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        local stud = (root.Position - hrp.Position).Magnitude
                        if sd <= (VD.TOF2_FOV or 180) and stud <= (VD.TOF2_MaxDist or 600) and sd < bestMetric then
                            bestMetric = sd
                            best = { char = root.Parent, part = root, hum = nil }
                        end
                    end
                end
            end
        end
        return best
    end

    local function UpdateLaser(origin, target)
        if not State.LaserBeam then
            local p = Instance.new("Part")
            p.Name = "MawwwToFV2Laser"
            p.Anchored = true; p.CanCollide = false
            p.CanTouch = false; p.CastShadow = false
            p.Material = Enum.Material.Neon
            p.Color = Color3.fromRGB(VD.TOF2_LaserColorR or 255, VD.TOF2_LaserColorG or 40, VD.TOF2_LaserColorB or 40)
            p.Parent = workspace
            State.LaserBeam = p
        end
        local dist = (target - origin).Magnitude
        State.LaserBeam.Size = Vector3.new(0.05, 0.05, dist)
        State.LaserBeam.CFrame = CFrame.new((origin + target) / 2, target)
        State.LaserBeam.Transparency = 0
        State.LaserBeam.Color = Color3.fromRGB(VD.TOF2_LaserColorR or 255, VD.TOF2_LaserColorG or 40, VD.TOF2_LaserColorB or 40)
    end

    local function ClearLaser()
        if State.LaserBeam then
            pcall(function() State.LaserBeam:Destroy() end)
            State.LaserBeam = nil
        end
    end

    local function DoFire()
        local remote = GetToFRemote()
        if not remote then return end
        local char = Player.Character
        if not char then return end
        if VD.TOF2_BlockKnocked and IsDownedChar(char) then return end
        local gunObj = GetGunObject()
        if not gunObj then return end
        local origin = GetOrigin(gunObj, char)
        if not origin then return end
        local tgt = State.Target
        if not tgt or not tgt.part or not tgt.part.Parent then
            tgt = PickTarget()
            State.Target = tgt
        end
        if not tgt then return end
        local targetPos = tgt.part.Position
        if not WallCheck(origin, targetPos) then return end
        local dir, pred = PredictTarget(origin, targetPos, tgt.part)
        if not dir then return end
        pcall(function() remote:FireServer(gunObj, dir) end)
    end

    if typeof(hookmetamethod) == "function" then
        pcall(function()
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                if not checkcaller() and method == "FireServer"
                    and (self.Name == "Fire" or self.Name == "Shoot")
                    and VD.TOF2_Enabled and VD.TOF2_Predict then
                    local args = {...}
                    if typeof(args[2]) == "Vector3" and State.Target and State.Target.part and State.Target.part.Parent then
                        local char = Player.Character
                        local gunObj = GetGunObject()
                        if char and gunObj then
                            local origin = GetOrigin(gunObj, char)
                            if origin then
                                local dir = PredictTarget(origin, State.Target.part.Position, State.Target.part)
                                if dir then
                                    args[2] = dir
                                    return oldNamecall(self, unpack(args))
                                end
                            end
                        end
                    end
                end
                return oldNamecall(self, ...)
            end)
        end)
    end

    local function Update()
        if not VD.TOF2_Enabled then
            if State.LaserBeam then State.LaserBeam.Transparency = 1 end
            State.Target = nil
            return
        end
        local tgt = PickTarget()
        State.Target = tgt
        if tgt then
            local char = Player.Character
            local gunObj = GetGunObject()
            if char and gunObj then
                local origin = GetOrigin(gunObj, char)
                if origin then
                    if VD.TOF2_ShowLaser then
                        UpdateLaser(origin, tgt.part.Position)
                    elseif State.LaserBeam then
                        State.LaserBeam.Transparency = 1
                    end
                end
            end
        else
            if State.LaserBeam then State.LaserBeam.Transparency = 1 end
        end
        if VD.TOF2_AutoFire then
            local now = os.clock()
            if now - State.LastFire >= (VD.TOF2_FireRate or 0.18) then
                State.LastFire = now
                pcall(DoFire)
            end
        end
    end

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if not VD.TOF2_Enabled then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if not VD.TOF2_AutoFire then
                State.LastFire = os.clock()
                pcall(DoFire)
            end
        end
    end)

    local ToFV2LastUpdate = 0
    RunService.RenderStepped:Connect(function()
        local now = os.clock()
        if now - ToFV2LastUpdate < 0.05 then return end
        ToFV2LastUpdate = now
        pcall(Update)
    end)

    return { State = State, DoFire = DoFire, ClearLaser = ClearLaser }
end)()

RegToggle(Tabs.AimTOFV2, "Silent Pistol / TOF V2", "V2 engine: prediction, target selection, wall check, laser, and auto-fire.", false, "TOF2_Enabled", function(v)
    if not v and ToFV2 and ToFV2.ClearLaser then
        pcall(ToFV2.ClearLaser)
    end
    notify("TOF V2", v and "Enabled" or "Disabled", 2)
end)

RegDropdown(Tabs.AimTOFV2, "Target Mode", "Killer / Survivors / Zombie", {"Killer", "Survivors", "Zombie"}, "Killer", false, "TOF2_TargetMode")
RegToggle(Tabs.AimTOFV2, "Auto Fire", "Automatically fire at the selected target.", false, "TOF2_AutoFire")
RegToggle(Tabs.AimTOFV2, "Prediction", "Predict target movement before firing.", true, "TOF2_Predict")
RegSlider(Tabs.AimTOFV2, "Predict Iterations", "Prediction refinement iterations.", 3, 1, 6, 1, "TOF2_PredictIterations")
RegToggle(Tabs.AimTOFV2, "Wall Check", "Require a clear line of sight.", true, "TOF2_WallCheck")
RegToggle(Tabs.AimTOFV2, "Block When Downed", "Do not fire while your character is downed.", true, "TOF2_BlockKnocked")
RegToggle(Tabs.AimTOFV2, "Ignore Downed Target", "Skip targets marked Downed or Dead.", true, "TOF2_IgnoreDown")
RegToggle(Tabs.AimTOFV2, "Show Laser", "Show the V2 aim laser.", true, "TOF2_ShowLaser")
RegSlider(Tabs.AimTOFV2, "Max Distance", "Maximum target distance.", 600, 50, 1000, 10, "TOF2_MaxDist")
RegSlider(Tabs.AimTOFV2, "FOV", "Maximum screen-space target FOV.", 180, 30, 500, 10, "TOF2_FOV")
RegSlider(Tabs.AimTOFV2, "Fire Rate (s)", "Minimum delay between automatic shots.", 0.18, 0.05, 1, 0.01, "TOF2_FireRate")
RegSlider(Tabs.AimTOFV2, "Laser R", "Laser red channel.", 255, 0, 255, 1, "TOF2_LaserColorR")
RegSlider(Tabs.AimTOFV2, "Laser G", "Laser green channel.", 40, 0, 255, 1, "TOF2_LaserColorG")
RegSlider(Tabs.AimTOFV2, "Laser B", "Laser blue channel.", 40, 0, 255, 1, "TOF2_LaserColorB")


RegDivider(Tabs.AimFlash)
RegLabel(Tabs.AimFlash, "Flashlight")
FlashAim = (function()
    local State = { Target=nil, LastFire=0 }
    local function TeamHas(p, keyword) if not p or not p.Team or not p.Team.Name then return false end; return string.find(string.lower(p.Team.Name), keyword, 1, true) ~= nil end
    local function IsDownedChar(c) if not c then return false end; local s = c:GetAttribute("State"); return s == "Downed" or s == "Dead" end
    local function PickTarget()
        local char = Player.Character; if not char then return nil end
        local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return nil end
        local cam = Workspace.CurrentCamera; if not cam then return nil end
        local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
        local keyword = (VD.FlashTargetMode == "Survivors") and "survivor" or "killer"
        local best, bestMetric = nil, math.huge
        for _, p in ipairs(MawwwGetPlayers()) do
            if p ~= Player and p.Character and TeamHas(p, keyword) then
                local pc = p.Character
                if not IsDownedChar(pc) then
                    local hum = pc:FindFirstChildOfClass("Humanoid")
                    local part = pc:FindFirstChild("UpperTorso") or pc:FindFirstChild("Torso") or pc:FindFirstChild("HumanoidRootPart")
                    if hum and hum.Health > 0 and part then
                        local sp, on = cam:WorldToViewportPoint(part.Position)
                        if on and sp.Z > 0 then
                            local sd = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                            local stud = (part.Position - hrp.Position).Magnitude
                            if sd <= (VD.FlashFOV or 200) and stud <= (VD.FlashMaxDist or 400) and sd < bestMetric then bestMetric = sd; best = part end
                        end
                    end
                end
            end
        end
        return best
    end
    local function WallCheck(origin, target)
        if not VD.FlashWallCheck then return true end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local excl = {}
        if Player.Character then table.insert(excl, Player.Character) end
        params.FilterDescendantsInstances = excl
        local dir = target - origin; local dist = dir.Magnitude
        if dist < 0.1 then return true end
        return Workspace:Raycast(origin, dir.Unit * dist, params) == nil
    end
    local function DoFire()
        local target = State.Target or PickTarget(); if not target then return end
        State.Target = target
        local char = Player.Character
        local origin = char and char:FindFirstChild("HumanoidRootPart"); if not origin then return end
        if not WallCheck(origin.Position, target.Position) then return end
        local dir = (target.Position - origin.Position).Unit
        pcall(function()
            local remotes = GetRemotes(); if not remotes then return end
            local items = remotes:FindFirstChild("Items")
            local fl = items and (items:FindFirstChild("Flashlight") or items:FindFirstChild("Torch"))
            if fl then
                local fire = fl:FindFirstChild("Fire") or fl:FindFirstChild("Shine") or fl:FindFirstChild("Aim")
                if fire then fire:FireServer(dir); return end
            end
            local playerFolder = remotes:FindFirstChild("Player")
            if playerFolder then
                local ev = playerFolder:FindFirstChild("FlashlightAim") or playerFolder:FindFirstChild("AimFlashlight")
                if ev then ev:FireServer(dir); return end
            end
        end)
    end
    local function Update()
        if not VD.FlashSilentAim then State.Target = nil; return end
        local tgt = PickTarget(); State.Target = tgt
        if VD.FlashAutoFire and tgt then
            local now = os.clock()
            if now - State.LastFire >= 0.2 then State.LastFire = now; pcall(DoFire) end
        end
    end
    local FlashAimLastUpdate = 0
    RunService.RenderStepped:Connect(function()
        local now = os.clock()
        if now - FlashAimLastUpdate < 0.05 then return end
        FlashAimLastUpdate = now
        pcall(Update)
    end)
    return { State = State, DoFire = DoFire }
end)()
RegToggle(Tabs.AimFlash, "Flashlight Silent Aim", "Silent aim flashlight", false, "FlashSilentAim")
RegToggle(Tabs.AimFlash, "Flashlight Auto Fire", "Auto fire flashlight", true, "FlashAutoFire")
RegToggle(Tabs.AimFlash, "Flashlight Wall Check", "Require line of sight", false, "FlashWallCheck")
RegDropdown(Tabs.AimFlash, "Flashlight Target Mode", "Target team", {"Killer", "Survivors"}, "Killer", false, "FlashTargetMode")
RegSlider(Tabs.AimFlash, "Flashlight FOV", "FOV radius", 200, 30, 500, 10, "FlashFOV")
RegSlider(Tabs.AimFlash, "Flashlight Max Distance", "Max distance", 400, 50, 1000, 10, "FlashMaxDist")

--========================================================--
--========================================================--
-- SILENT PISTOL / TOF V3
--========================================================--
TOFV3Module = {}
do
    local okModule, moduleResult = pcall(function()
        return (function()
MAWWW_ToFV3State = {
    Connection = nil,
    LaserBeam = nil,
    TargetGui = nil,
    InputBegan = nil,
    InputEnded = nil,
    TouchInput = nil,
    IsAiming = false,
    SavedUIPos = UDim2.new(0.5, -120, 0, 110),
    SCPCache = {},
    SCPCacheTimer = 0,
}

MAWWW_ToFV3KeyCodes = {
    None = nil,
    Q = Enum.KeyCode.Q,
    E = Enum.KeyCode.E,
    R = Enum.KeyCode.R,
    T = Enum.KeyCode.T,
    F = Enum.KeyCode.F,
    G = Enum.KeyCode.G,
    H = Enum.KeyCode.H,
    J = Enum.KeyCode.J,
    K = Enum.KeyCode.K,
    L = Enum.KeyCode.L,
    X = Enum.KeyCode.X,
    Z = Enum.KeyCode.Z,
}

function MAWWW_ToFV3GetEvent()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local items = remotes and remotes:FindFirstChild("Items")
    local tof = items and items:FindFirstChild("Twist of Fate")
    local fire = tof and tof:FindFirstChild("Fire")
    if fire and fire:IsA("RemoteEvent") then
        return fire
    end
    return nil
end

function MAWWW_ToFV3GetGunObject()
    local char = LocalPlayer.Character
    if not char then return nil end

    local baseToF = char:FindFirstChild("Twist of Fate", true)
    if not baseToF then return nil end

    local rightArm = baseToF:FindFirstChild("Right Arm")
    if rightArm then
        local gunPart = rightArm:FindFirstChild("gun")
        if gunPart then return gunPart end

        local emperorGun = rightArm:FindFirstChild("EmperorGun")
        if emperorGun then return emperorGun end
    end

    return baseToF
end

function MAWWW_ToFV3IsTargetVisible(originPos, targetPos, targetCharacter)
    local direction = targetPos - originPos
    local distance = direction.Magnitude
    if distance < 0.1 then return true end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local excludeList = {}
    local localChar = LocalPlayer.Character
    if localChar then table.insert(excludeList, localChar) end
    if targetCharacter and targetCharacter ~= localChar then table.insert(excludeList, targetCharacter) end
    if MAWWW_ToFV3State.LaserBeam then table.insert(excludeList, MAWWW_ToFV3State.LaserBeam) end

    rayParams.FilterDescendantsInstances = excludeList

    local result = Workspace:Raycast(originPos, direction.Unit * distance, rayParams)
    return result == nil
end

function MAWWW_ToFV3GetSCPs()
    if tick() - MAWWW_ToFV3State.SCPCacheTimer < 0.5 then
        return MAWWW_ToFV3State.SCPCache
    end

    local newTargets = {}
    local mapFolder = workspace:FindFirstChild("Map")
    if mapFolder then
        for _, container in pairs(mapFolder:GetDescendants()) do
            if container:IsA("Model") then
                local attributes = container:GetAttributes()
                if container:GetAttribute("CorpseCreated0492") or next(attributes) ~= nil then
                    local root = container:FindFirstChild("HumanoidRootPart")
                    if root then table.insert(newTargets, root) end
                end
            end
        end
    end

    MAWWW_ToFV3State.SCPCache = newTargets
    MAWWW_ToFV3State.SCPCacheTimer = tick()
    return MAWWW_ToFV3State.SCPCache
end

function MAWWW_ToFV3GetTargetPosition()
    local gunObj = MAWWW_ToFV3GetGunObject()
    local char = LocalPlayer.Character
    if not (gunObj and char) then return nil, nil, nil, nil end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, nil, nil, nil end

    local myPos = hrp.Position
    local originPos
    if char:GetAttribute("IsCarried") then
        originPos = hrp.Position + (hrp.CFrame.LookVector * 2)
    else
        pcall(function()
            originPos = gunObj:IsA("BasePart") and gunObj.Position
                or (gunObj:FindFirstChildOfClass("BasePart") and gunObj:FindFirstChildOfClass("BasePart").Position)
        end)
        originPos = originPos or Vector3.new(myPos.X, myPos.Y + 1.5, myPos.Z)
    end

    local function predictTarget(torso, targetCharacter)
        local targetPos = torso.Position
        if VD.TOF3_WallCheck and not MAWWW_ToFV3IsTargetVisible(originPos, targetPos, targetCharacter) then
            return nil, nil, nil, nil
        end

        local targetVel = Vector3.new(0, 0, 0)
        local rootPart = targetCharacter and (targetCharacter:FindFirstChild("HumanoidRootPart") or torso)
        if rootPart then targetVel = rootPart.Velocity end

        local directionRaw = targetPos - originPos
        local distance = directionRaw.Magnitude
        if distance < 0.1 then return nil, nil, nil, nil end
        if distance < 5 then return directionRaw.Unit, gunObj, originPos, targetPos end

        local travelTime = distance / 400
        local predictedPos = targetPos + (targetVel * travelTime)
        for _ = 1, 2 do
            local newDist = (predictedPos - originPos).Magnitude
            travelTime = newDist / 400
            predictedPos = targetPos + (targetVel * travelTime)
        end

        local finalDirection = predictedPos - originPos
        if finalDirection.Magnitude < 0.1 then return nil, nil, nil, nil end

        return finalDirection.Unit, gunObj, originPos, predictedPos
    end

    local targetMode = VD.TOF3_TargetMode or "Killer"
    if targetMode == "Killer" then
        local closestTorso, closestChar, shortestDist = nil, nil, math.huge
        for _, player in ipairs(MawwwGetPlayers()) do
            if player ~= LocalPlayer and player.Team and player.Team.Name == "Killer" and player.Character then
                local torso = player.Character:FindFirstChild("Torso")
                    or player.Character:FindFirstChild("UpperTorso")
                    or player.Character:FindFirstChild("HumanoidRootPart")
                if torso then
                    local dist = (myPos - torso.Position).Magnitude
                    if dist < shortestDist then
                        shortestDist = dist
                        closestTorso = torso
                        closestChar = player.Character
                    end
                end
            end
        end
        if not closestTorso then return nil, nil, nil, nil end
        return predictTarget(closestTorso, closestChar)
    elseif targetMode == "Survivors" then
        local bestTorso, bestChar, bestDot = nil, nil, -math.huge
        local cam = workspace.CurrentCamera
        local camLook = cam.CFrame.LookVector

        for _, player in ipairs(MawwwGetPlayers()) do
            if player ~= LocalPlayer and player.Team and player.Team.Name == "Survivors" and player.Character then
                local torso = player.Character:FindFirstChild("Torso")
                    or player.Character:FindFirstChild("UpperTorso")
                    or player.Character:FindFirstChild("HumanoidRootPart")
                if torso then
                    local dirToTarget = torso.Position - cam.CFrame.Position
                    if dirToTarget.Magnitude > 0.1 then
                        local dot = camLook:Dot(dirToTarget.Unit)
                        if dot > 0.5 and dot > bestDot then
                            bestDot = dot
                            bestTorso = torso
                            bestChar = player.Character
                        end
                    end
                end
            end
        end
        if not bestTorso then return nil, nil, nil, nil end
        return predictTarget(bestTorso, bestChar)
    elseif targetMode == "Zombie" then
        local bestPart, bestDot = nil, -math.huge
        local cam = workspace.CurrentCamera
        local camLook = cam.CFrame.LookVector

        for _, root in ipairs(MAWWW_ToFV3GetSCPs()) do
            if root and root.Parent then
                local dirToTarget = root.Position - cam.CFrame.Position
                if dirToTarget.Magnitude > 0.1 then
                    local dot = camLook:Dot(dirToTarget.Unit)
                    if dot > 0.5 and dot > bestDot then
                        bestDot = dot
                        bestPart = root
                    end
                end
            end
        end
        if not bestPart then return nil, nil, nil, nil end
        return predictTarget(bestPart, bestPart.Parent)
    end

    return nil, nil, nil, nil
end

function MAWWW_ToFV3UpdateLaser(originPos, targetPos)
    if not MAWWW_ToFV3State.LaserBeam then
        local laser = Instance.new("Part")
        laser.Name = "ToFLaserV3"
        laser.Anchored = true
        laser.CanCollide = false
        laser.CanTouch = false
        laser.CastShadow = false
        laser.Material = Enum.Material.Neon
        laser.Color = Color3.fromRGB(255, 50, 50)
        laser.Parent = workspace
        MAWWW_ToFV3State.LaserBeam = laser
    end

    local dist = (targetPos - originPos).Magnitude
    MAWWW_ToFV3State.LaserBeam.Size = Vector3.new(0.05, 0.05, dist)
    MAWWW_ToFV3State.LaserBeam.CFrame = CFrame.new((originPos + targetPos) / 2, targetPos)
    MAWWW_ToFV3State.LaserBeam.Transparency = 0
end

function MAWWW_ToFV3ClearLaser()
    if MAWWW_ToFV3State.LaserBeam then
        pcall(function() MAWWW_ToFV3State.LaserBeam:Destroy() end)
        MAWWW_ToFV3State.LaserBeam = nil
    end
end

MAWWW_ToFV3AimConfig = {
    Pistol_BlockKnocked = true,
}

function MAWWW_ToFV3GetMobileShootButton()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local survivorMob = playerGui and playerGui:FindFirstChild("Survivor-mob")
    local controls = survivorMob and survivorMob:FindFirstChild("Controls")
    local guiMob = controls and controls:FindFirstChild("Gui-mob")
    if not guiMob then return nil end

    local directNames = { "attack", "Attack", "shoot", "Shoot", "fire", "Fire" }
    for _, name in ipairs(directNames) do
        local btn = guiMob:FindFirstChild(name, true)
        if btn and btn:IsA("GuiObject") then return btn end
    end

    for _, obj in ipairs(guiMob:GetDescendants()) do
        if obj:IsA("GuiButton") and obj.Visible then
            return obj
        end
    end

    return guiMob:IsA("GuiObject") and guiMob or nil
end

function MAWWW_ToFV3IsTouchOnShootButton(input)
    local shootButton = MAWWW_ToFV3GetMobileShootButton()
    if not (shootButton and shootButton.Visible) then return false end

    local pos = input.Position
    local absPos = shootButton.AbsolutePosition
    local absSize = shootButton.AbsoluteSize

    return pos.X >= absPos.X and pos.X <= absPos.X + absSize.X
        and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y
end

function MAWWW_ToFV3DoShoot()
    if not VD.TOF3_SilentAim then return end

    MAWWW_ToFV3AimConfig.Pistol_BlockKnocked = VD.TOF3_BlockKnocked ~= false
    local char = LocalPlayer.Character
    if char then
        if MAWWW_ToFV3AimConfig.Pistol_BlockKnocked and IsDowned(char) then
            return
        end
    end

    local targetDirection, gunObject, originPos, targetPos = MAWWW_ToFV3GetTargetPosition()
    if not (targetDirection and gunObject and targetPos and originPos) then return end

    local tofEvent = MAWWW_ToFV3GetEvent()
    if not tofEvent then return end

    local freshDirection = targetPos - originPos
    if freshDirection.Magnitude < 0.1 then return end

    pcall(function()
        tofEvent:FireServer(gunObject, freshDirection.Unit)
    end)
end

MAWWW_ToFV3ModeButtons = {}
function MAWWW_ToFV3RefreshTargetButtons()
    local modes = {
        Killer = { Color3.fromRGB(180, 45, 45), Color3.fromRGB(255, 180, 180) },
        Survivors = { Color3.fromRGB(25, 80, 150), Color3.fromRGB(160, 210, 255) },
        Zombie = { Color3.fromRGB(120, 80, 10), Color3.fromRGB(255, 210, 100) },
    }

    for modeName, btn in pairs(MAWWW_ToFV3ModeButtons) do
        if btn and btn.Parent then
            local active = modeName == (VD.TOF3_TargetMode or "Killer")
            local colors = modes[modeName]
            btn.BackgroundColor3 = active and colors[1] or Color3.fromRGB(30, 32, 40)
            btn.TextColor3 = active and colors[2] or Color3.fromRGB(155, 160, 175)
        end
    end
end

function MAWWW_ToFV3SetTargetMode(modeName, notify)
    if modeName ~= "Killer" and modeName ~= "Survivors" and modeName ~= "Zombie" then return end
    VD.TOF3_TargetMode = modeName
    MAWWW_ToFV3RefreshTargetButtons()
    if notify then notify("Target Mode", modeName, 1) end
end

function MAWWW_ToFV3CreateTargetSelectorUI()
    local parent = MAWWW_GetSafeGuiParent()
    if not parent then return end
    if MAWWW_ToFV3State.TargetGui and MAWWW_ToFV3State.TargetGui.Parent then return end

    local old = parent:FindFirstChild("ToFTargetSelectorV3")
    if old then pcall(function() old:Destroy() end) end

    local gui = Instance.new("ScreenGui")
    gui.Name = "ToFTargetSelectorV3"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = parent

    local frame = Instance.new("Frame")
    frame.Name = "Main"
    frame.Size = UDim2.new(0, 180, 0, 126)
    frame.Position = MAWWW_ToFV3State.SavedUIPos
    frame.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(96, 72, 160)
    stroke.Thickness = 1

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 28)
    header.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
    header.BorderSizePixel = 0
    header.Parent = frame
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)

    local headerFix = Instance.new("Frame")
    headerFix.Size = UDim2.new(1, 0, 0, 10)
    headerFix.Position = UDim2.new(0, 0, 1, -10)
    headerFix.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
    headerFix.BorderSizePixel = 0
    headerFix.Parent = header

    local headerDiv = Instance.new("Frame")
    headerDiv.Size = UDim2.new(1, 0, 0, 1)
    headerDiv.Position = UDim2.new(0, 0, 1, -1)
    headerDiv.BackgroundColor3 = Color3.fromRGB(48, 42, 72)
    headerDiv.BorderSizePixel = 0
    headerDiv.Parent = header

    local dragArea = Instance.new("Frame")
    dragArea.Size = UDim2.new(1, -34, 1, 0)
    dragArea.BackgroundTransparency = 1
    dragArea.Parent = header

    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 28, 1, 0)
    minimizeBtn.Position = UDim2.new(1, -30, 0, 0)
    minimizeBtn.BackgroundTransparency = 1
    minimizeBtn.Text = "-"
    minimizeBtn.TextColor3 = Color3.fromRGB(185, 190, 205)
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 14
    minimizeBtn.Parent = header

    local headerLbl = Instance.new("TextLabel")
    headerLbl.Size = UDim2.new(1, -44, 1, 0)
    headerLbl.Position = UDim2.new(0, 10, 0, 0)
    headerLbl.BackgroundTransparency = 1
    headerLbl.Text = "TOF  •  TARGET MODE"
    headerLbl.TextColor3 = Color3.fromRGB(210, 215, 230)
    headerLbl.Font = Enum.Font.GothamBold
    headerLbl.TextSize = 10
    headerLbl.TextXAlignment = Enum.TextXAlignment.Left
    headerLbl.Parent = header

    local btnContainer = Instance.new("Frame")
    btnContainer.Size = UDim2.new(1, -16, 0, 86)
    btnContainer.Position = UDim2.new(0, 8, 0, 34)
    btnContainer.BackgroundTransparency = 1
    btnContainer.Parent = frame

    local layout = Instance.new("UIListLayout", btnContainer)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)

    local isMinimized = false
    minimizeBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        minimizeBtn.Text = isMinimized and "+" or "-"
        btnContainer.Visible = not isMinimized
        frame.Size = isMinimized and UDim2.new(0, 180, 0, 28) or UDim2.new(0, 180, 0, 126)
    end)

    local modes = {
        { Internal = "Killer", Display = "KILLER        K" },
        { Internal = "Survivors", Display = "SURVIVOR      J" },
        { Internal = "Zombie", Display = "ZOMBIE        L" },
    }

    MAWWW_ToFV3ModeButtons = {}
    for i, mode in ipairs(modes) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 25)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.Text = mode.Display
        btn.TextXAlignment = Enum.TextXAlignment.Center
        btn.LayoutOrder = i
        btn.Parent = btnContainer
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

        local btnStroke = Instance.new("UIStroke", btn)
        btnStroke.Color = Color3.fromRGB(58, 62, 78)
        btnStroke.Thickness = 1

        btn.MouseButton1Click:Connect(function()
            MAWWW_ToFV3SetTargetMode(mode.Internal, false)
        end)
        btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                MAWWW_ToFV3SetTargetMode(mode.Internal, false)
            end
        end)

        MAWWW_ToFV3ModeButtons[mode.Internal] = btn
    end
    MAWWW_ToFV3RefreshTargetButtons()

    local dragging = false
    local dragStart, startPos
    dragArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragStart = input.Position
            startPos = frame.Position
            dragging = true
        end
    end)
    dragArea.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            local newPos = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
            frame.Position = newPos
            MAWWW_ToFV3State.SavedUIPos = newPos
        end
    end)

    MAWWW_ToFV3State.TargetGui = gui
end

function MAWWW_ToFV3DestroyTargetSelectorUI()
    if MAWWW_ToFV3State.TargetGui then
        pcall(function() MAWWW_ToFV3State.TargetGui:Destroy() end)
        MAWWW_ToFV3State.TargetGui = nil
    end
    MAWWW_ToFV3ModeButtons = {}
end

function MAWWW_ToFV3StartConnection()
    if MAWWW_ToFV3State.Connection then return end
    MAWWW_ToFV3State.Connection = RunService.Heartbeat:Connect(function()
        if not VD.TOF3_SilentAim or not MAWWW_ToFV3State.IsAiming then
            if MAWWW_ToFV3State.LaserBeam then MAWWW_ToFV3State.LaserBeam.Transparency = 1 end
            return
        end

        local _, _, originPos, targetPos = MAWWW_ToFV3GetTargetPosition()
        if originPos and targetPos then
            pcall(function()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and not char:GetAttribute("IsCarried") then
                    hrp.CFrame = CFrame.new(hrp.Position, Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z))
                end
            end)

            if VD.TOF3_Laser then
                MAWWW_ToFV3UpdateLaser(originPos, targetPos)
            elseif MAWWW_ToFV3State.LaserBeam then
                MAWWW_ToFV3State.LaserBeam.Transparency = 1
            end
        elseif MAWWW_ToFV3State.LaserBeam then
            MAWWW_ToFV3State.LaserBeam.Transparency = 1
        end
    end)
end

function MAWWW_ToFV3StopConnection()
    if MAWWW_ToFV3State.Connection then
        pcall(function() MAWWW_ToFV3State.Connection:Disconnect() end)
        MAWWW_ToFV3State.Connection = nil
    end
    MAWWW_ToFV3State.IsAiming = false
    MAWWW_ToFV3ClearLaser()
end

function MAWWW_ToFV3DisconnectInputs()
    if MAWWW_ToFV3State.InputBegan then pcall(function() MAWWW_ToFV3State.InputBegan:Disconnect() end) end
    if MAWWW_ToFV3State.InputEnded then pcall(function() MAWWW_ToFV3State.InputEnded:Disconnect() end) end
    MAWWW_ToFV3State.InputBegan = nil
    MAWWW_ToFV3State.InputEnded = nil
end

MAWWW_SetToFV3SilentAim = nil

function MAWWW_ToFV3EnsureInputs()
    if not MAWWW_ToFV3State.InputBegan then
        MAWWW_ToFV3State.InputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end

            local keyCode = MAWWW_ToFV3KeyCodes[VD.TOF3_Key or "None"]
            if keyCode and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == keyCode then
                MAWWW_SetToFV3SilentAim(not VD.TOF3_SilentAim)
                return
            end

            if not VD.TOF3_SilentAim then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or (input.UserInputType == Enum.UserInputType.Touch and MAWWW_ToFV3IsTouchOnShootButton(input)) then
                MAWWW_ToFV3State.IsAiming = true
                if input.UserInputType == Enum.UserInputType.Touch then
                    MAWWW_ToFV3State.TouchInput = input
                end
                MAWWW_ToFV3DoShoot()
                return
            end

            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.K then
                    MAWWW_ToFV3SetTargetMode("Killer", true)
                elseif input.KeyCode == Enum.KeyCode.J then
                    MAWWW_ToFV3SetTargetMode("Survivors", true)
                elseif input.KeyCode == Enum.KeyCode.L then
                    MAWWW_ToFV3SetTargetMode("Zombie", true)
                end
            end
        end)
    end
    if not MAWWW_ToFV3State.InputEnded then
        MAWWW_ToFV3State.InputEnded = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or (input.UserInputType == Enum.UserInputType.Touch and input == MAWWW_ToFV3State.TouchInput) then
                MAWWW_ToFV3State.IsAiming = false
                if input == MAWWW_ToFV3State.TouchInput then MAWWW_ToFV3State.TouchInput = nil end
                if MAWWW_ToFV3State.LaserBeam then MAWWW_ToFV3State.LaserBeam.Transparency = 1 end
            end
        end)
    end
end

MAWWW_SetToFV3SilentAim = function(enabled)
    VD.TOF3_SilentAim = enabled and true or false
    MAWWW_ToFV3EnsureInputs()
    if VD.TOF3_SilentAim then
        MAWWW_ToFV3CreateTargetSelectorUI()
        MAWWW_ToFV3StartConnection()
    else
        MAWWW_ToFV3DestroyTargetSelectorUI()
        MAWWW_ToFV3StopConnection()
    end
end

MAWWW_ToFV3EnsureInputs()
getgenv().MAWWW_SetToFV3SilentAim = MAWWW_SetToFV3SilentAim
getgenv().MAWWW_ToFV3ClearLaser = MAWWW_ToFV3ClearLaser
getgenv().MAWWW_ToFV3SetTargetMode = MAWWW_ToFV3SetTargetMode
        return { State = MAWWW_ToFV3State, Stop = MAWWW_ToFV3StopConnection, ClearLaser = MAWWW_ToFV3ClearLaser }
        end)()
    end)
    if okModule and type(moduleResult) == "table" then
        TOFV3Module = moduleResult
    else
        warn("[MawwwHub] Silent Pistol / TOF V3 init failed:", moduleResult)
    end
end

-- SILENT PISTOL / TOF V4
-- Adapted from the supplied V4 interceptor so it chains cleanly with the
-- existing __namecall hooks instead of overwriting earlier aim modules.
--========================================================--
RegDivider(Tabs.AimTOFV4)
RegLabel(Tabs.AimTOFV4, "Silent Pistol / TOF V4")

local SilentAimPistolEnabled = VD.PistolEnabled == true
local PistolTargetMode = tostring(VD.PistolTargetMode or "KILLER"):upper()
if PistolTargetMode ~= "KILLER" and PistolTargetMode ~= "SURVIVOR" then
    PistolTargetMode = "KILLER"
end
VD.PistolTargetMode = PistolTargetMode

local PistolMyHRP = nil

local function ApplyAntiSaltoState(enabled)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not enabled) end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not enabled) end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Physics, not enabled) end)
    end
end

local function GetPlayerRoleCompat(plr)
    if not plr or plr == LocalPlayer then return nil end
    local char = plr.Character
    local role = plr:GetAttribute("Role") or (char and char:GetAttribute("Role"))
    if role then
        role = tostring(role):upper()
        if role == "KILLER" then return "KILLER" end
        if role == "SURVIVOR" or role == "SURVIVORS" then return "SURVIVOR" end
    end
    local team = plr.Team
    if team then
        local t = tostring(team.Name):upper()
        if t == "KILLER" then return "KILLER" end
        if t == "SURVIVOR" or t == "SURVIVORS" then return "SURVIVOR" end
    end
    if char then
        local isKiller = char:GetAttribute("IsKiller")
        if isKiller == true then return "KILLER" end
        if isKiller == false then return "SURVIVOR" end
    end
    return nil
end

local function GetKillerHRP()
    for _, plr in ipairs(MawwwGetPlayers()) do
        if plr ~= LocalPlayer and GetPlayerRoleCompat(plr) == "KILLER" then
            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then return hrp end
        end
    end
    return nil
end

local function GetClosestPistolTarget()
    local char = LocalPlayer.Character
    local myRoot = PistolMyHRP or (char and char:FindFirstChild("HumanoidRootPart"))
    if not myRoot then return nil end

    local wantRole = (PistolTargetMode == "KILLER") and "KILLER" or "SURVIVOR"
    local closest, bestDistance = nil, math.huge
    for _, plr in ipairs(MawwwGetPlayers()) do
        if plr ~= LocalPlayer and GetPlayerRoleCompat(plr) == wantRole then
            local pchar = plr.Character
            local hum = pchar and pchar:FindFirstChildOfClass("Humanoid")
            local hrp = pchar and pchar:FindFirstChild("HumanoidRootPart")
            if hrp and (not hum or hum.Health > 0) then
                local dist = (hrp.Position - myRoot.Position).Magnitude
                if dist < bestDistance then
                    bestDistance = dist
                    closest = hrp
                end
            end
        end
    end
    return closest
end

local rawNamecallV4
if typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function" then
    pcall(function()
        rawNamecallV4 = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if not checkcaller() and (method == "FireServer" or method == "fireServer") then
                local isTwistOfFateFire = false
                pcall(function()
                    isTwistOfFateFire = tostring(self) == "Fire" and self.Parent and self.Parent.Name == "Twist of Fate"
                end)

                if isTwistOfFateFire and SilentAimPistolEnabled then
                    local char = LocalPlayer.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if char and hum and hum.Health > 0 then
                        local targetPart = (PistolTargetMode == "KILLER") and GetKillerHRP() or GetClosestPistolTarget()
                        if targetPart and PistolMyHRP then
                            local originPos = PistolMyHRP.Position + Vector3.new(0, 1.5, 0)
                            local delta = targetPart.Position - originPos
                            if delta.Magnitude > 0.001 and args[2] and typeof(args[2]) == "Vector3" then
                                args[2] = delta.Unit
                                pcall(function() setnamecallmethod("FireServer") end)
                                return rawNamecallV4(self, table.unpack(args))
                            end
                        end
                    end
                end
            end
            return rawNamecallV4(self, ...)
        end)
    end)
else
    warn("[Mawww Hub] Silent Pistol V4 requires hookmetamethod/getnamecallmethod.")
end

local function UpdatePistolHRP(char)
    PistolMyHRP = char and char:FindFirstChild("HumanoidRootPart") or nil
    if char and not PistolMyHRP then
        PistolMyHRP = char:WaitForChild("HumanoidRootPart", 5)
    end
    if SilentAimPistolEnabled then
        task.delay(0.5, function()
            if SilentAimPistolEnabled then ApplyAntiSaltoState(true) end
        end)
    end
end

PistolMyHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or nil
if not getgenv().MAWWW_SilentPistolV4CharacterHook then
    getgenv().MAWWW_SilentPistolV4CharacterHook = LocalPlayer.CharacterAdded:Connect(UpdatePistolHRP)
end

getgenv().MAWWW_SilentPistolV4SetEnabled = function(enabled)
    SilentAimPistolEnabled = enabled == true
    VD.PistolEnabled = SilentAimPistolEnabled
    ApplyAntiSaltoState(SilentAimPistolEnabled)
end

getgenv().MAWWW_SilentPistolV4SetTargetMode = function(mode)
    mode = tostring(mode or "KILLER"):upper()
    if mode ~= "KILLER" and mode ~= "SURVIVOR" then mode = "KILLER" end
    PistolTargetMode = mode
    VD.PistolTargetMode = mode
end

RegToggle(Tabs.AimTOFV4, "Silent Pistol V4", "Redirect Twist of Fate pistol shots to the selected target.", SilentAimPistolEnabled, "PistolEnabled", function(v)
    SilentAimPistolEnabled = v == true
    if getgenv().MAWWW_SilentPistolV4SetEnabled then
        pcall(getgenv().MAWWW_SilentPistolV4SetEnabled, SilentAimPistolEnabled)
    end
end)

RegDropdown(Tabs.AimTOFV4, "Target Mode", "Choose the role used by V4 targeting.", {"KILLER", "SURVIVOR"}, PistolTargetMode, false, "PistolTargetMode", function(v)
    PistolTargetMode = tostring(v or "KILLER"):upper()
    if getgenv().MAWWW_SilentPistolV4SetTargetMode then
        pcall(getgenv().MAWWW_SilentPistolV4SetTargetMode, PistolTargetMode)
    end
end)

-- UI: SILENT PISTOL / TOF V3
RegDivider(Tabs.AimTOFV3)
RegLabel(Tabs.AimTOFV3, "Silent Pistol / TOF V3")
RegToggle(Tabs.AimTOFV3, "Silent Pistol / TOF V3", "Independent V3 clone of the V1 Twist of Fate engine.", false, "TOF3_SilentAim", function(v)
    VD.TOF3_SilentAim = v == true
    if getgenv().MAWWW_SetToFV3SilentAim then pcall(getgenv().MAWWW_SetToFV3SilentAim, VD.TOF3_SilentAim) end
    notify("TOF V3", v and "ON" or "OFF", 2)
end)
RegDropdown(Tabs.AimTOFV3, "Target Mode", "Killer / Survivors / Zombie", {"Killer", "Survivors", "Zombie"}, "Killer", false, "TOF3_TargetMode", function(v)
    VD.TOF3_TargetMode = v or "Killer"
    if getgenv().MAWWW_ToFV3SetTargetMode then pcall(getgenv().MAWWW_ToFV3SetTargetMode, VD.TOF3_TargetMode, false) end
end)
RegToggle(Tabs.AimTOFV3, "Wall Check", "Require clear line of sight.", false, "TOF3_WallCheck")
RegToggle(Tabs.AimTOFV3, "Laser", "Show the V3 aim laser.", true, "TOF3_Laser", function(v)
    VD.TOF3_Laser = v == true
    if not VD.TOF3_Laser and getgenv().MAWWW_ToFV3ClearLaser then pcall(getgenv().MAWWW_ToFV3ClearLaser) end
end)
RegToggle(Tabs.AimTOFV3, "Block When Downed", "Do not fire while downed/dead.", true, "TOF3_BlockKnocked")
RegDropdown(Tabs.AimTOFV3, "Silent Aim Key", "Toggle key for Silent Pistol / TOF V3.", {"None", "Q", "E", "R", "T", "F", "G", "H", "J", "K", "L", "X", "Z"}, "None", false, "TOF3_Key")



--========================================================--
-- SILENT VEIL V5 — imported from supplied silentaimveil.lua
-- Full homing / ballistic prediction core from the supplied source, integrated into Mawww Hub.
-- Standalone source UI removed; all controls are exposed below.
--========================================================--
do
-- Silent Aim Veil (Homing Spear) — A2 V16 extract
-- Full settings panel UI
-- FOV, Gravity, Lead, Homing Duration/Hit/Rate, Arc Homing,
-- Close Direct/Lock Range, Sticky Lock, Run To Target,
-- Ping Compensation, Distance Priority, Show Player Markers

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Stats = game:GetService("Stats")

-- firesignal shim
if not firesignal then
    function firesignal(sig, ...)
        for _, c in pairs(getconnections(sig)) do
            if c.Function then pcall(c.Function, ...) end
        end
    end
end


-- =====================================================================
--  SILENT AIM VEIL — PREDICTIVE SPEAR + RUN-TO-TARGET (HOMING UPDATE)
--  - Tombak keluar normal + HOMING langsung ngejar target ESP
--  - Pakai firesignal(visualizeEvent.OnClientEvent, ...) untuk visual
--  - Pakai Spearthrow:FireServer untuk trigger tombak asli
--  - V2.1: RunToTarget = visual tombak di-redirect terus tiap tick ke target
-- =====================================================================
local MawwwVeilV5Config = {
    Enabled = false,
    ShowFOV = true,
    FOV = 300,
    SpearSpeed = 165,
    Gravity = math.max(0, (workspace.Gravity or 196.2) * 0.5),
    AutoGravity = true,
    AutoPredict = true,
    MaxDist = 1000,
    TargetPart = "Torso",
    LeadMultiplier = 1.0,
    CloseRange = 15,
    ShowMarkers = true,
    MarkerSize = 1500,

    -- V2.1: RUN TO TARGET (Homing)
    RunToTarget = true,        -- aktif = tombak langsung ngejar target
    HomingDuration = 1.4,      -- berapa lama homing aktif (detik)
    HomingRate = 0.02,         -- seberapa cepat update arah (50 Hz)
    HomingHitDist = 4,         -- jarak dianggap "kena" target
    DirectAim = true,          -- jarak dekat memakai garis lurus; jarak jauh tetap ballistic arc
    LongRangeArc = true,       -- jarak jauh selalu melambung seperti Predictive Spear
    ArcStartRange = 65,        -- mulai memakai lintasan melambung pada jarak ini
    ArcHomingDelay = 0.18,     -- beri waktu lintasan melambung sebelum homing mengambil alih
    StrictFOV = true,          -- target baru wajib berada di dalam lingkaran POV/FOV

    -- V2.2: FIX target orang deket yang lagi jalan
    CloseLockRange = 60,       -- target sedekat ini SELALU kekunci walau di luar FOV / di belakang layar
    StickyLock = true,         -- target dikunci sampai mati/hilang, ga gonta-ganti pas homing
    StickySwitchGain = 0.55,   -- target baru harus 45% lebih "bagus" buat ngerebut lock
    DistanceBias = 0.75,       -- makin besar = makin milih yang paling deket badan
    PingCompensation = true,   -- tambah lead sesuai ping biar ga ketinggalan
    ExtraLeadTime = 0.06,      -- lead tambahan (detik)
};

local MawwwVeilV5State = {
    Charging = false,
    TouchInput = nil,
    AttackCooldown = false,
    SuppressNextThrow = false,
    SuppressUntil = 0,
    LastPredictedPos = nil,
    LastPredictedUntil = 0,
    Hooked = false,
    CurrentGUID = nil,
    CurrentTargetPos = nil,

    -- V2.1
    HomingThread = nil,
    HomingActive = false,

    -- V2.2
    LockedPlayer = nil,
};
local MawwwVeilV5VelocityCache = {};
local MawwwVeilV5DrawingAvailable = false;
pcall(function() MawwwVeilV5DrawingAvailable = typeof(Drawing) == "table" and type(Drawing.new) == "function" end);

-- V2: Drawing Pools untuk mencegah lag
local MawwwVeilV5CirclePool = {};
local MawwwVeilV5TextPool = {};

local function MawwwVeilV5GetCircleFromPool(index)
    if not MawwwVeilV5CirclePool[index] then
        local circle = Drawing.new("Circle");
        circle.Thickness = 1.5;
        circle.Filled = false;
        circle.Visible = false;
        MawwwVeilV5CirclePool[index] = circle;
    end;
    return MawwwVeilV5CirclePool[index];
end;

local function MawwwVeilV5GetTextFromPool(index)
    if not MawwwVeilV5TextPool[index] then
        local text = Drawing.new("Text");
        text.Size = 14;
        text.Center = true;
        text.Outline = true;
        text.OutlineColor = Color3.new(0, 0, 0);
        text.Visible = false;
        MawwwVeilV5TextPool[index] = text;
    end;
    return MawwwVeilV5TextPool[index];
end;

local MawwwVeilV5Draw = { Highlight = Instance.new("Highlight") };
if MawwwVeilV5DrawingAvailable then
    pcall(function()
        MawwwVeilV5Draw.FOVCircle = Drawing.new("Circle");
        MawwwVeilV5Draw.FOVCircle.Color = Color3.fromRGB(220, 70, 70);
        MawwwVeilV5Draw.FOVCircle.Thickness = 2;
        MawwwVeilV5Draw.FOVCircle.Filled = false;
        MawwwVeilV5Draw.FOVCircle.Visible = false;

        -- V2: Tracer Line
        MawwwVeilV5Draw.Tracer = Drawing.new("Line");
        MawwwVeilV5Draw.Tracer.Thickness = 2.5;
        MawwwVeilV5Draw.Tracer.Color = Color3.fromRGB(220, 70, 70);
        MawwwVeilV5Draw.Tracer.Visible = false;

        -- V2: Target Marker (Red Circle)
        MawwwVeilV5Draw.TargetMarker = Drawing.new("Circle");
        MawwwVeilV5Draw.TargetMarker.Color = Color3.fromRGB(255, 40, 40);
        MawwwVeilV5Draw.TargetMarker.Thickness = 3;
        MawwwVeilV5Draw.TargetMarker.Filled = false;
        MawwwVeilV5Draw.TargetMarker.Visible = false;
    end);
end;
MawwwVeilV5Draw.Highlight.Name = "Mawww_VeilV5_Target";
MawwwVeilV5Draw.Highlight.FillColor = Color3.fromRGB(220, 70, 70);
MawwwVeilV5Draw.Highlight.OutlineColor = Color3.fromRGB(255, 255, 255);
MawwwVeilV5Draw.Highlight.FillTransparency = 0.35;
MawwwVeilV5Draw.Highlight.OutlineTransparency = 0;
MawwwVeilV5Draw.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop;

-- GUI FOV fallback (works without Drawing library / mobile)
local function MawwwVeilV5EnsureGuiFOV()
    if MawwwVeilV5Draw.GuiFOV and MawwwVeilV5Draw.GuiFOV.Parent then return end
    local parent
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then parent = h end
    end
    if not parent then
        local ok, core = pcall(function() return game:GetService("CoreGui") end)
        if ok and core then parent = core end
    end
    if not parent then
        parent = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    end
    if not parent then return end

    local old = parent:FindFirstChild("VEIL_V12_FOVGui")
    if old then pcall(function() old:Destroy() end) end

    local sg = Instance.new("ScreenGui")
    sg.Name = "VEIL_V12_FOVGui"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 999990
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = parent

    local frame = Instance.new("Frame")
    frame.Name = "FOVCircle"
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.Size = UDim2.fromOffset(300, 300)
    frame.BackgroundTransparency = 1
    frame.Visible = false
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0)
    local st = Instance.new("UIStroke")
    st.Name = "Stroke"
    st.Color = Color3.fromRGB(220, 70, 70)
    st.Thickness = 2.5
    st.Transparency = 0
    st.Parent = frame

    -- tracer line approx using Frame rotated - optional simple vertical line from bottom
    local tracer = Instance.new("Frame")
    tracer.Name = "Tracer"
    tracer.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
    tracer.BorderSizePixel = 0
    tracer.AnchorPoint = Vector2.new(0.5, 1)
    tracer.Position = UDim2.fromScale(0.5, 1)
    tracer.Size = UDim2.fromOffset(2, 0)
    tracer.Visible = false
    tracer.Parent = sg

    MawwwVeilV5Draw.GuiFOV = frame
    MawwwVeilV5Draw.GuiFOVStroke = st
    MawwwVeilV5Draw.GuiTracer = tracer
    MawwwVeilV5Draw.GuiRoot = sg
end
pcall(MawwwVeilV5EnsureGuiFOV)

local function MawwwVeilV5HideAllMarkers()
    for _, circle in pairs(MawwwVeilV5CirclePool) do circle.Visible = false end;
    for _, text in pairs(MawwwVeilV5TextPool) do text.Visible = false end;
    if MawwwVeilV5Draw.TargetMarker then MawwwVeilV5Draw.TargetMarker.Visible = false end;
end;

-- Forward declare (didefinisikan setelah MawwwVeilV5Fire)
local MawwwVeilV5StopHoming;

local function MawwwVeilV5HideDrawings()
    if MawwwVeilV5StopHoming then MawwwVeilV5StopHoming() end;
    if MawwwVeilV5Draw.FOVCircle then MawwwVeilV5Draw.FOVCircle.Visible = false end;
    if MawwwVeilV5Draw.Tracer then MawwwVeilV5Draw.Tracer.Visible = false end;
    if MawwwVeilV5Draw.GuiFOV then MawwwVeilV5Draw.GuiFOV.Visible = false end;
    if MawwwVeilV5Draw.GuiTracer then MawwwVeilV5Draw.GuiTracer.Visible = false end;
    MawwwVeilV5Draw.Highlight.Parent = nil;
    MawwwVeilV5HideAllMarkers();
end;

local function MawwwVeilV5GenerateGUID()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx";
    return string.gsub(template, "[xy]", function(c)
        local v = (c == "x") and math.random(0, 15) or math.random(8, 11);
        return string.format("%x", v);
    end);
end;

local function MawwwVeilV5TargetPart(character)
    if not character then return nil end;
    if MawwwVeilV5Config.TargetPart == "Head" then return character:FindFirstChild("Head") end;
    if MawwwVeilV5Config.TargetPart == "Root" then return character:FindFirstChild("HumanoidRootPart") end;
    return character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart");
end;

local function MawwwVeilV5Velocity(part, playerName)
    if not part then return Vector3.zero end;
    local now = os.clock();
    local assemblyVelocity = Vector3.zero;
    pcall(function() assemblyVelocity = part.AssemblyLinearVelocity end);
    local cache = MawwwVeilV5VelocityCache[playerName];
    if not cache then
        MawwwVeilV5VelocityCache[playerName] = { LastPos = part.Position, LastTime = now, Velocity = assemblyVelocity };
        return assemblyVelocity;
    end;
    local dt = now - cache.LastTime;
    local measured = Vector3.zero;
    if dt > 0.01 then measured = (part.Position - cache.LastPos) / dt end;
    if measured.Magnitude > 250 then measured = assemblyVelocity end;
    local chosen = measured.Magnitude > 0.05 and measured or assemblyVelocity;
    if chosen.Magnitude < 250 then cache.Velocity = cache.Velocity:Lerp(chosen, 0.45) end;
    cache.LastPos = part.Position;
    cache.LastTime = now;
    return cache.Velocity;
end;

-- V2.2: ping (buat kompensasi lead)
local function MawwwVeilV5Ping()
    if not MawwwVeilV5Config.PingCompensation then return 0 end;
    local ping = 0;
    pcall(function()
        local stat = game:GetService("Stats").Network.ServerStatsItem["Data Ping"];
        ping = stat:GetValue() / 1000;
    end);
    return math.clamp(ping, 0, 0.5);
end;

-- V2.3: target baru hanya boleh dipilih dari dalam lingkaran POV/FOV
local function MawwwVeilV5GetAllTargets()
    local localPlayer = game:GetService("Players").LocalPlayer;
    local localCharacter = localPlayer.Character;
    local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart");
    local camera = workspace.CurrentCamera;
    if not localRoot or not camera then return {} end;

    local targets = {};
    local center = Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y * 0.5);
    local closeRange = math.max(0, tonumber(MawwwVeilV5Config.CloseLockRange) or 60);
    local bias = math.max(0, tonumber(MawwwVeilV5Config.DistanceBias) or 0.75);

    for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
        if player ~= localPlayer and player.Team and player.Team.Name == "Survivors" and player.Character then
            local character = player.Character;
            local humanoid = character:FindFirstChildOfClass("Humanoid");
            local part = MawwwVeilV5TargetPart(character);
            if humanoid and humanoid.Health > 0 and part then
                local distance3D = (part.Position - localRoot.Position).Magnitude;
                if distance3D <= MawwwVeilV5Config.MaxDist then
                    local screen, onScreen = camera:WorldToViewportPoint(part.Position);
                    local screenPos = Vector2.new(screen.X, screen.Y);
                    local screenDistance = (screenPos - center).Magnitude;
                    local isClose = distance3D <= closeRange;
                    local inFOV = onScreen and screenDistance <= MawwwVeilV5Config.FOV;

                    -- V2.3: lingkaran POV adalah batas lock; target dekat tetap diprioritaskan bila ada di dalamnya
                    if inFOV or (not MawwwVeilV5Config.StrictFOV and isClose) then
                        local score = (onScreen and screenDistance or (screenDistance + 2000)) + distance3D * bias;
                        if isClose then score = score - 1500 end;
                        table.insert(targets, {
                            Player = player,
                            Part = part,
                            Distance = distance3D,
                            ScreenPos = screenPos,
                            ScreenDistance = screenDistance,
                            OnScreen = onScreen,
                            IsClose = isClose,
                            Score = score,
                            Humanoid = humanoid
                        });
                    end;
                end;
            end;
        end;
    end;

    table.sort(targets, function(a, b)
        return a.Score < b.Score;
    end);

    return targets;
end;

-- V2.2: sticky lock — target yang udah dikunci ga gampang lepas
local function MawwwVeilV5ClosestTarget(preferPlayer)
    local targets = MawwwVeilV5GetAllTargets();
    local best = targets[1];
    if not best then return nil end;

    local wanted = preferPlayer or (MawwwVeilV5Config.StickyLock and MawwwVeilV5State.LockedPlayer or nil);
    if wanted then
        for _, t in ipairs(targets) do
            if t.Player == wanted then
                return t; -- target lama masih valid: tetap dikejar
            end;
        end;
    end;
    return best;
end;

local function MawwwVeilV5BallisticDirection(startPosition, targetPosition, targetVelocity)
    local speed = math.max(1, tonumber(MawwwVeilV5Config.SpearSpeed) or 165);
    local gravity = MawwwVeilV5Config.AutoGravity and math.max(0, (workspace.Gravity or 196.2) * 0.5) or math.max(0, tonumber(MawwwVeilV5Config.Gravity) or 0);
    local lead = MawwwVeilV5Config.AutoPredict and (tonumber(MawwwVeilV5Config.LeadMultiplier) or 1) or 0;
    local predicted = targetPosition;
    local travelTime = (targetPosition - startPosition).Magnitude / speed;
    local direction = (targetPosition - startPosition).Unit;
    for _ = 1, 4 do
        predicted = targetPosition + targetVelocity * travelTime * lead;
        local offset = predicted - startPosition;
        local distance = offset.Magnitude;
        if distance <= MawwwVeilV5Config.CloseRange then
            return offset.Unit, predicted;
        end;
        local horizontal = Vector3.new(offset.X, 0, offset.Z);
        local range = horizontal.Magnitude;
        if range < 0.05 or gravity <= 0 then
            direction = offset.Unit;
        else
            local speedSquared = speed * speed;
            local discriminant = speedSquared * speedSquared - gravity * (gravity * range * range + 2 * offset.Y * speedSquared);
            if discriminant <= 0 then
                direction = offset.Unit;
            else
                local tangent = (speedSquared - math.sqrt(discriminant)) / (gravity * range);
                local cosine = 1 / math.sqrt(1 + tangent * tangent);
                direction = (horizontal.Unit * cosine + Vector3.new(0, tangent * cosine, 0)).Unit;
            end;
        end;
        travelTime = distance / speed;
    end;
    return direction, predicted;
end;

-- =====================================================================
--  V2.1: RUN TO TARGET — homing spear ke target ESP
-- =====================================================================
MawwwVeilV5StopHoming = function()
    if MawwwVeilV5State.HomingThread then
        pcall(task.cancel, MawwwVeilV5State.HomingThread);
        MawwwVeilV5State.HomingThread = nil;
    end;
    MawwwVeilV5State.HomingActive = false;
    MawwwVeilV5State.LockedPlayer = nil;
end;

local function MawwwVeilV5StartHoming(initialTarget, character, startPosition, initialDirection, launchDistance)
    MawwwVeilV5StopHoming();

    local remotes        = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes");
    local mechanics      = remotes and remotes:FindFirstChild("Mechanics");
    local visualizeEvent = mechanics and mechanics:FindFirstChild("visualize");
    local visualizeStop  = mechanics and mechanics:FindFirstChild("visualizeStop");

    if not visualizeEvent or not firesignal then
        return false;
    end;

    local speed     = math.max(1, tonumber(MawwwVeilV5Config.SpearSpeed) or 165);
    local duration  = tonumber(MawwwVeilV5Config.HomingDuration) or 1.4;
    local rate      = math.max(0.02, tonumber(MawwwVeilV5Config.HomingRate) or 0.04);
    local hitDist   = tonumber(MawwwVeilV5Config.HomingHitDist) or 3;

    MawwwVeilV5State.HomingActive = true;

    MawwwVeilV5State.HomingThread = task.spawn(function()
        -- V2.3: pada jarak jauh biarkan tombak melambung dulu, baru koreksi ke target bergerak
        local useArc = MawwwVeilV5Config.LongRangeArc and (tonumber(launchDistance) or 0) > (tonumber(MawwwVeilV5Config.ArcStartRange) or 65);
        local arcDelay = useArc and math.max(0, tonumber(MawwwVeilV5Config.ArcHomingDelay) or 0.18) or 0;
        local launchDirection = initialDirection or workspace.CurrentCamera.CFrame.LookVector;
        if arcDelay > 0 then task.wait(arcDelay) end;

        local startTime   = os.clock();
        local lastTick    = startTime;
        local simPos      = startPosition + launchDirection * speed * arcDelay;
        if useArc then
            local gravity = MawwwVeilV5Config.AutoGravity and math.max(0, (workspace.Gravity or 196.2) * 0.5) or math.max(0, tonumber(MawwwVeilV5Config.Gravity) or 0);
            simPos = simPos - Vector3.new(0, 0.5 * gravity * arcDelay * arcDelay, 0);
        end;
        local currentGUID = nil;
        local lastTarget  = initialTarget;

        while MawwwVeilV5State.HomingActive and (os.clock() - startTime) < duration do
            local now = os.clock();
            local dt  = math.max(0, now - lastTick);
            lastTick  = now;

            -- V2.2: kunci target yang sama terus (sticky), jangan gonta-ganti pas melayang
            local lockPlayer = (initialTarget and initialTarget.Player) or MawwwVeilV5State.LockedPlayer;
            local live = MawwwVeilV5ClosestTarget(lockPlayer) or lastTarget;

            if live and live.Part and live.Part.Parent then
                lastTarget = live;
                MawwwVeilV5State.LockedPlayer = live.Player;

                local velocity    = MawwwVeilV5Velocity(live.Part, live.Player.Name);
                local distance    = (live.Part.Position - simPos).Magnitude;
                local leadTime    = distance / speed + MawwwVeilV5Ping() + (tonumber(MawwwVeilV5Config.ExtraLeadTime) or 0);
                local predicted   = live.Part.Position + velocity * leadTime * (tonumber(MawwwVeilV5Config.LeadMultiplier) or 1);

                local direction = (predicted - simPos);
                if direction.Magnitude < 0.01 then
                    direction = (live.Part.Position - simPos);
                end;
                direction = direction.Unit;

                -- kalau udah deket banget, tembak lurus ke badan biar pasti nyangkut
                if distance <= math.max(4, hitDist * 2) then
                    direction = (live.Part.Position - simPos).Unit;
                end;

                simPos = simPos + direction * speed * dt;

                if currentGUID and visualizeStop then
                    pcall(function()
                        firesignal(visualizeStop.OnClientEvent, currentGUID, simPos);
                    end);
                end;

                local newGUID = MawwwVeilV5GenerateGUID();
                pcall(function()
                    firesignal(visualizeEvent.OnClientEvent,
                        character,
                        direction,
                        speed,
                        0.1,
                        newGUID
                    );
                end);

                currentGUID = newGUID;
                MawwwVeilV5State.CurrentGUID = newGUID;
                MawwwVeilV5State.CurrentTargetPos = predicted;
                MawwwVeilV5State.LastPredictedPos = predicted;
                MawwwVeilV5State.LastPredictedUntil = now + 0.2;

                if (simPos - live.Part.Position).Magnitude <= hitDist then
                    break;
                end;
            else
                local dir = workspace.CurrentCamera.CFrame.LookVector;
                simPos = simPos + dir * speed * dt;

                if currentGUID and visualizeStop then
                    pcall(function()
                        firesignal(visualizeStop.OnClientEvent, currentGUID, simPos);
                    end);
                end;
                currentGUID = nil;
                break;
            end;

            task.wait(rate);
        end

        if currentGUID and visualizeStop then
            pcall(function()
                firesignal(visualizeStop.OnClientEvent, currentGUID, simPos);
            end);
        end

        MawwwVeilV5State.CurrentGUID = nil;
        MawwwVeilV5State.CurrentTargetPos = nil;
        MawwwVeilV5State.HomingActive = false;
    end);

    return true;
end;

-- =====================================================================
--  FIRE SPEAR dengan VISUAL REDIRECT ke target
-- =====================================================================
local function MawwwVeilV5Fire()
    if not MawwwVeilV5Config.Enabled or MawwwVeilV5State.AttackCooldown then return end;

    local localPlayer = game:GetService("Players").LocalPlayer;
    local character   = localPlayer.Character;
    if not character or character:GetAttribute("spearmode") ~= true then return end;

    MawwwVeilV5State.AttackCooldown = true;
    task.delay(0.18, function() MawwwVeilV5State.AttackCooldown = false end);

    local startPart = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart");
    if not startPart then return end;

    local startPosition = startPart.Position;
    -- V2.2: pilih target fresh tiap lempar (orang deket yang lagi jalan tetap kepilih)
    MawwwVeilV5State.LockedPlayer = nil;
    local target        = MawwwVeilV5ClosestTarget();
    local aimDirection  = workspace.CurrentCamera.CFrame.LookVector;
    local targetPosition = nil;

    -- Hitung arah lempar awal
    if target and target.Part then
        MawwwVeilV5State.LockedPlayer = target.Player;
        local velocity = MawwwVeilV5Velocity(target.Part, target.Player.Name);

        local dist = (target.Part.Position - startPosition).Magnitude;
        local useArc = MawwwVeilV5Config.LongRangeArc and dist > (tonumber(MawwwVeilV5Config.ArcStartRange) or 65);

        -- V2.3 hybrid: dekat lurus dan responsif, jauh selalu melambung dengan prediksi gerakan
        if MawwwVeilV5Config.DirectAim and not useArc then
            local leadTime = dist / math.max(1, MawwwVeilV5Config.SpearSpeed) + MawwwVeilV5Ping() + (tonumber(MawwwVeilV5Config.ExtraLeadTime) or 0);
            local predicted = target.Part.Position + velocity * leadTime * (tonumber(MawwwVeilV5Config.LeadMultiplier) or 1);
            if dist <= math.max(4, tonumber(MawwwVeilV5Config.HomingHitDist) or 4) * 2 then
                predicted = target.Part.Position;
            end;
            aimDirection = (predicted - startPosition).Unit;
            MawwwVeilV5State.LastPredictedPos = predicted;
        else
            aimDirection, MawwwVeilV5State.LastPredictedPos =
                MawwwVeilV5BallisticDirection(startPosition, target.Part.Position, velocity);
        end;

        MawwwVeilV5State.LastPredictedUntil = os.clock() + 1.25;
        targetPosition = MawwwVeilV5State.LastPredictedPos or target.Part.Position;
    else
        MawwwVeilV5State.LastPredictedPos   = nil;
        MawwwVeilV5State.LastPredictedUntil = 0;
    end;

    -- Fire visualize sekali untuk lemparan awal
    local visualizeEvent, visualizeStopEvent;
    pcall(function()
        local remotes   = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes");
        local mechanics = remotes and remotes:FindFirstChild("Mechanics");
        visualizeEvent      = mechanics and mechanics:FindFirstChild("visualize");
        visualizeStopEvent  = mechanics and mechanics:FindFirstChild("visualizeStop");

        if visualizeEvent and firesignal then
            if MawwwVeilV5State.CurrentGUID and visualizeStopEvent and MawwwVeilV5State.CurrentTargetPos then
                pcall(function()
                    firesignal(visualizeStopEvent.OnClientEvent, MawwwVeilV5State.CurrentGUID, MawwwVeilV5State.CurrentTargetPos);
                end);
            end;

            local newGUID = MawwwVeilV5GenerateGUID();
            MawwwVeilV5State.CurrentGUID      = newGUID;
            MawwwVeilV5State.CurrentTargetPos = targetPosition or (startPosition + aimDirection * 100);

            firesignal(visualizeEvent.OnClientEvent,
                character,
                aimDirection,
                MawwwVeilV5Config.SpearSpeed,
                0.5,
                newGUID
            );

            task.delay(1.5, function()
                if visualizeStopEvent and MawwwVeilV5State.CurrentGUID == newGUID and not MawwwVeilV5State.HomingActive then
                    pcall(function()
                        firesignal(visualizeStopEvent.OnClientEvent, newGUID, MawwwVeilV5State.CurrentTargetPos);
                    end);
                    MawwwVeilV5State.CurrentGUID = nil;
                    MawwwVeilV5State.CurrentTargetPos = nil;
                end;
            end);
        end;
    end);

    -- Fire Spearthrow ke server (yang bikin damage)
    MawwwVeilV5State.SuppressNextThrow = true;
    MawwwVeilV5State.SuppressUntil = os.clock() + 0.35;

    pcall(function()
        local remotes    = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes");
        local killers    = remotes and remotes:FindFirstChild("Killers");
        local veil       = killers and killers:FindFirstChild("Veil");
        local spearThrow = veil and veil:FindFirstChild("Spearthrow");
        if spearThrow then
            spearThrow:FireServer(aimDirection, MawwwVeilV5Config.SpearSpeed, startPosition);
        end
    end);

    task.delay(0.4, function() MawwwVeilV5State.SuppressNextThrow = false end);

    -- MULAI HOMING (langsung lari ke target)
    if MawwwVeilV5Config.RunToTarget and target and target.Part then
        task.spawn(function()
            MawwwVeilV5StartHoming(target, character, startPosition, aimDirection, target.Distance);
        end);
    end;
end;

-- ===== Hook suppress throw manual duplicate =====
if type(hookmetamethod) == "function" and type(getnamecallmethod) == "function" then
    pcall(function()
        local oldNamecall;
        oldNamecall = hookmetamethod(game, "__namecall", (newcclosure or function(fn) return fn end)(function(self, ...) 
            if getnamecallmethod() == "FireServer" and self.Name == "Spearthrow" then
                if MawwwVeilV5State.SuppressNextThrow and os.clock() <= MawwwVeilV5State.SuppressUntil then
                    if type(checkcaller) == "function" and not checkcaller() then
                        MawwwVeilV5State.SuppressNextThrow = false;
                        return nil;
                    end;
                end;
            end;
            return oldNamecall(self, ...);
        end));
        MawwwVeilV5State.Hooked = true;
    end);
end;

-- ===== Input handling =====
local MawwwVeilV5UserInput = game:GetService("UserInputService");
MawwwVeilV5UserInput.InputBegan:Connect(function(input, gameProcessed)
    local isTouch = input.UserInputType == Enum.UserInputType.Touch;
    if gameProcessed and not isTouch then return end;
    local character = game:GetService("Players").LocalPlayer.Character;
    if not MawwwVeilV5Config.Enabled or not character or character:GetAttribute("spearmode") ~= true then return end;
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        MawwwVeilV5State.Charging = true;
    elseif isTouch then
        local playerGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui");
        local slasher = playerGui and playerGui:FindFirstChild("Slasher-mob");
        local controls = slasher and slasher:FindFirstChild("Controls");
        local attack = controls and controls:FindFirstChild("attack");
        if attack and attack.Visible then
            local position = input.Position;
            local absolutePosition, absoluteSize = attack.AbsolutePosition, attack.AbsoluteSize;
            if position.X >= absolutePosition.X and position.X <= absolutePosition.X + absoluteSize.X and position.Y >= absolutePosition.Y and position.Y <= absolutePosition.Y + absoluteSize.Y then
                MawwwVeilV5State.Charging = true;
                MawwwVeilV5State.TouchInput = input;
            end;
        end;
    end;
end);
MawwwVeilV5UserInput.InputEnded:Connect(function(input)
    if MawwwVeilV5State.Charging and (input == MawwwVeilV5State.TouchInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
        MawwwVeilV5State.Charging = false;
        if MawwwVeilV5State.TouchInput == input then MawwwVeilV5State.TouchInput = nil end;
        MawwwVeilV5Fire();
    end;
end);

-- ===== Render loop (UPDATED WITH V2 MARKERS) =====
game:GetService("RunService").RenderStepped:Connect(function()
    local camera = workspace.CurrentCamera;
    local localPlayer = game:GetService("Players").LocalPlayer;
    local character = localPlayer.Character;
    local spearMode = character and character:GetAttribute("spearmode") == true;
    local localRoot = character and character:FindFirstChild("HumanoidRootPart");

    if not MawwwVeilV5Config.Enabled or not spearMode or not localRoot then
        MawwwVeilV5HideDrawings();
        return;
    end;

    -- FOV Circle (Drawing + GUI fallback so always visible)
    pcall(MawwwVeilV5EnsureGuiFOV);
    local fovR = tonumber(MawwwVeilV5Config.FOV) or 300;
    if MawwwVeilV5Config.ShowFOV then
        if MawwwVeilV5Draw.FOVCircle then
            MawwwVeilV5Draw.FOVCircle.Visible = true;
            MawwwVeilV5Draw.FOVCircle.Radius = fovR;
            MawwwVeilV5Draw.FOVCircle.Position = Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y * 0.5);
            MawwwVeilV5Draw.FOVCircle.Color = Color3.fromRGB(220, 70, 70);
            MawwwVeilV5Draw.FOVCircle.Thickness = 2;
        end
        if MawwwVeilV5Draw.GuiFOV then
            local diam = math.floor(fovR * 2);
            MawwwVeilV5Draw.GuiFOV.Size = UDim2.fromOffset(diam, diam);
            MawwwVeilV5Draw.GuiFOV.Visible = true;
            if MawwwVeilV5Draw.GuiFOVStroke then
                MawwwVeilV5Draw.GuiFOVStroke.Color = Color3.fromRGB(220, 70, 70);
                MawwwVeilV5Draw.GuiFOVStroke.Thickness = 2.5;
            end
        end
    else
        if MawwwVeilV5Draw.FOVCircle then MawwwVeilV5Draw.FOVCircle.Visible = false end;
        if MawwwVeilV5Draw.GuiFOV then MawwwVeilV5Draw.GuiFOV.Visible = false end;
    end;

    local targets = MawwwVeilV5GetAllTargets();
    local primaryTarget = targets[1];

    MawwwVeilV5HideAllMarkers();

    -- Draw Player Markers (White circles + Text)
    if MawwwVeilV5Config.ShowMarkers then
        for i, target in ipairs(targets) do
            local circle = MawwwVeilV5GetCircleFromPool(i);
            local text = MawwwVeilV5GetTextFromPool(i);

            local dynamicRadius = math.clamp(MawwwVeilV5Config.MarkerSize / target.Distance, 8, 35);

            circle.Position = target.ScreenPos;
            circle.Radius = dynamicRadius;
            circle.Color = Color3.fromRGB(255, 90, 90);
            circle.Visible = true;

            local healthPct = math.floor((target.Humanoid.Health / target.Humanoid.MaxHealth) * 100);
            text.Position = target.ScreenPos - Vector2.new(0, dynamicRadius + 15);
            text.Text = string.format("%s [%d%%] [%dm]", target.Player.Name, healthPct, math.floor(target.Distance));
            text.Color = Color3.fromRGB(255, 180, 180);
            text.Visible = true;
        end;
    end;

    -- Draw Target Marker (Red circle for primary target)
    if primaryTarget then
        local targetCircle = MawwwVeilV5GetCircleFromPool(#targets + 1);
        local dynamicRadius = math.clamp(MawwwVeilV5Config.MarkerSize / primaryTarget.Distance, 8, 35);

        targetCircle.Position = primaryTarget.ScreenPos;
        targetCircle.Radius = dynamicRadius + 4;
        targetCircle.Color = Color3.fromRGB(255, 0, 0);
        targetCircle.Visible = true;

        if primaryTarget.Part and primaryTarget.Part.Parent then
            MawwwVeilV5Draw.Highlight.Parent = primaryTarget.Part.Parent;
        end;

        if MawwwVeilV5Draw.Tracer then
            local bottomCenter = Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y);
            MawwwVeilV5Draw.Tracer.From = bottomCenter;
            MawwwVeilV5Draw.Tracer.To = primaryTarget.ScreenPos;
            MawwwVeilV5Draw.Tracer.Visible = true;
        end;

        if MawwwVeilV5State.Charging and character then
            local startPart = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart");
            if startPart then
                local velocity = MawwwVeilV5Velocity(primaryTarget.Part, primaryTarget.Player.Name);
                local _, predicted = MawwwVeilV5BallisticDirection(startPart.Position, primaryTarget.Part.Position, velocity);
                MawwwVeilV5State.LastPredictedPos = predicted;
                MawwwVeilV5State.LastPredictedUntil = os.clock() + 0.12;
            end;
        end;
    else
        MawwwVeilV5Draw.Highlight.Parent = nil;
        if MawwwVeilV5Draw.Tracer then MawwwVeilV5Draw.Tracer.Visible = false end;
    end;

    -- Fallback Tracer if no primary target but prediction exists
    if MawwwVeilV5Draw.Tracer and MawwwVeilV5State.LastPredictedPos and os.clock() <= MawwwVeilV5State.LastPredictedUntil and not primaryTarget then
        local screen, onScreen = camera:WorldToViewportPoint(MawwwVeilV5State.LastPredictedPos);
        local center = Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y * 0.5);
        local bottomCenter = Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y);
        if onScreen then
            MawwwVeilV5Draw.Tracer.From = bottomCenter;
            MawwwVeilV5Draw.Tracer.To = Vector2.new(screen.X, screen.Y);
        else
            local dx, dy = screen.X - center.X, screen.Y - center.Y;
            local scale = math.min((camera.ViewportSize.X * 0.5 - 10) / math.max(math.abs(dx), 0.001), (camera.ViewportSize.Y * 0.5 - 10) / math.max(math.abs(dy), 0.001));
            MawwwVeilV5Draw.Tracer.From = bottomCenter;
            MawwwVeilV5Draw.Tracer.To = Vector2.new(center.X + dx * scale, center.Y + dy * scale);
        end;
        MawwwVeilV5Draw.Tracer.Visible = true;
    end;
end);

    -- Hub-safe setter/getters.
    local function MAWWW_VeilV5SetEnabled(enabled)
        MawwwVeilV5Config.Enabled = enabled == true
        if not MawwwVeilV5Config.Enabled then
            pcall(MawwwVeilV5HideDrawings)
            pcall(MawwwVeilV5StopHoming)
            MawwwVeilV5State.Charging = false
        end
    end

    local function MAWWW_VeilV5SyncFromVD()
        MawwwVeilV5Config.Enabled = VD.VeilV5Enabled == true
        MawwwVeilV5Config.ShowFOV = VD.VeilV5ShowFOV ~= false
        MawwwVeilV5Config.ShowMarkers = VD.VeilV5ShowMarkers ~= false
        MawwwVeilV5Config.RunToTarget = VD.VeilV5RunToTarget ~= false
        MawwwVeilV5Config.StickyLock = VD.VeilV5StickyLock ~= false
        MawwwVeilV5Config.PingCompensation = VD.VeilV5PingCompensation ~= false
        MawwwVeilV5Config.AutoGravity = VD.VeilV5AutoGravity ~= false
        MawwwVeilV5Config.AutoPredict = VD.VeilV5AutoPredict ~= false
        MawwwVeilV5Config.LongRangeArc = VD.VeilV5LongRangeArc ~= false
        MawwwVeilV5Config.StrictFOV = VD.VeilV5StrictFOV ~= false
        MawwwVeilV5Config.TargetPart = VD.VeilV5TargetPart or "Torso"
        MawwwVeilV5Config.FOV = tonumber(VD.VeilV5FOV) or 300
        MawwwVeilV5Config.SpearSpeed = tonumber(VD.VeilV5SpearSpeed) or 165
        MawwwVeilV5Config.Gravity = tonumber(VD.VeilV5Gravity) or 98.1
        MawwwVeilV5Config.LeadMultiplier = tonumber(VD.VeilV5LeadMultiplier) or 1.0
        MawwwVeilV5Config.ExtraLeadTime = tonumber(VD.VeilV5ExtraLeadTime) or 0.06
        MawwwVeilV5Config.CloseRange = tonumber(VD.VeilV5CloseRange) or 15
        MawwwVeilV5Config.MaxDist = tonumber(VD.VeilV5MaxDist) or 1000
        MawwwVeilV5Config.HomingDuration = tonumber(VD.VeilV5HomingDuration) or 1.4
        MawwwVeilV5Config.HomingHitDist = tonumber(VD.VeilV5HomingHitDist) or 4
        MawwwVeilV5Config.HomingRate = tonumber(VD.VeilV5HomingRate) or 0.02
        MawwwVeilV5Config.ArcHomingDelay = tonumber(VD.VeilV5ArcHomingDelay) or 0.18
        MawwwVeilV5Config.ArcStartRange = tonumber(VD.VeilV5ArcStartRange) or 65
        MawwwVeilV5Config.CloseLockRange = tonumber(VD.VeilV5CloseLockRange) or 60
        MawwwVeilV5Config.DistanceBias = tonumber(VD.VeilV5DistanceBias) or 0.75
        MawwwVeilV5Config.MarkerSize = tonumber(VD.VeilV5MarkerSize) or 1500
    end

    getgenv().MAWWW_SetSilentVeilV5 = MAWWW_VeilV5SetEnabled
    getgenv().MAWWW_SilentVeilV5Hide = function()
        MawwwVeilV5Config.Enabled = false
        pcall(MawwwVeilV5HideDrawings)
        pcall(MawwwVeilV5StopHoming)
        MawwwVeilV5State.Charging = false
    end
    getgenv().MAWWW_SilentVeilV5Config = MawwwVeilV5Config

    -- Initial config follows saved/current hub state (default OFF).
    MAWWW_VeilV5SyncFromVD()

    --======================
    -- UI: SILENT VEIL V5
    --======================
    RegDivider(Tabs.AimVeilV5)
    RegLabel(Tabs.AimVeilV5, "Silent Veil V5 • Homing Spear")

    RegToggle(Tabs.AimVeilV5, "Silent Veil V5", "Predictive homing spear engine.", false, "VeilV5Enabled", function(v)
        VD.VeilV5Enabled = v == true
        MAWWW_VeilV5SyncFromVD()
        if VD.VeilV5Enabled then
            -- Prevent simultaneous old Veil engines.
            for _, key in ipairs({"VeilEnabled","VeilV2Enabled","VeilV3Enabled","VeilV4Enabled"}) do
                VD[key] = false
            end
            pcall(function() if VeilV2 and VeilV2.Stop then VeilV2.Stop() end end)
            MAWWW_VeilV5SetEnabled(true)
        else
            getgenv().MAWWW_SilentVeilV5Hide()
        end
    end)
    RegToggle(Tabs.AimVeilV5, "Show FOV", "Show the V5 FOV circle.", true, "VeilV5ShowFOV", function(v)
        VD.VeilV5ShowFOV = v == true
        MawwwVeilV5Config.ShowFOV = VD.VeilV5ShowFOV
    end)
    RegToggle(Tabs.AimVeilV5, "Show Markers", "Show target/player markers.", true, "VeilV5ShowMarkers", function(v)
        VD.VeilV5ShowMarkers = v == true
        MawwwVeilV5Config.ShowMarkers = VD.VeilV5ShowMarkers
    end)
    RegToggle(Tabs.AimVeilV5, "Run To Target", "Home the spear toward the locked target.", true, "VeilV5RunToTarget", function(v)
        VD.VeilV5RunToTarget = v == true
        MawwwVeilV5Config.RunToTarget = VD.VeilV5RunToTarget
    end)
    RegToggle(Tabs.AimVeilV5, "Sticky Lock", "Keep the current target while homing.", true, "VeilV5StickyLock", function(v)
        VD.VeilV5StickyLock = v == true
        MawwwVeilV5Config.StickyLock = VD.VeilV5StickyLock
    end)
    RegToggle(Tabs.AimVeilV5, "Ping Compensation", "Add network ping to lead calculation.", true, "VeilV5PingCompensation", function(v)
        VD.VeilV5PingCompensation = v == true
        MawwwVeilV5Config.PingCompensation = VD.VeilV5PingCompensation
    end)
    RegToggle(Tabs.AimVeilV5, "Auto Gravity", "Derive gravity from workspace gravity.", true, "VeilV5AutoGravity", function(v)
        VD.VeilV5AutoGravity = v == true
        MawwwVeilV5Config.AutoGravity = VD.VeilV5AutoGravity
    end)
    RegToggle(Tabs.AimVeilV5, "Auto Predict", "Predict moving targets.", true, "VeilV5AutoPredict", function(v)
        VD.VeilV5AutoPredict = v == true
        MawwwVeilV5Config.AutoPredict = VD.VeilV5AutoPredict
    end)
    RegToggle(Tabs.AimVeilV5, "Long Range Arc", "Use ballistic arc on long shots.", true, "VeilV5LongRangeArc", function(v)
        VD.VeilV5LongRangeArc = v == true
        MawwwVeilV5Config.LongRangeArc = VD.VeilV5LongRangeArc
    end)
    RegToggle(Tabs.AimVeilV5, "Strict FOV", "Only acquire targets inside the FOV.", true, "VeilV5StrictFOV", function(v)
        VD.VeilV5StrictFOV = v == true
        MawwwVeilV5Config.StrictFOV = VD.VeilV5StrictFOV
    end)
    RegDropdown(Tabs.AimVeilV5, "Target Part", "Head / Torso / Root.", {"Head","Torso","Root"}, "Torso", false, "VeilV5TargetPart", function(v)
        VD.VeilV5TargetPart = tostring(v or "Torso")
        MawwwVeilV5Config.TargetPart = VD.VeilV5TargetPart
    end)

    RegDivider(Tabs.AimVeilV5)
    RegLabel(Tabs.AimVeilV5, "Ballistic / Aim")

    RegSlider(Tabs.AimVeilV5, "FOV", "FOV radius.", 300, 50, 600, 10, "VeilV5FOV", function(v) MawwwVeilV5Config.FOV = tonumber(v) or 300 end)
    RegSlider(Tabs.AimVeilV5, "Spear Speed", "Projectile speed.", 165, 50, 300, 5, "VeilV5SpearSpeed", function(v) MawwwVeilV5Config.SpearSpeed = tonumber(v) or 165 end)
    RegSlider(Tabs.AimVeilV5, "Gravity", "Manual gravity when Auto Gravity is off.", 98.1, 0, 300, 5, "VeilV5Gravity", function(v) MawwwVeilV5Config.Gravity = tonumber(v) or 98.1 end)
    RegSlider(Tabs.AimVeilV5, "Lead", "Lead multiplier.", 1.0, 0, 3, 0.1, "VeilV5LeadMultiplier", function(v) MawwwVeilV5Config.LeadMultiplier = tonumber(v) or 1.0 end)
    RegSlider(Tabs.AimVeilV5, "Extra Lead", "Extra lead time in seconds.", 0.06, 0, 0.5, 0.01, "VeilV5ExtraLeadTime", function(v) MawwwVeilV5Config.ExtraLeadTime = tonumber(v) or 0.06 end)
    RegSlider(Tabs.AimVeilV5, "Close Range", "Direct-aim cutoff.", 15, 3, 30, 1, "VeilV5CloseRange", function(v) MawwwVeilV5Config.CloseRange = tonumber(v) or 15 end)
    RegSlider(Tabs.AimVeilV5, "Max Distance", "Maximum target distance.", 1000, 100, 3000, 50, "VeilV5MaxDist", function(v) MawwwVeilV5Config.MaxDist = tonumber(v) or 1000 end)

    RegDivider(Tabs.AimVeilV5)
    RegLabel(Tabs.AimVeilV5, "Homing / Lock")

    RegSlider(Tabs.AimVeilV5, "Homing Duration", "Homing duration.", 1.4, 0.2, 3, 0.1, "VeilV5HomingDuration", function(v) MawwwVeilV5Config.HomingDuration = tonumber(v) or 1.4 end)
    RegSlider(Tabs.AimVeilV5, "Homing Hit Dist", "Distance treated as a hit.", 4, 1, 15, 0.5, "VeilV5HomingHitDist", function(v) MawwwVeilV5Config.HomingHitDist = tonumber(v) or 4 end)
    RegSlider(Tabs.AimVeilV5, "Homing Rate", "Homing update interval.", 0.02, 0.02, 0.2, 0.01, "VeilV5HomingRate", function(v) MawwwVeilV5Config.HomingRate = tonumber(v) or 0.02 end)
    RegSlider(Tabs.AimVeilV5, "Arc Homing Delay", "Delay before long-range homing takes over.", 0.18, 0, 0.6, 0.02, "VeilV5ArcHomingDelay", function(v) MawwwVeilV5Config.ArcHomingDelay = tonumber(v) or 0.18 end)
    RegSlider(Tabs.AimVeilV5, "Arc Start Range", "Distance where ballistic arc starts.", 65, 20, 150, 5, "VeilV5ArcStartRange", function(v) MawwwVeilV5Config.ArcStartRange = tonumber(v) or 65 end)
    RegSlider(Tabs.AimVeilV5, "Close Lock Range", "Near targets get lock priority.", 60, 10, 120, 5, "VeilV5CloseLockRange", function(v) MawwwVeilV5Config.CloseLockRange = tonumber(v) or 60 end)
    RegSlider(Tabs.AimVeilV5, "Distance Bias", "Bias toward nearby targets.", 0.75, 0, 2, 0.05, "VeilV5DistanceBias", function(v) MawwwVeilV5Config.DistanceBias = tonumber(v) or 0.75 end)
    RegSlider(Tabs.AimVeilV5, "Marker Size", "Target marker scale.", 1500, 50, 2000, 10, "VeilV5MarkerSize", function(v) MawwwVeilV5Config.MarkerSize = tonumber(v) or 1500 end)
end



--========================================================--
-- SILENT PISTOL V5 — imported from supplied silentaimpistol.lua
-- Headless/core-only integration into Mawww Hub.
--========================================================--
do
    local MawwwPistolV5Config = {
        Enabled = false,
        Laser = true,
        WallCheck = false,
        BlockKnocked = true,
        BypassCarry = true,
        TargetMode = "Killer",
        Key = "None",
    }

    local VD_Notify = function(title, content, dur)
        notify(title, content, dur)
    end

-- Silent Aim ToF — GanKunZ (Pure)
-- Hold system + target modes + Bypass Carry
-- NO Oxio hub
-- Toggle: getgenv().MAWWW_SetSilentPistolV5(true/false)
-- Keys: K=Killer | J=Survivors | L=Zombie
-- UI colors: Aim Veil V12 palette

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer


local function GetSafeGuiParent()
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then
            return hui
        end
    end

    local ok, core = pcall(function()
        return game:GetService("CoreGui")
    end)

    if ok and core then
        return core
    end

    return LocalPlayer:FindFirstChild("PlayerGui")
        or LocalPlayer:WaitForChild("PlayerGui", 5)
end

local function VD_Notify(title, content, dur)
    print("[" .. tostring(title) .. "]", tostring(content))
end

local GANKZ_ToFState = {
    Connection = nil,
    LaserBeam = nil,
    TargetGui = nil,
    InputBegan = nil,
    InputEnded = nil,
    TouchInput = nil,
    IsAiming = false,
    SavedUIPos = UDim2.new(0.5, -120, 0, 110),
    SCPCache = {},
    SCPCacheTimer = 0,
}

local GANKZ_ToFKeyCodes = {
    None = nil,
    Q = Enum.KeyCode.Q,
    E = Enum.KeyCode.E,
    R = Enum.KeyCode.R,
    T = Enum.KeyCode.T,
    F = Enum.KeyCode.F,
    G = Enum.KeyCode.G,
    H = Enum.KeyCode.H,
    J = Enum.KeyCode.J,
    K = Enum.KeyCode.K,
    L = Enum.KeyCode.L,
    X = Enum.KeyCode.X,
    Z = Enum.KeyCode.Z,
}

local function GANKZ_ToFGetEvent()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local items = remotes and remotes:FindFirstChild("Items")
    local tof = items and items:FindFirstChild("Twist of Fate")
    local fire = tof and tof:FindFirstChild("Fire")

    if fire and fire:IsA("RemoteEvent") then
        return fire
    end

    return nil
end

local function GANKZ_ToFGetGunObject()
    local char = LocalPlayer.Character
    if not char then
        return nil
    end

    local baseToF = char:FindFirstChild("Twist of Fate", true)
    if not baseToF then
        return nil
    end

    local rightArm = baseToF:FindFirstChild("Right Arm")

    if rightArm then
        local gunPart = rightArm:FindFirstChild("gun")
        if gunPart then
            return gunPart
        end

        local emperorGun = rightArm:FindFirstChild("EmperorGun")
        if emperorGun then
            return emperorGun
        end
    end

    return baseToF
end

local function GANKZ_ToFIsTargetVisible(originPos, targetPos, targetCharacter)
    local direction = targetPos - originPos
    local distance = direction.Magnitude

    if distance < 0.1 then
        return true
    end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local excludeList = {}

    local localChar = LocalPlayer.Character
    if localChar then
        table.insert(excludeList, localChar)
    end

    if targetCharacter and targetCharacter ~= localChar then
        table.insert(excludeList, targetCharacter)
    end

    if GANKZ_ToFState.LaserBeam then
        table.insert(excludeList, GANKZ_ToFState.LaserBeam)
    end

    rayParams.FilterDescendantsInstances = excludeList

    local result = workspace:Raycast(
        originPos,
        direction.Unit * distance,
        rayParams
    )

    return result == nil
end

local function GANKZ_ToFGetSCPs()
    if tick() - GANKZ_ToFState.SCPCacheTimer < 0.5 then
        return GANKZ_ToFState.SCPCache
    end

    local newTargets = {}

    local mapFolder = workspace:FindFirstChild("Map")

    if mapFolder then
        for _, container in pairs(mapFolder:GetDescendants()) do
            if container:IsA("Model") then
                local attributes = container:GetAttributes()

                if container:GetAttribute("CorpseCreated0492")
                    or next(attributes) ~= nil then

                    local root = container:FindFirstChild("HumanoidRootPart")

                    if root then
                        table.insert(newTargets, root)
                    end
                end
            end
        end
    end

    GANKZ_ToFState.SCPCache = newTargets
    GANKZ_ToFState.SCPCacheTimer = tick()

    return GANKZ_ToFState.SCPCache
end

local function GANKZ_ToFGetTargetPosition()
    local gunObj = GANKZ_ToFGetGunObject()
    local char = LocalPlayer.Character

    if not (gunObj and char) then
        return nil, nil, nil, nil
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")

    if not hrp then
        return nil, nil, nil, nil
    end

    local myPos = hrp.Position
    local originPos

    if char:GetAttribute("IsCarried") then
        originPos = hrp.Position + (hrp.CFrame.LookVector * 2)
    else
        pcall(function()
            originPos =
                gunObj:IsA("BasePart")
                and gunObj.Position
                or (
                    gunObj:FindFirstChildOfClass("BasePart")
                    and gunObj:FindFirstChildOfClass("BasePart").Position
                )
        end)

        originPos =
            originPos
            or Vector3.new(
                myPos.X,
                myPos.Y + 1.5,
                myPos.Z
            )
    end

    local function predictTarget(torso, targetCharacter)
        local targetPos = torso.Position

        if MawwwPistolV5Config.WallCheck
            and not GANKZ_ToFIsTargetVisible(
                originPos,
                targetPos,
                targetCharacter
            ) then

            return nil, nil, nil, nil
        end

        local targetVel = Vector3.new(0, 0, 0)

        local rootPart =
            targetCharacter
            and (
                targetCharacter:FindFirstChild("HumanoidRootPart")
                or torso
            )

        if rootPart then
            targetVel = rootPart.Velocity
        end

        local directionRaw = targetPos - originPos
        local distance = directionRaw.Magnitude

        if distance < 0.1 then
            return nil, nil, nil, nil
        end

        if distance < 5 then
            return directionRaw.Unit, gunObj, originPos, targetPos
        end

        local travelTime = distance / 400
        local predictedPos = targetPos + (targetVel * travelTime)

        for _ = 1, 2 do
            local newDist = (predictedPos - originPos).Magnitude
            travelTime = newDist / 400
            predictedPos = targetPos + (targetVel * travelTime)
        end

        local finalDirection = predictedPos - originPos

        if finalDirection.Magnitude < 0.1 then
            return nil, nil, nil, nil
        end

        return finalDirection.Unit, gunObj, originPos, predictedPos
    end

    local targetMode = MawwwPistolV5Config.TargetMode or "Killer"

    if targetMode == "Killer" then
        local closestTorso
        local closestChar
        local shortestDist = math.huge

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer
                and player.Team
                and player.Team.Name == "Killer"
                and player.Character then

                local torso =
                    player.Character:FindFirstChild("Torso")
                    or player.Character:FindFirstChild("UpperTorso")
                    or player.Character:FindFirstChild("HumanoidRootPart")

                if torso then
                    local dist = (myPos - torso.Position).Magnitude

                    if dist < shortestDist then
                        shortestDist = dist
                        closestTorso = torso
                        closestChar = player.Character
                    end
                end
            end
        end

        if not closestTorso then
            return nil, nil, nil, nil
        end

        return predictTarget(closestTorso, closestChar)

    elseif targetMode == "Survivors" then
        local bestTorso
        local bestChar
        local bestDot = -math.huge

        local cam = workspace.CurrentCamera

        if not cam then
            return nil, nil, nil, nil
        end

        local camLook = cam.CFrame.LookVector

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer
                and player.Team
                and player.Team.Name == "Survivors"
                and player.Character then

                local torso =
                    player.Character:FindFirstChild("Torso")
                    or player.Character:FindFirstChild("UpperTorso")
                    or player.Character:FindFirstChild("HumanoidRootPart")

                if torso then
                    local dirToTarget =
                        torso.Position - cam.CFrame.Position

                    if dirToTarget.Magnitude > 0.1 then
                        local dot = camLook:Dot(dirToTarget.Unit)

                        if dot > 0.5 and dot > bestDot then
                            bestDot = dot
                            bestTorso = torso
                            bestChar = player.Character
                        end
                    end
                end
            end
        end

        if not bestTorso then
            return nil, nil, nil, nil
        end

        return predictTarget(bestTorso, bestChar)

    elseif targetMode == "Zombie" then
        local bestPart
        local bestDot = -math.huge

        local cam = workspace.CurrentCamera

        if not cam then
            return nil, nil, nil, nil
        end

        local camLook = cam.CFrame.LookVector

        for _, root in ipairs(GANKZ_ToFGetSCPs()) do
            if root and root.Parent then
                local dirToTarget =
                    root.Position - cam.CFrame.Position

                if dirToTarget.Magnitude > 0.1 then
                    local dot = camLook:Dot(dirToTarget.Unit)

                    if dot > 0.5 and dot > bestDot then
                        bestDot = dot
                        bestPart = root
                    end
                end
            end
        end

        if not bestPart then
            return nil, nil, nil, nil
        end

        return predictTarget(bestPart, bestPart.Parent)
    end

    return nil, nil, nil, nil
end

local function GANKZ_ToFUpdateLaser(originPos, targetPos)
    if not GANKZ_ToFState.LaserBeam then
        local laser = Instance.new("Part")

        laser.Name = "ToFLaser"
        laser.Anchored = true
        laser.CanCollide = false
        laser.CanTouch = false
        laser.CastShadow = false
        laser.Material = Enum.Material.Neon
        laser.Color = Color3.fromRGB(255, 50, 50)
        laser.Parent = workspace

        GANKZ_ToFState.LaserBeam = laser
    end

    local dist = (targetPos - originPos).Magnitude

    GANKZ_ToFState.LaserBeam.Size =
        Vector3.new(0.05, 0.05, dist)

    GANKZ_ToFState.LaserBeam.CFrame =
        CFrame.new(
            (originPos + targetPos) / 2,
            targetPos
        )

    GANKZ_ToFState.LaserBeam.Transparency = 0
end

local function GANKZ_ToFClearLaser()
    if GANKZ_ToFState.LaserBeam then
        pcall(function()
            GANKZ_ToFState.LaserBeam:Destroy()
        end)

        GANKZ_ToFState.LaserBeam = nil
    end
end

local function IsDowned(char)
    if not char then
        return true
    end

    if MawwwPistolV5Config.BypassCarry
        and char == LocalPlayer.Character
        and char:GetAttribute("IsCarried") then

        return char:GetAttribute("Knocked") == true
            or char:GetAttribute("IsHooked") == true
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")

    if not hrp then
        return true
    end

    local state = char:GetAttribute("State")

    return state == "Downed"
        or state == "Dead"
        or char:GetAttribute("Knocked") == true
        or char:GetAttribute("IsHooked") == true
end

local function GANKZ_ToFGetMobileShootButton()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")

    local survivorMob =
        playerGui
        and playerGui:FindFirstChild("Survivor-mob")

    local controls =
        survivorMob
        and survivorMob:FindFirstChild("Controls")

    local guiMob =
        controls
        and controls:FindFirstChild("Gui-mob")

    if not guiMob then
        return nil
    end

    local directNames = {
        "attack",
        "Attack",
        "shoot",
        "Shoot",
        "fire",
        "Fire"
    }

    for _, name in ipairs(directNames) do
        local btn = guiMob:FindFirstChild(name, true)

        if btn and btn:IsA("GuiObject") then
            return btn
        end
    end

    for _, obj in ipairs(guiMob:GetDescendants()) do
        if obj:IsA("GuiButton") and obj.Visible then
            return obj
        end
    end

    return guiMob:IsA("GuiObject") and guiMob or nil
end

local function GANKZ_ToFIsTouchOnShootButton(input)
    local shootButton = GANKZ_ToFGetMobileShootButton()

    if not (shootButton and shootButton.Visible) then
        return false
    end

    local pos = input.Position
    local absPos = shootButton.AbsolutePosition
    local absSize = shootButton.AbsoluteSize

    return pos.X >= absPos.X
        and pos.X <= absPos.X + absSize.X
        and pos.Y >= absPos.Y
        and pos.Y <= absPos.Y + absSize.Y
end

local function GANKZ_ToFDoShoot()
    if not MawwwPistolV5Config.Enabled then
        return
    end

    local char = LocalPlayer.Character

    if char then
        if MawwwPistolV5Config.BlockKnocked and IsDowned(char) then
            return
        end
    end

    local targetDirection
    local gunObject
    local originPos
    local targetPos

    targetDirection,
    gunObject,
    originPos,
    targetPos = GANKZ_ToFGetTargetPosition()

    if not (
        targetDirection
        and gunObject
        and targetPos
        and originPos
    ) then
        return
    end

    local tofEvent = GANKZ_ToFGetEvent()

    if not tofEvent then
        return
    end

    local freshDirection = targetPos - originPos

    if freshDirection.Magnitude < 0.1 then
        return
    end

    pcall(function()
        tofEvent:FireServer(
            gunObject,
            freshDirection.Unit
        )
    end)
end


    local function GANKZ_ToFRefreshTargetButtons()
        -- Standalone selector UI removed; hub dropdown controls the mode.
    end

    local function GANKZ_ToFSetTargetMode(modeName, notifyUser)
        modeName = tostring(modeName or "Killer")
        if modeName ~= "Killer" and modeName ~= "Survivors" and modeName ~= "Zombie" then
            modeName = "Killer"
        end
        MawwwPistolV5Config.TargetMode = modeName
        if notifyUser then
            VD_Notify("Target Mode", modeName, 1)
        end
    end

    local function GANKZ_ToFCreateTargetSelectorUI()
        -- no-op: Mawww Hub owns the UI
    end

    local function GANKZ_ToFDestroyTargetSelectorUI()
        GANKZ_ToFClearLaser()
    end

local function GANKZ_ToFStartConnection()
    if GANKZ_ToFState.Connection then
        return
    end

    GANKZ_ToFState.Connection =
        RunService.Heartbeat:Connect(function()

        if not MawwwPistolV5Config.Enabled
            or not GANKZ_ToFState.IsAiming then

            if GANKZ_ToFState.LaserBeam then
                GANKZ_ToFState.LaserBeam.Transparency = 1
            end

            return
        end

        local _
        local __
        local originPos
        local targetPos

        _, __, originPos, targetPos =
            GANKZ_ToFGetTargetPosition()

        if originPos and targetPos then
            pcall(function()
                local char = LocalPlayer.Character
                local hrp =
                    char
                    and char:FindFirstChild(
                        "HumanoidRootPart"
                    )

                if hrp
                    and not char:GetAttribute(
                        "IsCarried"
                    ) then

                    hrp.CFrame =
                        CFrame.new(
                            hrp.Position,
                            Vector3.new(
                                targetPos.X,
                                hrp.Position.Y,
                                targetPos.Z
                            )
                        )
                end
            end)

            if MawwwPistolV5Config.Laser then
                GANKZ_ToFUpdateLaser(
                    originPos,
                    targetPos
                )
            elseif GANKZ_ToFState.LaserBeam then
                GANKZ_ToFState.LaserBeam.Transparency = 1
            end

        elseif GANKZ_ToFState.LaserBeam then
            GANKZ_ToFState.LaserBeam.Transparency = 1
        end
    end)
end

local function GANKZ_ToFStopConnection()
    if GANKZ_ToFState.Connection then
        pcall(function()
            GANKZ_ToFState.Connection:Disconnect()
        end)

        GANKZ_ToFState.Connection = nil
    end

    GANKZ_ToFState.IsAiming = false

    GANKZ_ToFClearLaser()
end

local MAWWW_SetSilentPistolV5

local function GANKZ_ToFEnsureInputs()
    if not GANKZ_ToFState.InputBegan then
        GANKZ_ToFState.InputBegan =
            UserInputService.InputBegan:Connect(
            function(input, gameProcessed)

            if gameProcessed then
                return
            end

            local keyCode =
                GANKZ_ToFKeyCodes[
                    MawwwPistolV5Config.Key or "None"
                ]

            if keyCode
                and input.UserInputType ==
                    Enum.UserInputType.Keyboard
                and input.KeyCode == keyCode then

                MAWWW_SetSilentPistolV5(
                    not MawwwPistolV5Config.Enabled
                )

                return
            end

            if not MawwwPistolV5Config.Enabled then
                return
            end

            if input.UserInputType ==
                Enum.UserInputType.MouseButton1
                or (
                    input.UserInputType ==
                        Enum.UserInputType.Touch
                    and GANKZ_ToFIsTouchOnShootButton(
                        input
                    )
                ) then

                GANKZ_ToFState.IsAiming = true

                if input.UserInputType ==
                    Enum.UserInputType.Touch then

                    GANKZ_ToFState.TouchInput = input
                end

                GANKZ_ToFDoShoot()

                return
            end

            if input.UserInputType ==
                Enum.UserInputType.Keyboard then

                if input.KeyCode == Enum.KeyCode.K then
                    GANKZ_ToFSetTargetMode(
                        "Killer",
                        true
                    )

                elseif input.KeyCode == Enum.KeyCode.J then
                    GANKZ_ToFSetTargetMode(
                        "Survivors",
                        true
                    )

                elseif input.KeyCode == Enum.KeyCode.L then
                    GANKZ_ToFSetTargetMode(
                        "Zombie",
                        true
                    )
                end
            end
        end)
    end

    if not GANKZ_ToFState.InputEnded then
        GANKZ_ToFState.InputEnded =
            UserInputService.InputEnded:Connect(
            function(input)

            if input.UserInputType ==
                Enum.UserInputType.MouseButton1
                or (
                    input.UserInputType ==
                        Enum.UserInputType.Touch
                    and input ==
                        GANKZ_ToFState.TouchInput
                ) then

                GANKZ_ToFState.IsAiming = false

                if input ==
                    GANKZ_ToFState.TouchInput then

                    GANKZ_ToFState.TouchInput = nil
                end

                if GANKZ_ToFState.LaserBeam then
                    GANKZ_ToFState.LaserBeam.Transparency = 1
                end
            end
        end)
    end
end

MAWWW_SetSilentPistolV5 = function(enabled)
    MawwwPistolV5Config.Enabled =
        enabled and true or false

    GANKZ_ToFEnsureInputs()

    if MawwwPistolV5Config.Enabled then
        GANKZ_ToFCreateTargetSelectorUI()
        GANKZ_ToFStartConnection()
    else
        GANKZ_ToFDestroyTargetSelectorUI()
        GANKZ_ToFStopConnection()
    end
end

GANKZ_ToFEnsureInputs()


getgenv().MAWWW_SilentPistolV5ClearLaser =
    GANKZ_ToFClearLaser

getgenv().MAWWW_SilentPistolV5SetTargetMode =
    GANKZ_ToFSetTargetMode




    -- Public controls for the Mawww Hub.
    getgenv().MAWWW_SetSilentPistolV5 = MAWWW_SetSilentPistolV5
    getgenv().MAWWW_SilentPistolV5ClearLaser = GANKZ_ToFClearLaser
    getgenv().MAWWW_SilentPistolV5SetTargetMode = GANKZ_ToFSetTargetMode
    getgenv().MAWWW_SilentPistolV5Config = MawwwPistolV5Config

    -- Start input listeners once, but keep the engine OFF until the hub toggle is pressed.
    GANKZ_ToFEnsureInputs()

    local function MAWWW_PistolV5SyncFromVD()
        MawwwPistolV5Config.Enabled = VD.PistolV5Enabled == true
        MawwwPistolV5Config.Laser = VD.PistolV5Laser ~= false
        MawwwPistolV5Config.WallCheck = VD.PistolV5WallCheck == true
        MawwwPistolV5Config.BlockKnocked = VD.PistolV5BlockKnocked ~= false
        MawwwPistolV5Config.BypassCarry = VD.PistolV5BypassCarry ~= false
        MawwwPistolV5Config.TargetMode = tostring(VD.PistolV5TargetMode or "Killer")
        MawwwPistolV5Config.Key = tostring(VD.PistolV5Key or "None")
    end

    MAWWW_PistolV5SyncFromVD()
    if MawwwPistolV5Config.Enabled then
        pcall(MAWWW_SetSilentPistolV5, true)
    end

    --======================
    -- UI: SILENT PISTOL V5
    --======================
    RegDivider(Tabs.AimTOFV5)
    RegLabel(Tabs.AimTOFV5, "Silent Pistol V5 • Twist of Fate")

    RegToggle(Tabs.AimTOFV5, "Silent Pistol V5", "Redirect Twist of Fate shots to the selected target.", false, "PistolV5Enabled", function(v)
        VD.PistolV5Enabled = v == true
        -- Prevent simultaneous older pistol engines.
        for _, key in ipairs({"TOF_SilentAim","TOF2_Enabled","TOF3_SilentAim","PistolEnabled"}) do
            VD[key] = false
        end
        pcall(function() if MAWWW_SetToFSilentAim then MAWWW_SetToFSilentAim(false) end end)
        pcall(function() if MAWWW_SetToFV3SilentAim then MAWWW_SetToFV3SilentAim(false) end end)
        pcall(function() if getgenv().MAWWW_SilentPistolV4SetEnabled then getgenv().MAWWW_SilentPistolV4SetEnabled(false) end end)
        pcall(function() if ToFV2 and ToFV2.Stop then ToFV2.Stop() end end)
        pcall(function() if ToFV3Module and ToFV3Module.Stop then ToFV3Module.Stop() end end)
        MawwwPistolV5Config.Enabled = VD.PistolV5Enabled
        if getgenv().MAWWW_SetSilentPistolV5 then
            pcall(getgenv().MAWWW_SetSilentPistolV5, VD.PistolV5Enabled)
        end
    end)

    RegDropdown(Tabs.AimTOFV5, "Target Mode", "Killer / Survivors / Zombie.", {"Killer","Survivors","Zombie"}, "Killer", false, "PistolV5TargetMode", function(v)
        VD.PistolV5TargetMode = tostring(v or "Killer")
        if getgenv().MAWWW_SilentPistolV5SetTargetMode then
            pcall(getgenv().MAWWW_SilentPistolV5SetTargetMode, VD.PistolV5TargetMode, false)
        end
    end)

    RegToggle(Tabs.AimTOFV5, "Laser", "Show the V5 target laser.", true, "PistolV5Laser", function(v)
        VD.PistolV5Laser = v == true
        MawwwPistolV5Config.Laser = VD.PistolV5Laser
        if not VD.PistolV5Laser and getgenv().MAWWW_SilentPistolV5ClearLaser then
            pcall(getgenv().MAWWW_SilentPistolV5ClearLaser)
        end
    end)

    RegToggle(Tabs.AimTOFV5, "Wall Check", "Require line of sight.", false, "PistolV5WallCheck", function(v)
        VD.PistolV5WallCheck = v == true
        MawwwPistolV5Config.WallCheck = VD.PistolV5WallCheck
    end)

    RegToggle(Tabs.AimTOFV5, "Block When Downed", "Do not fire while downed/hooked.", true, "PistolV5BlockKnocked", function(v)
        VD.PistolV5BlockKnocked = v == true
        MawwwPistolV5Config.BlockKnocked = VD.PistolV5BlockKnocked
    end)

    RegToggle(Tabs.AimTOFV5, "Bypass Carry", "Allow aiming logic while carried.", true, "PistolV5BypassCarry", function(v)
        VD.PistolV5BypassCarry = v == true
        MawwwPistolV5Config.BypassCarry = VD.PistolV5BypassCarry
    end)

    RegDropdown(Tabs.AimTOFV5, "Toggle Key", "Press the selected key to toggle Silent Pistol V5.", {"None","Q","E","R","T","F","G","H","J","K","L","X","Z"}, "None", false, "PistolV5Key", function(v)
        VD.PistolV5Key = tostring(v or "None")
        MawwwPistolV5Config.Key = VD.PistolV5Key
    end)
end


-- FLASK / CURE
-- Single UI + single engine; intentionally kept outside Silent Veil.
--========================================================--
getgenv().MAWWW_CureFlaskLaserThread = getgenv().MAWWW_CureFlaskLaserThread or nil
getgenv().MAWWW_CureFlaskLaserPart = getgenv().MAWWW_CureFlaskLaserPart or nil

function MAWWW_DestroyCureFlaskLaser()
    if getgenv().MAWWW_CureFlaskLaserThread then
        pcall(function() getgenv().MAWWW_CureFlaskLaserThread:Disconnect() end)
        getgenv().MAWWW_CureFlaskLaserThread = nil
    end
    if getgenv().MAWWW_CureFlaskLaserPart then
        pcall(function() getgenv().MAWWW_CureFlaskLaserPart:Destroy() end)
        getgenv().MAWWW_CureFlaskLaserPart = nil
    end
end

function MAWWW_UpdateCureFlaskLaser()
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        if getgenv().MAWWW_CureFlaskLaserPart then
            getgenv().MAWWW_CureFlaskLaserPart.Transparency = 1
        end
        return
    end

    local hand = char:FindFirstChild("LeftHand") or char:FindFirstChild("Left Arm")
    local originPos = hand and hand.Position or hrp.Position
    local closest, minDst = nil, math.huge

    for _, v in ipairs(MawwwGetPlayers()) do
        if v ~= Player and v.Character and not IsKiller(v) then
            local vRoot = v.Character:FindFirstChild("HumanoidRootPart")
            if vRoot then
                local dst = (vRoot.Position - hrp.Position).Magnitude
                if dst < minDst then
                    minDst = dst
                    closest = v
                end
            end
        end
    end

    local targetRoot = closest and closest.Character and closest.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not VD.FlaskLaser then
        if getgenv().MAWWW_CureFlaskLaserPart then
            getgenv().MAWWW_CureFlaskLaserPart.Transparency = 1
        end
        return
    end

    if not getgenv().MAWWW_CureFlaskLaserPart then
        local laser = Instance.new("Part")
        laser.Name = "FlaskSilentAimLaser"
        laser.Anchored = true
        laser.CanCollide = false
        laser.CanTouch = false
        laser.CastShadow = false
        laser.Material = Enum.Material.Neon
        laser.Color = Color3.fromRGB(0, 100, 255)
        laser.Transparency = 1
        laser.Parent = Workspace
        getgenv().MAWWW_CureFlaskLaserPart = laser
    end

    local targetPos = targetRoot.Position
    local delta = targetPos - originPos
    local dist = delta.Magnitude
    local laser = getgenv().MAWWW_CureFlaskLaserPart
    if laser and laser.Parent and dist > 0.1 then
        laser.Size = Vector3.new(0.16, 0.16, dist)
        laser.CFrame = CFrame.new((originPos + targetPos) / 2, targetPos)
        laser.Transparency = 0
    end
end

function MAWWW_StartCureFlaskLaser()
    if getgenv().MAWWW_CureFlaskLaserThread then return end
    getgenv().MAWWW_CureFlaskLaserThread = RunService.RenderStepped:Connect(function()
        if VD.Destroyed or not VD.FlaskLaser then
            MAWWW_DestroyCureFlaskLaser()
            return
        end
        pcall(MAWWW_UpdateCureFlaskLaser)
    end)
end

RegDivider(Tabs.AimFlash)
RegLabel(Tabs.AimFlask, "Flask / Cure")
RegToggle(Tabs.AimFlask, "Flask Silent Aim", "Auto-aim flask ke survivor terdekat.", false, "FlaskSilentAim")
RegToggle(Tabs.AimFlask, "Flask Laser", "Tampilkan laser flask ke target.", false, "FlaskLaser", function(v)
    if v then
        pcall(MAWWW_StartCureFlaskLaser)
    else
        pcall(MAWWW_DestroyCureFlaskLaser)
    end
end)

--========================================================--
--========================================================--
-- ESP TAB
--========================================================--
RegLabel(Tabs.ESP, "ESP Targets")
RegLabel(Tabs.ESPOptions, "ESP Settings")

ESPObjects = {}
ESPNames = {}
ESPGenProgress = {}
CachedGenerators, CachedWindows, CachedPallets, CachedHooks = {}, {}, {}, {}
CachedSCP = {}

ESP_Colors = {
    Killer=Color3.fromRGB(255,0,0), Survivor=Color3.fromRGB(0,255,100), SCP=Color3.fromRGB(180,0,255),
    Generator=Color3.fromRGB(255,170,0), Pallet=Color3.fromRGB(74,255,181),
    Window=Color3.fromRGB(74,180,255), Hook=Color3.fromRGB(255,100,100), Lobby=Color3.fromRGB(255,215,0),
}

local ESP_RAINBOW_SPEED = 0.30
local ESP_TEXT_WHITE = Color3.fromRGB(255,255,255)

function cacheObject(obj)
    if obj.Name == "Generator" then CachedGenerators[obj] = true
    elseif obj.Name == "Window" then CachedWindows[obj] = true
    elseif obj.Name == "Pallet" or obj.Name == "Palletwrong" then CachedPallets[obj] = true
    elseif obj.Name == "Hook" then CachedHooks[obj] = true end
end

for _, obj in ipairs(Workspace:GetDescendants()) do
    cacheObject(obj)
    if string.find(string.lower(obj.Name), "scp", 1, true) then CachedSCP[obj] = true end
end

Workspace.DescendantAdded:Connect(function(obj)
    cacheObject(obj)
    if string.find(string.lower(obj.Name), "scp", 1, true) then CachedSCP[obj] = true end
end)

Workspace.DescendantRemoving:Connect(function(obj)
    CachedSCP[obj] = nil
    CachedGenerators[obj] = nil
    CachedWindows[obj] = nil
    CachedPallets[obj] = nil
    CachedHooks[obj] = nil

    if ESPObjects[obj] then
        pcall(function() ESPObjects[obj]:Destroy() end)
        ESPObjects[obj] = nil
    end

    if ESPGenProgress[obj] then
        pcall(function() ESPGenProgress[obj]:Destroy() end)
        ESPGenProgress[obj] = nil
    end
end)

function removeESP(obj)
    local h = ESPObjects[obj]
    if h then
        pcall(function() h:Destroy() end)
        ESPObjects[obj] = nil
    end
end

function createESP(obj, color)
    if not obj or not obj.Parent then return end

    local fillT = math.clamp((tonumber(VD.ESP_FillTransparency) or 70) / 100, 0, 1)
    local outlineT = math.clamp((tonumber(VD.ESP_OutlineTransparency) or 20) / 100, 0, 1)

    local existing = ESPObjects[obj]
    if existing and existing.Parent then
        existing.FillColor = color
        existing.OutlineColor = color
        existing.FillTransparency = fillT
        existing.OutlineTransparency = outlineT
        existing.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        return existing
    end

    if existing then
        pcall(function() existing:Destroy() end)
        ESPObjects[obj] = nil
    end

    local h = Instance.new("Highlight")
    h.Name = "Mawww_ESP_Object"
    h.Adornee = obj
    h.FillColor = color
    h.OutlineColor = color
    h.FillTransparency = fillT
    h.OutlineTransparency = outlineT
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = obj
    ESPObjects[obj] = h
    return h
end

--========================================================--
-- PLAYER / KILLER ESP
-- Enemy player = animated neon rainbow.
-- Player ESP has NO script-side distance check.
--========================================================--
local PlayerESPEnabled = true
local PlayerESP_LastColorUpdate = 0

local ATTR_STATE   = "State"
local ATTR_DOWNED  = "Downed"
local ATTR_CARRIED = "Carried"

local PlayerESPStatic = {
    Killer = Color3.fromRGB(255, 60, 60),
    Survivor = Color3.fromRGB(50, 120, 255),
    Hurt = Color3.fromRGB(255, 220, 50),
    Down = Color3.fromRGB(255, 140, 40),
    Carry = Color3.fromRGB(255, 40, 40),
    Lobby = Color3.fromRGB(255, 215, 80),
}

local function playerTeamRole(p)
    if not p then return "Unknown" end
    local teamName = p.Team and p.Team.Name or ""
    if teamMatches(teamName, "killer") then return "Killer" end
    if teamMatches(teamName, "survivor") then return "Survivor" end
    if teamMatches(teamName, "spectat") or teamMatches(teamName, "lobby") then return "Lobby" end

    local role = p:GetAttribute("Role")
    if role == "Killer" or role == "Survivor" then return role end
    if p:GetAttribute("IsKiller") == true or p:GetAttribute("IsKillerRole") == true then return "Killer" end
    if p:GetAttribute("IsSurvivor") == true then return "Survivor" end

    local char = p.Character
    if char then
        role = char:GetAttribute("Role")
        if role == "Killer" or role == "Survivor" then return role end
        if char:GetAttribute("IsKiller") == true or char:GetAttribute("IsKillerRole") == true then return "Killer" end
        if char:GetAttribute("IsSurvivor") == true then return "Survivor" end
    end
    return "Unknown"
end

local function PlayerESP_IsKiller(p)
    return playerTeamRole(p) == "Killer"
end

local function PlayerESP_IsSurvivor(p)
    return playerTeamRole(p) == "Survivor"
end

local function PlayerESP_IsEnemy(p)
    local myRole = GetRole()
    local targetRole = playerTeamRole(p)
    return (myRole == "Survivor" and targetRole == "Killer")
        or (myRole == "Killer" and targetRole == "Survivor")
end

local function PlayerESP_NameOffset(p)
    local uid = tonumber(p and p.UserId) or 0
    return (uid % 1000) / 1000
end

local function PlayerESP_Rainbow(offset)
    return Color3.fromHSV((os.clock() * ESP_RAINBOW_SPEED + (offset or 0)) % 1, 1, 1)
end

local function PlayerESP_GetStaticColor(p)
    local role = playerTeamRole(p)
    if role == "Killer" then
        return PlayerESPStatic.Killer
    elseif role == "Survivor" then
        local char = p.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if char then
            local carried = char:GetAttribute(ATTR_CARRIED) or p:GetAttribute(ATTR_CARRIED)
            if carried == true then return PlayerESPStatic.Carry end

            local downed = char:GetAttribute(ATTR_DOWNED) or p:GetAttribute(ATTR_DOWNED)
            if downed == true then return PlayerESPStatic.Down end

            local state = char:GetAttribute(ATTR_STATE) or p:GetAttribute(ATTR_STATE)
            if type(state) == "string" then
                local upper = state:upper()
                if upper:find("CARR", 1, true) then return PlayerESPStatic.Carry end
                if upper:find("DOWN", 1, true) or upper:find("KNOCK", 1, true) then return PlayerESPStatic.Down end
                if upper:find("INJUR", 1, true) or upper:find("HURT", 1, true) or upper:find("WOUND", 1, true) then
                    return PlayerESPStatic.Hurt
                end
            end

            if hum then
                if hum.Health <= 0 then return PlayerESPStatic.Down end
                if hum:GetState() == Enum.HumanoidStateType.Physics then return PlayerESPStatic.Carry end
                if hum.PlatformStand == true then return PlayerESPStatic.Down end
                if hum.MaxHealth > 0 then
                    local hpPct = hum.Health / hum.MaxHealth * 100
                    if hpPct <= 30 and hpPct > 0 then return PlayerESPStatic.Down end
                    if hpPct < 100 and hpPct > 0 then return PlayerESPStatic.Hurt end
                end
            end
        end
        return PlayerESPStatic.Survivor
    elseif role == "Lobby" then
        return PlayerESPStatic.Lobby
    end
    return Color3.fromRGB(255,255,255)
end

local function PlayerESP_GetName(char)
    local p = Players:GetPlayerFromCharacter(char)
    if not p then return char and char.Name or "Unknown" end
    return p.DisplayName or p.Name
end

local PlayerESP_RootCache = nil
local PlayerESP_RootCacheAt = 0
local function PlayerESP_GetCachedRoot()
    local now = os.clock()
    if now - PlayerESP_RootCacheAt >= 0.05 then
        PlayerESP_RootCacheAt = now
        PlayerESP_RootCache = getRoot()
    end
    return PlayerESP_RootCache
end

local function PlayerESP_GetDistance(p)
    local myRoot = PlayerESP_GetCachedRoot()
    local char = p and p.Character
    local targetRoot = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
    if not myRoot or not targetRoot then return nil end
    local ok, dist = pcall(function()
        return (myRoot.Position - targetRoot.Position).Magnitude
    end)
    if ok and type(dist) == "number" then return math.floor(dist + 0.5) end
    return nil
end

local function PlayerESP_RemoveName(p)
    local gui = ESPNames[p]
    if gui then
        pcall(function() gui:Destroy() end)
        ESPNames[p] = nil
    end
end

local function PlayerESP_CreateName(p)
    if not p or p == Player or not p.Character then
        if p then PlayerESP_RemoveName(p) end
        return nil
    end

    local char = p.Character
    local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if not head then
        PlayerESP_RemoveName(p)
        return nil
    end

    local bb = ESPNames[p]
    if bb and bb.Parent ~= head then
        pcall(function() bb:Destroy() end)
        ESPNames[p] = nil
        bb = nil
    end

    -- Replace any old split name/distance billboard from the previous build.
    if bb and (bb:FindFirstChild("NameLabel") or bb:FindFirstChild("DistanceLabel")) then
        pcall(function() bb:Destroy() end)
        ESPNames[p] = nil
        bb = nil
    end

    if not bb then
        local old = head:FindFirstChild("MWD_ESPName")
        if old then pcall(function() old:Destroy() end) end

        bb = Instance.new("BillboardGui")
        bb.Name = "MWD_ESPName"
        bb.Size = UDim2.fromOffset(170, 20)
        -- Tight, centered label directly above the head.
        bb.StudsOffset = Vector3.new(0, 1.15, 0)
        bb.AlwaysOnTop = true
        bb.MaxDistance = 0
        bb.LightInfluence = 0
        bb.Adornee = head
        bb.Parent = head

        local infoLabel = Instance.new("TextLabel")
        infoLabel.Name = "InfoLabel"
        infoLabel.Size = UDim2.fromScale(1, 1)
        infoLabel.Position = UDim2.fromScale(0, 0)
        infoLabel.AnchorPoint = Vector2.new(0, 0)
        infoLabel.BackgroundTransparency = 1
        infoLabel.TextColor3 = ESP_TEXT_WHITE
        infoLabel.TextStrokeTransparency = 0.05
        infoLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        infoLabel.TextSize = 12
        infoLabel.Font = Enum.Font.GothamBold
        infoLabel.TextXAlignment = Enum.TextXAlignment.Center
        infoLabel.TextYAlignment = Enum.TextYAlignment.Center
        infoLabel.TextTruncate = Enum.TextTruncate.AtEnd
        infoLabel.Parent = bb

        bb:SetAttribute("RainbowOffset", PlayerESP_NameOffset(p))
        ESPNames[p] = bb
    end

    local infoLabel = bb:FindFirstChild("InfoLabel")
    local nameText = PlayerESP_GetName(char)
    local distance = PlayerESP_GetDistance(p)
    if infoLabel then
        infoLabel.Text = distance and string.format("%s  •  %d studs", nameText, distance)
        or string.format("%s  •  -- studs", nameText)
        infoLabel.TextColor3 = ESP_TEXT_WHITE
    end

    return bb
end

local function PlayerESP_RemoveHighlight(p)
    local h = ESPObjects[p]
    if h then
        pcall(function() h:Destroy() end)
        ESPObjects[p] = nil
    end
end

local function PlayerESP_UpdateOne(p)
    if not p or p == Player then return end

    local role = playerTeamRole(p)
    local roleEnabled = (role == "Killer" and VD.ESP_Killer == true)
        or (role == "Survivor" and VD.ESP_Survivor == true)
    local lobbyEnabled = (role == "Lobby" and VD.ESP_Lobby == true)
    local nameEnabled = VD.ESP_ShowName == true and (role == "Killer" or role == "Survivor" or role == "Lobby")
    local highlightEnabled = roleEnabled or lobbyEnabled

    if not PlayerESPEnabled or not p.Character or (not highlightEnabled and not nameEnabled) then
        PlayerESP_RemoveHighlight(p)
        PlayerESP_RemoveName(p)
        return
    end

    local char = p.Character

    if highlightEnabled then
        local h = ESPObjects[p]
        if not h or not h.Parent or h.Adornee ~= char then
            if h then pcall(function() h:Destroy() end) end
            h = Instance.new("Highlight")
            h.Name = "Mawww_PlayerESP_Rainbow"
            h.Adornee = char
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            ESPObjects[p] = h
            h.Parent = char
        end

        local color = PlayerESP_IsEnemy(p)
            and PlayerESP_Rainbow(PlayerESP_NameOffset(p))
            or PlayerESP_GetStaticColor(p)

        h.FillColor = color
        h.OutlineColor = color
        h.FillTransparency = math.clamp((tonumber(VD.ESP_FillTransparency) or 70) / 100, 0, 1)
        h.OutlineTransparency = math.clamp((tonumber(VD.ESP_OutlineTransparency) or 20) / 100, 0, 1)
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    else
        PlayerESP_RemoveHighlight(p)
    end

    if nameEnabled then
        local bb = PlayerESP_CreateName(p)
        if bb then
            bb.Enabled = true
            local infoLabel = bb:FindFirstChild("InfoLabel")
            if infoLabel then infoLabel.TextColor3 = ESP_TEXT_WHITE end
        end
    else
        PlayerESP_RemoveName(p)
    end
end

local function PlayerESP_RefreshAll()
    local seen = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= Player then
            seen[p] = true
            PlayerESP_UpdateOne(p)
        end
    end
    for p in pairs(ESPObjects) do
        if typeof(p) == "Instance" and p:IsA("Player") and not seen[p] then
            PlayerESP_RemoveHighlight(p)
        end
    end
    for p in pairs(ESPNames) do
        if typeof(p) == "Instance" and p:IsA("Player") and not seen[p] then
            PlayerESP_RemoveName(p)
        end
    end
end

-- Rainbow animation is applied only to the enemy highlight.
task.spawn(function()
    while not VD.Destroyed do
        local now = os.clock()
        if now - PlayerESP_LastColorUpdate >= 0.07 then
            PlayerESP_LastColorUpdate = now
            if PlayerESPEnabled and (VD.ESP_Killer or VD.ESP_Survivor) then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= Player and p.Character then
                        local h = ESPObjects[p]
                        if h and h.Parent and PlayerESP_IsEnemy(p) then
                            local role = playerTeamRole(p)
                            local enabled = (role == "Killer" and VD.ESP_Killer == true)
                                or (role == "Survivor" and VD.ESP_Survivor == true)
                            if enabled then
                                local c = PlayerESP_Rainbow(PlayerESP_NameOffset(p))
                                h.FillColor = c
                                h.OutlineColor = c
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.07)
    end
end)

local ESPPlayerConnections = {}
local function PlayerESP_HookPlayer(p)
    if p == Player or ESPPlayerConnections[p] then return end
    local conns = {}
    conns[#conns + 1] = p.CharacterAdded:Connect(function()
        task.wait(0.2)
        if not VD.Destroyed then
            PlayerESP_RemoveHighlight(p)
            PlayerESP_RemoveName(p)
            PlayerESP_UpdateOne(p)
        end
    end)
    conns[#conns + 1] = p.CharacterRemoving:Connect(function()
        PlayerESP_RemoveHighlight(p)
        PlayerESP_RemoveName(p)
    end)
    conns[#conns + 1] = p:GetPropertyChangedSignal("Team"):Connect(function()
        task.defer(function()
            if not VD.Destroyed then PlayerESP_UpdateOne(p) end
        end)
    end)
    ESPPlayerConnections[p] = conns
end

local function PlayerESP_UnhookPlayer(p)
    local conns = ESPPlayerConnections[p]
    if conns then
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        ESPPlayerConnections[p] = nil
    end
    PlayerESP_RemoveHighlight(p)
    PlayerESP_RemoveName(p)
end

for _, p in ipairs(Players:GetPlayers()) do
    PlayerESP_HookPlayer(p)
end

Players.PlayerAdded:Connect(function(p)
    PlayerESP_HookPlayer(p)
end)

Players.PlayerRemoving:Connect(function(p)
    PlayerESP_UnhookPlayer(p)
end)

-- Global player ESP refresh; intentionally no player-distance condition.
task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.18)
        if PlayerESPEnabled and (VD.ESP_Killer or VD.ESP_Survivor or VD.ESP_Lobby or VD.ESP_ShowName) then
            pcall(PlayerESP_RefreshAll)
        end
    end
end)

--========================================================--
-- NAME VISIBILITY / DISTANCE:
-- always rendered regardless of player distance.
--========================================================--

function createNameBillboard(char)
    local p = char and Players:GetPlayerFromCharacter(char)
    if not p then return end
    return PlayerESP_CreateName(p)
end

function removeNameBillboard(char)
    local p = char and Players:GetPlayerFromCharacter(char)
    if p then PlayerESP_RemoveName(p) end
end

function updateNameBillboard(char)
    local p = char and Players:GetPlayerFromCharacter(char)
    if p then PlayerESP_UpdateOne(p) end
end

-- Keep the existing ESP toggle, but make the label description explicit.
RegToggle(Tabs.ESP, "Killer ESP", "Highlight killers. Enemy killer ESP is neon rainbow when you are Survivor.", false, "ESP_Killer")
RegToggle(Tabs.ESP, "Survivor ESP", "Highlight survivors. Enemy survivor ESP is neon rainbow when you are Killer.", false, "ESP_Survivor")
RegToggle(Tabs.ESP, "Lobby Player ESP", "Show player highlights in the lobby / spectator area.", true, "ESP_Lobby")
RegToggle(Tabs.ESP, "SCP ESP", "Highlight SCPs", false, "ESP_SCP")
RegToggle(Tabs.ESP, "Generator ESP", "Highlight generators", false, "ESP_Generator")
RegToggle(Tabs.ESP, "Window ESP", "Highlight windows", false, "ESP_Window")
RegToggle(Tabs.ESP, "Pallet ESP", "Highlight pallets", false, "ESP_Pallet")
RegToggle(Tabs.ESP, "Hook ESP", "Highlight hooks", false, "ESP_Hook")
RegSlider(Tabs.ESPOptions, "Object ESP Radius", "Used for object ESP only. Player/Killer ESP has no distance limit.", 250, 50, 1000, 10, "ESP_Distance")
RegToggle(Tabs.ESPOptions, "Player Name & Distance", "White name with distance beside it; no distance limit.", false, "ESP_ShowName")
RegToggle(Tabs.ESPOptions, "Generator Progress", "Show generator progress", false, "ESP_ShowGenProgress")
RegDivider(Tabs.ESPOptions)
RegLabel(Tabs.ESPOptions, "ESP Colors")
RegSlider(Tabs.ESPOptions, "Fill Transparency", "Highlight fill transparency", 70, 0, 100, 1, "ESP_FillTransparency")
RegSlider(Tabs.ESPOptions, "Outline Transparency", "Highlight outline transparency", 20, 0, 100, 1, "ESP_OutlineTransparency")

function createGenProgressBillboard(gen)
    if not gen then return end
    local existing = ESPGenProgress[gen]
    if existing and existing.Parent then
        local lbl = existing:FindFirstChild("ProgressLabel")
        if lbl then
            local progress = tonumber(gen:GetAttribute("RepairProgress")) or tonumber(gen:GetAttribute("ProgressRepair")) or 0
            progress = math.floor(progress)
            local kickcount = tonumber(gen:GetAttribute("kickcount")) or 0
            lbl.Text = string.format("Progress: %d%%", progress)
            if progress >= 100 then lbl.TextColor3 = Color3.fromRGB(0,255,100)
            elseif kickcount > 0 then lbl.TextColor3 = Color3.fromRGB(255,100,100)
            else lbl.TextColor3 = Color3.fromRGB(255,170,0) end
        end
        return existing
    end

    local adornee = gen.PrimaryPart or gen:FindFirstChildWhichIsA("BasePart", true)
    if not adornee then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "MWD_GenProgress"
    bb.Size = UDim2.fromOffset(160,20)
    bb.StudsOffset = Vector3.new(0,3.2,0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 0
    bb.Adornee = adornee
    bb.Parent = adornee

    local lbl = Instance.new("TextLabel")
    lbl.Name = "ProgressLabel"
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "Progress: 0%"
    lbl.TextColor3 = Color3.fromRGB(255,170,0)
    lbl.TextStrokeTransparency = 0.3
    lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    lbl.TextSize = 14
    lbl.Font = Enum.Font.GothamBold
    lbl.Parent = bb

    ESPGenProgress[gen] = bb
    return bb
end

function removeGenProgressBillboard(gen)
    local bb = ESPGenProgress[gen]
    if bb then
        pcall(function() bb:Destroy() end)
        ESPGenProgress[gen] = nil
    end
end

local function ESP_GetObjectPosition(obj)
    if not obj or not obj.Parent then return nil end
    local ok, pos = pcall(function()
        if obj:IsA("Model") then return obj:GetPivot().Position end
        if obj:IsA("BasePart") then return obj.Position end
        if obj:IsA("Attachment") then return obj.WorldPosition end
        return nil
    end)
    return ok and pos or nil
end

local function ESP_ObjectInRange(obj, root)
    local pos = ESP_GetObjectPosition(obj)
    if not pos or not root then return false end
    local radius = tonumber(VD.ESP_Distance) or 250
    return (pos - root.Position).Magnitude <= radius
end

function updateESP()
    -- Player ESP is handled by its dedicated cached refresh loop so world-object
    -- polling never duplicates the player scan. World-object ESP still requires a local root.
    local root = getRoot()

    if not root then return end

    if VD.ESP_SCP then
        for obj in pairs(CachedSCP) do
            if obj and obj.Parent and ESP_ObjectInRange(obj, root) then createESP(obj, ESP_Colors.SCP)
            else removeESP(obj) end
        end
    else
        for obj in pairs(CachedSCP) do removeESP(obj) end
    end

    if VD.ESP_Generator then
        for obj in pairs(CachedGenerators) do
            if obj and obj.Parent and ESP_ObjectInRange(obj, root) then
                createESP(obj, ESP_Colors.Generator)
                if VD.ESP_ShowGenProgress then createGenProgressBillboard(obj)
                else removeGenProgressBillboard(obj) end
            else
                removeESP(obj)
                removeGenProgressBillboard(obj)
            end
        end
    else
        for obj in pairs(CachedGenerators) do
            removeESP(obj)
            removeGenProgressBillboard(obj)
        end
    end

    if VD.ESP_Window then
        for obj in pairs(CachedWindows) do
            if obj and obj.Parent and ESP_ObjectInRange(obj, root) then createESP(obj, ESP_Colors.Window)
            else removeESP(obj) end
        end
    else
        for obj in pairs(CachedWindows) do removeESP(obj) end
    end

    if VD.ESP_Pallet then
        for obj in pairs(CachedPallets) do
            if obj and obj.Parent and ESP_ObjectInRange(obj, root) then createESP(obj, ESP_Colors.Pallet)
            else removeESP(obj) end
        end
    else
        for obj in pairs(CachedPallets) do removeESP(obj) end
    end

    if VD.ESP_Hook then
        for obj in pairs(CachedHooks) do
            if obj and obj.Parent and ESP_ObjectInRange(obj, root) then createESP(obj, ESP_Colors.Hook)
            else removeESP(obj) end
        end
    else
        for obj in pairs(CachedHooks) do removeESP(obj) end
    end
end

task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.25)
        if VD.ESP_Survivor or VD.ESP_Killer or VD.ESP_SCP or VD.ESP_Generator or VD.ESP_Window or VD.ESP_Pallet or VD.ESP_Hook or VD.ESP_ShowName or VD.ESP_ShowGenProgress then
            pcall(updateESP)
        end
    end
end)

-- Reload-safe controller for the player ESP engine.
getgenv().MAWWW_SourcePlayerESP = {
    SetEnabled = function(v)
        PlayerESPEnabled = v == true
        if not PlayerESPEnabled then
            for p in pairs(ESPObjects) do
                if typeof(p) == "Instance" and p:IsA("Player") then PlayerESP_RemoveHighlight(p) end
            end
            for p in pairs(ESPNames) do PlayerESP_RemoveName(p) end
        else
            pcall(PlayerESP_RefreshAll)
        end
    end,
    Refresh = function() pcall(PlayerESP_RefreshAll) end,
    Destroy = function()
        PlayerESPEnabled = false
        for p in pairs(ESPPlayerConnections) do PlayerESP_UnhookPlayer(p) end
        for p in pairs(ESPObjects) do
            if typeof(p) == "Instance" and p:IsA("Player") then PlayerESP_RemoveHighlight(p) end
        end
        for p in pairs(ESPNames) do PlayerESP_RemoveName(p) end
    end,
}

pcall(PlayerESP_RefreshAll)

-- VISUAL TAB
--========================================================--

RegLabel(Tabs.VisualCamera, "Camera")
CameraZoom = { DefaultFOV = (workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView) or 70 }
function applyUnlimitedZoom()
    if VD.UnlimitedZoom then Player.CameraMaxZoomDistance = VD.MaxZoomDistance; Player.CameraMinZoomDistance = 0
    else Player.CameraMaxZoomDistance = 128; Player.CameraMinZoomDistance = 0.5 end
end
function applyCameraFOV()
    local cam = workspace.CurrentCamera; if not cam then return end
    if VD.FOVEnabled then cam.FieldOfView = VD.FOV
    else cam.FieldOfView = CameraZoom.DefaultFOV end
end
Player.CharacterAdded:Connect(function() task.wait(0.5); applyUnlimitedZoom(); applyCameraFOV() end)
local FOVLastUpdate = 0
RunService.RenderStepped:Connect(function()
    local now = os.clock()
    if now - FOVLastUpdate < 0.10 then return end
    FOVLastUpdate = now
    if VD.FOVEnabled and VD.CAM_FOVEnabled ~= true then
        local cam = workspace.CurrentCamera
        if cam and cam.FieldOfView ~= VD.FOV then cam.FieldOfView = VD.FOV end
    end
end)
RegToggle(Tabs.VisualCamera, "Unlimited Zoom", "Remove zoom limit", false, "UnlimitedZoom", function(v) applyUnlimitedZoom() end)
RegSlider(Tabs.VisualCamera, "Max Zoom Distance", "Max camera distance", 1000, 100, 5000, 50, "MaxZoomDistance", function(v) if VD.UnlimitedZoom then applyUnlimitedZoom() end end)
RegToggle(Tabs.VisualCamera, "Fixed FOV • 90", "Fixed 90 FOV source is active.", false, "FOVEnabled", function(v) VD.FOVEnabled = true; VD.FOV = 90; applyCameraFOV() end)
RegSlider(Tabs.VisualCamera, "Camera FOV", "Source fixed at 90.", 90, 90, 90, 1, "FOV", function(v) VD.FOV = 90; VD.FOVEnabled = true; applyCameraFOV() end)

shiftLockWasActive = false
thirdPersonWasActive = false
local CameraControlLastUpdate = 0
RunService.RenderStepped:Connect(function()
    local now = os.clock()
    if now - CameraControlLastUpdate < 0.033 then return end
    CameraControlLastUpdate = now
    local cam = workspace.CurrentCamera; if not cam then return end
    local char = Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if VD.ThirdPerson and GetRole() == "Killer" and hum then
        cam.CameraType = Enum.CameraType.Custom
        hum.CameraOffset = Vector3.new(2, 1, 8)
        thirdPersonWasActive = true
    elseif thirdPersonWasActive then
        if hum then hum.CameraOffset = Vector3.zero end
        thirdPersonWasActive = false
    end
    if VD.ShiftLock then
        local char = Player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if hum and root then
            hum.AutoRotate = false
            local flat = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
            if flat.Magnitude > 0.001 then root.CFrame = CFrame.new(root.Position, root.Position + flat.Unit) end
        end
        shiftLockWasActive = true
    elseif shiftLockWasActive then
        local hum = getHum(); if hum then hum.AutoRotate = true end
        shiftLockWasActive = false
    end
end)
RegToggle(Tabs.VisualCamera, "Third Person (Killer)", "Third person camera", false, "ThirdPerson")
RegToggle(Tabs.VisualCamera, "Shift Lock", "Enable shift lock", false, "ShiftLock")
NoCutsceneState = {Saved = {}}
function SetNoCutscene(enabled)
    enabled = enabled == true
    if enabled then
        for _, gui in ipairs(PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") then
                local n = gui.Name:lower()
                if n:find("cutscene", 1, true) or n:find("cinematic", 1, true) or n:find("intro", 1, true) or n:find("outro", 1, true) then
                    if NoCutsceneState.Saved[gui] == nil then
                        NoCutsceneState.Saved[gui] = gui.Enabled
                    end
                    gui.Enabled = false
                end
            end
        end
    else
        for gui, wasEnabled in pairs(NoCutsceneState.Saved) do
            if gui and gui.Parent then
                pcall(function() gui.Enabled = wasEnabled == true end)
            end
            NoCutsceneState.Saved[gui] = nil
        end
    end
end
RegToggle(Tabs.VisualCamera, "No Cutscene", "Skip common cutscene/cinematic interfaces", false, "NoCutscene", function(v) SetNoCutscene(v) end)
task.spawn(function()
    while not VD.Destroyed do
        task.wait(0.4)
        if VD.NoCutscene then pcall(SetNoCutscene, true) end
    end
end)

RegDivider(Tabs.VisualLighting)
RegLabel(Tabs.VisualLighting, "Lighting")
RegToggle(Tabs.VisualLighting, "Fullbright", "Full bright lighting", false, "Fullbright")
RegToggle(Tabs.VisualLighting, "No Fog", "Remove fog", false, "NO_Fog")

VD_WeatherPresets = {
    ["Default"] = {},
    ["Christmas (Snow)"] = { Lighting={FogColor=Color3.fromRGB(150,180,220),FogEnd=200,ClockTime=8,OutdoorAmbient=Color3.fromRGB(100,120,150)}, Atmosphere={Density=0.5,Color=Color3.fromRGB(180,200,220),Decay=Color3.fromRGB(150,180,220),Haze=5,Glare=0} },
    ["Heavy Rain (Storm)"] = { Lighting={FogColor=Color3.fromRGB(50,50,60),FogEnd=150,OutdoorAmbient=Color3.fromRGB(40,40,50),Brightness=0.2,ClockTime=12}, CC={TintColor=Color3.fromRGB(150,150,180),Contrast=0.2,Saturation=-0.5} },
    ["Autumn (Musim Gugur)"] = { Lighting={FogColor=Color3.fromRGB(200,150,80),FogEnd=500,OutdoorAmbient=Color3.fromRGB(180,140,70),ClockTime=16.5}, CC={TintColor=Color3.fromRGB(255,220,180),Contrast=0.1,Saturation=0.2} },
    ["Cherry Blossom (Sakura)"] = { Lighting={FogColor=Color3.fromRGB(255,200,220),FogEnd=600,OutdoorAmbient=Color3.fromRGB(255,180,200),ClockTime=9}, CC={TintColor=Color3.fromRGB(255,230,240),Saturation=0.3} },
    ["Sunset (Golden Hour)"] = { Lighting={FogColor=Color3.fromRGB(255,120,50),FogEnd=1200,OutdoorAmbient=Color3.fromRGB(200,100,50),ClockTime=17.5,Brightness=1.5}, CC={TintColor=Color3.fromRGB(255,200,150),Contrast=0.2,Saturation=0.4} },
    ["Blood Moon (Spooky)"] = { Lighting={FogColor=Color3.fromRGB(150,10,10),FogEnd=500,OutdoorAmbient=Color3.fromRGB(80,0,0),ClockTime=0,Brightness=0.3}, CC={TintColor=Color3.fromRGB(255,50,50),Contrast=0.4,Saturation=0.5} },
    ["Toxic Wasteland"] = { Lighting={FogColor=Color3.fromRGB(80,150,50),FogEnd=250,OutdoorAmbient=Color3.fromRGB(50,120,40),ClockTime=12,Brightness=1}, CC={TintColor=Color3.fromRGB(150,255,150),Contrast=0.1,Saturation=0.3} },
    ["Vaporwave (Synthwave)"] = { Lighting={FogColor=Color3.fromRGB(200,50,255),FogEnd=500,OutdoorAmbient=Color3.fromRGB(150,0,200),ClockTime=20,Brightness=1}, CC={TintColor=Color3.fromRGB(255,100,255),Contrast=0.3,Saturation=0.5} },
    ["Midnight (Pitch Black)"] = { Lighting={FogColor=Color3.fromRGB(0,0,0),FogEnd=100,OutdoorAmbient=Color3.fromRGB(0,0,0),Brightness=0,ClockTime=0}, CC={TintColor=Color3.fromRGB(50,50,50),Contrast=0.5,Saturation=-0.8} }
}
function VD_ApplyWeather(themeName)
    local theme = VD_WeatherPresets[themeName] or VD_WeatherPresets["Default"]
    if getgenv().VD_WeatherCC and getgenv().VD_WeatherCC.Parent then getgenv().VD_WeatherCC:Destroy() end
    getgenv().VD_WeatherCC = nil
    if getgenv().VD_WeatherAtmosphere and getgenv().VD_WeatherAtmosphere.Parent then getgenv().VD_WeatherAtmosphere:Destroy() end
    getgenv().VD_WeatherAtmosphere = nil
    if theme.Atmosphere then
        local atm = Instance.new("Atmosphere"); atm.Name = "VD_WeatherAtmosphere"
        for k, v in pairs(theme.Atmosphere) do pcall(function() atm[k] = v end) end
        atm.Parent = Lighting; getgenv().VD_WeatherAtmosphere = atm
    end
    if theme.CC then
        local cc = Instance.new("ColorCorrectionEffect"); cc.Name = "VD_WeatherCC"
        for k, v in pairs(theme.CC) do pcall(function() cc[k] = v end) end
        cc.Parent = Lighting; getgenv().VD_WeatherCC = cc
    end
    if theme.Lighting then for k, v in pairs(theme.Lighting) do pcall(function() Lighting[k] = v end) end end
end
task.spawn(function()
    while not VD.Destroyed do
        if VD.Fullbright then
            Lighting.Brightness = 2; Lighting.ClockTime = 14
            Lighting.GlobalShadows = false
            Lighting.OutdoorAmbient = Color3.fromRGB(128,128,128)
            Lighting.FogStart = 0; Lighting.FogEnd = 100000
            for _, v in pairs(Lighting:GetChildren()) do
                if v:IsA("Atmosphere") and v.Name ~= "VD_WeatherAtmosphere" then v.Density = 0; v.Offset = 0; v.Glare = 0; v.Haze = 0 end
                if v:IsA("BlurEffect") then v.Size = 0 end
                if v:IsA("ColorCorrectionEffect") and v.Name ~= "VD_WeatherCC" then v.Enabled = false end
                if v:IsA("SunRaysEffect") then v.Enabled = false end
            end
        elseif not VD.NO_Fog then
            Lighting.Brightness = originalLighting.Brightness
            Lighting.ClockTime = originalLighting.ClockTime
            Lighting.FogEnd = originalLighting.FogEnd
            Lighting.FogStart = originalLighting.FogStart or 0
            Lighting.GlobalShadows = originalLighting.GlobalShadows
            Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
        end
        if VD.NO_Fog then Lighting.FogEnd = 100000; Lighting.FogStart = 0 end
        task.wait(0.5)
    end
end)
RegDropdown(Tabs.VisualLighting, "Weather & Sky Theme", "Select weather theme",
    {"Default","Christmas (Snow)","Heavy Rain (Storm)","Autumn (Musim Gugur)","Cherry Blossom (Sakura)","Sunset (Golden Hour)","Blood Moon (Spooky)","Toxic Wasteland","Vaporwave (Synthwave)","Midnight (Pitch Black)"},
    "Default", false, "WeatherTheme", function(v) pcall(VD_ApplyWeather, v) end)

-- Visual Implementations
PingFPSGui, PingFPSConn = nil, nil
VD_TogglePingFPS = function(state)
    if PingFPSConn then PingFPSConn:Disconnect(); PingFPSConn = nil end
    if PingFPSGui then PingFPSGui:Destroy(); PingFPSGui = nil end
    if not state then return end
    local sg = Instance.new("ScreenGui")
    sg.Name = "MWD_PingFPS"; sg.IgnoreGuiInset = true; sg.ResetOnSpawn = false; sg.Parent = PlayerGui
    local f = Instance.new("Frame", sg)
    f.Size = UDim2.new(0,118,0,44); f.Position = UDim2.new(0,12,0,120)
    f.BackgroundColor3 = Color3.fromRGB(16,18,24); f.BackgroundTransparency = 0.1; f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,8)
    local st = Instance.new("UIStroke", f); st.Color = Color3.fromRGB(96,72,160); st.Thickness = 1
    local lbl = Instance.new("TextLabel", f)
    lbl.Name = "PFLabel"; lbl.Size = UDim2.new(1,-12,1,-8); lbl.Position = UDim2.new(0,6,0,4)
    lbl.BackgroundTransparency = 1; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 13
    lbl.TextColor3 = Color3.fromRGB(230,235,245); lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = "PING: --ms\nFPS: --"
    PingFPSGui = sg
    local frames, last = 0, tick()
    PingFPSConn = RunService.RenderStepped:Connect(function()
        if not VD.ShowPingFPS then return end
        frames = frames + 1
        local now = tick()
        if now - last < 0.5 then return end
        local fps = math.floor(frames / (now - last) + 0.5)
        local ping
        pcall(function()
            local stats = game:GetService("Stats")
            local srv = stats:FindFirstChild("Network") and stats.Network:FindFirstChild("ServerStatsItem")
            local dp = srv and srv:FindFirstChild("Data Ping")
            if dp and dp.GetValue then ping = math.floor(dp:GetValue() + 0.5) end
        end)
        frames = 0; last = now
        if lbl and lbl.Parent then lbl.Text = ("PING: %sms\nFPS: %d"):format(ping and tostring(ping) or "--", fps) end
    end)
end

HideSurvConn, HideSurvOrig = nil, {}

local function HideSurv_Remember(obj, original)
    if obj and not HideSurvOrig[obj] then
        HideSurvOrig[obj] = original
    end
end

VD_ApplyHideSurvIcon = function()
    local pg = Player and Player:FindFirstChild("PlayerGui")
    if not pg then return end

    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Name:match("%-mob$") then
            local frame = gui:FindFirstChild("Frame")
            if frame then
                for i = 1, 5 do
                    local sf = frame:FindFirstChild("Survivor" .. i)
                    if sf then
                        local il = sf:FindFirstChild("ImageLabel")
                        if il and il:IsA("ImageLabel") then
                            HideSurv_Remember(il, {
                                Image = il.Image,
                                Color = il.ImageColor3,
                                Trans = il.ImageTransparency,
                                Offset = il.ImageRectOffset,
                                Size = il.ImageRectSize,
                                Scale = il.ScaleType,
                                Visible = il.Visible,
                            })

                            -- Use the same Roblox asset id as the Mawww Hub button/logo.
                            il.Image = SURVIVOR_HIDE_ICON_URL
                            il.ImageColor3 = Color3.fromRGB(255, 255, 255)
                            il.ImageTransparency = 0
                            il.ImageRectOffset = Vector2.new(0, 0)
                            il.ImageRectSize = Vector2.new(0, 0)
                            il.ScaleType = Enum.ScaleType.Crop
                            il.Visible = true
                        end

                        local tl = sf:FindFirstChild("TextLabel")
                        if tl and tl:IsA("TextLabel") then
                            HideSurv_Remember(tl, {
                                Text = tl.Text,
                                TextTransparency = tl.TextTransparency,
                                TextStrokeTransparency = tl.TextStrokeTransparency,
                                Visible = tl.Visible,
                            })
                            tl.TextTransparency = 1
                            tl.TextStrokeTransparency = 1
                        end
                    end
                end
            end
        end
    end
end

VD_RestoreHideSurvIcon = function()
    for obj, orig in pairs(HideSurvOrig) do
        if obj and obj.Parent and type(orig) == "table" then
            pcall(function()
                if obj:IsA("ImageLabel") then
                    obj.Image = orig.Image
                    obj.ImageColor3 = orig.Color
                    obj.ImageTransparency = orig.Trans
                    obj.ImageRectOffset = orig.Offset
                    obj.ImageRectSize = orig.Size
                    obj.ScaleType = orig.Scale
                    obj.Visible = orig.Visible
                elseif obj:IsA("TextLabel") then
                    obj.Text = orig.Text
                    obj.TextTransparency = orig.TextTransparency
                    obj.TextStrokeTransparency = orig.TextStrokeTransparency
                    obj.Visible = orig.Visible
                end
            end)
        end
    end
    HideSurvOrig = {}
end

VD_ToggleHideSurvIcon = function(v)
    local enabled = v == true
    VD.HideSurvIcon = enabled

    if enabled then
        HideSurvConn = true
        pcall(VD_ApplyHideSurvIcon)
    else
        HideSurvConn = nil
        pcall(VD_RestoreHideSurvIcon)
    end
end

HookCounterConn = nil
VD_UpdateHookCounter = function(enabled)
    local pg = Player:FindFirstChild("PlayerGui"); if not pg then return end
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Name:match("%-mob$") then
            local frame = gui:FindFirstChild("Frame")
            if frame then
                for i = 1, 5 do
                    local sf = frame:FindFirstChild("Survivor" .. i)
                    local il = sf and sf:FindFirstChild("ImageLabel")
                    local tl = sf and sf:FindFirstChild("TextLabel")
                    if il and tl then
                        local lbl = il:FindFirstChild("MWD_CustomHookCounter")
                        if enabled then
                            local pName = tl.Text
                            local target
                            for _, p in ipairs(MawwwGetPlayers()) do if p.Name == pName or p.DisplayName == pName then target = p; break end end
                            local cnt = 0
                            if target then cnt = target:GetAttribute("HookCount") or (target.Character and target.Character:GetAttribute("HookCount")) or 0 end
                            if not lbl then
                                lbl = Instance.new("TextLabel", il)
                                lbl.Name = "MWD_CustomHookCounter"; lbl.Size = UDim2.new(1,0,0.35,0); lbl.Position = UDim2.new(0,0,0.65,0)
                                lbl.BackgroundColor3 = Color3.fromRGB(0,0,0); lbl.BackgroundTransparency = 0.5
                                lbl.TextStrokeTransparency = 0; lbl.TextScaled = true; lbl.Font = Enum.Font.SourceSansBold
                            end
                            lbl.Visible = true
                            if cnt >= 3 then lbl.Text = "DEAD"; lbl.TextColor3 = Color3.fromRGB(255,75,75)
                            else
                                lbl.Text = "Hooks: " .. tostring(cnt)
                                if cnt == 2 then lbl.TextColor3 = Color3.fromRGB(255,140,0)
                                elseif cnt == 1 then lbl.TextColor3 = Color3.fromRGB(255,215,0)
                                else lbl.TextColor3 = Color3.fromRGB(255,255,255) end
                            end
                        elseif lbl then lbl.Visible = false end
                    end
                end
            end
        end
    end
end
VD_ToggleHookCounter = function(v)
    VD.ShowHookCounter = v
    if v then
        VD_UpdateHookCounter(true)
    else
        HookCounterConn = nil
        VD_UpdateHookCounter(false)
    end
end

-- Shared low-frequency overlay watcher. These two features manipulate
-- UI, not gameplay physics, so 0.25 s is enough and much cheaper than
-- running a full PlayerGui scan every frame.
task.spawn(function()
    while not VD.Destroyed do
        if VD.HideSurvIcon then
            pcall(VD_ApplyHideSurvIcon)
        end
        if VD.ShowHookCounter then
            pcall(VD_UpdateHookCounter, true)
        end
        task.wait(0.25)
    end
end)

-- Info Overlay
InfoOverlayGui, InfoOverlayFrame, InfoOverlayLabel = nil, nil, nil
function EnsureInfoOverlay()
    if InfoOverlayGui and InfoOverlayGui.Parent then return end
    InfoOverlayGui = Instance.new("ScreenGui")
    InfoOverlayGui.Name = "MWD_InfoOverlay"; InfoOverlayGui.ResetOnSpawn = false; InfoOverlayGui.IgnoreGuiInset = true
    InfoOverlayGui.Parent = PlayerGui
    InfoOverlayFrame = Instance.new("Frame")
    InfoOverlayFrame.Size = UDim2.new(0, 230, 0, 0); InfoOverlayFrame.AutomaticSize = Enum.AutomaticSize.Y
    InfoOverlayFrame.Position = UDim2.new(0, 12, 0, 180)
    InfoOverlayFrame.BackgroundColor3 = Color3.fromRGB(16, 18, 24); InfoOverlayFrame.BackgroundTransparency = 0.1
    InfoOverlayFrame.BorderSizePixel = 0; InfoOverlayFrame.Parent = InfoOverlayGui
    Instance.new("UICorner", InfoOverlayFrame).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", InfoOverlayFrame); stroke.Color = Color3.fromRGB(96, 72, 160); stroke.Thickness = 1
    local pad = Instance.new("UIPadding", InfoOverlayFrame)
    pad.PaddingTop = UDim.new(0, 6); pad.PaddingBottom = UDim.new(0, 6); pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)
    InfoOverlayLabel = Instance.new("TextLabel")
    InfoOverlayLabel.Size = UDim2.new(1, 0, 0, 0); InfoOverlayLabel.AutomaticSize = Enum.AutomaticSize.Y
    InfoOverlayLabel.BackgroundTransparency = 1; InfoOverlayLabel.Font = Enum.Font.GothamBold
    InfoOverlayLabel.TextSize = 12; InfoOverlayLabel.TextColor3 = Color3.fromRGB(230, 235, 245)
    InfoOverlayLabel.TextXAlignment = Enum.TextXAlignment.Left; InfoOverlayLabel.TextYAlignment = Enum.TextYAlignment.Top
    InfoOverlayLabel.TextWrapped = true; InfoOverlayLabel.Text = ""; InfoOverlayLabel.Parent = InfoOverlayFrame
end
function UpdateInfoOverlay()
    local anyOn = VD.MawwwtKiller or VD.SpectatorCounter or VD.KillerPerks
    if not anyOn then if InfoOverlayFrame then InfoOverlayFrame.Visible = false end; return end
    if not InfoOverlayFrame then EnsureInfoOverlay() end
    InfoOverlayFrame.Visible = true
    local lines = {}
    if VD.MawwwtKiller then
        local list = MawwwGetPlayers()
        table.sort(list, function(a, b)
            local aA = a:GetAttribute("AllowKiller") or false
            local bB = b:GetAttribute("AllowKiller") or false
            if aA ~= bB then return aA == true end
            return (a:GetAttribute("KillerChance") or 0) > (b:GetAttribute("KillerChance") or 0)
        end)
        local nk = list[1]
        local nkName = nk and (nk == Player and "YOU" or (nk.DisplayName or nk.Name)) or "Unknown"
        local nkScore = nk and (nk:GetAttribute("KillerChance") or 0) or 0
        table.insert(lines, string.format("[Killer Chance] %s (%d)", nkName, nkScore))
    end
    if VD.SpectatorCounter then
        local count = 0
        for _, p in ipairs(MawwwGetPlayers()) do if p.Team and p.Team.Name == "Spectator" then count = count + 1 end end
        table.insert(lines, string.format("[Spectators] %d", count))
    end
    if VD.KillerPerks then
        local k = nil
        for _, p in ipairs(MawwwGetPlayers()) do if p ~= Player and IsKiller(p) then k = p; break end end
        if k then table.insert(lines, string.format("[Killer] %s", k.DisplayName or k.Name))
        else table.insert(lines, "[Killer] None") end
    end
    InfoOverlayLabel.Text = table.concat(lines, "\n")
end
task.spawn(function()
    while not VD.Destroyed do task.wait(1); pcall(UpdateInfoOverlay) end
end)


--========================================================--
-- STUN INDICATOR
-- Detects stunned killers in range and optionally plays a selected sound.
--========================================================--
do
    local StunIndicator = {
        Enabled = false,
        Range = 500,
        SoundEnabled = true,
        SoundVolume = 1.5,
        SoundRange = 500,
        SelectedSound = "an anime",
        Connection = nil,
        Cache = {},
        LastScan = 0,
        ScanInterval = 0.08,
    }

    local StunSounds = {
        ["an anime"] = "128090092396552",
        ["Default"] = "18843924331",
        ["Clash Royale"] = "114072050006157",
        ["Blash"] = "89068385567682",
        ["Coin"] = "75510526696824",
        ["Kururin Kuru"] = "119896940405402",
        ["Spongebob"] = "6835794541",
        ["Fahhhh"] = "123562480982353",
        ["Cave"] = "3173566193",
        ["Aughhh"] = "9095205664",
        ["iPhone"] = "4203251375",
        ["Siren"] = "130677853589923",
    }

    local SoundOptions = {
        "an anime",
        "Default",
        "Clash Royale",
        "Blash",
        "Coin",
        "Kururin Kuru",
        "Spongebob",
        "Fahhhh",
        "Cave",
        "Aughhh",
        "iPhone",
        "Siren",
    }

    local function GetSoundId()
        return StunSounds[StunIndicator.SelectedSound] or StunSounds["Default"]
    end

    local function IsStunned(character)
        if not character then return false end

        local attrs = {
            "IsStunned", "isStunned", "Stunned", "stunned",
            "IsStun", "Stun",
        }

        for _, name in ipairs(attrs) do
            if character:GetAttribute(name) == true then
                return true
            end
        end

        local check = character:FindFirstChild("CheckInterractable")
        if check then
            if check:GetAttribute("isStunned") == true
                or check:GetAttribute("Stunned") == true
                or check:GetAttribute("IsStunned") == true then
                return true
            end
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local stunValue = humanoid:FindFirstChild("StunValue")
            if stunValue then
                local ok, value = pcall(function()
                    return stunValue.Value
                end)
                if ok and tonumber(value) and tonumber(value) > 0 then
                    return true
                end
            end

            local state = humanoid:GetState()
            if state == Enum.HumanoidStateType.PlatformStanding then
                if character:GetAttribute("IsStunned") == true
                    or character:GetAttribute("isStunned") == true then
                    return true
                end
            end
        end

        return false
    end

    local function PlayStunSound(character)
        if not StunIndicator.SoundEnabled then return end
        if StunIndicator.SoundVolume <= 0 then return end

        local attach = character and (
            character:FindFirstChild("Head")
            or character:FindFirstChild("HumanoidRootPart")
        )

        if not attach then return end

        local sound = Instance.new("Sound")
        sound.Name = "MawwwHub_StunSound"
        sound.SoundId = "rbxassetid://" .. tostring(GetSoundId())
        sound.Volume = math.clamp(tonumber(StunIndicator.SoundVolume) or 1.5, 0, 5)
        sound.RollOffMode = Enum.RollOffMode.InverseTapered
        sound.RollOffMinDistance = 10
        sound.RollOffMaxDistance = math.max(10, tonumber(StunIndicator.SoundRange) or 500)
        sound.Parent = attach

        local ok = pcall(function()
            sound:Play()
        end)

        if not ok then
            pcall(function() sound:Destroy() end)
            return
        end

        sound.Ended:Connect(function()
            if sound and sound.Parent then
                pcall(function() sound:Destroy() end)
            end
        end)

        task.delay(8, function()
            if sound and sound.Parent then
                pcall(function() sound:Destroy() end)
            end
        end)
    end

    local function RemoveIndicator(character)
        local data = StunIndicator.Cache[character]
        if not data then return end

        if data.Gui then
            pcall(function()
                data.Gui:Destroy()
            end)
        end

        StunIndicator.Cache[character] = nil
    end

    local function CreateIndicator(character)
        if StunIndicator.Cache[character] then
            local cached = StunIndicator.Cache[character]
            if cached.Gui and cached.Gui.Parent then
                return cached
            end
            StunIndicator.Cache[character] = nil
        end

        local head = character and character:FindFirstChild("Head")
        if not head then return nil end

        local gui = Instance.new("BillboardGui")
        gui.Name = "MawwwHub_StunIndicator"
        gui.Adornee = head
        gui.AlwaysOnTop = true
        gui.LightInfluence = 0
        gui.MaxDistance = math.max(0, tonumber(StunIndicator.Range) or 500)
        gui.Size = UDim2.fromOffset(140, 40)
        gui.StudsOffset = Vector3.new(0, 3, 0)
        gui.Parent = head

        local frame = Instance.new("Frame")
        frame.Name = "Container"
        frame.Size = UDim2.fromScale(1, 1)
        frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        frame.BackgroundTransparency = 0.05
        frame.BorderSizePixel = 0
        frame.Parent = gui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 9)
        corner.Parent = frame

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1.5
        stroke.Color = Color3.fromRGB(255, 255, 255)
        stroke.Transparency = 0.15
        stroke.Parent = frame

        local title = Instance.new("TextLabel")
        title.Name = "Title"
        title.BackgroundTransparency = 1
        title.Position = UDim2.fromOffset(10, 5)
        title.Size = UDim2.new(1, -20, 0, 15)
        title.Font = Enum.Font.GothamBlack
        title.Text = "STUNNED"
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 12
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = frame

        local sub = Instance.new("TextLabel")
        sub.Name = "Subtitle"
        sub.BackgroundTransparency = 1
        sub.Position = UDim2.fromOffset(10, 20)
        sub.Size = UDim2.new(1, -20, 0, 12)
        sub.Font = Enum.Font.GothamBold
        sub.Text = "STUN INDICATOR"
        sub.TextColor3 = Color3.fromRGB(175, 175, 185)
        sub.TextSize = 8
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.Parent = frame

        local data = {
            Gui = gui,
            Stroke = stroke,
        }
        StunIndicator.Cache[character] = data

        task.spawn(function()
            while gui and gui.Parent and StunIndicator.Cache[character] == data do
                local pulse = (math.sin(os.clock() * 4) + 1) / 2
                pcall(function()
                    stroke.Transparency = 0.15 + pulse * 0.45
                    stroke.Thickness = 1.2 + pulse * 0.5
                end)
                task.wait(0.05)
            end
        end)

        return data
    end

    local function CleanupStale()
        for character in pairs(StunIndicator.Cache) do
            if not character or not character.Parent then
                RemoveIndicator(character)
            end
        end
    end

    function StunIndicatorSetEnabled(enabled)
        StunIndicator.Enabled = enabled == true

        if StunIndicator.Connection then
            pcall(function()
                StunIndicator.Connection:Disconnect()
            end)
            StunIndicator.Connection = nil
        end

        if not StunIndicator.Enabled then
            for character in pairs(StunIndicator.Cache) do
                RemoveIndicator(character)
            end
            return
        end

        StunIndicator.LastScan = 0
        StunIndicator.Connection = RunService.Heartbeat:Connect(function()
            if not StunIndicator.Enabled or (VD and VD.Destroyed) then
                return
            end

            local now = os.clock()
            if now - StunIndicator.LastScan < StunIndicator.ScanInterval then
                return
            end
            StunIndicator.LastScan = now

            local myCharacter = Player and Player.Character
            local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")
            if not myRoot then
                CleanupStale()
                return
            end

            local maxRange = math.max(0, tonumber(StunIndicator.Range) or 500)
            local maxRangeSq = maxRange * maxRange
            local seen = {}

            for _, player in ipairs(MawwwGetPlayers()) do
                if player ~= Player and player.Character and IsKiller(player) then
                    local character = player.Character
                    local root = character:FindFirstChild("HumanoidRootPart")

                    if root then
                        local offset = root.Position - myRoot.Position
                        local distanceSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
                        local stunned = distanceSq <= maxRangeSq and IsStunned(character)
                        seen[character] = true

                        if stunned then
                            if not StunIndicator.Cache[character] then
                                PlayStunSound(character)
                                CreateIndicator(character)
                            elseif StunIndicator.Cache[character].Gui
                                and not StunIndicator.Cache[character].Gui.Parent then
                                RemoveIndicator(character)
                            end

                            local cached = StunIndicator.Cache[character]
                            if cached and cached.Gui then
                                pcall(function()
                                    cached.Gui.MaxDistance = maxRange
                                end)
                            end
                        elseif StunIndicator.Cache[character] then
                            RemoveIndicator(character)
                        end
                    elseif StunIndicator.Cache[character] then
                        RemoveIndicator(character)
                    end
                end
            end

            -- Remove indicators for players who are no longer eligible/current.
            for character in pairs(StunIndicator.Cache) do
                if not seen[character] then
                    RemoveIndicator(character)
                end
            end
        end)
    end

    function StunIndicatorPreviewSound()
        if not StunIndicator.SoundEnabled then return end

        local sound = Instance.new("Sound")
        sound.Name = "MawwwHub_StunPreview"
        sound.SoundId = "rbxassetid://" .. tostring(GetSoundId())
        sound.Volume = math.clamp(tonumber(StunIndicator.SoundVolume) or 1.5, 0, 5)
        sound.Parent = SoundService

        local ok = pcall(function()
            sound:Play()
        end)

        if not ok then
            pcall(function() sound:Destroy() end)
            return
        end

        sound.Ended:Connect(function()
            if sound and sound.Parent then
                pcall(function() sound:Destroy() end)
            end
        end)

        task.delay(8, function()
            if sound and sound.Parent then
                pcall(function() sound:Destroy() end)
            end
        end)
    end

    getgenv().MAWWW_StunIndicatorShutdown = function()
        pcall(function()
            StunIndicatorSetEnabled(false)
        end)
        pcall(function()
            for character in pairs(StunIndicator.Cache) do
                RemoveIndicator(character)
            end
        end)
    end

    getgenv().MAWWW_StunIndicator = StunIndicator
    getgenv().MAWWW_StunSounds = StunSounds

    local function ApplyStunIndicatorConfig()
        StunIndicator.Range = math.max(0, tonumber(VD.StunIndicatorRange) or 500)
        StunIndicator.SoundRange = math.max(10, tonumber(VD.StunIndicatorSoundRange) or StunIndicator.Range)
        StunIndicator.SoundVolume = math.clamp(tonumber(VD.StunIndicatorSoundVolume) or 1.5, 0, 5)
        StunIndicator.SoundEnabled = VD.StunIndicatorSoundEnabled ~= false

        local selected = tostring(VD.StunIndicatorSelectedSound or "an anime")
        if not StunSounds[selected] then
            selected = "an anime"
        end
        StunIndicator.SelectedSound = selected

        StunIndicatorSetEnabled(VD.StunIndicatorEnabled == true)
    end

    -- Store the helper globally so loaded configs and other hub modules can reuse it.
    getgenv().MAWWW_ApplyStunIndicatorConfig = ApplyStunIndicatorConfig

    RegDivider(Tabs.VisualHUD, "Stun Indicator")
    RegToggle(
        Tabs.VisualHUD,
        "Stun Indicator",
        "Tampilkan indikator saat killer dalam keadaan stun.",
        false,
        "StunIndicatorEnabled",
        function(v)
            VD.StunIndicatorEnabled = v == true
            StunIndicatorSetEnabled(VD.StunIndicatorEnabled)
        end
    )
    RegSlider(
        Tabs.VisualHUD,
        "Detection Range",
        "Jarak maksimum untuk mendeteksi killer yang sedang stun.",
        500,
        25,
        500,
        5,
        "StunIndicatorRange",
        function(v)
            StunIndicator.Range = math.max(0, tonumber(v) or 500)
            StunIndicator.SoundRange = StunIndicator.Range
        end
    )
    RegToggle(
        Tabs.VisualHUD,
        "Stun Sound",
        "Putar suara ketika stun pertama kali terdeteksi.",
        true,
        "StunIndicatorSoundEnabled",
        function(v)
            StunIndicator.SoundEnabled = v == true
        end
    )
    RegSlider(
        Tabs.VisualHUD,
        "Sound Volume",
        "Atur volume suara indikator stun.",
        1.5,
        0,
        5,
        0.1,
        "StunIndicatorSoundVolume",
        function(v)
            StunIndicator.SoundVolume = math.clamp(tonumber(v) or 1.5, 0, 5)
        end
    )
    RegDropdown(
        Tabs.VisualHUD,
        "Stun Sound Effect",
        "Pilih suara yang diputar saat killer stun.",
        SoundOptions,
        "an anime",
        false,
        "StunIndicatorSelectedSound",
        function(v)
            local selected = tostring(v or "an anime")
            if StunSounds[selected] then
                StunIndicator.SelectedSound = selected
            end
        end
    )
    RegButton(
        Tabs.VisualHUD,
        "Preview Stun Sound",
        "Tes suara stun yang sedang dipilih.",
        function()
            StunIndicatorPreviewSound()
        end
    )

    ApplyStunIndicatorConfig()
end

RegToggle(Tabs.VisualHUD, "Ping & FPS", "Display ping and FPS", false, "ShowPingFPS", function(v) VD.ShowPingFPS = v; VD_TogglePingFPS(v) end)
RegToggle(Tabs.VisualHUD, "Hide Survivor Icons", "Sembunyikan ikon survivor dan gunakan ikon tombol Mawww Hub.", false, "HideSurvIcon", function(v) VD_ToggleHideSurvIcon(v) end)
RegToggle(Tabs.VisualHUD, "Show Hook Counter", "Display hook counter", false, "ShowHookCounter", function(v) VD_ToggleHookCounter(v) end)
RegToggle(Tabs.VisualHUD, "Killer Chance Display", "Show killer chance", false, "MawwwtKiller")
RegToggle(Tabs.VisualHUD, "Spectator Counter", "Show spectator count", false, "SpectatorCounter")
RegToggle(Tabs.VisualHUD, "Killer Perks Display", "Show killer info", false, "KillerPerks", function(v)
    VD.VIS_KillerPerks = v == true
    if v then
        pcall(StartKillerPerksDisplay)
    else
        pcall(StopKillerPerksDisplay)
    end
end)

task.spawn(function()
    while not VD.Destroyed do
        task.wait(1.5)
        pcall(function()
            if VD.ShowPingFPS and not PingFPSGui then VD_TogglePingFPS(true) end
            if not VD.ShowPingFPS and PingFPSGui then VD_TogglePingFPS(false) end
            if VD.HideSurvIcon then
                pcall(VD_ApplyHideSurvIcon)
            elseif HideSurvConn then
                VD_ToggleHideSurvIcon(false)
            end
            if VD.ShowHookCounter and not HookCounterConn then VD_ToggleHookCounter(true) end
            if not VD.ShowHookCounter and HookCounterConn then VD_ToggleHookCounter(false) end
        end)
    end
end)

--========================================================--
-- UTILITY TAB
--========================================================--

RegLabel(Tabs.UtilityTeleport, "Teleport")
function getPlayerList()
    local list = {}
    for _, p in ipairs(MawwwGetPlayers()) do if p ~= Player then table.insert(list, p.Name) end end
    table.sort(list)
    if #list == 0 then table.insert(list, "No players") end
    return list
end
selectedTeleportPlayer = ""
teleportDropdown = nil
pcall(function()
    if Tabs.UtilityTeleport then
        teleportDropdown = Tabs.UtilityTeleport:Dropdown({
            Title = "Select Player", Flag = "TeleportPlayer", Values = getPlayerList(), Value = "No players",
            Multi = false,
            Callback = function(v) selectedTeleportPlayer = v end,
        })
    end
end)
RegButton(Tabs.UtilityTeleport, "Refresh Player List", "Refresh player dropdown", function()
    pcall(function() if teleportDropdown and teleportDropdown.Refresh then teleportDropdown:Refresh(getPlayerList()) end end)
    notify("Teleport", "Player list refreshed", 2)
end)
RegButton(Tabs.UtilityTeleport, "Teleport to Player", "Teleport to selected player", function()
    if selectedTeleportPlayer == "" or selectedTeleportPlayer == "No players" then notify("Teleport", "Select a player first", 3); return end
    local target = Players:FindFirstChild(selectedTeleportPlayer)
    local root = getRoot()
    local targetRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if root and targetRoot then root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3); notify("Teleport", "Teleported to " .. selectedTeleportPlayer, 3) end
end)
function VD_TPToPosition(pos)
    if not pos then return false end
    local char = Player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart"); if not root then return false end
    root.CFrame = CFrame.new(pos + Vector3.new(0, VD.TP_Offset, 0)); return true
end
RegButton(Tabs.UtilityTeleport, "Teleport to Nearest Generator", "Teleport to generator", function()
    local root = getRoot(); if not root then return end
    local best, bd = nil, math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "Generator" and obj:IsA("Model") then
            local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
            if p then local d = (p.Position - root.Position).Magnitude; if d < bd then bd = d; best = p end end
        end
    end
    if best then VD_TPToPosition(best.Position); notify("TP", "Teleported to Generator", 2) end
end)
RegButton(Tabs.UtilityTeleport, "Teleport to Nearest Hook", "Teleport to hook", function()
    local root = getRoot(); if not root then return end
    local best, bd = nil, math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "Hook" and obj:IsA("Model") then
            local p = obj:FindFirstChildWhichIsA("BasePart", true)
            if p then local d = (p.Position - root.Position).Magnitude; if d < bd then bd = d; best = p end end
        end
    end
    if best then VD_TPToPosition(best.Position); notify("TP", "Teleported to Hook", 2) end
end)


RegDivider(Tabs.UtilityGenBoost)
RegLabel(Tabs.UtilityGenBoost, "Gen Boost")

--========================================================--
-- REPLACED: BYPASS GEN / GEN BOOST
-- Source: bypassgene.lua.txt
--========================================================--
W = getgenv().MAWWW or {}
getgenv().MAWWW = W

if not W.GenBypass then
    W.GenBypass = {
        Enabled = VD.GenBoost == true,
        Button = nil,
        UI = nil,
        Cache = {},
        CacheTimer = 0,
        Processed = {},
        HotkeyCode = Enum.KeyCode.G,
        Destroy = nil,
    }
end

GenBypass = W.GenBypass
GenBypass.Enabled = VD.GenBoost == true

function W.GB_GetAllGenerators()
    local now = tick()
    if now - (GenBypass.CacheTimer or 0) < 5 then
        return GenBypass.Cache or {}
    end

    GenBypass.Cache = {}
    GenBypass.CacheTimer = now

    local mapFolder = Workspace:FindFirstChild("Map")
    if not mapFolder then
        return GenBypass.Cache
    end

    pcall(function()
        for _, v in ipairs(mapFolder:GetDescendants()) do
            if v:IsA("Model") and v.Name == "Generator" then
                local isReal =
                    v:GetAttribute("RepairProgress") ~= nil
                    or v:GetAttribute("kickcount") ~= nil
                    or v:GetAttribute("ProgressRepair") ~= nil

                if isReal then
                    table.insert(GenBypass.Cache, v)
                end
            end
        end
    end)

    return GenBypass.Cache
end

function W.GB_GetPoints(genModel)
    local points = {}
    if not genModel then return points end

    pcall(function()
        for _, obj in ipairs(genModel:GetChildren()) do
            if obj.Name:find("GeneratorPoint", 1, true) and obj:IsA("BasePart") then
                table.insert(points, obj)
            end
        end
    end)

    return points
end

function W.GB_WaitRepairing(point, timeout)
    local startTime = tick()
    while point and point.Parent and tick() - startTime < (timeout or 1) do
        if point:GetAttribute("IsRepairing") == true then
            return true
        end
        task.wait(0.05)
    end
    return false
end

function W.GB_DoRepair(targetPoint)
    if not targetPoint or not targetPoint.Parent or not GenBypass.Enabled then return false end

    local genModel = targetPoint.Parent
    if GenBypass.Processed[genModel] then return false end
    GenBypass.Processed[genModel] = true

    local character = Player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        GenBypass.Processed[genModel] = nil
        return false
    end

    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local genFolder = remotes and remotes:FindFirstChild("Generator")
    local repairEvent = genFolder and genFolder:FindFirstChild("RepairEvent")

    if not repairEvent or not repairEvent:IsA("RemoteEvent") then
        GenBypass.Processed[genModel] = nil
        return false
    end

    local originalCFrame = hrp.CFrame

    pcall(function()
        for _, point in ipairs(W.GB_GetPoints(genModel)) do
            if point ~= targetPoint and point.Parent and GenBypass.Enabled then
                hrp.Anchored = true
                hrp.CFrame = point.CFrame
                task.wait(0.15)

                pcall(function()
                    repairEvent:FireServer(point, true)
                end)

                if not W.GB_WaitRepairing(point, 0.8) then
                    pcall(function()
                        repairEvent:FireServer(point, false)
                    end)
                    task.wait(0.1)

                    if point.Parent and hrp.Parent then
                        hrp.CFrame = point.CFrame
                    end

                    task.wait(0.15)

                    pcall(function()
                        repairEvent:FireServer(point, true)
                    end)
                    W.GB_WaitRepairing(point, 0.5)
                end

                hrp.Anchored = false
                task.wait(0.05)
            end
        end
    end)

    pcall(function()
        if hrp and hrp.Parent then
            hrp.Anchored = false
            hrp.CFrame = originalCFrame
        end
    end)

    task.wait(0.1)

    if targetPoint.Parent then
        pcall(function()
            repairEvent:FireServer(targetPoint, false)
        end)
    end

    GenBypass.Processed[genModel] = nil
    return true
end

function W.GB_GetNearestPoint()
    local character = Player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, math.huge end

    local bestPoint, bestDist = nil, math.huge

    for _, genModel in ipairs(W.GB_GetAllGenerators()) do
        for _, point in ipairs(W.GB_GetPoints(genModel)) do
            local dist = (hrp.Position - point.Position).Magnitude
            if dist < bestDist then
                bestDist = dist
                bestPoint = point
            end
        end
    end

    return bestPoint, bestDist
end

function W.GB_IsPromptVisible()
    local ok, frame = pcall(function()
        return PlayerGui.pcprompts.Frame.GeneratorRepair
    end)
    return ok and frame and frame.Visible
end

function W.GB_UpdateButton()
    if GenBypass.Button and GenBypass.Button.Parent then
        GenBypass.Button.Visible = GenBypass.Enabled == true
    end
end

function W.GB_CreateButton()
    local oldUI = PlayerGui:FindFirstChild("BypassGenUI")
    if oldUI then
        pcall(function() oldUI:Destroy() end)
    end

    local ui = Instance.new("ScreenGui")
    ui.Name = "BypassGenUI"
    ui.ResetOnSpawn = false
    ui.IgnoreGuiInset = true
    ui.DisplayOrder = 999998
    ui.Parent = PlayerGui

    GenBypass.UI = ui

    local button = Instance.new("ImageButton")
    button.Name = "BypassGenButton"
    button.Size = UDim2.fromOffset(60, 60)
    button.Position = UDim2.new(0.88, 0, 0.55, 0)
    button.AnchorPoint = Vector2.new(0.5, 0.5)
    button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    button.BackgroundTransparency = 0.15
    button.AutoButtonColor = true
    button.Visible = GenBypass.Enabled == true
    button.ZIndex = 10
    button.Parent = ui

    Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 0, 0)
    stroke.Thickness = 2
    stroke.Transparency = 0.2
    stroke.Parent = button

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "GEN"
    label.TextColor3 = Color3.fromRGB(255, 0, 0)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBlack
    label.ZIndex = 11
    label.Parent = button

    GenBypass.Button = button

    button.MouseButton1Click:Connect(function()
        if not GenBypass.Enabled then return end

        local point, distance = W.GB_GetNearestPoint()
        if point and distance <= 8 then
            task.spawn(function()
                pcall(function() W.GB_DoRepair(point) end)
            end)
        end
    end)

    return ui
end

if GenBypass._CharacterConnection then
    pcall(function() GenBypass._CharacterConnection:Disconnect() end)
end

GenBypass._CharacterConnection = Player.CharacterAdded:Connect(function()
    task.wait(0.5)
    if not VD.Destroyed then
        W.GB_CreateButton()
        W.GB_UpdateButton()
    end
end)

if GenBypass._InputConnection then
    pcall(function() GenBypass._InputConnection:Disconnect() end)
end

GenBypass._InputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not GenBypass.Enabled then return end
    if input.KeyCode ~= GenBypass.HotkeyCode then return end

    local point, distance = W.GB_GetNearestPoint()
    if point and distance <= 8 and not GenBypass.Processed[point.Parent] then
        task.spawn(function()
            pcall(function() W.GB_DoRepair(point) end)
        end)
    end
end)

W.setGenBypass = function(value)
    GenBypass.Enabled = value == true
    VD.GenBoost = GenBypass.Enabled
    W.GB_UpdateButton()
    if getgenv().MAWWW_QuickRefresh then
        pcall(getgenv().MAWWW_QuickRefresh)
    end
end

W.GB_CreateButton()
W.GB_UpdateButton()

RegToggle(Tabs.UtilityGenBoost, "Gen Boost", "Enable the supplied Bypass Gen source.", VD.GenBoost == true, "GenBoost", function(v)
    W.setGenBypass(v)
end)

RegButton(Tabs.UtilityGenBoost, "Repair Nearest Gen (Manual)", "Run the supplied generator repair routine once.", function()
    local point, distance = W.GB_GetNearestPoint()
    if point and distance <= 8 then
        task.spawn(function()
            pcall(function() W.GB_DoRepair(point) end)
        end)
    elseif point then
        notify("Gen Boost", string.format("Gen terlalu jauh (%.1f studs).", distance), 3)
    else
        notify("Gen Boost", "Tidak ada generator ditemukan.", 3)
    end
end)

RegToggle(Tabs.UtilityGenBoost, "Show GenBoss Icon", "Show gen boss icon", false, "ShowGenBossIcon", function()
    if getgenv().MAWWW_QuickRefresh then pcall(getgenv().MAWWW_QuickRefresh) end
end)

RegToggle(Tabs.UtilityGenBoost, "Lock GenBoss Icon", "Lock icon position", false, "LockGenBossIcon", function()
    if getgenv().MAWWW_QuickRefresh then pcall(getgenv().MAWWW_QuickRefresh) end
end)

RegDivider(Tabs.UtilityQuick)
RegLabel(Tabs.UtilityQuick, "Anti-AFK")
RegToggle(Tabs.UtilityQuick, "Anti-AFK", "Prevent AFK kick", false, "AntiAFK")
task.spawn(function()
    while not VD.Destroyed do
        task.wait(60)
        if VD.AntiAFK then pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new(0, 0)) end) end
    end
end)

RegDivider(Tabs.UtilityQuick)
RegLabel(Tabs.UtilityQuick, "Quick / Actions")
RegButton(Tabs.UtilityQuick, "Rejoin Server Instantly", "Rejoin current server", function()
    notify("Rejoin", "Rejoining...", 2); task.wait(0.3)
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player) end)
end)
RegButton(Tabs.UtilityQuick, "Reset Character", "Reset your character", function()
    local char = Player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.Health = 0 end); notify("Reset", "Character reset!", 2)
    else notify("Reset", "No character found", 2) end
end)


RegDivider(Tabs.AutoFarmHop)
RegLabel(Tabs.AutoFarmHop, "Server / Hop")
MAX_HISTORY_SIZE = 200
function VD_SH_MarkVisited(jobId)
    if not jobId or jobId == "" then return end
    VD.SH_VisitedServers[jobId] = tick()
    local count = 0
    for _ in pairs(VD.SH_VisitedServers) do count = count + 1 end
    if count > MAX_HISTORY_SIZE then
        local oldestId, oldestT = nil, math.huge
        for id, t in pairs(VD.SH_VisitedServers) do if t < oldestT then oldestT = t; oldestId = id end end
        if oldestId then VD.SH_VisitedServers[oldestId] = nil end
    end
end
function VD_SH_GetServerList()
    local list = {}
    local placeId = game.PlaceId; local myJobId = game.JobId
    local visited = VD.SH_VisitedServers or {}
    local cursor = nil
    for _ = 1, 3 do
        local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100&cursor=%s", placeId, cursor or "")
        local ok, result = pcall(function() return HttpService:JSONDecode(game:HttpGet(url, true)) end)
        if not ok or not result or not result.data then break end
        for _, s in ipairs(result.data) do
            if s.id and s.playing and s.maxPlayers then
                local skip = (s.id == myJobId)
                if not skip and VD.SH_SkipVisited and visited[s.id] then skip = true end
                if not skip and s.playing < (VD.SH_MinPlayers or 3) then skip = true end
                if not skip and s.playing >= s.maxPlayers then skip = true end
                if not skip then table.insert(list, { Id=s.id, Playing=s.playing, Max=s.maxPlayers, Ping=s.ping or 999, FillRate=s.playing / math.max(s.maxPlayers, 1) }) end
            end
        end
        if result.nextPageCursor then cursor = result.nextPageCursor else break end
    end
    for i = #list, 2, -1 do local j = math.random(1, i); list[i], list[j] = list[j], list[i] end
    return list
end
function VD_SH_PickServer()
    local list = VD_SH_GetServerList(); if #list == 0 then return nil end
    if VD.SH_RandomHop then return list[math.random(1, #list)] end
    for _, s in ipairs(list) do if s.FillRate >= 0.6 then return s end end
    return list[1]
end
function VD_SH_Hop(reason)
    if VD.SH_IsHopping then notify("Server / Hop", "Sedang hop...", 2); return end
    if tick() - VD.SH_LastHopTime < (VD.SH_HopCooldown or 15) then
        local cd = math.ceil((VD.SH_HopCooldown or 15) - (tick() - VD.SH_LastHopTime))
        notify("Server / Hop", "Cooldown " .. cd .. "s", 2); return
    end
    VD.SH_IsHopping = true; VD.SH_LastHopTime = tick()
    notify("Server / Hop", reason or "Mencari server...", 3)
    if game.JobId and game.JobId ~= "" then VD_SH_MarkVisited(game.JobId) end
    local target = VD_SH_PickServer()
    if not target and VD.SH_AutoResetWhenAllVisited then
        local visitedCount = 0
        for _ in pairs(VD.SH_VisitedServers) do visitedCount = visitedCount + 1 end
        if visitedCount > 1 then
            VD.SH_VisitedServers = {}
            if game.JobId and game.JobId ~= "" then VD.SH_VisitedServers[game.JobId] = tick() end
            target = VD_SH_PickServer()
        end
    end
    if not target then
        pcall(function() TeleportService:Teleport(game.PlaceId, Player) end)
        task.wait(3); VD.SH_IsHopping = false; return
    end
    VD_SH_MarkVisited(target.Id)
    local modeTxt = VD.SH_RandomHop and "RANDOM" or "BEST"
    notify("Server / Hop", string.format("[%s] -> [%d/%d] Ping:%d", modeTxt, target.Playing, target.Max, target.Ping), 3)
    local teleportOk = false
    for _ = 1, (VD.SH_MaxRetries or 5) do
        local ok = pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, target.Id, Player) end)
        if ok then teleportOk = true; VD.SH_HopCount = VD.SH_HopCount + 1; break end
        task.wait(1)
    end
    if not teleportOk then pcall(function() TeleportService:Teleport(game.PlaceId, Player) end) end
    task.wait(5); VD.SH_IsHopping = false
end
RegToggle(Tabs.AutoFarmHop, "Server / Hop", "Enable server hop", false, "SH_Enabled")
RegToggle(Tabs.AutoFarmHop, "Random Server Hop", "Random hop", true, "SH_RandomHop")
RegToggle(Tabs.AutoFarmHop, "Hop After Match", "Hop after match", true, "SH_HopAfterMatch")
RegToggle(Tabs.AutoFarmHop, "Skip Visited Server", "Skip visited servers", true, "SH_SkipVisited")
RegToggle(Tabs.AutoFarmHop, "Auto Reset When All Visited", "Reset history when all visited", true, "SH_AutoResetWhenAllVisited")
RegSlider(Tabs.AutoFarmHop, "Hop Cooldown (s)", "Cooldown between hops", 15, 5, 120, 1, "SH_HopCooldown")
RegSlider(Tabs.AutoFarmHop, "Min Players Target", "Minimum players", 3, 1, 20, 1, "SH_MinPlayers")
RegButton(Tabs.AutoFarmHop, "Hop Random Sekarang", "Manual random hop", function() VD_SH_Hop("Manual random hop") end)
RegButton(Tabs.AutoFarmHop, "Reset History Server", "Reset visited servers", function()
    VD.SH_VisitedServers = {}
    if game.JobId and game.JobId ~= "" then VD.SH_VisitedServers[game.JobId] = tick() end
    notify("Server / Hop", "History server di-reset!", 3)
end)
pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(_, result)
        VD.SH_IsHopping = false; VD.SH_LastHopTime = 0
        notify("Server / Hop", "Teleport gagal: " .. tostring(result), 3)
    end)
end)

--========================================================--
-- AUTO FARM TAB
--========================================================--

RegLabel(Tabs.AutoFarm, "Auto Farm")
function AF_ClickLobbyButton()
    local pg = Player:FindFirstChild("PlayerGui"); if not pg then return false end
    local keywords = {"Play","Ready","Start","Confirm","Join","Continue","Requeue","Vote","Yes","Begin"}
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            for _, d in ipairs(gui:GetDescendants()) do
                if d:IsA("TextButton") or d:IsA("ImageButton") then
                    local txt = ""; pcall(function() txt = tostring(d.Text or "") end)
                    for _, kw in ipairs(keywords) do
                        if txt:lower():find(kw:lower(), 1, true) and d.Visible then
                            pcall(function() d:Activate() end)
                            if typeof(firesignal) == "function" then pcall(function() firesignal(d.MouseButton1Click) end) end
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end
function AF_IsInMatch()
    local char = Player.Character; if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health <= 0 then return false end
    local r = GetRole(); return r == "Killer" or r == "Survivor"
end
RegToggle(Tabs.AutoFarm, "Auto Farm", "Enable auto farm", false, "AF_Enabled")
RegDropdown(Tabs.AutoFarm, "Mode", "Farm mode", {"Auto","Survivor","Killer"}, "Auto", false, "AF_Mode")
RegToggle(Tabs.AutoFarm, "Auto Ready / Join", "Auto ready/join", true, "AF_AutoReady")
RegToggle(Tabs.AutoFarm, "Auto Requeue", "Auto requeue", true, "AF_AutoRequeue")
RegToggle(Tabs.AutoFarm, "Instant Exit Gate", "Instant escape", true, "AF_AutoEscapeNow")
RegToggle(Tabs.AutoFarm, "Auto Heal Self", "Auto heal self", true, "AF_AutoHeal")
RegToggle(Tabs.AutoFarm, "Killer: Auto Attack", "Auto attack as killer", true, "AF_AutoAttack")
RegToggle(Tabs.AutoFarm, "Killer: Auto Hook", "Auto hook as killer", true, "AF_AutoHook")
RegButton(Tabs.AutoFarm, "Status Auto Farm", "Show auto farm status", function()
    local mins = math.floor((tick() - VD.AF_StartTime) / 60)
    local mode = VD.SH_RandomHop and "RANDOM" or "BEST"
    local visitedCount = 0
    for _ in pairs(VD.SH_VisitedServers) do visitedCount = visitedCount + 1 end
    notify("Auto Farm Status", string.format("%s\n%d menit | %d match | Hop: %d\nMode: %s | History: %d server", VD.AF_Status, mins, VD.AF_MatchesPlayed, VD.SH_HopCount, mode, visitedCount), 5)
end)
task.spawn(function()
    VD.AF_StartTime = tick()
    while not VD.Destroyed do
        task.wait(0.3)
        if not VD.AF_Enabled then VD.AF_Status = "Idle"
        else
            local role = GetRole(); local prevRole = VD.SH_LastRole
            if (prevRole == "Killer" or prevRole == "Survivor") and (role == "Lobby" or role == "Unknown") then
                VD.AF_MatchesPlayed = VD.AF_MatchesPlayed + 1; VD.SH_LobbyEnterTime = tick()
                notify("Auto Farm", "Match selesai! Total: " .. VD.AF_MatchesPlayed, 3)
                if VD.SH_Enabled and VD.SH_HopAfterMatch then VD_SH_Hop("Match selesai"); task.wait(5) end
            end
            VD.SH_LastRole = role
            if role == "Lobby" or role == "Unknown" then
                if VD.SH_LobbyEnterTime == 0 then VD.SH_LobbyEnterTime = tick() end
                local lobbyTime = tick() - VD.SH_LobbyEnterTime
                VD.AF_Status = string.format("Lobby - %ds / %ds", math.floor(lobbyTime), VD.SH_WaitingTimeout)
                if VD.AF_AutoReady then pcall(AF_ClickLobbyButton) end
                if VD.SH_Enabled and lobbyTime > (VD.SH_WaitingTimeout or 60) then
                    if tick() - VD.SH_LastHopTime > (VD.SH_HopCooldown or 15) then VD.SH_LobbyEnterTime = 0; VD_SH_Hop("Lobby timeout"); task.wait(5) end
                end
                task.wait(0.7)
            else
                if role == "Killer" or role == "Survivor" then VD.SH_LobbyEnterTime = 0 end
                if role == "Survivor" then
                    local char = Player.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if not hum or hum.Health <= 0 then VD.AF_Status = "Mati - Menunggu respawn"; task.wait(2)
                    else
                        if VD.AF_AutoHeal and hum.Health < hum.MaxHealth * 0.9 then pcall(function() GetRemotes().Healing.HealEvent:FireServer(root, true) end) end
                        if hum.WalkSpeed < 16 and hum.WalkSpeed > 0 then hum.WalkSpeed = 16 end
                        if VD.AF_AutoEscapeNow then
                            VD.AF_Status = "Auto Exit Gate"
                            if tick() - VD.AF_LastEscapeTry > VD.AF_EscapeCooldown then VD.AF_LastEscapeTry = tick(); pcall(VD_DoEscape) end
                            task.wait(1)
                        end
                    end
                end
                if role == "Killer" then
                    local char = Player.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if not hum or hum.Health <= 0 or not root then VD.AF_Status = "Menunggu spawn Killer"; task.wait(2)
                    else
                        VD.AF_Status = "Killer Mode"
                        if VD.AF_AutoAttack then VD.KillerAutoAttack = true end
                        -- Auto Hook is handled by the single centralized engine above.
                        -- This prevents Auto Farm and Killer Tools from firing hook remotes twice.
                        local target, td = nil, math.huge
                            for _, p in ipairs(MawwwGetPlayers()) do
                                if p ~= Player and IsSurvivor(p) and p.Character then
                                    local tr = p.Character:FindFirstChild("HumanoidRootPart")
                                    local th = p.Character:FindFirstChildOfClass("Humanoid")
                                    if tr and th and th.Health > 0 then local d = (tr.Position - root.Position).Magnitude; if d < td then td = d; target = tr end end
                                end
                            end
                        if target then
                            if td > 20 then root.CFrame = CFrame.new(target.Position + Vector3.new(0, 2, 0)) end
                            pcall(function()
                                local ba = GetRemotes().Attacks:FindFirstChild("BasicAttack")
                                if ba then ba:FireServer(false) end
                            end)
                        end
                    end
                end
            end
        end
    end
end)
task.spawn(function()
    while not VD.Destroyed do
        task.wait(3)
        if VD.AF_Enabled and VD.AF_AutoRequeue and not VD.SH_Enabled then
            if not AF_IsInMatch() then pcall(AF_ClickLobbyButton) end
        end
    end
end)

--========================================================--
--========================================================--
-- SYNC: AUTO FARM GENERATOR (latest source adapter)
-- Source: autofarmgen.lua.txt
-- UI is adapted into the existing Auto Farm tab to avoid a duplicate ScreenGui.
--========================================================--
do
    local Config = {
        Enabled = VD.AFG_Enabled == true,
        Mode = VD.AFG_Mode or "SUCCESS",
        AutoTP = VD.AFG_AutoTP ~= false,
        AutoRepair = VD.AFG_AutoRepair ~= false,
        AutoSkill = VD.AFG_AutoSkill ~= false,
        TPDelay = tonumber(VD.AFG_TPDelay) or 0.35,
        LoopDelay = tonumber(VD.AFG_LoopDelay) or 0.8,
        FleeOnKiller = VD.AFG_FleeOnKiller ~= false,
        FleeDistance = tonumber(VD.AFG_FleeDistance) or 28,
        REPAIR_RADIUS = tonumber(VD.AFG_RepairRadius) or 10,
        SUCCESS_MIN = 102,
        SUCCESS_MAX = 116,
        NEUTRAL_MIN = 116,
        NEUTRAL_MAX = 159,
        TriggerDelay = tonumber(VD.AFG_TriggerDelay) or 0.035,
        LOCK_TIME = 30,
        COOLDOWN_FLEE = 20,
        COOLDOWN_OOR = 8,
        COOLDOWN_ABORT = 5,
    }

    local State = {
        Busy = false,
        LastTrigger = 0,
        CurrentGen = nil,
        Done = {},
        FarmThread = nil,
        Status = "Idle",
        Abort = false,
        SkipGen = nil,
        SkipUntil = 0,
        StopToken = 0,
        Running = false,
        LockedGen = nil,
        LockedUntil = 0,
        Cooldown = {},
    }

    local Check, Line, Goal, Action

    local function syncFlags()
        VD.AFG_Enabled = Config.Enabled
        VD.AFG_Mode = Config.Mode
        VD.AFG_AutoTP = Config.AutoTP
        VD.AFG_AutoRepair = Config.AutoRepair
        VD.AFG_AutoSkill = Config.AutoSkill
        VD.AFG_TPDelay = Config.TPDelay
        VD.AFG_LoopDelay = Config.LoopDelay
        VD.AFG_FleeOnKiller = Config.FleeOnKiller
        VD.AFG_FleeDistance = Config.FleeDistance
        VD.AFG_RepairRadius = Config.REPAIR_RADIUS
        VD.AFG_TriggerDelay = Config.TriggerDelay
    end

    local function RefreshSkillRefs()
        pcall(function()
            local skillGui = PlayerGui:FindFirstChild("SkillCheckPromptGui")
            if skillGui then
                Check = skillGui:FindFirstChild("Check")
                if Check then
                    Line = Check:FindFirstChild("Line")
                    Goal = Check:FindFirstChild("Goal")
                    Action = Check:FindFirstChild("Action")
                        or Check:FindFirstChild("Button")
                end
            end
        end)
    end

    local function TriggerAction()
        if not Config.Enabled or not State.Running then return end

        local now = tick()
        if now - State.LastTrigger < Config.TriggerDelay then return end
        State.LastTrigger = now

        pcall(function()
            if Action and Action:IsA("GuiButton") then
                if typeof(firesignal) == "function" then
                    pcall(function() firesignal(Action.MouseButton1Down) end)
                    pcall(function() firesignal(Action.MouseButton1Up) end)
                    pcall(function() firesignal(Action.MouseButton1Click) end)
                end
                pcall(function() Action:Activate() end)
            end

            local vim
            pcall(function()
                vim = game:GetService("VirtualInputManager")
            end)

            if vim then
                vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                task.wait(0.01)
                vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            end
        end)
    end

    local function IsSuccess()
        if not Line or not Goal then return false end
        local goalRotation = tonumber(Goal.Rotation) or 0
        local lineRotation = tonumber(Line.Rotation) or 0
        return lineRotation >= goalRotation + Config.SUCCESS_MIN
            and lineRotation <= goalRotation + Config.SUCCESS_MAX
    end

    local function IsNeutral()
        if not Line or not Goal then return false end
        local goalRotation = tonumber(Goal.Rotation) or 0
        local lineRotation = tonumber(Line.Rotation) or 0
        return lineRotation >= goalRotation + Config.NEUTRAL_MIN
            and lineRotation <= goalRotation + Config.NEUTRAL_MAX
    end

    local function InstantHit()
        for _ = 1, 8 do
            if not Config.Enabled or not State.Running then return end
            TriggerAction()
            task.wait(0.02)
        end
    end

    -- Define before the RenderStepped connection: avoids the source's forward-reference issue.
    local function GetPoints(genModel)
        local points = {}
        if not genModel then return points end

        for _, obj in ipairs(genModel:GetChildren()) do
            if obj.Name:find("GeneratorPoint", 1, true)
                and obj:IsA("BasePart") then
                table.insert(points, obj)
            end
        end

        return points
    end

    local function GetGenerators()
        local list = {}
        local map = Workspace:FindFirstChild("Map")
        if not map then return list end

        for _, v in ipairs(map:GetDescendants()) do
            if v:IsA("Model") and v.Name == "Generator" then
                local progress =
                    tonumber(v:GetAttribute("RepairProgress"))
                    or tonumber(v:GetAttribute("ProgressRepair"))
                    or 0

                if progress < 100 then
                    table.insert(list, {
                        Model = v,
                        Progress = progress,
                    })
                end
            end
        end

        table.sort(list, function(a, b)
            return a.Progress > b.Progress
        end)

        return list
    end

    local function GetNearestPoint(genModel, hrp)
        local best, bestDistance = nil, math.huge
        for _, point in ipairs(GetPoints(genModel)) do
            local distance = (point.Position - hrp.Position).Magnitude
            if distance < bestDistance then
                bestDistance = distance
                best = point
            end
        end
        return best, bestDistance
    end

    local function GetRepairEvent()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local generator = remotes and remotes:FindFirstChild("Generator")
        local event = generator and generator:FindFirstChild("RepairEvent")
        return event and event:IsA("RemoteEvent") and event or nil
    end

    local function IsKiller(plr)
        local team = plr.Team and plr.Team.Name or ""
        return team:lower():find("killer", 1, true) ~= nil
    end

    local function GetNearestKillerDist(hrp)
        local best = math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and IsKiller(plr) and plr.Character then
                local root = plr.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local distance = (root.Position - hrp.Position).Magnitude
                    if distance < best then
                        best = distance
                    end
                end
            end
        end
        return best
    end

    local function PickSafeGen(currentGen, hrp)
        local gens = GetGenerators()
        local best, bestScore = nil, -math.huge

        for _, data in ipairs(gens) do
            local model = data.Model
            local cooldownUntil = State.Cooldown[model] or 0

            if model ~= currentGen
                and not State.Done[model]
                and tick() > cooldownUntil then

                local points = GetPoints(model)
                local pos = points[1] and points[1].Position

                if not pos then
                    local primary = model.PrimaryPart
                        or model:FindFirstChildWhichIsA("BasePart", true)
                    pos = primary and primary.Position
                end

                if pos then
                    local killerDistance = math.huge

                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr ~= LocalPlayer
                            and IsKiller(plr)
                            and plr.Character then

                            local root = plr.Character:FindFirstChild("HumanoidRootPart")
                            if root then
                                local distance = (root.Position - pos).Magnitude
                                if distance < killerDistance then
                                    killerDistance = distance
                                end
                            end
                        end
                    end

                    local score = killerDistance - (data.Progress or 0) * 0.05
                    if score > bestScore then
                        bestScore = score
                        best = model
                    end
                end
            end
        end

        return best
    end

    local function TPTo(cf)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end

        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = cf + Vector3.new(0, 2, 0)
        end)

        return true
    end

    local function ReleaseGen(genModel)
        if not genModel then return end
        local event = GetRepairEvent()
        if not event then return end

        for _, point in ipairs(GetPoints(genModel)) do
            pcall(function()
                event:FireServer(point, false)
            end)
        end
    end

    local function DoRepair(genModel, myToken)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end

        local points = GetPoints(genModel)
        if #points == 0 then return false end

        local event = GetRepairEvent()
        local nearest = GetNearestPoint(genModel, hrp)
        local point = nearest or points[1]

        if Config.AutoTP then
            TPTo(point.CFrame)
            task.wait(Config.TPDelay)
        end

        -- Source logic preserved, with AutoRepair made effective.
        if Config.AutoRepair then
            for _, repairPoint in ipairs(points) do
                pcall(function()
                    if event then event:FireServer(repairPoint, true) end
                end)
                task.wait(0.05)
            end
        end

        local start = tick()

        while tick() - start < 18 do
            if not Config.Enabled
                or not State.Running
                or State.StopToken ~= myToken then

                pcall(function()
                    if event then event:FireServer(point, false) end
                end)
                return "stop"
            end

            local currentRoot = LocalPlayer.Character
                and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

            local distance = math.huge
            if currentRoot then
                distance = (currentRoot.Position - point.Position).Magnitude
            end

            if distance > Config.REPAIR_RADIUS then
                pcall(function()
                    if event then event:FireServer(point, false) end
                end)
                State.Status = string.format(
                    "Out of range (%.0f) — stop gen", distance
                )
                return "outofrange"
            end

            local progress =
                tonumber(genModel:GetAttribute("RepairProgress"))
                or tonumber(genModel:GetAttribute("ProgressRepair"))
                or 0

            State.Status = string.format(
                "Repair %.0f%% (%.0f studs)", progress, distance
            )

            if progress >= 100 then
                State.Done[genModel] = true
                State.Cooldown[genModel] = nil

                if State.LockedGen == genModel then
                    State.LockedGen = nil
                    State.LockedUntil = 0
                end

                pcall(function()
                    if event then event:FireServer(point, false) end
                end)

                return true
            end

            if State.Abort
                or State.CurrentGen == nil
                or (State.SkipGen and State.SkipGen == genModel) then
                pcall(function()
                    if event then event:FireServer(point, false) end
                end)
                State.Status = "Aborted old gen"
                return "abort"
            end

            local activeRoot = LocalPlayer.Character
                and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

            if Config.FleeOnKiller and activeRoot and activeRoot.Parent then
                local killerDistance = GetNearestKillerDist(activeRoot)

                if killerDistance <= Config.FleeDistance then
                    State.Status = string.format(
                        "Killer %.0f studs — flee", killerDistance
                    )

                    pcall(function()
                        if event then event:FireServer(point, false) end
                    end)

                    State.Cooldown[genModel] =
                        tick() + Config.COOLDOWN_FLEE

                    State.Abort = true
                    task.wait(0.05)

                    local safe = PickSafeGen(genModel, activeRoot)
                    if safe then
                        State.Status = "TP other gen"
                        State.CurrentGen = safe
                        State.LockedGen = safe
                        State.LockedUntil = tick() + Config.LOCK_TIME
                        State.Abort = false

                        local safePoints = GetPoints(safe)
                        if Config.AutoTP and safePoints[1] then
                            TPTo(safePoints[1].CFrame)
                            task.wait(Config.TPDelay)
                        end

                        return "flee"
                    end

                    local away = activeRoot.CFrame.Position
                        + Vector3.new(
                            math.random(-20, 20),
                            0,
                            math.random(-20, 20)
                        )

                    TPTo(CFrame.new(away + Vector3.new(0, 3, 0)))
                    task.wait(0.4)
                    return "flee"
                end
            end

            if Config.AutoTP and currentRoot and currentRoot.Parent then
                local repairDistance =
                    (currentRoot.Position - point.Position).Magnitude

                if repairDistance > 5
                    and repairDistance <= Config.REPAIR_RADIUS then
                    TPTo(point.CFrame)
                end
            end

            if Config.AutoRepair
                and event
                and (tick() - start) % 1 < 0.3 then

                pcall(function()
                    event:FireServer(point, true)
                end)
            end

            task.wait(0.2)
        end

        pcall(function()
            if event then event:FireServer(point, false) end
        end)

        return false
    end

    local function FarmLoop(myToken)
        while Config.Enabled
            and State.Running
            and State.StopToken == myToken do

            State.Status = "Scanning gens..."

            if State.LockedGen and tick() >= State.LockedUntil then
                State.LockedGen = nil
                State.LockedUntil = 0
            end

            if State.LockedGen and State.Done[State.LockedGen] then
                State.LockedGen = nil
                State.LockedUntil = 0
            end

            if State.SkipGen and tick() > State.SkipUntil then
                State.SkipGen = nil
                State.SkipUntil = 0
            end

            local gens = GetGenerators()
            local target = nil

            if State.LockedGen
                and not State.Done[State.LockedGen]
                and tick() < State.LockedUntil then

                target = State.LockedGen
            end

            if not target then
                for _, data in ipairs(gens) do
                    local cooldownUntil = State.Cooldown[data.Model] or 0
                    if not State.Done[data.Model]
                        and tick() > cooldownUntil then
                        target = data.Model
                        break
                    end
                end
            end

            if not target then
                local bestGen, bestCooldown = nil, math.huge

                for _, data in ipairs(gens) do
                    if not State.Done[data.Model] then
                        local cooldownUntil =
                            State.Cooldown[data.Model] or 0

                        if cooldownUntil < bestCooldown then
                            bestCooldown = cooldownUntil
                            bestGen = data.Model
                        end
                    end
                end

                if bestGen then
                    target = bestGen
                    State.Cooldown[bestGen] = nil
                    State.LockedGen = bestGen
                    State.LockedUntil = tick() + Config.LOCK_TIME
                    State.Status = "All on cooldown — retry oldest"
                end
            end

            if not target then
                if #gens == 0 then
                    State.Status = "No gens"
                else
                    State.Status = "All gens done"
                    State.Done = {}
                end
                task.wait(1.5)
            else
                State.CurrentGen = target
                State.Abort = false
                State.Status = "Farming gen..."

                local ok, result = pcall(function()
                    return DoRepair(target, myToken)
                end)

                if result == "flee" then
                    State.Status = "Flee → other gen"
                    State.Abort = false
                    task.wait(0.3)
                elseif result == "abort" then
                    State.Status = "Aborted"
                    State.Cooldown[target] =
                        tick() + Config.COOLDOWN_ABORT

                    if State.LockedGen == target then
                        State.LockedGen = nil
                        State.LockedUntil = 0
                    end

                    State.Abort = false
                    task.wait(0.2)
                elseif result == "outofrange" then
                    State.Status = "Out of range — skip"
                    State.Cooldown[target] =
                        tick() + Config.COOLDOWN_OOR

                    if State.LockedGen == target then
                        State.LockedGen = nil
                        State.LockedUntil = 0
                    end

                    State.Abort = false
                    task.wait(0.4)
                elseif result == "stop" then
                    break
                elseif not ok then
                    State.Status = "Generator error — retry"
                    State.Cooldown[target] =
                        tick() + Config.COOLDOWN_ABORT
                    task.wait(0.2)
                end

                task.wait(Config.LoopDelay)
            end

            task.wait(0.1)
        end

        if State.StopToken == myToken then
            State.Status = "Idle"
            State.CurrentGen = nil
        end
    end

    local function ReleaseCurrentGen()
        if State.CurrentGen then
            ReleaseGen(State.CurrentGen)
        end
    end

    local function setEnabled(on)
        on = on == true

        if on then
            Config.Enabled = true
            State.StopToken = State.StopToken + 1
            local myToken = State.StopToken

            State.Running = true
            State.Done = {}
            State.SkipGen = nil
            State.SkipUntil = 0
            State.Abort = false
            State.Busy = false
            State.LockedGen = nil
            State.LockedUntil = 0
            State.Cooldown = {}
            State.Status = "Starting..."

            RefreshSkillRefs()
            syncFlags()

            State.FarmThread = task.spawn(function()
                FarmLoop(myToken)
                if State.StopToken == myToken then
                    State.FarmThread = nil
                end
            end)

            print("[GEN FARM SOURCE] ON")
        else
            Config.Enabled = false
            State.StopToken = State.StopToken + 1
            State.Running = false
            State.Abort = true

            ReleaseCurrentGen()

            State.CurrentGen = nil
            State.SkipGen = nil
            State.SkipUntil = 0
            State.Busy = false
            State.FarmThread = nil
            State.LockedGen = nil
            State.LockedUntil = 0
            State.Cooldown = {}
            State.Status = "Stopped"

            syncFlags()

            print("[GEN FARM SOURCE] OFF")
        end
    end

    RunService.RenderStepped:Connect(function()
        if not Config.Enabled or not State.Running or not Config.AutoSkill then return end

        if not Check then
            RefreshSkillRefs()
        end

        if not Check or not Check.Visible then return end
        if State.Busy then return end

        if State.CurrentGen then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local pts = State.CurrentGen and GetPoints(State.CurrentGen) or {}

            if hrp and pts[1] then
                local distance = (hrp.Position - pts[1].Position).Magnitude
                if distance > Config.REPAIR_RADIUS + 2 then return end
            end
        end

        if Config.Mode == "INSTANT" then
            State.Busy = true
            InstantHit()
            task.delay(0.1, function()
                State.Busy = false
            end)
            return
        end

        local shouldTrigger = false

        if Config.Mode == "SUCCESS" then
            shouldTrigger = IsSuccess()
        elseif Config.Mode == "NEUTRAL" then
            shouldTrigger = IsNeutral()
        end

        if shouldTrigger then
            State.Busy = true
            TriggerAction()
            task.delay(0.07, function()
                State.Busy = false
            end)
        end
    end)

    LocalPlayer.CharacterAdded:Connect(function()
        Check, Line, Goal, Action = nil, nil, nil, nil
        task.wait(0.5)
        if Config.Enabled then
            RefreshSkillRefs()
        end
    end)

    getgenv().MAWWW_AutoFarmGenerator = {
        SetEnabled = setEnabled,
        GetStatus = function() return State.Status end,
        Config = Config,
        State = State,
        Destroy = function()
            setEnabled(false)
        end,
    }

    RegDivider(Tabs.AutoFarm)
    RegLabel(Tabs.AutoFarm, "Auto Farm Generator • Source")

    RegToggle(Tabs.AutoFarm, "Auto Farm • Generator", "Use the supplied generator farming logic.", Config.Enabled, "AFG_Enabled", function(v)
        setEnabled(v)
    end)

    RegDropdown(Tabs.AutoFarm, "Generator Skillcheck Mode", "SUCCESS / NEUTRAL / INSTANT.", {"SUCCESS", "NEUTRAL", "INSTANT"}, Config.Mode, false, "AFG_Mode", function(v)
        if v == "SUCCESS" or v == "NEUTRAL" or v == "INSTANT" then
            Config.Mode = v
            syncFlags()
        end
    end)

    RegToggle(Tabs.AutoFarm, "Generator • Auto TP", "Teleport to the selected generator point.", Config.AutoTP, "AFG_AutoTP", function(v)
        Config.AutoTP = v == true
        syncFlags()
    end)

    RegToggle(Tabs.AutoFarm, "Generator • Auto Repair", "Fire the generator repair remote.", Config.AutoRepair, "AFG_AutoRepair", function(v)
        Config.AutoRepair = v == true
        syncFlags()
    end)

    RegToggle(Tabs.AutoFarm, "Generator • Auto Skillcheck", "Automatically trigger the skillcheck.", Config.AutoSkill, "AFG_AutoSkill", function(v)
        Config.AutoSkill = v == true
        syncFlags()
    end)

    RegToggle(Tabs.AutoFarm, "Generator • Flee Killer", "Leave the current generator when a killer is close.", Config.FleeOnKiller, "AFG_FleeOnKiller", function(v)
        Config.FleeOnKiller = v == true
        syncFlags()
    end)

    RegSlider(Tabs.AutoFarm, "Generator Flee Distance", "Killer distance that triggers a flee.", Config.FleeDistance, 5, 80, 1, "AFG_FleeDistance", function(v)
        Config.FleeDistance = tonumber(v) or 28
        syncFlags()
    end)

    RegSlider(Tabs.AutoFarm, "Generator Repair Radius", "Allowed distance from the repair point.", Config.REPAIR_RADIUS, 4, 30, 1, "AFG_RepairRadius", function(v)
        Config.REPAIR_RADIUS = tonumber(v) or 10
        syncFlags()
    end)

    RegButton(Tabs.AutoFarm, "Generator Farm Status", "Show current generator farm status.", function()
        notify("Auto Farm Generator", tostring(State.Status or "Idle"), 3)
    end)
end

-- QUICK TOGGLE FLOATING UI (UPDATED: +Bypass Skill button)
--========================================================--
QuickToggleUI = (function()
    local QUICK_GUI_NAME = "MawwwHub_QuickToggle"
    local DRAG_THRESHOLD = 4; local BUTTON_SIZE = 68; local LOCK_SIZE = 24; local MARGIN = 8
    local State = { Gui = nil, Buttons = {}, Locks = {}, Strokes = {}, LabelObjects = {}, Connections = {}, ButtonConnections = {}, Rebuilding = false, LastEnsure = 0 }
    local function disconnectBucket(bucket) for _, c in ipairs(bucket) do pcall(function() c:Disconnect() end) end; table.clear(bucket) end
    local function disconnectAll() disconnectBucket(State.Connections); disconnectBucket(State.ButtonConnections) end
    local function connect(signal, fn, isButtonConnection)
        local ok, conn = pcall(function() return signal:Connect(fn) end)
        if ok and conn then table.insert(isButtonConnection and State.ButtonConnections or State.Connections, conn) end
        return conn
    end
    local function getSavedPos(vdKey, fallback) local pos = VD[vdKey]; if typeof(pos) == "UDim2" then return pos end; return fallback end
    local function savePos(vdKey, pos) if typeof(pos) == "UDim2" then VD[vdKey] = pos end end
    local function ensureGui()
        if VD.Destroyed then return nil end
        local current = PlayerGui and PlayerGui:FindFirstChild(QUICK_GUI_NAME)
        if current and current:IsA("ScreenGui") then
            State.Gui = current; current.ResetOnSpawn = false; current.IgnoreGuiInset = true; current.DisplayOrder = 999; return current
        end
        local gui = Instance.new("ScreenGui")
        gui.Name = QUICK_GUI_NAME; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 999; gui.Parent = PlayerGui
        State.Gui = gui; return gui
    end
    local function applyButtonVisual(btn, stroke, enabled, label)
        if not btn or not btn.Parent then return end
        if enabled then
            btn.BackgroundColor3 = Color3.fromRGB(120, 45, 200)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            stroke.Color = Color3.fromRGB(220, 130, 255); stroke.Transparency = 0
        else
            btn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
            btn.TextColor3 = Color3.fromRGB(200, 200, 200)
            stroke.Color = Color3.fromRGB(120, 120, 140); stroke.Transparency = 0
        end
        if label then label.TextColor3 = btn.TextColor3 end
    end
    local function applyLockVisual(lockBtn, locked)
        if not lockBtn or not lockBtn.Parent then return end
        lockBtn.Text = locked and "🔒" or "🔓"
        lockBtn.BackgroundColor3 = locked and Color3.fromRGB(150, 45, 45) or Color3.fromRGB(45, 45, 55)
        lockBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
    local function createLockButton(parent, vdLockKey, tooltip)
        local lock = Instance.new("TextButton")
        lock.Name = "Lock"; lock.Size = UDim2.new(0, LOCK_SIZE, 0, LOCK_SIZE)
        lock.Position = UDim2.new(1, -(LOCK_SIZE + 3), 0, 3); lock.AnchorPoint = Vector2.new(0, 0)
        lock.BackgroundColor3 = Color3.fromRGB(45, 45, 55); lock.BackgroundTransparency = 0.05
        lock.BorderSizePixel = 0; lock.AutoButtonColor = false; lock.Text = "🔓"; lock.TextSize = 13; lock.Font = Enum.Font.GothamBold; lock.ZIndex = 20; lock.Parent = parent
        Instance.new("UICorner", lock).CornerRadius = UDim.new(1, 0)
        local ls = Instance.new("UIStroke", lock); ls.Thickness = 1.5; ls.Color = Color3.fromRGB(150, 150, 165); ls.Transparency = 0.15
        lock.MouseButton1Click:Connect(function()
            VD[vdLockKey] = not (VD[vdLockKey] == true)
            applyLockVisual(lock, VD[vdLockKey] == true)
            if tooltip then notify(tooltip, VD[vdLockKey] and "LOCKED" or "UNLOCKED", 2) end
        end)
        applyLockVisual(lock, VD[vdLockKey] == true); return lock
    end
    local function createButton(spec)
        local gui = ensureGui(); if not gui then return nil end
        local old = gui:FindFirstChild(spec.name); if old then old:Destroy() end
        local btn = Instance.new("TextButton")
        btn.Name = spec.name; btn.Size = UDim2.new(0, BUTTON_SIZE, 0, BUTTON_SIZE)
        btn.Position = getSavedPos(spec.posKey, spec.defaultPos)
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 75); btn.BorderSizePixel = 0
        btn.Text = spec.label .. "\n[" .. spec.keyLetter .. "]"; btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        btn.Font = Enum.Font.GothamBold; btn.TextSize = 11; btn.AutoButtonColor = false; btn.Visible = false; btn.ZIndex = 10; btn.Parent = gui
        Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
        local stroke = Instance.new("UIStroke", btn); stroke.Thickness = 2; stroke.Color = Color3.fromRGB(120, 120, 140); stroke.Transparency = 0
        if spec.iconId then
            local iconFrame = Instance.new("Frame")
            iconFrame.Name = "IconFrame"; iconFrame.Size = UDim2.new(1, -8, 0, 22); iconFrame.Position = UDim2.new(0, 4, 0, 4)
            iconFrame.BackgroundTransparency = 1; iconFrame.ZIndex = 12; iconFrame.Parent = btn
            local img = Instance.new("ImageLabel")
            img.Name = "IconImage"; img.Size = UDim2.new(0, 22, 0, 22); img.Position = UDim2.new(0.5, 0, 0.5, 0)
            img.AnchorPoint = Vector2.new(0.5, 0.5); img.BackgroundTransparency = 1
            img.Image = "rbxassetid://" .. tostring(spec.iconId); img.ScaleType = Enum.ScaleType.Fit; img.ZIndex = 13; img.Parent = iconFrame
        end
        local label = Instance.new("TextLabel")
        label.Name = "MainLabel"; label.Size = UDim2.new(1, -8, 1, -8); label.Position = UDim2.new(0, 4, 0, 4)
        label.BackgroundTransparency = 1; label.Text = spec.label .. "\n[" .. spec.keyLetter .. "]"
        label.TextColor3 = btn.TextColor3; label.Font = Enum.Font.GothamBold; label.TextSize = 11; label.TextWrapped = true; label.ZIndex = 11; label.Parent = btn
        local lock = createLockButton(btn, spec.lockKey, spec.lockTitle)
        local drag = { active = false, moved = false, skipClick = false, startMouse = nil, startPos = nil }
        lock.MouseButton1Down:Connect(function() drag.skipClick = true end)
        btn.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            if VD[spec.lockKey] == true then return end
            drag.active = true; drag.moved = false; drag.startMouse = input.Position; drag.startPos = btn.Position
        end)
        connect(UserInputService.InputChanged, function(input)
            if not drag.active then return end
            if VD[spec.lockKey] == true then drag.active = false; return end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position - drag.startMouse
                if math.abs(delta.X) > DRAG_THRESHOLD or math.abs(delta.Y) > DRAG_THRESHOLD then drag.moved = true end
                btn.Position = UDim2.new(drag.startPos.X.Scale, drag.startPos.X.Offset + delta.X, drag.startPos.Y.Scale, drag.startPos.Y.Offset + delta.Y)
            end
        end, true)
        connect(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if drag.active then savePos(spec.posKey, btn.Position) end
                task.delay(0.05, function() drag.active = false; drag.moved = false end)
            end
        end, true)
        btn.MouseButton1Click:Connect(function()
            if drag.skipClick then drag.skipClick = false; return end
            if drag.moved then return end
            spec.onClick()
        end)
        btn.AncestryChanged:Connect(function(_, parent)
            if VD.Destroyed then return end
            if not parent then task.defer(function() if not VD.Destroyed then State.LastEnsure = 0 end end) end
        end)
        State.Buttons[spec.id] = btn; State.Locks[spec.id] = lock; State.Strokes[spec.id] = stroke; State.LabelObjects[spec.id] = label
        return btn
    end

    -- ═══ Specs: 4 quick toggle buttons ═══
    local Specs = {
        {
            id = "Moonwalk", name = "MoonwalkBtn", label = "MOON\nWALK", keyLetter = "M",
            posKey = "QuickMoonwalkPosition", lockKey = "LockMoonwalkIcon", lockTitle = "Moonwalk Lock",
            defaultPos = UDim2.new(0, 12, 0, 260), showKey = "ShowMoonwalkIcon", activeKey = "Moonwalk",
            onClick = function()
                VD.Moonwalk = not VD.Moonwalk
                if VD.Moonwalk then
                    if getgenv().MAWWW_StartMoonwalk then getgenv().MAWWW_StartMoonwalk() end
                    notify("Moonwalk", "ON", 2)
                else
                    local h = getHum(); if h then h.AutoRotate = true; h.WalkSpeed = 16 end
                    notify("Moonwalk", "OFF", 2)
                end
            end,
        },
        {
            id = "GenBoss", name = "GenBoostBtn", label = "GEN\nBOOST", keyLetter = "G",
            posKey = "QuickGenBossPosition", lockKey = "LockGenBossIcon", lockTitle = "Gen Boss Lock",
            defaultPos = UDim2.new(0, 12, 0, 340), showKey = "ShowGenBossIcon", activeKey = "GenBoost",
            onClick = function()
                if getgenv().MAWWW and getgenv().MAWWW.setGenBypass then getgenv().MAWWW.setGenBypass(not VD.GenBoost)
                else VD.GenBoost = not VD.GenBoost end
                notify("Gen Boost", VD.GenBoost and "ON — auto repair aktif" or "OFF", 2)
            end,
        },
        {
            id = "InfiniteMyers", name = "InfiniteMyersBtn", label = "INF\nMYERS", keyLetter = "I",
            iconId = ICON_ID, posKey = "QuickInfiniteMyersPosition", lockKey = "LockInfiniteMyersIcon",
            lockTitle = "Infinite Myers Lock", defaultPos = UDim2.new(0, 12, 0, 420),
            showKey = "ShowInfiniteMyersIcon", activeKey = "KillerInfGrab",
            onClick = function()
                VD.KillerInfGrab = not VD.KillerInfGrab
                if getgenv().MAWWW_QuickRefresh then pcall(getgenv().MAWWW_QuickRefresh) end
                notify("Infinite Myers", VD.KillerInfGrab and "ON — Infinite Grab aktif" or "OFF", 2)
            end,
        },
        -- ═══ [NEW] Bypass Skill quick toggle ═══
        {
            id = "BypassSkill", name = "BypassSkillBtn", label = "BYPASS\nSKILL", keyLetter = "B",
            posKey = "QuickBypassSkillPosition", lockKey = "LockBypassSkillIcon",
            lockTitle = "Bypass Skill Lock", defaultPos = UDim2.new(0, 12, 0, 500),
            showKey = "ShowBypassSkillIcon", activeKey = "KillerBypassSkill",
            onClick = function()
                local newVal = not VD.KillerBypassSkill
                if getgenv().MAWWW_SetAllKillerNoCooldown then
                    getgenv().MAWWW_SetAllKillerNoCooldown(newVal)
                else
                    VD.KillerBypassSkill = newVal
                end
                if getgenv().MAWWW_QuickRefresh then pcall(getgenv().MAWWW_QuickRefresh) end
                notify("Bypass Skill", newVal and "ON — All Killer Bypass aktif" or "OFF", 2)
            end,
        },
    }

    local function buildAll()
        if VD.Destroyed or State.Rebuilding then return end
        State.Rebuilding = true; disconnectBucket(State.ButtonConnections)
        local gui = ensureGui()
        if gui then
            State.Buttons = {}; State.Locks = {}; State.Strokes = {}; State.LabelObjects = {}
            for _, spec in ipairs(Specs) do createButton(spec) end
        end
        State.Rebuilding = false
    end
    local function refreshAll(forceBuild)
        if VD.Destroyed then return end
        local now = os.clock()
        local gui = PlayerGui and PlayerGui:FindFirstChild(QUICK_GUI_NAME)
        if forceBuild then State.LastEnsure = 0 end
        if not gui or not gui:IsA("ScreenGui")
            or not gui:FindFirstChild("MoonwalkBtn")
            or not gui:FindFirstChild("GenBoostBtn")
            or not gui:FindFirstChild("InfiniteMyersBtn")
            or not gui:FindFirstChild("BypassSkillBtn") then
            if now - State.LastEnsure > 0.1 then State.LastEnsure = now; buildAll() end
            gui = State.Gui
        else State.Gui = gui end
        if not gui then return end
        gui.Enabled = true; gui.DisplayOrder = 999
        for _, spec in ipairs(Specs) do
            local btn = State.Buttons[spec.id] or gui:FindFirstChild(spec.name)
            local lock = State.Locks[spec.id] or (btn and btn:FindFirstChild("Lock"))
            local stroke = State.Strokes[spec.id] or (btn and btn:FindFirstChildOfClass("UIStroke"))
            local label = State.LabelObjects[spec.id] or (btn and btn:FindFirstChild("MainLabel"))
            if btn and stroke then
                State.Buttons[spec.id] = btn; State.Locks[spec.id] = lock; State.Strokes[spec.id] = stroke; State.LabelObjects[spec.id] = label
                local visible = VD[spec.showKey] == true
                btn.Visible = visible
                if visible then
                    applyButtonVisual(btn, stroke, VD[spec.activeKey] == true, label)
                    if lock then applyLockVisual(lock, VD[spec.lockKey] == true) end
                end
            end
        end
    end
    buildAll(); refreshAll(true)
    connect(PlayerGui.ChildRemoved, function(child)
        if VD.Destroyed then return end
        if child.Name == QUICK_GUI_NAME then task.defer(function() if not VD.Destroyed then refreshAll(true) end end) end
    end)
    connect(Player.CharacterAdded, function() task.wait(0.35); if not VD.Destroyed then refreshAll(true) end end)
    connect(PlayerGui.DescendantRemoving, function(desc)
        if VD.Destroyed or State.Rebuilding then return end
        if desc.Name == "MoonwalkBtn" or desc.Name == "GenBoostBtn"
            or desc.Name == "InfiniteMyersBtn" or desc.Name == "BypassSkillBtn" then
            task.defer(function() if not VD.Destroyed then refreshAll(true) end end)
        end
    end)
    task.spawn(function() while not VD.Destroyed do task.wait(0.2); pcall(refreshAll, false) end end)
    getgenv().MAWWW_QuickRefresh = function() pcall(refreshAll, true) end
    return {
        Refresh = function() pcall(refreshAll, true) end,
        Destroy = function()
            disconnectAll()
            pcall(function() local g = PlayerGui and PlayerGui:FindFirstChild(QUICK_GUI_NAME); if g then g:Destroy() end end)
            State.Gui = nil; State.Buttons = {}; State.Locks = {}; State.Strokes = {}; State.LabelObjects = {}
        end,
    }
end)()

--========================================================--
-- UI SETTINGS TAB
-- Dedicated menu/config/keybind sections keep settings isolated.
--========================================================--
RegLabel(Tabs.UISettings, "Menu")
RegButton(Tabs.UISettings, "Test Notification", "Test notification system", function() notify("Mawww Hub", "Notification system works!", 4) end)
RegButton(Tabs.UISettings, "Print Current State", "Print current state to console", function()
    print("========================================")
    print("MAWWW HUB V2 — CURRENT STATE (Mawww / Obsidian UI)")
    print("========================================")
end)
RegButton(Tabs.UISettings, "Reset My Character (Emergency)", "Emergency character reset", function()
    pcall(function()
        VD.Noclip = false
        for part, cc in pairs(originalCanCollide) do if part and part.Parent then pcall(function() part.CanCollide = cc end) end end
        originalCanCollide = {}
        local hum = getHum()
        if hum then hum.WalkSpeed = 16; hum.AutoRotate = true; hum.CameraOffset = Vector3.new(0, 0, 0) end
        local cam = workspace.CurrentCamera
        if cam then cam.FieldOfView = 90 end
        notify("Emergency Reset", "Character di-reset.", 5)
    end)
end)
--========================================================--
-- MAWWW ADDITIVE PATCH: VAULT & FALL NO-SLOWDOWN+
-- Diambil dari deepseek patch, dirapikan dan dibuat reload-safe.
-- Tidak menggantikan Anti Fall Slowdown yang sudah ada.
--========================================================--

-- Bersihkan instance patch lama bila script dijalankan ulang.
pcall(function()
    local env = (getgenv and getgenv()) or _G
    local oldPatch = env and env.MAWWW_NoSlowPatch
    if oldPatch and type(oldPatch.Destroy) == "function" then
        oldPatch:Destroy()
    end
end)

NoSlowPatch = (function()
    local CFG = {
        VaultRadius = 8,
        RemoteCD = 0.30,
        MinFallDist = 8,
        MinFallTime = 0.20,
    }

    local ATTRS = {
        "Slow", "Slowed", "Slowdown", "VaultSlow", "VaultSlowdown", "VaultPenalty",
        "LandSlow", "LandingSlow", "LandingSlowdown", "FallSlow", "FallSlowdown",
        "LandingStun", "LandingRecovery", "MovementSlow", "MovementPenalty", "IsSlowed",
    }

    local REMOTES = {
        "CancelSlow", "ClearSlow", "RemoveSlow", "ResetSlow", "FallRecover",
        "LandRecover", "LandingRecover", "LandingCancel", "CancelStun", "ClearStun", "EndFall",
    }

    local FOLDERS = {
        "Player", "Movement", "Character", "PlayerActions",
        "Game", "Actions", "Status", "Effects",
    }

    local State = {
        LastRemote = 0,
        WasFalling = false,
        FallStart = 0,
        FallY = 0,
        VaultCD = 0,
        LandCD = 0,
        Hooked = {},
        AnimConnections = {},
        Connections = {},
        Destroyed = false,
        OldNamecall = nil,
        InstalledNamecall = nil,
        MetaTable = nil,
    }

    local function disconnect(connection)
        if connection then
            pcall(function() connection:Disconnect() end)
        end
    end

    local function isSurvivor()
        local team = Player and Player.Team
        local teamName = team and team.Name
        return type(teamName) == "string"
            and string.find(string.lower(teamName), "survivor", 1, true) ~= nil
    end

    local function clearCharacter(character)
        if not character then return end

        pcall(function()
            for _, attributeName in ipairs(ATTRS) do
                local value = character:GetAttribute(attributeName)
                if value ~= nil and value ~= false then
                    character:SetAttribute(attributeName, false)
                end
            end

            for _, child in ipairs(character:GetChildren()) do
                local childName = string.lower(child.Name)
                if childName:find("slow")
                    or childName:find("land")
                    or childName:find("fall")
                    or childName:find("stun") then

                    if child:IsA("BoolValue") and child.Value then
                        child.Value = false
                    elseif (child:IsA("NumberValue") or child:IsA("IntValue")) and child.Value > 0 then
                        child.Value = 0
                    end
                end
            end
        end)
    end

    local function fireRecoveryRemotes()
        local now = tick()
        if now - State.LastRemote < CFG.RemoteCD then
            return
        end

        State.LastRemote = now

        pcall(function()
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            if not remotes then return end

            for _, folderName in ipairs(FOLDERS) do
                local folder = remotes:FindFirstChild(folderName)
                if folder then
                    for _, remoteName in ipairs(REMOTES) do
                        local remote = folder:FindFirstChild(remoteName)
                        if remote and remote:IsA("RemoteEvent") then
                            pcall(function()
                                remote:FireServer()
                            end)
                        end
                    end
                end
            end

            for _, remoteName in ipairs(REMOTES) do
                local remote = remotes:FindFirstChild(remoteName)
                if remote and remote:IsA("RemoteEvent") then
                    pcall(function()
                        remote:FireServer()
                    end)
                end
            end
        end)
    end

    local function restoreHumanoid()
        local character = Player.Character
        if not character then return end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end

        pcall(function()
            if not VD.Speed and humanoid.WalkSpeed < 16 then
                humanoid.WalkSpeed = 16
            end

            local state = humanoid:GetState()
            if state == Enum.HumanoidStateType.FallingDown
                or state == Enum.HumanoidStateType.Ragdoll
                or state == Enum.HumanoidStateType.PlatformStanding then

                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end)
    end

    local function purge(reason)
        if State.Destroyed then return end

        local character = Player.Character
        if not character then return end

        clearCharacter(character)
        restoreHumanoid()
        fireRecoveryRemotes()

        if CFG.Debug then
            print("[NoSlowPatch]", tostring(reason))
        end
    end

    local function hookAnimator(character)
        if State.Destroyed or not character or State.Hooked[character] then
            return
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            return
        end

        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            return
        end

        State.Hooked[character] = true

        local animationConnection
        animationConnection = animator.AnimationPlayed:Connect(function(track)
            if State.Destroyed or not VD.NoSlowPatchEnabled or not isSurvivor() then
                return
            end

            local animationName = ""
            pcall(function()
                animationName = string.lower(track.Animation and track.Animation.Name or "")
            end)

            if animationName == "" then
                return
            end

            if animationName:find("vault")
                or animationName:find("window")
                or animationName:find("climb")
                or animationName:find("mantle")
                or animationName:find("slide") then

                task.delay(0.05, function()
                    purge("vault-anim")
                end)
            elseif animationName:find("fall")
                or animationName:find("land")
                or animationName:find("impact") then

                task.delay(0.02, function()
                    purge("fall-anim")
                end)
            end
        end)

        State.AnimConnections[character] = animationConnection

        pcall(function()
            character.AncestryChanged:Connect(function(_, parent)
                if parent then return end

                State.Hooked[character] = nil

                local connection = State.AnimConnections[character]
                State.AnimConnections[character] = nil
                disconnect(connection)
            end)
        end)
    end

    local heartbeatConnection = RunService.Heartbeat:Connect(function()
        if State.Destroyed or VD.Destroyed or not VD.NoSlowPatchEnabled then
            return
        end

        if not isSurvivor() then
            return
        end

        local character = Player.Character
        if not character then return end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")

        if not humanoid or not rootPart or humanoid.Health <= 0 then
            return
        end

        local now = tick()

        -- Fallback cleanup is deliberately kept lightweight and guarded by the toggle.
        clearCharacter(character)

        -- Fall detection.
        local humanoidState = humanoid:GetState()

        if humanoidState == Enum.HumanoidStateType.Freefall then
            if not State.WasFalling then
                State.WasFalling = true
                State.FallStart = now
                State.FallY = rootPart.Position.Y
            end
        elseif State.WasFalling then
            State.WasFalling = false

            local fallTime = now - State.FallStart
            local fallDistance = State.FallY - rootPart.Position.Y

            if fallTime >= CFG.MinFallTime
                and fallDistance >= CFG.MinFallDist
                and now - State.LandCD > 0.15 then

                State.LandCD = now

                task.delay(0.02, function()
                    purge("landed")
                end)

                task.delay(0.30, function()
                    purge("landed-follow")
                end)
            end
        end

        -- Vault proximity check, rate-limited to avoid unnecessary map scans.
        if now - State.VaultCD > 0.2
            and rootPart.AssemblyLinearVelocity.Magnitude > 1 then

            State.VaultCD = now

            pcall(function()
                local map = Workspace:FindFirstChild("Map") or Workspace
                local inspected = 0

                for _, object in ipairs(map:GetDescendants()) do
                    inspected = inspected + 1
                    if inspected > 200 then
                        break
                    end

                    if (object.Name == "VaultTrigger"
                        or object.Name == "VaultPoint"
                        or object.Name == "WindowVault")
                        and object:IsA("BasePart")
                        and (object.Position - rootPart.Position).Magnitude <= CFG.VaultRadius then

                        task.delay(0.05, function()
                            purge("vault-prox")
                        end)
                        break
                    end
                end
            end)
        end

        hookAnimator(character)
    end)

    table.insert(State.Connections, heartbeatConnection)

    local characterConnection = Player.CharacterAdded:Connect(function(character)
        if State.Destroyed then return end

        State.WasFalling = false
        State.FallStart = 0
        State.FallY = 0
        State.LandCD = 0
        State.VaultCD = 0

        task.delay(0.5, function()
            if not State.Destroyed then
                hookAnimator(character)
            end
        end)
    end)

    table.insert(State.Connections, characterConnection)

    -- Namecall hook: purge after the vault-related remotes fire.
    -- A strict environment check prevents hard errors on executors without the
    -- required metamethod helpers.
    if typeof(hookmetamethod) == "function"
        and type(newcclosure) == "function"
        and type(getnamecallmethod) == "function"
        and type(checkcaller) == "function"
        and type(getrawmetatable) == "function" then

        pcall(function()
            local metaTable = getrawmetatable(game)
            if not metaTable or not metaTable.__namecall then
                return
            end

            local oldNamecall = metaTable.__namecall
            if type(setreadonly) == "function" then
                setreadonly(metaTable, false)
            end

            local installedNamecall
            installedNamecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()

                if method == "FireServer" and not checkcaller() then
                    if VD.NoSlowPatchEnabled and isSurvivor() then
                        local ok, remoteName = pcall(function()
                            return tostring(self.Name)
                        end)

                        if ok and remoteName and (
                            remoteName == "VaultEvent"
                            or remoteName == "VaultCompleteEvent"
                            or remoteName == "VaultCompleteEventpart1"
                            or remoteName == "fastvault"
                            or remoteName == "PalletDropEvent"
                        ) then
                            task.defer(function()
                                purge("vault-remote")
                            end)
                        end
                    end
                end

                return oldNamecall(self, ...)
            end)

            metaTable.__namecall = installedNamecall

            if type(setreadonly) == "function" then
                setreadonly(metaTable, true)
            end

            State.MetaTable = metaTable
            State.OldNamecall = oldNamecall
            State.InstalledNamecall = installedNamecall
        end)
    end

    local patch = {
        Purge = function()
            purge("manual")
        end,

        CFG = CFG,

        Destroy = function(self)
            if State.Destroyed then
                return
            end

            State.Destroyed = true

            for _, connection in ipairs(State.Connections) do
                disconnect(connection)
            end
            State.Connections = {}

            for character, connection in pairs(State.AnimConnections) do
                disconnect(connection)
                State.AnimConnections[character] = nil
            end

            State.Hooked = {}

            pcall(function()
                if State.MetaTable
                    and State.OldNamecall
                    and State.InstalledNamecall
                    and State.MetaTable.__namecall == State.InstalledNamecall then

                    if type(setreadonly) == "function" then
                        setreadonly(State.MetaTable, false)
                    end

                    State.MetaTable.__namecall = State.OldNamecall

                    if type(setreadonly) == "function" then
                        setreadonly(State.MetaTable, true)
                    end
                end
            end)

            State.OldNamecall = nil
            State.InstalledNamecall = nil
            State.MetaTable = nil
        end,
    }

    return patch
end)()

getgenv().MAWWW_NoSlowPatch = NoSlowPatch

--========================================================--
-- UI: VAULT & FALL NO-SLOWDOWN+
--========================================================--

RegDivider(Tabs.SurvivalNoSlow)

RegToggle(
    Tabs.SurvivalNoSlow,
    "Vault & Fall No-Slowdown+",
    "Patch tambahan: auto-clear slowdown setelah vault jendela & landing dari ketinggian.",
    true,
    "NoSlowPatchEnabled",
    function(value)
        if value then
            notify("No-Slowdown+", "ON — vault & landing bebas slowdown", 3)
        else
            notify("No-Slowdown+", "OFF", 2)
        end
    end
)

RegButton(
    Tabs.SurvivalNoSlow,
    "Force Purge Slowdown Now",
    "Manual purge slowdown saat ini.",
    function()
        pcall(function()
            NoSlowPatch.Purge()
        end)
        notify("No-Slowdown+", "Purge dijalankan.", 2)
    end
)

print("[Mawww Hub] Patch Vault & Fall No-Slowdown+ loaded.")


RegButton(Tabs.UISettings, "Unload Script", "Unload the script", function()
    notify("Mawww Hub", "Unloading...", 2)
    pcall(function() if AutoParryV3Module and AutoParryV3Module.DestroyRing then AutoParryV3Module.DestroyRing() end end)
    pcall(function() if ParryV4 and ParryV4.DestroyCircle then ParryV4.DestroyCircle() end end)
    pcall(function() if getgenv().Mawww_DestroyParryV3Circle then getgenv().Mawww_DestroyParryV3Circle() end end)
    pcall(function() if getgenv().MAWWW_ToFV3ClearLaser then getgenv().MAWWW_ToFV3ClearLaser() end end)
    pcall(function() if getgenv().MAWWW_SetToFV3SilentAim then getgenv().MAWWW_SetToFV3SilentAim(false) end end)

    VD.Destroyed = true
    VD.NoCutscene = false
    pcall(SetNoCutscene, false)
    pcall(function() if MAWWW_Config then MAWWW_Config.Refresh() end end)
    pcall(function() if DBD_Restore then DBD_Restore() end end)
    pcall(function()
        MAWWW_InvisibleOn = false
        VD.Invisible = false
        if MAWWW_InvisibleModule then MAWWW_InvisibleModule.disable() end
        MAWWW_ForceCleanupInvisible()
        if MAWWW_InvisibleGui then MAWWW_InvisibleGui:Destroy(); MAWWW_InvisibleGui = nil end
        if MAWWW_InvisibleCharacterConn then MAWWW_InvisibleCharacterConn:Disconnect(); MAWWW_InvisibleCharacterConn = nil end
    end)
    pcall(function()
        local genv = getgenv and getgenv() or _G
        local neonConnection = genv and genv.PURPLE_X_NEON_CONNECTION
        if neonConnection and type(neonConnection.Disconnect) == "function" then
            neonConnection:Disconnect()
        end
        if genv then
            genv.PURPLE_X_NEON_CONNECTION = nil
        end
    end)
    pcall(function()
        local CoreGui = game:GetService("CoreGui")
        local toggle = CoreGui:FindFirstChild("PurpleXToggle")
        if toggle then
            toggle:Destroy()
        end
    end)
    pcall(function()
        local patch = getgenv().MAWWW_NoSlowPatch
        if patch and type(patch.Destroy) == "function" then
            patch:Destroy()
        end
        getgenv().MAWWW_NoSlowPatch = nil
        NoSlowPatch = nil
    end)
    pcall(function() if ParryV2 and ParryV2.DestroyCircle then pcall(ParryV2.DestroyCircle) end end)
    pcall(function() if AutoParryModule and AutoParryModule.DestroyRing then pcall(AutoParryModule.DestroyRing) end end)
    pcall(function() if SpearVeil and SpearVeil.State and SpearVeil.State.IndicatorPart and SpearVeil.State.IndicatorPart.Parent then SpearVeil.State.IndicatorPart:Destroy() end end)
    pcall(function() if PalletRangeIndicator and PalletRangeIndicator.Part and PalletRangeIndicator.Part.Parent then DestroyPalletRangeIndicator() end end)
    pcall(function() if TofV1New and TofV1New.Cleanup then TofV1New.Cleanup() end end)
    pcall(function() if getgenv().MAWWW_ToFClearLaser then getgenv().MAWWW_ToFClearLaser() end end)
    pcall(function() if MAWWW_DestroyCureFlaskLaser then MAWWW_DestroyCureFlaskLaser() end end)
    pcall(function() if QuickToggleUI and QuickToggleUI.Destroy then QuickToggleUI.Destroy() end end)
    pcall(function() if MyersGrabData and MyersGrabData.UI then MyersGrabData.UI:Destroy() end end)
    pcall(function() if getgenv().MAWWW and getgenv().MAWWW.GenBypass and getgenv().MAWWW.GenBypass.UI then getgenv().MAWWW.GenBypass.UI:Destroy() end end)
    pcall(function() if getgenv().MAWWW_AbyssCooldownBypassConnection then getgenv().MAWWW_AbyssCooldownBypassConnection:Disconnect() end end)
    pcall(function() if getgenv().MAWWW_MawwwStop then getgenv().MAWWW_MawwwStop() end end)
    pcall(function()
        if getgenv().VD_ParryRaycastConn then
            getgenv().VD_ParryRaycastConn:Disconnect()
            getgenv().VD_ParryRaycastConn = nil
        end
    end)
    pcall(function()
        if PingFPSGui then PingFPSGui:Destroy() end
        if PingFPSConn then PingFPSConn:Disconnect() end
        if HideSurvConn and type(HideSurvConn) == "userdata" and HideSurvConn.Disconnect then HideSurvConn:Disconnect() end
        if HookCounterConn then HookCounterConn:Disconnect() end
        if getgenv().MAWWW_StunIndicatorShutdown then
            getgenv().MAWWW_StunIndicatorShutdown()
        end
    end)
    pcall(function() VeilSharedVisuals.HideAll() end)
    -- Restore original V2 cleanup.
    pcall(function()
        if VeilV2 and VeilV2.Visuals then
            VeilV2.Visuals.HideAll()
            if VeilV2.Visuals.FOVOutline then VeilV2.Visuals.FOVOutline:Remove() end
            if VeilV2.Visuals.FOVFill then VeilV2.Visuals.FOVFill:Remove() end
            if VeilV2.Visuals.TracerLine then VeilV2.Visuals.TracerLine:Remove() end
            if VeilV2.Visuals.TargetOutline then VeilV2.Visuals.TargetOutline:Remove() end
            if VeilV2.Visuals.TargetFill then VeilV2.Visuals.TargetFill:Remove() end
        end
    end)
    pcall(function() if VeilV3SharedVisuals then VeilV3SharedVisuals.HideAll() end end)
    pcall(function() if VeilV4 and VeilV4.Visuals then VeilV4.Visuals.HideAll() end end)
    pcall(function()
        for _, c in pairs(VeilSharedVisuals.PlayerCircles) do
            if c.outline then c.outline:Remove() end
            if c.fill then c.fill:Remove() end
        end
        for _, bb in pairs(VeilSharedVisuals.NameLabels) do if bb then bb:Destroy() end end
    end)
    task.wait(0.3)
    pcall(function() MAWWW_SetUIVisible(false) end)
    getgenv().MAWWW_Obsidian_Window = nil
    getgenv().MAWWW_Obsidian_Library = nil
end)


--========================================================--
-- Mawww SOURCE COMPATIBILITY ADDITIONS
-- Imported from source Mawww where the base hub did not already
-- expose the same feature. Existing overlapping implementations
-- (Auto Parry V2 / TOF / Moonwalk / Gen Boost / Fake Perks, etc.)
-- are intentionally reused instead of duplicated.
--========================================================--

do
    local L2State = getgenv().MAWWW_Mawww_STATE or {}
    getgenv().MAWWW_Mawww_STATE = L2State

    L2State.AutoRunMobileThread = nil
    L2State.AutoRunPCThread = L2State.AutoRunPCThread
    L2State.SpeedConn = nil
    L2State.SpeedBV = nil
    L2State.GodThread = L2State.GodThread

    local function L2_GetMobileSprintButton()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return nil end
        local mob = pg:FindFirstChild("Survivor-mob")
        if not mob then return nil end
        local controls = mob:FindFirstChild("Controls")
        if not controls then return nil end
        local sprint = controls:FindFirstChild("sprint")
        if not sprint then return nil end

        if sprint:IsA("GuiButton") then return sprint end
        local icon = sprint:FindFirstChild("icon")
        if icon and icon:IsA("GuiButton") then return icon end
        if icon and icon.Parent and icon.Parent:IsA("GuiButton") then return icon.Parent end
        if sprint.Parent and sprint.Parent:IsA("GuiButton") then return sprint.Parent end
        return nil
    end

    local function L2_PressSprint()
        local btn = L2_GetMobileSprintButton()
        if not btn then return false end

        local ok = pcall(function()
            if type(firesignal) == "function" then
                firesignal(btn.MouseButton1Down)
                task.wait(0.04)
                firesignal(btn.MouseButton1Up)
            elseif VirtualInputManager then
                local pos = btn.AbsolutePosition
                local size = btn.AbsoluteSize
                local inset = GuiService:GetGuiInset()
                local x = pos.X + size.X / 2 + inset.X
                local y = pos.Y + size.Y / 2 + inset.Y
                local id = 9901
                VirtualInputManager:SendTouchEvent(id, 0, x, y)
                task.wait(0.04)
                VirtualInputManager:SendTouchEvent(id, 2, x, y)
            end
        end)

        return ok
    end

    local function L2_IsMoving()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return false end

        if hum.MoveDirection.Magnitude > 0.12 then
            return true
        end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local v = hrp.AssemblyLinearVelocity
            if Vector3.new(v.X, 0, v.Z).Magnitude > 1.5 then
                return true
            end
        end

        return false
    end

    local function L2_IsCrouching()
        local char = LocalPlayer.Character
        if not char then return false end
        return char:GetAttribute("Crouching") == true
            or char:GetAttribute("Crouchingserver") == true
    end

    local function L2_IsActuallySprinting()
        local char = LocalPlayer.Character
        if not char then return false end
        return char:GetAttribute("Sprinting") == true
            or char:GetAttribute("IsRunning") == true
    end

    local function L2_StopAutoRunMobile()
        VD.L2_AutoRunMobile = false
        if L2State.AutoRunMobileThread then
            pcall(task.cancel, L2State.AutoRunMobileThread)
            L2State.AutoRunMobileThread = nil
        end
        if L2_IsActuallySprinting() then
            pcall(L2_PressSprint)
        end
    end

    local function L2_StartAutoRunMobile()
        if L2State.AutoRunMobileThread then return end

        L2State.AutoRunMobileThread = task.spawn(function()
            while not VD.Destroyed and VD.L2_AutoRunMobile do
                local moving = L2_IsMoving()
                local crouching = L2_IsCrouching()
                local sprinting = L2_IsActuallySprinting()

                if crouching then
                    if sprinting then
                        L2_PressSprint()
                    end
                else
                    if moving and not sprinting then
                        L2_PressSprint()
                    elseif not moving and sprinting then
                        L2_PressSprint()
                    end
                end

                task.wait(0.12)
            end

            if L2_IsActuallySprinting() then
                L2_PressSprint()
            end

            L2State.AutoRunMobileThread = nil
        end)
    end

    local function L2_StopAutoRunPC()
        VD.L2_AutoRunPC = false
        if L2State.AutoRunPCThread then
            pcall(task.cancel, L2State.AutoRunPCThread)
            L2State.AutoRunPCThread = nil
        end
        pcall(function()
            if VirtualInputManager then
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
            end
        end)
    end

    local function L2_StartAutoRunPC()
        if L2State.AutoRunPCThread then return end

        L2State.AutoRunPCThread = task.spawn(function()
            while not VD.Destroyed and VD.L2_AutoRunPC do
                if VirtualInputManager then
                    pcall(function()
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)
                    end)
                end
                task.wait(0.1)
            end

            pcall(function()
                if VirtualInputManager then
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
                end
            end)

            L2State.AutoRunPCThread = nil
        end)
    end

    local function L2_ClearSpeedBoost()
        if L2State.SpeedConn then
            pcall(function() L2State.SpeedConn:Disconnect() end)
            L2State.SpeedConn = nil
        end

        if L2State.SpeedBV then
            pcall(function() L2State.SpeedBV:Destroy() end)
            L2State.SpeedBV = nil
        end
    end

    local function L2_ApplySpeedBoost()
        L2_ClearSpeedBoost()

        if not VD.L2_SpeedBoost then return end

        local function update()
            if not VD.L2_SpeedBoost or VD.Destroyed then return end

            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum or hum.Health <= 0 then return end

            local bv = hrp:FindFirstChild("MAWWW_L2SpeedBV")
            if not bv then
                bv = Instance.new("BodyVelocity")
                bv.Name = "MAWWW_L2SpeedBV"
                bv.MaxForce = Vector3.new(1e9, 0, 1e9)
                bv.P = 1e6
                bv.Parent = hrp
            end

            L2State.SpeedBV = bv

            local moveDir = hum.MoveDirection
            if moveDir.Magnitude > 0 then
                bv.Velocity = moveDir * math.max(1, tonumber(VD.L2_Speed) or 30)
            else
                bv.Velocity = Vector3.zero
            end
        end

        update()
        L2State.SpeedConn = RunService.Heartbeat:Connect(update)
    end

    local function L2_StartGodMode()
        if L2State.GodThread then
            pcall(task.cancel, L2State.GodThread)
            L2State.GodThread = nil
        end

        if not VD.L2_GodMode then return end

        L2State.GodThread = task.spawn(function()
            while not VD.Destroyed and VD.L2_GodMode do
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")

                if hum then
                    pcall(function()
                        if hum.Health > 0 and hum.Health < hum.MaxHealth then
                            hum.Health = hum.MaxHealth
                        end
                    end)
                end

                task.wait(0.1)
            end

            L2State.GodThread = nil
        end)
    end

    local function L2_ResetCharacterFeatures()
        if VD.L2_AutoRunMobile then
            L2State.AutoRunMobileThread = nil
            L2_StartAutoRunMobile()
        end
        if VD.L2_AutoRunPC then
            L2State.AutoRunPCThread = nil
            L2_StartAutoRunPC()
        end
        if VD.L2_SpeedBoost then
            task.delay(0.25, L2_ApplySpeedBoost)
        end
        if VD.L2_GodMode then
            L2_StartGodMode()
        end
    end

    RegDivider(Tabs.PlayerRight)
    RegLabel(Tabs.PlayerRight, "Extra Movement")

    RegToggle(
        Tabs.PlayerRight,
        "Auto Run (Mobile)",
        "Source Mawww auto sprint with crouch-state handling.",
        false,
        "L2_AutoRunMobile",
        function(v)
            VD.L2_AutoRunMobile = v == true
            if VD.L2_AutoRunMobile then
                L2_StartAutoRunMobile()
                notify("Auto Run Mobile", "ON", 2)
            else
                L2_StopAutoRunMobile()
                notify("Auto Run Mobile", "OFF", 2)
            end
        end
    )

    RegToggle(
        Tabs.PlayerRight,
        "Auto Run (PC)",
        "Hold sprint automatically while enabled.",
        false,
        "L2_AutoRunPC",
        function(v)
            VD.L2_AutoRunPC = v == true
            if VD.L2_AutoRunPC then
                L2_StartAutoRunPC()
                notify("Auto Run PC", "ON", 2)
            else
                L2_StopAutoRunPC()
                notify("Auto Run PC", "OFF", 2)
            end
        end
    )

    RegSlider(
        Tabs.PlayerRight,
        "Speed Boost Value",
        "BodyVelocity movement speed from the uploaded source.",
        30,
        16,
        100,
        1,
        "L2_Speed"
    )

    RegToggle(
        Tabs.PlayerRight,
        "Mawww Speed Boost",
        "Enable the source movement boost without replacing the existing WalkSpeed feature.",
        false,
        "L2_SpeedBoost",
        function(v)
            VD.L2_SpeedBoost = v == true
            if VD.L2_SpeedBoost then
                L2_ApplySpeedBoost()
                notify("Mawww Speed Boost", "ON", 2)
            else
                L2_ClearSpeedBoost()
                notify("Mawww Speed Boost", "OFF", 2)
            end
        end
    )

    RegToggle(
        Tabs.SurvivalAbilities,
        "God Mode",
        "Source Mawww health-regeneration loop.",
        false,
        "L2_GodMode",
        function(v)
            VD.L2_GodMode = v == true
            if VD.L2_GodMode then
                L2_StartGodMode()
                notify("Mawww God Mode", "ON", 2)
            else
                if L2State.GodThread then
                    pcall(task.cancel, L2State.GodThread)
                    L2State.GodThread = nil
                end
                notify("Mawww God Mode", "OFF", 2)
            end
        end
    )

    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.75)
        if VD.Destroyed then return end
        pcall(L2_ResetCharacterFeatures)
    end)

    -- Expose the controls for the existing quick-refresh/unload logic.
    getgenv().MAWWW_MawwwStop = function()
        VD.L2_AutoRunMobile = false
        VD.L2_AutoRunPC = false
        VD.L2_SpeedBoost = false
        VD.L2_GodMode = false
        pcall(L2_StopAutoRunMobile)
        pcall(L2_StopAutoRunPC)
        pcall(L2_ClearSpeedBoost)
        if L2State.GodThread then
            pcall(task.cancel, L2State.GodThread)
            L2State.GodThread = nil
        end
    end
end

--========================================================--

-- [NEW] CUSTOM CONFIG SYSTEM (Save / Load / Reset)
--========================================================--
MAWWW_Config = MAWWW_Config or {}

CONFIG_FOLDER = "MawwwHub_Configs"
CONFIG_INDEX = CONFIG_FOLDER .. "/_index.json"

function ensureConfigFolder()
    pcall(function()
        if type(isfolder) == "function" then
            if not isfolder(CONFIG_FOLDER) and type(makefolder) == "function" then
                makefolder(CONFIG_FOLDER)
            end
        elseif type(makefolder) == "function" then
            makefolder(CONFIG_FOLDER)
        end
    end)
end

function safeJsonEncode(tbl)
    local ok, result = pcall(function()
        return HttpService:JSONEncode(tbl)
    end)
    return ok and result or nil
end

function safeJsonDecode(str)
    local ok, result = pcall(function()
        return HttpService:JSONDecode(str)
    end)
    return ok and result or nil
end

function getConfigList()
    ensureConfigFolder()

    local list = {}

    pcall(function()
        if type(isfile) == "function" and isfile(CONFIG_INDEX)
            and type(readfile) == "function" then

            local raw = readfile(CONFIG_INDEX)
            local data = safeJsonDecode(raw)

            if type(data) == "table" then
                for _, name in ipairs(data) do
                    if type(name) == "string" and name ~= "" then
                        table.insert(list, name)
                    end
                end
            end
        end
    end)

    local seen = {}
    local unique = {}
    for _, name in ipairs(list) do
        local safe = tostring(name):gsub("[^%w_%-]", "_")
        if safe ~= "" and not seen[safe] then
            seen[safe] = true
            table.insert(unique, safe)
        end
    end
    list = unique
    if not seen.default then table.insert(list, 1, "default") end
    table.sort(list, function(a, b)
        if a == "default" then return true end
        if b == "default" then return false end
        return a:lower() < b:lower()
    end)
    return list
end

function saveConfigList(list)
    ensureConfigFolder()

    if type(writefile) ~= "function" then
        return false
    end

    local raw = safeJsonEncode(list)
    if not raw then
        return false
    end

    local ok = pcall(function()
        writefile(CONFIG_INDEX, raw)
    end)

    return ok
end

-- Runtime/UI values that should never be restored from disk.
CONFIG_BLACKLIST = {
    QuickMoonwalkPosition = false,
    QuickGenBossPosition = false,
    QuickInfiniteMyersPosition = false,
    QuickBypassSkillPosition = false,
    SH_VisitedServers = false,
    Destroyed = false,
    -- Global persistence preferences are stored in _prefs.json, not in profiles.
    Config_AutoSaveEnabled = false,
    Config_AutoLoadEnabled = false,
    Config_AutoSaveInterval = false,
}

function serializeUDim2(value)
    if typeof(value) == "UDim2" then
        return {
            XScale = value.X.Scale,
            XOffset = value.X.Offset,
            YScale = value.Y.Scale,
            YOffset = value.Y.Offset,
            __UDim2 = true,
        }
    end
    return value
end

function deserializeUDim2(value)
    if type(value) == "table" and value.__UDim2 then
        return UDim2.new(
            tonumber(value.XScale) or 0,
            tonumber(value.XOffset) or 0,
            tonumber(value.YScale) or 0,
            tonumber(value.YOffset) or 0
        )
    end
    return value
end

function sanitizeConfigValue(value)
    local rawType = type(value)
    local valueType = typeof(value)

    -- Roblox datatypes must be handled before the generic userdata branch.
    if valueType == "Color3" then
        return {
            R = value.R,
            G = value.G,
            B = value.B,
            __Color3 = true,
        }
    end

    if valueType == "UDim2" then
        return {
            XScale = value.X.Scale,
            XOffset = value.X.Offset,
            YScale = value.Y.Scale,
            YOffset = value.Y.Offset,
            __UDim2 = true,
        }
    end

    if valueType == "Vector2" then
        return {X = value.X, Y = value.Y, __Vector2 = true}
    end

    if valueType == "Vector3" then
        return {X = value.X, Y = value.Y, Z = value.Z, __Vector3 = true}
    end

    if valueType == "BrickColor" then
        return {Name = value.Name, __BrickColor = true}
    end

    if valueType == "EnumItem" then
        return {EnumType = tostring(value.EnumType), Name = value.Name, __EnumItem = true}
    end

    if rawType == "function" or rawType == "thread" or rawType == "userdata" then
        return nil
    end

    if rawType == "table" then
        local out = {}
        for k, v in pairs(value) do
            if type(k) == "string" or type(k) == "number" then
                local sanitized = sanitizeConfigValue(v)
                if sanitized ~= nil then
                    out[k] = sanitized
                end
            end
        end
        return out
    end

    if rawType == "number" or rawType == "string" or rawType == "boolean" or value == nil then
        return value
    end

    return nil
end

function deserializeConfigValue(value)
    if type(value) ~= "table" then
        return value
    end

    if value.__Color3 then
        return Color3.new(
            math.clamp(tonumber(value.R) or 0, 0, 1),
            math.clamp(tonumber(value.G) or 0, 0, 1),
            math.clamp(tonumber(value.B) or 0, 0, 1)
        )
    end

    if value.__UDim2 then
        return UDim2.new(
            tonumber(value.XScale) or 0,
            tonumber(value.XOffset) or 0,
            tonumber(value.YScale) or 0,
            tonumber(value.YOffset) or 0
        )
    end

    if value.__Vector2 then
        return Vector2.new(tonumber(value.X) or 0, tonumber(value.Y) or 0)
    end

    if value.__Vector3 then
        return Vector3.new(tonumber(value.X) or 0, tonumber(value.Y) or 0, tonumber(value.Z) or 0)
    end

    if value.__BrickColor and value.Name then
        local ok, result = pcall(function() return BrickColor.new(value.Name) end)
        if ok then return result end
    end

    if value.__EnumItem and value.EnumType and value.Name then
        local enumTypeName = tostring(value.EnumType):match("Enum%.(.+)")
        if enumTypeName and Enum[enumTypeName] then
            local ok, result = pcall(function() return Enum[enumTypeName][value.Name] end)
            if ok and result then return result end
        end
    end

    local out = {}
    for k, v in pairs(value) do
        if k ~= "__Color3" and k ~= "__UDim2" and k ~= "__Vector2" and k ~= "__Vector3" and k ~= "__BrickColor" and k ~= "__EnumItem" then
            out[k] = deserializeConfigValue(v)
        end
    end
    return out
end
function MAWWW_Config._BuildData()
    local data = {
        _meta = {
            version = 2,
            savedAt = os.time(),
            place = game.PlaceId,
        },
    }

    for k, v in pairs(VD) do
        if CONFIG_BLACKLIST[k] ~= false then
            local sanitized = sanitizeConfigValue(v)
            if sanitized ~= nil then
                data[k] = sanitized
            end
        end
    end

    return data
end

function MAWWW_Config._Write(name, silent)
    name = tostring(name or "default")
    name = name:gsub("[^%w_%-]", "_")
    if name == "" then name = "default" end

    if type(writefile) ~= "function" then
        if not silent then notify("Config", "Executor tidak menyediakan writefile().", 3) end
        return false
    end

    ensureConfigFolder()
    local data = MAWWW_Config._BuildData()
    local encoded = safeJsonEncode(data)
    if not encoded then
        if not silent then notify("Config", "Gagal encode config: " .. name, 3) end
        return false
    end

    local path = CONFIG_FOLDER .. "/" .. name .. ".json"
    local ok = pcall(function() writefile(path, encoded) end)
    if not ok then
        if not silent then notify("Config", "Gagal menyimpan: " .. name, 3) end
        return false
    end

    local list = getConfigList()
    local found = false
    for _, existingName in ipairs(list) do
        if existingName == name then found = true break end
    end
    if not found then table.insert(list, name) end
    saveConfigList(list)

    return true, encoded
end

function MAWWW_Config.Save(name)
    name = tostring(name or "default")
    name = name:gsub("[^%w_%-]", "_")
    if name == "" then name = "default" end

    local ok = MAWWW_Config._Write(name, false)
    if not ok then return false end

    MAWWW_Config._lastAutoSave = nil
    notify("Config", "Saved: " .. name, 3)
    return true
end

function MAWWW_Config.Load(name)
    name = tostring(name or "default")
    name = name:gsub("[^%w_%-]", "_")

    if name == "" then
        name = "default"
    end

    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        notify("Config", "Executor tidak menyediakan filesystem API.", 3)
        return false
    end

    ensureConfigFolder()

    local path = CONFIG_FOLDER .. "/" .. name .. ".json"
    local exists = false

    pcall(function()
        exists = isfile(path) == true
    end)

    if not exists then
        notify("Config", "Config tidak ditemukan: " .. name, 3)
        return false
    end

    local raw
    local readOK = pcall(function()
        raw = readfile(path)
    end)

    if not readOK or type(raw) ~= "string" then
        notify("Config", "Gagal membaca config: " .. name, 3)
        return false
    end

    local data = safeJsonDecode(raw)
    if type(data) ~= "table" then
        notify("Config", "Config corrupt: " .. name, 3)
        return false
    end

    local applied = 0

    for k, v in pairs(data) do
        if k ~= "_meta"
            and CONFIG_BLACKLIST[k] ~= false
            and type(k) == "string"
            and (defaults[k] ~= nil or VD[k] ~= nil) then

            VD[k] = deserializeConfigValue(v)
            applied = applied + 1
        end
    end

    -- Push loaded values into registered Obsidian controls.
    for vdKey, elem in pairs(VD_Elements) do
        if elem and VD[vdKey] ~= nil then
            pcall(function()
                if type(elem.SetValue) == "function" then
                    elem:SetValue(VD[vdKey])
                end
            end)
        end
    end

    pcall(function()
        if getgenv().MAWWW_QuickRefresh then
            getgenv().MAWWW_QuickRefresh()
        end
    end)

    pcall(function()
        if AutoParryModule and AutoParryModule.EnsureRaycastParry then
            AutoParryModule.EnsureRaycastParry()
        end
    end)

    notify("Config", string.format("Loaded: %s (%d setting)", name, applied), 4)
    return true
end

function MAWWW_Config.Delete(name)
    name = tostring(name or "")
    name = name:gsub("[^%w_%-]", "_")

    if name == "" or name == "default" then
        notify("Config", "Config 'default' tidak boleh dihapus.", 3)
        return false
    end

    if type(delfile) ~= "function" then
        notify("Config", "Executor tidak menyediakan delfile().", 3)
        return false
    end

    local path = CONFIG_FOLDER .. "/" .. name .. ".json"

    pcall(function()
        if type(isfile) == "function" and isfile(path) then
            delfile(path)
        end
    end)

    local list = getConfigList()

    for i = #list, 1, -1 do
        if list[i] == name then
            table.remove(list, i)
        end
    end

    saveConfigList(list)
    notify("Config", "Deleted: " .. name, 3)
    return true
end

function MAWWW_Config.Refresh()
    local list = getConfigList()

    if VD_Elements["Config_Select"] then
        pcall(function()
            if VD_Elements["Config_Select"].Refresh then
                VD_Elements["Config_Select"]:Refresh(list)
            elseif VD_Elements["Config_Select"].SetValues then
                VD_Elements["Config_Select"]:SetValues(list)
            end
        end)
    end

    return list
end

--========================================================--
-- AUTO SAVE / AUTO LOAD
-- Global persistence preferences live in _prefs.json so disabling
-- auto-load does not create a circular dependency with the profile itself.
--========================================================--
CONFIG_PREFS = CONFIG_FOLDER .. "/_prefs.json"

local function clampConfigInterval(value)
    return math.clamp(tonumber(value) or 3, 1, 60)
end

function MAWWW_Config.SavePrefs()
    if type(writefile) ~= "function" then return false end

    ensureConfigFolder()

    local payload = {
        AutoSave = MAWWW_Config.AutoSaveEnabled == true,
        AutoLoad = MAWWW_Config.AutoLoadEnabled == true,
        AutoSaveInterval = clampConfigInterval(MAWWW_Config.AutoSaveInterval),
    }

    local encoded = safeJsonEncode(payload)
    if not encoded then return false end

    return pcall(function()
        writefile(CONFIG_PREFS, encoded)
    end)
end

function MAWWW_Config.LoadPrefs()
    MAWWW_Config.AutoSaveEnabled = VD.Config_AutoSaveEnabled ~= false
    MAWWW_Config.AutoLoadEnabled = VD.Config_AutoLoadEnabled ~= false
    MAWWW_Config.AutoSaveInterval = clampConfigInterval(VD.Config_AutoSaveInterval)

    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        return false
    end

    local exists = false
    pcall(function()
        exists = isfile(CONFIG_PREFS) == true
    end)
    if not exists then
        return false
    end

    local raw
    local okRead = pcall(function()
        raw = readfile(CONFIG_PREFS)
    end)
    if not okRead or type(raw) ~= "string" then
        return false
    end

    local data = safeJsonDecode(raw)
    if type(data) ~= "table" then
        return false
    end

    if data.AutoSave ~= nil then
        MAWWW_Config.AutoSaveEnabled = data.AutoSave == true
    end
    if data.AutoLoad ~= nil then
        MAWWW_Config.AutoLoadEnabled = data.AutoLoad == true
    end
    if data.AutoSaveInterval ~= nil then
        MAWWW_Config.AutoSaveInterval = clampConfigInterval(data.AutoSaveInterval)
    end

    VD.Config_AutoSaveEnabled = MAWWW_Config.AutoSaveEnabled
    VD.Config_AutoLoadEnabled = MAWWW_Config.AutoLoadEnabled
    VD.Config_AutoSaveInterval = MAWWW_Config.AutoSaveInterval
    return true
end

pcall(function()
    MAWWW_Config.LoadPrefs()
end)

MAWWW_Config._lastAutoSave = nil
MAWWW_Config._autoSaveRunning = true

function MAWWW_Config.AutoSave(force)
    if not MAWWW_Config.AutoSaveEnabled then return false end
    if type(writefile) ~= "function" then return false end

    local okData, encoded = pcall(function()
        local data = MAWWW_Config._BuildData()
        return safeJsonEncode(data)
    end)
    if not okData or type(encoded) ~= "string" then return false end

    if not force and encoded == MAWWW_Config._lastAutoSave then
        return false
    end

    local okWrite = pcall(function()
        ensureConfigFolder()
        writefile(CONFIG_FOLDER .. "/default.json", encoded)
    end)
    if not okWrite then return false end

    MAWWW_Config._lastAutoSave = encoded

    pcall(function()
        local list = getConfigList()
        local found = false
        for _, name in ipairs(list) do
            if name == "default" then
                found = true
                break
            end
        end
        if not found then
            table.insert(list, 1, "default")
            saveConfigList(list)
        end
    end)

    return true
end

function MAWWW_Config.StartAutoSave()
    if MAWWW_Config._autoSaveStarted then return end
    MAWWW_Config._autoSaveStarted = true

    task.spawn(function()
        while MAWWW_Config._autoSaveRunning and not (VD and VD.Destroyed) do
            task.wait(clampConfigInterval(MAWWW_Config.AutoSaveInterval))
            if not MAWWW_Config._autoSaveRunning or (VD and VD.Destroyed) then
                break
            end
            pcall(function()
                MAWWW_Config.AutoSave(false)
            end)
        end
        MAWWW_Config._autoSaveStarted = false
    end)
end

MAWWW_Config.AutoSaveEnabled = true
MAWWW_Config.AutoSaveInterval = 3
MAWWW_Config._lastAutoSave = nil
MAWWW_Config._autoSaveRunning = true

function MAWWW_Config.AutoSave(force)
    if not MAWWW_Config.AutoSaveEnabled then return false end
    if type(writefile) ~= "function" then return false end

    local okData, encoded = pcall(function()
        local data = MAWWW_Config._BuildData()
        return safeJsonEncode(data)
    end)
    if not okData or type(encoded) ~= "string" then return false end

    if not force and encoded == MAWWW_Config._lastAutoSave then
        return false
    end

    local okWrite = pcall(function()
        ensureConfigFolder()
        writefile(CONFIG_FOLDER .. "/default.json", encoded)
    end)
    if not okWrite then return false end

    MAWWW_Config._lastAutoSave = encoded

    -- Keep "default" present in the config selector/index.
    pcall(function()
        local list = getConfigList()
        local found = false
        for _, name in ipairs(list) do
            if name == "default" then found = true break end
        end
        if not found then
            table.insert(list, 1, "default")
            saveConfigList(list)
        end
    end)

    return true
end

function MAWWW_Config.StartAutoSave()
    if MAWWW_Config._autoSaveStarted then return end
    MAWWW_Config._autoSaveStarted = true

    task.spawn(function()
        while MAWWW_Config._autoSaveRunning do
            task.wait(tonumber(MAWWW_Config.AutoSaveInterval) or 3)
            if not MAWWW_Config._autoSaveRunning then break end
            pcall(function() MAWWW_Config.AutoSave(false) end)
        end
    end)
end

pcall(function() MAWWW_Config.StartAutoSave() end)

RegDivider(Tabs.UIConfig)
RegLabel(Tabs.UIConfig, "Persistence")

RegToggle(
    Tabs.UIConfig,
    "Auto Save Config",
    "Simpan perubahan setting otomatis ke profile default.",
    true,
    "Config_AutoSaveEnabled",
    function(v)
        local enabled = v == true
        VD.Config_AutoSaveEnabled = enabled
        MAWWW_Config.AutoSaveEnabled = enabled
        pcall(MAWWW_Config.SavePrefs)
        if enabled then
            pcall(function() MAWWW_Config.StartAutoSave() end)
        end
    end
)

RegToggle(
    Tabs.UIConfig,
    "Auto Load Config",
    "Muat profile default otomatis saat script dimulai.",
    true,
    "Config_AutoLoadEnabled",
    function(v)
        local enabled = v == true
        VD.Config_AutoLoadEnabled = enabled
        MAWWW_Config.AutoLoadEnabled = enabled
        pcall(MAWWW_Config.SavePrefs)
    end
)

RegSlider(
    Tabs.UIConfig,
    "Auto Save Interval",
    "Interval penyimpanan otomatis dalam detik.",
    3,
    1,
    60,
    1,
    "Config_AutoSaveInterval",
    function(v)
        local interval = clampConfigInterval(v)
        VD.Config_AutoSaveInterval = interval
        MAWWW_Config.AutoSaveInterval = interval
        pcall(MAWWW_Config.SavePrefs)
    end
)

RegButton(
    Tabs.UIConfig,
    "Save Preferences",
    "Simpan pengaturan Auto Save, Auto Load, dan interval.",
    function()
        pcall(MAWWW_Config.SavePrefs)
        notify("Config", "Persistence preferences saved.", 2)
    end
)

RegLabel(Tabs.UIConfig, "Custom Config")

RegDropdown(
    Tabs.UIConfig,
    "Config Profile",
    "Pilih profile config yang tersimpan",
    getConfigList(),
    VD.Config_Select or "default",
    false,
    "Config_Select"
)

RegButton(
    Tabs.UIConfig,
    "Save Config",
    "Simpan setting ke profile terpilih",
    function()
        MAWWW_Config.Save(VD.Config_Select or "default")
    end
)

RegButton(
    Tabs.UIConfig,
    "Load Config",
    "Load setting dari profile terpilih",
    function()
        MAWWW_Config.Load(VD.Config_Select or "default")
    end
)

RegButton(
    Tabs.UIConfig,
    "Delete Config",
    "Hapus profile config terpilih",
    function()
        local name = VD.Config_Select or "default"

        if name == "default" then
            notify("Config", "Tidak bisa menghapus 'default'.", 3)
            return
        end

        MAWWW_Config.Delete(name)
        MAWWW_Config.Refresh()
    end
)

RegButton(
    Tabs.UIConfig,
    "Refresh Config List",
    "Refresh daftar config",
    function()
        MAWWW_Config.Refresh()
        notify("Config", "List refreshed.", 2)
    end
)

RegInput(
    Tabs.UIConfig,
    "Custom Config Name",
    "Ketik nama config yang ingin disimpan.",
    "my_config",
    "Config_CustomName"
)

RegButton(
    Tabs.UIConfig,
    "Save As Custom Name",
    "Simpan setting dengan nama custom di atas.",
    function()
        local name = VD.Config_CustomName or "my_config"
        MAWWW_Config.Save(name)
        MAWWW_Config.Refresh()
    end
)

RegButton(
    Tabs.UIConfig,
    "Save As New Timestamp",
    "Buat config baru dengan nama timestamp.",
    function()
        local name = "cfg_" .. tostring(os.time())
        MAWWW_Config.Save(name)
        MAWWW_Config.Refresh()
    end
)

RegButton(
    Tabs.UIConfig,
    "Reset All Settings to Default",
    "Reset semua nilai VD ke default tanpa menghapus file config.",
    function()
        local function cloneDefault(v)
            if type(v) ~= "table" then return v end
            local out = {}
            for tk, tv in pairs(v) do out[tk] = cloneDefault(tv) end
            return out
        end
        for k, v in pairs(defaults) do
            VD[k] = cloneDefault(v)
        end

        -- Keep runtime persistence preferences synchronized with the reset values.
        MAWWW_Config.AutoSaveEnabled = VD.Config_AutoSaveEnabled ~= false
        MAWWW_Config.AutoLoadEnabled = VD.Config_AutoLoadEnabled ~= false
        MAWWW_Config.AutoSaveInterval = clampConfigInterval(VD.Config_AutoSaveInterval)
        pcall(MAWWW_Config.SavePrefs)

        for vdKey, elem in pairs(VD_Elements) do
            if elem and VD[vdKey] ~= nil then
                pcall(function()
                    if type(elem.SetValue) == "function" then
                        elem:SetValue(VD[vdKey])
                    end
                end)
            end
        end

        pcall(function()
            if AutoParryModule and AutoParryModule.EnsureRaycastParry then
                AutoParryModule.EnsureRaycastParry()
            end
        end)

        notify("Config", "Semua setting di-reset ke default.", 4)
    end
)


RegDivider(Tabs.UIKeybinds)
RegLabel(Tabs.UIKeybinds, "Quick Keybinds")
function MAWWW_SafeKeybind(config)
    if not Tabs.UIKeybinds then return nil end
    local ok, obj = pcall(function() return Tabs.UIKeybinds:Keybind(config) end)
    if ok and obj then return obj end

    -- Obsidian compatibility on the initial key field (`Value` vs `Default`).
    -- Retry transparently with the current API spelling.
    if config and config.Default ~= nil and config.Value == nil then
        local retryConfig = {}
        for k, v in pairs(config) do retryConfig[k] = v end
        retryConfig.Value = retryConfig.Default
        retryConfig.Default = nil
        local ok2, obj2 = pcall(function() return Tabs.UIKeybinds:Keybind(retryConfig) end)
        if ok2 and obj2 then return obj2 end
        obj = obj2 or obj
    end

    warn("[Mawww Hub] Keybind failed:", config and config.Title, obj)
    return nil
end

MAWWW_SafeKeybind({
    Title = "Moonwalk Toggle", Flag = "MoonwalkKey", Default = "M",
    Callback = function(v)
        VD.Moonwalk = v
        if v then
            if getgenv().MAWWW_StartMoonwalk then getgenv().MAWWW_StartMoonwalk() end
        else
            local h = getHum(); if h then h.AutoRotate = true; h.WalkSpeed = 16 end
        end
        if getgenv().MAWWW_QuickRefresh then pcall(getgenv().MAWWW_QuickRefresh) end
        notify("Moonwalk", v and "ON" or "OFF", 2)
    end,
})

MAWWW_SafeKeybind({
    Title = "Gen Boost Toggle", Flag = "GenBoostKey", Default = "G",
    Callback = function(v)
        if getgenv().MAWWW and getgenv().MAWWW.setGenBypass then getgenv().MAWWW.setGenBypass(v)
        else VD.GenBoost = v end
        if getgenv().MAWWW_QuickRefresh then pcall(getgenv().MAWWW_QuickRefresh) end
        notify("Gen Boost", v and "ON — auto repair aktif" or "OFF", 3)
    end,
})

MAWWW_SafeKeybind({
    Title = "Infinite Myers Toggle", Flag = "InfiniteMyersKey", Default = "I",
    Callback = function(v)
        VD.KillerInfGrab = v
        if getgenv().MAWWW_QuickRefresh then pcall(getgenv().MAWWW_QuickRefresh) end
        notify("Infinite Myers", v and "ON — Infinite Grab aktif" or "OFF", 2)
    end,
})

MAWWW_SafeKeybind({
    Title = "Bypass Skill Toggle", Flag = "BypassSkillKey", Default = "B",
    Callback = function(v)
        if getgenv().MAWWW_SetAllKillerNoCooldown then
            getgenv().MAWWW_SetAllKillerNoCooldown(v)
        else
            VD.KillerBypassSkill = v
        end
        if getgenv().MAWWW_QuickRefresh then pcall(getgenv().MAWWW_QuickRefresh) end
        notify("Bypass Skill", v and "ON — All Killer Bypass" or "OFF", 2)
    end,
})

MAWWW_SafeKeybind({
    Title = "Myers Grab", Flag = "MyersGrabKey", Default = "H",
    Callback = function()
        if MyersGrabData and MyersGrabData.Enabled then
            doMyersGrab()
        else
            notify("Myers Grab", "Enable 'Bypass Skill (All Killers)' first.", 3)
        end
    end,
})

--========================================================--
-- CURRENT UI FINALIZATION
--========================================================--

-- Preserve the current UI's Settings > Interface block and dedicated UI Settings controls.

-- Auto-load / first-run persistence.
pcall(function()
    local defaultPath = CONFIG_FOLDER .. "/default.json"
    local loaded = false
    local defaultExists = false

    pcall(function()
        if type(isfile) == "function" and type(readfile) == "function" then
            defaultExists = isfile(defaultPath) == true
        end
    end)

    if MAWWW_Config.AutoLoadEnabled and defaultExists then
        loaded = MAWWW_Config.Load("default") == true

        if loaded then
            pcall(function()
                local raw = readfile(defaultPath)
                if type(raw) == "string" then
                    MAWWW_Config._lastAutoSave = raw
                end
            end)
        end
    end

    -- First run, missing profile, or a profile that failed validation.
    if MAWWW_Config.AutoSaveEnabled and MAWWW_Config.AutoLoadEnabled and not loaded then
        pcall(function()
            MAWWW_Config.AutoSave(true)
        end)
    end

    -- Apply the final persistence preference values after a config load so they
    -- remain controlled by the dedicated _prefs.json file.
    VD.Config_AutoSaveEnabled = MAWWW_Config.AutoSaveEnabled == true
    VD.Config_AutoLoadEnabled = MAWWW_Config.AutoLoadEnabled == true
    VD.Config_AutoSaveInterval = clampConfigInterval(MAWWW_Config.AutoSaveInterval)

    if MAWWW_Config.AutoSaveEnabled then
        pcall(function() MAWWW_Config.StartAutoSave() end)
    end
end)

-- Force one final silent save when the script is being torn down.
pcall(function()
    if type(game) == "userdata" and type(game.BindToClose) == "function" then
        game:BindToClose(function()
            pcall(function() MAWWW_Config.AutoSave(true) end)
            MAWWW_Config._autoSaveRunning = false
        end)
    end
end)

-- Save current settings immediately before hiding/closing the UI.
pcall(function()
    if CloseButton and CloseButton.MouseButton1Click then
        CloseButton.MouseButton1Click:Connect(function()
            pcall(function() MAWWW_Config.AutoSave(true) end)
        end)
    end
end)

-- Apply the final loaded state to Stun Indicator after config auto-load.
pcall(function()
    if getgenv().MAWWW_ApplyStunIndicatorConfig then
        getgenv().MAWWW_ApplyStunIndicatorConfig()
    end
end)

-- Select Settings after all feature pages are registered.
--========================================================--
-- REPLACED: FIXED FOV 90
-- Source: fovlayar90.lua.txt
-- No standalone UI; always enforces FOV 90.
--========================================================--
do
    VD.CAM_FOVEnabled = true
    VD.CAM_FOV = 90

    local function applyFixedFOV()
        local camera = Workspace.CurrentCamera
        if camera then
            camera.FieldOfView = 90
        end
    end

    applyFixedFOV()

    RunService.RenderStepped:Connect(function()
        if VD.Destroyed then return end
        local camera = Workspace.CurrentCamera
        if camera and math.abs(camera.FieldOfView - 90) > 0.1 then
            camera.FieldOfView = 90
        end
    end)

    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if not VD.Destroyed then
            applyFixedFOV()
        end
    end)
end

VDUI:SelectTab("Settings")

-- Final layout stabilizer: nested GroupBoxes may settle over multiple render frames.
-- Refreshing at a low rate guarantees the Aim tab CanvasSize stays in sync with its
-- real rendered GroupBox bounds, including the last Silent Aim Key row.
local layoutAlive = true
task.delay(4, function() layoutAlive = false end)
RunService.Heartbeat:Connect(function()
    if not ScreenGui.Parent then return end
    if not layoutAlive then return end
    for _, pageData in pairs(pages) do
        if pageData and pageData.RefreshLayout then
            pcall(pageData.RefreshLayout)
        end
    end
end)

_G.VDUI = VDUI
getgenv().MAWWW_VDUI = VDUI
getgenv().MAWWW_MawwwHub_Library = Library

--// Animated blue <-> purple neon accent
animatedObjects = {
    AccentLine,
    Logo,
    BackgroundImage,
    CloseButton,
    MinimizeButton,
    OpenButton,
}

for _, tab in pairs(VDUI.Tabs) do
    table.insert(animatedObjects, tab.indicator)
end

for _, obj in ipairs(animatedObjects) do
    if obj and obj:IsA("GuiObject") then
        obj.ClipsDescendants = false
    end
end

backgroundConnection = nil
local BackgroundLastUpdate = 0
backgroundConnection = RunService.RenderStepped:Connect(function()
    if not ScreenGui.Parent or not ScreenGui.Enabled then
        return
    end
    local t = os.clock()
    if t - BackgroundLastUpdate < 0.10 then return end
    BackgroundLastUpdate = t
    BackgroundGradient.Rotation = 25 + math.sin(t * 0.35) * 25
    local shift = (math.sin(t * 0.55) + 1) / 2
    BackgroundGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromHSV(0.62 + shift * 0.03, 0.70, 0.32)),
        ColorSequenceKeypoint.new(0.50, Color3.fromHSV(0.66 + shift * 0.05, 0.58, 0.18)),
        ColorSequenceKeypoint.new(1, Color3.fromHSV(0.76 + shift * 0.04, 0.65, 0.35)),
    })
end)

pulseConnection = nil
pulseAccumulator = 0
local MAWWW_UIStrokeCache = {}
local function RebuildMawwwUIStrokeCache()
    for i = #MAWWW_UIStrokeCache, 1, -1 do
        MAWWW_UIStrokeCache[i] = nil
    end
    if not ScreenGui or not ScreenGui.Parent then return end
    for _, obj in ipairs(ScreenGui:GetDescendants()) do
        if obj:IsA("UIStroke") then
            MAWWW_UIStrokeCache[#MAWWW_UIStrokeCache + 1] = obj
        end
    end
end
RebuildMawwwUIStrokeCache()

ScreenGui.DescendantAdded:Connect(function(obj)
    if obj:IsA("UIStroke") then
        MAWWW_UIStrokeCache[#MAWWW_UIStrokeCache + 1] = obj
    end
end)
ScreenGui.DescendantRemoving:Connect(function(obj)
    if not obj:IsA("UIStroke") then return end
    for i = #MAWWW_UIStrokeCache, 1, -1 do
        if MAWWW_UIStrokeCache[i] == obj then
            table.remove(MAWWW_UIStrokeCache, i)
            break
        end
    end
end)

pulseConnection = RunService.RenderStepped:Connect(function(deltaTime)
    if not ScreenGui.Parent or not ScreenGui.Enabled or (not Main.Visible and not KeyGate.Visible) then
        return
    end

    pulseAccumulator = pulseAccumulator + deltaTime
    if pulseAccumulator < 0.10 then
        return
    end
    pulseAccumulator = 0

    local t = os.clock()
    local wave = (math.sin(t * 2.35) + 1) / 2
    local hue = 0.61 + (0.15 * wave)
    local neon = Color3.fromHSV(hue, 0.86, 1)
    local soft = Color3.fromHSV(hue, 0.64, 0.92)

    Theme.Accent = neon
    Theme.Accent2 = soft
    Theme.Slider = neon

    AccentLine.BackgroundColor3 = neon
    Logo.BackgroundColor3 = Color3.fromRGB(20, 23, 39)
    if SidebarPhoto then
        SidebarPhoto.BackgroundColor3 = Color3.fromRGB(20, 23, 39)
    end

    for i = #MAWWW_UIStrokeCache, 1, -1 do
        local obj = MAWWW_UIStrokeCache[i]
        if obj and obj.Parent then
            obj.Color = (wave > 0.52) and neon or soft
        else
            table.remove(MAWWW_UIStrokeCache, i)
        end
    end
    if OpenButton and OpenButton.Parent then
        OpenButton.ImageColor3 = Theme.Text
    end

    for _, tab in pairs(VDUI.Tabs) do
        if tab.indicator then tab.indicator.BackgroundColor3 = neon end
        if tab.frame then tab.frame.ScrollBarImageColor3 = soft end
    end
end)

-- Persistent layout stabilizer.  Recalculate the visible page every 0.20 s so
-- GroupBox size changes (config load, mobile resize, dropdown state) cannot leave
-- the last control underneath the next GroupBox.
local MAWWW_LayoutAccumulator = 0
local MAWWW_LayoutConnection
MAWWW_LayoutConnection = RunService.Heartbeat:Connect(function(dt)
    if not ScreenGui.Parent then
        return
    end
    MAWWW_LayoutAccumulator = MAWWW_LayoutAccumulator + (dt or 0)
    if MAWWW_LayoutAccumulator < 0.20 then return end
    MAWWW_LayoutAccumulator = 0
    local currentName = currentPage and currentPage.Name
    local pageKey = currentName and currentName:gsub("Page$", "") or nil
    local pd = pageKey and pages[pageKey] or nil
    if pd and pd.RefreshLayout then pcall(pd.RefreshLayout) end
end)

-- Persistent UI watchdog. The hub is hosted outside PlayerGui when the executor
-- provides gethui(), and this guard repairs parent/enabled state after loading,
-- respawn, or game-side PlayerGui resets. It does not override the user's close
-- or minimize choice.
local MAWWW_UIRepairAccumulator = 0
local MAWWW_UIRepairConnection
MAWWW_UIRepairConnection = RunService.Heartbeat:Connect(function(dt)
    MAWWW_UIRepairAccumulator = MAWWW_UIRepairAccumulator + (dt or 0)
    if MAWWW_UIRepairAccumulator < 0.50 then return end
    MAWWW_UIRepairAccumulator = 0

    local preferred = getMawwwGuiParent()
    if preferred then
        if ScreenGui.Parent ~= preferred then
            pcall(function() ScreenGui.Parent = preferred end)
        end
        if PopupLayer.Parent ~= preferred then
            pcall(function() PopupLayer.Parent = preferred end)
        end
    end

    pcall(function() ScreenGui.Enabled = true end)
    pcall(function() PopupLayer.Enabled = true end)

    if KeyGate and KeyGate.Parent then
        if KeyGate.Visible then
            Main.Visible = false
            OpenButton.Visible = false
        elseif MAWWW_UI_UNLOCKED == true then
            Main.Visible = MAWWW_UI_WANTED_VISIBLE == true
            OpenButton.Visible = not MAWWW_UI_WANTED_VISIBLE
        end
    end
end)

-- Re-attach after respawn as an extra immediate recovery path.
LocalPlayer.CharacterAdded:Connect(function()
    task.defer(function()
        pcall(function()
            local preferred = getMawwwGuiParent()
            if preferred then
                ScreenGui.Parent = preferred
                PopupLayer.Parent = preferred
            end
            ScreenGui.Enabled = true
            PopupLayer.Enabled = true
        end)
    end)
end)



--========================================================--
-- MEGA MERGE PATCH • GLUTO EXTRA: GATE BYPASS
-- Kept as a single reload-safe module so it does not duplicate
-- the existing Mawww/W424/K4N3K1/L2 engines.
--========================================================--
do
    local previousGateDestroy = getgenv().MAWWW_GateBypass_Destroy
    if previousGateDestroy then pcall(previousGateDestroy) end

    local GateBypass = getgenv().MAWWW_GateBypass or {
        Enabled = false,
        Cache = setmetatable({}, { __mode = "k" }),
        Connection = nil,
        DescendantConnection = nil,
    }
    getgenv().MAWWW_GateBypass = GateBypass

    local function gateRemember(obj, prop)
        GateBypass.Cache[obj] = GateBypass.Cache[obj] or {}
        local slot = GateBypass.Cache[obj]
        if slot[prop] == nil then
            local ok, value = pcall(function() return obj[prop] end)
            if ok then slot[prop] = value end
        end
    end

    local function gateSet(obj, prop, value)
        if not obj then return end
        gateRemember(obj, prop)
        pcall(function() obj[prop] = value end)
    end

    local function gateRestoreObject(obj)
        local saved = GateBypass.Cache[obj]
        if not saved or not obj or not obj.Parent then return end
        for prop, value in pairs(saved) do
            pcall(function() obj[prop] = value end)
        end
        GateBypass.Cache[obj] = nil
    end

    local function gateList()
        local result = {}
        local map = Workspace:FindFirstChild("Map")
        if not map then return result end
        for _, obj in ipairs(map:GetDescendants()) do
            if obj.Name == "Gate" then
                result[#result + 1] = obj
            end
        end
        return result
    end

    local function applyGateBypass()
        for _, gate in ipairs(gateList()) do
            local leftGate = gate:FindFirstChild("LeftGate")
            local rightGate = gate:FindFirstChild("RightGate")
            local leftEnd = gate:FindFirstChild("LeftGate-end")
            local rightEnd = gate:FindFirstChild("RightGate-end")
            local box = gate:FindFirstChild("Box")

            gateSet(leftGate, "Transparency", 1)
            gateSet(leftGate, "CanCollide", false)
            gateSet(rightGate, "Transparency", 1)
            gateSet(rightGate, "CanCollide", false)
            gateSet(leftEnd, "Transparency", 0)
            gateSet(leftEnd, "CanCollide", true)
            gateSet(rightEnd, "Transparency", 0)
            gateSet(rightEnd, "CanCollide", true)
            gateSet(box, "CanCollide", false)
        end
    end

    local function restoreGateBypass()
        for obj in pairs(GateBypass.Cache) do
            gateRestoreObject(obj)
        end
    end

    local function gateWatch()
        if GateBypass.Connection then
            pcall(function() GateBypass.Connection:Disconnect() end)
            GateBypass.Connection = nil
        end
        GateBypass.Connection = RunService.Heartbeat:Connect(function()
            if VD.Destroyed then return end
            if not GateBypass.Enabled then return end
            local now = os.clock()
            if GateBypass._lastApply and now - GateBypass._lastApply < 0.75 then return end
            GateBypass._lastApply = now
            pcall(applyGateBypass)
        end)
    end

    getgenv().MAWWW_SetGateBypass = function(state)
        GateBypass.Enabled = state == true
        VD.BypassGate = GateBypass.Enabled
        if GateBypass.Enabled then
            pcall(applyGateBypass)
        else
            pcall(restoreGateBypass)
        end
        if getgenv().MAWWW_QuickRefresh then
            pcall(getgenv().MAWWW_QuickRefresh)
        end
    end

    if VD.BypassGate == true then
        GateBypass.Enabled = true
        pcall(applyGateBypass)
    end
    gateWatch()

    if Tabs and Tabs.UtilityTeleport and RegToggle then
        RegToggle(
            Tabs.UtilityTeleport,
            "Bypass Gate",
            "Open the gate collision locally using the supplied Gluto gate routine.",
            VD.BypassGate == true,
            "BypassGate",
            function(v)
                getgenv().MAWWW_SetGateBypass(v)
            end
        )
    end

    if GateBypass.DescendantConnection then
        pcall(function() GateBypass.DescendantConnection:Disconnect() end)
    end
    GateBypass.DescendantConnection = Workspace.DescendantAdded:Connect(function(obj)
        if not GateBypass.Enabled or VD.Destroyed then return end
        if obj.Name == "Gate" then
            task.defer(applyGateBypass)
        end
    end)

    getgenv().MAWWW_GateBypass_Destroy = function()
        GateBypass.Enabled = false
        if GateBypass.Connection then pcall(function() GateBypass.Connection:Disconnect() end) end
        if GateBypass.DescendantConnection then pcall(function() GateBypass.DescendantConnection:Disconnect() end) end
        GateBypass.Connection = nil
        GateBypass.DescendantConnection = nil
        pcall(restoreGateBypass)
        GateBypass._destroyed = true
    end

    task.spawn(function()
        while not VD.Destroyed and not GateBypass._destroyed do
            task.wait(1)
        end
        if VD.Destroyed then
            pcall(getgenv().MAWWW_GateBypass_Destroy)
        end
    end)
end

-- Final interaction normalization after every feature/control has been registered.
pcall(normalizeMainUIInteraction)

-- Expose API for later integration in the same environment.
_G.VDUI = VDUI
-- Register the currently active merged modules for the next reload.
pcall(function()
    local env = (getgenv and getgenv()) or _G
    env.MAWWW_ReplacedModules = {
        AutoDodgeSpear = SpearVeil,
        AutoFarmGenerator = env.MAWWW_AutoFarmGenerator,
    }
end)

return VDUI
