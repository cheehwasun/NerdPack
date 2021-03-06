local _, NeP = ...

NeP.CombatTracker = {}

-- Thse are Mixed Damage types (magic and pysichal)
local Doubles = {
	[3]   = 'Holy + Physical',
	[5]   = 'Fire + Physical',
	[9]   = 'Nature + Physical',
	[17]  = 'Frost + Physical',
	[33]  = 'Shadow + Physical',
	[65]  = 'Arcane + Physical',
	[127] = 'Arcane + Shadow + Frost + Nature + Fire + Holy + Physical',
}

--[[ This Logs the damage done for every unit ]]
local logDamage = function(...)
	local _,_,_, SourceGUID, _,_,_, DestGUID, _,_,_, spellID, _, school, Amount = ...
	local DestObj = NeP.OM:FindObjectByGuid(DestGUID)
	local SourceObj = NeP.OM:FindObjectByGuid(SourceGUID)
	-- Mixed
	if Doubles[school] then
		if DestObj and DestObj.combat_tack_enable then
			DestObj.dmgTaken_P = DestObj.dmgTaken_P + Amount
			DestObj.dmgTaken_M = DestObj.dmgTaken_M + Amount
		end
		if SourceObj and SourceObj.combat_tack_enable then
			SourceObj.dmgDone_P = SourceObj.dmgDone_P + Amount
			SourceObj.dmgDone_M = SourceObj.dmgDone_M + Amount
		end
	-- Pysichal
	elseif school == 1  then
		if DestObj and DestObj.combat_tack_enable then
			DestObj.dmgTaken_P = DestObj.dmgTaken_P + Amount
		end
		if SourceObj and SourceObj.combat_tack_enable then
			SourceObj.dmgDone_P = SourceObj.dmgDone_P + Amount
		end
	-- Magic
	else
		if DestObj and DestObj.combat_tack_enable then
			DestObj.dmgTaken_M = DestObj.dmgTaken_M + Amount
		end
		if SourceObj and SourceObj.combat_tack_enable then
			SourceObj.dmgDone_M = SourceObj.dmgDone_M + Amount
		end
	end
	local ctime = NeP._G.GetTime()
	-- Totals
	if DestObj and DestObj.combat_tack_enable then
		DestObj.dmgTaken = DestObj.dmgTaken + Amount
		DestObj.hits_taken = DestObj.hits_taken + 1
		DestObj.hits_done = DestObj.hits_done + 1
		DestObj.last_hit_taken_time = ctime
		if DestObj.combat_time == 0 then
			DestObj.combat_time = ctime
		end
	end
	if SourceObj and SourceObj.combat_tack_enable then
		SourceObj.dmgDone = SourceObj.dmgDone + Amount
		SourceObj[spellID] = ((SourceObj[spellID] or Amount) + Amount) / 2
		SourceObj.last_hit_done_time = ctime
		if SourceObj.combat_time == 0 then
			SourceObj.combat_time = ctime
		end
	end
end

--[[ This Logs the swings (damage) done for every unit ]]
local logSwing = function(...)
	local _,_,_, SourceGUID, _,_,_, DestGUID, _,_,_, Amount = ...
	local DestObj = NeP.OM:FindObjectByGuid(DestGUID)
	local SourceObj = NeP.OM:FindObjectByGuid(SourceGUID)
	if DestObj and DestObj.combat_tack_enable then
		DestObj.dmgTaken_P = DestObj.dmgTaken_P + Amount
		DestObj.dmgTaken = DestObj.dmgTaken + Amount
		DestObj.hits_taken = DestObj.hits_taken + 1
	end
	if SourceObj and SourceObj.combat_tack_enable then
		SourceObj.dmgDone_P = SourceObj.dmgDone_P + Amount
		SourceObj.dmgDone = SourceObj.dmgDone + Amount
		SourceObj.hits_done = SourceObj.hits_done + 1
	end
end

--[[ This Logs the healing done for every unit
		 !!~counting selfhealing only for now~!!]]
