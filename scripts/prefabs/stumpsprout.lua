require "mods"
local IsDST = MOD_API_VERSION >= 10
local IsRoG = IsDLCEnabled(REIGN_OF_GIANTS)
if IsDST then
  IsRoG = true
end

function debugprint(fnname, ...)
  if fnname == nil then fnname = "" end
  --print(debug.traceback())
  local name = debug.getinfo(2,"n").name or ""
  local currentline = debug.getinfo(2,"l").currentline or ""
  local dbgstr = "== "..name.." ( "..fnname.." ) @ "..currentline
  local n = {...}
  for i in pairs(n) do
    dbgstr = dbgstr .. " | "
    dbgstr = dbgstr .. n[i]
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

require "prefabutil"
local assets =
{
  Asset("ANIM", "anim/stumpsprout.zip"),
}

local function describe(inst, viewer)
  print(inst.entity:GetParent():GetDebugString())
  return inst.entity:GetParent():GetDebugString()
end

local function displaynamefn(inst)
  if inst:IsValid() and inst.entity:GetParent() == nil then
    --print("Remove a GHOST stumpsprout:", inst)
    inst:Remove()
  end
  return "Stump Sprout"
end

local function onburnt(inst)
  --print("onburnt:inst:", inst)
  local product_prefab = inst.components.sprout.product_prefab or "ash"
  local product = SpawnPrefab(product_prefab)
  if product.components.cookable and product.components.cookable.product then
    product:Remove()
    product = SpawnPrefab(product.components.cookable.product)
  end

  if inst.components.stackable and product.components.stackle then
    product.components.stackable.stacksize = inst.components.stackable.stacksize
  end

--if inst.components.crop and inst.components.crop.grower and inst.components.crop.grower.components.grower then
--  inst.components.crop.grower.components.grower:RemoveCrop(inst)
--end

  product.Transform:SetPosition(inst.Transform:GetWorldPosition())

  local inststump = inst.entity:GetParent()
  inst:Remove()

  if inststump and
     inststump:IsValid() and
     not inststump:HasTag("burnt")
  then
    --print("onburnt:stumpsprout:inststump:StartGrowing", inst, inststump)
    --print("onburnt:stumpsprout:inststump:Ignite", inst, inststump)
    --inststump.growtime = nil
    --inststump:StartGrowing()
    if inststump.components.burnable and
       not inststump.components.burnable:IsBurning()
    then
      inststump.components.burnable:Ignite()
    end
  end
end

local function CancelAllTasks(inst)
  if inst.sproutswaytask ~= nil then
    inst.sproutswaytask:Cancel()
    inst.sproutswaytask = nil
    --debugprint(inst.entity:GetParent().prefab..": CancelAllTasks : sproutswaytask", inst)
  end
  if inst.makewitherabletask then
    inst.makewitherabletask:Cancel()
    inst.makewitherabletask = nil
    --debugprint(inst.entity:GetParent().prefab..": CancelAllTasks : makewitherabletask", inst)
  end
end

local function MakeSproutSway(self, inststump)
  --debugprint(inststump.prefab..": MakeSproutSway")
  local SPROUTANIMFRAMERATE = 30
  local SWAYSPROUTFRAMERATE = 10
  local swayper = 0.5
  local swayperspaling = math.random(50,60) / 100.0
  local swaycur = 0.0
  local swaydir = math.random(-1,1)
  local swayloco,swayuntilmin,swayuntilmax  = inststump:GetSwayLocoParam()
  local swayuntil = math.random(swayuntilmin,swayuntilmax) / 100.0
  local swayspeed = (math.random(SWAYSPROUTFRAMERATE*5,SWAYSPROUTFRAMERATE*10) / SWAYSPROUTFRAMERATE) / swayloco * (SPROUTANIMFRAMERATE / SWAYSPROUTFRAMERATE)
  local swaymax = 60 / 100.0
  local swaymin = 50 / 100.0

  local function DoSproutSway(inst)
    local inststump = inst.entity:GetParent()
    --assert(inststump ~= nil)

    if swaycur > swayuntil then
      swaycur = 0.0
      swaydir = math.random(-1,1)
      swayloco,swayuntilmin,swayuntilmax = inststump.GetSwayLocoParam()
      swayuntil = math.random(swayuntilmin,swayuntilmax) / 100.0
      swayspeed = (math.random(SWAYSPROUTFRAMERATE*5,SWAYSPROUTFRAMERATE*10) / SWAYSPROUTFRAMERATE) / swayloco * (SPROUTANIMFRAMERATE / SWAYSPROUTFRAMERATE)
    end
    swaycur = swaycur + swayspeed
    swayper = swayper + swaydir * swayspeed
    if swayper < swaymin then
      swayper = swaymin
    elseif swaymax < swayper then
      swayper = swaymax
    end

    if inststump and inststump:IsValid() then
      if inststump.stumpsproutstage == 1 then
        local animation = inststump.prefab.."_sprout_"..inststump.stumpanims
        inst.AnimState:SetPercent(animation, swayper)
      else
        local animation = inststump.prefab.."_sapling_"..inststump.stumpanims
        inst.AnimState:SetPercent(animation, swayperspaling)
      end
    end
  end

  self.sproutswaytask = self:DoPeriodicTask((1/FRAMES)/SWAYSPROUTFRAMERATE*FRAMES, DoSproutSway, 0)
