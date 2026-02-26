local process = require("@lune/process")

-- Get script path from arguments
local scriptPath = process.args[1]
if not scriptPath then
    print("Usage: lune run sandbox.lua <script_path>")
    process.exit(1)
end

-- Read ONLY from the provided script path
local scriptContent
do
    local fs = require("@lune/fs")
    if fs.isFile(scriptPath) then
        scriptContent = fs.readFile(scriptPath)
    else
        print("Error: Script file not found: " .. scriptPath)
        process.exit(1)
    end
end

-- === COMPLETELY ISOLATED SANDBOX ===
-- NO file system, NO network, NO process access
-- ONLY logging and Roblox API simulation

-- Execution trace - records EVERY operation
local executionTrace = {}
local varCounter = 0
local varRegistry = {}

-- Create a new tracked variable
local function createVar(value, description)
    varCounter = varCounter + 1
    local varName = "v" .. varCounter
    varRegistry[varName] = {
        value = value,
        description = description,
        type = type(value)
    }
    return varName
end

-- Log an operation (SAFE - no file paths, no sensitive data)
local function logOp(code, description)
    -- Sanitize any potential system paths or sensitive info
    local sanitizedCode = tostring(code):gsub("\\", "/"):gsub("C:/.-/", "")
    local sanitizedDesc = tostring(description):gsub("\\", "/"):gsub("C:/.-/", "")
    
    table.insert(executionTrace, {
        code = sanitizedCode,
        description = "-- " .. sanitizedDesc
    })
end

-- Proxy object that logs all interactions
local function createProxy(varName, path, isCallable)
    local proxy = {}
    local proxyMeta = {}
    
    proxyMeta.__index = function(t, key)
        local accessPath = path .. "." .. tostring(key)
        local newVar = createVar(nil, accessPath)
        logOp(newVar .. " = " .. varName .. "." .. tostring(key), "Access property: " .. accessPath)
        return createProxy(newVar, accessPath, true)
    end
    
    proxyMeta.__newindex = function(t, key, value)
        local valueStr
        if type(value) == "string" then
            valueStr = '"' .. tostring(value) .. '"'
        elseif type(value) == "number" or type(value) == "boolean" then
            valueStr = tostring(value)
        elseif type(value) == "table" and getmetatable(value) then
            valueStr = tostring(value)
        else
            local valueVar = createVar(value, "value")
            valueStr = valueVar
        end
        
        logOp(varName .. "." .. tostring(key) .. " = " .. valueStr, 
              "Set " .. path .. "." .. tostring(key) .. " = " .. valueStr)
    end
    
    proxyMeta.__call = function(t, ...)
        local args = {...}
        local argStrs = {}
        
        for i, arg in ipairs(args) do
            if type(arg) == "string" then
                -- Sanitize strings to prevent path leakage
                local sanitized = tostring(arg):gsub("\\", "/"):gsub("C:/.-/", "")
                table.insert(argStrs, '"' .. sanitized .. '"')
            elseif type(arg) == "number" or type(arg) == "boolean" then
                table.insert(argStrs, tostring(arg))
            elseif type(arg) == "function" then
                table.insert(argStrs, "function() end")
            elseif type(arg) == "table" and getmetatable(arg) then
                table.insert(argStrs, tostring(arg))
            else
                local argVar = createVar(arg, "argument")
                table.insert(argStrs, argVar)
            end
        end
        
        local resultVar = createVar(nil, path .. "(" .. table.concat(argStrs, ", ") .. ")")
        logOp(resultVar .. " = " .. varName .. "(" .. table.concat(argStrs, ", ") .. ")",
              "Call: " .. path .. "(...)")
        
        return createProxy(resultVar, resultVar, true)
    end
    
    proxyMeta.__tostring = function()
        return varName
    end
    
    setmetatable(proxy, proxyMeta)
    return proxy
end

-- === SAFE ENVIRONMENT - NO DANGEROUS FUNCTIONS ===
local env = {}

-- Track global accesses
local globalAccessLog = {}

