
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UpdateNotification"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 350, 0, 200)
frame.Position = UDim2.new(0.5, -175, 0.5, -100)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 45)
title.Position = UDim2.new(0, 10, 0, 10)
title.BackgroundTransparency = 1
title.Text = "NEW UPDATE!"
title.TextColor3 = Color3.fromRGB(0, 170, 255)
title.TextSize = 26
title.Font = Enum.Font.GothamBold
title.Parent = frame

local message = Instance.new("TextLabel")
message.Size = UDim2.new(1, -30, 0, 75)
message.Position = UDim2.new(0, 15, 0, 60)
message.BackgroundTransparency = 1
message.Text = "new loadstring on rscript (xqrto)."
message.TextColor3 = Color3.fromRGB(255, 255, 255)
message.TextSize = 16
message.Font = Enum.Font.Gotham
message.TextWrapped = true
message.Parent = frame

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 120, 0, 35)
closeButton.Position = UDim2.new(0.5, -60, 1, -45)
closeButton.BackgroundColor3 = Color3.fromRGB(0, 140, 220)
closeButton.Text = "Got it!"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 16
closeButton.Font = Enum.Font.GothamBold
closeButton.Parent = frame

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 8)
buttonCorner.Parent = closeButton

closeButton.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)
