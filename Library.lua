local Library = {}
Library.Version = "1.0.0"
Library.Flags = {}

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

function Library:CreateWindow(options)
    options = options or {}

local LocalPlayer = Players.LocalPlayer

local LOGO_PNG_B64 = options.LogoBase64 or ""

local BRAND_NAME = options.Name or "UI Library"
local BRAND_DESC = options.Description or ""
local BRAND_VERSION = options.Version or "v1.0"

for _, oldName in ipairs({"UILibrary", "MacrOS_UI", "PastaCompleteUI"}) do
    local old = CoreGui:FindFirstChild(oldName)
    if old then old:Destroy() end
end

local function tryGetEnvFunction(name)
    local ok, fn = pcall(function()
        return _G[name]
    end)
    if ok and type(fn) == "function" then
        local ok2, result = pcall(fn)
        if ok2 and result then return result end
    end
    return nil
end

local function decodeBase64(encoded)
    if not encoded or encoded == "" then return nil end

    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local values = {}
    for index = 1, #alphabet do
        values[alphabet:sub(index, index)] = index - 1
    end

    local data = encoded:gsub("%s", "")
    if #data == 0 or #data % 4 ~= 0 then
        return nil
    end

    local output = {}

    for index = 1, #data, 4 do
        local c1 = data:sub(index, index)
        local c2 = data:sub(index + 1, index + 1)
        local c3 = data:sub(index + 2, index + 2)
        local c4 = data:sub(index + 3, index + 3)

        local v1 = values[c1]
        local v2 = values[c2]
        local v3 = values[c3]
        local v4 = values[c4]

        if v1 == nil or v2 == nil then return nil end
        if c3 ~= "=" and v3 == nil then return nil end
        if c4 ~= "=" and v4 == nil then return nil end
        if c3 == "=" and c4 ~= "=" then return nil end
        if index < #data - 3 and (c3 == "=" or c4 == "=") then return nil end

        v3 = v3 or 0
        v4 = v4 or 0

        local combined = v1 * 262144 + v2 * 4096 + v3 * 64 + v4

        output[#output + 1] = string.char(math.floor(combined / 65536) % 256)
        if c3 ~= "=" then
            output[#output + 1] = string.char(math.floor(combined / 256) % 256)
        end
        if c4 ~= "=" then
            output[#output + 1] = string.char(combined % 256)
        end
    end

    return table.concat(output)
end

local function resolveLogoAsset()
    if type(writefile) ~= "function" then
        return nil
    end
    if type(getcustomasset) ~= "function" then
        return nil
    end
    if LOGO_PNG_B64 == "" then
        return nil
    end

    local pngBytes = decodeBase64(LOGO_PNG_B64)
    if not pngBytes then return nil end

    local sig = string.char(137) .. "PNG" .. "\r\n" .. string.char(26) .. "\n"
    if pngBytes:sub(1, 8) ~= sig then
        return nil
    end

    if type(makefolder) == "function" then
        for _, folder in ipairs({
            "workspace",
            "workspace/UILibrary",
            "workspace/UILibrary/assets",
            "UILibrary",
            "UILibrary/assets",
        }) do
            pcall(makefolder, folder)
        end
    end

    local paths = {
        "workspace/UILibrary/assets/logo.png",
        "workspace\\UILibrary\\assets\\logo.png",
        "UILibrary/assets/logo.png",
        "UILibrary\\assets\\logo.png",
    }

    for _, path in ipairs(paths) do
        local okWrite = pcall(writefile, path, pngBytes)
        if okWrite then
            local okAsset, asset = pcall(getcustomasset, path)
            if okAsset and type(asset) == "string" and asset ~= "" then
                return asset
            end
        end
    end

    return nil
end

local LOGO_ASSET = resolveLogoAsset()

local targetParent = tryGetEnvFunction("gethui")
    or tryGetEnvFunction("run_secure")
    or CoreGui
    or LocalPlayer:WaitForChild("PlayerGui")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "UILibrary"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = targetParent

local CONNECTIONS = {}
local function trackConn(conn)
    table.insert(CONNECTIONS, conn)
    return conn
end
local isClosed = false
local unloadScript

local THEME = {
    Background    = Color3.fromRGB(12, 9, 11),
    CardBg        = Color3.fromRGB(18, 13, 16),
    PillBg        = Color3.fromRGB(16, 12, 14),
    SidebarActive = Color3.fromRGB(27, 16, 19),
    Border        = Color3.fromRGB(36, 24, 28),
    BorderActive  = Color3.fromRGB(90, 36, 42),
    Accent        = Color3.fromRGB(246, 92, 82),
    AccentSoft    = Color3.fromRGB(255, 165, 155),
    AccentDark    = Color3.fromRGB(130, 40, 42),
    TextPrimary   = Color3.fromRGB(235, 235, 235),
    TextMuted     = Color3.fromRGB(120, 110, 115),
    TextDim       = Color3.fromRGB(72, 64, 68),
    Divider       = Color3.fromRGB(48, 36, 40),
    BadgeBg       = Color3.fromRGB(25, 18, 22),
    ToggleOff     = Color3.fromRGB(36, 28, 32),
    KnobOff       = Color3.fromRGB(78, 68, 73),
    KnobOn        = Color3.fromRGB(255, 255, 255),
    VersionBg     = Color3.fromRGB(246, 92, 82),
    VersionText   = Color3.fromRGB(220, 225, 245),
    PopupBg       = Color3.fromRGB(24, 18, 20),
    BrandText     = Color3.fromRGB(200, 200, 200)
}

local ICONS = {
    Search   = "rbxassetid://7733911828",
    Chevron  = "rbxassetid://7733717447",
    Menu     = "rbxassetid://7733993211",
    Combat   = "rbxassetid://7734053426",
    Movement = "rbxassetid://7733799901",
    Visuals  = "rbxassetid://7733774602",
    Player   = "rbxassetid://7733954760",
    Misc     = "rbxassetid://7734056411",
    Presets  = "rbxassetid://7733964719",
    AutoBuy  = "rbxassetid://7733942651",
    Accounts = "rbxassetid://7733765307",
    User     = "rbxassetid://7733954760",
    Chart    = "rbxassetid://7733749837",
    Clock    = "rbxassetid://7733734762",
    Compass  = "rbxassetid://7733720755",
    Signal   = "rbxassetid://7734058495",
    Radar    = "rbxassetid://7734053426",
    Speed    = "rbxassetid://7733799901"
}

local LUCIDE = {
    ["activity"]          = "rbxassetid://94212016861936",
    ["alert-triangle"]    = "rbxassetid://125920361880643",
    ["balloon"]           = "rbxassetid://97489111621526",
    ["blocks"]            = "rbxassetid://72212693357737",
    ["book"]              = "rbxassetid://125383279695672",
    ["bot"]               = "rbxassetid://80451686744860",
    ["box"]               = "rbxassetid://101768155599700",
    ["check"]             = "rbxassetid://93898873302694",
    ["chevron-down"]      = "rbxassetid://134243273101015",
    ["chevron-right"]     = "rbxassetid://92473583511724",
    ["chevron-up"]        = "rbxassetid://122444883127455",
    ["circle"]            = "rbxassetid://130359823580534",
    ["circle-check"]      = "rbxassetid://85262178816537",
    ["clipboard"]         = "rbxassetid://89601995828423",
    ["clipboard-paste"]   = "rbxassetid://74382068849983",
    ["clock"]             = "rbxassetid://121808839832144",
    ["cloud"]             = "rbxassetid://121226497050352",
    ["cog"]               = "rbxassetid://116544501716299",
    ["coins"]             = "rbxassetid://116510979641930",
    ["copy"]              = "rbxassetid://78979572434545",
    ["crown"]             = "rbxassetid://127843403295538",
    ["download"]          = "rbxassetid://134814648082393",
    ["ellipsis-vertical"] = "rbxassetid://117978708573781",
    ["ethernet-port"]     = "rbxassetid://75391715149314",
    ["eye"]               = "rbxassetid://100033680381365",
    ["eye-off"]           = "rbxassetid://135928786788378",
    ["flask-conical"]     = "rbxassetid://128406680901165",
    ["folder-open"]       = "rbxassetid://76018996254888",
    ["gauge"]             = "rbxassetid://110273524101447",
    ["gem"]               = "rbxassetid://112904952151156",
    ["ghost"]             = "rbxassetid://113822048130017",
    ["gift"]              = "rbxassetid://109855212076373",
    ["grip"]              = "rbxassetid://109058783556768",
    ["hammer"]            = "rbxassetid://83545120140895",
    ["hand"]              = "rbxassetid://130703864968637",
    ["house"]             = "rbxassetid://98755624629571",
    ["image"]             = "rbxassetid://112751259236831",
    ["infinity"]          = "rbxassetid://98083086936965",
    ["inflate"]           = "rbxassetid://97489111621526",
    ["info"]              = "rbxassetid://124560466474914",
    ["keyboard"]          = "rbxassetid://121474456068237",
    ["languages"]         = "rbxassetid://90816903776498",
    ["layers"]            = "rbxassetid://81973586053257",
    ["list-checks"]       = "rbxassetid://99809353635593",
    ["loader-circle"]     = "rbxassetid://116535712789945",
    ["lock"]              = "rbxassetid://134724289526879",
    ["log-out"]           = "rbxassetid://84895399304975",
    ["map-pin"]           = "rbxassetid://84279202219901",
    ["menu"]              = "rbxassetid://77021539815611",
    ["message-circle"]    = "rbxassetid://127255077587058",
    ["message-square"]    = "rbxassetid://83881670383280",
    ["minus"]             = "rbxassetid://118026365011536",
    ["monitor"]           = "rbxassetid://72664649203050",
    ["move"]              = "rbxassetid://116138709011735",
    ["package"]           = "rbxassetid://97261141732706",
    ["palette"]           = "rbxassetid://86350350950064",
    ["pause"]             = "rbxassetid://74873705394436",
    ["play"]              = "rbxassetid://135609604299893",
    ["plus"]              = "rbxassetid://111774323017047",
    ["power"]             = "rbxassetid://96479131758775",
    ["refresh-cw"]        = "rbxassetid://138133190015277",
    ["repeat"]            = "rbxassetid://121886242955173",
    ["rotate-ccw"]        = "rbxassetid://110116685948665",
    ["rotate-cw"]         = "rbxassetid://84183336178654",
    ["save"]              = "rbxassetid://126116963775616",
    ["scroll-text"]       = "rbxassetid://97321022666868",
    ["search"]            = "rbxassetid://121018724060431",
    ["send"]              = "rbxassetid://127751956873796",
    ["settings"]          = "rbxassetid://80758916183665",
    ["shapes"]            = "rbxassetid://129989433311409",
    ["ship"]              = "rbxassetid://83995100553930",
    ["shopping-bag"]      = "rbxassetid://71885477293226",
    ["shopping-cart"]     = "rbxassetid://128420521375441",
    ["shuffle"]           = "rbxassetid://132382786975101",
    ["skull"]             = "rbxassetid://137726256442333",
    ["square"]            = "rbxassetid://86304921356806",
    ["store"]             = "rbxassetid://90338129673705",
    ["tag"]               = "rbxassetid://129104970103940",
    ["trash-2"]           = "rbxassetid://109843431391323",
    ["triangle-alert"]    = "rbxassetid://125920361880643",
    ["type"]              = "rbxassetid://133543553793564",
    ["user"]              = "rbxassetid://81589895647169",
    ["users"]             = "rbxassetid://115398113982385",
    ["webhook"]           = "rbxassetid://112812457747322",
    ["wind"]              = "rbxassetid://114551690399915",
    ["wrench"]            = "rbxassetid://112148279212860",
    ["x"]                 = "rbxassetid://110786993356448",
    ["zap"]               = "rbxassetid://130551565616516"
}

local TWEEN_FAST = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_SLOW = TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

local COLOR_BINDINGS = {}
local ACTIVE_TWEENS = {}

local function resolveToken(keyOrFn)
    if type(keyOrFn) == "function" then
        return keyOrFn()
    end
    return keyOrFn
end

local function bindColor(inst, prop, keyOrFn, skipApply)
    local byInst = COLOR_BINDINGS[inst]
    if not byInst then
        byInst = {}
        COLOR_BINDINGS[inst] = byInst
    end
    byInst[prop] = keyOrFn
    if not skipApply then
        inst[prop] = THEME[resolveToken(keyOrFn)]
    end
    return inst
end

local function tweenColors(inst, info, goal)
    local realGoal = {}
    for prop, value in pairs(goal) do
        if type(value) == "string" then
            bindColor(inst, prop, value, true)
            realGoal[prop] = THEME[value]
        else
            realGoal[prop] = value
        end
    end
    local tween = TweenService:Create(inst, info, realGoal)
    table.insert(ACTIVE_TWEENS, tween)
    if #ACTIVE_TWEENS > 300 then
        table.remove(ACTIVE_TWEENS, 1)
    end
    return tween
end

local function refreshTheme()
    for _, tween in ipairs(ACTIVE_TWEENS) do
        pcall(function() tween:Cancel() end)
    end
    ACTIVE_TWEENS = {}

    for inst, props in pairs(COLOR_BINDINGS) do
        if inst.Parent == nil then
            COLOR_BINDINGS[inst] = nil
        else
            for prop, keyOrFn in pairs(props) do
                local color = THEME[resolveToken(keyOrFn)]
                if color then
                    pcall(function() inst[prop] = color end)
                end
            end
        end
    end
end

local Main = Instance.new("Frame")
Main.Name = "MainFrame"
Main.Size = UDim2.new(0, 790, 0, 490)
Main.Position = UDim2.new(0.5, -395, 0.5, -245)
bindColor(Main, "BackgroundColor3", "Background")
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = ScreenGui

local UI_SCALE = 1
local UI_SCALE_MIN, UI_SCALE_MAX = 0.6, 2.0
local BASE_W, BASE_H = 790, 490
local mainScale = Instance.new("UIScale")
mainScale.Scale = UI_SCALE
mainScale.Parent = Main

local function scalePopup(popup)
    local sc = Instance.new("UIScale")
    sc.Scale = UI_SCALE
    sc.Parent = popup
    return popup
end

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
bindColor(MainStroke, "Color", "Border")
MainStroke.Thickness = 1.2
MainStroke.Parent = Main

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 56)
TopBar.BackgroundTransparency = 1
TopBar.Active = true
TopBar.Parent = Main

do
    local dragging, dragStart, startPos
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
        end
    end)
    trackConn(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            TweenService:Create(Main, TweenInfo.new(0.04), {
                Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            }):Play()
        end
    end))
    trackConn(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))
end

local BrandBlock = Instance.new("Frame")
BrandBlock.Name = "BrandBlock"
BrandBlock.Size = UDim2.new(0, 240, 1, 0)
BrandBlock.Position = UDim2.new(0, 14, 0, 0)
BrandBlock.BackgroundTransparency = 1
BrandBlock.Parent = TopBar

local BrandLayout = Instance.new("UIListLayout")
BrandLayout.FillDirection = Enum.FillDirection.Horizontal
BrandLayout.SortOrder = Enum.SortOrder.LayoutOrder
BrandLayout.VerticalAlignment = Enum.VerticalAlignment.Center
BrandLayout.Padding = UDim.new(0, 10)
BrandLayout.Parent = BrandBlock

local BrandIcon = Instance.new("ImageLabel")
BrandIcon.Name = "BrandIcon"
BrandIcon.Size = UDim2.new(0, 34, 0, 34)
BrandIcon.BackgroundTransparency = 1
BrandIcon.LayoutOrder = 1
BrandIcon.Image = LOGO_ASSET or ""
BrandIcon.ScaleType = Enum.ScaleType.Fit
BrandIcon.Visible = LOGO_ASSET ~= nil
BrandIcon.Parent = BrandBlock

local BrandTextCol = Instance.new("Frame")
BrandTextCol.Name = "BrandTextCol"
BrandTextCol.Size = UDim2.new(0, 0, 0, 32)
BrandTextCol.AutomaticSize = Enum.AutomaticSize.X
BrandTextCol.BackgroundTransparency = 1
BrandTextCol.LayoutOrder = 2
BrandTextCol.Parent = BrandBlock