end

local function MakeHarvestable(inst, product_prefab)
  --debugprint("[prefab:stumpsprout] MakeHarvestable")
  local function onharvest(inst, picker)
    inst.components.sprout.inststump.components.sproutable:OnSproutHarvest(picker)
  end

  if not inst.components.harvestable then inst:AddComponent("harvestable") end
  inst.components.harvestable:SetUp(product_prefab, 1, nil, onharvest, nil)
  inst.components.harvestable.produce = 1
end

local function DisableHarvestable(inst)
  --debugprint("[prefab:stumpsprout] DisableHarvestable")
  if inst.components.harvestable then inst:RemoveComponent("harvestable") end
end

local function OnSproutWithered(sproutable, product_prefab)
  --debugprint("[prefab:stumpsprout] "..sproutable.inststump.prefab..": OnSproutWithered")
  sproutable.instsprout:MakeHarvestable(product_prefab)
  sproutable.instsprout.AnimState:SetBank("stumpsprout")
  sproutable.instsprout.AnimState:SetBuild("stumpsprout")
  local stage = sproutable.inststump.stumpstage
  if sproutable.inststump.monster then stage = 4 end
  sproutable.instsprout.Transform:SetPosition(sproutable.inststump.PLANT_POINTS[stage].x, sproutable.inststump.PLANT_POINTS[stage].y, sproutable.inststump.PLANT_POINTS[stage].z)
  sproutable.instsprout.Transform:SetScale(0.8,0.8,0.8)
  sproutable.instsprout.AnimState:SetMultColour(sproutable.inststump.stumpcolorr, sproutable.inststump.stumpcolorg, sproutable.inststump.stumpcolorb, sproutable.inststump.stumpcolora)
  sproutable.instsprout.AnimState:PlayAnimation("picked")
  sproutable.inststump:AddChild(sproutable.instsprout)

  if sproutable.instsprout.components.burnable then sproutable.instsprout:RemoveComponent("burnable") end
  if sproutable.instsprout.components.propagator then sproutable.instsprout:RemoveComponent("propagator") end
  MakeSmallBurnable(sproutable.instsprout)
  MakeSmallPropagator(sproutable.instsprout)
  sproutable.instsprout.components.burnable:SetOnBurntFn(onburnt)
  if not IsDST and IsRoG then
    sproutable.instsprout.components.burnable:MakeDragonflyBait(1)
  elseif IsDST then
    MakeDragonflyBait(sproutable.instsprout, 1)
  end

  if sproutable.inststump.OptDebug == false then
    sproutable.instsprout.components.inspectable:SetDescription("Sprout withered :(")
  end
end

local function OnSproutGrowTree(sproutable, product_prefab)
  --debugprint("[prefab:stumpsprout] "..sproutable.inststump.prefab..": OnSproutGrowTree")
  local tree = SpawnPrefab(product_prefab)
  if tree then
    tree.Transform:SetPosition(sproutable.inststump.Transform:GetWorldPosition()) 
    if tree.growfromseed then tree:growfromseed() end --PushEvent("growfromseed")
  end
end

