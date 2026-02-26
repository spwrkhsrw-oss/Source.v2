

local process = require("@lune/process")
local fs = require("@lune/fs")

local scriptPath = process.args[1]
if not scriptPath then
    print("Usage: lune run premium_reconstructor.lua <script_path>")
    process.exit(1)
end

local scriptContent = fs.readFile(scriptPath)


local settings = {
    hookOp             = process.env.SETTING_HOOKOP == "1",        
    explore_funcs      = process.env.SETTING_EXPLORE_FUNCS == "1",  
    spyexeconly        = process.env.SETTING_SPYEXECONLY == "1",     
    no_string_limit    = process.env.SETTING_NO_STRING_LIMIT == "1",
    minifier           = process.env.SETTING_MINIFIER == "1",
    comments           = process.env.SETTING_COMMENTS == "1",
    ui_detection       = process.env.SETTING_UI_DETECTION == "1",
    constant_collection= process.env.SETTING_CONSTANT_COLLECTION == "1",
    duplicate_searcher = process.env.SETTING_DUPLICATE_SEARCHER == "1",
    neverNester        = process.env.SETTING_NEVERNESTER == "1",
}

local codeLines = {}       
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

        
        local mt = getmetatable(value)
        if mt and mt.__tostring then
            return tostring(value)
        end


        if value.__varName then
            return value.__varName
        end

    
        local parts = {}
        local count = 0
        for k, v in pairs(value) do
            count = count + 1
            if count > 10 then parts[#parts+1] = "..."; break end
            local keyStr
            if type(k) == "string" and k:match("^[%a_][%w_]*$") and not k:match("^__") then
                keyStr = k
            else
                keyStr = "[" .. serializeValue(k, visited) .. "]"
            end
            parts[#parts+1] = keyStr .. "=" .. serializeValue(v, visited)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif t == "function" then
   
        for name, fn in pairs(env) do
            if fn == value then return name end
        end
        return "function() --[[ reconstructed ]] end"
    else
        return tostring(value)
    end
end


local Types = {}


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
        __index = {
            Magnitude = function(self) return math.sqrt(self.x^2 + self.y^2) end,
            Unit = function(self) local m=self.Magnitude; if m==0 then return Types.Vector2.new(0,0) end return Types.Vector2.new(self.x/m, self.y/m) end,
            Dot = function(self, other) return self.x*other.x + self.y*other.y end,
            Lerp = function(self, other, alpha) return self + (other - self) * alpha end,
        }
    })
end
Types.Vector2.zero = Types.Vector2.new(0,0)
Types.Vector2.one  = Types.Vector2.new(1,1)
Types.Vector2.xAxis = Types.Vector2.new(1,0)
Types.Vector2.yAxis = Types.Vector2.new(0,1)


Types.Vector2int16 = {}
function Types.Vector2int16.new(x, y)
    return setmetatable({x = math.floor(x or 0), y = math.floor(y or 0)}, {
        __tostring = function(self) return string.format("Vector2int16.new(%d, %d)", self.x, self.y) end,
        __add = function(a,b) return Types.Vector2int16.new(a.x + b.x, a.y + b.y) end,
        __sub = function(a,b) return Types.Vector2int16.new(a.x - b.x, a.y - b.y) end,
        __eq  = function(a,b) return a.x==b.x and a.y==b.y end,
    })
end


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
            FuzzyEq = function(self, other, epsilon) epsilon = epsilon or 1e-6; return math.abs(self.x-other.x)<=epsilon and math.abs(self.y-other.y)<=epsilon and math.abs(self.z-other.z)<=epsilon end,
        }
    })
end
Types.Vector3.zero = Types.Vector3.new(0,0,0)
Types.Vector3.one  = Types.Vector3.new(1,1,1)
Types.Vector3.xAxis = Types.Vector3.new(1,0,0)
Types.Vector3.yAxis = Types.Vector3.new(0,1,0)
Types.Vector3.zAxis = Types.Vector3.new(0,0,1)


Types.Vector3int16 = {}
function Types.Vector3int16.new(x, y, z)
    return setmetatable({x = math.floor(x or 0), y = math.floor(y or 0), z = math.floor(z or 0)}, {
        __tostring = function(self) return string.format("Vector3int16.new(%d, %d, %d)", self.x, self.y, self.z) end,
        __add = function(a,b) return Types.Vector3int16.new(a.x+b.x, a.y+b.y, a.z+b.z) end,
        __sub = function(a,b) return Types.Vector3int16.new(a.x-b.x, a.y-b.y, a.z-b.z) end,
        __eq  = function(a,b) return a.x==b.x and a.y==b.y and a.z==b.z end,
    })
end