local BrandTextLayout = Instance.new("UIListLayout")
BrandTextLayout.FillDirection = Enum.FillDirection.Vertical
BrandTextLayout.SortOrder = Enum.SortOrder.LayoutOrder
BrandTextLayout.VerticalAlignment = Enum.VerticalAlignment.Center
BrandTextLayout.Padding = UDim.new(0, 0)
BrandTextLayout.Parent = BrandTextCol

local BrandName = Instance.new("TextLabel")
BrandName.Name = "BrandName"
BrandName.Size = UDim2.new(0, 0, 0, 18)
BrandName.AutomaticSize = Enum.AutomaticSize.X
BrandName.BackgroundTransparency = 1
BrandName.Text = BRAND_NAME
BrandName.Font = Enum.Font.GothamBold
BrandName.TextSize = 15
bindColor(BrandName, "TextColor3", "BrandText")
BrandName.TextXAlignment = Enum.TextXAlignment.Left
BrandName.LayoutOrder = 1
BrandName.Parent = BrandTextCol

local BrandDesc = Instance.new("TextLabel")
BrandDesc.Name = "BrandDesc"
BrandDesc.Size = UDim2.new(0, 0, 0, 13)
BrandDesc.AutomaticSize = Enum.AutomaticSize.X
BrandDesc.BackgroundTransparency = 1
BrandDesc.Text = BRAND_DESC
BrandDesc.Visible = BRAND_DESC ~= ""
BrandDesc.Font = Enum.Font.Gotham
BrandDesc.TextSize = 10
bindColor(BrandDesc, "TextColor3", "TextDim")
BrandDesc.TextXAlignment = Enum.TextXAlignment.Left
BrandDesc.LayoutOrder = 2
BrandDesc.Parent = BrandTextCol

local BrandVersion = Instance.new("TextLabel")
BrandVersion.Name = "BrandVersion"
BrandVersion.Size = UDim2.new(0, 38, 0, 20)
bindColor(BrandVersion, "BackgroundColor3", "VersionBg")
BrandVersion.Text = BRAND_VERSION
BrandVersion.Font = Enum.Font.GothamBold
BrandVersion.TextSize = 10
bindColor(BrandVersion, "TextColor3", "VersionText")
BrandVersion.TextXAlignment = Enum.TextXAlignment.Center
BrandVersion.LayoutOrder = 3
BrandVersion.Parent = BrandBlock

local BrandVersionCorner = Instance.new("UICorner")
BrandVersionCorner.CornerRadius = UDim.new(1, 0)
BrandVersionCorner.Parent = BrandVersion

local BrandVersionStroke = Instance.new("UIStroke")
bindColor(BrandVersionStroke, "Color", "Accent")
BrandVersionStroke.Thickness = 1
BrandVersionStroke.Transparency = 0.3
BrandVersionStroke.Parent = BrandVersion

local SearchBox = Instance.new("Frame")
SearchBox.Name = "SearchBox"
SearchBox.Size = UDim2.new(0, 180, 0, 26)
SearchBox.Position = UDim2.new(1, -248, 0.5, -13)
bindColor(SearchBox, "BackgroundColor3", "CardBg")
SearchBox.BorderSizePixel = 0
SearchBox.Parent = TopBar

local SearchCorner = Instance.new("UICorner")
SearchCorner.CornerRadius = UDim.new(0, 6)
SearchCorner.Parent = SearchBox

local SearchStroke = Instance.new("UIStroke")
bindColor(SearchStroke, "Color", "Border")
SearchStroke.Thickness = 0.8
SearchStroke.Parent = SearchBox

local SearchIcon = Instance.new("ImageLabel")
SearchIcon.Name = "SearchIcon"
SearchIcon.Size = UDim2.new(0, 13, 0, 13)
SearchIcon.Position = UDim2.new(0, 9, 0.5, -6.5)
SearchIcon.BackgroundTransparency = 1
SearchIcon.Image = ICONS.Search
bindColor(SearchIcon, "ImageColor3", "TextMuted")
SearchIcon.Parent = SearchBox

local SearchInput = Instance.new("TextBox")
SearchInput.Name = "SearchInput"
SearchInput.PlaceholderText = "Search something"
bindColor(SearchInput, "PlaceholderColor3", "TextMuted")
SearchInput.Text = ""
bindColor(SearchInput, "TextColor3", "TextPrimary")
SearchInput.Font = Enum.Font.Gotham
SearchInput.TextSize = 11
SearchInput.Position = UDim2.new(0, 30, 0, 0)
SearchInput.Size = UDim2.new(1, -36, 1, 0)
SearchInput.BackgroundTransparency = 1
SearchInput.TextXAlignment = Enum.TextXAlignment.Left
SearchInput.ClearTextOnFocus = false
SearchInput.Parent = SearchBox

local CloseBtn = Instance.new("ImageButton")
CloseBtn.Name = "CloseButton"
CloseBtn.Size = UDim2.new(0, 17, 0, 17)
CloseBtn.Position = UDim2.new(1, -32, 0.5, -8.5)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Image = LUCIDE["x"]
bindColor(CloseBtn, "ImageColor3", "TextMuted")
CloseBtn.Parent = TopBar

CloseBtn.MouseEnter:Connect(function()
    tweenColors(CloseBtn, TWEEN_FAST, {ImageColor3 = "TextPrimary"}):Play()
end)
CloseBtn.MouseLeave:Connect(function()
    tweenColors(CloseBtn, TWEEN_FAST, {ImageColor3 = "TextMuted"}):Play()
end)
CloseBtn.MouseButton1Click:Connect(function()
    unloadScript()
end)

local Sidebar = Instance.new("ScrollingFrame")
Sidebar.Size = UDim2.new(0, 155, 1, -58)
Sidebar.Position = UDim2.new(0, 14, 0, 54)
Sidebar.BackgroundTransparency = 1
Sidebar.BorderSizePixel = 0
Sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
Sidebar.ScrollingDirection = Enum.ScrollingDirection.Y
Sidebar.ScrollBarThickness = 3
bindColor(Sidebar, "ScrollBarImageColor3", "TextDim")
Sidebar.Parent = Main

local SideList = Instance.new("UIListLayout")
SideList.Padding = UDim.new(0, 2)
SideList.SortOrder = Enum.SortOrder.LayoutOrder
SideList.Parent = Sidebar

local activeSidebarTab = nil

local TAB_ACTIVATORS = {}
local showTabContent

local currentSection = nil
local SECTIONS = {}

local function setSectionCollapsed(section, collapsed)
    section.Collapsed = collapsed and true or false
    for _, itemBtn in ipairs(section.Items) do
        itemBtn.Visible = not section.Collapsed
    end
    local targetRotation = section.Collapsed and -90 or 0
    TweenService:Create(section.Chevron, TWEEN_FAST, {Rotation = targetRotation}):Play()
end

local function addCategory(name, order, collapsed)
    local header = Instance.new("TextButton")
    header.Size = UDim2.new(1, -4, 0, 20)
    header.LayoutOrder = order
    header.BackgroundTransparency = 1
    header.Text = "   " .. name:upper()
    header.Font = Enum.Font.GothamBold
    header.TextSize = 9
    bindColor(header, "TextColor3", "TextDim")
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.AutoButtonColor = false
    header.Parent = Sidebar

    local chevron = Instance.new("ImageLabel")
    chevron.Size = UDim2.new(0, 10, 0, 10)
    chevron.Position = UDim2.new(1, -18, 0.5, -5)
    chevron.BackgroundTransparency = 1
    chevron.Image = LUCIDE["chevron-down"]
    bindColor(chevron, "ImageColor3", "TextDim")
    chevron.Parent = header

    local section = {Name = name, Items = {}, Chevron = chevron, Collapsed = false}
    table.insert(SECTIONS, section)
    currentSection = section

    header.MouseButton1Click:Connect(function()
        setSectionCollapsed(section, not section.Collapsed)
    end)
    header.MouseEnter:Connect(function()
        tweenColors(header, TWEEN_FAST, {TextColor3 = "TextMuted"}):Play()
    end)
    header.MouseLeave:Connect(function()
        tweenColors(header, TWEEN_FAST, {TextColor3 = "TextDim"}):Play()
    end)

    local handle = {}
    function handle.Collapse() setSectionCollapsed(section, true) end
    function handle.Expand() setSectionCollapsed(section, false) end
    function handle.Toggle() setSectionCollapsed(section, not section.Collapsed) end
    function handle.IsCollapsed() return section.Collapsed end
    section.Handle = handle

    if collapsed then
        setSectionCollapsed(section, true)
    end
    return handle
end

local function addSidebarItem(name, iconId, isDefaultActive, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -4, 0, 29)
    btn.LayoutOrder = order
    bindColor(btn, "BackgroundColor3", function() return (isDefaultActive) and "SidebarActive" or "Background" end)
    btn.BackgroundTransparency = isDefaultActive and 0 or 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = Sidebar
    if currentSection then
        table.insert(currentSection.Items, btn)
        btn.Visible = not currentSection.Collapsed
    end

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn

    local stroke = Instance.new("UIStroke")
    bindColor(stroke, "Color", function() return isDefaultActive and "BorderActive" or "Background" end)
    stroke.Transparency = isDefaultActive and 0 or 1
    stroke.Thickness = 1
    stroke.Parent = btn

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 14, 0, 14)
    icon.Position = UDim2.new(0, 9, 0.5, -7)
    icon.BackgroundTransparency = 1
    icon.Image = iconId
    bindColor(icon, "ImageColor3", function() return (isDefaultActive) and "Accent" or "TextMuted" end)
    icon.Parent = btn

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -32, 1, 0)
    title.Position = UDim2.new(0, 30, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = name
    title.Font = Enum.Font.GothamMedium
    title.TextSize = 11
    bindColor(title, "TextColor3", function() return (isDefaultActive) and "TextPrimary" or "TextMuted" end)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = btn

    if isDefaultActive then
        activeSidebarTab = {Btn = btn, Icon = icon, Title = title, Stroke = stroke, Name = name}
    end

    btn.MouseEnter:Connect(function()
        if activeSidebarTab.Btn ~= btn then
            tweenColors(title, TWEEN_FAST, {TextColor3 = "TextPrimary"}):Play()
            tweenColors(icon, TWEEN_FAST, {ImageColor3 = "TextPrimary"}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeSidebarTab.Btn ~= btn then
            tweenColors(title, TWEEN_FAST, {TextColor3 = "TextMuted"}):Play()
            tweenColors(icon, TWEEN_FAST, {ImageColor3 = "TextMuted"}):Play()
        end
    end)

    local function activate()
        if activeSidebarTab.Btn == btn then return end

        TweenService:Create(activeSidebarTab.Btn, TWEEN_FAST, {BackgroundTransparency = 1}):Play()
        TweenService:Create(activeSidebarTab.Stroke, TWEEN_FAST, {Transparency = 1}):Play()
        tweenColors(activeSidebarTab.Icon, TWEEN_FAST, {ImageColor3 = "TextMuted"}):Play()
        tweenColors(activeSidebarTab.Title, TWEEN_FAST, {TextColor3 = "TextMuted"}):Play()

        tweenColors(btn, TWEEN_FAST, {BackgroundTransparency = 0, BackgroundColor3 = "SidebarActive"}):Play()
        tweenColors(stroke, TWEEN_FAST, {Transparency = 0, Color = "BorderActive"}):Play()
        tweenColors(icon, TWEEN_FAST, {ImageColor3 = "Accent"}):Play()
        tweenColors(title, TWEEN_FAST, {TextColor3 = "TextPrimary"}):Play()

        activeSidebarTab = {Btn = btn, Icon = icon, Title = title, Stroke = stroke, Name = name}
        showTabContent(name)
    end
    btn.MouseButton1Click:Connect(activate)
    TAB_ACTIVATORS[name] = activate
end

local sidebarOrder = 0

local Footer = Instance.new("Frame")
Footer.Size = UDim2.new(0, 160, 0, 28)
Footer.Position = UDim2.new(0, 18, 1, -38)
Footer.BackgroundTransparency = 1
Footer.Parent = Main

local UserLabel = Instance.new("TextLabel")
UserLabel.Size = UDim2.new(1, 0, 0, 13)
UserLabel.BackgroundTransparency = 1
UserLabel.Text = string.lower(LocalPlayer.Name)
UserLabel.Font = Enum.Font.GothamBold
UserLabel.TextSize = 10
bindColor(UserLabel, "TextColor3", "TextMuted")
UserLabel.TextXAlignment = Enum.TextXAlignment.Left
UserLabel.Parent = Footer

local SubLabel = Instance.new("TextLabel")
SubLabel.Size = UDim2.new(1, 0, 0, 11)
SubLabel.Position = UDim2.new(0, 0, 0, 13)
SubLabel.BackgroundTransparency = 1
SubLabel.Text = options.FooterText or ""
SubLabel.Font = Enum.Font.Gotham
SubLabel.TextSize = 7.5
bindColor(SubLabel, "TextColor3", "TextDim")
SubLabel.TextXAlignment = Enum.TextXAlignment.Left
SubLabel.Parent = Footer

local ContentWrapper = Instance.new("Frame")
ContentWrapper.Size = UDim2.new(1, -195, 1, -62)
ContentWrapper.Position = UDim2.new(0, 182, 0, 54)
ContentWrapper.BackgroundTransparency = 1
ContentWrapper.BorderSizePixel = 0
ContentWrapper.ClipsDescendants = true
ContentWrapper.Parent = Main

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, 0, 1, 0)
ContentArea.BackgroundTransparency = 1
ContentArea.ClipsDescendants = true
ContentArea.Parent = ContentWrapper

local Backdrop = Instance.new("Frame")
Backdrop.Size = UDim2.new(1, 0, 1, 0)
bindColor(Backdrop, "BackgroundColor3", "Background")
Backdrop.BorderSizePixel = 0
Backdrop.ZIndex = 1
Backdrop.Parent = ContentArea

local BackdropCorner = Instance.new("UICorner")
BackdropCorner.CornerRadius = UDim.new(0, 8)
BackdropCorner.Parent = Backdrop

local Col1 = Instance.new("ScrollingFrame")
Col1.Size = UDim2.new(0.485, 0, 1, 0)
Col1.BackgroundTransparency = 1
Col1.BorderSizePixel = 0
Col1.ScrollBarThickness = 0
Col1.CanvasSize = UDim2.new(0, 0, 0, 0)
Col1.ScrollingDirection = Enum.ScrollingDirection.Y
Col1.ClipsDescendants = true
Col1.ZIndex = 2
Col1.Parent = ContentArea

local Col2 = Instance.new("ScrollingFrame")
Col2.Size = UDim2.new(0.485, 0, 1, 0)
Col2.Position = UDim2.new(0.515, 0, 0, 0)
Col2.BackgroundTransparency = 1
Col2.BorderSizePixel = 0
Col2.ScrollBarThickness = 0
Col2.CanvasSize = UDim2.new(0, 0, 0, 0)
Col2.ScrollingDirection = Enum.ScrollingDirection.Y
Col2.ClipsDescendants = true
Col2.ZIndex = 2
Col2.Parent = ContentArea

local colLayouts = {}

for _, col in ipairs({Col1, Col2}) do
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 12)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = col

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 24)
    pad.PaddingLeft = UDim.new(0, 4)
    pad.PaddingRight = UDim.new(0, 4)
    pad.Parent = col

    table.insert(colLayouts, {Col = col, Layout = l})
end

local function updateCanvasSize(entry)
    local col = entry.Col
    local layout = entry.Layout
    local contentHeight = layout.AbsoluteContentSize.Y
    col.CanvasSize = UDim2.new(0, 0, 0, contentHeight + 8)
end

for _, entry in ipairs(colLayouts) do
    entry.Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        updateCanvasSize(entry)
    end)
    task.defer(function() updateCanvasSize(entry) end)
end

local CARD_INFO = {}
local CARD_LIST = {}

