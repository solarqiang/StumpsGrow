require "mods"

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

local IsDST = MOD_API_VERSION >= 10

local function GetTheWorld()
  local world
  if IsDST then
    world = TheWorld
  else
    world = GetWorld()
  end
  return world
end

local function IsSW() return GetTheWorld():HasTag("shipwrecked") or GetTheWorld():HasTag("volcano") end
local function IsRoG() return not IsSW() and (IsDST or GLOBAL.IsDLCEnabled(GLOBAL.REIGN_OF_GIANTS)) end

local Sprout = Class(function(self, inst)
  self.instsprout = inst
  --self.inststump = self.instsprout.entity:GetParent()
  self.inststump = nil
  self.product_prefab = nil
  --self.growthpercent = 0
  --self.rate = 1/120
  --self.task = nil
  self.matured = false
  --self.onmatured = nil

  self.witherable = false
  self.withered = false
  self.protected = false
  if IsRoG() then
    self.wither_temp = math.random(TUNING.MIN_PLANT_WITHER_TEMP, TUNING.MAX_PLANT_WITHER_TEMP)
  end
end)

--function Sprout:SetOnMatureFn(fn)
--  self.onmatured = fn
--end

--function Sprout:OnSave()
--  local data = 
--  {
--    prefab = self.product_prefab,
--    percent = self.growthpercent,
--    rate = self.rate,
--    matured = self.matured,
--    withered = self.withered,
--  }
--  return data
--end   

--function Sprout:OnLoad(data)
--  if data then
--     self.product_prefab = data.prefab or self.product_prefab
--     self.growthpercent = data.percent or self.growthpercent
--     self.rate = data.rate or self.rate
--     self.matured = data.matured or self.matured
--     self.withered = data.withered or self.withered
--  end

--  if self.withered then
--    self:MakeWithered()
--  else
--    self:DoGrow(0)
--    if self.product_prefab and self.matured then
--      self.inst.AnimState:PlayAnimation("grow_pst")
--      if self.onmatured then
--        self.onmatured(self.inst)
--      end
--    end
--  end
--end

function Sprout:IsWithered()
  return self.withered
end

function Sprout:RemoveAllTags()
  if self.instsprout:HasTag("plant") then self.instsprout:RemoveTag("plant") end
  if self.instsprout:HasTag("sapling") then self.instsprout:RemoveTag("sapling") end
  if self.instsprout:HasTag("sprout") then self.instsprout:RemoveTag("sprout") end
  if self.instsprout:HasTag("seed") then self.instsprout:RemoveTag("seed") end
  if self.instsprout:HasTag("withered") then self.instsprout:RemoveTag("withered") end
  if self.instsprout:HasTag("witherable") then self.instsprout:RemoveTag("witherable") end
  if self.instsprout:HasTag("readyforharvest") then self.instsprout:RemoveTag("readyforharvest") end
  if self.instsprout:HasTag("notreadyforharvest") then self.instsprout:RemoveTag("notreadyforharvest") end
end

function Sprout:OnRemoveFromEntity()
  self:RemoveAllTags()
end

function Sprout:MakeWitherable()
  self.witherable = true
  self:RemoveAllTags()
  self.instsprout:AddTag("witherable")
  self.instsprout:AddTag("notreadyforharvest")
  self.instsprout:ListenForEvent("witherplants", function(it, data) 
    if self.witherable and not self.withered and not self.protected and data.temp > self.wither_temp then
      self:MakeWithered("cutgrass")
    end
  end, GetTheWorld())
end

function Sprout:OnSproutWithered(sproutable, product_prefab)
  --assert(sproutable ~= nil)
  --debugprint("Sprout:OnSproutWithered")
  self.product_prefab = product_prefab
end

function Sprout:MakeWithered(product_prefab)
  --debugprint("Sprout:MakeWithered")
  self.product_prefab = product_prefab
  self:RemoveAllTags()
  self.instsprout:AddTag("withered")
  self.instsprout:AddTag("notreadyforharvest")

  self.withered = true
  --self.matured = false

--  if self.task then 
--    self.task:Cancel()
--    self.task = nil
--  end
--  self.product_prefab = "cutgrass"
--  self.growthpercent = 0
--  self.rate = 0
--  if not self.inst.components.burnable then
--    MakeMediumBurnable(self.inst)
--    MakeSmallPropagator(self.inst)
--  end

  self.inststump.components.sproutable:OnSproutWithered(product_prefab)
end

function Sprout:OnSproutGrowTree(sproutable, product_prefab)
  --assert(sproutable ~= nil)
  --debugprint("Sprout:OnSproutGrowTree")
  self.product_prefab = product_prefab
  self:RemoveAllTags()
  self.instsprout:AddTag("tree")
  self.instsprout:AddTag("notreadyforharvest")
end

