

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local Library = {}
Library.Version = "2.0.0"

local COL = {
    bg = Color3.fromRGB(10, 10, 13),
    panel = Color3.fromRGB(18, 18, 22),
    panelHi = Color3.fromRGB(27, 27, 33),
    line = Color3.fromRGB(42, 42, 52),
    text = Color3.fromRGB(240, 240, 245),
    textDim = Color3.fromRGB(140, 140, 152),
    accent = Color3.fromRGB(255, 45, 60),
    accentDim = Color3.fromRGB(120, 22, 30),
}
Library.Theme = COL

local DEFAULT_BACKGROUND = "rbxassetid://94657811117742"
local DEFAULT_LOGO = "rbxassetid://131769820484042"

local HEADER_HEIGHT = 62
local TAB_HEIGHT = 44
local DEFAULT_WIDTH = 420
local DEFAULT_HEIGHT = 600

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(0, 0, 0)
local OK_GREEN = Color3.fromRGB(74, 222, 128)

local function new(class, properties, parent)
    local inst = Instance.new(class)
    for key, value in pairs(properties or {}) do
        inst[key] = value
    end
    if parent then
        inst.Parent = parent
    end
    return inst
end

local function tween(inst, properties, duration, style, direction)
    local info = TweenInfo.new(
        duration or 0.15,
        style or Enum.EasingStyle.Quad,
        direction or Enum.EasingDirection.Out
    )
    local animation = TweenService:Create(inst, info, properties)
    animation:Play()
    return animation
end

local function addStroke(inst, color, transparency, thickness)
    return new("UIStroke", {
        Color = color or COL.line,
        Thickness = thickness or 1,
        Transparency = transparency or 0.5,
    }, inst)
end

local function addCorner(inst, radius)
    return new("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
    }, inst)
end

local function addCircle(inst)
    return new("UICorner", {
        CornerRadius = UDim.new(1, 0),
    }, inst)
end

local function addSheen(inst, top, bottom)
    return new("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, top or 0),
            NumberSequenceKeypoint.new(1, bottom or 0.14),
        }),
    }, inst)
end

local function addTopGloss(inst, inset)
    return new("Frame", {
        Size = UDim2.new(1, -(inset or 16), 0, 1),
        Position = UDim2.new(0, (inset or 16) / 2, 0, 1),
        BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.94,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, inst)
end

local function safeCall(callback, ...)
    if type(callback) ~= "function" then
        return
    end
    local ok, err = pcall(callback, ...)
    if not ok then
        warn("[Lib] Callback-Fehler: " .. tostring(err))
    end
end

local function roundTo(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(value * mult + 0.5) / mult
end

local function formatNumber(value, decimals)
    if (decimals or 0) <= 0 then
        return tostring(math.floor(value + 0.5))
    end
    return tostring(roundTo(value, decimals))
end

local function addHover(btn, normal, hover)
    btn.MouseEnter:Connect(function()
        tween(btn, { BackgroundColor3 = hover }, 0.15)
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, { BackgroundColor3 = normal }, 0.15)
    end)
end

local function addRow(tab, inst)
    inst.LayoutOrder = tab.NextOrder
    tab.NextOrder = tab.NextOrder + 1
    inst.Parent = tab.Content
end

local function pointInside(gui, point)
    local pos = gui.AbsolutePosition
    local size = gui.AbsoluteSize
    return point.X >= pos.X
        and point.X <= pos.X + size.X
        and point.Y >= pos.Y
        and point.Y <= pos.Y + size.Y
end

local function rowButton(win, tab, height, zIndex)
    local theme = win.Theme
    local btn = new("TextButton", {
        Size = UDim2.new(1, -6, 0, height),
        BackgroundColor3 = theme.panel,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = zIndex or 5,
    })
    addRow(tab, btn)
    addCorner(btn, 10)
    local stroke = addStroke(btn, theme.line, 0.55, 1)
    addSheen(btn, 0, 0.12)
    addTopGloss(btn, 18)
    return btn, stroke
end

local function addRowHover(win, btn, stroke)
    local theme = win.Theme
    btn.MouseEnter:Connect(function()
        if win.Closed then
            return
        end
        tween(btn, { BackgroundColor3 = theme.panelHi }, 0.16)
        if stroke then
            tween(stroke, { Transparency = 0.32 }, 0.16)
        end
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, { BackgroundColor3 = theme.panel }, 0.16)
        if stroke then
            tween(stroke, { Transparency = 0.55 }, 0.16)
        end
    end)
end

local function createSectionLabel(win, tab, text)
    local theme = win.Theme
    local row = new("Frame", {
        Size = UDim2.new(1, -6, 0, 26),
        BackgroundTransparency = 1,
        ZIndex = 5,
    })
    addRow(tab, row)

    local glow = new("Frame", {
        Size = UDim2.new(0, 10, 0, 10),
        Position = UDim2.new(0, 0, 0.5, -5),
        BackgroundColor3 = theme.accent,
        BackgroundTransparency = 0.82,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, row)
    addCircle(glow)

    local dot = new("Frame", {
        Size = UDim2.new(0, 4, 0, 4),
        Position = UDim2.new(0, 3, 0.5, -2),
        BackgroundColor3 = theme.accent,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, row)
    addCircle(dot)

    local label = new("TextLabel", {
        Size = UDim2.new(1, -30, 0, 20),
        Position = UDim2.new(0, 18, 0, 3),
        BackgroundTransparency = 1,
        Text = string.upper(tostring(text or "")),
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = theme.accent,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 6,
    }, row)

    local line = new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = theme.line,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, row)
    new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, theme.accent),
            ColorSequenceKeypoint.new(0.45, theme.line),
            ColorSequenceKeypoint.new(1, theme.line),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(1, 0.92),
        }),
    }, line)

    return label
end