local emptyLabel = Instance.new("TextLabel")
emptyLabel.Name = "EmptyTab"
emptyLabel.Size = UDim2.new(1, 0, 0, 40)
emptyLabel.Position = UDim2.new(0, 0, 0, 60)
emptyLabel.BackgroundTransparency = 1
emptyLabel.Text = "Nothing here yet"
emptyLabel.Font = Enum.Font.GothamMedium
emptyLabel.TextSize = 12
bindColor(emptyLabel, "TextColor3", "TextDim")
emptyLabel.Visible = false
emptyLabel.ZIndex = 3
emptyLabel.Parent = ContentArea

showTabContent = function(tabName)
    local shown = 0
    for _, entry in ipairs(CARD_LIST) do
        local show = entry.Tab == tabName
        entry.Card.Visible = show
        if show then shown = shown + 1 end
    end
    emptyLabel.Visible = shown == 0
    for _, entry in ipairs(colLayouts) do
        entry.Col.CanvasPosition = Vector2.new(0, 0)
    end
end

local function createHStack(parent, padding, order)
    local stack = Instance.new("Frame")
    stack.Size = UDim2.new(1, 0, 0, 0)
    stack.AutomaticSize = Enum.AutomaticSize.Y
    stack.BackgroundTransparency = 1
    stack.LayoutOrder = order or 0
    stack.Parent = parent

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, padding or 6)
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Parent = stack

    return stack
end

local function createVStack(parent, padding, order)
    local stack = Instance.new("Frame")
    stack.Size = UDim2.new(1, 0, 0, 0)
    stack.AutomaticSize = Enum.AutomaticSize.Y
    stack.BackgroundTransparency = 1
    stack.LayoutOrder = order or 0
    stack.Parent = parent

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, padding or 6)
    layout.Parent = stack

    return stack
end

local function createCard(parent, titleText, order, tab)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    bindColor(card, "BackgroundColor3", "CardBg")
    card.BorderSizePixel = 0
    card.ClipsDescendants = false
    card.LayoutOrder = order
    card.ZIndex = 3
    card.Parent = parent
    CARD_INFO[card] = {Tab = tab, Title = titleText}
    table.insert(CARD_LIST, {Card = card, Tab = tab})

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = card

    local s = Instance.new("UIStroke")
    bindColor(s, "Color", "Border")
    s.Thickness = 0.8
    s.Parent = card

    local outerLayout = Instance.new("UIListLayout")
    outerLayout.Padding = UDim.new(0, 0)
    outerLayout.SortOrder = Enum.SortOrder.LayoutOrder
    outerLayout.Parent = card

    local outerPad = Instance.new("UIPadding")
    outerPad.PaddingTop = UDim.new(0, 11)
    outerPad.PaddingBottom = UDim.new(0, 13)
    outerPad.PaddingLeft = UDim.new(0, 12)
    outerPad.PaddingRight = UDim.new(0, 12)
    outerPad.Parent = card

    local header = Instance.new("TextButton")
    header.Size = UDim2.new(1, 0, 0, 18)
    header.BackgroundTransparency = 1
    header.Text = ""
    header.AutoButtonColor = false
    header.LayoutOrder = 0
    header.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = titleText
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    bindColor(title, "TextColor3", "TextPrimary")
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local arrow = Instance.new("ImageLabel")
    arrow.Size = UDim2.new(0, 12, 0, 12)
    arrow.Position = UDim2.new(1, -12, 0.5, -6)
    arrow.BackgroundTransparency = 1
    arrow.Image = ICONS.Chevron
    bindColor(arrow, "ImageColor3", "Accent")
    arrow.Rotation = 0
    arrow.Parent = header

    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, 0, 0, 0)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.BackgroundTransparency = 1
    body.LayoutOrder = 1
    body.Parent = card
    CARD_INFO[body] = CARD_INFO[card]

    local bodyLayout = Instance.new("UIListLayout")
    bodyLayout.Padding = UDim.new(0, 10)
    bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bodyLayout.Parent = body

    local bodyPad = Instance.new("UIPadding")
    bodyPad.PaddingTop = UDim.new(0, 10)
    bodyPad.Parent = body

    local isOpen = true

    header.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        body.Visible = isOpen
        arrow.Rotation = isOpen and 0 or -90
    end)

    return body
end

local DEFAULT_PALETTE = {}
for key, value in pairs(THEME) do
    DEFAULT_PALETTE[key] = value
end

local THEME_KEYS = {
    "Background", "CardBg", "PillBg", "SidebarActive", "Border", "BorderActive",
    "Accent", "AccentSoft", "AccentDark", "TextPrimary", "TextMuted", "TextDim",
    "Divider", "BadgeBg", "ToggleOff", "KnobOff", "KnobOn", "VersionBg",
    "VersionText", "PopupBg", "BrandText",
}

local THEME_PRESETS = {
    { Name = "Default", Default = true },
    { Name = "Dark",        Background = "#101010", Text = "#FFFFFF", Placeholder = "#a1a1a1", Icon = "#a1a1aa", Accent = "#0091FF" },
    { Name = "Light",       Background = "#FFFFFF", Text = "#000000", Placeholder = "#555555", Icon = "#52525b", Accent = "#0091FF" },
    { Name = "Rose",        Background = "#1f0308", Text = "#fdf2f8", Placeholder = "#d67aa6", Icon = "#fb7185", Accent = "#e95f74" },
    { Name = "Plant",       Background = "#0a1b0f", Text = "#f0fdf4", Placeholder = "#4fbf7a", Icon = "#4ade80", Accent = "#16a34a" },
    { Name = "Red",         Background = "#1c0606", Text = "#fef2f2", Placeholder = "#d95353", Icon = "#ef4444", Accent = "#dc2626" },
    { Name = "Indigo",      Background = "#0f0a2e", Text = "#f1f5f9", Placeholder = "#7078d9", Icon = "#6366f1", Accent = "#4f46e5" },
    { Name = "Sky",         Background = "#051a26", Text = "#e6f7ff", Placeholder = "#66b3cc", Icon = "#2db8d9", Accent = "#00d4ff" },
    { Name = "Violet",      Background = "#1e0a3e", Text = "#faf5ff", Placeholder = "#8f7ee0", Icon = "#8b5cf6", Accent = "#7c3aed" },
    { Name = "Amber",       Background = "#1c1003", Text = "#fffbeb", Placeholder = "#d1a326", Icon = "#f59e0b", Accent = "#d97706" },
    { Name = "Emerald",     Background = "#011411", Text = "#ecfdf5", Placeholder = "#3fbf8f", Icon = "#10b981", Accent = "#059669" },
    { Name = "Midnight",    Background = "#0a0f1e", Text = "#dbeafe", Placeholder = "#2f74d1", Icon = "#5591f4", Accent = "#2563eb" },
    { Name = "Crimson",     Background = "#0c0404", Text = "#fef2f2", Placeholder = "#6f757b", Icon = "#dc2626", Accent = "#991b1b" },
    { Name = "Monokai Pro", Background = "#191622", Text = "#fcfcfa", Placeholder = "#afafaf", Icon = "#a9dc76", Accent = "#ab9df2" },
    { Name = "Cotton Candy",Background = "#1a0b2e", Text = "#fdf2f8", Placeholder = "#8a5fd3", Icon = "#06b6d4", Accent = "#d946ef" },
    { Name = "Mellowsi",    Background = "#1C1002", Text = "#F5EBDD", Placeholder = "#9C8A73", Icon = "#C9B79C", Accent = "#C9A24D" },
    { Name = "Custom", Custom = true },
}

local THEME_NAMES = {}
for _, preset in ipairs(THEME_PRESETS) do
    table.insert(THEME_NAMES, preset.Name)
end

local function buildPalette(spec)
    local bg = Color3.fromHex(spec.Background)
    local text = Color3.fromHex(spec.Text)
    local accent = Color3.fromHex(spec.Accent)
    local icon = Color3.fromHex(spec.Icon)
    local placeholder = Color3.fromHex(spec.Placeholder)
    local white = Color3.fromRGB(250, 250, 250)
    local black = Color3.new(0, 0, 0)

    return {
        Background    = bg,
        CardBg        = bg:Lerp(text, 0.04),
        PillBg        = bg:Lerp(text, 0.03),
        SidebarActive = bg:Lerp(accent, 0.14),
        Border        = bg:Lerp(text, 0.14),
        BorderActive  = bg:Lerp(accent, 0.5),
        Accent        = accent,
        AccentSoft    = accent:Lerp(white, 0.45),
        AccentDark    = accent:Lerp(black, 0.45),
        TextPrimary   = text,
        TextMuted     = icon,
        TextDim       = placeholder,
        Divider       = bg:Lerp(text, 0.18),
        BadgeBg       = bg:Lerp(text, 0.07),
        ToggleOff     = bg:Lerp(text, 0.18),
        KnobOff       = bg:Lerp(text, 0.4),
        KnobOn        = white,
        VersionBg     = accent,
        VersionText   = white,
        PopupBg       = bg:Lerp(text, 0.07),
        BrandText     = text:Lerp(bg, 0.2),
    }
end

local currentThemeName = "Default"

local CUSTOM_NAME = "Custom"
local CUSTOM_DIR = "UILibrary/config"
local CUSTOM_FILE = CUSTOM_DIR .. "/custom_theme.txt"
local SAVED_THEMES = {}

local function findSavedTheme(name)
    for _, saved in ipairs(SAVED_THEMES) do
        if saved.Name == name then return saved end
    end
    return nil
end

local CUSTOM_PALETTE = {}
for _, key in ipairs(THEME_KEYS) do
    CUSTOM_PALETTE[key] = DEFAULT_PALETTE[key]
end

local setThemeLabel = function() end
local syncCustomPickers = function() end

local B64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_DECODE = {}
for i = 1, 64 do
    B64_DECODE[string.byte(B64_ALPHABET, i)] = i - 1
end

local function base64Decode(data)
    data = string.gsub(data, "[^%w%+/]", "")
    local out = {}
    for i = 1, #data, 4 do
        local a, b, c, d = string.byte(data, i, i + 3)
        local n = (B64_DECODE[a] or 0) * 262144 + (B64_DECODE[b] or 0) * 4096
            + (B64_DECODE[c] or 0) * 64 + (B64_DECODE[d] or 0)
        local count = d and 3 or (c and 2 or 1)
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if count >= 2 then out[#out + 1] = string.char(math.floor(n / 256) % 256) end
        if count >= 3 then out[#out + 1] = string.char(n % 256) end
    end
    return table.concat(out)
end

local ICON_CUBE3D_B64 = [==[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]==]

local CUSTOM_ICON_DATA = {
    cube3d = ICON_CUBE3D_B64,
}
local customIconCache = {}

local function isCustomIcon(name)
    return name ~= nil and CUSTOM_ICON_DATA[name] ~= nil
end

local function resolveIcon(name)
    if not name then return "" end
    if CUSTOM_ICON_DATA[name] then
        if customIconCache[name] == nil then
            customIconCache[name] = ""
            local ok, asset = pcall(function()
                local fileName = "UILibrary_" .. name .. ".png"
                if not (isfile and isfile(fileName)) then
                    writefile(fileName, base64Decode(CUSTOM_ICON_DATA[name]))
                end
                return getcustomasset(fileName)
            end)
            if ok and asset then
                customIconCache[name] = asset
            end
        end
        return customIconCache[name]
    end
    return LUCIDE[name] or ""
end

local function tintIcon(icon, name, keyOrFn)
    if isCustomIcon(name) then

        if COLOR_BINDINGS[icon] then COLOR_BINDINGS[icon].ImageColor3 = nil end
        icon.ImageColor3 = Color3.new(1, 1, 1)
    else
        bindColor(icon, "ImageColor3", keyOrFn)
    end
end

local NOTIFY_WIDTH = 340
local NOTIFY_MAX = 5
local notifyCounter = 0
local activeNotifications = {}

local NotifyHolder = Instance.new("Frame")
NotifyHolder.Name = "Notifications"
NotifyHolder.AnchorPoint = Vector2.new(1, 1)
NotifyHolder.Position = UDim2.new(1, -18, 1, -18)
NotifyHolder.Size = UDim2.new(0, NOTIFY_WIDTH, 1, -32)
NotifyHolder.BackgroundTransparency = 1
NotifyHolder.ZIndex = 200
NotifyHolder.Parent = ScreenGui
local notifyScale = Instance.new("UIScale")
notifyScale.Scale = UI_SCALE
notifyScale.Parent = NotifyHolder

local notifyLayout = Instance.new("UIListLayout")
notifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
notifyLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
notifyLayout.Padding = UDim.new(0, 10)
notifyLayout.Parent = NotifyHolder

local function dismissNotification(card)
    if not card or not card.Parent then return end
    for i, c in ipairs(activeNotifications) do
        if c == card then
            table.remove(activeNotifications, i)
            break
        end
    end

    for _, d in ipairs(card:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            TweenService:Create(d, TWEEN_FAST, {TextTransparency = 1, BackgroundTransparency = 1}):Play()
        elseif d:IsA("ImageLabel") then
            TweenService:Create(d, TWEEN_FAST, {ImageTransparency = 1, BackgroundTransparency = 1}):Play()
        elseif d:IsA("Frame") then
            TweenService:Create(d, TWEEN_FAST, {BackgroundTransparency = 1}):Play()
        end
    end
    TweenService:Create(card, TWEEN_FAST, {BackgroundTransparency = 1}):Play()
    task.delay(0.25, function()
        card:Destroy()
    end)
end

local function Notify(opts)
    opts = opts or {}
    local duration = opts.Duration or 3
    notifyCounter = notifyCounter + 1

    local card = Instance.new("TextButton")
    card.Name = "Notification"
    card.Text = ""
    card.AutoButtonColor = false
    card.BorderSizePixel = 0
    card.Size = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.LayoutOrder = notifyCounter
    card.ZIndex = 201
    bindColor(card, "BackgroundColor3", "CardBg")
    card.Parent = NotifyHolder

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 0.8
    bindColor(stroke, "Color", "Border")
    stroke.Parent = card

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 14)
    pad.PaddingBottom = UDim.new(0, 14)
    pad.PaddingLeft = UDim.new(0, 16)
    pad.PaddingRight = UDim.new(0, 16)
    pad.Parent = card

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = card

    local titleRow = Instance.new("Frame")
    titleRow.Name = "TitleRow"
    titleRow.Size = UDim2.new(1, 0, 0, 22)
    titleRow.BackgroundTransparency = 1
    titleRow.LayoutOrder = 1
    titleRow.Parent = card

    local textX = 0
    if opts.Icon then
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(0, 18, 0, 18)
        icon.Position = UDim2.new(0, 0, 0.5, -9)
        icon.BackgroundTransparency = 1
        icon.Image = resolveIcon(opts.Icon)
        tintIcon(icon, opts.Icon, "Accent")
        icon.Parent = titleRow
        textX = 26
    end

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -textX, 1, 0)
    title.Position = UDim2.new(0, textX, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = opts.Title or "Notification"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextTruncate = Enum.TextTruncate.AtEnd
    bindColor(title, "TextColor3", "TextPrimary")
    title.Parent = titleRow

    if opts.Content and opts.Content ~= "" then
        local body = Instance.new("TextLabel")
        body.Name = "Content"
        body.Size = UDim2.new(1, 0, 0, 0)
        body.AutomaticSize = Enum.AutomaticSize.Y
        body.BackgroundTransparency = 1
        body.Text = opts.Content
        body.Font = Enum.Font.Gotham
        body.TextSize = 13
        body.TextWrapped = true
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.LayoutOrder = 2
        bindColor(body, "TextColor3", "TextMuted")
        body.Parent = card
    end

    local track = Instance.new("Frame")
    track.Name = "Track"
    track.Size = UDim2.new(1, 0, 0, 4)
    track.LayoutOrder = 3
    track.BorderSizePixel = 0
    bindColor(track, "BackgroundColor3", "ToggleOff")
    track.Parent = card

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BorderSizePixel = 0
    bindColor(fill, "BackgroundColor3", "Accent")
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 1, 0)}):Play()

    card.MouseButton1Click:Connect(function()
        dismissNotification(card)
    end)

    table.insert(activeNotifications, card)
    if #activeNotifications > NOTIFY_MAX then
        dismissNotification(activeNotifications[1])
    end
    task.delay(duration, function()
        dismissNotification(card)
    end)

    return card