Types.CFrame = {}
function Types.CFrame.new(...)
    local args = {...}
    if #args == 3 then
        local pos = Types.Vector3.new(args[1], args[2], args[3])
        return setmetatable({
            position = pos,
            components = {pos.x, pos.y, pos.z, 1,0,0,0,1,0,0,0,1} -- identity rotation
        }, {
            __tostring = function(self) return string.format("CFrame.new(%g, %g, %g)", self.position.x, self.position.y, self.position.z) end,
            __mul = function(a, b)
                if getmetatable(b) == Types.Vector3 then
                    return Types.Vector3.new(a.position.x + b.x, a.position.y + b.y, a.position.z + b.z)
                elseif getmetatable(b) == Types.CFrame then
                    return Types.CFrame.new(a.position.x + b.position.x, a.position.y + b.position.y, a.position.z + b.position.z)
                end
                return a
            end,
            __index = {
                Position = function(self) return self.position end,
                X = function(self) return self.position.x end,
                Y = function(self) return self.position.y end,
                Z = function(self) return self.position.z end,
                LookVector = function(self) return Types.Vector3.new(0,0,-1) end, -- placeholder cuz nigga we cant
                RightVector = function(self) return Types.Vector3.new(1,0,0) end,
                UpVector = function(self) return Types.Vector3.new(0,1,0) end,
                ToWorldSpace = function(self, cf) return self * cf end,
                ToObjectSpace = function(self, cf) return cf * self:Inverse() end,
                PointToWorldSpace = function(self, v) return self * v end,
                VectorToWorldSpace = function(self, v) return self * v end,
                Inverse = function(self) return Types.CFrame.new(-self.position.x, -self.position.y, -self.position.z) end,
                Lerp = function(self, goal, alpha) return self + (goal - self) * alpha end,
                GetComponents = function(self) return self.position.x, self.position.y, self.position.z, 1,0,0,0,1,0,0,0,1 end,
            }
        })
    elseif #args == 12 then -- full matrix no shit sherlock
        return setmetatable({matrix = args, position = Types.Vector3.new(args[1], args[2], args[3])}, {
            __tostring = function() return "CFrame.new(...)" end,
            __index = function(self, key) return rawget(self, key) or rawget(getmetatable(self).__index, key) end
        })
    else
        return setmetatable({args = args}, {__tostring = function() return "CFrame.new(...)" end})
    end
end
function Types.CFrame.Angles(rx, ry, rz)
    return setmetatable({angles = {rx, ry, rz}, position = Types.Vector3.new(0,0,0)}, {
        __tostring = function() return string.format("CFrame.Angles(%g, %g, %g)", rx, ry, rz) end
    })
end
function Types.CFrame.fromEulerAnglesXYZ(x, y, z) return Types.CFrame.Angles(x, y, z) end
function Types.CFrame.lookAt(eye, target)
    return setmetatable({eye = eye, target = target}, {__tostring = function() return "CFrame.lookAt("..tostring(eye)..", "..tostring(target)..")" end})
end
function Types.CFrame.fromMatrix(pos, vX, vY, vZ)
    return setmetatable({pos = pos, vX = vX, vY = vY, vZ = vZ}, {__tostring = function() return "CFrame.fromMatrix(...)" end})
end


Types.Color3 = {}
function Types.Color3.new(r, g, b)
    return setmetatable({r = r or 0, g = g or 0, b = b or 0}, {
        __tostring = function(self) return string.format("Color3.new(%g, %g, %g)", self.r, self.g, self.b) end,
        __add = function(a,b) return Types.Color3.new(a.r+b.r, a.g+b.g, a.b+b.b) end,
        __sub = function(a,b) return Types.Color3.new(a.r-b.r, a.g-b.g, a.b-b.b) end,
        __mul = function(a,b) if type(b)=="number" then return Types.Color3.new(a.r*b, a.g*b, a.b*b) end return Types.Color3.new(a.r*b.r, a.g*b.g, a.b*b.b) end,
        __eq  = function(a,b) return a.r==b.r and a.g==b.g and a.b==b.b end,
        __index = {
            Lerp = function(self, other, alpha) return self + (other - self) * alpha end,
            ToHex = function(self) return string.format("#%02x%02x%02x", math.floor(self.r*255), math.floor(self.g*255), math.floor(self.b*255)) end,
        }
    })
end
function Types.Color3.fromRGB(r, g, b) return Types.Color3.new(r/255, g/255, b/255) end
function Types.Color3.fromHSV(h, s, v)
    return setmetatable({h = h, s = s, v = v}, {__tostring = function(self) return string.format("Color3.fromHSV(%g, %g, %g)", self.h, self.s, self.v) end})
end
function Types.Color3.fromHex(hex)
    hex = hex:gsub("#","")
    local r = tonumber(hex:sub(1,2),16)/255
    local g = tonumber(hex:sub(3,4),16)/255
    local b = tonumber(hex:sub(5,6),16)/255
    return Types.Color3.new(r,g,b)