-- Instance.new
env.Instance = {
    new = function(className, parent)
        local classStr = '"' .. tostring(className) .. '"'
        local instanceVar = createVar(nil, 'Instance.new(' .. classStr .. ')')
        
        if parent then
            logOp(instanceVar .. ' = Instance.new(' .. classStr .. ', ' .. tostring(parent) .. ')',
                  'Create Instance: ' .. tostring(className))
        else
            logOp(instanceVar .. ' = Instance.new(' .. classStr .. ')',
                  'Create Instance: ' .. tostring(className))
        end
        
        return createProxy(instanceVar, instanceVar, false)
    end
}

-- Enum support
local function createEnumValue(path)
    return setmetatable({}, {
        __tostring = function() return path end,
        __index = function(t, k)
            return createEnumValue(path .. "." .. k)
        end
    })
end

env.Enum = setmetatable({}, {
    __index = function(t, k)
        return createEnumValue("Enum." .. k)
    end
})

-- Math types (Vector3, Color3, UDim2, etc.)
local Vector3 = {}
Vector3.__index = Vector3
function Vector3.new(x, y, z)
    local v = setmetatable({x=x or 0, y=y or 0, z=z or 0}, Vector3)
    local varName = createVar(v, string.format("Vector3.new(%g, %g, %g)", x or 0, y or 0, z or 0))
    logOp(varName .. string.format(" = Vector3.new(%g, %g, %g)", x or 0, y or 0, z or 0), "Create Vector3")
    return v
end
function Vector3.__add(a, b)
    local ax = (type(a) == "table" and a.x) or 0
    local ay = (type(a) == "table" and a.y) or 0
    local az = (type(a) == "table" and a.z) or 0
    local bx = (type(b) == "table" and b.x) or 0
    local by = (type(b) == "table" and b.y) or 0
    local bz = (type(b) == "table" and b.z) or 0
    return Vector3.new(ax + bx, ay + by, az + bz)
end
function Vector3.__tostring(v)
    return string.format("Vector3.new(%g, %g, %g)", v.x, v.y, v.z)
end
env.Vector3 = Vector3

local Color3 = {}
Color3.__index = Color3
function Color3.new(r, g, b)
    local c = setmetatable({r=r or 0, g=g or 0, b=b or 0}, Color3)
    local varName = createVar(c, string.format("Color3.new(%g, %g, %g)", r or 0, g or 0, b or 0))
    logOp(varName .. string.format(" = Color3.new(%g, %g, %g)", r or 0, g or 0, b or 0), "Create Color3")
    return c
end
function Color3.fromRGB(r, g, b)
    local c = setmetatable({r=(r or 0)/255, g=(g or 0)/255, b=(b or 0)/255}, Color3)
    local varName = createVar(c, string.format("Color3.fromRGB(%d, %d, %d)", r or 0, g or 0, b or 0))
    logOp(varName .. string.format(" = Color3.fromRGB(%d, %d, %d)", r or 0, g or 0, b or 0), "Create Color3 from RGB")
    return c
end
function Color3.__tostring(v)
    return string.format("Color3.fromRGB(%d, %d, %d)", 
        math.floor(v.r * 255), math.floor(v.g * 255), math.floor(v.b * 255))
end
env.Color3 = Color3

local UDim2 = {}
UDim2.__index = UDim2
function UDim2.new(xScale, xOffset, yScale, yOffset)
    local u = setmetatable({
        X = {Scale = xScale or 0, Offset = xOffset or 0},
        Y = {Scale = yScale or 0, Offset = yOffset or 0}
    }, UDim2)
    local varName = createVar(u, string.format("UDim2.new(%g, %g, %g, %g)", 
        xScale or 0, xOffset or 0, yScale or 0, yOffset or 0))
    logOp(varName .. string.format(" = UDim2.new(%g, %g, %g, %g)", 
        xScale or 0, xOffset or 0, yScale or 0, yOffset or 0), "Create UDim2")
    return u
end
function UDim2.__tostring(v)
    return string.format("UDim2.new(%g, %g, %g, %g)", 
        v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset)