end

local STARTUP_THEME = nil

local function writeCustomConfig()
    if not writefile then return end
    if makefolder then
        pcall(makefolder, "UILibrary")
        pcall(makefolder, CUSTOM_DIR)
    end
    local parts = {"active=" .. currentThemeName, "[" .. CUSTOM_NAME .. "]"}
    for _, key in ipairs(THEME_KEYS) do
        local c = CUSTOM_PALETTE[key]
        parts[#parts + 1] = string.format("%s=%d,%d,%d", key,
            math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
    end
    for _, saved in ipairs(SAVED_THEMES) do
        parts[#parts + 1] = "[" .. saved.Name .. "]"
        for _, key in ipairs(THEME_KEYS) do
            local c = saved.Palette[key]
            parts[#parts + 1] = string.format("%s=%d,%d,%d", key,
                math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
        end
    end
    pcall(writefile, CUSTOM_FILE, table.concat(parts, "\n"))
end

local function setTheme(themeName)
    if themeName == currentThemeName then return true end

    local newPalette
    local saved = findSavedTheme(themeName)
    if saved then
        newPalette = saved.Palette
    else
        local preset = nil
        for _, p in ipairs(THEME_PRESETS) do
            if p.Name == themeName then
                preset = p
                break
            end
        end
        if not preset then return false end

        if preset.Custom then
            newPalette = CUSTOM_PALETTE
        elseif preset.Default then
            newPalette = DEFAULT_PALETTE
        else
            newPalette = buildPalette(preset)
        end
    end
    for _, key in ipairs(THEME_KEYS) do
        THEME[key] = newPalette[key]
    end
    currentThemeName = themeName
    refreshTheme()
    syncCustomPickers()
    writeCustomConfig()
    return true
end

local function applyTheme(themeName)
    if themeName == currentThemeName then return end
    if not setTheme(themeName) then return end
    Notify({Title = "Theme changed", Content = themeName .. " theme applied", Icon = "palette", Duration = 2.5})
end

local ROW_TITLE_H = 14
local ROW_DESC_H = 11
local ROW_CONTROL_GAP = 4
local CONTROL_H = 24
local SELECT_OPTION_H = 26
local BUTTON_H = 30

local registeredRows = {}
local activePopups = {}

local function closeAllPopups(except)
    for _, p in ipairs(activePopups) do
        if p ~= except and p.Parent then
            p:Destroy()
        end
    end
    activePopups = except and {except} or {}
end

local POPUP_ANCHOR = setmetatable({}, { __mode = "k" })
local POPUP_ORIGIN = setmetatable({}, { __mode = "k" })
local POPUP_SCROLL_LIMIT = 10

local function isPointInside(obj, point)
    local pos = obj.AbsolutePosition
    local size = obj.AbsoluteSize
    return point.X >= pos.X and point.X <= pos.X + size.X
        and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

trackConn(UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
       and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    if #activePopups == 0 then return end

    local mouse = UserInputService:GetMouseLocation()

    local inset = game:GetService("GuiService"):GetGuiInset()
    local points = {
        Vector2.new(mouse.X, mouse.Y),
        Vector2.new(mouse.X, mouse.Y - inset.Y),
    }
    for _, p in ipairs(activePopups) do
        for _, point in ipairs(points) do
            if p.Parent and isPointInside(p, point) then return end
            local anchor = POPUP_ANCHOR[p]

            if anchor and anchor.Parent and isPointInside(anchor, point) then return end
        end
    end
    closeAllPopups()
end))

trackConn(RunService.RenderStepped:Connect(function()
    if #activePopups == 0 then return end
    for _, p in ipairs(activePopups) do
        local anchor = POPUP_ANCHOR[p]
        local origin = POPUP_ORIGIN[p]
        if not anchor or not anchor.Parent or not origin then
            closeAllPopups()
            return
        end
        local pos = anchor.AbsolutePosition
        if math.abs(pos.X - origin.X) > POPUP_SCROLL_LIMIT or math.abs(pos.Y - origin.Y) > POPUP_SCROLL_LIMIT then
            closeAllPopups()
            return
        end
    end
end))

local function trackPopup(popup, anchor)
    table.insert(activePopups, popup)
    POPUP_ANCHOR[popup] = anchor
    POPUP_ORIGIN[popup] = anchor and anchor.AbsolutePosition or nil
    popup.Destroying:Connect(function()
        for i, p in ipairs(activePopups) do
            if p == popup then
                table.remove(activePopups, i)
                break
            end
        end
    end)
end

local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local function addStroke(parent, thickness)
    local s = Instance.new("UIStroke")
    bindColor(s, "Color", "Border")
    s.Thickness = thickness or 0.8
    s.Parent = parent
    return s
end

local function createRow(card, name, description, options)
    options = options or {}
    local sideWidth = options.sideWidth
    local headerH = ROW_TITLE_H + (description and (ROW_DESC_H + 1) or 0)

    local rowHeight, controlTop, headerTop
    if sideWidth then
        rowHeight = math.max(headerH, 16)
        headerTop = math.floor((rowHeight - headerH) / 2)
        controlTop = 0
    else
        headerTop = 0
        controlTop = headerH + ROW_CONTROL_GAP
        rowHeight = controlTop + (options.controlHeight or 0)
    end

    local row = Instance.new("Frame")
    row.Name = name
    row.Size = UDim2.new(1, 0, 0, rowHeight)
    row.BackgroundTransparency = 1
    row.Parent = card

    local cardInfo = CARD_INFO[card] or {}
    table.insert(registeredRows, {
        Frame = row,
        Label = name,
        Name = string.lower(name),
        Desc = description and string.lower(description) or "",
        Tab = cardInfo.Tab,
        CardTitle = cardInfo.Title,
        Card = card,
    })

    local rightInset = sideWidth and (sideWidth + 8) or (options.titleInset or 0)

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -rightInset, 0, ROW_TITLE_H)
    title.Position = UDim2.new(0, 0, 0, headerTop)
    title.BackgroundTransparency = 1
    title.Text = name
    title.Font = Enum.Font.GothamMedium
    title.TextSize = 11
    bindColor(title, "TextColor3", "TextPrimary")
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.Parent = row

    if description then
        local desc = Instance.new("TextLabel")
        desc.Name = "Description"
        desc.Size = UDim2.new(1, -rightInset, 0, ROW_DESC_H)
        desc.Position = UDim2.new(0, 0, 0, headerTop + ROW_TITLE_H + 1)
        desc.BackgroundTransparency = 1
        desc.Text = description
        desc.Font = Enum.Font.Gotham
        desc.TextSize = 9
        bindColor(desc, "TextColor3", "TextMuted")
        desc.TextXAlignment = Enum.TextXAlignment.Left
        desc.TextTruncate = Enum.TextTruncate.AtEnd
        desc.Parent = row
    end

    return row, controlTop
end

local SEARCH_MAX_RESULTS = 8
local searchPopup = nil

local function closeSearchResults()
    if searchPopup and searchPopup.Parent then
        searchPopup:Destroy()
    end
    searchPopup = nil
end

local function findRows(query)
    local q = string.lower(query)
    local startsWith, contains = {}, {}
    for _, item in ipairs(registeredRows) do
        if item.Frame.Parent ~= nil then
            local at = string.find(item.Name, q, 1, true)
            if at == 1 then
                table.insert(startsWith, item)
            elseif at or string.find(item.Desc, q, 1, true) then
                table.insert(contains, item)
            end
        end
    end
    local out = {}
    for _, it in ipairs(startsWith) do table.insert(out, it) end
    for _, it in ipairs(contains) do table.insert(out, it) end
    return out
end

local function scrollToRow(row)
    local col = row.Parent
    while col and not col:IsA("ScrollingFrame") do
        col = col.Parent
    end
    if not col then return end
    local offset = row.AbsolutePosition.Y - col.AbsolutePosition.Y + col.CanvasPosition.Y
    col.CanvasPosition = Vector2.new(col.CanvasPosition.X, math.max(0, offset - 40))
end

local function highlightRow(row)
    local hl = Instance.new("Frame")
    hl.Name = "Highlight"
    hl.Size = UDim2.new(1, 12, 1, 8)
    hl.Position = UDim2.new(0, -6, 0, -4)
    hl.BorderSizePixel = 0
    hl.ZIndex = 0
    bindColor(hl, "BackgroundColor3", "Accent")
    hl.BackgroundTransparency = 0.85
    hl.Parent = row
    addCorner(hl, 6)

    local info = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(hl, info, {BackgroundTransparency = 0.5}):Play()
    task.delay(0.3, function()
        if hl.Parent then TweenService:Create(hl, info, {BackgroundTransparency = 0.85}):Play() end
    end)
    task.delay(0.6, function()
        if hl.Parent then TweenService:Create(hl, info, {BackgroundTransparency = 0.5}):Play() end
    end)
    task.delay(1.4, function()
        if hl.Parent then hl:Destroy() end
    end)
end

local function goToRow(item)
    closeSearchResults()
    SearchInput.Text = ""
    if TAB_ACTIVATORS[item.Tab] then
        TAB_ACTIVATORS[item.Tab]()
    end

    local connection
    connection = trackConn(RunService.RenderStepped:Connect(function()
        connection:Disconnect()
        if item.Frame.Parent ~= nil then
            scrollToRow(item.Frame)
            highlightRow(item.Frame)
        end
    end))
end

local function showSearchResults(query)
    closeSearchResults()
    if query == "" then return end

    local results = findRows(query)

    local popup = Instance.new("Frame")
    popup.Name = "SearchResults"
    popup.Size = UDim2.new(0, SearchBox.AbsoluteSize.X / UI_SCALE, 0, 0)
    popup.AutomaticSize = Enum.AutomaticSize.Y
    popup.Position = UDim2.fromOffset(SearchBox.AbsolutePosition.X, SearchBox.AbsolutePosition.Y + SearchBox.AbsoluteSize.Y + 4)
    bindColor(popup, "BackgroundColor3", "PopupBg")
    popup.BorderSizePixel = 0
    popup.ZIndex = 100
    scalePopup(popup)
    popup.Parent = ScreenGui
    addCorner(popup, 6)
    addStroke(popup)

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.PaddingLeft = UDim.new(0, 4)
    pad.PaddingRight = UDim.new(0, 4)
    pad.Parent = popup

    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 2)
    list.Parent = popup

    if #results == 0 then
        local none = Instance.new("TextLabel")
        none.Size = UDim2.new(1, 0, 0, 30)
        none.BackgroundTransparency = 1
        none.Text = "No results for \"" .. query .. "\""
        none.Font = Enum.Font.Gotham
        none.TextSize = 10.5
        bindColor(none, "TextColor3", "TextMuted")
        none.ZIndex = 101
        none.LayoutOrder = 1
        none.Parent = popup
    end

    for i, item in ipairs(results) do
        if i > SEARCH_MAX_RESULTS then break end

        local ob = Instance.new("TextButton")
        ob.Size = UDim2.new(1, 0, 0, 36)
        bindColor(ob, "BackgroundColor3", "SidebarActive")
        ob.BackgroundTransparency = 1
        ob.Text = ""
        ob.AutoButtonColor = false
        ob.ZIndex = 101
        ob.LayoutOrder = i
        ob.Parent = popup
        addCorner(ob, 4)

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -16, 0, 16)
        nameLbl.Position = UDim2.new(0, 8, 0, 4)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = item.Label
        nameLbl.Font = Enum.Font.GothamMedium
        nameLbl.TextSize = 11
        bindColor(nameLbl, "TextColor3", "TextPrimary")
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.ZIndex = 102
        nameLbl.Parent = ob

        local whereLbl = Instance.new("TextLabel")
        whereLbl.Size = UDim2.new(1, -16, 0, 12)
        whereLbl.Position = UDim2.new(0, 8, 0, 19)
        whereLbl.BackgroundTransparency = 1
        whereLbl.Text = item.Tab .. "  >  " .. (item.CardTitle or "")
        whereLbl.Font = Enum.Font.Gotham
        whereLbl.TextSize = 9
        bindColor(whereLbl, "TextColor3", "TextMuted")
        whereLbl.TextXAlignment = Enum.TextXAlignment.Left
        whereLbl.ZIndex = 102
        whereLbl.Parent = ob

        ob.MouseEnter:Connect(function()
            ob.BackgroundTransparency = 0
        end)
        ob.MouseLeave:Connect(function()
            ob.BackgroundTransparency = 1
        end)
        ob.MouseButton1Click:Connect(function()
            goToRow(item)
        end)
    end

    trackPopup(popup, SearchBox)
    searchPopup = popup
end

SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
    showSearchResults(SearchInput.Text)
end)

SearchInput.FocusLost:Connect(function(enterPressed)
    if enterPressed and SearchInput.Text ~= "" then
        local first = findRows(SearchInput.Text)[1]
        if first then goToRow(first) end
    end
end)

local function addToggle(card, name, description, defaultState, callback)
    local row = createRow(card, name, description, {sideWidth = 32})

    local switch = Instance.new("TextButton")
    switch.Name = "Switch"
    switch.Size = UDim2.new(0, 32, 0, 16)
    switch.Position = UDim2.new(1, -32, 0.5, -8)
    bindColor(switch, "BackgroundColor3", function() return (defaultState) and "Accent" or "ToggleOff" end)
    switch.Text = ""
    switch.AutoButtonColor = false
    switch.Parent = row
    addCorner(switch, 8)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = defaultState and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
    bindColor(knob, "BackgroundColor3", function() return (defaultState) and "KnobOn" or "KnobOff" end)
    knob.BorderSizePixel = 0
    knob.Parent = switch
    addCorner(knob, 6)

    local isToggled = defaultState

    local function applyToggle(value, fire)
        isToggled = value and true or false
        local targetColor = isToggled and "Accent" or "ToggleOff"
        local targetKnobColor = isToggled and "KnobOn" or "KnobOff"
        local targetPos = isToggled and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)

        tweenColors(switch, TWEEN_FAST, {BackgroundColor3 = targetColor}):Play()
        tweenColors(knob, TWEEN_FAST, {BackgroundColor3 = targetKnobColor, Position = targetPos}):Play()

        if fire and callback then
            callback(isToggled)
        end
    end

    switch.MouseButton1Click:Connect(function()
        applyToggle(not isToggled, true)
    end)

    return {
        Set = function(value) applyToggle(value, true) end,
        Get = function() return isToggled end,
    }
end

local function addInput(card, name, description, placeholder, defaultText, callback)
    local row, top = createRow(card, name, description, {controlHeight = CONTROL_H})

    local box = Instance.new("Frame")
    box.Name = "Box"
    box.Size = UDim2.new(1, 0, 0, CONTROL_H)
    box.Position = UDim2.new(0, 0, 0, top)
    bindColor(box, "BackgroundColor3", "BadgeBg")
    box.BorderSizePixel = 0
    box.Parent = row
    addCorner(box, 4)
    addStroke(box)

    local input = Instance.new("TextBox")
    input.Size = UDim2.new(1, -16, 1, 0)
    input.Position = UDim2.new(0, 8, 0, 0)
    input.BackgroundTransparency = 1
    input.Text = defaultText or ""
    input.PlaceholderText = placeholder or ""
    bindColor(input, "PlaceholderColor3", "TextDim")
    bindColor(input, "TextColor3", "TextPrimary")
    input.Font = Enum.Font.Gotham
    input.TextSize = 10.5
    input.TextXAlignment = Enum.TextXAlignment.Left
    input.ClearTextOnFocus = false
    input.Parent = box

    input.FocusLost:Connect(function()
        if callback then callback(input.Text) end
    end)
    return input
end

local ICON_SIZE = 16
local CHEVRON_SIZE = 14
local POPUP_VISIBLE_ROWS = 5

