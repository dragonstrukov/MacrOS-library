local Library = {}
Library.Version = "1.3.0"
Library.Flags = {}

--[[ Module/stage runner (MacrOS-style): Library.Stage("Catalog", function() ... end)
    Runs the function in a protected call, keeps the result in Library.Stages[name]
    and reports errors through the window notification when one exists. ]]
Library.Stages = {}
function Library.Stage(name, fn, ...)
    if type(name) == "function" then fn, name = name, "stage" end
    if type(fn) ~= "function" then return false, "Stage " .. tostring(name) .. ": no function" end
    local ok, result = pcall(fn, ...)
    Library.Stages[name] = ok and (result == nil and true or result) or nil
    if not ok then
        warn(("[UI Library] stage '%s' failed: %s"):format(tostring(name), tostring(result)))
        if type(Library.Notify) == "function" then
            pcall(Library.Notify, {Title = "Stage failed: " .. tostring(name), Content = tostring(result), Icon = "alert-triangle", Duration = 6})
        end
    end
    return ok, result
end
Library.stage = Library.Stage

-- Executor file helpers (nil-safe: return nil / false when the executor lacks them)
function Library.ReadFile(path)
    if type(readfile) ~= "function" then return nil end
    if type(isfile) == "function" then
        local okExists, exists = pcall(isfile, path)
        if okExists and not exists then return nil end
    end
    local ok, data = pcall(readfile, path)
    return ok and data or nil
end
function Library.WriteFile(path, data)
    if type(writefile) ~= "function" then return false end
    local folder = string.match(path, "^(.*)/[^/]+$")
    if folder and type(makefolder) == "function" then
        local acc = ""
        for part in string.gmatch(folder, "[^/]+") do
            acc = (acc == "") and part or (acc .. "/" .. part)
            if type(isfolder) ~= "function" or not isfolder(acc) then pcall(makefolder, acc) end
        end
    end
    return (pcall(writefile, path, data))
end
function Library.JSONDecode(text)
    local ok, res = pcall(function() return game:GetService("HttpService"):JSONDecode(text) end)
    return ok and res or nil, (not ok) and res or nil
end
function Library.JSONEncode(value)
    local ok, res = pcall(function() return game:GetService("HttpService"):JSONEncode(value) end)
    return ok and res or nil
end
Library.readFile, Library.writeFile = Library.ReadFile, Library.WriteFile

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

function Library:CreateWindow(options)
    options = options or {}

local LocalPlayer = Players.LocalPlayer

local function getViewportSize()
    local ok, size = pcall(function()
        local camera = workspace.CurrentCamera
        return camera and camera.ViewportSize or nil
    end)
    if ok and size and size.X > 0 and size.Y > 0 then
        return size
    end
    return Vector2.new(1280, 720)
end

local function isMobileDevice(viewport)
    viewport = viewport or getViewportSize()
    local ok, platform = pcall(function()
        return UserInputService:GetPlatform()
    end)
    local platformName = ok and string.lower(tostring(platform)) or ""
    if string.find(platformName, "android", 1, true) or string.find(platformName, "ios", 1, true) then
        return true
    end
    return viewport.X <= 720 or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
end

local function shiftHeld()
    local left, right = false, false
    pcall(function() left = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) end)
    pcall(function() right = UserInputService:IsKeyDown(Enum.KeyCode.RightShift) end)
    return left or right
end

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

local DEFAULT_MAIN_W, DEFAULT_MAIN_H = 790, 490
local INITIAL_VIEWPORT = getViewportSize()
local INITIAL_MOBILE = isMobileDevice(INITIAL_VIEWPORT)
local MAIN_START_W, MAIN_START_H = DEFAULT_MAIN_W, DEFAULT_MAIN_H
if INITIAL_MOBILE then
    MAIN_START_W = math.min(DEFAULT_MAIN_W, math.max(200, INITIAL_VIEWPORT.X - 24))
    MAIN_START_H = math.min(DEFAULT_MAIN_H, math.max(200, INITIAL_VIEWPORT.Y - 24))
end

local Main = Instance.new("Frame")
Main.Name = "MainFrame"
Main.Size = UDim2.new(0, MAIN_START_W, 0, MAIN_START_H)
Main.Position = UDim2.new(0.5, -MAIN_START_W / 2, 0.5, -MAIN_START_H / 2)
bindColor(Main, "BackgroundColor3", "Background")
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = ScreenGui

local UI_SCALE = 1
local UI_SCALE_MIN, UI_SCALE_MAX = 0.6, 2.0
local BASE_W, BASE_H = MAIN_START_W, MAIN_START_H
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

-- Frames that float above the main window (Browse windows, dialogs). Input that
-- lands on them must never start a drag of the main window underneath.
local FLOATING_FRAMES = setmetatable({}, { __mode = "k" })
local function pointOnFloatingFrame(x, y)
    for frame in pairs(FLOATING_FRAMES) do
        if frame.Parent and frame.Visible then
            local p0 = frame.AbsolutePosition
            local p1 = p0 + frame.AbsoluteSize
            if x >= p0.X and x <= p1.X and y >= p0.Y and y <= p1.Y then
                return true
            end
        end
    end
    return false
end
local function inputOnFloatingFrame(input)
    local x, y = input.Position.X, input.Position.Y
    if pointOnFloatingFrame(x, y) then return true end
    local ok, inset = pcall(function() return game:GetService("GuiService"):GetGuiInset() end)
    if ok and inset then
        return pointOnFloatingFrame(x, y - inset.Y) or pointOnFloatingFrame(x, y + inset.Y)
    end
    return false
end

do
    local dragging, dragStart, startPos
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if inputOnFloatingFrame(input) then return end
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
local PANEL_LIST = {} -- full-area panels (Browse tab etc.) shown instead of the two columns

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
    local panelShown = false
    for _, entry in ipairs(PANEL_LIST) do
        local show = entry.Tab == tabName
        entry.Frame.Visible = show
        if show then
            panelShown = true
            if entry.OnShow then task.spawn(entry.OnShow) end
        end
    end
    Col1.Visible = not panelShown
    Col2.Visible = not panelShown
    emptyLabel.Visible = shown == 0 and not panelShown
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

