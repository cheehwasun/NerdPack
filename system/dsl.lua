NeP.DSL = {
	Conditions = {}
}

local DSL = NeP.DSL

local OPs = {
	['>='] = function(arg1, arg2) return arg1 >= arg2 end,
	['<='] = function(arg1, arg2) return arg1 <= arg2 end,
	['=='] = function(arg1, arg2) return arg1 == arg2 end,
	['~='] = function(arg1, arg2) return arg1 ~= arg2 end,
	['>'] = function(arg1, arg2) return arg1 > arg2 end,
	['<'] = function(arg1, arg2) return arg1 < arg2 end,
	['+'] = function(arg1, arg2) return arg1 + arg2 end,
	['-'] = function(arg1, arg2) return arg1 - arg2 end,
	['/'] = function(arg1, arg2) return arg1 / arg2 end,
	['*'] = function(arg1, arg2) return arg1 * arg2 end,
	['true'] = function() return true end,
	['false'] = function() return false end,
}

local function DoMath(arg1, arg2, token)
	local arg1, arg2 = tonumber(arg1), tonumber(arg2)
	--print(arg1, arg2)
	if arg1 ~= nil and arg2 ~= nil then
		--print(OPs[token](arg1, arg2))
		return OPs[token](arg1, arg2)
	end
end

local function _AND(Strg, spell)
	local Arg1, Arg2 = Strg:match('(.-)&(.+)')
	--print('AND 0',Arg1, Arg2)
	local Arg1 = DSL.Parse(Arg1, spell)
	--print('AND 1', Arg1)
	if not Arg1 then return false end -- Dont process anything in front sence we already failed
	local Arg2 = DSL.Parse(Arg2, spell)
	--print('AND 2', Arg1, Arg2)
	return Arg1 and Arg2
end

local function _OR(Strg, spell)
	local Arg1, Arg2 = Strg:match('(.-)|(.+)')
	local Arg1 = DSL.Parse(Arg1, spell)
	if Arg1 then return false end -- Dont process anything in front sence we already hit
	local Arg2 = DSL.Parse(Arg2, spell)
	return Arg1 or Arg2
end

local function Nest(Strg, spell)
	local first, second = Strg:find('({.-})')
	local Result = DSL.Parse(Strg:sub(first + 1, second - 1) , spell)
	Strg = Strg:sub(1, first - 1) .. tostring(Result or false) .. Strg:sub(second + 1)
	return DSL.Parse(Strg, spell)
end

local function ProcessCondition(Strg, Args)
	if DSL.Conditions[Strg] then
		return DSL.Get(Strg)('player', Args)
	end
	local unitId, rest = strsplit('.', Strg, 2)
	local unitId = NeP.Engine.FilterUnit(unitId)
	if UnitExists(unitId) then
		return DSL.Get(rest)(unitId, Args)
	end
end

local function ProcessString(Strg, spell)
	local Strg = Strg
	if Strg:find('%a') then
		local Args = Strg:match('%((.+)%)')
		if Args then 
			Args = NeP.Locale.Spells(Args) -- Translates the name to the correct locale
			Strg = Strg:gsub('%((.+)%)', '')
		end
		Strg = Strg:gsub('%s', '')
		return ProcessCondition(Strg, (Args or spell))
	end
	return Strg:gsub('%s', '')
end

local fOps = {['!='] = '~=',['='] = '=='}
local function FindComparator(Strg)
	local OP = Strg:match('[><=!~]')
	local Strg = Strg:gsub(OP, '')
	local OP2 = Strg:match('[><=!~]')
	if OP2 then Strg = Strg:gsub(OP2, '') end
	local OP = OP..(OP2 or '')
	local StringOP = OP
	if fOps[OP] then OP = fOps[OP] end
	return StringOP, OP
end

local function Comperatores(Strg, spell)
	local StringOP, OP = FindComparator(Strg)
	local arg1, arg2 = unpack(NeP.string_split(Strg, StringOP))
	local arg1, arg2 = DSL.Parse(arg1, spell), DSL.Parse(arg2, spell)
	return DoMath(arg1, arg2, OP)
end

local function StringMath(Strg, spell)
	local OP, total = Strg:match('[%+%-%*%/]'), 0
	--print('MATH 0', Strg)
	local tempT = NeP.string_split(Strg, OP)
	for i=1, #tempT do
		local Strg = DSL.Parse(tempT[i], spell)
		--print('MATH 1', Strg)
		total = DoMath(total, Strg, OP)
	end
	--print('MATH 2', Strg)
	return total
end

-- Routes
local typesTable = {
	['function'] = function(dsl, spell) return dsl() end,
	['table'] = function(dsl, spell)
		local r_Tbl = {[1] = true}
		for _,String in ipairs(dsl) do
			if String == 'or' then
				r_Tbl[#r_Tbl+1] = true
			elseif r_Tbl[#r_Tbl] then
				local eval = DSL.Parse(String, spell)
				r_Tbl[#r_Tbl] = eval or false
			end
		end
		for i = 1, #r_Tbl do
			if r_Tbl[i] then
				return true
			end
		end
		return false
	end,
	['string'] = function(Strg, spell)
		if string.sub(Strg, 1, 1) == '!' then
			local Strg = string.sub(Strg, 2)
			return not DSL.Parse(Strg, spell)
		elseif Strg:find('{(.-)}') then
			return Nest(Strg, spell)
		elseif Strg:find('|') then
			return _OR(Strg, spell)
		elseif Strg:find('&') then
			return _AND(Strg, spell)
		elseif Strg:find('[><=!~]') then
			return Comperatores(Strg, spell)
		elseif Strg:find("[%+%-%*%/]") then
			return StringMath(Strg)
		elseif OPs[Strg] then
			return OPs[Strg](Strg, spell)
		else
			return ProcessString(Strg, spell)
		end
	end,
	['nil'] = function(dsl, spell) return true end,
	['boolean']	 = function(dsl, spell) return dsl end,
}

function DSL.Get(condition)
	if condition then
		local condition = string.lower(condition)
		if DSL.Conditions[condition] then
			return DSL.Conditions[condition]
		end
	end
	return (function() end)
end

function DSL.RegisterConditon(name, condition, overwrite)
	local name = string.lower(name)
	if not DSL.Conditions[name] or overwrite then
		DSL.Conditions[name] = condition
	end
end

function DSL.Parse(dsl, spell)
	--print(dsl)
	if typesTable[type(dsl)] then
		return typesTable[type(dsl)](dsl, spell)
	end
end