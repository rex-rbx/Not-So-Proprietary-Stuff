return function(Length)
    local b = buffer.create(Length)
    local offset = 0
    local Ranges = {
        -- Latin-1 Supplement (excluding controls, keeping visible symbols)
        {0x00A1, 0x00AC}, {0x00AE, 0x00FF},
        -- Latin Extended through Cyrillic (all safe)
        {0x0100, 0x052F},
        -- Armenian, Hebrew, Arabic, Syriac (safe)
        {0x0530, 0x07BF},
        -- Indic scripts (safe)
        {0x0900, 0x0DFF},
        -- Thai through Georgian (safe)
        {0x0E00, 0x10FF},
        -- Hangul, Ethiopic, Cherokee (safe)
        {0x1100, 0x13FF},
        -- Canadian Aboriginal through Runic (safe)
        {0x1400, 0x16FF},
        -- Full Width Alphanumerics
        {0xFF01, 0xFF5E},
        -- Latin-1 Symbols (already covered above but explicit)
        {0x00A1, 0x00FF},
        -- Math/Arrows (full range)
        {0x2000, 0x2BFF},
        -- CJK/Asian (main block)
        {0x4E00, 0x9FFF},
        -- Emojis (smileys, emoticons)
        {0x1F600, 0x1F64F},
        -- Yi Blocky Symbols
        {0xA000, 0xA48C},
        -- Extended CJK, Hangul, etc
        {0x3400, 0x4DBF},
        {0xAC00, 0xD7AF},
        {0xF900, 0xFAFF},
        -- More emojis and symbols
        {0x1F300, 0x1F5FF},
        {0x1F680, 0x1F6FF},
        {0x1F900, 0x1F9FF},
    }
    local ExcludeCodepoints = {
        -- Line terminators
        0x000A, -- LINE FEED (LF)
        0x000D, -- CARRIAGE RETURN (CR)
        0x000C, -- FORM FEED (FF)
        0x0085, -- NEXT LINE (NEL)
        0x2028, -- LINE SEPARATOR
        0x2029, -- PARAGRAPH SEPARATOR
        -- Other problematic controls
        0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007,
        0x0008, 0x0009, -- TAB (usually fine but sometimes problematic)
        0x000B, -- VERTICAL TAB
        0x000E, 0x000F, 0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015,
        0x0016, 0x0017, 0x0018, 0x0019, 0x001A, 0x001B, 0x001C, 0x001D,
        0x001E, 0x001F, 0x007F, -- DELETE
        -- Bidirectional controls
        0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
        0x200B, 0x200C, 0x200D, 0xFEFF,
        0xD800, 0xDBFF, 0xDC00, 0xDFFF,
    }
    local ExcludeSet = {}
    for _, cp in ipairs(ExcludeCodepoints) do
        ExcludeSet[cp] = true
    end
    local function isAllowedCodepoint(cp)
        return not ExcludeSet[cp]
    end
    while offset < Length do
        local selectedRange = Ranges[math.random(1, #Ranges)]
        local cp = math.random(selectedRange[1], selectedRange[2])
        while not isAllowedCodepoint(cp) do
            cp = math.random(selectedRange[1], selectedRange[2])
        end
        local ok, str = pcall(utf8.char, cp)
        if not ok then
            str = "?"
        end
        local charLen = #str
        if offset + charLen <= Length then
            for i = 1, charLen do
                buffer.writeu8(b, offset, string.byte(str, i))
                offset = offset + 1
            end
        else
            while offset < Length do
                buffer.writeu8(b, offset, math.random(33, 126))
                offset = offset + 1
            end
        end
    end
    
    return buffer.tostring(b)
end
