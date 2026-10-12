local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/dragonstrukov/test/main/Library.lua"
))()

local Window = Library:CreateWindow({
    Name = "My Hub",
    Description = "Example script",
    Version = "v1.0",
    FooterText = "made with UI Library",
    ToggleKey = Enum.KeyCode.RightShift,
})

local Keybinds = Window:CreateKeybindList({
    Title = "Keybinds",
    Visible = true,
    Position = UDim2.new(0, 16, 0.32, 0),
})

local Features = Window:CreateCategory("Features")

local CombatTab = Window:CreateTab("Combat", "zap")
local MoveTab = Window:CreateTab({ Name = "Movement", Icon = "move" })

local Fight = CombatTab:CreateSection("Fighting", 1)
local Target = CombatTab:CreateSection("Target", 2)

local aura = Fight:CreateToggle({
    Name = "Attack Aura",
    Description = "Automatically attacks nearby players",
    Default = false,
    Flag = "AttackAura",
    Callback = function(value)
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

-- Dropdown with 3D icons (ViewportFrame). Any Model / BasePart / Tool works:
-- pass it per option as `Model`, or give a shared `Models` folder and the library
-- looks the option text up inside it. Here simple parts are built on the fly so
-- the demo works in any game.
local function demoPart(shape, color, size)
    local part = Instance.new("Part")
    part.Shape = shape
    part.Color = color
    part.Material = Enum.Material.SmoothPlastic
    part.Size = size
    part.Anchored = true
    return part
end

Fight:CreateDropdown({
    Name = "Weapon",
    Description = "3D icons: Icons3D = true, IconSize = 36",
    Icons3D = true,          -- replaces the lucide icon with a ViewportFrame
    IconSize = 36,           -- viewport side in px (rows grow to fit)
    Icon3D = {               -- optional fine-tuning
        Spin = true,         -- slowly rotate the model
        Padding = 1.1,       -- air around the model (>1 = smaller model)
        Angle = Vector3.new(20, -35, 0), -- pitch / yaw / roll the camera looks from
    },
    Options = {
        { Text = "Sword", Model = demoPart(Enum.PartType.Block, Color3.fromRGB(232, 92, 82), Vector3.new(0.4, 3, 0.6)) },
        { Text = "Orb",   Model = demoPart(Enum.PartType.Ball, Color3.fromRGB(84, 170, 255), Vector3.new(2, 2, 2)) },
        { Text = "Barrel", Model = demoPart(Enum.PartType.Cylinder, Color3.fromRGB(110, 200, 120), Vector3.new(2, 1.4, 1.4)) },
        { Text = "Fists", Icon = "hand" }, -- no model -> falls back to a lucide icon
    },
    Default = "Sword",
    Flag = "Weapon",
    Callback = function(text, index)
        print("Weapon:", text, index)
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

Target:CreateKeybind({
    Name = "Aura Key",
    Description = "Press to change, Esc to clear",
    Default = "G",
    Flag = "AuraKey",
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
    { Text = "Start", Callback = function() print("Start!") end },
    { Text = "Stop", Callback = function() print("Stop!") end },
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

-- Browse: a gallery of universal scripts loaded from a JSON API, so the list
-- is the same for every user and can be updated without touching the script.
-- JSON format: {"items": [{"name", "category", "rating", "author", "image", "url"}, ...]}
-- (see browse.json in the repo).
-- Runs a script from the feed (item.Data = "url" field of the JSON)
local function runScript(item)
    if not item.Data then return end
    Window:Notify({ Title = "Browse", Content = "Loading " .. item.Name .. "...", Icon = "download", Duration = 2 })
    task.spawn(function()
        local ok, err = pcall(function()
            loadstring(game:HttpGet(tostring(item.Data)))()
        end)
        if not ok then
            Window:Notify({ Title = "Browse", Content = "Failed: " .. tostring(err), Icon = "alert-triangle", Duration = 4 })
        end
    end)
end

Window:CreateCategory("Library")
local Browse = Window:CreateBrowseTab({
    Name = "Browse",
    Icon = "store",
    -- JSON API with the list of scripts (see browse.json). Remove it to use only Items.
    Source = "https://raw.githubusercontent.com/dragonstrukov/test/main/browse.json",

    -- Optional: shown right away and kept if the API is unreachable (offline / 404).
    Items = {
        { Name = "Example Hub", Category = "Universal", Rating = 96, Author = "dragonstrukov", Image = "rbxassetid://81973586053257",  Fit = true, Data = "https://raw.githubusercontent.com/dragonstrukov/test/main/Example.lua" },
        { Name = "Attack Aura", Category = "Combat",    Rating = 88, Author = "dragonstrukov", Image = "rbxassetid://130551565616516", Fit = true, Data = "https://raw.githubusercontent.com/dragonstrukov/test/main/Example.lua" },
        { Name = "Walk Speed",  Category = "Movement",  Rating = 79, Author = "dragonstrukov", Image = "rbxassetid://110273524101447", Fit = true, Data = "https://raw.githubusercontent.com/dragonstrukov/test/main/Example.lua" },
        { Name = "Player ESP",  Category = "Visuals",   Rating = 91, Author = "dragonstrukov", Image = "rbxassetid://100033680381365", Fit = true, Data = "https://raw.githubusercontent.com/dragonstrukov/test/main/Example.lua" },
        { Name = "Anti AFK",    Category = "Misc",      Rating = 99, Author = "dragonstrukov", Image = "rbxassetid://98083086936965",  Fit = true, Data = "https://raw.githubusercontent.com/dragonstrukov/test/main/Example.lua" },
        { Name = "Noclip",      Category = "Movement",  Rating = 77, Author = "dragonstrukov", Image = "rbxassetid://113822048130017", Fit = true, Data = "https://raw.githubusercontent.com/dragonstrukov/test/main/Example.lua" },
    },
    Categories = { "Universal", "Combat", "Movement", "Visuals", "Misc" }, -- omit to build them from the items
    SortModes = { "Hot", "New", "A-Z" },
    PageSize = 9,
    Columns = 3,
    SearchPlaceholder = "Search scripts...",
    OnLoad = function(items)
        Window:Notify({ Title = "Browse", Content = #items .. " scripts loaded from API", Icon = "circle-check", Duration = 2 })
    end,

    -- Clicking a card opens a details dialog. `Details = true` gives the default one
    -- (title, pictures, rating, info, "Select" button -> Callback). A function lets
    -- you build it per item; anything you leave out falls back to the default.
    Details = function(item, browse)
        -- item.Name, item.Category, item.Rating, item.Author, item.Description, item.Images, item.Data, item.Raw
        return {
            HeaderButtons = { { Text = "Grid", Close = true } },
            Tag = "Catalog #" .. tostring(item.Id),
            Badge = string.format("★ %d%% · %s", item.Rating or 0, tostring(item.Author or "?")),
            Lines = {
                { Text = tostring(item.Category) .. " · by " .. tostring(item.Author or "unknown"), Icon = "tag" },
                { Text = item.Description or "No description", Icon = "info" },
                { Text = "Source: " .. tostring(item.Data), Icon = "ethernet-port", Color = "TextDim" },
            },
            Buttons = {
                { Text = "Run Script", Icon = "play", Primary = true, Close = true, Callback = runScript },
                {   -- two buttons in one row
                    { Text = "Copy Link", Icon = "copy", Callback = function(item, dialog)
                        if setclipboard then setclipboard(tostring(item.Data)) end
                        dialog:GetButton(2):SetText("Copied!")
                        task.delay(1.2, function() if dialog:IsOpen() then dialog:GetButton(2):SetText("Copy Link") end end)
                    end },
                    { Text = "Save to Files", Icon = "save", Callback = function(item)
                        if not writefile then return end
                        pcall(writefile, item.Name .. ".lua", game:HttpGet(tostring(item.Data)))
                        Window:Notify({ Title = "Browse", Content = "Saved " .. item.Name .. ".lua", Icon = "save", Duration = 2 })
                    end },
                },
                { Text = "More from " .. tostring(item.Author or "author"), Icon = "search", Accent = true, Close = true,
                    Callback = function(item) browse:Search(tostring(item.Author or "")) end },
            },
        }
    end,

    Callback = runScript, -- used when there is no Details (direct click) or by the default "Select" button
})

-- Browse as a SEPARATE WINDOW (catalog popup) instead of a sidebar tab.
-- It stays hidden until Browse:Open() is called from a button / toggle / hotkey.
local catalogCache
local Catalog = Window:CreateBrowseWindow({
    Name = "Catalog",
    Description = "Builds Gallery",
    Width = 620, Height = 470,
    ToggleKey = Enum.KeyCode.B,                      -- optional hotkey
    Tabs = { "All", { Name = "Tab 1", Id = "1" }, { Name = "Tab 2", Id = "2" } }, -- source switch in the header
    Categories = { "Universal", "Combat", "Movement", "Visuals", "Misc" },
    SortModes = { "Hot", "New", "A-Z" },
    PageSize = 9, Columns = 3,
    Details = true,                                  -- default details dialog, "Select" -> Callback
    Callback = runScript,

    -- SERVER-SIDE mode: Fetch receives page / query / sort / category / tab and returns
    -- ONE page of items + the number of pages + the total. Every search, page flip, sort
    -- or tab switch calls it again - exactly how a paged API (…/builds?page=2&q=jet) works.
    Fetch = function(ctx)
        -- Real API: local body = game:HttpGet(("https://example.com/api/builds?page=%d&pageSize=%d&q=%s&sort=%s")
        --     :format(ctx.Page, ctx.PageSize, game:GetService("HttpService"):UrlEncode(ctx.Query), ctx.Sort))
        -- local data = game:GetService("HttpService"):JSONDecode(body)
        -- return data.items, math.ceil(data.total / ctx.PageSize), data.total
        if not catalogCache then
            local ok, decoded = pcall(function()
                return game:GetService("HttpService"):JSONDecode(game:HttpGet("https://raw.githubusercontent.com/dragonstrukov/test/main/browse.json"))
            end)
            catalogCache = (ok and type(decoded) == "table" and decoded.items) or Browse:GetItems() -- offline fallback
        end
        local function field(raw, a, b) return raw[a] ~= nil and raw[a] or raw[b] end
        local list = {}
        for i, raw in ipairs(catalogCache) do
            local inTab = ctx.Tab == "All" or (ctx.Tab == "1" and i % 2 == 1) or (ctx.Tab == "2" and i % 2 == 0)
            local inCat = ctx.Category == "All" or field(raw, "Category", "category") == ctx.Category
            local inQuery = ctx.Query == "" or string.find(string.lower(tostring(field(raw, "Name", "name"))), string.lower(ctx.Query), 1, true) ~= nil
            if inTab and inCat and inQuery then table.insert(list, raw) end
        end
        if ctx.Sort == "Hot" then
            table.sort(list, function(a, b) return (tonumber(field(a, "Rating", "rating")) or 0) > (tonumber(field(b, "Rating", "rating")) or 0) end)
        elseif ctx.Sort == "New" then
            table.sort(list, function(a, b) return (tonumber(field(a, "Date", "date")) or 0) > (tonumber(field(b, "Date", "date")) or 0) end)
        else
            table.sort(list, function(a, b) return tostring(field(a, "Name", "name")) < tostring(field(b, "Name", "name")) end)
        end
        local pages = math.max(1, math.ceil(#list / ctx.PageSize))
        local page = {}
        for i = (ctx.Page - 1) * ctx.PageSize + 1, math.min(#list, ctx.Page * ctx.PageSize) do
            table.insert(page, list[i])
        end
        return page, pages, #list
    end,
})

-- Open the catalog window from ordinary controls
local ToolsTab = Window:CreateTab("Tools", "wrench")
local CatalogSection = ToolsTab:CreateSection("Catalog window", 1)
CatalogSection:CreateButton({
    Name = "Open Catalog",
    Callback = function() Catalog:Open() end,
})
CatalogSection:CreateToggle({
    Name = "Catalog window",
    Description = "Also toggled with the B key",
    Default = false,
    Callback = function(value) Catalog:Toggle(value) end,
})
CatalogSection:CreateButton({
    Name = "Show first item details",
    Callback = function()
        Catalog:Open()
        local first = Catalog:GetItems()[1]
        if first then Catalog:ShowDetails(first) end
    end,
})

-- Dialogs can also be opened directly:
-- Window:CreateDialog({ Title = "Hello", Lines = { "Line one", { Text = "Warning", Icon = "alert-triangle", Color = "Accent" } },
--     Buttons = { { Text = "OK", Primary = true, Close = true }, { "Cancel", "Later" } } })
-- Browse:ShowDetails(Browse:GetItems()[1])

-- The same panel can also be driven from code:
-- Browse:SetItems({ { Name = "Local script", Category = "Misc", Rating = 50, Data = "https://..." } })
-- Browse:Search("esp") / Browse:SetCategory("Visuals") / Browse:SetSort("New") / Browse:Refresh()

Window:CreateCategory({ Name = "Manager", Collapsed = true })
Window:CreateThemeTab("Themes", "palette")

Window:Notify({
    Title = "Loaded",
    Content = "Keybinds overlay is on the left.",
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