function Sprout:OnSproutGrowVeggie(sproutable, product_prefab)
  --assert(sproutable ~= nil)
  --debugprint("Sprout:OnSproutGrowVeggie")
  self.product_prefab = product_prefab
  self:RemoveAllTags()
  self.instsprout:AddTag("veggie")
  self.instsprout:AddTag("readyforharvest")
end

function Sprout:OnSproutGrowFlower(sproutable, product_prefab, flowername)
  --assert(sproutable ~= nil)
  --debugprint("Sprout:OnSproutGrowFlower")
  self.product_prefab = product_prefab
  self:RemoveAllTags()
  self.instsprout:AddTag("flower")
  self.instsprout:AddTag("readyforharvest")
end

function Sprout:OnSproutGrowPlant(sproutable)
  --assert(sproutable ~= nil)
  --debugprint("Sprout:OnSproutGrowPlant")
  self:RemoveAllTags()
  self.instsprout:AddTag("plant")
  self.instsprout:AddTag("notreadyforharvest")
  self.withered = false
end

function Sprout:OnSproutGrowSapling(sproutable)
  --assert(sproutable ~= nil)
  --debugprint("Sprout:OnSproutGrowSapling")
  self:RemoveAllTags()
  self.instsprout:AddTag("sapling")
  self.instsprout:AddTag("notreadyforharvest")
  self.withered = false
end

function Sprout:OnSproutGrowSprout(sproutable)
  --assert(sproutable ~= nil)
  --debugprint("Sprout:OnSproutGrowSprout")
  self:RemoveAllTags()
  self.instsprout:AddTag("sprout")
  self.instsprout:AddTag("notreadyforharvest")
  self.withered = false
end

function Sprout:OnSproutStartGrowing(sproutable)
  --assert(sproutable ~= nil)
  --debugprint("Sprout:OnSproutStartGrowing")
  self.product_prefab = nil
  self:RemoveAllTags()
  self.instsprout:AddTag("stump")
  self.instsprout:AddTag("notreadyforharvest")
  self.withered = false
end

function Sprout:OnSproutPlantSeed(sproutable)
  --assert(sproutable ~= nil)
  --debugprint("Sprout:OnSproutPlantSeed")
  self:RemoveAllTags()
  self.instsprout:AddTag("seed")
  self.instsprout:AddTag("notreadyforharvest")
end

function Sprout:OnSproutFertilize(sproutable, fertilizer)
  --assert(sproutable ~= nil)
  --assert(fertilizer ~= nil)
  --debugprint("Sprout:OnSproutFertilize")
end

function Sprout:Fertilize(fertilizer)
  --debugprint("Sprout:Fertilize")
--  if self.inst.components.burnable then
--    self.inst.components.burnable:StopSmoldering()
--  end

--  if not (GetSeasonManager():IsWinter() and GetSeasonManager():GetCurrentTemperature() <= 0) then
--    self.growthpercent = self.growthpercent + fertilizer.components.fertilizer.fertilizervalue*self.rate
--    self.inst.AnimState:SetPercent("grow", self.growthpercent)
--    if self.growthpercent >=1 then
--       self.inst.AnimState:PlayAnimation("grow_pst")
--       self:Mature()
--       self.task:Cancel()
--       self.task = nil
--    end
--    if fertilizer.components.finiteuses then
--      fertilizer.components.finiteuses:Use()
--    else
--      fertilizer.components.stackable:Get(1):Remove()
--    end
--    return true
--  end

  local sproutstagebefore = self.inststump.stumpsproutstage
  local growtimebefore = self.inststump.growtime

  if self.inststump.components.sproutable.OnSproutFertilize then
    self.inststump.components.sproutable:OnSproutFertilize(fertilizer)
  end

  local sproutstageafter = self.inststump.stumpsproutstage
  local growtimeafter = self.inststump.growtime

  if (sproutstagebefore ~= nil and sproutstageafter ~= nil and sproutstagebefore < sproutstageafter) or
     (growtimebefore ~= nil and growtimeafter ~= nil and growtimebefore > growtimeafter)
  then
    if fertilizer.components.finiteuses then
      fertilizer.components.finiteuses:Use()
    else
      fertilizer.components.stackable:Get(1):Remove()
    end
    return true
  end
end

--function Sprout:DoGrow(dt)
--  if not self.withered then
--    local clock = GetClock()
--    local season = GetSeasonManager()

--    self.inst.AnimState:SetPercent("grow", self.growthpercent)

--    local weather_rate = 1

--    if season:GetTemperature() < TUNING.MIN_CROP_GROW_TEMP then
--      weather_rate = 0
--    else
--      --if season:GetTemperature() > TUNING.CROP_BONUS_TEMP then
--      --  weather_rate = weather_rate + TUNING.CROP_HEAT_BONUS
--      --end
--      if season:IsRaining() then
--        weather_rate = weather_rate + TUNING.CROP_RAIN_BONUS*season:GetPrecipitationRate()
--      elseif season:IsSpring() then
--        weather_rate = weather_rate + (TUNING.SPRING_GROWTH_MODIFIER/3)
--      end
--    end