local function OnSproutGrowVeggie(sproutable, product_prefab)
  --debugprint("[prefab:stumpsprout] "..sproutable.inststump.prefab..": OnSproutGrowVeggie")
  local stage = sproutable.inststump.stumpstage
  if sproutable.inststump.monster then stage = 4 end
  sproutable.instsprout.Transform:SetPosition(sproutable.inststump.PLANT_POINTS[stage].x, sproutable.inststump.PLANT_POINTS[stage].y, sproutable.inststump.PLANT_POINTS[stage].z)
  local veggiescale = {0.5, 0.7, 0.8, 0.6}
  sproutable.instsprout.Transform:SetScale(veggiescale[stage],veggiescale[stage],veggiescale[stage])
  sproutable.instsprout.AnimState:SetBank("plant_normal")
  sproutable.instsprout.AnimState:SetBuild("plant_normal")
  sproutable.instsprout.AnimState:PlayAnimation("grow_pst")
  sproutable.inststump:AddChild(sproutable.instsprout)
  sproutable.instsprout.AnimState:OverrideSymbol("swap_grown", product_prefab, product_prefab.."01")
  sproutable.instsprout:MakeHarvestable(product_prefab)

  if sproutable.instsprout.components.burnable then sproutable.instsprout:RemoveComponent("burnable") end
  if sproutable.instsprout.components.propagator then sproutable.instsprout:RemoveComponent("propagator") end
  MakeSmallBurnable(sproutable.instsprout)
  MakeSmallPropagator(sproutable.instsprout)
  sproutable.instsprout.components.burnable:SetOnBurntFn(onburnt)
  if not IsDST and IsRoG then
    sproutable.instsprout.components.burnable:MakeDragonflyBait(1)
  elseif IsDST then
    MakeDragonflyBait(sproutable.instsprout, 1)
  end

  if sproutable.inststump.OptDebug == false then
    sproutable.instsprout.components.inspectable:SetDescription("Looks very delicious!")
  end
end

local function OnSproutGrowFlower(sproutable, product_prefab, flowername)
  --debugprint("[prefab:stumpsprout] "..sproutable.inststump.prefab..": OnSproutGrowFlower")
  local stage = sproutable.inststump.stumpstage
  if sproutable.inststump.monster then stage = 4 end
  sproutable.instsprout.Transform:SetPosition(sproutable.inststump.PLANT_POINTS[stage].x, sproutable.inststump.PLANT_POINTS[stage].y, sproutable.inststump.PLANT_POINTS[stage].z)
  local flowerscale = {0.5, 0.7, 0.8, 0.6}
  sproutable.instsprout.Transform:SetScale(flowerscale[stage],flowerscale[stage],flowerscale[stage])
  sproutable.instsprout.AnimState:SetBank("flowers")
  sproutable.instsprout.AnimState:SetBuild("flowers")
  sproutable.instsprout.AnimState:PlayAnimation(flowername)
  sproutable.inststump:AddChild(sproutable.instsprout)
  sproutable.instsprout:MakeHarvestable(product_prefab)

  if sproutable.instsprout.components.burnable then sproutable.instsprout:RemoveComponent("burnable") end
  if sproutable.instsprout.components.propagator then sproutable.instsprout:RemoveComponent("propagator") end
  MakeSmallBurnable(sproutable.instsprout)
  MakeSmallPropagator(sproutable.instsprout)
  sproutable.instsprout.components.burnable:SetOnBurntFn(onburnt)
  if not IsDST and IsRoG then
    sproutable.instsprout.components.burnable:MakeDragonflyBait(1)
  elseif IsDST then
    MakeDragonflyBait(sproutable.instsprout, 1)
  end

  local rarity = math.random(1,100)
  if (sproutable.inststump.OptDifficulty == 0 and rarity <= sproutable.inststump.SOMETIMESLIGHT_EASY) or
     (sproutable.inststump.OptDifficulty == 1 and rarity <= sproutable.inststump.SOMETIMESLIGHT_NORMAL)
  then
    sproutable.instsprout.entity:AddLight()
    sproutable.instsprout.Light:SetColour(128/255,192/255,192/255)
    sproutable.instsprout.Light:SetIntensity(.8)
    sproutable.instsprout.Light:SetRadius(.5)
    sproutable.instsprout.Light:SetFalloff(.33)
    sproutable.instsprout.Light:Enable(true)
    sproutable.instsprout.AnimState:SetBloomEffectHandle( "shaders/anim_fade.ksh" )
    sproutable.instsprout.AnimState:SetBloomEffectHandle( "" )
  end

  if sproutable.inststump.OptDebug == false then
    sproutable.instsprout.components.inspectable:SetDescription("What a pretty flower :)")
  end
