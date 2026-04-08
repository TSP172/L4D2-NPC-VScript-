//=======================================================================\\
//		Copyright TSP172 || https://steamcommunity.com/id/tsp172/        \\
// 		You can freely modify and use this script in any of your maps    \\
// 		        Made for L4D2, credit is appreciated				     \\
//=======================================================================\\

//TO DO: Fix melee lock in and melee walk distance, also make melee ones attack survivors too

const defaultClip = 0x00000001 //Default
const team1Clip = 0x00000800; //Survivor Team
const team2Clip = 0x00001000; //Infected Team
const playerClip = 0x00010000; //Player Clip
const monsterClip = 0x02000000; //NPCs (common infected, witches etc.)
const moveableClip = 0x00004000; //Doors, Plats etc.

const hitBoxModelName = "models/blop4dead/npchitbox.mdl";


IncludeScript("pedestrian_stats.nut");
printl("[PEDESTRIAN NPC] Successfully Loaded!")

::currentNameID <- 0; //Name ID counter for NPCs
::currentWeaponNameID <- 0; //Ditto, for weapon models
::globalNPCCount <- 0; //count how many NPCs currently in game world.
::NONARMEDNPC_COUNT <- 0; //Seperate counter for non-armed NPCs
::FIREARMNPC_COUNT <- 0; //Seperate counter for Armed NPCs
::PROJECTILENPC_COUNT <- 0; //Seperate counter for Projectile based NPCs
::MELEENPC_COUNT <- 0;  //Seperate counter for Melee based NPCs
::globalNPCLimit <- 50; //MAX NPC limit, this is too much but I will keep in this number for now.

::CreateNPCName <- function(type) //Ignore
{
    if(type == 0)
    {
        ::currentNameID++;
        return "NPCpedestrian" + currentNameID.tostring();
    }
    else if(type == 1)
    {
        ::currentWeaponNameID++;
        return "NPCweapon" + currentWeaponNameID.tostring();
    }
}

::BindNPCToEntity <- function(ent, npcClassInstance) //Ignore
{
    ent.ValidateScriptScope();
    local scope = ent.GetScriptScope();
    scope.Controller <- npcClassInstance;

    if ("npcModel" in npcClassInstance)
    {
        npcClassInstance.npcModel = ent; 
    }
    else 
    {
        npcClassInstance.projectileEntity = ent; 
    }
}

class ::Pedestrian
{
    npcClassNumber = 1; //Class number for NPC, 1 means un-armed
    npcThinkTime = 0.03; //the default think time for npc is 0.03 seconds.
    npcNextSleepCheck = 2.0; //next sleep check delay time.
    npcHealth = 100; //self explaintory.
    npcModel = null; //self explaintory.
    npcName = null; //self explaintory.
    npcHitbox = null; //a seperate prop_dynamic that takes damage and calls "Hurt()" function.
    npcGender = 0; //0 = male, 1 = female.
    npcVoiceSet = null; //voice set for NPC, see pedestrian_stats.nut
    npcType = null; //NPC TYPES: 0 = Wander, 1 = Static. currently useless.
    npcAffiliation = null; //AFFILIATIONS: 0 = Neutral, 1 = Friendly, 2 = Hostile (seems like there is no difference between 0 and 2)
    npcAggression = 0.5; //AGGRESSION 0.0 - 1.0. works as "courage" of NPC
    npcCanTaunt = false; //can do taunts? currently useless.
    npcRange = 725; //npc vision range, only useless for non-armed NPCs(?)
    npcBodyGroup = 0; //either -2, -1 or any number should be used. -2 will give a random body number, -1 will give random body id in pedestrian_stats. any other number for specific bodyset
    npcBodySkin = 0; //Skin of NPC.
    //===========================================================================//
    npcStuckCounter = 0; //Stuck counter for NPC; dont touch.
    npcSleepRadius = 2100; //Sleep radius for NPC; for optimization purposes keep this number around 2000-3000.
    npcCurrentPathIndex = 0; //Current path index. used for navigation.
    npcLastPos = null; //Checks origin of NPC; for anti-stuck purposes.
    npcLookAheadDistance = 18; //used for multiplying traceline distance, to prevent npc walk through walls.
    npcBumpCounter = 0; //bump counter for NPC; dont touch.
    npcTurnRate = 0.5; //0.1 for extremely smooth turns, 1.0 for instant turns
    npcBusy = false; //NPC Busy boolean; dont touch.
    npcLastTalkedNPC = null; //stores which npc last talked to, to prevent npc talking same other npc over and over again.
    npcLastVisitedAreaID = null; //last visited nav area, to prevent picking same nav area over again.
    npcRiotMode = false; //Also means "chaos" mode, the npcs will aimlessly run around.
    npcIsRetreating = false; //our npc retreating?
    npcNextBackupCall = 0.0; //wait this amount of time to call backup from other npcs
    npcNextSurvivorAssistTime = 0.0; //waiğt times amound of time to help survivors that in combat
    npcRiotTime = 3.0; //riot time; dont touch
    npcBusyTime = 0; //busy time for npc, will not do certain actions when this over 0
    npcRunAwayTime = 0; //this amount of time npc run away from something.
    npcRunType = 0; //run animation id: 0 = walk, 1 = run, 2 = fear run, 3 = rush.
    npcSpeed = 0; //self explaintory.
    npcNextCombatInsult = 3.0; //wait this amount of time to play combat insult voice line
    npcWanderingOrIdling = 0; //dont touch.
    npcNextMoveTime = 5.0; //self explaintory.
    npcNextRandomQuote = 6.3; //self explaintory.
    npcShoveTime = 0.0;
    npcCurrentVoiceline = null;
    npcConversationMode = false;
    npcCurrentlyTalking = false;
    npcCurrentlyAnimated = false;
    npcCurrentAnimation = null;
    npcNavPathC = [];
    npcIsCurrentlyGoing = false;
    npcCurrentlyRunning = false;
    npcTargetAngle = 0;
    npcTurnSpeed = 3.0; 

    constructor(npcorigin, thehealth, themodel, gender, voiceSet, type, affiliation, aggression, canTaunt, bodyGroup, bodySkin, range)
    {
        ::globalNPCCount++
        ::NONARMEDNPC_COUNT++
        this.npcHealth = thehealth;
        this.npcName = CreateNPCName(0);
        this.npcModel = SpawnEntityFromTable("prop_dynamic_override", {
        targetname = this.npcName,
        model = themodel.model,
        origin = npcorigin,
        fademindist = 1500,
        fademaxdist = 2000,
        solid = 0
        });
        this.npcGender = gender;
        this.npcRange = range;
        this.npcVoiceSet = voiceSet;
        this.npcType = type;
        this.npcAffiliation = affiliation;
        this.npcAggression = aggression;
        this.npcCanTaunt = canTaunt;
        this.npcBodyGroup = bodyGroup;
        this.npcBodySkin = bodySkin;
        local filter = "filter_infected";
        if (affiliation == 2) {filter = ""} //we are hostile to survivors
        this.npcHitbox = SpawnEntityFromTable("prop_dynamic_override", {model = hitBoxModelName, damagefilter = filter, health = thehealth, disableshadows = 1, solid = 2, CollisionGroup = 16, origin = npcorigin, rendermode = 10});
        NetProps.SetPropInt(this.npcHitbox, "m_CollisionGroup", 16); //My friend says this would crash the physics engine, but I will keep it until I spot a major bug.
        DoEntFire("!self", "SetParent", this.npcModel.GetName(), 0, null, this.npcHitbox);
        NetProps.SetPropInt(this.npcModel, "m_nSkin", this.npcBodySkin);
        if(bodyGroup == -2) //pick random
        {
            NetProps.SetPropInt(this.npcModel, "m_nBody", RandomInt(0, 10000));
        }
        else if (bodyGroup == -1) //pick random in existing population
        {
            local categories = themodel.bodygroupSets;
    
            local randomCatIndex = RandomInt(0, categories.len() - 1);
            local selectedCategory = categories[randomCatIndex];

            if (typeof(selectedCategory) == "array" && selectedCategory.len() > 0)
            {
                local finalBodyID = selectedCategory[RandomInt(0, selectedCategory.len() - 1)];
                NetProps.SetPropInt(this.npcModel, "m_nBody", finalBodyID);
            }
            else if (typeof(selectedCategory) == "integer")
            {
                NetProps.SetPropInt(this.npcModel, "m_nBody", selectedCategory);
            }
        }
        else //pick specific
        {
            NetProps.SetPropInt(this.npcModel, "m_nBody", this.npcBodyGroup);
        }
        EntityOutputs.AddOutput(this.npcHitbox, "OnTakeDamage", this.npcName, "RunScriptCode", "Controller.Hurt()", 0.00, -1);
    }

    function SayQuote(quoteType, id = -1)
    {
        if (this.npcVoiceSet == null)
        {
            return;
        }

        switch(quoteType)
        {
            case 0: //Idle
            {
                if(this.npcVoiceSet.totalIdleSounds == 0) return;
                local soundNum = null;
                if (id == -1) {soundNum = RandomInt(1, this.npcVoiceSet.totalIdleSounds);} else {soundNum = id;};
                local soundPath = this.npcVoiceSet.soundDirectory + "idle" + soundNum + ".mp3";
                this.npcCurrentVoiceline = soundPath;
                EmitAmbientSoundOn(soundPath, 1, 85, 100, this.npcModel);
                break;
            }
            case 1: //Laugh
            {
                if(this.npcVoiceSet.totalLaughSounds == 0) return;
                local soundNum = null;
                if (id == -1) {soundNum = RandomInt(1, this.npcVoiceSet.totalLaughSounds);} else {soundNum = id;};
                local soundPath = this.npcVoiceSet.soundDirectory + "laugh" + soundNum + ".mp3";
                this.npcCurrentVoiceline = soundPath;
                EmitAmbientSoundOn(soundPath, 1, 85, 100, this.npcModel);
                break;
            }
            case 2: //Combat
            {
                if(this.npcVoiceSet.totalCombatSounds == 0) return;
                local soundNum = null;
                if (id == -1) {soundNum = RandomInt(1, this.npcVoiceSet.totalCombatSounds);} else {soundNum = id;};
                local soundPath = this.npcVoiceSet.soundDirectory + "combat" + soundNum + ".mp3";
                this.npcCurrentVoiceline = soundPath;
                EmitAmbientSoundOn(soundPath, 1, 85, 100, this.npcModel);
                break;
            }
            case 3: //Taunt
            {
                if(this.npcVoiceSet.totalTauntSounds == 0) return;
                local soundNum = null;
                if (id == -1) {soundNum = RandomInt(1, this.npcVoiceSet.totalTauntSounds);} else {soundNum = id;};
                local soundPath = this.npcVoiceSet.soundDirectory + "taunt" + soundNum + ".mp3";
                this.npcCurrentVoiceline = soundPath;
                EmitAmbientSoundOn(soundPath, 1, 85, 100, this.npcModel);
                break;
            }
            case 4: //Hurt
            {
                if(this.npcVoiceSet.totalHurtSounds == 0) return;
                local soundNum = null;
                if (id == -1) {soundNum = RandomInt(1, this.npcVoiceSet.totalHurtSounds);} else {soundNum = id;};
                local soundPath = this.npcVoiceSet.soundDirectory + "hurt" + soundNum + ".mp3";
                this.npcCurrentVoiceline = soundPath;
                EmitAmbientSoundOn(soundPath, 1, 85, 100, this.npcModel);
                break;
            }
            case 5: //Scream
            {
                if(this.npcVoiceSet.totalScreamSounds == 0) return;
                local soundNum = null;
                if (id == -1) {soundNum = RandomInt(1, this.npcVoiceSet.totalScreamSounds);} else {soundNum = id;};
                local soundPath = this.npcVoiceSet.soundDirectory + "scream" + soundNum + ".mp3";
                this.npcCurrentVoiceline = soundPath;
                EmitAmbientSoundOn(soundPath, 10, 85, 100, this.npcModel); //formerly 95dB
                break;
            }
            case 6: //Dialogue Start
            {
                if(this.npcVoiceSet.totalDialogueStartSounds == 0) return;
                local soundNum = null;
                if (id == -1) {soundNum = RandomInt(1, this.npcVoiceSet.totalDialogueStartSounds);} else {soundNum = id;};
                local soundPath = this.npcVoiceSet.soundDirectory + "dialogue_start" + soundNum + ".mp3";
                this.npcCurrentVoiceline = soundPath;
                EmitAmbientSoundOn(soundPath, 10, 85, 100, this.npcModel); //formerly 95dB
                break;
            }
            case 7: //Dialogue Respond
            {
                if(this.npcVoiceSet.totalDialogueRespondSounds == 0) return;
                local soundNum = null;
                if (id == -1) {soundNum = RandomInt(1, this.npcVoiceSet.totalDialogueRespondSounds);} else {soundNum = id;};
                local soundPath = this.npcVoiceSet.soundDirectory + "dialogue_respond" + soundNum + ".mp3";
                this.npcCurrentVoiceline = soundPath;
                EmitAmbientSoundOn(soundPath, 10, 85, 100, this.npcModel); //formerly 95dB
                break;
            }
            case 8: //Dialogue End
            {
                if(this.npcVoiceSet.totalDialogueEndSounds == 0) return;
                local soundNum = null;
                if (id == -1) {soundNum = RandomInt(1, this.npcVoiceSet.totalDialogueEndSounds);} else {soundNum = id;};
                local soundPath = this.npcVoiceSet.soundDirectory + "dialogue_end" + soundNum + ".mp3";
                this.npcCurrentVoiceline = soundPath;
                EmitAmbientSoundOn(soundPath, 10, 85, 100, this.npcModel); //formerly 95dB
                break;
            }
            case 9: //Confusion
            {
                if(this.npcVoiceSet.totalConfusionSounds == 0) return;
                local soundNum = null;
                if (id == -1) {soundNum = RandomInt(1, this.npcVoiceSet.totalConfusionSounds);} else {soundNum = id;};
                local soundPath = this.npcVoiceSet.soundDirectory + "confusion" + soundNum + ".mp3";
                this.npcCurrentVoiceline = soundPath;
                EmitAmbientSoundOn(soundPath, 10, 85, 100, this.npcModel); //formerly 95dB
                break;
            }
            case 10: //Death
            {
                if(this.npcVoiceSet.totalDeathSounds == 0) return;
                local soundNum = null;
                if (id == -1) {soundNum = RandomInt(1, this.npcVoiceSet.totalDeathSounds);} else {soundNum = id;};
                local soundPath = this.npcVoiceSet.soundDirectory + "death" + soundNum + ".mp3";
                this.npcCurrentVoiceline = soundPath;
                EmitAmbientSoundOn(soundPath, 10, 85, 100, this.npcModel); //formerly 95dB
                break;
            }
            case 11: //Misc Action
            {
                if(this.npcVoiceSet.totalMiscActionSounds == 0) return;
                local soundNum = null;
                if (id == -1) {soundNum = RandomInt(1, this.npcVoiceSet.totalMiscActionSounds);} else {soundNum = id;};
                local soundPath = this.npcVoiceSet.soundDirectory + "miscaction" + soundNum + ".mp3";
                this.npcCurrentVoiceline = soundPath;
                EmitAmbientSoundOn(soundPath, 10, 85, 100, this.npcModel); //formerly 95dB
                break;
            }
            case 12: //Retreat
            {
                if(this.npcVoiceSet.totalRetreatSounds == 0) return;
                local soundNum = null;
                if (id == -1) {soundNum = RandomInt(1, this.npcVoiceSet.totalRetreatSounds);} else {soundNum = id;};
                local soundPath = this.npcVoiceSet.soundDirectory + "retreat" + soundNum + ".mp3";
                this.npcCurrentVoiceline = soundPath;
                EmitAmbientSoundOn(soundPath, 10, 85, 100, this.npcModel); //formerly 95dB
                break;
            }
            case 13: //Assist
            {
                if(this.npcVoiceSet.totalAssistSounds == 0) return;
                local soundNum = null;
                if (id == -1) {soundNum = RandomInt(1, this.npcVoiceSet.totalAssistSounds);} else {soundNum = id;};
                local soundPath = this.npcVoiceSet.soundDirectory + "assist" + soundNum + ".mp3";
                this.npcCurrentVoiceline = soundPath;
                EmitAmbientSoundOn(soundPath, 10, 85, 100, this.npcModel); //formerly 95dB
                break;
            }
            case 14: //Negative
            {
                if(this.npcVoiceSet.totalNegativeSounds == 0) return;
                local soundNum = null;
                if (id == -1) {soundNum = RandomInt(1, this.npcVoiceSet.totalNegativeSounds);} else {soundNum = id;};
                local soundPath = this.npcVoiceSet.soundDirectory + "negative" + soundNum + ".mp3";
                this.npcCurrentVoiceline = soundPath;
                EmitAmbientSoundOn(soundPath, 10, 85, 100, this.npcModel); //formerly 95dB
                break;
            }
            case 15: //Victory 
            {
                if(this.npcVoiceSet.totalVictorySounds == 0) return;
                local soundNum = null;
                if (id == -1) {soundNum = RandomInt(1, this.npcVoiceSet.totalVictorySounds);} else {soundNum = id;};
                local soundPath = this.npcVoiceSet.soundDirectory + "victory" + soundNum + ".mp3";
                this.npcCurrentVoiceline = soundPath;
                EmitAmbientSoundOn(soundPath, 10, 85, 100, this.npcModel); //formerly 95dB
                break;
            }
            case 16: //Spot
            {
                if(this.npcVoiceSet.totalSpotSounds == 0) return;
                local soundNum = null;
                if (id == -1) {soundNum = RandomInt(1, this.npcVoiceSet.totalSpotSounds);} else {soundNum = id;};
                local soundPath = this.npcVoiceSet.soundDirectory + "spot" + soundNum + ".mp3";
                this.npcCurrentVoiceline = soundPath;
                EmitAmbientSoundOn(soundPath, 10, 85, 100, this.npcModel); //formerly 95dB
                break;
            }
        }
    }

    function GetGroundLegacy() //obsolete now
    {
        local traceInfo = [];

        local TraceTable = 
        {
            start = this.npcModel.GetOrigin() + Vector(0, 0, 72)
            end = this.npcModel.GetOrigin() + Vector(0, 0, -15)
            mask = DirectorScript.TRACE_MASK_PLAYER_SOLID
            ignore = this.npcHitbox
        }

        if(TraceLine(TraceTable))
        {
            if(TraceTable.hit)
            {
                traceInfo = [TraceTable.pos, TraceTable.enthit];
                return traceInfo;
            }
        }
        return null;
    }

    function BumpIntoWall()
    {
        if (this.npcBumpCounter < 200)
        {
            if(this.npcBumpCounter % 50 == 0)
            {
                this.npcTurnRate += 0.15; //the longer we stuck, the sharper we turn to try to get out of there.
            }
            this.npcBumpCounter++;
            return null;
        }
        this.npcTurnRate = 0.5;
        this.npcBumpCounter = 0;
        this.SetAnimation("blocked", 2.0);
        this.npcBusyTime = 0.5;
        //this.npcModel.SetAngles(QAngle(0, this.npcModel.GetOrigin().y + 180, 0)); // emergency 180
        this.npcSpeed = 0;
        ClearPath()
        return null;
    }

