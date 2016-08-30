require "mods"
local IsDST = MOD_API_VERSION >= 10
local IsRoG = IsDLCEnabled(REIGN_OF_GIANTS)
if IsDST then
  IsRoG = true
end

function debugprint(fnname, ...)
  if fnname == nil then fnname = "" end
  --print(GLOBAL.debug.traceback())
  local name = debug.getinfo(2,"n").name or ""
  local currentline = debug.getinfo(2,"l").currentline or ""
  local dbgstr = "== "..name.." ( "..fnname.." ) @ "..currentline
  local n = {...}
  for i in pairs(n) do
    dbgstr = dbgstr .. " | "
    dbgstr = dbgstr .. tostring(n[i])
  end
  print(dbgstr)
end

local function GetTheWorld()
  local world
  if IsDST then
    world = TheWorld
  else
    world = GetWorld()
  end
  return world
end

local Sproutable = Class(function(self, inst)
  self.sproutable = self
  self.sprout = nil
  self.instsprout = nil
  self.inststump = inst
end)

function Sproutable:SpawnPrefabStumpSprout()
  --debugprint("Sproutable:SpawnPrefabStumpSprout")
  if self.instsprout then self.instsprout:Remove() end
  self.instsprout = SpawnPrefab("stumpsprout")
  self.sprout = self.instsprout.components.sprout
  self.instsprout.Transform:SetPosition(0,0,0)
  self.instsprout.Transform:SetScale(1,1,1)
  self.inststump:AddChild(self.instsprout)
  self.instsprout.components.sprout.inststump = self.inststump
end

function Sproutable:MakeWithered(product_prefab)
  --debugprint("Sproutable:MakeWithered")
  self:SpawnPrefabStumpSprout()
  self:OnSproutWithered(product_prefab)
end

function Sproutable:MakeGrowTree(product_prefab)
  --debugprint("Sproutable:MakeGrowTree")
  self:SpawnPrefabStumpSprout()
  self:OnSproutGrowTree(product_prefab)
end

function Sproutable:MakeGrowVeggie(product_prefab)
  --debugprint("Sproutable:MakeGrowVeggie")
  self:SpawnPrefabStumpSprout()
  self:OnSproutGrowVeggie(product_prefab)
end

function Sproutable:MakeGrowFlower(product_prefab, flowername)
  --debugprint("Sproutable:MakeGrowFlower")
  self:SpawnPrefabStumpSprout()
  self:OnSproutGrowFlower(product_prefab, flowername)
end

function Sproutable:MakeGrowPlant()
  --debugprint("Sproutable:MakeGrowPlant")
  self:SpawnPrefabStumpSprout()
  self:OnSproutGrowPlant()
end

function Sproutable:MakeGrowSapling()
  --debugprint("Sproutable:MakeGrowSapling")
  self:SpawnPrefabStumpSprout()
  self:OnSproutGrowSapling()
end

function Sproutable:MakeGrowSprout()
  --debugprint("Sproutable:MakeGrowSprout")
  self:SpawnPrefabStumpSprout()
  self:OnSproutGrowSprout()
end

function Sproutable:MakeStartGrowing()
  --debugprint("Sproutable:MakeStartGrowing")
  self:SpawnPrefabStumpSprout()
  self:OnSproutStartGrowing()
end

function Sproutable:MakePlantSeed()
  --debugprint("Sproutable:MakePlantSeed")
  self:SpawnPrefabStumpSprout()
  self:OnSproutPlantSeed()
end

-------------------------------------------------------------------------------

function Sproutable:OnSproutWithered(product_prefab)
  --debugprint("Sproutable:OnSproutWithered")
  self.sprout:OnSproutWithered(self, product_prefab)
  self.instsprout.OnSproutWithered(self, product_prefab)
  self.inststump.OnSproutWithered(self, product_prefab)
end

function Sproutable:OnSproutGrowTree(product_prefab)
  --debugprint("Sproutable:OnSproutGrowTree")
  self.sprout:OnSproutGrowTree(self, product_prefab)
  self.instsprout.OnSproutGrowTree(self, product_prefab)
  self.inststump.OnSproutGrowTree(self, product_prefab)
end

function Sproutable:OnSproutGrowVeggie(product_prefab)
  --debugprint("Sproutable:OnSproutGrowVeggie", product_prefab)
  self.sprout:OnSproutGrowVeggie(self, product_prefab)
  self.instsprout.OnSproutGrowVeggie(self, product_prefab)
  self.inststump.OnSproutGrowVeggie(self, product_prefab)
end

function Sproutable:OnSproutGrowFlower(product_prefab, flowername)
  --debugprint("Sproutable:OnSproutGrowFlower", product_prefab, flowername)
  self.sprout:OnSproutGrowFlower(self, product_prefab, flowername)
  self.instsprout.OnSproutGrowFlower(self, product_prefab, flowername)
  self.inststump.OnSproutGrowFlower(self, product_prefab, flowername)
end

function Sproutable:OnSproutGrowPlant()
  --debugprint("Sproutable:OnSproutGrowPlant")
  self.sprout:OnSproutGrowPlant(self)
  self.instsprout.OnSproutGrowPlant(self)
  self.inststump.OnSproutGrowPlant(self)
end

function Sproutable:OnSproutGrowSapling()
  --debugprint("Sproutable:OnSproutGrowSapling")
  self.sprout:OnSproutGrowSapling(self)
  self.instsprout.OnSproutGrowSapling(self)
  self.inststump.OnSproutGrowSapling(self)
end

function Sproutable:OnSproutGrowSprout()
  --debugprint("Sproutable:OnSproutGrowSprout")
  self.sprout:OnSproutGrowSprout(self)
  self.instsprout.OnSproutGrowSprout(self)
  self.inststump.OnSproutGrowSprout(self)
end

function Sproutable:OnSproutStartGrowing()
  --debugprint("Sproutable:OnSproutStartGrowing")
  self.sprout:OnSproutStartGrowing(self)
  self.instsprout.OnSproutStartGrowing(self)
  self.inststump.OnSproutStartGrowing(self)
end

function Sproutable:OnSproutPlantSeed()
  --debugprint("Sproutable:OnSproutPlantSeed")
  self.sprout:OnSproutPlantSeed(self)
  self.instsprout.OnSproutPlantSeed(self)
  self.inststump.OnSproutPlantSeed(self)
end

function Sproutable:OnSproutFertilize(fertilizer)
  --debugprint("Sproutable:OnSproutFertilize")
  self.sprout:OnSproutFertilize(self, fertilizer)
  self.instsprout.OnSproutFertilize(self, fertilizer)
  self.inststump.OnSproutFertilize(self, fertilizer)
end

function Sproutable:OnSproutHarvest(picker)
  --debugprint("Sproutable:OnSproutHarvest")
  self.sprout:OnSproutHarvest(self, picker)
  self.instsprout.OnSproutHarvest(self, picker)
  self.inststump.OnSproutHarvest(self, picker)
end

return Sproutable
