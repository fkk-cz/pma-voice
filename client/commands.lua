local wasProximityDisabledFromOverride = false
disableProximityCycle = false
RegisterCommand('setvoiceintent', function(source, args)
	if GetConvarInt('voice_allowSetIntent', 1) == 1 then
		local intent = args[1]
		if intent == 'speech' then
			MumbleSetAudioInputIntent(`speech`)
		elseif intent == 'music' then
			MumbleSetAudioInputIntent(`music`)
		end
		LocalPlayer.state:set('voiceIntent', intent, true)
	end
end)

-- TODO: Better implementation of this?
RegisterCommand('vol', function(_, args)
	if not args[1] then return end
	setVolume(tonumber(args[1]))
end)

exports('setAllowProximityCycleState', function(state)
	type_check({state, "boolean"})
	disableProximityCycle = state
end)

function setProximityState(proximityRange, isCustom)
	local voiceModeData = Cfg.voiceModes[mode]
	MumbleSetTalkerProximity(proximityRange + 0.0)
	LocalPlayer.state:set('proximity', {
		index = mode,
		distance = proximityRange,
		mode = isCustom and "Custom" or voiceModeData[2],
	}, false)
	sendUIMessage({
		-- JS expects this value to be - 1, "custom" voice is on the last index
		voiceMode = isCustom and #Cfg.voiceModes or mode - 1
	})
end

exports("overrideProximityRange", function(range, disableCycle)
	type_check({range, "number"})
	setProximityState(range, true)
	if disableCycle then
		disableProximityCycle = true
		wasProximityDisabledFromOverride = true
	end
end)

exports("clearProximityOverride", function()
	local voiceModeData = Cfg.voiceModes[mode]
	setProximityState(voiceModeData[1], false)
	if wasProximityDisabledFromOverride then
		disableProximityCycle = false
	end
end)

RegisterCommand('cyclevoiceproximity', function()
	-- Proximity is either disabled, or manually overwritten.
	if GetConvarInt('voice_enableProximityCycle', 1) ~= 1 or disableProximityCycle then return end
	local newMode = mode + 1

	-- If we're within the range of our voice modes, allow the increase, otherwise reset to the first state
	if newMode <= #Cfg.voiceModes then
		mode = newMode
	else
		mode = 1
	end

	setProximityState(Cfg.voiceModes[mode][1], false)
	TriggerEvent('pma-voice:setTalkingMode', mode)
end, false)
if gameVersion == 'fivem' then
	RegisterKeyMapping('cyclevoiceproximity', 'Cycle Proximity', 'keyboard', GetConvar('voice_defaultCycle', 'GRAVE'))
end

function DisableMegaphone()
	LocalPlayer.state:set("megaphoneEnabled", false, true)
	MumbleSetAudioInputIntent(`speech`)

	local voiceModeData = Cfg.voiceModes[mode]
	setProximityState(voiceModeData[1], false)

	if wasProximityDisabledFromOverride then
		disableProximityCycle = false
	end

	exports["mythic_notify"]:PersistentAlert("end", "megaphoneStatus")
end

AddEventHandler("pma-voice:activeMegaphone", ToggleMegaphone)
function ToggleMegaphone()
	if isDead() then
		return
	end

	if GetInvokingResource() == nil then -- Invoked by command, most likely from this resource
		if not IsPedInAnyVehicle(PlayerPedId(), false) then
			return
		end

		local veh = GetVehiclePedIsIn(PlayerPedId(), false)
		if GetVehicleClass(veh) ~= 18 then
			return
		end

		if GetPedInVehicleSeat(veh, -1) ~= PlayerPedId() and GetPedInVehicleSeat(veh, 0) ~= PlayerPedId() then
			return
		end
	else
		if megaphoneEnabled then
			megaphoneEnabled = false
			DisableMegaphone()
			return
		end

		Citizen.CreateThread(function()
			local startPos = GetEntityCoords(PlayerPedId())

			while #(startPos - GetEntityCoords(PlayerPedId())) < 1.0 and not IsPedInAnyVehicle(PlayerPedId(), true) and not isDead() do
				if IsControlJustPressed(0, 73) then
					break
				end
				Citizen.Wait(0)
			end

			megaphoneEnabled = false
			DisableMegaphone()
		end)
	end

	megaphoneEnabled = not megaphoneEnabled

	if megaphoneEnabled then
		LocalPlayer.state:set("megaphoneEnabled", true, true)
		MumbleSetAudioInputIntent(`music`)

		local range = GetConvarInt("voice_megaphoneRange", 25)
		setProximityState(range, true)

		disableProximityCycle = true
		wasProximityDisabledFromOverride = true

		exports["mythic_notify"]:PersistentAlert("start", "megaphoneStatus", "inform", "/!\\ P.A. ON - Radio Disabled", { ['background-color'] = '#ff0000', ['color'] = '#000000'} )
	else
		DisableMegaphone()
	end
end

RegisterCommand('togglemegaphone', ToggleMegaphone, false)
if gameVersion == 'fivem' then
	RegisterKeyMapping('togglemegaphone', 'Toggle Megaphone / P.A.', 'keyboard', 'k')
end