    function GetGroundAndFront(_moveSpeed, _lookAhead = 18) //decreased _lookAhead from 25 to 18 because this time we can't use stairs
    {
        local myPos = this.npcModel.GetOrigin();
        local forward = this.npcModel.GetForwardVector();
        local right = Vector(forward.y, -forward.x, 0); // Get Side Vector
        local stepHeight = Vector(0, 0, 26); //formerly 18

        local offsets = [Vector(0,0,0), right * 15, right * -15];
        
        foreach (offset in offsets)
        {
            local t1_start = myPos + stepHeight + offset;
            local t1_end = t1_start + (forward * npcLookAheadDistance);

            local trace1 = { start = t1_start, end = t1_end, mask = playerClip | monsterClip | moveableClip | defaultClip | team2Clip, ignore = this.npcHitbox};
            //playerClip | monsterClip | moveableClip | defaultClip | team2Clip
            if (TraceLine(trace1) && trace1.hit) 
            {
                if ("startsolid" in trace1 && trace1.startsolid)
                {
                    local ent = trace1.enthit;
                    if (ent == null) continue;

                    local entityCls = ent.GetClassname();

                    if (ent.GetModelName() == hitBoxModelName || ent.GetClassname() == "player")
                    {
                        continue; 
                    }

                    if(entityCls == "prop_physics" || entityCls == "worldspawn" || entityCls == "prop_dynamic")
                    {
                        return null;
                    }
                }           
            }
        }

        local moveEnd = myPos + (forward * _moveSpeed);
        
        local trace2 = { start = moveEnd + stepHeight, end = moveEnd + stepHeight + Vector(0,0,-150), mask = playerClip | monsterClip | moveableClip | defaultClip, ignore = this.npcHitbox };
        TraceLine(trace2);

        if (trace2.hit)
        {
            local ent = trace2.enthit;
            local cls = (ent != null) ? ent.GetClassname() : "";

            if (ent.GetModelName() == hitBoxModelName || cls == "player")
            {
                return moveEnd; 
            }

            if(cls == "prop_physics" || cls == "worldspawn" || cls == "prop_dynamic")
            {
                return trace2.pos;
            }
        }

        else 
        {
            local fallPos = moveEnd - Vector(0, 0, 5); 
            return fallPos; 
        }
    }

    function IsPathClear()
    {
        local forward = this.npcModel.GetForwardVector();
        local left = CrossProduct(Vector(0,0,1), forward);
        local right = CrossProduct(forward, Vector(0,0,1));
        
        local startCenter = this.npcModel.GetOrigin() + Vector(0, 0, 30);
        local dist = 45; // How far to look ahead

        // 3 parrellel lines
        local rays = [
            { s = startCenter, e = startCenter + (forward * dist) },
            { s = startCenter + (left * 18), e = startCenter + (left * 18) + (forward * dist) },
            { s = startCenter + (right * 18), e = startCenter + (right * 18) + (forward * dist) }
        ];

        foreach (ray in rays)
        {
            // L4D2 DebugDrawLine: Start, End, R, G, B, NoDepthTest
            //DebugDrawLine(ray.s, ray.e, 255, 0, 0, false, 2); 

            local t = {
                start = ray.s,
                end = ray.e,
                mask = DirectorScript.TRACE_MASK_PLAYER_SOLID,
                ignore = this.npcHitbox
            };

            TraceLine(t); 

            if (t.hit) 
            {
                return false; // path is blocked
            }
        }
        return true; // Path is actually clear
    }

    function GetFront() //no longer used.
    {
        local traceInfo = [];

        local forwardVec = this.npcModel.GetForwardVector();
        local startPos = this.npcModel.GetOrigin() + Vector(0, 0, 30);
        
        local traceStart = startPos + (forwardVec * 3);
        local traceEnd = startPos + (forwardVec * this.npcSpeed * 5);
        //DebugDrawLine(traceStart, traceEnd, 0, 255, 0, true, 2);
        local TraceTable = {
            start = traceStart
            end = traceEnd
            mask = DirectorScript.TRACE_MASK_PLAYER_SOLID
            ignore = this.npcHitbox
        }

        if (TraceLine(TraceTable))
        {
            if (TraceTable.hit)
            {
                traceInfo = [TraceTable.pos, TraceTable.enthit];
                return traceInfo;
            }
        }
        return null;
    }

    function CrossProduct(v1, v2)
    {
        return Vector(
            (v1.y * v2.z) - (v1.z * v2.y),
            (v1.z * v2.x) - (v1.x * v2.z),
            (v1.x * v2.y) - (v1.y * v2.x)
        );
    }

    function CheckSide(side, degree = 40)
    {
        local currentAngles = this.npcModel.GetAngles();
        local checkYaw = currentAngles.y;

        if (side == "right")
        {
            checkYaw -= degree; // Subtracting moves the angle to the Right
        }
        else if (side == "left")
        {
            checkYaw += degree; // Adding moves the angle to the Left
        }

        local sideVec = QAngle(0, checkYaw, 0).Forward();
        
        local startPos = this.npcModel.GetOrigin() + Vector(0, 0, 40);
        local endPos = startPos + (sideVec * 8); // formerly 45

        // Cyan line for debugging 
        //DebugDrawLine(startPos, endPos, 0, 255, 255, false, 2.0);

        local TraceTable = {
            start = startPos,
            end = endPos,
            mask = monsterClip | playerClip | moveableClip | defaultClip | team2Clip,
            ignore = this.npcHitbox,
        }


        TraceLine(TraceTable);

        if (TraceTable.hit)
        {
            if (TraceTable.enthit) 
            {
                local entityCls = TraceTable.enthit.GetClassname()
                if(entityCls == "prop_physics" || entityCls == "worldspawn")
                {
                    return true;
                }
            }
            return true;
        }
        
        return false;
    }

    function CreatePath(navOrigin) //this shit for some reason brokes the AI and gives them "Hivemind". now is only used command npcs to custom path.
    {   
        local endArea = NavMesh.GetNavArea(this.npcModel.GetOrigin(), 100); //reversed endArea and startArea because creating path reverses it.
        local startArea = NavMesh.GetNavArea(navOrigin, 100);

        if (startArea && endArea)
        {
            local myPathArray = {}; 

            if (NavMesh.NavAreaBuildPath(startArea, endArea, endArea.GetCenter(), 99999.0, 0, false))
            {
                NavMesh.GetNavAreasFromBuildPath(startArea, endArea, endArea.GetCenter(), 99999.0, 0, false, myPathArray);
                
                this.npcNavPathC = [];
                this.npcCurrentPathIndex = 0; // RESET THIS EVERY TIME

                for (local i = 0; i < myPathArray.len(); i++)
                {
                    local key = "area" + i;
                    if (key in myPathArray)
                    {
                        this.npcNavPathC.push(myPathArray[key].GetCenter());
                    }
                }

                if (this.npcNavPathC.len() > 0)
                {
                    local lastIdx = this.npcNavPathC.len() - 1;
                    local lastPoint = this.npcNavPathC[lastIdx] + Vector(0, 0, 40);
                    local adjustedPoint = this.npcNavPathC[lastIdx];

                    local checkDirs = [Vector(40,0,0), Vector(-40,0,0), Vector(0,40,0), Vector(0,-40,0)];
                    foreach (dir in checkDirs)
                    {
                        local t = { start = lastPoint, end = lastPoint + dir, mask = 33570827, ignore = this.npcHitbox };
                        if (TraceLine(t) && t.hit)
                        {
                            adjustedPoint = adjustedPoint - (dir * 0.5);
                        }
                    }

                    this.npcNavPathC[lastIdx] = adjustedPoint + Vector(RandomInt(-30, 30), RandomInt(-30, 30), 0);
                    
                    this.npcIsCurrentlyGoing = true;

                    // DEBUG: See the ordered path
                    /*
                    for(local j = 0; j < this.npcNavPathC.len(); j++) {
                        DebugDrawText(this.npcNavPathC[j], j.tostring(), false, 5.0);
                    }
                    */
                }
            }
        }
    }

    function CreatePathLegacy(navOrigin)
    {   
        local endArea = NavMesh.GetNavArea(this.npcModel.GetOrigin(), 120); //reversed because this stupid navareabuildpath function puts in reverse order.
        local startArea  = NavMesh.GetNavArea(navOrigin, 120);

        if (startArea && endArea)
        {
            local tempTable = {}; 

            if (NavMesh.NavAreaBuildPath(startArea, endArea, endArea.GetCenter(), 99999.0, 0, false))
            {
                NavMesh.GetNavAreasFromBuildPath(startArea, endArea, endArea.GetCenter(), 99999.0, 0, false, tempTable);
                
                this.npcNavPathC = []; // Clear current path
                
                for (local i = 0; i < tempTable.len(); i++)
                {
                    local key = "area" + i;
                    if (key in tempTable)
                    {
                        this.npcNavPathC.push(tempTable[key]);
                    }
                }

                this.npcCurrentPathIndex = 0;
                // printl("Path Success! " + this.npcNavPathC.len() + " steps found.");
            }
        }
    }

    function NPCPathFollower() //OBSOLETE. NEVER USED.
    {
        if (this.npcNavPathC == null || this.npcCurrentPathIndex >= this.npcNavPathC.len()) 
        {
            this.npcNavPathC = null;
            return;
        }

        local targetArea = this.npcNavPathC[this.npcCurrentPathIndex];

        if (targetArea != null)
        {
            local targetPos = targetArea.GetCenter();
            
            this.TurnToTargetAndMove(targetPos, this.npcSpeed);

            local dist = (this.npcModel.GetOrigin() - targetPos).Length();
            if (dist < 45)
            {
                this.npcCurrentPathIndex++; 
                
                // 4. Finish line
                if (this.npcCurrentPathIndex >= this.npcNavPathC.len())
                {
                    this.npcNavPathC = null;
                    this.npcCurrentPathIndex = 0;
                }
            }
        }
    }

    function IsOldLocation(location)
    {
        if (location.GetID() == this.npcLastVisitedAreaID)
        {
            //printl("NPC: Almost went back to the same spot! Picking a different one...");
            return true;
        }
        return false;
    }

    function ClearPath()
    {
        this.npcNavPathC.clear();
    }

    function StuckCheck()
    {
        if(this.npcNavPathC.len() == 0 && !this.npcBusy && !this.npcIsCurrentlyGoing)
        {
            this.npcStuckCounter++;
            if(this.npcStuckCounter > 10)
            {
                this.npcStuckCounter = 0;
                local checkDirs = [Vector(40,0,0), Vector(-40,0,0), Vector(0,40,0), Vector(0,-40,0)];
                
                foreach (dir in checkDirs)
                {
                    local npcOrigin = this.npcModel.GetOrigin() + Vector(0, 0, 40);
                    local t = {
                        start = npcOrigin, 
                        end = npcOrigin + dir, 
                        mask = 33570827, 
                        ignore = this.npcHitbox
                    }

                    if (TraceLine(t) && t.hit)
                    {
                        local enthitclass = t.enthit.GetClassname()
                        if(enthitclass == "worldspawn" || enthitclass == "prop_physics")
                        {
                            local adjustedPoint = npcOrigin + (dir * -1.5) - Vector(0, 0, 40);
                        
                            printl("Found wall at " + dir + "! Teleporting away.");
                            this.npcModel.SetOrigin(adjustedPoint);
                            this.npcBusyTime = 1.0;
                            return true;
                        }
                        
                    }
                }
                
                //printl("Stuck but couldn't find a wall to push off of."); //too spammy.
                return false;
            }
        }
        else 
        {
            this.npcStuckCounter = 0;
        }
        return false;
    }

    function OOBCheck()
    {
        if (this.npcModel.GetOrigin().z <= -16377) //-16377 is (almost) the limit of minimum Z axis.
        {
            printl("NPC IN OUT OF BOUNDS!!!!")
            this.npcModel.Kill()
            return true;
        }
        return false;
    }

    function GoToPathCustom(_vector)
    {
        local closestNav = NavMesh.GetNearestNavArea(_vector, 500, false, false);

        if(closestNav != null)
        {
            CreatePath(closestNav.GetCenter());
            this.npcTurnRate = 0.6;
        }
        else 
        {
            printl("FAILED: TARGET NAV AREA NOT FOUND");
        }
    }

    function SelectRandomNavFromDistance(minDistance, maxDistance)
    {
        local startPos = this.npcModel.GetOrigin();
        local startArea = NavMesh.GetNavArea(startPos, 200);

        local availableNavs = {};
        local bestNavAreas = [];

        if (startArea == null)
        {
            return null;
        }

        NavMesh.GetNavAreasInRadius(startArea.GetCenter(), maxDistance, availableNavs);

        foreach (navmesh in availableNavs)
        {
            local navCenter = navmesh.GetCenter();
            local dist = (navCenter - startPos).Length2D();
            
            if (dist >= minDistance && dist <= maxDistance && (navmesh.GetAttributes() & 536870912) == 0) //navs marked with LYINGDOWN is forbidden.
            {
                bestNavAreas.push(navmesh);
            }
        }
        
        if (bestNavAreas.len() > 0)
        {
            return bestNavAreas[RandomInt(0, bestNavAreas.len() - 1)];
        }

        return null;
    }

    function SelectRandomNavRadius(rad)
    {
        local startPos = this.npcModel.GetOrigin();
        local availableAreas = {}; // This is a Table

        NavMesh.GetNavAreasInRadius(startPos, rad, availableAreas);

        if (availableAreas.len() > 0)
        {
            local navList = [];
            foreach (navHandle in availableAreas)
            {
                if ((navHandle.GetAttributes() & (1 << 11 | 1 << 20)) == 0 && !IsOldLocation(navHandle))
                {
                    navList.push(navHandle);
                }
            }

            if (navList.len() > 0)
            {
                return navList[RandomInt(0, navList.len() - 1)];
            }
        }
        //printl("Didn't found a random nav!");
        return null;
    }

    function IsThreatNearby()
    {
        local origin = this.npcModel.GetOrigin();
        local nearbyThreats = [];
        
        local ent = null;
        while (ent = Entities.FindInSphere(ent, origin, 220.0)) 
        {
            if (ent.IsValid() && ent != this.npcModel) 
            {
                local cls = ent.GetClassname();
                if (cls == "infected" || cls == "player") 
                {
                    nearbyThreats.push(ent);
                }
            }
        }
        
        if (nearbyThreats == null)
        {
            return false;
        }

        foreach(threat in nearbyThreats)
        {
            if (threat.IsPlayer())
            {
                if (threat.GetZombieType() == 8 || threat.GetZombieType() != 9)
                {
                    return true;
                    break;
                }
                
                if (this.npcAffiliation == 2)
                {
                    if (threat.GetZombieType() == 9)
                    {
                        //printl("I don't like the look of him!")
                        return true;
                        break;
                    }
                }
            }
            if(threat.GetClassname() == "infected")
            {
                return true;
            }
        }
        return false;
    }

    function GetDistance(ent1, ent2)
    {
        local post1 = ent1.GetOrigin();
        local post2 = ent2.GetOrigin();
        return (post1 - post2).Length();
    }

    function LookForNearbyTargets()
    {
        local origin = this.npcModel.GetOrigin();
        local ent = null;
        
        local foundTank = null;
        local foundSpecial = null;
        local foundCommon = null;
        local foundSurvivor = null;
        local foundNPC = null;

        while (ent = Entities.FindInSphere(ent, origin, this.npcRange)) 
        {
            if (!ent.IsValid() || ent == this.npcModel) continue;

            local cls = ent.GetClassname();
            
            if (ent.IsPlayer() && !ent.IsDead()) 
            {
                local zType = ent.GetZombieType();
                if (zType == 8) foundTank = ent;
                else if (zType == 9) foundSurvivor = ent;
                else foundSpecial = ent; 
            }

            else if (cls == "infected") 
            {
                foundCommon = ent;
            }

            else if (cls == "prop_dynamic" && ent.GetName().find("NPCpedestrian") != null)
            {
                if (ent.GetScriptScope() && "Controller" in ent.GetScriptScope())
                    foundNPC = ent;
            }
        }

        if (foundTank)     return ["tank", foundTank, GetDistance(this.npcModel, foundTank)];
        if (foundSpecial)  return ["special", foundSpecial, GetDistance(this.npcModel, foundSpecial)];
        if (foundCommon)   return ["common", foundCommon, GetDistance(this.npcModel, foundCommon)];
        if (foundSurvivor) return ["survivor", foundSurvivor, GetDistance(this.npcModel, foundSurvivor)];
        if (foundNPC)      return ["npc", foundNPC, GetDistance(this.npcModel, foundNPC)];

        return null; 
    }

    function RunAwayFrom(type)
    {
        local multiplier = 1.0
        switch(type)
        {
            case "tank":
            {
                multiplier = 1.4
                break;
            }
            case "special":
            {
                multiplier = 1.2
                break;
            }
            case "common":
            {
                multiplier = 1.0
                break;
            }
        }
        if (this.npcAggression >= 0.5 * multiplier)
        {
            return false;
        }
        return true;
    }

    function WanderOrIdle()
    {
        local wanderOrIdle = RandomInt(0, 1)
        this.npcWanderingOrIdling = wanderOrIdle; //0 = Idle, 1 = Wander

        if (wanderOrIdle == 1)
        {
            CreatePathLegacy(SelectRandomNavRadius(1000).GetCenter());
            //ClientPrint(null, DirectorScript.HUD_PRINTTALK, "\x04[NPC] \x01" + "Wandering Now.");
            return;
        }
        //ClientPrint(null, DirectorScript.HUD_PRINTTALK, "\x04[NPC] \x01" + "Idling Now.");
    }

    function SmoothTurn()
    {
        local currentAngles = this.npcModel.GetAngles();
        local currentYaw = currentAngles.y;
        
        // Smoothly interpolate the angle
        // We use a simple approach: Move a percentage of the way to the target
        local nextYaw = Lerp(0.15, currentYaw, this.npcTargetAngle);
        
        this.npcModel.SetAngles(QAngle(0, nextYaw, 0));
    }

    function Lerp(t, a, b) {
        return a + (b - a) * t;
    }

    function SmoothLerp(current, target, t)
    {
        local delta = (target - current) % 360.0;
        // Calculate shortest path
        if (delta > 180.0) delta -= 360.0;
        if (delta < -180.0) delta += 360.0;
        
        return current + delta * t;
    }

    function TurnToTarget(target)
    {
        local myPos = this.npcModel.GetOrigin();
        local targetPos = target.GetOrigin();

        local delta = targetPos - myPos;
        // Calculate the destination angle
        this.npcTargetAngle = atan2(delta.y, delta.x) * (180 / PI);
    }

    /*
    function TurnToTargetAndMove(targetPos, speed)
    {
        local myPos = this.npcModel.GetOrigin();
        local currentAngles = this.npcModel.GetAngles();

        // --- HACK FIX ---
        local targetPosition = targetPos;
        // Check if the target is a NavArea object instead of a Vector
        if (typeof(targetPos) == "instance" && !("x" in targetPos)) 
        {
            targetPosition = targetPos.GetCenter();
        }

        
        local delta = targetPosition - myPos;
        local adjustedYaw = atan2(delta.y, delta.x) * (180 / PI);

        local leftBlocked = CheckSide("right", 90);   // Check 45 degrees left
        local rightBlocked = CheckSide("left", 90); // Check 45 degrees right

        // --- ADD REPULSION FORCE ---
        local forward = this.npcModel.GetForwardVector();
        local leftVec = Vector(-forward.y, forward.x, 0); // Manual Left Vector

        //I HATE NPCS STUCK IN WALL, I HATE NPCS STUCK IN WALL, I HATE NPCS STUCK IN WALL, I HATE NPCS STUCK IN WALL
        if (leftBlocked || rightBlocked)
        {
            local forward = this.npcModel.GetForwardVector();
            local rightVec = Vector(forward.y, -forward.x, 0);

            local shoveDir = leftBlocked ? (rightVec * 4.0) : (rightVec * -4.0);
            
            this.npcModel.SetOrigin(myPos + shoveDir);
        }

        local newYaw = this.SmoothLerp(currentAngles.y, adjustedYaw, 0.5); //less value = more smooth turns
        local newAngles = QAngle(0, newYaw, 0);
        this.npcModel.SetAngles(newAngles);

        if (this.npcBusyTime <= 0)
        {
            this.npcModel.SetOrigin(myPos + (newAngles.Forward() * speed));
        }
    }
    */