local function addPopupSearch(popup, rows, list)
    local holder = Instance.new("Frame")
    holder.Name = "Search"
    holder.Size = UDim2.new(1, 0, 0, SELECT_OPTION_H)
    holder.LayoutOrder = -1
    bindColor(holder, "BackgroundColor3", "BadgeBg")
    holder.BorderSizePixel = 0
    holder.ZIndex = 101
    holder.Parent = popup
    addCorner(holder, 4)
    addStroke(holder)

    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
    icon.Position = UDim2.new(0, 6, 0.5, -8)
    icon.BackgroundTransparency = 1
    icon.Image = resolveIcon("search")
    tintIcon(icon, "search", "TextMuted")
    icon.ZIndex = 102
    icon.Parent = holder

    local box = Instance.new("TextBox")
    box.Name = "PopupSearchInput"
    box.Size = UDim2.new(1, -30, 1, 0)
    box.Position = UDim2.new(0, 26, 0, 0)
    box.BackgroundTransparency = 1
    box.Text = ""
    box.PlaceholderText = "Search"
    bindColor(box, "PlaceholderColor3", "TextDim")
    bindColor(box, "TextColor3", "TextPrimary")
    box.Font = Enum.Font.Gotham
    box.TextSize = 10.5
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ClearTextOnFocus = false
    box.ZIndex = 102
    box.Parent = holder

    local empty = Instance.new("TextLabel")
    empty.Name = "NoResults"
    empty.Size = UDim2.new(1, 0, 0, SELECT_OPTION_H)
    empty.LayoutOrder = 10000
    empty.Visible = false
    empty.BackgroundTransparency = 1
    empty.Text = "No results"
    empty.Font = Enum.Font.Gotham
    empty.TextSize = 10.5
    bindColor(empty, "TextColor3", "TextDim")
    empty.ZIndex = 102
    empty.Parent = list

    local function fitList()
        local shown = 0
        for _, r in ipairs(rows) do
            if r.Frame.Visible then shown = shown + 1 end
        end
        empty.Visible = shown == 0
        local rowsShown = math.max(1, math.min(shown, POPUP_VISIBLE_ROWS))
        list.Size = UDim2.new(1, 0, 0, rowsShown * SELECT_OPTION_H + (rowsShown - 1) * 2)
    end

    box:GetPropertyChangedSignal("Text"):Connect(function()
        local query = string.lower(box.Text)
        for _, r in ipairs(rows) do
            r.Frame.Visible = query == "" or string.find(string.lower(r.Text), query, 1, true) ~= nil
        end
        fitList()
    end)
    fitList()
    return box
end

local function normalizeOption(opt)
    if type(opt) == "table" then
        return opt.Text or "", opt.Icon
    end
    return tostring(opt), nil
end

local function addDropdown(card, name, description, options, defaultIndex, callback)
    local row, top = createRow(card, name, description, {controlHeight = CONTROL_H})

    local select = Instance.new("TextButton")
    select.Name = "Select"
    select.Size = UDim2.new(1, 0, 0, CONTROL_H)
    select.Position = UDim2.new(0, 0, 0, top)
    bindColor(select, "BackgroundColor3", "BadgeBg")
    select.Text = ""
    select.AutoButtonColor = false
    select.Parent = row
    addCorner(select, 4)
    addStroke(select)

    local currentIdx = defaultIndex or 1
    local curText, curIconName = normalizeOption(options[currentIdx])

    local selectIcon = Instance.new("ImageLabel")
    selectIcon.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
    selectIcon.Position = UDim2.new(0, 6, 0.5, -8)
    selectIcon.BackgroundTransparency = 1
    selectIcon.Image = resolveIcon(curIconName)
    tintIcon(selectIcon, curIconName, "TextMuted")
    selectIcon.Visible = curIconName ~= nil
    selectIcon.Parent = select

    local valueLbl = Instance.new("TextLabel")
    valueLbl.Size = UDim2.new(1, -52, 1, 0)
    valueLbl.Position = UDim2.new(0, curIconName and 28 or 8, 0, 0)
    valueLbl.BackgroundTransparency = 1
    valueLbl.Text = curText
    valueLbl.Font = Enum.Font.Gotham
    valueLbl.TextSize = 10.5
    bindColor(valueLbl, "TextColor3", "TextPrimary")
    valueLbl.TextXAlignment = Enum.TextXAlignment.Left
    valueLbl.TextTruncate = Enum.TextTruncate.AtEnd
    valueLbl.Parent = select

    local arrow = Instance.new("ImageLabel")
    arrow.Size = UDim2.new(0, CHEVRON_SIZE, 0, CHEVRON_SIZE)
    arrow.Position = UDim2.new(1, -CHEVRON_SIZE - 6, 0.5, -CHEVRON_SIZE / 2)
    arrow.BackgroundTransparency = 1
    arrow.Image = ICONS.Chevron
    bindColor(arrow, "ImageColor3", "TextMuted")
    arrow.Parent = select

    local currentPopup = nil

    select.MouseButton1Click:Connect(function()
        if currentPopup and currentPopup.Parent then
            currentPopup:Destroy()
            currentPopup = nil
            return
        end
        closeAllPopups()

        local popup = Instance.new("Frame")
        popup.Size = UDim2.new(0, select.AbsoluteSize.X / UI_SCALE, 0, 0)
        popup.AutomaticSize = Enum.AutomaticSize.Y
        popup.Position = UDim2.fromOffset(select.AbsolutePosition.X, select.AbsolutePosition.Y + select.AbsoluteSize.Y + 3)
        bindColor(popup, "BackgroundColor3", "PopupBg")
        popup.BorderSizePixel = 0
        popup.ZIndex = 100
        scalePopup(popup)
        popup.Parent = ScreenGui
        addCorner(popup, 5)
        addStroke(popup)

        local dl = Instance.new("UIListLayout")
        dl.Padding = UDim.new(0, 2)
        dl.SortOrder = Enum.SortOrder.LayoutOrder
        dl.Parent = popup

        local dp = Instance.new("UIPadding")
        dp.PaddingTop = UDim.new(0, 4)
        dp.PaddingBottom = UDim.new(0, 4)
        dp.PaddingLeft = UDim.new(0, 4)
        dp.PaddingRight = UDim.new(0, 4)
        dp.Parent = popup

        local list = Instance.new("ScrollingFrame")
        list.Name = "Options"
        list.Size = UDim2.new(1, 0, 0, 0)
        list.LayoutOrder = 1
        list.BackgroundTransparency = 1
        list.BorderSizePixel = 0
        list.ScrollBarThickness = 3
        bindColor(list, "ScrollBarImageColor3", "TextDim")
        list.CanvasSize = UDim2.new(0, 0, 0, 0)
        list.AutomaticCanvasSize = Enum.AutomaticSize.Y
        list.ZIndex = 101
        list.Parent = popup

        local ll = Instance.new("UIListLayout")
        ll.Padding = UDim.new(0, 2)
        ll.SortOrder = Enum.SortOrder.LayoutOrder
        ll.Parent = list

        local rows = {}
        for i, optData in ipairs(options) do
            local optText, optIconName = normalizeOption(optData)

            local ob = Instance.new("TextButton")
            ob.Size = UDim2.new(1, 0, 0, SELECT_OPTION_H)
            bindColor(ob, "BackgroundColor3", "SidebarActive")
            ob.BackgroundTransparency = 1
            ob.Text = ""
            ob.AutoButtonColor = false
            ob.ZIndex = 101
            ob.LayoutOrder = i
            ob.Parent = list
            addCorner(ob, 4)
            table.insert(rows, {Frame = ob, Text = optText})

            local obIcon = nil
            if optIconName then
                obIcon = Instance.new("ImageLabel")
                obIcon.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
                obIcon.Position = UDim2.new(0, 6, 0.5, -8)
                obIcon.BackgroundTransparency = 1
                obIcon.Image = resolveIcon(optIconName)
                tintIcon(obIcon, optIconName, function() return ((i == currentIdx)) and "Accent" or "TextMuted" end)
                obIcon.ZIndex = 102
                obIcon.Parent = ob
            end

            local obText = Instance.new("TextLabel")
            obText.Size = UDim2.new(1, -36, 1, 0)
            obText.Position = UDim2.new(0, optIconName and 28 or 8, 0, 0)
            obText.BackgroundTransparency = 1
            obText.Text = optText
            obText.Font = Enum.Font.Gotham
            obText.TextSize = 10.5
            bindColor(obText, "TextColor3", function() return ((i == currentIdx)) and "Accent" or "TextPrimary" end)
            obText.TextXAlignment = Enum.TextXAlignment.Left
            obText.ZIndex = 102
            obText.Parent = ob

            ob.MouseEnter:Connect(function()
                ob.BackgroundTransparency = 0
                bindColor(obText, "TextColor3", "Accent")
                if obIcon then tintIcon(obIcon, optIconName, "Accent") end
            end)
            ob.MouseLeave:Connect(function()
                ob.BackgroundTransparency = 1
                local c = (i == currentIdx) and THEME.Accent or THEME.TextPrimary
                obText.TextColor3 = c
                if obIcon then
                    tintIcon(obIcon, optIconName, function() return ((i == currentIdx)) and "Accent" or "TextMuted" end)
                end
            end)
            ob.MouseButton1Click:Connect(function()
                currentIdx = i
                valueLbl.Text = optText
                if optIconName then
                    selectIcon.Image = resolveIcon(optIconName)
                    tintIcon(selectIcon, optIconName, "TextMuted")
                    selectIcon.Visible = true
                    valueLbl.Position = UDim2.new(0, 28, 0, 0)
                else
                    selectIcon.Visible = false
                    valueLbl.Position = UDim2.new(0, 8, 0, 0)
                end
                popup:Destroy()
                currentPopup = nil
                if callback then callback(optText, i) end
            end)
        end

        addPopupSearch(popup, rows, list)
        trackPopup(popup, select)
        currentPopup = popup
    end)

    local function applySelection(idx, fire)
        if not idx or not options[idx] then return end
        currentIdx = idx
        local optText, optIconName = normalizeOption(options[idx])
        valueLbl.Text = optText
        if optIconName then
            selectIcon.Image = resolveIcon(optIconName)
            tintIcon(selectIcon, optIconName, "TextMuted")
            selectIcon.Visible = true
            valueLbl.Position = UDim2.new(0, 28, 0, 0)
        else
            selectIcon.Visible = false
            valueLbl.Position = UDim2.new(0, 8, 0, 0)
        end
        if currentPopup and currentPopup.Parent then
            currentPopup:Destroy()
            currentPopup = nil
        end
        if fire and callback then
            callback(optText, idx)
        end
    end

    local dropdownApi = {}

    function dropdownApi.Set(indexOrText)
        local idx = nil
        if type(indexOrText) == "number" then
            idx = indexOrText
        else
            for i, optData in ipairs(options) do
                local text = normalizeOption(optData)
                if text == tostring(indexOrText) then
                    idx = i
                    break
                end
            end
        end
        applySelection(idx, true)
    end

    function dropdownApi.Get()
        local text = normalizeOption(options[currentIdx])
        return text, currentIdx
    end

    setmetatable(dropdownApi, {__call = function(_, text, idx)
        if idx then
            applySelection(idx, false)
        else
            valueLbl.Text = text
        end
    end})
    return dropdownApi
end

local function addSlider(card, name, description, minVal, maxVal, defaultVal, decimals, callback)
    if type(decimals) == "function" then
        callback = decimals
        decimals = 0
    end
    decimals = decimals or 0
    local fmt = "%." .. decimals .. "f"

    local row, top = createRow(card, name, description, {controlHeight = 6, titleInset = 44})

    local valBtn = Instance.new("TextButton")
    valBtn.Name = "Value"
    valBtn.Size = UDim2.new(0, 40, 0, ROW_TITLE_H)
    valBtn.Position = UDim2.new(1, -40, 0, 0)
    valBtn.BackgroundTransparency = 1
    valBtn.Text = string.format(fmt, defaultVal)
    valBtn.Font = Enum.Font.GothamBold
    valBtn.TextSize = 10
    bindColor(valBtn, "TextColor3", "Accent")
    valBtn.TextXAlignment = Enum.TextXAlignment.Right
    valBtn.AutoButtonColor = false
    valBtn.Parent = row

    local track = Instance.new("Frame")
    track.Name = "Track"
    track.Size = UDim2.new(1, 0, 0, 6)
    track.Position = UDim2.new(0, 0, 0, top)
    bindColor(track, "BackgroundColor3", "ToggleOff")
    track.BorderSizePixel = 0
    track.Parent = row
    addCorner(track, 3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
    bindColor(fill, "BackgroundColor3", "Accent")
    fill.BorderSizePixel = 0
    fill.Parent = track
    addCorner(fill, 3)

    local currentValue = defaultVal

    local function setValue(val, fireCallback)
        val = math.clamp(val, minVal, maxVal)
        currentValue = val
        local rel = (val - minVal) / (maxVal - minVal)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        valBtn.Text = string.format(fmt, val)
        if fireCallback and callback then callback(val) end
    end

    local dragging = false
    local function updateFromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local val = minVal + (maxVal - minVal) * rel
        if decimals == 0 then
            val = math.floor(val + 0.5)
        end
        setValue(val, true)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateFromX(input.Position.X)
        end
    end)
    trackConn(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateFromX(input.Position.X)
        end
    end))
    trackConn(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))

    valBtn.MouseButton1Click:Connect(function()
        closeAllPopups()

        local box = Instance.new("Frame")
        box.Size = UDim2.new(0, 60, 0, 20)
        box.Position = UDim2.fromOffset(valBtn.AbsolutePosition.X + valBtn.AbsoluteSize.X - 60, valBtn.AbsolutePosition.Y - 2)
        bindColor(box, "BackgroundColor3", "PopupBg")
        box.BorderSizePixel = 0
        box.ZIndex = 100
        scalePopup(box)
        box.Parent = ScreenGui
        addCorner(box, 4)
        addStroke(box)

        local input = Instance.new("TextBox")
        input.Size = UDim2.new(1, -8, 1, 0)
        input.Position = UDim2.new(0, 4, 0, 0)
        input.BackgroundTransparency = 1
        input.Text = tostring(currentValue)
        input.Font = Enum.Font.GothamBold
        input.TextSize = 10
        bindColor(input, "TextColor3", "Accent")
        input.TextXAlignment = Enum.TextXAlignment.Center
        input.ClearTextOnFocus = false
        input.ZIndex = 101
        input.Parent = box

        trackPopup(box, valBtn)
        input:CaptureFocus()

        input.FocusLost:Connect(function()
            local num = tonumber(input.Text)
            if num then
                setValue(num, true)
            end
            box:Destroy()
        end)
    end)

    return {
        Set = function(value) setValue(value, true) end,
        Get = function() return currentValue end,
    }
end

local function addKeybind(card, name, description, defaultKey, callback)
    local row = createRow(card, name, description, {sideWidth = 94})

    local badge = Instance.new("TextButton")
    badge.Name = "Badge"
    badge.Size = UDim2.new(0, 60, 0, 16)
    badge.Position = UDim2.new(1, -86, 0.5, -8)
    bindColor(badge, "BackgroundColor3", "BadgeBg")
    badge.Text = defaultKey or "None"
    badge.AutoButtonColor = false
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 9
    badge.TextTruncate = Enum.TextTruncate.AtEnd
    bindColor(badge, "TextColor3", "TextMuted")
    badge.Parent = row
    addCorner(badge, 3)
    addStroke(badge)

    local resetBtn = Instance.new("ImageButton")
    resetBtn.Name = "Reset"
    resetBtn.Size = UDim2.new(0, 14, 0, 14)
    resetBtn.Position = UDim2.new(1, -18, 0.5, -7)
    resetBtn.BackgroundTransparency = 1
    resetBtn.Image = LUCIDE["rotate-cw"]
    bindColor(resetBtn, "ImageColor3", "TextDim")
    resetBtn.Parent = row

    resetBtn.MouseEnter:Connect(function()
        tweenColors(resetBtn, TWEEN_FAST, {ImageColor3 = "Accent"}):Play()
    end)
    resetBtn.MouseLeave:Connect(function()
        tweenColors(resetBtn, TWEEN_FAST, {ImageColor3 = "TextDim"}):Play()
    end)

    local listening = false
    local listener
    local currentKey = defaultKey or "None"

    resetBtn.MouseButton1Click:Connect(function()
        if listener then
            listener:Disconnect()
            listener = nil
        end
        listening = false
        currentKey = "None"
        badge.Text = "None"
        bindColor(badge, "TextColor3", "TextMuted")
        if callback then callback("None") end
    end)

    badge.MouseButton1Click:Connect(function()
        if listening then
            if listener then listener:Disconnect() end
            badge.Text = defaultKey or "None"
            bindColor(badge, "TextColor3", "TextMuted")
            listening = false
            return
        end
        listening = true
        badge.Text = "..."
        bindColor(badge, "TextColor3", "Accent")
        listener = trackConn(UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local key = input.KeyCode.Name
                currentKey = (key == "Escape") and "None" or key
                badge.Text = currentKey
                bindColor(badge, "TextColor3", "TextMuted")
                listening = false
                listener:Disconnect()
                if callback then callback(badge.Text) end
            end
        end))
    end)

    return {
        Set = function(value)
            currentKey = tostring(value)
            badge.Text = currentKey
            bindColor(badge, "TextColor3", "TextMuted")
            if callback then callback(currentKey) end
        end,
        Get = function() return currentKey end,
    }
