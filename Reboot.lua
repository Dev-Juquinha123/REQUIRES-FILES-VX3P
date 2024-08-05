local hooks = require("hooks")

local speed = 0.25
local original_GetButtonSprintResults

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

function main()
    while not isSampAvailable() do wait(0) end
    original_GetButtonSprintResults = hooks.jmp.new("float(__thiscall*)(void* CPlayerPed, int sprintType)", GetButtonSprintResults_hooked, 0x60A820)
    wait(-1)
end