end
env.UDim2 = UDim2

local NumberRange = {}
NumberRange.__index = NumberRange
function NumberRange.new(min, max)
    local n = setmetatable({Min = min or 0, Max = max or min or 0}, NumberRange)
    local varName = createVar(n, string.format("NumberRange.new(%g, %g)", min or 0, max or min or 0))
    logOp(varName .. string.format(" = NumberRange.new(%g, %g)", min or 0, max or min or 0), "Create NumberRange")
    return n
end
function NumberRange.__tostring(v)
    return string.format("NumberRange.new(%g, %g)", v.Min, v.Max)
end
env.NumberRange = NumberRange

local ColorSequence = {}
ColorSequence.__index = ColorSequence
function ColorSequence.new(color)
    local cs = setmetatable({Keypoints = {color}}, ColorSequence)
    local varName = createVar(cs, "ColorSequence.new(" .. tostring(color) .. ")")
    logOp(varName .. " = ColorSequence.new(" .. tostring(color) .. ")", "Create ColorSequence")
    return cs
end
function ColorSequence.__tostring(v)
    return "ColorSequence.new(" .. tostring(v.Keypoints[1]) .. ")"
end
env.ColorSequence = ColorSequence

local NumberSequence = {}
NumberSequence.__index = NumberSequence
function NumberSequence.new(...)
    local args = {...}
    local ns = setmetatable({Keypoints = args}, NumberSequence)
    local varName = createVar(ns, "NumberSequence.new(" .. table.concat(args, ", ") .. ")")
    logOp(varName .. " = NumberSequence.new(" .. table.concat(args, ", ") .. ")", "Create NumberSequence")
    return ns
end
function NumberSequence.__tostring(v)
    return "NumberSequence.new(" .. table.concat(v.Keypoints, ", ") .. ")"
end
env.NumberSequence = NumberSequence

env.BrickColor = {
    new = function(name)
        local bc = setmetatable({Name = name}, {
            __tostring = function(v) return 'BrickColor.new("' .. v.Name .. '")' end
        })
        local varName = createVar(bc, 'BrickColor.new("' .. name .. '")')
        logOp(varName .. ' = BrickColor.new("' .. name .. '")', "Create BrickColor")
        return bc
    end,
    Random = function()
        return env.BrickColor.new("Random")
    end
}

local TweenInfo = {}
TweenInfo.__index = TweenInfo
function TweenInfo.new(time, easingStyle, easingDirection, repeatCount, reverses, delayTime)
    local ti = setmetatable({
        Time = time or 1,
        EasingStyle = easingStyle or "Linear",
        EasingDirection = easingDirection or "Out",
        RepeatCount = repeatCount or 0,
        Reverses = reverses or false,
        DelayTime = delayTime or 0
    }, TweenInfo)
    local varName = createVar(ti, "TweenInfo.new(...)")
    logOp(varName .. string.format(" = TweenInfo.new(%g, %s, %s, %d, %s, %g)",
        time or 1, tostring(easingStyle or "Linear"), tostring(easingDirection or "Out"),
        repeatCount or 0, tostring(reverses or false), delayTime or 0), "Create TweenInfo")
    return ti
end
function TweenInfo.__tostring(v)
    return string.format("TweenInfo.new(%g, %s, %s, %d, %s, %g)",
        v.Time, tostring(v.EasingStyle), tostring(v.EasingDirection),
        v.RepeatCount, tostring(v.Reverses), v.DelayTime)
end
env.TweenInfo = TweenInfo

-- === ANTI-TAMPER BYPASS SYSTEM ===
-- Tricks obfuscator anti-tamper checks (Prometheus, Hurcules, etc.)

-- Mock debug library that passes all anti-tamper checks
local fakeDebug = {}

-- getinfo - returns fake "C" for native functions
fakeDebug.getinfo = function(func, what)
    logOp("debug.getinfo() called", "Debug info access")
    
    -- Return fake info that looks like a native C function
    return {
        what = "C",  -- Claim it's a C function (native)
        source = "[C]",
        short_src = "[C]",
        linedefined = -1,
        lastlinedefined = -1,
        nups = 0,
        numparams = 0,
        isvararg = true,
        name = nil,
        namewhat = "",
        func = func
    }
