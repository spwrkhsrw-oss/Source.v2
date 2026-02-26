-- Prometheus/src/prometheus/steps/ComplexAntiTamper.lua
local parser = (function()
    local locations = {"prometheus.parser", "src.parser", "parser"}
    for _, loc in ipairs(locations) do
        local ok, mod = pcall(require, loc)
        if ok then return mod end
    end
    error("Could not find parser module")
end)()

return function(ast, config)
    local watermark = config.Watermark or "Protected by Lularph Obfuscator by valeratter"

    local function rand_int(mn, mx) return math.random(mn, mx) end

    local function opaque_true()
        local a,b,c = rand_int(1000,9999), rand_int(1000,9999), rand_int(1,100)
        return string.format("((%d*%d)%%%d == (%d*%d)%%%d)", a,b,c, a,b,c)
    end

    local function opaque_false()
        local a = rand_int(2,100)
        return string.format("(%d~=%d)", a, a)
    end

    local function hash_string(s)
        local h = 2166136261
        for i = 1, #s do
            h = (h ~ string.byte(s, i)) * 16777619
            h = h & 0xFFFFFFFF
        end
        return ("0x%08x"):format(h)
    end
    local w_hash = hash_string(watermark)

    local anti_code = string.format([[
do
    local function f1() if debug and debug.getinfo then error("protected") end end
    local function f2() if type(print)~='function' or type(string.byte)~='function' then error("protected") end end
    local function f3() local a,b=12345,67890; if (a*b)%%13 ~= (a*b)%%13 then error("protected") end end
    local function f4() local s=os.clock(); for i=1,10000 do local x=i*i end; if os.clock()-s>0.01 then error("protected") end end
    local function f5() local w="%s"; local h=2166136261; for i=1,#w do h=(h~string.byte(w,i))*16777619 h=h&0xFFFFFFFF end; if ("0x%%08x"):format(h)~="%s" then error("protected") end end
    if %s then f1() end
    if %s then f2() end
    if %s then f3() end
    if %s then f4() end
    if %s then f5() end
end
]], watermark, w_hash, opaque_true(), opaque_true(), opaque_false(), opaque_true(), opaque_true())

    local anti_ast = parser.parse(anti_code)
    if ast and ast.body then
        table.insert(ast.body, 1, anti_ast.body[1])
    end
    return ast
end