    function TurnToTargetAndMove(targetPos, speed)
    {
        local myPos = this.npcModel.GetOrigin();
        local currentAngles = this.npcModel.GetAngles();

        local targetPosition = targetPos;
        if (typeof(targetPos) == "instance" && !("x" in targetPos)) targetPosition = targetPos.GetCenter();
        
        local delta = targetPosition - myPos;
        local adjustedYaw = atan2(delta.y, delta.x) * (180 / PI);
        
        local shove = Vector(0, 0, 0);
        /*
        local leftBlocked = CheckSide("right", 90);   // Check 45 degrees left
        local rightBlocked = CheckSide("left", 90); // Check 45 degrees right

        if (leftBlocked || rightBlocked)
        {
            local forward = this.npcModel.GetForwardVector();
            local rightVec = Vector(forward.y, -forward.x, 0);

            local shoveDir = leftBlocked ? (rightVec * 4.0) : (rightVec * -4.0);

            shove = shoveDir;
        }
        */

        local newYaw = this.SmoothLerp(currentAngles.y, adjustedYaw, this.npcTurnRate); //formerly 0.5, made it 0.7 so they can turn sharper. 

        this.npcModel.SetAngles(QAngle(0, newYaw, 0));

        // 2. NOW check if it's safe to move forward at this new angle
        if (this.npcBusyTime <= 0)
        {
            local safePos = this.GetGroundAndFront(speed, 30); // Look ahead 30 units
            
            if (safePos != null)
            {
                this.npcModel.SetOrigin(safePos);
            }
            else 
            {
                this.BumpIntoWall();
            }
        }
    }

    function GetOrderedPath(pathTable)
    {
        local orderedArray = [];
        
        for(local i = 0; i < pathTable.len(); i++)
        {
            local key = "area" + i;
            if (key in pathTable)
            {
                orderedArray.push(pathTable[key]);
            }
        }
        return orderedArray;
    }

    function OrganizePathArray()
    {
        local sortedArray = [];
        local count = rawTable.len();

        for (local i = 0; i < count; i++)
        {
            local key = "area" + i;
            if (key in rawTable)
            {
                sortedArray.push(rawTable[key]);
            }
        }
        
        return sortedArray;
    }

    function GoToNavPath(walkOrRun, speed)
    {
        //local thePath = GetOrderedPath(this.npcNavPathC);
        local thePath = this.npcNavPathC
        this.npcSpeed = speed;

        if (thePath.len() == 0) 
        {
            this.ClearPath();
            this.npcIsCurrentlyGoing = false;
            return false;
        }

        local requiredAnim = "walk";
        if (walkOrRun == 0 || this.npcRunType == 0) requiredAnim = "walk";
        else if (walkOrRun == 1 || this.npcRunType == 1) requiredAnim = "run";
        else if (walkOrRun == 2 || this.npcRunType == 2) requiredAnim = "runfear";
        else if (walkOrRun == 3 || this.npcRunType == 3) requiredAnim = "rush";

        if (this.npcCurrentAnimation != requiredAnim)
        {
            this.SetAnimationWithDefault(requiredAnim);
            this.npcCurrentAnimation = requiredAnim; 
        }

        local nextWayPoint = thePath[0];
        
        local targetPos = nextWayPoint;
        if (typeof(nextWayPoint) == "instance" && !("x" in nextWayPoint)) 
        {
            targetPos = nextWayPoint.GetCenter();
        }

        TurnToTargetAndMove(targetPos, speed);
        //printl("Moving towards: " + nextWayPoint.tostring() + " | Distance: " + (this.npcModel.GetOrigin() - targetPos).Length());

        if ((this.npcModel.GetOrigin() - targetPos).Length() < 50) //formely using Length2D, because NPCs might stop in multi floor.
        {
            this.npcNavPathC.remove(0);
            //local keyToRemove = "area" + (this.npcNavPathC.len() - thePath.len());
            //delete this.npcNavPathC[keyToRemove];
            
            if (this.npcNavPathC.len() == 0) 
            {
                this.npcSpeed = 0;
                this.npcIsCurrentlyGoing = false;
                this.npcCurrentAnimation = "idle01";
                this.DefaultAnimation();
                return false; 
            }
        }
        return true;
    }

    function GoToTarget(walkOrRun, speed, target, targetVector = Vector(0, 0, 0)) //designed for PedArmed class specifically.
    {
        this.npcSpeed = speed;

        //ClearPath()

        local requiredAnim = "walk";
        switch(walkOrRun)
        {
            case 0: requiredAnim = "walk"; break;
            case 1: requiredAnim = "run"; break;
            case 2: requiredAnim = "runfear"; break;
            case 3: requiredAnim = "rush"; break;
            default:
            {
                if (this.npcRunType == 1) requiredAnim = "run";
                else if (this.npcRunType == 2) requiredAnim = "runfear";
                else requiredAnim = "walk";
                break;
            }       
        }

        if (this.npcCurrentAnimation != requiredAnim)
        {
            SetAnimationWithDefault(requiredAnim)
            //printl("Setting animation to: " + requiredAnim)
            this.npcCurrentAnimation = requiredAnim; 
        }

        local targetOrigin = null;

        if (target != null)
        {
            targetOrigin = target.GetOrigin();
        }
        else
        {
            targetOrigin = targetVector;
        }

        if (this.npcNavPathC.len() == 0) 
        {
            this.npcNavPathC.append(targetOrigin);
        } 
        else 
        {
            this.npcNavPathC[0] = targetOrigin;
        }

        TurnToTargetAndMove(this.npcNavPathC[0], speed);
        //printl("Moving towards: " + nextWayPoint.tostring() + " | Distance: " + (this.npcModel.GetOrigin() - targetPos).Length());

        if ((this.npcModel.GetOrigin() - this.npcNavPathC[0]).Length() < 60) 
        {
            this.npcNavPathC.remove(0);
            
            if (this.npcNavPathC.len() == 0) 
            {
                this.npcSpeed = 0;
                this.npcIsCurrentlyGoing = false;

                if (!this.npcMeleeLockedIn) {
                    this.npcCurrentAnimation = "idle01";
                    this.DefaultAnimation();
                }
                return false; 
            }
        }
    }

    function IsMyWayToPathBlocked(targetVector)
    {
        local type = typeof targetVector
        local ignoreEntity = null
        local endVector = targetVector;
        if(type != "Vector")
        {
            ignoreEntity = targetVector;
            endVector = targetVector.GetOrigin()
        }
        local t = {start = this.npcModel.GetOrigin() + Vector(0, 0, 32), end = endVector + Vector(0, 0, 16), mask = DirectorScript.TRACE_MASK_PLAYER_SOLID, ignore = ignoreEntity}
        if(TraceLine(t))
        {
            if(t.hit)
            {
                return true;
            }
        }
        return false;
    }

    function RunAway(runAnimation = 2, minDistance = 1000, maxDistance = 2000)
    {
        if (this.npcRunAwayTime <= 0) 
        {
            local nav = SelectRandomNavFromDistance(minDistance, maxDistance);
            if (nav)
            {
                ClearPath(); 
                CreatePathLegacy(nav.GetCenter()); 
                
                // Set the state flags - the Think function will handle the rest
                this.npcCurrentlyRunning = true; 
                this.npcRunType = runAnimation; // Store the animation type (0, 1, or 2)
                
                this.Scream(); 
                this.npcRunAwayTime = 4.0; 
                //printl("RunAway: Path Created!");
                return true;
            }
        }
        this.npcRunAwayTime -= this.npcThinkTime;
        return false;
    }

    function Assist(target)
    {
        ClearPath();
        this.npcBusy = false;
        SayQuote(13);
        CreatePathLegacy(target.GetOrigin() + Vector(RandomInt(-50, 50), RandomInt(-50, 50), 0));
        this.npcCurrentlyRunning = true;
        //this.npcIsRetreating = true;
        this.npcRunType = 1; //non-fear run animation.
        //ClientPrint(null, DirectorScript.HUD_PRINTTALK, "[NPC] Assisting!");
    }

    function TryAssistSurvivor()
    {
        if (this.npcNextSurvivorAssistTime > 0)
        {
            this.npcNextSurvivorAssistTime -= this.npcThinkTime;
            return;
        }
        local anySurvivorInCombat = Director.IsAnySurvivorInCombat();
        if (anySurvivorInCombat)
        {
            local closestSurvivor = Entities.FindByClassnameNearest("player", this.npcModel.GetOrigin(), 1000);
            if (closestSurvivor != null && closestSurvivor.GetZombieType() == 9 && !closestSurvivor.IsDead() && closestSurvivor.IsInCombat())
            {
                Assist(closestSurvivor);
            }
        }
        this.npcNextSurvivorAssistTime = RandomFloat(10.0, 20.0);
    }

    function CallBackup(rad = 1000)
    {
        if (this.npcNextBackupCall > 0)
        {
            this.npcNextBackupCall -= this.npcThinkTime;
            return false;
        }

        local myOrigin = this.npcModel.GetOrigin();
        local buddies = [];
        local ent = null;
        while (ent = Entities.FindInSphere(ent, myOrigin, rad)) 
        {
            if (ent.IsValid() && ent != this.npcModel) 
            {
                local cls = ent.GetClassname();
                if (cls == "prop_dynamic" && ent.GetName().find("NPCpedestrian") != null)
                {
                    if (ent.GetScriptScope() && "Controller" in ent.GetScriptScope())
                    {
                        local buddyController = ent.GetScriptScope().Controller;
                        if (!buddyController.npcIsCurrentlyGoing && !buddyController.npcCurrentlyRunning)
                        {
                            buddies.push(buddyController);
                        }
                    }
                }
            }
        }
        foreach(buddy in buddies)
        {
            buddy.Assist(this.npcModel); //get your asses over here!
        }
        //ClientPrint(null, DirectorScript.HUD_PRINTTALK, "[NPC] Calling Backup!");
        this.npcNextBackupCall = RandomFloat(10.0, 15.0);
        return true;
    }

    function Retreat(runAnimation = 1, minDistance = 500, maxDistance = 1200)
    {
        if (this.npcRunAwayTime <= 0)
        {
            local nav = SelectRandomNavFromDistance(minDistance, maxDistance);
            if (nav)
            {
                ClearPath();
                CreatePathLegacy(nav.GetCenter());

                this.npcCurrentlyRunning = true;
                this.npcIsRetreating = true;
                this.npcRunType = runAnimation;

                this.npcRunAwayTime = 3.0;
                printl("RETREATING!")
                DoEntFire(this.npcModel.GetName(), "RunScriptCode", "Controller.npcIsRetreating = false", 3.5, null, null);
                return true;
            }
        }
        this.npcRunAwayTime -= this.npcThinkTime;
        return false;
    }

    function StartConversationWithNPC(targetEntHandle = null) 
    {
        //TO DO: Get closest NPC and clear their path and make them talk.
        printl("Starting conversation with NPC")
        // don't start if busy or moving
        if (this.npcBusy || this.npcNavPathC.len() > 0) return false;

        local origin = this.npcModel.GetOrigin();
        local targetNPC = null;

        // Otherwise, search nearby for a pedestrian.
        if (targetEntHandle != null && targetEntHandle.IsValid())
        {
            local scope = targetEntHandle.GetScriptScope();
            if (scope && "Controller" in scope) 
            {
                local other = scope.Controller;
                if (!other.npcBusy && !other.npcCurrentlyTalking && other.npcNavPathC.len() == 0)
                {
                    targetNPC = other;
                }
            }
        }
        else 
        {
            // Fallback search if no target was passed
            local ent = null;
            while (ent = Entities.FindByName(ent, "NPCpedestrian*"))
            {
                if (ent != this.npcModel && (ent.GetOrigin() - origin).Length2D() < 300)
                {
                    local scope = ent.GetScriptScope();
                    local other = scope.Controller;
                    if (!other.npcBusy && !other.npcCurrentlyTalking && other.npcNavPathC.len() == 0)
                    {
                        targetNPC = other;
                        break;
                    }
                }
            }
        }

        if (targetNPC == null) return false;

        // 3. Meeting point logic

        if(GetDistance(this.npcModel, targetNPC.npcModel) < 150)
        {

            StartConversation();
            //targetNPC.npcCurrentlyTalking = true;
            this.npcConversationMode = true;
            targetNPC.npcConversationMode = true;
            targetNPC.npcLastTalkedNPC = this.npcModel;
            this.npcLastTalkedNPC = targetNPC.npcModel;
            return true;
        }

        /*
        local meetingPoint = (origin + targetNPC.npcModel.GetOrigin()) * 0.5;
        local navArea = NavMesh.GetNavArea(meetingPoint, 100);
        
        if (navArea)
        {
            local pos = navArea.GetCenter();
            
            // Setup movement
            this.CreatePathLegacy(pos);
            targetNPC.CreatePathLegacy(pos);
            
            // Tag both
            this.npcLastTalkedNPC = targetNPC.npcModel;
            targetNPC.npcLastTalkedNPC = this.npcModel;
            
            // VERY IMPORTANT: Set flags so they don't pick new targets while walking to the meeting
            this.npcCurrentlyTalking = true; 
            targetNPC.npcCurrentlyTalking = true;
            this.npcConversationMode = true;

            return true;
        }

        */

        return false;
    }
        
    function CancelConversation()
    {
        local buddyScope = this.npcLastTalkedNPC.GetScriptScope()
        if (!("Controller" in buddyScope)) return;
        buddyScope.Controller.npcLastTalkedNPC = null;
        this.npcLastTalkedNPC = null;
    }

    function IsMyBuddyAvailable()
    {
        if (this.npcLastTalkedNPC == null || !this.npcLastTalkedNPC.IsValid())
        {
            return false;
        }

        local buddyScope = this.npcLastTalkedNPC.GetScriptScope();
        
        if (!("Controller" in buddyScope)) return false;
        
        local buddy = buddyScope.Controller;

        local buddyIsFighting = false;
        
        if ("InCombat" in buddy) 
        {
            buddyIsFighting = buddy.InCombat();
        }

        if (buddy.npcIsCurrentlyGoing || buddy.npcCurrentlyRunning || buddyIsFighting || buddy.npcCurrentlyTalking)
        {
            // Buddy is too busy to talk!
            return false;
        }

        return true;
    }

    function StartConversation()
    {
        if (!IsMyBuddyAvailable()) return;

        local myVoice = this.npcVoiceSet;
        local buddyScope = this.npcLastTalkedNPC.GetScriptScope();
        
        if (!("Controller" in buddyScope)) return;
        local buddy = buddyScope.Controller;

        local categories = [::DIALOGUE_TYPE.GREET, ::DIALOGUE_TYPE.QUESTION, ::DIALOGUE_TYPE.RANDOM];
        local myCategory = categories[RandomInt(0, categories.len() - 1)];

        local myIDs = myVoice.dialogueMap[myCategory];
        local myID = myIDs[RandomInt(0, myIDs.len() - 1)];

        this.SayQuote(6, myID);
        this.TurnToTarget(this.npcLastTalkedNPC);

        local responseTime = 3.0; 
        EntFire(this.npcLastTalkedNPC.GetName(), "RunScriptCode", "Controller.ConversationResponse(" + myCategory + ")", responseTime);
    }

    function ConversationResponse(heardCategoryID)
    {
        local myVoice = this.npcVoiceSet;

        if (!(heardCategoryID in myVoice.responseTable)) return;
        
        local possibleResponseCategories = myVoice.responseTable[heardCategoryID];
        local myResponseCategoryID = possibleResponseCategories[RandomInt(0, possibleResponseCategories.len() - 1)];

        local myIDs = myVoice.dialogueMap[myResponseCategoryID];
        local myID = myIDs[RandomInt(0, myIDs.len() - 1)];

        this.SayQuote(7, myID);
        this.TurnToTarget(this.npcLastTalkedNPC);

        // should we keep talking or say goodbye?
        local CONVERSATION_END_CHANCE = 60; // 60% chance to end the chat
        local responseDelay = 3.5;

        if (RandomInt(1, 100) <= CONVERSATION_END_CHANCE)
        {
            EntFire(this.npcModel.GetName(), "RunScriptCode", "Controller.ConversationEnd(0)", responseDelay);
        }
        else 
        {
            EntFire(this.npcModel.GetName(), "RunScriptCode", "Controller.ConversationEnd(0)", responseDelay);
        }
    }

    function ConversationEnd(isLastBye)
    {
        local buddyScope = this.npcLastTalkedNPC.GetScriptScope();
        if (!("Controller" in buddyScope)) return;
        local buddy = buddyScope.Controller;

        this.SayQuote(8); 

        this.npcCurrentlyTalking = false;

        if (isLastBye == 0) 
        {
            local delay = 2.0;
            EntFire(this.npcLastTalkedNPC.GetName(), "RunScriptCode", "Controller.ConversationEnd(1)", delay);
            this.TurnToTarget(this.npcLastTalkedNPC);
        }
    }

    function RandomQuote()
    {
        if (this.npcCurrentlyTalking)
        {
            return;
        }
        SayQuote(0);
        this.npcCurrentlyTalking = true;
        this.npcNextRandomQuote = RandomFloat(6.4, 16.8);
        //printl("Saying random one liners")
    }

    function VictoryDance()
    {
        this.npcIsCurrentlyGoing = false;
        ResetTalking();
        SetAnimation("victory", 3.0);
        SayQuote(15);
        this.npcBusyTime = 3.0;
        this.npcBusy = true;
    }

    function ReactNegativly()
    {
        this.npcIsCurrentlyGoing = false;
        SetAnimation("negative0" + RandomInt(1, 2), 5.0)
        SayQuote(14)
        this.npcBusyTime = 5.0;
        this.npcBusy = true;
    }

    function StareAt(target, duration)
    {
        //ClearPath();
        this.npcIsCurrentlyGoing = false;
        SetAnimation("idle0" + RandomInt(1, 3), duration)
        this.TurnToTarget(target);
        this.npcBusyTime = duration;
        this.npcBusy = true;
        //printl("Staring at...")
        //ClientPrint(null, DirectorScript.HUD_PRINTTALK, "\x04[NPC] \x01" + "Staring at: " + target.GetClassname() + " for " + duration.tostring());
    }

    function TauntAt(target)
    {
        //ClearPath();
        this.npcIsCurrentlyGoing = false;
        SetAnimation("taunt0" + RandomInt(1, 4), 5)
        ResetTalking(5.0)
        this.TurnToTarget(target);
        this.SayQuote(3); // Taunt
        this.npcBusyTime = 3.0
        this.npcCurrentlyTalking = true;
        this.npcBusy = true;
        //printl("taunting at")
        //ClientPrint(null, DirectorScript.HUD_PRINTTALK, "\x04[NPC] \x01" + "Taunting at: " + target.GetClassname());
    }

    function LaughAt(target)
    {
        //ClearPath();
        this.npcIsCurrentlyGoing = false;
        SetAnimation("laugh0" + RandomInt(1, 2), 4)
        ResetTalking(4.0)
        this.TurnToTarget(target);
        this.SayQuote(1); // Taunt
        this.npcBusyTime = 4.0
        this.npcBusy = true;
        //printl("laughing at")
    }

    function TalkTo(target)
    {
        //ClearPath();
        this.npcIsCurrentlyGoing = false;
        SayQuote(6);
        ResetTalking(3.0)
        SetAnimation("talk0" + RandomInt(1, 3), 2.0); //temporarly, for testing. Normal Sequence: "talk01"
        this.TurnToTarget(target);
        //printl("Talking to...")
        //(null, DirectorScript.HUD_PRINTTALK, "\x04[NPC] \x01" + "Talking to: " + target.GetClassname());
    }

    function GetStunned()
    {
        this.npcIsCurrentlyGoing = false;
        this.npcBusyTime = 3.0
        this.npcBusy = true;
        SayQuote(4);
        ResetTalking(1.0)
        SetAnimation("stun01", 3.0); //only has one sequence
    }

