-- ULTIMATE VM INTERCEPTOR v4
-- Robust environment logging with proper sandboxing and execution handling
local process = require("@lune/process")
local fs = require("@lune/fs")
local stdio = require("@lune/stdio")

local scriptPath = process.args[1]
if not scriptPath then
    print("Usage: lune run vm_ultimate.lua <script_path>")
    process.exit(1)
end

local scriptContent = fs.readFile(scriptPath)

-- === MOCK ENVIRONMENT SETUP ===
local env = {}
local logs = {}
local opCount = 0
local startTime = os.clock()

local function log(category, detail)
    opCount = opCount + 1
    local time = string.format("%.3f", os.clock() - startTime)
    local entry = string.format("[%04d] [%s] %s: %s", opCount, time, category, tostring(detail))
    table.insert(logs, entry)
    print("  " .. entry)
end

-- Helper to create mock objects
local function createMock(name, props)
    local mock = props or {}
    mock.__type = name
    mock.__props = {}
    
    local mt = {
        __index = function(t, k)
            -- Check explicit properties first
            if mock[k] ~= nil then return mock[k] end
            if mock.__props[k] ~= nil then return mock.__props[k] end
            
            -- Special properties
            if k == "Name" then return mock.__props.Name or name end
            if k == "Parent" then return mock.__props.Parent end
            if k == "ClassName" then return name end
            
            -- Methods
            if k == "Destroy" or k == "Clone" or k == "ClearAllChildren" then
                return function(self) log("METHOD", name .. ":" .. k .. "()") end
            end
            if k == "WaitForChild" or k == "FindFirstChild" then
                return function(self, childName)
                    log("METHOD", name .. ":" .. k .. "(\"" .. tostring(childName) .. "\")")
                    return createMock(childName)
                end
            end
            if k == "GetChildren" then
                return function(self)
                    log("METHOD", name .. ":GetChildren()")
                    return {}
                end
            end
            if k == "GetPropertyChangedSignal" then
                return function(self, prop)
                    log("METHOD", name .. ":GetPropertyChangedSignal(\"" .. tostring(prop) .. "\")")
                    return createMock("Signal")
                end
            end
            
            -- Events (return a Signal-like object)
            return createMock("Signal", {
                Connect = function(self, callback)
                    log("EVENT CONNECT", name .. "." .. k)
                    if type(callback) == "function" then
                        -- pcall(callback) -- Risky
                    end
                    return createMock("Connection", {
                        Disconnect = function() log("EVENT DISCONNECT", name .. "." .. k) end
                    })
                end,
                Wait = function(self)
                    log("EVENT WAIT", name .. "." .. k)
                    return createMock("Instance")
                end
            })
        end,
        
        __newindex = function(t, k, v)
            log("SET PROPERTY", name .. "." .. k .. " = " .. tostring(v))
            mock.__props[k] = v
        end,
        
        __tostring = function(t)
            return mock.__props.Name or name
        end,
        
        __metatable = "The metatable is locked"
    }
    return setmetatable(mock, mt)
end

-- Populate Environment
env._G = env
env.shared = {}
env._VERSION = "Lua 5.1"

-- Standard Globals
env.print = function(...)
    local args = {...}
    local s = {}
    for i, v in ipairs(args) do s[i] = tostring(v) end
    log("PRINT", table.concat(s, " "))
end
env.warn = function(...)
    local args = {...}
    local s = {}
    for i, v in ipairs(args) do s[i] = tostring(v) end
    log("WARN", table.concat(s, " "))
end
env.error = function(msg) log("ERROR", msg); error(msg) end
env.assert = assert
env.pcall = function(f, ...)
    log("PCALL", "Executing function safely")
    local res = {pcall(f, ...)}
    if not res[1] then
        log("PCALL ERROR", tostring(res[2]))
    end
    return table.unpack(res)
end
env.xpcall = xpcall
env.select = select
env.tonumber = tonumber
env.tostring = tostring
env.type = function(v)
    if type(v) == "table" and v.__type then return "userdata" end
    return type(v)
end
env.typeof = function(v)
    if type(v) == "table" and v.__type then return v.__type == "Proxy" and "Instance" or v.__type end
    return type(v)
end
env.unpack = unpack
env.next = next
env.pairs = pairs
env.ipairs = ipairs
env.getmetatable = getmetatable
env.setmetatable = setmetatable
env.rawequal = rawequal
env.rawget = rawget
env.rawset = rawset
env.newproxy = function(u) return createMock("Proxy") end

-- Libraries
env.math = math
env.table = table
env.string = string
env.coroutine = coroutine
env.os = os
env.debug = debug 
env.bit32 = bit32 -- Global bit32 in Luau
env.utf8 = utf8

-- Environment Manipulation
env.getfenv = function(f) return env end
env.setfenv = function(f, t) 
    log("SETFENV", "Attempt to change environment ignored")
    return f 
end
env.getgenv = function() return env end
env.getrenv = function() return env end

-- Roblox Globals
env.Instance = {
    new = function(className, parent)
        log("INSTANCE.NEW", className)
        local obj = createMock(className)
        if parent then
            obj.Parent = parent
            log("SET PROPERTY", className .. ".Parent = " .. tostring(parent))
        end
        return obj
    end
}