end


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
        __index = {
            Lerp = function(self, other, alpha)
                return Types.UDim2.new(
                    self.X.Scale + (other.X.Scale - self.X.Scale) * alpha,
                    self.X.Offset + (other.X.Offset - self.X.Offset) * alpha,
                    self.Y.Scale + (other.Y.Scale - self.Y.Scale) * alpha,
                    self.Y.Offset + (other.Y.Offset - self.Y.Offset) * alpha
                )
            end
        }
    })
end
function Types.UDim2.fromOffset(x, y) return Types.UDim2.new(0, x, 0, y) end
function Types.UDim2.fromScale(x, y) return Types.UDim2.new(x, 0, y, 0) end


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
    if type(name) == "number" then 
        for k, v in pairs(brickColorPalette) do if v == name then name = k; break end end
    end
    return setmetatable({Name = tostring(name), Number = brickColorPalette[name] or 1}, {
        __tostring = function(self) return 'BrickColor.new("' .. self.Name .. '")' end,
        __index = {
            Color = function(self) 
                if self.Name == "White" then return Types.Color3.new(1,1,1)
                elseif self.Name == "Black" then return Types.Color3.new(0,0,0)
                elseif self.Name == "Red" then return Types.Color3.new(1,0,0)
                else return Types.Color3.new(0.5,0.5,0.5) end
            end,
        }
    })
end
for name, num in pairs(brickColorPalette) do
    Types.BrickColor[name] = Types.BrickColor.new(name)
end
function Types.BrickColor.random() return Types.BrickColor.new("Random") end
function Types.BrickColor.Red() return Types.BrickColor.new("Red") end
function Types.BrickColor.Blue() return Types.BrickColor.new("Blue") end
function Types.BrickColor.Green() return Types.BrickColor.new("Green") end
function Types.BrickColor.Yellow() return Types.BrickColor.new("Yellow") end

Types.NumberRange = {}
function Types.NumberRange.new(min, max) max = max or min
    return setmetatable({Min = min, Max = max}, {__tostring = function(self) return string.format("NumberRange.new(%g, %g)", self.Min, self.Max) end})
end


Types.NumberSequence = {}
function Types.NumberSequence.new(...)
    local points = {...}
    return setmetatable({Keypoints = points}, {__tostring = function(self) 
        local str = "NumberSequence.new("
        for i, kp in ipairs(self.Keypoints) do
            if i > 1 then str = str .. ", " end
            str = str .. tostring(kp)
        end
        return str .. ")"
    end})
end
Types.NumberSequenceKeypoint = {}
function Types.NumberSequenceKeypoint.new(time, value, envelope)
    return setmetatable({Time = time, Value = value, Envelope = envelope or 0}, {
        __tostring = function(self) return string.format("NumberSequenceKeypoint.new(%g, %g, %g)", self.Time, self.Value, self.Envelope) end
    })
end


Types.ColorSequence = {}
function Types.ColorSequence.new(...)
    local points = {...}
    return setmetatable({Keypoints = points}, {__tostring = function(self)
        local str = "ColorSequence.new("
        for i, kp in ipairs(self.Keypoints) do
            if i > 1 then str = str .. ", " end
            str = str .. tostring(kp)
        end
        return str .. ")"
    end})
end
Types.ColorSequenceKeypoint = {}
function Types.ColorSequenceKeypoint.new(time, color, envelope)
    return setmetatable({Time = time, Color = color, Envelope = envelope or 0}, {
        __tostring = function(self) return string.format("ColorSequenceKeypoint.new(%g, %s, %g)", self.Time, tostring(self.Color), self.Envelope) end
    })
end


Types.Ray = {}
function Types.Ray.new(origin, direction)
    return setmetatable({Origin = origin, Direction = direction}, {__tostring = function(self) return string.format("Ray.new(%s, %s)", tostring(self.Origin), tostring(self.Direction)) end})
end


Types.Region3 = {}
function Types.Region3.new(min, max)
    return setmetatable({Min = min, Max = max}, {__tostring = function(self) return string.format("Region3.new(%s, %s)", tostring(self.Min), tostring(self.Max)) end})
end


Types.Region3int16 = {}
function Types.Region3int16.new(min, max)
    return setmetatable({Min = min, Max = max}, {__tostring = function(self) return string.format("Region3int16.new(%s, %s)", tostring(self.Min), tostring(self.Max)) end})
end


Types.TweenInfo = {}
function Types.TweenInfo.new(time, easingStyle, easingDirection, repeatCount, reverses, delayTime)
    return setmetatable({
        Time = time or 1,
        EasingStyle = easingStyle or Types.Enum.EasingStyle.Linear,
        EasingDirection = easingDirection or Types.Enum.EasingDirection.In,
        RepeatCount = repeatCount or 0,
        Reverses = reverses or false,
        DelayTime = delayTime or 0
    }, {
        __tostring = function(self)
            return string.format("TweenInfo.new(%g, %s, %s, %g, %s, %g)",
                self.Time, tostring(self.EasingStyle), tostring(self.EasingDirection),
                self.RepeatCount, tostring(self.Reverses), self.DelayTime)
        end
    })
