-- VM Injector - Intercepts VM-executed code by injecting monitoring BEFORE VM loads
local process = require("@lune/process")
local fs = require("@lune/fs")

local scriptPath = process.args[1]
if not scriptPath then
    print("Usage: lune run vm_inject.lua <script_path>")
    process.exit(1)
end

local scriptContent = fs.readFile(scriptPath)

-- Preamble injected BEFORE the obfuscated code runs
local preamble = [[
-- === INJECTED VM MONITOR ===
local __P = print

print = function(...)
    local args = {...}
    local strs = {}
    for _, v in ipairs(args) do strs[#strs+1] = tostring(v) end
    
    __P("\n" .. string.rep("=", 70))
    __P("🎯 ORIGINAL CODE EXECUTED BY VM!")
    __P(string.rep("=", 70))
    __P("CODE: print(" .. table.concat(strs, ", ") .. ")")
    __P(string.rep("=", 70))
end

HttpGet = HttpGet or function(url)
    __P("🌐 HTTP GET:", url)
    return ""
end

game = game or setmetatable({}, {
    __index = function(t, k)
        if k == "HttpGet" then
            return function(url)
                __P("🌐 game:HttpGet:", url)
                return ""
            end
        end
        return setmetatable({}, {__index = function() return function() end end})
    end
})

writefile = writefile or function(n, c)
    __P("📝 WRITE:", n, "(" .. #tostring(c) .. " bytes)")
end

readfile = readfile or function(n)
    __P("📖 READ:", n)
    return ""
end

loadstring = loadstring or function(code)
    __P("⚡ LOADSTRING:", string.sub(tostring(code), 1, 80) .. "...")
    return function() end
end

setclipboard = setclipboard or function(t)
    __P("📋 CLIPBOARD:", string.sub(tostring(t), 1, 50))
end

workspace = workspace or game
script = script or {}
-- === END INJECTION ===

]]

-- Inject + original script
local monitored = preamble .. scriptContent

-- Run it
local chunk = assert(loadstring(monitored, "@script"))
local ok, err = pcall(chunk)

if not ok then
    print("\n❌ Runtime error:", err)
end

print("\n✅ Execution complete")