    function DoShove()
    {
        if(this.npcShoveTime > 0)
        {
            this.npcShoveTime -= this.npcThinkTime;
            return;
        }

        local entities = [];
        local zombies = null;
        local players = null;
        while(zombies = Entities.FindByClassname(zombies, "infected"))
        {
            if(zombies.IsValid())
            {
                entities.push(zombies);
            }
        }
        while(players = Entities.FindByClassname(players, "player"))
        {
            if(players.IsValid() && players.GetHealth() > 0)
            {
                entities.push(players);
            }
        }

        if(entities.len() == 0) {return;}

        this.npcShoveTime = RandomInt(3, 4);

        //now shove them
        foreach(entity in entities)
        {
            if (entity.GetClassname() == "player")
            {
                entity.Stagger(this.npcModel.GetOrigin() - entity.GetOrigin())
            }
            else
            {
                entity.TakeDamage(10, 33554432, this.npcHitbox) //DMG_STUMBLE
            }
        }
        SetAnimation("shove", 1.8);
        EmitSoundOn("Weapon.HitInfected", this.npcHitbox);
    }

    function CombatInsult()
    {
        if (this.npcCurrentlyTalking) return;
        SayQuote(2);
        ResetTalking(4.0)
    }

    function DoSpot(target)
    {
        this.npcIsCurrentlyGoing = false;
        SayQuote(16);
        //ResetTalking(3.0)
        SetAnimation("spot0" + RandomInt(1, 2), 2.0);
        this.TurnToTarget(target);
    }

    function ResetBusy()
    {
        this.npcBusyTime = 0;
        this.npcBusy = false;
    }

    function ResetTalking(additionalTime = 0.0)
    {
        this.npcCurrentlyTalking = false;
        StopAmbientSoundOn(this.npcCurrentVoiceline, this.npcModel);
        this.npcNextRandomQuote = RandomFloat(6.4 + additionalTime, 16.8 + additionalTime);
    }

    function MiscAction(actionType)
    {
        if (this.npcVoiceSet.totalMiscActionSounds == 0)
        {
            //dont even bother if there are no misc action sounds.
            return;
        }
        switch(actionType)
        {
            case 1:
            {
                local phone = SpawnEntityFromTable("prop_dynamic", {
                   targetname = this.npcName + "_actionitem",
                   origin = this.npcModel.GetOrigin()
                   fademindist = 1500,
                   fademaxdist = 2000,
                   model = "models/blop4dead/npc_phone.mdl"
                });
                SetAnimation("miscaction01", 10);
                DoEntFire(phone.GetName(), "SetParent", this.npcName, 0.00, null, null);
                DoEntFire(phone.GetName(), "SetParentAttachment", "item_bone", 0.02, null, null);
                local soundID = [2, 7, 8];
                SayQuote(11, soundID[RandomInt(0, 2)]);
                this.npcBusyTime = 10;
                this.npcBusy = true;
                DoEntFire(phone.GetName(), "Kill", "", 6.5, null, null);
                break;
            }
            case 2:
            {
                local drink = SpawnEntityFromTable("prop_dynamic", {
                   targetname = this.npcName + "_actionitem",
                   origin = this.npcModel.GetOrigin()
                   fademindist = 1500,
                   fademaxdist = 2000,
                   model = "models/blop4dead/npc_drink.mdl"
                });
                SetAnimation("miscaction02", 4.5);
                DoEntFire(drink.GetName(), "SetParent", this.npcName, 0.00, null, null);
                DoEntFire(drink.GetName(), "SetParentAttachment", "item_bone", 0.02, null, null);
                DoEntFire(this.npcName, "RunScriptCode", "Controller.SayQuote(11, 3)", 5.5, null, null);
                this.npcBusyTime = 4.5;
                this.npcBusy = true;
                DoEntFire(drink.GetName(), "Kill", "", 5.5, null, null);
                break;
            }
            case 3:
            {
                local cigar = SpawnEntityFromTable("prop_dynamic", {
                   targetname = this.npcName + "_actionitem",
                   origin = this.npcModel.GetOrigin()
                   fademindist = 1500,
                   fademaxdist = 2000,
                   model = "models/blop4dead/npc_cigar.mdl"
                });
                SetAnimation("miscaction03", 4.5);
                DoEntFire(cigar.GetName(), "SetParent", this.npcName, 0.00, null, null);
                DoEntFire(cigar.GetName(), "SetParentAttachment", "item_bone", 0.02, null, null);
                SayQuote(11, 1);
                this.npcBusyTime = 5;
                this.npcBusy = true;
                DoEntFire(cigar.GetName(), "Kill", "", 5, null, null);
                break;
            }
            case 4:
            {
                SetAnimation("miscaction04", 5);
                SayQuote(11, 6);
                this.npcBusyTime = 5;
                this.npcBusy = true;
                break;
            }
        }
    }

    function ResetAnimationBusy()
    {
        this.npcCurrentlyAnimated = false;
    }

    function DefaultAnimation()
    {
        DoEntFire(this.npcModel.GetName(), "SetAnimation", "idle0" + RandomInt(1, 3).tostring(), 0, null, null);
        DoEntFire(this.npcModel.GetName(), "SetDefaultAnimation", "idle0" + RandomInt(1, 3).tostring(), 0, null, null);
        //DoEntFire(this.npcModel, "SetAnimation", "idle", 0, null, null);
        //DoEntFire(this.npcModel, "SetDefaultAnimation", "idle", 0, null, null);
    }

    function SetAnimation(animationName, animationDuration)
    {
        DoEntFire(this.npcModel.GetName(), "SetAnimation", animationName, 0, null, null);
        //DoEntFire(this.npcModel.GetName(), "SetDefaultAnimation", animationName, 0, null, null);
        //DoEntFire(this.npcModel, "SetAnimation", animationName, 0, null, null);
        this.npcCurrentlyAnimated = true;
        this.npcCurrentAnimation = animationName;
        if (animationDuration != -1)
        {
            //DoEntFire(this.npcModel, "RunScriptCode", "DefaultAnimation()", animationDuration, null, null);
            DoEntFire(this.npcModel.GetName(), "SetAnimation", "idle0" + RandomInt(1, 3).tostring(), animationDuration, null, null);
            DoEntFire(this.npcModel.GetName(), "SetDefaultAnimation", "idle0" + RandomInt(1, 3).tostring(), animationDuration, null, null);
            DoEntFire(this.npcModel.GetName(), "RunScriptCode", "Controller.ResetAnimationBusy()", animationDuration, null, null);
            DoEntFire(this.npcModel.GetName(), "RunScriptCode", "Controller.npcCurrentAnimation = null", animationDuration, null, null);
        }
    }

    function SetAnimationWithDefault(animationName)
    {
        DoEntFire(this.npcModel.GetName(), "SetAnimation", animationName, 0, null, null);
        DoEntFire(this.npcModel.GetName(), "SetDefaultAnimation", animationName, 0, null, null);
    }

    function Scream()
    {
        SayQuote(5);
    }

    function Die()
    {
        ::globalNPCCount--;
        ::NONARMEDNPC_COUNT--;
    
        local deathanim = "death0" + RandomInt(1, 3).tostring();
        
        this.npcBusy = true;
        this.npcIsCurrentlyGoing = false;
        this.npcCurrentlyRunning = false;
        this.npcCurrentlyTalking = true;
        AddThinkToEnt(this.npcModel, null); 

        DoEntFire("!self", "SetDefaultAnimation", deathanim, 0.0, null, this.npcModel);
        DoEntFire("!self", "SetAnimation", deathanim, 0.01, null, this.npcModel);

        SayQuote(10); 
        
        //this.npcName = "dead_body_" + EntityGroup[0].GetEntityIndex();
        DoEntFire("!self", "Kill", "", 5.0, null, this.npcModel);
    }

    function Hurt()
    {
        SetAnimation("hurt0" + RandomInt(1, 2).tostring(), 1.0);
        SayQuote(4);
        this.npcBusy = true;
        this.npcBusyTime = 0.5;
    }

    function NPCSleep()
    {
        // Don't sleep if we are currently playing a death or hurt animation
        if (this.npcBusy) return 0;
        if (!this.npcHitbox.IsValid())
        {
            Die()
            AddThinkToEnt(this.npcModel, null);
            return 3;
        }
        else 
        {
            if (this.npcHitbox.GetHealth() <= 0)
            {
                Die()
                AddThinkToEnt(this.npcModel, null);
                return 3;
            }
        }

        if (this.npcNextSleepCheck < Time()) 
        {
            local nearestPlayer = Entities.FindByClassnameNearest("player", this.npcModel.GetOrigin(), this.npcSleepRadius); //formerly 1800
            
            if (!nearestPlayer) 
            {
                // Optional: Snap to idle so they don't freeze in a walking pose
                this.DefaultAnimation(); 
                
                this.npcNextSleepCheck = Time() + 2.0; 
                //printl("[NPC] Zzzz... Sleeping...")
                return 2.0; // Tell the engine to wait 2 seconds
            }
            
            this.npcNextSleepCheck = Time() + 0.5; 
        }
        return 0; // Don't sleep, continue with AI logic
    }

    function NPCThink()
    {
        // 1. DIES/SLEEP/TURNING (Highest Priority)
        local sleepTime = this.NPCSleep();
        if (sleepTime > 0) return sleepTime;

        //printl("--- TICK --- Path Len: " + this.npcNavPathC.len() + " Busy: " + this.npcBusy + " Currently Going: " + this.npcIsCurrentlyGoing);
        
        SmoothTurn();
        if (!this.npcHitbox.IsValid()) { Die(); AddThinkToEnt(this.npcModel, null); return 1; }
        
        local nearbyTarget = LookForNearbyTargets()
        
        GetGroundAndFront(this.npcSpeed);
        this.npcLastPos = this.npcModel.GetOrigin();

        if(this.npcIsRetreating && this.npcNavPathC.len() > 0)
        {
            //NPCPathFollower()
            if (this.npcCurrentlyRunning && nearbyTarget == null) 
            {
                this.npcCurrentlyRunning = false;
            }
            local speed = this.npcCurrentlyRunning ? 10 : 4;
            local moveType = this.npcCurrentlyRunning ? 2 : 0;

            local isMoving = GoToNavPath(moveType, speed);
            
            if (!isMoving) 
            {
                this.npcIsCurrentlyGoing = false;
                this.npcCurrentlyRunning = false;
            } 
            else 
            {
                this.npcIsCurrentlyGoing = true;
            }
            return this.npcThinkTime;      
        }

        if (nearbyTarget != null)
        {
            if (nearbyTarget[0] == "tank" || nearbyTarget[0] == "special" || nearbyTarget[0] == "common")
            {
                if (RunAwayFrom(nearbyTarget[0]))
                {
                    RunAway(2) //fear run animation
                    CallBackup() //only non-armed NPCs can call backup, armed ones will just scream for help and run like crazy.
                    //printl("threat found");
                    //return this.npcThinkTime + 1.0; //<-- stop using this shit.
                }
                else 
                {
                    if(this.npcNextCombatInsult <= 0)
                    {
                        CombatInsult()
                        if((nearbyTarget[1].GetOrigin() - this.npcModel.GetOrigin()).Length2D() < 30) {DoShove()};
                        this.npcNextCombatInsult = RandomInt(1, 4);
                    }
                    if(nearbyTarget[2] <= 80) //if target (threat) near to 80 units to us
                    {
                        Retreat()
                        if(nearbyTarget[0] == "tank" || nearbyTarget[0] == "special") //CALL THE FUCKING BACKUP NOW!
                        {
                            CallBackup()
                        }
                    }
                    if (nearbyTarget[0] == "tank" && nearbyTarget[1].GetHealth() <= 1 && !this.npcBusy) //tank is dead victory dance now
                    {
                        VictoryDance();
                    }
                    this.npcNextCombatInsult -= this.npcThinkTime;
                }
            }
        }
        

        if (this.npcBusyTime <= 0)
        {
            this.npcBusy = false;
        }
        else 
        {
            this.npcBusyTime -= this.npcThinkTime;
            return this.npcThinkTime; 
        }

        StuckCheck();

        if (this.npcNavPathC.len() > 0) 
        {
            //NPCPathFollower()
            local speed = this.npcCurrentlyRunning ? 10 : 4;
            local moveType = this.npcCurrentlyRunning ? 2 : 0;
            local isMoving = GoToNavPath(moveType, speed);
            
            if (!isMoving) 
            {
                this.npcIsCurrentlyGoing = false;
                this.npcCurrentlyRunning = false;
                
                if (this.npcConversationMode && this.npcLastTalkedNPC != null)
                {
                    StartConversation();
                    this.npcLastTalkedNPC = null;
                }
                else 
                {
                    DefaultAnimation();
                }
            } 
            else 
            {
                this.npcIsCurrentlyGoing = true;
            }
            return this.npcThinkTime;
        }

        if (nearbyTarget != null)
        {
            if (nearbyTarget[0] == "survivor" || nearbyTarget[0] == "npc")
            {
                switch(RandomInt(1, 9))
                {
                    case 1: //talk to npc
                    {
                        if (nearbyTarget[0] == "npc")
                        {
                            StartConversationWithNPC(nearbyTarget[1]);
                        }
                        break;
                    }
                    case 2: //do misc action
                    {
                        switch(RandomInt(1, 4))
                        {
                            case 1:{MiscAction(1); break;}
                            case 2:{MiscAction(2); break;}
                            case 3:{MiscAction(3); break;}
                            case 4:{MiscAction(4); break;}
                        }
                        break;
                    }
                    case 3: //stare at
                    {
                        StareAt(nearbyTarget[1], RandomFloat(2.0, 4.0));
                        break;
                    }
                    case 4: //taunt at
                    {
                        TauntAt(nearbyTarget[1]);
                        break;
                    }
                    case 5: case 6: //talk at
                    {
                        TalkTo(nearbyTarget[1]);
                        break;
                    }
                    case 7: case 8: case 9: //just wander
                    {
                        CreatePathLegacy(SelectRandomNavRadius(1000).GetCenter());
                        break;
                    }
                }
            }
        }

        else 
        {
            local randomTarget = SelectRandomNavRadius(1000);
            if (randomTarget) CreatePathLegacy(randomTarget.GetCenter());
        }

        //say random quote
        this.npcNextRandomQuote -= this.npcThinkTime;
        
        if (this.npcNextRandomQuote <= 0 && !this.npcCurrentlyTalking)
        {
            RandomQuote();
        }

        return this.npcThinkTime;
    }
}


class ::PedArmed extends Pedestrian //uses weaponfire based weapons like pistol, shotgun etc.
{
    npcClassNumber = 2;
    npcWeapon = null; //WEAPON TYPES: 0 = Nothing, 1 = Pistol, 2 = Shotgun, 3 = Rifle, 4 = Sniper Rifle, 5 = Grenade Launcher, 6 = Molotov, 7 = Mini-nuke launcher.
    npcWeaponModel = null;
    npcWeaponName = null;
    npcWeaponFireEntity = null; //if npc has pistol, shotgun, riffle or sniper riffle we gonna use this and assign env_weaponfire to it.
    npcIsAiming = false;
    npcMyCurrentEnemy = null;
    npcCombatTime = 4.0;
    
    constructor(npcorigin, thehealth, themodel, gender, voiceSet, type, affiliation, aggression, canTaunt, bodyGroup, bodySkin, range, weapon)
    {
        ::FIREARMNPC_COUNT++
        base.constructor(npcorigin, thehealth, themodel, gender, voiceSet, type, affiliation, aggression, canTaunt, bodyGroup, bodySkin, range);
        this.npcWeapon = weapon;
        this.npcWeaponName = CreateNPCName(1);
        
        local wpModel = null;
        local wpSkin = 0;
        local wfType = 0;
        local wfDamageMod = 1.0;

        switch(weapon)
        {
            case 1: //Pistol
            {
                wfType = 2; wfDamageMod = 0.1; wpModel = "models/blop4dead/npc_pistol.mdl"; break;
            }
            case 2: //Shotgun
            {
                wfType = 3; wfDamageMod = 0.04; wpModel = "models/blop4dead/npc_shotgun.mdl"; break; //shotguns are op
            }
            case 3: //Riffle
            {
                wfType = 1; wfDamageMod = 0.1; wpModel = "models/blop4dead/npc_rifle.mdl"; break;
            }
            case 4: //Sniper Riffle
            {
                wfType = 2; wfDamageMod = 0.2; wpModel = "models/blop4dead/npc_sniperrifle.mdl"; break;
            }
            case 5: //Grenade Launcher !!DONT CALL THIS IN PedArmed CLASS!!
            {
                wfType = 2; wfDamageMod = 1.0; wpModel = "models/blop4dead/npc_grenadelauncher.mdl"; break;
            }
            case 6: //Molotov !!DONT CALL THIS IN PedArmed CLASS!!
            {
                wfType = 2; wfDamageMod = 1.0; wpModel = "models/blop4dead/npc_molotov.mdl"; break;
            }
            case 7: //Rocket Launcher !!DONT CALL THIS IN PedArmed CLASS!!
            {
                wfType = 2; wfDamageMod = 1.0; wpModel = "models/blop4dead/npc_rocketlauncher.mdl"; break;
            }
            case 8: //MINI NUKE LAUNCHER !!DONT CALL THIS IN PedArmed CLASS!!
            {
                wfType = 2; wfDamageMod = 1.0; wpSkin = 1; wpModel = "models/blop4dead/npc_rocketlauncher.mdl"; break;
            }
        }

        local team = -1;

        switch(affiliation)
        {
            case 0: //Neutral
            {
                team = -1; break;
            }
            case 1: //Friendly
            {
                team = 3; break;
            }
            case 2: //Hostile
            {
                team = 2; break;
            }
        }
        this.npcWeaponModel = SpawnEntityFromTable("prop_dynamic", {targetname = this.npcWeaponName, model = wpModel, skin = wpSkin, fademindist = 1500, fademaxdist = 2000, solid = 0})
        this.npcWeaponFireEntity = SpawnEntityFromTable("env_weaponfire", {StartDisabled = 1, TargetArc = 360, TargetRange = 3600, TargetTeam = team, DamageMod = wfDamageMod, WeaponType = wfType});
        DoEntFire("!self", "SetParent", this.npcModel.GetName(), 0, null, this.npcWeaponModel);
        DoEntFire("!self", "SetParent", this.npcWeaponName, 0, null, this.npcWeaponFireEntity);
        DoEntFire("!self", "SetParentAttachment", "weapon_bone", 0.05, null, this.npcWeaponModel);
        DoEntFire("!self", "SetParentAttachment", "fire", 0.05, null, this.npcWeaponFireEntity);
    }

    function Die()
    {
        ::globalNPCCount--;
        ::FIREARMNPC_COUNT--;
    
        local deathanim = "death0" + RandomInt(1, 3).tostring();
        
        this.npcBusy = true;
        this.npcIsCurrentlyGoing = false;
        this.npcCurrentlyRunning = false;
        this.npcCurrentlyTalking = true;
        AddThinkToEnt(this.npcModel, null); 

        DoEntFire("!self", "SetDefaultAnimation", deathanim, 0.0, null, this.npcModel);
        DoEntFire("!self", "SetAnimation", deathanim, 0.01, null, this.npcModel);

        SayQuote(10); 
        
        //this.npcName = "dead_body_" + EntityGroup[0].GetEntityIndex();
        DoEntFire("!self", "Kill", "", 5.0, null, this.npcModel);
    }

    function RiotMode(toggle)
    {
        if (toggle == 1) { this.npcRiotMode = true; }
        else {this.npcRiotMode = false;}
    }

    function WeaponDisableOrEnable(toggle)
    {
        if (toggle == 1)
        {
            DoEntFire("!self", "Enable", "", 0, null, this.npcWeaponModel);
            DoEntFire("!self", "Enable", "", 0, null, this.npcWeaponFireEntity);
        }
        else
        {
            DoEntFire("!self", "Disable", "", 0, null, this.npcWeaponModel);
            DoEntFire("!self", "Disable", "", 0, null, this.npcWeaponFireEntity);
        }
    }