--    local in_light = TheSim:GetLightAtPoint(self.inst.Transform:GetWorldPosition()) > TUNING.DARK_CUTOFF
--    if in_light then
--      self.growthpercent = self.growthpercent + dt*self.rate*weather_rate
--    end

--    if self.growthpercent >= 1 then
--      self.inst.AnimState:PlayAnimation("grow_pst")
--      self:Mature()
--      if self.task then
--        self.task:Cancel()
--        self.task = nil
--      end
--    end
--  end
--end

function Sprout:GetDebugString()
--  local s = "[" .. tostring(self.product_prefab) .. "] "
--  if self.matured then
--    s = s .. "DONE"
--  else
--    s = s .. string.format("%2.2f%% (done in %2.2f)", self.growthpercent, (1 - self.growthpercent)/self.rate)
--  end
--  s = s .. " || wither temp: " .. self.wither_temp
--  return s
end

--function Sprout:Resume()
--  if not self.matured and not self.withered then

--    if self.task then
--      scheduler:KillTask(self.task)
--    end
--    self.inst.AnimState:SetPercent("grow", self.growthpercent)
--    local dt = 2
--    self.task = self.inst:DoPeriodicTask(dt, function() self:DoGrow(dt) end)
--  end
--end

--function Sprout:StartGrowing(prod, grow_time, grower, percent)
--  self.product_prefab = prod
--  if self.task then
--    scheduler:KillTask(self.task)
--  end
--  self.rate = 1/ grow_time
--  self.growthpercent = percent or 0
--  self.inst.AnimState:SetPercent("grow", self.growthpercent)

--  local dt = 2
--  self.task = self.inst:DoPeriodicTask(dt, function() self:DoGrow(dt) end)
--  self.grower = grower
--end

function Sprout:OnSproutHarvest(sproutable, picker)
  --assert(sproutable ~= nil)
  --assert(picker ~= nil)
  --debugprint("Sprout:OnSproutHarvest")
  --self.product_prefab = nil
end

--function Sprout:Harvest(harvester)
--  debugprint("Sprout:Harvest")
--  if self.matured or self.withered then
----    local product = nil
----    if self.grower and self.grower:HasTag("fire") or self.inst:HasTag("fire") then
----      local temp = SpawnPrefab(self.product_prefab)
----      if temp.components.cookable and temp.components.cookable.product then
----        product = SpawnPrefab(temp.components.cookable.product)
----      else
----        product = SpawnPrefab("seeds_cooked")
----      end
----      temp:Remove()
----    else
----      product = SpawnPrefab(self.product_prefab)
----    end
--
----    if product then
----      local targetMoisture = 0
--
----      if self.inst.components.moisturelistener then
----        targetMoisture = self.inst.components.moisturelistener:GetMoisture()
----      elseif self.inst.components.moisture then
----        targetMoisture = self.inst.components.moisture:GetMoisture()
----      else
----        targetMoisture = GetTheWorld().components.moisturemanager:GetWorldMoisture()
----      end
--
----      product.targetMoisture = targetMoisture
----      product:DoTaskInTime(2*FRAMES, function()
----        if product.components.moisturelistener then 
----          product.components.moisturelistener.moisture = product.targetMoisture
----          product.targetMoisture = nil
----          product.components.moisturelistener:DoUpdate()
----        end
----      end)
----    end
----    harvester.components.inventory:GiveItem(product)
----    ProfileStatsAdd("grown_"..product.prefab) 
--
--    --self.matured = false
--    self.witherable = false
--    self.withered = false
--    self.instsprout:RemoveTag("withered")
----    self.growthpercent = 0
----    self.product_prefab = nil
--    --self.grower.components.grower:RemoveCrop(self.instsprout)
--    --self.grower.components.grower:Reset()
--    --self.grower = nil
--
--    --self.inststump.components.grower:Reset()
--    self.inststump.components.grower:RemoveCrop(self.instsprout)
--
--    if self.instsprout.OnSproutHarvest then
--      self.instsprout.OnSproutHarvest(self, self.instsprout, self.inststump)
--    end
--
--    if self.inststump.OnSproutHarvest then
--      self.inststump.OnSproutHarvest(self, self.instsprout, self.inststump)
--    end
--
--    return true
--  end
--end

--function Sprout:Mature()
--  debugprint("Sprout:Mature")
--  if self.product_prefab and not self.matured and not self.withered then
--    self.matured = true
--    if self.onmatured then
--      self.onmatured(self.instsprout)
--    end
--  end
--end


function Sprout:IsReadyForHarvest()
  return ((self.matured == true and self.withered == false) or self.withered == true)
end


--function Sprout:CollectSceneActions(doer, actions)
--  if (self:IsReadyForHarvest() or self:IsWithered()) and doer.components.inventory then
--    table.insert(actions, ACTIONS.HARVEST)
--  end
--end

--function Sprout:LongUpdate(dt)
--  self:DoGrow(dt)		
--end


return Sprout
