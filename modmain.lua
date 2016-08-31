local GROWVEGGIERATE = 10
local GROWVEGGIERATE_PLANTSEEDS = 50
local GROWFLOWERRATE = 5

local SOMETIMESLIGHT_EASY = 30
local SOMETIMESLIGHT_NORMAL = 10

local OptDifficulty  = GetModConfigData("Difficulty", false)
local OptGrowthSpeed = GetModConfigData("GrowthSpeed", false)
local OptEdible      = GetModConfigData("Edible", false)
local OptAutoCrumble = GetModConfigData("AutoCrumble", false)

local OptDebug = false

local assert = GLOBAL.assert
local require = GLOBAL.require

require "mods"

function debugprint(fnname, ...)
  if fnname == nil then fnname = "" end
  --print(GLOBAL.debug.traceback())
  local name = GLOBAL.debug.getinfo(2,"n").name or ""
  local currentline = GLOBAL.debug.getinfo(2,"l").currentline or ""
  local dbgstr = "== "..name.." ( "..fnname.." ) @ "..currentline
  local n = {...}
  for i in pairs(n) do
    dbgstr = dbgstr .. " | "
    dbgstr = dbgstr .. tostring(n[i])
  end
  print(dbgstr)
end

local function GetDebugString(inst)
  local dmsg = ""
  dmsg = dmsg.."inst: "..tostring(inst).."\n"
  dmsg = dmsg.."inst.build: "..tostring(inst.build).."\n"
  dmsg = dmsg.."inst.stumpstage: "..tostring(inst.stumpstage).."\n"
  dmsg = dmsg.."inst.stumpanims: "..tostring(inst.stumpanims).."\n"
  dmsg = dmsg.."inst.stumpname: "..tostring(inst.stumpname).."\n"
  dmsg = dmsg.."inst.growtime: "..tostring(inst.growtime).."\n"
  if inst.growtime ~= nil then
    dmsg = dmsg.."growtime: "..tostring(inst.growtime - GLOBAL.GetTime()).."\n"
  else
    dmsg = dmsg.."growtime: nil".."\n"
  end
  dmsg = dmsg.."inst.stumpplanted: "..tostring(inst.stumpplanted).."\n"
  dmsg = dmsg.."inst.stumpwithered: "..tostring(inst.stumpwithered).."\n"
  dmsg = dmsg.."inst.stumpsproutstage: "..tostring(inst.stumpsproutstage).."\n"
  dmsg = dmsg.."inst.stumpproduct: "..tostring(inst.stumpproduct).."\n"
  dmsg = dmsg.."inst.stumpflowername: "..tostring(inst.stumpflowername).."\n"
  dmsg = dmsg.."inst.GrowNext: "..tostring(inst.GrowNext).."\n"
  dmsg = dmsg.."burnt?: "..tostring(inst:HasTag("burnt")).."\n"
  dmsg = dmsg.."fire?: "..tostring(inst:HasTag("fire")).."\n"
  return dmsg
end

		-- season_trans = {"mild", "wet", "green", "dry"}

local function GetThePlayer()
  local player
  if IsDST then
    player = GLOBAL.ThePlayer
  else
    player = GLOBAL.GetPlayer()
  end
  return player
end


local function GetTheWorld()
  local world
  if IsDST then
    world = GLOBAL.TheWorld
  else
    world = GLOBAL.GetWorld()
  end
  return world
end

local IsDST = GLOBAL.TheSim:GetGameID() == "DST"
local IsSW =  GetTheWorld():HasTag("shipwrecked") or GetTheWorld():HasTag("volcano")
local IsRoG = not IsSW and (IsDST or GLOBAL.IsDLCEnabled(GLOBAL.REIGN_OF_GIANTS))

local function IsWinter()
  if IsDST then
    return GLOBAL.TheWorld.state.iswinter
  else
    return GLOBAL.GetSeasonManager():IsWinter()
  end
end

local function IsSummer()
  if IsDST then
    return GLOBAL.TheWorld.state.issummer
  elseif IsSW then
    return GLOBAL.GetSeasonManager():IsDrySeason()
  else
    return GLOBAL.GetSeasonManager():IsSummer()
  end
end

local function IsSpring()
  if IsDST then
    return GLOBAL.TheWorld.state.isspring
  else
    if IsRoG then
      return GLOBAL.GetSeasonManager():IsSpring()
    elseif IsSW then
      return GLOBAL.GetSeasonManager():IsGreenSeason() or GLOBAL.GetSeasonManager():IsWetSeason()
    else
      return GLOBAL.GetSeasonManager():IsSummer()
    end
  end
end

local function IsAutumn()
  if IsDST then
    return GLOBAL.TheWorld.state.isautumn
  else
    if IsRoG then
      return GLOBAL.GetSeasonManager():IsAutumn()
    elseif IsSW then
      return GLOBAL.GetSeasonManager():IsMildSeason()
    else
      return GLOBAL.GetSeasonManager():IsWinter()
    end
  end
end

local function GetDaysLeftInSeason()
  if IsDST then
    return GLOBAL.TheWorld.state.remainingdaysinseason
  else
    return GLOBAL.GetSeasonManager():GetDaysLeftInSeason()
  end
end

local function IsDay()
  if IsDST then
    return GLOBAL.TheWorld.state.isday
  else
    return GLOBAL.GetClock():IsDay()
  end
end

local function IsDusk()
  if IsDST then
    return GLOBAL.TheWorld.state.isdusk
  else
    return GLOBAL.GetClock():IsDusk()
  end
end

local function CancelAllTasks(inst)
  --debugprint("CancelAllTasks", inst)
  if inst.growtask then
    inst.growtask:Cancel()
    inst.growtask = nil
    inst.growtime = nil
    --print("CancelAllTasks:growtask")
  end
  if inst.components.sproutable and
     inst.components.sproutable.instsprout ~= nil and
     inst.components.sproutable.instsprout.CancelAllTasks
  then
    --print("CancelAllTasks:instsprouttask")
    inst.components.sproutable.instsprout:CancelAllTasks()
  end
end

local function RemoveChildren(inst)
  --print("RemoveChildren:",inst)

  CancelAllTasks(inst)

  local guid = inst.entity:GetGUID()
  if guid and
     GLOBAL.Ents[guid] and
     GLOBAL.Ents[guid].children
  then
    for k,v in pairs(GLOBAL.Ents[guid].children) do
      k.parent = nil
      k:Remove()
      --k.entity:SetParent(nil)
      --print("-- remove child-------------------------------")
      --debugprint()
      --print("----------------------------------------------")
    end
  end

  if inst.components.sproutable and
     inst.components.sproutable.instsprout
  then
    --print("RemoveChildren:instsprout:Remove", inst.components.sproutable.instsprout)
    inst.components.sproutable.instsprout:Remove()
    --inst:RemoveComponent("sproutable")
  elseif inst.components.sproutable then
    --inst:RemoveComponent("sproutable")
  end
end

if not IsDST then
  local actionsharvestfnbase = GLOBAL.ACTIONS.HARVEST.fn
  GLOBAL.ACTIONS.HARVEST.fn = function(act)
    -- for the issue "grower == nil" crash bug
    if act.target.components.crop and
       act.target.components.crop.grower == nil
    then
      act.target:Remove()
      return false
    end

    ret = actionsharvestfnbase(act)

--  if act.target.components.sprout then
--    return act.target.components.sprout:Harvest(act.doer)
--  end
    return ret
  end
end

local actionsfertilizefnbase = GLOBAL.ACTIONS.FERTILIZE.fn
GLOBAL.ACTIONS.FERTILIZE.fn = function(act)
  local ret = actionsfertilizefnbase(act)
  if (not IsDST and
      act.target and
      act.target.components.sprout and
      not act.target.components.sprout:IsReadyForHarvest() and
      not act.target.components.sprout:IsWithered() and
      act.invobject and
      act.invobject.components.fertilizer)
    or
     (IsDST and
      act.target and
      act.target.components.sprout and
      not act.target:HasTag("readyforharvest") and
      not act.target:HasTag("withered") and
      act.invobject and
      act.invobject.components.fertilizer)
  then
    local obj = act.invobject

    if act.target.components.sprout:Fertilize(obj) then
      return true
    else
      return false
    end
  end
  return ret
end