    function AimAt(target)
    {
        this.npcMyCurrentEnemy = target;
        
        if (this.npcIsAiming) {
            TurnToTarget(target); 
        }

        if (!this.npcCurrentlyAnimated)
        {
            switch(this.npcWeapon)
            {
                case 1: SetAnimation("pistolaim", 3.0); break;
                case 2: SetAnimation("shotgunaim", 3.0); break;
                case 3: SetAnimation("rifleaim", 3.0); break;
                case 4: SetAnimation("sniperrifleaim", 3.0); break;
                case 5: SetAnimation("grenadelauncheraim", 3.0); break;
                case 6: SetAnimation("molotovaim", 3.0); break;
                case 7: SetAnimation("rocketlauncheraim", 3.0); break;
                case 8: SetAnimation("rocketlauncheraim", 3.0); break;
            }
            EmitSoundOn("AutoShotgun.Deploy", this.npcWeaponModel);
        }
        WeaponDisableOrEnable(1);
        this.npcIsAiming = true;
    }

    function StopAim()
    {
        DefaultAnimation();
        WeaponDisableOrEnable(0);
        this.npcIsAiming = false;
        ForgetEnemy()
    }

    function SwitchTeam(targetTeam = 1)
    {
        this.npcAffiliation = targetTeam;
        local changeWeaponTeam = null;
        local changeHitboxTeam = null;
        switch(targetTeam)
        {
            case 0: {changeWeaponTeam = -1; changeHitboxTeam = ""; break;} //NEUTRAL
            case 1: {changeWeaponTeam = 3; changeHitboxTeam = "filter_infected"; break;} //FRIENDLY (SURVIVORS SIDE)
            case 2: {changeWeaponTeam = 2; changeHitboxTeam = ""; break;} //HOSTILE TO BOTH SIDES
        }
        DoEntFire("!self", "AddOutput", "TargetTeam " + changeWeaponTeam.tostring(), 0.00, null, this.npcWeaponFireEntity);
        DoEntFire("!self", "AddOutput", "damagefilter " + changeHitboxTeam, 0.00, null, this.npcHitbox);
        ForgetEnemy()
    }

    function ForgetEnemy()
    {
        if (this.npcMyCurrentEnemy != null)
        {
            this.npcMyCurrentEnemy = null;
        }
    }

    function IsMyEnemyAlive()
    {
        if(this.npcMyCurrentEnemy != null && this.npcMyCurrentEnemy.IsValid())
        {
            if (this.npcMyCurrentEnemy.GetHealth() > 0)
            {
                return true;
            }
        }
        return false;
    }

    function InCombat() 
    {
        if (IsMyEnemyAlive() && this.npcIsAiming)
        {
            return true;
        }
        return false;
    }

    function NPCThink()
    {
        local sleepTime = this.NPCSleep();
        if (sleepTime > 0) return sleepTime;
        
        SmoothTurn();
        if (!this.npcHitbox.IsValid()) { Die(); AddThinkToEnt(this.npcModel, null); return 1; }

        local nearbyTarget = LookForNearbyTargets()

        GetGroundAndFront(this.npcSpeed);
        this.npcLastPos = this.npcModel.GetOrigin();

        if(this.npcIsRetreating && this.npcNavPathC.len() > 0)
        {
            //NPCPathFollower()
            local speed = this.npcCurrentlyRunning ? 10 : 4;
            local moveType = this.npcCurrentlyRunning ? 2 : 0;

            local isMoving = GoToNavPath(moveType, speed);
            
            if (!isMoving) 
            {
                this.npcIsCurrentlyGoing = false;
                this.npcCurrentlyRunning = false;
            } 
            else 
            {
                this.npcIsCurrentlyGoing = true;
            }
            return this.npcThinkTime;      
        }

        if (nearbyTarget != null)
        {
            if (nearbyTarget[0] == "tank" || nearbyTarget[0] == "special" || nearbyTarget[0] == "common")
            {
                if (RunAwayFrom(nearbyTarget[0]))
                {
                    RunAway(2) //fear run animation
                    //printl("threat found");
                    //return this.npcThinkTime + 1.0; //<-- stop using this shit.
                }
                else 
                {
                    this.npcMyCurrentEnemy = nearbyTarget[1];
                    if (this.npcNextCombatInsult <= 0)
                    {
                        CombatInsult();
                        ClearPath();
                        AimAt(nearbyTarget[1]);
                        this.npcNextCombatInsult = RandomInt(2, 5);
                    }
                    if(nearbyTarget[2] <= 80) //if target (threat) near to 80 units to us
                    {
                        Retreat()
                        if(nearbyTarget[0] == "tank" || nearbyTarget[0] == "special") //call backup if possible
                        {
                            CallBackup()
                        }
                    }
                    if (nearbyTarget[0] == "tank" && nearbyTarget[1].GetHealth() <= 1 && !this.npcBusy) //tank is dead victory dance now
                    {
                        VictoryDance();
                    }
                    this.npcNextCombatInsult -= this.npcThinkTime;
                }
            }
        }

        // 4 AIMING LOGIC
        if (InCombat()) 
        {
            this.npcCombatTime = 4.0; 
            this.AimAt(this.npcMyCurrentEnemy);
            this.npcNextCombatInsult -= this.npcThinkTime;
            if (this.npcNextCombatInsult <= 0)
            {
                this.npcNextCombatInsult = RandomInt(3, 6);
                CombatInsult()
            }
            // Don't return here, let it fall through to check if there is a HIGHER priority target
        }
        else if (this.npcIsAiming) 
        {
            this.npcCombatTime -= this.npcThinkTime;
            
            if (this.npcCombatTime <= 0) 
            {
                this.StopAim(); 
            }
            // If we are still in the "cooldown" phase of aiming but enemy is dead, 
            // we should still look for a new target before deciding to idle.
        }

        if(this.npcRiotMode)
        {
            this.npcRiotTime -= this.npcThinkTime;

            if (this.npcNavPathC.len() == 0) // Only pick a new target if we finished the old one
            {
                this.npcRunType = 1;
                this.npcCurrentlyRunning = true; 
                CreatePathLegacy(SelectRandomNavRadius(1000).GetCenter());
                this.npcRiotTime = RandomFloat(2.5, 4.5);
            }
        }
        else if (this.npcRiotMode && this.npcRiotTime > 0)
        {
            this.npcRiotTime -= this.npcThinkTime;
        }

        if (this.npcBusyTime <= 0)
        {
            this.npcBusy = false;
        }
        else 
        {
            this.npcBusyTime -= this.npcThinkTime;
            return this.npcThinkTime;
        }

        StuckCheck();

        // 4.5. PATHING LOGIC
        if (this.npcNavPathC.len() > 0) 
        {
            //NPCPathFollower()
            local speed = this.npcCurrentlyRunning ? 10 : 4;
            local moveType = this.npcCurrentlyRunning ? 2 : 0;
            
            // We use a temporary variable so we don't call the function twice in one 'if'
            local isMoving = GoToNavPath(moveType, speed);
            
            if (!isMoving) 
            {
                this.npcIsCurrentlyGoing = false;
                this.npcCurrentlyRunning = false;
                
                if (this.npcConversationMode && this.npcLastTalkedNPC != null)
                {
                    StartConversation();
                    this.npcLastTalkedNPC = null;
                }
                else 
                {
                    DefaultAnimation();
                }
            } 
            else 
            {
                this.npcIsCurrentlyGoing = true;
            }
            return this.npcThinkTime;
        }

        if (this.npcAffiliation != 2 && this.npcAggression > 0.7) //aggressive NPCs in this level will assist survivors.
        {
            TryAssistSurvivor()
        }


        // 5. AI DECISION MAKING
        if (nearbyTarget != null)
        {
            if (nearbyTarget[0] == "survivor" || nearbyTarget[0] == "npc")
            {
                if (this.npcAffiliation == 2 && nearbyTarget[0] == "survivor")
                {
                    AimAt(nearbyTarget[1]);
                    return this.npcThinkTime;
                }
                switch(RandomInt(1, 9))
                {
                    case 1: //talk to npc
                    {
                        if (nearbyTarget[0] == "npc")
                        {
                            StartConversationWithNPC(nearbyTarget[1]);
                        }
                        break;
                    }
                    case 2: //do misc action
                    {
                        switch(RandomInt(1, 4))
                        {
                            case 1:{MiscAction(1); break;}
                            case 2:{MiscAction(2); break;}
                            case 3:{MiscAction(3); break;}
                            case 4:{MiscAction(4); break;}
                        }
                        break;
                    }
                    case 3: //stare at
                    {
                        StareAt(nearbyTarget[1], RandomFloat(2.0, 4.0));
                        break;
                    }
                    case 4: //taunt at
                    {
                        TauntAt(nearbyTarget[1]);
                        break;
                    }
                    case 5: case 6: //talk at
                    {
                        TalkTo(nearbyTarget[1]);
                        break;
                    }
                    case 7: case 8: case 9: //just wander
                    {
                        CreatePathLegacy(SelectRandomNavRadius(1000).GetCenter());
                        break;
                    }
                }
            }
        }

        else 
        {
            CreatePathLegacy(SelectRandomNavRadius(RandomInt(500, 1000)).GetCenter());
        }

        this.npcNextRandomQuote -= this.npcThinkTime;
        if (this.npcNextRandomQuote <= 0 && !this.npcCurrentlyTalking)
        {
            RandomQuote();
        }
        
        return this.npcThinkTime;
    }
}

class ::PedProjectile extends PedArmed //uses Grenade Launcher or Molotov
{
    npcClassNumber = 3;
    npcWeapon = null; //WEAPON TYPES: 0 = Nothing, 1 = Pistol, 2 = Shotgun, 3 = Riffle, 4 = Sniper Riffle, 5 = Grenade Launcher, 6 = Molotov, 7 = Rocket Launcher, 8 = mini nuke launcher.
    npcProjectileSpawnEntity = null; //if npc has grenade launcher or molotov we gonna use this and assign an info_target to it.
    npcNextProjectileSpawnTime = 4.0;

    constructor(npcorigin, thehealth, themodel, gender, voiceSet, type, affiliation, aggression, canTaunt, bodyGroup, bodySkin, range, weapon)
    {
        ::PROJECTILENPC_COUNT++
        base.constructor(npcorigin, thehealth, themodel, gender, voiceSet, type, affiliation, aggression, canTaunt, bodyGroup, bodySkin, range, weapon);
        this.npcProjectileSpawnEntity = SpawnEntityFromTable("info_target", {});
        DoEntFire("!self", "SetParent", this.npcModel.GetName(), 0, null, this.npcWeaponModel);
        DoEntFire("!self", "SetParent", this.npcWeaponName, 0, null, this.npcProjectileSpawnEntity);
        DoEntFire("!self", "SetParentAttachment", "weapon_bone", 0.05, null, this.npcWeaponModel);
        DoEntFire("!self", "SetParentAttachment", "fire", 0.05, null, this.npcProjectileSpawnEntity);
    }

    function Die()
    {
        ::globalNPCCount--;
        ::PROJECTILENPC_COUNT--;
    
        local deathanim = "death0" + RandomInt(1, 3).tostring();
        
        this.npcBusy = true;
        this.npcIsCurrentlyGoing = false;
        this.npcCurrentlyRunning = false;
        this.npcCurrentlyTalking = true;
        AddThinkToEnt(this.npcModel, null); 

        DoEntFire("!self", "SetDefaultAnimation", deathanim, 0.0, null, this.npcModel);
        DoEntFire("!self", "SetAnimation", deathanim, 0.01, null, this.npcModel);

        SayQuote(10); 
        
        //this.npcName = "dead_body_" + EntityGroup[0].GetEntityIndex();
        DoEntFire("!self", "Kill", "", 5.0, null, this.npcModel);
    }
    
    function WeaponDisableOrEnable(toggle)
    {
        if (toggle == 1)
        {
            DoEntFire("!self", "Enable", "", 0, null, this.npcWeaponModel);

        }
        else
        {
            DoEntFire("!self", "Disable", "", 0, null, this.npcWeaponModel);
        }
    }

    function VectorFromQAngle(angles, radius = 1.0)
	{
		local function ToRad(angle)
		{
			return (angle * PI) / 180;
		}
		local yaw = ToRad(angles.Yaw());
		local pitch = ToRad(-angles.Pitch());
		local x = radius * cos(yaw) * cos(pitch);
		local y = radius * sin(yaw) * cos(pitch);
		local z = radius * sin(pitch);
		return Vector(x, y, z);
	}

    function ShootProjectile(target = null)
    {
        if (this.npcWeapon != 8) {
            this.npcNextProjectileSpawnTime = RandomFloat(4.0, 5.0);
        }
        else {
            this.npcNextProjectileSpawnTime = RandomFloat(14.0, 20.0);
        }
        
        if(target != null)
        {
            TurnToTarget(target);
        }

        local startPos = this.npcModel.GetOrigin() + Vector(0, 0, 50); 
        local traceEndpoint = startPos + (this.npcModel.GetForwardVector() * 9000);

        local traceTable = {
            start = startPos
            end = traceEndpoint
            ignore = this.npcHitbox
        }

        if(TraceLine(traceTable))
        {
            if(traceTable.hit)
            {
                if(this.npcWeapon == 5 || this.npcWeapon == 6)
                {
                    local newProjectile = NPCProjectile(this.npcWeapon, "projectile_" + this.npcName, this.npcProjectileSpawnEntity.GetOrigin(), target, this.npcModel, this.npcAffiliation);
                    local ent = newProjectile.projectileEntity; 
                    
                    BindNPCToEntity(ent, newProjectile);
                    ent.ValidateScriptScope();
                    local scope = ent.GetScriptScope();
                    
                    scope.Think <- function() {
                        return Controller.ProjectileThink();
                    };
                    AddThinkToEnt(ent, "Think");
                }
                else if (this.npcWeapon == 7 || this.npcWeapon == 8)
                {
                    local newProjectile = NPCProjectileRocket(this.npcWeapon, "projectile_" + this.npcName, this.npcProjectileSpawnEntity.GetOrigin(), this.npcMyCurrentEnemy, this.npcModel, this.npcAffiliation, this.npcModel.GetAngles(), 38);
                    local ent = newProjectile.projectileEntity; 
                    
                    BindNPCToEntity(ent, newProjectile);
                    ent.ValidateScriptScope();
                    local scope = ent.GetScriptScope();
                    
                    scope.Think <- function() {
                        return Controller.ProjectileThink();
                    };
                    AddThinkToEnt(ent, "Think");
                }
            }
        }

        switch (this.npcWeapon)
        {
            case 5: //grenade launcher
            {
                SetAnimation("grenadelaunchershoot", 1.0);
                EmitSoundOn("GrenadeLauncher.Fire", this.npcWeaponModel);
                break;
            }
            case 6: //molotov
            {
                SetAnimation("molotovshoot", 1.0);
                EmitSoundOn("Molotov.Throw", this.npcWeaponModel);
                break;
            }
            case 7: //rocket launcher
            {
                SetAnimation("rocketlaunchershoot", 1.0);
                EmitAmbientSoundOn("cutscene/rpgshoot01.mp3", 10, 85, 100, this.npcWeaponModel);	
                break;
            }
            case 8: //MINI-NUKE LAUNCHER
            {
                SetAnimation("rocketlaunchershoot", 1.0);
                EmitAmbientSoundOn("sfx/weapons/mininukelaunchershoot.mp3", 10, 95, 100, this.npcWeaponModel);	
                break;
            }
        }
    }

    function StopAim()
    {
        DefaultAnimation();
        WeaponDisableOrEnable(0);
        this.npcIsAiming = false;
        this.npcNextProjectileSpawnTime = 1.0;
        ForgetEnemy()
    }

    function NPCThink()
    {
        local sleepTime = this.NPCSleep();
        if (sleepTime > 0) return sleepTime;
        
        SmoothTurn();
        if (!this.npcHitbox.IsValid()) { Die(); AddThinkToEnt(this.npcModel, null); return 1; }

        local nearbyTarget = LookForNearbyTargets()

        GetGroundAndFront(this.npcSpeed);
        this.npcLastPos = this.npcModel.GetOrigin();

        if(this.npcIsRetreating && this.npcNavPathC.len() > 0)
        {
            //NPCPathFollower()
            local speed = this.npcCurrentlyRunning ? 10 : 4;
            local moveType = this.npcCurrentlyRunning ? 2 : 0;

            local isMoving = GoToNavPath(moveType, speed);
            
            if (!isMoving) 
            {
                this.npcIsCurrentlyGoing = false;
                this.npcCurrentlyRunning = false;
            } 
            else 
            {
                this.npcIsCurrentlyGoing = true;
            }
            return this.npcThinkTime;      
        }

        if (nearbyTarget != null)
        {
            if (nearbyTarget[0] == "tank" || nearbyTarget[0] == "special" || nearbyTarget[0] == "common")
            {
                if (RunAwayFrom(nearbyTarget[0]))
                {
                    RunAway(2) //fear run animation
                    //printl("threat found");
                    //return this.npcThinkTime + 1.0; //<-- stop using this shit.
                }
                else 
                {
                    this.npcMyCurrentEnemy = nearbyTarget[1];
                    if (this.npcNextCombatInsult <= 0)
                    {
                        CombatInsult();
                        ClearPath();
                        AimAt(nearbyTarget[1]);
                        this.npcNextCombatInsult = RandomInt(2, 5);
                    }
                    this.npcNextCombatInsult -= this.npcThinkTime;
                    if(nearbyTarget[2] <= 80) //if target (threat) near to 80 units to us
                    {
                        Retreat()
                        if(nearbyTarget[0] == "tank" || nearbyTarget[0] == "special") //call backup if possible
                        {
                            CallBackup()
                        }
                    }
                    if (nearbyTarget[0] == "tank" && nearbyTarget[1].GetHealth() <= 1 && !this.npcBusy) //tank is dead victory dance now
                    {
                        VictoryDance();
                    }
                }
            }
        }

        // 4.5. AIMING LOGIC
        if (InCombat()) 
        {
            this.npcCombatTime = 4.0; 
            this.AimAt(this.npcMyCurrentEnemy);
            this.npcNextCombatInsult -= this.npcThinkTime;
            this.npcNextProjectileSpawnTime -= this.npcThinkTime;
            if (this.npcNextCombatInsult <= 0)
            {
                this.npcNextCombatInsult = RandomInt(3, 6);
                CombatInsult()
            }
            if (this.npcNextProjectileSpawnTime <= 0)
            {
                ShootProjectile(this.npcMyCurrentEnemy)
            }
        }
        else if (this.npcIsAiming) 
        {
            this.npcCombatTime -= this.npcThinkTime;
            
            if (this.npcCombatTime <= 0) 
            {
                this.StopAim(); 
            }
            // If we are still in the "cooldown" phase of aiming but enemy is dead, 
            // we should still look for a new target before deciding to idle.
        }

        if(this.npcRiotMode)
        {
            this.npcRiotTime -= this.npcThinkTime;

            if (this.npcNextProjectileSpawnTime <= 0) 
            {
                ShootProjectile(); 
            }

            if (this.npcNavPathC.len() == 0) // Only pick a new target if we finished the old one
            {
                this.npcRunType = 1;
                this.npcCurrentlyRunning = true; 
                CreatePathLegacy(SelectRandomNavRadius(1000).GetCenter());
                this.npcRiotTime = RandomFloat(2.5, 4.5);
            }
        }

        else if (this.npcRiotMode && this.npcRiotTime > 0)
        {
            this.npcRiotTime -= this.npcThinkTime;
        }

        if (this.npcBusyTime <= 0)
        {
            this.npcBusy = false;
        }
        else 
        {
            this.npcBusyTime -= this.npcThinkTime;
            return this.npcThinkTime;
        }

        StuckCheck();

        // 4. PATHING LOGIC
        if (this.npcNavPathC.len() > 0) 
        {
            //NPCPathFollower()
            local speed = this.npcCurrentlyRunning ? 10 : 4;
            local moveType = this.npcCurrentlyRunning ? 2 : 0;
            
            // We use a temporary variable so we don't call the function twice in one 'if'
            local isMoving = GoToNavPath(moveType, speed);
            
            if (!isMoving) 
            {
                this.npcIsCurrentlyGoing = false;
                this.npcCurrentlyRunning = false;
                
                if (this.npcConversationMode && this.npcLastTalkedNPC != null)
                {
                    StartConversation();
                    this.npcLastTalkedNPC = null;
                }
                else 
                {
                    DefaultAnimation();
                }
            } 
            else 
            {
                this.npcIsCurrentlyGoing = true;
            }
            return this.npcThinkTime;
        }

        if (this.npcAffiliation != 2 && this.npcAggression > 0.7) //aggressive NPCs in this level will assist survivors.
        {
            TryAssistSurvivor()
        }


        // 5. AI DECISION MAKING
        if (nearbyTarget != null)
        {
            if (nearbyTarget[0] == "survivor" || nearbyTarget[0] == "npc")
            {
                if (this.npcAffiliation == 2 && nearbyTarget[0] == "survivor")
                {
                    AimAt(nearbyTarget[1]);
                    return this.npcThinkTime;
                }
                switch(RandomInt(1, 9))
                {
                    case 1: //talk to npc
                    {
                        if (nearbyTarget[0] == "npc")
                        {
                            StartConversationWithNPC(nearbyTarget[1]);
                        }
                        break;
                    }
                    case 2: //do misc action
                    {
                        switch(RandomInt(1, 4))
                        {
                            case 1:{MiscAction(1); break;}
                            case 2:{MiscAction(2); break;}
                            case 3:{MiscAction(3); break;}
                            case 4:{MiscAction(4); break;}
                        }
                        break;
                    }
                    case 3: //stare at
                    {
                        StareAt(nearbyTarget[1], RandomFloat(2.0, 4.0));
                        break;
                    }
                    case 4: //taunt at
                    {
                        TauntAt(nearbyTarget[1]);
                        break;
                    }
                    case 5: case 6: //talk at
                    {
                        TalkTo(nearbyTarget[1]);
                        break;
                    }
                    case 7: case 8: case 9: //just wander
                    {
                        CreatePathLegacy(SelectRandomNavRadius(1000).GetCenter());
                        break;
                    }
                }
            }
        }

        else 
        {
            CreatePathLegacy(SelectRandomNavRadius(RandomInt(500, 1000)).GetCenter());
        }

        this.npcNextRandomQuote -= this.npcThinkTime;
        if (this.npcNextRandomQuote <= 0 && !this.npcCurrentlyTalking)
        {
            RandomQuote();
        }
        
        return this.npcThinkTime;
    }
}

