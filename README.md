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
| `Window:CreateBrowseTab(opts)` | Full-width gallery tab (search, categories, sort, pages, cards). See [Browse](#browse) |
| `Window:CreateBrowseWindow(opts)` | The same gallery in its own draggable window, opened with `Browse:Open()`. See [Browse window](#browse-window) |
| `Window:CreateBrowsec(opts)` | Separate File Market window with rank cards, category/sort filters, download actions and build details. See [Browsec File Market](#browsec-file-market) |
| `Window:CreateDialog(opts)` / `Window:CloseDialog()` | Centered modal card with pictures, info lines and buttons. See [Dialog](#dialog) |
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
| `CreateToggle` | `Default` (bool) | `function(value)` |
| `CreateButtonRow(name, {{Text, Icon, Model, Callback}, ...})` | 1–2 buttons in a row; returns `{Button, Icon, Icon3D, Fire, SetText}` handles | — |
| `CreateButton({Name, Icon, Model, Callback})` | Single button; accepts the same 3D icon options as dropdowns | — |
| `CreateSlider` | `Min`, `Max`, `Default`, `Decimals` | `function(value)` |
| `CreateDropdown` | `Options` (array of strings or `{Text, Icon}`), `Default` (text or index) | `function(text, index)` |
| `CreateMultiDropdown` | `Options`, `Default` (`{"A"}` or `{A = true}`) | `function(picked)` — array of selected |
| `CreateInput` | `Placeholder`, `Default` | `function(text)` — on typing |
| `CreateKeybind` | `Default` (e.g. `"G"`, `"None"`), `Overlay` (bool), `OverlayName` | `function(key)` |
| `CreateColorPicker` | `Default` (Color3) | `function(color)` |
| `CreateProgressBar` | `Default` (0–100), `Interactive` (draggable) | `function(value)` |
| `CreateLabel(text)` | — | Handle: only `Set(text)` |
| `CreateDivider()` | Divider line | — |

Orion-style aliases are available: `AddToggle`, `AddButton`, `AddSlider`,
`AddDropdown`, `AddTextbox`, `AddBind`, `AddColorPicker`, `AddLabel`, etc.

### 3D icons (buttons and dropdowns)

Buttons, `CreateDropdown`, and `CreateMultiDropdown` render model icons in a
`ViewportFrame`. Give a button or dropdown option a `Model` (any `Model`,
`BasePart`, `Tool`, `Accessory`…; it is cloned and scripts are stripped). The
feature auto-enables when a model is supplied; use `Icons3D = true/false` or
`["3DIcons"] = true/false` to explicitly enable/disable it.

```lua
Section:CreateDropdown({
    Name = "Weapon",
    Icons3D = true,      -- or ["3DIcons"] = true; auto-enabled when options have Model / Models is set
    IconSize = 36,       -- viewport side in px (default 32) — rows grow to fit
    Icon3D = {           -- optional, all fields have defaults
        Padding = 1.15,  -- >1 = more air around the model
        Zoom = 1,        -- >1 = closer
        FOV = 40,
        Angle = Vector3.new(20, -35, 0), -- pitch, yaw, roll (deg) the camera looks from
        Spin = false, SpinSpeed = 45,    -- rotate the model
        Ambient = Color3.fromRGB(190, 190, 190),
        LightColor = Color3.new(1, 1, 1),
        LightDirection = Vector3.new(-1, -1.5, -1),
        Background = nil,  -- Color3 or theme key ("BadgeBg") for a tile behind the model
    },
    Models = ReplicatedStorage.Weapons,  -- optional: look models up by option text
    Options = {
        { Text = "Sword", Model = ReplicatedStorage.Weapons.Sword },
        { Text = "Bow" },                         -- found via Models by name
        { Text = "Gun", Model = function() return player.Backpack:FindFirstChild("Gun") end },
        { Text = "Fists", Icon = "hand" },        -- no model -> lucide icon fallback
    },
})
```

Buttons use the same options. Put shared settings on a button row, or configure
a single button directly. `Icon` may remain a 2D Lucide name while `Model`
provides the 3D preview/fallback:

```lua
Section:CreateButton({
    Name = "Preview sword",
    Icon = "package",
    Model = swordModel,
    Icons3D = true,
    IconSize = 36,
    Icon3D = { Spin = true, Angle = Vector3.new(20, -35, 0) },
    Callback = function() print("Preview") end,
})

Section:CreateButtonRow({
    Name = "Actions",
    Icons3D = true,
    IconSize = 36,
    Buttons = {
        { Text = "Start", Model = swordModel, Callback = function() end },
        { Text = "Stop", Icon = "pause", Callback = function() end },
    },
})
```

`Models` may be an Instance (searched recursively by name), a table
`{Sword = model, ...}` or a `function(text)` returning an Instance. `Icons3D`
may also be a number (= `IconSize`) or a table (= `Icon3D`). Button and
dropdown handles expose `.Icon` (the icon slot; `.Icon.Viewport` has
`SetModel`, `SetAngle`, `SetZoom`) and `.Icon3D` (effective settings).

`Window.CreateViewportIcon(parent, cfg, zIndex)` is exported for custom UI:
returns `{Frame, Camera, World, SetModel(inst), SetAngle(v3), SetZoom(n), Destroy}`.

### 3D previews in Browse, FileMarket and Dialog

The same model/camera settings work in gallery thumbnails, details dialogs,
Dialog lines/stats/buttons, and required-block cards. Use `Model` / `Model3D`
for a specific model, or `Models` as a shared Folder, table, or lookup function.
A model is resolved first by the explicit model/icon key and then by its display
name. `Icons3D = true` enables model lookup; it also auto-enables when `Model`
or `Models` is supplied. `Icons3D = false` explicitly keeps the 2D behavior.
`Icon3D` accepts the same camera fields shown above; `IconSize` sets the icon
slot size. Existing Lucide `Icon` names and `Image` / `Images` assets remain
valid and are used when no model is found.

```lua
local models = ReplicatedStorage.BuildModels

local Market = Window:CreateBrowsec({
    Icons3D = true,
    Icon3D = { FOV = 40, Angle = Vector3.new(20, -35, 0), Spin = true },
    Models = models, -- looked up by item name, block name, or an explicit Model key
    Items = {
        { Name = "Sky Fortress", Image = "rbxassetid://123", BlockList = {
            { Name = "Metal Block", Count = 12 }, -- Models["Metal Block"] / matching child
        } },
    },
})

Window:CreateDialog({
    Title = "Sky Fortress",
    Images = { "rbxassetid://123" }, -- keep a 2D image alongside the model preview
    Model = models:FindFirstChild("Sky Fortress"),
    Icons3D = true,
    Icon3D = { FOV = 35, Padding = 1.2 },
    Models = models,
    Lines = { { Text = "Verified build", Icon = "circle-check" } },
    Stats = { { Label = "Blocks", Value = 12, Icon = "blocks" } },
    BlocksGrid = {
        Items = { { Name = "Metal Block", Count = 12 } },
        Models = models, Icons3D = true,
    },
})
```

Per-item or per-block `Icons3D`, `Icon3D`, `IconSize` and `Models` values
override the shared settings. `Images` may also contain model Instances or
preview records such as `{ Name = "Preview", Model = model }`; ordinary image
IDs/URLs still render as 2D images.

## Browse

`Window:CreateBrowseTab` adds a full-width gallery: a search box, a sort switch
(Hot / New / A-Z), a refresh button, pagination, category chips and a grid of
cards (thumbnail, rating badge, name). Items can be loaded from a JSON API, so
one script works for every user and the list is updated on the server side.

```lua
local Browse = Window:CreateBrowseTab({
    Name = "Browse",
    Icon = "store",
    Source = "https://example.com/scripts.json", -- JSON API (optional)
    -- Items = { { Name = "...", Category = "...", Rating = 90, Image = "rbxassetid://...", Data = "..." } },
    -- Fetch = function(url) return itemsTableOrJsonString end,   -- custom loader
    -- Parse = function(decoded) return decoded.payload.list end, -- custom response shape
    Categories = { "Mech", "Car", "Jet", "Tank" }, -- omit to build them from the items ("All" is always first)
    SortModes = { "Hot", "New", "A-Z" },          -- also "Top", or { Name = "...", Icon = "zap", Sort = function(a, b) end }
    PageSize = 9,
    Columns = 3,
    Lazy = true,                 -- load when the tab is opened the first time (false = load right away)
    SearchPlaceholder = "Search builds...",
    Callback = function(item, raw)
        print(item.Name, item.Category, item.Rating, item.Data)
    end,
})
```

### Browse window

The gallery can also live in a separate window instead of a sidebar tab —
handy when it should pop up from a button, a toggle or a hotkey:

```lua
local Catalog = Window:CreateBrowseWindow({   -- or CreateBrowseTab({ Mode = "Window", ... })
    Name = "Catalog", Description = "Builds Gallery",
    Width = 620, Height = 470,
    ToggleKey = Enum.KeyCode.B,       -- optional hotkey
    Visible = false,                  -- true = open right away
    Tabs = { "All", { Name = "Tab 1", Id = "1" }, { Name = "Tab 2", Id = "2" } }, -- header switch -> ctx.Tab
    Source = "https://.../builds.json", Details = true, Callback = function(item) end,
})

Section:CreateButton({ Name = "Open Catalog", Callback = function() Catalog:Open() end })
Section:CreateToggle({ Name = "Catalog", Callback = function(v) Catalog:Toggle(v) end })
Catalog:Close() / Catalog:IsOpen() / Catalog:SetTitle("...") / Catalog:SetCount(7960) / Catalog:SetPosition(UDim2) / Catalog:SetSize(w, h) / Catalog:GetSize()
```

The window is resizable from the grip in its bottom-right corner, independently
of the main window. `ResizeMode = "Scale"` (default) scales the content with the
window like the main window does; `ResizeMode = "Size"` keeps the content size
and gives the grid more room (more / wider cards). `MinWidth` / `MinHeight`
(420 × 300 by default), `Resizable = false`, `OnResize(w, h)`,
`Catalog:SetScale(1.2)` / `GetScale()` control it.

The handle has everything a tab-mode Browse has plus `Open / Close / Toggle /
IsOpen`. The window hides together with the main UI (toggle key) and comes back
with it. The header shows the logo, title, an item counter (`7 960`), the
`Tabs` switch and a close button. `Window:CreateBrowsePanel(frame, opts)` puts
the bare panel into any frame of your own.

### Browsec File Market

`CreateBrowsec` opens a **separate** File Market window; it does not replace or
change `CreateBrowseTab` / `CreateBrowseWindow`. It uses the light three-column
card layout, category chips and a sort dropdown (`Newest`, `Most downloaded`,
`Most popular`). Cards can show rank, preview, block/download/popularity counts,
and Details/Download actions. The wider details dialog supports author
verification, crisp metrics, buildability and a copyable 3D link. Required
blocks open in their own dialog as individual cards with an icon or 3D model and
quantity. Thumbnail icons default to Fit; set `Fit = false` for cover art.

3D previews are available on both card thumbnails and the details dialog. Set
`Icons3D = true`, `Icon3D = { FOV, Angle, Padding, Zoom, Spin, ... }`, and
`Models` on the market options for shared defaults; individual items can override
these with `Model` / `Model3D`, `Icon3D`, `IconSize`, `Icons3D`, or `Models`.
The same settings flow into required-block cards. Each block can provide a direct
`Model`, or a named model can be found in `Models` by the block's `Name` (an
explicit block icon/model key is checked first). If no model resolves, the
existing `Image` / `Icon` rendering is kept; use `Icons3D = false` to force the
2D fallback.

```lua
local Market
Market = Window:CreateBrowsec({
    Name = "File Market", Description = "7,460 builds on lsup.pro",
    Width = 920, Height = 620,
    Items = {
        {
            Id = "sky-fortress", Name = "Sky Fortress", Category = "Aircraft",
            Author = "Builder42", Verified = true, Published = "Oct 2026",
            Image = "rbxassetid://81973586053257", Fit = true, Downloads = 1824, Likes = 96,
            BuildValue = 3226, Buildability = 0.94, BlockCount = 317,
            BlockList = {
                { Name = "Metal Block", Count = 220, Icon = "box" },
                { Name = "Glass", Count = 52, Icon = "gem" },
                { Name = "Thruster", Count = 45, Icon = "wind" },
            },
            ViewUrl = "https://example.com/builds/sky-fortress/3d",
        },
    },
    Categories = { "Aircraft", "Buildings", "Vehicles" }, -- omit to infer from items
    SortModes = { "Newest", "Most downloaded", "Most popular" },
    Sort = "Most downloaded",
    DownloadCallback = function(item, raw, market)
        print("Download build:", item.Name, item.Data)
    end,
    Details = function(item, market) -- omitted fields keep the default detail UI
        return {
            Author = item.Author, Verified = item.Verified,
            Stats = {
                { Label = "Downloads", Value = item.Downloads, Icon = "download" },
                { Label = "Build Value", Value = item.BuildValue, Icon = "coins" },
            },
            Buildability = { Value = item.Buildability, Label = "Buildability", Detail = "All required blocks found" },
            BlocksButton = {
                Text = "Required Blocks", Title = "Blocks required for this build",
                Icon = "blocks", Columns = 2,
            },
            ShareLink = { Url = item.ViewUrl, Label = "View in 3D in your browser" },
        }
    end,
    OnDetails = function(item, dialog)
        -- Add a two-button horizontal group to the open details dialog.
        dialog:AddHStack({
            { Text = "Favorite", Icon = "plus", Callback = function(d) print("Favorite", d.Data.Name) end },
            { Text = "More from author", Icon = "user", Callback = function(d) Market:Search(item.Author) end },
        })
    end,
})

Market:Open() -- also Close(), Toggle(), IsOpen(), SetItems(), Search(), etc.

-- Card buttons share one HStack. The built-in Details and Download buttons can
-- be customized with CardButtons, or append another button at runtime (up to 3
-- fit comfortably in a row):
Market:AddButton({ Text = "Author", Icon = "user", Callback = function(item) print(item.Author) end })
-- Market:AddHStack({ {Text = "Preview", Icon = "eye", Callback = ...}, {Text = "Pin", Icon = "plus", Callback = ...} })
```

The default market card buttons are Details and Download. `CardButtons = { ... }`
replaces them; each button accepts `Text`, `Icon`, `Primary`, `Action = "Details"`
or `"Download"`, and `Callback(item, market)`. `Market:AddButton(def)` and
`Market:AddHStack(defs)` add actions to every card. `DownloadCallback(item, raw,
market)` runs for the built-in download action. Items accept `Downloads`,
`Likes` / `Popularity`, `BuildValue`, `Buildability` (fraction or percent),
`BlockCount`, `BlockList`, `Verified`, `Published`, `ViewUrl` and `Fit` in
addition to the regular Browse fields. Each block can be a string or an object
with `Name`, `Count` / `Amount` / `Quantity`, `Icon` or `Image`; use `Model` /
`Model3D` (or `Models` plus the block name) for a ViewportFrame 3D preview.
`Icons3D`, `IconSize`, `Icon3D` / `Icon3DConfig` and `Models` accept the shared
settings above. `Icon` stays the Lucide/2D fallback when no model resolves.

`BlocksButton` in a `Details` spec customizes the required-blocks button and
its dialog. Its fields include `Text`, `Title`, `Icon`, `Items` / `Blocks`,
`Count`, `Columns`, `MaxHeight`, `Models`, `Icon3D`, `IconSize`, `Icons3D` and
`ImageLoader`. The item list/count default from `item.BlockList` / `item.BlockCount`. Set
`BlocksButton = false` (or the window option `ShowBlocksButton = false`) to
hide the button; old `Blocks = ...` detail specs remain as inline lists.

For reusable content in `Details`, use `Stats`, `Buildability`, `Blocks`,
`BlocksButton`, `ShareLink`, or a list of typed `Elements` such as
`{ Type = "HStack", Items = { {Text = "One"}, {Text = "Two"} } }`.
The returned dialog can also be extended from `OnDetails` with
`dialog:AddButton`, `AddHStack`, `AddLabel` / `AddText`, `AddDivider`,
`AddProgressBar`, `AddStats`, `AddBlocks`, `AddBlocksGrid`, `AddBlocksButton`,
`AddCopyLink` or `AddElement`. `HStack` accepts two or three buttons (or
text/button elements). Buttons with Lucide icons or 3D models keep the icon on
the left. Callbacks in a `Details` spec receive `(item, dialog)`; callbacks
passed to a runtime `dialog:AddButton` / `AddHStack` receive `(dialog)`.

The standalone window and modal fit the available viewport on phones and small
screens; the market switches to one/two columns as it gets narrower. On a
resizable window, hold **Shift** while dragging the bottom-right grip to change
the window size without scaling its controls. Without Shift, the existing
scale-to-fit resize mode remains. `Mobile = true/false` can override device
detection, and `MobileColumns` can set a fixed responsive column count.

### Server-side paging (`Fetch`)

For APIs that page / search / sort on the server, give Browse a `Fetch`
function. It is called again on every page flip, search, sort, category or
tab change and returns **one page**:

```lua
Fetch = function(ctx)
    -- ctx = { Page, PageSize, Query, Sort ("Hot"), SortIndex, Category, Tab, Source, Browse }
    local body = game:HttpGet(("https://example.com/api/builds?page=%d&pageSize=%d&q=%s&sort=%s")
        :format(ctx.Page, ctx.PageSize, HttpService:UrlEncode(ctx.Query), ctx.Sort))
    local data = HttpService:JSONDecode(body)
    return data.items, math.ceil(data.total / ctx.PageSize), data.total   -- items, pages, total
    -- return nil, 0, 0, "error text"  -> shows "Failed to load"
end,
```

Returning only `items` (no page count) keeps the client-side mode: Browse
filters, sorts and pages the list itself. `Remote = true` forces server mode
from the start. `Tabs` renders an `All / Tab 1 / Tab 2` switch (in the toolbar
for tab mode, in the header for window mode) and passes the active id as
`ctx.Tab`; `OnTab(id)` fires on change. `ImageLoader = function(src, item)
return asset end` replaces the built-in picture loader (e.g. to convert webp
through a proxy before `getcustomasset`). Item fields also accept API names
like `title`, `quality`, `thumbUrl` / `thumb_url` / `cover_url`, `uid`, `path`.

Accepted JSON: an array of objects, or an object with `items` / `data` /
`results` / `list` / `builds` / `scripts`, or a dictionary keyed by id.
Field names are matched case-insensitively with common aliases:

| Item field | Aliases in JSON |
|---|---|
| `Name` | `name`, `title` |
| `Category` | `category`, `type`, `class`, `kind` |
| `Rating` | `rating`, `likes`, `score`, `percent` (0–1 is treated as a fraction) |
| `Image` / `Images` | `image`, `thumbnail`, `images`, `thumbnails`, `previews` (up to 2 are shown side by side) |
| `Icon` | `icon` (Lucide name, image asset, or model lookup key) |
| `Model` / `Models` | `model`, `model3d` / shared model folder, table, or lookup function |
| `Author` | `author`, `creator`, `owner` |
| `Date` | `date`, `time`, `created`, `timestamp` (used by the "New" sort) |
| `Tags` | `tags` (also matched by category chips and search) |
| `Data` | `data`, `payload`, `script`, `url`, `link`, `code` — whatever your callback needs |
| `Fit` | `fit`, `contain` — show the picture with air around it (icons) instead of cropping it |
| `Downloads` | `downloads`, `download_count` |
| `Likes` / `Popularity` | `likes`, `favorites`, `stars` / `popularity` |
| `BuildValue` / `Buildability` | `build_value`, `value`, `cost` / `buildability`, `completeness` (fraction or percent) |
| `BlockCount` / `BlockList` | `block_count`, `part_count` / `blocks`, `block_list`, `block_names` |
| `Verified` / `Published` | `verified`, `author_verified` / `published`, `published_at`, `created_at` |
| `ViewUrl` | `view_url`, `preview_url`, `3d_url` — used for the copyable 3D preview link |

The original object is kept in `item.Raw`. Images can be `rbxassetid://…`,
`rbxthumb://…`, a bare asset id, or an `https://` link (downloaded once and
cached through `getcustomasset` on executors that support it). Without an image
the card shows a placeholder icon (`PlaceholderIcon`). `ImageScaleType = "Fit"`
switches the whole grid from crop to fit. If `Source` and `Items` are both
given, the items are shown immediately and replaced when the API answers; if
the request fails they stay on screen.

Handle methods:

```lua
Browse:SetItems(list)            -- replace all items (table, same shapes as the API)
Browse:AddItem(item) / Browse:RemoveItem(idOrItem)
Browse:Load(url) / Browse:Refresh()
Browse:Search("text") / Browse:SetCategory("Tank") / Browse:SetCategories({ ... })
Browse:SetSort("New") / Browse:SetPage(2) / Browse:NextPage() / Browse:PrevPage()
Browse:GetItems() / Browse:GetFiltered() / Browse:GetSelected() / Browse:GetPage()
Browse:SetCallback(fn) / Browse:SetStatus("text") / Browse:Select()
```

### Item details

With a `Details` option a click on a card opens a [dialog](#dialog) instead of
calling `Callback` right away:

```lua
Details = true, -- default dialog: title, pictures, "★ 85%" badge, author/category/description, "Select" button -> Callback

Details = function(item, browse)   -- or a table with the same fields
    return {
        HeaderButtons = { { Text = "Grid", Close = true } },
        Tag = "Catalog #" .. item.Id,
        Badge = ("★ %d%% · %s"):format(item.Rating or 0, item.Author),
        Lines = {
            { Text = item.Category .. " · by " .. item.Author, Icon = "tag" },
            { Text = "Missing: 11 blocks", Icon = "alert-triangle", Color = "Accent" },
        },
        Buttons = {
            { Text = "Build Now", Icon = "hammer", Primary = true, Close = true, Callback = function(item, dialog) end },
            { { Text = "3D Preview", Icon = "eye" }, { Text = "Save to Files", Icon = "save" } }, -- one row
            { Text = "Auto-Swap Missing Blocks", Icon = "zap", Accent = true },
        },
    }
end,
```

Anything you leave out comes from the default dialog. Button callbacks get
`(item, dialog)`. `Browse:ShowDetails(item)`, `Browse:CloseDetails()` and
`Browse:SetDetails(spec)` control it from code; `OnDetails(item, dialog)` is
called whenever a dialog opens.

`OnLoad(items)`, `OnError(err)` and `OnRefresh()` options are called around
API requests. [browse.json](browse.json) is a ready-made example feed and
[Example.lua](Example.lua) shows it wired to `loadstring(game:HttpGet(item.Data))()`.

## Dialog

```lua
local dialog = Window:CreateDialog({
    Title = "jet 1485759085486932068",
    HeaderButtons = { { Text = "Grid", Callback = function(dialog) end, Close = true } },
    Images = { "rbxassetid://1", "rbxassetid://2", "rbxassetid://3", "rbxassetid://4" }, -- 1–4, laid out 1 / 2 / 2x2
    Fit = false,              -- true = no cropping (icons)
    ImageHeight = 170,
    Tag = "Catalog #1",       -- top-left pill over the pictures
    Badge = "★ 85% · 18 594", -- top-right pill (RichText allowed)
    Lines = {
        "1153 blocks · 18 594",
        { Text = "Missing: Delay 0/5, Hinge 0/2 +11 more", Icon = "alert-triangle", Color = "Accent" },
    },
    Buttons = {
        { Text = "Build Now", Icon = "hammer", Primary = true, Close = true, Callback = function(dialog) end },
        { { Text = "3D Preview", Icon = "eye" }, { Text = "Save to Files", Icon = "save" } },
        { Text = "Auto-Swap Missing Blocks", Icon = "zap", Accent = true, Id = "swap" },
    },
    Width = 320,
    CloseOnBackdrop = true,
    OnClose = function() end,
})

dialog:SetTitle("...") / dialog:SetLines({ ... }) / dialog:SetTag("...") / dialog:SetBadge("...")
dialog:GetButton(1):SetText("Building...")   -- by index or by `Id`
dialog:GetButton("swap"):SetEnabled(false)
dialog:IsOpen() / dialog:Close()
```

Dialog preview options include `Model` / `Model3D`, `Icon3D` (or
`Icon3DConfig`), `Models`, `Icons3D` and `IconSize`. A model preview can be
shown alongside ordinary `Images`; `Images` entries may also be model Instances
or `{ Model = model, Name = "..." }` records. The same icon options are accepted
by `HeaderButtons`, `Lines`, `Stats`, `Buildability`, typed `Elements`, HStack
text/button entries, and button definitions. `Blocks` supports compact rows; `BlocksGrid` and
`BlocksButton` render full required-block cards. All retain 2D Lucide/image
fallbacks when 3D is off or a model cannot be resolved.

Button styles: `Primary = true` (filled accent), `Accent = true` (accent text),
default (neutral). `Close = true` closes the dialog after the callback. Only one
dialog is open at a time; Esc, the ✕ button and a click on the backdrop close it
(a press that starts inside the dialog never closes it, so dragging is safe).
The header can be dragged. Dialogs can also be resized from the bottom-right
corner with mouse or touch; the body scrolls if you make a dialog shorter than
its contents. Set `Resizable = false` to hide the resize grip, or pass
`MinWidth` / `MinHeight` to adjust the smallest size. `OnResize(width, height,
dialog)` fires when a resize drag ends. `Anchor = someFrame`
centers the dialog over that frame instead of the main window; `ImageLoader`
works like in Browse.

## Shared internals / companion scripts

Scripts built next to the window (modules, catalogs, overlays) can reuse the
live theme engine so every extra frame matches the UI 1:1:

```lua
local UI = Window              -- the same fields are mirrored on Library after CreateWindow
UI.Theme                       -- live palette table: UI.Theme.Accent, UI.Theme.CardBg ...
UI.BindColor(inst, "BackgroundColor3", "CardBg")   -- re-applied on every theme change
UI.TweenColors(inst, TweenInfo.new(0.2), { TextColor3 = "Accent" }):Play()
UI.RefreshTheme()
UI.ResolveIcon("zap")          -- Lucide name -> rbxassetid
UI.TintIcon(imageLabel, "zap", "Accent")
UI.Icons                       -- the Lucide table
UI.LogoAsset                   -- window logo asset (may be "")
UI.ScreenGui, UI.Main          -- root ScreenGui and the main frame
UI.HttpGet(url)                -- game:HttpGet -> request() -> HttpService fallback; returns body or nil, err
```

A MacrOS-style module simply points at the window: `local MacrOSUI = Window`
gives `MacrOSUI.Theme`, `MacrOSUI.BindColor`, `MacrOSUI.ResolveIcon`,
`MacrOSUI.LogoAsset`. Small helpers live on `Library` itself and do not need a
window:

```lua
Library.Stage("Catalog", function() ... end)  -- protected runner, errors go to warn() + notification
Library.ReadFile(path)                        -- nil when missing / unsupported
Library.WriteFile(path, data)                 -- creates folders, returns true/false
Library.JSONDecode(text) / Library.JSONEncode(value)
Library.HttpGet(url), Library.Notify(opts), Library.CreateDialog(opts)  -- after CreateWindow
```

## Keybind list

A small draggable overlay stays on screen after the menu is hidden. It lists
every `CreateKeybind` plus the menu toggle key, and updates live when a key
changes. Pressing a bound key flashes its badge.

By default the overlay appears as soon as the first keybind is created.
`CreateWindow({ KeybindList = false })` keeps it hidden.
`KeybindList = true` shows it immediately.

```lua
local List = Window:CreateKeybindList({
    Title = "Keybinds",
    Visible = true,
    Position = UDim2.new(0, 16, 0.32, 0),
    HideUnbound = false,     -- hide rows whose key is "None"
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
```

`CreateKeybind({ Overlay = false })` skips that row.
`OverlayName` is the label in the list when it should differ from `Name`.
If the control has a `Flag`, that flag is the row id. `List:Set(flag, key)`
updates the overlay label only — use the control's `Set` to change the real key.

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
