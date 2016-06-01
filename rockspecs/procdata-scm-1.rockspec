package = "procdata"
version = "scm-1"

source = {
   url = "git://github.com/analuciadm/procdata"
}

description = {
   summary = "[[Lua access to Linux /proc data",
   detailed = [[
   ]],
}

dependencies = {
   "luaposix",
   "luafilesystem",
}

build = {
   type = "builtin",
   modules = {
     procdata = "procdata.lua",
   },
}
