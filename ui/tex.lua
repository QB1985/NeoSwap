-- tex.lua : pictures from NeoSwap's images folder, loaded once (the same way YunaUI loads its own)
local ffi = require('ffi');
local d3d = require('d3d8');
local imgui = require('imgui');

local tex = {};
local cache = {};

function tex.get(name)
    local t = cache[name];
    if t ~= nil then return t or nil; end
    cache[name] = false;
    pcall(function()
        local f = io.open(addon.path .. '/images/' .. name, 'rb');
        if f == nil then return; end
        local data = f:read('*a');
        f:close();
        local ptr = ffi.new('IDirect3DTexture8*[1]');
        if ffi.C.D3DXCreateTextureFromFileInMemoryEx(d3d.get_device(), data, #data, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0,
                ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 0, nil, nil, ptr) == ffi.C.S_OK then
            local t2 = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', ptr[0]));
            cache[name] = { tex = t2, ptr = tonumber(ffi.cast('uint32_t', t2)) };
        end
    end);
    return cache[name] or nil;
end

-- A job's emblem (images/jobs/war.png ...), drawn at a screen position; tint alpha a
function tex.job(dl, abbr, x, y, size, a)
    local t = tex.get('jobs/' .. abbr:lower() .. '.png');
    if t == nil then return false; end
    local col = imgui.GetColorU32({ 1, 1, 1, a or 1 });
    pcall(function() dl:AddImage(t.ptr, { x, y }, { x + size, y + size }, { 0, 0 }, { 1, 1 }, col); end);
    return true;
end

function tex.unload()
    for _, t in pairs(cache) do
        if t then pcall(function() ffi.gc(t.tex, nil); t.tex:Release(); end); end
    end
    cache = {};
end

return tex;