class ::PedMelee extends Pedestrian //uses melee weapons.
{
    npcClassNumber = 5;
    npcWeapon = null; //WEAPON TYPES: 0 = Fists, 1 = Baseballbat, 2 = Sword, 3 = Katana, 4 = Shovel, 5 = Frying Pan, 6 = Sledgehammer, 7 = Police baton, 8 = Axe, 9 = Knife, 10 = Protest Sign
    npcWeaponModel = null;
    npcLookAheadDistance = 32;
    npcWeaponName = null;
    npcIsAiming = false;
    npcSpottingTimer = 0;
    npcMyCurrentEnemy = null;
    npcCombatTime = 4.0;
    npcNextPathCreation = 0.0;
    npcMeleeLockedIn = false;
    npcIsSwinging = false;
    npcMeleeMoveDirection = "N";
    npcMeleeNextRandomMove = 2.0;
    npcIsStandingStill = false;
    npcNextMeleeAttack = 0.5;
    npcDamageMultiplier = 1.0;
    npcMeleeCanStagger = false;
    npcMeleeDamageMin = 20;
    npcMeleeDamageMax = 80;
    
    constructor(npcorigin, thehealth, themodel, gender, voiceSet, type, affiliation, aggression, canTaunt, bodyGroup, bodySkin, range, weapon, dmgMulti)
    {
        ::MELEENPC_COUNT++
        base.constructor(npcorigin, thehealth, themodel, gender, voiceSet, type, affiliation, aggression, canTaunt, bodyGroup, bodySkin, range);
        this.npcWeapon = weapon;
        this.npcDamageMultiplier = dmgMulti;
        this.npcWeaponName = CreateNPCName(1);
        
        local wpModel = null;
        local wpSkin = 0;

        switch(weapon)
        {
            case 0: //Fists
            {
                wpModel = null; this.npcMeleeCanStagger = true; break;
            }
            case 1: //Baseball bat
            {
                wpModel = "models/blop4dead/npc_baseballbat.mdl"; this.npcMeleeDamageMin = 35; this.npcMeleeDamageMax = 110; this.npcMeleeCanStagger = true; break;
            }
            case 2: //Sword
            {
                wpModel = "models/blop4dead/npc_sword.mdl"; this.npcMeleeDamageMin = 50; this.npcMeleeDamageMax = 125; break;
            }
            case 3: //Katana
            {
                wpModel = "models/blop4dead/npc_katana.mdl"; this.npcMeleeDamageMin = 65; this.npcMeleeDamageMax = 150; break;
            }
            case 4: //Shovel
            {
                wpModel = "models/blop4dead/npc_shovel.mdl"; this.npcMeleeDamageMin = 45; this.npcMeleeDamageMax = 100; this.npcMeleeCanStagger = true; break;
            }
            case 5: //Frying Pan
            {
                wpModel = "models/blop4dead/npc_fryingpan.mdl"; this.npcMeleeDamageMin = 45; this.npcMeleeDamageMax = 120; this.npcMeleeCanStagger = true; break;
            }
            case 6: //Sledgehammer
            {
                wpModel = "models/blop4dead/npc_sledgehammer.mdl"; this.npcMeleeDamageMin = 50; this.npcMeleeDamageMax = 170; this.npcMeleeCanStagger = true; break;
            }
            case 7: //Police Baton
            {
                wpModel = "models/blop4dead/npc_policebaton.mdl"; this.npcMeleeDamageMin = 25; this.npcMeleeDamageMax = 85; break;
            }
            case 8: //Axe
            {
                wpModel = "models/blop4dead/npc_axe.mdl"; this.npcMeleeDamageMin = 50; this.npcMeleeDamageMax = 140; break;
            }
            case 9: //Knife
            {
                wpModel = "models/blop4dead/npc_knife.mdl"; this.npcMeleeDamageMin = 44; this.npcMeleeDamageMax = 117; break;
            }
            case 10: //Protest Sign
            {
                wpModel = "models/blop4dead/npc_protestsign.mdl"; this.npcMeleeDamageMin = 30; this.npcMeleeDamageMax = 111; this.npcMeleeCanStagger = true; break;
            }
        }

        if(wpModel != null)
        {
            this.npcWeaponModel = SpawnEntityFromTable("prop_dynamic", {targetname = this.npcWeaponName, model = wpModel, skin = wpSkin, fademindist = 1500, fademaxdist = 2000, solid = 0})
        }
        DoEntFire("!self", "SetParent", this.npcModel.GetName(), 0, null, this.npcWeaponModel);
        DoEntFire("!self", "SetParentAttachment", "weapon_bone", 0.05, null, this.npcWeaponModel);
    }

    function Die()
    {
        ::globalNPCCount--;
        ::MELEENPC_COUNT--;
    
        local deathanim = "death0" + RandomInt(1, 3).tostring();
        
        this.npcBusy = true;
        this.npcIsCurrentlyGoing = false;
        this.npcCurrentlyRunning = false;
        this.npcCurrentlyTalking = true;
        AddThinkToEnt(this.npcModel, null); 

        DoEntFire("!self", "SetDefaultAnimation", deathanim, 0.0, null, this.npcModel);
        DoEntFire("!self", "SetAnimation", deathanim, 0.01, null, this.npcModel);

        SayQuote(10); 
        
        //this.npcName = "dead_body_" + EntityGroup[0].GetEntityIndex();
        DoEntFire("!self", "Kill", "", 5.0, null, this.npcModel);
    }

    function Hurt()
    {
        //SetAnimation("hurt0" + RandomInt(1, 2).tostring(), 1.0);
        SayQuote(4);
        //overwritten to prevent npc getting softlocked and not being able to hit target
    }

    function RiotMode(toggle)
    {
        if (toggle == 1) { this.npcRiotMode = true; }
        else {this.npcRiotMode = false;}
    }

    function WeaponDisableOrEnable(toggle)
    {
        if(this.npcWeaponModel == null) {return};

        if (toggle == 1)
        {
            DoEntFire("!self", "Enable", "", 0, null, this.npcWeaponModel);
        }
        else
        {
            DoEntFire("!self", "Disable", "", 0, null, this.npcWeaponModel);
        }
    }

    function AimAt(target)
    {
        this.npcMyCurrentEnemy = target;
        
        if (this.npcIsAiming) {
            TurnToTarget(target); 
        }

        if (!this.npcCurrentlyAnimated)
        {
            SetAnimation("melee_stand", 3.0);
            //EmitSoundOn("AutoShotgun.Deploy", this.npcWeaponModel);
        }
        WeaponDisableOrEnable(1);
        this.npcIsAiming = true;
    }

    function StopAim()
    {
        DefaultAnimation();
        WeaponDisableOrEnable(0);
        this.npcIsAiming = false;
        this.npcMeleeLockedIn = false
        ForgetEnemy()
    }

    function SwitchTeam(targetTeam = 1)
    {
        this.npcAffiliation = targetTeam;
        local changeWeaponTeam = null;
        local changeHitboxTeam = null;
        switch(targetTeam)
        {
            case 0: {changeWeaponTeam = -1; changeHitboxTeam = ""; break;} //NEUTRAL
            case 1: {changeWeaponTeam = 3; changeHitboxTeam = "filter_infected"; break;} //FRIENDLY (SURVIVORS SIDE)
            case 2: {changeWeaponTeam = 2; changeHitboxTeam = ""; break;} //HOSTILE TO BOTH SIDES
        }
        DoEntFire("!self", "AddOutput", "damagefilter " + changeHitboxTeam, 0.00, null, this.npcHitbox);
        ForgetEnemy()
    }

    function ForgetEnemy()
    {
        if (this.npcMyCurrentEnemy != null)
        {
            this.npcMyCurrentEnemy = null;
        }
    }

    function IsMyEnemyAlive()
    {
        if(this.npcMyCurrentEnemy != null && this.npcMyCurrentEnemy.IsValid())
        {
            if (this.npcMyCurrentEnemy.GetHealth() > 0)
            {
                return true;
            }
        }
        this.npcMeleeLockedIn = false;
        this.npcIsAiming = false;
        return false;
    }

    function InCombat() 
    {
        if (IsMyEnemyAlive() && this.npcIsAiming)
        {
            return true;
        }
        return false;
    }

    function RushAt(target)
    {
        if(this.npcMyCurrentEnemy == null && this.npcMyCurrentEnemy.IsValid()) return false;

        if (target == null || !target.IsValid() || target.GetHealth() <= 0) 
        {
            this.npcIsCurrentlyGoing = false;
            return false;
        }

        local dist = (this.npcMyCurrentEnemy.GetOrigin() - this.npcModel.GetOrigin()).Length2D();

        if (dist <= 100) 
        {
            this.npcIsCurrentlyGoing = false; 
            this.LockIn();                   
            this.npcIsAiming = true;          
            return true;
        }
        
        if (IsMyWayToPathBlocked(target) && dist > 400)
        {
            if(this.npcNextPathCreation <= 0)
            {
                CreatePath(target.GetOrigin())
                this.npcNextPathCreation = 10.0;
            }
            this.npcNextPathCreation -= this.npcThinkTime;
            local moving = GoToNavPath(3, 2);

            if (!moving) 
            {
                this.npcIsCurrentlyGoing = false;
                this.npcCurrentlyRunning = false;
                return false;
            } 
            else 
            {
                this.npcIsCurrentlyGoing = true;
                return true;
            }
        }
        else
        {
            this.npcCurrentlyRunning = true;
            GoToTarget(3, 2, target); 
            return true;
        }

        return false;
    }

    function LockIn()
    {
        this.npcMeleeLockedIn = true;
        this.npcIsAiming = true;
        this.npcCombatTime = 4.0;
        SetAnimationWithDefault("melee_stand");
    }

    function LockOut()
    {
        this.npcMeleeLockedIn = false;
        SetAnimationWithDefault("idle01");
    }

    function MeleeMove(direction, _moveDist = 5, _checkDistance = 20) //formerly 18
    {
        if (this.npcMyCurrentEnemy == null) return false;

        local myPos = this.npcModel.GetOrigin();
        local forward = this.npcModel.GetForwardVector();
        local right = Vector(forward.y, -forward.x, 0);
        
        local moveVec = Vector(0,0,0);
        local anim = "melee_moveforward";

        switch(direction)
        {
            case "N":  moveVec = forward; break;                         // Forward
            case "S":  moveVec = forward * -1; anim = "melee_movebackward"; break; // Backward
            case "W":  moveVec = right * -1; break;                      // Left
            case "E":  moveVec = right; break;                           // Right
            case "NW": moveVec = (forward - right); break;        // Forward-Left
            case "NE": moveVec = (forward + right); break;        // Forward-Right
            case "SW": moveVec = (forward * -1 - right); anim = "melee_movebackward"; break;   // Back-Left
            case "SE": moveVec = (forward * -1 + right); anim = "melee_movebackward"; break;   // Back-Right
        }

        if (moveVec.x == 0 && moveVec.y == 0 && moveVec.z == 0)
        {
            moveVec = forward; 
        }

        //doing this instead of .Norm() because it fucking destroys the whole script.
        local len = sqrt((moveVec.x * moveVec.x) + (moveVec.y * moveVec.y) + (moveVec.z * moveVec.z));
        if (len > 0)
        {
            moveVec = Vector(moveVec.x / len, moveVec.y / len, moveVec.z / len);
        }

        local targetMoveCheck = myPos + (moveVec * _checkDistance);
        local targetMovePos = myPos + (moveVec * _moveDist)

        local enemy = this.npcMyCurrentEnemy; 

        if (enemy != null && enemy.IsValid() && enemy.GetHealth() > 0)
        {
            TurnToTarget(enemy);
        }
        else 
        {
            this.npcMeleeLockedIn = false;
            this.npcIsAiming = false;
            this.npcMyCurrentEnemy = null;
        }  

        local tr = {
            start = myPos + Vector(0,0,32),
            end = targetMoveCheck + Vector(0,0,32),
            mask = playerClip | monsterClip | moveableClip | defaultClip,
            ignore = this.npcHitbox
        };

        if (this.npcCurrentAnimation != anim && !this.npcBusy)
        {
            SetAnimationWithDefault(anim);
            this.npcCurrentAnimation = anim;
        }

        this.npcIsStandingStill = false;

        TraceLine(tr);

        if (!tr.hit)
        {
            local tr2 = 
            {
            start = targetMovePos + Vector(0,0,32),
            end = targetMovePos + Vector(0,0,-64),
            mask = playerClip | monsterClip | moveableClip | defaultClip,
            ignore = this.npcHitbox
            }
            TraceLine(tr2)

            if(tr2.hit)
            {
                if (abs(myPos.z - tr2.pos.z) < 64) 
                {
                    this.npcModel.SetOrigin(tr2.pos);
                    return true;
                }
            }
            else
            {
                this.npcModel.SetOrigin(tr2.pos - Vector(0, 0, -3));
                return false;
            }
        }
        
        return false;
    }

    function DoMeleeDamage(target)
    {
        local damage = RandomInt(this.npcMeleeDamageMin, this.npcMeleeDamageMax) * this.npcDamageMultiplier;
        
        // DMG_CLUB is 128, but 33554432 is fine if that's what you're using for your mod
        target.TakeDamage(damage, 33554432, this.npcHitbox);
        
        if(this.npcMeleeCanStagger && target.GetClassname() == "player")
        {
            target.Stagger(this.npcModel.GetOrigin() - target.GetOrigin());
        }
    }

