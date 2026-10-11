-- Demo points at the feature branch so it includes the latest overlay behavior.
-- Switch /arena/0c851cbf-test/ to /main/ after the PR is merged.
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/dragonstrukov/MacrOS-Library/main/Library.lua"
))()

local Window = Library:CreateWindow({
    Name = "My Hub",
    Description = "Example script",
    Version = "v1.0",
    FooterText = "made with UI Library",
    ToggleKey = Enum.KeyCode.RightShift,
})

local Keybinds = Window:CreateKeybindList({
    Title = "Keybinds + Status",
    Visible = true,
    Position = UDim2.new(0, 16, 0.32, 0),
})

local actionStatus = Keybinds:AddStatus({ Name = "Actions", Active = false })

local Features = Window:CreateCategory("Features")

local CombatTab = Window:CreateTab("Combat", "zap")
local MoveTab = Window:CreateTab({ Name = "Movement", Icon = "move" })

local Fight = CombatTab:CreateSection("Fighting", 1)
local Target = CombatTab:CreateSection("Target", 2)

local auraKeybind
local aura = Fight:CreateToggle({
    Name = "Attack Aura",
    Description = "Automatically attacks nearby players",
    Default = false,
    Flag = "AttackAura",
    Callback = function(value)
        if auraKeybind then
            auraKeybind:SetActive(value)
        end
        print("Aura:", value)
    end,
})

Fight:CreateSlider({
    Name = "Range",
    Description = "Attack distance in studs",
    Min = 5, Max = 30, Default = 12, Decimals = 0,
    Flag = "AuraRange",
    Callback = function(value)
        print("Range:", value)
    end,
})

Fight:CreateDropdown({
    Name = "Mode",
    Options = { "Legit", "Rage", "Silent" },
    Default = "Legit",
    Flag = "AuraMode",
    Callback = function(text, index)
        print("Mode:", text, index)
    end,
})

Fight:CreateMultiDropdown({
    Name = "Targets",
    Options = { "Players", "NPCs", "Bosses" },
    Default = { "Players" },
    Flag = "AuraTargets",
    Callback = function(picked)
        print("Targets:", table.concat(picked, ", "))
    end,
})

Target:CreateInput({
    Name = "Username",
    Description = "Player to target",
    Placeholder = "Type a name...",
    Default = "",
    Flag = "TargetName",
    Callback = function(text)
        print("Target:", text)
    end,
})

auraKeybind = Target:CreateKeybind({
    Name = "Aura Key",
    Description = "Press to change, Esc to clear",
    Default = "G",
    Flag = "AuraKey",
    OverlayName = "Attack Aura",
    Mode = "Toggle",
    OnStateChanged = function(active)
        aura:Set(active)
    end,
    Callback = function(key)
        print("Key:", key)
    end,
})

Target:CreateColorPicker({
    Name = "Highlight Color",
    Default = Color3.fromRGB(246, 92, 82),
    Flag = "ESColor",
    Callback = function(color)
        print("Color:", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255))
    end,
})

Target:CreateProgressBar({
    Name = "Charge",
    Description = "Hold to charge",
    Default = 35,
    Interactive = true,
    Flag = "Charge",
    Callback = function(value)
        print("Charge:", value)
    end,
})

Fight:CreateButtonRow("Actions", {
    { Text = "Start", Callback = function()
        actionStatus:Set(true)
        print("Start!")
    end },
    { Text = "Stop", Callback = function()
        actionStatus:Set(false)
        print("Stop!")
    end },
})

MoveTab:CreateSection("Speed", 1):CreateButton({
    Name = "Reset Speed",
    Callback = function() print("Speed reset") end,
})

Fight:CreateDivider()
local statusLabel = Fight:CreateLabel("Status: idle")

local Speed = MoveTab:CreateSection("Speed", 1)
Speed:CreateToggle({
    Name = "Keybind Overlay",
    Description = "Show the on-screen Keybinds list",
    Default = true,
    Callback = function(value)
        Keybinds:SetVisible(value)
    end,
})
Speed:CreateKeybind({
    Name = "Speed Key",
    Description = "Shown in the Keybinds overlay",
    Default = "V",
    Flag = "SpeedKey",
    OverlayName = "Speed",
    Mode = "Hold",
    OnStateChanged = function(active)
        print("Speed hold active:", active)
    end,
    Callback = function(key)
        print("Speed key:", key)
    end,
})
Speed:CreateSlider({
    Name = "Walk Speed", Min = 16, Max = 200, Default = 16, Decimals = 0,
    Callback = function(value)
        local char = game.Players.LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = value end
    end,
})

Window:CreateCategory({ Name = "Manager", Collapsed = true })
Window:CreateThemeTab("Themes", "palette")

Window:Notify({
    Title = "Loaded",
    Content = "Toggle dots stay lit; hold dots light only while pressed.",
    Duration = 3,
    Icon = "keyboard",
})

task.spawn(function()
    task.wait(3)
    aura:Set(true)
    print("Aura flag:", Library.Flags["AttackAura"])
    statusLabel.Set("Status: running")
    task.wait(3)
    aura:Set(false)
    statusLabel.Set("Status: idle")
end)