if OptDebug == true then
  local actionslookatfnbase = GLOBAL.ACTIONS.LOOKAT.fn
  GLOBAL.ACTIONS.LOOKAT.fn = function(act)
    ret = actionslookatfnbase(act)
    if act.target and
       (act.target.prefab == "evergreen" or
        act.target.prefab == "evergreen_sparse" or
        act.target.prefab == "jungletree" or
        act.target.prefab == "palmtree" or
        act.target.prefab == "deciduoustree")
    then
      print(GetDebugString(act.target))
    end
    return ret
  end
end

--Assets = 
--{
--  Asset("ANIM", "anim/stumpsprout.zip"),
--}

PrefabFiles = {
  "stumpsprout",
  "veggies",
  "petals",
  "seeds",
  "silk",
  "cutgrass",
  "flower"
}

--local localfunc = {}
local seg_time = 30
local day_segs = 10
local day_time = seg_time * day_segs


local function IsValidStumpProperty(inst)
  if inst.stumpstage == nil or
     inst.stumpscalex == nil or
     inst.stumpscaley == nil or
     inst.stumpscalez == nil or
     inst.stumpanims == nil or
     inst.stumpname == nil or
     inst.stumpcolorr == nil or
     inst.stumpcolorg == nil or
     inst.stumpcolorb == nil or
     inst.stumpcolora == nil or
     inst.stumpplanted == nil or
     inst.stumpwithered == nil or
     inst.stumpsproutstage == nil
  then
    return false
  end
  return true
end

require "prefabs/veggies"

local function pickproduct_veggie(inst)

  local total_w = 0
  for k,v in pairs(GLOBAL.VEGGIES) do
    total_w = total_w + (v.seed_weight or 1)
  end

  local rnd = math.random()*total_w
  for k,v in pairs(GLOBAL.VEGGIES) do
    rnd = rnd - (v.seed_weight or 1)
    if rnd <= 0 then
      return k
    end
  end

  return "carrot"
end

-------------------------------------------------------------------------------

local function TreePrefabPostInit(inst,treetype)

  local STUMPS_GROWTIME = {
    evergreen = {
      short        = {base=7*day_time,      random=2*day_time},       -- short
      normal       = {base=3.5*day_time,    random=1*day_time},       -- normal
      tall         = {base=2*day_time,      random=0.5*day_time},     -- tall
      shortall     = {base=2*day_time/2,    random=0.5*day_time/2},   -- shortall
      taller       = {base=2*day_time/2.5,  random=0.5*day_time/2.5}, -- taller
      tallest      = {base=2*day_time/3.0,  random=0.5*day_time/3.0}, -- tallest
      giant        = {base=2*day_time/3.5,  random=0.5*day_time/3.5}, -- giant
      massive      = {base=2*day_time/4,    random=0.5*day_time/4},   -- massive
      old          = {base=12*day_time,     random=4*day_time},       -- old
      tall_monster = {base=12*day_time,     random=4*day_time},       -- tall_monster
      stump        = {base=0.75*day_time/2, random=0.25*day_time/2}   -- stump
    }, 
    deciduoustree = {
      short        = {base=3*day_time,      random=1*day_time},       -- short
      normal       = {base=2*day_time,      random=0.75*day_time},    -- normal
      tall         = {base=1*day_time,      random=0.5*day_time},     -- tall
      shortall     = {base=1*day_time/2,    random=0.5*day_time/2},   -- shortall
      taller       = {base=1*day_time/2.5,  random=0.5*day_time/2.5}, -- taller
      tallest      = {base=1*day_time/3.0,  random=0.5*day_time/3.0}, -- tallest
      giant        = {base=1*day_time/3.5,  random=0.5*day_time/3.5}, -- giant
      massive      = {base=1*day_time/4,    random=0.5*day_time/4},   -- massive
      old          = {base=10*day_time,     random=4*day_time},       -- old
      tall_monster = {base=10*day_time,     random=4*day_time},       -- tall_monster
      stump        = {base=0.75*day_time/2, random=0.25*day_time/2}   -- stump
    },
    jungletree = {
      short        = {base=7*day_time,      random=2*day_time},       -- short
      normal       = {base=3.5*day_time,    random=1*day_time},       -- normal
      tall         = {base=2*day_time,      random=0.5*day_time},     -- tall
      shortall     = {base=2*day_time/2,    random=0.5*day_time/2},   -- shortall
      taller       = {base=2*day_time/2.5,  random=0.5*day_time/2.5}, -- taller
      tallest      = {base=2*day_time/3.0,  random=0.5*day_time/3.0}, -- tallest
      giant        = {base=2*day_time/3.5,  random=0.5*day_time/3.5}, -- giant
      massive      = {base=2*day_time/4,    random=0.5*day_time/4},   -- massive
      old          = {base=12*day_time,     random=4*day_time},       -- old
      tall_monster = {base=12*day_time,     random=4*day_time},       -- tall_monster
      stump        = {base=0.75*day_time/2, random=0.25*day_time/2}   -- stump
    }, 
    palmtree = {
      short        = {base=3*day_time,      random=1*day_time},       -- short
      normal       = {base=2*day_time,      random=0.75*day_time},    -- normal
      tall         = {base=1*day_time,      random=0.5*day_time},     -- tall
      shortall     = {base=1*day_time/2,    random=0.5*day_time/2},   -- shortall
      taller       = {base=1*day_time/2.5,  random=0.5*day_time/2.5}, -- taller
      tallest      = {base=1*day_time/3.0,  random=0.5*day_time/3.0}, -- tallest
      giant        = {base=1*day_time/3.5,  random=0.5*day_time/3.5}, -- giant
      massive      = {base=1*day_time/4,    random=0.5*day_time/4},   -- massive
      old          = {base=10*day_time,     random=4*day_time},       -- old
      tall_monster = {base=10*day_time,     random=4*day_time},       -- tall_monster
      stump        = {base=0.75*day_time/2, random=0.25*day_time/2}   -- stump
    },
  }

  local BUILDS = {
    evergreen = {
      normal = "evergreen_new",
      sparse = "evergreen_new_2",
    },
    deciduoustree = {
      normal = "tree_leaf_green_build",
      barren = "tree_leaf_trunk_build",
      red = "tree_leaf_red_build",
      orange = "tree_leaf_orange_build",
      yellow = "tree_leaf_yellow_build",
      poison = "tree_leaf_poison_build",
    },
    jungletree = {
      normal="tree_jungle_build",
    },
    palmtree = {
      normal="palmtree_build",
    },
  }
  
  local function getOffspring()
    local OFFSPRINGS = {
      evergreen = {
        normal = "evergreen_short",
        sparse = "evergreen_sparse_short",
      },
      deciduoustree = "deciduoustree_short", 
      jungletree = "jungletree_short" ,
      palmtree = "palmtree_short",
    }
    local product_prefab = OFFSPRINGS[treetype]
    if inst.build == "sparse" then
        product_prefab = "evergreen_sparse_short"
    end
    return product_prefab
  end

  local TREE_SEEDS = {
      evergreen = "pinecone",
      deciduoustree = "acorn", 
      jungletree = "jungletreeseed" ,
      palmtree = "coconut",
  }
  
  local PLANT_POINTS = {
    evergreen = {
      GLOBAL.Vector3(0, 50.5/128, 0), -- short
      GLOBAL.Vector3(0, 85.5/128, 0), -- normal
      GLOBAL.Vector3(0, 85.5/128, 0), -- tall
      GLOBAL.Vector3(0, 65.5/128, 0), -- old
    },
    deciduoustree = {
      GLOBAL.Vector3(0,  52.7/128, 0), -- short
      GLOBAL.Vector3(0,  68.2/128, 0), -- normal
      GLOBAL.Vector3(0,  57.8/128, 0), -- tall
      GLOBAL.Vector3(0, 111.2/128, 0), -- monster
    },
    jungletree = {
      GLOBAL.Vector3(0, 50.5/128, 0), -- short
      GLOBAL.Vector3(0, 85.5/128, 0), -- normal
      GLOBAL.Vector3(0, 85.5/128, 0), -- tall
      GLOBAL.Vector3(0, 65.5/128, 0), -- old
    },
    palmtree = {
      GLOBAL.Vector3(0,  52.7/128, 0), -- short
      GLOBAL.Vector3(0,  68.2/128, 0), -- normal
      GLOBAL.Vector3(0,  57.8/128, 0), -- tall
      GLOBAL.Vector3(0, 111.2/128, 0), -- monster
    },
  }
  
  inst.PLANT_POINTS = PLANT_POINTS[treetype]

  if OptDebug == true then
    inst.GetDebugString = GetDebugString