    function MeleeAttack()
    {

        this.npcBusy = true;
        this.npcBusyTime = 1.2;
        this.npcIsSwinging = true;
        local myOrigin = this.npcModel.GetOrigin();
        local forward = this.npcModel.GetForwardVector();

        local traceStart = myOrigin + Vector(0, 0, 32);

        local traceEnd = null //formerly 40
        local nearestEnt = Entities.FindByNameNearest("*", this.npcModel.GetOrigin(), 44)
        
        if(nearestEnt != null)
        {
            local entCls = nearestEnt.GetClassname()
            if(entCls == "player" || entCls == "infected")
            {
                traceEnd = nearestEnt.GetOrigin();
            }
            else 
            {
                traceEnd = traceStart + (forward * 52);
            }
        }
        else
        {
            traceEnd = traceStart + (forward * 52);
        }

        // Create the trace table
        local tr = {
            start = traceStart,
            end = traceEnd,
            mask = 33570827,
            ignore = this.npcHitbox
        };
        TraceLine(tr);

        local animName = ""
        switch(this.npcWeapon)
        {
            case 0: animName = "melee_fists_hit0" + RandomInt(1, 4); break;//FISTS
            case 1: animName = "melee_sword_hit"; break;                   //SWORD
            case 2: animName = "melee_katana_hit"; break;                  //KATANA
            case 3: animName = "melee_shovel_hit"; break;                  //SHOVEL
            case 4: animName = "melee_pan_hit"; break;                     //FRYING PAN
            case 5: animName = "melee_sledgehammer_hit"; break;            //SLEDGEHAMMER
            case 6: animName = "melee_baton_hit"; break;                   //POLICE BATON
            case 7: animName = "melee_axe_hit"; break;                     //AXE
            case 8: animName = "melee_knife_hit"; break;                   //KNIFE
            case 9: animName = "melee_sign_hit"; break;                    //PROTEST SIGN
        }

        SetAnimation(animName, 2.0);
        this.npcCurrentAnimation = animName;

        EmitSoundOn("Claw.Swing", this.npcModel)

        if (tr.hit)
        {
            EmitSoundOn("Zombie.Punch", this.npcModel);
            local entities = []
            for(local entity; entity = Entities.FindByClassnameWithin(entity, "*", this.npcModel.GetOrigin(), 80); ) //formerly 32
            {
                if (entity != null)
                {
                    entities.push(entity);
                }
                                        
            }

            if (entities != null)
            {
                foreach(ent in entities)
                {
                    if (ent == null || !ent.IsValid()) continue;
    
                    if (ent == this.npcModel || ent == this.npcHitbox) continue;

                    local entCls = ent.GetClassname();

                    if (this.npcAffiliation == 1) // SURVIVOR SIDE NPC
                    {
                        if (entCls == "player")
                        {
                            if (ent.GetZombieType() != 9) 
                            {
                                DoMeleeDamage(ent);
                            }
                        }
                        else if (entCls == "infected" || entCls == "witch")
                        {
                            DoMeleeDamage(ent);
                        }
                    }
                    else
                    {
                        if (entCls == "player" || entCls == "infected")
                        {
                            DoMeleeDamage(ent);
                        }
                    }
                }
            } 
        }
    }
    function NPCThink()
    {
        OOBCheck()
        local sleepTime = this.NPCSleep();
        if (sleepTime > 0) return sleepTime;
        
        SmoothTurn();
        if (!this.npcHitbox.IsValid()) { Die(); AddThinkToEnt(this.npcModel, null); return 1; }

        local nearbyTarget = LookForNearbyTargets()

        GetGroundAndFront(this.npcSpeed);
        this.npcLastPos = this.npcModel.GetOrigin();

        if(this.npcIsRetreating && this.npcNavPathC.len() > 0)
        {
            local speed = this.npcCurrentlyRunning ? 10 : 4;
            local moveType = this.npcCurrentlyRunning ? 2 : 0;

            local isMoving = GoToNavPath(moveType, speed);
            
            if (!isMoving) 
            {
                this.npcIsCurrentlyGoing = false;
                this.npcCurrentlyRunning = false;
            } 
            else 
            {
                this.npcIsCurrentlyGoing = true;
            }
            return this.npcThinkTime;      
        }

        if (nearbyTarget != null && !this.npcMeleeLockedIn)
        {
            local targetType = nearbyTarget[0];
            local targetEnt = nearbyTarget[1];

            local isHostileSurvivor = (targetType == "survivor" && this.npcAffiliation == 2);
            local isZombie = (targetType == "tank" || targetType == "special" || targetType == "common");

            if (isZombie || isHostileSurvivor)
            {
                // Check if this is a BRAND NEW enemy
                if (this.npcMyCurrentEnemy == null || !this.npcMyCurrentEnemy.IsValid())
                {
                    this.npcMyCurrentEnemy = targetEnt;
                    
                    // Perform the "Spotting" action
                    DoSpot(this.npcMyCurrentEnemy); 
                    
                    // Lock the NPC in place for 1.5 seconds before they can move/attack
                    this.npcBusy = true;
                    this.npcBusyTime = 1.5; 
                    
                    return this.npcThinkTime; 
                }

                // If we already have an enemy, just handle regular logic (Run away or Lock In)
                if (isZombie && RunAwayFrom(targetType))
                {
                    RunAway(2);
                }
                else 
                {
                    // Ensure target is updated if it changes (but skip DoSpot if we already had an enemy)
                    this.npcMyCurrentEnemy = targetEnt;

                    local dist = GetDistance(this.npcMyCurrentEnemy, this.npcModel);
                    if (dist <= 80) 
                    {
                        LockIn(); 
                        if (targetType == "tank" || targetType == "special")
                        {
                            CallBackup();
                        }
                    }
                }
            }
        }

        if (IsMyEnemyAlive())
        {
            if(GetDistance(this.npcMyCurrentEnemy, this.npcModel) > 200)
            {
                RushAt(this.npcMyCurrentEnemy);
            }
            else if (GetDistance(this.npcMyCurrentEnemy, this.npcModel) <= 200 && GetDistance(this.npcMyCurrentEnemy, this.npcModel) > 45)
            {
                this.npcMeleeMoveDirection = "N";
            }
        }   
    
        if (this.npcBusyTime <= 0)
        {
            this.npcBusy = false;
        }
        else 
        {
            this.npcBusyTime -= this.npcThinkTime;
            return this.npcThinkTime;
        }

        if(this.npcMyCurrentEnemy != null) 
        {
            //printl("Enemy is there, combat insult is active")
            this.npcNextCombatInsult -= this.npcThinkTime;
            if (this.npcNextCombatInsult <= 0)
            {
                //printl("Combat insulting NOW")
                SayQuote(2)
                this.npcNextCombatInsult = RandomInt(3, 6);
            }
        }
        
        if (InCombat() && !this.npcBusy) 
        {
            local dist = GetDistance(this.npcMyCurrentEnemy, this.npcModel);

            if (this.npcMeleeLockedIn && !IsMyEnemyAlive())
            {
                this.LockOut();
                return this.npcThinkTime;
            }
            else if(this.npcMeleeLockedIn)
            {
                this.npcCombatTime = 4.0; 
                this.AimAt(this.npcMyCurrentEnemy);
                
                if(this.npcNextMeleeAttack <= 0)
                {
                    MeleeAttack();
                    this.npcBusy = true;
                    this.npcNextMeleeAttack = RandomFloat(0.5, 2.5);
                    this.npcBusyTime = 1.0;
                    return this.npcThinkTime; // Don't move while swinging!
                }

                local moveDir = this.npcMeleeMoveDirection;
                local moveSpeed = 2;

                if (dist > 85) 
                {
                    moveDir = "N"; 
                    moveSpeed = 4;
                }
                else if (dist < 15) 
                {
                    moveDir = "S"; 
                    moveSpeed = 4;
                }

                local isWalking = MeleeMove(moveDir, moveSpeed);
                //printl("Melee Move: " + moveDir);
                
                if (!isWalking && !this.npcBusy && this.npcCurrentAnimation != "melee_stand")
                {
                    this.SetAnimationWithDefault("melee_stand");
                    this.npcCurrentAnimation = "melee_stand";
                }

                if (this.npcMeleeNextRandomMove <= 0)
                {
                    local moveOptions = ["N", "S", "W", "E", "NE", "NW", "SW", "SE"];
                    this.npcMeleeMoveDirection = moveOptions[RandomInt(0, 7)];
                    this.npcMeleeNextRandomMove = RandomFloat(1.0, 5.0);
                }

                this.npcMeleeNextRandomMove -= this.npcThinkTime;
                this.npcNextMeleeAttack -= this.npcThinkTime;
            }        
            return this.npcThinkTime 
        }
        else if (this.npcIsAiming) 
        {   
            this.npcCombatTime -= this.npcThinkTime;
            
            if (this.npcCombatTime <= 0) 
            {
                this.StopAim(); 
            }
        }

        if(!IsMyEnemyAlive())
        {
            if (this.npcMyCurrentEnemy != null)
            {
                this.npcNavPathC = [];
                this.npcIsCurrentlyGoing = false;
                this.npcCurrentlyRunning = false;
                StopAim();
                LockOut();
            }
            this.npcMyCurrentEnemy = null;
        }

        if(this.npcRiotMode)
        {
            this.npcRiotTime -= this.npcThinkTime;

            if (this.npcNavPathC.len() == 0)
            {
                this.npcRunType = 1;
                this.npcCurrentlyRunning = true; 
                CreatePathLegacy(SelectRandomNavRadius(1000).GetCenter());
                this.npcRiotTime = RandomFloat(2.5, 4.5);
            }
        }

        else if (this.npcRiotMode && this.npcRiotTime > 0)
        {
            this.npcRiotTime -= this.npcThinkTime;
        }

        StuckCheck();

        // 4. PATHING LOGIC

        if (this.npcNavPathC.len() > 0) 
        {
            //NPCPathFollower()
            local speed = 4; // Default speed
            local moveType = 0; // Default Walk

            if (this.npcMeleeLockedIn || this.npcIsAiming) // If we are in "Melee Mode"
            {
                moveType = 3;
                speed = 5; 
            }
            else if (this.npcCurrentlyRunning)
            {
                moveType = 1; // Standard Run
                speed = 8;
            }

            local isMoving = GoToNavPath(moveType, speed);
            
            if (!isMoving) 
            {
                this.npcIsCurrentlyGoing = false;
                if (!this.npcBusy && !this.npcMeleeLockedIn) 
                {
                    this.npcCurrentlyRunning = false;
                    DefaultAnimation();
                }  
            } 
            else 
            {
                this.npcIsCurrentlyGoing = true;
            }
            return this.npcThinkTime;
        }

        if (this.npcAffiliation != 2 && this.npcAggression > 0.7) //aggressive NPCs in this level will assist survivors.
        {
            TryAssistSurvivor()
        }


        // 5. AI DECISION MAKING
        if (nearbyTarget != null)
        {
            if (nearbyTarget[0] == "survivor" || nearbyTarget[0] == "npc")
            {
                /* if (this.npcAffiliation == 2 && nearbyTarget[0] == "survivor")
                {
                    this.npcMyCurrentEnemy = nearbyTarget[1];
                    return this.npcThinkTime; 
                }
                */
                switch(RandomInt(1, 9))
                {
                    case 1: //talk to npc
                    {
                        if (nearbyTarget[0] == "npc")
                        {
                            StartConversationWithNPC(nearbyTarget[1]);
                        }
                        break;
                    }
                    case 2: //do misc action
                    {
                        switch(RandomInt(1, 4))
                        {
                            case 1:{MiscAction(1); break;}
                            case 2:{MiscAction(2); break;}
                            case 3:{MiscAction(3); break;}
                            case 4:{MiscAction(4); break;}
                        }
                        break;
                    }
                    case 3: //stare at
                    {
                        StareAt(nearbyTarget[1], RandomFloat(2.0, 4.0));
                        break;
                    }
                    case 4: //taunt at
                    {
                        TauntAt(nearbyTarget[1]);
                        break;
                    }
                    case 5: case 6: //talk at
                    {
                        TalkTo(nearbyTarget[1]);
                        break;
                    }
                    case 7: case 8: case 9: //just wander
                    {
                        CreatePathLegacy(SelectRandomNavRadius(1000).GetCenter());
                        break;
                    }
                }
            }
        }

        if (nearbyTarget == null && !InCombat()) 
        {
            CreatePathLegacy(SelectRandomNavRadius(RandomInt(500, 1000)).GetCenter());
        }

        this.npcNextRandomQuote -= this.npcThinkTime;
        if (this.npcNextRandomQuote <= 0 && !this.npcCurrentlyTalking)
        {
            RandomQuote();
        }
        
        return this.npcThinkTime;
    }
}

class ::NPCProjectile 
{
    projectileEntity = null;
    projectileType = null;
    projectileTeam = null;
    projectileLifeTime = 10.0;
    projectileOwner = null;
    projectileName = null;
    projectileSmoke = null;
    //projectileOrigin = null;
    projectileTarget = null;

    function VectorFromQAngle(angles, radius = 1.0)
	{
		local function ToRad(angle)
		{
			return (angle * PI) / 180;
		}
		local yaw = ToRad(angles.Yaw());
		local pitch = ToRad(-angles.Pitch());
		local x = radius * cos(yaw) * cos(pitch);
		local y = radius * sin(yaw) * cos(pitch);
		local z = radius * sin(pitch);
		return Vector(x, y, z);
	}
    
    constructor(pType, pName, pOrigin, pTarget, pOwner, pTeam)
    {
        this.projectileName = pName + "_" + RandomInt(1, 1000).tostring();
        this.projectileOwner = pOwner;
        this.projectileTeam = pTeam;
        this.projectileType = pType; // Make sure to save this!

        switch(pType)
        {
            case 5: //grenade launcher
            {
                this.projectileEntity = SpawnEntityFromTable("grenade_launcher_projectile", {targetname = this.projectileName});
                this.projectileEntity.SetOrigin(pOrigin);
                DoEntFire("!self", "ignite", "", 0, this.projectileEntity, this.projectileEntity);
				NetProps.SetPropEntity(this.projectileEntity, "m_hOwnerEntity", pOwner);
                break;
            }
            case 6: //molotov
            {
                this.projectileEntity = SpawnEntityFromTable("molotov_projectile", {targetname = this.projectileName});
                this.projectileEntity.SetOrigin(pOrigin);
                DoEntFire("!self", "ignite", "", 0, this.projectileEntity, this.projectileEntity);
				NetProps.SetPropEntity(this.projectileEntity, "m_hOwnerEntity", pOwner);
                break;
            }
            case 7: //rocket launcher //DO NOT CALL THIS IN THIS CLASS
            {
                this.projectileEntity = SpawnEntityFromTable("prop_dynamic", {targetname = this.projectileName, model = "models/blop4dead/npc_rpgprojectile.mdl", origin = pOrigin, solid = 0});
                this.projectileSmoke = SpawnEntityFromTable("info_particle_system", {targetname = this.projectileName + "_smoke", effect_name = "RPG_Parent", start_active = 0});
                DoEntFire(this.projectileName + "_smoke", "SetParent", this.projectileName, 0.01, null, null);
                DoEntFire(this.projectileName + "_smoke", "SetParentAttachment", "smoke", 0.03, null, null);
                DoEntFire(this.projectileName + "_smoke", "Start", "", 0.04, null, null);
                NetProps.SetPropEntity(this.projectileEntity, "m_hOwnerEntity", pOwner);
                break;
            }
            case 8: //MIN-NUKE LAUNCHER //DO NOT CALL THIS IN THIS CLASS
            {
                this.projectileEntity = SpawnEntityFromTable("prop_dynamic", {targetname = this.projectileName, model = "models/blop4dead/npc_rpgprojectile.mdl", origin = pOrigin, solid = 0, rendercolor = "255 125 39"});
                this.projectileSmoke = SpawnEntityFromTable("info_particle_system", {targetname = this.projectileName + "_smoke", effect_name = "RPG_Parent", start_active = 0});
                DoEntFire(this.projectileName + "_smoke", "SetParent", this.projectileName, 0.01, null, null);
                DoEntFire(this.projectileName + "_smoke", "SetParentAttachment", "smoke", 0.03, null, null);
                DoEntFire(this.projectileName + "_smoke", "Start", "", 0.04, null, null);
                NetProps.SetPropEntity(this.projectileEntity, "m_hOwnerEntity", pOwner);
                DoEntFire("!self", "ignite", "", 0, this.projectileEntity, this.projectileEntity);
                break;
            }
        }
        
        if (this.projectileEntity)
        {
            // 1. Calculate the offset starting FROM the NPC's origin
            local spawnPos = pOwner.GetOrigin() + (pOwner.GetForwardVector() * 32) + Vector(0, 0, 50);
            
            this.projectileEntity.SetOrigin(spawnPos);

            // 2. Fire and Owner setup
            DoEntFire("!self", "ignite", "", 0, this.projectileEntity, this.projectileEntity);
            NetProps.SetPropEntity(this.projectileEntity, "m_hOwnerEntity", pOwner);

            // 3. Launch physics (Velocity)
            // Aim toward the target's origin if it exists, otherwise just forward
            local aimDir = pTarget.GetOrigin() - spawnPos;
            aimDir.Norm();
            
            local launchVec = (aimDir * 900) + Vector(0, 0, 200); // Forward + Upward arc
            this.projectileEntity.ApplyAbsVelocityImpulse(launchVec);
        }
    }

    function TriggerProjectile()
    {
        switch(this.projectileType)
        {
            case 5: //grenade launcher
            {
                TriggerGrenadeExplosion(this.projectileEntity.GetOrigin(), 250, 400, this.projectileTeam);
                return 10;
                break;
            }
            case 6: //molotov
            {
                TriggerMolotovExplosion(this.projectileOwner, this.projectileEntity);
                return 10;
                break;
            }
            case 7: //rocket launcher
            {
                TriggerGrenadeExplosion(this.projectileEntity.GetOrigin(), 400, 450, this.projectileTeam);
                return 10;
                break;
            }
            case 8: //MINI-NUKE LAUNCHER
            {
                TriggerNuclearExplosion(this.projectileEntity.GetOrigin(), 1500, 1500, this.projectileTeam, "explosion_huge");
                return 10;
                break;
            }
        }
    }

    function TriggerNuclearExplosion(iorigin, rad, damage, team, particle)
    {
        local explodeEffectEnt = SpawnEntityFromTable("info_particle_system", {
        targetname = this.projectileName + "_effect",
        effect_name = particle,
        angles = Vector(-90, 0, 0),
        origin = iorigin
        })

        local victims = [];
        local ent = null;

        //2 = survivor team, 3 = infected team
        
        while (ent = Entities.FindInSphere(ent, iorigin, rad))
        {
            if (ent && ent.IsValid())
            {
                local cls = ent.GetClassname();
                
                // Get the team via NetProps (2 = Survivor, 3 = Infected)
                local entTeam = NetProps.GetPropInt(ent, "m_iTeamNum");

                local shouldAdd = false;

            
                if (team == 1) //friendly
                {
                    // Hit anything not on our team, or common infected (who are often team 0)
                    if (entTeam != 2|| cls == "infected" || cls == "witch") 
                        shouldAdd = true;
                }
                // infected team projectile logic
                else if (team == 2) //hostile
                {
                    if (entTeam == 2) shouldAdd = true;
                }
                else
                {
                    shouldAdd = true;
                }

                if (shouldAdd) victims.push(ent);
            }
        }

        foreach(victim in victims) 
        {
            local dist = (iorigin - victim.GetOrigin()).Length();
            if (dist <= rad)
            {
                victim.TakeDamage(damage, 72, this.projectileOwner); //burn + explode
                //victim.TakeDamage(damage * 0.01, 8, this.projectileOwner);
                if(victim.GetClassname() == "prop_physics")
                {
                    victim.ApplyAbsVelocityImpulse((victim.GetCenter() - iorigin) + Vector(0, 0, 100))
                }
            }
        }

        //clean this fucker
        DoEntFire("!self", "Start", "", 0.01, explodeEffectEnt, explodeEffectEnt);
        DoEntFire("!self", "Kill", "", 15.0, explodeEffectEnt, explodeEffectEnt);
        EmitAmbientSoundOn("sfx/explosions/megaexplosion01.mp3", 10, 0, 100, explodeEffectEnt);

        local player = null;
        while (player = Entities.FindByClassname(player, "player")) {
            if (player.IsValid()) {
                // White out for 1.5 seconds if they are in the blast zone
                ScreenFade(player, 255, 255, 255, 255, 2, 0.1, 1);
            }
        }   
        
        if (this.projectileEntity && this.projectileEntity.IsValid())
            BroadcastNPCExplosion(iorigin, rad);
            AddThinkToEnt(this.projectileEntity, null);
            this.projectileEntity.Kill();
    }

    function TriggerMolotovExplosion(ent, target)
	{
		DropFire(target.GetOrigin())
		for(local zombienearby; zombienearby = Entities.FindByClassnameWithin(zombienearby, "molotov_projectile", target.GetOrigin(), 150); )
		{
			NetProps.SetPropEntity(zombienearby, "m_hOwnerEntity", ent);
									
		}
        BroadcastInferno(this.projectileEntity.GetOrigin(), 500);
        this.projectileEntity.Kill();
	    EmitSoundOn("Glass.Break", target);		
	}

    function TriggerGrenadeExplosion(iorigin, rad, damage, team)
    {
        local explodeEffectEnt = SpawnEntityFromTable("env_explosion", {
        targetname = this.projectileName + "_effect",
        spawnflags = 3,
        rendermode = 5,
        origin = iorigin
        })

        local victims = [];
        local ent = null;
        
        while (ent = Entities.FindInSphere(ent, iorigin, rad))
        {
            if (ent && ent.IsValid())
            {
                local cls = ent.GetClassname();
                
                // Get the team via NetProps (2 = Survivor, 3 = Infected)
                local entTeam = NetProps.GetPropInt(ent, "m_iTeamNum");

                local shouldAdd = false;

                if (team == 1) //friendly
                {
                    // Hit anything not on our team, or common infected (who are often team 0)
                    if (entTeam != 2 || cls == "infected" || cls == "witch") 
                        shouldAdd = true;
                }
                // infected team projectile logic
                else if (team == 2) //hostile
                {
                    if (entTeam == 2) shouldAdd = true;
                }
                else
                {
                    shouldAdd = true;
                }

                if (shouldAdd) victims.push(ent);
            }
        }

        foreach(victim in victims) 
        {
            local dist = (iorigin - victim.GetOrigin()).Length();
            if (dist <= rad)
            {
                victim.TakeDamage(damage, 64, this.projectileOwner);
                //printl("damage dealt to: " + victim.GetClassame());
            }
        }

        //clean this fucker
        DoEntFire("!self", "Explode", "", 0.01, explodeEffectEnt, explodeEffectEnt);
        DoEntFire("!self", "Kill", "", 2.0, explodeEffectEnt, explodeEffectEnt);
        EmitSoundOn("GrenadeLauncher.Explode", explodeEffectEnt);       
        
        if (this.projectileEntity && this.projectileEntity.IsValid())
            BroadcastNPCExplosion(iorigin, rad);
            AddThinkToEnt(this.projectileEntity, null);
            this.projectileEntity.Kill();
    }