local ICON_CUBE3D_B64 = [==[iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAYQElEQVR42tWbe4xd93HfPzO/c+++uUsu36T5kBhRLxtOrMRIgpZS6yIJ0jo1EqppCiFxnKRN4caPJHVs11guWtluHMQOXCuRXNeW00dCtmiL2GjqtpDkFJBayHacSLQdkRLf5C4fS+7j7t57zm+mf/x+59xLk7ZoN3bVBRZ7d/fee87Mb+Y73/nOXPgufLm7+BMzRf37+T/5L/es/I9H/6D3n95zuffZfzrXeeYPHnnpS0/vaZ7/xEzh7vLduDf5zhqOPPnkTHjggdkK4PQzT+xcv3LsV9vXTryltXpqgoWzoC3YtJfexJ5L1eTujy1M3vbRnXe//nJ6/eEg8mD8/9EB4ocPqzyYbv7o//pv069aevFt7ZXz/6jdPTPFhePEqjQthlTALXZNh0YDO++iHN11rju1+7efHb7z0QfuvXcZwA8fDvV7veIdMHizzz57dnT/0ud+qb14+lfbayd3MvcCVL2KMBxcRLy5C8FdHFuLYWSiYPs99MZ2v1CO7/zgh1be9OnZB6RyRzjSd+orzgF++GDg+SMus9jME168vffxnx3tXvz1dvfsfua+gq2tVOhQUFUxoG++gAiSf5qZU/VMJ6YC2++mO7H3S2tjOz84dd/fPgyO+4zCIUTEXhEO8JkZBZDZWQO49NlP/uTY2tn3DvdOfi+XX8BWliJFW0WDgOP5xAGcZLiIDDgj/XSP5rHnYf3mwJZ76E3s+fzqyLaHp+574+f6Dr/b6+t+1x3gMzPKPfdIHZIXPvOJN0x0Lv/GaPfMX2fhq8Tl+ShFSzS01N1wSYYnY7Mj8uWlvg0ZuB3RFBFeGrHysHFHYMOdrE3d/kedkd0fmH7d33i6BspDh5732W/TEfKtI7sLR440uXjyyOP3beicet949+wbWTlBvHbBpCiQdksRBxzckwNU8iU9O0IGzR+IjIHHkp7rMUbcRDfv0mpqP9XUrn/bGd/9genX/shzdenk/kNxEFr+Uh3g7vLkoUPhgdlU0r76yU/euVUW3jWycuah9sqxEBdOmxe4tNpB1NM7a/oW8WyQ908XT3GQHSF6s1sThOQ8QXERPPaiiijb9ko1sb9bTu/7RHfyez60/q4fPPHtOOJlHeAgT87MNIY/9+jju3bE8782sjr3lqG1M6PxyklQi7SLQDBQQ1RAaidIbUuNd/2ruuNa30Z+XYMNuToMJovUzhMsdmMIRWDHfnrjdyxWU7t/d378zo/svff1FwCeeGKmuP+B2SiN178NBwyWtD/5N59Zv//asV8ZXzz7tpHlU+vj5RNEyijD7SAFiCZjJBgE7xutA9HdOCSfLPk1ZIcNwkCTAjU2ysDdSi6d7sS1qEW7YOddlFN3zVVT+z58ctf9j9y1adPSrXCImzrg8MGD4eCRIybgH/r0p8ceunzhF8c7194xtnR+l88fp7RORbsVpHBJBgsEQ5TsBAftR4DIgEP60Z2/62ipw73+PTtEhetCQGrjSTgi4G5O7EYdHi941WsoJ/YdL9e96kMvfd/BT94r0nNHYEZEbgRKuUnIq4ARAic/8M9/bvLi2XdPdi/f4RdPUvY6VT5xIXg66cLxkCIA9RShgfw4G5Od4Y3RPlD6vt4h6Xky8BMFwRN8Djgu/T9HlAYwc6q1yOi6gh130x3/nj9fm7z94anX/eQfguEzM/r1ZfM6B8zMzOjs7Kz96Vvf/td2jej713cXX8/ZF1lbXaq8VYRQqIg6UpAML/LNFeDqSHaAqyMhG6FkBwiIpZSobxxvTj/diWfDsoMUXCQfujevhVxWc/o0TkFRDeClWdVzndoc2PoauqO7P9+ZuO29G+574/90d7mOhA6G/YNHjsRnf/wnfuRVp0//8YbNk6x5NwbvSTHUVloBU0c0JiOLZLiEhEuWw16CZPTvG9s3mq8DxFweG+P8RrAUybgxmFb1+/p1sOAAGprUMBWLOurtNqFr7bgy9eq/svHB33r6Dw8fDA8+eCQCNC0qR44AMDEx8Y7WpStcWFrpDd+2q93euBVbuUZYvooOBRhq4ThSJRS3CBocMerkyacu15dAHXB5nRKk0044MVgxvDlh1MHyc1yTIyw7zPrXSZjgeOxhoYCRTXgxrr54mc5Srzs6wtDi2b94q8PTm54/0vitccCDEFGFrZu3LQX18uq1Ih79C6ot0wzfvhfZuBVfnEOXryLtAK0WWCp7HiXlfTAkSk6D60MYSanRBz6uf6xfVzlEEsZoijA3b14v9emH7ChzoILQRtbthGKCuHSZuHoOWpuxkQ1Ft7fg1cT2rQD3J9dd7wBJZIeoLcp166RnpUfv4XNniYtXqPbsZmT/HWhw7MxxWLmGtgt0qIW74+YQNVWB/M0gH8iG+ddFgYhkw6R5Tm0gUSDk/9fvKf3S6ThYD0ILJnbi41uwtRXs0hxWTODDO1i9PM/SmT9mct2khNe9JpfDGWD2egc0qBArogvl0Di0nco6qK2xeuqrlBdPM3L7PobveDUaK/z0MarFy0gRkFYAFyQ2XCWhtEo/z+teYKAaJIMlGVy/TnP5q52gKRo8pBIrGFRdvAiwfhe6fi9WdokXT2Im+NBOusvLdM4+w9rVeaqqohqfJpblDVWvuEkZTN2YGeaBcngc05Lgq5iv4Me/TO/KaYbuuIeRu16DLl2jOv0isnwNLQooihQNcn3pE9HmsTdNn1wHaAxUDNMEsH0cEMTAqxJa4FO7kA17wY3e+RO4GYxuo9vpsHLiC6xdOYeJIsUwgV6+YOAbOkAGoyA/MnOsAm8VeHsCKSqQDrG8RPlnT1GePsrYXa+jdd8PYVeuYCdegMWrSAhQhEzocjOTK0+dAgkbvN8lqqSTr/NbgQgeckUpyxQB01uQbfugNUq1cApfXcCHJunFks4Lf8raldNEd6QYSUkSDTdy2w0vGwGI4gjpEAXxhPAenTK0qFrjhKJLS3tU1TzLR/87rblXMbz3tRTfex92cZ7q1EvI0jJBC6QI2Wy5jgil3wdSoj75uuYXGUzLEg+ObNhM2LYHHxmlvDKPrZ6AsXXEYiOd019lZe4YlUWkPYyEhA/i0hAld7lpU1DcRMjEPcepp1IT64iORqgc1zax1aYsepisUl09Rvml07Q37Wb4ttfS/oEfxuYuYSdehKVlRBUNmh2R6K6qDDA7wW2ACapDVaWImN5E2LEXxsYoFy8RL3wNb49QhXE6p46zdvE4VdVFWkNoawhzB8sk7DrVgZu2RcU36hA8dyJujpugBmLJq25GLMGkRWgJYaQL0sMXX8CeP097837a2++ltfkHiRfOYSdPYsudlBpBG9KXeqD6ZPIfYpW8vW4DumMnMrmO8toC1YVz+MgI1t7E6vxLLJ9/nqpawYdG0NZoOikzRFOpaTgGoOlUb2rqTUDQ0jkJmEsKIzPI9d1iylcJoGZ4VKpiBIo2PlTirGKXvki1cIxiej+tLXcSNt6Hzc3D3DzS6YAqrkrSBqWuwSlsJ9cTtmzDx8cor12m/OpRbLiNjYyzNn+eztmvUK4twsgQ2l6XyqKle1aVTMi8Lz0A0dLvN1MRbyiDZo66Z4flNzIB85r35PRIkeGAmGGV4NLGWgXe6hHtKuXF/01v4TjtTfdQbLkTtu7A5y/CpYvQ6yFa9E9/qI1u2gyjY/QWF+gdP4YXBTa2gc7CRVaee5ayswBDBTI8itInR5pLi7sl/LCcWt5H93Svcmsp4Dn3PaTygzoxU3FqvDLHjcQCs/JDdKIozjBatAitHtgVVueeJiycoD19B8WG3cj622CxA4sroIqMjyFFQbl0le7pU1h7CJmYYm3hEsvPf5G1hfP4SIGMjCcekA8oRWjTQ2Un1DnvjeJITLgmt4QBGmqoAgeTdEGpwTGmhsetHwWSL5wRNDsmEBnBQyQMd/HuCeLpcxSXttOavoNifCcyMg3RqRYX6c3PU4nC+ATdpUUWn/sz1ubPwpAg42Noka/nJMB0abDETFDxBHwZUxK2JFT1qHiUm8LAjRhglt40U2wB3BSJ3nB7ixBUUx+gKbzMnCCNBorn8mleEDUQhltoaw3rvUR1Zo7W+B6ktZPelS7RnTC1ge5ql6Uvf5mVky9hKujYMNJO6edW6yS5pLkTLM8ScrSrJ/4gZGNTKUiHFQWPtxIBNYLmINIm3OjT3OgQ+oaraRMNWvUZoJOEEjEnegvTAh3pYVWXXuclepdeYPWFZWRyL8XkFEtf+RqlVcjoMFJk4TR66gc8M0HPpKZOvwFm7d4vp/3SJ3gl6bnfrApIU6VT2rsIhqe8t75uZwZiqTym0phCUmIiNtSn755PyjLbTQ6KDEEE3X4v3eoCS/4c8aUXCTqEDA8jQ+2E7J4Fjtz2UJdLSwwRTU7RWJ+aXKco+aDUZPUf9eWrQE1V6/C31OUi+W+eNc+UI+l3iyAhn4ompyQ21ndsag1ydLhgGGWrTcec0G5RDI3VEIKgA8JxMqDueoOBKahl7ThXJJOBJuw6SqNNBFi8hSqQTj3BuiFErK/sGgRzvEoGJixIXZpXYKrglkplAyADclfdaJHSwomJ9+eoAb1OGqcBX83OMYwsukRptBFcUR3oZLLclrBAsCoZf0sY4BkDahXDcghK5tZmCQuo+jK3mxNdKCKJ4KgRYq30WhNVtbTdaAK5+fdGCNAcNdIMUmyAi4hpcxDuEIMQ8r3FjPwyMHBrMCCmA6LyW4gATww6miSkF8eAwvrvaeKEKnVq0SQZq2AiWfYXnJQLTgazPACRDGLYoLh33UAgY0mKaXdDzRu+0Z8mNeOUhEEiN2jcnttLLwNeKR7t5R0Qo9fSXiY+mgYYHrMgK3h0KnU002Ot+q2ti+DaV3ZdvD/i0hRFdQh4XdLqGMviiVhfRXLLXWN0TAQvAulcPIFtpCnPffrTRzQRyWqVYB5uwQGZLZgmJ0i+2ZQK1oSjm+GVNMMQD+ARNJ+giaC5p68HHpKps2eMSBw+Pd8zoInnVrkWgENKOyTTcMv3lYFSMjr2548MUN5MtKtEhHC5FQc0piYj3HPlSS8OeDIkJq3OY1JvqARRpxInxHTjHn0Qi5sKQBQwa/iFNipULR9lbSBTbskDBjOQKitFmZl6fm49T+yP0jJ4ItkBITn+VjCgZlYZvlA88W4UISIYISqWR1giKWJCKU2/T0mT/2mzI4/MMopjCflr3hFJ758cniJFczTXCpvagKiR0Jp43eitXxbrPzmCRSea434LGODRUs7n+0z8OpWo6IpIuj0xR2PuFXK49zU/b1pddUHckrTlZAYJEhPLsyjZMGmuOzhGtGyrWj8la6orlqNwcJiS09Qb4cnwyqH0RKBeNgWAUCNxJj+1LwOCezoll3Tz0ig4GcBqxiiSKkWu3epZ5gKoDIukJsUEMyF6QngVyUUxobtqrUxlfUfBojcSec22XBIwSn59zWprHkBMgHsLPMAwzaBXDzVSq5eGMaIIhqaWLHPyNAixRgVWRFJtLmqHoAngQsYLa0ScDHypnzCsGZzWw5+Qj7iWuzJHqgfFA+VZ+hpAg4GOV06sfGAc8jJM0ESIuXyFWrPL0eEOLkqrFgxN8AqiOCqKimOSSinqRBG0Skaa5p68UqRyYjSiJWSp2TWu/c2hGgOam1NcPJfY3AFKvyHyZu/Em1Ejklp4N26tHY7RUqgn3MbJPLt2e8Z0wyk8gaaSWJaJ9dmeAGUmViGfouYGqSI5oMoU2lPEDR6n1+wuGyQDJblxUZ2ilrvOgRRockAUcc202W9FD0hRUNNhz3RUhYZLiwsxn5tmAUQ0ezqTPMmCZ8hCieXRlrpAlVWa6JSV9Yck3leNHUHzDgC5K1VJ6G45PTwjnTRhksJCBmlw5jCpxN5SL5CMN6lDLxAkJatn8aHCCabEHIq1ClRv9NRbHnU3qU4ebeVjicmZFiHGdK3okic3jor1yx8DSk9mlgoNOWpoN9K04ZKZpw5EQupk4y1gQIy5NtcMLQEYkspZU91zM1PVvMy8ITw+MGxNqpA0O19GCnuNWdCIYEW+XuaboKDSGOD5uo1pdYRljaEuf02fUfczeaxYNw5mN6qCN5HF3T0vOcR6kyufasjrbZaTBAclYBLRPEMwMjVtimefnTeqTiWpLlfedJ+W87+WFmVA6lFCvwrkoK6bLmlOPu8O4H2ZfUAaVxEo9AZFRAc3RHCnWl250BLMJcR8QI0aYypNiewPjxQnJKrsisRkbIwJ5Mw01fzS8TLPGiuw0rDoVNYHwFxYm14iep+RmtQLVCm4owlmoXltnZ5WR1mzhiN4ZTGYe9fkAsCTA3bf4JGlpcXHFhYWtFrrtByvPIh7SAtPloPU6vlhxorY9A4Jub2WzCvHep4VGYUqbZZ4FKwyrHQqC1QIsTYug6jl6uONcUasmSGpVTZP7XjMwJ3yIusKWhANj91eFYaH21cnN8jlrj0GcPHo0SYVmv7wyNGjPgP6zpMvHv3h/fvPyWrv+0bX4pQ6IoVWJioJcL2P2s2Eu5mlNT7VgeFqvwDnDYmyhPEJljslV+cuE8IwrdHxZm3WGSyHyQmay/LgylzaPcg0ur5eBgcpe3GoaIfRXXt19bZ9x+c3b3nrj/3eb312ZmZG3/rII3aDAwCeAp8BfffZU1/4W+9716fWzp7vlitr97ZXO+PmJlK0oqQdq7QA4t7Pc6+1+v7ta63ger95ScTEYHSCTqfHtUsLaDFEMTqaxQ6a9Ep1c4DV5WlyDamO9neoVDER914V1QljW7bp6r59567t2zP7hR+78xd+/tD7v1hvwb38oiQHw4OkLarffc97doTPff4drfnLf39Tz8elVRDa7SjmgRgpcqlSS1pgwND8XZB2KKXZBklLlR4rdOs25q91OPm1Y7SG1zG2aWPq4rQ2LzakKzWdnneoJBstzeIp4FSlBZcwNr2Jlc3TV7rbtjzy3G1bf+fXZmcvDW7B3fKqrIMc4kCY5akK4F+85R/uW/+lP//11sXFn1tX9dqxCB6KwjR6UMsGxxQVKo5ihFyza93O1RJ7iyWydTtzSx1OvnCc1sgE4xs3NXekuRlKio5lFpiKoObwV0nfVDFqVYWxqSk6O7ct2/Ztj53ZueMjP//w+04DPHHgQHH/U099w53hW1qWPgRhFioEPvXQW14jXzr63qErCw+urxwvghehZWoxqCdmGPLKmgIFsUkVzTtBXnaxrVuYW1rlxIsv0hqdZGLTxoEPHNV1PnMByRp1jgLVgESL1uuFodFx1rZsKdm1/fHl27d98O8+/PDxWzH8W16Xn2FG72FW0jqd8K/e9Pd+aPTYS+8ev3z1b46XFRY0aihEzFQsDUMKhyDWqEHBM6uresQt01xYXOXEyVO0RtexbvN0zW2bVk8ly16JihEE1D3SK2VkaEQ70xu83L79cHn73g/89If/2ZcB/ODBwOHD9pe2Ln+DI2Zm9J7Z7IigPP7jP/WGkWMn/8nE1cUDo70SL4qoRSHBTNWcIq8Qusf+vlBVYps3cGGxw4lTp2iNrGNi83Qz5W20PkkAqqmLNF/r0lJVn57Gd237THfvzod/+qMffqbO8efvvvtb/uTI/9VHZg7NzjILRlHwqTe86afGj5/4x9PLS98/VEWsCFElSHBTzaHrxFSmyhLbuJ4LS6ucPHOWYnScsc3TzQZ42pBzVEERo1d6YYRy3QRrmzd93u/Y8/6f/Zcf+681YD8/c/d37yMz32y1Hnc5/IafeGj49NnfmLq2dFdRVVC0Kgka0kpxVvuqimpykrMrq5w+d4722DgT2QGeF7VUMMqeF5UFHRunu3Xjs9Xtuz745n/9if9AtMTCZ2b4f/ahqZs54u8cORIdeMepUyOv/5lf+oXRs2ffuXVlbY+4Q9GqUAniUSh7VJOTnFnucPLCBdpj40xtnk61XXHpVZGyKmy4zdrGDUd19+7f/MV//+nfR9LE4MjBg3qzkvaK+ODkYL199PDhyW2/89gvD52ff/vGpbUt0SPSKiqzKsi6MTm32OH43Dw6Nsbklo0uMUbtVUUxNEZnauyl3vZNHx792G9//M179659s1r+ivzo7MyBA2H2qcQhPv7wR7Zs+o//+R0j8xf+wZZuOVlFo5oat3NLHT05dxEZGY4TkxOBIKxMTs63du/6SO9n3vSxtz300OJ3yvDvtAP6H7jiQHggk6nHf+Vdu6affuadw3OX39xa7qw7sdzhYq/D0Ph62LHlYrl5/WP6o3/1o29/73vnBgw3XqaWv+K/HOQJDjTaw797yy/f9Uev/oHff2Tjns6hjXuWfvP7Dzz64ZmZPU2pPXCg8O/w4dRf/wekb/5bkmBnWwAAAABJRU5ErkJggg==]==]

local CUSTOM_ICON_DATA = {
    cube3d = ICON_CUBE3D_B64,
    -- White Lucide-style outline; tintIcon applies the active theme colour.
    heart = "iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAACY0lEQVR42u2cW47DIBAEc7Q5GjfjaN6fjRRFicNzeoBqaf+iZLoaBoztfTwQQgghhBBCaJCu60r/f/m61/Nz5libvfzunfLzcytB79WUMF6gd9cXDboVjHKZ2UHQv80O2xX8u6yxPg/5BzFxVN0aragvC+pLXvAV5opmg+Oo7x4k0VtOdQgB4M9rSYHMfQwhen1K+Ld76Iprha8mO+rLFfXpQmiA0zwFnRb35NiCsyf8Yb1vUhBJtBZmj9aTJi36sfpx+yCxlh+QmRu47c2TayseJLPSdbkCbAwhO9Vmw7tEJPit65HgWGbMLCgc/a4GK0OIXFsaMfolBguNRq7t9ywoHP32EOuL0RygLuuaBQUJyk1+uEoNdceqi+Fyd4MWvSvYPH3AO2wXaS3JZdAOa0OpJQDaz7g2RAARA8jRt58LBWDV7ZwF2HchJoCAAdCCxC2IRZhdEAFwISa8EOMoQnkUwWGc+DCucOrQhvrbT+5Kj+1o1/bzdxeJfkty8dF/DelhhNAGv3gNjfhYygat56r5wkQIY+FX7yCjPJq4Cfxr6pefGIILn8rHAQ34+ncEDPiDd4sNz+kb8PXviRnw9W9KGvB3LeRE+CeGENbrCSGE97hzCMt42zGE5TztFMKyXnYIYXkPKxvYZhavaGS7dWwlQ9vu5FYwtv21TGSDx1zNRzR63HlWJMPHnuhGMH78PQ0lAG4oCUEAXwgE+EIwwBcCAr4QFPCFIQBfGALwhSEAXxgC8PUhAH+REIAvDAH4whCALwwB+MIQgC8MAfjCEIAvDAH4jkEk/o8RQgghhBBCTfoDKZ+DkuCUgS8AAAAASUVORK5CYII=",
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
    -- The bundled cube art is already coloured; the heart is a white outline
    -- and should follow the active theme like the other Lucide icons.
    if name == "cube3d" then
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

local TextService = game:GetService("TextService")
local KB_WIDTH = 216
local TOGGLE_ENTRY_ID = "__toggle_menu"

local KEY_ALIASES = {
    RightShift = "RShift",
    LeftShift = "LShift",
    RightControl = "RCtrl",
    LeftControl = "LCtrl",
    RightAlt = "RAlt",
    LeftAlt = "LAlt",
    CapsLock = "Caps",
    Backspace = "Bksp",
    Delete = "Del",
    Insert = "Ins",
    PageUp = "PgUp",
    PageDown = "PgDn",
    Return = "Enter",
    KeypadEnter = "NumEnt",
    KeypadPlus = "Num+",
    KeypadMinus = "Num-",
    KeypadMultiply = "Num*",
    KeypadDivide = "Num/",
    KeypadPeriod = "Num.",
    Space = "Space",
    QuotedDouble = "\"",
    Quote = "'",
    Minus = "-",
    Equals = "=",
    LeftBracket = "[",
    RightBracket = "]",
    BackSlash = "\\",
    Semicolon = ";",
    Comma = ",",
    Period = ".",
    Slash = "/",
}

    --[[ ------------------------------------------------------------------
        Luau allows at most 200 local variables in a single function. The rest
        of the file used to live in this same function, which made it fail to
        compile with "Out of local registers when trying to allocate <name>:
        exceeded limit 200".

        Everything below therefore lives in one nested function. It still sees
        every variable created above as an upvalue, and it gets its own budget
        of 200 locals, so both functions stay comfortably inside the limit.
    ------------------------------------------------------------------ ]]
    local function buildStage2()
    local function formatKeyName(key)
        key = tostring(key or "None")
        if key == "" then return "None" end
        if KEY_ALIASES[key] then return KEY_ALIASES[key] end
        local num = string.match(key, "^Keypad(.+)$")
        if num then return "Num" .. num end
        return key
    end

    local function keyCodeName(key)
        if typeof(key) == "EnumItem" then
            return key.Name
        end
        if type(key) == "string" and key ~= "" then
            return key
        end
        return "RightShift"
    end

    local function keyBadgeWidth(text)
        local ok, bounds = pcall(function()
            return TextService:GetTextSize(text, 10, Enum.Font.GothamBold, Vector2.new(140, 16))
        end)
        local width = (ok and bounds and bounds.X) or (#text * 7)
        if width < 18 then width = 18 end
        if width > 108 then width = 108 end
        return math.floor(width + 12)
    end

    local KeybindHolder = Instance.new("Frame")
    KeybindHolder.Name = "Keybinds"
    KeybindHolder.AnchorPoint = Vector2.new(0, 0)
    KeybindHolder.Position = UDim2.new(0, 16, 0.32, 0)
    KeybindHolder.Size = UDim2.new(0, KB_WIDTH, 0, 0)
    KeybindHolder.AutomaticSize = Enum.AutomaticSize.Y
    KeybindHolder.BorderSizePixel = 0
    KeybindHolder.Active = true
    KeybindHolder.Visible = false
    KeybindHolder.ZIndex = 60
    KeybindHolder.Parent = ScreenGui
    bindColor(KeybindHolder, "BackgroundColor3", "CardBg")

    local keybindScale = Instance.new("UIScale")
    keybindScale.Scale = UI_SCALE
    keybindScale.Parent = KeybindHolder

    local function kbCorner(parent, radius)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, radius)
        corner.Parent = parent
        return corner
    end

    local function kbStroke(parent, thickness)
        local stroke = Instance.new("UIStroke")
        bindColor(stroke, "Color", "Border")
        stroke.Thickness = thickness or 0.8
        stroke.Parent = parent
        return stroke
    end

    kbCorner(KeybindHolder, 8)
    kbStroke(KeybindHolder, 0.8)

    local kbPad = Instance.new("UIPadding")
    kbPad.PaddingTop = UDim.new(0, 10)
    kbPad.PaddingBottom = UDim.new(0, 10)
    kbPad.PaddingLeft = UDim.new(0, 12)
    kbPad.PaddingRight = UDim.new(0, 12)
    kbPad.Parent = KeybindHolder

    local kbLayout = Instance.new("UIListLayout")
    kbLayout.SortOrder = Enum.SortOrder.LayoutOrder
    kbLayout.Padding = UDim.new(0, 6)
    kbLayout.Parent = KeybindHolder

    local kbHeader = Instance.new("Frame")
    kbHeader.Name = "Header"
    kbHeader.Size = UDim2.new(1, 0, 0, 18)
    kbHeader.BackgroundTransparency = 1
    kbHeader.BorderSizePixel = 0
    kbHeader.Active = true
    kbHeader.LayoutOrder = 1
    kbHeader.ZIndex = 61
    kbHeader.Parent = KeybindHolder

    local kbIcon = Instance.new("ImageLabel")
    kbIcon.Name = "Icon"
    kbIcon.Size = UDim2.new(0, 14, 0, 14)
    kbIcon.Position = UDim2.new(0, 0, 0.5, -7)
    kbIcon.BackgroundTransparency = 1
    kbIcon.Image = resolveIcon("keyboard")
    kbIcon.ScaleType = Enum.ScaleType.Fit
    kbIcon.ZIndex = 62
    kbIcon.Parent = kbHeader
    tintIcon(kbIcon, "keyboard", "Accent")

    local kbTitle = Instance.new("TextLabel")
    kbTitle.Name = "Title"
    kbTitle.Size = UDim2.new(1, -36, 1, 0)
    kbTitle.Position = UDim2.new(0, 20, 0, 0)
    kbTitle.BackgroundTransparency = 1
    kbTitle.Text = "Keybinds"
    kbTitle.Font = Enum.Font.GothamBold
    kbTitle.TextSize = 13
    kbTitle.TextXAlignment = Enum.TextXAlignment.Left
    kbTitle.TextTruncate = Enum.TextTruncate.AtEnd
    kbTitle.ZIndex = 62
    kbTitle.Parent = kbHeader
    bindColor(kbTitle, "TextColor3", "TextPrimary")

    local kbChevron = Instance.new("ImageButton")
    kbChevron.Name = "Collapse"
    kbChevron.Size = UDim2.new(0, 14, 0, 14)
    kbChevron.Position = UDim2.new(1, -14, 0.5, -7)
    kbChevron.BackgroundTransparency = 1
    kbChevron.Image = ICONS.Chevron
    kbChevron.AutoButtonColor = false
    kbChevron.ZIndex = 63
    kbChevron.Parent = kbHeader
    bindColor(kbChevron, "ImageColor3", "Accent")

    local kbDivider = Instance.new("Frame")
    kbDivider.Name = "Divider"
    kbDivider.Size = UDim2.new(1, 0, 0, 1)
    kbDivider.BorderSizePixel = 0
    kbDivider.LayoutOrder = 2
    kbDivider.ZIndex = 61
    kbDivider.Parent = KeybindHolder
    bindColor(kbDivider, "BackgroundColor3", "Divider")

    local kbList = Instance.new("Frame")
    kbList.Name = "List"
    kbList.Size = UDim2.new(1, 0, 0, 0)
    kbList.AutomaticSize = Enum.AutomaticSize.Y
    kbList.BackgroundTransparency = 1
    kbList.BorderSizePixel = 0
    kbList.LayoutOrder = 3
    kbList.ZIndex = 61
    kbList.Parent = KeybindHolder

    local kbListLayout = Instance.new("UIListLayout")
    kbListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    kbListLayout.Padding = UDim.new(0, 4)
    kbListLayout.Parent = kbList

    local kbEmpty = Instance.new("TextLabel")
    kbEmpty.Name = "Empty"
    kbEmpty.Size = UDim2.new(1, 0, 0, 16)
    kbEmpty.BackgroundTransparency = 1
    kbEmpty.Text = "No keybinds"
    kbEmpty.Font = Enum.Font.Gotham
    kbEmpty.TextSize = 11
    kbEmpty.TextXAlignment = Enum.TextXAlignment.Left
    kbEmpty.LayoutOrder = 0
    kbEmpty.Visible = true
    kbEmpty.ZIndex = 62
    kbEmpty.Parent = kbList
    bindColor(kbEmpty, "TextColor3", "TextMuted")

    local kbEntries = {}
    local kbById = {}
    local kbOrder = 0
    local kbHideUnbound = false
    local kbCollapsed = false
    local kbShowToggle = true
    local kbToggleName = "Toggle Menu"
    local kbVisible = false
    local kbAutoShow = options.KeybindList == nil
    local kbToggleHandle = nil
    local kbApplyingVisible = false

    local function entryVisible(entry)
        if entry.hidden then return false end
        if kbHideUnbound and (entry.key == "None" or entry.key == "") then
            return false
        end
        return true
    end

    local function refreshKeybindEmpty()
        local any = false
        for _, entry in ipairs(kbEntries) do
            local show = entryVisible(entry)
            if entry.row then
                entry.row.Visible = show
            end
            if show then any = true end
        end
        kbList.Visible = not kbCollapsed
        kbDivider.Visible = not kbCollapsed
        kbEmpty.Visible = not any
        if not any then
            kbEmpty.Text = kbHideUnbound and "Nothing bound" or "No keybinds"
        end
    end

    local function renderKeybindEntry(entry)
        if not entry or not entry.row then return end
        entry.nameLabel.Text = entry.name
        local shown = formatKeyName(entry.key)
        entry.badge.Text = shown
        local width = keyBadgeWidth(shown)
        entry.badge.Size = UDim2.new(0, width, 0, 16)
        entry.nameLabel.Size = UDim2.new(1, -(width + 8), 1, 0)
        local token = (entry.key == "None" or entry.key == "") and "TextDim" or "Accent"
        bindColor(entry.badge, "TextColor3", token)
        refreshKeybindEmpty()
    end

    local function createKeybindRow(entry)
        local row = Instance.new("Frame")
        row.Name = "Bind"
        row.Size = UDim2.new(1, 0, 0, 18)
        row.BackgroundTransparency = 1
        row.BorderSizePixel = 0
        row.LayoutOrder = entry.order
        row.ZIndex = 62
        row.Parent = kbList

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "Name"
        nameLabel.Size = UDim2.new(1, -48, 1, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.GothamMedium
        nameLabel.TextSize = 12
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.ZIndex = 63
        nameLabel.Parent = row
        bindColor(nameLabel, "TextColor3", "TextPrimary")

        local badge = Instance.new("TextLabel")
        badge.Name = "Key"
        badge.AnchorPoint = Vector2.new(1, 0.5)
        badge.Position = UDim2.new(1, 0, 0.5, 0)
        badge.Size = UDim2.new(0, 36, 0, 16)
        badge.BorderSizePixel = 0
        badge.Font = Enum.Font.GothamBold
        badge.TextSize = 10
        badge.TextXAlignment = Enum.TextXAlignment.Center
        badge.TextTruncate = Enum.TextTruncate.AtEnd
        badge.ZIndex = 63
        badge.Parent = row
        bindColor(badge, "BackgroundColor3", "BadgeBg")
        bindColor(badge, "TextColor3", "TextMuted")
        kbCorner(badge, 3)
        kbStroke(badge)

        entry.row = row
        entry.nameLabel = nameLabel
        entry.badge = badge
        renderKeybindEntry(entry)
    end

    local function registerOverlayKeybind(info)
        info = info or {}
        local id = info.Id
        if id == nil or id == "" then
            kbOrder = kbOrder + 1
            id = "kb" .. kbOrder
        else
            id = tostring(id)
        end

        local existing = kbById[id]
        if existing then
            if info.Name ~= nil then existing.name = tostring(info.Name) end
            if info.Key ~= nil then existing.key = tostring(info.Key) end
            if info.Hidden ~= nil then existing.hidden = info.Hidden and true or false end
            renderKeybindEntry(existing)
            return id
        end

        if info.Order == nil then
            kbOrder = kbOrder + 1
        end
        local entry = {
            id = id,
            name = tostring(info.Name or info.Title or "Keybind"),
            key = tostring(info.Key or info.Default or "None"),
            order = info.Order or kbOrder,
            hidden = info.Hidden and true or false,
        }
        kbById[id] = entry
        table.insert(kbEntries, entry)
        createKeybindRow(entry)
        return id
    end

    local function updateOverlayKeybind(id, key, name)
        local entry = kbById[tostring(id)]
        if not entry then return end
        if key ~= nil then entry.key = tostring(key) end
        if name ~= nil then entry.name = tostring(name) end
        renderKeybindEntry(entry)
    end

    local function removeOverlayKeybind(id)
        id = tostring(id)
        local entry = kbById[id]
        if not entry then return end
        kbById[id] = nil
        for i, item in ipairs(kbEntries) do
            if item == entry then
                table.remove(kbEntries, i)
                break
            end
        end
        if entry.row then entry.row:Destroy() end
        refreshKeybindEmpty()
    end

    local function setKeybindListCollapsed(collapsed)
        kbCollapsed = collapsed and true or false
        kbChevron.Rotation = kbCollapsed and -90 or 0
        refreshKeybindEmpty()
    end

    local function setKeybindListVisible(visible, fromToggle)
        kbVisible = visible and true or false
        KeybindHolder.Visible = kbVisible
        if not kbVisible then
            kbAutoShow = false
        end
        if not fromToggle and kbToggleHandle and not kbApplyingVisible then
            kbApplyingVisible = true
            kbToggleHandle.Set(kbVisible)
            kbApplyingVisible = false
        end
    end

    local function setKeybindListTitle(text)
        kbTitle.Text = tostring(text)
    end

    local function applyKeybindListOptions(opts)
        if opts == false then
            setKeybindListVisible(false)
            return
        end
        if opts == true or opts == nil then
            setKeybindListVisible(true)
            return
        end
        if type(opts) ~= "table" then return end

        if opts.Title ~= nil or opts.Name ~= nil then
            setKeybindListTitle(opts.Title or opts.Name)
        end
        if opts.Position ~= nil and typeof(opts.Position) == "UDim2" then
            KeybindHolder.Position = opts.Position
        end
        if opts.HideUnbound ~= nil then
            kbHideUnbound = opts.HideUnbound and true or false
            refreshKeybindEmpty()
        end
        if opts.ToggleKeyName ~= nil then
            kbToggleName = tostring(opts.ToggleKeyName)
            if kbById[TOGGLE_ENTRY_ID] then
                updateOverlayKeybind(TOGGLE_ENTRY_ID, nil, kbToggleName)
            end
        end
        if opts.ShowToggleKey ~= nil then
            kbShowToggle = opts.ShowToggleKey and true or false
            if kbById[TOGGLE_ENTRY_ID] then
                kbById[TOGGLE_ENTRY_ID].hidden = not kbShowToggle
                renderKeybindEntry(kbById[TOGGLE_ENTRY_ID])
            end
        end
        if opts.Collapsed ~= nil then
            setKeybindListCollapsed(opts.Collapsed)
        end
        if opts.Visible ~= nil then
            setKeybindListVisible(opts.Visible)
        end
    end

    if type(options.KeybindList) == "table" then
        kbAutoShow = false
        applyKeybindListOptions(options.KeybindList)
        if options.KeybindList.Visible == nil then
            setKeybindListVisible(true)
        end
    elseif options.KeybindList == false then
        kbAutoShow = false
        kbVisible = false
        KeybindHolder.Visible = false
    elseif options.KeybindList == true then
        kbAutoShow = false
        setKeybindListVisible(true)
    end

    registerOverlayKeybind({
        Id = TOGGLE_ENTRY_ID,
        Name = kbToggleName,
        Key = keyCodeName(options.ToggleKey or Enum.KeyCode.RightShift),
        Order = -100,
        Hidden = not kbShowToggle,
    })

    kbChevron.MouseButton1Click:Connect(function()
        setKeybindListCollapsed(not kbCollapsed)
    end)
    kbChevron.MouseEnter:Connect(function()
        tweenColors(kbChevron, TWEEN_FAST, {ImageColor3 = "AccentSoft"}):Play()
    end)
    kbChevron.MouseLeave:Connect(function()
        tweenColors(kbChevron, TWEEN_FAST, {ImageColor3 = "Accent"}):Play()
    end)

    do
        local dragging = false
        local dragStart, startPos
        kbHeader.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = KeybindHolder.Position
            end
        end)
        trackConn(UserInputService.InputChanged:Connect(function(input)
            if not dragging then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement
                and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            local delta = input.Position - dragStart
            KeybindHolder.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end))
        trackConn(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end))
    end

    local function flashKeybind(entry)
        if not entry.badge or not entry.row or not entry.row.Visible then return end
        tweenColors(entry.badge, TWEEN_FAST, {BackgroundColor3 = "Accent", TextColor3 = "KnobOn"}):Play()
        task.delay(0.16, function()
            if not entry.badge or not entry.badge.Parent then return end
            local token = (entry.key == "None" or entry.key == "") and "TextDim" or "Accent"
            tweenColors(entry.badge, TWEEN_FAST, {BackgroundColor3 = "BadgeBg", TextColor3 = token}):Play()
        end)
    end

    trackConn(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if isClosed or gameProcessed then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if not KeybindHolder.Visible or kbCollapsed then return end
        local pressed = input.KeyCode.Name
        for _, entry in ipairs(kbEntries) do
            if entry.key == pressed and entry.row and entry.row.Visible then
                flashKeybind(entry)
            end
        end
    end))

    local function overlayKeybindHandle(id)
        return {
            Id = id,
            Set = function(key, maybeKey)
                if maybeKey ~= nil then key = maybeKey end
                updateOverlayKeybind(id, key)
            end,
            SetName = function(name, maybeName)
                if maybeName ~= nil then name = maybeName end
                updateOverlayKeybind(id, nil, name)
            end,
            Remove = function() removeOverlayKeybind(id) end,
            Get = function()
                local entry = kbById[id]
                return entry and entry.key or "None"
            end,
        }
    end

    local KeybindListApi = {}

    function KeybindListApi:SetVisible(visible)
        setKeybindListVisible(visible)
    end

    function KeybindListApi:IsVisible()
        return kbVisible and KeybindHolder.Visible
    end

    function KeybindListApi:Toggle()
        setKeybindListVisible(not kbVisible)
    end

    function KeybindListApi:SetTitle(text)
        setKeybindListTitle(text)
    end

    function KeybindListApi:SetPosition(position)
        if typeof(position) == "UDim2" then
            KeybindHolder.Position = position
        end
    end

    function KeybindListApi:Collapse(collapsed)
        if type(collapsed) ~= "boolean" then
            setKeybindListCollapsed(not kbCollapsed)
        else
            setKeybindListCollapsed(collapsed)
        end
    end

    function KeybindListApi:Add(entryOptions)
        entryOptions = entryOptions or {}
        local id = registerOverlayKeybind({
            Id = entryOptions.Id or entryOptions.Flag,
            Name = entryOptions.Name or entryOptions.Title,
            Key = entryOptions.Key or entryOptions.Default or "None",
        })
        return overlayKeybindHandle(id)
    end

    function KeybindListApi:Remove(id)
        removeOverlayKeybind(id)
    end

    function KeybindListApi:Set(id, key)
        updateOverlayKeybind(id, key)
    end

    function KeybindListApi:Configure(opts)
        kbAutoShow = false
        applyKeybindListOptions(opts)
    end

    local function noteKeybindForOverlay()
        if kbAutoShow then
            setKeybindListVisible(true)
        end
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
    local POPUP_META = setmetatable({}, { __mode = "k" }) -- {dx, gap}: popup offset from its anchor

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

    -- The window the anchor belongs to (main window, a Browse window, ...) = popup bounds
    local function popupBounds(anchor)
        local root = anchor
        while root and root.Parent and root.Parent ~= ScreenGui do
            root = root.Parent
        end
        if root and root ~= ScreenGui and root:IsA("GuiObject") then
            return root.AbsolutePosition, root.AbsolutePosition + root.AbsoluteSize
        end
        return Vector2.new(0, 0), ScreenGui.AbsoluteSize
    end

    -- false when the anchor was scrolled out of its clipping container or hidden
    local function anchorVisible(anchor)
        if not anchor.Visible then return false end
        local a0 = anchor.AbsolutePosition
        local center = a0 + anchor.AbsoluteSize / 2
        local p = anchor.Parent
        while p and p ~= ScreenGui do
            if p:IsA("GuiObject") then
                if not p.Visible then return false end
                if p.ClipsDescendants or p:IsA("ScrollingFrame") then
                    local c0 = p.AbsolutePosition
                    local c1 = c0 + p.AbsoluteSize
                    if center.Y < c0.Y or center.Y > c1.Y or center.X < c0.X or center.X > c1.X then
                        return false
                    end
                end
            end
            p = p.Parent
        end
        return true
    end

    local function placePopup(popup, anchor)
        local meta = POPUP_META[popup]
        if not meta then return end
        local aPos, aSize = anchor.AbsolutePosition, anchor.AbsoluteSize
        local pSize = popup.AbsoluteSize
        local b0, b1 = popupBounds(anchor)
        local screen = ScreenGui.AbsoluteSize

        local x = aPos.X + meta.dx
        x = math.clamp(x, math.min(b0.X, aPos.X), math.max(b0.X, b1.X - pSize.X))
        x = math.clamp(x, 0, math.max(0, screen.X - pSize.X))

        local below = aPos.Y + aSize.Y + meta.gap
        local above = aPos.Y - meta.gap - pSize.Y
        local y
        if below + pSize.Y <= b1.Y then
            y = below                     -- fits under the control inside the window
        elseif above >= b0.Y then
            y = above                     -- no room below -> open upwards
        elseif below + pSize.Y <= screen.Y then
            y = below                     -- window too small: at least stay on screen
        else
            y = math.max(0, above)
        end
        popup.Position = UDim2.fromOffset(x, y)
    end

    trackConn(RunService.RenderStepped:Connect(function()
        if #activePopups == 0 then return end
        for _, p in ipairs(activePopups) do
            local anchor = POPUP_ANCHOR[p]
            if not anchor or not anchor.Parent then
                closeAllPopups()
                return
            end
            if p.Parent then
                local visible = anchorVisible(anchor)
                p.Visible = visible
                if visible then placePopup(p, anchor) end
            end
        end
    end))

    local function trackPopup(popup, anchor)
        table.insert(activePopups, popup)
        POPUP_ANCHOR[popup] = anchor
        if anchor then
            POPUP_META[popup] = {
                dx = popup.Position.X.Offset - anchor.AbsolutePosition.X,
                gap = popup.Position.Y.Offset - (anchor.AbsolutePosition.Y + anchor.AbsoluteSize.Y),
            }
            task.defer(function()
                if popup.Parent and anchor.Parent then placePopup(popup, anchor) end
            end)
        end
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

    --[[ Control handles are documented (README and Example.lua) to be used with
        a colon: `toggle:Set(true)`. A method written as `function(value)` would
        then receive the handle table itself as `value`, so every handle table
        is passed through this wrapper: the leading handle argument is dropped
        and the remaining arguments are forwarded, which makes `handle:Set(x)`
        and `handle.Set(x)` behave identically. ]]
    local function wrapHandle(handle)
        for name, fn in pairs(handle) do
            if type(fn) == "function" then
                handle[name] = function(a, b, c)
                    if a == handle then
                        return fn(b, c)
                    end
                    return fn(a, b)
                end
            end
        end
        return handle
    end

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

        return wrapHandle({
            Set = function(value) applyToggle(value, true) end,
            Get = function() return isToggled end,
        })
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

    local function addPopupSearch(popup, rows, list, rowH)
        rowH = rowH or SELECT_OPTION_H
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
            list.Size = UDim2.new(1, 0, 0, rowsShown * rowH + (rowsShown - 1) * 2)
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
            local icon, model = opt.Icon, opt.Model or opt.Icon3D or opt.Model3D or opt.Instance
            if typeof(icon) == "Instance" then model, icon = icon, nil end
            return opt.Text or "", icon, model
        end
        return tostring(opt), nil, nil
    end

    ------------------------------------------------------------------
    -- 3D icons (ViewportFrame) for dropdown options
    ------------------------------------------------------------------
    local ICON3D_DEFAULTS = {
        Size = 32,             -- px (pre-scale) side of the viewport
        Padding = 1.15,        -- >1 = more air around the model
        Zoom = 1,              -- >1 = closer
        FOV = 40,
        Angle = Vector3.new(20, -35, 0), -- pitch, yaw, roll (deg) the camera looks from
        Spin = false,          -- slowly rotate the model
        SpinSpeed = 45,        -- deg / s
        Ambient = Color3.fromRGB(190, 190, 190),
        LightColor = Color3.fromRGB(255, 255, 255),
        LightDirection = Vector3.new(-1, -1.5, -1),
        Background = nil,      -- Color3 or theme key; nil = transparent
        Models = nil,          -- Folder / table / function(text) used to look models up by option text
    }

    local function normalize3DConfig(cfg, extra)
        local out = {}
        for k, v in pairs(ICON3D_DEFAULTS) do out[k] = v end
        if type(cfg) == "number" then
            out.Size = cfg
        elseif type(cfg) == "table" then
            for k, v in pairs(cfg) do out[k] = v end
        end
        if extra then
            if extra.IconSize then out.Size = extra.IconSize end
            if extra.Models ~= nil then out.Models = extra.Models end
        end
        if type(out.Angle) == "number" then out.Angle = Vector3.new(20, out.Angle, 0) end
        if typeof(out.Angle) ~= "Vector3" then out.Angle = ICON3D_DEFAULTS.Angle end
        return out
    end

    -- turns the option's `Model` (or the shared `Models` source) into an Instance
    local function resolveModel(value, text, cfg)
        if type(value) == "function" then
            local ok, res = pcall(value, text)
            value = ok and res or nil
        end
        if typeof(value) == "Instance" then return value end
        local src = cfg and cfg.Models
        if src == nil then return nil end
        local keys = {}
        if type(value) == "string" and value ~= "" then table.insert(keys, value) end
        if type(text) == "string" and text ~= "" and text ~= keys[1] then table.insert(keys, text) end
        if #keys == 0 then return nil end
        if type(src) == "function" then
            for _, key in ipairs(keys) do
                local ok, res = pcall(src, key, text)
                if ok and typeof(res) == "Instance" then return res end
            end
        elseif typeof(src) == "Instance" then
            for _, key in ipairs(keys) do
                local found = src:FindFirstChild(key, true)
                if found then return found end
            end
        elseif type(src) == "table" then
            for _, key in ipairs(keys) do
                local found = src[key]
                if type(found) == "function" then
                    local ok, res = pcall(found, key, text)
                    found = ok and res or nil
                elseif type(found) == "table" then
                    found = found.Model or found.Model3D or found.Instance
                end
                if typeof(found) == "Instance" then return found end
            end
        end
        return nil
    end

    local function createViewportIcon(parent, cfg, zIndex)
        cfg = normalize3DConfig(cfg)
        local vp = Instance.new("ViewportFrame")
        vp.Name = "Icon3D"
        vp.Size = UDim2.new(1, 0, 1, 0)
        vp.BackgroundTransparency = cfg.Background and 0 or 1
        if typeof(cfg.Background) == "Color3" then
            vp.BackgroundColor3 = cfg.Background
        elseif type(cfg.Background) == "string" then
            bindColor(vp, "BackgroundColor3", cfg.Background)
        end
        vp.BorderSizePixel = 0
        vp.Ambient = cfg.Ambient
        vp.LightColor = cfg.LightColor
        vp.LightDirection = cfg.LightDirection
        vp.ImageTransparency = 0
        if zIndex then vp.ZIndex = zIndex end
        vp.Parent = parent
        if cfg.Background then addCorner(vp, 4) end

        local camera = Instance.new("Camera")
        camera.FieldOfView = cfg.FOV
        camera.Parent = vp
        vp.CurrentCamera = camera

        local world = Instance.new("WorldModel")
        world.Parent = vp

        local handle = {Frame = vp, Camera = camera, World = world}
        local current, center, dist, yaw, spinConn = nil, Vector3.zero, 10, 0, nil

        local function aim()
            local pitch = math.rad(cfg.Angle.X)
            local rot = CFrame.Angles(0, math.rad(cfg.Angle.Y) + yaw, 0) * CFrame.Angles(pitch, 0, 0)
            local offset = rot:VectorToWorldSpace(Vector3.new(0, 0, dist))
            camera.CFrame = CFrame.lookAt(center + offset, center)
        end

        local function stopSpin()
            if spinConn then spinConn:Disconnect(); spinConn = nil end
        end

        function handle:SetModel(model)
            if current then current:Destroy(); current = nil end
            stopSpin()
            if typeof(model) ~= "Instance" then return false end
            local ok, clone = pcall(function() return model:Clone() end)
            if not ok or not clone then return false end
            local holder = Instance.new("Model")
            holder.Name = "Holder"
            clone.Parent = holder
            for _, d in ipairs(holder:GetDescendants()) do
                if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
                    d:Destroy()
                elseif d:IsA("BasePart") then
                    d.Anchored = true
                    d.CanCollide = false
                end
            end
            holder.Parent = world
            current = holder

            local okBox, cf, size = pcall(function() return holder:GetBoundingBox() end)
            if not okBox or not size or size.Magnitude == 0 then
                center, dist = Vector3.zero, 10
            else
                center = cf.Position
                local radius = math.max(size.Magnitude / 2, 0.05)
                dist = (radius / math.sin(math.rad(cfg.FOV) / 2)) * cfg.Padding / math.max(cfg.Zoom, 0.05)
            end
            yaw = 0
            aim()

            if cfg.Spin then
                spinConn = trackConn(RunService.RenderStepped:Connect(function(dt)
                    if not vp.Parent then stopSpin() return end
                    if not vp.Visible then return end
                    yaw = yaw + math.rad(cfg.SpinSpeed) * dt
                    aim()
                end))
            end
            return true
        end

        function handle:SetAngle(v)
            cfg.Angle = v
            aim()
        end

        function handle:SetZoom(z)
            local radius = dist * math.max(cfg.Zoom, 0.05) / cfg.Padding * math.sin(math.rad(cfg.FOV) / 2)
            cfg.Zoom = z
            dist = (radius / math.sin(math.rad(cfg.FOV) / 2)) * cfg.Padding / math.max(cfg.Zoom, 0.05)
            aim()
        end

        function handle:Destroy()
            stopSpin()
            vp:Destroy()
        end

        vp.AncestryChanged:Connect(function()
            if not vp.Parent then stopSpin() end
        end)
        return handle
    end

    -- A fixed-size "icon slot": shows either a lucide icon or (when 3D is on) a viewport
    local function createIconSlot(parent, slotPx, cfg3, zIndex, xOffset)
        local slot = Instance.new("Frame")
        slot.Name = "IconSlot"
        slot.Size = UDim2.new(0, slotPx, 0, slotPx)
        slot.Position = UDim2.new(0, xOffset == nil and 6 or xOffset, 0.5, -slotPx / 2)
        slot.BackgroundTransparency = 1
        if zIndex then slot.ZIndex = zIndex end
        slot.Visible = false
        slot.Parent = parent

        local img = Instance.new("ImageLabel")
        img.AnchorPoint = Vector2.new(0.5, 0.5)
        img.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
        img.Position = UDim2.new(0.5, 0, 0.5, 0)
        img.BackgroundTransparency = 1
        if zIndex then img.ZIndex = zIndex + 1 end
        img.Visible = false
        img.Parent = slot

        local handle = {Frame = slot, Image = img, Has = false, IconName = nil, Viewport = nil}

        function handle:Set(iconName, model, text)
            local inst = cfg3 and resolveModel(model, text, cfg3) or nil
            local renderedModel = false
            if inst then
                if not self.Viewport then
                    self.Viewport = createViewportIcon(slot, cfg3, zIndex and (zIndex + 1) or nil)
                end
                renderedModel = self.Viewport:SetModel(inst)
                self.Viewport.Frame.Visible = renderedModel
            end
            if renderedModel then
                img.Visible = false
                self.Has = true
            elseif iconName then
                if self.Viewport then self.Viewport.Frame.Visible = false end
                img.Image = resolveIcon(iconName)
                img.Visible = true
                self.IconName = iconName
                self.Has = true
            else
                if self.Viewport then self.Viewport.Frame.Visible = false end
                img.Visible = false
                self.Has = false
            end
            slot.Visible = self.Has
            return self.Has
        end

        function handle:Tint(spec)
            if img.Visible then tintIcon(img, self.IconName, spec) end
        end

        return handle
    end

    local function isIconImageSource(value)
        if type(value) == "number" then return true end
        if type(value) ~= "string" then return false end
        local lower = string.lower(value)
        local extension = string.match(lower, "%.([a-z0-9]+)$")
        return string.match(lower, "^%d+$") ~= nil or string.match(lower, "^rbx") ~= nil
            or string.match(lower, "^https?://") ~= nil or string.match(lower, "^data:image/") ~= nil
            or extension == "png" or extension == "jpg" or extension == "jpeg" or extension == "webp"
            or extension == "gif" or extension == "bmp" or extension == "avif" or extension == "tif" or extension == "tiff"
    end

    -- Shared icon parsing for API-created controls. A model/Models source opts
    -- into a ViewportFrame automatically; a Lucide icon remains the fallback.
    local function buttonIconSpec(def, inherited)
        if type(def) ~= "table" then return nil, nil, nil end
        inherited = inherited or {}
        local iconDef = type(def.Icon) == "table" and def.Icon or nil
        local iconName = iconDef and (iconDef.Icon or iconDef.Name or iconDef.Image) or def.Icon
        local model = def.Model or def.Model3D or def.Instance
            or (iconDef and (iconDef.Model or iconDef.Model3D or iconDef.Instance))
        local icon3DValue = def.Icon3D
        if model == nil then
            if typeof(icon3DValue) == "Instance" then
                model = icon3DValue
            elseif type(icon3DValue) == "table" then
                model = icon3DValue.Model or icon3DValue.Model3D or icon3DValue.Instance
            end
        end
        if model == nil and iconDef then
            local nested3D = iconDef.Icon3D
            if typeof(nested3D) == "Instance" then
                model = nested3D
            elseif type(nested3D) == "table" then
                model = nested3D.Model or nested3D.Model3D or nested3D.Instance
            end
        end
        if typeof(iconName) == "Instance" then
            model, iconName = model or iconName, nil
        end

        local enabled = def.Icons3D
        if enabled == nil then enabled = def["3DIcons"] end
        if enabled == nil then enabled = def.ViewportIcons end
        if enabled == nil and iconDef then enabled = iconDef.Icons3D end
        if enabled == nil and iconDef then enabled = iconDef["3DIcons"] end
        if enabled == nil and iconDef then enabled = iconDef.ViewportIcons end
        if enabled == nil then enabled = inherited.Icons3D end
        if enabled == nil then enabled = inherited["3DIcons"] end
        if enabled == nil then enabled = inherited.ViewportIcons end
        local nestedIcon3DValue = iconDef and iconDef.Icon3D
        local icon3DModels = type(icon3DValue) == "table" and icon3DValue.Models or nil
        if icon3DModels == nil and type(nestedIcon3DValue) == "table" then icon3DModels = nestedIcon3DValue.Models end
        if icon3DModels == nil and iconDef and type(iconDef.Icons3D) == "table" then icon3DModels = iconDef.Icons3D.Models end
        if icon3DModels == nil and iconDef and type(iconDef["3DIcons"]) == "table" then icon3DModels = iconDef["3DIcons"].Models end
        if icon3DModels == nil and iconDef and type(iconDef.ViewportIcons) == "table" then icon3DModels = iconDef.ViewportIcons.Models end
        if icon3DModels == nil and type(def.Icons3D) == "table" then icon3DModels = def.Icons3D.Models end
        if icon3DModels == nil and type(def["3DIcons"]) == "table" then icon3DModels = def["3DIcons"].Models end
        if icon3DModels == nil and type(def.ViewportIcons) == "table" then icon3DModels = def.ViewportIcons.Models end
        if icon3DModels == nil and type(def.Icon3DConfig) == "table" then icon3DModels = def.Icon3DConfig.Models end
        if icon3DModels == nil and type(def.Viewport) == "table" then icon3DModels = def.Viewport.Models end
        if icon3DModels == nil and type(def.IconConfig) == "table" then icon3DModels = def.IconConfig.Models end
        if icon3DModels == nil and iconDef and type(iconDef.Icon3DConfig) == "table" then icon3DModels = iconDef.Icon3DConfig.Models end
        if icon3DModels == nil and iconDef and type(iconDef.Viewport) == "table" then icon3DModels = iconDef.Viewport.Models end
        if icon3DModels == nil and iconDef and type(iconDef.IconConfig) == "table" then icon3DModels = iconDef.IconConfig.Models end
        if icon3DModels == nil and type(inherited.Icon3D) == "table" then icon3DModels = inherited.Icon3D.Models end
        if icon3DModels == nil and type(inherited.Icon3DConfig) == "table" then icon3DModels = inherited.Icon3DConfig.Models end
        if icon3DModels == nil and type(inherited.Viewport) == "table" then icon3DModels = inherited.Viewport.Models end
        if icon3DModels == nil and type(inherited.Icons3D) == "table" then icon3DModels = inherited.Icons3D.Models end
        if icon3DModels == nil and type(inherited["3DIcons"]) == "table" then icon3DModels = inherited["3DIcons"].Models end
        if icon3DModels == nil and type(inherited.ViewportIcons) == "table" then icon3DModels = inherited.ViewportIcons.Models end
        local models = def.Models or (iconDef and iconDef.Models) or icon3DModels or inherited.Models
        if model == nil and type(iconName) == "string" and models ~= nil
            and not (LUCIDE[iconName] or CUSTOM_ICON_DATA[iconName]) and not isIconImageSource(iconName) then
            model = iconName
        end
        if enabled == nil and (model ~= nil or models ~= nil) then enabled = true end
        if enabled == false then return iconName, nil, nil end

        local cfg = nil
        if enabled then
            local cfgSource = def.Icon3DConfig or def.Viewport or def.IconConfig
                or (iconDef and (iconDef.Icon3DConfig or iconDef.Viewport or iconDef.IconConfig))
            if type(icon3DValue) == "table" or type(icon3DValue) == "number" then
                cfgSource = icon3DValue
            elseif iconDef and (type(iconDef.Icon3D) == "table" or type(iconDef.Icon3D) == "number") then
                cfgSource = iconDef.Icon3D
            elseif cfgSource == nil then
                cfgSource = inherited.Icon3D or inherited.Icon3DConfig or inherited.Viewport
            end
            if type(enabled) == "table" then
                cfgSource = enabled
            elseif type(enabled) == "number" then
                local merged = {}
                if type(cfgSource) == "table" then
                    for key, value in pairs(cfgSource) do merged[key] = value end
                elseif type(cfgSource) == "number" then
                    merged.Size = cfgSource
                end
                merged.Size = enabled
                cfgSource = merged
            elseif type(inherited.Icons3D) == "table" and def.Icons3D == nil then
                cfgSource = inherited.Icons3D
            end
            cfg = normalize3DConfig(cfgSource, {
                IconSize = def.IconSize or def.Icon3DSize or def.ViewportSize
                    or (iconDef and (iconDef.IconSize or iconDef.Size or (type(iconDef.Icon3D) == "number" and iconDef.Icon3D)))
                    or (type(icon3DValue) == "number" and icon3DValue)
                    or (type(def.Icons3D) == "number" and def.Icons3D)
                    or inherited.IconSize,
                Models = models,
            })
        end
        return iconName, model, cfg
    end

    local function createModelViewport(parent, modelValue, text, cfg, zIndex)
        if not cfg then return nil end
        local model = resolveModel(modelValue, text, cfg)
        if not model then return nil end
        local viewport = createViewportIcon(parent, cfg, zIndex)
        if not viewport:SetModel(model) then
            viewport:Destroy()
            return nil
        end
        return viewport
    end

    -- shared per-dropdown geometry derived from the 3D-icon settings
    local function dropdownIconLayout(extra)
        local use3D = extra and extra.Icons3D
        local cfg3 = use3D and normalize3DConfig(extra.Icon3D, extra) or nil
        local slotPx = cfg3 and math.max(cfg3.Size, ICON_SIZE) or ICON_SIZE
        return {
            Cfg = cfg3,
            Slot = slotPx,
            ControlH = math.max(CONTROL_H, slotPx + 6),
            OptionH = math.max(SELECT_OPTION_H, slotPx + 6),
            TextX = slotPx + 12,
        }
    end

    local function addDropdown(card, name, description, options, defaultIndex, callback, extra)
        local L = dropdownIconLayout(extra)
        local row, top = createRow(card, name, description, {controlHeight = L.ControlH})

        local select = Instance.new("TextButton")
        select.Name = "Select"
        select.Size = UDim2.new(1, 0, 0, L.ControlH)
        select.Position = UDim2.new(0, 0, 0, top)
        bindColor(select, "BackgroundColor3", "BadgeBg")
        select.Text = ""
        select.AutoButtonColor = false
        select.Parent = row
        addCorner(select, 4)
        addStroke(select)

        local currentIdx = defaultIndex or 1
        local curText, curIconName, curModel = normalizeOption(options[currentIdx])

        local selectIcon = createIconSlot(select, L.Slot, L.Cfg, nil)
        selectIcon:Set(curIconName, curModel, curText)
        selectIcon:Tint("TextMuted")

        local valueLbl = Instance.new("TextLabel")
        valueLbl.Size = UDim2.new(1, -52, 1, 0)
        valueLbl.Position = UDim2.new(0, selectIcon.Has and L.TextX or 8, 0, 0)
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
                local optText, optIconName, optModel = normalizeOption(optData)

                local ob = Instance.new("TextButton")
                ob.Size = UDim2.new(1, 0, 0, L.OptionH)
                bindColor(ob, "BackgroundColor3", "SidebarActive")
                ob.BackgroundTransparency = 1
                ob.Text = ""
                ob.AutoButtonColor = false
                ob.ZIndex = 101
                ob.LayoutOrder = i
                ob.Parent = list
                addCorner(ob, 4)
                table.insert(rows, {Frame = ob, Text = optText})

                local obIcon = createIconSlot(ob, L.Slot, L.Cfg, 102)
                if obIcon:Set(optIconName, optModel, optText) then
                    obIcon:Tint(function() return ((i == currentIdx)) and "Accent" or "TextMuted" end)
                else
                    obIcon = nil
                end

                local obText = Instance.new("TextLabel")
                obText.Size = UDim2.new(1, -36, 1, 0)
                obText.Position = UDim2.new(0, obIcon and L.TextX or 8, 0, 0)
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
                    if obIcon then obIcon:Tint("Accent") end
                end)
                ob.MouseLeave:Connect(function()
                    ob.BackgroundTransparency = 1
                    local c = (i == currentIdx) and THEME.Accent or THEME.TextPrimary
                    obText.TextColor3 = c
                    if obIcon then
                        obIcon:Tint(function() return ((i == currentIdx)) and "Accent" or "TextMuted" end)
                    end
                end)
                ob.MouseButton1Click:Connect(function()
                    currentIdx = i
                    valueLbl.Text = optText
                    if selectIcon:Set(optIconName, optModel, optText) then
                        selectIcon:Tint("TextMuted")
                        valueLbl.Position = UDim2.new(0, L.TextX, 0, 0)
                    else
                        valueLbl.Position = UDim2.new(0, 8, 0, 0)
                    end
                    popup:Destroy()
                    currentPopup = nil
                    if callback then callback(optText, i) end
                end)
            end

            addPopupSearch(popup, rows, list, L.OptionH)
            trackPopup(popup, select)
            currentPopup = popup
        end)

        local function applySelection(idx, fire)
            if not idx or not options[idx] then return end
            currentIdx = idx
            local optText, optIconName, optModel = normalizeOption(options[idx])
            valueLbl.Text = optText
            if selectIcon:Set(optIconName, optModel, optText) then
                selectIcon:Tint("TextMuted")
                valueLbl.Position = UDim2.new(0, L.TextX, 0, 0)
            else
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

        dropdownApi.Icon = selectIcon          -- icon slot of the closed control (.Viewport when 3D)
        dropdownApi.Icon3D = L.Cfg             -- effective 3D settings (nil when disabled)

        setmetatable(dropdownApi, {__call = function(_, text, idx)
            if idx then
                applySelection(idx, false)
            else
                valueLbl.Text = text
            end
        end})
        return wrapHandle(dropdownApi)
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

        return wrapHandle({
            Set = function(value) setValue(value, true) end,
            Get = function() return currentValue end,
        })
    end

    local function addKeybind(card, name, description, defaultKey, callback, extra)
        extra = extra or {}
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
        local overlayId = nil
        if extra.Show ~= false then
            overlayId = registerOverlayKeybind({
                Id = extra.Id,
                Name = extra.DisplayName or name,
                Key = currentKey,
            })
            noteKeybindForOverlay()
        end

        local function syncOverlay()
            if overlayId then
                updateOverlayKeybind(overlayId, currentKey)
            end
        end

        resetBtn.MouseButton1Click:Connect(function()
            if listener then
                listener:Disconnect()
                listener = nil
            end
            listening = false
            currentKey = "None"
            badge.Text = "None"
            bindColor(badge, "TextColor3", "TextMuted")
            syncOverlay()
            if callback then callback("None") end
        end)

        badge.MouseButton1Click:Connect(function()
            if listening then
                if listener then
                    listener:Disconnect()
                    listener = nil
                end
                badge.Text = currentKey
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
                    syncOverlay()
                    if callback then callback(badge.Text) end
                end
            end))
        end)

        return wrapHandle({
            Set = function(value)
                currentKey = tostring(value)
                badge.Text = currentKey
                bindColor(badge, "TextColor3", "TextMuted")
                syncOverlay()
                if callback then callback(currentKey) end
            end,
            Get = function() return currentKey end,
        })
    end

    local function addButtonRow(card, name, description, buttons, extra)
        local iconLayout = dropdownIconLayout(extra)
        local buttonHeight = math.max(BUTTON_H, iconLayout.Slot + 6)
        local row, top = createRow(card, name, description, {controlHeight = buttonHeight})

        local holder = Instance.new("Frame")
        holder.Name = "Buttons"
        holder.Size = UDim2.new(1, 0, 0, buttonHeight)
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
            local buttonText = tostring(def.Text or "")
            local btn = Instance.new("TextButton")
            btn.Name = tostring(def.Name or (buttonText ~= "" and buttonText) or ("Button" .. i))
            btn.LayoutOrder = i
            btn.Size = UDim2.new(1 / count, -(gap * (count - 1)) / count, 1, 0)
            bindColor(btn, "BackgroundColor3", "Accent")
            btn.Text = buttonText
            btn.AutoButtonColor = false
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 12
            bindColor(btn, "TextColor3", "KnobOn")
            btn.Parent = holder
            addCorner(btn, 6)

            local _, iconName, iconModel = normalizeOption(def)
            local buttonIconConfig = iconLayout.Cfg
            if def.Icons3D == false or def["3DIcons"] == false or def.ViewportIcons == false then
                buttonIconConfig = nil
            end
            local iconSlot = createIconSlot(btn, iconLayout.Slot, buttonIconConfig, 2)
            local iconText = nil
            if iconSlot:Set(iconName, iconModel, buttonText) then
                iconSlot:Tint("KnobOn")
                btn.TextTransparency = 1

                iconText = Instance.new("TextLabel")
                iconText.Name = "ButtonText"
                iconText.Size = UDim2.new(1, -(iconLayout.TextX + 8), 1, 0)
                iconText.Position = UDim2.new(0, iconLayout.TextX, 0, 0)
                iconText.BackgroundTransparency = 1
                iconText.Text = buttonText
                iconText.Font = Enum.Font.GothamBold
                iconText.TextSize = 12
                bindColor(iconText, "TextColor3", "KnobOn")
                iconText.TextXAlignment = Enum.TextXAlignment.Left
                iconText.TextTruncate = Enum.TextTruncate.AtEnd
                iconText.ZIndex = 2
                iconText.Parent = btn
            end

            btn.MouseButton1Click:Connect(function()
                if def.Callback then def.Callback() end
            end)
            table.insert(createdButtons, wrapHandle({
                Button = btn,
                Icon = iconSlot,
                Icon3D = buttonIconConfig,
                Fire = function() if def.Callback then def.Callback() end end,
                SetText = function(t)
                    local text = tostring(t)
                    btn.Text = text
                    if iconText then iconText.Text = text end
                end,
            }))
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

        return wrapHandle({
            Set = function(t) lbl.Text = tostring(t) end,
        })
    end

    local function addMultiDropdown(card, name, description, options, defaults, callback, extra)
        local L = dropdownIconLayout(extra)
        local row, top = createRow(card, name, description, {controlHeight = L.ControlH})

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
        select.Size = UDim2.new(1, 0, 0, L.ControlH)
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
                local optText, optIconName, optModel = normalizeOption(optData)

                local ob = Instance.new("TextButton")
                ob.Size = UDim2.new(1, 0, 0, L.OptionH)
                bindColor(ob, "BackgroundColor3", "SidebarActive")
                ob.BackgroundTransparency = 1
                ob.Text = ""
                ob.AutoButtonColor = false
                ob.ZIndex = 101
                ob.LayoutOrder = i
                ob.Parent = list
                addCorner(ob, 4)
                table.insert(rows, {Frame = ob, Text = optText})

                local obIcon = createIconSlot(ob, L.Slot, L.Cfg, 102)
                if obIcon:Set(optIconName, optModel, optText) then
                    obIcon:Tint(function() return (states[i]) and "Accent" or "TextMuted" end)
                else
                    obIcon = nil
                end

                local obText = Instance.new("TextLabel")
                obText.Size = UDim2.new(1, -36, 1, 0)
                obText.Position = UDim2.new(0, obIcon and L.TextX or 8, 0, 0)
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
                        obIcon:Tint(function() return (states[i]) and "Accent" or "TextMuted" end)
                    end
                    valueLbl.Text = buildSummary()
                    if callback then callback(options, states) end
                end)
            end

            addPopupSearch(popup, rows, list, L.OptionH)
            trackPopup(popup, select)
            currentPopup = popup
        end)

        return wrapHandle({
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
        })
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
        return wrapHandle(colorApi)
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

        return wrapHandle(api)
    end

    local RESIZE_MIN_W = INITIAL_MOBILE and math.max(200, math.min(260, MAIN_START_W)) or 500
    local RESIZE_MIN_H = INITIAL_MOBILE and math.max(180, math.min(220, MAIN_START_H)) or 320

    local resizeHandleSize = INITIAL_MOBILE and 28 or 18
    local resizeHandle = Instance.new("TextButton")
    resizeHandle.Name = "ResizeHandle"
    resizeHandle.Size = UDim2.new(0, resizeHandleSize, 0, resizeHandleSize)
    resizeHandle.Position = UDim2.new(1, -resizeHandleSize, 1, -resizeHandleSize)
    resizeHandle.BackgroundTransparency = 1
    resizeHandle.Text = ""
    resizeHandle.AutoButtonColor = false
    resizeHandle.ZIndex = 10
    resizeHandle.Parent = Main

    local BROWSE_WINDOWS = {} -- standalone Browse windows: {Frame, Scale, HiddenWithUI}

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
        local resizeStart, startSize, startScale, activeInputType
        local resizeWithoutScale = false

        resizeHandle.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            if pointOnFloatingFrame(input.Position.X, input.Position.Y) then return end
            resizing = true
            activeInputType = input.UserInputType
            resizeStart = input.Position
            startScale = UI_SCALE
            resizeWithoutScale = shiftHeld()
            startSize = Vector2.new(Main.Size.X.Offset * startScale, Main.Size.Y.Offset * startScale)
            closeAllPopups()
        end)

        trackConn(UserInputService.InputChanged:Connect(function(input)
            if not resizing then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement
                and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end

            local delta = input.Position - resizeStart
            local viewport = getViewportSize()
            local minimumScale = resizeWithoutScale and startScale or UI_SCALE_MIN
            local minW = RESIZE_MIN_W * minimumScale
            local minH = RESIZE_MIN_H * minimumScale
            local maxW = math.max(minW, viewport.X - Main.AbsolutePosition.X - 8)
            local maxH = math.max(minH, viewport.Y - Main.AbsolutePosition.Y - 8)
            local pixelW = math.clamp(startSize.X + delta.X, minW, maxW)
            local pixelH = math.clamp(startSize.Y + delta.Y, minH, maxH)

            local scale = startScale
            if not resizeWithoutScale then
                scale = math.clamp(math.sqrt((pixelW / BASE_W) * (pixelH / BASE_H)), UI_SCALE_MIN, UI_SCALE_MAX)
            end
            UI_SCALE = scale
            mainScale.Scale = scale
            notifyScale.Scale = scale
            keybindScale.Scale = scale
            Main.Size = UDim2.new(0, pixelW / scale, 0, pixelH / scale)
        end))

        trackConn(UserInputService.InputEnded:Connect(function(input)
            if (activeInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)
                or (activeInputType == Enum.UserInputType.Touch and input.UserInputType == Enum.UserInputType.Touch) then
                resizing = false
                activeInputType = nil
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

    --[[ Browse / gallery panel ------------------------------------------------
        A full-area tab that shows items as a grid of cards (thumbnail, rating
        badge, name) with a search box, category chips, a sort switch, a refresh
        button and pagination. Items come from a plain table, a function, or an
        HTTP JSON API (`Source = "https://.../items.json"`), so the same script
        works for every user: the list lives on the server, not in the script. ]]
    local HttpService = game:GetService("HttpService")
    local BROWSE_IMAGE_CACHE = {}
    local BROWSE_CACHE_DIR = "UILibrary/cache"

    local function looksLikeHttpError(body)
        return string.match(body, "^%s*404") ~= nil or string.match(body, "^%s*<!DOCTYPE") ~= nil
    end

    local function httpGet(url)
        local ok, body = pcall(function() return game:HttpGet(url, true) end)
        if ok and type(body) == "string" and #body > 0 and not looksLikeHttpError(body) then return body end
        local req = (type(request) == "function" and request)
            or (type(http_request) == "function" and http_request)
            or (type(syn) == "table" and type(syn.request) == "function" and syn.request)
            or nil
        if req then
            local ok2, res = pcall(req, {Url = url, Method = "GET"})
            if ok2 and type(res) == "table" and type(res.Body) == "string" and #res.Body > 0 then
                local code = tonumber(res.StatusCode) or 200
                if code >= 200 and code < 300 then return res.Body end
                return nil, "HTTP " .. tostring(code)
            end
        end
        local ok3, body3 = pcall(HttpService.GetAsync, HttpService, url)
        if ok3 and type(body3) == "string" and #body3 > 0 then return body3 end
        return nil, (not ok and tostring(body)) or (not ok3 and tostring(body3)) or "request failed"
    end

    local function stringHash(s)
        local h = 5381
        for i = 1, #s do
            h = (h * 33 + string.byte(s, i)) % 4294967296
        end
        return string.format("%08x", h)
    end

    local function ensureFolder(path)
        if type(isfolder) ~= "function" or type(makefolder) ~= "function" then return end
        local ok, exists = pcall(isfolder, path)
        if ok and not exists then pcall(makefolder, path) end
    end

    -- Turns anything the API can give us into something ImageLabel.Image accepts.
    -- http(s) links are downloaded once and served through getcustomasset (executor only).
    local function resolveBrowseImage(src)
        if type(src) == "number" then return "rbxassetid://" .. tostring(src) end
        src = tostring(src or "")
        if src == "" then return "" end
        if string.match(src, "^%d+$") then return "rbxassetid://" .. src end
        if string.match(src, "^rbx") then return src end
        if string.match(src, "^https?://") then
            local cached = BROWSE_IMAGE_CACHE[src]
            if cached ~= nil then return cached end
            BROWSE_IMAGE_CACHE[src] = ""
            if type(writefile) ~= "function" or type(getcustomasset) ~= "function" then
                return ""
            end
            local ok, asset = pcall(function()
                local body = httpGet(src)
                if not body then return nil end
                ensureFolder("UILibrary")
                ensureFolder(BROWSE_CACHE_DIR)
                local ext = string.find(string.lower(src), "%.jpe?g") and ".jpg" or ".png"
                local file = BROWSE_CACHE_DIR .. "/" .. stringHash(src) .. ext
                if not (type(isfile) == "function" and isfile(file)) then
                    writefile(file, body)
                end
                return getcustomasset(file)
            end)
            if ok and type(asset) == "string" then
                BROWSE_IMAGE_CACHE[src] = asset
                return asset
            end
            return ""
        end
        return src
    end

    local function pickField(raw, ...)
        for _, key in ipairs({...}) do
            local v = raw[key]
            if v ~= nil then return v end
        end
        return nil
    end

    local function normalizeBrowseItem(raw, index, defaultFit, sharedModels)
        if type(raw) ~= "table" then return nil end
        if raw.__browseItem then
            if defaultFit and raw.Fit == nil then raw.Fit = true end
            return raw
        end
        local item = {__browseItem = true, Raw = raw}
        item.Id = pickField(raw, "Id", "id", "ID", "Key", "key", "uid", "Uid", "path", "Path") or index
        item.Name = tostring(pickField(raw, "Name", "name", "Title", "title", "rawTitle", "fileName", "filename") or ("Item " .. tostring(index)))
        item.Category = tostring(pickField(raw, "Category", "category", "Type", "type", "Class", "class", "Kind", "kind") or "Other")
        local rating = tonumber(pickField(raw, "Rating", "rating", "Likes", "likes", "Score", "score", "Percent", "percent", "Quality", "quality"))
        if rating and rating > 0 and rating <= 1 then rating = rating * 100 end
        item.Rating = rating
        item.Images = {}
        local many = pickField(raw, "Images", "images", "Thumbnails", "thumbnails", "Previews", "previews")
        if type(many) == "table" then
            for _, img in ipairs(many) do
                if img ~= nil and img ~= "" then table.insert(item.Images, img) end
            end
        end
        item.Icon = pickField(raw, "Icon", "icon")
        item.Icon3D = pickField(raw, "Icon3D", "icon3d", "Icon3d", "Icon3DConfig", "icon3d_config", "Viewport", "viewport", "ModelConfig", "modelConfig")
        item.Models = pickField(raw, "Models", "models")
        item.IconSize = tonumber(pickField(raw, "IconSize", "iconSize", "Icon3DSize", "icon3d_size"))
        item.Icons3D = pickField(raw, "Icons3D", "icons3d", "3DIcons", "ViewportIcons")
        item.Model = pickField(raw, "Model", "model", "Model3D", "model3d", "PreviewModel", "previewModel", "Instance", "instance")
        if type(item.Icon) == "table" then
            item.Models = item.Models or item.Icon.Models
            item.Icon3D = item.Icon3D or item.Icon.Icon3D or item.Icon.Icon3DConfig or item.Icon.Viewport
            item.IconSize = item.IconSize or tonumber(item.Icon.IconSize or item.Icon.Size)
            if item.Icons3D == nil then
                item.Icons3D = item.Icon.Icons3D
                if item.Icons3D == nil then item.Icons3D = item.Icon["3DIcons"] end
                if item.Icons3D == nil then item.Icons3D = item.Icon.ViewportIcons end
            end
        end
        if item.Model == nil and typeof(item.Icon) == "Instance" then item.Model = item.Icon end
        if item.Model == nil and typeof(item.Icon3D) == "Instance" then item.Model = item.Icon3D end
        if item.Model == nil and type(item.Icon) == "table" then
            item.Model = item.Icon.Model or item.Icon.Model3D or item.Icon.Instance
            item.Icon3D = item.Icon3D or item.Icon.Icon3D
        end
        if item.Model == nil and type(item.Icon3D) == "table" then
            item.Model = item.Icon3D.Model or item.Icon3D.Model3D or item.Icon3D.Instance
        end
        local iconName = type(item.Icon) == "table" and (item.Icon.Name or item.Icon.Icon) or item.Icon
        if type(iconName) == "string" and (LUCIDE[iconName] or CUSTOM_ICON_DATA[iconName]) then
            item.IconName = iconName
        end
        local single = pickField(raw, "Image", "image", "Thumbnail", "thumbnail", "Preview", "preview",
            "thumbUrl", "thumb_url", "thumbnail_url", "image_url", "coverUrl", "cover_url", "ImageUrl", "imageUrl")
        if single == nil and item.Model == nil and item.IconName == nil then
            if type(item.Icon) == "number" then
                single = item.Icon
            elseif type(item.Icon) == "string" then
                if isIconImageSource(item.Icon) or (item.Models == nil and sharedModels == nil) then
                    single = item.Icon
                end
            elseif type(item.Icon) == "table" then
                single = item.Icon.Image or item.Icon.Url or item.Icon.Source
            end
        end
        if single ~= nil and single ~= "" and #item.Images == 0 then
            table.insert(item.Images, single)
        end
        item.Image = item.Images[1]
        local fitValue = pickField(raw, "Fit", "fit", "Contain", "contain")
        if fitValue == nil then
            item.Fit = defaultFit == true
        else
            local fitText = string.lower(tostring(fitValue))
            item.Fit = fitValue == true or fitValue == 1 or fitText == "true" or fitText == "yes" or fitText == "1"
        end
        item.Author = pickField(raw, "Author", "author", "Creator", "creator", "Owner", "owner", "By", "by")
        item.Date = tonumber(pickField(raw, "Date", "date", "Time", "time", "Created", "created", "Timestamp", "timestamp", "Updated", "updated")) or index
        item.Published = pickField(raw, "Published", "published", "PublishedAt", "published_at", "CreatedAt", "created_at")
        local verified = pickField(raw, "Verified", "verified", "AuthorVerified", "author_verified")
        local verifiedText = string.lower(tostring(verified or ""))
        item.Verified = verified == true or verified == 1 or verifiedText == "true" or verifiedText == "yes" or verifiedText == "verified" or verifiedText == "1"
        item.Downloads = tonumber(pickField(raw, "Downloads", "downloads", "DownloadCount", "download_count", "DownloadsCount", "downloads_count"))
        item.Likes = tonumber(pickField(raw, "Likes", "likes", "Favorites", "favorites", "Stars", "stars"))
        item.Popularity = tonumber(pickField(raw, "Popularity", "popularity", "Popular", "popular"))
        item.Rank = tonumber(pickField(raw, "Rank", "rank", "Position", "position"))
        item.BuildValue = pickField(raw, "BuildValue", "build_value", "Value", "value", "Cost", "cost")
        item.Buildability = tonumber(pickField(raw, "Buildability", "buildability", "BuildabilityPercent", "buildability_percent", "Completeness", "completeness"))
        item.ViewUrl = pickField(raw, "ViewUrl", "viewUrl", "view_url", "PreviewUrl", "preview_url", "ThreeDUrl", "3d_url")
        local blocks = pickField(raw, "BlockList", "block_list", "BlockNames", "block_names", "Blocks", "blocks")
        local blockContainer = type(blocks) == "table" and blocks or nil
        local blockList = blockContainer and (blockContainer.Items or blockContainer.Blocks) or blockContainer
        item.BlockList = type(blockList) == "table" and blockList or nil
        item.BlockCount = tonumber(pickField(raw, "BlockCount", "block_count", "BlocksCount", "blocks_count", "PartCount", "part_count"))
            or (blockContainer and tonumber(blockContainer.Count or blockContainer.Total))
            or (type(blockList) == "table" and #blockList or tonumber(blocks))
        item.Blocks = item.BlockList or item.BlockCount
        item.Tags = pickField(raw, "Tags", "tags")
        item.Description = pickField(raw, "Description", "description", "Desc", "desc")
        item.Data = pickField(raw, "Data", "data", "Payload", "payload", "Script", "script", "Url", "url", "Link", "link", "Code", "code")
        return item
    end

    local function extractBrowseList(data)
        if type(data) ~= "table" then return {} end
        if #data > 0 or next(data) == nil then return data end
        for _, key in ipairs({"items", "Items", "data", "Data", "results", "Results", "list", "List", "builds", "Builds", "scripts", "Scripts", "entries", "Entries"}) do
            if type(data[key]) == "table" then return extractBrowseList(data[key]) end
        end
        -- dictionary keyed by id -> array
        local list = {}
        for key, value in pairs(data) do
            if type(value) == "table" then
                if value.Id == nil and value.id == nil then value.Id = key end
                table.insert(list, value)
            end
        end
        table.sort(list, function(a, b) return tostring(a.Id) < tostring(b.Id) end)
        return list
    end

    local BROWSE_SORTS = {
        Hot = {Icon = "zap", Sort = function(a, b)
            local ra, rb = a.Rating or -1, b.Rating or -1
            if ra ~= rb then return ra > rb end
            if a.Date ~= b.Date then return a.Date > b.Date end
            return a.Name < b.Name
        end},
        New = {Icon = "clock", Sort = function(a, b)
            if a.Date ~= b.Date then return a.Date > b.Date end
            return a.Name < b.Name
        end},
        Newest = {Icon = "clock", Sort = function(a, b)
            if a.Date ~= b.Date then return a.Date > b.Date end
            return a.Name < b.Name
        end},
        Top = {Icon = "crown", Sort = function(a, b)
            local ra, rb = a.Rating or -1, b.Rating or -1
            if ra ~= rb then return ra > rb end
            return a.Name < b.Name
        end},
        ["Most downloaded"] = {Icon = "download", Sort = function(a, b)
            local da, db = a.Downloads or 0, b.Downloads or 0
            if da ~= db then return da > db end
            return a.Name < b.Name
        end},
        ["Most popular"] = {Icon = "zap", Sort = function(a, b)
            local pa = a.Popularity or a.Likes or a.Rating or 0
            local pb = b.Popularity or b.Likes or b.Rating or 0
            if pa ~= pb then return pa > pb end
            return a.Name < b.Name
        end},
        ["A-Z"] = {Icon = "type", Sort = function(a, b)
            return string.lower(a.Name) < string.lower(b.Name)
        end},
    }

    --[[ Dialog --------------------------------------------------------------
        A centered modal card: title + header buttons + close, an image block
        (1-4 pictures with a tag and a badge over it), info lines and stacked
        action buttons (single or two per row). Used by the Browse tab for item
        details and available directly as Window:CreateDialog(opts). ]]
    local DIALOG_W = 320
    local DIALOG_BTN_H = 34
    local activeDialog = nil

    -- Dialogs live in their own ScreenGui with IgnoreGuiInset = true, so the
    -- backdrop really covers the whole screen (including the Roblox top bar).
    local DialogGui = nil
    local function getDialogGui()
        if DialogGui and DialogGui.Parent then return DialogGui end
        DialogGui = Instance.new("ScreenGui")
        DialogGui.Name = "UILibraryDialogs"
        DialogGui.ResetOnSpawn = false
        DialogGui.IgnoreGuiInset = true
        DialogGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        DialogGui.DisplayOrder = ScreenGui.DisplayOrder + 1
        DialogGui.Parent = ScreenGui.Parent or ScreenGui
        return DialogGui
    end

    local function guiInset()
        local ok, topLeft = pcall(function() return game:GetService("GuiService"):GetGuiInset() end)
        return (ok and topLeft) or Vector2.new(0, 0)
    end

    local function closeActiveDialog()
        local d = activeDialog
        activeDialog = nil
        if d then d.Close() end
    end

    local function dialogTextOf(def)
        if type(def) == "table" then return tostring(def.Text or def.Title or def.Name or "") end
        return tostring(def or "")
    end

    local function dialogCompactCount(value)
        local n = tonumber(value)
        if not n then return tostring(value or "") end
        if math.abs(n) >= 1000000 then return string.format("%.1fm", n / 1000000):gsub("%.0m$", "m") end
        if math.abs(n) >= 1000 then return string.format("%.1fk", n / 1000):gsub("%.0k$", "k") end
        return tostring(math.floor(n + 0.5))
    end

    local function createDialog(dOpts)
        dOpts = dOpts or {}
        closeActiveDialog()
        closeAllPopups()
        local anchor = dOpts.Anchor
        if typeof(anchor) ~= "Instance" or not anchor:IsA("GuiObject") or not anchor.Visible then
            anchor = Main.Visible and Main or nil
        end
        local dialogScale = UI_SCALE
        if anchor then
            local anchorScale = anchor:FindFirstChildOfClass("UIScale")
            if anchorScale then dialogScale = anchorScale.Scale end
        end
        local viewport = getViewportSize()
        local mobileDialog = isMobileDevice(viewport)
        local widthMargin = mobileDialog and 16 or 28
        local maxWidth = math.max(180, (viewport.X - widthMargin * 2) / math.max(dialogScale, 0.01))
        local maxHeight = math.max(180, (viewport.Y - widthMargin * 2) / math.max(dialogScale, 0.01))
        local width = math.min(tonumber(dOpts.Width) or DIALOG_W, maxWidth)
        local resizable = dOpts.Resizable ~= false
        local dialogIcons3D = dOpts.Icons3D
        if dialogIcons3D == nil then dialogIcons3D = dOpts["3DIcons"] end
        local dialogIconDefaults = {
            Icons3D = dialogIcons3D,
            Icon3D = dOpts.Icon3DConfig or dOpts.Viewport,
            IconSize = dOpts.IconSize or dOpts.Icon3DSize,
            Models = dOpts.Models,
        }
        if type(dOpts.Icon3D) == "table" or type(dOpts.Icon3D) == "number" then
            dialogIconDefaults.Icon3D = dOpts.Icon3D
        end
        local function isDialogImageSource(value)
            return isIconImageSource(value)
        end
        local boxBottomPadding = 12
        local gripSize = mobileDialog and 28 or 18
        -- The grip is unscaled in the dialog ScreenGui; convert its clearance
        -- back to dialog units so it remains safe at every dialog scale.
        local gripBottomClearance = math.max(0, (gripSize + 4) / math.max(dialogScale, 0.01) - boxBottomPadding)
        local connections = {}
        local closed = false
        local handle = {}

        local layer = getDialogGui()
        local overlay = Instance.new("TextButton")
        overlay.Name = "DialogOverlay"
        overlay.Position = UDim2.new(0, -8, 0, -8)
        overlay.Size = UDim2.new(1, 16, 1, 16)
        overlay.BackgroundColor3 = Color3.new(0, 0, 0)
        overlay.BackgroundTransparency = 1
        overlay.BorderSizePixel = 0
        overlay.Text = ""
        overlay.AutoButtonColor = false
        overlay.ZIndex = 149
        overlay.Parent = layer
        TweenService:Create(overlay, TWEEN_FAST, {BackgroundTransparency = dOpts.Dim == false and 1 or 0.45}):Play()

        local box = Instance.new("Frame")
        box.Name = "Dialog"
        box.Size = UDim2.new(0, width, 0, 0)
        box.AutomaticSize = Enum.AutomaticSize.Y
        box.AnchorPoint = Vector2.new(0.5, 0.5)
        bindColor(box, "BackgroundColor3", "Background")
        box.BorderSizePixel = 0
        box.Active = true -- sinks input: clicks/drags inside never reach the backdrop
        box.ClipsDescendants = resizable
        box.ZIndex = 150
        box.Parent = layer
        FLOATING_FRAMES[box] = true
        FLOATING_FRAMES[overlay] = true
        scalePopup(box)
        local boxScale = box:FindFirstChildOfClass("UIScale")
        if boxScale then boxScale.Scale = dialogScale end
        addCorner(box, 12)
        local boxStroke = addStroke(box, 1)
        boxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        boxStroke.LineJoinMode = Enum.LineJoinMode.Round

        do -- center over the anchor window (main window by default)
            local center
            if anchor then
                -- anchor position relative to the main ScreenGui + that gui's offset on screen (the inset)
                center = anchor.AbsolutePosition - ScreenGui.AbsolutePosition + guiInset() + anchor.AbsoluteSize / 2
            else
                center = layer.AbsoluteSize / 2
            end
            box.Position = UDim2.fromOffset(center.X, center.Y + 16)
            TweenService:Create(box, TWEEN_SLOW, {Position = UDim2.fromOffset(center.X, center.Y)}):Play()
        end

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 10)
        pad.PaddingBottom = UDim.new(0, boxBottomPadding)
        pad.PaddingLeft = UDim.new(0, 12)
        pad.PaddingRight = UDim.new(0, 12)
        pad.Parent = box

        local list = Instance.new("UIListLayout")
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Padding = UDim.new(0, 8)
        list.Parent = box

        local order = 0
        local function nextOrder() order = order + 1 return order end

        -- Header ------------------------------------------------------------------
        local header = Instance.new("Frame")
        header.Size = UDim2.new(1, 0, 0, 24)
        header.BackgroundTransparency = 1
        header.LayoutOrder = nextOrder()
        header.ZIndex = 151
        header.Parent = box

        local headerRight = Instance.new("Frame")
        headerRight.Size = UDim2.new(0, 0, 1, 0)
        headerRight.AutomaticSize = Enum.AutomaticSize.X
        headerRight.AnchorPoint = Vector2.new(1, 0)
        headerRight.Position = UDim2.new(1, 0, 0, 0)
        headerRight.BackgroundTransparency = 1
        headerRight.ZIndex = 151
        headerRight.Parent = header
        local hrLayout = Instance.new("UIListLayout")
        hrLayout.FillDirection = Enum.FillDirection.Horizontal
        hrLayout.SortOrder = Enum.SortOrder.LayoutOrder
        hrLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        hrLayout.Padding = UDim.new(0, 6)
        hrLayout.Parent = headerRight

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -40, 1, 0)
        title.BackgroundTransparency = 1
        title.Text = dialogTextOf(dOpts.Title ~= nil and dOpts.Title or "Details")
        title.Font = Enum.Font.GothamBold
        title.TextSize = 12
        bindColor(title, "TextColor3", "TextPrimary")
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextTruncate = Enum.TextTruncate.AtEnd
        title.ZIndex = 151
        title.Parent = header
        headerRight:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            title.Size = UDim2.new(1, -(headerRight.AbsoluteSize.X / math.max(dialogScale, 0.01) + 8), 1, 0)
        end)

        local function smallPill(parent, rawDef, orderIdx)
            local def = type(rawDef) == "table" and rawDef or {Text = rawDef}
            local text = dialogTextOf(def)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, 0, 0, 22)
            btn.AutomaticSize = Enum.AutomaticSize.X
            btn.LayoutOrder = orderIdx
            bindColor(btn, "BackgroundColor3", "BadgeBg")
            btn.BorderSizePixel = 0
            btn.Text = ""
            btn.AutoButtonColor = false
            btn.ZIndex = 152
            btn.Parent = parent
            addCorner(btn, 6)
            local stroke = addStroke(btn, 1)
            local p = Instance.new("UIPadding")
            p.PaddingLeft = UDim.new(0, 9)
            p.PaddingRight = UDim.new(0, 9)
            p.Parent = btn
            local content = Instance.new("UIListLayout")
            content.FillDirection = Enum.FillDirection.Horizontal
            content.SortOrder = Enum.SortOrder.LayoutOrder
            content.VerticalAlignment = Enum.VerticalAlignment.Center
            content.Padding = UDim.new(0, 4)
            content.Parent = btn
            local iconName, iconModel, iconConfig = buttonIconSpec(def, dialogIconDefaults)
            local iconSize = iconConfig and math.clamp(iconConfig.Size, 12, 16) or 12
            local hasIcon = false
            if iconName or iconModel or iconConfig then
                local iconSlot = createIconSlot(btn, iconSize, iconConfig, 153, 0)
                iconSlot.Frame.LayoutOrder = 1
                hasIcon = iconSlot:Set(iconName, iconModel, text)
                if hasIcon then
                    iconSlot:Tint("TextPrimary")
                else
                    iconSlot.Frame:Destroy()
                end
            end
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0, 0, 1, 0)
            lbl.AutomaticSize = Enum.AutomaticSize.X
            lbl.LayoutOrder = hasIcon and 2 or 1
            lbl.BackgroundTransparency = 1
            lbl.Text = text
            lbl.Font = Enum.Font.GothamMedium
            lbl.TextSize = 10.5
            bindColor(lbl, "TextColor3", "TextPrimary")
            lbl.ZIndex = 153
            lbl.Parent = btn
            btn.MouseEnter:Connect(function() tweenColors(stroke, TWEEN_FAST, {Color = "BorderActive"}):Play() end)
            btn.MouseLeave:Connect(function() tweenColors(stroke, TWEEN_FAST, {Color = "Border"}):Play() end)
            return btn
        end

        local headerIdx = 0
        for _, def in ipairs(dOpts.HeaderButtons or {}) do
            headerIdx = headerIdx + 1
            local btn = smallPill(headerRight, def, headerIdx)
            btn.MouseButton1Click:Connect(function()
                if type(def) == "table" and def.Callback then task.spawn(def.Callback, handle) end
                if type(def) == "table" and def.Close then handle.Close() end
            end)
        end

        local closeBtn = Instance.new("ImageButton")
        closeBtn.Size = UDim2.new(0, 22, 0, 22)
        closeBtn.LayoutOrder = headerIdx + 1
        bindColor(closeBtn, "BackgroundColor3", "BadgeBg")
        closeBtn.BorderSizePixel = 0
        closeBtn.AutoButtonColor = false
        closeBtn.Image = ""
        closeBtn.ZIndex = 152
        closeBtn.Parent = headerRight
        addCorner(closeBtn, 6)
        addStroke(closeBtn, 1)
        local closeIcon = Instance.new("ImageLabel")
        closeIcon.Size = UDim2.new(0, 11, 0, 11)
        closeIcon.Position = UDim2.new(0.5, -5.5, 0.5, -5.5)
        closeIcon.BackgroundTransparency = 1
        closeIcon.Image = resolveIcon("x")
        tintIcon(closeIcon, "x", "TextMuted")
        closeIcon.ZIndex = 153
        closeIcon.Parent = closeBtn
        closeBtn.MouseEnter:Connect(function() tweenColors(closeIcon, TWEEN_FAST, {ImageColor3 = "Accent"}):Play() end)
        closeBtn.MouseLeave:Connect(function() tweenColors(closeIcon, TWEEN_FAST, {ImageColor3 = "TextMuted"}):Play() end)

        if dOpts.Author or dOpts.Verified or dOpts.Published then
            local meta = Instance.new("Frame")
            meta.Name = "AuthorMeta"
            meta.Size = UDim2.new(1, 0, 0, 18)
            meta.BackgroundTransparency = 1
            meta.LayoutOrder = nextOrder()
            meta.ZIndex = 151
            meta.Parent = box
            local metaLayout = Instance.new("UIListLayout")
            metaLayout.FillDirection = Enum.FillDirection.Horizontal
            metaLayout.SortOrder = Enum.SortOrder.LayoutOrder
            metaLayout.VerticalAlignment = Enum.VerticalAlignment.Center
            metaLayout.Padding = UDim.new(0, 6)
            metaLayout.Parent = meta
            if dOpts.Author then
                local userIcon = Instance.new("ImageLabel")
                userIcon.Size = UDim2.new(0, 12, 0, 12)
                userIcon.LayoutOrder = 1
                userIcon.BackgroundTransparency = 1
                userIcon.Image = resolveIcon("user")
                tintIcon(userIcon, "user", "TextMuted")
                userIcon.ZIndex = 152
                userIcon.Parent = meta
                local author = Instance.new("TextLabel")
                author.Size = UDim2.new(0, 0, 1, 0)
                author.AutomaticSize = Enum.AutomaticSize.X
                author.LayoutOrder = 2
                author.BackgroundTransparency = 1
                author.Text = tostring(dOpts.Author)
                author.Font = Enum.Font.GothamMedium
                author.TextSize = 10.5
                bindColor(author, "TextColor3", "TextPrimary")
                author.ZIndex = 152
                author.Parent = meta
            end
            if dOpts.Verified then
                local verified = Instance.new("Frame")
                verified.Size = UDim2.new(0, 0, 0, 16)
                verified.AutomaticSize = Enum.AutomaticSize.X
                verified.LayoutOrder = 3
                bindColor(verified, "BackgroundColor3", "SidebarActive")
                verified.BorderSizePixel = 0
                verified.ZIndex = 152
                verified.Parent = meta
                addCorner(verified, 5)
                local vp = Instance.new("UIPadding")
                vp.PaddingLeft = UDim.new(0, 5)
                vp.PaddingRight = UDim.new(0, 5)
                vp.Parent = verified
                local vIcon = Instance.new("ImageLabel")
                vIcon.Size = UDim2.new(0, 10, 0, 10)
                vIcon.Position = UDim2.new(0, 0, 0.5, -5)
                vIcon.BackgroundTransparency = 1
                vIcon.Image = resolveIcon("circle-check")
                tintIcon(vIcon, "circle-check", "Accent")
                vIcon.ZIndex = 153
                vIcon.Parent = verified
                local vText = Instance.new("TextLabel")
                vText.Size = UDim2.new(0, 0, 1, 0)
                vText.AutomaticSize = Enum.AutomaticSize.X
                vText.Position = UDim2.new(0, 13, 0, 0)
                vText.BackgroundTransparency = 1
                vText.Text = "Verified"
                vText.Font = Enum.Font.GothamBold
                vText.TextSize = 8.5
                bindColor(vText, "TextColor3", "Accent")
                vText.ZIndex = 153
                vText.Parent = verified
            end
            if dOpts.Published then
                local published = Instance.new("TextLabel")
                published.Size = UDim2.new(0, 0, 1, 0)
                published.AutomaticSize = Enum.AutomaticSize.X
                published.LayoutOrder = 4
                published.BackgroundTransparency = 1
                published.Text = "· " .. tostring(dOpts.Published)
                published.Font = Enum.Font.Gotham
                published.TextSize = 9.5
                bindColor(published, "TextColor3", "TextMuted")
                published.TextXAlignment = Enum.TextXAlignment.Left
                published.TextTruncate = Enum.TextTruncate.AtEnd
                published.ZIndex = 152
                published.Parent = meta
            end
        end

        -- Images and optional 3D preview models -----------------------------------
        local images = {}
        if type(dOpts.Images) == "table" then
            for _, src in ipairs(dOpts.Images) do
                if src ~= nil and src ~= "" then table.insert(images, src) end
            end
        elseif dOpts.Image ~= nil and dOpts.Image ~= "" then
            images[1] = dOpts.Image
        end
        local heroDef = {
            Icon = dOpts.Icon,
            Model = dOpts.Model or dOpts.Model3D or dOpts.Instance,
            Icon3D = dOpts.Icon3D,
            Icon3DConfig = dOpts.Icon3DConfig,
            Models = dOpts.Models,
            Icons3D = dialogIcons3D,
            IconSize = dOpts.IconSize or dOpts.Icon3DSize,
        }
        local heroIcon, heroModelValue, heroConfig = buttonIconSpec(heroDef, dialogIconDefaults)
        local heroName = tostring(dOpts.ModelName or dOpts.Title or dOpts.Name or "Dialog")
        local heroModel = heroConfig and resolveModel(heroModelValue, heroName, heroConfig) or nil
        if heroModel then
            table.insert(images, 1, {Model = heroModel, Icon3D = heroConfig, Name = heroName})
        elseif #images == 0 and heroIcon then
            local isLucideIcon = type(heroIcon) == "string" and (LUCIDE[heroIcon] or CUSTOM_ICON_DATA[heroIcon])
            images[1] = isLucideIcon and {Icon = heroIcon} or heroIcon
        end

        local tagLabel, badgeLabel
        if #images > 0 or dOpts.Tag or dOpts.Badge then
            local area = Instance.new("Frame")
            local imageHeight = tonumber(dOpts.ImageHeight) or 170
            if isMobileDevice(viewport) then
                imageHeight = math.min(imageHeight, math.max(100, viewport.Y / math.max(dialogScale, 0.01) * 0.28))
            end
            area.Size = UDim2.new(1, 0, 0, imageHeight)
            bindColor(area, "BackgroundColor3", "PillBg")
            area.BorderSizePixel = 0
            area.ClipsDescendants = true
            area.LayoutOrder = nextOrder()
            area.ZIndex = 151
            area.Parent = box
            addCorner(area, 8)
            addStroke(area, 1)

            local count = math.min(#images, 4)
            local cols = (count <= 1) and 1 or 2
            local rows = (count <= 2) and 1 or 2
            for i = 1, count do
                local c = (i - 1) % cols
                local r = math.floor((i - 1) / cols)
                local src = images[i]
                local previewDef = type(src) == "table" and src or (typeof(src) == "Instance" and {Model = src}) or {Icon = src}
                local iconName, modelValue, iconConfig = buttonIconSpec(previewDef, dialogIconDefaults)
                local previewName = tostring(previewDef.Name or previewDef.Text or heroName)
                local imageSource = previewDef.Image or previewDef.image or previewDef.Thumbnail or previewDef.thumbnail
                    or previewDef.Url or previewDef.URL or previewDef.Source
                if imageSource == nil and type(previewDef.Icon) == "string" and isDialogImageSource(previewDef.Icon) then
                    imageSource = previewDef.Icon
                end
                if imageSource == nil and type(src) ~= "table" and isDialogImageSource(src) then imageSource = src end
                local size, position
                if dOpts.Fit then
                    size = UDim2.new(1 / cols, -24, 1 / rows, -24)
                    position = UDim2.new(c / cols, 12, r / rows, 12)
                else
                    size = UDim2.new(1 / cols, (cols > 1) and -1 or 0, 1 / rows, (rows > 1) and -1 or 0)
                    position = UDim2.new(c / cols, (c > 0) and 1 or 0, r / rows, (r > 0) and 1 or 0)
                end
                local hasModelPreview = false
                if iconConfig and (modelValue ~= nil or iconConfig.Models ~= nil) then
                    local slot = Instance.new("Frame")
                    slot.Name = "Preview3D"
                    slot.Size = size
                    slot.Position = position
                    slot.BackgroundTransparency = 1
                    slot.ClipsDescendants = true
                    slot.ZIndex = 152
                    slot.Parent = area
                    if createModelViewport(slot, modelValue, previewName, iconConfig, 153) then
                        hasModelPreview = true
                    else
                        slot:Destroy()
                    end
                end
                if not hasModelPreview and imageSource == nil and type(src) == "string"
                    and not (LUCIDE[src] or CUSTOM_ICON_DATA[src]) then
                    imageSource = src
                end
                if not hasModelPreview and imageSource ~= nil then
                    local img = Instance.new("ImageLabel")
                    img.BackgroundTransparency = 1
                    img.Size = size
                    img.Position = position
                    img.ScaleType = dOpts.Fit and Enum.ScaleType.Fit or Enum.ScaleType.Crop
                    img.ZIndex = 152
                    img.Parent = area
                    local loader = previewDef.ImageLoader or dOpts.ImageLoader
                    if loader or (type(imageSource) == "string" and string.match(imageSource, "^https?://")) then
                        task.spawn(function()
                            local asset
                            if type(loader) == "function" then
                                local ok, res = pcall(loader, imageSource, dOpts.Data, previewDef)
                                asset = (ok and type(res) == "string") and res or nil
                            end
                            if not asset then asset = resolveBrowseImage(imageSource) end
                            if img.Parent and asset then img.Image = asset end
                        end)
                    else
                        img.Image = resolveBrowseImage(imageSource)
                    end
                elseif not hasModelPreview and iconName and not isDialogImageSource(iconName) then
                    local img = Instance.new("ImageLabel")
                    img.AnchorPoint = Vector2.new(0.5, 0.5)
                    img.Size = UDim2.new(0, 24, 0, 24)
                    img.Position = UDim2.new(c / cols + 0.5 / cols, 0, r / rows + 0.5 / rows, 0)
                    img.BackgroundTransparency = 1
                    img.Image = resolveIcon(iconName)
                    tintIcon(img, iconName, previewDef.Color or "TextMuted")
                    img.ZIndex = 152
                    img.Parent = area
                end
            end

            local function overlayPill(anchorX, text, colorKey, iconDef)
                local pill = Instance.new("Frame")
                pill.Size = UDim2.new(0, 0, 0, 20)
                pill.AutomaticSize = Enum.AutomaticSize.X
                pill.AnchorPoint = Vector2.new(anchorX, 0)
                pill.Position = UDim2.new(anchorX, anchorX > 0 and -8 or 8, 0, 8)
                bindColor(pill, "BackgroundColor3", "Background")
                pill.BackgroundTransparency = 0.2
                pill.BorderSizePixel = 0
                pill.ZIndex = 153
                pill.Visible = text ~= nil and text ~= ""
                pill.Parent = area
                addCorner(pill, 5)
                local p = Instance.new("UIPadding")
                p.PaddingLeft = UDim.new(0, 7)
                p.PaddingRight = UDim.new(0, 7)
                p.Parent = pill
                local content = Instance.new("UIListLayout")
                content.FillDirection = Enum.FillDirection.Horizontal
                content.SortOrder = Enum.SortOrder.LayoutOrder
                content.VerticalAlignment = Enum.VerticalAlignment.Center
                content.Padding = UDim.new(0, 4)
                content.Parent = pill
                local hasIcon = false
                if iconDef ~= nil then
                    local iconOptions = type(iconDef) == "table" and iconDef or {Icon = iconDef}
                    local iconName, iconModel, iconConfig = buttonIconSpec(iconOptions, dialogIconDefaults)
                    local iconSize = iconConfig and math.clamp(iconConfig.Size, 12, 16) or 12
                    local iconSlot = createIconSlot(pill, iconSize, iconConfig, 154, 0)
                    iconSlot.Frame.LayoutOrder = 1
                    hasIcon = iconSlot:Set(iconName, iconModel, tostring(text or ""))
                    if hasIcon then
                        iconSlot:Tint(colorKey)
                    else
                        iconSlot.Frame:Destroy()
                    end
                end
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(0, 0, 1, 0)
                lbl.AutomaticSize = Enum.AutomaticSize.X
                lbl.LayoutOrder = hasIcon and 2 or 1
                lbl.BackgroundTransparency = 1
                lbl.Text = text or ""
                lbl.RichText = true
                lbl.Font = Enum.Font.GothamBold
                lbl.TextSize = 11.5
                bindColor(lbl, "TextColor3", colorKey)
                lbl.ZIndex = 154
                lbl.Parent = pill
                return lbl, pill
            end
            tagLabel = overlayPill(0, dOpts.Tag and tostring(dOpts.Tag) or nil, "Accent", dOpts.TagIcon)
            badgeLabel = overlayPill(1, dOpts.Badge and tostring(dOpts.Badge) or nil, "TextPrimary", dOpts.BadgeIcon)
        end

        -- Lines -------------------------------------------------------------------
        local linesHolder = Instance.new("Frame")
        linesHolder.Size = UDim2.new(1, 0, 0, 0)
        linesHolder.AutomaticSize = Enum.AutomaticSize.Y
        linesHolder.BackgroundTransparency = 1
        linesHolder.LayoutOrder = nextOrder()
        linesHolder.ZIndex = 151
        linesHolder.Parent = box
        local linesLayout = Instance.new("UIListLayout")
        linesLayout.SortOrder = Enum.SortOrder.LayoutOrder
        linesLayout.Padding = UDim.new(0, 3)
        linesLayout.Parent = linesHolder

        local function setLines(lines)
            for _, child in ipairs(linesHolder:GetChildren()) do
                if child:IsA("Frame") then child:Destroy() end
            end
            if type(lines) == "string" then lines = {lines} end
            for i, def in ipairs(lines or {}) do
                local text = dialogTextOf(def)
                local colorKey = type(def) == "table" and def.Color or "TextMuted"
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, 16)
                row.BackgroundTransparency = 1
                row.LayoutOrder = i
                row.ZIndex = 151
                row.Parent = linesHolder
                local inset = 0
                local iconDef = type(def) == "table" and def or {}
                local iconName, iconModel, iconConfig = buttonIconSpec(iconDef, dialogIconDefaults)
                local iconSize = iconConfig and math.clamp(iconConfig.Size, 12, 16) or 12
                if iconName or iconModel or iconConfig then
                    local iconSlot = createIconSlot(row, iconSize, iconConfig, 152, 0)
                    if iconSlot:Set(iconName, iconModel, text) then
                        iconSlot:Tint(colorKey)
                        inset = iconSize + 5
                    end
                end
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1, -inset, 1, 0)
                lbl.Position = UDim2.new(0, inset, 0, 0)
                lbl.BackgroundTransparency = 1
                lbl.Text = text
                lbl.RichText = true
                lbl.Font = Enum.Font.Gotham
                lbl.TextSize = 10.5
                bindColor(lbl, "TextColor3", colorKey)
                lbl.TextXAlignment = Enum.TextXAlignment.Left
                lbl.TextTruncate = Enum.TextTruncate.AtEnd
                lbl.ZIndex = 152
                lbl.Parent = row
            end
            linesHolder.Visible = #(lines or {}) > 0
        end
        setLines(dOpts.Lines or dOpts.Info or dOpts.Content)

        local elementsHolder = Instance.new("Frame")
        elementsHolder.Name = "Elements"
        elementsHolder.Size = UDim2.new(1, 0, 0, 0)
        elementsHolder.AutomaticSize = Enum.AutomaticSize.Y
        elementsHolder.BackgroundTransparency = 1
        elementsHolder.LayoutOrder = nextOrder()
        elementsHolder.ZIndex = 151
        elementsHolder.Parent = box
        local elementsLayout = Instance.new("UIListLayout")
        elementsLayout.SortOrder = Enum.SortOrder.LayoutOrder
        elementsLayout.Padding = UDim.new(0, 6)
        elementsLayout.Parent = elementsHolder

        -- Buttons -----------------------------------------------------------------
        local buttonHandles = {}

        local function makeButton(parent, def, widthScale, widthOffset, orderIdx)
            local style = (def.Primary and "primary") or (def.Accent and "accent") or (def.Style and string.lower(tostring(def.Style))) or "default"
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(widthScale, widthOffset, 0, DIALOG_BTN_H)
            btn.LayoutOrder = orderIdx
            btn.BorderSizePixel = 0
            btn.Text = ""
            btn.AutoButtonColor = false
            btn.ZIndex = 152
            btn.Parent = parent
            addCorner(btn, 8)
            local stroke = addStroke(btn, 1)
            local textKey, bgKey, hoverBg
            if style == "primary" then
                bgKey, textKey, hoverBg = "Accent", "KnobOn", "AccentSoft"
                stroke.Transparency = 1
            elseif style == "accent" then
                bgKey, textKey, hoverBg = "BadgeBg", "Accent", "SidebarActive"
            else
                bgKey, textKey, hoverBg = "BadgeBg", "TextPrimary", "SidebarActive"
            end
            bindColor(btn, "BackgroundColor3", bgKey)

            local iconName, iconModel, iconConfig = buttonIconSpec(def, dialogIconDefaults)
            local iconSlotSize = iconConfig and math.clamp(iconConfig.Size, 18, 24) or 16
            local iconSlot = createIconSlot(btn, iconSlotSize, iconConfig, 153)
            local hasIcon = iconSlot:Set(iconName, iconModel, dialogTextOf(def))
            if hasIcon then iconSlot:Tint(textKey) end

            local inner = Instance.new("Frame")
            inner.BackgroundTransparency = 1
            inner.ZIndex = 153
            inner.Parent = btn
            if hasIcon then
                inner.Size = UDim2.new(1, -(iconSlotSize + 22), 1, 0)
                inner.Position = UDim2.new(0, iconSlotSize + 14, 0, 0)
            else
                inner.Size = UDim2.new(0, 0, 1, 0)
                inner.AutomaticSize = Enum.AutomaticSize.X
                inner.AnchorPoint = Vector2.new(0.5, 0)
                inner.Position = UDim2.new(0.5, 0, 0, 0)
            end
            local lbl = Instance.new("TextLabel")
            lbl.Size = hasIcon and UDim2.new(1, 0, 1, 0) or UDim2.new(0, 0, 1, 0)
            lbl.AutomaticSize = hasIcon and Enum.AutomaticSize.None or Enum.AutomaticSize.X
            lbl.BackgroundTransparency = 1
            lbl.Text = dialogTextOf(def)
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 11.5
            lbl.TextXAlignment = hasIcon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
            lbl.TextTruncate = Enum.TextTruncate.AtEnd
            bindColor(lbl, "TextColor3", textKey)
            lbl.ZIndex = 154
            lbl.Parent = inner

            btn.MouseEnter:Connect(function()
                tweenColors(btn, TWEEN_FAST, {BackgroundColor3 = hoverBg}):Play()
                if style ~= "primary" then tweenColors(stroke, TWEEN_FAST, {Color = "BorderActive"}):Play() end
            end)
            btn.MouseLeave:Connect(function()
                tweenColors(btn, TWEEN_FAST, {BackgroundColor3 = bgKey}):Play()
                if style ~= "primary" then tweenColors(stroke, TWEEN_FAST, {Color = "Border"}):Play() end
            end)
            local function fire()
                if def.Callback then task.spawn(def.Callback, handle) end
                if def.Close then handle.Close() end
            end
            btn.MouseButton1Click:Connect(fire)
            local h = {
                Button = btn,
                Fire = fire,
                SetText = function(t) lbl.Text = tostring(t) end,
                SetEnabled = function(on)
                    btn.Active = on ~= false
                    btn.BackgroundTransparency = (on == false) and 0.5 or 0
                    lbl.TextTransparency = (on == false) and 0.5 or 0
                end,
            }
            wrapHandle(h)
            if def.Id or def.Flag then buttonHandles[def.Id or def.Flag] = h end
            table.insert(buttonHandles, h)
            return btn, h
        end

        local elementOrders = {}
        local function nextElementOrder(parent)
            elementOrders[parent] = (elementOrders[parent] or 0) + 1
            return elementOrders[parent]
        end

        local function listOf(value)
            if value == nil then return {} end
            if type(value) ~= "table" then return {value} end
            if value[1] ~= nil then return value end
            return {value}
        end

        local renderElement
        local function renderStats(parent, rawStats)
            local stats = listOf(rawStats)
            if #stats == 0 then return nil end
            local shown = math.min(#stats, 3)
            local row = Instance.new("Frame")
            row.Name = "Stats"
            row.Size = UDim2.new(1, 0, 0, 42)
            row.LayoutOrder = nextElementOrder(parent)
            row.BackgroundTransparency = 1
            row.ZIndex = 152
            row.Parent = parent
            local layout = Instance.new("UIListLayout")
            layout.FillDirection = Enum.FillDirection.Horizontal
            layout.SortOrder = Enum.SortOrder.LayoutOrder
            layout.Padding = UDim.new(0, 6)
            layout.Parent = row
            for i = 1, shown do
                local raw = stats[i]
                local def = type(raw) == "table" and raw or {Value = raw, Label = ""}
                local card = Instance.new("Frame")
                card.Size = UDim2.new(1 / shown, -(6 * (shown - 1)) / shown, 1, 0)
                card.LayoutOrder = i
                bindColor(card, "BackgroundColor3", "BadgeBg")
                card.BorderSizePixel = 0
                card.ZIndex = 152
                card.Parent = row
                addCorner(card, 7)
                addStroke(card, 1)
                local iconName, iconModel, iconConfig = buttonIconSpec(def, dialogIconDefaults)
                local iconSize = iconConfig and math.clamp(iconConfig.Size, 13, 18) or 13
                local inset = 8
                if iconName or iconModel or iconConfig then
                    local iconSlot = createIconSlot(card, iconSize, iconConfig, 153, 8)
                    if iconSlot:Set(iconName, iconModel, tostring(def.Label or def.Name or "")) then
                        iconSlot:Tint(def.Color or "Accent")
                        inset = iconSize + 11
                    end
                end
                local valueLabel = Instance.new("TextLabel")
                valueLabel.Size = UDim2.new(1, -inset - 4, 0, 17)
                valueLabel.Position = UDim2.new(0, inset, 0, 4)
                valueLabel.BackgroundTransparency = 1
                valueLabel.Text = tostring(def.Value ~= nil and def.Value or "—")
                valueLabel.Font = Enum.Font.GothamBold
                valueLabel.TextSize = 12.5
                valueLabel.TextXAlignment = Enum.TextXAlignment.Left
                valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
                bindColor(valueLabel, "TextColor3", def.Color or "TextPrimary")
                valueLabel.ZIndex = 153
                valueLabel.Parent = card
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, -inset - 4, 0, 12)
                label.Position = UDim2.new(0, inset, 0, 23)
                label.BackgroundTransparency = 1
                label.Text = tostring(def.Label or def.Name or "")
                label.Font = Enum.Font.Gotham
                label.TextSize = 9.5
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.TextTruncate = Enum.TextTruncate.AtEnd
                bindColor(label, "TextColor3", "TextMuted")
                label.ZIndex = 153
                label.Parent = card
            end
            return row
        end

        local function renderProgress(parent, rawDef)
            local def = type(rawDef) == "table" and rawDef or {Value = rawDef}
            local value = tonumber(def.Value or def.Percent or def.Progress) or 0
            if value > 1 then value = value / 100 end
            value = math.clamp(value, 0, 1)
            local frame = Instance.new("Frame")
            frame.Name = "Progress"
            frame.Size = UDim2.new(1, 0, 0, 38)
            frame.LayoutOrder = nextElementOrder(parent)
            frame.BackgroundTransparency = 1
            frame.ZIndex = 152
            frame.Parent = parent
            local titleText = tostring(def.Label or def.Title or "Buildability")
            local iconName, iconModel, iconConfig = buttonIconSpec(def, dialogIconDefaults)
            local iconSize = iconConfig and math.clamp(iconConfig.Size, 12, 16) or 12
            local hasIcon = false
            if iconName or iconModel or iconConfig then
                local iconSlot = createIconSlot(frame, iconSize, iconConfig, 153, 0)
                hasIcon = iconSlot:Set(iconName, iconModel, titleText)
                if hasIcon then iconSlot:Tint(def.Color or "TextMuted") end
            end
            local title = Instance.new("TextLabel")
            title.Size = UDim2.new(1, -(46 + (hasIcon and iconSize + 5 or 0)), 0, 15)
            title.Position = UDim2.new(0, hasIcon and iconSize + 5 or 0, 0, 0)
            title.BackgroundTransparency = 1
            title.Text = titleText
            title.Font = Enum.Font.GothamMedium
            title.TextSize = 10
            title.TextXAlignment = Enum.TextXAlignment.Left
            bindColor(title, "TextColor3", "TextPrimary")
            title.ZIndex = 153
            title.Parent = frame
            local percent = Instance.new("TextLabel")
            percent.Size = UDim2.new(0, 44, 0, 15)
            percent.Position = UDim2.new(1, -44, 0, 0)
            percent.BackgroundTransparency = 1
            percent.Text = string.format("%d%%", math.floor(value * 100 + 0.5))
            percent.Font = Enum.Font.GothamBold
            percent.TextSize = 10
            percent.TextXAlignment = Enum.TextXAlignment.Right
            bindColor(percent, "TextColor3", "Accent")
            percent.ZIndex = 153
            percent.Parent = frame
            local track = Instance.new("Frame")
            track.Size = UDim2.new(1, 0, 0, 7)
            track.Position = UDim2.new(0, 0, 0, 22)
            bindColor(track, "BackgroundColor3", "BadgeBg")
            track.BorderSizePixel = 0
            track.ZIndex = 153
            track.Parent = frame
            addCorner(track, 5)
            local fill = Instance.new("Frame")
            fill.Size = UDim2.new(value, 0, 1, 0)
            bindColor(fill, "BackgroundColor3", def.Color or "Accent")
            fill.BorderSizePixel = 0
            fill.ZIndex = 154
            fill.Parent = track
            addCorner(fill, 5)
            if def.Detail then
                local detail = Instance.new("TextLabel")
                detail.Size = UDim2.new(1, 0, 0, 11)
                detail.Position = UDim2.new(0, 0, 0, 29)
                detail.BackgroundTransparency = 1
                detail.Text = tostring(def.Detail)
                detail.Font = Enum.Font.Gotham
                detail.TextSize = 8
                bindColor(detail, "TextColor3", "TextMuted")
                detail.TextXAlignment = Enum.TextXAlignment.Left
                detail.ZIndex = 153
                detail.Parent = frame
                frame.Size = UDim2.new(1, 0, 0, 42)
            end
            return frame
        end

        local function renderBlocks(parent, rawBlocks)
            local blocks = rawBlocks
            local title, list, explicitCount
            if type(blocks) == "table" and blocks.Items then
                title = blocks.Label or blocks.Title
                list = blocks.Items
                explicitCount = tonumber(blocks.Count or blocks.Total)
            elseif type(blocks) == "table" and blocks.Blocks then
                title = blocks.Label or blocks.Title
                list = blocks.Blocks
                explicitCount = tonumber(blocks.Count or blocks.Total)
            elseif type(blocks) == "table" then
                if blocks.Name or blocks.name or blocks.Type or blocks.type or blocks.Id or blocks.id then
                    list = {blocks}
                else
                    list = blocks
                end
            else
                title = "Blocks"
                list = nil
            end
            if type(list) ~= "table" then list = nil end
            local blockIcons3D
            if type(blocks) == "table" then blockIcons3D = blocks.Icons3D end
            if blockIcons3D == nil then blockIcons3D = dialogIcons3D end
            local blockIconDefaults = {
                Icons3D = blockIcons3D,
                Icon3D = (type(blocks) == "table" and (blocks.Icon3D or blocks.Icon3DConfig)) or dOpts.BlockIcon3D or dialogIconDefaults.Icon3D,
                IconSize = (type(blocks) == "table" and blocks.IconSize) or dOpts.BlockIconSize or dialogIconDefaults.IconSize or 16,
                Models = (type(blocks) == "table" and blocks.Models) or dOpts.BlockModels or dialogIconDefaults.Models,
            }
            local count = explicitCount or (type(list) == "table" and #list or tonumber(blocks))
            local heading = tostring(title or "Blocks") .. (count and (" · " .. dialogCompactCount(count)) or "")
            local section = Instance.new("Frame")
            section.Name = "Blocks"
            section.Size = UDim2.new(1, 0, 0, 0)
            section.AutomaticSize = Enum.AutomaticSize.Y
            section.LayoutOrder = nextElementOrder(parent)
            section.BackgroundTransparency = 1
            section.ZIndex = 152
            section.Parent = parent
            local layout = Instance.new("UIListLayout")
            layout.SortOrder = Enum.SortOrder.LayoutOrder
            layout.Padding = UDim.new(0, 3)
            layout.Parent = section
            local headingLabel = Instance.new("TextLabel")
            headingLabel.Size = UDim2.new(1, 0, 0, 14)
            headingLabel.LayoutOrder = 1
            headingLabel.BackgroundTransparency = 1
            headingLabel.Text = heading
            headingLabel.Font = Enum.Font.GothamBold
            headingLabel.TextSize = 9.5
            headingLabel.TextXAlignment = Enum.TextXAlignment.Left
            bindColor(headingLabel, "TextColor3", "TextMuted")
            headingLabel.ZIndex = 153
            headingLabel.Parent = section
            for i, raw in ipairs(list or {}) do
                if i > 8 then
                    local more = Instance.new("TextLabel")
                    more.Size = UDim2.new(1, 0, 0, 13)
                    more.LayoutOrder = i + 1
                    more.BackgroundTransparency = 1
                    more.Text = "and " .. tostring(#list - 8) .. " more..."
                    more.Font = Enum.Font.Gotham
                    more.TextSize = 8.5
                    more.TextXAlignment = Enum.TextXAlignment.Left
                    bindColor(more, "TextColor3", "TextDim")
                    more.ZIndex = 153
                    more.Parent = section
                    break
                end
                local block
                if typeof(raw) == "Instance" then
                    block = {Name = raw.Name, Model = raw}
                elseif type(raw) == "table" then
                    block = raw
                else
                    block = {Name = tostring(raw)}
                end
                local name = tostring(block.Name or block.name or block.Type or block.type or block.Id or block.id or raw)
                local amount = tonumber(block.Count or block.count or block.Amount or block.amount or block.Quantity or block.quantity)
                local itemIconDefaults = {
                    Icons3D = blockIconDefaults.Icons3D,
                    Icon3D = block.Icon3D or block.Viewport or blockIconDefaults.Icon3D,
                    IconSize = block.IconSize or blockIconDefaults.IconSize,
                    Models = block.Models or blockIconDefaults.Models,
                }
                local iconSpec = {
                    Icon = block.Icon or block.icon or block.IconName or block.icon_name,
                    Model = block.Model or block.Model3D or block.model or block.model3d or block.Instance,
                    Icon3D = block.Icon3D or block.icon3d,
                    Icon3DConfig = block.Icon3DConfig or block.ModelConfig,
                    Viewport = block.Viewport,
                    IconSize = block.IconSize or block.iconSize,
                    Models = block.Models or block.models,
                }
                if block.Icons3D ~= nil then iconSpec.Icons3D = block.Icons3D end
                local iconName, modelValue, iconConfig = buttonIconSpec(iconSpec, itemIconDefaults)
                if modelValue == nil and type(iconName) == "string" and blockIconDefaults.Models
                    and not (LUCIDE[iconName] or CUSTOM_ICON_DATA[iconName]) and not isDialogImageSource(iconName) then
                    modelValue = iconName
                end
                local imageSource = block.Image or block.image or block.Thumbnail or block.thumbnail or block.Texture or block.texture
                if imageSource == nil and isDialogImageSource(iconName) then
                    imageSource, iconName = iconName, nil
                end
                local line = Instance.new("Frame")
                line.Size = UDim2.new(1, 0, 0, 18)
                line.LayoutOrder = i + 1
                line.BackgroundTransparency = 1
                line.ZIndex = 153
                line.Parent = section
                local inset = 0
                if iconName or modelValue or iconConfig then
                    local iconSize = math.clamp(tonumber(block.IconSize or blockIconDefaults.IconSize) or 16, 12, 20)
                    local iconSlot = createIconSlot(line, iconSize, iconConfig, 154, 0)
                    if iconSlot:Set(iconName, modelValue, name) then
                        iconSlot:Tint(block.Color or "TextMuted")
                        inset = iconSize + 5
                    end
                end
                if inset == 0 and imageSource ~= nil and imageSource ~= "" then
                    local icon = Instance.new("ImageLabel")
                    icon.Size = UDim2.new(0, 16, 0, 16)
                    icon.Position = UDim2.new(0, 0, 0.5, -8)
                    icon.BackgroundTransparency = 1
                    icon.ScaleType = Enum.ScaleType.Fit
                    icon.ZIndex = 154
                    icon.Parent = line
                    local imageLoader = type(block.ImageLoader) == "function" and block.ImageLoader
                        or (type(dOpts.ImageLoader) == "function" and dOpts.ImageLoader or nil)
                    local immediate = imageLoader == nil
                        and not (type(imageSource) == "string" and string.match(imageSource, "^https?://"))
                        and resolveBrowseImage(imageSource) or nil
                    if immediate then
                        icon.Image = immediate
                    else
                        task.spawn(function()
                            local asset
                            if imageLoader then
                                local ok, result = pcall(imageLoader, imageSource, block, blocks)
                                if ok and type(result) == "string" then asset = result end
                            end
                            if not asset then asset = resolveBrowseImage(imageSource) end
                            if icon.Parent and asset then icon.Image = asset end
                        end)
                    end
                    inset = 21
                end
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, -inset, 1, 0)
                label.Position = UDim2.new(0, inset, 0, 0)
                label.BackgroundTransparency = 1
                label.Text = (inset > 0 and "" or "• ") .. name .. (amount and (" × " .. dialogCompactCount(amount)) or "")
                label.Font = Enum.Font.Gotham
                label.TextSize = 8.5
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.TextTruncate = Enum.TextTruncate.AtEnd
                bindColor(label, "TextColor3", "TextMuted")
                label.ZIndex = 154
                label.Parent = line
            end
            return section
        end

        local function renderCopyLink(parent, rawDef)
            local def = type(rawDef) == "table" and rawDef or {Url = rawDef}
            local url = tostring(def.Url or def.URL or def.Value or "")
            local frame = Instance.new("Frame")
            frame.Name = "CopyLink"
            frame.Size = UDim2.new(1, 0, 0, 46)
            frame.LayoutOrder = nextElementOrder(parent)
            frame.BackgroundTransparency = 1
            frame.ZIndex = 152
            frame.Parent = parent
            local titleRow = Instance.new("Frame")
            titleRow.Size = UDim2.new(1, 0, 0, 13)
            titleRow.BackgroundTransparency = 1
            titleRow.ZIndex = 153
            titleRow.Parent = frame
            local titleText = tostring(def.Label or def.Title or "View in 3D in your browser")
            local iconName, iconModel, iconConfig = buttonIconSpec(def, dialogIconDefaults)
            local iconSize = iconConfig and math.clamp(iconConfig.Size, 12, 16) or 12
            local inset = 0
            if iconName or iconModel or iconConfig then
                local iconSlot = createIconSlot(titleRow, iconSize, iconConfig, 154, 0)
                if iconSlot:Set(iconName, iconModel, titleText) then
                    iconSlot:Tint(def.Color or "TextMuted")
                    inset = iconSize + 5
                end
            end
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -inset, 1, 0)
            label.Position = UDim2.new(0, inset, 0, 0)
            label.BackgroundTransparency = 1
            label.Text = titleText
            label.Font = Enum.Font.GothamMedium
            label.TextSize = 9.5
            label.TextXAlignment = Enum.TextXAlignment.Left
            bindColor(label, "TextColor3", "TextMuted")
            label.ZIndex = 154
            label.Parent = titleRow
            local box = Instance.new("Frame")
            box.Size = UDim2.new(1, -64, 0, 27)
            box.Position = UDim2.new(0, 0, 0, 17)
            bindColor(box, "BackgroundColor3", "BadgeBg")
            box.BorderSizePixel = 0
            box.ZIndex = 153
            box.Parent = frame
            addCorner(box, 6)
            addStroke(box, 1)
            local urlText = Instance.new("TextBox")
            urlText.Size = UDim2.new(1, -14, 1, 0)
            urlText.Position = UDim2.new(0, 7, 0, 0)
            urlText.BackgroundTransparency = 1
            urlText.Text = url
            urlText.PlaceholderText = "Paste or copy a 3D preview link"
            urlText.ClearTextOnFocus = false
            urlText.TextEditable = false
            urlText.TextTruncate = Enum.TextTruncate.AtEnd
            urlText.Font = Enum.Font.Gotham
            urlText.TextSize = 8.5
            urlText.TextXAlignment = Enum.TextXAlignment.Left
            bindColor(urlText, "TextColor3", "TextPrimary")
            bindColor(urlText, "PlaceholderColor3", "TextDim")
            urlText.ZIndex = 154
            urlText.Parent = box
            local copy = Instance.new("TextButton")
            copy.Size = UDim2.new(0, 56, 0, 27)
            copy.Position = UDim2.new(1, -56, 0, 17)
            bindColor(copy, "BackgroundColor3", "SidebarActive")
            copy.BorderSizePixel = 0
            copy.Text = "Copy"
            copy.Font = Enum.Font.GothamBold
            copy.TextSize = 9
            bindColor(copy, "TextColor3", "Accent")
            copy.AutoButtonColor = false
            copy.ZIndex = 154
            copy.Parent = frame
            addCorner(copy, 6)
            addStroke(copy, 1)
            local originalText = copy.Text
            copy.MouseButton1Click:Connect(function()
                local copied = false
                local setter = type(setclipboard) == "function" and setclipboard or nil
                if setter then copied = pcall(setter, url) end
                if type(def.OnCopy) == "function" then
                    task.spawn(def.OnCopy, url, handle)
                    copied = true
                end
                copy.Text = copied and "Copied!" or originalText
                if copied then task.delay(1.2, function() if copy.Parent then copy.Text = originalText end end) end
            end)
            return frame
        end

        local function renderPlainLabel(parent, rawDef)
            local def = type(rawDef) == "table" and rawDef or {Text = tostring(rawDef)}
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, tonumber(def.Height) or 18)
            row.LayoutOrder = nextElementOrder(parent)
            row.BackgroundTransparency = 1
            row.ZIndex = 152
            row.Parent = parent
            local iconName, iconModel, iconConfig = buttonIconSpec(def, dialogIconDefaults)
            local iconSize = iconConfig and math.clamp(iconConfig.Size, 12, 16) or 12
            local inset = 0
            if iconName or iconModel or iconConfig then
                local iconSlot = createIconSlot(row, iconSize, iconConfig, 153, 0)
                if iconSlot:Set(iconName, iconModel, tostring(def.Text or def.Title or "")) then
                    iconSlot:Tint(def.Color or "TextMuted")
                    inset = iconSize + 5
                end
            end
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -inset, 1, 0)
            label.Position = UDim2.new(0, inset, 0, 0)
            label.BackgroundTransparency = 1
            label.Text = tostring(def.Text or def.Title or "")
            label.Font = def.Bold and Enum.Font.GothamBold or Enum.Font.Gotham
            label.TextSize = tonumber(def.TextSize) or 9.5
            label.TextWrapped = def.Wrap == true
            label.TextTruncate = def.Wrap == true and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd
            label.TextXAlignment = Enum.TextXAlignment.Left
            bindColor(label, "TextColor3", def.Color or "TextMuted")
            label.ZIndex = 153
            label.Parent = row
            return label
        end

        local function renderBlocksGrid(parent, rawDef)
            local def = type(rawDef) == "table" and rawDef or {Items = rawDef}
            local rawList = def.Items or def.Blocks
            if rawList == nil and type(rawDef) == "table" and rawDef[1] ~= nil then
                rawList = rawDef
            end
            local blocks = {}
            if type(rawList) == "table" then
                if rawList[1] ~= nil then
                    blocks = rawList
                elseif rawList.Name or rawList.name or rawList.Type or rawList.type or rawList.Id or rawList.id then
                    blocks = {rawList}
                else
                    for _, value in pairs(rawList) do table.insert(blocks, value) end
                end
            elseif rawList ~= nil then
                blocks = {rawList}
            end
            local gridIcons3D = def.Icons3D
            if gridIcons3D == nil then gridIcons3D = dialogIcons3D end
            local gridIconDefaults = {
                Icons3D = gridIcons3D,
                Icon3D = def.Icon3DConfig or def.Viewport or def.ModelConfig or dialogIconDefaults.Icon3D,
                IconSize = def.IconSize or dialogIconDefaults.IconSize or 40,
                Models = def.Models or dialogIconDefaults.Models,
            }
            if type(def.Icon3D) == "table" or type(def.Icon3D) == "number" then
                gridIconDefaults.Icon3D = def.Icon3D
            end

            local empty = #blocks == 0
            local scroll = Instance.new("ScrollingFrame")
            scroll.Name = "BlocksGrid"
            scroll.Size = UDim2.new(1, 0, 0, 0)
            scroll.LayoutOrder = nextElementOrder(parent)
            scroll.BackgroundTransparency = 1
            scroll.BorderSizePixel = 0
            scroll.ScrollBarThickness = 3
            scroll.ScrollingDirection = Enum.ScrollingDirection.Y
            scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
            scroll.Active = true
            bindColor(scroll, "ScrollBarImageColor3", "Accent")
            scroll.ZIndex = 152
            scroll.Parent = parent
            if empty then
                scroll.Size = UDim2.new(1, 0, 0, 28)
                scroll.ScrollingEnabled = false
                local emptyLabel = Instance.new("TextLabel")
                emptyLabel.Size = UDim2.new(1, 0, 1, 0)
                emptyLabel.BackgroundTransparency = 1
                emptyLabel.Text = tostring(def.EmptyText or "No block details were provided.")
                emptyLabel.Font = Enum.Font.Gotham
                emptyLabel.TextSize = 10.5
                emptyLabel.TextXAlignment = Enum.TextXAlignment.Left
                bindColor(emptyLabel, "TextColor3", "TextMuted")
                emptyLabel.ZIndex = 153
                emptyLabel.Parent = scroll
                return scroll
            end

            local viewport = getViewportSize()
            local maxHeight = math.max(120, (viewport.Y - 210) / math.max(dialogScale, 0.01))
            local scrollHeight = math.min(tonumber(def.MaxHeight or def.Height) or 320, maxHeight)
            scroll.Size = UDim2.new(1, 0, 0, math.max(120, scrollHeight))
            local padding = Instance.new("UIPadding")
            padding.PaddingLeft = UDim.new(0, 3)
            padding.PaddingRight = UDim.new(0, 3)
            padding.PaddingTop = UDim.new(0, 3)
            padding.PaddingBottom = UDim.new(0, 5)
            padding.Parent = scroll

            local gridLayout = Instance.new("UIGridLayout")
            gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
            gridLayout.CellSize = UDim2.new(0, 160, 0, 62)
            gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
            gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
            gridLayout.Parent = scroll

            local function updateGridSize()
                local width = scroll.AbsoluteSize.X / math.max(dialogScale, 0.01) - 10
                if width <= 0 then return end
                local columns = tonumber(def.Columns)
                if not columns then columns = width >= 340 and 2 or 1 end
                columns = math.clamp(math.floor(columns), 1, 3)
                local cellWidth = math.max(120, math.floor((width - 8 * (columns - 1)) / columns))
                gridLayout.CellSize = UDim2.new(0, cellWidth, 0, 62)
                scroll.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y / math.max(dialogScale, 0.01) + 8)
            end
            scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateGridSize)
            gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateGridSize)

            local function loadBlockImage(image, source, block)
                if source == nil or source == "" then return end
                local imageLoader = type(def.ImageLoader) == "function" and def.ImageLoader
                    or (type(dOpts.ImageLoader) == "function" and dOpts.ImageLoader or nil)
                local immediate = (imageLoader == nil and not (type(source) == "string" and string.match(source, "^https?://")))
                    and resolveBrowseImage(source) or nil
                if immediate then
                    image.Image = immediate
                    return
                end
                task.spawn(function()
                    local asset
                    if imageLoader then
                        local ok, result = pcall(imageLoader, source, block, def)
                        if ok and type(result) == "string" then asset = result end
                    end
                    if not asset then asset = resolveBrowseImage(source) end
                    if image.Parent and asset then image.Image = asset end
                end)
            end

            for index, raw in ipairs(blocks) do
                local block
                if typeof(raw) == "Instance" then
                    block = {Name = raw.Name, Model = raw}
                elseif type(raw) == "table" then
                    block = raw
                else
                    block = {Name = tostring(raw)}
                end
                local name = tostring(block.Name or block.name or block.Type or block.type or block.Material or block.material or block.Id or block.id or "Block " .. index)
                local amount = block.Count or block.count or block.Amount or block.amount or block.Quantity or block.quantity or block.Required or block.required
                local rawIcon = block.Icon or block.icon or block.IconName or block.icon_name
                local iconName
                local imageSource = block.Image or block.image or block.Thumbnail or block.thumbnail or block.Texture or block.texture
                local modelValue = block.Model or block.Model3D or block.model or block.model3d or block.Instance
                if typeof(rawIcon) == "Instance" then
                    modelValue = modelValue or rawIcon
                    rawIcon = nil
                elseif type(rawIcon) == "table" then
                    modelValue = modelValue or rawIcon.Model or rawIcon.Model3D or rawIcon.Instance
                    imageSource = imageSource or rawIcon.Image or rawIcon.image or rawIcon.Thumbnail or rawIcon.Url
                    iconName = rawIcon.Icon or rawIcon.Name
                elseif type(rawIcon) == "string" then
                    if LUCIDE[rawIcon] or CUSTOM_ICON_DATA[rawIcon] then
                        iconName = rawIcon
                    elseif isDialogImageSource(rawIcon) then
                        imageSource = imageSource or rawIcon
                    elseif gridIconDefaults.Models ~= nil then
                        modelValue = modelValue or rawIcon
                    end
                elseif type(rawIcon) == "number" then
                    imageSource = imageSource or rawIcon
                end
                local iconSpec = {
                    Icon = type(rawIcon) == "table" and rawIcon or iconName,
                    Model = modelValue,
                    Icon3D = block.Icon3D or block.icon3d,
                    Icon3DConfig = block.Icon3DConfig or block.icon3DConfig,
                    Viewport = block.Viewport,
                    IconSize = block.IconSize or block.iconSize,
                    Models = block.Models or block.models,
                }
                if block.Icons3D ~= nil then iconSpec.Icons3D = block.Icons3D end
                if iconSpec.Models == nil and gridIconDefaults.Models ~= nil then iconSpec.Models = gridIconDefaults.Models end
                if iconSpec.IconSize == nil then iconSpec.IconSize = gridIconDefaults.IconSize end
                local parsedIcon, parsedModel, modelConfig = buttonIconSpec(iconSpec, gridIconDefaults)
                iconName = parsedIcon
                modelValue = parsedModel or modelValue
                if imageSource == nil and isDialogImageSource(iconName) then
                    imageSource, iconName = iconName, nil
                end
                local resolvedModel = modelConfig and resolveModel(modelValue, name, modelConfig) or nil

                local card = Instance.new("Frame")
                card.Name = "BlockItem"
                card.LayoutOrder = index
                bindColor(card, "BackgroundColor3", "BadgeBg")
                card.BorderSizePixel = 0
                card.ZIndex = 153
                card.Parent = scroll
                addCorner(card, 8)
                addStroke(card, 1)

                local iconBox = Instance.new("Frame")
                iconBox.Size = UDim2.new(0, 42, 0, 42)
                iconBox.Position = UDim2.new(0, 8, 0.5, -21)
                bindColor(iconBox, "BackgroundColor3", "PillBg")
                iconBox.BorderSizePixel = 0
                iconBox.ClipsDescendants = true
                iconBox.ZIndex = 154
                iconBox.Parent = card
                addCorner(iconBox, 7)

                local hasModelPreview = resolvedModel ~= nil
                    and createModelViewport(iconBox, modelValue, name, modelConfig, 155) ~= nil
                if not hasModelPreview and imageSource ~= nil and imageSource ~= "" then
                    local image = Instance.new("ImageLabel")
                    image.Size = UDim2.new(1, -6, 1, -6)
                    image.Position = UDim2.new(0, 3, 0, 3)
                    image.BackgroundTransparency = 1
                    image.ScaleType = Enum.ScaleType.Fit
                    image.ZIndex = 155
                    image.Parent = iconBox
                    loadBlockImage(image, imageSource, block)
                elseif not hasModelPreview then
                    local fallbackIcon = iconName or "box"
                    local icon = Instance.new("ImageLabel")
                    icon.Size = UDim2.new(0, 20, 0, 20)
                    icon.Position = UDim2.new(0.5, -10, 0.5, -10)
                    icon.BackgroundTransparency = 1
                    icon.Image = resolveIcon(fallbackIcon)
                    tintIcon(icon, fallbackIcon, "TextMuted")
                    icon.ZIndex = 155
                    icon.Parent = iconBox
                end

                local nameLabel = Instance.new("TextLabel")
                nameLabel.Size = UDim2.new(1, -62, 0, 20)
                nameLabel.Position = UDim2.new(0, 58, 0, 8)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Text = name
                nameLabel.Font = Enum.Font.GothamMedium
                nameLabel.TextSize = 11.5
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
                bindColor(nameLabel, "TextColor3", "TextPrimary")
                nameLabel.ZIndex = 154
                nameLabel.Parent = card

                local quantityLabel = Instance.new("TextLabel")
                quantityLabel.Size = UDim2.new(1, -62, 0, 16)
                quantityLabel.Position = UDim2.new(0, 58, 0, 33)
                quantityLabel.BackgroundTransparency = 1
                quantityLabel.Text = amount ~= nil and ("× " .. dialogCompactCount(amount)) or "Quantity not set"
                quantityLabel.Font = Enum.Font.Gotham
                quantityLabel.TextSize = 10
                quantityLabel.TextXAlignment = Enum.TextXAlignment.Left
                quantityLabel.TextTruncate = Enum.TextTruncate.AtEnd
                bindColor(quantityLabel, "TextColor3", amount ~= nil and "Accent" or "TextMuted")
                quantityLabel.ZIndex = 154
                quantityLabel.Parent = card
            end
            task.defer(updateGridSize)
            return scroll
        end

        local function renderBlocksButton(parent, rawDef)
            if rawDef == nil or rawDef == false then return nil end
            local cfg = rawDef == true and {} or (type(rawDef) == "table" and rawDef or {Text = tostring(rawDef)})
            local blockIcons3D = cfg.Icons3D
            if blockIcons3D == nil then blockIcons3D = dialogIcons3D end
            local blockIcon3D = cfg.Icon3D or cfg.Icon3DConfig or dialogIconDefaults.Icon3D
            local blockIcon3DConfig = cfg.Icon3DConfig
            local blockIconSize = cfg.IconSize or dialogIconDefaults.IconSize
            local blockModels = cfg.Models or dialogIconDefaults.Models
            local rawBlocks = cfg.Items or cfg.Blocks or dOpts.Blocks
            local blockCount = cfg.Count or cfg.Total
            if blockCount == nil and type(rawBlocks) == "table" then
                blockCount = rawBlocks.Count or rawBlocks.Total
            end
            local buttonText = tostring(cfg.Text or cfg.Label or "View required blocks")
            local buttonDef = {
                Text = buttonText,
                Icon = cfg.Icon or "blocks",
                Model = cfg.Model or cfg.Model3D,
                Icon3D = cfg.Icon3D,
                Icon3DConfig = cfg.Icon3DConfig,
                Models = cfg.Models,
                IconSize = cfg.IconSize,
                Icons3D = cfg.Icons3D,
                Primary = cfg.Primary == true,
                Style = cfg.Style,
                Callback = function()
                    local rawItems = cfg.Items or cfg.Blocks or dOpts.Blocks
                    if type(rawItems) == "table" and (rawItems.Items or rawItems.Blocks) then
                        rawItems = rawItems.Items or rawItems.Blocks
                    end
                    local listCount = type(rawItems) == "table" and #rawItems or 0
                    local total = blockCount or cfg.Count or listCount
                    local subDialog
                    local headers = {}
                    if type(cfg.OnBack) == "function" then
                        table.insert(headers, {
                            Text = cfg.BackText or "Back",
                            Callback = function()
                                cfg.OnBack(dOpts.Data, subDialog)
                            end,
                        })
                    end
                    subDialog = createDialog({
                        Title = cfg.Title or "Required blocks",
                        Width = tonumber(cfg.DialogWidth or cfg.Width) or 560,
                        Anchor = dOpts.Anchor,
                        Icons3D = blockIcons3D,
                        Icon3D = blockIcon3D,
                        Icon3DConfig = blockIcon3DConfig,
                        IconSize = blockIconSize,
                        Models = blockModels,
                        HeaderButtons = headers,
                        Lines = cfg.Description and {{Text = tostring(cfg.Description), Icon = "info"}} or {
                            {Text = tostring(total or 0) .. " required blocks · " .. tostring(listCount) .. " block types", Icon = "blocks"},
                        },
                        BlocksGrid = {
                            Title = cfg.Title or "Required blocks",
                            Items = rawItems,
                            Count = total,
                            Columns = cfg.Columns,
                            MaxHeight = cfg.MaxHeight,
                            Models = blockModels,
                            Icon3D = blockIcon3D,
                            Icon3DConfig = blockIcon3DConfig,
                            IconSize = blockIconSize,
                            Icons3D = blockIcons3D,
                            ImageLoader = cfg.ImageLoader or dOpts.ImageLoader,
                            EmptyText = cfg.EmptyText,
                        },
                        Data = dOpts.Data,
                        CloseOnBackdrop = cfg.CloseOnBackdrop,
                    })
                    if type(cfg.Callback) == "function" then
                        task.spawn(cfg.Callback, dOpts.Data, subDialog)
                    end
                    if type(cfg.OnOpen) == "function" then
                        task.spawn(cfg.OnOpen, dOpts.Data, subDialog)
                    end
                end,
            }
            local _, buttonHandle = makeButton(parent, buttonDef, 1, 0, nextElementOrder(parent))
            return buttonHandle
        end

        local function renderHStack(parent, rawChildren, options)
            local children = listOf(rawChildren)
            if #children == 0 then return nil end
            local count = #children
            local height = tonumber(options and options.Height) or DIALOG_BTN_H
            local rowGap = tonumber(options and options.Gap) or 8
            local row = Instance.new("Frame")
            row.Name = "HStack"
            row.Size = UDim2.new(1, 0, 0, height)
            row.LayoutOrder = nextElementOrder(parent)
            row.BackgroundTransparency = 1
            row.ZIndex = 152
            row.Parent = parent
            local layout = Instance.new("UIListLayout")
            layout.FillDirection = Enum.FillDirection.Horizontal
            layout.SortOrder = Enum.SortOrder.LayoutOrder
            layout.Padding = UDim.new(0, rowGap)
            layout.VerticalAlignment = Enum.VerticalAlignment.Center
            layout.Parent = row
            local handles = {}
            for i, raw in ipairs(children) do
                local def = type(raw) == "string" and {Text = raw} or raw
                if type(def) == "table" and (string.lower(tostring(def.Type or "")) == "label" or string.lower(tostring(def.Type or "")) == "text") then
                    local cell = Instance.new("Frame")
                    cell.Size = UDim2.new(1 / count, -(rowGap * (count - 1)) / count, 1, 0)
                    cell.LayoutOrder = i
                    cell.BackgroundTransparency = 1
                    cell.ZIndex = 152
                    cell.Parent = row
                    local iconName, iconModel, iconConfig = buttonIconSpec(def, dialogIconDefaults)
                    local iconSize = iconConfig and math.clamp(iconConfig.Size, 12, 16) or 12
                    local inset = 0
                    if iconName or iconModel or iconConfig then
                        local iconSlot = createIconSlot(cell, iconSize, iconConfig, 153, 0)
                        if iconSlot:Set(iconName, iconModel, tostring(def.Text or def.Title or "")) then
                            iconSlot:Tint(def.Color or "TextMuted")
                            inset = iconSize + 5
                        end
                    end
                    local label = Instance.new("TextLabel")
                    label.Size = UDim2.new(1, -inset, 1, 0)
                    label.Position = UDim2.new(0, inset, 0, 0)
                    label.BackgroundTransparency = 1
                    label.Text = tostring(def.Text or def.Title or "")
                    label.Font = def.Bold and Enum.Font.GothamBold or Enum.Font.GothamMedium
                    label.TextSize = tonumber(def.TextSize) or 9.5
                    label.TextXAlignment = def.Align == "Right" and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
                    label.TextTruncate = Enum.TextTruncate.AtEnd
                    bindColor(label, "TextColor3", def.Color or "TextMuted")
                    label.ZIndex = 153
                    label.Parent = cell
                else
                    if type(def) ~= "table" then def = {Text = tostring(def)} end
                    local btn, buttonHandle = makeButton(row, def, 1 / count, -(rowGap * (count - 1)) / count, i)
                    handles[i] = buttonHandle
                end
            end
            return row, handles
        end

        renderElement = function(parent, rawDef)
            local def = type(rawDef) == "table" and rawDef or {Type = "Label", Text = tostring(rawDef)}
            local kind = string.lower(tostring(def.Type or def.Kind or def.Element or "Label"))
            if kind == "button" then
                local copy = {}
                for k, v in pairs(def) do copy[k] = v end
                copy.LayoutOrder = nil
                local buttonDef = copy
                local btn, buttonHandle = makeButton(parent, buttonDef, 1, 0, nextElementOrder(parent))
                return btn, buttonHandle
            elseif kind == "hstack" or kind == "row" then
                return renderHStack(parent, def.Items or def.Children or def.Buttons or {}, def)
            elseif kind == "divider" or kind == "separator" then
                local divider = Instance.new("Frame")
                divider.Name = "Divider"
                divider.Size = UDim2.new(1, 0, 0, tonumber(def.Height) or 1)
                divider.LayoutOrder = nextElementOrder(parent)
                bindColor(divider, "BackgroundColor3", def.Color or "Divider")
                divider.BorderSizePixel = 0
                divider.ZIndex = 152
                divider.Parent = parent
                return divider
            elseif kind == "progress" or kind == "progressbar" or kind == "buildability" then
                return renderProgress(parent, def)
            elseif kind == "stats" or kind == "stat" then
                return renderStats(parent, def.Items or def.Stats or def)
            elseif kind == "blocks" or kind == "list" then
                return renderBlocks(parent, def.Items or def.Blocks or def)
            elseif kind == "blocksbutton" or kind == "blockbutton" then
                return renderBlocksButton(parent, def)
            elseif kind == "blocksgrid" or kind == "blockgrid" then
                return renderBlocksGrid(parent, def)
            elseif kind == "link" or kind == "copylink" or kind == "share" then
                return renderCopyLink(parent, def)
            end
            return renderPlainLabel(parent, def)
        end

        if dOpts.Stats then renderStats(elementsHolder, dOpts.Stats) end
        if dOpts.Buildability then renderProgress(elementsHolder, dOpts.Buildability) end
        if dOpts.Blocks and not (dOpts.BlocksButton and dOpts.BlocksButton ~= false) then
            renderBlocks(elementsHolder, dOpts.Blocks)
        end
        if dOpts.BlocksButton then renderBlocksButton(elementsHolder, dOpts.BlocksButton) end
        if dOpts.BlocksGrid then renderBlocksGrid(elementsHolder, dOpts.BlocksGrid) end
        local shareLink = dOpts.ShareLink or dOpts.Share or dOpts.View3D
        if shareLink then renderCopyLink(elementsHolder, shareLink) end
        if dOpts.FooterText then
            renderPlainLabel(elementsHolder, {Text = dOpts.FooterText, Icon = dOpts.FooterIcon or "circle-check", Color = "TextMuted", Height = 16})
        end
        for _, element in ipairs(listOf(dOpts.Elements)) do renderElement(elementsHolder, element) end
        for _, stack in ipairs(listOf(dOpts.HStacks)) do
            if type(stack) == "table" and (stack.Type or stack.Items or stack.Children) then
                renderElement(elementsHolder, stack)
            else
                renderElement(elementsHolder, {Type = "HStack", Items = listOf(stack)})
            end
        end

        for _, def in ipairs(dOpts.Buttons or {}) do
            if type(def) == "table" and def[1] ~= nil then -- a row of buttons
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, 0, 0, DIALOG_BTN_H)
                row.BackgroundTransparency = 1
                row.LayoutOrder = nextOrder()
                row.ZIndex = 151
                row.Parent = box
                local rl = Instance.new("UIListLayout")
                rl.FillDirection = Enum.FillDirection.Horizontal
                rl.SortOrder = Enum.SortOrder.LayoutOrder
                rl.Padding = UDim.new(0, 8)
                rl.Parent = row
                local n = #def
                for i, sub in ipairs(def) do
                    if type(sub) == "string" then sub = {Text = sub} end
                    makeButton(row, sub, 1 / n, -(8 * (n - 1)) / n, i)
                end
            elseif def ~= nil then
                if type(def) == "string" then def = {Text = def} end
                local btn = makeButton(box, def, 1, 0, nextOrder())
                btn.LayoutOrder = order
            end
        end

        local runtimeHolder = Instance.new("Frame")
        runtimeHolder.Name = "DynamicElements"
        runtimeHolder.Size = UDim2.new(1, 0, 0, 0)
        runtimeHolder.AutomaticSize = Enum.AutomaticSize.Y
        runtimeHolder.BackgroundTransparency = 1
        runtimeHolder.LayoutOrder = nextOrder()
        runtimeHolder.ZIndex = 151
        runtimeHolder.Parent = box
        local runtimeLayout = Instance.new("UIListLayout")
        runtimeLayout.SortOrder = Enum.SortOrder.LayoutOrder
        runtimeLayout.Padding = UDim.new(0, 6)
        runtimeLayout.Parent = runtimeHolder

        function handle.AddElement(def)
            return renderElement(runtimeHolder, def)
        end
        function handle.AddButton(def)
            if type(def) == "string" then
                def = {Type = "Button", Text = def}
            elseif type(def) ~= "table" then
                def = {Type = "Button", Text = tostring(def)}
            else
                local copy = {}
                for key, value in pairs(def) do copy[key] = value end
                def = copy
            end
            if def.Type == nil then def.Type = "Button" end
            local _, buttonHandle = renderElement(runtimeHolder, def)
            return buttonHandle
        end
        function handle.AddHStack(items, options)
            return renderHStack(runtimeHolder, items, options)
        end
        function handle.AddLabel(text, options)
            local source = type(text) == "table" and text or options
            local def = {}
            if type(source) == "table" then
                for key, value in pairs(source) do def[key] = value end
            end
            if type(text) ~= "table" then def.Text = tostring(text or "") end
            return renderPlainLabel(runtimeHolder, def)
        end
        function handle.AddDivider(options)
            local def = {}
            if type(options) == "table" then
                for key, value in pairs(options) do def[key] = value end
            end
            def.Type = "Divider"
            return renderElement(runtimeHolder, def)
        end
        function handle.AddProgressBar(def)
            return renderProgress(runtimeHolder, def)
        end
        function handle.AddStats(stats)
            return renderStats(runtimeHolder, stats)
        end
        function handle.AddBlocks(blocks)
            return renderBlocks(runtimeHolder, blocks)
        end
        function handle.AddBlocksGrid(blocks)
            return renderBlocksGrid(runtimeHolder, blocks)
        end
        function handle.AddBlocksButton(def)
            return renderBlocksButton(runtimeHolder, def)
        end
        function handle.AddCopyLink(link)
            return renderCopyLink(runtimeHolder, link)
        end
        handle.AddText = handle.AddLabel
        handle.AddSeparator = handle.AddDivider
        handle.HStack = handle.AddHStack

        -- Resizable dialogs keep their header visible and scroll the body when
        -- the user makes the modal shorter than its content.
        local dialogBody, dialogBodyContent, dialogBodyLayout
        local dialogChromeHeight = 0
        local dialogHasFixedSize = false
        local resizeGripHost, resizeGrip
        local function updateDialogBodyCanvas()
            if not dialogBody or not dialogBodyContent then return end
            local contentHeight = dialogBodyContent.AbsoluteSize.Y / math.max(dialogScale, 0.01)
            dialogBody.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
        end
        local function setDialogFixedSize(widthValue, heightValue)
            if not resizable or not dialogBody then return end
            if not dialogHasFixedSize then
                local totalHeight = box.AbsoluteSize.Y / math.max(dialogScale, 0.01)
                local bodyHeight = dialogBody.AbsoluteSize.Y / math.max(dialogScale, 0.01)
                dialogChromeHeight = totalHeight - bodyHeight
                if bodyHeight <= 0 or dialogChromeHeight < 1 then dialogChromeHeight = 54 end
                dialogHasFixedSize = true
            end
            box.AutomaticSize = Enum.AutomaticSize.None
            dialogBody.AutomaticSize = Enum.AutomaticSize.None
            box.Size = UDim2.new(0, widthValue, 0, heightValue)
            dialogBody.Size = UDim2.new(1, 0, 0, math.max(0, heightValue - dialogChromeHeight))
            task.defer(updateDialogBodyCanvas)
        end
        local capCheckPending = false
        local function scheduleAutoHeightCap()
            if not resizable or dialogHasFixedSize or capCheckPending or closed then return end
            capCheckPending = true
            task.defer(function()
                task.wait()
                capCheckPending = false
                if closed or dialogHasFixedSize or not box.Parent then return end
                local naturalHeight = box.AbsoluteSize.Y / math.max(dialogScale, 0.01)
                if naturalHeight > maxHeight then
                    local naturalWidth = box.AbsoluteSize.X / math.max(dialogScale, 0.01)
                    setDialogFixedSize(naturalWidth, maxHeight)
                end
            end)
        end

        if resizable then
            dialogBody = Instance.new("ScrollingFrame")
            dialogBody.Name = "DialogBody"
            dialogBody.Size = UDim2.new(1, 0, 0, 0)
            dialogBody.AutomaticSize = Enum.AutomaticSize.Y
            dialogBody.BackgroundTransparency = 1
            dialogBody.BorderSizePixel = 0
            dialogBody.LayoutOrder = 2
            dialogBody.Active = true
            dialogBody.ClipsDescendants = true
            dialogBody.ScrollingEnabled = true
            dialogBody.ScrollingDirection = Enum.ScrollingDirection.Y
            dialogBody.ScrollBarThickness = mobileDialog and 4 or 3
            dialogBody.AutomaticCanvasSize = Enum.AutomaticSize.None
            dialogBody.CanvasSize = UDim2.new(0, 0, 0, 0)
            bindColor(dialogBody, "ScrollBarImageColor3", "Accent")
            dialogBody.ZIndex = 151
            dialogBody.Parent = box

            dialogBodyContent = Instance.new("Frame")
            dialogBodyContent.Name = "DialogBodyContent"
            dialogBodyContent.Size = UDim2.new(1, 0, 0, 0)
            dialogBodyContent.AutomaticSize = Enum.AutomaticSize.Y
            dialogBodyContent.BackgroundTransparency = 1
            dialogBodyContent.ZIndex = 151
            dialogBodyContent.Parent = dialogBody
            dialogBodyLayout = Instance.new("UIListLayout")
            dialogBodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
            dialogBodyLayout.Padding = list.Padding
            dialogBodyLayout.Parent = dialogBodyContent

            local originalChildren = box:GetChildren()
            for _, child in ipairs(originalChildren) do
                if child:IsA("GuiObject") and child ~= header and child ~= dialogBody then
                    child.Parent = dialogBodyContent
                end
            end
            -- A layout item makes the reserve part of AutomaticSize/CanvasSize.
            local gripSpacer = Instance.new("Frame")
            gripSpacer.Name = "ResizeGripClearance"
            gripSpacer.Size = UDim2.new(1, 0, 0, math.max(0, gripBottomClearance - list.Padding.Offset))
            gripSpacer.LayoutOrder = runtimeHolder.LayoutOrder + 1
            gripSpacer.BackgroundTransparency = 1
            gripSpacer.BorderSizePixel = 0
            gripSpacer.ZIndex = 151
            gripSpacer.Parent = dialogBodyContent
            table.insert(connections, dialogBodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateDialogBodyCanvas))
            table.insert(connections, dialogBodyContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateDialogBodyCanvas))
            task.defer(updateDialogBodyCanvas)

            resizeGripHost = Instance.new("Frame")
            resizeGripHost.Name = "DialogResizeGripHost"
            resizeGripHost.BackgroundTransparency = 1
            resizeGripHost.BorderSizePixel = 0
            resizeGripHost.Active = false
            resizeGripHost.Visible = false
            resizeGripHost.ZIndex = 155
            resizeGripHost.Parent = layer
            FLOATING_FRAMES[resizeGripHost] = true

            resizeGrip = Instance.new("TextButton")
            resizeGrip.Name = "ResizeHandle"
            resizeGrip.Size = UDim2.new(0, gripSize, 0, gripSize)
            resizeGrip.Position = UDim2.new(1, -gripSize, 1, -gripSize)
            resizeGrip.BackgroundTransparency = 1
            resizeGrip.Text = ""
            resizeGrip.AutoButtonColor = false
            resizeGrip.Active = true
            resizeGrip.ZIndex = 156
            resizeGrip.Parent = resizeGripHost
            local gripLines = {}
            for index, spec in ipairs({{-4, -4, 14}, {-4, -8, 8}}) do
                local line = Instance.new("Frame")
                line.Size = UDim2.new(0, spec[3], 0, 1)
                line.Position = UDim2.new(1, spec[1], 1, spec[2])
                line.AnchorPoint = Vector2.new(1, 1)
                bindColor(line, "BackgroundColor3", "TextDim")
                line.BorderSizePixel = 0
                line.ZIndex = 157
                line.Parent = resizeGrip
                addCorner(line, 4)
                gripLines[index] = line
            end
            resizeGrip.MouseEnter:Connect(function()
                for _, line in ipairs(gripLines) do bindColor(line, "BackgroundColor3", "Accent") end
            end)
            resizeGrip.MouseLeave:Connect(function()
                for _, line in ipairs(gripLines) do bindColor(line, "BackgroundColor3", "TextDim") end
            end)

            local function updateGripHost()
                if not box.Parent or not resizeGripHost.Parent then return end
                local origin = Vector2.zero
                pcall(function() origin = layer.AbsolutePosition end)
                local topLeft = box.AbsolutePosition - origin
                resizeGripHost.Position = UDim2.fromOffset(
                    topLeft.X + box.AbsoluteSize.X - gripSize,
                    topLeft.Y + box.AbsoluteSize.Y - gripSize)
                resizeGripHost.Size = UDim2.fromOffset(gripSize, gripSize)
                resizeGripHost.Visible = box.Visible
            end
            table.insert(connections, box:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateGripHost))
            table.insert(connections, box:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateGripHost))
            table.insert(connections, box:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleAutoHeightCap))
            task.defer(updateGripHost)

            local minResizeWidth = math.min(tonumber(dOpts.MinWidth) or 220, maxWidth)
            local minResizeHeight = math.min(tonumber(dOpts.MinHeight) or 180, maxHeight)
            local resizing, resizeStart, startPixels, startPos, startTopLeft, activeInputType = false, nil, nil, nil, nil, nil
            resizeGrip.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1
                    and input.UserInputType ~= Enum.UserInputType.Touch then
                    return
                end
                if closed then return end
                resizing = true
                activeInputType = input.UserInputType
                resizeStart = input.Position
                startPixels = box.AbsoluteSize
                startPos = box.Position
                startTopLeft = box.AbsolutePosition
                setDialogFixedSize(startPixels.X / math.max(dialogScale, 0.01), startPixels.Y / math.max(dialogScale, 0.01))
            end)
            table.insert(connections, UserInputService.InputChanged:Connect(function(input)
                if not resizing then return end
                if input.UserInputType ~= Enum.UserInputType.MouseMovement
                    and input.UserInputType ~= Enum.UserInputType.Touch then
                    return
                end
                local delta = input.Position - resizeStart
                local currentViewport = getViewportSize()
                local minPixelW = minResizeWidth * dialogScale
                local minPixelH = minResizeHeight * dialogScale
                local centerX = startTopLeft.X + startPixels.X / 2
                local centerY = startTopLeft.Y + startPixels.Y / 2
                local maxPixelW = math.max(minPixelW, 2 * math.min(centerX - widthMargin, currentViewport.X - centerX - widthMargin))
                local maxPixelH = math.max(minPixelH, 2 * math.min(centerY - widthMargin, currentViewport.Y - centerY - widthMargin))
                local pixelW = math.clamp(startPixels.X + delta.X, minPixelW, maxPixelW)
                local pixelH = math.clamp(startPixels.Y + delta.Y, minPixelH, maxPixelH)
                local logicalW = pixelW / math.max(dialogScale, 0.01)
                local logicalH = pixelH / math.max(dialogScale, 0.01)
                setDialogFixedSize(logicalW, logicalH)
                box.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + (pixelW - startPixels.X) / 2,
                    startPos.Y.Scale, startPos.Y.Offset + (pixelH - startPixels.Y) / 2)
            end))
            table.insert(connections, UserInputService.InputEnded:Connect(function(input)
                local ended = (activeInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)
                    or (activeInputType == Enum.UserInputType.Touch and input.UserInputType == Enum.UserInputType.Touch)
                if ended then
                    resizing = false
                    activeInputType = nil
                    if type(dOpts.OnResize) == "function" then
                        task.spawn(dOpts.OnResize, box.Size.X.Offset, box.Size.Y.Offset, handle)
                    end
                end
            end))

            -- Cap after initial layout and any later runtime content additions.
            scheduleAutoHeightCap()
        end

        -- Behaviour ---------------------------------------------------------------
        do -- drag by the header
            local dragging, dragStart, startPos = false, nil, nil
            header.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    dragStart = input.Position
                    startPos = box.Position
                end
            end)
            table.insert(connections, UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    local delta = input.Position - dragStart
                    box.Position = UDim2.fromOffset(startPos.X.Offset + delta.X, startPos.Y.Offset + delta.Y)
                end
            end))
            table.insert(connections, UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end))
        end

        function handle.Close()
            if closed then return end
            closed = true
            if activeDialog == handle then activeDialog = nil end
            if resizeGripHost then
                resizeGripHost:Destroy()
                resizeGripHost = nil
            end
            for _, c in ipairs(connections) do c:Disconnect() end
            connections = {}
            TweenService:Create(overlay, TWEEN_FAST, {BackgroundTransparency = 1}):Play()
            local t = TweenService:Create(box, TWEEN_FAST, {Position = box.Position + UDim2.fromOffset(0, 12)})
            t:Play()
            task.delay(0.2, function()
                overlay:Destroy()
                box:Destroy()
            end)
            if dOpts.OnClose then task.spawn(dOpts.OnClose) end
        end
        function handle.IsOpen() return not closed end
        function handle.SetTitle(text) title.Text = tostring(text) end
        function handle.SetLines(lines) setLines(lines) end
        function handle.SetTag(text) if tagLabel then tagLabel.Text = tostring(text or "") tagLabel.Parent.Visible = text ~= nil and text ~= "" end end
        function handle.SetBadge(text) if badgeLabel then badgeLabel.Text = tostring(text or "") badgeLabel.Parent.Visible = text ~= nil and text ~= "" end end
        function handle.GetButton(idOrIndex) return buttonHandles[idOrIndex] end
        handle.Buttons = buttonHandles
        handle.Frame = box
        handle.Data = dOpts.Data

        if dOpts.CloseOnBackdrop ~= false then
            local function insideBox(pos)
                local p0 = box.AbsolutePosition
                local p1 = p0 + box.AbsoluteSize
                return pos.X >= p0.X and pos.X <= p1.X and pos.Y >= p0.Y and pos.Y <= p1.Y
            end
            local pressedOutside = false
            overlay.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
                pressedOutside = not insideBox(Vector2.new(input.Position.X, input.Position.Y))
            end)
            overlay.InputEnded:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
                local wasOutside = pressedOutside
                pressedOutside = false
                if wasOutside and not insideBox(Vector2.new(input.Position.X, input.Position.Y)) then
                    handle.Close()
                end
            end)
        end
        closeBtn.MouseButton1Click:Connect(function() handle.Close() end)
        table.insert(connections, UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == Enum.KeyCode.Escape then handle.Close() end
        end))
        trackConn(connections[#connections])

        activeDialog = handle
        return wrapHandle(handle)
    end

    --[[ host = nil  -> panel lives in the main window's content area (tab mode)
         host = {Parent = frame, Window = frame, OnOpen = fn} -> standalone window ]]
    local function buildBrowsePanel(tabName, opts, host)
        opts = opts or {}
        local marketStyle = opts.Browsec == true or opts.MarketStyle == true
        local columns = math.max(1, math.floor(tonumber(opts.Columns) or 3))
        local viewport = getViewportSize()
        local mobileLayout = opts.Mobile == nil and isMobileDevice(viewport) or opts.Mobile == true
        local mobileColumns = tonumber(opts.MobileColumns)
        if mobileColumns then mobileColumns = math.max(1, math.floor(mobileColumns)) end
        local pageSize = math.max(1, math.floor(tonumber(opts.PageSize) or 9))
        local gap = 8
        local callback = opts.Callback or opts.OnSelect or opts.OnClick
        local downloadCallback = opts.DownloadCallback or opts.OnDownload or callback
        local parse = opts.Parse or opts.Transform
        local source = opts.Source or opts.Url or opts.Api or opts.API
        local fetcher = opts.Fetch or opts.Loader
        local detailsOpt = opts.Details or opts.Dialog
        if marketStyle and opts.Details == false then detailsOpt = false end
        if marketStyle and opts.Details == nil and opts.Dialog == nil then detailsOpt = true end
        local imageLoader = opts.ImageLoader or opts.LoadImage -- function(src, item) -> asset string
        local marketIcons3D = opts.Icons3D
        if marketIcons3D == nil then marketIcons3D = opts["3DIcons"] end
        local marketIconDefaults = {
            Icons3D = marketIcons3D,
            Icon3D = opts.Icon3D or opts.Icon3DConfig or opts.Viewport,
            IconSize = opts.IconSize or opts.Icon3DSize,
            Models = opts.Models,
        }
        local remote = (opts.Remote == true) or (opts.ServerSide == true) -- server does paging/search/sort
        local sourceTabs = {}
        for _, t in ipairs(opts.Tabs or {}) do
            if type(t) == "table" then
                table.insert(sourceTabs, {Name = tostring(t.Name or t.Text or t.Title or "Tab"), Id = t.Id or t.Value or t.Name or t.Text})
            else
                table.insert(sourceTabs, {Name = tostring(t), Id = t})
            end
        end
        local placeholderIcon = opts.PlaceholderIcon or "image"
        local imageScale = (tostring(opts.ImageScaleType or opts.ImageScale or "Crop"):lower() == "fit")
            and Enum.ScaleType.Fit or Enum.ScaleType.Crop
        local autoCategories = (opts.Categories == nil)

        -- sort modes: {"Hot", "New"} or {{Name = "Hot", Sort = fn, Icon = "zap"}, ...}
        local sortModes = {}
        for _, mode in ipairs(opts.SortModes or opts.Sorts or {"Hot", "New", "A-Z"}) do
            if type(mode) == "string" and BROWSE_SORTS[mode] then
                table.insert(sortModes, {Name = mode, Icon = BROWSE_SORTS[mode].Icon, Sort = BROWSE_SORTS[mode].Sort})
            elseif type(mode) == "table" and type(mode.Sort) == "function" then
                table.insert(sortModes, {Name = mode.Name or mode.Title or "Sort", Icon = mode.Icon or "zap", Sort = mode.Sort})
            end
        end
        if #sortModes == 0 then
            table.insert(sortModes, {Name = "Hot", Icon = "zap", Sort = BROWSE_SORTS.Hot.Sort})
        end

        local showDetails -- defined after the card helpers
        local state = {
            Items = {},
            Filtered = {},
            Query = "",
            Category = "All",
            Categories = {"All"},
            SortIndex = 1,
            Page = 1,
            Pages = 1,
            Selected = nil,
            Loading = false,
            Generation = 0,
            Tab = sourceTabs[1] and sourceTabs[1].Id or nil,
            Total = tonumber(opts.Total),
        }

        -- scale of the window this panel lives in (main window or its own Browse window)
        local function panelScale()
            local sc = host and host.Scale
            return math.max((sc and sc.Scale) or UI_SCALE, 0.01)
        end

        local Panel = Instance.new("Frame")
        Panel.Name = "BrowsePanel"
        Panel.Size = UDim2.new(1, 0, 1, 0)
        Panel.BackgroundTransparency = 1
        Panel.Visible = host ~= nil
        Panel.ZIndex = 3
        Panel.Parent = host and host.Parent or ContentArea

        local panelPad = Instance.new("UIPadding")
        panelPad.PaddingLeft = UDim.new(0, 4)
        panelPad.PaddingRight = UDim.new(0, 4)
        panelPad.PaddingTop = UDim.new(0, 4)
        panelPad.PaddingBottom = UDim.new(0, 6)
        panelPad.Parent = Panel

        -- Toolbar --------------------------------------------------------------
        local TOOL_H = 30
        local Toolbar = Instance.new("Frame")
        Toolbar.Size = UDim2.new(1, 0, 0, TOOL_H)
        Toolbar.BackgroundTransparency = 1
        Toolbar.ZIndex = 4
        Toolbar.Parent = Panel

        local sortW = marketStyle and 156 or 68
        local rightW = marketStyle and 100 or (sortW + 6 + 28 + 10 + 24 + 46 + 24) -- sort, refresh, prev, page, next

        local SearchFrame = Instance.new("Frame")
        SearchFrame.Size = UDim2.new(1, -(rightW + 8), 1, 0)
        bindColor(SearchFrame, "BackgroundColor3", "BadgeBg")
        SearchFrame.BorderSizePixel = 0
        SearchFrame.ZIndex = 4
        SearchFrame.Parent = Toolbar
        addCorner(SearchFrame, 8)
        local searchStroke = addStroke(SearchFrame, 1)

        local searchIcon = Instance.new("ImageLabel")
        searchIcon.Size = UDim2.new(0, 13, 0, 13)
        searchIcon.Position = UDim2.new(0, 10, 0.5, -6.5)
        searchIcon.BackgroundTransparency = 1
        searchIcon.Image = resolveIcon("search")
        tintIcon(searchIcon, "search", "TextMuted")
        searchIcon.ZIndex = 5
        searchIcon.Parent = SearchFrame

        local searchInput = Instance.new("TextBox")
        searchInput.Size = UDim2.new(1, -36, 1, 0)
        searchInput.Position = UDim2.new(0, 29, 0, 0)
        searchInput.BackgroundTransparency = 1
        searchInput.Text = ""
        searchInput.PlaceholderText = opts.SearchPlaceholder or "Search..."
        bindColor(searchInput, "PlaceholderColor3", "TextDim")
        bindColor(searchInput, "TextColor3", "TextPrimary")
        searchInput.Font = Enum.Font.Gotham
        searchInput.TextSize = 11
        searchInput.TextXAlignment = Enum.TextXAlignment.Left
        searchInput.ClearTextOnFocus = false
        searchInput.ZIndex = 5
        searchInput.Parent = SearchFrame

        searchInput.Focused:Connect(function()
            tweenColors(searchStroke, TWEEN_FAST, {Color = "BorderActive"}):Play()
        end)
        searchInput.FocusLost:Connect(function()
            tweenColors(searchStroke, TWEEN_FAST, {Color = "Border"}):Play()
        end)

        local function toolButton(width, xOffset, iconName)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, width, 1, 0)
            btn.Position = UDim2.new(1, -xOffset, 0, 0)
            bindColor(btn, "BackgroundColor3", "BadgeBg")
            btn.BorderSizePixel = 0
            btn.Text = ""
            btn.AutoButtonColor = false
            btn.ZIndex = 4
            btn.Parent = Toolbar
            addCorner(btn, 8)
            local stroke = addStroke(btn, 1)
            local icon
            if iconName then
                icon = Instance.new("ImageLabel")
                icon.Size = UDim2.new(0, 13, 0, 13)
                icon.Position = UDim2.new(0.5, -6.5, 0.5, -6.5)
                icon.BackgroundTransparency = 1
                icon.Image = resolveIcon(iconName)
                tintIcon(icon, iconName, "TextMuted")
                icon.ZIndex = 5
                icon.Parent = btn
            end
            btn.MouseEnter:Connect(function()
                tweenColors(stroke, TWEEN_FAST, {Color = "BorderActive"}):Play()
                if icon then tweenColors(icon, TWEEN_FAST, {ImageColor3 = "TextPrimary"}):Play() end
            end)
            btn.MouseLeave:Connect(function()
                tweenColors(stroke, TWEEN_FAST, {Color = "Border"}):Play()
                if icon then tweenColors(icon, TWEEN_FAST, {ImageColor3 = "TextMuted"}):Play() end
            end)
            return btn, icon, stroke
        end

        -- sort switch ("Hot")
        local SortBtn = toolButton(sortW, rightW, nil)
        local sortIcon = Instance.new("ImageLabel")
        sortIcon.Size = UDim2.new(0, 13, 0, 13)
        sortIcon.Position = UDim2.new(0, 10, 0.5, -6.5)
        sortIcon.BackgroundTransparency = 1
        sortIcon.Image = resolveIcon(sortModes[1].Icon)
        tintIcon(sortIcon, sortModes[1].Icon, "Accent")
        sortIcon.ZIndex = 5
        sortIcon.Parent = SortBtn
        local sortLabel = Instance.new("TextLabel")
        sortLabel.Size = UDim2.new(1, -30, 1, 0)
        sortLabel.Position = UDim2.new(0, 28, 0, 0)
        sortLabel.BackgroundTransparency = 1
        sortLabel.Text = sortModes[1].Name
        sortLabel.Font = Enum.Font.GothamBold
        sortLabel.TextSize = 11
        bindColor(sortLabel, "TextColor3", "TextPrimary")
        sortLabel.TextXAlignment = Enum.TextXAlignment.Left
        sortLabel.ZIndex = 5
        sortLabel.Parent = SortBtn

        if marketStyle then
            SortBtn.Parent = Panel
            SortBtn.Size = UDim2.new(0, sortW, 0, 24)
            SortBtn.AnchorPoint = Vector2.new(1, 0)
            SortBtn.Position = UDim2.new(1, -4, 0, TOOL_H + 8)
            sortLabel.Size = UDim2.new(1, -48, 1, 0)
            local arrow = Instance.new("ImageLabel")
            arrow.Size = UDim2.new(0, 11, 0, 11)
            arrow.AnchorPoint = Vector2.new(1, 0.5)
            arrow.Position = UDim2.new(1, -8, 0.5, 0)
            arrow.BackgroundTransparency = 1
            arrow.Image = resolveIcon("chevron-down")
            tintIcon(arrow, "chevron-down", "TextMuted")
            arrow.ZIndex = 5
            arrow.Parent = SortBtn
        end

        local RefreshBtn, refreshIcon = toolButton(28, rightW - sortW - 6, "refresh-cw")
        local PrevBtn, prevIcon = toolButton(24, 24 + 46 + 24, "chevron-right")
        prevIcon.Rotation = 180
        local NextBtn = toolButton(24, 24, "chevron-right")

        local PageLabel = Instance.new("TextLabel")
        PageLabel.Size = UDim2.new(0, 46, 1, 0)
        PageLabel.Position = UDim2.new(1, -(24 + 46), 0, 0)
        PageLabel.BackgroundTransparency = 1
        PageLabel.Text = "1/1"
        PageLabel.Font = Enum.Font.GothamMedium
        PageLabel.TextSize = 11
        bindColor(PageLabel, "TextColor3", "TextMuted")
        PageLabel.ZIndex = 5
        PageLabel.Parent = Toolbar
        if marketStyle then
            RefreshBtn.Visible = false
            PrevBtn.Visible = false
            NextBtn.Visible = false
            PageLabel.Visible = false
        end

        -- Category chips -------------------------------------------------------
        local CHIP_H = 24
        local Chips = Instance.new("ScrollingFrame")
        Chips.Size = UDim2.new(1, marketStyle and -(sortW + 12) or 0, 0, CHIP_H)
        Chips.Position = UDim2.new(0, 0, 0, TOOL_H + 8)
        Chips.BackgroundTransparency = 1
        Chips.BorderSizePixel = 0
        Chips.ScrollBarThickness = 0
        Chips.ScrollingDirection = Enum.ScrollingDirection.X
        Chips.CanvasSize = UDim2.new(0, 0, 0, 0)
        Chips.AutomaticCanvasSize = Enum.AutomaticSize.X
        Chips.ZIndex = 4
        Chips.Parent = Panel

        local chipLayout = Instance.new("UIListLayout")
        chipLayout.FillDirection = Enum.FillDirection.Horizontal
        chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
        chipLayout.Padding = UDim.new(0, 6)
        chipLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        chipLayout.Parent = Chips

        local chipButtons = {}

        -- Grid -----------------------------------------------------------------
        local GRID_TOP = TOOL_H + 8 + CHIP_H + 8
        local Grid = Instance.new("ScrollingFrame")
        Grid.Size = UDim2.new(1, 0, 1, -GRID_TOP)
        Grid.Position = UDim2.new(0, 0, 0, GRID_TOP)
        Grid.BackgroundTransparency = 1
        Grid.BorderSizePixel = 0
        Grid.ScrollBarThickness = 2
        bindColor(Grid, "ScrollBarImageColor3", "Accent")
        Grid.ScrollingDirection = Enum.ScrollingDirection.Y
        Grid.CanvasSize = UDim2.new(0, 0, 0, 0)
        Grid.ZIndex = 4
        Grid.Parent = Panel

        local gridLayout = Instance.new("UIGridLayout")
        gridLayout.CellPadding = UDim2.new(0, gap, 0, gap)
        gridLayout.CellSize = UDim2.new(0, 180, 0, 124)
        gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
        gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        gridLayout.Parent = Grid

        local gridPad = Instance.new("UIPadding")
        gridPad.PaddingRight = UDim.new(0, 6)
        gridPad.PaddingBottom = UDim.new(0, 4)
        gridPad.Parent = Grid

        local Status = Instance.new("TextLabel")
        Status.Size = UDim2.new(1, 0, 0, 40)
        Status.Position = UDim2.new(0, 0, 0, GRID_TOP + 60)
        Status.BackgroundTransparency = 1
        Status.Text = ""
        Status.Font = Enum.Font.GothamMedium
        Status.TextSize = 12
        bindColor(Status, "TextColor3", "TextDim")
        Status.Visible = false
        Status.ZIndex = 5
        Status.Parent = Panel

        local NAME_H = 26
        local MARKET_INFO_H = 72
        local MARKET_THUMB_RATIO = 0.36
        local function columnsForWidth(width)
            if not marketStyle or opts.Responsive == false then return columns end
            if mobileColumns then return math.min(columns, mobileColumns) end
            if width < 520 then return 1 end
            if width < 860 or (mobileLayout and width < 980) then return math.min(columns, 2) end
            return columns
        end
        local function updateCellSize()
            local width = Grid.AbsoluteSize.X / panelScale() - 6
            if width <= 0 then return end
            local activeColumns = columnsForWidth(width)
            local cellW = math.floor((width - gap * (activeColumns - 1)) / activeColumns)
            local cellH = marketStyle and (math.floor(cellW * MARKET_THUMB_RATIO) + MARKET_INFO_H)
                or (math.floor(cellW * 0.55) + NAME_H)
            gridLayout.CellSize = UDim2.new(0, cellW, 0, cellH)
        end
        Grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCellSize)
        gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            Grid.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y / panelScale() + 8)
        end)
        task.defer(updateCellSize)

        local function setStatus(text)
            Status.Text = text or ""
            Status.Visible = text ~= nil and text ~= ""
        end

        -- Cards ------------------------------------------------------------------
        local cardPool = {}
        local cardActionDefs = {}
        if marketStyle then
            local configured = opts.CardButtons or opts.CardActions
            if type(configured) == "table" then
                if configured[1] ~= nil then
                    for _, def in ipairs(configured) do table.insert(cardActionDefs, def) end
                elseif configured.Text or configured.Name then
                    table.insert(cardActionDefs, configured)
                end
            else
                if detailsOpt ~= false then
                    table.insert(cardActionDefs, {Text = opts.DetailsText or "Details", Icon = "eye", Action = "Details"})
                end
                table.insert(cardActionDefs, {Text = opts.DownloadText or "Download", Icon = "download", Primary = true, Action = "Download"})
            end
        end
        local function browseArray(value)
            if value == nil then return {} end
            if type(value) ~= "table" then return {value} end
            if value[1] ~= nil then return value end
            return {value}
        end

        local function formatRating(r)
            if not r then return nil end
            return string.format("%d%%", math.floor(r + 0.5))
        end

        local function compactCount(value)
            local n = tonumber(value)
            if not n then return tostring(value or "") end
            local sign = n < 0 and "-" or ""
            n = math.abs(n)
            if n >= 1000000 then return sign .. string.format("%.1fm", n / 1000000):gsub("%.0m$", "m") end
            if n >= 1000 then return sign .. string.format("%.1fk", n / 1000):gsub("%.0k$", "k") end
            return sign .. tostring(math.floor(n + 0.5))
        end

        --[[ Item details dialog. `Details` can be:
              true                     -> default dialog (title, pictures, rating badge, info, Select button)
              table                    -> overrides for the default; function fields are called with (item)
              function(item, Browse)   -> returns such a table (or nil for the default)
            Button callbacks receive (item, dialog). ]]
        local Browse = {} -- filled below; needed by the Details callback
        local function defaultDetails(item)
            if marketStyle then
                local stats = {}
                if item.Downloads ~= nil then
                    table.insert(stats, {Label = "Downloads", Value = compactCount(item.Downloads), Icon = "download"})
                end
                if item.BuildValue ~= nil then
                    table.insert(stats, {Label = "Build Value", Value = compactCount(item.BuildValue), Icon = "coins"})
                end
                if item.BlockCount ~= nil then
                    table.insert(stats, {Label = "Blocks", Value = compactCount(item.BlockCount), Icon = "blocks"})
                end
                local progress = item.Buildability
                if progress and progress > 1 then progress = progress / 100 end
                local badgeCount = item.Likes or item.Popularity
                local itemIcons3D = item.Icons3D
                if itemIcons3D == nil then itemIcons3D = marketIcons3D end
                local blocksButton
                local globalBlocksButton = opts.BlocksButton
                local blocksButtonEnabled = globalBlocksButton ~= false and opts.ShowBlocksButton ~= false
                    and not (type(globalBlocksButton) == "table" and globalBlocksButton.Enabled == false)
                if blocksButtonEnabled and type(item.BlockList) == "table" and #item.BlockList > 0 then
                    blocksButton = {
                        Text = opts.BlocksButtonText or "Required Blocks",
                        Title = opts.BlocksDialogTitle or "Required blocks",
                        Icon = opts.BlocksButtonIcon or "blocks",
                        Items = item.BlockList,
                        Count = item.BlockCount,
                        Models = opts.BlockModels or item.BlockModels or item.Models or marketIconDefaults.Models,
                        Icon3D = opts.BlockIcon3D or item.BlockIcon3D or item.Icon3D or opts.Icon3D or marketIconDefaults.Icon3D,
                        Icon3DConfig = opts.BlockIcon3DConfig or item.BlockIcon3DConfig,
                        IconSize = opts.BlockIconSize or item.BlockIconSize or item.IconSize or opts.IconSize or marketIconDefaults.IconSize,
                        Icons3D = opts.BlockIcons3D,
                        ImageLoader = imageLoader and function(src) return imageLoader(src, item) end or nil,
                        OnBack = function() showDetails(item) end,
                    }
                    if blocksButton.Icons3D == nil then blocksButton.Icons3D = item.BlockIcons3D end
                    if blocksButton.Icons3D == nil then blocksButton.Icons3D = itemIcons3D end
                    if type(globalBlocksButton) == "table" then
                        for key, value in pairs(globalBlocksButton) do
                            if key ~= "Enabled" then blocksButton[key] = value end
                        end
                    end
                end
                local downloadDef = {
                    Text = opts.DownloadText or "Download Build",
                    Icon = "download",
                    Primary = true,
                    Close = opts.CloseOnDownload == true,
                    Callback = downloadCallback and function(selectedItem, dialog)
                        task.spawn(downloadCallback, selectedItem, selectedItem.Raw, Browse, dialog)
                    end or nil,
                }
                return {
                    Title = item.Name,
                    Author = item.Author,
                    Verified = item.Verified,
                    Images = item.Images,
                    Model = item.Model,
                    Icon3D = item.Icon3D or marketIconDefaults.Icon3D,
                    Models = item.Models or marketIconDefaults.Models,
                    Icons3D = itemIcons3D,
                    IconSize = item.IconSize or marketIconDefaults.IconSize,
                    Icon = item.IconName,
                    Fit = item.Fit,
                    ImageHeight = tonumber(opts.DetailImageHeight) or 190,
                    Width = tonumber(opts.DetailWidth) or 540,
                    Tag = item.Category,
                    Badge = badgeCount and compactCount(badgeCount) or nil,
                    BadgeIcon = badgeCount and "heart" or nil,
                    Lines = item.Description and {{Text = tostring(item.Description), Icon = "info"}} or {},
                    Stats = #stats > 0 and stats or nil,
                    Buildability = progress and {Value = progress, Label = "Buildability"} or nil,
                    BlocksButton = blocksButton,
                    ShareLink = item.ViewUrl and {Url = tostring(item.ViewUrl), Label = "View in 3D in your browser"} or nil,
                    FooterText = item.Published and ("Published " .. tostring(item.Published)) or nil,
                    Buttons = {downloadDef},
                }
            end

            local lines = {}
            if item.Author then table.insert(lines, {Text = "by " .. tostring(item.Author), Icon = "user"}) end
            if item.Category and item.Category ~= "" then table.insert(lines, {Text = tostring(item.Category), Icon = "tag"}) end
            if item.Description then table.insert(lines, {Text = tostring(item.Description), Icon = "info"}) end
            local ratingText = formatRating(item.Rating)
            local itemIcons3D = item.Icons3D
            if itemIcons3D == nil then itemIcons3D = marketIcons3D end
            return {
                Title = item.Name,
                Images = item.Images,
                Model = item.Model,
                Icon3D = item.Icon3D or marketIconDefaults.Icon3D,
                Models = item.Models or marketIconDefaults.Models,
                Icons3D = itemIcons3D,
                IconSize = item.IconSize or marketIconDefaults.IconSize,
                Icon = item.IconName,
                Fit = item.Fit,
                Tag = item.Category,
                Badge = ratingText and ("★ " .. ratingText) or nil,
                Lines = lines,
                Buttons = {
                    {Text = opts.SelectText or "Select", Icon = "check", Primary = true, Close = true, UseCallback = true},
                },
            }
        end

        showDetails = function(item, overrides)
            if not item then return nil end
            item = normalizeBrowseItem(item, 0, marketStyle, marketIconDefaults.Models)
            local spec = defaultDetails(item)
            local user = overrides
            if user == nil then
                if type(detailsOpt) == "function" then
                    local ok, res = pcall(detailsOpt, item, Browse)
                    if ok and type(res) == "table" then user = res end
                elseif type(detailsOpt) == "table" then
                    user = detailsOpt
                end
            end
            if type(user) == "table" then
                for key, value in pairs(user) do
                    local resolved = value
                    if type(value) == "function" and key ~= "OnClose" then
                        local ok, result = pcall(value, item, Browse)
                        if ok then resolved = result end
                    end
                    if key == "BlocksButton" and type(resolved) == "table" and type(spec.BlocksButton) == "table" then
                        local merged = {}
                        for option, entry in pairs(spec.BlocksButton) do merged[option] = entry end
                        for option, entry in pairs(resolved) do merged[option] = entry end
                        spec.BlocksButton = merged
                    elseif key == "BlocksButton" and resolved == true and type(spec.BlocksButton) == "table" then
                        -- true enables the item's default button configuration.
                    else
                        spec[key] = resolved
                    end
                end
                -- Existing Details callbacks that explicitly provide Blocks keep
                -- the legacy inline list unless they also opt into the button.
                if user.Blocks ~= nil and user.BlocksButton == nil
                    and opts.BlocksButton == nil and opts.ShowBlocksButton == nil then
                    spec.BlocksButton = nil
                end
            end
            -- wire callbacks: button Callback(item, dialog); default Select -> Browse Callback
            local function wire(def)
                if type(def) ~= "table" then return def end
                local cb = def.Callback
                local copy = {}
                for k, v in pairs(def) do copy[k] = v end
                copy.Callback = function(dialog)
                    if cb then
                        cb(item, dialog)
                    elseif def.UseCallback and callback then
                        callback(item, item.Raw)
                    end
                end
                return copy
            end
            local wiredButtons = {}
            for i, def in ipairs(spec.Buttons or {}) do
                if type(def) == "table" and def[1] ~= nil then
                    local row = {}
                    for j, sub in ipairs(def) do row[j] = wire(type(sub) == "string" and {Text = sub} or sub) end
                    wiredButtons[i] = row
                else
                    wiredButtons[i] = wire(type(def) == "string" and {Text = def} or def)
                end
            end
            spec.Buttons = wiredButtons
            local wiredHeader = {}
            for i, def in ipairs(spec.HeaderButtons or {}) do
                wiredHeader[i] = wire(type(def) == "string" and {Text = def} or def)
            end
            spec.HeaderButtons = wiredHeader
            local function wireElements(list)
                if type(list) ~= "table" then return list end
                local isArray = list[1] ~= nil
                local entries = isArray and list or {list}
                local result = {}
                for i, def in ipairs(entries) do
                    if type(def) == "table" then
                        local copy = wire(def)
                        if def.Items then copy.Items = wireElements(def.Items) end
                        if def.Children then copy.Children = wireElements(def.Children) end
                        if def[1] ~= nil then
                            for j, child in ipairs(def) do copy[j] = wireElements(child) end
                        end
                        result[i] = copy
                    else
                        result[i] = def
                    end
                end
                return isArray and result or result[1]
            end
            spec.Elements = wireElements(spec.Elements)
            spec.HStacks = wireElements(spec.HStacks)
            spec.Data = item
            if spec.ImageLoader == nil and imageLoader then
                spec.ImageLoader = function(src) return imageLoader(src, item) end
            end
            if spec.Anchor == nil and host and host.Window then spec.Anchor = host.Window end
            state.Selected = item
            local dialog = createDialog(spec)
            if opts.OnDetails then task.spawn(opts.OnDetails, item, dialog) end
            return dialog
        end

        local function fillThumb(thumb, item, generation)
            for _, child in ipairs(thumb:GetChildren()) do
                if child:IsA("ImageLabel") or child.Name == "CardPreview" then child:Destroy() end
            end

            local itemIcons3D = item.Icons3D
            if itemIcons3D == nil then itemIcons3D = marketIconDefaults.Icons3D end
            local itemIconDefaults = {
                Icons3D = itemIcons3D,
                Icon3D = item.Icon3D or marketIconDefaults.Icon3D,
                IconSize = item.IconSize or marketIconDefaults.IconSize,
                Models = item.Models or marketIconDefaults.Models,
            }
            local iconDef = {
                Icon = item.IconName or item.Icon,
                Model = item.Model,
                Icon3D = item.Icon3D,
                Models = item.Models,
                IconSize = item.IconSize,
                Icons3D = item.Icons3D,
            }
            local iconName, modelValue, modelConfig = buttonIconSpec(iconDef, itemIconDefaults)
            local resolvedModel = modelConfig and resolveModel(modelValue, item.Name, modelConfig) or nil
            local sources = {}
            if resolvedModel then
                table.insert(sources, {Model = resolvedModel, Icon3D = modelConfig, Name = item.Name})
            end
            for _, src in ipairs(item.Images or {}) do
                if #sources >= 2 then break end
                if src ~= item.Model and src ~= resolvedModel then table.insert(sources, src) end
            end
            if #sources == 0 and iconName then
                table.insert(sources, {Icon = iconName})
            end
            if #sources == 0 then
                local ph = Instance.new("ImageLabel")
                ph.Name = "CardPreview"
                ph.Size = UDim2.new(0, 22, 0, 22)
                ph.Position = UDim2.new(0.5, -11, 0.5, -11)
                ph.BackgroundTransparency = 1
                ph.Image = resolveIcon(placeholderIcon)
                tintIcon(ph, placeholderIcon, "TextDim")
                ph.ZIndex = 6
                ph.Parent = thumb
                return
            end

            local count = #sources
            for i, src in ipairs(sources) do
                local sourceDef = type(src) == "table" and src or nil
                local sourceOptions = sourceDef or (typeof(src) == "Instance" and {Model = src}) or {Icon = src}
                local sourceDefaults = {
                    Icons3D = itemIconDefaults.Icons3D,
                    Icon3D = itemIconDefaults.Icon3D,
                    IconSize = itemIconDefaults.IconSize,
                    Models = (sourceDef and sourceDef.Models) or itemIconDefaults.Models,
                }
                local sourceIcon, sourceModel, sourceConfig = buttonIconSpec(sourceOptions, sourceDefaults)
                local label = tostring((sourceDef and (sourceDef.Name or sourceDef.Text)) or item.Name)
                local fit = item.Fit
                if sourceDef and sourceDef.Fit ~= nil then fit = sourceDef.Fit end
                local size, position
                if fit then
                    size = UDim2.new(1 / count, -24, 1, -28)
                    position = UDim2.new((i - 1) / count, 12, 0, 14)
                else
                    size = UDim2.new(1 / count, count > 1 and -1 or 0, 1, 0)
                    position = UDim2.new((i - 1) / count, (i > 1) and 1 or 0, 0, 0)
                end

                local modelPreview = sourceConfig and createModelViewport(thumb, sourceModel, label, sourceConfig, 6) or nil
                if modelPreview then
                    local slot = modelPreview.Frame
                    slot.Name = "CardPreview"
                    slot.Size = size
                    slot.Position = position
                    slot.ZIndex = 6
                else
                    local imageSource = sourceDef and (sourceDef.Image or sourceDef.image or sourceDef.Thumbnail or sourceDef.Url or sourceDef.Source)
                    if imageSource == nil and not sourceDef then
                        if typeof(src) == "Instance" then
                            imageSource = nil
                        elseif type(src) == "string" and not (LUCIDE[src] or CUSTOM_ICON_DATA[src]) then
                            imageSource = src
                        elseif type(src) == "number" then
                            imageSource = src
                        end
                    end
                    if imageSource ~= nil then
                        local img = Instance.new("ImageLabel")
                        img.Name = "CardPreview"
                        img.Size = size
                        img.Position = position
                        img.BackgroundTransparency = 1
                        img.ScaleType = fit and Enum.ScaleType.Fit or imageScale
                        img.ZIndex = 6
                        img.Parent = thumb
                        local immediate = (imageLoader == nil and not (type(imageSource) == "string" and string.match(imageSource, "^https?://")))
                            and resolveBrowseImage(imageSource) or nil
                        if immediate then
                            img.Image = immediate
                        else
                            task.spawn(function()
                                local asset
                                if imageLoader then
                                    local ok, res = pcall(imageLoader, imageSource, item)
                                    asset = (ok and type(res) == "string") and res or nil
                                end
                                if not asset then asset = resolveBrowseImage(imageSource) end
                                if state.Generation == generation and img.Parent and asset then
                                    img.Image = asset
                                end
                            end)
                        end
                    elseif sourceIcon then
                        local img = Instance.new("ImageLabel")
                        img.Name = "CardPreview"
                        img.AnchorPoint = Vector2.new(0.5, 0.5)
                        img.Size = UDim2.new(0, 24, 0, 24)
                        img.Position = UDim2.new((i - 1) / count + 0.5 / count, 0, 0.5, 0)
                        img.BackgroundTransparency = 1
                        img.Image = resolveIcon(sourceIcon)
                        tintIcon(img, sourceIcon, "TextDim")
                        img.ZIndex = 6
                        img.Parent = thumb
                    end
                end
            end
        end

        local function createBrowseCard(index)
            local card = Instance.new("TextButton")
            card.Name = "Card"
            card.LayoutOrder = index
            bindColor(card, "BackgroundColor3", "CardBg")
            card.BorderSizePixel = 0
            card.Text = ""
            card.AutoButtonColor = false
            card.ClipsDescendants = true
            card.ZIndex = 5
            card.Parent = Grid
            addCorner(card, 8)
            local stroke = addStroke(card, 1)

            local thumb = Instance.new("Frame")
            thumb.Name = "Thumb"
            thumb.Size = marketStyle and UDim2.new(1, 0, 1, -MARKET_INFO_H) or UDim2.new(1, 0, 1, -NAME_H)
            bindColor(thumb, "BackgroundColor3", "PillBg")
            thumb.BorderSizePixel = 0
            thumb.ClipsDescendants = true
            thumb.ZIndex = 5
            thumb.Parent = card
            addCorner(thumb, 8)

            local thumbFill = Instance.new("Frame") -- squares off the bottom corners of the thumbnail
            local thumbFillHeight = marketStyle and 4 or 10
            thumbFill.Size = UDim2.new(1, 0, 0, thumbFillHeight)
            thumbFill.Position = UDim2.new(0, 0, 1, -thumbFillHeight)
            bindColor(thumbFill, "BackgroundColor3", "PillBg")
            thumbFill.BorderSizePixel = 0
            thumbFill.ZIndex = 5
            thumbFill.Parent = thumb

            local badge = Instance.new("Frame")
            badge.Name = "Badge"
            badge.Size = UDim2.new(0, 44, 0, 16)
            badge.AutomaticSize = Enum.AutomaticSize.X
            badge.Position = UDim2.new(1, -6, 0, 6)
            badge.AnchorPoint = Vector2.new(1, 0)
            bindColor(badge, "BackgroundColor3", "Background")
            badge.BackgroundTransparency = 0.25
            badge.BorderSizePixel = 0
            badge.ZIndex = 7
            badge.Parent = thumb
            addCorner(badge, 5)
            local badgePad = Instance.new("UIPadding")
            badgePad.PaddingLeft = UDim.new(0, 6)
            badgePad.PaddingRight = UDim.new(0, 6)
            badgePad.Parent = badge

            local badgeText = Instance.new("TextLabel")
            badgeText.Size = UDim2.new(0, 0, 1, 0)
            badgeText.AutomaticSize = Enum.AutomaticSize.X
            badgeText.BackgroundTransparency = 1
            badgeText.Text = ""
            badgeText.RichText = true
            badgeText.Font = Enum.Font.GothamBold
            badgeText.TextSize = 10
            bindColor(badgeText, "TextColor3", "TextPrimary")
            badgeText.ZIndex = 8
            badgeText.Parent = badge

            local name = Instance.new("TextLabel")
            name.Name = "Title"
            name.Size = marketStyle and UDim2.new(1, -16, 0, 16) or UDim2.new(1, -16, 0, NAME_H)
            name.Position = marketStyle and UDim2.new(0, 8, 1, -(MARKET_INFO_H - 4)) or UDim2.new(0, 8, 1, -NAME_H)
            name.BackgroundTransparency = 1
            name.Text = ""
            name.Font = Enum.Font.GothamMedium
            name.TextSize = marketStyle and 12 or 11
            bindColor(name, "TextColor3", "TextPrimary")
            name.TextXAlignment = Enum.TextXAlignment.Left
            name.TextTruncate = Enum.TextTruncate.AtEnd
            name.ZIndex = 6
            name.Parent = card

            local rankBadge, rankText, statsRow, metricCells, actionRow
            if marketStyle then
                rankBadge = Instance.new("Frame")
                rankBadge.Name = "RankBadge"
                rankBadge.Size = UDim2.new(0, 38, 0, 18)
                rankBadge.Position = UDim2.new(0, 6, 0, 6)
                bindColor(rankBadge, "BackgroundColor3", "Background")
                rankBadge.BackgroundTransparency = 0.2
                rankBadge.BorderSizePixel = 0
                rankBadge.ZIndex = 7
                rankBadge.Parent = thumb
                addCorner(rankBadge, 5)
                rankText = Instance.new("TextLabel")
                rankText.Size = UDim2.new(1, -8, 1, 0)
                rankText.Position = UDim2.new(0, 4, 0, 0)
                rankText.BackgroundTransparency = 1
                rankText.Text = "#1"
                rankText.Font = Enum.Font.GothamBold
                rankText.TextSize = 9
                bindColor(rankText, "TextColor3", "TextPrimary")
                rankText.ZIndex = 8
                rankText.Parent = rankBadge

                statsRow = Instance.new("Frame")
                statsRow.Name = "Stats"
                statsRow.Size = UDim2.new(1, -16, 0, 14)
                statsRow.Position = UDim2.new(0, 8, 1, -(MARKET_INFO_H - 22))
                statsRow.BackgroundTransparency = 1
                statsRow.ZIndex = 6
                statsRow.Parent = card
                local statsLayout = Instance.new("UIListLayout")
                statsLayout.FillDirection = Enum.FillDirection.Horizontal
                statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
                statsLayout.Padding = UDim.new(0, 6)
                statsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
                statsLayout.Parent = statsRow
                metricCells = {}
                for i = 1, 3 do
                    local cell = Instance.new("Frame")
                    cell.Size = UDim2.new(1 / 3, -4, 1, 0)
                    cell.LayoutOrder = i
                    cell.BackgroundTransparency = 1
                    cell.ZIndex = 6
                    cell.Parent = statsRow
                    local icon = Instance.new("ImageLabel")
                    icon.Size = UDim2.new(0, 11, 0, 11)
                    icon.Position = UDim2.new(0, 0, 0.5, -5.5)
                    icon.BackgroundTransparency = 1
                    icon.ZIndex = 7
                    icon.Parent = cell
                    local label = Instance.new("TextLabel")
                    label.Size = UDim2.new(1, -15, 1, 0)
                    label.Position = UDim2.new(0, 15, 0, 0)
                    label.BackgroundTransparency = 1
                    label.Text = ""
                    label.Font = Enum.Font.GothamMedium
                    label.TextSize = 9
                    label.TextXAlignment = Enum.TextXAlignment.Left
                    label.TextTruncate = Enum.TextTruncate.AtEnd
                    bindColor(label, "TextColor3", "TextMuted")
                    label.ZIndex = 7
                    label.Parent = cell
                    metricCells[i] = {Frame = cell, Icon = icon, Label = label}
                end

                actionRow = Instance.new("Frame")
                actionRow.Name = "Actions"
                actionRow.Size = UDim2.new(1, -16, 0, 24)
                actionRow.AnchorPoint = Vector2.new(0, 1)
                actionRow.Position = UDim2.new(0, 8, 1, -6)
                actionRow.BackgroundTransparency = 1
                actionRow.ZIndex = 7
                actionRow.Parent = card
                local actionLayout = Instance.new("UIListLayout")
                actionLayout.FillDirection = Enum.FillDirection.Horizontal
                actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
                actionLayout.Padding = UDim.new(0, 6)
                actionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
                actionLayout.Parent = actionRow
            end

            local entry = {Button = card, Stroke = stroke, Thumb = thumb, Badge = badge, BadgeText = badgeText, Name = name, Item = nil}
            if marketStyle then
                entry.RankText = rankText
                entry.MetricCells = metricCells
                entry.ActionRow = actionRow
                entry.SetMarketMetrics = function(item, rank)
                    rankText.Text = "#" .. tostring(item.Rank or rank or 1)
                    local metrics = {}
                    if item.BlockCount ~= nil then table.insert(metrics, {Value = item.BlockCount, Icon = "blocks"}) end
                    if item.Downloads ~= nil then table.insert(metrics, {Value = item.Downloads, Icon = "download"}) end
                    local popular = item.Likes or item.Popularity
                    if popular ~= nil then table.insert(metrics, {Value = popular, Icon = "zap"}) end
                    for i, cell in ipairs(metricCells) do
                        local metric = metrics[i]
                        cell.Frame.Visible = metric ~= nil
                        if metric then
                            cell.Label.Text = compactCount(metric.Value)
                            cell.Icon.Image = resolveIcon(metric.Icon)
                            tintIcon(cell.Icon, metric.Icon, "TextMuted")
                        end
                    end
                end
                entry.RefreshActions = function()
                    for _, child in ipairs(actionRow:GetChildren()) do
                        if child:IsA("GuiButton") then child:Destroy() end
                    end
                    local count = #cardActionDefs
                    actionRow.Visible = count > 0
                    if count == 0 then return end
                    for actionIndex, rawDef in ipairs(cardActionDefs) do
                        local def = type(rawDef) == "string" and {Text = rawDef} or rawDef
                        if type(def) == "table" then
                            local btn = Instance.new("TextButton")
                            btn.Size = UDim2.new(1 / count, -(6 * (count - 1)) / count, 1, 0)
                            btn.LayoutOrder = actionIndex
                            btn.BorderSizePixel = 0
                            btn.Text = ""
                            btn.AutoButtonColor = false
                            btn.ZIndex = 8
                            btn.Parent = actionRow
                            addCorner(btn, 7)
                            local stroke = addStroke(btn, 1)
                            local primary = def.Primary == true
                            local bgKey = primary and "Accent" or "BadgeBg"
                            local textKey = primary and "KnobOn" or "TextPrimary"
                            bindColor(btn, "BackgroundColor3", bgKey)
                            if primary then stroke.Transparency = 1 end
                            local iconName, iconModel, iconConfig = buttonIconSpec(def, marketIconDefaults)
                            local iconSlotSize = iconConfig and math.clamp(iconConfig.Size, 12, 16) or 12
                            local iconSlot = createIconSlot(btn, iconSlotSize, iconConfig, 9)
                            local buttonText = tostring(def.Text or def.Name or "Action")
                            local hasIcon = iconSlot:Set(iconName, iconModel, buttonText)
                            if hasIcon then iconSlot:Tint(textKey) end

                            local inner = Instance.new("Frame")
                            inner.BackgroundTransparency = 1
                            inner.ZIndex = 9
                            inner.Parent = btn
                            if hasIcon then
                                inner.Size = UDim2.new(1, -(iconSlotSize + 17), 1, 0)
                                inner.Position = UDim2.new(0, iconSlotSize + 12, 0, 0)
                            else
                                inner.Size = UDim2.new(1, -12, 1, 0)
                                inner.Position = UDim2.new(0, 6, 0, 0)
                            end
                            local label = Instance.new("TextLabel")
                            label.Size = UDim2.new(1, 0, 1, 0)
                            label.BackgroundTransparency = 1
                            label.Text = buttonText
                            label.Font = Enum.Font.GothamBold
                            label.TextSize = 9.5
                            label.TextXAlignment = hasIcon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
                            label.TextTruncate = Enum.TextTruncate.AtEnd
                            bindColor(label, "TextColor3", textKey)
                            label.ZIndex = 10
                            label.Parent = inner
                            btn.MouseEnter:Connect(function()
                                tweenColors(btn, TWEEN_FAST, {BackgroundColor3 = primary and "AccentSoft" or "SidebarActive"}):Play()
                                if not primary then tweenColors(stroke, TWEEN_FAST, {Color = "BorderActive"}):Play() end
                            end)
                            btn.MouseLeave:Connect(function()
                                tweenColors(btn, TWEEN_FAST, {BackgroundColor3 = bgKey}):Play()
                                if not primary then tweenColors(stroke, TWEEN_FAST, {Color = "Border"}):Play() end
                            end)
                            btn.MouseButton1Click:Connect(function()
                                local selectedItem = entry.Item
                                if not selectedItem then return end
                                if type(def.Callback) == "function" or type(def.OnClick) == "function" then
                                    task.spawn(def.Callback or def.OnClick, selectedItem, Browse)
                                    return
                                end
                                local action = string.lower(tostring(def.Action or def.Kind or def.Type or def.Text or ""))
                                if action == "details" or action == "detail" then
                                    if detailsOpt then
                                        showDetails(selectedItem)
                                    elseif callback then
                                        task.spawn(callback, selectedItem, selectedItem.Raw)
                                    end
                                elseif string.find(action, "download", 1, true) then
                                    if downloadCallback then task.spawn(downloadCallback, selectedItem, selectedItem.Raw, Browse) end
                                elseif callback then
                                    task.spawn(callback, selectedItem, selectedItem.Raw)
                                end
                            end)
                        end
                    end
                end
                entry.RefreshActions()
            end

            card.MouseEnter:Connect(function()
                if state.Selected ~= entry.Item then
                    tweenColors(stroke, TWEEN_FAST, {Color = "BorderActive"}):Play()
                end
                tweenColors(card, TWEEN_FAST, {BackgroundColor3 = "SidebarActive"}):Play()
            end)
            card.MouseLeave:Connect(function()
                if state.Selected ~= entry.Item then
                    tweenColors(stroke, TWEEN_FAST, {Color = "Border"}):Play()
                end
                tweenColors(card, TWEEN_FAST, {BackgroundColor3 = "CardBg"}):Play()
            end)
            card.MouseButton1Click:Connect(function()
                if not entry.Item then return end
                state.Selected = entry.Item
                for _, other in ipairs(cardPool) do
                    tweenColors(other.Stroke, TWEEN_FAST, {Color = (other.Item == entry.Item) and "Accent" or "Border"}):Play()
                end
                if detailsOpt then
                    showDetails(entry.Item)
                elseif callback then
                    task.spawn(callback, entry.Item, entry.Item.Raw)
                end
            end)
            return entry
        end

        local accentHex = function()
            local c = THEME.Accent
            return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
        end

        local function renderPage()
            state.Generation = state.Generation + 1
            local generation = state.Generation
            local total = #state.Filtered
            local first
            if remote then
                -- the server already returned exactly one page
                state.Pages = math.max(1, math.floor(tonumber(state.RemotePages) or 1))
                state.Page = math.clamp(state.Page, 1, state.Pages)
                first = 1
            else
                state.Pages = math.max(1, math.ceil(total / pageSize))
                state.Page = math.clamp(state.Page, 1, state.Pages)
                first = (state.Page - 1) * pageSize + 1
            end
            PageLabel.Text = string.format("%d/%d", state.Page, state.Pages)
            if marketStyle then
                local showPager = state.Pages > 1
                PrevBtn.Visible = showPager
                NextBtn.Visible = showPager
                PageLabel.Visible = showPager
            end
            if host and host.SetCount then host.SetCount(state.Total or (not remote and #state.Items or nil)) end

            local shown = 0
            for i = first, (remote and total or math.min(total, first + pageSize - 1)) do
                shown = shown + 1
                local entry = cardPool[shown]
                if not entry then
                    entry = createBrowseCard(shown)
                    cardPool[shown] = entry
                end
                local item = state.Filtered[i]
                entry.Item = item
                entry.Button.Visible = true
                entry.Button.LayoutOrder = shown
                entry.Name.Text = item.Name
                local ratingText
                if marketStyle then
                    local popularity = item.Likes or item.Popularity or item.Rating
                    ratingText = popularity and compactCount(popularity) or nil
                else
                    ratingText = formatRating(item.Rating)
                end
                entry.Badge.Visible = ratingText ~= nil
                entry.BadgeText.Text = ratingText and (string.format('<font color="%s">★</font> ', accentHex()) .. ratingText) or ""
                if entry.SetMarketMetrics then entry.SetMarketMetrics(item, first + shown - 1) end
                bindColor(entry.Stroke, "Color", (state.Selected == item) and "Accent" or "Border")
                fillThumb(entry.Thumb, item, generation)
            end
            for i = shown + 1, #cardPool do
                cardPool[i].Item = nil
                cardPool[i].Button.Visible = false
            end
            Grid.CanvasPosition = Vector2.new(0, 0)

            if state.Loading then
                setStatus("Loading...")
            elseif total == 0 then
                setStatus(#state.Items == 0 and (opts.EmptyText or "Nothing here yet") or "Nothing found")
            else
                setStatus(nil)
            end
        end

        local function itemMatchesCategory(item, category)
            if category == nil or category == "All" then return true end
            local wanted = string.lower(tostring(category))
            if string.lower(tostring(item.Category or "")) == wanted then return true end
            if type(item.Tags) == "table" then
                for _, tag in ipairs(item.Tags) do
                    if string.lower(tostring(tag)) == wanted then return true end
                end
            end
            return false
        end

        local function itemMatchesQuery(item, query)
            if query == "" then return true end
            local hay = string.lower(table.concat({
                item.Name or "", tostring(item.Author or ""), tostring(item.Category or ""),
                tostring(item.Id or ""), tostring(item.Description or ""),
                type(item.Tags) == "table" and table.concat(item.Tags, " ") or "",
            }, " "))
            return string.find(hay, query, 1, true) ~= nil
        end

        local requestLoad -- forward: (re)fetch in remote mode

        local function applyFilters(keepPage)
            if remote then
                state.Filtered = state.Items
                if not keepPage then state.Page = 1 end
                renderPage()
                return
            end
            local query = string.lower(trimText(state.Query))
            local list = {}
            for _, item in ipairs(state.Items) do
                if itemMatchesCategory(item, state.Category) and itemMatchesQuery(item, query) then
                    table.insert(list, item)
                end
            end
            local mode = sortModes[state.SortIndex]
            if mode and mode.Sort then
                table.sort(list, function(a, b)
                    local ok, res = pcall(mode.Sort, a, b)
                    return ok and res == true
                end)
            end
            state.Filtered = list
            if not keepPage then state.Page = 1 end
            renderPage()
        end

        -- chips
        local function setChipActive(chip, active)
            chip.Active = active
            tweenColors(chip.Button, TWEEN_FAST, {BackgroundColor3 = active and "Accent" or "BadgeBg"}):Play()
            tweenColors(chip.Stroke, TWEEN_FAST, {Color = active and "Accent" or "Border"}):Play()
            tweenColors(chip.Label, TWEEN_FAST, {TextColor3 = active and "KnobOn" or "TextMuted"}):Play()
        end

        local setCategory -- forward

        local function rebuildChips()
            for _, chip in ipairs(chipButtons) do chip.Button:Destroy() end
            chipButtons = {}
            for i, name in ipairs(state.Categories) do
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(0, 0, 1, 0)
                btn.AutomaticSize = Enum.AutomaticSize.X
                btn.LayoutOrder = i
                btn.BorderSizePixel = 0
                btn.Text = ""
                btn.AutoButtonColor = false
                btn.ZIndex = 5
                btn.Parent = Chips
                addCorner(btn, 12)
                local stroke = addStroke(btn, 1)
                local pad = Instance.new("UIPadding")
                pad.PaddingLeft = UDim.new(0, 12)
                pad.PaddingRight = UDim.new(0, 12)
                pad.Parent = btn
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(0, 0, 1, 0)
                label.AutomaticSize = Enum.AutomaticSize.X
                label.BackgroundTransparency = 1
                label.Text = name
                label.Font = Enum.Font.GothamMedium
                label.TextSize = 10.5
                label.ZIndex = 6
                label.Parent = btn
                local chip = {Button = btn, Stroke = stroke, Label = label, Name = name, Active = (name == state.Category)}
                bindColor(btn, "BackgroundColor3", chip.Active and "Accent" or "BadgeBg")
                bindColor(stroke, "Color", chip.Active and "Accent" or "Border")
                bindColor(label, "TextColor3", chip.Active and "KnobOn" or "TextMuted")
                btn.MouseEnter:Connect(function()
                    if not chip.Active then tweenColors(label, TWEEN_FAST, {TextColor3 = "TextPrimary"}):Play() end
                end)
                btn.MouseLeave:Connect(function()
                    if not chip.Active then tweenColors(label, TWEEN_FAST, {TextColor3 = "TextMuted"}):Play() end
                end)
                btn.MouseButton1Click:Connect(function() setCategory(name) end)
                table.insert(chipButtons, chip)
            end
        end

        setCategory = function(name)
            name = tostring(name or "All")
            state.Category = name
            for _, chip in ipairs(chipButtons) do
                setChipActive(chip, chip.Name == name)
            end
            if remote then state.Page = 1 requestLoad() else applyFilters(false) end
        end

        local function setCategories(list)
            local cats = {"All"}
            local seen = {All = true}
            for _, c in ipairs(list or {}) do
                local key = tostring(c)
                if not seen[key] then
                    seen[key] = true
                    table.insert(cats, key)
                end
            end
            state.Categories = cats
            if not seen[state.Category] then state.Category = "All" end
            rebuildChips()
        end

        local function collectCategories(items)
            local list, seen = {}, {}
            for _, item in ipairs(items) do
                local c = tostring(item.Category or "")
                if c ~= "" and not seen[c] then
                    seen[c] = true
                    table.insert(list, c)
                end
            end
            table.sort(list)
            return list
        end

        local function setItems(list)
            local items = {}
            for i, raw in ipairs(extractBrowseList(list)) do
                local item = normalizeBrowseItem(raw, i, marketStyle, marketIconDefaults.Models)
                if item then table.insert(items, item) end
            end
            state.Items = items
            state.Selected = nil
            if autoCategories then
                setCategories(collectCategories(items))
            end
            applyFilters(false)
        end

        local function setSort(indexOrName)
            local idx = tonumber(indexOrName)
            if not idx then
                for i, mode in ipairs(sortModes) do
                    if string.lower(mode.Name) == string.lower(tostring(indexOrName)) then idx = i break end
                end
            end
            if not idx or not sortModes[idx] then return end
            state.SortIndex = idx
            local mode = sortModes[idx]
            sortLabel.Text = mode.Name
            sortIcon.Image = resolveIcon(mode.Icon)
            tintIcon(sortIcon, mode.Icon, "Accent")
            if remote then state.Page = 1 requestLoad() else applyFilters(false) end
        end

        local function fetchContext()
            return {
                Page = state.Page,
                PageSize = pageSize,
                Query = trimText(state.Query),
                Sort = sortModes[state.SortIndex] and sortModes[state.SortIndex].Name or nil,
                SortIndex = state.SortIndex,
                Category = state.Category,
                Tab = state.Tab,
                Source = source,
                Browse = Browse,
                State = state,
            }
        end

        --[[ Fetch(ctx) may return:
              items                      -> client-side list (filtered/sorted/paged here)
              items, pages, total, err   -> one server page (remote mode is switched on automatically)
            A string result is JSON-decoded. ctx = {Page, PageSize, Query, Sort, Category, Tab, Source, Browse} ]]
        local loadToken = 0
        local function load(newSource)
            if newSource ~= nil then source = newSource end
            if not source and not fetcher then
                return false
            end
            loadToken = loadToken + 1
            local token = loadToken
            state.Loading = true
            setStatus("Loading...")
            local ctx = fetchContext()
            task.spawn(function()
                local ok, result, pages, total, fetchErr = pcall(function()
                    if fetcher then
                        local out, outPages, outTotal, outErr = fetcher(ctx)
                        if type(out) == "string" then
                            out = HttpService:JSONDecode(out)
                        end
                        if out == nil and outErr ~= nil then error(tostring(outErr)) end
                        return out, outPages, outTotal, outErr
                    end
                    local body, err = httpGet(tostring(source))
                    if not body then error(err or "request failed") end
                    local ok2, decoded = pcall(HttpService.JSONDecode, HttpService, body)
                    if not ok2 then error("invalid JSON from " .. tostring(source)) end
                    return decoded
                end)
                if token ~= loadToken or isClosed then return end
                state.Loading = false
                if ok then
                    if parse then
                        local okParse, parsed = pcall(parse, result, ctx)
                        if okParse and parsed ~= nil then
                            result = parsed
                        end
                    end
                    if pages ~= nil and tonumber(pages) then
                        remote = true
                        state.RemotePages = tonumber(pages)
                        state.Total = tonumber(total)
                    end
                    if remote then
                        state.Items = {}
                        for i, raw in ipairs(extractBrowseList(result)) do
                            local item = normalizeBrowseItem(raw, (ctx.Page - 1) * pageSize + i, marketStyle, marketIconDefaults.Models)
                            if item then table.insert(state.Items, item) end
                        end
                        if autoCategories then setCategories(collectCategories(state.Items)) end
                        applyFilters(true)
                    else
                        setItems(result)
                    end
                    if opts.OnLoad then task.spawn(opts.OnLoad, state.Items, ctx) end
                else
                    -- keep whatever is already shown (e.g. `Items` passed as a fallback)
                    if #state.Items == 0 then
                        setStatus("Failed to load")
                    else
                        applyFilters(true)
                    end
                    Notify({
                        Title = opts.Name or "Browse",
                        Content = "Failed to load: " .. tostring(result),
                        Icon = "alert-triangle",
                        Duration = 4,
                    })
                    if opts.OnError then task.spawn(opts.OnError, result) end
                end
            end)
            return true
        end
        requestLoad = function() load() end

        -- wiring -------------------------------------------------------------------
        local searchDebounce = 0
        searchInput:GetPropertyChangedSignal("Text"):Connect(function()
            searchDebounce = searchDebounce + 1
            local id = searchDebounce
            state.Query = searchInput.Text
            task.delay(remote and 0.4 or 0.15, function()
                if id ~= searchDebounce or isClosed then return end
                if remote then state.Page = 1 requestLoad() else applyFilters(false) end
            end)
        end)

        local sortPopup
        local function toggleSortPopup()
            if sortPopup and sortPopup.Parent then
                sortPopup:Destroy()
                sortPopup = nil
                return
            end
            closeAllPopups()
            local popup = Instance.new("Frame")
            popup.Name = "BrowseSortMenu"
            popup.Size = UDim2.new(0, sortW, 0, 0)
            popup.AutomaticSize = Enum.AutomaticSize.Y
            popup.Position = UDim2.fromOffset(SortBtn.AbsolutePosition.X, SortBtn.AbsolutePosition.Y + SortBtn.AbsoluteSize.Y + 4)
            bindColor(popup, "BackgroundColor3", "PopupBg")
            popup.BorderSizePixel = 0
            popup.ZIndex = 140
            scalePopup(popup)
            popup.Parent = ScreenGui
            if host and host.Scale then
                local popupScale = popup:FindFirstChildOfClass("UIScale")
                if popupScale then
                    popupScale.Scale = host.Scale.Scale
                    local scaleConnection
                    scaleConnection = host.Scale:GetPropertyChangedSignal("Scale"):Connect(function()
                        if popup.Parent then
                            popupScale.Scale = host.Scale.Scale
                        elseif scaleConnection then
                            scaleConnection:Disconnect()
                        end
                    end)
                    popup.Destroying:Connect(function()
                        if scaleConnection then scaleConnection:Disconnect() end
                    end)
                end
            end
            addCorner(popup, 8)
            addStroke(popup, 1)
            local pad = Instance.new("UIPadding")
            pad.PaddingTop = UDim.new(0, 4)
            pad.PaddingBottom = UDim.new(0, 4)
            pad.PaddingLeft = UDim.new(0, 4)
            pad.PaddingRight = UDim.new(0, 4)
            pad.Parent = popup
            local layout = Instance.new("UIListLayout")
            layout.SortOrder = Enum.SortOrder.LayoutOrder
            layout.Padding = UDim.new(0, 2)
            layout.Parent = popup
            for i, mode in ipairs(sortModes) do
                local option = Instance.new("TextButton")
                option.Size = UDim2.new(1, 0, 0, 28)
                option.LayoutOrder = i
                option.BorderSizePixel = 0
                option.Text = ""
                option.AutoButtonColor = false
                option.ZIndex = 141
                option.Parent = popup
                addCorner(option, 5)
                bindColor(option, "BackgroundColor3", i == state.SortIndex and "SidebarActive" or "PopupBg")
                option.BackgroundTransparency = i == state.SortIndex and 0 or 1
                local icon = Instance.new("ImageLabel")
                icon.Size = UDim2.new(0, 13, 0, 13)
                icon.Position = UDim2.new(0, 8, 0.5, -6.5)
                icon.BackgroundTransparency = 1
                icon.Image = resolveIcon(mode.Icon)
                tintIcon(icon, mode.Icon, i == state.SortIndex and "Accent" or "TextMuted")
                icon.ZIndex = 142
                icon.Parent = option
                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, -30, 1, 0)
                label.Position = UDim2.new(0, 28, 0, 0)
                label.BackgroundTransparency = 1
                label.Text = mode.Name
                label.Font = i == state.SortIndex and Enum.Font.GothamBold or Enum.Font.GothamMedium
                label.TextSize = 10.5
                label.TextXAlignment = Enum.TextXAlignment.Left
                bindColor(label, "TextColor3", i == state.SortIndex and "TextPrimary" or "TextMuted")
                label.ZIndex = 142
                label.Parent = option
                option.MouseEnter:Connect(function()
                    option.BackgroundTransparency = 0
                    tweenColors(label, TWEEN_FAST, {TextColor3 = "TextPrimary"}):Play()
                end)
                option.MouseLeave:Connect(function()
                    option.BackgroundTransparency = i == state.SortIndex and 0 or 1
                    bindColor(label, "TextColor3", i == state.SortIndex and "TextPrimary" or "TextMuted")
                end)
                option.MouseButton1Click:Connect(function()
                    setSort(i)
                    if popup.Parent then popup:Destroy() end
                    sortPopup = nil
                end)
            end
            trackPopup(popup, SortBtn)
            sortPopup = popup
        end

        SortBtn.MouseButton1Click:Connect(function()
            if marketStyle then
                toggleSortPopup()
            else
                local nextIdx = state.SortIndex % #sortModes + 1
                setSort(nextIdx)
            end
        end)

        RefreshBtn.MouseButton1Click:Connect(function()
            TweenService:Create(refreshIcon, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {Rotation = refreshIcon.Rotation + 360}):Play()
            if not load() then
                applyFilters(true)
            end
            if opts.OnRefresh then task.spawn(opts.OnRefresh) end
        end)

        local function setPage(n)
            n = math.floor(tonumber(n) or 1)
            n = math.clamp(n, 1, state.Pages)
            if remote then
                if n == state.Page and not state.Loading then return end
                state.Page = n
                requestLoad()
            else
                state.Page = n
                renderPage()
            end
        end

        local setTab -- source tabs ("All / Tab 1 / Tab 2")
        local tabButtons = {}
        if #sourceTabs > 0 then
            local segHost = (host and host.TabsParent) or Toolbar
            local seg = Instance.new("Frame")
            seg.Name = "SourceTabs"
            seg.Size = UDim2.new(0, 0, 1, 0)
            seg.AutomaticSize = Enum.AutomaticSize.X
            bindColor(seg, "BackgroundColor3", "BadgeBg")
            seg.BorderSizePixel = 0
            seg.ZIndex = 4
            seg.Parent = segHost
            addCorner(seg, 8)
            addStroke(seg, 1)
            local segPad = Instance.new("UIPadding")
            segPad.PaddingLeft = UDim.new(0, 3)
            segPad.PaddingRight = UDim.new(0, 3)
            segPad.PaddingTop = UDim.new(0, 3)
            segPad.PaddingBottom = UDim.new(0, 3)
            segPad.Parent = seg
            local segLayout = Instance.new("UIListLayout")
            segLayout.FillDirection = Enum.FillDirection.Horizontal
            segLayout.SortOrder = Enum.SortOrder.LayoutOrder
            segLayout.VerticalAlignment = Enum.VerticalAlignment.Center
            segLayout.Padding = UDim.new(0, 2)
            segLayout.Parent = seg
            if segHost == Toolbar then
                seg.Position = UDim2.new(1, -(rightW + 6), 0, 0)
                seg.AnchorPoint = Vector2.new(1, 0)
                seg:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                    SearchFrame.Size = UDim2.new(1, -(rightW + 14 + seg.AbsoluteSize.X / panelScale()), 1, 0)
                end)
            end
            for i, t in ipairs(sourceTabs) do
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(0, 0, 1, 0)
                b.AutomaticSize = Enum.AutomaticSize.X
                b.LayoutOrder = i
                b.BorderSizePixel = 0
                b.Text = ""
                b.AutoButtonColor = false
                b.ZIndex = 5
                b.Parent = seg
                addCorner(b, 6)
                local bp = Instance.new("UIPadding")
                bp.PaddingLeft = UDim.new(0, 10)
                bp.PaddingRight = UDim.new(0, 10)
                bp.Parent = b
                local l = Instance.new("TextLabel")
                l.Size = UDim2.new(0, 0, 1, 0)
                l.AutomaticSize = Enum.AutomaticSize.X
                l.BackgroundTransparency = 1
                l.Text = t.Name
                l.Font = Enum.Font.GothamBold
                l.TextSize = 10.5
                l.ZIndex = 6
                l.Parent = b
                local entry = {Button = b, Label = l, Tab = t}
                local active = (state.Tab == t.Id)
                bindColor(b, "BackgroundColor3", active and "Accent" or "BadgeBg")
                b.BackgroundTransparency = active and 0 or 1
                bindColor(l, "TextColor3", active and "KnobOn" or "TextMuted")
                b.MouseButton1Click:Connect(function() setTab(t.Id) end)
                b.MouseEnter:Connect(function() if state.Tab ~= t.Id then tweenColors(l, TWEEN_FAST, {TextColor3 = "TextPrimary"}):Play() end end)
                b.MouseLeave:Connect(function() if state.Tab ~= t.Id then tweenColors(l, TWEEN_FAST, {TextColor3 = "TextMuted"}):Play() end end)
                table.insert(tabButtons, entry)
            end
        end
        setTab = function(id)
            for _, entry in ipairs(tabButtons) do
                local active = (entry.Tab.Id == id)
                tweenColors(entry.Button, TWEEN_FAST, {BackgroundColor3 = active and "Accent" or "BadgeBg", BackgroundTransparency = active and 0 or 1}):Play()
                tweenColors(entry.Label, TWEEN_FAST, {TextColor3 = active and "KnobOn" or "TextMuted"}):Play()
            end
            if state.Tab == id then return end
            state.Tab = id
            if opts.OnTab then task.spawn(opts.OnTab, id, Browse) end
            if fetcher then state.Page = 1 requestLoad() else applyFilters(false) end
        end
        PrevBtn.MouseButton1Click:Connect(function() setPage(state.Page - 1) end)
        NextBtn.MouseButton1Click:Connect(function() setPage(state.Page + 1) end)

        -- initial data
        if not autoCategories then
            setCategories(opts.Categories)
        else
            rebuildChips()
        end
        if opts.Sort then setSort(opts.Sort) end
        if opts.Items then
            setItems(opts.Items)
        else
            applyFilters(false)
        end
        local loadedOnce = false
        local function ensureLoaded()
            if loadedOnce then return end
            loadedOnce = true
            load()
        end

        local function onShown()
            updateCellSize()
            if opts.Lazy ~= false then ensureLoaded() end
        end
        if host then
            host.OnOpen = onShown
            if not host.Window then task.defer(onShown) end -- embedded in a custom frame: always visible
        else
            table.insert(PANEL_LIST, {Frame = Panel, Tab = tabName, OnShow = onShown})
        end
        if opts.Lazy == false then
            task.spawn(ensureLoaded)
        end

        -- public handle ------------------------------------------------------------
        Browse.Panel = Panel
        Browse.Host = host
        function Browse:SetTab(id) setTab(id) end
        function Browse:GetTab() return state.Tab end
        function Browse:SetTotal(n) state.Total = tonumber(n) if host and host.SetCount then host.SetCount(state.Total) end end
        function Browse:GetTotal() return state.Total or #state.Items end
        function Browse:SetRemote(on) remote = on and true or false end
        function Browse:IsRemote() return remote end
        function Browse:GetState() return state end
        function Browse:ShowDetails(item, overrides) return showDetails(item or state.Selected, overrides) end
        function Browse:CloseDetails() closeActiveDialog() end
        function Browse:SetDetails(details) detailsOpt = details end
        function Browse:AddCardButton(def)
            if not marketStyle then return nil end
            if type(def) == "string" then def = {Text = def} end
            if type(def) ~= "table" then return nil end
            table.insert(cardActionDefs, def)
            for _, entry in ipairs(cardPool) do
                if entry.RefreshActions then entry.RefreshActions() end
            end
            return def
        end
        function Browse:AddCardHStack(defs)
            local added = {}
            for _, def in ipairs(browseArray(defs)) do
                local button = self:AddCardButton(def)
                if button then table.insert(added, button) end
            end
            return added
        end
        function Browse:SetCardButtons(defs)
            if not marketStyle then return end
            cardActionDefs = {}
            for _, def in ipairs(browseArray(defs)) do
                if type(def) == "string" then def = {Text = def} end
                if type(def) == "table" then table.insert(cardActionDefs, def) end
            end
            for _, entry in ipairs(cardPool) do
                if entry.RefreshActions then entry.RefreshActions() end
            end
        end
        Browse.AddButton = Browse.AddCardButton
        Browse.AddHStack = Browse.AddCardHStack
        function Browse:SetItems(list) setItems(list or {}) end
        function Browse:AddItem(raw)
            local item = normalizeBrowseItem(raw, #state.Items + 1, marketStyle, marketIconDefaults.Models)
            if not item then return end
            table.insert(state.Items, item)
            if autoCategories then setCategories(collectCategories(state.Items)) end
            applyFilters(true)
            return item
        end
        function Browse:RemoveItem(idOrItem)
            for i, item in ipairs(state.Items) do
                if item == idOrItem or item.Id == idOrItem then
                    table.remove(state.Items, i)
                    break
                end
            end
            applyFilters(true)
        end
        function Browse:GetItems() return state.Items end
        function Browse:GetFiltered() return state.Filtered end
        function Browse:GetSelected() return state.Selected end
        function Browse:Load(url) loadedOnce = true return load(url) end
        function Browse:Refresh()
            loadedOnce = true
            if not load() then applyFilters(true) end
        end
        function Browse:SetSource(url) source = url end
        function Browse:SetCategories(list) autoCategories = false setCategories(list) applyFilters(false) end
        function Browse:SetCategory(name) setCategory(name) end
        function Browse:GetCategory() return state.Category end
        function Browse:Search(text)
            searchInput.Text = tostring(text or "")
        end
        function Browse:GetQuery() return state.Query end
        function Browse:SetSort(mode) setSort(mode) end
        function Browse:GetSort() return sortModes[state.SortIndex].Name end
        function Browse:SetPage(n) setPage(n) end
        function Browse:GetPage() return state.Page, state.Pages end
        function Browse:NextPage() setPage(state.Page + 1) end
        function Browse:PrevPage() setPage(state.Page - 1) end
        function Browse:SetCallback(fn) callback = fn end
        function Browse:SetStatus(text) setStatus(text) end
        function Browse:IsLoading() return state.Loading end
        Browse.Reload = Browse.Refresh
        Browse.Filter = Browse.SetCategory
        Browse.OnSelect = Browse.SetCallback
        return Browse
    end

    --[[ Standalone Browse window: the same gallery panel inside its own
        draggable window (header with logo, title, counter, source tabs and a
        close button). Opened from code: Browse:Open() / Close() / Toggle(). ]]
    local function createBrowseWindow(opts)
        opts = opts or {}
        local viewport = getViewportSize()
        local mobile = opts.Mobile == nil and isMobileDevice(viewport) or opts.Mobile == true
        local initialScale = math.max(UI_SCALE, 0.01)
        local margin = mobile and 12 or 24
        local requestedWidth = tonumber(opts.Width) or 620
        local requestedHeight = tonumber(opts.Height) or 470
        local availableWidth = math.max(180, (viewport.X - margin * 2) / initialScale)
        local availableHeight = math.max(180, (viewport.Y - margin * 2) / initialScale)
        local width = math.min(requestedWidth, availableWidth)
        local height = math.min(requestedHeight, availableHeight)
        local HEADER_H = 50

        local Win = Instance.new("Frame")
        Win.Name = opts.Browsec and "BrowsecWindow" or "BrowseWindow"
        Win.Size = UDim2.new(0, width, 0, height)
        Win.AnchorPoint = Vector2.new(0.5, 0.5)
        Win.Position = opts.Position or UDim2.new(0.5, 0, 0.5, 0)
        bindColor(Win, "BackgroundColor3", "Background")
        Win.BorderSizePixel = 0
        Win.Active = true
        Win.ClipsDescendants = true
        Win.Visible = false
        Win.ZIndex = 120
        Win.Parent = ScreenGui
        FLOATING_FRAMES[Win] = true
        local winScale = Instance.new("UIScale")
        winScale.Scale = UI_SCALE
        winScale.Parent = Win
        addCorner(Win, 12)
        local winStroke = addStroke(Win, 1.2)
        winStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        local header = Instance.new("Frame")
        header.Size = UDim2.new(1, 0, 0, HEADER_H)
        header.BackgroundTransparency = 1
        header.ZIndex = 121
        header.Parent = Win

        local headerLine = Instance.new("Frame")
        headerLine.Size = UDim2.new(1, -24, 0, 1)
        headerLine.Position = UDim2.new(0, 12, 0, HEADER_H - 1)
        bindColor(headerLine, "BackgroundColor3", "Divider")
        headerLine.BorderSizePixel = 0
        headerLine.ZIndex = 121
        headerLine.Parent = Win

        local logo = Instance.new("ImageLabel")
        logo.Size = UDim2.new(0, 26, 0, 26)
        logo.Position = UDim2.new(0, 12, 0, 12)
        logo.BackgroundTransparency = 1
        logo.ZIndex = 122
        logo.Parent = header
        local iconName = opts.Icon
        if opts.Logo == false or (iconName and (LUCIDE[iconName] or CUSTOM_ICON_DATA[iconName])) then
            logo.Image = resolveIcon(iconName or "store")
            tintIcon(logo, iconName or "store", "Accent")
        elseif LOGO_ASSET and LOGO_ASSET ~= "" then
            logo.Image = LOGO_ASSET
        else
            logo.Image = resolveIcon("store")
            tintIcon(logo, "store", "Accent")
        end

        local brandRow = Instance.new("Frame")
        brandRow.Size = UDim2.new(1, -200, 0, 18)
        brandRow.Position = UDim2.new(0, 46, 0, 8)
        brandRow.BackgroundTransparency = 1
        brandRow.ZIndex = 122
        brandRow.Parent = header
        local brandLayout = Instance.new("UIListLayout")
        brandLayout.FillDirection = Enum.FillDirection.Horizontal
        brandLayout.SortOrder = Enum.SortOrder.LayoutOrder
        brandLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        brandLayout.Padding = UDim.new(0, 8)
        brandLayout.Parent = brandRow

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(0, 0, 1, 0)
        title.AutomaticSize = Enum.AutomaticSize.X
        title.LayoutOrder = 1
        title.BackgroundTransparency = 1
        title.Text = tostring(opts.Title or opts.Name or "Browse")
        title.Font = Enum.Font.GothamBold
        title.TextSize = 13
        bindColor(title, "TextColor3", "TextPrimary")
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.ZIndex = 122
        title.Parent = brandRow

        local countPill = Instance.new("Frame")
        countPill.Size = UDim2.new(0, 0, 0, 16)
        countPill.AutomaticSize = Enum.AutomaticSize.X
        countPill.LayoutOrder = 2
        bindColor(countPill, "BackgroundColor3", "VersionBg")
        countPill.BorderSizePixel = 0
        countPill.Visible = false
        countPill.ZIndex = 122
        countPill.Parent = brandRow
        addCorner(countPill, 8)
        local cpPad = Instance.new("UIPadding")
        cpPad.PaddingLeft = UDim.new(0, 7)
        cpPad.PaddingRight = UDim.new(0, 7)
        cpPad.Parent = countPill
        local countText = Instance.new("TextLabel")
        countText.Size = UDim2.new(0, 0, 1, 0)
        countText.AutomaticSize = Enum.AutomaticSize.X
        countText.BackgroundTransparency = 1
        countText.Text = ""
        countText.Font = Enum.Font.GothamBold
        countText.TextSize = 10
        bindColor(countText, "TextColor3", "KnobOn")
        countText.ZIndex = 123
        countText.Parent = countPill

        local subtitle = Instance.new("TextLabel")
        subtitle.Size = UDim2.new(1, -200, 0, 12)
        subtitle.Position = UDim2.new(0, 46, 0, 27)
        subtitle.BackgroundTransparency = 1
        subtitle.Text = tostring(opts.Description or opts.Subtitle or "Gallery")
        subtitle.Font = Enum.Font.Gotham
        subtitle.TextSize = 9
        bindColor(subtitle, "TextColor3", "TextMuted")
        subtitle.TextXAlignment = Enum.TextXAlignment.Left
        subtitle.ZIndex = 122
        subtitle.Parent = header

        local headerRight = Instance.new("Frame")
        headerRight.Size = UDim2.new(0, 0, 0, 28)
        headerRight.AutomaticSize = Enum.AutomaticSize.X
        headerRight.AnchorPoint = Vector2.new(1, 0.5)
        headerRight.Position = UDim2.new(1, -12, 0, HEADER_H / 2)
        headerRight.BackgroundTransparency = 1
        headerRight.ZIndex = 122
        headerRight.Parent = header
        local hrLayout = Instance.new("UIListLayout")
        hrLayout.FillDirection = Enum.FillDirection.Horizontal
        hrLayout.SortOrder = Enum.SortOrder.LayoutOrder
        hrLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        hrLayout.Padding = UDim.new(0, 8)
        hrLayout.Parent = headerRight

        local closeBtn = Instance.new("ImageButton")
        closeBtn.Size = UDim2.new(0, 26, 0, 26)
        closeBtn.LayoutOrder = 99
        bindColor(closeBtn, "BackgroundColor3", "BadgeBg")
        closeBtn.BorderSizePixel = 0
        closeBtn.AutoButtonColor = false
        closeBtn.Image = ""
        closeBtn.ZIndex = 123
        closeBtn.Parent = headerRight
        addCorner(closeBtn, 7)
        addStroke(closeBtn, 1)
        local closeIcon = Instance.new("ImageLabel")
        closeIcon.Size = UDim2.new(0, 12, 0, 12)
        closeIcon.Position = UDim2.new(0.5, -6, 0.5, -6)
        closeIcon.BackgroundTransparency = 1
        closeIcon.Image = resolveIcon("x")
        tintIcon(closeIcon, "x", "TextMuted")
        closeIcon.ZIndex = 124
        closeIcon.Parent = closeBtn
        closeBtn.MouseEnter:Connect(function() tweenColors(closeIcon, TWEEN_FAST, {ImageColor3 = "Accent"}):Play() end)
        closeBtn.MouseLeave:Connect(function() tweenColors(closeIcon, TWEEN_FAST, {ImageColor3 = "TextMuted"}):Play() end)

        local content = Instance.new("Frame")
        content.Name = "Content"
        content.Size = UDim2.new(1, -20, 1, -(HEADER_H + 8))
        content.Position = UDim2.new(0, 10, 0, HEADER_H + 2)
        content.BackgroundTransparency = 1
        content.ClipsDescendants = true
        content.ZIndex = 121
        content.Parent = Win

        --[[ Resize grip (bottom-right corner). Hold Shift while dragging to
            resize the frame without scaling its contents. Touch input uses the
            same size-only path; mobile windows get smaller minimum dimensions. ]]
        local minW = tonumber(opts.MinWidth) or (mobile and 250 or 420)
        local minH = tonumber(opts.MinHeight) or (mobile and 200 or 300)
        if mobile then
            minW = math.min(minW, math.max(200, math.floor(availableWidth * 0.75)))
            minH = math.min(minH, math.max(180, math.floor(availableHeight * 0.55)))
        end
        minW = math.min(minW, width)
        minH = math.min(minH, height)
        local scaleMode = string.lower(tostring(opts.ResizeMode or "scale")) ~= "size"
        local SCALE_MIN, SCALE_MAX = 0.6, 2.0
        local function fitWindowSize(w, h)
            local scale = math.max(winScale.Scale, 0.01)
            local currentViewport = getViewportSize()
            local currentMargin = mobile and 12 or 24
            local maxW = math.max(minW, (currentViewport.X - currentMargin * 2) / scale)
            local maxH = math.max(minH, (currentViewport.Y - currentMargin * 2) / scale)
            return math.clamp(tonumber(w) or width, minW, maxW), math.clamp(tonumber(h) or height, minH, maxH)
        end
        if opts.Resizable ~= false then
            local grip = Instance.new("TextButton")
            grip.Name = "ResizeHandle"
            local gripSize = mobile and 32 or 24
            grip.Size = UDim2.new(0, gripSize, 0, gripSize)
            grip.Position = UDim2.new(1, -gripSize, 1, -gripSize)
            grip.BackgroundTransparency = 1
            grip.Text = ""
            grip.AutoButtonColor = false
            grip.ZIndex = 130
            grip.Parent = Win

            local lines = {}
            for i, spec in ipairs({{-4, -4, 14}, {-4, -8, 8}}) do
                local line = Instance.new("Frame")
                line.Size = UDim2.new(0, spec[3], 0, 1)
                line.Position = UDim2.new(1, spec[1], 1, spec[2])
                line.AnchorPoint = Vector2.new(1, 1)
                bindColor(line, "BackgroundColor3", "TextDim")
                line.BorderSizePixel = 0
                line.ZIndex = 131
                line.Parent = grip
                addCorner(line, 4)
                lines[i] = line
            end
            grip.MouseEnter:Connect(function()
                for _, l in ipairs(lines) do bindColor(l, "BackgroundColor3", "Accent") end
            end)
            grip.MouseLeave:Connect(function()
                for _, l in ipairs(lines) do bindColor(l, "BackgroundColor3", "TextDim") end
            end)

            local resizing, resizeStart, startPixels, startPos, startScale, activeInputType = false, nil, nil, nil, nil, nil
            local resizeWithoutScale = false
            grip.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1
                    and input.UserInputType ~= Enum.UserInputType.Touch then
                    return
                end
                if activeDialog then return end
                resizing = true
                activeInputType = input.UserInputType
                resizeStart = input.Position
                startScale = winScale.Scale
                resizeWithoutScale = shiftHeld()
                -- size on screen in pixels (Size * scale)
                startPixels = Vector2.new(Win.Size.X.Offset * startScale, Win.Size.Y.Offset * startScale)
                startPos = Win.Position
                closeAllPopups()
            end)
            trackConn(UserInputService.InputChanged:Connect(function(input)
                if not resizing then return end
                if input.UserInputType ~= Enum.UserInputType.MouseMovement
                    and input.UserInputType ~= Enum.UserInputType.Touch then
                    return
                end
                local delta = input.Position - resizeStart
                local currentViewport = getViewportSize()
                local topLeft = Win.AbsolutePosition
                local maxPixelW = math.max(minW * (resizeWithoutScale and startScale or SCALE_MIN), currentViewport.X - topLeft.X - margin)
                local maxPixelH = math.max(minH * (resizeWithoutScale and startScale or SCALE_MIN), currentViewport.Y - topLeft.Y - margin)
                local minScale = resizeWithoutScale and startScale or SCALE_MIN
                local pxW = math.clamp(startPixels.X + delta.X, minW * minScale, maxPixelW)
                local pxH = math.clamp(startPixels.Y + delta.Y, minH * minScale, maxPixelH)
                local scale = startScale
                if scaleMode and not resizeWithoutScale then
                    scale = math.clamp(math.sqrt((pxW / width) * (pxH / height)), SCALE_MIN, SCALE_MAX)
                end
                local newW = math.max(minW, pxW / scale)
                local newH = math.max(minH, pxH / scale)
                winScale.Scale = scale
                Win.Size = UDim2.new(0, newW, 0, newH)
                -- AnchorPoint is the center: shift by half the growth (in pixels) so the top-left stays put
                Win.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + (newW * scale - startPixels.X) / 2,
                    startPos.Y.Scale, startPos.Y.Offset + (newH * scale - startPixels.Y) / 2)
            end))
            trackConn(UserInputService.InputEnded:Connect(function(input)
                local ended = (activeInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)
                    or (activeInputType == Enum.UserInputType.Touch and input.UserInputType == Enum.UserInputType.Touch)
                if ended then
                    if resizing and opts.OnResize then
                        task.spawn(opts.OnResize, Win.Size.X.Offset, Win.Size.Y.Offset)
                    end
                    resizing = false
                    activeInputType = nil
                end
            end))
        end

        -- the panel uses ZIndex 3..8 internally; lift everything above the window chrome
        local host = {Parent = content, Window = Win, TabsParent = headerRight, Scale = winScale, Mobile = mobile}
        local entry = {Frame = Win, Scale = winScale, HiddenWithUI = false}
        table.insert(BROWSE_WINDOWS, entry)

        function host.SetCount(n)
            n = tonumber(n)
            if not n then countPill.Visible = false return end
            local str = tostring(math.floor(n))
            -- 7960 -> "7 960"
            str = string.reverse((string.gsub(string.reverse(str), "(%d%d%d)", "%1 ")))
            str = (string.gsub(str, "^%s+", ""))
            countText.Text = str
            countPill.Visible = true
        end

        do -- drag (ignored while a modal dialog is open above the window)
            local dragging, dragStart, startPos = false, nil, nil
            header.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    if activeDialog then return end
                    dragging = true
                    dragStart = input.Position
                    startPos = Win.Position
                end
            end)
            trackConn(UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    local delta = input.Position - dragStart
                    Win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                end
            end))
            trackConn(UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end))
        end

        local api = {}
        function api.IsOpen() return Win.Visible end
        function api.Open()
            if Win.Visible then return end
            local fittedW, fittedH = fitWindowSize(Win.Size.X.Offset, Win.Size.Y.Offset)
            Win.Size = UDim2.new(0, fittedW, 0, fittedH)
            entry.HiddenWithUI = false
            Win.Visible = true
            local target = Win.Position
            Win.Position = target + UDim2.fromOffset(0, 24)
            TweenService:Create(Win, TWEEN_SLOW, {Position = target}):Play()
            if host.OnOpen then task.spawn(host.OnOpen) end
            if opts.OnOpen then task.spawn(opts.OnOpen) end
        end
        function api.Close()
            if not Win.Visible then return end
            Win.Visible = false
            entry.HiddenWithUI = false
            if opts.Browsec == true or opts.MarketStyle == true then closeAllPopups() end
            closeActiveDialog()
            if opts.OnClose then task.spawn(opts.OnClose) end
        end
        function api.Toggle(visible)
            if visible == nil then visible = not Win.Visible end
            if visible then api.Open() else api.Close() end
        end
        function api.SetTitle(text) title.Text = tostring(text) end
        function api.SetDescription(text) subtitle.Text = tostring(text) end
        function api.SetCount(n) host.SetCount(n) end
        function api.SetPosition(pos) Win.Position = pos end
        function api.SetSize(w, h)
            local fittedW, fittedH = fitWindowSize(w, h)
            Win.Size = UDim2.new(0, fittedW, 0, fittedH)
        end
        function api.GetSize() return Win.Size.X.Offset, Win.Size.Y.Offset end
        function api.SetScale(scale)
            winScale.Scale = math.clamp(tonumber(scale) or 1, SCALE_MIN, SCALE_MAX)
            local fittedW, fittedH = fitWindowSize(Win.Size.X.Offset, Win.Size.Y.Offset)
            Win.Size = UDim2.new(0, fittedW, 0, fittedH)
        end
        function api.GetScale() return winScale.Scale end
        function api.IsMobile() return mobile end
        api.Frame = Win
        api.Host = host
        closeBtn.MouseButton1Click:Connect(api.Close)

        if opts.ToggleKey then
            trackConn(UserInputService.InputBegan:Connect(function(input, gp)
                if gp or isClosed then return end
                if input.KeyCode == opts.ToggleKey then api.Toggle() end
            end))
        end
        return api, host
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

    kbToggleHandle = addToggle(cardSettings, "Keybind List", "Show the on-screen keybind overlay", kbVisible, function(value)
        if kbApplyingVisible then return end
        setKeybindListVisible(value, true)
    end)

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
            for _, bw in ipairs(BROWSE_WINDOWS) do
                if bw.HiddenWithUI then
                    bw.HiddenWithUI = false
                    bw.Frame.Visible = true
                end
            end
            Main.Position = lastMainPosition + UDim2.fromOffset(0, 30)
            TweenService:Create(Main, TWEEN_SLOW, {Position = lastMainPosition}):Play()
        else
            lastMainPosition = Main.Position
            closeAllPopups()
            closeActiveDialog()
            for _, bw in ipairs(BROWSE_WINDOWS) do
                if bw.Frame.Visible then
                    bw.HiddenWithUI = true
                    bw.Frame.Visible = false
                end
            end
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
        if DialogGui then DialogGui:Destroy() end
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
        Window.IsMobile = INITIAL_MOBILE
        Window.Mobile = INITIAL_MOBILE

        local colOrders = {0, 0}

        local function resolveTabIcon(icon)
            if icon == nil then
                return ICONS.Misc
            end
            if type(icon) == "string" then
                if LUCIDE[icon] or CUSTOM_ICON_DATA[icon] then
                    return resolveIcon(icon)
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

                -- 3D icon options shared by buttons and dropdown controls
                local function iconExtra(o, list)
                    local flag = o.Icons3D
                    if flag == nil then flag = o["3DIcons"] end
                    if flag == nil then flag = o.ViewportIcons end
                    if flag == nil then
                        -- auto-enable when a model source or any option carries a model
                        if o.Models ~= nil then
                            flag = true
                        else
                            for _, v in ipairs(list) do
                                if type(v) == "table" and (v.Model ~= nil or v.Icon3D ~= nil
                                    or v.Model3D ~= nil or v.Instance ~= nil or typeof(v.Icon) == "Instance") then
                                    flag = true
                                    break
                                end
                            end
                        end
                    end
                    if not flag then return nil end
                    local cfg = o.Icon3D or o.Viewport or o.IconConfig
                    if type(flag) == "table" then cfg = flag end
                    if type(flag) == "number" then cfg = {Size = flag} end
                    return {
                        Icons3D = true,
                        Icon3D = cfg,
                        IconSize = o.IconSize or o.Icon3DSize or o.ViewportSize,
                        Models = o.Models,
                    }
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
                    local buttons = o.Buttons or o.Value or {}
                    return addButtonRow(body, o.Name or o.Title or "",
                        descOf(o), buttons, iconExtra(o, buttons))
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
                    local buttonDefinition = {}
                    for key, value in pairs(o) do
                        buttonDefinition[key] = value
                    end
                    buttonDefinition.Text = o.Text or name
                    local created = addButtonRow(body, name, descOf(o), {
                        buttonDefinition,
                    }, iconExtra(o, {buttonDefinition}))
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
                        descOf(dOpts), list, defIdx, flagCallback(dOpts.Flag, dOpts.Callback),
                        iconExtra(dOpts, list))
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
                        flagCallback(mOpts.Flag, mOpts.Callback, transform),
                        iconExtra(mOpts, list))
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
                    return wrapHandle({
                        Box = input,
                        Set = function(v)
                            input.Text = tostring(v)
                            if wrapped then wrapped(input.Text) end
                        end,
                        Get = function() return input.Text end,
                    })
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
                    local showInOverlay = kOpts.Overlay ~= false and kOpts.ShowInOverlay ~= false
                    return addKeybind(body, kOpts.Name or kOpts.Title or "Keybind",
                        descOf(kOpts), tostring(default), flagCallback(kOpts.Flag, kOpts.Callback), {
                            Id = kOpts.Flag,
                            Show = showInOverlay,
                            DisplayName = kOpts.OverlayName,
                        })
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

        --[[ Browse tab: a full-width gallery (search, category chips, sort,
            pagination, grid of cards). Items can be a table, a loader function
            or a JSON API url, so one script serves every user. ]]
        --[[ Browse in its own window (no sidebar tab). Returns the same Browse
            handle plus Open / Close / Toggle / IsOpen / SetTitle / SetCount.
            Opens on Browse:Open(), e.g. from a button or toggle, or on `ToggleKey`;
            `Visible = true` opens it right away. ]]
        function Window:CreateBrowseWindow(browseOptions)
            local bOpts = type(browseOptions) == "table" and browseOptions or {Name = tostring(browseOptions or "Browse")}
            local win, host = createBrowseWindow(bOpts)
            local browse = buildBrowsePanel(nil, bOpts, host)
            browse.Window = win
            browse.Name = bOpts.Name or bOpts.Title or "Browse"
            browse.Mode = "Window"
            function browse:Open() win.Open() end
            function browse:Close() win.Close() end
            function browse:Toggle(visible) win.Toggle(visible) end
            function browse:IsOpen() return win.IsOpen() end
            function browse:Select() win.Open() end
            function browse:SetTitle(text) win.SetTitle(text) end
            function browse:SetDescription(text) win.SetDescription(text) end
            function browse:SetCount(n) win.SetCount(n) end
            function browse:SetPosition(pos) win.SetPosition(pos) end
            function browse:SetSize(w, h) win.SetSize(w, h) end
            function browse:GetSize() return win.GetSize() end
            function browse:SetScale(scale) win.SetScale(scale) end
            function browse:GetScale() return win.GetScale() end
            function browse:IsMobile() return win.IsMobile() end
            browse.Mobile = host.Mobile
            browse.Show = browse.Open
            browse.Hide = browse.Close
            if bOpts.Visible == true or bOpts.Open == true then
                task.defer(win.Open)
            end
            return browse
        end
        Window.CreateBrowsePopup = Window.CreateBrowseWindow
        Window.CreateGalleryWindow = Window.CreateBrowseWindow

        --[[ Separate File Market / Browsec window. This intentionally has its
            own card actions and detail layout; the existing Browse window and
            sidebar gallery keep their original appearance. ]]
        function Window:CreateBrowsec(browsecOptions)
            local source = type(browsecOptions) == "table" and browsecOptions or {Name = tostring(browsecOptions or "File Market")}
            local bOpts = {}
            for key, value in pairs(source) do bOpts[key] = value end
            bOpts.Browsec = true
            bOpts.Name = bOpts.Name or bOpts.Title or "File Market"
            bOpts.Description = bOpts.Description or bOpts.Subtitle or "Community builds and files"
            bOpts.Icon = bOpts.Icon or "shopping-bag"
            bOpts.Width = tonumber(bOpts.Width) or 920
            bOpts.Height = tonumber(bOpts.Height) or 620
            bOpts.Columns = tonumber(bOpts.Columns) or 3
            bOpts.PageSize = tonumber(bOpts.PageSize) or 12
            bOpts.SearchPlaceholder = bOpts.SearchPlaceholder or "Search builds..."
            bOpts.SortModes = bOpts.SortModes or bOpts.Sorts or {"Newest", "Most downloaded", "Most popular"}
            bOpts.Sort = bOpts.Sort or "Most downloaded"
            bOpts.PlaceholderIcon = bOpts.PlaceholderIcon or "cube3d"
            if bOpts.Details == nil and bOpts.Dialog == nil then bOpts.Details = true end
            local market = Window:CreateBrowseWindow(bOpts)
            market.Mode = "Browsec"
            market.Name = bOpts.Name
            return market
        end
        Window.CreateBrowsecWindow = Window.CreateBrowsec
        Window.CreateFileMarket = Window.CreateBrowsec

        function Window:CreateBrowseTab(browseOptions, iconMaybe)
            local bOpts = {}
            if type(browseOptions) == "string" then
                bOpts.Name = browseOptions
                bOpts.Icon = iconMaybe
            elseif type(browseOptions) == "table" then
                bOpts = browseOptions
            end
            local mode = string.lower(tostring(bOpts.Mode or bOpts.Type or "tab"))
            if mode == "window" or mode == "popup" or mode == "float" then
                return Window:CreateBrowseWindow(bOpts)
            end
            local tab = Window:CreateTab(bOpts.Name or bOpts.Title or "Browse", bOpts.Icon or "store")
            local browse = buildBrowsePanel(tab.Name, bOpts)
            browse.Tab = tab
            browse.Name = tab.Name
            browse.Mode = "Tab"
            function browse:Select() tab:Select() end
            function browse:Open() tab:Select() end
            function browse:IsOpen() return activeSidebarTab ~= nil and activeSidebarTab.Name == tab.Name end
            if activeSidebarTab then
                showTabContent(activeSidebarTab.Name)
            end
            return browse
        end
        Window.CreateGalleryTab = Window.CreateBrowseTab

        -- Modal dialog: {Title, Images, Tag, Badge, Lines, Buttons, HeaderButtons, Width, OnClose}
        function Window:CreateDialog(dialogOptions)
            return createDialog(dialogOptions)
        end
        Window.Dialog = Window.CreateDialog
        Window.ShowDialog = Window.CreateDialog
        function Window:CloseDialog()
            closeActiveDialog()
        end
        Window.CreateBrowser = Window.CreateBrowseTab
        Window.AddBrowseTab = Window.CreateBrowseTab

        function Window:Notify(opts)
            return Notify(opts)
        end

        function Window:CreateKeybindList(listOptions)
            kbAutoShow = false
            if listOptions == nil or listOptions == true then
                setKeybindListVisible(true)
            elseif listOptions == false then
                setKeybindListVisible(false)
            else
                applyKeybindListOptions(listOptions)
                if type(listOptions) == "table" and listOptions.Visible == nil then
                    setKeybindListVisible(true)
                end
            end
            return KeybindListApi
        end
        Window.AddKeybindList = Window.CreateKeybindList
        Window.KeybindList = Window.CreateKeybindList

        function Window:GetKeybindList()
            return KeybindListApi
        end

        function Window:SetKeybindListVisible(visible)
            setKeybindListVisible(visible)
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

        --[[ Shared internals for companion scripts (MacrOS-style `MacrOSUI.Theme`,
            `MacrOSUI.BindColor`, `MacrOSUI.ResolveIcon`, `MacrOSUI.LogoAsset` ...).
            Everything here is the live object the window itself uses. ]]
        Window.Theme = THEME
        Window.BindColor = bindColor
        Window.TweenColors = tweenColors
        Window.RefreshTheme = refreshTheme
        Window.ResolveIcon = resolveIcon
        Window.CreateViewportIcon = createViewportIcon -- (parent, cfg, zIndex) -> {Frame, SetModel, SetAngle, SetZoom, Destroy}
        Window.Icon3DDefaults = ICON3D_DEFAULTS
        Window.TintIcon = tintIcon
        Window.Icons = LUCIDE
        Window.LogoAsset = LOGO_ASSET
        Window.ScreenGui = ScreenGui
        Window.Main = Main
        Window.HttpGet = httpGet
        Window.CreateBrowsePanel = function(_, parentFrame, bOpts)
            -- gallery panel inside any frame of your own (no tab, no window)
            return buildBrowsePanel(nil, bOpts or {}, {Parent = parentFrame})
        end
        for _, key in ipairs({"Theme", "BindColor", "TweenColors", "RefreshTheme", "ResolveIcon", "TintIcon",
            "Icons", "LogoAsset", "ScreenGui", "Main", "HttpGet"}) do
            Library[key] = Window[key]
        end
        Library.httpGet = httpGet
        Library.Notify = function(opts) return Notify(opts) end
        Library.CreateDialog = function(_, dOpts) return createDialog(type(_) == "table" and _ ~= Library and _ or dOpts) end
        Library.Dialog = Library.CreateDialog
        Library.Window = Window
        Library.GetWindow = function() return Window end

        return Window

    end

    return buildStage2()
end

return Library
