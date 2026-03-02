--[[
	Nova UI Library
	General-purpose executor GUI framework with Nova's visual style.
	
	Layout:
	- Title bar with icon, title, version, settings gear, minimize, close
	- Left sidebar with category list
	- Right content area with options for selected category
	- Settings panel (DPI scale, etc.)
	
	API:
		local Nova = loadstring(...)()
		local Main = Nova:AddCategory("Main", "home")
		Main:AddToggle("Aimbot", false, function(value) end)
		Main:AddSlider("FOV", 50, 1, 360, function(value) end)
		Main:AddDropdown("Mode", {"Silent", "Legit"}, "Silent", function(value) end)
		Main:AddButton("Execute", function() end)
		Main:AddKeybind("Toggle", Enum.KeyCode.RightShift, function(key) end)
		Main:AddLabel("Status: Ready")
		Main:AddSeparator()
]]

-- UI Modules
local UI = script.UI
local Theme = require(UI.Theme)
local Interface = require(UI.Interface)
local Helper = require(UI.Helper)
local Resize = require(UI.Resize)
local Drag = require(UI.Drag)
local Sonner = require(UI.Sonner)
local Icons = require(UI.Icons)

-- Services
for _, Service in pairs({
	"CoreGui",
	"TweenService",
	"Players",
	"UserInputService",
}) do
	wax.shared[Service] = cloneref(game:GetService(Service))
end

local TweenService = wax.shared.TweenService
local UserInputService = wax.shared.UserInputService

-- Default tween info
local DefaultTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Library state
local Library = {}
Library.Categories = {}
Library.CategoryOrder = {}
Library.ActiveCategory = nil
Library.SettingsVisible = false

-- ============================================================
-- SCREEN GUI
-- ============================================================

local ScreenGui = Interface.CreateScreenGui("NovaUI")

local ScreenDPIScale = Interface.New("UIScale", {
	Scale = 1,
	Parent = ScreenGui,
})

Sonner.Initialize(ScreenGui, Icons)

-- ============================================================
-- MAIN FRAME
-- ============================================================

local MainFrame = Interface.New("Frame", {
	BackgroundColor3 = Theme.Background,
	Size = UDim2.fromOffset(620, 450),
	Position = UDim2.new(0.5, -310, 0.5, -225),
	BorderSizePixel = 0,
	Parent = ScreenGui,
	["UICorner"] = { CornerRadius = UDim.new(0, 8) },
	["UIStroke"] = { Color = Theme.Border, Thickness = 1 },
})

-- ============================================================
-- TITLE BAR
-- ============================================================

local TitleBar = Interface.New("Frame", {
	BackgroundColor3 = Theme.Surface,
	Size = UDim2.new(1, 0, 0, 36),
	BorderSizePixel = 0,
	Parent = MainFrame,
	["UICorner"] = { CornerRadius = UDim.new(0, 8) },
})

Interface.New("Frame", {
	BackgroundColor3 = Theme.Surface,
	Size = UDim2.new(1, 0, 0, 10),
	Position = UDim2.new(0, 0, 1, -10),
	BorderSizePixel = 0,
	Parent = TitleBar,
})

Drag.new(MainFrame, TitleBar, function() return ScreenDPIScale.Scale end)

-- Title icon
local TitleIcon = Interface.New("ImageLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(18, 18),
	Position = UDim2.new(0, 12, 0.5, 0),
	AnchorPoint = Vector2.new(0, 0.5),
	ImageColor3 = Theme.Accent,
	Parent = TitleBar,
})
Icons.ApplyIcon(TitleIcon, "radar")

Interface.New("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.new(0, 200, 1, 0),
	Position = UDim2.new(0, 36, 0, 0),
	Text = "Nova",
	TextColor3 = Theme.Text,
	TextSize = 16,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = TitleBar,
})

Interface.New("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.new(0, 60, 0, 18),
	Position = UDim2.new(0, 72, 0.5, 0),
	AnchorPoint = Vector2.new(0, 0.5),
	Text = "Fisch",
	TextColor3 = Theme.TextMuted,
	TextSize = 11,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = TitleBar,
})

-- Window buttons container
local WindowButtons = Interface.New("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.new(0, 110, 1, 0),
	Position = UDim2.new(1, -110, 0, 0),
	Parent = TitleBar,
	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
	},
	["UIPadding"] = { PaddingRight = UDim.new(0, 8) },
})

local function CreateWindowButton(iconName, callback)
	local btn = Interface.New("TextButton", {
		Text = "",
		BackgroundColor3 = Theme.SurfaceHover,
		BackgroundTransparency = 0.5,
		Size = UDim2.fromOffset(28, 28),
		Parent = WindowButtons,
		AutoButtonColor = false,
		["UICorner"] = { CornerRadius = UDim.new(0, 6) },
	})

	local icon = Interface.New("ImageLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ImageColor3 = Theme.TextMuted,
		Parent = btn,
	})
	Icons.ApplyIcon(icon, iconName)

	Helper.HoverEffect(btn, Theme.SurfaceHover, Theme.Surface)
	btn.MouseButton1Click:Connect(callback)
	return btn
end

-- Settings gear button
CreateWindowButton("settings", function()
	Library:ToggleSettings()
end)

-- Separator dot
Interface.New("Frame", {
	BackgroundColor3 = Color3.fromRGB(50, 50, 50),
	Size = UDim2.fromOffset(4, 4),
	Parent = WindowButtons,
	["UICorner"] = { CornerRadius = UDim.new(1, 0) },
})

-- Minimize & Close
CreateWindowButton("minus", function() MainFrame.Visible = not MainFrame.Visible end)
CreateWindowButton("x", function() ScreenGui:Destroy() end)

-- ============================================================
-- LEFT SIDEBAR (CATEGORIES)
-- ============================================================

local Sidebar = Interface.New("Frame", {
	BackgroundColor3 = Theme.Surface,
	Size = UDim2.new(0, 160, 1, -36),
	Position = UDim2.new(0, 0, 0, 36),
	BorderSizePixel = 0,
	Parent = MainFrame,
})

local SidebarScroll = Interface.New("ScrollingFrame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	BorderSizePixel = 0,
	ScrollBarThickness = 2,
	ScrollBarImageColor3 = Theme.Border,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.fromScale(0, 0),
	Parent = Sidebar,
	["UIListLayout"] = {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
	},
	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	},
})

-- ============================================================
-- SIDEBAR DIVIDER (RESIZABLE)
-- ============================================================

local SidebarDivider = Interface.New("Frame", {
	BackgroundColor3 = Color3.fromRGB(25, 25, 25),
	Size = UDim2.new(0, 2, 1, -36),
	Position = UDim2.new(0, 160, 0, 36),
	ZIndex = 5,
	Parent = MainFrame,
})

local DividerHandle = Interface.New("TextButton", {
	Text = "",
	BackgroundTransparency = 1,
	Size = UDim2.new(0, 8, 1, 0),
	Position = UDim2.new(0.5, 0, 0, 0),
	AnchorPoint = Vector2.new(0.5, 0),
	AutoButtonColor = false,
	ZIndex = 6,
	Parent = SidebarDivider,
})

local isDraggingDivider = false
local dividerDragStart = nil
local dividerStartWidth = 160

DividerHandle.MouseEnter:Connect(function() SidebarDivider.BackgroundColor3 = Color3.fromRGB(50, 50, 50) end)
DividerHandle.MouseLeave:Connect(function() if not isDraggingDivider then SidebarDivider.BackgroundColor3 = Color3.fromRGB(25, 25, 25) end end)
DividerHandle.MouseButton1Down:Connect(function()
	isDraggingDivider = true
	dividerDragStart = UserInputService:GetMouseLocation().X
	dividerStartWidth = Sidebar.Size.X.Offset
end)

