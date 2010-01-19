if not modules then modules = { } end modules ['font-xtx'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local texsprint, count = tex.sprint, tex.count
local format, concat, gmatch, match, find, lower = string.format, table.concat, string.gmatch, string.match, string.find, string.lower
local tostring, next = tostring, next
local lpegmatch = lpeg.match

local trace_defining = false  trackers.register("fonts.defining", function(v) trace_defining = v end)

--[[ldx--
<p>Choosing a font by name and specififying its size is only part of the
game. In order to prevent complex commands, <l n='xetex'/> introduced
a method to pass feature information as part of the font name. At the
risk of introducing nasty parsing and compatinility problems, this
syntax was expanded over time.</p>

<p>For the sake of users who have defined fonts using that syntax, we
will support it, but we will provide additional methods as well.
Normally users will not use this direct way, but use a more abstract
interface.</p>

<p>The next one is the official one. However, in the plain
variant we need to support the crappy [] specification as
well and that does not work too well with the general design
of the specifier.</p>
--ldx]]--

--~ function fonts.define.specify.colonized(specification) -- xetex mode
--~     local list = { }
--~     if specification.detail and specification.detail ~= "" then
--~         for v in gmatch(specification.detail,"%s*([^;]+)%s*") do
--~             local a, b = match(v,"^(%S*)%s*=%s*(%S*)$")
--~             if a and b then
--~                 list[a] = b:is_boolean()
--~                 if type(list[a]) == "nil" then
--~                     list[a] = b
--~                 end
--~             else
--~                 local a, b = match(v,"^([%+%-]?)%s*(%S+)$")
--~                 if a and b then
--~                     list[b] = a ~= "-"
--~                 end
--~             end
--~         end
--~     end
--~     specification.features.normal = list
--~     return specification
--~ end

--~ check("oeps/BI:+a;-b;c=d")
--~ check("[oeps]/BI:+a;-b;c=d")
--~ check("file:oeps/BI:+a;-b;c=d")
--~ check("name:oeps/BI:+a;-b;c=d")

local list = { }

fonts.define.specify.colonized_default_lookup = "file"

local function isstyle(s)
    local style  = string.lower(s):split("/")
    for _,v in ipairs(style) do
        if v == "b" then
            list.style = "bold"
        elseif v == "i" then
            list.style = "italic"
        elseif v == "bi" or v == "ib" then
            list.style = "bolditalic"
        end
    end
end
local function issome ()    list.lookup = fonts.define.specify.colonized_default_lookup end
local function isfile ()    list.lookup = 'file' end
local function isname ()    list.lookup = 'name' end
local function thename(s)   list.name   = s end
local function issub  (v)   list.sub    = v end
local function istrue (s)   list[s]     = 'yes' end
--KH local function isfalse(s)   list[s]     = 'no' end
local function isfalse(s)   list[s]     = nil end -- see mpg/luaotfload#4
local function iskey  (k,v) list[k]     = v end

local spaces     = lpeg.P(" ")^0
local namespec   = (1-lpeg.S("/:("))^0 -- was: (1-lpeg.S("/: ("))^0
local crapspec   = spaces * lpeg.P("/") * (((1-lpeg.P(":"))^0)/isstyle) * spaces
local filename   = (lpeg.P("file:")/isfile * (namespec/thename)) + (lpeg.P("[") * lpeg.P(true)/isname * (((1-lpeg.P("]"))^0)/thename) * lpeg.P("]"))
local fontname   = (lpeg.P("name:")/isname * (namespec/thename)) + lpeg.P(true)/issome * (namespec/thename)
local sometext   = (lpeg.R("az") + lpeg.R("AZ") + lpeg.R("09"))^1
local truevalue  = lpeg.P("+") * spaces * (sometext/istrue)
local falsevalue = lpeg.P("-") * spaces * (sometext/isfalse)
local someval    = (lpeg.S("+-.") + sometext)^1
local keyvalue   = (lpeg.C(sometext) * spaces * lpeg.P("=") * spaces * lpeg.C(someval))/iskey
local somevalue  = sometext/istrue
local subvalue   = lpeg.P("(") * (lpeg.C(lpeg.P(1-lpeg.S("()"))^1)/issub) * lpeg.P(")") -- for Kim
local option     = spaces * (keyvalue + falsevalue + truevalue + somevalue) * spaces
local options    = lpeg.P(":") * spaces * (lpeg.P(";")^0  * option)^0
local pattern    = (filename + fontname) * subvalue^0 * crapspec^0 * options^0

function fonts.define.specify.colonized(specification) -- xetex mode
    list = { }
    lpegmatch(pattern,specification.specification)
    for k, v in next, list do
        list[k] = v:is_boolean()
        if type(list[a]) == "nil" then
            list[k] = v
        end
    end
    if list.style then
        specification.style = list.style
        list.style = nil
    end
    if list.name then
        specification.name = list.name
        list.name = nil
    end
    if list.lookup then
        specification.lookup = list.lookup
        list.lookup = nil
    end
    if list.sub then
        specification.sub = list.sub
        list.sub = nil
    end
    specification.features.normal = list
    return specification
end

fonts.define.register_split(":", fonts.define.specify.colonized)
