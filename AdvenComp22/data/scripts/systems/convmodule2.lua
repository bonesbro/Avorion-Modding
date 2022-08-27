package.path = package.path .. ";data/scripts/systems/?.lua"
package.path = package.path .. ";data/scripts/lib/?.lua"
include ("basesystem")
include ("utility")
include ("randomext")

materialLevel = 0

--local highlightColor = ColorRGB(1.0, 1.0, 1.0)

local interestingEntities = {}
local baseCooldown = 40.0
local cooldown = 40.0
local remainingCooldown = 0.0 -- no initial cooldown
local highlightDuration = 30.0
local highlightRange = 0
local highlightTime = nil
local tooltipName = "Object Detection"%_t

-- optimization so that energy requirement doesn't have to be read every frame
FixedEnergyRequirement = true
Unique = true

function getBonuses(seed, rarity)
	math.randomseed(seed)

    local lootRange = (rarity.value + 2 + getFloat(0.0, 0.75)) * 2 * (1.3 ^ rarity.value) * 10 -- one unit is 10 meters
    lootRange = round(lootRange)

    local deepScan = (math.max(0, getInt(rarity.value, rarity.value * 1.5)) + 1) * 2
    local radar = (math.max(0, getInt(rarity.value, rarity.value * 2.0)) + 1) * 1.5

    local highlightRange = 1000 + (1500 * rarity.value) + (math.random() * 1000)
	highlightRange = math.max(highlightRange, 1000)
	
    local cooldown = baseCooldown
	if rarity.value >= RarityType.Rare then
        cooldown = baseCooldown
    elseif rarity.value >= RarityType.Uncommon then
        cooldown = baseCooldown + highlightDuration * 0.5
    elseif rarity.value >= RarityType.Common then
        cooldown = baseCooldown + highlightDuration
    elseif rarity.value >= RarityType.Petty then
        cooldown = baseCooldown + highlightDuration * 3
    end

    local dockRange = (rarity.value / 2 + 1 + round(getFloat(0.0, 0.4), 1)) * 100

    local scanner = 5 -- base value, in percent
    -- add flat percentage based on rarity
    scanner = scanner + (rarity.value + 2) * 15 -- add +15% (worst rarity) to +105% (best rarity)

    -- add randomized percentage, span is based on rarity
    scanner = scanner + math.random() * ((rarity.value + 1) * 15) -- add random value between +0% (worst rarity) and +90% (best rarity)
    scanner = scanner / 50

    return lootRange, deepScan, radar, highlightRange, dockRange, scanner, cooldown
end

function onInstalled(seed, rarity, permanent)
    local lootRange, deepScan, radar, localhighlightRange, dockRange, scanner, localcooldown = getBonuses(seed, rarity)
	highlightRange = localhighlightRange
	cooldown = localcooldown

    addAbsoluteBias(StatsBonuses.LootCollectionRange, lootRange)
    addAbsoluteBias(StatsBonuses.HiddenSectorRadarReach, deepScan)
    addAbsoluteBias(StatsBonuses.RadarReach, radar)
    addBaseMultiplier(StatsBonuses.ScannerReach, scanner)
	
	if permanent then
	    addAbsoluteBias(StatsBonuses.TransporterRange, dockRange)
	end
	
    if onClient() then
        local player = Player()
        if valid(player) then
            player:registerCallback("onPreRenderHud", "onPreRenderHud")
            player:registerCallback("onPreRenderHud", "sendMessageForValuables")
        end
		
        sendMessageForValuables()		
    end

end

function onUninstalled(seed, rarity, permanent)
end

