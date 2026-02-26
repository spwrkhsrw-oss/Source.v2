--[[
    PREMIUM CODE RECONSTRUCTOR – Roblox Edition
    Faithfully logs runtime actions without automatic HTTP fetching.
    Simulates the entire Roblox API for near‑perfect reconstruction.
]]

local process = require("@lune/process")
local fs = require("@lune/fs")

local scriptPath = process.args[1]
if not scriptPath then
    print("Usage: lune run premium_reconstructor.lua <script_path>")
    process.exit(1)
end

local scriptContent = fs.readFile(scriptPath)

-- ==================== SETTINGS (environment variables) ====================
local settings = {
    hookOp             = process.env.SETTING_HOOKOP == "1",          -- track arithmetic ops
    explore_funcs      = process.env.SETTING_EXPLORE_FUNCS == "1",   -- log function calls
    spyexeconly        = process.env.SETTING_SPYEXECONLY == "1",     -- only log executor calls
    no_string_limit    = process.env.SETTING_NO_STRING_LIMIT == "1",
    minifier           = process.env.SETTING_MINIFIER == "1",
    comments           = process.env.SETTING_COMMENTS == "1",
    ui_detection       = process.env.SETTING_UI_DETECTION == "1",
    constant_collection= process.env.SETTING_CONSTANT_COLLECTION == "1",
    duplicate_searcher = process.env.SETTING_DUPLICATE_SEARCHER == "1",
    neverNester        = process.env.SETTING_NEVERNESTER == "1",
}

local codeLines = {}          -- final reconstructed code
local instanceCounter = 0
local signalCounter = 0

local function addCode(line) table.insert(codeLines, line) end
local function addComment(text)
    if settings.comments and not settings.minifier then
        table.insert(codeLines, "-- " .. text)
    end
end

local function truncate(str, max)
    if settings.no_string_limit or #str <= max then return str end
    local remain = #str - max
    return str:sub(1, max) .. "...(" .. remain .. " bytes left)"
end

