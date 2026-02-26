-- COMPREHENSIVE VM INTERCEPTOR - Captures ALL operations including object creation
local process = require("@lune/process")
local fs = require("@lune/fs")

local scriptPath = process.args[1]
if not scriptPath then
    print("Usage: lune run vm_enhanced.lua <script_path>")
    process.exit(1)
end

local scriptContent = fs.readFile(scriptPath)

-- Enhanced monitoring that captures EVERYTHING
local preamble = [[
-- === ENHANCED VM MONITOR ===
local __P = print
local __log = {}
local __opCount = 0

local function log(category, detail)
    __opCount = __opCount + 1
    local entry = "[" .. __opCount .. "] " .. category .. ": " .. tostring(detail)
    table.insert(__log, entry)
    __P("  " .. entry)
end

-- Track Instance creation
local __RealInstance = Instance
Instance = setmetatable({}, {
    __index = function(t, k)
        if k == "new" then
            return function(className, parent)
                log("INSTANCE.NEW", className .. (parent and (" (parent: " .. tostring(parent) .. ")") or ""))
                local obj = __RealInstance and __RealInstance.new(className) or setmetatable({
                    __className = className,
                })
                if parent then
                    obj.Parent = parent
                end
                return obj
            end
        end
        return __RealInstance and __RealInstance[k] or function() end
    end
})

-- Intercept print with full argument capture
print = function(...)
    local args = {...}
    local strs = {}
    for _, v in ipairs(args) do 
        strs[#strs+1] = tostring(v)
    end
    
    __P("\n" .. string.rep("=", 70))
    __P("🎯 VM EXECUTED: print")
    __P(string.rep("=", 70))
    log("PRINT", table.concat(strs, ", "))
    __P(string.rep("=", 70))
end

warn = function(...)
    local strs = {}
    for _, v in ipairs({...}) do strs[#strs+1] = tostring(v) end
    log("WARN", table.concat(strs, ", "))
end

-- Enhanced game with service tracking
game = setmetatable({}, {
    __index = function(t, k)
        if k == "GetService" then
            return function(self, serviceName)
                __P("\n" .. string.rep("=", 70))
                __P("🎮 ROBLOX SERVICE ACCESS")
                __P(string.rep("=", 70))
                log("GAME:GETSERVICE", serviceName)
                __P(string.rep("=", 70))
                
                -- Return service proxy
                return setmetatable({
                    __serviceName = serviceName
                }, {
                    __index = function(t, k)
                        log("SERVICE ACCESS", serviceName .. "." .. k)
                        if k == "LocalPlayer" then
                            return setmetatable({}, {
                                __index = function(t, k)
                                    log("PLAYER ACCESS", "LocalPlayer." .. k)
                                    if k == "WaitForChild" then
                                        return function(self, childName)
                                            log("WAITFORCHILD", childName)
                                            return setmetatable({}, {__index = function() return function() end end})
                                        end
                                    end
                                    return setmetatable({}, {__index = function() return function() end end})
                                end
                            })
                        end
                        return setmetatable({}, {__index = function() return function() end end})
                    end
                })
            end
        end
        
        log("GAME ACCESS", "game." .. tostring(k))
        return setmetatable({}, {__index = function() return function() end end})
    end
})

workspace = setmetatable({}, {
    __index = function(t, k)
        log("WORKSPACE ACCESS", "workspace." .. tostring(k))
        return setmetatable({}, {__index = function() return function() end end})
    end,
    __newindex = function(t, k, v)
        log("WORKSPACE SET", "workspace." .. tostring(k) .. " = " .. tostring(v))
    end
})

-- Vector3, UDim2, Color3, BrickColor, Enum - with logging
Vector3 = {
    new = function(x, y, z)
        log("VECTOR3.NEW", string.format("(%s, %s, %s)", tostring(x), tostring(y), tostring(z)))
        return setmetatable({X=x, Y=y, Z=z}, {
            __tostring = function(v) return string.format("Vector3.new(%s, %s, %s)", v.X, v.Y, v.Z) end
        })
    end
}

UDim2 = {
    new = function(xScale, xOffset, yScale, yOffset)
        log("UDIM2.NEW", string.format("(%s, %s, %s, %s)", tostring(xScale), tostring(xOffset), tostring(yScale), tostring(yOffset)))
        return setmetatable({}, {
            __tostring = function() return string.format("UDim2.new(%s, %s, %s, %s)", xScale, xOffset, yScale, yOffset) end
        })
    end
}

Color3 = {
    fromRGB = function(r, g, b)
        log("COLOR3.FROMRGB", string.format("(%d, %d, %d)", r, g, b))
        return setmetatable({R=r/255, G=g/255, B=b/255}, {
            __tostring = function() return string.format("Color3.fromRGB(%d, %d, %d)", r, g, b) end
        })
    end,
    new = function(r, g, b)
        log("COLOR3.NEW", string.format("(%s, %s, %s)", r, g, b))
        return {R=r, G=g, B=b}
    end
}

BrickColor = {
    new = function(name)
        log("BRICKCOLOR.NEW", name)
        return setmetatable({Name=name}, {
            __tostring = function() return "BrickColor.new(\"" .. name .. "\")" end
        })
    end
}

Enum = setmetatable({}, {
    __index = function(t, category)
        return setmetatable({}, {
            __index = function(t, value)
                log("ENUM ACCESS", "Enum." .. category .. "." .. value)
                return category .. "." .. value
            end
        })
    end
})

-- HTTP
HttpGet = function(url)
    __P("\n" .. string.rep("=", 70))
    __P("🌐 HTTP REQUEST")
    __P(string.rep("=", 70))
    log("HTTP GET", url)
    __P(string.rep("=", 70))
    return ""
end

-- File operations
writefile = function(name, content)
    __P("\n" .. string.rep("=", 70))
    __P("📝 FILE WRITE")
    __P(string.rep("=", 70))
    log("WRITE FILE", name .. " (" .. #tostring(content) .. " bytes)")
    log("CONTENT PREVIEW", string.sub(tostring(content), 1, 100))
    __P(string.rep("=", 70))
end

readfile = function(name)
    log("READ FILE", name)
    return ""
end

loadstring = function(code)
    __P("\n" .. string.rep("=", 70))
    __P("⚡ LOADSTRING")
    __P(string.rep("=", 70))
    log("LOADSTRING", string.sub(tostring(code), 1, 100))
    __P(string.rep("=", 70))
    return function() end
end

setclipboard = function(text)
    __P("\n" .. string.rep("=", 70))
    __P("📋 CLIPBOARD")
    __P(string.rep("=", 70))
    log("SET CLIPBOARD", string.sub(tostring(text), 1, 100))
    __P(string.rep("=", 70))
end

-- Task/Wait
wait = function(t)
    log("WAIT", tostring(t or 0) .. " seconds")
    return 0
end

task = {
    wait = function(t)
        log("TASK.WAIT", tostring(t or 0))
        return 0
    end,
    spawn = function(func)
        log("TASK.SPAWN", "function spawned")
    end,
    delay = function(t, func)
        log("TASK.DELAY", tostring(t))
    end
}

-- Other required globals
script = setmetatable({}, {__index = function() return "" end})
Players = game:GetService("Players")
ReplicatedStorage = game:GetService("ReplicatedStorage")
TweenService = game:GetService("TweenService")

-- Summary at end
local function printSummary()
    __P("\n" .. string.rep("=", 70))
    __P("📊 EXECUTION SUMMARY")
    __P(string.rep("=", 70))
    __P("Total operations logged: " .. __opCount)
    __P(string.rep("=", 70))
end

-- Hook to print summary (will run after script)
-- We'll call this manually below

-- === END VM MONITOR ===

]]

-- Inject + original + summary
local monitored = preamble .. scriptContent

-- Execute
local chunk, compErr = loadstring(monitored, "@monitored")
if not chunk then
    print("❌ Compilation error:", compErr)
    process.exit(1)
end

print("▶️  EXECUTING VM-OBFUSCATED SCRIPT WITH ENHANCED MONITORING...")
print("📊 Capturing ALL operations including object creation, properties, and method calls")
print()

local ok, runtimeErr = pcall(chunk)

if not ok then
    print("\n❌ Runtime error:", runtimeErr)
end

print("\n✅ Execution complete - check logs above for all captured operations")