end


Types.Rect = {}
function Types.Rect.new(min, max)
    return setmetatable({Min = min, Max = max}, {__tostring = function(self) return string.format("Rect.new(%s, %s)", tostring(self.Min), tostring(self.Max)) end})
end


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


Types.DateTime = {}
function Types.DateTime.fromUnixTimestamp(ts)
    return setmetatable({unix = ts}, {
        __tostring = function(self) return "DateTime.fromUnixTimestamp("..self.unix..")" end,
        __index = {
            ToIsoDate = function(self) return os.date("%Y-%m-%dT%H:%M:%SZ", self.unix) end,
            ToUnixTimestamp = function(self) return self.unix end,
        }
    })
end
function Types.DateTime.fromIsoDate(date)
    
    return setmetatable({iso = date}, {__tostring = function(self) return 'DateTime.fromIsoDate("'..self.iso..'")' end})
end
function Types.DateTime.now()
    return setmetatable({unix = os.time()}, {__tostring = function() return "DateTime.now()" end})
end


Types.Faces = {}
function Types.Faces.new(faceIds) 
    return setmetatable({faces = faceIds}, {
        __tostring = function() return "Faces.new(...)" end,
        __index = {
            Left = false, Right = false, Top = false, Bottom = false, Front = false, Back = false,
        }
    })
end
Types.Axes = {}
function Types.Axes.new(axisIds) 
    return setmetatable({axes = axisIds}, {
        __tostring = function() return "Axes.new(...)" end,
        __index = {
            X = false, Y = false, Z = false,
        }
    })
end


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
    "CoreGuiType", "PlayerActions", "AnalyticsLogLevel", "UserCFrame", "BodyMoverType",
    "RibbonTab", "DockWidgetPluginGuiInfo", "InitialDockState", "ZIndexBehavior", "ItemSample",
    "VRSessionState", "PartType", "FormFactor", "LegacyDialogBehavior", "LegacyDialogPurpose",
    "LegacyDialogTone", "ModelStreamingMode", "StreamingMinRadius", "StreamingTargetRadius",
    "StreamingPauseMode", "StreamingRenderMode", "StreamingBudget", "StreamingMode",
    "StreamingPriority", "StreamingSource", "StreamingSourceType", "StreamingSourceMode",
    "StreamingSourcePriority", "StreamingSourceBudget", "StreamingSourceRenderMode",
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
                elseif key == "FindFirstAncestor" then
                    return function(_, name)
                        local p = t.Parent
                        while p do
                            if p.Name == name then return p end
                            p = p.Parent
                        end
                        return nil
                    end
                elseif key == "FindFirstAncestorOfClass" then
                    return function(_, class)
                        local p = t.Parent
                        while p do
                            if p.__className == class then return p end
                            p = p.Parent
                        end
                        return nil
                    end
                elseif key == "FindFirstAncestorWhichIsA" then
                    return function(_, class)
                        local p = t.Parent
                        while p do
                            if p:IsA(class) then return p end
                            p = p.Parent
                        end
                        return nil
                    end
                elseif key == "GetFullName" then
                    return function()
                        local parts = {}
                        local obj = t
                        while obj do
                            table.insert(parts, 1, obj.Name)
                            obj = obj.Parent
                        end
                        return table.concat(parts, ".")
                    end
                elseif key == "GetDebugId" then
                    return function() return tostring(t) end
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
            local base = t.__varName or t.__expression
            if base then
                addCode(base .. "." .. key .. " = " .. valueStr)
            else
                addComment("Assignment to unknown instance: " .. tostring(key) .. " = " .. valueStr)
            end
        end,
        __tostring = function() return t.__expression end
    }
    return setmetatable(self, mt)
end


env = {} 
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