end

-- getlocal - returns nil (no locals for "C" functions)
fakeDebug.getlocal = function(level, index)
    logOp("debug.getlocal() called", "Debug local access")
    return nil  -- No locals for "native" functions
end

-- getupvalue - returns nil (no upvalues for "C" functions)
fakeDebug.getupvalue = function(func, index)
    logOp("debug.getupvalue() called", "Debug upvalue access")
    return nil  -- No upvalues for "native" functions
end

-- setupvalue - does nothing but logs
fakeDebug.setupvalue = function(func, index, value)
    logOp("debug.setupvalue() called", "Debug setupvalue")
    return nil
end

-- traceback - returns fake traceback with consistent line numbers
fakeDebug.traceback = function(message, level)
    logOp("debug.traceback() called", "Debug traceback")
    
    -- Return a realistic fake traceback
    local msg = tostring(message or "")
    level = level or 1
    
    -- Create fake traceback that passes anti-tamper line number checks
    local tb = msg .. "\n"
    tb = tb .. "stack traceback:\n"
    tb = tb .. "\t[C]: in function 'error'\n"
    tb = tb .. "\t[C]: in function 'pcall'\n"
    
    return tb
end

-- sethook - logs but does nothing (prevents anti-beautify checks)
fakeDebug.sethook = function(hook, mask, count)
    logOp("debug.sethook() called", "Debug hook set")
    -- Do nothing - this prevents anti-beautify detection
end

-- getregistry - returns empty table
fakeDebug.getregistry = function()
    logOp("debug.getregistry() called", "Debug registry access")
    return {}
end

-- gethook - returns nil
fakeDebug.gethook = function()
    return nil, "", 0
end

-- Additional debug functions
fakeDebug.getmetatable = function(value)
    return getmetatable(value)
end

fakeDebug.setmetatable = function(value, table)
    return setmetatable(value, table)
end

env.debug = fakeDebug

-- Override _VERSION to say "Lua" not "Lune"
env._VERSION = "Lua 5.1"

-- Safe standard libraries (READ-ONLY)
local safeGlobals = {
    "assert", "error", "ipairs", "next", "pairs", "pcall", "select",
    "tonumber", "tostring", "type", "unpack", "_VERSION", "xpcall"
}

for _, name in ipairs(safeGlobals) do
    local val = _G[name]
    if val == nil then
        -- Try getting from current environment
        val = getfenv()[name]
    end
    env[name] = val
end

-- Environment manipulation
env.getfenv = function(stack)
    logOp("getfenv(" .. tostring(stack or "") .. ")", "Get environment")
    return env
end

env.setfenv = function(stack, newEnv)
    logOp("setfenv(" .. tostring(stack) .. ", [env])", "Set environment")
    return newEnv
                end
            end,
            __newindex = function() error("Cannot modify standard library") end,
            __metatable = "Locked"
        })
    end
end

-- Override print/warn to catch VM-executed code
env.print = function(...)
    local args = {...}
    local argStrs = {}
    local rawArgs = {}
    
    for _, v in ipairs(args) do
        table.insert(rawArgs, tostring(v))
        if type(v) == "string" then
            local sanitized = tostring(v):gsub("\\", "/"):gsub("C:/.-/", "")
            table.insert(argStrs, '"' .. sanitized .. '"')
        else
            table.insert(argStrs, tostring(v))
        end
    end
    
    -- Mark this as likely VM-executed original code
    logOp("", "")
    logOp("-- ═══════════════════════════════════════", "VM EXECUTION DETECTED")
    logOp("-- 🎯 ORIGINAL CODE (VM Executed):", "This is what the obfuscated script does")
    logOp("print(" .. table.concat(argStrs, ", ") .. ")", "ORIGINAL: " .. table.concat(rawArgs, ", "))
    logOp("-- ═══════════════════════════════════════", "End VM execution")
    logOp("", "")