end

local function addButtonRow(card, name, description, buttons)
    local row, top = createRow(card, name, description, {controlHeight = BUTTON_H})

    local holder = Instance.new("Frame")
    holder.Name = "Buttons"
    holder.Size = UDim2.new(1, 0, 0, BUTTON_H)
    holder.Position = UDim2.new(0, 0, 0, top)
    holder.BackgroundTransparency = 1
    holder.Parent = row

    local gap = 8
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, gap)
    layout.Parent = holder

    local count = #buttons
    local createdButtons = {}
    for i, def in ipairs(buttons) do
        local btn = Instance.new("TextButton")
        btn.Name = def.Text
        btn.LayoutOrder = i
        btn.Size = UDim2.new(1 / count, -(gap * (count - 1)) / count, 1, 0)
        bindColor(btn, "BackgroundColor3", "Accent")
        btn.Text = def.Text
        btn.AutoButtonColor = false
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        bindColor(btn, "TextColor3", "KnobOn")
        btn.Parent = holder
        addCorner(btn, 6)

        btn.MouseButton1Click:Connect(function()
            if def.Callback then def.Callback() end
        end)
        table.insert(createdButtons, {
            Button = btn,
            Fire = function() if def.Callback then def.Callback() end end,
            SetText = function(t) btn.Text = tostring(t) end,
        })
    end
    return createdButtons
end

local function addLabel(card, text, isDivider)
    if isDivider then
        local div = Instance.new("Frame")
        div.Size = UDim2.new(1, 0, 0, 1)
        bindColor(div, "BackgroundColor3", "Divider")
        div.BorderSizePixel = 0
        div.Parent = card
        return
    end
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 14)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 9.5
    bindColor(lbl, "TextColor3", "TextDim")
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = card

    return {
        Set = function(t) lbl.Text = tostring(t) end,
    }
end

local function addMultiDropdown(card, name, description, options, defaults, callback)
    local row, top = createRow(card, name, description, {controlHeight = CONTROL_H})

    local states = {}
    for i, opt in ipairs(options) do
        local optText = normalizeOption(opt)
        states[i] = defaults and defaults[optText] or false
    end

    local function buildSummary()
        local picked = {}
        for i, opt in ipairs(options) do
            local optText = normalizeOption(opt)
            if states[i] then table.insert(picked, optText) end
        end
        if #picked == 0 then return "None" end
        return table.concat(picked, ", ")
    end

    local select = Instance.new("TextButton")
    select.Name = "Select"
    select.Size = UDim2.new(1, 0, 0, CONTROL_H)
    select.Position = UDim2.new(0, 0, 0, top)
    bindColor(select, "BackgroundColor3", "BadgeBg")
    select.Text = ""
    select.AutoButtonColor = false
    select.Parent = row
    addCorner(select, 4)
    addStroke(select)

    local valueLbl = Instance.new("TextLabel")
    valueLbl.Size = UDim2.new(1, -52, 1, 0)
    valueLbl.Position = UDim2.new(0, 8, 0, 0)
    valueLbl.BackgroundTransparency = 1
    valueLbl.Text = buildSummary()
    valueLbl.Font = Enum.Font.Gotham
    valueLbl.TextSize = 10.5
    bindColor(valueLbl, "TextColor3", "TextPrimary")
    valueLbl.TextXAlignment = Enum.TextXAlignment.Left
    valueLbl.TextTruncate = Enum.TextTruncate.AtEnd
    valueLbl.Parent = select

    local arrow = Instance.new("ImageLabel")
    arrow.Size = UDim2.new(0, CHEVRON_SIZE, 0, CHEVRON_SIZE)
    arrow.Position = UDim2.new(1, -CHEVRON_SIZE - 6, 0.5, -CHEVRON_SIZE / 2)
    arrow.BackgroundTransparency = 1
    arrow.Image = ICONS.Chevron
    bindColor(arrow, "ImageColor3", "TextMuted")
    arrow.Parent = select

    local currentPopup = nil

    select.MouseButton1Click:Connect(function()
        if currentPopup and currentPopup.Parent then
            currentPopup:Destroy()
            currentPopup = nil
            return
        end
        closeAllPopups()

        local popup = Instance.new("Frame")
        popup.Size = UDim2.new(0, select.AbsoluteSize.X / UI_SCALE, 0, 0)
        popup.AutomaticSize = Enum.AutomaticSize.Y
        popup.Position = UDim2.fromOffset(select.AbsolutePosition.X, select.AbsolutePosition.Y + select.AbsoluteSize.Y + 3)
        bindColor(popup, "BackgroundColor3", "PopupBg")
        popup.BorderSizePixel = 0
        popup.ZIndex = 100
        scalePopup(popup)
        popup.Parent = ScreenGui
        addCorner(popup, 5)
        addStroke(popup)

        local dl = Instance.new("UIListLayout")
        dl.Padding = UDim.new(0, 2)
        dl.SortOrder = Enum.SortOrder.LayoutOrder
        dl.Parent = popup

        local dp = Instance.new("UIPadding")
        dp.PaddingTop = UDim.new(0, 4)
        dp.PaddingBottom = UDim.new(0, 4)
        dp.PaddingLeft = UDim.new(0, 4)
        dp.PaddingRight = UDim.new(0, 4)
        dp.Parent = popup

        local list = Instance.new("ScrollingFrame")
        list.Name = "Options"
        list.Size = UDim2.new(1, 0, 0, 0)
        list.LayoutOrder = 1
        list.BackgroundTransparency = 1
        list.BorderSizePixel = 0
        list.ScrollBarThickness = 3
        bindColor(list, "ScrollBarImageColor3", "TextDim")
        list.CanvasSize = UDim2.new(0, 0, 0, 0)
        list.AutomaticCanvasSize = Enum.AutomaticSize.Y
        list.ZIndex = 101
        list.Parent = popup

        local ll = Instance.new("UIListLayout")
        ll.Padding = UDim.new(0, 2)
        ll.SortOrder = Enum.SortOrder.LayoutOrder
        ll.Parent = list

        local rows = {}
        for i, optData in ipairs(options) do
            local optText, optIconName = normalizeOption(optData)

            local ob = Instance.new("TextButton")
            ob.Size = UDim2.new(1, 0, 0, SELECT_OPTION_H)
            bindColor(ob, "BackgroundColor3", "SidebarActive")
            ob.BackgroundTransparency = 1
            ob.Text = ""
            ob.AutoButtonColor = false
            ob.ZIndex = 101
            ob.LayoutOrder = i
            ob.Parent = list
            addCorner(ob, 4)
            table.insert(rows, {Frame = ob, Text = optText})

            local obIcon = nil
            if optIconName then
                obIcon = Instance.new("ImageLabel")
                obIcon.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
                obIcon.Position = UDim2.new(0, 6, 0.5, -8)
                obIcon.BackgroundTransparency = 1
                obIcon.Image = resolveIcon(optIconName)
                tintIcon(obIcon, optIconName, function() return (states[i]) and "Accent" or "TextMuted" end)
                obIcon.ZIndex = 102
                obIcon.Parent = ob
            end

            local obText = Instance.new("TextLabel")
            obText.Size = UDim2.new(1, -36, 1, 0)
            obText.Position = UDim2.new(0, optIconName and 28 or 8, 0, 0)
            obText.BackgroundTransparency = 1
            obText.Text = optText
            obText.Font = Enum.Font.Gotham
            obText.TextSize = 10.5
            bindColor(obText, "TextColor3", function() return (states[i]) and "Accent" or "TextPrimary" end)
            obText.TextXAlignment = Enum.TextXAlignment.Left
            obText.ZIndex = 102
            obText.Parent = ob

            ob.MouseEnter:Connect(function()
                ob.BackgroundTransparency = 0
            end)
            ob.MouseLeave:Connect(function()
                ob.BackgroundTransparency = 1
            end)
            ob.MouseButton1Click:Connect(function()
                states[i] = not states[i]
                bindColor(obText, "TextColor3", function() return (states[i]) and "Accent" or "TextPrimary" end)
                if obIcon then
                    tintIcon(obIcon, optIconName, function() return (states[i]) and "Accent" or "TextMuted" end)
                end
                valueLbl.Text = buildSummary()
                if callback then callback(options, states) end
            end)
        end

        addPopupSearch(popup, rows, list)
        trackPopup(popup, select)
        currentPopup = popup
    end)

    return {
        Set = function(indexOrText, state)
            local idx = nil
            if type(indexOrText) == "number" then
                idx = indexOrText
            else
                for i, optData in ipairs(options) do
                    local text = normalizeOption(optData)
                    if text == tostring(indexOrText) then
                        idx = i
                        break
                    end
                end
            end
            if not idx or not options[idx] then
                return
            end
            if state == nil then
                state = not states[idx]
            end
            states[idx] = (state == true)
            valueLbl.Text = buildSummary()
            if callback then
                callback(options, states)
            end
        end,
        Get = function()
            local picked = {}
            for i, optData in ipairs(options) do
                if states[i] then
                    local text = normalizeOption(optData)
                    table.insert(picked, text)
                end
            end
            return picked
        end,
    }
end

local function addColorPicker(card, name, description, defaultColor, callback)
    defaultColor = defaultColor or Color3.fromRGB(246, 92, 82)

    local row = createRow(card, name, description, {sideWidth = 50})

    local preview = Instance.new("TextButton")
    preview.Name = "Preview"
    preview.Size = UDim2.new(0, 50, 0, 16)
    preview.Position = UDim2.new(1, -50, 0.5, -8)
    preview.BackgroundColor3 = defaultColor
    preview.Text = ""
    preview.AutoButtonColor = false
    preview.Parent = row
    addCorner(preview, 3)
    addStroke(preview)

    local currentColor = defaultColor
    local currentPopup = nil

    local function setColor(c, fire)
        currentColor = c
        preview.BackgroundColor3 = c
        if fire and callback then callback(c) end
    end

    preview.MouseButton1Click:Connect(function()
        if currentPopup and currentPopup.Parent then
            currentPopup:Destroy()
            currentPopup = nil
            return
        end
        closeAllPopups()

        local popup = Instance.new("Frame")
        popup.Size = UDim2.new(0, 200, 0, 0)
        popup.AutomaticSize = Enum.AutomaticSize.Y
        popup.Position = UDim2.fromOffset(preview.AbsolutePosition.X + preview.AbsoluteSize.X - 200, preview.AbsolutePosition.Y + preview.AbsoluteSize.Y + 4)
        bindColor(popup, "BackgroundColor3", "PopupBg")
        popup.BorderSizePixel = 0
        popup.ZIndex = 100
        scalePopup(popup)
        popup.Parent = ScreenGui
        addCorner(popup, 6)
        addStroke(popup)

        local dp = Instance.new("UIPadding")
        dp.PaddingTop = UDim.new(0, 8)
        dp.PaddingBottom = UDim.new(0, 8)
        dp.PaddingLeft = UDim.new(0, 8)
        dp.PaddingRight = UDim.new(0, 8)
        dp.Parent = popup

        local dl = Instance.new("UIListLayout")
        dl.Padding = UDim.new(0, 6)
        dl.SortOrder = Enum.SortOrder.LayoutOrder
        dl.Parent = popup

        local hexInputRef = nil

        local function refreshHex()
            if hexInputRef then
                hexInputRef.Text = string.format("#%02X%02X%02X",
                    math.floor(currentColor.R * 255 + 0.5),
                    math.floor(currentColor.G * 255 + 0.5),
                    math.floor(currentColor.B * 255 + 0.5))
            end
        end

        local function makeChannel(labelText, channelIdx)
            local r = Instance.new("Frame")
            r.Size = UDim2.new(1, 0, 0, 18)
            r.BackgroundTransparency = 1
            r.Parent = popup

            local l = Instance.new("TextLabel")
            l.Size = UDim2.new(0, 14, 1, 0)
            l.BackgroundTransparency = 1
            l.Text = labelText
            l.Font = Enum.Font.GothamBold
            l.TextSize = 9.5
            bindColor(l, "TextColor3", "TextMuted")
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.Parent = r

            local valLbl = Instance.new("TextLabel")
            valLbl.Size = UDim2.new(0, 24, 1, 0)
            valLbl.Position = UDim2.new(1, -24, 0, 0)
            valLbl.BackgroundTransparency = 1
            valLbl.Font = Enum.Font.GothamBold
            valLbl.TextSize = 9.5
            bindColor(valLbl, "TextColor3", "Accent")
            valLbl.TextXAlignment = Enum.TextXAlignment.Right
            valLbl.Parent = r

            local track = Instance.new("Frame")
            track.Size = UDim2.new(1, -46, 0, 5)
            track.Position = UDim2.new(0, 18, 0.5, -2.5)
            bindColor(track, "BackgroundColor3", "ToggleOff")
            track.BorderSizePixel = 0
            track.Parent = r
            addCorner(track, 3)

            local fill = Instance.new("Frame")
            bindColor(fill, "BackgroundColor3", "Accent")
            fill.BorderSizePixel = 0
            fill.Parent = track
            addCorner(fill, 3)

            local function getChannel()
                if channelIdx == 1 then return currentColor.R end
                if channelIdx == 2 then return currentColor.G end
                return currentColor.B
            end

            local function refresh()
                local v = getChannel()
                fill.Size = UDim2.new(v, 0, 1, 0)
                valLbl.Text = tostring(math.floor(v * 255 + 0.5))
            end
            refresh()

            local dragging = false
            local function update(x)
                local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                fill.Size = UDim2.new(rel, 0, 1, 0)
                valLbl.Text = tostring(math.floor(rel * 255 + 0.5))

                local c
                if channelIdx == 1 then
                    c = Color3.new(rel, currentColor.G, currentColor.B)
                elseif channelIdx == 2 then
                    c = Color3.new(currentColor.R, rel, currentColor.B)
                else
                    c = Color3.new(currentColor.R, currentColor.G, rel)
                end

                setColor(c, true)
                refreshHex()
            end

            track.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                    update(inp.Position.X)
                end
            end)
            trackConn(UserInputService.InputChanged:Connect(function(inp)
                if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
                    update(inp.Position.X)
                end
            end))
            trackConn(UserInputService.InputEnded:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = false
                end
            end))

            return refresh
        end

        local refreshR = makeChannel("R", 1)
        local refreshG = makeChannel("G", 2)
        local refreshB = makeChannel("B", 3)

        local hexBox = Instance.new("Frame")
        hexBox.Size = UDim2.new(1, 0, 0, 20)
        bindColor(hexBox, "BackgroundColor3", "BadgeBg")
        hexBox.BorderSizePixel = 0
        hexBox.Parent = popup
        addCorner(hexBox, 4)
        addStroke(hexBox)

        local hexInput = Instance.new("TextBox")
        hexInput.Size = UDim2.new(1, -12, 1, 0)
        hexInput.Position = UDim2.new(0, 6, 0, 0)
        hexInput.BackgroundTransparency = 1
        hexInput.Text = string.format("#%02X%02X%02X",
            math.floor(currentColor.R * 255 + 0.5),
            math.floor(currentColor.G * 255 + 0.5),
            math.floor(currentColor.B * 255 + 0.5))
        hexInput.Font = Enum.Font.GothamBold
        hexInput.TextSize = 10
        bindColor(hexInput, "TextColor3", "TextPrimary")
        hexInput.TextXAlignment = Enum.TextXAlignment.Left
        hexInput.ClearTextOnFocus = false
        hexInput.Parent = hexBox
        hexInputRef = hexInput

        hexInput.FocusLost:Connect(function()
            local hex = hexInput.Text:gsub("#", "")
            if #hex == 6 then
                local r = tonumber(hex:sub(1, 2), 16)
                local g = tonumber(hex:sub(3, 4), 16)
                local b = tonumber(hex:sub(5, 6), 16)
                if r and g and b then
                    setColor(Color3.fromRGB(r, g, b), true)
                    refreshR()
                    refreshG()
                    refreshB()
                end
            end
            refreshHex()
        end)

        local paletteRow = Instance.new("Frame")
        paletteRow.Size = UDim2.new(1, 0, 0, 18)
        paletteRow.BackgroundTransparency = 1
        paletteRow.Parent = popup

        local palette = Instance.new("UIListLayout")
        palette.FillDirection = Enum.FillDirection.Horizontal
        palette.Padding = UDim.new(0, 4)
        palette.SortOrder = Enum.SortOrder.LayoutOrder
        palette.Parent = paletteRow

        local swatches = {
            Color3.fromRGB(246, 92, 82),
            Color3.fromRGB(255, 180, 0),
            Color3.fromRGB(80, 200, 120),
            Color3.fromRGB(80, 160, 255),
            Color3.fromRGB(180, 100, 255),
            Color3.fromRGB(255, 255, 255),
            Color3.fromRGB(120, 120, 120),
            Color3.fromRGB(20, 20, 20),
        }

        for _, col in ipairs(swatches) do
            local sw = Instance.new("TextButton")
            sw.Size = UDim2.new(0, 16, 0, 16)
            sw.BackgroundColor3 = col
            sw.Text = ""
            sw.AutoButtonColor = false
            sw.Parent = paletteRow
            addCorner(sw, 3)
            addStroke(sw)

            sw.MouseButton1Click:Connect(function()
                setColor(col, true)
                refreshR()
                refreshG()
                refreshB()
                refreshHex()
            end)
        end

        trackPopup(popup, preview)
        currentPopup = popup
    end)

    local colorApi = {
        Set = function(c) setColor(c, true) end,
        Get = function() return currentColor end,
    }
    setmetatable(colorApi, {__call = function(_, c) setColor(c, false) end})
    return colorApi