end

local function OnSproutGrowPlant(sproutable)
  --debugprint("[prefab:stumpsprout] "..sproutable.inststump.prefab..": OnSproutGrowPlant")
  sproutable.instsprout.AnimState:SetBank("plant_normal")
  sproutable.instsprout.AnimState:SetBuild("plant_normal")
  local animation = "grow"
  local stage = sproutable.inststump.stumpstage
  if sproutable.inststump.monster then stage = 4 end
  sproutable.instsprout.Transform:SetPosition(sproutable.inststump.PLANT_POINTS[stage].x, sproutable.inststump.PLANT_POINTS[stage].y, sproutable.inststump.PLANT_POINTS[stage].z)
  local plantscale = {0.5, 0.7, 0.8, 0.6}
  sproutable.instsprout.Transform:SetScale(plantscale[stage],plantscale[stage],plantscale[stage])
  sproutable.instsprout.AnimState:PlayAnimation(animation)
  sproutable.instsprout.AnimState:SetMultColour(sproutable.inststump.stumpcolorr, sproutable.inststump.stumpcolorg, sproutable.inststump.stumpcolorb, sproutable.inststump.stumpcolora)
  sproutable.inststump:AddChild(sproutable.instsprout)

  if sproutable.instsprout.components.burnable then sproutable.instsprout:RemoveComponent("burnable") end
  if sproutable.instsprout.components.propagator then sproutable.instsprout:RemoveComponent("propagator") end
  MakeSmallBurnable(sproutable.instsprout)
  MakeSmallPropagator(sproutable.instsprout)
  sproutable.instsprout.components.burnable:SetOnBurntFn(onburnt)
  if not IsDST and IsRoG then
    sproutable.instsprout.components.burnable:MakeDragonflyBait(1)
  elseif IsDST then
    MakeDragonflyBait(sproutable.instsprout, 1)
  end

  if sproutable.inststump.OptDebug == false then
    sproutable.instsprout.components.inspectable:SetDescription("Before becoming a veggie.")
  end
end

local function OnSproutGrowSapling(sproutable)
  --debugprint("[prefab:stumpsprout] "..sproutable.inststump.prefab..": OnSproutGrowSapling")
  sproutable.instsprout.AnimState:SetBank("stumpsprout")
  sproutable.instsprout.AnimState:SetBuild("stumpsprout")
  local animation = sproutable.inststump.prefab.."_sapling_"..sproutable.inststump.stumpanims
  sproutable.instsprout.Transform:SetPosition(0,0,0)
  sproutable.instsprout.Transform:SetScale(1,1,1)
  sproutable.instsprout.AnimState:SetPercent(animation, 0.5)
  sproutable.instsprout.AnimState:SetMultColour(sproutable.inststump.stumpcolorr, sproutable.inststump.stumpcolorg, sproutable.inststump.stumpcolorb, sproutable.inststump.stumpcolora)
  sproutable.inststump:AddChild(sproutable.instsprout)
  MakeSproutSway(sproutable.instsprout, sproutable.inststump)

  if sproutable.instsprout.components.burnable then sproutable.instsprout:RemoveComponent("burnable") end
  if sproutable.instsprout.components.propagator then sproutable.instsprout:RemoveComponent("propagator") end
  MakeSmallBurnable(sproutable.instsprout)
  MakeSmallPropagator(sproutable.instsprout)
  sproutable.instsprout.components.burnable:SetOnBurntFn(onburnt)
  if not IsDST and IsRoG then
    sproutable.instsprout.components.burnable:MakeDragonflyBait(1)
  elseif IsDST then
    MakeDragonflyBait(sproutable.instsprout, 1)
  end

  if sproutable.inststump.OptDebug == false then
    sproutable.instsprout.components.inspectable:SetDescription("Sapling!")
  end
