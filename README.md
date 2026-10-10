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
})
```

Window methods:

| Method | Description |
|---|---|
| `Window:CreateCategory(name)` | Sidebar section: groups tabs, click collapses. Returns `{Collapse, Expand, Toggle, IsCollapsed}` |
| `Window:CreateTab(name, icon)` / `Window:CreateTab({Name, Icon})` | Tab, returns `Tab` |
| `Window:CreateThemeTab(name, icon)` | Tab with the theme list + custom theme editor |
| `Window:Notify({Title, Content, Duration, Icon})` | Notification (icon is a Lucide name) |
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
| `CreateToggle` | `Default` (bool) | `function(value)` |
| `CreateButtonRow(name, {{Text, Callback}, ...})` | 1–2 buttons in a row, returns an array of `{Button, Fire, SetText}` handles | — |
| `CreateButton({Name, Callback})` | Single button, returns `{Button, Fire, SetText}` | — |
| `CreateSlider` | `Min`, `Max`, `Default`, `Decimals` | `function(value)` |
| `CreateDropdown` | `Options` (array of strings or `{Text, Icon}`), `Default` (text or index) | `function(text, index)` |
| `CreateMultiDropdown` | `Options`, `Default` (`{"A"}` or `{A = true}`) | `function(picked)` — array of selected |
| `CreateInput` | `Placeholder`, `Default` | `function(text)` — on typing |
| `CreateKeybind` | `Default` (e.g. `"G"`, `"None"`) | `function(key)` |
| `CreateColorPicker` | `Default` (Color3) | `function(color)` |
| `CreateProgressBar` | `Default` (0–100), `Interactive` (draggable) | `function(value)` |
| `CreateLabel(text)` | — | Handle: only `Set(text)` |
| `CreateDivider()` | Divider line | — |

Orion-style aliases are available: `AddToggle`, `AddButton`, `AddSlider`,
`AddDropdown`, `AddTextbox`, `AddBind`, `AddColorPicker`, `AddLabel`, etc.

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
