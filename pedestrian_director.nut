IncludeScript("pedestrian_population.nut");
IncludeScript("pedestrian_stats.nut");
printl("[PEDESTRIAN DIRECTOR] Successfully Loaded!")

local ChaosSounds = 
[
    "sfx/war/warloop01.wav","ambient/levels/streetwar/city_battle2.wav","ambient/levels/streetwar/city_battle3.wav","ambient/levels/streetwar/city_battle4.wav",
    "ambient/levels/streetwar/city_battle5.wav","ambient/levels/streetwar/city_battle6.wav","ambient/levels/streetwar/city_battle7.wav",
    "ambient/levels/streetwar/city_battle8.wav","ambient/levels/streetwar/city_battle9.wav", "ambient/levels/streetwar/city_battle19.wav"
]

for(local i = 0; i < ChaosSounds.len(); i++)
{
    PrecacheSound(ChaosSounds[i]);
}

// Configuration
POPULATION <- DEFAULT_POPULATION;
MAX_NPCS <- 20;        // Maximum allowed NPCs at once
MAX_NORMAL <- 20;      // Maximum allowed non-armed NPCs
MAX_ARMED <- 20;       // Maximum allowed Armed NPCs
MAX_PROJECTILE <- 8;   // Maximum allowed Projectile weapon NPCs
MAX_MELEE <- 20        // Maximum allowed Melee NPCs
SPAWN_TIMER <- 2.0     // Wait this total seconds until next NPC Spawn.
SPAWN_BEHIND_WALLS <- true; //If true the NPCs will ONLY spawn places where players cannot see.
DESPAWN_DIST <- 2600;  // Kill NPC if further than this
SPAWN_DIST_MIN <- 800; // MINIMUM SPAWN DISTANCE 
SPAWN_DIST_MAX <- 2000;// MAXIMUM SPAWN DISTANCE
CHAOS_MODE <- false; //NPCs will run around and shoot randomly (projectile class only), along with riot/war type of sound effects.
CHAOS_ONSLAUGHT <- "c1_gunshop_onslaught";
CHAOS_MODE_NEXT_SOUND_TIMER <- 5.0;
CHAOS_MODE_AMBIENT <- null;
spawnTimer <- 0.0;

function DirectorConfigure(_spawndistmin = 800, _spawndistmax = 2000, _despawndist = 2600, _maxnpcs = 20, _behindwalls = 1, _spawn_timer = 2.0)
{
    //I do not recommend setting max npc limit to more than 35
    SPAWN_DIST_MIN = _spawndistmin;
    SPAWN_DIST_MAX = _spawndistmax;
    DESPAWN_DIST = _despawndist;
    MAX_NPCS = _maxnpcs;
    SPAWN_TIMER = _spawn_timer;
    if (_behindwalls == 1)
    {
        SPAWN_BEHIND_WALLS = true;
    }
    else 
    {
        SPAWN_BEHIND_WALLS = false;
    }
    printl("[NPC DIRECTOR] NEW CONFIG: MINIMUM SPAWN DISTANCE: " + SPAWN_DIST_MIN + " | MAXIMUM SPAWN DISTANCE: " + SPAWN_DIST_MAX + " | DESPAWN DISTANCE: " + DESPAWN_DIST + " | MAX NPCS: " + MAX_NPCS + " | BEHIND WALLS?: " + SPAWN_BEHIND_WALLS);
}

function ConfigureNPCLimit(_maxNormal = 20, _maxArmed = 15, _maxProjectile = 7, _maxMelee = 20)
{
    MAX_NORMAL = _maxNormal;
    MAX_ARMED = _maxArmed;
    MAX_PROJECTILE = _maxProjectile;
    MAX_MELEE = _maxMelee;
    printl("[NPC DIRECTOR] NEW NPC LIMIT CONFIG: MAX NORMALS: " + MAX_NORMAL + " | MAX ARMED: " + MAX_ARMED + " | MAX PROJECTILE: " + MAX_PROJECTILE + " | MAX MELEE: " + MAX_MELEE);
}