local function createToggle(win, tab, cfg)
    cfg = cfg or {}
    local theme = win.Theme

    local btn, stroke = rowButton(win, tab, 46, 5)

    local tint = new("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = theme.accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, btn)
    addCorner(tint, 10)

    local accent = new("Frame", {
        Size = UDim2.new(0, 3, 1, -20),
        Position = UDim2.new(0, 0, 0, 10),
        BackgroundColor3 = theme.accent,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, btn)
    addCircle(accent)

    local label = new("TextLabel", {
        Size = UDim2.new(1, -96, 1, 0),
        Position = UDim2.new(0, 18, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(cfg.Text or "Toggle"),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = theme.textDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 6,
    }, btn)

    local switch = new("Frame", {
        Size = UDim2.new(0, 40, 0, 22),
        Position = UDim2.new(1, -56, 0.5, -11),
        BackgroundColor3 = Color3.fromRGB(35, 35, 42),
        BorderSizePixel = 0,
        ZIndex = 7,
    }, btn)
    addCircle(switch)
    local switchStroke = addStroke(switch, theme.line, 0.4, 1)

    local knob = new("Frame", {
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new(0, 3, 0.5, -8),
        BackgroundColor3 = Color3.fromRGB(124, 124, 136),
        BorderSizePixel = 0,
        ZIndex = 8,
    }, switch)
    addCircle(knob)
    addStroke(knob, WHITE, 0.78, 1)

    local active = cfg.Default == true

    local function render(on)
        accent.Visible = on
        tint.BackgroundTransparency = on and 0.93 or 1
        tween(knob, {
            Position = UDim2.new(0, on and 21 or 3, 0.5, -8),
            BackgroundColor3 = on and WHITE or Color3.fromRGB(124, 124, 136),
        }, 0.2)
        tween(switch, {
            BackgroundColor3 = on and theme.accent or Color3.fromRGB(35, 35, 42),
        }, 0.2)
        tween(switchStroke, {
            Transparency = on and 0.15 or 0.4,
        }, 0.2)
        tween(label, {
            TextColor3 = on and theme.text or theme.textDim,
        }, 0.16)
    end

    render(active)
    addRowHover(win, btn, stroke)

    btn.MouseEnter:Connect(function()
        if not active then
            tween(label, { TextColor3 = theme.text }, 0.16)
        end
    end)
    btn.MouseLeave:Connect(function()
        if not active then
            tween(label, { TextColor3 = theme.textDim }, 0.16)
        end
    end)

    local function toggle()
        if win.Closed then
            return
        end
        active = not active
        render(active)
        safeCall(cfg.Callback, active)
    end

    btn.MouseButton1Click:Connect(toggle)

    local object = { Instance = btn }
    function object:Get()
        return active
    end
    function object:Set(value, silent)
        active = value and true or false
        render(active)
        if not silent then
            safeCall(cfg.Callback, active)
        end
    end
    function object:SetText(text)
        label.Text = tostring(text or "")
    end
    return object
end

local function createSlider(win, tab, cfg)
    cfg = cfg or {}
    local theme = win.Theme

    local minimum = tonumber(cfg.Min) or 0
    local maximum = tonumber(cfg.Max) or 100
    if maximum <= minimum then
        maximum = minimum + 1
    end
    local suffix = cfg.Suffix or ""
    local decimals = cfg.Decimals
    if decimals == nil then
        decimals = (maximum - minimum) <= 1 and 2 or 0
    end
    decimals = math.max(0, math.floor(decimals))

    local frame = new("Frame", {
        Size = UDim2.new(1, -6, 0, 60),
        BackgroundTransparency = 1,
        ZIndex = 5,
    })
    addRow(tab, frame)

    local label = new("TextLabel", {
        Size = UDim2.new(1, -92, 0, 20),
        BackgroundTransparency = 1,
        Text = tostring(cfg.Text or "Slider"),
        TextColor3 = theme.text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 5,
    }, frame)

    local chip = new("Frame", {
        Size = UDim2.new(0, 70, 0, 22),
        Position = UDim2.new(1, -70, 0, -1),
        BackgroundColor3 = theme.panelHi,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, frame)
    addCorner(chip, 7)
    local chipStroke = addStroke(chip, theme.line, 0.55, 1)

    local valueLabel = new("TextLabel", {
        Size = UDim2.new(1, -10, 1, 0),
        Position = UDim2.new(0, 5, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = theme.accent,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 6,
    }, chip)

    local track = new("Frame", {
        Position = UDim2.new(0, 0, 0, 39),
        Size = UDim2.new(1, -18, 0, 6),
        BackgroundColor3 = Color3.fromRGB(31, 31, 38),
        BorderSizePixel = 0,
        ZIndex = 5,
    }, frame)
    addCorner(track, 3)
    addStroke(track, theme.line, 0.6, 1)

    local fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = theme.accent,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, track)
    addCorner(fill, 3)
    new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, theme.accentLight),
            ColorSequenceKeypoint.new(1, theme.accent),
        }),
    }, fill)

    local thumb = new("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(0, -7, 0.5, -7),
        BackgroundColor3 = theme.text,
        BorderSizePixel = 0,
        ZIndex = 8,
    }, track)
    addCircle(thumb)
    addStroke(thumb, theme.accent, 0.05, 2)

    local trigger = new("TextButton", {
        Position = UDim2.new(0, 0, 0, 30),
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 9,
    }, frame)

    local current = math.clamp(tonumber(cfg.Default) or minimum, minimum, maximum)
    current = roundTo(current, decimals)

    local function setValue(value, silent)
        value = math.clamp(tonumber(value) or minimum, minimum, maximum)
        value = roundTo(value, decimals)
        current = value
        local ratio = (value - minimum) / (maximum - minimum)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        thumb.Position = UDim2.new(ratio, -7, 0.5, -7)
        valueLabel.Text = formatNumber(value, decimals) .. suffix
        if not silent then
            safeCall(cfg.Callback, value)
        end
    end

    setValue(current, true)

    local dragging = false

    local function applyFromX(x)
        local width = math.max(track.AbsoluteSize.X, 1)
        local ratio = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
        setValue(minimum + ratio * (maximum - minimum), false)
    end

    trigger.InputBegan:Connect(function(input)
        if win.Closed then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            tween(thumb, { Size = UDim2.new(0, 16, 0, 16) }, 0.12)
            applyFromX(input.Position.X)
        end
    end)

    trigger.MouseEnter:Connect(function()
        tween(chipStroke, { Transparency = 0.25 }, 0.15)
        tween(track, { BackgroundColor3 = Color3.fromRGB(38, 38, 46) }, 0.15)
    end)
    trigger.MouseLeave:Connect(function()
        tween(chipStroke, { Transparency = 0.55 }, 0.15)
        tween(track, { BackgroundColor3 = Color3.fromRGB(31, 31, 38) }, 0.15)
    end)

    win:Bind(UserInputService.InputChanged, function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            applyFromX(input.Position.X)
        end
    end)

    win:Bind(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                tween(thumb, { Size = UDim2.new(0, 14, 0, 14) }, 0.15)
            end
        end
    end)

    local object = { Instance = frame }
    function object:Get()
        return current
    end
    function object:Set(value, silent)
        setValue(value, silent)
    end
    return object
end