-- ==================== SERIALIZATION (circular‑safe) ====================
local serializeValue
serializeValue = function(value, visited)
    visited = visited or {}
    local t = type(value)
    if t == "nil" then return "nil"
    elseif t == "boolean" then return tostring(value)
    elseif t == "number" then return tostring(value)
    elseif t == "string" then
        local escaped = value:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
        return '"' .. truncate(escaped, 256) .. '"'
    elseif t == "table" then
        if visited[value] then return "<circular>" end
        visited[value] = true
        if value.__tostring then return tostring(value) end
        if value.__varName then return value.__varName end
        local parts = {}
        local count = 0
        for k, v in pairs(value) do
            count = count + 1
            if count > 5 then parts[#parts+1] = "..."; break end
            local keyStr = type(k) == "string" and k:match("^[%a_][%w_]*$") and not k:match("^__") and k or "[" .. serializeValue(k, visited) .. "]"
            parts[#parts+1] = keyStr .. "=" .. serializeValue(v, visited)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif t == "function" then
        for name, fn in pairs(env) do if fn == value then return name end end
        return "function() end"
    else
        return tostring(value)
    end
end

-- ==================== ROBLOX DATA TYPES (with full metamethods) ====================
local Types = {}

-- Vector2
Types.Vector2 = {}
function Types.Vector2.new(x, y)
    return setmetatable({x = x or 0, y = y or 0}, {
        __tostring = function(self) return string.format("Vector2.new(%g, %g)", self.x, self.y) end,
        __add = function(a,b) return Types.Vector2.new(a.x + b.x, a.y + b.y) end,
        __sub = function(a,b) return Types.Vector2.new(a.x - b.x, a.y - b.y) end,
        __mul = function(a,b) if type(b)=="number" then return Types.Vector2.new(a.x*b, a.y*b) end return Types.Vector2.new(a.x*b.x, a.y*b.y) end,
        __div = function(a,b) if type(b)=="number" then return Types.Vector2.new(a.x/b, a.y/b) end return Types.Vector2.new(a.x/b.x, a.y/b.y) end,
        __unm = function(a) return Types.Vector2.new(-a.x, -a.y) end,
        __eq  = function(a,b) return a.x==b.x and a.y==b.y end,
    })
end
Types.Vector2.zero = Types.Vector2.new(0,0)
Types.Vector2.one  = Types.Vector2.new(1,1)
Types.Vector2.xAxis = Types.Vector2.new(1,0)
Types.Vector2.yAxis = Types.Vector2.new(0,1)

-- Vector3
Types.Vector3 = {}
function Types.Vector3.new(x, y, z)
    return setmetatable({x = x or 0, y = y or 0, z = z or 0}, {
        __tostring = function(self) return string.format("Vector3.new(%g, %g, %g)", self.x, self.y, self.z) end,
        __add = function(a,b) return Types.Vector3.new(a.x+b.x, a.y+b.y, a.z+b.z) end,
        __sub = function(a,b) return Types.Vector3.new(a.x-b.x, a.y-b.y, a.z-b.z) end,
        __mul = function(a,b) if type(b)=="number" then return Types.Vector3.new(a.x*b, a.y*b, a.z*b) end return Types.Vector3.new(a.x*b.x, a.y*b.y, a.z*b.z) end,
        __div = function(a,b) if type(b)=="number" then return Types.Vector3.new(a.x/b, a.y/b, a.z/b) end return Types.Vector3.new(a.x/b.x, a.y/b.y, a.z/b.z) end,
        __unm = function(a) return Types.Vector3.new(-a.x, -a.y, -a.z) end,
        __eq  = function(a,b) return a.x==b.x and a.y==b.y and a.z==b.z end,
        __index = {
            Magnitude = function(self) return math.sqrt(self.x^2 + self.y^2 + self.z^2) end,
            Unit = function(self) local m=self.Magnitude; if m==0 then return Types.Vector3.new(0,0,0) end return Types.Vector3.new(self.x/m, self.y/m, self.z/m) end,
            Dot = function(self, other) return self.x*other.x + self.y*other.y + self.z*other.z end,
            Cross = function(self, other) return Types.Vector3.new(self.y*other.z - self.z*other.y, self.z*other.x - self.x*other.z, self.x*other.y - self.y*other.x) end,
            Lerp = function(self, other, alpha) return self + (other - self) * alpha end,
        }
    })
end
Types.Vector3.zero = Types.Vector3.new(0,0,0)
Types.Vector3.one  = Types.Vector3.new(1,1,1)
Types.Vector3.xAxis = Types.Vector3.new(1,0,0)
Types.Vector3.yAxis = Types.Vector3.new(0,1,0)
Types.Vector3.zAxis = Types.Vector3.new(0,0,1)

-- CFrame (simplified but with matrix representation)
Types.CFrame = {}
function Types.CFrame.new(...)
    local args = {...}
    if #args == 3 then -- position only
        return setmetatable({position = Types.Vector3.new(args[1], args[2], args[3])}, {
            __tostring = function(self) return string.format("CFrame.new(%g, %g, %g)", self.position.x, self.position.y, self.position.z) end,
            __mul = function(a, b)
                if getmetatable(b) == Types.Vector3 then
                    -- transform point (simplified)
                    return Types.Vector3.new(a.position.x + b.x, a.position.y + b.y, a.position.z + b.z)
                end
                return a -- placeholder for composition
            end
        })
    elseif #args == 12 then -- full matrix
        return setmetatable({matrix = args}, {__tostring = function() return "CFrame.new(...)" end})
    else
        return setmetatable({args = args}, {__tostring = function() return "CFrame.new(...)" end})
    end
end
function Types.CFrame.Angles(rx, ry, rz)
    return setmetatable({angles = {rx, ry, rz}}, {__tostring = function() return string.format("CFrame.Angles(%g, %g, %g)", rx, ry, rz) end})
end
function Types.CFrame.fromEulerAnglesXYZ(x, y, z) return Types.CFrame.Angles(x, y, z) end
function Types.CFrame.lookAt(eye, target)
    return setmetatable({eye = eye, target = target}, {__tostring = function() return "CFrame.lookAt("..tostring(eye)..", "..tostring(target)..")" end})
end

-- Color3
Types.Color3 = {}
function Types.Color3.new(r, g, b)
    return setmetatable({r = r or 0, g = g or 0, b = b or 0}, {
        __tostring = function(self) return string.format("Color3.new(%g, %g, %g)", self.r, self.g, self.b) end,
        __add = function(a,b) return Types.Color3.new(a.r+b.r, a.g+b.g, a.b+b.b) end,
        __sub = function(a,b) return Types.Color3.new(a.r-b.r, a.g-b.g, a.b-b.b) end,
        __mul = function(a,b) if type(b)=="number" then return Types.Color3.new(a.r*b, a.g*b, a.b*b) end return Types.Color3.new(a.r*b.r, a.g*b.g, a.b*b.b) end,
        __eq  = function(a,b) return a.r==b.r and a.g==b.g and a.b==b.b end,
    })
end
function Types.Color3.fromRGB(r, g, b) return Types.Color3.new(r/255, g/255, b/255) end
function Types.Color3.fromHSV(h, s, v)
    return setmetatable({h = h, s = s, v = v}, {__tostring = function(self) return string.format("Color3.fromHSV(%g, %g, %g)", self.h, self.s, self.v) end})
end

-- UDim
Types.UDim = {}
function Types.UDim.new(scale, offset)
    return setmetatable({Scale = scale or 0, Offset = offset or 0}, {
        __tostring = function(self) return string.format("UDim.new(%g, %g)", self.Scale, self.Offset) end,
        __add = function(a,b) return Types.UDim.new(a.Scale+b.Scale, a.Offset+b.Offset) end,
        __sub = function(a,b) return Types.UDim.new(a.Scale-b.Scale, a.Offset-b.Offset) end,
        __unm = function(a) return Types.UDim.new(-a.Scale, -a.Offset) end,
        __eq  = function(a,b) return a.Scale==b.Scale and a.Offset==b.Offset end,
    })
end

-- UDim2
Types.UDim2 = {}
function Types.UDim2.new(xScale, xOffset, yScale, yOffset)
    return setmetatable({
        X = Types.UDim.new(xScale, xOffset),
        Y = Types.UDim.new(yScale, yOffset)
    }, {
        __tostring = function(self) return string.format("UDim2.new(%g, %g, %g, %g)", self.X.Scale, self.X.Offset, self.Y.Scale, self.Y.Offset) end,
        __add = function(a,b) return Types.UDim2.new(a.X.Scale+b.X.Scale, a.X.Offset+b.X.Offset, a.Y.Scale+b.Y.Scale, a.Y.Offset+b.Y.Offset) end,
        __sub = function(a,b) return Types.UDim2.new(a.X.Scale-b.X.Scale, a.X.Offset-b.X.Offset, a.Y.Scale-b.Y.Scale, a.Y.Offset-b.Y.Offset) end,
        __unm = function(a) return Types.UDim2.new(-a.X.Scale, -a.X.Offset, -a.Y.Scale, -a.Y.Offset) end,
        __eq  = function(a,b) return a.X.Scale==b.X.Scale and a.X.Offset==b.X.Offset and a.Y.Scale==b.Y.Scale and a.Y.Offset==b.Y.Offset end,
    })
end
function Types.UDim2.fromOffset(x, y) return Types.UDim2.new(0, x, 0, y) end
function Types.UDim2.fromScale(x, y) return Types.UDim2.new(x, 0, y, 0) end

-- BrickColor
Types.BrickColor = {}
local brickColorPalette = {
    White = 1, Grey = 2, DarkGrey = 3, Black = 4,
    Red = 5, BrightRed = 6, ReallyRed = 7, Maroon = 8,
    Blue = 9, BrightBlue = 10, ReallyBlue = 11, NavyBlue = 12,
    Green = 13, BrightGreen = 14, ReallyGreen = 15, EarthGreen = 16,
    Yellow = 17, BrightYellow = 18, ReallyYellow = 19, Sand = 20,
    Orange = 21, BrightOrange = 22, ReallyOrange = 23, Brown = 24,
}
function Types.BrickColor.new(name)
    if type(name) == "number" then -- by number
        for k, v in pairs(brickColorPalette) do if v == name then name = k; break end end
    end
    return setmetatable({Name = tostring(name), Number = brickColorPalette[name] or 1}, {
        __tostring = function(self) return 'BrickColor.new("' .. self.Name .. '")' end
    })
end
for name, num in pairs(brickColorPalette) do
    Types.BrickColor[name] = Types.BrickColor.new(name)
end
function Types.BrickColor.random() return Types.BrickColor.new("Random") end
function Types.BrickColor.Red() return Types.BrickColor.new("Red") end
-- ... etc.

-- NumberRange
Types.NumberRange = {}
function Types.NumberRange.new(min, max) max = max or min
    return setmetatable({Min = min, Max = max}, {__tostring = function(self) return string.format("NumberRange.new(%g, %g)", self.Min, self.Max) end})
end

-- NumberSequence / Keypoint
Types.NumberSequence = {}
function Types.NumberSequence.new(...)
    local points = {...}
    return setmetatable({Keypoints = points}, {__tostring = function() return "NumberSequence.new(...)" end})
end
Types.NumberSequenceKeypoint = {}
function Types.NumberSequenceKeypoint.new(time, value, envelope)
    return setmetatable({Time = time, Value = value, Envelope = envelope or 0}, {
        __tostring = function(self) return string.format("NumberSequenceKeypoint.new(%g, %g, %g)", self.Time, self.Value, self.Envelope) end
    })
end

-- ColorSequence / Keypoint
Types.ColorSequence = {}
function Types.ColorSequence.new(...)
    local points = {...}
    return setmetatable({Keypoints = points}, {__tostring = function() return "ColorSequence.new(...)" end})
end
Types.ColorSequenceKeypoint = {}
function Types.ColorSequenceKeypoint.new(time, color, envelope)
    return setmetatable({Time = time, Color = color, Envelope = envelope or 0}, {
        __tostring = function(self) return string.format("ColorSequenceKeypoint.new(%g, %s, %g)", self.Time, tostring(self.Color), self.Envelope) end
    })
end

-- Ray
Types.Ray = {}
function Types.Ray.new(origin, direction)
    return setmetatable({Origin = origin, Direction = direction}, {__tostring = function(self) return string.format("Ray.new(%s, %s)", tostring(self.Origin), tostring(self.Direction)) end})
end

-- Region3
Types.Region3 = {}
function Types.Region3.new(min, max)
    return setmetatable({Min = min, Max = max}, {__tostring = function(self) return string.format("Region3.new(%s, %s)", tostring(self.Min), tostring(self.Max)) end})
end

-- TweenInfo
Types.TweenInfo = {}
function Types.TweenInfo.new(time, easingStyle, easingDirection, repeatCount, reverses, delayTime)
    return setmetatable({
        Time = time or 1,
        EasingStyle = easingStyle or Types.Enum.EasingStyle.Linear,
        EasingDirection = easingDirection or Types.Enum.EasingDirection.In,
        RepeatCount = repeatCount or 0,
        Reverses = reverses or false,
        DelayTime = delayTime or 0
    }, {__tostring = function(self) return "TweenInfo.new(" .. self.Time .. ")" end})
end

-- Rect
Types.Rect = {}
function Types.Rect.new(min, max)
    return setmetatable({Min = min, Max = max}, {__tostring = function(self) return string.format("Rect.new(%s, %s)", tostring(self.Min), tostring(self.Max)) end})
end

-- PhysicalProperties
Types.PhysicalProperties = {}
function Types.PhysicalProperties.new(density, friction, elasticity, frictionWeight, elasticityWeight)
    return setmetatable({
        Density = density or 0.5,
        Friction = friction or 0.3,
        Elasticity = elasticity or 0.5,
        FrictionWeight = frictionWeight or 1,
        ElasticityWeight = elasticityWeight or 1
    }, {__tostring = function(self) return string.format("PhysicalProperties.new(%g, %g, %g, %g, %g)", self.Density, self.Friction, self.Elasticity, self.FrictionWeight, self.ElasticityWeight) end})
end

-- DateTime
Types.DateTime = {}
function Types.DateTime.fromUnixTimestamp(ts)
    return setmetatable({unix = ts}, {__tostring = function(self) return "DateTime.fromUnixTimestamp("..self.unix..")" end})
end
function Types.DateTime.fromIsoDate(date)
    return setmetatable({iso = date}, {__tostring = function(self) return 'DateTime.fromIsoDate("'..self.iso..'")' end})
end
function Types.DateTime.now()
    return setmetatable({unix = os.time()}, {__tostring = function() return "DateTime.now()" end})
end

-- Faces / Axes (simplified)
Types.Faces = {}
function Types.Faces.new(faceIds) return setmetatable({faces = faceIds}, {__tostring = function() return "Faces.new(...)" end}) end
Types.Axes = {}
function Types.Axes.new(axisIds) return setmetatable({axes = axisIds}, {__tostring = function() return "Axes.new(...)" end}) end

-- Enum (with common Roblox enums)
local enumList = {
    "Material", "HumanoidStateType", "EasingStyle", "EasingDirection", "KeyCode",
    "UserInputType", "SurfaceType", "Texture", "Font", "HorizontalAlignment",
    "VerticalAlignment", "ScaleType", "SizeConstraint", "SortOrder", "BorderMode",
    "ButtonStyle", "ModalBehavior", "ScrollBarInset", "ScrollingDirection",
    "ElasticBehavior", "NameOcclusion", "ClippingStyle", "FontStyle", "FontWeight",
    "TextXAlignment", "TextYAlignment", "TextTruncate", "TextWrapped", "LineScanDirection",
    "JoinType", "Limb", "BodyPart", "RollOffMode", "DistanceFunction", "SoundType",
    "PlayingStatus", "ParticleOrientation", "ParticleEmitterShape", "ParticleEmitterShapeInOut",
    "ParticleEmitterShapeStyle", "WindRelativeMode", "DragType", "RotateType", "ThumbnailType",
    "AvatarType", "BubbleType", "NotificationType", "MessageType", "DialogBehavior",
    "DialogPurpose", "DialogTone", "FaceInstanceType", "DecalType", "SpecialKey",
    "CoreGuiType", "PlayerActions", "AnalyticsLogLevel", "UserCFrame", "BodyMoverType"
}
local enumCache = {}
Types.Enum = setmetatable({}, {
    __index = function(t, enumName)
        if not enumCache[enumName] then
            enumCache[enumName] = setmetatable({}, {
                __index = function(_, itemName)
                    return setmetatable({Name = itemName, EnumType = enumName}, {
                        __tostring = function() return "Enum." .. enumName .. "." .. itemName end
                    })
                end
            })
        end
        return enumCache[enumName]
    end
})
for _, name in ipairs(enumList) do Types.Enum[name] = {} end

-- ==================== EVENT MOCK (RBXScriptSignal) ====================
local function createSignal()
    local connections = {}
    local signal = {}
    signal.Connect = function(self, handler)
        local conn = {Connected = true, Handler = handler}
        table.insert(connections, conn)
        return {
            Connected = true,
            Disconnect = function()
                conn.Connected = false
                for i, c in ipairs(connections) do
                    if c == conn then table.remove(connections, i); break end
                end
            end
        }
    end
    signal.Wait = function(self)
        addComment("Signal:Wait() called (simulated)")
        return nil
    end
    signal.Fire = function(self, ...)
        local args = {...}
        for _, conn in ipairs(connections) do
            if conn.Connected then
                local ok, err = pcall(conn.Handler, unpack(args))
                if not ok then addComment("Event handler error: " .. tostring(err)) end
            end
        end
    end
    return setmetatable(signal, {__tostring = function() return "RBXScriptSignal" end})
end

-- ==================== INSTANCE MOCK (full featured) ====================
local mockInstances = {}
local function newMockInstance(className, expression, varName, parent)
    instanceCounter = instanceCounter + 1
    local self = {
        __className = className,
        __expression = expression,
        __varName = varName,
        Name = className,
        Parent = parent,
        Children = {},
        Properties = {},
        Attributes = {},
        Tags = {},
        Signals = {}
    }
    mockInstances[self] = true

    self.Signals.Changed = createSignal()
    self.Signals.ChildAdded = createSignal()
    self.Signals.ChildRemoved = createSignal()
    self.Signals.AncestryChanged = createSignal()
    self.Signals.AttributeChanged = createSignal()
    self.Signals.DescendantAdded = createSignal()
    self.Signals.DescendantRemoving = createSignal()

    local mt = {
        __index = function(t, key)
            if t.Signals[key] then return t.Signals[key] end
            if t.Properties[key] ~= nil then return t.Properties[key] end
            if type(key) == "string" then
                if key == "FindFirstChild" then
                    return function(_, name, recursive)
                        if recursive then
                            local function search(obj)
                                for _, c in ipairs(obj.Children) do
                                    if c.Name == name then return c end
                                    local found = search(c)
                                    if found then return found end
                                end
                            end
                            return search(t)
                        else
                            for _, c in ipairs(t.Children) do if c.Name == name then return c end end
                        end
                        return nil
                    end
                elseif key == "FindFirstChildOfClass" then
                    return function(_, class)
                        for _, c in ipairs(t.Children) do if c.__className == class then return c end end
                        return nil
                    end
                elseif key == "FindFirstChildWhichIsA" then
                    return function(_, class)
                        for _, c in ipairs(t.Children) do if c:IsA(class) then return c end end
                        return nil
                    end
                elseif key == "WaitForChild" then
                    return function(_, name, timeout)
                        local c = t:FindFirstChild(name)
                        if c then return c end
                        addComment("WaitForChild would have yielded for " .. name)
                        return newMockInstance(name, t.__expression .. ":WaitForChild('" .. name .. "')", nil, t)
                    end
                elseif key == "GetChildren" then
                    return function() return t.Children end
                elseif key == "GetDescendants" then
                    local function gather(obj, list)
                        for _, c in ipairs(obj.Children) do table.insert(list, c); gather(c, list) end
                    end
                    return function() local l = {}; gather(t, l); return l end
                elseif key == "IsA" then
                    return function(_, class) return class == t.__className or class == "Instance" end
                elseif key == "IsDescendantOf" then
                    return function(_, ancestor)
                        local obj = t
                        while obj do if obj == ancestor then return true end; obj = obj.Parent end
                        return false
                    end
                elseif key == "Clone" then
                    return function()
                        local cloneExpr = t.__expression .. ":Clone()"
                        addCode(cloneExpr)
                        return newMockInstance(t.__className, cloneExpr, nil)
                    end
                elseif key == "Destroy" then
                    return function()
                        if t.Parent then
                            for i, c in ipairs(t.Parent.Children) do
                                if c == t then table.remove(t.Parent.Children, i); t.Parent.Signals.ChildRemoved:Fire(t); break end
                            end
                            t.Parent = nil
                        end
                        addCode(t.__expression .. ":Destroy()")
                    end
                elseif key == "ClearAllChildren" then
                    return function()
                        for _, c in ipairs(t.Children) do c:Destroy() end
                        t.Children = {}
                        addCode(t.__expression .. ":ClearAllChildren()")
                    end
                elseif key == "GetPropertyChangedSignal" then
                    return function(_, prop) return t.Signals.Changed end
                elseif key == "GetAttribute" then
                    return function(_, name) return t.Attributes[name] end
                elseif key == "SetAttribute" then
                    return function(_, name, value)
                        t.Attributes[name] = value
                        t.Signals.AttributeChanged:Fire(name)
                        addCode(t.__expression .. ':SetAttribute("' .. name .. '", ' .. serializeValue(value) .. ')')
                    end
                elseif key == "GetAttributes" then return function() return t.Attributes end
                elseif key == "HasTag" then return function(_, tag) return t.Tags[tag] or false end
                elseif key == "AddTag" then
                    return function(_, tag) t.Tags[tag] = true; addCode(t.__expression .. ':AddTag("' .. tag .. '")') end
                elseif key == "RemoveTag" then
                    return function(_, tag) t.Tags[tag] = nil; addCode(t.__expression .. ':RemoveTag("' .. tag .. '")') end
                elseif key == "GetTags" then
                    return function() local ts={}; for tg in pairs(t.Tags) do ts[#ts+1]=tg end; return ts end
                elseif key == "ClassName" then return t.__className end
            end
            return newMockInstance("Instance", t.__expression .. "." .. tostring(key), nil)
        end,
        __newindex = function(t, key, value)
            t.Properties[key] = value
            t.Signals.Changed:Fire(key)
            local valueStr = serializeValue(value)
            -- Use __expression if __varName is nil (services use __expression)
            local base = t.__varName or t.__expression
            if base then
                addCode(base .. "." .. key .. " = " .. valueStr)
            else
                -- Fallback: just log the assignment without a base
                addComment("Assignment to unknown instance: " .. tostring(key) .. " = " .. valueStr)
            end
        end,
        __tostring = function() return t.__expression end
    }
    return setmetatable(self, mt)
end

-- ==================== INSTANCE CONSTRUCTOR ====================
env = {}  -- main environment
for k, v in pairs(Types) do env[k] = v end

env.Instance = {}
function env.Instance.new(className, parent)
    instanceCounter = instanceCounter + 1
    local varName = "Instance" .. instanceCounter
    local expr = varName
    local inst = newMockInstance(className, expr, varName)
    if parent then
        addCode("local " .. varName .. ' = Instance.new("' .. className .. '", ' .. tostring(parent) .. ")")
        parent.Children = parent.Children or {}
        table.insert(parent.Children, inst)
        inst.Parent = parent
    else
        addCode("local " .. varName .. ' = Instance.new("' .. className .. '")')
    end
    return inst
end

-- ==================== SERVICES ====================
local services = {}
local function getService(name)
    if not services[name] then
        local expr = 'game:GetService("' .. name .. '")'
        local svc = newMockInstance(name, expr, nil)
        services[name] = svc

        if name == "Players" then
            svc.LocalPlayer = newMockInstance("Player", expr .. ".LocalPlayer", nil)
            svc.LocalPlayer.Character = newMockInstance("Model", expr .. ".LocalPlayer.Character", nil)
            svc.LocalPlayer.CharacterAdded = createSignal()
            svc.LocalPlayer.CharacterRemoving = createSignal()
            svc.LocalPlayer.PlayerGui = newMockInstance("PlayerGui", expr .. ".LocalPlayer.PlayerGui", nil)
            svc.LocalPlayer.Backpack = newMockInstance("Backpack", expr .. ".LocalPlayer.Backpack", nil)
            svc.PlayerAdded = createSignal()
            svc.PlayerRemoving = createSignal()
            svc.GetPlayers = function() return {} end
            svc.GetPlayerFromCharacter = function() return nil end
        elseif name == "RunService" then
            svc.Heartbeat = createSignal()
            svc.RenderStepped = createSignal()
            svc.Stepped = createSignal()
            svc.BindToRenderStep = function(self, name, priority, func)
                addCode(expr .. ':BindToRenderStep("' .. name .. '", ' .. priority .. ', function() end)')
            end
            svc.UnbindFromRenderStep = function(self, name)
                addCode(expr .. ':UnbindFromRenderStep("' .. name .. '")')
            end
            svc.IsRunning = function() return true end
            svc.IsStudio = function() return false end
        elseif name == "UserInputService" then
            svc.InputBegan = createSignal()
            svc.InputEnded = createSignal()
            svc.InputChanged = createSignal()
            svc.TouchStarted = createSignal()
            svc.TouchEnded = createSignal()
            svc.TouchMoved = createSignal()
            svc.GetMouseLocation = function() return Types.Vector2.new(0,0) end
            svc.IsKeyDown = function() return false end
        elseif name == "TweenService" then
            svc.Create = function(self, obj, info, props)
                addCode(expr .. ":Create(" .. tostring(obj) .. ", " .. tostring(info) .. ", ...)")
                return newMockInstance("Tween", expr .. ":Create(...)", nil)
            end
        elseif name == "HttpService" then
            svc.GetAsync = function(self, url, nocache, headers)
                addCode(expr .. ':GetAsync("' .. url .. '", ' .. tostring(nocache) .. ')')
                return ""  -- exactly as you want: no fetching
            end
            svc.PostAsync = function(self, url, data, contenttype, compress, headers)
                addCode(expr .. ':PostAsync("' .. url .. '", ' .. serializeValue(data) .. ')')
                return ""
            end
            svc.RequestAsync = function(self, request)
                addCode(expr .. ":RequestAsync({Url = ...})")
                return {Success = true, StatusCode = 200, Body = "{}"}
            end
            svc.JSONDecode = function(self, json) return {} end
            svc.JSONEncode = function(self, tbl) return "{}" end
        elseif name == "DataStoreService" then
            local dataStores = {}
            svc.GetDataStore = function(self, name, scope)
                scope = scope or "global"
                if not dataStores[name] then dataStores[name] = {} end
                if not dataStores[name][scope] then
                    dataStores[name][scope] = {
                        GetAsync = function(_, key)
                            addCode(expr .. ':GetDataStore("' .. name .. '", "' .. scope .. '"):GetAsync("' .. key .. '")')
                            return nil
                        end,
                        SetAsync = function(_, key, value)
                            addCode(expr .. ':GetDataStore("' .. name .. '", "' .. scope .. '"):SetAsync("' .. key .. '", ...)')
                        end,
                        UpdateAsync = function(_, key, transformFunc)
                            addCode(expr .. ':GetDataStore("' .. name .. '", "' .. scope .. '"):UpdateAsync("' .. key .. '", ...)')
                            return nil
                        end,
                        IncrementAsync = function(_, key, delta)
                            addCode(expr .. ':GetDataStore("' .. name .. '", "' .. scope .. '"):IncrementAsync("' .. key .. '", ' .. tostring(delta) .. ')')
                            return delta or 1
                        end,
                    }
                end
                return dataStores[name][scope]
            end
        elseif name == "MessagingService" then
            svc.PublishAsync = function(self, topic, message)
                addCode(expr .. ':PublishAsync("' .. topic .. '", ...)')
            end
            svc.SubscribeAsync = function(self, topic, callback)
                addCode(expr .. ':SubscribeAsync("' .. topic .. '", function(...) end)')
                return {Disconnect = function() end}
            end
        elseif name == "CollectionService" then
            svc.GetTagged = function(self, tag)
                addCode(expr .. ':GetTagged("' .. tag .. '")')
                return {}
            end
            svc.AddTag = function(self, instance, tag)
                addCode(expr .. ':AddTag(' .. tostring(instance) .. ', "' .. tag .. '")')
            end
            svc.RemoveTag = function(self, instance, tag)
                addCode(expr .. ':RemoveTag(' .. tostring(instance) .. ', "' .. tag .. '")')
            end
            svc.HasTag = function(self, instance, tag) return false end
            svc.GetInstanceAddedSignal = function(self, tag) return createSignal() end
            svc.GetInstanceRemovedSignal = function(self, tag) return createSignal() end
        elseif name == "PathfindingService" then
            svc.CreatePath = function(self, params)
                addCode(expr .. ":CreatePath(...)")
                return newMockInstance("Path", expr .. ":CreatePath(...)", nil)
            end
        elseif name == "PhysicsService" then
            svc.CollisionGroup = {}
            svc.CreateCollisionGroup = function(self, name)
                addCode(expr .. ':CreateCollisionGroup("' .. name .. '")')
            end
            svc.CollisionGroupSetCollidable = function(self, group1, group2, collidable)
                addCode(expr .. ':CollisionGroupSetCollidable("' .. group1 .. '", "' .. group2 .. '", ' .. tostring(collidable) .. ')')
            end
        elseif name == "Lighting" then
            -- Use rawset to bypass any read‑only metamethods
            rawset(svc, "ClockTime", 12)
            rawset(svc, "Brightness", 1)
            rawset(svc, "FogEnd", 1000)
            rawset(svc, "Ambient", Types.Color3.new(0,0,0))
        elseif name == "StarterGui" then
            svc.SetCore = function(self, core, value)
                addCode(expr .. ':SetCore("' .. core .. '", ' .. serializeValue(value) .. ')')
            end
            svc.GetCore = function(self, core) return nil end
            svc.SetCoreGuiEnabled = function(self, coreGuiType, enabled)
                addCode(expr .. ':SetCoreGuiEnabled(Enum.CoreGuiType.' .. coreGuiType .. ', ' .. tostring(enabled) .. ')')
            end
        elseif name == "TeleportService" then
            svc.Teleport = function(self, placeId, players, spawnName)
                addCode(expr .. ":Teleport(" .. serializeValue(placeId) .. ", ...)")
            end
        elseif name == "MarketplaceService" then
            svc.PromptGamePassPurchase = function(self, player, gamePassId)
                addCode(expr .. ":PromptGamePassPurchase(...)")
            end
            svc.PromptProductPurchase = function(self, player, productId)
                addCode(expr .. ":PromptProductPurchase(...)")
            end
            svc.PlayerOwnsAsset = function(self, player, assetId) return false end
        elseif name == "Debris" then
            svc.AddItem = function(self, item, lifetime)
                addCode(expr .. ':AddItem(' .. tostring(item) .. ', ' .. lifetime .. ')')
            end
        elseif name == "ReplicatedStorage" then
            -- nothing extra
        elseif name == "ServerScriptService" then
            -- nothing extra
        end
    end
    return services[name]
end

-- Game object
env.game = setmetatable({}, {
    __index = function(t, key)
        if key == "GetService" then return function(_, name) return getService(name) end
        elseif key == "HttpGet" or key == "HttpGetAsync" then
            return function(_, url)
                addCode('game:HttpGet("' .. url .. '")')
                return ""
            end
        elseif key == "Players" then return getService("Players")
        elseif key == "Workspace" or key == "workspace" then return env.workspace
        elseif key == "ReplicatedStorage" then return getService("ReplicatedStorage")
        elseif key == "ServerScriptService" then return getService("ServerScriptService")
        elseif key == "ServerStorage" then return getService("ServerStorage")
        elseif key == "Lighting" then return getService("Lighting")
        elseif key == "RunService" then return getService("RunService")
        elseif key == "UserInputService" then return getService("UserInputService")
        elseif key == "TweenService" then return getService("TweenService")
        elseif key == "HttpService" then return getService("HttpService")
        elseif key == "TeleportService" then return getService("TeleportService")
        elseif key == "MarketplaceService" then return getService("MarketplaceService")
        elseif key == "Debris" then return getService("Debris")
        elseif key == "StarterGui" then return getService("StarterGui")
        elseif key == "StarterPack" then return getService("StarterPack")
        elseif key == "StarterPlayer" then return getService("StarterPlayer")
        elseif key == "CollectionService" then return getService("CollectionService")
        elseif key == "DataStoreService" then return getService("DataStoreService")
        elseif key == "MessagingService" then return getService("MessagingService")
        elseif key == "PathfindingService" then return getService("PathfindingService")
        elseif key == "PhysicsService" then return getService("PhysicsService")
        else return newMockInstance("Instance", "game." .. tostring(key), nil)
        end
    end,
    __tostring = function() return "game" end
})

env.workspace = newMockInstance("Workspace", "workspace", nil)
env.script   = newMockInstance("Script", "script", nil)

-- ==================== PRINT / WARN ====================
env.print = function(...)
    local args = {...}
    local strs = {}
    for i, v in ipairs(args) do strs[i] = serializeValue(v) end
    addCode("print(" .. table.concat(strs, ", ") .. ")")
end
env.warn = env.print

-- ==================== LOADSTRING (with execution) ====================
env.loadstring = function(code, chunkname)
    addCode("loadstring([[" .. truncate(code, 100) .. "]])")
    return function(...)
        addComment("loadstring function called")
        local chunk, err = loadstring(code, chunkname or "@loadstring")
        if chunk then
            setfenv(chunk, env)
            return chunk(...)
        else
            addComment("loadstring error: " .. err)
            return nil
        end
    end
end

-- ==================== STANDARD LIBRARY & COMMON GLOBALS ====================
env.type = type
env.typeof = type
env.tostring = tostring
env.tonumber = tonumber
env.pairs = pairs
env.ipairs = ipairs
env.next = next
env.pcall = pcall
env.xpcall = xpcall
env.assert = assert
env.error = error
env.select = select
env.unpack = unpack or table.unpack
env.getmetatable = getmetatable
env.setmetatable = setmetatable
env.rawget = rawget
env.rawset = rawset
env.rawequal = rawequal
env.math = math
env.table = table
env.string = string
env.os = {clock = os.clock, time = os.time, date = os.date}
env.tick = function() return os.clock() end
env.wait = function(t) if t then addCode("wait(" .. t .. ")") else addCode("wait()") end; return 0 end
env.task = {
    wait = function(t) addCode("task.wait(" .. (t and tostring(t) or "") .. ")"); return 0 end,
    spawn = function(f) addCode("task.spawn(function() end)") end,
    delay = function(t, f) addCode("task.delay(" .. t .. ", function() end)") end,
    defer = function(f) addCode("task.defer(function() end)") end,
}
env.getgenv = function() return env end
env.getrenv = function() return env end
env.getgc = function() return {} end
env.getinstances = function() return {} end
env.getnilinstances = function() return {} end
env.getloadedmodules = function() return {} end
env.getconnections = function() return {} end
env.setclipboard = function(text) addCode('setclipboard("' .. truncate(text, 50) .. '")') end
env.checkcaller = function() return true end
env.newcclosure = function(f) return f end
env.clonefunction = function(f) return f end
env._G = env
env.shared = {}
env._VERSION = "Lua 5.1"

-- ==================== OPTIONAL HOOKOP (operation tracking) ====================
if settings.hookOp then
    local function trackedNumber(n)
    return setmetatable({__value = n}, {
        __add = function(a,b) local av = type(a)=="table" and a.__value or a; local bv = type(b)=="table" and b.__value or b; return trackedNumber(av+bv) end,
        __sub = function(a,b) local av = type(a)=="table" and a.__value or a; local bv = type(b)=="table" and b.__value or b; return trackedNumber(av-bv) end,
        __mul = function(a,b) local av = type(a)=="table" and a.__value or a; local bv = type(b)=="table" and b.__value or b; return trackedNumber(av*bv) end,
        __div = function(a,b) local av = type(a)=="table" and a.__value or a; local bv = type(b)=="table" and b.__value or b; return trackedNumber(av/bv) end,
        __mod = function(a,b) local av = type(a)=="table" and a.__value or a; local bv = type(b)=="table" and b.__value or b; return trackedNumber(av%bv) end,
        __pow = function(a,b) local av = type(a)=="table" and a.__value or a; local bv = type(b)=="table" and b.__value or b; return trackedNumber(av^bv) end,
        __unm = function(a) local av = type(a)=="table" and a.__value or a; return trackedNumber(-av) end,
        __eq = function(a,b) local av = type(a)=="table" and a.__value or a; local bv = type(b)=="table" and b.__value or b; return av==bv end,
        __lt = function(a,b) local av = type(a)=="table" and a.__value or a; local bv = type(b)=="table" and b.__value or b; return av<bv end,
        __le = function(a,b) local av = type(a)=="table" and a.__value or a; local bv = type(b)=="table" and b.__value or b; return av<=bv end,
        __tostring = function(self) return tostring(self.__value) end,
        __tonumber = function(self) return self.__value end,
    })
end
    local oldTonumber = env.tonumber
    env.tonumber = function(...) local r = oldTonumber(...); if r then return trackedNumber(r) else return r end end
    for k, v in pairs(math) do if type(v)=="function" then env.math[k] = function(...) local r = v(...); if type(r)=="number" then r = trackedNumber(r) end; return r end end end
end

-- ==================== FUNCTION TRACKING (explore_funcs) ====================
if settings.explore_funcs then
    local function wrapFunction(func, name)
        return function(...)
            local args = {...}
            local argStrs = {}
            for i, v in ipairs(args) do argStrs[i] = serializeValue(v) end
            addComment("Function call: " .. name .. "(" .. table.concat(argStrs, ", ") .. ")")
            local results = {pcall(func, ...)}
            local ok = table.remove(results, 1)
            if ok then
                if #results > 0 then addComment("Returned: " .. serializeValue(results[1])) end
                return unpack(results)
            else
                addComment("Function errored: " .. tostring(results[1]))
                return nil
            end
        end
    end
    setmetatable(env, {
        __newindex = function(t, k, v)
            if type(v) == "function" then
                local params = {}
                local ok, info = pcall(debug.getinfo, v, "u")
                if ok and info then
                    for i = 1, info.nparams or 0 do params[i] = "arg"..i end
                    if info.isvararg then table.insert(params, "...") end
                else params = {"..."} end
                addCode("function " .. k .. "(" .. table.concat(params, ", ") .. ")")
                addComment("Function body (execution tracked below)")
                addCode("end")
                rawset(t, k, wrapFunction(v, k))
            else
                rawset(t, k, v)
            end
        end
    })
end

-- ==================== EXECUTION ====================
local chunk, err = loadstring(scriptContent)
if not chunk then
    addComment("Parse error: " .. tostring(err))
else
    setfenv(chunk, env)
    local ok, result = pcall(chunk)
    if not ok then addComment("Runtime error: " .. tostring(result)) end
    if ok and type(result) == "function" then
        setfenv(result, env)
        pcall(result)
    end
end

-- ==================== OUTPUT ====================
if not settings.minifier then
    print("-- Premium")
    print("")
end
for _, line in ipairs(codeLines) do print(line) end
if not settings.minifier then print(""); print("-- End of reconstructed code") end