-- rel fi bypaz
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
            svc.ReserveUserId = function() return 0 end
            svc.CreateHumanoidModelFromUserId = function() return newMockInstance("Model", expr .. ":CreateHumanoidModelFromUserId()", nil) end
            svc.GetUserThumbnailAsync = function() return "", 0 end
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
            svc.IsClient = function() return true end
            svc.IsServer = function() return false end
        elseif name == "UserInputService" then
            svc.InputBegan = createSignal()
            svc.InputEnded = createSignal()
            svc.InputChanged = createSignal()
            svc.TouchStarted = createSignal()
            svc.TouchEnded = createSignal()
            svc.TouchMoved = createSignal()
            svc.GetMouseLocation = function() return Types.Vector2.new(0,0) end
            svc.IsKeyDown = function() return false end
            svc.GetKeyboardEnabled = function() return true end
            svc.GetMouseEnabled = function() return true end
            svc.GetTouchEnabled = function() return false end
            svc.GetGamepadEnabled = function() return false end
            svc.GetPlatform = function() return "Windows" end
        elseif name == "TweenService" then
            svc.Create = function(self, obj, info, props)
                addCode(expr .. ":Create(" .. tostring(obj) .. ", " .. tostring(info) .. ", ...)")
                return newMockInstance("Tween", expr .. ":Create(...)", nil)
            end
        elseif name == "HttpService" then
            svc.GetAsync = function(self, url, nocache, headers)
                addCode(expr .. ':GetAsync("' .. url .. '", ' .. tostring(nocache) .. ')')
                return ""  -- bro i wanna shit myself
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
            svc.UrlEncode = function(self, str) return str end
            svc.GenerateGUID = function(self) return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx" end
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
                        RemoveAsync = function(_, key)
                            addCode(expr .. ':GetDataStore("' .. name .. '", "' .. scope .. '"):RemoveAsync("' .. key .. '")')
                        end,
                        ListKeysAsync = function(_, prefix, pageSize, exclusiveStartKey)
                            addCode(expr .. ':GetDataStore("' .. name .. '", "' .. scope .. '"):ListKeysAsync(...)')
                            return {GetCurrentPage = function() return {} end}
                        end,
                    }
                end
                return dataStores[name][scope]
            end
            svc.GetOrderedDataStore = function(self, name, scope)
                scope = scope or "global"
                return {
                    GetAsync = function(_, key) return nil end,
                    SetAsync = function(_, key, value) addCode(expr .. ':GetOrderedDataStore("' .. name .. '", "' .. scope .. '"):SetAsync("' .. key .. '", ' .. tostring(value) .. ')') end,
                    UpdateAsync = function(_, key, transform) return nil end,
                    IncrementAsync = function(_, key, delta) return delta end,
                    RemoveAsync = function(_, key) end,
                    GetSortedAsync = function(_, ascending, pageSize, min, max) return {GetCurrentPage = function() return {} end} end,
                }
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
            svc.ComputeRawPathAsync = function(self, start, finish, maxDistance, params)
                addCode(expr .. ":ComputeRawPathAsync(...)")
                return {Status = Types.Enum.PathStatus.Success, Waypoints = {}}
            end
        elseif name == "PhysicsService" then
            svc.CollisionGroup = {}
            svc.CreateCollisionGroup = function(self, name)
                addCode(expr .. ':CreateCollisionGroup("' .. name .. '")')
            end
            svc.CollisionGroupSetCollidable = function(self, group1, group2, collidable)
                addCode(expr .. ':CollisionGroupSetCollidable("' .. group1 .. '", "' .. group2 .. '", ' .. tostring(collidable) .. ')')
            end
            svc.GetCollisionGroupName = function(self, id) return "" end
            svc.GetCollisionGroupId = function(self, name) return 0 end
            svc.RenameCollisionGroup = function(self, oldName, newName)
                addCode(expr .. ':RenameCollisionGroup("' .. oldName .. '", "' .. newName .. '")')
            end
            svc.RemoveCollisionGroup = function(self, name)
                addCode(expr .. ':RemoveCollisionGroup("' .. name .. '")')
            end
        elseif name == "Lighting" then
            rawset(svc, "ClockTime", 12)
            rawset(svc, "Brightness", 1)
            rawset(svc, "FogEnd", 1000)
            rawset(svc, "Ambient", Types.Color3.new(0,0,0))
            rawset(svc, "OutdoorAmbient", Types.Color3.new(0.5,0.5,0.5))
            rawset(svc, "GeographicLatitude", 41.5)
            rawset(svc, "TimeOfDay", "12:00:00")
            rawset(svc, "GetMoonDirection", function() return Types.Vector3.new(0, -1, 0) end)
            rawset(svc, "GetSunDirection", function() return Types.Vector3.new(0, 1, 0) end)
        elseif name == "StarterGui" then
            svc.SetCore = function(self, core, value)
                addCode(expr .. ':SetCore("' .. core .. '", ' .. serializeValue(value) .. ')')
            end
            svc.GetCore = function(self, core) return nil end
            svc.SetCoreGuiEnabled = function(self, coreGuiType, enabled)
                addCode(expr .. ':SetCoreGuiEnabled(Enum.CoreGuiType.' .. coreGuiType .. ', ' .. tostring(enabled) .. ')')
            end
            svc.GetCoreGuiEnabled = function(self, coreGuiType) return false end
        elseif name == "TeleportService" then
            svc.Teleport = function(self, placeId, players, spawnName)
                addCode(expr .. ":Teleport(" .. serializeValue(placeId) .. ", ...)")
            end
            svc.TeleportToSpawnByName = function(self, placeId, spawnName, players)
                addCode(expr .. ':TeleportToSpawnByName(' .. placeId .. ', "' .. spawnName .. '", ...)')
            end
            svc.TeleportPAsync = function(self, placeId, players, teleportData, spawnName)
                addCode(expr .. ":TeleportPAsync(...)")
            end
            svc.GetLocalPlayerTeleportData = function(self) return nil end
        elseif name == "MarketplaceService" then
            svc.PromptGamePassPurchase = function(self, player, gamePassId)
                addCode(expr .. ":PromptGamePassPurchase(...)")
            end
            svc.PromptProductPurchase = function(self, player, productId)
                addCode(expr .. ":PromptProductPurchase(...)")
            end
            svc.PlayerOwnsAsset = function(self, player, assetId) return false end
            svc.PlayerOwnsGamePassAsync = function(self, player, gamePassId) return false end
            svc.GetProductInfo = function(self, assetId, infoType) return {} end
            svc.UserOwnsGamePassAsync = function(self, userId, gamePassId) return false end
        elseif name == "Debris" then
            svc.AddItem = function(self, item, lifetime)
                addCode(expr .. ':AddItem(' .. tostring(item) .. ', ' .. lifetime .. ')')
            end
        elseif name == "ContextActionService" then
            svc.BindAction = function(self, actionName, func, createTouchButton, ...)
                addCode(expr .. ':BindAction("' .. actionName .. '", function(...) end, ' .. tostring(createTouchButton) .. ', ...)')
            end
            svc.UnbindAction = function(self, actionName)
                addCode(expr .. ':UnbindAction("' .. actionName .. '")')
            end
            svc.BindActionAtPriority = function(self, actionName, func, createTouchButton, priority, ...)
                addCode(expr .. ':BindActionAtPriority("' .. actionName .. '", ...)')
            end
            svc.GetBoundActionInfo = function(self, actionName) return nil end
            svc.SetTitle = function(self, actionName, title)
                addCode(expr .. ':SetTitle("' .. actionName .. '", "' .. title .. '")')
            end
            svc.SetDescription = function(self, actionName, description)
                addCode(expr .. ':SetDescription("' .. actionName .. '", "' .. description .. '")')
            end
            svc.SetImage = function(self, actionName, image)
                addCode(expr .. ':SetImage("' .. actionName .. '", "' .. image .. '")')
            end
            svc.SetPosition = function(self, actionName, position)
                addCode(expr .. ':SetPosition("' .. actionName .. '", ' .. tostring(position) .. ')')
            end
        elseif name == "VirtualInputManager" then
            svc.SendKeyEvent = function(self, inputType, keyCode, down, gameProcessedEvent)
                addCode(expr .. ':SendKeyEvent(' .. tostring(inputType) .. ', ' .. tostring(keyCode) .. ', ' .. tostring(down) .. ')')
            end
            svc.SendMouseButtonEvent = function(self, x, y, button, down, gameProcessedEvent)
                addCode(expr .. ':SendMouseButtonEvent(' .. x .. ', ' .. y .. ', ' .. button .. ', ' .. tostring(down) .. ')')
            end
            svc.SendMouseWheelEvent = function(self, x, y, scrollX, scrollY, gameProcessedEvent)
                addCode(expr .. ':SendMouseWheelEvent(' .. x .. ', ' .. y .. ', ' .. scrollX .. ', ' .. scrollY .. ')')
            end
            svc.SendTouchEvent = function(self, position, phase, gameProcessedEvent)
                addCode(expr .. ':SendTouchEvent(' .. tostring(position) .. ', ' .. tostring(phase) .. ')')
            end
        elseif name == "VirtualUser" then
            svc.Button1Down = function(self, position, gameProcessedEvent)
                addCode(expr .. ':Button1Down(' .. tostring(position) .. ')')
            end
            svc.Button1Up = function(self, position, gameProcessedEvent)
                addCode(expr .. ':Button1Up(' .. tostring(position) .. ')')
            end
            svc.Move = function(self, vector, gameProcessedEvent)
                addCode(expr .. ':Move(' .. tostring(vector) .. ')')
            end
            svc.Scroll = function(self, scrollX, scrollY)
                addCode(expr .. ':Scroll(' .. scrollX .. ', ' .. scrollY .. ')')
            end
        elseif name == "SoundService" then
            svc.PlayLocalSound = function(self, soundId)
                addCode(expr .. ':PlayLocalSound("' .. soundId .. '")')
            end
            svc.SetListener = function(self, listener) end
            svc.GetListener = function(self) return "CFrame" end
            svc.ListenerType = "CFrame"
        elseif name == "TextService" then
            svc.GetTextSize = function(self, text, fontSize, font, frameSize)
                addCode(expr .. ':GetTextSize("' .. text .. '", ' .. fontSize .. ', ' .. tostring(font) .. ', ' .. tostring(frameSize) .. ')')
                return Types.Vector2.new(100,20)
            end
            svc.FilterStringAsync = function(self, text, fromUserId, enumContext)
                addCode(expr .. ':FilterStringAsync("' .. text .. '", ' .. fromUserId .. ')')
                return {GetNonChatStringForBroadcastAsync = function() return text end}
            end
        elseif name == "Chat" then
            svc.Chat = function(self, speaker, message, channel)
                addCode(expr .. ':Chat(' .. tostring(speaker) .. ', "' .. message .. '", "' .. channel .. '")')
            end
            svc.RegisterChatCallback = function(self, callbackType, func) end
        elseif name == "Teams" then
            svc.TeamAdded = createSignal()
            svc.TeamRemoved = createSignal()
            svc.GetTeams = function() return {} end
        elseif name == "StarterPlayer" then
            svc.StarterPlayerScripts = newMockInstance("Folder", expr .. ".StarterPlayerScripts", nil)
            svc.StarterCharacterScripts = newMockInstance("Folder", expr .. ".StarterCharacterScripts", nil)
        elseif name == "StarterPack" then
            svc.StarterPack.ChildAdded = createSignal()
        elseif name == "ReplicatedFirst" then
            svc.ReplicatedFirst.ChildAdded = createSignal()
        elseif name == "ServerStorage" then
            -- nothing extra
        elseif name == "ServerScriptService" then
            -- nothing extra
        elseif name == "GroupService" then
            svc.GetGroupInfoAsync = function(self, groupId) return {Name = "Group", Id = groupId} end
            svc.GetGroupsAsync = function(self, userId) return {} end
        elseif name == "FriendsService" then
            svc.GetFriendsAsync = function(self, userId) return {} end
            svc.GetFriendCount = function(self, userId) return 0 end
        elseif name == "BadgeService" then
            svc.UserHasBadgeAsync = function(self, userId, badgeId) return false end
            svc.AwardBadge = function(self, userId, badgeId) end
        elseif name == "GamePassService" then
            svc.UserHasGamePassAsync = function(self, userId, gamePassId) return false end
        elseif name == "PolicyService" then
            svc.GetPolicyInfoAsync = function(self) return {} end
        elseif name == "PermissionsService" then
            svc.GetPermissionsAsync = function(self, userId) return {} end
        elseif name == "HttpRbxApiService" then
            svc.GetAsync = function(self, url) return "" end
            svc.PostAsync = function(self, url, data) return "" end
        elseif name == "AnalyticsService" then
            svc.LogEvent = function(self, eventName, ...) end
            svc.LogCustomEvent = function(self, eventName, ...) end
        elseif name == "LogService" then
            svc.MessageOut = createSignal()
            svc.GetLogHistory = function() return {} end
        elseif name == "DebuggerManager" then
            svc.DebuggerEnabled = true
            svc.DebuggerEnabledChanged = createSignal()
        elseif name == "PluginManager" then
            svc.PluginAdded = createSignal()
        elseif name == "Selection" then
            svc.Get = function() return {} end
            svc.Set = function(_, objects) addCode(expr .. ':Set(...)') end
        elseif name == "ChangeHistoryService" then
            svc.ResetWaypoint = function() end
            svc.SetEnabled = function(_, enabled) end
        elseif name == "StudioService" then
            svc.GetClassIcon = function(_, className) return "" end
        end
    end
    return services[name]
