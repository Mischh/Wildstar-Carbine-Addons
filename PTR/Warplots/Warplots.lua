-----------------------------------------------------------------------------------------------
-- Client Lua Script for Warplots
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
require "Apollo"
require "Sound"
require "GameLib"
require "PublicEvent"
require "MatchingGameLib"

local Warplots = {}

local LuaEnumBlueTeamInfo =
{
	Energy 			= 1495,
	Nanopacks 		= 2463,
	GeneratorNorth 	= 1387,
	GeneratorSouth 	= 1388,
}

local LuaEnumRedTeamInfo = 
{
	Energy 			= 1494,
	Nanopacks 		= 2441,
	GeneratorNorth 	= 1389,
	GeneratorSouth 	= 1390,
}

local LuaEnumControlPoints =
{
	BlueNorth 	= 1605,
	RedNorth 	= 1606,
	Center 		= 1607,
	RedSouth 	= 1608,
	BlueSouth 	= 1609,
}


function Warplots:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	
	o.tWndRefs = {}
	
	return o
end

function Warplots:Init()
	Apollo.RegisterAddon(self)
end

function Warplots:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("Warplots.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function Warplots:OnDocumentReady()
	if not self.xmlDoc then
		return
	end
	
	Apollo.RegisterTimerHandler("WarPlot_OneSecMatchTimer", "OnWarPlotOneSecMatchTimer", self)
	
	Apollo.RegisterEventHandler("ChangeWorld", 				"OnChangeWorld", self)
	Apollo.RegisterEventHandler("PublicEventStart",			"CheckForWarplot", self)
	Apollo.RegisterEventHandler("MatchEntered", 			"CheckForWarplot", self)
	
	Apollo.CreateTimer("WarPlot_OneSecMatchTimer", 1.0, true)
	Apollo.StopTimer("WarPlot_OneSecMatchTimer")
	
	self.tBlueInfo = {}
	self.tRedInfo = {}
	self.tControlPointInfo = {}
	self.peMatch = nil
	
	local uMatchMakingEntry = MatchingGameLib.GetQueueEntry()
	if uMatchMakingEntry and uMatchMakingEntry:IsPvpGame() then
		self:CheckForWarplot()
	end
end

function Warplots:OnChangeWorld()
	if self.tWndRefs.wndMain ~= nil and self.tWndRefs.wndMain:IsValid() then
		self.tWndRefs.wndMain:Close()
		self.tWndRefs.wndMain:Destroy()
	end
	self.tWndRefs = {}
	Apollo.StopTimer("WarPlot_OneSecMatchTimer")
	self.peMatch = nil
end

function Warplots:OnWarPlotOneSecMatchTimer()	
	if not self.peMatch then
		self:CheckForWarplot()
		return
	end
	
	if self.tWndRefs.wndMain == nil or not self.tWndRefs.wndMain:IsValid() then
		local wndMain = Apollo.LoadForm(self.xmlDoc, "WarplotsMain", "FixedHudStratumLow", self)
		self.tWndRefs.wndMain = wndMain
		self.tWndRefs.wndRedBar = wndMain:FindChild("RedBar")
		self.tWndRefs.wndBlueBar = wndMain:FindChild("BlueBar")
		
		self.tWndRefs.wndRedGeneratorN = Apollo.LoadForm(self.xmlDoc, "ClusterTargetMini", wndMain:FindChild("Red:Generator1"), self)
		self.tWndRefs.wndRedGeneratorS = Apollo.LoadForm(self.xmlDoc, "ClusterTargetMini", wndMain:FindChild("Red:Generator2"), self)
		self.tWndRefs.wndBlueGeneratorN = Apollo.LoadForm(self.xmlDoc, "ClusterTargetMini", wndMain:FindChild("Blue:Generator1"), self)
		self.tWndRefs.wndBlueGeneratorS = Apollo.LoadForm(self.xmlDoc, "ClusterTargetMini", wndMain:FindChild("Blue:Generator2"), self)
		
		wndMain:Invoke()
	end
	
	-- Building Red Team's Info
	self:DrawEnergy(self.tRedInfo[LuaEnumRedTeamInfo.Energy], self.tWndRefs.wndRedBar, self.tWndRefs.wndMain:FindChild("Red:CurrentProgress"))
	self.tWndRefs.wndMain:FindChild("Red:CurrencyValue"):SetText(self.tRedInfo[LuaEnumRedTeamInfo.Nanopacks]:GetCount()) -- Nanopacks
	self:DrawGenerator(self.tRedInfo[LuaEnumRedTeamInfo.GeneratorNorth], self.tWndRefs.wndRedGeneratorN, "Red")
	self:DrawGenerator(self.tRedInfo[LuaEnumRedTeamInfo.GeneratorSouth], self.tWndRefs.wndRedGeneratorS, "Red")
	
	-- Building Blue Team's Info
	self:DrawEnergy(self.tBlueInfo[LuaEnumBlueTeamInfo.Energy], self.tWndRefs.wndBlueBar, self.tWndRefs.wndMain:FindChild("Blue:CurrentProgress"))
	self.tWndRefs.wndMain:FindChild("Blue:CurrencyValue"):SetText(self.tBlueInfo[LuaEnumBlueTeamInfo.Nanopacks]:GetCount()) -- Nanopacks
	self:DrawGenerator(self.tBlueInfo[LuaEnumBlueTeamInfo.GeneratorNorth], self.tWndRefs.wndBlueGeneratorN, "Blue")
	self:DrawGenerator(self.tBlueInfo[LuaEnumBlueTeamInfo.GeneratorSouth], self.tWndRefs.wndBlueGeneratorS, "Blue")
	
	-- Draw Control Points
	self:DrawControlPoint(self.tControlPointInfo[LuaEnumControlPoints.BlueNorth], self.tWndRefs.wndMain:FindChild("BlueN"), 1)
	self:DrawControlPoint(self.tControlPointInfo[LuaEnumControlPoints.RedNorth], self.tWndRefs.wndMain:FindChild("RedN"), 2)
	self:DrawControlPoint(self.tControlPointInfo[LuaEnumControlPoints.Center], self.tWndRefs.wndMain:FindChild("Center"), 3)
	self:DrawControlPoint(self.tControlPointInfo[LuaEnumControlPoints.RedSouth], self.tWndRefs.wndMain:FindChild("RedS"), 4)
	self:DrawControlPoint(self.tControlPointInfo[LuaEnumControlPoints.BlueSouth], self.tWndRefs.wndMain:FindChild("BlueS"), 5)
end

function Warplots:DrawEnergy(peoEnergy, wndBar, wndProgress)
	local nMaxEnergy = peoEnergy:GetRequiredCount()
	local nCurrentEnergy = peoEnergy:GetCount()
	local strTeam = Apollo.GetString(peoEnergy:GetTeam() == self.peMatch:GetJoinedTeam() and "MatchTracker_MyTeam" or "MatchTracker_EnemyTeam")
		
	wndBar:SetMax(nMaxEnergy)
	wndBar:SetProgress(nCurrentEnergy)
	wndBar:SetStyleEx("EdgeGlow", nCurrentEnergy > 0 and nCurrentEnergy < nMaxEnergy)
	wndBar:SetTooltip(string.format("%s: %s / %s", strTeam, Apollo.FormatNumber(nCurrentEnergy, 0, true), Apollo.FormatNumber(nMaxEnergy, 0, true)))
	wndProgress:SetText(Apollo.FormatNumber(nCurrentEnergy / nMaxEnergy * 100, 1, true).."%")
end

function Warplots:DrawGenerator(peoGenerator, wndParent, strTeamColor)
	local nCurrentHP = peoGenerator:GetCount()
	local nMaxHP = peoGenerator:GetRequiredCount()
	local nHealthPCT = nCurrentHP / nMaxHP * 100
	local wndHealth = wndParent:FindChild("HealthTint")
			
	wndParent:Show(true)
			
	if nCurrentHP > 0 then
		wndParent:SetSprite(nHealthPCT > 20 and "spr_WarPlots_Generator_" .. strTeamColor or "anim_WarPlots_Generator_" .. strTeamColor)
		wndParent:FindChild("HealthValue"):SetText(Apollo.FormatNumber(nHealthPCT, 1, true).."%")
	else
		wndParent:SetSprite("spr_WarPlots_Generator_Inactive")
		wndParent:FindChild("HealthValue"):SetText("")
	end
			
	wndHealth:SetMax(100)
	wndHealth:SetProgress(nCurrentHP)
	wndHealth:SetTooltip(Apollo.FormatNumber(nCurrentHP))
	wndHealth:SetFullSprite("spr_WarPlots_Generator_Fill" .. strTeamColor)
end

function Warplots:DrawControlPoint(peoControlPoint, wndPoint, nIndex)		
	wndPoint:SetMax(100)
	wndPoint:SetProgress(100)
	wndPoint:SetFullSprite(peoControlPoint:GetOwningTeam() == 0 and "" or peoControlPoint:GetOwningTeam() == 6 and "spr_WarPlots_CP" .. nIndex .. "_RedCap" or "spr_WarPlots_CP" .. nIndex .. "_BlueCap")
end

function Warplots:CheckForWarplot()
	if not MatchingGameLib.GetPvpMatchState() or self.peMatch then
		return
	end

	for key, peCurrent in pairs(PublicEvent.GetActiveEvents()) do
		local eType = peCurrent:GetEventType()
		if eType == PublicEvent.PublicEventType_PVP_Warplot then
			self.peMatch = peCurrent
			
			for idx, idObjective in pairs(LuaEnumBlueTeamInfo) do
				self.tBlueInfo[idObjective] = self.peMatch:GetObjective(idObjective)
			end
			
			for idx, idObjective in pairs(LuaEnumRedTeamInfo) do
				self.tRedInfo[idObjective] = self.peMatch:GetObjective(idObjective)
			end
			
			for idx, idObjective in pairs(LuaEnumControlPoints) do
				self.tControlPointInfo[idObjective] = self.peMatch:GetObjective(idObjective)
			end
			
			Apollo.StartTimer("WarPlot_OneSecMatchTimer")
			return
		end
	end
	
	return
end

local WarplotsInstance = Warplots:new()
WarplotsInstance:Init()