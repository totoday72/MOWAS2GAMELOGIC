require([[/script/multiplayer/bot.data]])

local Context = {
	Purchase = nil,
	SpawnInfo = nil,
	SquadTimers = {}
}

local PIter = {}
PIter.__index = PIter

function PIter:new(data)
	local obj = {
		idx = nil,
		rpt = nil,
		purchases = data
	}
	self.nextIndex(obj)
	return setmetatable(obj, self)
end

function PIter:current()
	if self.idx then
		return self.purchases[self.idx].Units
	end
end

function PIter:nextIndex()
	self.idx = next(self.purchases, self.idx)
	if self.idx then
		self.rpt = self.purchases[self.idx].Repeat
	else
		self.rpt = nil
	end
end

function PIter:moveNext()
	if not self.rpt or self.rpt == 0 then
		return
	end
	
	self.rpt = self.rpt - 1

	if self.rpt == 0 then
		self:nextIndex()
	end
end

function GetRandomItem(items, getRate)
	local item_rates = {}
	
	local total = 0
	for i, item in pairs(items) do
		local rate = getRate(item)
		
		total = total + rate
		table.insert(item_rates, {i = item, r = rate})
	end
	
	local rnd = math.random()
	local bound = 0.0
	
	for j, item_rate in pairs(item_rates) do
		bound = bound + item_rate.r
		if rnd < bound / total then
			return item_rate.i
		end
	end
end

function IsCapturedFlag(flag)
	return flag.occupant == BotApi.Instance.team
end

function IsEnemyFlag(flag)
	return flag.occupant == BotApi.Instance.enemyTeam
end

function GetFlagPriority(flag)
	if		IsCapturedFlag(flag)then return FlagPriority.Captured
	elseif	IsEnemyFlag(flag)	then return FlagPriority.Enemy
	else 							 return FlagPriority.Neutral
	end
end

function GetFlagToCapture(flagPoints, getPriority)
	local flags = {}
	
	for i, flag in pairs(flagPoints) do
		table.insert(flags, {name = flag.name, k = getPriority(flag)})
	end
	
	return GetRandomItem(flags, function(f) return f.k end)
end

function GetNextUnitToSpawn(purchase)
	local units = purchase:current()
	
	if not units then
		return nil
	end
	
	local unit = GetUnitToSpawn(units[BotApi.Instance.army])
	purchase:moveNext()
	return unit
end

function GetUnitToSpawn(units)
	if not units then
		return nil
	end
	
	local unitsToSpawn = {}
	
	local teamSize = BotApi.Instance.teamSize
	local income = BotApi.Commands:Income(BotApi.Instance.playerId)
	
	for i, unit in pairs(units) do
		local min_income = unit.min_income
		local min_team = unit.min_team
		
		if not min_income then min_income = -1 end
		if not min_team then min_team = 0 end
		
		if teamSize >= min_team and income >= min_income then
			table.insert(unitsToSpawn, unit)
		end
	end
	
	if #unitsToSpawn == 0 then
		return nil
	end
	
	local capturedFlags, enemyFlags = 0, 0
	for i, flag in pairs(BotApi.Scene.Flags) do
		if IsCapturedFlag(flag) then
			capturedFlags = capturedFlags + 1
		end
		if IsEnemyFlag(flag) then
			enemyFlags = enemyFlags + 1
		end
	end
	
	local enemyHasTanks = BotApi.Commands:EnemyHasTanks();
	
	return GetRandomItem(unitsToSpawn, function(t)
		if capturedFlags < enemyFlags and t.class == UnitClass.Infantry then
			return t.priority * 2.5
		end
		
		if not enemyHasTanks and t.class == UnitClass.ATTank then
			return 0
		end
		
		if enemyHasTanks and (t.class == UnitClass.ATInfantry or
							  t.class == UnitClass.ATTank) then
			return t.priority * 2
		end
		return t.priority
	end)
end

function UpdateUnitToSpawn(purchase)
	Context.SpawnInfo = GetNextUnitToSpawn(purchase)
end

function OnGameStart()
	math.randomseed(os.time()*BotApi.Instance.hostId)
	math.random() math.random() math.random()
	
	Context.Purchase = PIter:new(Purchases)
	UpdateUnitToSpawn(Context.Purchase)
end

function OnGameStop()
	for squad, timer in pairs(Context.SquadTimers) do
		if timer then
			BotApi.Events:KillQuantTimer(timer)
		end
	end
end

function OnGameQuant()
	if not Context.SpawnInfo or BotApi.Commands:Spawn(Context.SpawnInfo.unit, MaxSquadSize) then
		UpdateUnitToSpawn(Context.Purchase)
	end
	
	for i, squad in pairs(BotApi.Scene.Squads) do
		if not Context.SquadTimers[squad] then
			SetSquadOrder(CaptureFlag, squad, OrderRotationPeriod)
		end
	end
end

function CaptureFlag(squad)
	local flag = GetFlagToCapture(BotApi.Scene.Flags, GetFlagPriority)
	if flag then
		BotApi.Commands:CaptureFlag(squad, flag.name)
	end
end

function SetSquadOrder(order, squad, delay)
	order(squad)
	local setTimer = function(callback)
		Context.SquadTimers[squad] = BotApi.Events:SetQuantTimer(
			function()
				order(squad)
				Context.SquadTimers[squad] = nil
				if BotApi.Scene:IsSquadExists(squad) then
					callback(callback)
				end
			end,
			delay)
	end
	setTimer(setTimer)
end

function OnGameSpawn(args)
	SetSquadOrder(CaptureFlag, args.squadId, OrderRotationPeriod)
end

BotApi.Events:Subscribe(BotApi.Events.GameStart, OnGameStart)
BotApi.Events:Subscribe(BotApi.Events.GameEnd, OnGameStop)
BotApi.Events:Subscribe(BotApi.Events.Quant, OnGameQuant)
BotApi.Events:Subscribe(BotApi.Events.GameSpawn, OnGameSpawn)
