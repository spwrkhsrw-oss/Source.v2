-- VM COMPLETE INTERCEPTOR - Captures ALL operations from VM-executed code
local process = require("@lune/process")
local fs = require("@lune/fs")

local scriptPath = process.args[1]
if not scriptPath then
    print("Usage: lune run vm_complete.lua <script_path>")
    process.exit(1)
end

local scriptContent = fs.readFile(scriptPath)

-- Comprehensive preamble that logs EVERYTHING
local preamble = [[
-- === COMPREHENSIVE VM MONITOR ===
local __P = print
local __log = {}
local __varCount = 0

local function log(op, detail)
    table.insert(__log, {op=op, detail=detail})
    __P("  " .. op .. ": " .. tostring(detail))
end

-- Intercept print
print = function(...)
    local args = {...}
    local strs = {}
    for _, v in ipairs(args) do strs[#strs+1] = tostring(v) end
    
    __P("\n" .. string.rep("=", 70))
    __P("🎯 VM EXECUTED: print")
    __P(string.rep("=", 70))
    log("CALL", "print(" .. table.concat(strs, ", ") .. ")")
    __P(string.rep("=", 70))
end

warn = function(...)
    log("CALL", "warn(" .. table.concat({...}, ", ") .. ")")
end

-- HTTP operations
HttpGet = function(url)
    __P("\n" .. string.rep("=", 70))
    __P("🌐 VM EXECUTED: HTTP Request")
    __P(string.rep("=", 70))
    log("HTTP GET", url)
    __P(string.rep("=", 70))
    return ""
end

HttpPost = function(url, data)
    log("HTTP POST", url .. " | data: " .. string.sub(tostring(data), 1, 50))
    return ""
end

-- File operations
writefile = function(name, content)
    __P("\n" .. string.rep("=", 70))
    __P("📝 VM EXECUTED: File Write")
    __P(string.rep("=", 70))
    log("WRITE FILE", name .. " (" .. #tostring(content) .. " bytes)")
    log("CONTENT PREVIEW", string.sub(tostring(content), 1, 200))
    __P(string.rep("=", 70))
end

readfile = function(name)
    log("READ FILE", name)
    return ""
end

isfile = function(name)
    log("CHECK FILE", name)
    return false
end

isfolder = function(name)
    log("CHECK FOLDER", name)
    return false
end

makefolder = function(name)
    log("MAKE FOLDER", name)
end

listfiles = function(path)
    log("LIST FILES", path)
    return {}
end

delfile = function(name)
    log("DELETE FILE", name)
end

appendfile = function(name, content)
    log("APPEND FILE", name)
end

-- Loadstring
loadstring = function(code)
    local preview = string.sub(tostring(code), 1, 150)
    __P("\n" .. string.rep("=", 70))
    __P("⚡ VM EXECUTED: loadstring")
    __P(string.rep("=", 70))
    log("LOADSTRING", preview .. "...")
    __P(string.rep("=", 70))
    return function() 
        log("LOADSTRING EXEC", "Attempted execution (blocked)")
    end
end

-- Clipboard
setclipboard = function(text)
    __P("\n" .. string.rep("=", 70))
    __P("📋 VM EXECUTED: Clipboard")
    __P(string.rep("=", 70))
    log("SET CLIPBOARD", string.sub(tostring(text), 1, 100))
    __P(string.rep("=", 70))
end

getclipboard = function()
    log("GET CLIPBOARD", "")
    return ""
end

-- Game/Roblox API
game = setmetatable({}, {
    __index = function(t, k)
        log("GAME ACCESS", "game." .. tostring(k))
        
        if k == "HttpGet" or k == "HttpGetAsync" then
            return function(self, url)
                __P("\n" .. string.rep("=", 70))
                __P("🌐 VM EXECUTED: game:HttpGet")
                __P(string.rep("=", 70))
                log("HTTP GET (game)", url)
                __P(string.rep("=", 70))
                return ""
            end
        elseif k == "HttpPost" or k == "HttpPostAsync" then
            return function(self, url, data)
                log("HTTP POST (game)", url)
                return ""
            end
        end
        
        -- Return proxy for chaining
        return setmetatable({}, {
            __index = function(t2, k2)
                log("CHAIN ACCESS", "game." .. k .. "." .. tostring(k2))
                return function() end
            end
        })
    end
})

workspace = setmetatable({}, {
    __index = function(t, k)
        log("WORKSPACE ACCESS", "workspace." .. tostring(k))
        return setmetatable({}, {__index = function() return function() end end})
    end
})

script = setmetatable({}, {
    __index = function(t, k)
        log("SCRIPT ACCESS", "script." .. tostring(k))
        return ""
    end
})

-- Exploit functions
syn = {
    request = function(options)
        local url = type(options) == "table" and options.Url or tostring(options)
        log("SYN REQUEST", url)
        return {Success = false, StatusCode = 403}
    end
}

request = function(options)
    local url = type(options) == "table" and options.Url or tostring(options)
    log("REQUEST", url)
    return {Success = false, StatusCode = 403}
end

-- Drawing
Drawing = {
    new = function(drawingType)
        log("DRAWING NEW", drawingType)
        return setmetatable({}, {
            __index = function(t, k)
                return function() end
            end,
            __newindex = function(t, k, v)
                log("DRAWING SET", k .. " = " .. tostring(v))
            end
        })
    end
}

-- Hooking
hookfunction = function(orig, hook)
    log("HOOK FUNCTION", "Attempted function hook")
    return orig
end

hookmetamethod = function(obj, method, hook)
    log("HOOK METAMETHOD", method)
    return function() end
end

getrawmetatable = function(obj)
    log("GET METATABLE", tostring(obj))
    return {}
end

setrawmetatable = function(obj, mt)
    log("SET METATABLE", tostring(obj))
end

-- Executor info
identifyexecutor = function()
    log("IDENTIFY EXECUTOR", "")
    return "VMMonitor", "1.0"
end

getexecutorname = function()
    log("GET EXECUTOR NAME", "")
    return "VMMonitor"
end

-- Console
rconsoleprint = function(text)
    log("CONSOLE PRINT", text)
end

rconsoleclear = function()
    log("CONSOLE CLEAR", "")
end

-- Wait/Task
wait = function(t)
    log("WAIT", t or 0)
    return 0
end

task = {
    wait = function(t)
        log("TASK WAIT", t or 0)
        return 0
    end,
    spawn = function(func)
        log("TASK SPAWN", "function")
        return
    end,
    delay = function(t, func)
        log("TASK DELAY", t)
    end
}

-- === END VM MONITOR ===

]]

-- Inject monitoring + original script
local monitored = preamble .. scriptContent

-- Execute
local chunk, compErr = loadstring(monitored, "@monitored")
if not chunk then
    print("❌ Compilation error:", compErr)
    process.exit(1)
end

print("▶️  EXECUTING VM-OBFUSCATED SCRIPT...")
print("📊 All operations will be logged below:")
print()

local ok, runtimeErr = pcall(chunk)

if not ok then
    print("\n❌ Runtime error:", runtimeErr)
end

print("\n✅ Execution complete")
print("\n📋 Check the logs above to see all VM-executed operations")
