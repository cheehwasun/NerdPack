local n_name, NeP = ...

NeP.Debug = {}
NeP.Debug.Profiles = {}
NeP.Debug.Profiles.total_usage = 0
NeP.Debug.Profiles.total_average = 0

_G.SetCVar("scriptProfile", "1")

NeP.Core:WhenInGame(function()
	NeP.Interface:Add(n_name..' Debugger', function() _G.texplore(NeP) end)
end)

function NeP.Debug:Add(name, func, subroutines)
	table.insert(self.Profiles, {
		name = name,
		func = func,
		subroutines = subroutines,
    max = 0,
    min = 0,
    average = 0
	})
end

local function GetAvg(a, b)
  return a == 0 and b or (a+b)/2
end

local tbl = NeP.Debug.Profiles
_G.C_Timer.NewTicker(1, function()
  tbl.total_usage = 0
	for i=1, #tbl do
		local usage, calls = _G.GetFunctionCPUUsage(tbl[i].func, tbl[i].subroutines)
		tbl[i].cpu_time = usage
		tbl[i].calls = calls
    tbl[i].time_call = calls > 0 and usage/calls or 0
    tbl[i].average = GetAvg(tbl[i].average, usage)
    tbl[i].max = tbl[i].max > usage and tbl[i].max or usage
    tbl[i].min = tbl[i].min < usage and tbl[i].min or usage
    tbl.total_usage = tbl.total_usage + usage
    tbl.total_average = GetAvg(tbl.total_average, tbl.total_usage)
	end
	_G.ResetCPUUsage()
end, nil)

NeP.Globals.Debug = {
	Add =  NeP.Debug.Add
}