end

local function OnSproutGrowSprout(sproutable)
  --debugprint("[prefab:stumpsprout] "..sproutable.inststump.prefab..": OnSproutGrowSprout")
  sproutable.instsprout.AnimState:SetBank("stumpsprout")
  sproutable.instsprout.AnimState:SetBuild("stumpsprout")
  local animation = sproutable.inststump.prefab.."_sprout_"..sproutable.inststump.stumpanims
  sproutable.instsprout.Transform:SetPosition(0,0,0)
  sproutable.instsprout.Transform:SetScale(1,1,1)
  sproutable.instsprout.AnimState:SetPercent(animation, 0.5)
  sproutable.instsprout.AnimState:SetMultColour(sproutable.inststump.stumpcolorr, sproutable.inststump.stumpcolorg, sproutable.inststump.stumpcolorb, sproutable.inststump.stumpcolora)
  sproutable.inststump:AddChild(sproutable.instsprout)
  MakeSproutSway(sproutable.instsprout, sproutable.inststump)

  if sproutable.instsprout.components.burnable then sproutable.instsprout:RemoveComponent("burnable") end
  if sproutable.instsprout.components.propagator then sproutable.instsprout:RemoveComponent("propagator") end
  MakeSmallBurnable(sproutable.instsprout)
  MakeSmallPropagator(sproutable.instsprout)
  sproutable.instsprout.components.burnable:SetOnBurntFn(onburnt)
  if not IsDST and IsRoG then
    sproutable.instsprout.components.burnable:MakeDragonflyBait(1)
  elseif IsDST then
    MakeDragonflyBait(sproutable.instsprout, 1)
  end

  local rarity = math.random(1,100)
  if (sproutable.inststump.OptDifficulty == 0 and rarity <= sproutable.inststump.SOMETIMESLIGHT_EASY) or
     (sproutable.inststump.OptDifficulty == 1 and rarity <= sproutable.inststump.SOMETIMESLIGHT_NORMAL)
  then
    sproutable.instsprout.entity:AddLight()
    sproutable.instsprout.Light:SetColour(128/255,192/255,128/255)
    sproutable.instsprout.Light:SetIntensity(.8)
    sproutable.instsprout.Light:SetRadius(.5)
    sproutable.instsprout.Light:SetFalloff(.33)
    sproutable.instsprout.Light:Enable(true)
    sproutable.instsprout.AnimState:SetBloomEffectHandle( "shaders/anim_fade.ksh" )
    sproutable.instsprout.AnimState:SetBloomEffectHandle( "" )
  end

  if IsRoG then
    sproutable.instsprout.makewitherabletask = sproutable.instsprout:DoTaskInTime(TUNING.WITHER_BUFFER_TIME, function(inst) inst.components.sprout:MakeWitherable() end)
  end
  if sproutable.inststump.OptDebug == false then
    sproutable.instsprout.components.inspectable:SetDescription("Sways from side to side.")
  end
end

local function OnSproutStartGrowing(sproutable)
  --debugprint("[prefab:stumpsprout] "..sproutable.inststump.prefab..": OnSproutStartGrowing")
  if sproutable.inststump.OptDifficulty <= 1 then
    sproutable.instsprout.AnimState:SetBank("stumpsprout")
    sproutable.instsprout.AnimState:SetBuild("stumpsprout")
    sproutable.instsprout.Transform:SetPosition(0,0,0)
    sproutable.instsprout.Transform:SetScale(1,1,1)
    sproutable.instsprout.AnimState:PlayAnimation("idle")
    sproutable.instsprout.AnimState:SetMultColour(sproutable.inststump.stumpcolorr, sproutable.inststump.stumpcolorg, sproutable.inststump.stumpcolorb, sproutable.inststump.stumpcolora)
    sproutable.inststump:AddChild(sproutable.instsprout)

    if sproutable.instsprout.components.burnable then sproutable.instsprout:RemoveComponent("burnable") end
    if sproutable.instsprout.components.propagator then sproutable.instsprout:RemoveComponent("propagator") end

    if sproutable.inststump.OptDebug == false then
      sproutable.instsprout.components.inspectable:SetDescription("Stump growing...")
    end
  end
end