-- Forward declare ContentWrapper for divider logic
local ContentWrapper

UserInputService.InputChanged:Connect(function(input)
	if isDraggingDivider and input.UserInputType == Enum.UserInputType.MouseMovement then
		local scale = ScreenDPIScale.Scale
		local delta = (input.Position.X - dividerDragStart) / scale
		local newWidth = math.clamp(dividerStartWidth + delta, 120, math.floor(MainFrame.AbsoluteSize.X / 2))
		Sidebar.Size = UDim2.new(0, newWidth, 1, -36)
		SidebarDivider.Position = UDim2.new(0, newWidth, 0, 36)
		if ContentWrapper then
			ContentWrapper.Size = UDim2.new(1, -(newWidth + 2), 1, -36)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isDraggingDivider = false
		SidebarDivider.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	end
end)

-- ============================================================
-- CONTENT AREA (RIGHT SIDE)
-- ============================================================

ContentWrapper = Interface.New("Frame", {
	AnchorPoint = Vector2.one,
	BackgroundTransparency = 1,
	Position = UDim2.fromScale(1, 1),
	Size = UDim2.new(1, -162, 1, -36),
	Parent = MainFrame,
	["UIPadding"] = {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
	},
})

-- ============================================================
-- SETTINGS PANEL
-- ============================================================

local SettingsFrame = Interface.New("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	Parent = ContentWrapper,
	["UIPadding"] = { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 4) },
})

local SettingsScroll = Interface.New("ScrollingFrame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.fromScale(0, 0),
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = Theme.Border,
	BorderSizePixel = 0,
	Parent = SettingsFrame,
	["UIListLayout"] = { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 8) },
})

local function CreateSettingsSection(title)
	local wrapper = Interface.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = SettingsScroll,
		["UIListLayout"] = { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) },
	})

	Interface.New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 0,
		Text = string.upper(title),
		TextColor3 = Theme.TextMuted,
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = wrapper,
	})

	local section = Interface.New("Frame", {
		BackgroundColor3 = Theme.Surface,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = wrapper,
		["UICorner"] = { CornerRadius = UDim.new(0, 8) },
		["UIStroke"] = { Color = Theme.Border, Thickness = 1, Transparency = 0.5 },
		["UIListLayout"] = { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0) },
		["UIPadding"] = { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) },
	})

	return section
end

local settingsRowOrder = 0
local function CreateSettingsRow(section)
	settingsRowOrder += 1
	return Interface.New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = settingsRowOrder,
		Parent = section,
	})
end

local function CreateSettingsToggle(section, text, default, callback)
	local value = default or false
	local row = CreateSettingsRow(section)

	Interface.New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -52, 1, 0),
		Text = text,
		TextColor3 = Theme.Text,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})

	local toggleTrack = Interface.New("TextButton", {
		Text = "",
		BackgroundColor3 = value and Theme.Accent or Theme.SurfaceHover,
		Size = UDim2.fromOffset(40, 22),
		Position = UDim2.new(1, -44, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		AutoButtonColor = false,
		Parent = row,
		["UICorner"] = { CornerRadius = UDim.new(1, 0) },
	})

	local toggleKnob = Interface.New("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.fromOffset(16, 16),
		Position = value and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = toggleTrack,
		["UICorner"] = { CornerRadius = UDim.new(1, 0) },
	})

	toggleTrack.MouseButton1Click:Connect(function()
		value = not value
		TweenService:Create(toggleTrack, DefaultTweenInfo, { BackgroundColor3 = value and Theme.Accent or Theme.SurfaceHover }):Play()
		TweenService:Create(toggleKnob, DefaultTweenInfo, { Position = value and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }):Play()
		if callback then callback(value) end
	end)
end

local function CreateSettingsDropdown(section, text, values, default, callback)
	local row = CreateSettingsRow(section)
	local currentIndex = table.find(values, default) or 1

	Interface.New("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.55, 0, 1, 0),
		Text = text,
		TextColor3 = Theme.Text,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local valueLabel = Interface.New("TextButton", {
		Text = default,
		TextColor3 = Theme.TextMuted,
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		BackgroundColor3 = Theme.SurfaceHover,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 100, 0, 26),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		AutoButtonColor = false,
		Parent = row,
		["UICorner"] = { CornerRadius = UDim.new(0, 6) },
	})

	valueLabel.MouseButton1Click:Connect(function()
		currentIndex = (currentIndex % #values) + 1
		local newValue = values[currentIndex]
		valueLabel.Text = newValue
		if callback then callback(newValue) end
	end)
end

-- Fisch State (declared early for settings references)
local ToggleKey = Enum.KeyCode.RightShift

-- Build settings sections
local GeneralSection = CreateSettingsSection("General")
CreateSettingsDropdown(GeneralSection, "DPI Scale", { "50%", "75%", "100%", "125%", "150%" }, "100%", function(value)
local scaleNumber = tonumber(string.match(value, "%d+"))
ScreenDPIScale.Scale = (scaleNumber or 100) / 100
end)

-- Toggle GUI Key setting
local KeybindSection = CreateSettingsSection("Keybinds")
local toggleKeyRow = CreateSettingsRow(KeybindSection)

Interface.New("TextLabel", {
BackgroundTransparency = 1,
Size = UDim2.new(1, -90, 1, 0),
Text = "Toggle GUI Key",
TextColor3 = Theme.Text,
TextSize = 13,
Font = Enum.Font.GothamMedium,
TextXAlignment = Enum.TextXAlignment.Left,
TextTruncate = Enum.TextTruncate.AtEnd,
Parent = toggleKeyRow,
})

local toggleKeyBtn = Interface.New("TextButton", {
Text = ToggleKey.Name,
TextColor3 = Theme.TextMuted,
TextSize = 11,
Font = Enum.Font.GothamBold,
BackgroundColor3 = Theme.SurfaceHover,
BorderSizePixel = 0,
Size = UDim2.new(0, 80, 0, 24),
Position = UDim2.new(1, -80, 0.5, 0),
AnchorPoint = Vector2.new(0, 0.5),
AutoButtonColor = false,
Parent = toggleKeyRow,
["UICorner"] = { CornerRadius = UDim.new(0, 4) },
})

local isListeningToggleKey = false
toggleKeyBtn.MouseButton1Click:Connect(function()
isListeningToggleKey = true
toggleKeyBtn.Text = "..."
toggleKeyBtn.TextColor3 = Theme.Accent
end)

UserInputService.InputBegan:Connect(function(input)
if not isListeningToggleKey then return end
if input.UserInputType == Enum.UserInputType.Keyboard then
isListeningToggleKey = false
ToggleKey = input.KeyCode
toggleKeyBtn.Text = ToggleKey.Name
toggleKeyBtn.TextColor3 = Theme.TextMuted
end
end)

-- Unload button
local DangerSection = CreateSettingsSection("Danger Zone")
local unloadRow = CreateSettingsRow(DangerSection)

local unloadBtn = Interface.New("TextButton", {
Text = "",
BackgroundTransparency = 1,
Size = UDim2.new(1, 0, 1, -8),
Position = UDim2.new(0, 0, 0, 4),
AutoButtonColor = false,
ClipsDescendants = true,
Parent = unloadRow,
})

local unloadIcon = Interface.New("ImageLabel", {
BackgroundTransparency = 1,
Size = UDim2.fromOffset(14, 14),
Position = UDim2.new(0, 10, 0.5, 0),
AnchorPoint = Vector2.new(0, 0.5),
ImageColor3 = Theme.Error,
Parent = unloadBtn,
})
Icons.ApplyIcon(unloadIcon, "power")

Interface.New("TextLabel", {
BackgroundTransparency = 1,
Size = UDim2.new(1, -34, 1, 0),
Position = UDim2.new(0, 30, 0, 0),
Text = "Unload Nova",
TextColor3 = Theme.Error,
TextSize = 13,
Font = Enum.Font.GothamBold,
TextXAlignment = Enum.TextXAlignment.Left,
Parent = unloadBtn,
})

unloadBtn.MouseEnter:Connect(function()
unloadBtn.BackgroundTransparency = 0.85
unloadBtn.BackgroundColor3 = Theme.Error
end)
unloadBtn.MouseLeave:Connect(function()
unloadBtn.BackgroundTransparency = 1
end)
unloadBtn.MouseButton1Click:Connect(function()
ScreenGui:Destroy()
end)

local AboutSection = CreateSettingsSection("About")
Interface.New("TextLabel", {
BackgroundTransparency = 1,
Size = UDim2.new(1, 0, 0, 24),
Text = "<b>Nova UI</b>  04xSkater",
TextColor3 = Theme.TextMuted,
TextSize = 12,
Font = Enum.Font.GothamMedium,
TextXAlignment = Enum.TextXAlignment.Left,
RichText = true,
Parent = AboutSection,
})

-- ============================================================
-- OPTION ELEMENT BUILDERS
-- ============================================================

local optionOrder = 0
local function NextOrder()
optionOrder += 1
return optionOrder
end

local function CreateToggle(parent, text, default, callback)
local value = default or false
local container = Interface.New("Frame", {
BackgroundColor3 = Color3.fromRGB(25, 25, 25),
Size = UDim2.new(1, 0, 0, 38),
LayoutOrder = NextOrder(),
Parent = parent,
["UICorner"] = { CornerRadius = UDim.new(0, 6) },
["UIPadding"] = { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) },
})