end

env.warn = function(...)
    local args = {...}
    local argStrs = {}
    for _, v in ipairs(args) do
        if type(v) == "string" then
            local sanitized = tostring(v):gsub("\\", "/"):gsub("C:/.-/", "")
            table.insert(argStrs, '"' .. sanitized .. '"')
        else
            table.insert(argStrs, tostring(v))
        end
    end
    logOp("warn(" .. table.concat(argStrs, ", ") .. ")", "Warn: " .. table.concat(argStrs, ", "))
end

env.typeof = function(value)
    return type(value)
end

-- wait/task (safe, no actual delays)
env.wait = function(t)
    logOp("wait(" .. (t or "") .. ")", "Wait " .. (t or "default"))
    return 0
end

env.task = {
    wait = function(t)
        logOp("task.wait(" .. (t or "") .. ")", "Task wait")
        return 0
    end,
    spawn = function(func)
        logOp("task.spawn(function() end)", "Spawn task")
        return createProxy(createVar(nil, "task.spawn"), "task.spawn", true)
    end,
    delay = function(t, func)
        logOp("task.delay(" .. (t or 0) .. ", function() end)", "Delay task")
    end
}

-- === EXPLOIT FUNCTIONS (ALL LOGGED, NONE EXECUTED) ===

-- loadstring - logs code but DOES NOT execute for security
env.loadstring = function(code, chunkname)
    local codePreview = tostring(code):sub(1, 100)
    if #tostring(code) > 100 then
        codePreview = codePreview .. "..."
    end
    
    logOp("-- loadstring() called with code:", "Code loading attempt")
    logOp("-- CODE PREVIEW: " .. codePreview, "Loaded code preview")
    
    -- Log but DO NOT execute for security
    logOp("-- [SECURITY] Loadstring NOT executed in sandbox", "Security block")
    
    return function() 
        logOp("-- [SECURITY] Attempted to execute loadstring result", "Blocked execution")
    end
end

-- HTTP functions - ALL LOGGED, NONE EXECUTED
local function logHttpRequest(method, url, headers, body)
    -- Sanitize URL to remove any potential sensitive tokens
    local sanitizedUrl = tostring(url):gsub("[?&]token=[^&]+", "?token=REDACTED")
    
    logOp("-- HTTP " .. method .. " REQUEST DETECTED", "Network request (blocked)")
    logOp("-- URL: " .. sanitizedUrl, "Request URL")
    if headers then
        logOp("-- Headers: [REDACTED FOR SECURITY]", "Request headers")
    end
    if body then
        local bodyPreview = tostring(body):sub(1, 100)
        logOp("-- Body preview: " .. bodyPreview, "Request body")
    end
    logOp("-- [SECURITY] HTTP request NOT executed", "Security block")
    
    return "-- HTTP BLOCKED FOR SECURITY"
end

env.HttpGet = function(url)
    return logHttpRequest("GET", url)
end

env.syn = {
    request = function(options)
        local url = type(options) == "table" and options.Url or tostring(options)
        local method = type(options) == "table" and options.Method or "GET"
        return logHttpRequest(method, url)
    end
}

env.request = function(options)
    return env.syn.request(options)
end

-- File operations - ALL LOGGED, NONE EXECUTED
env.writefile = function(filename, content)
    logOp("writefile('" .. tostring(filename) .. "', [content])", "File write attempt(blocked)")
    logOp("-- [SECURITY] File write NOT executed", "Security block")
end

env.readfile = function(filename)
    logOp("readfile('" .. tostring(filename) .. "')", "File read attempt (blocked)")
    logOp("-- [SECURITY] File read NOT executed", "Security block")
    return ""
end

env.isfile = function(filename)
    logOp("isfile('" .. tostring(filename) .. "')", "File check (blocked)")
    return false
end

env.isfolder = function(path)
    logOp("isfolder('" .. tostring(path) .. "')", "Folder check (blocked)")
    return false
end