local logHealing = function(...)
	local _,_,_, SourceGUID, _,_,_, DestGUID, _,_,_, spellID, _,_, Amount = ...
	local DestObj = NeP.OM:FindObjectByGuid(DestGUID)
	local SourceObj = NeP.OM:FindObjectByGuid(SourceGUID)
	if DestObj and DestObj.combat_tack_enable then
		DestObj.heal_taken = DestObj.heal_taken + Amount
		DestObj.heal_hits_taken = DestObj.heal_hits_taken + 1
	end
	if SourceObj and SourceObj.combat_tack_enable then
		SourceObj.heal_done = SourceObj.heal_done + Amount
		SourceObj.heal_hits_done = SourceObj.heal_hits_done + 1
		SourceObj[spellID] = ((SourceObj[spellID] or Amount) + Amount) / 2
	end
end

--[[ This Logs the last action done for every unit ]]
local addAction = function(...)
	local _,_,_, SourceGUID, _,_,_,_, destName, _,_,_, spellName = ...
	if not spellName then return end
	if SourceGUID == NeP.DSL:Get('guid')('player') and destName then
		local icon = select(3, NeP._G.GetSpellInfo(spellName))
		NeP.ActionLog:Add('Spell Cast Succeed', spellName, icon, destName)
	end
	local obj = NeP.OM:FindObjectByGuid(SourceGUID)
	if obj then
		obj.lastcast = spellName
	end
end

local UnitBuffL = NeP.Core.UnitBuffL
local UnitDebuffL = NeP.Core.UnitDebuffL

local addAura = function(...)
	local _,_,_, SourceGUID, _,_,_, DestGUID, _,_,_, spellId, spellName, _, auraType = ...
	local DestObj = NeP.OM:FindObjectByGuid(DestGUID)
	if not DestObj then return end
	local arrType = auraType == 'BUFF' and 'buffs' or 'debuffs'
	if not DestObj[arrType] then return end -- this unit is not tracking buffs/debuffs
	local func = auraType == 'BUFF' and UnitBuffL or UnitDebuffL
	-- delay everything one frame / tick?
	-- some buffs are wierd, they have a one frame / tick delay (maybe...)
	NeP._G.C_Timer.After(0, function()
		local xname, count, expiration, caster, type, isStealable, isBoss, duration = func(DestObj.key, spellName)
		if not xname then return end --huh?
		local found = DestObj[arrType][spellName] or DestObj[arrType][spellId]
		local data = found or {}
		data.isCastByPlayer = SourceGUID == NeP.DSL:Get('guid')('player')
		data.SourceGUID = SourceGUID
		data.spellId = spellId
		data.spellName = spellName
		data.auraType = auraType
		data.type = type
		data.count = count
		data.isStealable = isStealable
		data.isBoss = isBoss
		data.expiration = expiration
		data.duration = duration
		data.caster = caster
		DestObj[arrType][spellName] = data
		DestObj[arrType][spellId] = data
	end)
end

local removeAura = function(...)
	local _,_,_, _, _,_,_, DestGUID, _,_,_, spellId, spellName, _, auraType = ...
	local DestObj = NeP.OM:FindObjectByGuid(DestGUID)
	local arrType = auraType == 'BUFF' and 'buffs' or 'debuffs'
	if DestObj and DestObj[arrType] then
		DestObj[arrType][spellName] = nil
		DestObj[arrType][spellId] = nil
	end
end

--local auraStack = function(...)
	--local _,_,_, SourceGUID, _,_,_, GUID, _,_,_, spellId, spellName, _, auraType, amount = ...
	--print(amount)
--end

