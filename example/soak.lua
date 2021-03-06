-- a lua version of
-- https://github.com/libvips/pyvips/blob/master/examples/soak-test.py
-- this should run in a steady amount of memory

local vips = require "vips"

vips.leak_set(true)
vips.cache_set_max(0)

if #arg ~= 2 then
    print("usage: luajit soak.lua image-file iterations")
    error()
end

local im

for i = 0, tonumber(arg[2]) do
    print("loop ", i)

    im = vips.Image.new_from_file(arg[1])
    im = im:embed(100, 100, 3000, 3000, { extend = "mirror" })
    -- local buf = im:write_to_buffer(".jpg")
    -- im:write_to_file("x.jpg")
    im:write_to_file("x.v")
    im = nil -- luacheck: ignore

    collectgarbage()
end