end


env.game = setmetatable({}, {
    __index = function(t, key)
        if key == "GetService" then return function(_, name) return getService(name) end
        elseif key == "HttpGet" or key == "HttpGetAsync" then
            return function(_, url)
                addCode('game:HttpGet("' .. url .. '")')
                return ""
            end
        elseif key == "HttpPost" or key == "HttpPostAsync" then
            return function(_, url, data)
                addCode('game:HttpPost("' .. url .. '", ' .. serializeValue(data) .. ')')
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
        elseif key == "ContextActionService" then return getService("ContextActionService")
        elseif key == "VirtualInputManager" then return getService("VirtualInputManager")
        elseif key == "VirtualUser" then return getService("VirtualUser")
        elseif key == "SoundService" then return getService("SoundService")
        elseif key == "TextService" then return getService("TextService")
        elseif key == "Chat" then return getService("Chat")
        elseif key == "Teams" then return getService("Teams")
        elseif key == "ReplicatedFirst" then return getService("ReplicatedFirst")
        elseif key == "GroupService" then return getService("GroupService")
        elseif key == "FriendsService" then return getService("FriendsService")
        elseif key == "BadgeService" then return getService("BadgeService")
        elseif key == "GamePassService" then return getService("GamePassService")
        elseif key == "PolicyService" then return getService("PolicyService")
        elseif key == "PermissionsService" then return getService("PermissionsService")
        elseif key == "HttpRbxApiService" then return getService("HttpRbxApiService")
        elseif key == "AnalyticsService" then return getService("AnalyticsService")
        elseif key == "LogService" then return getService("LogService")
        elseif key == "DebuggerManager" then return getService("DebuggerManager")
        elseif key == "PluginManager" then return getService("PluginManager")
        elseif key == "Selection" then return getService("Selection")
        elseif key == "ChangeHistoryService" then return getService("ChangeHistoryService")
        elseif key == "StudioService" then return getService("StudioService")
        else return newMockInstance("Instance", "game." .. tostring(key), nil)
        end
    end,
    __tostring = function() return "game" end
})