end

local function addProgressBar(card, name, description, defaultValue, interactive, callback)
    defaultValue = math.clamp(defaultValue or 0, 0, 1)

    local row, top = createRow(card, name, description, {controlHeight = 8, titleInset = 44})

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0, 40, 0, ROW_TITLE_H)
    valLbl.Position = UDim2.new(1, -40, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(math.floor(defaultValue * 100 + 0.5)) .. "%"
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 10
    bindColor(valLbl, "TextColor3", "Accent")
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = row

    local track = Instance.new("Frame")
    track.Name = "Track"
    track.Size = UDim2.new(1, 0, 0, 8)
    track.Position = UDim2.new(0, 0, 0, top)
    bindColor(track, "BackgroundColor3", "ToggleOff")
    track.BorderSizePixel = 0
    track.Parent = row
    addCorner(track, 4)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(defaultValue, 0, 1, 0)
    bindColor(fill, "BackgroundColor3", "Accent")
    fill.BorderSizePixel = 0
    fill.Parent = track
    addCorner(fill, 4)

    local currentValue = defaultValue
    local api = {}

    function api.SetValue(v, fire)
        v = math.clamp(v, 0, 1)
        currentValue = v
        TweenService:Create(fill, TweenInfo.new(0.15), {Size = UDim2.new(v, 0, 1, 0)}):Play()
        valLbl.Text = tostring(math.floor(v * 100 + 0.5)) .. "%"
        if fire and callback then callback(v) end
    end

    function api.GetValue()
        return currentValue
    end
    api.Set = api.SetValue
    api.Get = api.GetValue

    if interactive then
        local dragging = false
        local function update(x)
            local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            api.SetValue(rel, true)
        end

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                update(input.Position.X)
            end
        end)
        trackConn(UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                update(input.Position.X)
            end
        end))
        trackConn(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end))
    end

    return api
end

local RESIZE_MIN_W = 500
local RESIZE_MIN_H = 320

local resizeHandle = Instance.new("TextButton")
resizeHandle.Name = "ResizeHandle"
resizeHandle.Size = UDim2.new(0, 18, 0, 18)
resizeHandle.Position = UDim2.new(1, -18, 1, -18)
resizeHandle.BackgroundTransparency = 1
resizeHandle.Text = ""
resizeHandle.AutoButtonColor = false
resizeHandle.ZIndex = 10
resizeHandle.Parent = Main

local function makeGripLine(xOffset, yOffset, length)
    local line = Instance.new("Frame")
    line.Size = UDim2.new(0, length, 0, 1)
    line.Position = UDim2.new(1, xOffset, 1, yOffset)
    line.AnchorPoint = Vector2.new(1, 1)
    bindColor(line, "BackgroundColor3", "TextDim")
    line.BorderSizePixel = 0
    line.ZIndex = 11
    line.Parent = resizeHandle

    local r = Instance.new("UICorner")
    r.CornerRadius = UDim.new(1, 0)
    r.Parent = line

    return line
end

local gripLine1 = makeGripLine(-4, -4, 14)
local gripLine2 = makeGripLine(-4, -8, 8)

local function setGripColor(key)
    bindColor(gripLine1, "BackgroundColor3", key)
    bindColor(gripLine2, "BackgroundColor3", key)
end

resizeHandle.MouseEnter:Connect(function()
    setGripColor("Accent")
end)
resizeHandle.MouseLeave:Connect(function()
    setGripColor("TextDim")
end)

do
    local resizing = false
    local resizeStart
    local startSize

    resizeHandle.MouseButton1Down:Connect(function()
        resizing = true
        resizeStart = UserInputService:GetMouseLocation()

        startSize = Vector2.new(Main.Size.X.Offset * UI_SCALE, Main.Size.Y.Offset * UI_SCALE)
        closeAllPopups()
    end)

    trackConn(UserInputService.InputChanged:Connect(function(input)
        if not resizing then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
           and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local current = UserInputService:GetMouseLocation()
        local delta = current - resizeStart

        local newW = math.max(RESIZE_MIN_W, startSize.X + delta.X)
        local newH = math.max(RESIZE_MIN_H, startSize.Y + delta.Y)

        local scale = math.clamp(math.sqrt((newW / BASE_W) * (newH / BASE_H)), UI_SCALE_MIN, UI_SCALE_MAX)
        UI_SCALE = scale
        mainScale.Scale = scale
        notifyScale.Scale = scale
        Main.Size = UDim2.new(0, newW / scale, 0, newH / scale)
    end))

    trackConn(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            resizing = false
        end
    end))
end

local function trimText(s)
    return (string.gsub(s or "", "^%s*(.-)%s*$", "%1"))
end

local function isBuiltinName(name)
    for _, preset in ipairs(THEME_PRESETS) do
        if preset.Name == name and not preset.Custom then return true end
    end
    return false
end

local function cleanName(s)
    local name = trimText(s)
    name = (string.gsub(name, "[%[%]\r\n]", ""))
    name = string.sub(name, 1, 24)
    if name == "" then name = CUSTOM_NAME end
    return name
end

local function freeName(base)
    local i = 1
    while true do
        local candidate = base .. " " .. i
        if not isBuiltinName(candidate) and not findSavedTheme(candidate) then
            return candidate
        end
        i = i + 1
    end
end

local function rebuildThemeNames()
    for i = #THEME_NAMES, 1, -1 do
        THEME_NAMES[i] = nil
    end
    for _, preset in ipairs(THEME_PRESETS) do
        if not preset.Custom then table.insert(THEME_NAMES, preset.Name) end
    end
    for _, saved in ipairs(SAVED_THEMES) do
        table.insert(THEME_NAMES, saved.Name)
    end
    table.insert(THEME_NAMES, CUSTOM_NAME)
end

local function loadCustomConfig()
    if not (isfile and readfile) then return end
    local okFile, exists = pcall(isfile, CUSTOM_FILE)
    if not (okFile and exists) then return end
    local okRead, data = pcall(readfile, CUSTOM_FILE)
    if not (okRead and type(data) == "string") then return end

    local blocks, current = {}, nil
    for line in string.gmatch(data, "[^\r\n]+") do
        local active = string.match(line, "^active=(.+)$")
        local header = string.match(line, "^%[(.-)%]$")
        local key, value = string.match(line, "^([%w_]+)=(.+)$")
        if active then
            STARTUP_THEME = trimText(active)
            current = nil
        elseif header then
            current = {Name = trimText(header), Palette = {}}
            table.insert(blocks, current)
        elseif key == "name" then
            current = {Name = trimText(value), Palette = {}}
            table.insert(blocks, current)
        elseif key and current then
            local r, g, b = string.match(value, "^(%d+),(%d+),(%d+)$")
            if r then
                current.Palette[key] = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
            end
        end
    end

    local function complete(block)
        for _, key in ipairs(THEME_KEYS) do
            if not block.Palette[key] then return false end
        end
        return true
    end

    for _, block in ipairs(blocks) do
        if block.Name == CUSTOM_NAME then
            if complete(block) then
                for _, key in ipairs(THEME_KEYS) do
                    CUSTOM_PALETTE[key] = block.Palette[key]
                end
            end
        elseif block.Name ~= "" and not isBuiltinName(block.Name)
            and not findSavedTheme(block.Name) and complete(block) then
            table.insert(SAVED_THEMES, block)
        end
    end
end

local function saveCustomTheme(name)
    local palette = {}
    for _, key in ipairs(THEME_KEYS) do
        palette[key] = THEME[key]
    end
    local saved = findSavedTheme(name)
    if saved then
        saved.Palette = palette
    else
        table.insert(SAVED_THEMES, {Name = name, Palette = palette})
    end
    rebuildThemeNames()
    writeCustomConfig()
    Notify({Title = "Theme saved", Content = "'" .. name .. "' is in the Theme list", Icon = "circle-check", Duration = 3})
end

loadCustomConfig()
rebuildThemeNames()

local function themeDefaultIndex()
    for i, name in ipairs(THEME_NAMES) do
        if name == currentThemeName then
            return i
        end
    end
    return 1
end

local function buildThemeCards(themeTabName)
local cardSettings = createCard(Col1, "Settings", 0, themeTabName)
setThemeLabel = addDropdown(cardSettings, "Theme", "Changes the color palette of the whole UI", THEME_NAMES, themeDefaultIndex(), function(themeName)
    applyTheme(themeName)
end)

addButtonRow(cardSettings, "Notification", "Preview the notification popup", {
    { Text = "Show", Callback = function()
        Notify({Title = "Notification", Content = "This is how notifications look.", Icon = "circle-check", Duration = 4})
    end },
})

local cardCustomTheme = createCard(Col1, "Custom Theme", 1, themeTabName)

local customPickers = {}

local function activateCustom(palette)
    for _, key in ipairs(THEME_KEYS) do
        CUSTOM_PALETTE[key] = palette[key]
        THEME[key] = palette[key]
    end
    currentThemeName = "Custom"
    setThemeLabel(CUSTOM_NAME, #THEME_NAMES)
    refreshTheme()
    syncCustomPickers()
    writeCustomConfig()
end

local function setCustomToken(key, color)
    if currentThemeName ~= "Custom" then

        for _, k in ipairs(THEME_KEYS) do
            CUSTOM_PALETTE[k] = THEME[k]
        end
        currentThemeName = "Custom"
        setThemeLabel(CUSTOM_NAME, #THEME_NAMES)
        writeCustomConfig()
    end
    CUSTOM_PALETTE[key] = color
    THEME[key] = color
    refreshTheme()
end

syncCustomPickers = function()
    for key, setter in pairs(customPickers) do
        setter(THEME[key])
    end
end

local function addTokenPicker(key, name, description)
    customPickers[key] = addColorPicker(cardCustomTheme, name, description, THEME[key], function(c)
        setCustomToken(key, c)
    end)
end

addButtonRow(cardCustomTheme, "Start from", "Copy the theme on screen, or reset to Default", {
    { Text = "Current", Callback = function()
        local snapshot = {}
        for _, key in ipairs(THEME_KEYS) do
            snapshot[key] = THEME[key]
        end
        activateCustom(snapshot)
    end },
    { Text = "Default", Callback = function() activateCustom(DEFAULT_PALETTE) end },
})

addLabel(cardCustomTheme, "WINDOW")
addTokenPicker("Background", "Window", "Main window background")
addTokenPicker("CardBg", "Cards", "Card and search box background")
addTokenPicker("Border", "Outlines", "Window, card and input borders")
addTokenPicker("Divider", "Dividers", "Lines between rows")

addLabel(cardCustomTheme, "ACCENT & TABS")
addTokenPicker("Accent", "Accent", "Buttons, enabled toggles, slider fill, highlights")
addTokenPicker("BorderActive", "Active tab outline", "Outline of the selected sidebar tab")
addTokenPicker("SidebarActive", "Active tab fill", "Background of the selected sidebar tab")

addLabel(cardCustomTheme, "TOGGLES & INPUTS")
addTokenPicker("ToggleOff", "Toggle track (off)", "Track of a toggle that is off")
addTokenPicker("KnobOff", "Toggle knob (off)", "Knob of a toggle that is off")
addTokenPicker("KnobOn", "Button text", "Knob of an enabled toggle and text on buttons")
addTokenPicker("BadgeBg", "Dropdown and input fill", "Background of dropdowns, inputs and keybinds")

addLabel(cardCustomTheme, "TEXT")
addTokenPicker("TextPrimary", "Primary text", "Titles and values")
addTokenPicker("TextMuted", "Muted text & icons", "Sidebar icons and secondary text")
addTokenPicker("TextDim", "Dim text", "Descriptions, group labels and placeholders")

addLabel(cardCustomTheme, "BRAND & POPUPS")
addTokenPicker("BrandText", "Brand name", "App name in the top bar")
addTokenPicker("VersionBg", "Version badge", "Background of the version badge")
addTokenPicker("VersionText", "Version text", "Text of the version badge")
addTokenPicker("PopupBg", "Popup background", "Dropdown and colour popups")

addLabel(cardCustomTheme, "CONFIG")

local nameBox = addInput(cardCustomTheme, "Name", "Name of the custom theme in the Theme list", "Custom", CUSTOM_NAME, nil)

addButtonRow(cardCustomTheme, "Save", "Saves the colours above as a theme in the Theme list", {
    { Text = "Save", Callback = function()
        local name = cleanName(nameBox.Text)
        if isBuiltinName(name) then
            Notify({Title = "Name is taken", Content = "'" .. name .. "' is a built-in theme. Pick another name.", Icon = "palette", Duration = 3})
            return
        end
        if name == CUSTOM_NAME then
            name = freeName(CUSTOM_NAME)
        end
        nameBox.Text = name
        saveCustomTheme(name)
    end },
})

end

local isUIVisible = true
local lastMainPosition = Main.Position

local CollapseBtn = Instance.new("ImageButton")
CollapseBtn.Name = "CollapseButton"
CollapseBtn.Size = UDim2.new(0, 17, 0, 17)
CollapseBtn.Position = UDim2.new(1, -58, 0.5, -8.5)
CollapseBtn.BackgroundTransparency = 1
CollapseBtn.Image = LUCIDE["minus"]
bindColor(CollapseBtn, "ImageColor3", "TextMuted")
CollapseBtn.Parent = TopBar

CollapseBtn.MouseEnter:Connect(function()
    tweenColors(CollapseBtn, TWEEN_FAST, {ImageColor3 = "TextPrimary"}):Play()
end)
CollapseBtn.MouseLeave:Connect(function()
    tweenColors(CollapseBtn, TWEEN_FAST, {ImageColor3 = "TextMuted"}):Play()
end)

local OPEN_BUTTON_W = 128
local OpenButton = Instance.new("TextButton")
OpenButton.Name = "OpenUIButton"
OpenButton.Size = UDim2.new(0, OPEN_BUTTON_W, 0, 32)

OpenButton.AnchorPoint = Vector2.new(0.5, 0)
OpenButton.Position = UDim2.new(0.5, 0, 0, 12)
bindColor(OpenButton, "BackgroundColor3", "Accent")
OpenButton.AutoButtonColor = false
OpenButton.Text = ""
OpenButton.Visible = false
OpenButton.ZIndex = 50
OpenButton.Parent = ScreenGui
addCorner(OpenButton, 6)

local openIcon = Instance.new("ImageLabel")
openIcon.Name = "Icon"
openIcon.Size = UDim2.new(0, 20, 0, 20)
openIcon.Position = UDim2.new(0, 10, 0.5, -10)
openIcon.BackgroundTransparency = 1
openIcon.Image = LOGO_ASSET or ""
openIcon.ImageRectOffset = Vector2.new(105, 112)
openIcon.ImageRectSize = Vector2.new(202, 200)
openIcon.ScaleType = Enum.ScaleType.Fit
openIcon.Visible = LOGO_ASSET ~= nil
openIcon.ZIndex = 51
openIcon.Parent = OpenButton

local openLabel = Instance.new("TextLabel")
openLabel.Name = "Label"
openLabel.Size = UDim2.new(1, -42, 1, 0)
openLabel.Position = UDim2.new(0, 36, 0, 0)
openLabel.BackgroundTransparency = 1
openLabel.Text = "Open " .. BRAND_NAME
openLabel.Font = Enum.Font.GothamBold
openLabel.TextSize = 12
openLabel.TextXAlignment = Enum.TextXAlignment.Left
bindColor(openLabel, "TextColor3", "KnobOn")
openLabel.ZIndex = 51
openLabel.Parent = OpenButton

local function setUIOpen(open)
    if open == isUIVisible then return end
    isUIVisible = open

    if open then
        OpenButton.Visible = false
        Main.Visible = true
        Main.Position = lastMainPosition + UDim2.fromOffset(0, 30)
        TweenService:Create(Main, TWEEN_SLOW, {Position = lastMainPosition}):Play()
    else
        lastMainPosition = Main.Position
        closeAllPopups()
        Main.Visible = false
        OpenButton.Visible = true
        Notify({Title = "Menu hidden", Content = "Click 'Open " .. BRAND_NAME .. "' to show it again", Icon = "eye", Duration = 3})
    end
end

CollapseBtn.MouseButton1Click:Connect(function()
    setUIOpen(false)
end)

unloadScript = function()
    if isClosed then return end
    isClosed = true
    for _, conn in ipairs(CONNECTIONS) do
        conn:Disconnect()
    end
    CONNECTIONS = {}
    closeAllPopups()
    writeCustomConfig()
    ScreenGui:Destroy()
end

do
    local dragging, moved = false, false
    local dragStart, startPos
    OpenButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            moved = false
            dragStart = input.Position
            startPos = OpenButton.Position
        end
    end)
    trackConn(UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then
                moved = true
            end
            if moved then
                OpenButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end))
    trackConn(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end))
    OpenButton.MouseButton1Click:Connect(function()
        if moved then return end
        setUIOpen(true)
    end)
