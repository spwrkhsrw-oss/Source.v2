-- PARTICLE EFFECTS VISUALIZER
-- A fun, legitimate Roblox script for creating cool visual effects
-- Safe to use - Does not violate Roblox ToS

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Player
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Settings
local settings = {
    particlesEnabled = false,
    trailEnabled = false,
    auraEnabled = false,
    rainbowMode = false,
    currentColor = Color3.fromRGB(0, 170, 255),
    particleSize = 0.5,
    emissionRate = 20
}

-- Storage
local effects = {}
local connections = {}

-- Create GUI
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ParticleVisualizerGUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Try to parent to PlayerGui first, fallback to CoreGui
    local success = pcall(function()
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end)
    
    if not success then
        screenGui.Parent = game:GetService("CoreGui")
    end
    
    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 320, 0, 450)
    mainFrame.Position = UDim2.new(0.02, 0, 0.3, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = mainFrame
    
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(80, 80, 100)
    mainStroke.Thickness = 2
    mainStroke.Parent = mainFrame
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -20, 1, 0)
    titleLabel.Position = UDim2.new(0, 10, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "✨ Particle Visualizer"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 20
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar
    
    -- Content Container
    local contentFrame = Instance.new("ScrollingFrame")
    contentFrame.Size = UDim2.new(1, -20, 1, -70)
    contentFrame.Position = UDim2.new(0, 10, 0, 60)
    contentFrame.BackgroundTransparency = 1
    contentFrame.BorderSizePixel = 0
    contentFrame.ScrollBarThickness = 6
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    contentFrame.Parent = mainFrame
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 12)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = contentFrame
    
    -- Auto-resize canvas
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        contentFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
    end)
    
    return screenGui, mainFrame, contentFrame, titleBar
end

-- Create Toggle Button
local function createToggle(parent, labelText, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 50)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.65, 0, 1, 0)
    label.Position = UDim2.new(0, 15, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(240, 240, 245)
    label.Font = Enum.Font.Gotham
    label.TextSize = 16
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(0, 70, 0, 30)
    toggleButton.Position = UDim2.new(1, -85, 0.5, -15)
    toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    toggleButton.Text = "OFF"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.TextSize = 14
    toggleButton.BorderSizePixel = 0
    toggleButton.Parent = frame
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = toggleButton
    
    local isEnabled = false
    
    toggleButton.MouseButton1Click:Connect(function()
        isEnabled = not isEnabled
        
        if isEnabled then
            toggleButton.Text = "ON"
            TweenService:Create(toggleButton, TweenInfo.new(0.2), 
                {BackgroundColor3 = Color3.fromRGB(50, 200, 50)}):Play()
        else
            toggleButton.Text = "OFF"
            TweenService:Create(toggleButton, TweenInfo.new(0.2), 
                {BackgroundColor3 = Color3.fromRGB(200, 50, 50)}):Play()
        end
        
        if callback then
            callback(isEnabled)
        end
    end)
    
    return frame, toggleButton
end

-- Create Slider
local function createSlider(parent, labelText, minValue, maxValue, defaultValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 70)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -30, 0, 25)
    label.Position = UDim2.new(0, 15, 0, 8)
    label.BackgroundTransparency = 1
    label.Text = labelText .. ": " .. defaultValue
    label.TextColor3 = Color3.fromRGB(240, 240, 245)
    label.Font = Enum.Font.Gotham
    label.TextSize = 15
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, -30, 0, 8)
    sliderBg.Position = UDim2.new(0, 15, 0, 45)
    sliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = frame
    
    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(1, 0)
    sliderCorner.Parent = sliderBg
    
    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((defaultValue - minValue) / (maxValue - minValue), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBg
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = sliderFill
    
    local sliderButton = Instance.new("TextButton")
    sliderButton.Size = UDim2.new(0, 20, 0, 20)
    sliderButton.Position = UDim2.new((defaultValue - minValue) / (maxValue - minValue), -10, 0.5, -10)
    sliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sliderButton.Text = ""
    sliderButton.BorderSizePixel = 0
    sliderButton.Parent = sliderBg
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(1, 0)
    btnCorner.Parent = sliderButton
    
    local dragging = false
    
    sliderButton.MouseButton1Down:Connect(function()
        dragging = true
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    RunService.RenderStepped:Connect(function()
        if dragging then
            local mousePos = UserInputService:GetMouseLocation()
            local relativePos = (mousePos.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
            relativePos = math.clamp(relativePos, 0, 1)
            
            sliderButton.Position = UDim2.new(relativePos, -10, 0.5, -10)
            sliderFill.Size = UDim2.new(relativePos, 0, 1, 0)
            
            local value = minValue + (maxValue - minValue) * relativePos
            value = math.floor(value * 10 + 0.5) / 10
            
            label.Text = labelText .. ": " .. value
            
            if callback then
                callback(value)
            end
        end
    end)
    
    return frame
end

-- Create Color Picker
local function createColorPicker(parent, labelText, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 80)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -30, 0, 25)
    label.Position = UDim2.new(0, 15, 0, 8)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(240, 240, 245)
    label.Font = Enum.Font.Gotham
    label.TextSize = 15
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local colorGrid = Instance.new("Frame")
    colorGrid.Size = UDim2.new(1, -30, 0, 35)
    colorGrid.Position = UDim2.new(0, 15, 0, 38)
    colorGrid.BackgroundTransparency = 1
    colorGrid.Parent = frame
    
    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 30, 0, 30)
    gridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
    gridLayout.Parent = colorGrid
    
    local colors = {
        Color3.fromRGB(255, 50, 50),   -- Red
        Color3.fromRGB(255, 150, 50),  -- Orange
        Color3.fromRGB(255, 255, 50),  -- Yellow
        Color3.fromRGB(50, 255, 50),   -- Green
        Color3.fromRGB(50, 255, 255),  -- Cyan
        Color3.fromRGB(50, 150, 255),  -- Blue
        Color3.fromRGB(150, 50, 255),  -- Purple
        Color3.fromRGB(255, 50, 255),  -- Magenta
    }
    
    for _, color in ipairs(colors) do
        local colorBtn = Instance.new("TextButton")
        colorBtn.Size = UDim2.new(0, 30, 0, 30)
        colorBtn.BackgroundColor3 = color
        colorBtn.Text = ""
        colorBtn.BorderSizePixel = 2
        colorBtn.BorderColor3 = Color3.fromRGB(255, 255, 255)
        colorBtn.Parent = colorGrid
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 6)
        btnCorner.Parent = colorBtn
        
        colorBtn.MouseButton1Click:Connect(function()
            if callback then
                callback(color)
            end
        end)
    end
    
    return frame
