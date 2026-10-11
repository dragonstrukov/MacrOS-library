# UI Library

A neutral UI library for Roblox scripts. Its own visual style: a dark window
with a sidebar, card sections, live search, and 60+ themes.

## Installation

```lua
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/dragonstrukov/test/main/Library.lua"
))()
```

A working example with every control is in [Example.lua](Example.lua).

## Quick start

```lua
local Window = Library:CreateWindow({ Name = "My Hub" })

local Tab = Window:CreateTab("Combat", "zap")
local Section = Tab:CreateSection("Fighting", 1)

Section:CreateToggle({
    Name = "Attack Aura",
    Default = false,
    Callback = function(value)
        print("Aura:", value)
    end,
})
```

## CreateWindow

```lua
local Window = Library:CreateWindow({
    Name = "My Hub",               -- header title ("UI Library" by default)
    Description = "My script",     -- subtitle ("" = hidden)
    Version = "v1.0",              -- version badge
    FooterText = "by me",          -- bottom line of the window ("" = hidden)
    ToggleKey = Enum.KeyCode.RightShift, -- hide/show hotkey
    LogoBase64 = "...",            -- your own PNG in base64 for the icon (optional)
    KeybindList = true,            -- keybind overlay: true / false / options table
})
```

Window methods:

| Method | Description |
|---|---|
| `Window:CreateCategory(name)` | Sidebar section: groups tabs, click collapses. Returns `{Collapse, Expand, Toggle, IsCollapsed}` |
| `Window:CreateTab(name, icon)` / `Window:CreateTab({Name, Icon})` | Tab, returns `Tab` |
| `Window:CreateThemeTab(name, icon)` | Tab with the theme list + custom theme editor |
| `Window:Notify({Title, Content, Duration, Icon})` | Notification (icon is a Lucide name) |
| `Window:CreateKeybindList(opts)` | Draggable Keybinds overlay (also `GetKeybindList`, `SetKeybindListVisible`) |
| `Window:SetTheme(name)` / `Window:SetTheme(name, true)` | Switch theme (2nd arg = silent, no notification) |
| `Window:GetTheme()` / `Window:GetThemes()` | Current theme / list of all themes |
| `Window:Toggle()` / `Window:Toggle(bool)` / `Window:IsVisible()` | Hide/show the window |
| `Window:SetFooter(text)` | Change the bottom line of the window |
| `Window:Destroy()` | Unload the whole UI |

The search in the top bar finds tabs and controls automatically —
nothing to configure. The first created tab is shown by itself.

## Tabs and sections

```lua
Window:CreateCategory("Features")
local Tab = Window:CreateTab("Combat", "zap")

Tab:Select() -- open the tab from code
```

Each section groups the tabs created after it. Clicking the header
collapses/expands its tabs (the header has a chevron). A section can be
created already collapsed and controlled from code:

```lua
local Manager = Window:CreateCategory({ Name = "Manager", Collapsed = true })
Manager:Expand() -- Collapse(), Toggle(), IsCollapsed()
```

```lua
local Section = Tab:CreateSection("Fighting", 1) -- 2nd arg: column 1/2
local Auto = Tab:CreateSection({ Title = "Auto", Column = 2 })
```

Without a column number the section goes to the shorter column. Sections can
be created at any time — even after the tab is shown.

## Controls

Every control has `Name`/`Title`, an optional `Description`, an optional
`Flag`, and a `Callback`. Every control returns a handle with `Set`
(changes the value and fires the callback) and `Get` methods.

```lua
local toggle = Section:CreateToggle({ Name = "Aura", Default = false })
toggle:Set(true)
print(toggle:Get())
```

| Control | Options | Callback |
|---|---|---|
| `CreateToggle` | `Default` (bool), `Overlay` (bool), `OverlayName` | `function(value)` |
| `CreateButtonRow(name, {{Text, Callback}, ...})` | 1–2 buttons in a row, returns an array of `{Button, Fire, SetText}` handles | — |
| `CreateButton({Name, Callback})` | Single button, returns `{Button, Fire, SetText}` | — |
| `CreateSlider` | `Min`, `Max`, `Default`, `Decimals` | `function(value)` |
| `CreateDropdown` | `Options` (array of strings or `{Text, Icon}`), `Default` (text or index) | `function(text, index)` |
| `CreateMultiDropdown` | `Options`, `Default` (`{"A"}` or `{A = true}`) | `function(picked)` — array of selected |
| `CreateInput` | `Placeholder`, `Default` | `function(text)` — on typing |
| `CreateKeybind` | `Default`, `Overlay`, `OverlayName`, `Mode` (`"Toggle"` / `"Hold"`), `DefaultActive` | `Callback(key)` when the bind changes; `OnStateChanged(active)` on press/release or toggle |
| `CreateColorPicker` | `Default` (Color3) | `function(color)` |
| `CreateProgressBar` | `Default` (0–100), `Interactive` (draggable) | `function(value)` |
| `CreateLabel(text)` | — | Handle: only `Set(text)` |
| `CreateDivider()` | Divider line | — |