Interface.New("TextLabel", {
BackgroundTransparency = 1,
Size = UDim2.new(1, -52, 1, 0),
Text = text,
TextColor3 = Theme.Text,
TextSize = 13,
Font = Enum.Font.GothamMedium,
TextXAlignment = Enum.TextXAlignment.Left,
TextTruncate = Enum.TextTruncate.AtEnd,
Parent = container,
})

local toggleTrack = Interface.New("TextButton", {
Text = "",
BackgroundColor3 = value and Theme.Accent or Theme.SurfaceHover,
Size = UDim2.fromOffset(40, 22),
Position = UDim2.new(1, -44, 0.5, 0),
AnchorPoint = Vector2.new(0, 0.5),
AutoButtonColor = false,
Parent = container,
["UICorner"] = { CornerRadius = UDim.new(1, 0) },
})

local toggleKnob = Interface.New("Frame", {
BackgroundColor3 = Color3.fromRGB(255, 255, 255),
Size = UDim2.fromOffset(16, 16),
Position = value and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
AnchorPoint = Vector2.new(0, 0.5),
Parent = toggleTrack,
["UICorner"] = { CornerRadius = UDim.new(1, 0) },
})

local element = {
Type = "Toggle",
Value = value,
Set = function(self, newValue)
self.Value = newValue
TweenService:Create(toggleTrack, DefaultTweenInfo, { BackgroundColor3 = newValue and Theme.Accent or Theme.SurfaceHover }):Play()
TweenService:Create(toggleKnob, DefaultTweenInfo, { Position = newValue and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }):Play()
end,
}

toggleTrack.MouseButton1Click:Connect(function()
element.Value = not element.Value
element:Set(element.Value)
if callback then callback(element.Value) end
end)

return element
end

local function CreateSlider(parent, text, default, min, max, callback)
local value = math.clamp(default or min, min, max)

local container = Interface.New("Frame", {
BackgroundColor3 = Color3.fromRGB(25, 25, 25),
Size = UDim2.new(1, 0, 0, 50),
LayoutOrder = NextOrder(),
Parent = parent,
["UICorner"] = { CornerRadius = UDim.new(0, 6) },
["UIPadding"] = { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) },
})

Interface.New("TextLabel", {
BackgroundTransparency = 1,
Size = UDim2.new(1, -60, 0, 20),
Position = UDim2.new(0, 0, 0, 6),
Text = text,
TextColor3 = Theme.Text,
TextSize = 13,
Font = Enum.Font.GothamMedium,
TextXAlignment = Enum.TextXAlignment.Left,
Parent = container,
})

local valueLabel = Interface.New("TextLabel", {
BackgroundTransparency = 1,
Size = UDim2.new(0, 50, 0, 20),
Position = UDim2.new(1, -50, 0, 6),
Text = tostring(math.floor(value)),
TextColor3 = Theme.Accent,
TextSize = 13,
Font = Enum.Font.GothamBold,
TextXAlignment = Enum.TextXAlignment.Right,
Parent = container,
})

local sliderBg = Interface.New("Frame", {
BackgroundColor3 = Theme.SurfaceHover,
Size = UDim2.new(1, 0, 0, 6),
Position = UDim2.new(0, 0, 0, 34),
Parent = container,
["UICorner"] = { CornerRadius = UDim.new(1, 0) },
})

local sliderFill = Interface.New("Frame", {
BackgroundColor3 = Theme.Accent,
Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
Parent = sliderBg,
["UICorner"] = { CornerRadius = UDim.new(1, 0) },
})

local sliderKnob = Interface.New("Frame", {
BackgroundColor3 = Color3.fromRGB(255, 255, 255),
Size = UDim2.fromOffset(12, 12),
Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0),
AnchorPoint = Vector2.new(0.5, 0.5),
ZIndex = 2,
Parent = sliderBg,
["UICorner"] = { CornerRadius = UDim.new(1, 0) },
})

local isDragging = false

local function UpdateSlider(inputX)
local relativeX = (inputX - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
relativeX = math.clamp(relativeX, 0, 1)
value = math.floor(min + (max - min) * relativeX)
valueLabel.Text = tostring(value)
sliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
sliderKnob.Position = UDim2.new(relativeX, 0, 0.5, 0)
if callback then callback(value) end
end

sliderBg.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 then
isDragging = true
UpdateSlider(input.Position.X)
end
end)

sliderKnob.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 then
isDragging = true
end
end)

UserInputService.InputChanged:Connect(function(input)
if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
UpdateSlider(input.Position.X)
end
end)

UserInputService.InputEnded:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 then
isDragging = false
end
end)

return {
Type = "Slider",
Value = value,
Set = function(self, newValue)
value = math.clamp(math.floor(newValue), min, max)
self.Value = value
local pct = (value - min) / (max - min)
valueLabel.Text = tostring(value)
sliderFill.Size = UDim2.new(pct, 0, 1, 0)
sliderKnob.Position = UDim2.new(pct, 0, 0.5, 0)
end,
}
end

local function CreateDropdown(parent, text, options, default, callback)
local currentIndex = table.find(options, default) or 1
local value = options[currentIndex]

local container = Interface.New("Frame", {
BackgroundColor3 = Color3.fromRGB(25, 25, 25),
Size = UDim2.new(1, 0, 0, 38),
LayoutOrder = NextOrder(),
Parent = parent,
["UICorner"] = { CornerRadius = UDim.new(0, 6) },
["UIPadding"] = { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) },
})