local function createButton(win, tab, cfg)
    cfg = cfg or {}
    local theme = win.Theme

    local btn, stroke = rowButton(win, tab, 44, 5)

    local label = new("TextLabel", {
        Size = UDim2.new(1, -72, 1, 0),
        Position = UDim2.new(0, 18, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(cfg.Text or "Button"),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 6,
    }, btn)

    local chevronHolder = new("Frame", {
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(1, -38, 0.5, -13),
        BackgroundColor3 = theme.panelHi,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, btn)
    addCircle(chevronHolder)

    local chevron = new("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = ">",
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextColor3 = theme.accent,
        ZIndex = 7,
    }, chevronHolder)

    btn.MouseButton1Click:Connect(function()
        if win.Closed then
            return
        end
        safeCall(cfg.Callback)
    end)

    btn.MouseEnter:Connect(function()
        tween(btn, { BackgroundColor3 = theme.panelHi }, 0.16)
        tween(stroke, { Transparency = 0.3 }, 0.16)
        tween(chevronHolder, { BackgroundColor3 = theme.accent }, 0.16)
        tween(chevron, { TextColor3 = theme.bg }, 0.16)
        tween(label, { TextColor3 = WHITE }, 0.16)
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, { BackgroundColor3 = theme.panel }, 0.16)
        tween(stroke, { Transparency = 0.55 }, 0.16)
        tween(chevronHolder, { BackgroundColor3 = theme.panelHi }, 0.16)
        tween(chevron, { TextColor3 = theme.accent }, 0.16)
        tween(label, { TextColor3 = theme.text }, 0.16)
    end)
    btn.MouseButton1Down:Connect(function()
        tween(chevronHolder, { BackgroundColor3 = theme.accentDim }, 0.1)
    end)
    btn.MouseButton1Up:Connect(function()
        tween(chevronHolder, { BackgroundColor3 = theme.accent }, 0.12)
    end)

    return { Instance = btn }
end

local function createInput(win, tab, cfg)
    cfg = cfg or {}
    local theme = win.Theme

    local row = new("Frame", {
        Size = UDim2.new(1, -6, 0, 46),
        BackgroundColor3 = theme.panel,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 5,
    })
    addRow(tab, row)
    addCorner(row, 10)
    local rowStroke = addStroke(row, theme.line, 0.55, 1)
    addSheen(row, 0, 0.12)
    addTopGloss(row, 18)

    new("TextLabel", {
        Size = UDim2.new(0.5, -24, 1, 0),
        Position = UDim2.new(0, 18, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(cfg.Text or "Input"),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 6,
    }, row)

    local box = new("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(0.46, 0, 0, 28),
        BackgroundColor3 = theme.input,
        BorderSizePixel = 0,
        Text = tostring(cfg.Default or ""),
        PlaceholderText = tostring(cfg.Placeholder or "Eingabe..."),
        PlaceholderColor3 = theme.textDim,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = cfg.ClearOnFocus == true,
        ClipsDescendants = true,
        ZIndex = 7,
    }, row)
    addCorner(box, 8)
    local boxStroke = addStroke(box, theme.line, 0.55, 1)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 9),
        PaddingRight = UDim.new(0, 9),
    }, box)

    local hovered = false

    box.Focused:Connect(function()
        tween(rowStroke, { Transparency = 0.02 }, 0.16)
        tween(boxStroke, { Transparency = 0.05 }, 0.16)
        tween(box, { BackgroundColor3 = theme.panelHi }, 0.16)
        tween(row, { BackgroundColor3 = theme.panelHi }, 0.16)
    end)
    box.FocusLost:Connect(function(enterPressed)
        tween(rowStroke, { Transparency = 0.55 }, 0.18)
        tween(boxStroke, { Transparency = 0.55 }, 0.18)
        tween(box, { BackgroundColor3 = theme.input }, 0.18)
        if not hovered then
            tween(row, { BackgroundColor3 = theme.panel }, 0.18)
        end
        if win.Closed then
            return
        end
        safeCall(cfg.Callback, box.Text, enterPressed)
    end)

    row.MouseEnter:Connect(function()
        hovered = true
        tween(row, { BackgroundColor3 = theme.panelHi }, 0.16)
    end)
    row.MouseLeave:Connect(function()
        hovered = false
        if not box:IsFocused() then
            tween(row, { BackgroundColor3 = theme.panel }, 0.16)
        end
    end)

    local object = { Instance = box }
    function object:Get()
        return box.Text
    end
    function object:Set(text, silent)
        box.Text = tostring(text or "")
        if not silent then
            safeCall(cfg.Callback, box.Text, false)
        end
    end
    return object
end