--  local getdescriptionbase = inst.components.inspectable.GetDescription
--  inst.components.inspectable.GetDescription = function(self, viewer)
--    local msg = GetDebugString(self.inst)
--    print(msg)
--    return msg
--  end
  end

  inst.OptDifficulty = OptDifficulty
  inst.OptGrowthSpeed = OptGrowthSpeed
  inst.OptEdible = OptEdible
  inst.OptAutoCrumble = OptAutoCrumble
  inst.OptDebug = OptDebug
  inst.SOMETIMESLIGHT_EASY = SOMETIMESLIGHT_EASY
  inst.SOMETIMESLIGHT_NORMAL = SOMETIMESLIGHT_NORMAL
  
  local buildspeed = 1.0
  if inst.build == "sparse" or inst.build == "poison" then buildspeed = 0.5 end

  local function GetTimeToGrowFromSproutToTree(inst)
    local iswinter = IsWinter()
    local issummer = IsSummer()
    local stump_growtime = STUMPS_GROWTIME[treetype][inst.stumpname]
    if not stump_growtime then
      stump_growtime = {base=math.random(1,10)*day_time, random=0.5*day_time}
    end
    local base
    local random
    local growthrate
    if iswinter then
      growthrate = 0.5 * OptGrowthSpeed * buildspeed
      local daysleft = GetDaysLeftInSeason()
      base = math.min(stump_growtime.base/growthrate, daysleft*day_time+stump_growtime.base*math.random())
      random = stump_growtime.random/growthrate
    elseif issummer then
      growthrate = 1.5 * OptGrowthSpeed * buildspeed
      base = stump_growtime.base/growthrate
      random = stump_growtime.random/growthrate
    else
      growthrate = 1.0 * OptGrowthSpeed * buildspeed
      base = stump_growtime.base/growthrate
      random = stump_growtime.random/growthrate
    end
    local timeToGrow = GLOBAL.GetRandomWithVariance(base, random)
    --debugprint("evergreen: GetTimeToGrowTree", timeToGrow)
    return timeToGrow
  end

  local function GetTimeToGrowSapling(inst)
    local growtime = GetTimeToGrowFromSproutToTree(inst)
    return growtime * 0.8
  end

  local function GetTimeToGrowTree(inst)
    local growtime = GetTimeToGrowFromSproutToTree(inst)
    return growtime * 0.2
  end

  local function GetTimeToAutoCrumble(inst)
    local growtime = GetTimeToGrowFromSproutToTree(inst)
    return growtime * math.random(2.0, 3.0)
  end

  local function GetTimeToGrowSprout(inst)
    local iswinter = IsWinter()
    local issummer = IsSummer()
    local growtime
    local stump_growtime = STUMPS_GROWTIME[treetype]["stump"]
    local base
    local random
    local growthrate
    if iswinter then
      growthrate = 0.5 * OptGrowthSpeed * buildspeed
      --local daysleft = GetDaysLeftInSeason()
      base = stump_growtime.base/growthrate
      random = stump_growtime.random/growthrate
    elseif issummer then
      growthrate = 1.5 * OptGrowthSpeed * buildspeed
      base = stump_growtime.base/growthrate
      random = stump_growtime.random/growthrate
    else
      growthrate = 1.0 * OptGrowthSpeed * buildspeed
      base = stump_growtime.base/growthrate
      random = stump_growtime.random/growthrate
    end
    growtime = GLOBAL.GetRandomWithVariance(base, random)
    --debugprint("evergreen: GetTimeToGrowSprout", growtime)
    return growtime
  end

  local function RebuildStumpProperty(inst, growtime, sproutstage)
    if inst.components.sproutable == nil then inst:AddComponent("sproutable") end
    if not inst.monster then
        local growth_stages = {"short","normal","tall"}
        inst.stumpstage = math.random(1,3)
        inst.stumpanims = growth_stages[inst.stumpstage]
    else
        inst.stumpstage = 3
        inst.stumpanims = "tall_monster"
    end
    inst.stumpscalex = 1
    inst.stumpscaley = 1
    inst.stumpscalez = 1
    inst.stumpname = inst.stumpanims
    inst.stumpcolorr = 1
    inst.stumpcolorg = 1
    inst.stumpcolorb = 1
    inst.stumpcolora = 1
    if growtime then
      inst.growtime = growtime + GLOBAL.GetTime()
    else
      inst.growtime = nil
    end
    inst.stumpplanted = false
    inst.stumpwithered = false
    inst.stumpsproutstage = sproutstage
    inst.stumpproduct = nil
    inst.stumpflowername = nil
  end

  if IsDST then
    local function OnGrowVeggie(inst)
      inst.SoundEmitter:PlaySound("dontstarve/common/farm_harvestable")
    end
    inst:ListenForEvent("stumps_grow.evergreen.growveggie", OnGrowVeggie)
    inst.evergreen_growveggieevent = GLOBAL.net_event(inst.GUID, "stumps_grow.evergreen.growveggie")
  end

  local function DigUpStump(inst, chopper)
    --debugprint("evergreen: DigUpStump")
    inst.components.lootdropper:SpawnLootPrefab("log")
    if inst.stumpsproutstage >= 1 and
       OptDifficulty <= 0 and
       math.random(1,100) <= 20
    then
      inst.components.lootdropper:SpawnLootPrefab("seeds")
    end
    if inst.stumpsproutstage >= 1 and
       OptDifficulty <= 0 and
       math.random(1,100) <= 10
    then
      inst.components.lootdropper:SpawnLootPrefab("silk")
    end
    if inst.stumpsproutstage == 5 and
       OptDifficulty <= 1 and
       inst.stumpproduct ~= nil
    then
      inst.components.lootdropper:SpawnLootPrefab(inst.stumpproduct)
    end
    if inst.stumpsproutstage == 6 and
       inst.stumpproduct ~= nil
    then
      inst.components.lootdropper:SpawnLootPrefab(inst.stumpproduct)
    end
    if inst.stumpwithered == true then
      inst.components.lootdropper:SpawnLootPrefab("cutgrass")
      if OptDebug then assert(inst.stumpsproutstage ~= 5 and inst.stumpsproutstage ~= 4 and inst.stumpsproutstage ~= 3 and inst.stumpsproutstage ~= 2) end
      --debugprint("evergreen: DigUpStump", inst, inst.stumpwithered)
    end
    --RemoveChildren(inst)
    inst:Remove()
  end

  inst.DigUpStump = DigUpStump

  if IsDST then
    local function OnGrowSprout(inst)
      inst.SoundEmitter:PlaySound("dontstarve/common/mushroom_up")
    end
    inst:ListenForEvent("stumps_grow.evergreen.growsprout", OnGrowSprout)
    inst.evergreen_growsproutevent = GLOBAL.net_event(inst.GUID, "stumps_grow.evergreen.growsprout")
  end

  if IsDST then
    local function OnGrowSapling(inst)
      --inst.SoundEmitter:PlaySound("dontstarve/forest/treeGrow")
      inst.SoundEmitter:PlaySound("dontstarve/common/mushroom_up")
    end
    inst:ListenForEvent("stumps_grow.evergreen.growsapling", OnGrowSapling)
    inst.evergreen_growsaplingevent = GLOBAL.net_event(inst.GUID, "stumps_grow.evergreen.growsapling")
  end

  if IsDST then
    local function OnGrowPlant(inst)
      --inst.SoundEmitter:PlaySound("dontstarve/forest/treeGrow")
      --inst.SoundEmitter:PlaySound("dontstarve/common/mushroom_up")
      inst.SoundEmitter:PlaySound("dontstarve/common/farm_harvestable")
    end
    inst:ListenForEvent("stumps_grow.evergreen.growplant", OnGrowPlant)
    inst.evergreen_growplantevent = GLOBAL.net_event(inst.GUID, "stumps_grow.evergreen.growplant")
  end

  local function OnSproutWithered(sproutable, product_prefab)
    sproutable.inststump.stumpwithered = true
    sproutable.inststump.growtime = nil
    CancelAllTasks(sproutable.inststump)
    --debugprint("evergreen: OnSproutWithered", sproutable.inststump, sproutable.inststump.stumpwithered)
  end

  local function OnSproutGrowTree(sproutable, product_prefab)
    --RemoveChildren(sproutable.inststump)
    sproutable.inststump:Remove()
  end

  local function OnSproutGrowVeggie(sproutable, product_prefab)
  end

  local function OnSproutGrowFlower(sproutable, product_prefab, flowername)
  end

  local function OnSproutGrowPlant(sproutable)
  end

  local function OnSproutGrowSapling(sproutable)
  end

  local function OnSproutGrowSprout(sproutable)
  end

  local function OnSproutStartGrowing(sproutable)
    sproutable.inststump.stumpproduct = nil
    sproutable.inststump.stumpflowername = nil
    sproutable.inststump.stumpwithered = false
    sproutable.inststump.stumpplanted = false
  end

  local function OnSproutPlantSeed(sproutable)
    sproutable.inststump.stumpplanted = true
  end

  local function OnSproutFertilize(sproutable, fertilizer)
    if sproutable.inststump.growtime ~= nil then
      local growtime = sproutable.inststump.growtime - GLOBAL.GetTime()
      growtime = growtime - fertilizer.components.fertilizer.fertilizervalue
      if growtime > 0 then
        sproutable.inststump.growtime = growtime + GLOBAL.GetTime()
        if sproutable.inststump.growtask ~= nil then
          sproutable.inststump.growtask:Cancel()
          sproutable.inststump.growtask = nil
        end
        sproutable.inststump.growtask = sproutable.inststump:DoTaskInTime(growtime, sproutable.inststump.GrowNext)
      else
        sproutable.inststump.growtime = nil
        if sproutable.inststump.GrowNext then sproutable.inststump.GrowNext(sproutable.inststump) end
      end
    end
  end

  local function OnSproutHarvest(sproutable, picker)
    --debugprint("evergreen: OnSproutHarvest", sprout, instsprout, sproutable.inststump)
    sproutable.inststump.stumpplanted = false
    sproutable.inststump.stumpwithered = false
    sproutable.inststump.growtime = nil
    sproutable.inststump.StartGrowing(sproutable.inststump)
    --debugprint("evergreen: OnSproutHarvest", sproutable.inststump, sproutable.inststump.stumpwithered)
  end

  local function AddGrowerToStump(inst)
    --debugprint("evergreen: AddGrowerToStump")
    if inst.components.grower then return end

    inst:AddComponent("grower")
    inst.components.grower.level = 1
    inst.components.grower.croppoints = {} --GLOBAL.Vector3(0,0,0)
    inst.components.grower.crops = {}
    inst.components.grower.growrate = 0.1
    inst.components.grower.max_cycles_left = 6
    inst.components.grower.cycles_left = inst.components.grower.max_cycles_left
    inst.components.grower.onplantfn = function()
      --debugprint("evergreen: onplantfn")
      inst.stumpplanted = true
      inst.SoundEmitter:PlaySound("dontstarve/wilson/plant_seeds")

      inst.components.sproutable:MakePlantSeed()

      if inst.stumpwithered then -- OnLoad
        inst.components.sproutable:MakeWithered("cutgrass")
      elseif OptDifficulty == 2 or inst.build == "sparse" then
        local growtime = GetTimeToGrowSprout(inst)
        local rarity = math.random(1,100)
        if rarity <= GROWFLOWERRATE then
          inst.growtime = GLOBAL.GetTime() + growtime
          inst.growtask = inst:DoTaskInTime(growtime, inst.GrowFlower)
          inst.GrowNext = inst.GrowFlower
        else
          inst.growtime = GLOBAL.GetTime() + growtime
          inst.growtask = inst:DoTaskInTime(growtime, inst.GrowSprout)
          inst.GrowNext = inst.GrowSprout
          --debugprint("evergreen: onplantfn", growtime)
        end
      end
    end
  end

  local function GetSwayLocoParam()
    local swayloco
    if IsDay() then
      swayloco = 1500
    elseif IsDusk() then
      swayloco = 3000
    else
      swayloco = 8000
    end
    if IsWinter() then
      swayloco = swayloco * 2
    elseif IsSpring() then
      swayloco = swayloco * 1
    elseif IsSummer() then
      swayloco = swayloco * 0.8
    elseif IsAutumn() then
      swayloco = swayloco * 1
    end
    return swayloco, 5, 40
  end

  inst.GetSwayLocoParam = GetSwayLocoParam

  local function GrowTree(inst)
    --debugprint("evergreen: GrowTree")
    if not inst:IsValid() then
      --print("Remove a GHOST stump:", inst)
      RemoveChildren(inst)
      if inst.components.sproutable and
         inst.components.sproutable.instsprout
      then
        --print("Remove a GHOST stump:instsprout:", inst.components.sproutable.instsprout)
        CancelAllTasks(inst)
        inst.components.sproutable.instsprout:Remove()
        inst:RemoveComponent("sproutable")
      end
      return
    end

    inst.stumpsproutstage = 4
    inst.GrowNext = nil

    CancelAllTasks(inst)

    local product_prefab = getOffspring()

    inst.components.sproutable:MakeGrowTree(product_prefab)
  end

  inst.GrowTree = GrowTree

  local function GrowVeggie(inst)
    --debugprint("evergreen: GrowVeggie")
    if not inst:IsValid() then
      --print("Remove a GHOST stump:", inst)
      RemoveChildren(inst)
      if inst.components.sproutable and
         inst.components.sproutable.instsprout
      then
        --print("Remove a GHOST stump:instsprout:", inst.components.sproutable.instsprout)
        CancelAllTasks(inst)
        inst.components.sproutable.instsprout:Remove()
        inst:RemoveComponent("sproutable")
      end
      return
    end

    inst.stumpsproutstage = 5
    inst.GrowNext = nil

    CancelAllTasks(inst)

    if inst.stumpproduct == nil then inst.stumpproduct = pickproduct_veggie(inst) end
    inst.components.sproutable:MakeGrowVeggie(inst.stumpproduct)

    inst.components.grower.isempty = false

    if inst.components.lootdropper then inst:RemoveComponent("lootdropper") end
    if inst.components.workable then inst:RemoveComponent("workable") end
    inst:AddComponent("lootdropper")
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(GLOBAL.ACTIONS.DIG)
    inst.components.workable:SetOnFinishCallback(inst.DigUpStump)
    inst.components.workable:SetWorkLeft(1)

    if inst.stumpwithered then
      inst.components.sproutable:MakeWithered("cutgrass")
    else
      if OptEdible and OptDifficulty >= 0 then
        if not inst.components.sproutable.instsprout.components.edible then inst.components.sproutable.instsprout:AddComponent("edible") end
        local function oneaten(inst, eater)
          local instparent = inst.entity:GetParent()
          instparent:StartGrowing()
        end
        inst.components.sproutable.instsprout.components.edible:SetOnEatenFn(oneaten)
        inst.components.sproutable.instsprout.components.edible.hungervalue = GLOBAL.VEGGIES[inst.stumpproduct].hunger
        inst.components.sproutable.instsprout.components.edible.healthvalue = GLOBAL.VEGGIES[inst.stumpproduct].health
        inst.components.sproutable.instsprout.components.edible.sanityvalue = GLOBAL.VEGGIES[inst.stumpproduct].sanity or 0
        inst.components.sproutable.instsprout.components.edible.foodtype = "VEGGIE"
        --debugprint("evergreen: GrowVeggie: ", inst.components.sproutable.instsprout.components.edible.hungervalue, inst.components.sproutable.instsprout.components.edible.healthvalue, inst.components.sproutable.instsprout.components.edible.sanityvalue, inst.components.sproutable.instsprout.components.edible.foodtype)
      end

      if not IsDST then
        inst.SoundEmitter:PlaySound("dontstarve/common/farm_harvestable")
      else
        inst.evergreen_growveggieevent:push()
      end
    end
  end

  inst.GrowVeggie = GrowVeggie

  local function GrowFlower(inst)
    --debugprint("evergreen: GrowFlower")
    if not inst:IsValid() then
      --print("Remove a GHOST stump:", inst)
      RemoveChildren(inst)
      if inst.components.sproutable and
         inst.components.sproutable.instsprout
      then
        --print("Remove a GHOST stump:instsprout:", inst.components.sproutable.instsprout)
        CancelAllTasks(inst)
        inst.components.sproutable.instsprout:Remove()
        inst:RemoveComponent("sproutable")
      end
      return
    end

    inst.stumpsproutstage = 6
    inst.GrowNext = nil

    CancelAllTasks(inst)

    if inst.stumpproduct == nil then
      inst.stumpproduct = "petals"
      local names = {"f1","f2","f3","f4","f5","f6","f7","f8","f9","f10"}
      inst.stumpflowername = names[math.random(#names)]
    end
    inst.components.sproutable:MakeGrowFlower(inst.stumpproduct, inst.stumpflowername)

    inst.components.grower.isempty = false

    if inst.components.lootdropper then inst:RemoveComponent("lootdropper") end
    if inst.components.workable then inst:RemoveComponent("workable") end
    inst:AddComponent("lootdropper")
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(GLOBAL.ACTIONS.DIG)
    inst.components.workable:SetOnFinishCallback(inst.DigUpStump)
    inst.components.workable:SetWorkLeft(1)

    if inst.stumpwithered then
      inst.components.sproutable:MakeWithered("cutgrass")
    end
  end

  inst.GrowFlower = GrowFlower

  local function GrowPlant(inst)
    --debugprint("evergreen: GrowPlant")
    if not inst:IsValid() then
      --print("Remove a GHOST stump:", inst)
      RemoveChildren(inst)
      if inst.components.sproutable and
         inst.components.sproutable.instsprout
      then
        --print("Remove a GHOST stump:instsprout:", inst.components.sproutable.instsprout)
        CancelAllTasks(inst)
        inst.components.sproutable.instsprout:Remove()
        inst:RemoveComponent("sproutable")
      end
      return
    end
    if OptDebug then assert(inst.build ~= nil) end

    inst.stumpsproutstage = 3
    inst.GrowNext = inst.GrowVeggie

    CancelAllTasks(inst)

    local growtime
    if not IsValidStumpProperty(inst) then
      growtime = GetTimeToGrowTree(inst)
      RebuildStumpProperty(inst, growtime, 3)
    elseif inst.growtime == nil then
      growtime = GetTimeToGrowTree(inst)
      inst.growtime = GLOBAL.GetTime() + growtime
    else
      growtime = inst.growtime - GLOBAL.GetTime()
    end

    inst.components.sproutable:MakeGrowPlant()

    inst.components.grower.isempty = false

    if inst.components.lootdropper then inst:RemoveComponent("lootdropper") end
    if inst.components.workable then inst:RemoveComponent("workable") end
    inst:AddComponent("lootdropper")
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(GLOBAL.ACTIONS.DIG)
    inst.components.workable:SetOnFinishCallback(inst.DigUpStump)
    inst.components.workable:SetWorkLeft(1)

    if inst.stumpwithered then
      inst.components.sproutable:MakeWithered("cutgrass")
    else
      if OptEdible and OptDifficulty >= 0 then
        if not inst.components.sproutable.instsprout.components.edible then inst.components.sproutable.instsprout:AddComponent("edible") end
        local function oneaten(inst, eater)
          local instparent = inst.entity:GetParent()
          instparent:StartGrowing()
        end
        inst.components.sproutable.instsprout.components.edible:SetOnEatenFn(oneaten)
        inst.components.sproutable.instsprout.components.edible.hungervalue = GLOBAL.TUNING.CALORIES_TINY
        inst.components.sproutable.instsprout.components.edible.healthvalue = GLOBAL.TUNING.HEALING_TINY
        inst.components.sproutable.instsprout.components.edible.sanityvalue = 0
        inst.components.sproutable.instsprout.components.edible.foodtype = "RAW"
        --debugprint("evergreen: GrowPlant: ", inst.components.sproutable.instsprout.components.edible.hungervalue, inst.components.sproutable.instsprout.components.edible.healthvalue, inst.components.sproutable.instsprout.components.edible.sanityvalue, inst.components.sproutable.instsprout.components.edible.foodtype)
      end

      if not IsDST then
        --inst.SoundEmitter:PlaySound("dontstarve/forest/treeGrow")
        --inst.SoundEmitter:PlaySound("dontstarve/common/mushroom_up")
        inst.SoundEmitter:PlaySound("dontstarve/common/farm_harvestable")
      else
        inst.evergreen_growplantevent:push()
      end

      inst.growtask = inst:DoTaskInTime(growtime, inst.GrowVeggie)
    end
  end

  inst.GrowPlant = GrowPlant

  local function GrowSapling(inst)
    --debugprint("evergreen: GrowSapling")
    if not inst:IsValid() then
      --print("Remove a GHOST stump:", inst)
      RemoveChildren(inst)
      if inst.components.sproutable and
         inst.components.sproutable.instsprout
      then
        --print("Remove a GHOST stump:instsprout:", inst.components.sproutable.instsprout)
        CancelAllTasks(inst)
        inst.components.sproutable.instsprout:Remove()
        inst:RemoveComponent("sproutable")
      end
      return
    end
    if OptDebug then assert(inst.build ~= nil) end

    inst.stumpsproutstage = 2
    inst.GrowNext = inst.GrowTree

    CancelAllTasks(inst)

    local growtime
    if not IsValidStumpProperty(inst) then
      growtime = GetTimeToGrowTree(inst)
      RebuildStumpProperty(inst, growtime, 2)
    elseif inst.growtime == nil then
      growtime = GetTimeToGrowTree(inst)
      inst.growtime = GLOBAL.GetTime() + growtime
    else
      growtime = inst.growtime - GLOBAL.GetTime()
    end

    inst.components.sproutable:MakeGrowSapling()

    inst.components.grower.isempty = false

    if inst.components.lootdropper then inst:RemoveComponent("lootdropper") end
    if inst.components.workable then inst:RemoveComponent("workable") end
    inst:AddComponent("lootdropper")
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(GLOBAL.ACTIONS.DIG)
    inst.components.workable:SetOnFinishCallback(inst.DigUpStump)
    inst.components.workable:SetWorkLeft(1)

    if inst.stumpwithered then
      inst.components.sproutable:MakeWithered("cutgrass")
    else
      if not IsDST then
        --inst.SoundEmitter:PlaySound("dontstarve/forest/treeGrow")
        inst.SoundEmitter:PlaySound("dontstarve/common/mushroom_up")
      else
        inst.evergreen_growsaplingevent:push()
      end

      inst.growtask = inst:DoTaskInTime(growtime, inst.GrowTree)
    end
  end

  inst.GrowSapling = GrowSapling

  local function GrowSprout(inst)
    --debugprint("evergreen: GrowSprout")
    if not inst:IsValid() then
      --print("Remove a GHOST stump:", inst)
      RemoveChildren(inst)
      if inst.components.sproutable and
         inst.components.sproutable.instsprout
      then
        --print("Remove a GHOST stump:instsprout:", inst.components.sproutable.instsprout)
        CancelAllTasks(inst)
        inst.components.sproutable.instsprout:Remove()
        inst:RemoveComponent("sproutable")
      end
      return
    end
    if OptDebug then assert(inst.build ~= nil) end

    inst.stumpsproutstage = 1

    CancelAllTasks(inst)

    local growtime
    if not IsValidStumpProperty(inst) then
      growtime = GetTimeToGrowSapling(inst)
      RebuildStumpProperty(inst, growtime, 1)
    elseif inst.growtime == nil then
      growtime = GetTimeToGrowSapling(inst)
      inst.growtime = GLOBAL.GetTime() + growtime
    else
      growtime = inst.growtime - GLOBAL.GetTime()
    end

    inst.components.sproutable:MakeGrowSprout()

    inst.components.grower.isempty = false

    if inst.components.lootdropper then inst:RemoveComponent("lootdropper") end
    if inst.components.workable then inst:RemoveComponent("workable") end
    inst:AddComponent("lootdropper")
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(GLOBAL.ACTIONS.DIG)
    inst.components.workable:SetOnFinishCallback(inst.DigUpStump)
    inst.components.workable:SetWorkLeft(1)

    if inst.stumpwithered then
      inst.components.sproutable:MakeWithered("cutgrass")
    else
      if OptEdible and OptDifficulty >= 2 then
        if not inst.components.sproutable.instsprout.components.edible then inst.components.sproutable.instsprout:AddComponent("edible") end
        local function oneaten(inst, eater)
          local instparent = inst.entity:GetParent()
          instparent:StartGrowing()
        end
        inst.components.sproutable.instsprout.components.edible:SetOnEatenFn(oneaten)
        inst.components.sproutable.instsprout.components.edible.hungervalue = GLOBAL.TUNING.CALORIES_TINY
        inst.components.sproutable.instsprout.components.edible.healthvalue = 0
        inst.components.sproutable.instsprout.components.edible.sanityvalue = 0
        inst.components.sproutable.instsprout.components.edible.foodtype = "RAW"
        --debugprint("deciduoustree: GrowSprout: ", inst.components.sproutable.instsprout.components.edible.hungervalue, inst.components.sproutable.instsprout.components.edible.healthvalue, inst.components.sproutable.instsprout.components.edible.sanityvalue, inst.components.sproutable.instsprout.components.edible.foodtype)
      end

      if not IsDST then
        inst.SoundEmitter:PlaySound("dontstarve/common/mushroom_up")
      else
        inst.evergreen_growsproutevent:push()
      end

      local rarity = math.random(1,100)
      --print("rarity = ", rarity)
      if (OptDifficulty == 0 and not inst.stumpplanted and rarity <= GROWVEGGIERATE and inst.build ~= "sparse") or
         (OptDifficulty == 0 and inst.stumpplanted and rarity <= GROWVEGGIERATE_PLANTSEEDS and inst.build ~= "sparse")
      then
        inst.growtask = inst:DoTaskInTime(growtime, inst.GrowPlant)
        inst.GrowNext = inst.GrowPlant
      elseif OptDifficulty == 1 and inst.stumpplanted and rarity <= GROWVEGGIERATE and inst.build ~= "sparse" then
        inst.growtask = inst:DoTaskInTime(growtime, inst.GrowPlant)
        inst.GrowNext = inst.GrowPlant
      else
        inst.growtask = inst:DoTaskInTime(growtime, inst.GrowSapling)
        inst.GrowNext = inst.GrowSapling
      end
    end
  end

  inst.GrowSprout = GrowSprout

  local function StartGrowing(inst)
    --debugprint("evergreen: StartGrowing")
    if not inst:IsValid() then
      --print("Remove a GHOST stump:", inst)
      RemoveChildren(inst)
      if inst.components.sproutable and
         inst.components.sproutable.instsprout
      then
        --print("Remove a GHOST stump:instsprout:", inst.components.sproutable.instsprout)
        CancelAllTasks(inst)
        inst.components.sproutable.instsprout:Remove()
        inst:RemoveComponent("sproutable")
      end
      return
    end
    if OptDebug then assert(inst.build ~= nil) end

    inst.stumpsproutstage = 0

    CancelAllTasks(inst)

    local growtime
    if not IsValidStumpProperty(inst) then
      growtime = GetTimeToGrowSprout(inst)
      RebuildStumpProperty(inst, growtime, 0)
    elseif inst.growtime == nil then
      growtime = GetTimeToGrowSprout(inst)
      inst.growtime = GLOBAL.GetTime() + growtime
    else
      growtime = inst.growtime - GLOBAL.GetTime()
    end

    inst.components.sproutable:MakeStartGrowing()

    inst.components.grower:Reset()

    if inst.components.lootdropper then inst:RemoveComponent("lootdropper") end
    if inst.components.workable then inst:RemoveComponent("workable") end
    inst:AddComponent("lootdropper")
    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(GLOBAL.ACTIONS.DIG)
    inst.components.workable:SetOnFinishCallback(inst.DigUpStump)
    inst.components.workable:SetWorkLeft(1)

    if inst.stumpwithered then
      inst.components.sproutable:MakeWithered("cutgrass")
    else
      local rarity = math.random(1,100)
      if rarity <= GROWFLOWERRATE then
        if OptDifficulty <= 1 and inst.build ~= "sparse" then
          inst.growtask = inst:DoTaskInTime(growtime, inst.GrowFlower)
        else
          inst.growtime = nil
        end
        inst.GrowNext = inst.GrowFlower
      else
        if OptDifficulty <= 1 and inst.build ~= "sparse" then
          inst.growtask = inst:DoTaskInTime(growtime, inst.GrowSprout)
          --debugprint("evergreen: StartGrowing", growtime)
        else
          inst.growtime = nil
        end
        inst.GrowNext = inst.GrowSprout
      end
    end
  end

  inst.StartGrowing = StartGrowing

  local function GrowUp(inst)
    if OptDifficulty <= 1 and inst.stumpsproutstage == 0 then
      inst.StartGrowing(inst)
    elseif inst.stumpsproutstage == 1 then
      inst.GrowSprout(inst)
    elseif inst.stumpsproutstage == 2 then
      inst.GrowSapling(inst)
    elseif inst.stumpsproutstage == 3 then
      inst.GrowPlant(inst)
    elseif inst.stumpsproutstage == 4 then
      inst.GrowTree(inst)
    elseif inst.stumpsproutstage == 5 then
      inst.GrowVeggie(inst)
    elseif inst.stumpsproutstage == 6 then
      inst.GrowFlower(inst)
    end
  end

  inst.GrowUp = GrowUp

  local function MakeStumpGrow(inst)
    --debugprint("evergreen: MakeStumpGrow")
    if not inst:IsValid() then
      --print("Remove a GHOST stump:", inst)
      RemoveChildren(inst)
      if inst.components.sproutable and
         inst.components.sproutable.instsprout
      then
        --print("Remove a GHOST stump:instsprout:", inst.components.sproutable.instsprout)
        CancelAllTasks(inst)
        inst.components.sproutable.instsprout:Remove()
        inst:RemoveComponent("sproutable")
      end
      return
    end
    if OptDebug then assert(inst.build ~= nil) end

    if not IsValidStumpProperty(inst) then
      RebuildStumpProperty(inst, nil, 0)
    end

    local function getAnimBank(inst)
      local AnimBank = "evergreen_short"
      if treetype == "evergreen" then AnimBank = "evergreen_short"
      elseif treetype  == "deciduoustree" then
        if not inst.monster then
          AnimBank = "tree_leaf"
        else
          AnimBank = "tree_leaf_monster"
        end
      elseif treetype == "jungletree" then AnimBank = "jungletree"
      elseif treetype == "palmtree" then AnimBank = "palmtree"
      end
    return AnimBank
    end

    inst.AnimState:SetBuild(BUILDS[treetype][inst.build])
    inst.AnimState:SetBank(getAnimBank(inst))
    inst.AnimState:PushAnimation("stump_"..inst.stumpanims)
    inst.Transform:SetScale(inst.stumpscalex, inst.stumpscaley, inst.stumpscalez)
    inst.AnimState:SetMultColour(inst.stumpcolorr,inst.stumpcolorg,inst.stumpcolorb,inst.stumpcolora)
    if not inst.monster then
      inst.AnimState:SetBuild("tree_leaf_trunk_build")
      inst.AnimState:SetBank("tree_leaf")
      inst.AnimState:PushAnimation("stump_"..inst.stumpanims)
      inst.Transform:SetScale(inst.stumpscalex, inst.stumpscaley, inst.stumpscalez)
      inst.AnimState:SetMultColour(inst.stumpcolorr,inst.stumpcolorg,inst.stumpcolorb,inst.stumpcolora)
    else
      inst.AnimState:SetBuild("tree_leaf_trunk_build")
      inst.AnimState:SetBank("tree_leaf_monster")
      inst.AnimState:PushAnimation("stump_"..inst.stumpanims)
      inst.AnimState:OverrideSymbol("legs", "tree_leaf_poison_build", "legs")
      inst.AnimState:OverrideSymbol("legs_mouseover", "tree_leaf_poison_build", "legs_mouseover")
      inst.AnimState:SetMultColour(inst.stumpcolorr,inst.stumpcolorg,inst.stumpcolorb,inst.stumpcolora)
    end

    AddGrowerToStump(inst)

    inst.GrowUp(inst)
  end

  inst.MakeStumpGrow = MakeStumpGrow

  local function auto_crumble_burnt_tree(inst, chopper)
    -- DS and DS_RoG and DST : same code
    inst:RemoveComponent("workable")
    inst.SoundEmitter:PlaySound("dontstarve/forest/treeCrumble")
    --inst.SoundEmitter:PlaySound("dontstarve/wilson/use_axe_tree")
    inst.AnimState:PlayAnimation(inst.anims.chop_burnt)
    GLOBAL.RemovePhysicsColliders(inst)
    inst:ListenForEvent("animover", function() inst:Remove() end)
    inst.components.lootdropper:SpawnLootPrefab("charcoal")
    inst.components.lootdropper:DropLoot()
    if treetype ~= "deciduoustree" then
      if inst.pineconetask then
        inst.pineconetask:Cancel()
        inst.pineconetask = nil
      end
    else
      if inst.acorntask then
        inst.acorntask:Cancel()
        inst.acorntask = nil
      end
    end

    inst:DoTaskInTime(1, function(inst)
      local target = GLOBAL.FindEntity(inst, 5,
        function(seed) 
          return seed.prefab == TREE_SEEDS[treetype]
        end)
      if target ~= nil then
        target.components.deployable.ondeploy(target, GLOBAL.Vector3(target.Transform:GetWorldPosition()))
        --print("target: ", target)
      end
    end)
  end

  local function MakeBurntTreeAutoCrumble(inst)
    local function autocrumble(inst)
      if inst:HasTag("burnt") then
        --inst.components.workable.onfinish(inst, nil)
        auto_crumble_burnt_tree(inst, nil)
      else
        --print("no burnt tag: ", inst, "  fire tag ? : ", inst:HasTag("fire"))
      end
    end

    local crumbletime
    if inst.growtime == nil then
      crumbletime = GetTimeToAutoCrumble(inst)
      inst.growtime = crumbletime + GLOBAL.GetTime()
    else
      crumbletime = inst.growtime - GLOBAL.GetTime()
    end

    inst.autocrumbletask = inst:DoTaskInTime(crumbletime, autocrumble)
    --inst.autocrumbletask = inst:DoTaskInTime(30, autocrumble)
    --print("e: autocrumbletask", inst)
  end

  inst.MakeBurntTreeAutoCrumble = MakeBurntTreeAutoCrumble

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

  local onsave_base = inst.OnSave
  inst.OnSave = function(inst, data)
    onsave_base(inst, data)
    if inst.build then
      data.build = inst.build
    end
    if inst.growtime ~= nil then
      data.growtime = inst.growtime - GLOBAL.GetTime()
    end
    if inst.stumpstage ~= nil then
      data.stumpstage = inst.stumpstage
    end
    if inst.stumpscalex ~= nil then
      data.stumpscalex = inst.stumpscalex
    end
    if inst.stumpscaley ~= nil then
      data.stumpscaley = inst.stumpscaley
    end
    if inst.stumpscalez ~= nil then
      data.stumpscalez = inst.stumpscalez
    end
    if inst.stumpanims ~= nil then
      data.stumpanims = inst.stumpanims
    end
    if inst.stumpname ~= nil then
      data.stumpname = inst.stumpname
    end
    if inst.stumpcolorr ~= nil then
      data.stumpcolorr = inst.stumpcolorr
    end
    if inst.stumpcolorg ~= nil then
      data.stumpcolorg = inst.stumpcolorg
    end
    if inst.stumpcolorb ~= nil then
      data.stumpcolorb = inst.stumpcolorb
    end
    if inst.stumpcolora ~= nil then
      data.stumpcolora = inst.stumpcolora
    end
    if inst.stumpplanted ~= nil then
      data.stumpplanted = inst.stumpplanted
    end
    if inst.stumpwithered ~= nil then
      data.stumpwithered = inst.stumpwithered
    end
    if inst.stumpsproutstage ~= nil then
      data.stumpsproutstage = inst.stumpsproutstage
    end
    if inst.stumpproduct ~= nil then
      data.stumpproduct = inst.stumpproduct
    end
    if inst.stumpflowername ~= nil then
      data.stumpflowername = inst.stumpflowername
    end
    if inst.components.grower and inst.components.grower.cycles_left ~= nil then
      --data.crops = inst.components.grower:OnSave().crops
      data.cycles_left = inst.components.grower.cycles_left
    end
  end

  local onload_base = inst.OnLoad
  inst.OnLoad = function(inst, data)
    onload_base(inst, data)
--    if inst:HasTag("stump") then
    if data and data.stump then
      if inst.components.sproutable == nil then inst:AddComponent("sproutable") end
      if data and data.build ~= nil then
        inst.build = data.build
      end
      if data and data.growtime ~= nil then
        inst.growtime = data.growtime + GLOBAL.GetTime()
      end
      if data and data.stumpstage ~= nil then
        inst.stumpstage = data.stumpstage
      end
      if data and data.stumpscalex ~= nil then
        inst.stumpscalex = data.stumpscalex
      end
      if data and data.stumpscaley ~= nil then
        inst.stumpscaley = data.stumpscaley
      end
      if data and data.stumpscalez ~= nil then
        inst.stumpscalez = data.stumpscalez
      end
      if data and data.stumpanims ~= nil then
        inst.stumpanims = data.stumpanims
      end
      if data and data.stumpname ~= nil then
        inst.stumpname = data.stumpname
      end
      if data and data.stumpcolorr ~= nil then
        inst.stumpcolorr = data.stumpcolorr
      end
      if data and data.stumpcolorg ~= nil then
        inst.stumpcolorg = data.stumpcolorg
      end
      if data and data.stumpcolorb ~= nil then
        inst.stumpcolorb = data.stumpcolorb
      end
      if data and data.stumpcolora ~= nil then
        inst.stumpcolora = data.stumpcolora
      end
      if data and data.stumpplanted ~= nil then
        inst.stumpplanted = data.stumpplanted
      end
      if data and data.stumpwithered ~= nil then
        inst.stumpwithered = data.stumpwithered
      end
      if data and data.stumpsproutstage ~= nil then
        inst.stumpsproutstage = data.stumpsproutstage
      end
      if data and data.stumpproduct ~= nil then
        inst.stumpproduct = data.stumpproduct
      end
      if data and data.stumpflowername ~= nil then
        inst.stumpflowername = data.stumpflowername
      end
      local stumpplanted = inst.stumpplanted
      MakeStumpGrow(inst)
      inst:DoTaskInTime(0, function()
        if stumpplanted == true and
           inst.components.grower ~= nil and
           inst.stumpsproutstage == 0
        then
          local seeds = GLOBAL.SpawnPrefab("seeds")
          inst.components.grower:PlantItem(seeds)
        end
        if data and data.cycles_left then
          inst.components.grower.cycles_left = data.cycles_left
        end
        -- deciduoustree bug fix
        GLOBAL.MakeSmallBurnable(inst)
      end)
    elseif data and data.burnt then
      if OptAutoCrumble == true then
        MakeBurntTreeAutoCrumble(inst)
      end
    end
  end

  local function OnRemoveEntity(inst)
    --print("e:OnRemoveEntity:inst", inst)
    CancelAllTasks(inst)
    RemoveChildren(inst)
    if inst.components.sproutable then
      --print("e:OnRemoveEntity:RemoveComponent:sproutable")
      inst:RemoveComponent("sproutable")
    end
  end

  inst.OnRemoveEntity = OnRemoveEntity

end

local function EvergreenPrefabPostInit(inst)
    TreePrefabPostInit(inst,"evergreen")
end

AddPrefabPostInit("evergreen", EvergreenPrefabPostInit)
AddPrefabPostInit("evergreen_normal", EvergreenPrefabPostInit)
AddPrefabPostInit("evergreen_tall", EvergreenPrefabPostInit)
AddPrefabPostInit("evergreen_short", EvergreenPrefabPostInit)
AddPrefabPostInit("evergreen_sparse", EvergreenPrefabPostInit)
AddPrefabPostInit("evergreen_sparse_normal", EvergreenPrefabPostInit)
AddPrefabPostInit("evergreen_sparse_tall", EvergreenPrefabPostInit)
AddPrefabPostInit("evergreen_sparse_short", EvergreenPrefabPostInit)
AddPrefabPostInit("evergreen_burnt", EvergreenPrefabPostInit)
AddPrefabPostInit("evergreen_stump", EvergreenPrefabPostInit)

-------------------------------------------------------------------------------

local function DeciduoustreePrefabPostInit(inst)
    TreePrefabPostInit(inst,"deciduoustree")
end

AddPrefabPostInit("deciduoustree", DeciduoustreePrefabPostInit)
AddPrefabPostInit("deciduoustree_normal", DeciduoustreePrefabPostInit)
AddPrefabPostInit("deciduoustree_tall", DeciduoustreePrefabPostInit)
AddPrefabPostInit("deciduoustree_short", DeciduoustreePrefabPostInit)
AddPrefabPostInit("deciduoustree_burnt", DeciduoustreePrefabPostInit)
AddPrefabPostInit("deciduoustree_stump", DeciduoustreePrefabPostInit)
AddPrefabPostInit("deciduous_root", DeciduoustreePrefabPostInit)

-------------------------------------------------------------------------------

local function JungletreePrefabPostInit(inst)
    TreePrefabPostInit(inst,"jungletree")
end

AddPrefabPostInit("jungletree", JungletreePrefabPostInit)
AddPrefabPostInit("jungletree_normal", JungletreePrefabPostInit)
AddPrefabPostInit("jungletree_tall", JungletreePrefabPostInit)
AddPrefabPostInit("jungletree_short", JungletreePrefabPostInit)
AddPrefabPostInit("jungletree_burnt", JungletreePrefabPostInit)
AddPrefabPostInit("jungletree_stump", JungletreePrefabPostInit)
AddPrefabPostInit("jungle_root", JungletreePrefabPostInit)
-------------------------------------------------------------------------------

local function PalmtreePrefabPostInit(inst)
    TreePrefabPostInit(inst,"palmtree")
end

AddPrefabPostInit("palmtree", PalmtreePrefabPostInit)
AddPrefabPostInit("palmtree_normal", PalmtreePrefabPostInit)
AddPrefabPostInit("palmtree_tall", PalmtreePrefabPostInit)
AddPrefabPostInit("palmtree_short", PalmtreePrefabPostInit)
AddPrefabPostInit("palmtree_burnt", PalmtreePrefabPostInit)
AddPrefabPostInit("palmtree_stump", PalmtreePrefabPostInit)
AddPrefabPostInit("palm_root", PalmtreePrefabPostInit)
-------------------------------------------------------------------------------

--local function BurnableClassPostConstruct(self)
local function BurnableComponentPostInit(self)
  local burnable_setonburntfn_base = self.SetOnBurntFn
  self.SetOnBurntFn = function(self, fn)
    --assert(fn ~= nil) -- gunpowder == nil
    --if fn == nil then return end
    local onburnt_base = fn
    local function onburnt_for_trees(inst)
      if inst.prefab == "evergreen" or
         inst.prefab == "evergreen_sparse" or
         inst.prefab == "jungletree" or
         inst.prefab == "palmtree" or
         inst.prefab == "deciduoustree"
      then
        if inst.components.sproutable and
           inst.components.sproutable.instsprout and
           inst.components.sproutable.instsprout:IsValid() and
           inst.components.sproutable.instsprout.components.burnable and
           inst.components.sproutable.instsprout.components.burnable.onburnt
        then
          --print("onburnt_for_trees -> instsprout -> onburnt")
          inst.components.sproutable.instsprout.components.burnable.onburnt(inst.components.sproutable.instsprout)
        end

        if inst.components.sproutable and
           inst.components.sproutable.instsprout and
           inst.components.sproutable.instsprout:IsValid()
        then
          --print("onburnt_for_trees -> CancelAllTasks and RemoveChildren")
          CancelAllTasks(inst)
          RemoveChildren(inst)
        end

        if onburnt_base ~= nil then
          --print("onburnt_for_trees -> onburnt_base")
          onburnt_base(inst)
        end

        if inst:IsValid() and
           inst:HasTag("burnt") and
           not inst:HasTag("stump") and
           inst.MakeBurntTreeAutoCrumble ~= nil and
           OptAutoCrumble == true
        then
          --print("onburnt_for_trees -> MakeBurntTreeAutoCrumble")
          inst:MakeBurntTreeAutoCrumble()
        end

        if inst:IsValid() and
           not inst:HasTag("burnt") and
           inst:HasTag("stump") and
           inst.components.sproutable
        then
          --print("onburnt_for_trees -> StartGrowing")
          inst.growtime = nil
          inst:StartGrowing()
        end
      else
        if onburnt_base ~= nil then
          --print("[not trees] onburnt_for_trees -> onburnt_base")
          onburnt_base(inst)
        end
      end
    end
    burnable_setonburntfn_base(self, onburnt_for_trees)
  end
end

AddComponentPostInit("burnable", BurnableComponentPostInit)
--AddClassPostConstruct("components/burnable", BurnableClassPostConstruct)

-------------------------------------------------------------------------------

--local function WorkableClassPostConstruct(self)
local function WorkableComponentPostInit(self)

  local workable_setonfinishcallback_base = self.SetOnFinishCallback
  self.SetOnFinishCallback = function(self, fn)

    if OptDebug then assert(fn ~= nil) end
    local onfinish_base = fn
    --self.inst:DoTaskInTime(0, function(inst)
    --print("inst: ", inst, "  [1st] onfinish_base: ", onfinish_base, "  burnt: ", inst:HasTag("burnt"), "  fire: ", inst:HasTag("fire"))
    --end)
    local function onfinish_for_stump(inst, worker)
      local stage
      local scalex,scaley,scalez
      local anims
      local monster
      local name
      local colorr,colorg,colorb,colora
      if inst:IsValid() and
         (inst.prefab == "evergreen" or
          inst.prefab == "evergreen_sparse" or
          inst.prefab == "jungletree" or
          inst.prefab == "palmtree" or
          inst.prefab == "deciduoustree") and
         inst.components.growable and
         not inst:HasTag("stump")
      then
        stage = inst.components.growable.stage
        scalex,scaley,scalez = inst.Transform:GetScale()
        monster = inst.monster or false
        if monster then
          anims = "tall_monster"
          name = "tall_monster"
        else
          anims = inst.anims.stump:match("stump_(.+)")
          name = inst.components.growable.stages[stage].name
        end
        colorr,colorg,colorb,colora = inst.AnimState:GetMultColour()

        --print("inst: ", inst, "  [called] onfinish_base: ", onfinish_base, "  burnt: ", inst:HasTag("burnt"), "  fire: ", inst:HasTag("fire"))
        onfinish_base(inst, worker)

        if inst.components.sproutable == nil then inst:AddComponent("sproutable") end
        inst.stumpstage = stage
        inst.stumpscalex = scalex
        inst.stumpscaley = scaley
        inst.stumpscalez = scalez
        inst.stumpanims = anims
        inst.stumpname = name
        inst.stumpcolorr = colorr
        inst.stumpcolorg = colorg
        inst.stumpcolorb = colorb
        inst.stumpcolora = colora
        inst.stumpplanted = false
        inst.stumpwithered = false
        inst.stumpsproutstage = 0
        inst.stumpproduct = nil
        inst.stumpflowername = nil
        if OptDebug then assert(inst.MakeStumpGrow ~= nil) end
        if inst.MakeStumpGrow then inst:MakeStumpGrow() end
      else
        onfinish_base(inst, worker)
      end
    end

    workable_setonfinishcallback_base(self, onfinish_for_stump)
  end
end

AddComponentPostInit("workable", WorkableComponentPostInit)
--if not IsDST then
--  AddClassPostConstruct("components/workable", WorkableClassPostConstruct)
--else
--  local workable = require "components/workable"
--  WorkableClassPostConstruct(workable)
--end

-------------------------------------------------------------------------------

if not IsDST then
  --local function FertilizerClassPostConstruct(self)
  local function FertilizerComponentPostInit(self)
    local fertilizercollectuseactionsbase = self.CollectUseActions
    self.CollectUseActions = function(self, doer, target, actions)
      fertilizercollectuseactionsbase(self, doer, target, actions)
      if target.components.sprout and not target.components.sprout:IsReadyForHarvest() then
        table.insert(actions, GLOBAL.ACTIONS.FERTILIZE)
      end
    end
  end

  AddComponentPostInit("fertilizer", FertilizerComponentPostInit)
  --AddClassPostConstruct("components/fertilizer", FertilizerClassPostConstruct)
else
--  local FERTILIZE_SPROUT = GLOBAL.Action()
--  FERTILIZE_SPROUT.str = "Fertilize"
--  FERTILIZE_SPROUT.id = "FERTILIZE_SPROUT"
--  FERTILIZE_SPROUT.fn = function(act)
--    print("FERTILIZE_SPROUT.fn")
--    if act.target and
--       act.target.components.sprout and
--       not act.target.components.sprout:IsReadyForHarvest() and
--       not act.target:HasTag("withered") and
--       act.invobject and
--       act.invobject.components.fertilizer
--    then
--      local obj = act.invobject

--      if act.target.components.crop:Fertilize(obj, act.doer) then
--        return true
--      else
--        return false
--      end
--    end
--  end

--  AddAction(FERTILIZE_SPROUT)

--  AddStategraphActionHandler("wilson", GLOBAL.ActionHandler(FERTILIZE_SPROUT, "doshortaction"))

--  local function FertilizerComponentAction(inst, doer, target, actions, right)
--    if right then
--      if target.components.sprout and not target.components.sprout:IsReadyForHarvest() then
--        --print("table.insert:ACTIONS.FERTILIZE_SPROUT")
  --        if OptDebug then assert(GLOBAL.ACTIONS.FERTILIZE_SPROUT ~= nil) end
----        table.insert(actions, GLOBAL.ACTIONS.FERTILIZE_SPROUT)
--        table.insert(actions, GLOBAL.ACTIONS.FERTILIZE)
--      end
--    end
--  end
--  AddComponentAction("USEITEM", "fertilizer", FertilizerComponentAction)
end
