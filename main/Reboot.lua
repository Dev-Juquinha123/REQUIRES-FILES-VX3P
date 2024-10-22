local hooks = require("hooks")
local ffi = require("ffi")
local speed = 0.25
local original_GetButtonSprintResults
local originalBytes

function GetButtonSprintResults_hooked(CPlayerPed, sprintType)
    local result = original_GetButtonSprintResults(CPlayerPed, sprintType)
    result = result + speed
    return result
end

function setSpeed(newSpeed)
    speed = newSpeed
end

EXPORTS = {
    setSpeed = setSpeed,
}

function saveOriginalBytes(address, size)
    local bytes = ffi.new("uint8_t[?]", size)
    ffi.copy(bytes, ffi.cast("void*", address), size)
    return bytes
end

function restoreOriginalBytes(address, originalBytes, size)
    local oldProtect = ffi.new("unsigned long[1]")
    ffi.C.VirtualProtect(ffi.cast("void*", address), size, 0x40, oldProtect)
    ffi.copy(ffi.cast("void*", address), originalBytes, size)
    ffi.C.VirtualProtect(ffi.cast("void*", address), size, oldProtect[0], oldProtect)
end

function main()
    while not isSampAvailable() do wait(0) end

    -- Salve os bytes originais da função que deseja hookar
    originalBytes = saveOriginalBytes(0x60A820, 5)

    -- Instale o hook
    original_GetButtonSprintResults = hooks.jmp.new("float(__thiscall*)(void* CPlayerPed, int sprintType)", GetButtonSprintResults_hooked, 0x60A820)

    -- Verifique se algum conflito ocorreu e restaure os bytes originais se necessário
    if originalBytes[0] == 0xE9 or originalBytes[0] == 0xE8 then
        print("[WARNING] Outro hook detectado, restaurando bytes originais...")
        restoreOriginalBytes(0x60A820, originalBytes, 5)
    end

    wait(-1)
end