local function createDropdown(win, tab, cfg)
    cfg = cfg or {}
    local theme = win.Theme
    local options = cfg.Options or {}
    local multi = cfg.Multi == true

    local selected
    if multi then
        selected = {}
        if type(cfg.Default) == "table" then
            for _, value in ipairs(cfg.Default) do
                selected[value] = true
            end
        elseif cfg.Default ~= nil then
            selected[cfg.Default] = true
        end
    else
        selected = cfg.Default
    end

    local row, rowStroke = rowButton(win, tab, 44, 5)

    new("TextLabel", {
        Size = UDim2.new(1, -222, 1, 0),
        Position = UDim2.new(0, 18, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(cfg.Text or "Dropdown"),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 6,
    }, row)

    local valueLabel = new("TextLabel", {
        Size = UDim2.new(0, 150, 1, 0),
        Position = UDim2.new(1, -196, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = theme.accent,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 6,
    }, row)

    local chevronHolder = new("Frame", {
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(1, -36, 0.5, -13),
        BackgroundColor3 = theme.panelHi,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, row)
    addCircle(chevronHolder)

    local chevron = new("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "v",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = theme.textDim,
        ZIndex = 7,
    }, chevronHolder)

    local function getSelectedList()
        local list = {}
        for _, option in ipairs(options) do
            if selected[option] then
                table.insert(list, option)
            end
        end
        return list
    end

    local function updateDisplay()
        if multi then
            local list = getSelectedList()
            if #list == 0 then
                valueLabel.Text = "None"
                valueLabel.TextColor3 = theme.textDim
            else
                valueLabel.Text = table.concat(list, ", ")
                valueLabel.TextColor3 = theme.accent
            end
        else
            if selected == nil then
                valueLabel.Text = "None"
                valueLabel.TextColor3 = theme.textDim
            else
                valueLabel.Text = tostring(selected)
                valueLabel.TextColor3 = theme.accent
            end
        end
    end

    updateDisplay()

    local popup = nil

    local function setOpenVisual(open)
        tween(chevron, {
            Rotation = open and 180 or 0,
            TextColor3 = open and theme.bg or theme.textDim,
        }, 0.18)
        tween(chevronHolder, {
            BackgroundColor3 = open and theme.accent or theme.panelHi,
        }, 0.18)
        tween(rowStroke, {
            Transparency = open and 0.18 or 0.55,
        }, 0.18)
    end

    local function closePopup()
        if popup then
            if popup.Parent then
                popup:Destroy()
            end
            popup = nil
        end
        setOpenVisual(false)
    end
    table.insert(win.PopupClosers, closePopup)

    local function openPopup()
        if popup then
            return
        end

        local rowHeight = 30
        local gap = 2
        local padding = 6
        local screen = win.GuiRoot.AbsoluteSize
        local count = math.max(#options, 1)
        local height = count * rowHeight + (count - 1) * gap + padding * 2
        height = math.min(height, math.max(140, screen.Y - 24))
        local width = row.AbsoluteSize.X

        local posX = row.AbsolutePosition.X
        local posY = row.AbsolutePosition.Y + row.AbsoluteSize.Y + 6
        if posY + height > screen.Y - 8 then
            posY = row.AbsolutePosition.Y - height - 6
        end
        posX = math.clamp(posX, 8, math.max(8, screen.X - width - 8))
        posY = math.clamp(posY, 8, math.max(8, screen.Y - height - 8))

        popup = new("CanvasGroup", {
            Name = "LibDropdown",
            BackgroundColor3 = theme.panel,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(posX, posY - 6),
            Size = UDim2.fromOffset(width, height),
            ClipsDescendants = true,
            GroupTransparency = 1,
            ZIndex = 500,
        }, win.GuiRoot)
        addCorner(popup, 12)
        addStroke(popup, theme.line, 0.2, 1)
        addSheen(popup, 0, 0.16)
        new("UIPadding", {
            PaddingTop = UDim.new(0, padding),
            PaddingBottom = UDim.new(0, padding),
            PaddingLeft = UDim.new(0, padding),
            PaddingRight = UDim.new(0, padding),
        }, popup)

        local list = new("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = theme.accent,
            ScrollBarImageTransparency = 0.35,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ZIndex = 501,
        }, popup)
        new("UIListLayout", {
            Padding = UDim.new(0, gap),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, list)

        tween(popup, {
            Position = UDim2.fromOffset(posX, posY),
            GroupTransparency = 0,
        }, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

        for index, option in ipairs(options) do
            local isSelected = (multi and selected[option]) or (not multi and selected == option)

            local optionBtn = new("TextButton", {
                Size = UDim2.new(1, 0, 0, rowHeight),
                BackgroundColor3 = theme.panelHi,
                BackgroundTransparency = isSelected and 0.55 or 1,
                Text = "",
                AutoButtonColor = false,
                BorderSizePixel = 0,
                LayoutOrder = index,
                ZIndex = 501,
            }, list)
            addCorner(optionBtn, 7)

            new("TextLabel", {
                Size = UDim2.new(1, -40, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = tostring(option),
                Font = Enum.Font.GothamMedium,
                TextSize = 12,
                TextColor3 = theme.text,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 502,
            }, optionBtn)

            local check = new("Frame", {
                Size = UDim2.new(0, 16, 0, 16),
                Position = UDim2.new(1, -26, 0.5, -8),
                BackgroundColor3 = isSelected and theme.accent or theme.panelHi,
                BackgroundTransparency = isSelected and 0 or 1,
                BorderSizePixel = 0,
                ZIndex = 502,
            }, optionBtn)
            if multi then
                addCorner(check, 4)
            else
                addCircle(check)
            end
            local checkStroke = addStroke(check, isSelected and theme.accent or theme.line, isSelected and 0 or 0.4, 1)

            local dot = new("Frame", {
                Size = UDim2.new(0, 7, 0, 7),
                Position = UDim2.new(0.5, -3.5, 0.5, -3.5),
                BackgroundColor3 = theme.bg,
                BorderSizePixel = 0,
                Visible = isSelected and true or false,
                ZIndex = 503,
            }, check)
            if multi then
                addCorner(dot, 2)
            else
                addCircle(dot)
            end

            local function refreshCheck(state)
                dot.Visible = state and true or false
                tween(check, {
                    BackgroundColor3 = state and theme.accent or theme.panelHi,
                    BackgroundTransparency = state and 0 or 1,
                }, 0.14)
                tween(checkStroke, {
                    Color = state and theme.accent or theme.line,
                    Transparency = state and 0 or 0.4,
                }, 0.14)
            end

            optionBtn.MouseEnter:Connect(function()
                tween(optionBtn, {
                    BackgroundTransparency = 0,
                    BackgroundColor3 = theme.panelHi,
                }, 0.12)
            end)
            optionBtn.MouseLeave:Connect(function()
                local stillSelected = (multi and selected[option]) or (not multi and selected == option)
                tween(optionBtn, {
                    BackgroundTransparency = stillSelected and 0.55 or 1,
                }, 0.12)
            end)

            optionBtn.MouseButton1Click:Connect(function()
                if win.Closed then
                    return
                end
                if multi then
                    if selected[option] then
                        selected[option] = nil
                    else
                        selected[option] = true
                    end
                    refreshCheck(selected[option] == true)
                    updateDisplay()
                    safeCall(cfg.Callback, getSelectedList())
                else
                    selected = option
                    updateDisplay()
                    safeCall(cfg.Callback, option)
                    closePopup()
                end
            end)
        end

        if #options == 0 then
            new("TextLabel", {
                Size = UDim2.new(1, 0, 0, rowHeight),
                BackgroundTransparency = 1,
                Text = "Keine Optionen",
                Font = Enum.Font.GothamMedium,
                TextSize = 12,
                TextColor3 = theme.textDim,
                ZIndex = 501,
            }, list)
        end

        setOpenVisual(true)
    end

    row.MouseButton1Click:Connect(function()
        if win.Closed then
            return
        end
        if popup then
            closePopup()
        else
            openPopup()
        end
    end)

    addRowHover(win, row, rowStroke)

    win:Bind(UserInputService.InputBegan, function(input)
        if not popup then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end
        local point = Vector2.new(input.Position.X, input.Position.Y)
        if pointInside(popup, point) or pointInside(row, point) then
            return
        end
        closePopup()
    end)

    win:Bind(tab.Content:GetPropertyChangedSignal("CanvasPosition"), function()
        closePopup()
    end)

    local object = { Instance = row }
    function object:Get()
        if multi then
            return getSelectedList()
        end
        return selected
    end
    function object:Set(value, silent)
        closePopup()
        if multi then
            selected = {}
            if type(value) == "table" then
                for _, entry in ipairs(value) do
                    selected[entry] = true
                end
            elseif value ~= nil then
                selected[value] = true
            end
            updateDisplay()
            if not silent then
                safeCall(cfg.Callback, getSelectedList())
            end
        else
            selected = value
            updateDisplay()
            if not silent then
                safeCall(cfg.Callback, selected)
            end
        end
    end
    return object
end

local function createKeybind(win, tab, cfg)
    cfg = cfg or {}
    local theme = win.Theme

    local key = cfg.Default
    local listening = false

    local row, rowStroke = rowButton(win, tab, 44, 5)

    new("TextLabel", {
        Size = UDim2.new(1, -132, 1, 0),
        Position = UDim2.new(0, 18, 0, 0),
        BackgroundTransparency = 1,
        Text = tostring(cfg.Text or "Keybind"),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 6,
    }, row)

    local pill = new("Frame", {
        Size = UDim2.new(0, 92, 0, 26),
        Position = UDim2.new(1, -104, 0.5, -13),
        BackgroundColor3 = theme.input,
        BorderSizePixel = 0,
        ZIndex = 6,
    }, row)
    addCorner(pill, 8)
    local pillStroke = addStroke(pill, theme.line, 0.55, 1)

    local keyLabel = new("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = theme.textDim,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 7,
    }, pill)

    local function updateKey()
        if listening then
            keyLabel.Text = "PRESS A KEY"
            keyLabel.TextColor3 = WHITE
        else
            keyLabel.Text = key and key.Name or "None"
            keyLabel.TextColor3 = key and theme.accent or theme.textDim
        end
    end

    local function setListening(on)
        if listening == on then
            return
        end
        listening = on
        if on then
            win.ListeningCount = win.ListeningCount + 1
            tween(rowStroke, { Color = theme.accent, Transparency = 0.02 }, 0.16)
            tween(pillStroke, { Color = theme.accent, Transparency = 0.1 }, 0.16)
            tween(pill, { BackgroundColor3 = theme.accentDim }, 0.16)
        else
            win.ListeningCount = math.max(0, win.ListeningCount - 1)
            tween(rowStroke, { Color = theme.line, Transparency = 0.55 }, 0.18)
            tween(pillStroke, { Color = theme.line, Transparency = 0.55 }, 0.18)
            tween(pill, { BackgroundColor3 = theme.input }, 0.18)
        end
        updateKey()
    end

    updateKey()
    addRowHover(win, row, rowStroke)

    row.MouseButton1Click:Connect(function()
        if win.Closed then
            return
        end
        setListening(not listening)
    end)

    win:Bind(UserInputService.InputBegan, function(input, processed)
        if not listening then
            return
        end
        if processed then
            return
        end
        if UserInputService:GetFocusedTextBox() then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end
        if input.KeyCode == Enum.KeyCode.Unknown then
            return
        end

        setListening(false)
        if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
            key = nil
        else
            key = input.KeyCode
        end
        updateKey()
        safeCall(cfg.Callback, key)
    end)

    local object = { Instance = row }
    function object:Get()
        return key
    end
    function object:Set(value, silent)
        key = value
        updateKey()
        if not silent then
            safeCall(cfg.Callback, key)
        end
    end
    return object
end

local function createLabel(win, tab, cfg)
    if type(cfg) == "string" then
        cfg = { Text = cfg }
    end
    cfg = cfg or {}
    local theme = win.Theme

    local label = new("TextLabel", {
        Size = UDim2.new(1, -6, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = tostring(cfg.Text or ""),
        Font = Enum.Font.GothamMedium,
        TextSize = tonumber(cfg.TextSize) or 12,
        TextColor3 = cfg.Color or theme.textDim,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        LineHeight = 1.15,
        ZIndex = 5,
    })
    addRow(tab, label)

    local object = { Instance = label }
    function object:SetText(text)
        label.Text = tostring(text or "")
    end
    return object
end

function Tab:Section(name)
    createSectionLabel(self.Window, self, name)
    return setmetatable({ Tab = self, Name = name }, Section)
end

function Tab:Toggle(cfg)
    return createToggle(self.Window, self, cfg)
end

function Tab:Slider(cfg)
    return createSlider(self.Window, self, cfg)
end

function Tab:Button(cfg)
    return createButton(self.Window, self, cfg)
end

function Tab:Input(cfg)
    return createInput(self.Window, self, cfg)
end

function Tab:Dropdown(cfg)
    return createDropdown(self.Window, self, cfg)
end

function Tab:Keybind(cfg)
    return createKeybind(self.Window, self, cfg)
end

function Tab:Label(cfg)
    return createLabel(self.Window, self, cfg)
end

function Section:Toggle(cfg)
    return createToggle(self.Tab.Window, self.Tab, cfg)
end

function Section:Slider(cfg)
    return createSlider(self.Tab.Window, self.Tab, cfg)
end

function Section:Button(cfg)
    return createButton(self.Tab.Window, self.Tab, cfg)
end

function Section:Input(cfg)
    return createInput(self.Tab.Window, self.Tab, cfg)
end

function Section:Dropdown(cfg)
    return createDropdown(self.Tab.Window, self.Tab, cfg)
end

function Section:Keybind(cfg)
    return createKeybind(self.Tab.Window, self.Tab, cfg)
end

function Section:Label(cfg)
    return createLabel(self.Tab.Window, self.Tab, cfg)
end

function Window:Bind(signal, callback)
    local connection = signal:Connect(function(...)
        if self.Closed then
            return
        end
        callback(...)
    end)
    table.insert(self.Connections, connection)
    return connection
end

function Window:ClosePopups()
    for _, closer in ipairs(self.PopupClosers) do
        safeCall(closer)
    end
end

function Window:LayoutTabs()
    local showTabs = #self.Tabs > 1 and not self.Minimized
    local top = HEADER_HEIGHT + (showTabs and TAB_HEIGHT or 0)

    for _, tab in ipairs(self.Tabs) do
        if tab.Content then
            tab.Content.Position = UDim2.new(0, 14, 0, top + 14)
            tab.Content.Size = UDim2.new(1, -28, 1, -(top + 28))
        end
    end

    if self.ContentBackdrop then
        self.ContentBackdrop.Position = UDim2.new(0, 8, 0, top + 8)
        self.ContentBackdrop.Size = UDim2.new(1, -16, 1, -(top + 16))
        self.ContentBackdrop.Visible = not self.Minimized
    end
end

function Window:UpdateTabs()
    local showTabs = #self.Tabs > 1 and not self.Minimized
    self.TabBar.Visible = showTabs

    for _, tab in ipairs(self.Tabs) do
        local isActive = tab == self.ActiveTab
        if tab.Button then
            tween(tab.Button, {
                TextColor3 = isActive and self.Theme.text or self.Theme.textDim,
                BackgroundTransparency = isActive and 0 or 1,
            }, 0.18)
        end
        if tab.Stroke then
            tween(tab.Stroke, {
                Transparency = isActive and 0.55 or 1,
            }, 0.18)
        end
        if tab.Underline then
            tab.Underline.Visible = isActive
        end
        if tab.Content then
            tab.Content.Visible = isActive and not self.Minimized
        end
    end

    self:LayoutTabs()
end

function Window:Tab(name)
    if self.Closed then
        return nil
    end

    name = tostring(name or ("Tab " .. (#self.Tabs + 1)))

    local tab = setmetatable({
        Window = self,
        Name = name,
        NextOrder = 0,
        Content = nil,
        Button = nil,
        Underline = nil,
    }, Tab)

    local content = self.CreateContent(self)
    content.Name = "Content_" .. name
    tab.Content = content

    local upper = string.upper(name)
    local button = new("TextButton", {
        Size = UDim2.new(0, math.max(46, 20 + #upper * 7), 0, 26),
        BackgroundColor3 = self.Theme.panelHi,
        BackgroundTransparency = 1,
        Text = upper,
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextColor3 = self.Theme.textDim,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        LayoutOrder = #self.Tabs + 1,
        ZIndex = 8,
    }, self.TabList)
    addCorner(button, 8)
    local tabStroke = addStroke(button, self.Theme.accent, 1, 1)
    tab.Button = button
    tab.Stroke = tabStroke

    local underline = new("Frame", {
        Size = UDim2.new(1, -22, 0, 2),
        Position = UDim2.new(0, 11, 1, -4),
        BackgroundColor3 = self.Theme.accent,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 9,
    }, button)
    addCorner(underline, 2)
    tab.Underline = underline

    button.MouseButton1Click:Connect(function()
        self:SetActiveTab(tab)
    end)
    button.MouseEnter:Connect(function()
        if self.Closed or self.ActiveTab == tab then
            return
        end
        tween(button, {
            BackgroundTransparency = 0.82,
            TextColor3 = self.Theme.text,
        }, 0.16)
    end)
    button.MouseLeave:Connect(function()
        if self.Closed or self.ActiveTab == tab then
            return
        end
        tween(button, {
            BackgroundTransparency = 1,
            TextColor3 = self.Theme.textDim,
        }, 0.16)
    end)

    table.insert(self.Tabs, tab)

    if not self.ActiveTab then
        self.ActiveTab = tab
    end

    self:UpdateTabs()
    return tab
end

function Window:GetTab(name)
    for _, tab in ipairs(self.Tabs) do
        if tab.Name == name then
            return tab
        end
    end
    return nil
end

function Window:SelectTab(tab)
    if type(tab) == "string" then
        tab = self:GetTab(tab)
    end
    if tab then
        self:SetActiveTab(tab)
    end
end

function Window:SetActiveTab(tab)
    if self.Closed or not tab then
        return
    end
    self.ActiveTab = tab
    self:ClosePopups()
    self:UpdateTabs()
end

function Window:GetDefaultTab()
    return self.ActiveTab or self:Tab(self.Config.DefaultTab or "Main")
end

function Window:Section(name)
    return self:GetDefaultTab():Section(name)
end

function Window:Toggle(cfg)
    return self:GetDefaultTab():Toggle(cfg)
end

function Window:Slider(cfg)
    return self:GetDefaultTab():Slider(cfg)
end

function Window:Button(cfg)
    return self:GetDefaultTab():Button(cfg)
end

function Window:Input(cfg)
    return self:GetDefaultTab():Input(cfg)
end

function Window:Dropdown(cfg)
    return self:GetDefaultTab():Dropdown(cfg)
end

function Window:Keybind(cfg)
    return self:GetDefaultTab():Keybind(cfg)
end

function Window:Label(cfg)
    return self:GetDefaultTab():Label(cfg)
end

function Window:SetMinimized(minimized)
    minimized = minimized and true or false
    if self.Closed or self.Minimized == minimized then
        return
    end

    self.Minimized = minimized
    self:ClosePopups()

    if minimized then
        self.MinimizeBtn.Text = "+"
        self:UpdateTabs()
        tween(self.MainFrame, {
            Size = UDim2.new(self.Size.X.Scale, self.Size.X.Offset, 0, HEADER_HEIGHT),
        }, 0.24, Enum.EasingStyle.Quint)
    else
        self.MinimizeBtn.Text = "–"
        tween(self.MainFrame, { Size = self.Size }, 0.24, Enum.EasingStyle.Quint)
        self:LayoutTabs()
        task.delay(0.12, function()
            if not self.Closed and not self.Minimized then
                self:UpdateTabs()
            end
        end)
    end
end

function Window:SetVisible(visible)
    if self.Closed then
        return
    end

    visible = visible and true or false
    if self.Visible == visible then
        return
    end
    self.Visible = visible

    if visible then
        self.GuiRoot.Visible = true
        tween(self.GuiRoot, { GroupTransparency = 0 }, 0.22)
    else
        self:ClosePopups()
        local fade = tween(self.GuiRoot, { GroupTransparency = 1 }, 0.2)
        fade.Completed:Connect(function()
            if not self.Visible and not self.Closed then
                self.GuiRoot.Visible = false
            end
        end)
    end
end

function Window:ToggleVisible()
    self:SetVisible(not self.Visible)
end

function Window:Destroy()
    if self.Closed then
        return
    end

    self.Closed = true
    self:ClosePopups()
    safeCall(self.Config.OnClose)

    for _, connection in ipairs(self.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    self.Connections = {}

    if self.ScreenGui then
        pcall(function()
            self.ScreenGui:Destroy()
        end)
        self.ScreenGui = nil
    end
end

function Library:CreateWindow(config)
    config = config or {}

    local theme = {}
    for key, value in pairs(COL) do
        theme[key] = value
    end
    if type(config.Theme) == "table" then
        for key, value in pairs(config.Theme) do
            theme[key] = value
        end
    end
    if typeof(config.Accent) == "Color3" then
        theme.accent = config.Accent
        if not (type(config.Theme) == "table" and config.Theme.accentDim ~= nil) then
            theme.accentDim = Color3.new(
                config.Accent.R * 0.47,
                config.Accent.G * 0.47,
                config.Accent.B * 0.47
            )
        end
    end
    theme.accentLight = theme.accentLight or theme.accent:Lerp(WHITE, 0.35)
    theme.input = theme.input or Color3.fromRGB(13, 13, 16)
    theme.track = theme.track or Color3.fromRGB(31, 31, 38)
    theme.ok = theme.ok or OK_GREEN

    local win = setmetatable({}, Window)
    win.Config = config
    win.Theme = theme
    win.Connections = {}
    win.PopupClosers = {}
    win.Tabs = {}
    win.ActiveTab = nil
    win.Closed = false
    win.Minimized = false
    win.Visible = true
    win.ListeningCount = 0
    win.Size = config.Size or UDim2.fromOffset(DEFAULT_WIDTH, DEFAULT_HEIGHT)

    local toggleText = string.upper(tostring(config.Title or "Title"))
    local subtitle = string.upper(tostring(config.Subtitle or "Made by xqrto"))
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")

    local screenGui = new("ScreenGui", {
        Name = config.Name or "UltimateLibGui",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, playerGui)
    win.ScreenGui = screenGui

    local guiRoot = new("CanvasGroup", {
        Name = "GuiRoot",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
    }, screenGui)
    win.GuiRoot = guiRoot

    local mainFrame = new("Frame", {
        Name = "MainFrame",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = win.Size,
        BackgroundColor3 = theme.bg,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
        ZIndex = 2,
    }, guiRoot)
    win.MainFrame = mainFrame
    addCorner(mainFrame, 16)
    addStroke(mainFrame, theme.line, 0.25, 1)

    local function makeShadow(extra, extraY, offsetY, transparency, radius, z)
        local shadow = new("Frame", {
            Name = "Shadow",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = mainFrame.Position,
            Size = UDim2.new(
                mainFrame.Size.X.Scale,
                mainFrame.Size.X.Offset + extra,
                mainFrame.Size.Y.Scale,
                mainFrame.Size.Y.Offset + extraY
            ),
            BackgroundColor3 = BLACK,
            BackgroundTransparency = transparency,
            BorderSizePixel = 0,
            ZIndex = z,
        }, guiRoot)
        addCorner(shadow, radius)
        return shadow
    end

    local shadowFar = makeShadow(28, 28, 14, 0.88, 26, 0)
    local shadowNear = makeShadow(12, 12, 6, 0.7, 20, 1)

    local shadowData = {
        { Instance = shadowFar, extra = 28, extraY = 28, offsetY = 14 },
        { Instance = shadowNear, extra = 12, extraY = 12, offsetY = 6 },
    }

    local function syncShadows()
        local pos = mainFrame.Position
        local size = mainFrame.Size
        for _, data in ipairs(shadowData) do
            data.Instance.Position = UDim2.new(
                pos.X.Scale,
                pos.X.Offset,
                pos.Y.Scale,
                pos.Y.Offset + data.offsetY
            )
            data.Instance.Size = UDim2.new(
                size.X.Scale,
                size.X.Offset + data.extra,
                size.Y.Scale,
                size.Y.Offset + data.extraY
            )
        end
    end

    mainFrame:GetPropertyChangedSignal("Position"):Connect(syncShadows)
    mainFrame:GetPropertyChangedSignal("Size"):Connect(syncShadows)

    new("Frame", {
        Name = "TopGloss",
        Size = UDim2.new(1, -36, 0, 1),
        Position = UDim2.new(0, 18, 0, 1),
        BackgroundColor3 = WHITE,
        BackgroundTransparency = 0.9,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, mainFrame)

    local bgImage = new("ImageLabel", {
        Name = "ParallaxBg",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1.3, 1.3),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = config.Background or DEFAULT_BACKGROUND,
        ImageTransparency = 0.58,
        ScaleType = Enum.ScaleType.Crop,
        ZIndex = 1,
    }, mainFrame)
    win.BackgroundImage = bgImage

    local bgShade = new("Frame", {
        Name = "BgShade",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = theme.bg,
        BackgroundTransparency = 0.16,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, mainFrame)
    new("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.08),
            NumberSequenceKeypoint.new(0.55, 0.52),
            NumberSequenceKeypoint.new(1, 0.04),
        }),
    }, bgShade)

    local function makeAmbient(size, position, color, rotation, alpha)
        local glow = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = position,
            Size = size,
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Rotation = rotation,
            ZIndex = 3,
        }, mainFrame)
        new("UIGradient", {
            Rotation = 90,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.5, 1 - alpha),
                NumberSequenceKeypoint.new(1, 1),
            }),
        }, glow)
        return glow
    end

    local ambientA = makeAmbient(
        UDim2.fromScale(0.95, 0.5),
        UDim2.fromScale(0.24, 0.16),
        theme.accent,
        24,
        0.075
    )
    local ambientB = makeAmbient(
        UDim2.fromScale(0.9, 0.45),
        UDim2.fromScale(0.82, 0.86),
        theme.accentLight,
        -18,
        0.05
    )

    local contentBackdrop = new("Frame", {
        Name = "ContentBackdrop",
        Position = UDim2.new(0, 8, 0, HEADER_HEIGHT + 8),
        Size = UDim2.new(1, -16, 1, -(HEADER_HEIGHT + 16)),
        BackgroundColor3 = theme.bg,
        BackgroundTransparency = 0.42,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, mainFrame)
    addCorner(contentBackdrop, 12)
    addStroke(contentBackdrop, theme.line, 0.78, 1)
    win.ContentBackdrop = contentBackdrop

    local topBar = new("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
        BackgroundColor3 = Color3.fromRGB(15, 15, 19),
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Active = true,
        ZIndex = 6,
    }, mainFrame)
    new("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.05),
            NumberSequenceKeypoint.new(1, 0.28),
        }),
    }, topBar)

    local headerLine = new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = theme.line,
        BorderSizePixel = 0,
        ZIndex = 8,
    }, topBar)
    new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, theme.accent),
            ColorSequenceKeypoint.new(0.4, theme.line),
            ColorSequenceKeypoint.new(1, theme.line),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.35),
            NumberSequenceKeypoint.new(1, 0.85),
        }),
    }, headerLine)

    local avatarHolder = new("Frame", {
        Name = "Avatar",
        Size = UDim2.new(0, 36, 0, 36),
        Position = UDim2.new(0, 16, 0.5, -18),
        BackgroundColor3 = theme.panelHi,
        BorderSizePixel = 0,
        ZIndex = 7,
    }, topBar)
    addCorner(avatarHolder, 11)
    addStroke(avatarHolder, theme.accent, 0.55, 1.2)

    local avatarImage = new("ImageLabel", {
        Size = UDim2.new(1, -6, 1, -6),
        Position = UDim2.new(0, 3, 0, 3),
        BackgroundTransparency = 1,
        Image = config.Logo or DEFAULT_LOGO,
        ZIndex = 8,
    }, avatarHolder)
    addCorner(avatarImage, 8)

    local statusDot = new("Frame", {
        Size = UDim2.new(0, 9, 0, 9),
        Position = UDim2.new(1, -10, 1, -10),
        BackgroundColor3 = theme.ok,
        BorderSizePixel = 0,
        ZIndex = 9,
    }, avatarHolder)
    addCircle(statusDot)
    addStroke(statusDot, theme.bg, 0, 2)

    new("TextLabel", {
        Name = "Title",
        Position = UDim2.new(0, 64, 0, 10),
        Size = UDim2.new(1, -196, 0, 20),
        Text = toggleText,
        Font = Enum.Font.GothamBold,
        TextColor3 = theme.text,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 7,
    }, topBar)

    new("TextLabel", {
        Name = "Subtitle",
        Position = UDim2.new(0, 64, 0, 30),
        Size = UDim2.new(1, -196, 0, 14),
        Text = subtitle,
        Font = Enum.Font.Gotham,
        TextColor3 = theme.textDim,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 7,
    }, topBar)

    local buttonHolder = new("Frame", {
        Size = UDim2.new(0, 68, 0, 28),
        Position = UDim2.new(1, -84, 0.5, -14),
        BackgroundTransparency = 1,
        ZIndex = 8,
    }, topBar)

    local minimizeBtn = new("TextButton", {
        Size = UDim2.new(0, 28, 0, 28),
        BackgroundColor3 = theme.panelHi,
        Text = "–",
        Font = Enum.Font.GothamBold,
        TextSize = 15,
        TextColor3 = theme.textDim,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = 9,
    }, buttonHolder)
    addCorner(minimizeBtn, 8)
    addStroke(minimizeBtn, theme.line, 0.7, 1)

    local closeBtn = new("TextButton", {
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(1, -28, 0, 0),
        BackgroundColor3 = Color3.fromRGB(34, 20, 24),
        Text = "×",
        Font = Enum.Font.GothamBold,
        TextSize = 17,
        TextColor3 = theme.accent,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = 9,
    }, buttonHolder)
    addCorner(closeBtn, 8)
    addStroke(closeBtn, theme.accent, 0.75, 1)

    addHover(minimizeBtn, theme.panelHi, Color3.fromRGB(43, 43, 52))
    addHover(closeBtn, Color3.fromRGB(34, 20, 24), theme.accentDim)

    win.MinimizeBtn = minimizeBtn
    win.CloseBtn = closeBtn

    local tabBar = new("Frame", {
        Name = "TabBar",
        Position = UDim2.new(0, 0, 0, HEADER_HEIGHT),
        Size = UDim2.new(1, 0, 0, TAB_HEIGHT),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 7,
    }, mainFrame)
    win.TabBar = tabBar

    local tabBarBg = new("Frame", {
        Position = UDim2.new(0, 14, 0, 6),
        Size = UDim2.new(1, -28, 0, 32),
        BackgroundColor3 = theme.bg,
        BackgroundTransparency = 0.42,
        BorderSizePixel = 0,
        ZIndex = 7,
    }, tabBar)
    addCorner(tabBarBg, 10)
    addStroke(tabBarBg, theme.line, 0.65, 1)

    local tabList = new("ScrollingFrame", {
        Name = "TabList",
        Position = UDim2.new(0, 4, 0, 0),
        Size = UDim2.new(1, -8, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        ScrollBarImageTransparency = 1,
        ScrollingDirection = Enum.ScrollingDirection.X,
        ScrollingEnabled = true,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        ZIndex = 8,
    }, tabBarBg)
    win.TabList = tabList

    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, tabList)

    tabList.MouseWheelForward:Connect(function()
        tabList.CanvasPosition = Vector2.new(
            math.max(0, tabList.CanvasPosition.X - 48),
            0
        )
    end)
    tabList.MouseWheelBackward:Connect(function()
        local maxX = math.max(0, tabList.AbsoluteCanvasSize.X - tabList.AbsoluteSize.X)
        tabList.CanvasPosition = Vector2.new(
            math.min(maxX, tabList.CanvasPosition.X + 48),
            0
        )
    end)

    local function createContent()
        local content = new("ScrollingFrame", {
            Name = "Content",
            Position = UDim2.new(0, 14, 0, HEADER_HEIGHT + 14),
            Size = UDim2.new(1, -28, 1, -(HEADER_HEIGHT + 28)),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = theme.accent,
            ScrollBarImageTransparency = 0.3,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ScrollingEnabled = true,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            CanvasPosition = Vector2.new(0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
            ZIndex = 5,
        }, mainFrame)

        new("UIPadding", {
            PaddingTop = UDim.new(0, 2),
            PaddingBottom = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 4),
        }, content)

        new("UIListLayout", {
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, content)

        return content
    end
    win.CreateContent = createContent

    local dragging = false
    local dragStart
    local startPos

    topBar.InputBegan:Connect(function(input)
        if win.Closed then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    win:Bind(UserInputService.InputChanged, function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    minimizeBtn.MouseButton1Click:Connect(function()
        win:SetMinimized(not win.Minimized)
    end)

    closeBtn.MouseButton1Click:Connect(function()
        win:Destroy()
    end)

    win:Bind(RunService.RenderStepped, function()
        if not guiRoot.Visible or win.Minimized then
            return
        end

        local mouse = UserInputService:GetMouseLocation()
        local center = mainFrame.AbsolutePosition + (mainFrame.AbsoluteSize / 2)
        local nx = math.clamp(
            (mouse.X - center.X) / math.max(mainFrame.AbsoluteSize.X / 2, 1),
            -1,
            1
        )
        local ny = math.clamp(
            (mouse.Y - center.Y) / math.max(mainFrame.AbsoluteSize.Y / 2, 1),
            -1,
            1
        )

        local goal = UDim2.new(0.5 - nx * 0.045, 0, 0.5 - ny * 0.045, 0)
        bgImage.Position = bgImage.Position:Lerp(goal, 0.1)

        ambientA.Position = ambientA.Position:Lerp(
            UDim2.new(0.24 - nx * 0.025, 0, 0.16 - ny * 0.025, 0),
            0.06
        )
        ambientB.Position = ambientB.Position:Lerp(
            UDim2.new(0.82 - nx * 0.018, 0, 0.86 - ny * 0.018, 0),
            0.05
        )
    end)

    local toggleKey = config.ToggleKey
    if toggleKey == nil then
        toggleKey = Enum.KeyCode.RightShift
    end

    if toggleKey ~= false then
        win:Bind(UserInputService.InputBegan, function(input, processed)
            if processed then
                return
            end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then
                return
            end
            if input.KeyCode ~= toggleKey then
                return
            end
            if UserInputService:GetFocusedTextBox() then
                return
            end
            if win.ListeningCount > 0 then
                return
            end
            win:ToggleVisible()
        end)
    end

    syncShadows()
    guiRoot.GroupTransparency = 1
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 12)
    syncShadows()
    tween(mainFrame, {
        Position = UDim2.fromScale(0.5, 0.5),
    }, 0.36, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    tween(guiRoot, {
        GroupTransparency = 0,
    }, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    return win
end

return Library