end

-- Particle Effects Functions
local function createParticles()
    if effects.particles then return end
    
    local attachment = Instance.new("Attachment")
    attachment.Parent = HumanoidRootPart
    
    local particles = Instance.new("ParticleEmitter")
    particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particles.Rate = settings.emissionRate
    particles.Lifetime = NumberRange.new(1, 2)
    particles.Speed = NumberRange.new(3, 5)
    particles.SpreadAngle = Vector2.new(360, 360)
    particles.Size = NumberSequence.new(settings.particleSize)
    particles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1)
    })
    particles.LightEmission = 0.8
    particles.Color = ColorSequence.new(settings.currentColor)
    particles.Parent = attachment
    
    effects.particles = {attachment = attachment, emitter = particles}
end

local function removeParticles()
    if effects.particles then
        effects.particles.attachment:Destroy()
        effects.particles = nil
    end
end

local function createTrail()
    if effects.trail then return end
    
    local attachment0 = Instance.new("Attachment")
    attachment0.Position = Vector3.new(0, -2, 0)
    attachment0.Parent = HumanoidRootPart
    
    local attachment1 = Instance.new("Attachment")
    attachment1.Position = Vector3.new(0, -2, 0)
    attachment1.Parent = HumanoidRootPart
    
    local trail = Instance.new("Trail")
    trail.Attachment0 = attachment0
    trail.Attachment1 = attachment1
    trail.Lifetime = 1
    trail.MinLength = 0
    trail.Color = ColorSequence.new(settings.currentColor)
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 1)
    })
    trail.WidthScale = NumberSequence.new(1)
    trail.LightEmission = 0.8
    trail.Parent = HumanoidRootPart
    
    effects.trail = {attachment0 = attachment0, attachment1 = attachment1, trail = trail}
end

local function removeTrail()
    if effects.trail then
        effects.trail.attachment0:Destroy()
        effects.trail.attachment1:Destroy()
        effects.trail.trail:Destroy()
        effects.trail = nil
    end
