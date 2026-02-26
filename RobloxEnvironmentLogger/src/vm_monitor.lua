-- VM INTERCEPTOR SIMPLE ENHANCED
-- Based on vm_enhanced.lua but with property logging and task support
local process = require("@lune/process")
local fs = require("@lune/fs")

local scriptPath = process.args[1]
if not scriptPath then
    print("Usage: lune run vm_simple_enhanced.lua <script_path>")
    process.exit(1)
end

local scriptContent = fs.readFile(scriptPath)

local preamble = [[
-- === VM MONITOR PREAMBLE ===
local __original_print = print
local __logs = {}
local __opCount = 0
local __startTime = os.clock()

local function log(category, detail)
    __opCount = __opCount + 1
    local time = string.format("%.3f", os.clock() - __startTime)
    local entry = string.format("[%04d] [%s] %s: %s", __opCount, time, category, tostring(detail))
    __original_print("  " .. entry)
end

-- Override print
print = function(...)
    local args = {...}
    local s = {}
    for i, v in ipairs(args) do s[i] = tostring(v) end
    log("PRINT", table.concat(s, " "))
end

warn = function(...)
    local args = {...}
    local s = {}
    for i, v in ipairs(args) do s[i] = tostring(v) end
    log("WARN", table.concat(s, " "))
end

-- Instance Mock
local function createInstanceMock(className, parent)
    local props = {Name = className, ClassName = className, Parent = parent}
    local proxy = {}
    
    local mt = {
        __index = function(t, k)
            if props[k] ~= nil then return props[k] end
            
            if k == "Destroy" or k == "Clone" or k == "ClearAllChildren" then
                return function() log("METHOD", className .. ":" .. k .. "()") end
            end
            
            if k == "WaitForChild" or k == "FindFirstChild" then
                return function(self, childName)
                    log("METHOD", className .. ":" .. k .. "(\"" .. tostring(childName) .. "\")")
                    return createInstanceMock(childName or "Instance")
                end
            end
            
            if k == "GetChildren" then
                return function()
                    log("METHOD", className .. ":GetChildren()")
                    return {}
                end
            end
            
            if k == "GetPropertyChangedSignal" then
                return function(self, prop)
                    log("METHOD", className .. ":GetPropertyChangedSignal(\"" .. tostring(prop) .. "\")")
                     return {
                        Connect = function(self, cb)
                            log("EVENT CONNECT", className .. ".Signal(" .. tostring(prop) .. ")")
                            return {Disconnect = function() log("EVENT DISCONNECT", className .. ".Signal") end}
                        end,
                        Wait = function()
                            log("EVENT WAIT", className .. ".Signal")
                        end
                     }
                end
            end

            -- Events (properties that are signals)
            if k == "Connect" or k == "Changed" or string.sub(k, 1, 1) == string.upper(string.sub(k, 1, 1)) then
                 -- Assume event property (e.g. MouseButton1Click)
                 return {
                    Connect = function(self, cb)
                        log("EVENT CONNECT", className .. "." .. k)
                        return {Disconnect = function() log("EVENT DISCONNECT", className .. "." .. k) end}
                    end,
                    Wait = function()
                        log("EVENT WAIT", className .. "." .. k)
                        return createInstanceMock("Instance")
                    end
                 }
            end
            
            return function() end
        end,
        
        __newindex = function(t, k, v)
            log("SET PROPERTY", className .. "." .. k .. " = " .. tostring(v))
            props[k] = v
        end,
        
        __tostring = function() return props.Name end
    }
    return setmetatable(proxy, mt)
end

Instance = {
    new = function(className, parent)
        log("INSTANCE.NEW", className)
        local obj = createInstanceMock(className, parent)
        if parent then
            log("SET PROPERTY", className .. ".Parent = " .. tostring(parent))
        end
        return obj
    end
}

-- Vector3 etc
Vector3 = {
    new = function(x, y, z) return setmetatable({X=x or 0, Y=y or 0, Z=z or 0}, {__tostring=function(t) return string.format("%s, %s, %s", t.X, t.Y, t.Z) end}) end,
    zero = setmetatable({X=0, Y=0, Z=0}, {__tostring=function() return "0, 0, 0" end}),
}
Vector2 = {
    new = function(x, y) return setmetatable({X=x or 0, Y=y or 0}, {__tostring=function(t) return string.format("%s, %s", t.X, t.Y) end}) end
}
UDim2 = {
    new = function(xs, xo, ys, yo) return setmetatable({X={Scale=xs or 0,Offset=xo or 0}, Y={Scale=ys or 0,Offset=yo or 0}}, {__tostring=function() return "UDim2" end}) end
}
UDim = {
    new = function(s, o) return setmetatable({Scale=s or 0, Offset=o or 0}, {__tostring=function() return "UDim" end}) end
}
Color3 = {
    fromRGB = function(r, g, b) 
        log("COLOR3.FROMRGB", string.format("(%d, %d, %d)", r or 0, g or 0, b or 0))
        return setmetatable({R=(r or 0)/255, G=(g or 0)/255, B=(b or 0)/255}, {__tostring=function() return "Color3" end}) 
    end,
    fromHSV = function(h, s, v) return setmetatable({H=h, S=s, V=v}, {__tostring=function() return "Color3" end}) end,
    new = function(r, g, b) return setmetatable({R=r, G=g, B=b}, {__tostring=function() return "Color3" end}) end
}
BrickColor = {
    new = function(val) return setmetatable({Name=tostring(val)}, {__tostring=function(t) return t.Name end}) end
}
CFrame = {
    new = function(...) return setmetatable({}, {__tostring=function() return "CFrame" end}) end
}
TweenInfo = {
    new = function(...) return setmetatable({}, {__tostring=function() return "TweenInfo" end}) end
}
NumberRange = {
    new = function(...) return setmetatable({}, {__tostring=function() return "NumberRange" end}) end
}
NumberSequence = {
    new = function(...) return setmetatable({}, {__tostring=function() return "NumberSequence" end}) end
}
NumberSequenceKeypoint = {
    new = function(...) return setmetatable({}, {__tostring=function() return "NumberSequenceKeypoint" end}) end
}
ColorSequence = {
    new = function(...) return setmetatable({}, {__tostring=function() return "ColorSequence" end}) end
}
ColorSequenceKeypoint = {
    new = function(...) return setmetatable({}, {__tostring=function() return "ColorSequenceKeypoint" end}) end
}

Enum = setmetatable({}, {
    __index = function(t, k)
        return setmetatable({}, {
            __index = function(t2, v)
                return setmetatable({Name=v, EnumType=k}, {__tostring=function(t) return "Enum."..k.."."..v end})
            end
        })
    end
})

task = {
    wait = function(t) log("TASK.WAIT", t); return t or 0 end,
    spawn = function(f, ...) log("TASK.SPAWN", "Function"); f(...) end,
    delay = function(t, f, ...) log("TASK.DELAY", t); f(...) end,
    defer = function(f, ...) log("TASK.DEFER", "Function"); f(...) end
}
wait = task.wait
spawn = task.spawn
delay = task.delay

-- Game
local services = {}
game = createInstanceMock("DataModel")
local original_GetService = game.GetService -- Wait, createInstanceMock returns proxy. It doesn't have GetService method yet.

-- We need to attach GetService to game proxy
local game_mt = getmetatable(game)
local old_index = game_mt.__index
game_mt.__index = function(t, k)
    if k == "GetService" then
        return function(self, name)
            log("GET SERVICE", name)
            if not services[name] then
                services[name] = createInstanceMock(name)
                -- Add specific service logic if needed
                if name == "Players" then
                     services[name].LocalPlayer = createInstanceMock("Player")
                     services[name].LocalPlayer.Name = "LocalPlayer"
                     services[name].LocalPlayer.Character = createInstanceMock("Model")
                     services[name].LocalPlayer.Character.Name = "Character"
                end
            end
            return services[name]
        end
    end
    return old_index(t, k)
end

workspace = createInstanceMock("Workspace")
script = createInstanceMock("Script")

HttpGet = function(url) log("HTTP GET", url); return "" end
writefile = function(f, c) log("WRITEFILE", f); end
readfile = function(f) log("READFILE", f); return "" end
loadstring = function(c) log("LOADSTRING", #c); return function() end end

-- Debug Mock
debug = {
    sethook = function(...) log("DEBUG", "sethook blocked") end,
    traceback = function() return "" end
}

if not bit32 then bit32 = require("@lune/bit32") end

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
local ok, result = pcall(chunk)

if not ok then
    print("❌ Runtime error:", result)
else
    print("✅ Execution finished")
end
