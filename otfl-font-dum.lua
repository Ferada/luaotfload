if not modules then modules = { } end modules ['font-dum'] = {
    version   = 1.001,
    comment   = "companion to luatex-*.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

fonts = fonts or { }

-- general

fonts.otf.pack       = false
fonts.tfm.resolve_vf = false -- no sure about this

-- readers

fonts.tfm.readers          = fonts.tfm.readers or { }
fonts.tfm.readers.sequence = { 'otf', 'ttf', 'tfm' }
fonts.tfm.readers.afm      = nil

-- define

fonts.define = fonts.define or { }

--~ fonts.define.method = "tfm"

fonts.define.specify.colonized_default_lookup = "name"

function fonts.define.get_specification(str)
    return "", str, "", ":", str
end

-- logger

fonts.logger = fonts.logger or { }

function fonts.logger.save()
end

-- names
--
-- Watch out, the version number is the same as the one used in
-- the mtx-fonts.lua function scripts.fonts.names as we use a
-- simplified font database in the plain solution and by using
-- a different number we're less dependent on context.

fonts.names = fonts.names or { }

fonts.names.version    = 2.002 -- not the same as in context
fonts.names.basename   = "otfl-names.lua"
fonts.names.new_to_old = { }
fonts.names.old_to_new = { }

local data, loaded = nil, false

local synonyms = {
    regular     = {"normal", "roman", "plain", "book", "medium"},
    italic      = {"regularitalic", "normalitalic", "oblique", "slant"},
    bolditalic  = {"boldoblique", "boldslant"},
}

local function sanitize(str)
    return string.gsub(string.lower(str), "[^%a%d]", "")
end

function fonts.names.resolve(specification)
    local name, style = specification.name, specification.style or "regular"
    if not loaded then
        local basename = fonts.names.basename
        if basename and basename ~= "" then
            for _, format in ipairs { "lua", "tex", "other text files" } do
                local foundname = resolvers.find_file(basename,format) or ""
                if foundname ~= "" then
                    data = dofile(foundname)
                    break
                end
            end
        end
        loaded = true
    end
    if type(data) == "table" and data.version == fonts.names.version then
        if data.mappings then
            local family = data.families[name]
            if family and type(family) == "table" then
                for _,v in ipairs(family) do
                   local face      = data.mappings[v]
                   local subfamily = face.names.subfamily
                   local rqssize   = tonumber(specification.optsize) or specification.size and specification.size / 65536
                   local dsnsize   = face.size[1] and face.size[1] / 10
                   local maxsize   = face.size[2] and face.size[2] / 10
                   local minsize   = face.size[3] and face.size[3] / 10
                   local filename  = face.filename
                   if subfamily then
                       if sanitize(subfamily) == style then
                           if not dsnsize or dsnsize == rqssize or (rqssize > minsize and rqssize <= maxsize) then
                               found = filename
                               break
                           end
                       else
                           if synonyms[style] then
                               for _,v in ipairs(synonyms[style]) do
                                   if sanitize(subfamily) == v then
                                       if not dsnsize or dsnsize == rqssize or (rqssize > minsize and rqssize <= maxsize) then
                                            found = filename
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
    end
    logs.report("define font", "Font names database version mismatch")
end

fonts.names.resolvespec = fonts.names.resolve -- only supported in mkiv

-- For the moment we put this (adapted) pseudo feature here.

table.insert(fonts.triggers,"itlc")

local function itlc(tfmdata,value)
    if value then
        -- the magic 40 and it formula come from Dohyun Kim
        local metadata = tfmdata.shared.otfdata.metadata
        if metadata then
            local italicangle = metadata.italicangle
            if italicangle and italicangle ~= 0 then
                local uwidth = (metadata.uwidth or 40)/2
                for unicode, d in next, tfmdata.descriptions do
                    local it = d.boundingbox[3] - d.width + uwidth
                    if it ~= 0 then
                        d.italic = it
                    end
                end
                tfmdata.has_italic = true
            end
        end
    end
end

fonts.initializers.base.otf.itlc = itlc
fonts.initializers.node.otf.itlc = itlc

function fonts.register_message()
end
