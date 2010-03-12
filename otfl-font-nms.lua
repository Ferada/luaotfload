if not modules then modules = { } end modules ['font-nms'] = {
    version   = 1.002,
    comment   = "companion to luaotfload.lua",
    author    = "Khaled Hosny and Elie Roux",
    copyright = "Luaotfload Development Team",
    license   = "GPL"
}

fonts                = fonts       or { }
fonts.names          = fonts.names or { }

local names          = fonts.names
names.version        = 2.005 -- not the same as in context
names.basename       = "otfl-names.lua"
names.subtexmfvardir = "/scripts/luatexfontdb/"
names.new_to_old     = { }
names.old_to_new     = { }


local splitpath, expandpath, glob, basename = file.split_path, kpse.expand_path, dir.glob, file.basename
local upper, format  = string.upper, string.format

local trace_progress = true  --trackers.register("names.progress", function(v) trace_progress = v end)
local trace_search   = false --trackers.register("names.search",   function(v) trace_search   = v end)
local trace_loading  = false --trackers.register("names.loading",  function(v) trace_loading  = v end)

local function sanitize(str)
    return string.gsub(string.lower(str), "[^%a%d]", "")
end

local data, loaded = nil, false
local synonyms = {
    regular     = {"normal", "roman", "plain", "book", "medium"},
    italic      = {"regularitalic", "normalitalic", "oblique", "slant"},
    bolditalic  = {"boldoblique", "boldslant"},
}

function names.resolve(specification)
    local name, style = specification.name, specification.style or "regular"
    if not loaded then
        local basename = names.basename
        if basename and basename ~= "" and names.subtexmfvardir then
            local foundname = kpse.expand_var("$TEXMFVAR") .. names.subtexmfvardir .. basename
            if not file.isreadable(foundname) then
                foundname = kpse.expand_var("$TEXMFSYSVAR") .. names.subtexmfvardir .. basename
            end
            if file.isreadable(foundname) then
                data = dofile(foundname)
                logs.report("load font", "loaded font names database: %s", foundname)
            end
        end
        loaded = true
    end
    if type(data) == "table" and data.version == names.version then
        if data.mappings then
            local family = data.families[name]
            if family and type(family) == "table" then
                for _,v in ipairs(family) do
                   local face      = data.mappings[v]
                   local subfamily = sanitize(face.names.subfamily)
                   local rqssize   = tonumber(specification.optsize) or specification.size and specification.size / 65536
                   local dsnsize   = face.size[1] and face.size[1] / 10
                   local maxsize   = face.size[2] and face.size[2] / 10
                   local minsize   = face.size[3] and face.size[3] / 10
                   local filename  = face.filename
                   if subfamily then
                       if subfamily == style then
                           if not dsnsize or dsnsize == rqssize or (rqssize > minsize and rqssize <= maxsize) then
                               found = filename
                               logs.report("load font", "font family='%s', subfamily='%s' found: %s", name, style, found)
                               break
                           end
                       else
                           if synonyms[style] then
                               for _,v in ipairs(synonyms[style]) do
                                   if subfamily == v then
                                       if not dsnsize or dsnsize == rqssize or (rqssize > minsize and rqssize <= maxsize) then
                                            found = filename
                                            logs.report("load font", "font family='%s', subfamily='%s' found: %s", name, style, found)
                                            break
                                       end
                                   end
                               end
                           end
                       end
                   end
                end
                if found then
                   return found, false
                else
                   return name, false -- fallback to filename
                end
            end
        end
    else
        logs.report("load font", "Font names database version mismatch, found: %s, requested: %s", data.version, names.version)
    end
end

names.resolvespec = names.resolve -- only supported in mkiv

function names.set_log_level(level)
    if level == 2 then
        trace_progress = false
        trace_loading = true
    elseif level >= 3 then
        trace_progress = false
        trace_loading = true
        trace_search = true
    end
end
    
local lastislog = 0

function log(fmt, ...)
    lastislog = 1
    texio.write_nl(format("luaotfload | %s", format(fmt,...)))
end

logs        = logs or { }
logs.report = logs.report or log

local log = names.log

-- The progress bar
local function progress(current, total)
    if trace_progress then
--      local width   = os.getenv("COLUMNS") -2 --doesn't work
        local width   = 78
        local percent = current/total
        local gauge   = format("[%s]", string.rpadd(" ", width, " "))
        if percent > 0 then
            local done = string.rpadd("=", (width * percent) - 1, "=") .. ">"
            gauge = format("[%s]", string.rpadd(done, width, " ") )
        end
        if lastislog == 1 then
            texio.write_nl("")
            lastislog = 0
        end
        io.stderr:write("\r"..gauge)
        io.stderr:flush()
    end
end

