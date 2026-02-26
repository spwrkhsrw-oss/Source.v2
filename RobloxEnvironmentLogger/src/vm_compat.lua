-- VM Compatibility Layer - Lets Prometheus VM run and catches actual calls
local process = require("@lune/process")
local fs = require("@lune/fs")

local scriptPath = process.args[1]
if not scriptPath then
    print("Usage: lune run vm_compat.lua <script_path>")
    process.exit(1)
end

local scriptContent = fs.readFile(scriptPath)

-- Build environment with FULL compatibility
local env = {}

-- Copy EVERYTHING from current environment
for k, v in pairs(getfenv()) do
    env[k] = v
end

-- Ensure VM-critical functions exist
env._G = env
env._VERSION = "Lua 5.1"

-- INSTRUMENTED PRINT - catches VM output
local origPrint = print
env.print = function(...)
    origPrint("\n" .. string.rep("=", 60))
    origPrint("🎯 VM EXECUTED CODE!")
    origPrint(string.rep("=", 60))
    origPrint("OUTPUT:", ...)
    origPrint(string.rep("=", 60))
    origPrint()
end

-- Log exploit functions
env.HttpGet = function(url)
    origPrint("🌐 HTTP GET:", url)
    return ""
end

env.writefile = function(name, content)
    origPrint("📝 WRITE FILE:", name)
end

env.loadstring = function(code)
    origPrint("⚡ LOADSTRING -", string.sub(tostring(code), 1, 50))
    return function() end
end

-- Mock Roblox
env.game = setmetatable({}, {__index = function() return env.game end})
env.workspace = env.game
env.script = env.game

-- Run it
local chunk = assert(loadstring(scriptContent, "@script"))
setfenv(chunk, env)

local ok, err = pcall(chunk)
if not ok then
    origPrint("\n❌ Error:", err)
end

origPrint("\n✅ Done")
