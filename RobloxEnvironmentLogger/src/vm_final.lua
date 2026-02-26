-- VM INTERCEPTOR FINAL v2
-- Uses local shadowing + string metatable fix
local process = require("@lune/process")
local fs = require("@lune/fs")
local stdio = require("@lune/stdio")

local scriptPath = process.args[1]
if not scriptPath then
    print("Usage: lune run vm_final.lua <script_path>")
    process.exit(1)
end

local scriptContent = fs.readFile(scriptPath)

local preamble = [[
-- === VM MONITOR PREAMBLE ===
local __original_print = print
local __logs = {}
local __opCount = 0
local __startTime = os.clock()

local function __log(category, detail)
    __opCount = __opCount + 1
    local time = string.format("%.3f", os.clock() - __startTime)
    local entry = string.format("[%04d] [%s] %s: %s", __opCount, time, category, tostring(detail))
    __original_print("  " .. entry)
end

local function __createMock(name, props)
    local mock = props or {}
    mock.__type = name
    mock.__props = {}
    
    local mt = {
        __index = function(t, k)
            if mock[k] ~= nil then return mock[k] end
            if mock.__props[k] ~= nil then return mock.__props[k] end
            
            if k == "Name" then return mock.__props.Name or name end
            if k == "Parent" then return mock.__props.Parent end
            if k == "ClassName" then return name end
            
            if k == "Destroy" or k == "Clone" or k == "ClearAllChildren" then
                return function(self) __log("METHOD", name .. ":" .. k .. "()") end
            end
            if k == "WaitForChild" or k == "FindFirstChild" then
                return function(self, childName)
                    __log("METHOD", name .. ":" .. k .. "(\"" .. tostring(childName) .. "\")")
                    return __createMock(childName)
                end
            end
            if k == "GetChildren" then
                return function(self)
                    __log("METHOD", name .. ":GetChildren()")
                    return {}
                end
            end
             if k == "GetPropertyChangedSignal" then
                return function(self, prop)
                    __log("METHOD", name .. ":GetPropertyChangedSignal(\"" .. tostring(prop) .. "\")")
                    return __createMock("Signal")
                end
            end
            
            return __createMock("Signal", {
                Connect = function(self, callback)
                    __log("EVENT CONNECT", name .. "." .. k)
                    if type(callback) == "function" then
                        -- pcall(callback) 
                    end
                    return __createMock("Connection", {
                        Disconnect = function() __log("EVENT DISCONNECT", name .. "." .. k) end
                    })
                end,
                Wait = function(self)
                    __log("EVENT WAIT", name .. "." .. k)
                    return __createMock("Instance")
                end
            })
        end,
        
        __newindex = function(t, k, v)
            __log("SET PROPERTY", name .. "." .. k .. " = " .. tostring(v))
            mock.__props[k] = v
        end,
        
        __tostring = function(t)
            return mock.__props.Name or name
        end
    }
    return setmetatable(mock, mt)
end

-- SETUP STRING METATABLE
if debug and debug.setmetatable then
    pcall(function()
        debug.setmetatable("", {__index = string})
    end)
end

-- SHADOW GLOBALS
local print = function(...)
    local args = {...}
    local s = {}
    for i, v in ipairs(args) do s[i] = tostring(v) end
    __log("PRINT", table.concat(s, " "))
end

local warn = function(...)
    local args = {...}
    local s = {}
    for i, v in ipairs(args) do s[i] = tostring(v) end
    __log("WARN", table.concat(s, " "))
end

local Instance = {
    new = function(className, parent)
        __log("INSTANCE.NEW", className)
        local obj = __createMock(className)
        if parent then
            obj.Parent = parent
            __log("SET PROPERTY", className .. ".Parent = " .. tostring(parent))
        end
        return obj
    end
}

local Vector3 = {
    new = function(x, y, z) return __createMock("Vector3", {X=x or 0, Y=y or 0, Z=z or 0, __tostring=function(t) return string.format("%s, %s, %s", t.X, t.Y, t.Z) end}) end,
    zero = __createMock("Vector3", {X=0, Y=0, Z=0}),
}
local Vector2 = {
    new = function(x, y) return __createMock("Vector2", {X=x or 0, Y=y or 0, __tostring=function(t) return string.format("%s, %s", t.X, t.Y) end}) end
}
local UDim2 = {
    new = function(xs, xo, ys, yo) return __createMock("UDim2", {X={Scale=xs or 0,Offset=xo or 0}, Y={Scale=ys or 0,Offset=yo or 0}}) end
}
local UDim = {
    new = function(s, o) return __createMock("UDim", {Scale=s or 0, Offset=o or 0}) end
}
local Color3 = {
    fromRGB = function(r, g, b) 
        __log("COLOR3.FROMRGB", string.format("(%d, %d, %d)", r or 0, g or 0, b or 0))
        return __createMock("Color3", {R=(r or 0)/255, G=(g or 0)/255, B=(b or 0)/255}) 
    end,
    fromHSV = function(h, s, v) return __createMock("Color3", {H=h, S=s, V=v}) end,
    new = function(r, g, b) return __createMock("Color3", {R=r, G=g, B=b}) end
}
local BrickColor = {
    new = function(val) return __createMock("BrickColor", {Name=tostring(val)}) end
}
local CFrame = {
    new = function(...) return __createMock("CFrame", {}) end
}
local TweenInfo = {
    new = function(...) return __createMock("TweenInfo", {}) end
}
local NumberRange = {
    new = function(...) return __createMock("NumberRange", {}) end
}
local NumberSequence = {
    new = function(...) return __createMock("NumberSequence", {}) end
}
local NumberSequenceKeypoint = {
    new = function(...) return __createMock("NumberSequenceKeypoint", {}) end
}
local ColorSequence = {
    new = function(...) return __createMock("ColorSequence", {}) end
}
local ColorSequenceKeypoint = {
    new = function(...) return __createMock("ColorSequenceKeypoint", {}) end
}

local Enum = setmetatable({}, {
    __index = function(t, k)
        return setmetatable({}, {
            __index = function(t2, v)
                return __createMock("EnumItem", {Name=v, EnumType=k})
            end
        })
    end
})

local task = {
    wait = function(t) __log("TASK.WAIT", t); return t or 0 end,
    spawn = function(f, ...) __log("TASK.SPAWN", "Function"); f(...) end,
    delay = function(t, f, ...) __log("TASK.DELAY", t); f(...) end,
    defer = function(f, ...) __log("TASK.DEFER", "Function"); f(...) end
}
local wait = task.wait
local spawn = task.spawn
local delay = task.delay

local _services = {}
local game = __createMock("DataModel")
game.GetService = function(self, name)
    __log("GET SERVICE", name)
    if not _services[name] then
        _services[name] = __createMock(name)
        
        if name == "TweenService" then
            _services[name].Create = function(self, obj, info, props)
                __log("TWEEN CREATE", tostring(obj))
                return __createMock("Tween", {
                    Play = function() __log("TWEEN PLAY", tostring(obj)) end,
                    Cancel = function() end
                })
            end
        elseif name == "UserInputService" then
            _services[name].GetMouseLocation = function() return Vector2.new(0, 0) end
        elseif name == "Players" then
            _services[name].LocalPlayer = __createMock("Player", {
                Name = "LocalPlayer",
                UserId = 123456,
                Character = __createMock("Model", {Name="Character"}),
                CharacterAdded = __createMock("Signal", {
                    Connect = function(self, cb)
                        __log("CONNECT", "CharacterAdded")
                        if type(cb) == "function" then cb(_services[name].LocalPlayer.Character) end
                        return __createMock("Connection")
                    end,
                    Wait = function() return _services[name].LocalPlayer.Character end
                })
            })
        end
    end
    return _services[name]
end

local workspace = __createMock("Workspace")
local script = __createMock("Script")

local HttpGet = function(url) __log("HTTP GET", url); return "" end
local writefile = function(f, c) __log("WRITEFILE", f); end
local readfile = function(f) __log("READFILE", f); return "" end
local loadstring = function(c) __log("LOADSTRING", #c); return function() end end

-- End Preamble
]]

local fullSource = preamble .. "\n" .. scriptContent

print("▶️  Compiling...")
local chunk, err = loadstring(fullSource, "@monitored_script")
if not chunk then
    print("❌ Compilation error:", err)
    process.exit(1)
end

print("▶️  Running...")
local ok, result = xpcall(function() return chunk("dummy", "args") end, debug.traceback)

if not ok then
    print("❌ Runtime error:", result)
else
    print("✅ Main chunk finished")
    if type(result) == "function" then
        print("▶️  Executing returned function...")
        local ok2, err2 = xpcall(function() return result("dummy", "args") end, debug.traceback)
        if not ok2 then
            print("❌ Runtime error in returned function:", err2)
        else
            print("✅ Returned function finished")
        end
    end
end