env.workspace = newMockInstance("Workspace", "workspace", nil)
env.script   = newMockInstance("Script", "script", nil)


env.print = function(...)
    local args = {...}
    local strs = {}
    for i, v in ipairs(args) do strs[i] = serializeValue(v) end
    addCode("print(" .. table.concat(strs, ", ") .. ")")
end
env.warn = function(...)
    local args = {...}
    local strs = {}
    for i, v in ipairs(args) do strs[i] = serializeValue(v) end
    addCode("warn(" .. table.concat(strs, ", ") .. ")")
end
env.error = function(msg, level)
    addCode('error("' .. tostring(msg):gsub('"', '\\"') .. '", ' .. (level or 1) .. ')')
end
env.assert = function(cond, msg)
    if not cond then
        addCode('assert(false, "' .. tostring(msg):gsub('"', '\\"') .. '")')
    end
    return cond, msg
end


env.type = type
env.typeof = function(v)
    if getmetatable(v) and getmetatable(v).__type then
        return getmetatable(v).__type
    end
    return type(v)
end
env.tostring = tostring
env.tonumber = tonumber
env.pairs = pairs
env.ipairs = ipairs
env.next = next
env.pcall = pcall
env.xpcall = xpcall
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
-- We will NOT expose io or dangerous os functions
env.os = {clock = os.clock, time = os.time, date = os.date, difftime = os.difftime}
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