function fontloader.fullinfo(...)
    local t = { }
    local f = fontloader.open(...)
    local m = f and fontloader.to_table(f)
    fontloader.close(f)
    -- see http://www.microsoft.com/typography/OTSPEC/features_pt.htm#size
    if m.fontstyle_name then
        for _,v in pairs(m.fontstyle_name) do
            if v.lang == 1033 then
                t.fontstyle_name = v.name
            end
        end
    end
    if m.names then
        for _,v in pairs(m.names) do
            if v.lang == "English (US)" then
                t.names = {
                    -- see http://developer.apple.com/textfonts/TTRefMan/RM06/Chap6name.html
                    fullname       = v.names.compatfull     or v.names.fullname, -- 18, 4
                    family         = v.names.preffamilyname or v.names.family,   -- 17, 1
                    subfamily      = t.fontstyle_name       or v.names.prefmodifiers  or v.names.subfamily, -- opt. style, 16, 2
                    psname         = v.names.postscriptname --or t.fontname
                }
            end
        end
    end
    t.fontname    = m.fontname
    t.fullname    = m.fullname
    t.familyname  = m.familyname
    t.filename    = m.origname
    t.weight      = m.pfminfo.weight
    t.width       = m.pfminfo.width
    t.slant       = m.italicangle
    -- don't waste the space with zero values
    t.size = {
        m.design_size         ~= 0 and m.design_size         or nil,
        m.design_range_top    ~= 0 and m.design_range_top    or nil,
        m.design_range_bottom ~= 0 and m.design_range_bottom or nil,
    }
    return t
end