Interface.New("TextLabel", {
BackgroundTransparency = 1,
Size = UDim2.new(1, -120, 1, 0),
Text = text,
TextColor3 = Theme.Text,
TextSize = 13,
Font = Enum.Font.GothamMedium,
TextXAlignment = Enum.TextXAlignment.Left,
TextTruncate = Enum.TextTruncate.AtEnd,
Parent = container,
})

local dropdownBtn = Interface.New("TextButton", {
Text = value,
TextColor3 = Theme.TextMuted,
TextSize = 12,
Font = Enum.Font.GothamMedium,
BackgroundColor3 = Theme.SurfaceHover,
BorderSizePixel = 0,
Size = UDim2.new(0, 110, 0, 26),
Position = UDim2.new(1, -110, 0.5, 0),
AnchorPoint = Vector2.new(0, 0.5),
AutoButtonColor = false,
Parent = container,
["UICorner"] = { CornerRadius = UDim.new(0, 6) },
})

local arrowIcon = Interface.New("ImageLabel", {
BackgroundTransparency = 1,
Size = UDim2.fromOffset(10, 10),
Position = UDim2.new(1, -14, 0.5, 0),
AnchorPoint = Vector2.new(0, 0.5),
ImageColor3 = Theme.TextMuted,
Parent = dropdownBtn,
})
Icons.ApplyIcon(arrowIcon, "chevron-down")

dropdownBtn.MouseButton1Click:Connect(function()
currentIndex = (currentIndex % #options) + 1
value = options[currentIndex]
dropdownBtn.Text = value
if callback then callback(value) end
end)

Helper.HoverEffect(dropdownBtn, Theme.Border, Theme.SurfaceHover)

return {
Type = "Dropdown",
Value = value,
Set = function(self, newValue)
local idx = table.find(options, newValue)
if idx then
currentIndex = idx
value = newValue
self.Value = value
dropdownBtn.Text = value
end
end,
UpdateOptions = function(self, newOptions, newDefault)
if not newOptions or #newOptions == 0 then return end
options = newOptions
local idx = table.find(options, newDefault)
if idx then
currentIndex = idx
value = options[idx]
else
currentIndex = 1
value = options[1]
end
self.Value = value
dropdownBtn.Text = value
end,
}
end

local function CreateButton(parent, text, callback)
local container = Interface.New("TextButton", {
Text = "",
BackgroundColor3 = Color3.fromRGB(25, 25, 25),
Size = UDim2.new(1, 0, 0, 38),
LayoutOrder = NextOrder(),
AutoButtonColor = false,
ClipsDescendants = true,
Parent = parent,
["UICorner"] = { CornerRadius = UDim.new(0, 6) },
["UIPadding"] = { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) },
})

local btnIcon = Interface.New("ImageLabel", {
BackgroundTransparency = 1,
Size = UDim2.fromOffset(14, 14),
Position = UDim2.new(0, 0, 0.5, 0),
AnchorPoint = Vector2.new(0, 0.5),
ImageColor3 = Theme.Accent,
Parent = container,
})
Icons.ApplyIcon(btnIcon, "play")

Interface.New("TextLabel", {
BackgroundTransparency = 1,
Size = UDim2.new(1, -24, 1, 0),
Position = UDim2.new(0, 20, 0, 0),
Text = text,
TextColor3 = Theme.Text,
TextSize = 13,
Font = Enum.Font.GothamMedium,
TextXAlignment = Enum.TextXAlignment.Left,
Parent = container,
})

Helper.HoverEffect(container, Color3.fromRGB(30, 30, 30), Color3.fromRGB(25, 25, 25))

container.MouseButton1Click:Connect(function()
Helper.Ripple(container)
if callback then callback() end
end)

return { Type = "Button" }
end

local function CreateKeybind(parent, text, default, callback)
local currentKey = default or Enum.KeyCode.Unknown
local isListening = false

local container = Interface.New("Frame", {
BackgroundColor3 = Color3.fromRGB(25, 25, 25),
Size = UDim2.new(1, 0, 0, 38),
LayoutOrder = NextOrder(),
Parent = parent,
["UICorner"] = { CornerRadius = UDim.new(0, 6) },
["UIPadding"] = { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) },
})

Interface.New("TextLabel", {
BackgroundTransparency = 1,
Size = UDim2.new(1, -90, 1, 0),
Text = text,
TextColor3 = Theme.Text,
TextSize = 13,
Font = Enum.Font.GothamMedium,
TextXAlignment = Enum.TextXAlignment.Left,
TextTruncate = Enum.TextTruncate.AtEnd,
Parent = container,
})

local keyBtn = Interface.New("TextButton", {
Text = currentKey.Name,
TextColor3 = Theme.TextMuted,
TextSize = 11,
Font = Enum.Font.GothamBold,
BackgroundColor3 = Theme.SurfaceHover,
BorderSizePixel = 0,
Size = UDim2.new(0, 80, 0, 24),
Position = UDim2.new(1, -80, 0.5, 0),
AnchorPoint = Vector2.new(0, 0.5),
AutoButtonColor = false,
Parent = container,
["UICorner"] = { CornerRadius = UDim.new(0, 4) },
})

keyBtn.MouseButton1Click:Connect(function()
isListening = true
keyBtn.Text = "..."
keyBtn.TextColor3 = Theme.Accent
end)

UserInputService.InputBegan:Connect(function(input)
if not isListening then return end
if input.UserInputType == Enum.UserInputType.Keyboard then
isListening = false
currentKey = input.KeyCode
keyBtn.Text = currentKey.Name
keyBtn.TextColor3 = Theme.TextMuted
if callback then callback(currentKey) end
end
end)

return {
Type = "Keybind",
Value = currentKey,
Set = function(self, key)
currentKey = key
self.Value = key
keyBtn.Text = key.Name
end,
}
end

local function CreateLabel(parent, text)
local label = Interface.New("TextLabel", {
BackgroundTransparency = 1,
Size = UDim2.new(1, 0, 0, 24),
LayoutOrder = NextOrder(),
Text = text,
TextColor3 = Theme.TextMuted,
TextSize = 12,
Font = Enum.Font.GothamMedium,
TextXAlignment = Enum.TextXAlignment.Left,
Parent = parent,
["UIPadding"] = { PaddingLeft = UDim.new(0, 4) },
})

return {
Type = "Label",
Set = function(_, newText) label.Text = newText end,
}
end

local function CreateSeparator(parent)
Interface.New("Frame", {
BackgroundColor3 = Theme.Border,
Size = UDim2.new(1, 0, 0, 1),
LayoutOrder = NextOrder(),
Parent = parent,
})
end

local function CreateTextInput(parent, text, placeholder, callback)
local container = Interface.New("Frame", {
BackgroundColor3 = Color3.fromRGB(25, 25, 25),
Size = UDim2.new(1, 0, 0, 38),
LayoutOrder = NextOrder(),
Parent = parent,
["UICorner"] = { CornerRadius = UDim.new(0, 6) },
["UIPadding"] = { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) },
})

Interface.New("TextLabel", {
BackgroundTransparency = 1,
Size = UDim2.new(0.45, 0, 1, 0),
Text = text,
TextColor3 = Theme.Text,
TextSize = 13,
Font = Enum.Font.GothamMedium,
TextXAlignment = Enum.TextXAlignment.Left,
TextTruncate = Enum.TextTruncate.AtEnd,
Parent = container,
})