function NPCDirectorThink()
{
    local players = [];
    local ent = null;
    
    while (ent = Entities.FindByClassname(ent, "player"))
    {
        if (ent.IsSurvivor()) players.push(ent);
    }

    local npc = null;
    while (npc = Entities.FindByName(npc, "NPCpedestrian*"))
    {
        local tooFar = true;
        foreach (p in players)
        {
            if ((npc.GetOrigin() - p.GetOrigin()).Length() < DESPAWN_DIST)
            {
                tooFar = false;
                break;
            }
        }

        if (tooFar) {
            DebugDrawBox(npc.GetOrigin(), Vector(-10, -10, -10), Vector(10, 10, 10), 255, 0, 0, 255, 5.0); //debugging purpose only.
            npc.Kill(); // Clean up npc
            ::globalNPCCount--;
            local npc_scope = npc.GetScriptScope()
            if (npc_scope && ("Controller" in npc_scope))
            if ("npcClassNumber" in npc_scope.Controller)
            {
                switch(npc_scope.Controller.npcClassNumber)
                {
                    case 1: //non-armed
                    {
                        ::NONARMEDNPC_COUNT--;
                        break;
                    }
                    case 2: //armed
                    {
                        ::FIREARMNPC_COUNT--;
                        break;
                    }
                    case 3: case 4: //projectile
                    {
                        ::PROJECTILENPC_COUNT--;
                        break;
                    }
                    case 5: //melee
                    {
                        ::MELEENPC_COUNT--;
                        break;
                    }
                }
            }
            
        }
        else 
        {
            //::globalNPCCount++;
        }
    }

    spawnTimer -= 1.0;
    if (::globalNPCCount < MAX_NPCS && spawnTimer <= 0)
    {
        local validPoints = [];
        
        foreach (p in players)
        {
            local navAreas = GetNavAreasFromDistance(SPAWN_DIST_MIN, SPAWN_DIST_MAX, p);
            if (navAreas != null && navAreas.len() > 0 && SPAWN_BEHIND_WALLS)
            {
                // few random areas from this player's radius
                for (local i = 0; i < 3; i++) 
                {
                    local randomNav = navAreas[RandomInt(0, navAreas.len() - 1)];
                    local spawnPos = randomNav.GetCenter() + Vector(0, 0, 5);
                    
                    // Visibility Check
                    local visibleToAnyone = false;
                    foreach (otherPlayer in players)
                    {
                        local TraceTable = {
                            start = spawnPos + Vector(0, 0, 30),
                            end = otherPlayer.GetOrigin() + Vector(0, 0, 30),
                            mask = DirectorScript.TRACE_MASK_VISION,
                            ignore = otherPlayer
                        };

                        if (TraceLine(TraceTable))
                        {
                            if (!TraceTable.hit) // looks like we have line of sight to a player.
                            {
                                if (!Director.IsLocationFoggedToSurvivors(spawnPos))
                                {
                                    visibleToAnyone = true;
                                    break;
                                }
                            }
                        }
                    }

                    if (!visibleToAnyone)
                    {
                        validPoints.push(spawnPos);
                    }
                }
            }
            else if(navAreas != null && navAreas.len() > 0 && !SPAWN_BEHIND_WALLS)
            {
                foreach(navArea in navAreas)
                {
                    local isValid = true;
                    local spawnPos = navArea.GetCenter() + Vector(0, 0, 5);
                    foreach(otherPlayer in players)
                    {
                        local theLength = (otherPlayer.GetOrigin() - spawnPos).Length()
                        if(theLength <= SPAWN_DIST_MIN || theLength >= SPAWN_DIST_MAX)
                        {
                            isValid = false;
                            break;
                        }
                    }
                    if (isValid)
                    {
                        validPoints.push(spawnPos);
                    }
                }
            }
        }
            
        if (validPoints.len() > 0)
        {
            local pick = validPoints[RandomInt(0, validPoints.len() - 1)];
            DebugDrawBox(pick, Vector(-10, -10, -10), Vector(10, 10, 10), 255, 255, 255, 255, 5.0); //debugging purpose only.
            SpawnFromPopulation(pick);
            spawnTimer = SPAWN_TIMER;
        }
    }

    if (CHAOS_MODE)
    {
        CHAOS_MODE_NEXT_SOUND_TIMER -= 1.0;
        if (CHAOS_MODE_NEXT_SOUND_TIMER <= 0)
        {
            local sound = ChaosSounds[RandomInt(1, ChaosSounds.len() - 1)];
            EmitAmbientSoundOn(sound, RandomFloat(0.7, 1.0), 0, RandomInt(95, 105), CHAOS_MODE_AMBIENT);
            CHAOS_MODE_NEXT_SOUND_TIMER = RandomInt(9, 30);
        }
        while (ent = Entities.FindByClassname(ent, "prop_dynamic"))
        {
            if (ent.ValidateScriptScope())
            {
                local scope = ent.GetScriptScope()
                if ("Controller" in scope)
                {
                    if("RiotMode" in scope.Controller)
                    {
                        scope.Controller.RiotMode(1);
                    }
                }
            }
        }
    }

    return 1; //formeryl 0.5, changed to 1 to increase performance.
}