local function load_font(filename, fontnames, status, newfontnames, newstatus, texmf)
    local mappings  = newfontnames and newfontnames.mappings  or { }
    local families  = newfontnames and newfontnames.families  or { }
    local oldmappings  = fontnames.mappings  or { }
    local oldfamilies  = fontnames.families  or { }
    local purge = true
    local tofillstatus = newstatus
    if not newstatus then
        purge = false
        families = fontnames.families  or { }
        mappings = fontnames.mappings  or { }
        tofillstatus = status
    end
    if filename then
        local db_lastmodif = status[filename] and status[filename].timestamp
        local true_lastmodif = lfs.attributes(filename, "modification")
        if purge then
            tofillstatus[filename] = {timestamp = true_lastmodif, mappings = {}}
        end
        if db_lastmodif and db_lastmodif == true_lastmodif then
            if purge then
                for _, i in ipairs(status[filename].mappings) do
                    mappings[#mappings+1] = oldmappings[i]
                    table.insert(tofillstatus[filename].mappings, #mappings)
                    if oldmappings[i].names.family then
                        if not families[oldmappings[i].names.family] then
                            families[oldmappings[i].names.family] = {}
                        end
                        table.insert(families[oldmappings[i].names.family], #mappings)
                    elseif trace_loading then
                        logs.report("font with broken names table: %s, ignored", filename)
                    end
                end
            end
            if trace_loading then
                logs.report("font already indexed: %s", filename)
            end
            return
        end
        if trace_loading then
            logs.report("loading font: %s", filename)
        end
        local checksum = file.checksum(filename)
        local info = fontloader.info(filename)
        if not purge then
            tofillstatus[filename] = {timestamp = true_lastmodif, mappings = {}}
        end
        if info then
            if type(info) == "table" and #info > 1 then
                for index,_ in ipairs(info) do
                    local fullinfo = fontloader.fullinfo(filename, index-1)
                    fullinfo.checksum = checksum
                    if texmf then
                        fullinfo.filename = basename(filename)
                    end
                    mappings[#mappings+1] = fullinfo
                    table.insert(tofillstatus[filename].mappings, #mappings)
                    if fullinfo.names.family then
                        if not families[fullinfo.names.family] then
                            families[fullinfo.names.family] = { }
                        end
                        table.insert(families[fullinfo.names.family], #mappings)
                    elseif trace_loading then
                        logs.report("font with broken names table: %s, ignored", filename)
                    end
                end
            else
                local fullinfo = fontloader.fullinfo(filename)
                fullinfo.checksum = checksum
                if texmf then
                    fullinfo.filename = basename(filename)
                end
                mappings[#mappings+1] = fullinfo
                table.insert(tofillstatus[filename].mappings, #mappings)
                if fullinfo.names.family then
                    if not families[fullinfo.names.family] then
                        families[fullinfo.names.family] = { }
                    end
                    table.insert(families[fullinfo.names.family], #mappings)
                else
                    if trace_loading then
                        logs.report("font with broken names table: %s, ignored", filename)
                    end
                end
            end
        else
            if trace_loading then
               logs.report("failed to load %s", filename)
            end
        end
    end
end

-- path normalization:
-- - a\b\c  -> a/b/c
-- - a/../b -> b
-- - /cygdrive/a/b -> a:/b
local function path_normalize(path)
    if os.type ~= 'unix' then
        path = path:gsub('\\', '/')
        path = path:lower()
    end
    path = file.collapse_path(path)
    if os.name == "cygwin" then
        path = path:gsub('^/cygdrive/(%a)/', '%1:/')
    end
    return path
end

fonts.path_normalize = path_normalize

-- this function scans a directory and populates the list of fonts
-- with all the fonts it finds.
-- - dirname is the name of the directory to scan
-- - names is the font database to fill
-- - recursive is whether we scan all directories recursively (always false
--       in this script)
-- - texmf is a boolean saying if we are scanning a texmf directory (always
--       true in this script)
local function scan_dir(dirname, fontnames, status, newfontnames, newstatus, recursive, texmf)
    local list, found = { }, { }
    local nbfound = 0
    for _,ext in ipairs { "otf", "ttf", "ttc", "dfont" } do
        if recursive then pat = "/**." else pat = "/*." end
        if trace_search then
            logs.report("scanning '%s' for '%s' fonts", dirname, ext)
        end
        found = glob(dirname .. pat .. ext)
        -- note that glob fails silently on broken symlinks, which happens
        -- sometimes in TeX Live.
        if trace_search then
            logs.report("%s fonts found", #found)
        end
        nbfound = nbfound + #found
        table.append(list, found)
        if trace_search then
            logs.report("scanning '%s' for '%s' fonts", dirname, upper(ext))
        end
        found = glob(dirname .. pat .. upper(ext))
        table.append(list, found)
        nbfound = nbfound + #found
    end
    if trace_search then
        logs.report("%d fonts found in '%s'", nbfound, dirname)
    end
    for _,fnt in ipairs(list) do
        fnt = path_normalize(fnt)
        load_font(fnt, fontnames, status, newfontnames, newstatus, texmf)
    end
end

-- The function that scans all fonts in the texmf tree, through kpathsea
-- variables OPENTYPEFONTS and TTFONTS of texmf.cnf
local function scan_texmf_tree(fontnames, status, newfontnames, newstatus)
    if trace_progress then
        if expandpath("$OSFONTDIR"):is_empty() then
            logs.report("scanning TEXMF fonts:")
        else
            logs.report("scanning TEXMF and OS fonts:")
        end
    end
    local fontdirs = expandpath("$OPENTYPEFONTS")
    fontdirs = fontdirs .. string.gsub(expandpath("$TTFONTS"), "^\.", "")
    if not fontdirs:is_empty() then
        local explored_dirs = {}
        fontdirs = splitpath(fontdirs)
        -- hack, don't scan current dir
        table.remove(fontdirs, 1)
        count = 0
        for _,d in ipairs(fontdirs) do
            if not explored_dirs[d] then
                count = count + 1
                progress(count, #fontdirs)
                scan_dir(d, fontnames, status, newfontnames, newstatus, false, true)
                explored_dirs[d] = true
            end
        end
    end
end

-- this function takes raw data returned by fc-list, parses it, normalizes the
-- paths and makes a list out of it.
local function read_fcdata(data)
    local list = { }
    for line in data:lines() do
        line = line:gsub(": ", "")
        local ext = string.lower(string.match(line,"^.+%.([^/\\]-)$"))
        if ext == "otf" or ext == "ttf" or ext == "ttc" or ext == "dfont" then
            list[#list+1] = path_normalize(line:gsub(": ", ""))
        end
    end
    return list
end

-- This function scans the OS fonts through fontcache (fc-list), it executes
-- only if OSFONTDIR is empty (which is the case under most Unix by default).
-- If OSFONTDIR is non-empty, this means that the system fonts it contains have
-- already been scanned, and thus we don't scan them again.
local function scan_os_fonts(fontnames, status, newfontnames, newstatus)
    if expandpath("$OSFONTDIR"):is_empty() then 
        if trace_progress then
            logs.report("scanning OS fonts:")
        end
        if trace_search then
            logs.report("executing 'fc-list : file' and parsing its result...")
        end
        local data = io.popen("fc-list : file", 'r')
        local list = read_fcdata(data)
        data:close()
        if trace_search then
            logs.report("%d fonts found", #list)
        end
        count = 0
        for _,fnt in ipairs(list) do
            count = count + 1
            progress(count, #list)
            load_font(fnt, fontnames, status, newfontnames, newstatus, false)
        end
    end
end

local function fontnames_init()
    return {
        mappings  = { },
        families  = { },
        version   = names.version,
    }
end

local function status_init()
    return {
        version   = names.version,
    }
end

-- The main function, scans everything
-- - fontnames is the final table to return
-- - force is whether we rebuild it from scratch or not
-- - status is a table containing the current status of the database 
local function update(fontnames, status, force, purge)
    if force then
        fontnames = fontnames_init()
        status = status_init()
    else
        if not fontnames or not fontnames.version or fontnames.version ~= names.version
                or not status or not status.version or status.version ~= names.version then
            fontnames = fontnames_init()
            status = status_init()
            if trace_search then
                logs.report("no font names database or old one found, generating new one")
            end
        end
    end
    local newfontnames = nil
    local newstatus    = nil
    if purge then
        newfontnames = fontnames_init()
        newstatus    = status_init()
    end
    scan_texmf_tree(fontnames, status, newfontnames, newstatus)
    scan_os_fonts  (fontnames, status, newfontnames, newstatus)
    if purge then
        return newfontnames, newstatus
    else
        return fontnames, status
    end
end

names.scan   = scan_dir
names.update = update
