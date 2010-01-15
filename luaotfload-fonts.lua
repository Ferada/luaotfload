luaotfload              = luaotfload or { }
luaotfload.fonts        = { }

luaotfload.fonts.module = {
    name          = "luaotfload.fonts",
    version       = 1.001,
    date          = "2010/01/12",
    description   = "luaotfload font database.",
    author        = "Khaled Hosny",
    copyright     = "Khaled Hosny",
    license       = "CC0"
}

kpse.set_program_name("luatex")

require("luaextra.lua")
require("otfl-luat-dum.lua")

local upper, splitpath, expandpath, glob, basename = string.upper, file.split_path, kpse.expand_path, dir.glob, file.basename

luaotfload.fonts.basename = "otfl-names.lua"
luaotfload.fonts.version  = 1.001
luaotfload.fonts.log      = false

local function log(...)
    if luaotfload.fonts.log then
        logs.simple(...)
    end
end

local function info(...)
    logs.simple(...)
end

local function clean(str)
    return string.gsub(string.lower(str), "[^%a%d]", "")
end

local function tprint(t) print(table.serialize(t)) end
function fontloader.fullinfo(filename, subfont)
--  info("loaing %s", filename)
    local f, w, m, t, n = nil, nil, nil, { }, { }
    if subfont then
        f, w = fontloader.open(filename, subfont)
    else
        f, w = fontloader.open(filename)
    end
    m = fontloader.to_table(f)
    fontloader.close(f)
    m.glyphs, m.gpos, m.gsub, m.kerns, m.lookups, m.map = nil, nil, nil, nil, nil, nil
    m.anchor_classes, m.mark_classes, m.horiz_base = nil, nil, nil
    if m.names then
        for _,v in pairs(m.names) do
            if v.lang == "English (US)" then
                n.fullname = v.names.compatfull
                n.familyname = v.names.preffamilyname
                n.subfamily = v.names.subfamily
                n.modifier = v.names.prefmodifiers
            end
        end
    end
    if m.fontstyle_name then
        for _,v in pairs(m.fontstyle_name) do
            if v.lang == 1033 then
                m.style = v.name
            end
        end
    end
    t.psname = m.fontname
    t.fullname = n.fullname or m.fullname
    t.family = n.familyname or m.familyname
    t.style = n.subfamily or m.style
    if not t.style or t.style:is_empty() then
        local s = t.psname:split("-")
        if s and #s >= 2 then
            t.style = s[#s]
        end
    end
    if not t.style or t.style:is_empty() then
        t.style = n.modifier
    end
    if not t.style or t.style:is_empty() then
        if n.fullname and n.familyname then
            t.style = (n.fullname:gsub(n.familyname, "") ~= n.fullname and n.fullname:gsub(n.familyname, "")) or nil
        elseif m.fontname and m.familyname then
            t.style = (m.fontname:gsub(m.familyname, "") ~= m.fontname and m.fontname:gsub(m.familyname, "")) or nil
        end
    end
    if not t.style or t.style:is_empty() then
        t.style = (m.fullname:gsub(m.familyname, "") ~= m.fullname and m.fullname:gsub(m.familyname, "")) or nil
    end
    if not t.style or t.style:is_empty() then
        t.style = "Regular"
    end
--  tprint(m) print(w)
    m, n = nil, nil
    return t
end

local function load_font(filename, names, texmf)
    local psnames, families = names.mappings.psnames, names.mappings.families
    if filename then
        local info = fontloader.info(filename)
        if info then
            if type(info) == "table" and #info > 1 then
                for index,_ in ipairs(info) do
                    local fullinfo = fontloader.fullinfo(filename, index-1)
                    if not families[fullinfo.family] then
                        families[fullinfo.family] = { }
                    end
                    families[fullinfo.family][fullinfo.style] = {texmf and basename(filename) or filename, index-1}
                    psnames[fullinfo.psname] = {texmf and basename(filename) or filename, index-1}
                end
            else
                local fullinfo = fontloader.fullinfo(filename)
                if texmf == true then
                    filename = basename(filename)
		end
                if not families[fullinfo.family] then
                    families[fullinfo.family] = { }
                end
                families[fullinfo.family][fullinfo.style] = texmf and basename(filename) or filename
                psnames[fullinfo.psname] = texmf and basename(filename) or filename
            end
        else
            log("Failed to load %s", filename)
        end
    end
end

local function scan_dir(dirname, names, recursive, texmf)
    local list, found = { }, { }
    for _,ext in ipairs { "otf", "ttf", "ttc", "dfont" } do
        if recursive then pat = "/**." else pat = "/*." end
        log("Scanning '%s' for '%s' fonts", dirname, ext)
        found = glob(dirname .. pat .. ext)
        log("%s fonts found", #found)
        table.append(list, found)

        log("Scanning '%s' for '%s' fonts", dirname, upper(ext))
        found = glob(dirname .. pat .. upper(ext))
        log("%s fonts found", #found)
        table.append(list, found)
    end
    for _,fnt in ipairs(list) do
        load_font(fnt, names, texmf)
    end
end

--[[
local function scan_os_fonts(names)
    local fontdirs
    fontdirs = expandpath("$OSFONTDIR")
    if not fontdirs:is_empty() then
        fontdirs = splitpath(fontdirs, ":")
        for _,d in ipairs(fontdirs) do
            scan_dir(d, names, true)
        end
    end
end
--]]

local function scan_txmf_tree(names)
    local fontdirs = expandpath("$OPENTYPEFONTS")
    fontdirs = fontdirs .. expandpath("$TTFONTS")
    if not fontdirs:is_empty() then
        fontdirs = splitpath(fontdirs, ":")
        for _,d in ipairs(fontdirs) do
            scan_dir(d, names, false, true)
        end
    end
end

local function generate()
    local fnames = {
        mappings = {
            families = { },
            psnames  = { },
        },
        version  = luaotfload.fonts.version
    }
    local savepath
    scan_txmf_tree(fnames)
    logs.simple("%s fonts saved in the database", #table.keys(fnames.mappings.psnames))
    savepath = kpse.expand_var("$TEXMFVAR") .. "/tex/"
    lfs.mkdir(savepath)
    savepath = savepath .. luaotfload.fonts.basename
    io.savedata(savepath, table.serialize(fnames, true))
    logs.simple("Saved font names database in %s\n", savepath)
end

luaotfload.fonts.scan     = scan_dir
luaotfload.fonts.generate = generate

if arg[0] == "luaotfload-fonts.lua" then
    generate()
--  t = fontloader.fullinfo(arg[1])
--  tprint(t)
end