function GetNavAreasFromDistance(_minDistance, _maxDistance, _player)
{
    local areas = {};
    NavMesh.GetNavAreasInRadius(_player.GetOrigin(), _maxDistance, areas);

    local validAreas = [];

    if (areas == null) return null;

    foreach(id, area in areas)
    {
        local dist = (area.GetCenter() - _player.GetOrigin()).Length();
        
        if (dist >= _minDistance && dist <= _maxDistance)
        {
            if(area.HasAttributes(1 << 11 | 1 << 20))
            {
                continue;
            }

            validAreas.push(area);
        }
    }
    return validAreas;
}

function SpawnFromPopulation(_vectorOrigin)
{
    local populationRandom = RandomInt(0, POPULATION.len() - 1);
    local npcData = POPULATION[populationRandom];
    //local tryAnotherNPC = false;

    local weaponChoice = npcData[12];
    local skinChoice = npcData[10];

    switch(npcData[0])
    {
        case 1: //non-armed
        {
            if(::NONARMEDNPC_COUNT >= MAX_NORMAL) return false; break;
        }
        case 2: //Armed
        {
            if(::FIREARMNPC_COUNT >= MAX_ARMED) return false; break;
        }
        case 3: case 4: //Projectile + Mini-nuke
        {
            if(::PROJECTILENPC_COUNT >= MAX_PROJECTILE) return false; break;
        }
        case 5: //Melee
        {
            if(::MELEENPC_COUNT >= MAX_MELEE) return false; break;
        }
    }

    if(npcData[12] == -1)
    {
        if (npcData[0] == 2) { weaponChoice = RandomInt(1, 4); }
        else if (npcData[0] == 3) { weaponChoice = RandomInt(5, 7); }
        else if (npcData[0] == 4) { weaponChoice = 8; }
        else if (npcData[0] == 5) { weaponChoice = RandomInt(0, 10); }
    }
    if (npcData[10] == -1) { skinChoice = RandomInt(0, 3); }
    
    SpawnNPC(npcData[0], _vectorOrigin, npcData[1], npcData[2], npcData[3], npcData[4], npcData[5], npcData[6], npcData[7], npcData[8], npcData[9], skinChoice, npcData[11], weaponChoice)
    return true;
}

function ChangePopulationMap()
{
    local mapName = Director.GetMapName();
    switch(mapName)
    {
        case "tsp_npctest":
        {
            POPULATION = TSP_NPCTEST_POPULATION;
            printl("[PEDESTIRAN DIRECTOR] Population set to TSP_NPCTEST_POPULATION");
            break;
        }
        case "blop4dead_03":
        {
            POPULATION = BLOP4DEAD_03_POPULATION;
            printl("[PEDESTIRAN DIRECTOR] Population set to BLOP4DEAD_03_POPULATION");
            break;
        }
        case "blop4dead_04":
        {
            POPULATION = BLOP4DEAD_04_POPULATION;
            printl("[PEDESTIRAN DIRECTOR] Population set to BLOP4DEAD_04_POPULATION");
            break;
        }
        default:
        {
            printl("[PEDESTIRAN DIRECTOR] Map not recognized, using DEFAULT_POPULATION");
            POPULATION = DEFAULT_POPULATION;
            break;
        }
    }
}

function ChangePopulationByID(id=0)
{
    switch(id)
    {
        case 0:
        {
            POPULATION = FIGHTFIGHTFIGHT_POPULATION;
            printl("POPULATION CHANGED: FIGHT FIGHT FIGHT!");
            break;
        }
        default:
        {
            printl("[PEDESTIRAN DIRECTOR] Map not recognized, using DEFAULT_POPULATION");
            POPULATION = DEFAULT_POPULATION;
            break;
        }
    }
}

function DirectorStart()
{
    AddThinkToEnt(self, "NPCDirectorThink");
}

function DirectorStop()
{
    AddThinkToEnt(self, null);
}

function DebugShowForbiddenAreas()
{
    local navAreas = {};
    NavMesh.GetNavAreasInRadius(Vector(0, 0, 0), 99999.0, navAreas);
    foreach(id, area in navAreas)
    {
        printl(area.GetAttributes().tostring()); //WHY THIS SHIT DOESN'T PRINT????
        DebugDrawText(area.GetCenter(), area.GetAttributes().tostring(), true, 10.0);
        if(area.HasAttributes(1 << 11 | 1 << 20)) //navs marked with LYINGDOWN or NO_HOSTAGES is forbidden.
        {
            DebugDrawBox(area.GetCenter(), Vector(-20, -20, -20), Vector(20, 20, 20), 255, 0, 0, 255, 10.0);
        }
    }
}