env.makefolder = function(path)
    logOp("makefolder('" .. tostring(path) .. "')", "Folder create (blocked)")
    logOp("-- [SECURITY] Folder creation NOT executed", "Security block")
end

env.listfiles = function(path)
    logOp("listfiles('" .. tostring(path) .. "')", "List files (blocked)")
    return {}
end

env.delfile = function(filename)
    logOp("delfile('" .. tostring(filename) .. "')", "File delete (blocked)")
    logOp("-- [SECURITY] File deletion NOT executed", "Security block")
end

-- Clipboard - logged only
env.setclipboard = function(text)
    local sanitized = tostring(text):sub(1, 100)
    logOp("setclipboard([text])", "Clipboard set (blocked)")
    logOp("-- Text preview: " .. sanitized, "Clipboard content")
    logOp("-- [SECURITY] Clipboard NOT modified", "Security block")
end

-- Other exploit functions - all logged, none executed
env.getrawmetatable = function(obj)
    logOp("getrawmetatable(obj)", "Metatable access (blocked)")
    return {}
end

env.setrawmetatable = function(obj, mt)
    logOp("setrawmetatable(obj, mt)", "Metatable modification (blocked)")
end

env.hookfunction = function(original, hook)
    logOp("hookfunction(func, hook)", "Function hook (blocked)")
    return original
end

env.hookmetamethod = function(obj, method, hook)
    logOp("hookmetamethod(obj, '" .. tostring(method) .. "', hook)", "Metamethod hook (blocked)")
    return function() end
end

env.Drawing = {
    new = function(drawingType)
        logOp("Drawing.new('" .. tostring(drawingType) .. "')", "Drawing creation")
        return createProxy(createVar(nil, "drawing"), "drawing", true)
    end
}

env.identifyexecutor = function()
    logOp("identifyexecutor()", "Executor identification")
    return "SecureSandbox", "1.0.0"
end

env.getexecutorname = function()
    logOp("getexecutorname()", "Get executor name")
    return "SecureSandbox"
end

-- Global game/workspace/script
local gameVar = createVar(nil, "game")
env.game = createProxy(gameVar, "game", true)

local workspaceVar = createVar(nil, "workspace")
env.workspace = createProxy(workspaceVar, "workspace", true)

local scriptVar = createVar(nil, "script")
env.script = createProxy(scriptVar, "script", true)

logOp("-- SCRIPT START", "Execution begins")

-- Metatable to catch undefined globals
local envMt = {
    __index = function(t, key)
        table.insert(globalAccessLog, key)
        local newVar = createVar(nil, key)
        logOp(newVar .. " = " .. key, "Access global: " .. key)
        return createProxy(newVar, key, true)
    end,
    __newindex = function(t, key, value)
        local valueStr
        if type(value) == "string" then
            valueStr = '"' .. tostring(value) .. '"'
        elseif type(value) == "number" or type(value) == "boolean" then
            valueStr = tostring(value)
        else
            valueStr = "..."
        end
        logOp(key .. " = " .. valueStr, "Set global: " .. key)
        rawset(t, key, value)
    end,
    __metatable = "Locked"
}
setmetatable(env, envMt)

-- Execute the script in the sandbox
local chunk, err = loadstring(scriptContent, "@user_script")

if not chunk then
    logOp("-- ERROR: Compilation failed", tostring(err))
else
    setfenv(chunk, env)
    local success, runtimeErr = pcall(chunk)
    if not success then
        local sanitizedErr = tostring(runtimeErr):gsub("\\", "/"):gsub("C:/.-/", "")
        logOp("-- ERROR: Runtime error", sanitizedErr)
    end
end

logOp("-- SCRIPT END", "Execution complete")

-- Generate safe output
local output = {}
table.insert(output, "-- ========================================")
table.insert(output, "-- RECONSTRUCTED CODE (Complete Execution Trace)")
table.insert(output, "-- ========================================")
table.insert(output, "-- Every operation performed by the script")
table.insert(output, "-- Variable names: v1, v2, v3...")
table.insert(output, "-- [SECURE SANDBOX - No file/network access]")
table.insert(output, "-- ========================================")
table.insert(output, "")

