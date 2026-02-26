return {
    LuaVersion = "LuaU",
    PrettyPrint = false,
    NameGenerator = "MangledShuffled",
    Steps = {
        { Name = "NumbersToExpressions" },
        { Name = "SplitStrings", Settings = { ChunkSize = 2 } },
        { Name = "EncryptStrings" },
        { Name = "Vmify", Settings = { Complexity = "High" } },
        { Name = "ConstantArray", Settings = { StringsOnly = false, Shuffle = true } },
        { Name = "Vmify", Settings = { Complexity = "High" } },  -- double Vmify!
        { Name = "AntiTamper", Settings = { Level = "Aggressive" } },
        { Name = "WatermarkCheck", Settings = {
            Watermark = "Protected by Lularph Obfuscator by valeratter"
        } },
        { Name = "WrapInFunction" },
        { Name = "AddVararg" },
    },
    Seed = 0xDEADBEEF,  -- optional: fixed seed for deterministic output
}