local function OnSproutPlantSeed(sproutable)
  --debugprint("[prefab:stumpsprout] "..sproutable.inststump.prefab..": OnSproutPlantSeed")
  sproutable.instsprout.AnimState:SetBank("stumpsprout")
  sproutable.instsprout.AnimState:SetBuild("stumpsprout")
  local animation = sproutable.inststump.prefab.."_seed_"..sproutable.inststump.stumpanims
  sproutable.instsprout.AnimState:PlayAnimation(animation)
  sproutable.instsprout.AnimState:SetMultColour(sproutable.inststump.stumpcolorr, sproutable.inststump.stumpcolorg, sproutable.inststump.stumpcolorb, sproutable.inststump.stumpcolora)
  sproutable.instsprout.Transform:SetPosition(0,0,0)
  sproutable.instsprout.Transform:SetScale(1,1,1)
  sproutable.inststump:AddChild(sproutable.instsprout)
  if IsRoG then
    sproutable.instsprout.makewitherabletask = sproutable.instsprout:DoTaskInTime(TUNING.WITHER_BUFFER_TIME, function(inst) inst.components.sprout:MakeWitherable() end)
  end
  if sproutable.inststump.OptDebug == false then
    sproutable.instsprout.components.inspectable:SetDescription("Some seeds are growing...")
  end
end

local function OnSproutFertilize(sproutable)
  --debugprint("[prefab:stumpsprout] "..sproutable.inststump.prefab..": OnSproutFertilize")
end

local function OnSproutHarvest(sproutable, picker)
  --debugprint("[prefab:stumpsprout] "..sproutable.inststump.prefab..": OnSproutHarvest")
  sproutable.instsprout:DisableHarvestable()
  sproutable.instsprout.AnimState:SetBank("stumpsprout")
  sproutable.instsprout.AnimState:SetBuild("stumpsprout")
  sproutable.instsprout.AnimState:PlayAnimation("idle")
  sproutable.instsprout:Remove()
end

local function fn()
  local inst = CreateEntity()

  inst.entity:AddTransform()
  inst.entity:AddAnimState()
  inst.entity:AddSoundEmitter()
  if IsDST then inst.entity:AddNetwork() end

  --MakeInventoryPhysics(inst)

  inst.AnimState:SetBank("stumpsprout")
  inst.AnimState:SetBuild("stumpsprout")
  inst.AnimState:PlayAnimation("idle")

  inst.displaynamefn = displaynamefn

  if IsDST then inst.entity:SetPristine() end

  if IsDST and not GetTheWorld().ismastersim then
    return inst
  end

  inst:AddComponent("inspectable")
  if inst.entity:GetParent() and inst.entity:GetParent().OptDebug == true then
  --inst.components.inspectable:SetDescription(describe)
    inst.components.inspectable.descriptionfn = describe
--  inst.components.inspectable.getstatus = describe
--  inst.components.inspectable.getstatus = function(inst)
--    if inst.components.sprout:IsReadyForHarvest() then
--      return "READY"
--    elseif inst.components.sprout:IsWithered() then
--      return "WITHERED"
--    else
--      return "GROWING"
--    end
--  end
  end

  inst:AddComponent("sprout")

  inst.MakeHarvestable = MakeHarvestable
  inst.DisableHarvestable = DisableHarvestable
  inst.OnSproutWithered = OnSproutWithered
  inst.OnSproutGrowTree = OnSproutGrowTree
  inst.OnSproutGrowVeggie = OnSproutGrowVeggie
  inst.OnSproutGrowFlower = OnSproutGrowFlower
  inst.OnSproutGrowPlant = OnSproutGrowPlant
  inst.OnSproutGrowSapling = OnSproutGrowSapling
  inst.OnSproutGrowSprout = OnSproutGrowSprout
  inst.OnSproutStartGrowing = OnSproutStartGrowing
  inst.OnSproutPlantSeed = OnSproutPlantSeed
  inst.OnSproutFertilize = OnSproutFertilize
  inst.OnSproutHarvest = OnSproutHarvest
  inst.CancelAllTasks = CancelAllTasks

  --inst.AnimState:SetFinalOffset(-1)

  return inst
end

return Prefab("common/objects/stumpsprout", fn, assets)
