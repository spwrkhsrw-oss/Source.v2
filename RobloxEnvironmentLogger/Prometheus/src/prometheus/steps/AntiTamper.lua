-- Prometheus/src/prometheus/steps/AntiTamper.lua
-- Simplified anti‑tamper – minimal locals, works with trivial scripts
local Step = require("prometheus.step")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local logger = require("logger")

local AntiTamper = Step:extend()
AntiTamper.Description = "Lightweight self‑decrypting anti‑tamper"
AntiTamper.Name = "Light Anti Tamper"

function AntiTamper:init(settings) end

function AntiTamper:apply(ast, pipeline)
    if pipeline.PrettyPrint then
        logger:warn(string.format("\"%s\" cannot be used with PrettyPrint, ignoring \"%s\"", self.Name, self.Name))
        return ast
    end

    local unparser = require("prometheus.unparser")
    local original_source = unparser:new({LuaVersion = pipeline.LuaVersion}):unparse(ast)

    -- Simple additive encryption
    local function encrypt(data, key)
        local bytes = {}
        for i = 1, #data do
            bytes[i] = (string.byte(data, i) + key) % 256
        end
        return bytes
    end

    -- Split into 3 chunks
    local num_chunks = 3
    local chunk_size = math.ceil(#original_source / num_chunks)
    local chunks = {}
    for i = 1, #original_source, chunk_size do
        chunks[#chunks+1] = original_source:sub(i, i + chunk_size - 1)
    end

    local base_keys = { 137, 42, 199 }
    local encrypted_chunks = {}
    for i, chunk in ipairs(chunks) do
        encrypted_chunks[i] = encrypt(chunk, base_keys[i])
    end

    local function bytes_to_string(bytes)
        local parts = {}
        for _, b in ipairs(bytes) do
            parts[#parts+1] = tostring(b)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end

    local chunk_tables = {}
    for i, bytes in ipairs(encrypted_chunks) do
        chunk_tables[i] = bytes_to_string(bytes)
    end

    local targetVersion = pipeline.LuaVersion or Enums.LuaVersion.Lua51

    -- Ultra‑compact wrapper (NO huge constant tables)
    local wrapper_code = string.format([[
do
    -- ASCII art (inner string uses [=[ ... ]=] to avoid nesting)
    local art = [=[


__________$$$$$$
_________$$____$$
_________$$$__$$$
_________$$_$$_$$
_________$$____$$
_________$$____$$
_________$$____$$
_________$$____$$$$$$$
___$$$$$$$$____$$____$$
_$$$$$___$$____$$____$$$$$$
$$$_$$___$$____$$____$$___$$
$$__$$___$$____$$____$$___$$
$$__$$___$$____$$____$$___$$
$$__$$___$$____$$___$$$___$$
$$__$$___$$____$$____$____$$
$$____$$$__$$$$__$$$$___$_$$
$$________________________$$
_$$lularp:_______________$$
_$$$https://discord.gg/vD93ZH5th9
__$$$$_________________$$$
____$$_________________$
____$$$_______________$$
    ]=]

    local function panic()
        warn("Anti EnvLogger/Tamper triggered")
        warn("\n" .. art)
        while true do end
    end

    -- Minimal environment checks (all inside pcall)
    local function safe(f, ...)
        local ok, res = pcall(f, ...)
        return ok and res or nil
    end

    local loader = load or loadstring
    if not loader then panic() end

    -- Quick checks (only essential)
    if type(print) == "function" and not tostring(print):find("function") then panic() end
    if safe(function() return Instance and Instance.new end) then
        local f = safe(Instance.new, "Frame")
        if f and (f.Name ~= "Frame" or f.Parent ~= nil) then panic() end
    end

    -- Opaque predicates (simplified)
    local op = 0
    if (12345 * 54321) %% 101 == (12345 + 54321) %% 103 then op = 1 end
    local x = 0.5
    for i = 1, 20 do x = x * 2 end
    if x ~= x then op = op + 2 end

    -- Derive keys (using fixed values + opaque)
    local a,b,c,d = string.byte("A"),string.byte("B"),string.byte("C"),string.byte("D")
    local keys = {
        (a*b + 199 + op) %% 256,
        (b*c + 228 + op) %% 256,
        (c*d + 251 + op) %% 256
    }
    for i=1,3 do if keys[i]==0 then keys[i]=1 end end

    -- Decrypt chunks
    local encrypted = { %s, %s, %s }
    local decrypted = {}
    local ok = pcall(function()
        for i=1,3 do
            local key = keys[i]
            local bytes = encrypted[i]
            if not bytes then error() end
            local out = {}
            for j,byte in ipairs(bytes) do
                out[j] = string.char((byte - key) %% 256)
            end
            decrypted[i] = table.concat(out)
        end
    end)
    if not ok or not decrypted[1] or not decrypted[2] or not decrypted[3] then panic() end

    -- Load and execute
    local src = decrypted[1] .. decrypted[2] .. decrypted[3]
    local fn, err = loader(src)
    if not fn then panic() end
    pcall(fn)
end
]], chunk_tables[1], chunk_tables[2], chunk_tables[3])

    local parser = Parser:new({LuaVersion = targetVersion})
    local wrapper_ast = parser:parse(wrapper_code)
    return wrapper_ast
end

return AntiTamper