function getComparableValues(seed, rarity)
    local _, _, _, highlightRange, _, scanner, cooldown = getBonuses(seed, rarity, false)

    local base = {}
    local bonus = {}
    table.insert(base, {name = "Highlight Range"%_t, key = "highlight_range", value = round(highlightRange / 100), comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Highlight Duration"%_t, key = "highlight_duration", value = round(highlightDuration), comp = UpgradeComparison.MoreIsBetter})
    table.insert(base, {name = "Detection Range"%_t, key = "detection_range", value = 1, comp = UpgradeComparison.MoreIsBetter})
    table.insert(base, {name = "Scanner Range"%_t, key = "range", value = round(scanner * 100), comp = UpgradeComparison.MoreIsBetter})
    table.insert(bonus, {name = "Scanner Range"%_t, key = "range", value = round(scanner * 100), comp = UpgradeComparison.MoreIsBetter})
    table.insert(base, {name = "Cooldown"%_t, key = "cooldown", value = cooldown, comp = UpgradeComparison.LessIsBetter})

    return base, bonus
end

function getName(seed, rarity)
    return "Universal Adventuring Companion"%_t
end

function getIcon(seed, rarity)
    return "data/textures/icons/fusion-core.png"
end

function getEnergy(seed, rarity, permanent)
    local lootRange, _, _, highlightRange, _, _, _ = getBonuses(seed, rarity)
    highlightRange = math.min(highlightRange, 1500)

    return highlightRange * 1000 * 1000 / (1.2 ^ rarity.value)
end

function getPrice(seed, rarity)
    local lootRange, _, _, highlightRange, _, _, _ = getBonuses(seed, rarity)
    highlightRange = math.min(highlightRange, 1500)

    local lootPrice = 400 * lootRange
    local highlightPrice = 35 * (highlightRange * 1.5)

    return lootPrice + highlightPrice
end

function getTooltipLines(seed, rarity, permanent)
    local lootRange, deepScan, radar, highlightRange, dockRange, scanner, cooldown = getBonuses(seed, rarity)

    local bonuses = {}
    local texts = {}
	
	if lootRange ~= 0 then
        table.insert(texts, {ltext = "Loot Collection Range"%_t, rtext = "+${distance} km"%_t % {distance = lootRange / 100}, icon = "data/textures/icons/sell.png"})
	end
	
	if deepScan ~= 0 then
        table.insert(texts, {ltext = "Deep Scan Range"%_t, rtext = string.format("%+i", deepScan), icon = "data/textures/icons/radar-sweep.png"})
	end
	
	if radar ~= 0 then
        table.insert(texts, {ltext = "Radar Range"%_t, rtext = string.format("%+i", radar), icon = "data/textures/icons/radar-sweep.png"})
	end

    if scanner ~= 0 then
        table.insert(texts, {ltext = "Scanner Range"%_t, rtext = string.format("%+i%%", round(scanner * 100)), icon = "data/textures/icons/signal-range.png"})
    end
	
	-- this one only takes effect if it's installed permanently
	if dockrange ~= 0 then
		if permanent then
			table.insert(texts, {ltext = "Docking Distance"%_t, rtext = "+${distance} km"%_t % {distance = dockRange / 100}, icon = "data/textures/icons/solar-system.png", boosted = permanent})
		end
		table.insert(bonuses, {ltext = "Docking Distance"%_t, rtext = "+${distance} km"%_t % {distance = dockRange / 100}, icon = "data/textures/icons/solar-system.png"})
	end

	if highlightRange ~= 0 then
		--table.insert(texts, {}) -- empty line
		--table.insert(texts, {ltext = "Detection Range"%_t, rtext = "Sector"%_t, icon = "data/textures/icons/rss.png"})

		local rangeText = string.format("%g km"%_t, round(highlightRange / 100, 2))
		table.insert(texts, {ltext = "Highlight Range"%_t, rtext = rangeText, icon = "data/textures/icons/rss.png"})
		table.insert(texts, {ltext = "Highlight Duration"%_t, rtext = string.format("%s", createReadableShortTimeString(highlightDuration)), icon = "data/textures/icons/hourglass.png"})
		table.insert(texts, {ltext = "Cooldown"%_t, rtext = string.format("%s", createReadableShortTimeString(cooldown)), icon = "data/textures/icons/hourglass.png"})
	end
	
    return texts, bonuses
end

function getDescriptionLines(seed, rarity, permanent)
    return
    {
        {ltext = "One ping only, please."%_t, lcolor = ColorRGB(1, 0.5, 0.5)},
    }
end

--------------------------- Begin vanilla valueablesdetector.lua ---------------------------

function updateClient(timeStep)
    if remainingCooldown > 0.0 then
        remainingCooldown = math.max(0, remainingCooldown - timeStep)
    end

    if highlightTime then
        highlightTime = highlightTime - timeStep
        if highlightTime <= 0.0 then
            highlightTime = nil
            interestingEntities = {}
        end
    end
end

function onDetectorButtonPressed()
    -- set cooldown and highlightTime on both client and server
    remainingCooldown = cooldown
    highlightTime = highlightDuration

    interestingEntities = collectHighlightableObjects()

    playSound("scifi-sonar", SoundType.UI, 0.5)

    -- notify player that entities were found
    if tablelength(interestingEntities) > 0 then
        deferredCallback(3, "showNotification", "Valuable objects detected."%_t)
    else
        deferredCallback(3, "showNotification", "Nothing found here."%_t)
    end

    interestingEntities = filterHighlightableObjects(interestingEntities)
end

function showNotification(text)
    displayChatMessage(text, "Object Detector"%_t, ChatMessageType.Information)

end

function onSectorChanged()
    if onClient() then
        sendMessageForValuables()
    end
end

function interactionPossible(playerIndex, option)
    local player = Player(playerIndex)
    if not player then return false, "" end

    local craftId = player.craftIndex
    if not craftId then return false, "" end

    if craftId ~= Entity().index then
        return false, ""
    end

    if remainingCooldown > 0.0 then
        return false, ""
    end

    return true
end

function initUI()
    ScriptUI():registerInteraction(tooltipName, "onDetectorButtonPressed", -1);
end

function getUIButtonCooldown()
    local tooltipText = ""

    if remainingCooldown > 0 then
        local duration = math.max(0.0, remainingCooldown)
        local minutes = math.floor(duration / 60)
        local seconds = duration - minutes * 60
        tooltipText = tooltipName .. ": " .. string.format("%02d:%02d", math.max(0, minutes), math.max(0.01, seconds))
    else
        tooltipText = tooltipName
    end

    return remainingCooldown / cooldown, tooltipText
end

function collectHighlightableObjects()
    local player = Player()
    if not valid(player) then return end

    local self = Entity()
    if player.craftIndex ~= self.index then return end

    local objects = {}

    -- normal entities
    for _, entity in pairs({Sector():getEntitiesByScriptValue("valuable_object")}) do
        local value = entity:getValue("highlight_color") or entity:getValue("valuable_object")

        if entity.dockingParent ~= self.id then
            if type(value) == "string" then
                objects[entity.id] = {entity = entity, color = Color(value)}
            else
                objects[entity.id] = {entity = entity, color = Rarity(value).color}
            end
        end
    end

    -- wreckages with black boxes
    -- black box wreckages are always tagged as Petty
    for _, entity in pairs({Sector():getEntitiesByScriptValue("blackbox_wreckage")}) do
        if entity.dockingParent ~= self.id then
            objects[entity.id] = {entity = entity, color = ColorRGB(0.3, 0.9, 0.9)}
        end
    end

    return objects
end

function filterHighlightableObjects(objects)
    -- no need to sort out if none of the found entities will be marked
    if highlightRange == 0 then
        return {}
    end

    -- remove all entities that are too far away and shouldn't be marked
    local range2 = highlightRange * highlightRange
    local center = Entity().translationf
    for id, entry in pairs(objects) do
        if valid(entry.entity) then
            if distance2(center, entry.entity.translationf) > range2 then
                objects[id] = nil
            end
        end
    end

    return objects
end

local automaticMessageDisplayed
function sendMessageForValuables()
    if automaticMessageDisplayed then return end

    local player = Player()
    if not valid(player) then return end

    local self = Entity()
    if player.craftIndex ~= self.index then return end

    local objects = collectHighlightableObjects()

    -- notify player that entities were found
    if tablelength(objects) > 0 then
        displayChatMessage("Valuable objects detected."%_t, "Object Detector"%_t, ChatMessageType.Information)
        automaticMessageDisplayed = true
    end
end

function onPreRenderHud()
    if not highlightRange or highlightRange == 0 then return end

    local player = Player()
    if not player then return end
    if player.state == PlayerStateType.BuildCraft or player.state == PlayerStateType.BuildTurret then return end

    local self = Entity()
    if player.craftIndex ~= self.index then return end

    if tablelength(interestingEntities) == 0 then return end

    -- detect all objects in range
    local renderer = UIRenderer()

    local range = lerp(highlightTime, highlightDuration, highlightDuration - 5, 0, 100000, true)
    local range2 = range * range
    local center = self.translationf

    for id, object in pairs(interestingEntities) do
        if not valid(object.entity) then
            interestingEntities[id] = nil
            goto continue
        end

        if distance2(object.entity.translationf, center) < range2 then
            renderer:renderEntityTargeter(object.entity, object.color);
        end

        ::continue::
    end

    renderer:display()
end

function getControlAction()
    return ControlAction.ScriptQuickAccess2
end
---------------------------  End vanilla valueablesdetector.lua  ---------------------------