    function ProjectileThink()
    {   
        if (this.projectileLifeTime <= 0)
        {
            TriggerProjectile();
        }

        local closestinfectedVictim = Entities.FindByClassnameNearest("infected", this.projectileEntity.GetOrigin(), 35.0);
        local closestPlayerVictim = Entities.FindByClassnameNearest("player", this.projectileEntity.GetOrigin(), 35.0);

        if (closestinfectedVictim != null || closestPlayerVictim != null)
        {
            TriggerProjectile();
        }

        this.projectileLifeTime -= 0.07;
	    return 0.07;
    }
}

class ::NPCProjectileRocket extends NPCProjectile
{
    projectileSpeed = 50;
    projectileForward = null;

    constructor(pType, pName, pOrigin, pTarget, pOwner, pTeam, pAngles, pSpeed)
    {
        base.constructor(pType, pName, pOrigin, pTarget, pOwner, pTeam)
        this.projectileSpeed = pSpeed;
        this.projectileEntity.SetAngles(pAngles);
        this.projectileForward = pAngles.Forward();
    }

    function ProjectileThink()
    {   
        if (!this.projectileEntity || !this.projectileEntity.IsValid()) return null;

        local currentPos = this.projectileEntity.GetOrigin();
        local nextPos = currentPos + (this.projectileForward * this.projectileSpeed);

        // 1. COLLISION TRACE
        local traceTable = {
            start = currentPos,
            end = nextPos,
            mask = DirectorScript.TRACE_MASK_SHOT,
            ignore = this.projectileEntity
        };

        TraceLine(traceTable);

        if (traceTable.hit)
        {
            TriggerProjectile()
            return 10;
        }

        this.projectileEntity.SetOrigin(nextPos);

        this.projectileLifeTime -= 0.03;
        if (this.projectileLifeTime <= 0) {
            TriggerProjectile();
            return 10;
        }

        return 0.03;
    }
}

//====================================================================================================================================//
//============================================CUSTOM EVENTS AND ONGAMEEVENTS==========================================================//
//====================================================================================================================================//
::BroadcastNPCExplosion <- function(_origin, _radius)
{
    local ent = null;
    while (ent = Entities.FindByClassname(ent, "prop_dynamic"))
    {
        // 1. Basic entity safety
        if (ent && ent.IsValid())
        {
            local scope = ent.GetScriptScope();
            // 2. Check if it's one of your NPCs
            if (scope && ("Controller" in scope))
            {
                local controller = scope.Controller;
                local dist = (_origin - ent.GetOrigin()).Length();

                if (dist <= _radius)
                {
                    // 3. SAFETY GATE: Check if the function exists before calling it
                    if ("GetStunned" in controller)
                    {
                        controller.GetStunned(); 
                    }
                    else
                    {
                        printl("[NPC ERROR] Stun() function is missing from the Controller!");
                    }
                }
            }
        }
    }
}

::BroadcastInferno <- function(_origin, _radius)
{
    local ent = null;
    while (ent = Entities.FindByClassname(ent, "prop_dynamic"))
    {
        // 1. Basic entity safety
        if (ent && ent.IsValid())
        {
            local scope = ent.GetScriptScope();
            // 2. Check if it's one of your NPCs
            if (scope && ("Controller" in scope))
            {
                local controller = scope.Controller;
                local dist = (_origin - ent.GetOrigin()).Length();

                if (dist <= _radius)
                {
                    // 3. SAFETY GATE: Check if the function exists before calling it
                    if ("RunAway" in controller)
                    {
                        controller.RunAway(); 
                    }
                    else
                    {
                        printl("[NPC ERROR] RunAway() function is missing from the Controller!");
                    }
                }
            }
        }
    }
}

function OnGameEvent_player_death(params) 
{
    // L4D2 player_death params use 'userid' for the victim
    // 'victimname' will be "Boomer", "Smoker", etc.
    if ("victimname" in params)
    {
        if (params.victimname == "Boomer")
        {
            // Extract coordinates from the params table
            local pos = Vector(params.victim_x, params.victim_y, params.victim_z);
            
            printl("[NPC EVENT] Boomer exploded! Sending broadcast...");
            
            // Trigger your broadcast
            // Note: Boomer explosion radius is usually around 250 in-game
            BroadcastNPCExplosion(pos, 100);
        }
    }
}

__CollectGameEventCallbacks(this)

//====================================================================================================================================//
//============================================SPAWNING AND DEBUG RELATED FUNCTIONS====================================================//
//====================================================================================================================================//

::ClearAllNPCS <- function()
{
    local npc = null;

    ::NONARMEDNPC_COUNT = 0;
    ::FIREARMNPC_COUNT = 0;
    ::PROJECTILENPC_COUNT = 0;
    ::MELEENPC_COUNT = 0;

    while (npc = Entities.FindByName(npc, "NPCpedestrian*"))
    {
        npc.Kill()
        ::globalNPCCount--;
    }
}

::SpawnNPC <- function(npcClass, spawnPos, health, modelID, gender, voiceID, type, affiliation, aggression, canTaunt, totalBody, skin, npcRange, npcWeapon, dmgMultiplier = 1.0)
{
    if(::globalNPCCount >= ::globalNPCLimit) //if we are reached the limit abort it
    {
        printl("[NPC] NPC LIMIT IS REACHED!!!!!! ABORTED.")
        return;
    }
    // Create the Instance
    local taunt = true;
    if (canTaunt == 0)
    {
        taunt = false;
    }

    local newPed = null;
    local ent = null;

    switch(npcClass)
    {
        case 1: //PEDESTRIAN
        {
            newPed = Pedestrian(spawnPos, health, maleModels[modelID], gender, maleVoiceSets[voiceID], type, affiliation, aggression, taunt, totalBody, skin, npcRange);
            ent = newPed.npcModel;
            break;
        }
        case 2: //ARMED
        {
            if(npcWeapon > 4)
            {
                printl("[NPC] YOU CANNOT SPAWN PROJECTILE WEAPON IN THIS NPC CLASS");
                return;
            }
            newPed = PedArmed(spawnPos, health, maleModels[modelID], gender, maleVoiceSets[voiceID], type, affiliation, aggression, taunt, totalBody, skin, npcRange, npcWeapon);
            ent = newPed.npcModel;
            break;
        }
        case 3: //PROJECTILE (No nukes)
        {
            if(npcWeapon <= 4)
            {
                printl("[NPC] YOU CANNOT SPAWN FIREARM WEAPON IN THIS NPC CLASS");
                return;
            }
            newPed = PedProjectile(spawnPos, health, maleModels[modelID], gender, maleVoiceSets[voiceID], type, affiliation, aggression, taunt, totalBody, skin, npcRange, npcWeapon);
            ent = newPed.npcModel;
            break;
        }
        case 4: //PROJECTILE (Nuke)
        {
            newPed = PedProjectile(spawnPos, health, maleModels[modelID], gender, maleVoiceSets[voiceID], type, affiliation, aggression, taunt, totalBody, skin, npcRange, 8);
            ent = newPed.npcModel;
            break;
        }
        case 5: //MELEE
        {
            newPed = PedMelee(spawnPos, health, maleModels[modelID], gender, maleVoiceSets[voiceID], type, affiliation, aggression, taunt, totalBody, skin, npcRange, npcWeapon, dmgMultiplier);
            ent = newPed.npcModel;
            break;
        }
    }

    if (newPed == null) return;

    BindNPCToEntity(ent, newPed);
    ent.ValidateScriptScope();
    local scope = ent.GetScriptScope();
    scope.Think <- function() 
    {
        return this.Controller.NPCThink();
    };

    AddThinkToEnt(ent, "Think");
}

::SpawnNPCFromRandomLocation <- function(npcClass, health, modelID, gender, voiceID, type, affiliation, aggression, canTaunt, totalBody, skin, npcRange, npcWeapon, dmgMultiplier = 1.0)
{
    local point = null;
    local pointList = [];
    while (point = Entities.FindByName(point, "npc_randomspawnpoint"))
    {
        pointList.push(point);
    }

    if (pointList.len() == 0) return;

    local maxTries = 10;
    local finalOrigin = null;

    for (local i = 0; i < maxTries; i++)
    {
        local testPoint = pointList[RandomInt(0, pointList.len() - 1)];
        local testPos = testPoint.GetOrigin();
        local isOccupied = false;

        local nearbyEnt = null;
        while (nearbyEnt = Entities.FindInSphere(nearbyEnt, testPos, 100.0))
        {
            local cName = nearbyEnt.GetClassname();
            
            // check for Players, NPCs (prop_dynamic), Physics objects, or Infected
            if (cName == "player" || cName == "prop_dynamic" || cName == "prop_physics" || cName == "infected")
            {
                isOccupied = true;
                break; // Exit the 'while' loop, this spot is bad
            }
        }

        if (!isOccupied)
        {
            finalOrigin = testPos;
            break; 
        }
        
        finalOrigin = testPos;
    }

    SpawnNPC(npcClass, finalOrigin, health, modelID, gender, voiceID, type, affiliation, aggression, canTaunt, totalBody, skin, npcRange, npcWeapon, dmgMultiplier);
}

function DebugCreatePath()
{
    local startArea = NavMesh.GetNavArea(Vector(4, 3597, 8), 100);
    local endArea = NavMesh.GetNavArea(Vector(1800, -1944, 0), 100);
    DebugDrawBox(endArea.GetCenter(), Vector(-10, -10, -10), Vector(10, 10, 10), 0, 255, 0, 255, 5.0)
    DebugDrawBox(startArea.GetCenter(), Vector(-10, -10, -10), Vector(10, 10, 10), 255, 0, 0, 255, 5.0)

    if (startArea && endArea)
    {
        // 1. Create the container array first
        local myPathArray = {}; 

        // 2. Build the path
        if (NavMesh.NavAreaBuildPath(startArea, endArea, endArea.GetCenter(), 99999.0, 0, false))
        {
            NavMesh.GetNavAreasFromBuildPath(startArea, endArea, endArea.GetCenter(), 99999.0, 0, false, myPathArray);
            
            printl("DEBUG: Found " + myPathArray.len() + " areas.");
            
            // Visual check: Draw boxes at every point found in the path
            foreach(index, area in myPathArray)
            {
                DebugDrawBox(area.GetCenter(), Vector(-5, -5, -5), Vector(5, 5, 5), 0, 255, 255, 255, 5.0);
                printl("INDEX: " + index);
                printl("AREA: " + area);
                printl("AREA ORIGIN: " + area.GetCenter());
            }
        }
        else
        {
            printl("DEBUG: Path build failed even with 0 flags.");
        }
    }
}

function DebugForceZombiesAttackNPCs()
{
    local zombies = [];
    local availableTargets = [];
    local ent = null;

    // 1. Gather ALL zombies and ALL NPC Hitboxes in ONE pass through the entity list
    while (ent = Entities.FindByClassname(ent, "*"))
    {
        if (!ent.IsValid()) continue;

        local cls = ent.GetClassname();

        // Check for Common Infected or Special Infected players
        if (cls == "infected")
        {
            zombies.push(ent);
        }
        else if (cls == "player")
        {
            //ZombieType 9 is Survivor.
            if (ent.GetZombieType() != 9)
            {
                zombies.push(ent);
            }
        }
        // Check for your NPC hitboxes
        else if (cls == "prop_dynamic")
        {
            if (ent.GetModelName() == "models/blop4dead/npchitbox.mdl")
            {
                availableTargets.push(ent);
            }
        }
    }

    // 2. If we have no targets or no zombies, stop here
    if (zombies.len() == 0 || availableTargets.len() == 0)
    {
        printl("DEBUG: No zombies or no NPC targets found.");
        return;
    }

    // 3. Command the bots
    foreach (zombie in zombies)
    {
        // Pick a random hitbox from our pre-made list
        local randomTarget = availableTargets[RandomInt(0, availableTargets.len() - 1)];

        local commands =
        {
            cmd = DirectorScript.BOT_CMD_ATTACK,
            target = randomTarget,
            bot = zombie
        };

        CommandABot(commands);
    }
    
    printl("DEBUG: Commanded " + zombies.len() + " zombies to attack NPCs.");
}

function OnGameEvent_player_say( params )
{
    if("userid" in params && "text" in params)
    {
    	local player = GetPlayerFromUserID(params.userid)
    	local whatsay = params.text.toupper()
    
        if(player == GetListenServerHost() && Convars.GetStr("sv_cheats") == "1")
		{
			switch(whatsay)
            {
                case "BRINGOUTTHENUKES": 
                {
                    local hostOrigin = player.GetOrigin();
                    SpawnNPCFromRandomLocation(4, 100, 1, 0, 0, 0, 2, 1.0, 1, -2, RandomInt(0, 3), 4000, 8)
                    break;
                }
                case "ZOMBIEMAGNET":
                {
                    DebugForceZombiesAttackNPCs();
                    break;
                }
                case "STARTCONVERSATION":
                {
                    local fuckhead1 = Entities.FindByName(null, "NPCpedestrian1");
                    local fuckhead2 = Entities.FindByName(null, "NPCpedestrian2");
                    local fuckhead1Scope = fuckhead1.GetScriptScope();
                    fuckhead1Scope.Controller.StartConversationWithNPC(fuckhead2);
                    break;
                }
                case "NPCPARTY":
                {
                    for(local i = 0; i <= 20; i++)
                    {
                        if(::globalNPCCount >= ::globalNPCLimit)
                        {
                            printl("NPC limit reached, not longer spawning npcs")
                            return;
                        }
                        switch(RandomInt(1, 3))
                        {
                            case 1:
                            {
                                SpawnNPCFromRandomLocation(1, RandomInt(50, 100), 1, 0, 0, 0, 1, RandomFloat(0.0, 1.0), 1, -1, RandomInt(0, 3), RandomInt(500, 2000), 1);
                                break;
                            }
                            case 2:
                            {
                                SpawnNPCFromRandomLocation(2, RandomInt(50, 100), 1, 0, 0, 0, 1, RandomFloat(0.5, 1.0), 1, -1, RandomInt(0, 3), RandomInt(500, 2000), RandomInt(1, 4));
                                break;
                            }
                            case 3:
                            {
                                SpawnNPCFromRandomLocation(3, RandomInt(50, 100), 1, 0, 0, 0, 1, RandomFloat(0.6, 1.0), 1, -1, RandomInt(0, 3), RandomInt(500, 2000), RandomInt(5, 7));
                                break;
                            }
                        }
                    }
                    break;
                }
                case "DEATHWISH":
                {
                    for(local i = 0; i <= 10; i++)
                    {
                        if(::globalNPCCount >= ::globalNPCLimit)
                        {
                            printl("NPC limit reached, not longer spawning npcs")
                            return;
                        }
                        switch(RandomInt(1, 2))
                        {
                            case 1:
                            {
                                SpawnNPCFromRandomLocation(2, RandomInt(50, 100), 1, 0, 0, 0, 2, RandomFloat(0.5, 1.0), 1, 94, RandomInt(0, 3), RandomInt(500, 2000), RandomInt(1, 4));
                                break;
                            }
                            case 2:
                            {
                                SpawnNPCFromRandomLocation(3, RandomInt(50, 100), 1, 0, 0, 0, 2, RandomFloat(0.6, 1.0), 1, 94, RandomInt(0, 3), RandomInt(500, 2000), RandomInt(5, 7));
                                break;
                            }
                        }
                    }
                    break;
                }
                case "FUCKYOU":
                {
                    local npc = null;
                    while (npc = Entities.FindByClassname(npc, "prop_dynamic"))
                    {
                        if (npc.ValidateScriptScope())
                        {
                            local npcScope = npc.GetScriptScope();

                            if ("Controller" in npcScope)
                            {
                                if("SwitchTeam" in npcScope.Controller)
                                {
                                    printl("[CHEAT] Found NPC! Switching Team...");
                                    npcScope.Controller.SwitchTeam(2);
                                }
                            }
                        }
                    }
                    break;
                }
                case "HAVEMERCY":
                {
                    local npc = null;
                    while (npc = Entities.FindByClassname(npc, "prop_dynamic"))
                    {
                        if (npc.ValidateScriptScope())
                        {
                            local npcScope = npc.GetScriptScope();
                            
                            if ("Controller" in npcScope)
                            {
                                if("SwitchTeam" in npcScope.Controller)
                                {
                                    printl("[CHEAT] Found NPC! Switching Team...");
                                    npcScope.Controller.SwitchTeam(1);
                                }
                            }
                        }
                    }
                    break;
                }
                case "ARMEDMANIACS":
                {
                    for(local i = 0; i <= 10; i++)
                    {
                        if(::globalNPCCount >= ::globalNPCLimit)
                        {
                            printl("NPC limit reached, not longer spawning npcs")
                            return;
                        }
                        switch(RandomInt(1, 2))
                        {
                            case 1:
                            {
                                SpawnNPCFromRandomLocation(2, RandomInt(50, 100), 1, 0, 0, 0, 1, 1.0, 1, -1, RandomInt(0, 3), RandomInt(500, 2000), RandomInt(1, 4));
                                break;
                            }
                            case 2:
                            {
                                SpawnNPCFromRandomLocation(3, RandomInt(50, 100), 2, 0, 0, 0, 1, 1.0, 1, -2, RandomInt(0, 3), RandomInt(500, 2000), RandomInt(5, 7));
                                break;
                            }
                        }
                    }
                    break;
                }
                case "MELEEFIGHT":
                {
                    for(local i = 0; i <= 10; i++)
                    {
                        if(::globalNPCCount >= ::globalNPCLimit)
                        {
                            printl("NPC limit reached, not longer spawning npcs")
                            return;
                        }
                        switch(RandomInt(1, 2))
                        {
                            case 1:
                            {
                                SpawnNPCFromRandomLocation(5, 250, 1, 0, 0, 0, 1, 0.7, 1, -1, RandomInt(0, 3), 1200, RandomInt(0, 10), 1.1);
                                break;
                            }
                            case 2:
                            {
                                SpawnNPCFromRandomLocation(5, 250, 2, 0, 0, 0, 1, 0.7, 1, -1, RandomInt(0, 3), 1200, RandomInt(0, 10), 2.0);
                                break;
                            }
                        }
                    }
                    break;
                }
                case "GETYOURASSMOVING":
                {
                    local ent = null;
                    while (ent = Entities.FindByClassname(ent, "prop_dynamic"))
                    {
                        if (ent.ValidateScriptScope())
                        {
                            local scope = ent.GetScriptScope()
                            if ("Controller" in scope)
                            {
                                scope.Controller.GoToPathCustom(Vector(4, 3597, 8))
                            }
                        }
                    }
                    
                    break;
                }
                case "STATEOFEMERGENCY":
                {
                    ChaosMode(1, 0);
                    DoEntFire("director", "BeginScript", "c1_gunshop_onslaught", 0.00, null, null);
                    //Director.PlayMegaMobWarningSounds();
                    break;
                }
                case "PLEASECALMDOWN":
                {
                    ChaosMode(0, 0);
                    DoEntFire("director", "EndScript", "", 0.00, null, null);
                    break;
                }
                case "BACKMEUP":
                {
                    local ent = null;
                    while (ent = Entities.FindByClassname(ent, "prop_dynamic"))
                    {
                        if (ent.ValidateScriptScope())
                        {
                            local scope = ent.GetScriptScope()
                            if ("Controller" in scope)
                            {
                                scope.Controller.Assist(GetListenServerHost());
                            }
                        }
                    }
                    break;
                }
                case "DONTBEACOWARD":
                {
                    local ent = null;
                    while (ent = Entities.FindByClassname(ent, "prop_dynamic"))
                    {
                        if (ent.ValidateScriptScope())
                        {
                            local scope = ent.GetScriptScope()
                            if ("Controller" in scope)
                            {
                                scope.Controller.npcAggression = 1.0;
                            }
                        }
                    }
                    printl("NPCs are now fully aggressive!")
                    break;
                }
            }
		}
    }
}