end

local function createAura()
    if effects.aura then return end
    
    local aura = Instance.new("Part")
    aura.Name = "Aura"
    aura.Size = Vector3.new(6, 6, 6)
    aura.Transparency = 0.7
    aura.CanCollide = false
    aura.Anchored = false
    aura.Material = Enum.Material.Neon
    aura.Color = settings.currentColor
    aura.CastShadow = false
    aura.Parent = Character
    
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Scale = Vector3.new(1.5, 1.5, 1.5)
    mesh.Parent = aura
    
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = HumanoidRootPart
    weld.Part1 = aura
    weld.Parent = aura
    
    effects.aura = {part = aura, mesh = mesh}
    
    -- Pulse animation
    local pulseConnection = RunService.Heartbeat:Connect(function()
        if effects.aura and effects.aura.mesh then
            local scale = 1.5 + math.sin(tick() * 3) * 0.2
            effects.aura.mesh.Scale = Vector3.new(scale, scale, scale)
        end
    end)
    
    table.insert(connections, pulseConnection)
end

local function removeAura()
    if effects.aura then
        effects.aura.part:Destroy()
        effects.aura = nil
    end
end

-- Rainbow mode
local function updateRainbow()
    if not settings.rainbowMode then return end
    
    local hue = (tick() % 5) / 5
    local rainbowColor = Color3.fromHSV(hue, 1, 1)
    settings.currentColor = rainbowColor
    
    if effects.particles then
        effects.particles.emitter.Color = ColorSequence.new(rainbowColor)
    end
    if effects.trail then
        effects.trail.trail.Color = ColorSequence.new(rainbowColor)
    end
    if effects.aura then
        effects.aura.part.Color = rainbowColor
    end
end

-- Create GUI
local screenGui, mainFrame, contentFrame, titleBar = createGUI()

-- Add controls
createToggle(contentFrame, "💫 Particle Effects", function(enabled)
    settings.particlesEnabled = enabled
    if enabled then
        createParticles()
    else
        removeParticles()
    end
end)

createToggle(contentFrame, "✨ Trail Effect", function(enabled)
    settings.trailEnabled = enabled
    if enabled then
        createTrail()
    else
        removeTrail()
    end
end)

createToggle(contentFrame, "🔮 Aura Effect", function(enabled)
    settings.auraEnabled = enabled
    if enabled then
        createAura()
    else
        removeAura()
    end
end)

createToggle(contentFrame, "🌈 Rainbow Mode", function(enabled)
    settings.rainbowMode = enabled
end)

createSlider(contentFrame, "Particle Size", 0.1, 2, 0.5, function(value)
    settings.particleSize = value
    if effects.particles then
        effects.particles.emitter.Size = NumberSequence.new(value)
    end
end)

createSlider(contentFrame, "Emission Rate", 5, 50, 20, function(value)
    settings.emissionRate = value
    if effects.particles then
        effects.particles.emitter.Rate = value
    end
end)

createColorPicker(contentFrame, "🎨 Color", function(color)
    settings.currentColor = color
    settings.rainbowMode = false
    
    if effects.particles then
        effects.particles.emitter.Color = ColorSequence.new(color)
    end
    if effects.trail then
        effects.trail.trail.Color = ColorSequence.new(color)
    end
    if effects.aura then
        effects.aura.part.Color = color
    end
end)

-- Make GUI draggable
local dragging = false
local dragInput, dragStart, startPos

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)

titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- Rainbow mode update loop
table.insert(connections, RunService.Heartbeat:Connect(updateRainbow))

-- Character respawn handling
LocalPlayer.CharacterAdded:Connect(function(newChar)
    Character = newChar
    HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
    
    -- Clear old effects
    for _, effect in pairs(effects) do
        if type(effect) == "table" and effect.part then
            pcall(function() effect.part:Destroy() end)
        end
    end
    effects = {}
    
    -- Recreate active effects
    task.wait(0.5)
    if settings.particlesEnabled then createParticles() end
    if settings.trailEnabled then createTrail() end
    if settings.auraEnabled then createAura() end
end)

-- Cleanup on script end
game:GetService("Players").PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end
    end
end)

print("✨ Particle Visualizer loaded successfully!")
print("📌 Open the GUI to customize your effects!")
print("🎨 This script is 100% safe and ToS-compliant!")