local inputBox = Interface.New("TextBox", {
BackgroundColor3 = Theme.SurfaceHover,
Size = UDim2.new(0.5, 0, 0, 26),
Position = UDim2.new(1, 0, 0.5, 0),
AnchorPoint = Vector2.new(1, 0.5),
Text = "",
PlaceholderText = placeholder or "...",
PlaceholderColor3 = Color3.fromRGB(80, 80, 80),
TextColor3 = Theme.Text,
TextSize = 12,
Font = Enum.Font.GothamMedium,
TextXAlignment = Enum.TextXAlignment.Left,
ClearTextOnFocus = false,
Parent = container,
["UICorner"] = { CornerRadius = UDim.new(0, 6) },
["UIPadding"] = { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) },
})

inputBox.FocusLost:Connect(function(enterPressed)
if callback then callback(inputBox.Text, enterPressed) end
end)

return {
Type = "TextInput",
Value = "",
Set = function(self, newText) inputBox.Text = newText; self.Value = newText end,
}
end

-- ============================================================
-- CATEGORY CLASS
-- ============================================================

local Category = {}
Category.__index = Category

function Category.new(name, iconName, contentParent)
local self = setmetatable({}, Category)
self.Name = name
self.IconName = iconName
self.ContentFrame = Interface.New("Frame", {
BackgroundTransparency = 1,
Size = UDim2.fromScale(1, 1),
Visible = false,
Parent = contentParent,
})

local categoryScroll = Interface.New("ScrollingFrame", {
BackgroundTransparency = 1,
Size = UDim2.fromScale(1, 1),
AutomaticCanvasSize = Enum.AutomaticSize.Y,
CanvasSize = UDim2.fromScale(0, 0),
ScrollBarThickness = 3,
ScrollBarImageColor3 = Theme.Border,
BorderSizePixel = 0,
Parent = self.ContentFrame,
["UIListLayout"] = {
FillDirection = Enum.FillDirection.Vertical,
Padding = UDim.new(0, 4),
SortOrder = Enum.SortOrder.LayoutOrder,
},
})

self.Scroll = categoryScroll
self.Elements = {}
return self
end

function Category:AddToggle(text, default, callback)
local elem = CreateToggle(self.Scroll, text, default, callback)
table.insert(self.Elements, elem)
return elem
end

function Category:AddSlider(text, default, min, max, callback)
local elem = CreateSlider(self.Scroll, text, default, min, max, callback)
table.insert(self.Elements, elem)
return elem
end

function Category:AddDropdown(text, options, default, callback)
local elem = CreateDropdown(self.Scroll, text, options, default, callback)
table.insert(self.Elements, elem)
return elem
end

function Category:AddButton(text, callback)
local elem = CreateButton(self.Scroll, text, callback)
table.insert(self.Elements, elem)
return elem
end

function Category:AddKeybind(text, default, callback)
local elem = CreateKeybind(self.Scroll, text, default, callback)
table.insert(self.Elements, elem)
return elem
end

function Category:AddLabel(text)
local elem = CreateLabel(self.Scroll, text)
table.insert(self.Elements, elem)
return elem
end

function Category:AddSeparator()
CreateSeparator(self.Scroll)
end

function Category:AddTextInput(text, placeholder, callback)
local elem = CreateTextInput(self.Scroll, text, placeholder, callback)
table.insert(self.Elements, elem)
return elem
end

-- ============================================================
-- LIBRARY API
-- ============================================================

function Library:AddCategory(name, iconName)
local category = Category.new(name, iconName or "folder", ContentWrapper)
local order = #self.CategoryOrder + 1

local btn = Interface.New("TextButton", {
Text = "",
BackgroundColor3 = Theme.Surface,
Size = UDim2.new(1, 0, 0, 36),
LayoutOrder = order,
AutoButtonColor = false,
Parent = SidebarScroll,
["UICorner"] = { CornerRadius = UDim.new(0, 6) },
})

local btnIcon = Interface.New("ImageLabel", {
BackgroundTransparency = 1,
Size = UDim2.fromOffset(14, 14),
Position = UDim2.new(0, 10, 0.5, 0),
AnchorPoint = Vector2.new(0, 0.5),
ImageColor3 = Theme.TextMuted,
Parent = btn,
})
Icons.ApplyIcon(btnIcon, iconName or "folder")

local btnLabel = Interface.New("TextLabel", {
BackgroundTransparency = 1,
Size = UDim2.new(1, -36, 1, 0),
Position = UDim2.new(0, 30, 0, 0),
Text = name,
TextColor3 = Theme.TextMuted,
TextSize = 13,
Font = Enum.Font.GothamMedium,
TextXAlignment = Enum.TextXAlignment.Left,
TextTruncate = Enum.TextTruncate.AtEnd,
Parent = btn,
})

Helper.HoverEffect(btn, Theme.SurfaceHover, Theme.Surface)

category.SidebarButton = btn
category.SidebarIcon = btnIcon
category.SidebarLabel = btnLabel

self.Categories[name] = category
table.insert(self.CategoryOrder, name)

btn.MouseButton1Click:Connect(function()
self:SelectCategory(name)
end)

if #self.CategoryOrder == 1 then
self:SelectCategory(name)
end

return category
end

function Library:SelectCategory(name)
self.ActiveCategory = name
self.SettingsVisible = false

for catName, cat in pairs(self.Categories) do
local isActive = (catName == name)
cat.SidebarButton.BackgroundColor3 = isActive and Theme.Accent or Theme.Surface
cat.SidebarLabel.TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or Theme.TextMuted
cat.SidebarIcon.ImageColor3 = isActive and Color3.fromRGB(255, 255, 255) or Theme.TextMuted
cat.ContentFrame.Visible = isActive
end

SettingsFrame.Visible = false
end

function Library:ToggleSettings()
self.SettingsVisible = not self.SettingsVisible

if self.SettingsVisible then
for _, cat in pairs(self.Categories) do
cat.SidebarButton.BackgroundColor3 = Theme.Surface
cat.SidebarLabel.TextColor3 = Theme.TextMuted
cat.SidebarIcon.ImageColor3 = Theme.TextMuted
cat.ContentFrame.Visible = false
end
SettingsFrame.Visible = true
else
if self.ActiveCategory and self.Categories[self.ActiveCategory] then
self:SelectCategory(self.ActiveCategory)
end
end
end

function Library:Notify(text, notifType)
if notifType == "success" then
Sonner.success(text)
elseif notifType == "error" then
Sonner.error(text)
elseif notifType == "warning" then
Sonner.warning(text)
else
Sonner.info(text)
end
end

function Library:Destroy()
ScreenGui:Destroy()
end

function Library:SetVisible(visible)
MainFrame.Visible = visible
end

function Library:Toggle()
MainFrame.Visible = not MainFrame.Visible
end

-- Toggle keybind
UserInputService.InputBegan:Connect(function(input, gameProcessed)
if gameProcessed then return end
if input.KeyCode == ToggleKey then
Library:Toggle()
end
end)

-- ============================================================
-- GUI CATEGORIES + FISCH INTEGRATION
-- ============================================================

-- Callback forwarding table (populated by pcall game logic below)
local GameCallbacks = {}

-- Fishing category
local Fishing = Library:AddCategory("Fishing", "anchor")
Fishing:AddToggle("Auto Fish", false, function(v)
if GameCallbacks.autoFish then GameCallbacks.autoFish(v) end
end)
Fishing:AddDropdown("Shake Mode", {"Mouse", "Phantom"}, "Mouse", function(v)
if GameCallbacks.shakeMode then GameCallbacks.shakeMode(v) end
end)
Fishing:AddSlider("Shake Delay", 0.3, 0.1, 1.0, function(v)
if GameCallbacks.shakeDelay then GameCallbacks.shakeDelay(v) end
end)
Fishing:AddToggle("No Shake Delay", false, function(v)
if GameCallbacks.noShakeDelay then GameCallbacks.noShakeDelay(v) end
end)
Fishing:AddSeparator()
Fishing:AddToggle("Freeze Position", false, function(v)
if GameCallbacks.freeze then GameCallbacks.freeze(v) end
end)
Fishing:AddToggle("Anti-AFK", false, function(v)
if GameCallbacks.antiAfk then GameCallbacks.antiAfk(v) end
end)