::ChaosMode <- function(toggle, onslaught = 0)
{
    if(toggle == 1)
    {
        CHAOS_MODE = true;
        local ent = null;
        while (ent = Entities.FindByClassname(ent, "prop_dynamic"))
        {
            if (ent.ValidateScriptScope())
            {
                local scope = ent.GetScriptScope()
                if ("Controller" in scope)
                {
                    if("RiotMode" in scope.Controller)
                    {
                        scope.Controller.RiotMode(1);
                    }
                }
            }
        }
        if(onslaught == 1)
        {
            DoEntFire("director", "BeginScript", CHAOS_ONSLAUGHT, 0.00, null, null);
        }

        CHAOS_MODE_AMBIENT = SpawnEntityFromTable("ambient_generic", {targetname = "RIOTAMBIENT", message = ChaosSounds[0], spawnflags = 1, health = 8});
    }
    else
    {
        CHAOS_MODE = false;
        local ent = null;
        while (ent = Entities.FindByClassname(ent, "prop_dynamic"))
        {
            if (ent.ValidateScriptScope())
            {
                local scope = ent.GetScriptScope()
                if ("Controller" in scope)
                {
                    if("RiotMode" in scope.Controller)
                    {
                        scope.Controller.RiotMode(0);
                    }
                }
            }
        }
        if(onslaught == 1)
        {
            DoEntFire("director", "EndScript", "", 0.00, null, null);
        }
        local riotAmbient = Entities.FindByName(null, "RIOTAMBIENT");
        if(riotAmbient) DoEntFire("RIOTAMBIENT", "StopSound", "", 0.0, null, null); riotAmbient.Kill(); CHAOS_MODE_AMBIENT = null;
    }
}

//==============================================COMMON ATTACK ENTITY================================================//


local npcCommonAttack = SpawnEntityFromTable("info_target", {targetname = "NPCCOMMONATTACKENTITY"});
local npcCommonAttackScope = npcCommonAttack.GetScriptScope()

if (npcCommonAttack.ValidateScriptScope())
{
    local npcCommonAttackScope = npcCommonAttack.GetScriptScope();

    npcCommonAttackScope.ZombieAttackThink <- function()
    {
        local zombieent = null;
        local npcent = null;
        local commonzombies = [];
        local npccharacters = [];
        
        while(zombieent = Entities.FindByClassname(zombieent, "infected"))
        {
            if(zombieent && zombieent.IsValid()) 
            {
                if(NetProps.GetPropInt(zombieent, "m_clientLookatTarget") <= -1 && zombieent.GetContext("AffactedByNPCAttacker") == null)
                {
                    zombieent.SetContext("AffactedByNPCAttacker", "Yes", 10.0); // Set to 10s so they can re-target later
                    commonzombies.push(zombieent);
                }
            }
        }

        while(npcent = Entities.FindByClassname(npcent, "prop_dynamic"))
        {
            // Check if valid BEFORE asking for the model name
            if(npcent && npcent.IsValid())
            {
                try {
                    if(npcent.GetModelName() == "models/blop4dead/npchitbox.mdl")
                    {
                        npccharacters.push(npcent);
                    }
                } catch(e) { continue; } // Skip if the model name check fails
            }
        }

        if (commonzombies.len() == 0 || npccharacters.len() == 0) { return 1.0; } 

        while(zombieent = Entities.FindByClassname(zombieent, "infected"))
        {
            if(zombieent && zombieent.IsValid())
            {
                // Ensure NetProps is valid too
                try {
                    if(NetProps.GetPropInt(zombieent, "m_clientLookatTarget") <= -1 && zombieent.GetContext("AffactedByNPCAttacker") == null)
                    {
                        zombieent.SetContext("AffactedByNPCAttacker", "Yes", 10.0);
                        commonzombies.push(zombieent);
                    }
                } catch(e) {}
            }
        }

        foreach(zombie in commonzombies)
        {
            // Double check the zombie didn't die in the last 0.01 seconds
            if (!zombie || !zombie.IsValid()) continue;

            local closestNPC = null;
            local minDistance = 400.0;

            foreach(npc in npccharacters)
            {
                // Double check the NPC is still there
                if (!npc || !npc.IsValid()) continue;

                local dist = (npc.GetOrigin() - zombie.GetOrigin()).Length2D();
                if (dist < minDistance)
                {
                    minDistance = dist;
                    closestNPC = npc;
                }
            }

            if (closestNPC != null)
            {
                local commands =
                {
                    cmd = DirectorScript.BOT_CMD_ATTACK,
                    target = closestNPC,
                    bot = zombie
                };

                CommandABot(commands);
            }
        }
        return 5.0; // Return time for the next 'Think'
    }

    // Start the thinking process
    AddThinkToEnt(npcCommonAttack, "ZombieAttackThink");
}