--[[ These are the events we're looking for and its respective action ]]
local EVENTS = {
	['SPELL_DAMAGE'] = logDamage,
	['DAMAGE_SHIELD'] = logDamage,
	['SPELL_PERIODIC_DAMAGE']	= logDamage,
	['SPELL_BUILDING_DAMAGE']	= logDamage,
	['RANGE_DAMAGE'] = logDamage,
	['SWING_DAMAGE'] = logSwing,
	['SPELL_HEAL'] = logHealing,
	['SPELL_PERIODIC_HEAL'] = logHealing,
	['UNIT_DIED'] = function(...)
		local _,_,_, _, _,_,_, DestGUID = ...
		local Obj = NeP.OM:FindObjectByGuid(DestGUID)
		if not Obj or not (Obj.tbl == 'Friendly' or Obj.tbl == 'Enemy') then
			return
		end
		NeP.OM:MoveObjectByGuid(DestGUID, 'Dead')
	end,
	['SPELL_CAST_SUCCESS'] = addAction,
	["SPELL_AURA_REFRESH"] = addAura,
	["SPELL_AURA_APPLIED"] = addAura,
	["SPELL_PERIODIC_AURA_APPLIED"] = addAura,
	["SPELL_AURA_REMOVED"] = removeAura,
	["SPELL_PERIODIC_AURA_REMOVED"] = removeAura,
	--["SPELL_AURA_APPLIED_DOSE"] = auraStack,
	--["SPELL_PERIODIC_AURA_APPLIED_DOSE"] = auraStack,
	--["SPELL_AURA_REMOVED_DOSE"] = auraStack,
	--["SPELL_PERIODIC_AURA_REMOVED_DOSE"] = auraStack,
}

--[[ Returns the total ammount of time a unit is in-combat for ]]
function NeP.CombatTracker.CombatTime(_, unit)
	local Obj = NeP.OM:FindObjectByGuid(NeP.DSL:Get('guid')(unit))
	if Obj and Obj.combat_tack_enable then
		return NeP._G.GetTime() - Obj.combat_time
	end
	return 0
end

function NeP.CombatTracker:getDMG(unit)
	local total, Hits, phys, magic = 0, 0, 0, 0
	local Obj = NeP.OM:FindObjectByGuid(NeP.DSL:Get('guid')(unit))
	if Obj and Obj.combat_tack_enable and Obj.dmgTaken then
		local combatTime = self:CombatTime(unit)
		total = Obj.dmgTaken / combatTime
		phys = Obj.dmgTaken_P / combatTime
		magic = Obj.dmgTaken_M / combatTime
		Hits = Obj.hits_taken
	end
	return total, Hits, phys, magic
end

function NeP.CombatTracker:TimeToDie(unit)
	local ttd = nil
	local DMG, Hits = self:getDMG(unit)
	if DMG >= 1 and Hits > 1 then
		ttd = NeP.DSL:Get('health.actual')(unit) / DMG
	end
	return ttd or 8675309
end

function NeP.CombatTracker.LastCast(_, unit)
	local Obj = NeP.OM:FindObjectByGuid(NeP.DSL:Get('guid')(unit))
	return Obj and Obj.combat_tack_enable and Obj.lastcast
end

function NeP.CombatTracker.SpellDamage(_, unit, spellID)
  local Obj = NeP.OM:FindObjectByGuid(NeP.DSL:Get('guid')(unit))
  return Obj and Obj.combat_tack_enable and Obj[spellID] or 0
end

local function doStuff(...)
	local _, EVENT, _, SourceGUID, _,_,_, DestGUID = ...
	local DestObj = NeP.OM:FindObjectByGuid(DestGUID)
	local SourceObj = NeP.OM:FindObjectByGuid(SourceGUID)
	-- Update last  hit time
	if DestObj and DestObj.combat_tack_enable then
		DestObj.lastHit_taken = NeP._G.GetTime()
	end
	if SourceObj and SourceObj.combat_tack_enable then
		SourceObj.lastHit_done = NeP._G.GetTime()
	end
	-- Add the amount of dmg/heak
	if EVENTS[EVENT] then EVENTS[EVENT](...) end
end

NeP.Listener:Add('NeP_CombatTracker', 'COMBAT_LOG_EVENT_UNFILTERED', function()
	doStuff(NeP._G.CombatLogGetCurrentEventInfo())
end)