-- Items category
local Items = Library:AddCategory("Items", "package")
Items:AddButton("Sell Hand", function()
if GameCallbacks.sellHand then GameCallbacks.sellHand() end
end)
Items:AddButton("Sell All", function()
if GameCallbacks.sellAll then GameCallbacks.sellAll() end
end)

-- Teleports category
local Teleports = Library:AddCategory("Teleports", "map-pin")
local AreaDropdown = Teleports:AddDropdown("Area Teleport", {"(loading...)"}, "(loading...)", function(v)
if v ~= "(loading...)" and GameCallbacks.areaTp then GameCallbacks.areaTp(v) end
end)
Teleports:AddDropdown("Totem Teleport", {"Aurora", "Sundial", "Windset", "Smokescreen", "Tempest"}, "Aurora", function(v)
if GameCallbacks.totemTp then GameCallbacks.totemTp(v) end
end)
Teleports:AddDropdown("World Event", {"Whirlpool", "Hammerhead", "White Shark", "Whale Shark", "Serpent"}, "Whirlpool", function(v)
if GameCallbacks.worldEventTp then GameCallbacks.worldEventTp(v) end
end)
Teleports:AddButton("Teleport to Merchant", function()
if GameCallbacks.merchantTp then GameCallbacks.merchantTp() end
end)

-- Character category
local Character = Library:AddCategory("Character", "user")
Character:AddToggle("Walk On Water", false, function(v)
if GameCallbacks.walkOnWater then GameCallbacks.walkOnWater(v) end
end)
Character:AddDropdown("Walk Zone", {"Ocean", "Desolate Deep", "The Depths"}, "Ocean", function(v)
if GameCallbacks.walkZone then GameCallbacks.walkZone(v) end
end)
Character:AddSeparator()
Character:AddSlider("Walk Speed", 16, 16, 200, function(v)
if GameCallbacks.walkSpeed then GameCallbacks.walkSpeed(v) end
end)
Character:AddSlider("Jump Height", 50, 50, 200, function(v)
if GameCallbacks.jumpHeight then GameCallbacks.jumpHeight(v) end
end)
Character:AddToggle("Noclip", false, function(v)
if GameCallbacks.noclip then GameCallbacks.noclip(v) end
end)

-- Misc category
local Misc = Library:AddCategory("Misc", "list")
Misc:AddToggle("Bypass Fish Radar", false, function(v)
if GameCallbacks.bypassRadar then GameCallbacks.bypassRadar(v) end
end)
Misc:AddToggle("Remove Fog", false, function(v)
if GameCallbacks.removeFog then GameCallbacks.removeFog(v) end
end)
Misc:AddToggle("Day Only", false, function(v)
if GameCallbacks.dayOnly then GameCallbacks.dayOnly(v) end
end)
Misc:AddToggle("Night Only", false, function(v)
if GameCallbacks.nightOnly then GameCallbacks.nightOnly(v) end
end)
Misc:AddToggle("Hold Duration 0s", false, function(v)
if GameCallbacks.holdDuration then GameCallbacks.holdDuration(v) end
end)
Misc:AddToggle("Disable Oxygen", false, function(v)
if GameCallbacks.disableOxygen then GameCallbacks.disableOxygen(v) end
end)

-- Tools category
local ToolsCat = Library:AddCategory("Tools", "wrench")
ToolsCat:AddToggle("White Screen", false, function(v)
if GameCallbacks.whiteScreen then GameCallbacks.whiteScreen(v) end
end)
ToolsCat:AddButton("Low VFX", function()
if GameCallbacks.lowVfx then GameCallbacks.lowVfx() end
end)
ToolsCat:AddButton("Boost FPS", function()
if GameCallbacks.boostFps then GameCallbacks.boostFps() end
end)
ToolsCat:AddButton("Copy Position", function()
if GameCallbacks.copyPos then GameCallbacks.copyPos() end
end)
ToolsCat:AddSeparator()
ToolsCat:AddButton("Rejoin", function()
if GameCallbacks.rejoin then GameCallbacks.rejoin() end
end)
ToolsCat:AddButton("Hop Server", function()
if GameCallbacks.hopServer then GameCallbacks.hopServer() end
end)
ToolsCat:AddButton("Copy Job ID", function()
if GameCallbacks.copyJobId then GameCallbacks.copyJobId() end
end)

-- ============================================================
-- FISCH GAME LOGIC (wrapped in pcall for safety)
-- ============================================================