`CreateToggle({Overlay = true})` adds a status marker to the keybind overlay
that lights while enabled, and stays synced with clicks and `Set()` calls.
Keybinds can opt into activation tracking with `Mode = "Toggle"` or
`Mode = "Hold"`; without `Mode`, a keybind remains a key picker. In either mode,
a small circle immediately to the right of the key badge lights while active;
the key badge itself stays neutral. `Toggle` keeps the circle lit until the next
press; `Hold` lights it only between key-down and key-up.
`OnStateChanged(active)` receives state
changes, while the existing `Callback(key)` still only fires when the assigned
key changes. `DefaultActive` applies to toggle mode.

Orion-style aliases are available: `AddToggle`, `AddButton`, `AddSlider`,
`AddDropdown`, `AddTextbox`, `AddBind`, `AddColorPicker`, `AddLabel`, etc.

## Keybind list

A small draggable overlay stays on screen after the menu is hidden. It lists
every `CreateKeybind` plus the menu toggle key, and updates live when a key
changes. Rows show the function name, its key badge, and a separate active-state
circle. Toggle controls can also show a small state indicator, while
`Mode = "Hold"` keybinds light their circle only while the key is held.

By default the overlay appears as soon as the first keybind or overlay-enabled
toggle is created. `CreateWindow({ KeybindList = false })` keeps it hidden.
`KeybindList = true` shows it immediately.

```lua
local List = Window:CreateKeybindList({
    Title = "Keybinds",
    Visible = true,
    Position = UDim2.new(0, 16, 0.32, 0),
    HideUnbound = false,     -- set true to hide keybinds whose key is "None"
    ShowToggleKey = true,    -- include the menu hotkey
    ToggleKeyName = "Toggle Menu",
    Collapsed = false,
})

List:SetVisible(false)
List:Toggle()
List:Collapse()              -- or Collapse(true / false)
List:SetTitle("Binds")
List:SetPosition(UDim2.fromOffset(24, 80))

local fly = List:Add({ Name = "Fly", Key = "F" })
fly:Set("G")                 -- display only; does not change a control
fly:Remove()

local status = List:AddStatus({ Name = "Fly", Active = false })
status:Set(true)              -- light the status dot
status:Remove()
```

`CreateToggle({ Overlay = true })` registers its state automatically. For a
keybind, `Mode = "Toggle"` flips the active state each press, while
`Mode = "Hold"` is active only between key-down and key-up. Both can use
`OnStateChanged = function(active) ... end`; their control handles also provide
`SetActive(bool)`, `GetActive()`, and `GetMode()`. The regular `Callback(key)`
continues to report key assignment changes.

`CreateKeybind({ Overlay = false })` skips that row.
`OverlayName` is the label in the list when it should differ from `Name`.
If the control has a `Flag`, that flag is the row id. `List:Set(flag, key)`
updates the overlay label only — use the control's `Set` to change the real key.
Use `List:SetActive(id, bool)` to update a status row by id. Status-only rows
aren't filtered by `HideUnbound`.

The header can be dragged. The chevron collapses the list to the title.
The Themes tab has a "Keybind List" toggle when `CreateThemeTab` is used.
`Window:SetKeybindListVisible(bool)` and `Window:GetKeybindList()` are the
same overlay — there is only one per window.

## Flags

If a control has a `Flag`, its value is always available globally:

```lua
Section:CreateSlider({ Name = "Range", Min = 0, Max = 100, Default = 50, Flag = "Range" })
print(Library.Flags["Range"]) -- 50, updates itself
```

`Window.Flags` is the same table.

## Tab icons

An icon is a name from the Lucide set (88 total). You can pass a ready-made
icon name (`"zap"`, `"eye"`, `"palette"`…), a built-in set key
(`"Combat"`, `"Player"`…), or your own `rbxassetid://...`.

<details>
<summary>All Lucide names</summary>

activity, alert-triangle, balloon, blocks, book, bot, box, check,
chevron-down, chevron-right, chevron-up, circle, circle-check, clipboard,
clipboard-paste, clock, cloud, cog, coins, copy, crown, download,
ellipsis-vertical, ethernet-port, eye, eye-off, flask-conical, folder-open,
gauge, gem, ghost, gift, grip, hammer, hand, house, image, infinity, inflate,
info, keyboard, languages, layers, list-checks, loader-circle, lock, log-out,
map-pin, menu, message-circle, message-square, minus, monitor, move, package,
palette, pause, play, plus, power, refresh-cw, repeat, rotate-ccw, rotate-cw,
save, scroll-text, search, send, settings, shapes, ship, shopping-bag,
shopping-cart, shuffle, skull, square, store, tag, trash-2, triangle-alert,
type, user, users, webhook, wind, wrench, x, zap.

</details>

## Themes

`Window:CreateThemeTab("Themes", "palette")` adds a tab with 60+ palettes
and a custom theme editor (colors persist between sessions if the executor
supports `writefile`). From code: `Window:SetTheme("Dark")`.