env.Vector3 = {
    new = function(x, y, z) return createMock("Vector3", {X=x or 0, Y=y or 0, Z=z or 0, __tostring=function(t) return string.format("%s, %s, %s", t.X, t.Y, t.Z) end}) end,
    zero = createMock("Vector3", {X=0, Y=0, Z=0}),
}
env.Vector2 = {
    new = function(x, y) return createMock("Vector2", {X=x or 0, Y=y or 0, __tostring=function(t) return string.format("%s, %s", t.X, t.Y) end}) end
}
env.UDim2 = {
    new = function(xs, xo, ys, yo) return createMock("UDim2", {X={Scale=xs or 0,Offset=xo or 0}, Y={Scale=ys or 0,Offset=yo or 0}}) end
}
env.UDim = {
    new = function(s, o) return createMock("UDim", {Scale=s or 0, Offset=o or 0}) end
}
env.Color3 = {
    fromRGB = function(r, g, b) 
        log("COLOR3.FROMRGB", string.format("(%d, %d, %d)", r or 0, g or 0, b or 0))
        return createMock("Color3", {R=(r or 0)/255, G=(g or 0)/255, B=(b or 0)/255}) 
    end,
    fromHSV = function(h, s, v) return createMock("Color3", {H=h, S=s, V=v}) end,
    new = function(r, g, b) return createMock("Color3", {R=r, G=g, B=b}) end
}
env.BrickColor = {
    new = function(val) return createMock("BrickColor", {Name=tostring(val)}) end
}
env.CFrame = {
    new = function(...) return createMock("CFrame", {}) end
}
env.TweenInfo = {
    new = function(...) return createMock("TweenInfo", {}) end
}
env.NumberRange = {
    new = function(...) return createMock("NumberRange", {}) end
}
env.NumberSequence = {
    new = function(...) return createMock("NumberSequence", {}) end
}
env.NumberSequenceKeypoint = {
    new = function(...) return createMock("NumberSequenceKeypoint", {}) end
}
env.ColorSequence = {
    new = function(...) return createMock("ColorSequence", {}) end
}
env.ColorSequenceKeypoint = {
    new = function(...) return createMock("ColorSequenceKeypoint", {}) end
}

-- Enum
env.Enum = setmetatable({}, {
    __index = function(t, k)
        return setmetatable({}, {
            __index = function(t2, v)
                return createMock("EnumItem", {Name=v, EnumType=k})
            end
        })
    end
})

-- Task
env.task = {
    wait = function(t) log("TASK.WAIT", t); return t or 0 end,
    spawn = function(f, ...) log("TASK.SPAWN", "Function"); f(...) end,
    delay = function(t, f, ...) log("TASK.DELAY", t); f(...) end,
    defer = function(f, ...) log("TASK.DEFER", "Function"); f(...) end
}
env.wait = env.task.wait
env.spawn = env.task.spawn
env.delay = env.task.delay

-- Game & Services
local services = {}
env.game = createMock("DataModel")
env.game.GetService = function(self, name)
    log("GET SERVICE", name)
    if not services[name] then
        services[name] = createMock(name)
        
        if name == "TweenService" then
            services[name].Create = function(self, obj, info, props)
                log("TWEEN CREATE", tostring(obj))
                return createMock("Tween", {
                    Play = function() log("TWEEN PLAY", tostring(obj)) end,
                    Cancel = function() end
                })
            end
        elseif name == "UserInputService" then
            services[name].GetMouseLocation = function() return env.Vector2.new(0, 0) end
        elseif name == "Players" then
            services[name].LocalPlayer = createMock("Player", {
                Name = "LocalPlayer",
                UserId = 123456,
                Character = createMock("Model", {Name="Character"}),
                CharacterAdded = createMock("Signal", {
                    Connect = function(self, cb)
                        log("CONNECT", "CharacterAdded")
                        if type(cb) == "function" then cb(services[name].LocalPlayer.Character) end
                        return createMock("Connection")
                    end,
                    Wait = function() return services[name].LocalPlayer.Character end
                })
            })
        end
    end
    return services[name]
end
env.workspace = createMock("Workspace")
env.script = createMock("Script")

-- Extra
env.HttpGet = function(url) log("HTTP GET", url); return "" end
env.writefile = function(f, c) log("WRITEFILE", f); end
env.readfile = function(f) log("READFILE", f); return "" end
env.loadstring = function(c) log("LOADSTRING", #c); return function() end end
env.tick = os.clock

-- Setup String Metatable (Crucial for obfuscators)
-- Lune strings already have methods, but we ensure it for safety
if debug and debug.setmetatable then
    pcall(function()
        debug.setmetatable("", {__index = string})
    end)
end

-- Execution
print("▶️  Initializing Ultimate VM Interceptor...")
local chunk, err = loadstring(scriptContent, "@target_script")
if not chunk then
    print("❌ Compilation error:", err)
    process.exit(1)
end

setfenv(chunk, env)

print("▶️  Running script...")
local ok, result = xpcall(chunk, debug.traceback)

if not ok then
    print("❌ Runtime error:", result)
else
    print("✅ Main chunk finished")
    -- Check if it returned a function (common in obfuscators)
    if type(result) == "function" then
        print("▶️  Executing returned function...")
        setfenv(result, env) -- Ensure it uses our env
        local ok2, err2 = xpcall(result, debug.traceback)
        if not ok2 then
            print("❌ Runtime error in returned function:", err2)
        else
            print("✅ Returned function finished")
        end
    end
end

print("\n📊 Total operations logged:", opCount)