local rawLoadstring = loadstring
env.loadstring = function(code, chunkname)
    addCode("loadstring([[" .. truncate(code, 100) .. "]])")
    return function() end
end


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


local function createRestrictedEnv(baseEnv)
    local restricted = {}
    
    local safeKeys = {
        
        "Vector2", "Vector3", "CFrame", "Color3", "UDim", "UDim2",
        "BrickColor", "NumberRange", "NumberSequence", "NumberSequenceKeypoint",
        "ColorSequence", "ColorSequenceKeypoint", "Ray", "Region3", "Region3int16",
        "TweenInfo", "Rect", "PhysicalProperties", "DateTime", "Faces", "Axes",
        "Enum", "Instance", "game", "workspace", "script",
        
        "print", "warn", "error", "assert", "type", "typeof", "tostring", "tonumber",
        "pairs", "ipairs", "next", "pcall", "xpcall", "select", "unpack",
        "getmetatable", "setmetatable", "rawget", "rawset", "rawequal",
        "math", "table", "string", "os", "tick", "wait", "task",
        "shared", "_G", "_VERSION",
        
        "getgenv", "getrenv", "getgc", "getinstances", "getnilinstances",
        "getloadedmodules", "getconnections", "setclipboard", "checkcaller",
        "newcclosure", "clonefunction",
        
        "loadstring",
    }
    for _, k in ipairs(safeKeys) do
        if baseEnv[k] ~= nil then
            restricted[k] = baseEnv[k]
        end
    end

    
    restricted.os = {
        clock = os.clock,
        time = os.time,
        date = os.date,
        difftime = os.difftime,
    }
    restricted.io = nil
    restricted.debug = nil  
    restricted.coroutine = coroutine  

    
    restricted.loadstring = function(code, chunkname)
        local chunk, err = rawLoadstring(code, chunkname)
        if chunk then
            setfenv(chunk, restricted)
        end
        return chunk, err
    end

    
    restricted.getfenv = function(level)
        
        return restricted
    end
    restricted.setfenv = function(f, env)
        
        return f
    end

    
    restricted.checkcaller = function() return false end
    restricted.getgenv = function() return restricted end
    restricted.getrenv = function() return restricted end

    
    restricted._G = restricted

    return restricted
end


local chunk, err = loadstring(scriptContent)
if not chunk then
    addComment("Parse error: " .. tostring(err))
else
    
    local restrictedEnv = createRestrictedEnv(env)
    setfenv(chunk, restrictedEnv)
    local ok, result = pcall(chunk)
    if not ok then addComment("Runtime error: " .. tostring(result)) end
    if ok and type(result) == "function" then
        setfenv(result, restrictedEnv)
        pcall(result)
    end
end


if not settings.minifier then
    print("-- sum shit log:")
    print("-- wearelarps")
    print("")
end
for _, line in ipairs(codeLines) do print(line) end
if not settings.minifier then print(""); print("-- End of ts shit") end