end

local TOGGLE_KEY = options.ToggleKey or Enum.KeyCode.RightShift
trackConn(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not isClosed and not gameProcessed and input.KeyCode == TOGGLE_KEY then
        setUIOpen(not isUIVisible)
    end
end))

if STARTUP_THEME and STARTUP_THEME ~= currentThemeName then
    local idx = nil
    for i, name in ipairs(THEME_NAMES) do
        if name == STARTUP_THEME then
            idx = i
            break
        end
    end
    if idx and setTheme(STARTUP_THEME) then
        setThemeLabel(STARTUP_THEME, idx)
    end
end

    local Window = {}
    Window.Tabs = {}
    Window.Flags = Library.Flags

    local colOrders = {0, 0}

    local function resolveTabIcon(icon)
        if icon == nil then
            return ICONS.Misc
        end
        if type(icon) == "string" then
            if LUCIDE[icon] then
                return LUCIDE[icon]
            end
            if ICONS[icon] then
                return ICONS[icon]
            end
            return icon
        end
        return icon
    end

    local function nextSidebarOrder()
        sidebarOrder = sidebarOrder + 1
        return sidebarOrder
    end

    function Window:CreateCategory(categoryOptions, collapsedMaybe)
        local cName = "Category"
        local cCollapsed = false
        if type(categoryOptions) == "table" then
            cName = categoryOptions.Name or categoryOptions.Title or cName
            cCollapsed = categoryOptions.Collapsed or categoryOptions.Collapse or false
        elseif categoryOptions ~= nil then
            cName = tostring(categoryOptions)
            cCollapsed = collapsedMaybe or false
        end
        return addCategory(cName, nextSidebarOrder(), cCollapsed)
    end
    Window.AddCategory = Window.CreateCategory

    function Window:CreateTab(tabOptions, iconMaybe)
        local opts = {}
        if type(tabOptions) == "string" then
            opts.Name = tabOptions
            opts.Icon = iconMaybe
        elseif type(tabOptions) == "table" then
            opts = tabOptions
        end
        local baseName = opts.Name or opts.Title or ("Tab" .. (#Window.Tabs + 1))

        local tabName = baseName
        local dup = 2
        while TAB_ACTIVATORS[tabName] do
            tabName = baseName .. " " .. dup
            dup = dup + 1
        end

        local isFirst = (#Window.Tabs == 0)
        addSidebarItem(tabName, resolveTabIcon(opts.Icon), isFirst, nextSidebarOrder())
        if isFirst then
            showTabContent(tabName)
        end

        local Tab = {}
        Tab.Name = tabName
        table.insert(Window.Tabs, Tab)

        function Tab:Select()
            local activate = TAB_ACTIVATORS[tabName]
            if activate then activate() end
        end

        function Tab:CreateSection(sectionOptions, columnMaybe)
            local sOpts = {}
            if type(sectionOptions) == "string" then
                sOpts.Title = sectionOptions
                sOpts.Column = columnMaybe
            elseif type(sectionOptions) == "table" then
                sOpts = sectionOptions
            end
            local title = sOpts.Title or sOpts.Name or "Section"
            local column = tonumber(sOpts.Column) or 0
            if column ~= 1 and column ~= 2 then
                column = (colOrders[1] <= colOrders[2]) and 1 or 2
            end
            colOrders[column] = colOrders[column] + 1
            local parentCol = (column == 1) and Col1 or Col2
            local body = createCard(parentCol, title, colOrders[column], tabName)
            if activeSidebarTab and activeSidebarTab.Name == tabName then
                showTabContent(tabName)
            end

            local Section = {}

            local function flagCallback(flag, callback, transform)
                if callback == nil and flag == nil then
                    return nil
                end
                return function(...)
                    if flag ~= nil then
                        if transform then
                            Library.Flags[flag] = transform(...)
                        else
                            Library.Flags[flag] = ...
                        end
                    end
                    if callback then
                        callback(...)
                    end
                end
            end

            local function optText(value)
                if type(value) == "table" then
                    return tostring(value.Text or "")
                end
                return tostring(value)
            end

            local function descOf(o)
                return o.Description or o.Desc
            end

            function Section:CreateToggle(tOpts)
                tOpts = tOpts or {}
                local default = tOpts.Default
                if default == nil then
                    default = tOpts.Value
                end
                default = (default == true)
                if tOpts.Flag ~= nil then
                    Library.Flags[tOpts.Flag] = default
                end
                return addToggle(body, tOpts.Name or tOpts.Title or "Toggle",
                    descOf(tOpts), default, flagCallback(tOpts.Flag, tOpts.Callback))
            end

            function Section:CreateButtonRow(rOpts, buttonsMaybe)
                local o = {}
                if type(rOpts) == "string" then
                    o.Name = rOpts
                    o.Buttons = buttonsMaybe
                elseif type(rOpts) == "table" then
                    o = rOpts
                end
                return addButtonRow(body, o.Name or o.Title or "",
                    descOf(o), o.Buttons or o.Value or {})
            end

            function Section:CreateButton(bOpts, maybeCallback)
                local o = {}
                if type(bOpts) == "string" then
                    o.Name = bOpts
                    o.Callback = maybeCallback
                elseif type(bOpts) == "table" then
                    o = bOpts
                end
                local name = o.Name or o.Title or "Button"
                local created = addButtonRow(body, name, descOf(o), {
                    {Text = o.Text or name, Callback = o.Callback},
                })
                return created[1]
            end

            function Section:CreateSlider(sOpts)
                sOpts = sOpts or {}
                local min = sOpts.Min
                if min == nil then
                    min = sOpts.Minimum or 0
                end
                local max = sOpts.Max
                if max == nil then
                    max = sOpts.Maximum or 100
                end
                local default = sOpts.Default
                if default == nil then
                    default = sOpts.Value or min
                end
                local decimals = sOpts.Decimals or sOpts.Decimal or 0
                if sOpts.Flag ~= nil then
                    Library.Flags[sOpts.Flag] = default
                end
                return addSlider(body, sOpts.Name or sOpts.Title or "Slider",
                    descOf(sOpts), min, max, default, decimals,
                    flagCallback(sOpts.Flag, sOpts.Callback))
            end

            function Section:CreateDropdown(dOpts)
                dOpts = dOpts or {}
                local list = dOpts.Options or dOpts.Values or {}
                local defIdx = 1
                if type(dOpts.Default) == "number" and list[dOpts.Default] then
                    defIdx = dOpts.Default
                elseif dOpts.Default ~= nil then
                    for i, v in ipairs(list) do
                        if optText(v) == tostring(dOpts.Default) then
                            defIdx = i
                            break
                        end
                    end
                end
                if dOpts.Flag ~= nil then
                    Library.Flags[dOpts.Flag] = list[defIdx] and optText(list[defIdx]) or ""
                end
                return addDropdown(body, dOpts.Name or dOpts.Title or "Dropdown",
                    descOf(dOpts), list, defIdx, flagCallback(dOpts.Flag, dOpts.Callback))
            end

            function Section:CreateMultiDropdown(mOpts)
                mOpts = mOpts or {}
                local list = mOpts.Options or mOpts.Values or {}
                local defaultsMap = {}
                if type(mOpts.Default) == "table" then
                    for k, v in pairs(mOpts.Default) do
                        if type(k) == "number" then
                            defaultsMap[tostring(v)] = true
                        else
                            defaultsMap[tostring(k)] = (v == true)
                        end
                    end
                end
                local function selectedList(states)
                    local picked = {}
                    for i, v in ipairs(list) do
                        if states and states[i] then
                            table.insert(picked, optText(v))
                        end
                    end
                    return picked
                end
                local function initialStates()
                    local st = {}
                    for i, v in ipairs(list) do
                        st[i] = defaultsMap[optText(v)] or false
                    end
                    return st
                end
                if mOpts.Flag ~= nil then
                    Library.Flags[mOpts.Flag] = selectedList(initialStates())
                end
                local function transform(_options, states)
                    return selectedList(states)
                end
                return addMultiDropdown(body, mOpts.Name or mOpts.Title or "Multi",
                    descOf(mOpts), list, defaultsMap,
                    flagCallback(mOpts.Flag, mOpts.Callback, transform))
            end

            function Section:CreateInput(iOpts)
                iOpts = iOpts or {}
                local default = iOpts.Default
                if default == nil then
                    default = iOpts.Value or ""
                end
                if iOpts.Flag ~= nil then
                    Library.Flags[iOpts.Flag] = tostring(default)
                end
                local wrapped = flagCallback(iOpts.Flag, iOpts.Callback)
                local input = addInput(body, iOpts.Name or iOpts.Title or "Input",
                    descOf(iOpts), iOpts.Placeholder, tostring(default), wrapped)
                return {
                    Box = input,
                    Set = function(v)
                        input.Text = tostring(v)
                        if wrapped then wrapped(input.Text) end
                    end,
                    Get = function() return input.Text end,
                }
            end
            Section.CreateTextbox = Section.CreateInput

            function Section:CreateKeybind(kOpts)
                kOpts = kOpts or {}
                local default = kOpts.Default
                if default == nil then
                    default = kOpts.Value or "None"
                end
                if kOpts.Flag ~= nil then
                    Library.Flags[kOpts.Flag] = tostring(default)
                end
                return addKeybind(body, kOpts.Name or kOpts.Title or "Keybind",
                    descOf(kOpts), tostring(default), flagCallback(kOpts.Flag, kOpts.Callback))
            end
            Section.CreateBind = Section.CreateKeybind

            function Section:CreateColorPicker(cOpts)
                cOpts = cOpts or {}
                local default = cOpts.Default or cOpts.Value or Color3.fromRGB(246, 92, 82)
                if cOpts.Flag ~= nil then
                    Library.Flags[cOpts.Flag] = default
                end
                return addColorPicker(body, cOpts.Name or cOpts.Title or "Color",
                    descOf(cOpts), default, flagCallback(cOpts.Flag, cOpts.Callback))
            end

            function Section:CreateProgressBar(pOpts)
                pOpts = pOpts or {}
                local default = pOpts.Default
                if default == nil then
                    default = pOpts.Value or 0
                end
                if pOpts.Flag ~= nil then
                    Library.Flags[pOpts.Flag] = default
                end
                return addProgressBar(body, pOpts.Name or pOpts.Title or "Progress",
                    descOf(pOpts), default, pOpts.Interactive or false,
                    flagCallback(pOpts.Flag, pOpts.Callback))
            end

            function Section:CreateLabel(text)
                return addLabel(body, tostring(text), false)
            end

            function Section:CreateDivider()
                return addLabel(body, "", true)
            end

            Section.AddToggle = Section.CreateToggle
            Section.AddButton = Section.CreateButton
            Section.AddButtonRow = Section.CreateButtonRow
            Section.AddSlider = Section.CreateSlider
            Section.AddDropdown = Section.CreateDropdown
            Section.AddMultiDropdown = Section.CreateMultiDropdown
            Section.AddInput = Section.CreateInput
            Section.AddTextbox = Section.CreateInput
            Section.AddKeybind = Section.CreateKeybind
            Section.AddBind = Section.CreateKeybind
            Section.AddColorPicker = Section.CreateColorPicker
            Section.AddProgressBar = Section.CreateProgressBar
            Section.AddLabel = Section.CreateLabel
            Section.AddDivider = Section.CreateDivider

            return Section
        end
        Tab.AddSection = Tab.CreateSection

        return Tab
    end
    Window.AddTab = Window.CreateTab

    local themeTabBuilt = false
    function Window:CreateThemeTab(name, icon)
        local tab = Window:CreateTab(name or "Themes", icon or "palette")
        if not themeTabBuilt then
            themeTabBuilt = true
            buildThemeCards(tab.Name)
            if activeSidebarTab then
                showTabContent(activeSidebarTab.Name)
            end
        end
        return tab
    end

    function Window:Notify(opts)
        return Notify(opts)
    end

    function Window:SetTheme(themeName, silent)
        if silent then
            return setTheme(themeName)
        end
        applyTheme(themeName)
        return currentThemeName == themeName
    end

    function Window:GetTheme()
        return currentThemeName
    end

    function Window:GetThemes()
        local copy = {}
        for i, name in ipairs(THEME_NAMES) do
            copy[i] = name
        end
        return copy
    end

    function Window:Toggle(visible)
        if visible == nil then
            setUIOpen(not isUIVisible)
        else
            setUIOpen(visible and true or false)
        end
    end

    function Window:IsVisible()
        return isUIVisible
    end

    function Window:SetFooter(text)
        SubLabel.Text = tostring(text)
    end

    function Window:Destroy()
        unloadScript()
    end

    return Window
end

return Library