for _, op in ipairs(executionTrace) do
    table.insert(output, op.code)
    if op.description ~= op.code then
        table.insert(output, op.description)
    end
end

table.insert(output, "")
table.insert(output, "-- ========================================")
table.insert(output, "-- EXECUTION SUMMARY")
table.insert(output, "-- ========================================")
table.insert(output, "-- Total operations: " .. #executionTrace)
table.insert(output, "-- Variables created: " .. varCounter)
table.insert(output, "-- Global accesses: " .. #globalAccessLog)
if #globalAccessLog > 0 then
    table.insert(output, "-- Globals accessed: " .. table.concat(globalAccessLog, ", "))
end
table.insert(output, "-- Security: MAXIMUM (no file/network access)")

-- ===== LITERAL RECONSTRUCTION =====
-- This section reconstructs the code with ACTUAL values (URLs, strings, etc.)
-- instead of variable references

table.insert(output, "")
table.insert(output, "")
table.insert(output, "-- ========================================")
table.insert(output, "-- LITERAL RECONSTRUCTION")
table.insert(output, "-- ========================================")
table.insert(output, "-- Code reconstructed with actual URLs and values")
table.insert(output, "-- This shows what the script ACTUALLY does")
table.insert(output, "-- ========================================")
table.insert(output, "")

-- Build a map of variables to their literal values
local literalValues = {}
for varName, info in pairs(varRegistry) do
    if info.description then
        literalValues[varName] = info.description
    end
end

-- Reconstruct with actual values where possible
for _, op in ipairs(executionTrace) do
    local literalCode = op.code
    
    -- Replace variable references with their literal values when beneficial
    -- Specifically for URLs, file names, and other important strings
    for varName, literal in pairs(literalValues) do
        -- Only replace if it's a meaningful value (URL, string, etc.)
        if literal:match("http") or literal:match("%.lua") or literal:match("%.txt") then
            literalCode = literalCode:gsub(varName .. "([^%d])", literal .. "%1")
            literalCode = literalCode:gsub(varName .. "$", literal)
        end
    end
    
    -- Clean up obvious patterns
    if not literalCode:match("^%-%-") then -- Don't process comments
        table.insert(output, literalCode)
    end
end

table.insert(output, "")
table.insert(output, "-- ========================================")
table.insert(output, "-- EXTRACTED INFORMATION")
table.insert(output, "-- ========================================")

-- Extract and list all URLs found
local urls = {}
local files = {}
local suspiciousStrings = {}

for _, op in ipairs(executionTrace) do
    local code = op.code
    
    -- Extract URLs
    for url in code:gmatch("https?://[%w%.%-_/%%?&=]+") do
        urls[url] = true
    end
    for url in code:gmatch('"(https?://[^"]+)"') do
        urls[url] = true
    end
    
    -- Extract file names
    for file in code:gmatch('writefile%(["\']([^"\']+)["\']') do
        files[file] = true
    end
    for file in code:gmatch('readfile%(["\']([^"\']+)["\']') do
        files[file] = true
    end
    
    -- Extract potential tokens/cookies
    if code:match("[Tt]oken") or code:match("[Cc]ookie") or code:match("%.ROBLOSECURITY") then
        table.insert(suspiciousStrings, code)
    end
end

-- Output findings
if next(urls) then
    table.insert(output, "")
    table.insert(output, "-- URLs FOUND:")
    for url in pairs(urls) do
        table.insert(output, "--   " .. url)
    end
end

if next(files) then
    table.insert(output, "")
    table.insert(output, "-- FILES ACCESSED:")
    for file in pairs(files) do
        table.insert(output, "--   " .. file)
    end
end

if #suspiciousStrings > 0 then
    table.insert(output, "")
    table.insert(output, "-- SUSPICIOUS OPERATIONS:")
    for _, str in ipairs(suspiciousStrings) do
        table.insert(output, "--   " .. str)
    end
end

-- Print to stdout
local fullOutput = table.concat(output, "\n")
print(fullOutput)
