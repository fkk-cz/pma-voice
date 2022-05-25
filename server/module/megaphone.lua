RegisterNetEvent("pma-voice:toggleMegaphone")
AddEventHandler(
    "pma-voice:toggleMegaphone",
    function(value)
        local _source = source
        TriggerClientEvent("pma-voice:toggleMegaphone", -1, _source, value)
    end
)
