std = "lua51+reaper"

stds.reaper = {
    globals = { "reaper", "gfx" },
    read_globals = { "RPR_ShimVersion" },
}

max_line_length = 120

exclude_files = {
    "lua_modules/",
    "luarocks/",
    ".lua_env/",
}

files["spec/**/*.lua"] = {
    std = "+busted",
}