pcall(function()
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local CollectionService = game:GetService("CollectionService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local LocalCharacter = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = LocalCharacter:FindFirstChild("HumanoidRootPart")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local RenderStepped = RunService.RenderStepped

-- Keep references fresh after respawn
LocalPlayer.CharacterAdded:Connect(function(char)
LocalCharacter = char
HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
end)

-- Link (new Fisch event path)
local Link = ReplicatedStorage:FindFirstChild("Link") or (#ReplicatedStorage:GetChildren() > 2 and ReplicatedStorage or ReplicatedStorage:GetChildren()[1])

-- State
local ShakeMode = "Mouse"
local WalkZone = "Ocean"
local Noclip = false
local AutoFreeze = false
local AutoFish = false
local AutoCast = false
local autoReel = false
local autoShake = false -- mouse mode
local autoShake2 = false -- phantom mode
local autoShake3 = false -- no delay mode
local autoShakeDelay = 0.3
local DayOnlyLoop = nil
local NightOnlyLoop = nil

-- ============ AUTO REEL (blatant via Link) ============
PlayerGui.ChildAdded:Connect(function(GUI)
if GUI:IsA("ScreenGui") and GUI.Name == "reel" and autoReel then
local reelfinishedEvent = Link:WaitForChild("events"):WaitForChild("reelfinished")
if reelfinishedEvent then
while GUI do
task.wait(2)
reelfinishedEvent:FireServer(100, false)
end
end
end
end)

-- ============ AUTO SHAKE (loop) ============
local function AutoFish5()
if autoShake3 then
task.spawn(function()
while AutoFish do
local shakeUI = PlayerGui:FindFirstChild("shakeui")
if shakeUI and shakeUI.Enabled then
local safezone = shakeUI:FindFirstChild("safezone")
if safezone then
local button = safezone:FindFirstChild("button")
if button and button:IsA("ImageButton") and button.Visible then
if autoShake then
local pos = button.AbsolutePosition
local size = button.AbsoluteSize
VirtualInputManager:SendMouseButtonEvent(pos.X + size.X / 2, pos.Y + size.Y / 2, 0, true, LocalPlayer, 0)
VirtualInputManager:SendMouseButtonEvent(pos.X + size.X / 2, pos.Y + size.Y / 2, 0, false, LocalPlayer, 0)
elseif autoShake2 then
GuiService.SelectedObject = button
VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
end
end
end
end
task.wait()
end
end)
else
task.spawn(function()
while AutoFish do
task.wait(autoShakeDelay)
local shakeUI = PlayerGui:FindFirstChild("shakeui")
if shakeUI and shakeUI.Enabled then
local safezone = shakeUI:FindFirstChild("safezone")
if safezone then
local button = safezone:FindFirstChild("button")
if button and button:IsA("ImageButton") and button.Visible then
if autoShake then
local pos = button.AbsolutePosition
local size = button.AbsoluteSize
VirtualInputManager:SendMouseButtonEvent(pos.X + size.X / 2, pos.Y + size.Y / 2, 0, true, LocalPlayer, 0)
VirtualInputManager:SendMouseButtonEvent(pos.X + size.X / 2, pos.Y + size.Y / 2, 0, false, LocalPlayer, 0)
elseif autoShake2 then
GuiService.SelectedObject = button
VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
end
end
end
end
end
end)
end
end

-- ============ AUTO CAST (blatant via cast:FireServer) ============
local function Pidoras()
spawn(function()
while AutoCast do
local character = LocalPlayer.Character
if character then
local tool = character:FindFirstChildOfClass("Tool")
if tool then
local hasBobber = tool:FindFirstChild("bobber")
if not hasBobber then
local castEvent = tool:FindFirstChild("events") and tool.events:FindFirstChild("cast")
if castEvent then
local Random2 = math.random(90, 99)
castEvent:FireServer(Random2)
local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
if humanoidRootPart then
humanoidRootPart.Anchored = false
end
end
end
end
task.wait(1)
end
end
end)
end

-- ============ SELL FUNCTIONS ============
local function rememberPosition()
spawn(function()
local initialCFrame = HumanoidRootPart.CFrame
local bodyVelocity = Instance.new("BodyVelocity")
bodyVelocity.Velocity = Vector3.new(0, 0, 0)
bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
bodyVelocity.Parent = HumanoidRootPart
local bodyGyro = Instance.new("BodyGyro")
bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
bodyGyro.D = 100
bodyGyro.P = 10000
bodyGyro.CFrame = initialCFrame
bodyGyro.Parent = HumanoidRootPart
while AutoFreeze do
HumanoidRootPart.CFrame = initialCFrame
task.wait(0.01)
end
if bodyVelocity then bodyVelocity:Destroy() end
if bodyGyro then bodyGyro:Destroy() end
end)
end

local function SellHand()
local currentPosition = HumanoidRootPart.CFrame
local sellPosition = CFrame.new(464, 151, 232)
local wasAutoFreezeActive = AutoFreeze
if AutoFreeze then AutoFreeze = false end
HumanoidRootPart.CFrame = sellPosition
task.wait(0.5)
pcall(function()
Workspace:WaitForChild("world"):WaitForChild("npcs"):WaitForChild("Marc Merchant"):WaitForChild("merchant"):WaitForChild("sell"):InvokeServer()
end)
task.wait(1)
HumanoidRootPart.CFrame = currentPosition
if wasAutoFreezeActive then AutoFreeze = true; rememberPosition() end
Library:Notify("Sold hand items!", "success")
end

local function SellAll()
local currentPosition = HumanoidRootPart.CFrame
local sellPosition = CFrame.new(464, 151, 232)
local wasAutoFreezeActive = AutoFreeze
if AutoFreeze then AutoFreeze = false end
HumanoidRootPart.CFrame = sellPosition
task.wait(0.5)
pcall(function()
Workspace:WaitForChild("world"):WaitForChild("npcs"):WaitForChild("Marc Merchant"):WaitForChild("merchant"):WaitForChild("sellall"):InvokeServer()
end)
task.wait(1)
HumanoidRootPart.CFrame = currentPosition
if wasAutoFreezeActive then AutoFreeze = true; rememberPosition() end
Library:Notify("Sold all items!", "success")
end

-- ============ NOCLIP ============
RunService.Stepped:Connect(function()
if Noclip and LocalCharacter then
for _, v in pairs(LocalCharacter:GetDescendants()) do
if v:IsA("BasePart") and v.CanCollide then
v.CanCollide = false
end
end
end
end)

-- ============ ANTI-AFK ============
local vu = VirtualUser
Players.LocalPlayer.Idled:Connect(function()
vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
task.wait(1)
vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)

Players.LocalPlayer.Idled:Connect(function()
vu:CaptureController()
vu:ClickButton2(Vector2.new())
end)

spawn(function()
while true do
pcall(function()
ReplicatedStorage:WaitForChild("events"):WaitForChild("afk"):FireServer(false)
end)
task.wait(60)
end
end)

-- ============ TOTEM POSITIONS ============
local TotemPositions = {
Aurora = CFrame.new(-1811, -137, -3282),
Sundial = CFrame.new(-1148, 135, -1075),
Windset = CFrame.new(2849, 178, 2702),
Smokescreen = CFrame.new(2789, 140, -625),
Tempest = CFrame.new(35, 133, 1943),
}

-- ============ POPULATE CALLBACKS ============

GameCallbacks.autoFish = function(v)
AutoFish = v
autoReel = v
AutoCast = v
if AutoCast then
Pidoras()
end
if ShakeMode == "Mouse" then
autoShake = v
autoShake2 = false
elseif ShakeMode == "Phantom" then
autoShake2 = v
autoShake = false
end
AutoFish5()
if AutoCast and LocalCharacter and LocalCharacter:FindFirstChildOfClass("Tool") then
local Tool = LocalCharacter:FindFirstChildOfClass("Tool")
if Tool:FindFirstChild("events") and Tool.events:FindFirstChild("cast") then
local Random2 = math.random(90, 99)
Tool.events.cast:FireServer(Random2)
end
end
Library:Notify("Auto Fish: " .. (v and "ON" or "OFF"), v and "success" or "error")
end

GameCallbacks.shakeMode = function(v)
ShakeMode = v
if AutoFish then
if v == "Mouse" then
autoShake = true
autoShake2 = false
elseif v == "Phantom" then
autoShake2 = true
autoShake = false
end
end
end

GameCallbacks.shakeDelay = function(v)
autoShakeDelay = v
end

GameCallbacks.noShakeDelay = function(v)
autoShake3 = v
if AutoFish then
AutoFish5()
end
end

GameCallbacks.freeze = function(v)
AutoFreeze = v
if v then
rememberPosition()
end
end

GameCallbacks.antiAfk = function(v)
if v then
task.spawn(function()
while v do
pcall(function()
Link:WaitForChild("events"):WaitForChild("afk"):FireServer(false)
end)
task.wait(0.01)
end
end)
end
end

GameCallbacks.sellHand = function() task.spawn(SellHand) end
GameCallbacks.sellAll = function() task.spawn(SellAll) end

GameCallbacks.areaTp = function(value)
if value == "(select area)" then return end
pcall(function()
local TpSpotsFolder = Workspace:FindFirstChild("world"):WaitForChild("spawns"):WaitForChild("TpSpots")
if TpSpotsFolder:FindFirstChild(value) then
HumanoidRootPart.CFrame = TpSpotsFolder:FindFirstChild(value).CFrame + Vector3.new(0, 5, 0)
Library:Notify("Teleported to " .. value, "success")
end
end)
end

GameCallbacks.totemTp = function(value)
if TotemPositions[value] then
HumanoidRootPart.CFrame = TotemPositions[value]
Library:Notify("Teleported to " .. value .. " Totem", "success")
end
end

GameCallbacks.worldEventTp = function(value)
local FishingZones = Workspace:FindFirstChild("zones") and Workspace.zones:FindFirstChild("fishing")
if not FishingZones then Library:Notify("Zones not found", "error") return end

local eventMap = {
["Whirlpool"] = { name = "Isonade", offset = Vector3.new(25, 135, 25) },
["Hammerhead"] = { name = "Great Hammerhead Shark", offset = Vector3.new(0, 135, 0) },
["White Shark"] = { name = "Great White Shark", offset = Vector3.new(0, 135, 0) },
["Whale Shark"] = { name = "Whale Shark", offset = Vector3.new(0, 135, 0) },
["Serpent"] = { name = "The Depths - Serpent", offset = Vector3.new(0, 50, 0) },
}

local info = eventMap[value]
if not info then return end
local target = FishingZones:FindFirstChild(info.name)
if not target then Library:Notify(info.name .. " not found", "error") return end
HumanoidRootPart.CFrame = CFrame.new(target.Position + info.offset)
Library:Notify("Teleported to " .. value, "success")
end

GameCallbacks.merchantTp = function()
pcall(function()
local Merchant = Workspace.active:FindFirstChild("Merchant Boat")
if not Merchant then Library:Notify("Merchant not found", "error") return end
HumanoidRootPart.CFrame = CFrame.new(Merchant.Boat["Merchant Boat"].r.HandlesR.Position)
Library:Notify("Teleported to Merchant", "success")
end)
end

GameCallbacks.walkOnWater = function(v)
local FishingZones = Workspace:FindFirstChild("zones") and Workspace.zones:FindFirstChild("fishing")
if FishingZones then
for _, zone in pairs(FishingZones:GetChildren()) do
if zone.Name == WalkZone then
zone.CanCollide = v
if zone.Name == "Ocean" then
for _, z2 in pairs(FishingZones:GetChildren()) do
if z2.Name == "Deep Ocean" then z2.CanCollide = v end
end
end
end
end
end
end

GameCallbacks.walkZone = function(v) WalkZone = v end

GameCallbacks.walkSpeed = function(v)
pcall(function() LocalPlayer.Character.Humanoid.WalkSpeed = v end)
end

GameCallbacks.jumpHeight = function(v)
pcall(function() LocalPlayer.Character.Humanoid.JumpPower = v end)
end

GameCallbacks.noclip = function(v) Noclip = v end

GameCallbacks.bypassRadar = function(v)
for _, tag in pairs(CollectionService:GetTagged("radarTag")) do
if tag:IsA("BillboardGui") or tag:IsA("SurfaceGui") then
tag.Enabled = v
end
end
end

GameCallbacks.removeFog = function(v)
pcall(function()
if v then
if Lighting:FindFirstChild("Sky") then
Lighting:FindFirstChild("Sky").Parent = Lighting.bloom
end
else
if Lighting.bloom:FindFirstChild("Sky") then
Lighting.bloom:FindFirstChild("Sky").Parent = Lighting
end
end
end)
end

GameCallbacks.dayOnly = function(v)
if v then
DayOnlyLoop = RunService.Heartbeat:Connect(function()
Lighting.TimeOfDay = "12:00:00"
end)
else
if DayOnlyLoop then DayOnlyLoop:Disconnect(); DayOnlyLoop = nil end
end
end

GameCallbacks.nightOnly = function(v)
if v then
NightOnlyLoop = RunService.Heartbeat:Connect(function()
Lighting.TimeOfDay = "24:00:00"
end)
else
if NightOnlyLoop then NightOnlyLoop:Disconnect(); NightOnlyLoop = nil end
end
end

GameCallbacks.holdDuration = function(v)
if v then
for _, desc in ipairs(Workspace:GetDescendants()) do
if desc.ClassName == "ProximityPrompt" then desc.HoldDuration = 0 end
end
end
end

GameCallbacks.disableOxygen = function(v)
pcall(function() LocalPlayer.Character.client.oxygen.Disabled = v end)
end

GameCallbacks.whiteScreen = function(v)
pcall(function() RunService:Set3dRenderingEnabled(not v) end)
end

GameCallbacks.lowVfx = function()
pcall(function()
local terrain = workspace:FindFirstChildOfClass("Terrain")
terrain.WaterWaveSize = 0
terrain.WaterWaveSpeed = 0
terrain.WaterReflectance = 0
terrain.WaterTransparency = 0
Lighting.GlobalShadows = false
Lighting.FogEnd = 9e9
settings().Rendering.QualityLevel = 1
for _, v in pairs(workspace:GetDescendants()) do
if v:IsA("Part") or v:IsA("UnionOperation") or v:IsA("MeshPart") or v:IsA("CornerWedgePart") or v:IsA("TrussPart") then
v.Material = "Plastic"
v.Reflectance = 0
elseif v:IsA("Decal") then
v.Transparency = 1
elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
v.Lifetime = NumberRange.new(0)
elseif v:IsA("Explosion") then
v.BlastPressure = 1
v.BlastRadius = 1
end
end
for _, v in pairs(Lighting:GetDescendants()) do
if v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") then
v.Enabled = false
end
end
end)
Library:Notify("Low VFX applied!", "success")
end

GameCallbacks.boostFps = function()
pcall(function()
for _, v in next, game:GetDescendants() do
if v:IsA("Part") or v:IsA("Union") or v:IsA("BasePart") then
v.Material = Enum.Material.SmoothPlastic
end
if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Explosion") or v:IsA("Sparkles") or v:IsA("Fire") then
v.Enabled = false
end
if v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("SunRaysEffect") then
v.Enabled = false
end
if v:IsA("Decal") or v:IsA("Texture") then
v.Texture = ""
end
if v:IsA("Sky") then
v.Parent = nil
end
end
end)
Library:Notify("FPS Boost applied!", "success")
end

GameCallbacks.copyPos = function()
pcall(function()
setclipboard(tostring(LocalPlayer.Character.HumanoidRootPart.Position))
Library:Notify("Position copied!", "success")
end)
end

GameCallbacks.rejoin = function()
pcall(function()
TeleportService:Teleport(game.PlaceId, LocalPlayer)
end)
end

GameCallbacks.hopServer = function()
task.spawn(function()
pcall(function()
local PlaceID = game.PlaceId
local AllIDs = {}
local foundAnything = ""
local function TPReturner()
local url
if foundAnything == "" then
url = "https://games.roblox.com/v1/games/" .. PlaceID .. "/servers/Public?sortOrder=Asc&limit=100"
else
url = "https://games.roblox.com/v1/games/" .. PlaceID .. "/servers/Public?sortOrder=Asc&limit=100&cursor=" .. foundAnything
end
local Site = HttpService:JSONDecode(game:HttpGet(url))
if Site.nextPageCursor and Site.nextPageCursor ~= "null" then
foundAnything = Site.nextPageCursor
end
for _, v in pairs(Site.data) do
local ID = tostring(v.id)
if tonumber(v.maxPlayers) > tonumber(v.playing) then
local Possible = true
for _, Existing in pairs(AllIDs) do
if ID == tostring(Existing) then Possible = false; break end
end
if Possible then
table.insert(AllIDs, ID)
TeleportService:TeleportToPlaceInstance(PlaceID, ID, LocalPlayer)
task.wait(4)
end
end
end
end
while true do
pcall(TPReturner)
if foundAnything ~= "" then pcall(TPReturner) end
task.wait(1)
end
end)
end)
end

GameCallbacks.copyJobId = function()
pcall(function()
setclipboard(game.JobId)
Library:Notify("Job ID copied!", "success")
end)
end

-- ============ UPDATE AREA TELEPORT DROPDOWN ============
pcall(function()
local TpSpotsFolder = Workspace:FindFirstChild("world"):WaitForChild("spawns"):WaitForChild("TpSpots")
local spots = {}
for _, v in pairs(TpSpotsFolder:GetChildren()) do
if table.find(spots, v.Name) == nil then
table.insert(spots, v.Name)
end
end
table.sort(spots)
if #spots > 0 and AreaDropdown then
AreaDropdown:UpdateOptions(spots, spots[1])
end
end)
end)

Library:Notify("Nova Fisch loaded!", "success")

return Library