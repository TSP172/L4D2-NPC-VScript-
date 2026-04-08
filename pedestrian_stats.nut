//========================================================================================================//
//===================================PEDESTRIAN STATS=====================================================//
//========================================================================================================//
printl("[PEDESTRIAN NPC] Stats Successfully Loaded!")


//============================================VOICE============================================================//
::DIALOGUE_TYPE <- {
    GREET = 1,
    QUESTION = 2,
    INSULT = 3,
    CONFUSED = 4,
    RANDOM = 5
};

local DefaultDialogue = {
    dialogueMap = { 
        [::DIALOGUE_TYPE.GREET] = [1], 
        [::DIALOGUE_TYPE.QUESTION] = [1], 
        [::DIALOGUE_TYPE.RANDOM] = [1], 
        [::DIALOGUE_TYPE.INSULT] = [1], 
        [::DIALOGUE_TYPE.CONFUSED] = [1] 
    },
    responseTable = { 
        [::DIALOGUE_TYPE.GREET] = [::DIALOGUE_TYPE.GREET, ::DIALOGUE_TYPE.CONFUSED], 
        [::DIALOGUE_TYPE.QUESTION] = [::DIALOGUE_TYPE.RANDOM], 
        [::DIALOGUE_TYPE.INSULT] = [::DIALOGUE_TYPE.CONFUSED], 
        [::DIALOGUE_TYPE.CONFUSED] = [::DIALOGUE_TYPE.RANDOM] 
    }
};

::maleVoiceSets <- [
    { // 0: Generic Male (POSTAL 2)
        soundDirectory = "blop4deadnpcs/generic/",
        totalIdleSounds = 29, totalLaughSounds = 2, totalCombatSounds = 43, totalTauntSounds = 30, 
        totalHurtSounds = 9, totalScreamSounds = 5, totalDialogueStartSounds = 30, 
        totalDialogueRespondSounds = 34, totalDialogueEndSounds = 10, totalConfusionSounds = 5, 
        totalMiscActionSounds = 10, totalRetreatSounds = 4, totalAssistSounds = 8, totalNegativeSounds = 1, 
        totalVictorySounds = 0, totalSpotSounds = 4, totalDeathSounds = 9,
        
        dialogueMap = {
            [::DIALOGUE_TYPE.GREET]    = [14, 15, 16, 17, 18, 29, 30],
            [::DIALOGUE_TYPE.QUESTION] = [6, 7, 8, 11, 13, 19, 20, 21, 24, 25],
            [::DIALOGUE_TYPE.INSULT]   = [23],
            [::DIALOGUE_TYPE.CONFUSED] = [22],
            [::DIALOGUE_TYPE.RANDOM]   = [1, 4, 5, 9, 10, 12, 27, 28]
        },
        responseTable = {
            [::DIALOGUE_TYPE.GREET]    = [::DIALOGUE_TYPE.GREET, ::DIALOGUE_TYPE.CONFUSED],
            [::DIALOGUE_TYPE.QUESTION] = [::DIALOGUE_TYPE.RANDOM, ::DIALOGUE_TYPE.GREET],
            [::DIALOGUE_TYPE.INSULT]   = [::DIALOGUE_TYPE.CONFUSED, ::DIALOGUE_TYPE.INSULT],
            [::DIALOGUE_TYPE.CONFUSED] = [::DIALOGUE_TYPE.QUESTION, ::DIALOGUE_TYPE.RANDOM]
        }
    },
    { // 1: Club Penguin
        soundDirectory = "blop4deadnpcs/penguin/male/",
        totalIdleSounds = 5, totalLaughSounds = 2, totalCombatSounds = 3, 
        totalTauntSounds = 4, totalHurtSounds = 3, totalScreamSounds = 3, totalDialogueStartSounds = 2,
        dialogueMap = DefaultDialogue.dialogueMap,
        responseTable = DefaultDialogue.responseTable
    },
    { // 2: Badger 1 (Bucky from Bully game)
        soundDirectory = "blop4deadnpcs/badger1/",
        totalIdleSounds = 15, totalLaughSounds = 2, totalCombatSounds = 26, totalTauntSounds = 10, 
        totalHurtSounds = 4, totalScreamSounds = 10, totalDialogueStartSounds = 6, 
        totalDialogueRespondSounds = 13, totalDialogueEndSounds = 7, totalConfusionSounds = 2, 
        totalMiscActionSounds = 10, totalRetreatSounds = 6, totalAssistSounds = 5, totalNegativeSounds = 8, 
        totalVictorySounds = 6, totalSpotSounds = 0, totalDeathSounds = 9,
        
        dialogueMap = {
            [::DIALOGUE_TYPE.GREET]    = [9, 10],
            [::DIALOGUE_TYPE.QUESTION] = [7, 8],
            [::DIALOGUE_TYPE.INSULT]   = [6], 
            [::DIALOGUE_TYPE.CONFUSED] = [1, 11, 12, 13],
            [::DIALOGUE_TYPE.RANDOM]   = [2, 3, 4, 5] 
        },
        responseTable = DefaultDialogue.responseTable
    }
];
femaleVoiceSets <- [] //currently I have no plans adding female peds but I will leave this here for future use.

::maleVoiceSets[0].dialogueMap <- {
    [::DIALOGUE_TYPE.GREET]    = [14, 15, 16, 17, 18, 29, 30],
    [::DIALOGUE_TYPE.QUESTION] = [6, 7, 8, 11, 13, 19, 20, 21, 24, 25],
    [::DIALOGUE_TYPE.INSULT] = [23],
    [::DIALOGUE_TYPE.CONFUSED] = [22],
    [::DIALOGUE_TYPE.RANDOM] = [1, 4, 5, 9, 10, 12, 27, 28]
};

//============================================BODYGROUP============================================================//

function CalBodyVal_Penguin(hat, neck, face, clothing)
{
    local meshSize = 1; //just one mesh
    local hatSize = 19;  // Total items in Hat block
    local neckSize = 4; // Total items in Neck block
    local faceSize = 3; // Total items in Face block

    local val = 0;
    //val += 0;                      // Mesh (always 0)
    val += (hat * 1);              // Hat Index
    val += (neck * 19);            // Neck Index * HatSize
    val += (face * 19 * 4);        // Face Index * HatSize * NeckSize
    val += (clothing * 19 * 4 * 3); // Clothing Index * HatSize * NeckSize * FaceSize
    
    return val;
}

maleModels <- 
[
    { //npctest (OBSOLETE)
        model = "models/blop4dead/npctest.mdl"
        bodygroupSets =  0 //we never gonna use npctest model anyway so.
    },
    
    { //Penguin 01
        model = "models/blop4dead/penguin.mdl"
        bodygroupSets = 
        [
            //FORMULA = (MeshID = 0) + (HatID * MeshSize) + (NeckID * MeshSize * HatSize) + (FaceID * MeshSize * HatSize * NeckSize) + (ClotheID * MeshSize * HatSize * NeckSize * FaceSize)
            //ID = Choosen Cosmetic | SIZE = How much cosmetics in one group
            [0, 1, 4, 5, 7, 11, 13, 15, 16], //civilians
            [CalBodyVal_Penguin(18,0,0,0), CalBodyVal_Penguin(18,3,0,0), CalBodyVal_Penguin(18,0,1,0)], //police officers
            [CalBodyVal_Penguin(12,0,0,0), CalBodyVal_Penguin(17,0,0,0), CalBodyVal_Penguin(17,0,1,0)], //soldier and sergants
            [CalBodyVal_Penguin(15, 0, 0, 5), 15], //golf guy
            [CalBodyVal_Penguin(10, 0, 0, 2), 10], //Chef
            [CalBodyVal_Penguin(16, 0, 1, 4), CalBodyVal_Penguin(16, 0, 0, 4)], //tourist
            [CalBodyVal_Penguin(14, 0, 0, 3), CalBodyVal_Penguin(0, 0, 0, 3), 14], //marching band
            [CalBodyVal_Penguin(7, 0, 1, 5), CalBodyVal_Penguin(11, 0, 1, 5), CalBodyVal_Penguin(11, 0, 1, 0)], //rich class
            [CalBodyVal_Penguin(9, 1, 0, 0), 9], //russian / winter specialist
            [CalBodyVal_Penguin(4, 0, 2, 5), CalBodyVal_Penguin(4, 0, 2, 0), CalBodyVal_Penguin(4, 0, 2, 1)], //90s Kid
            [CalBodyVal_Penguin(3, 3, 0, 5), 3], //viking
            [CalBodyVal_Penguin(2, 2, 0, 4)] //party animal.
        ]
    },

    { //Penguin 02
        model = "models/blop4dead/penguin02.mdl"
        bodygroupSets = 
        [
            //FORMULA = (MeshID = 0) + (HatID * MeshSize) + (NeckID * MeshSize * HatSize) + (FaceID * MeshSize * HatSize * NeckSize) + (ClotheID * MeshSize * HatSize * NeckSize * FaceSize)
            //ID = Choosen Cosmetic | SIZE = How much cosmetics in one group
            [2, 56], //construction worker
            [0, 1, 2, 3, 6, 8, 10, 14, 15], //civilians
            [16], //pirate
            [878] //saint patrick's day dude
        ]
    },

    { //Badger
        model = "models/blop4dead/badger.mdl"
        bodygroupSets = 0 //yet to be added.
    }
];
femaleModels <- []; 

PrecacheModel("models/blop4dead/npchitbox.mdl");
PrecacheModel("models/blop4dead/npc_pistol.mdl");
PrecacheModel("models/blop4dead/npc_shotgun.mdl");
PrecacheModel("models/blop4dead/npc_rifle.mdl");
PrecacheModel("models/blop4dead/npc_sniperrifle.mdl");
PrecacheModel("models/blop4dead/npc_grenadelauncher.mdl");
PrecacheModel("models/blop4dead/npc_molotov.mdl");
PrecacheModel("models/blop4dead/npc_rocketlauncher.mdl");
PrecacheModel("models/blop4dead/npc_rpgprojectile.mdl");
PrecacheModel("models/blop4dead/npc_fryingpan.mdl");
PrecacheModel("models/blop4dead/npc_katana.mdl");
PrecacheModel("models/blop4dead/npc_policebaton.mdl");
PrecacheModel("models/blop4dead/npc_protestsign.mdl");
PrecacheModel("models/blop4dead/npc_shovel.mdl");
PrecacheModel("models/blop4dead/npc_sledgehammer.mdl");
PrecacheModel("models/blop4dead/npc_sword.mdl");
PrecacheModel("models/blop4dead/npc_knife.mdl");
PrecacheModel("models/blop4dead/npc_baseballbat.mdl");
PrecacheModel("models/blop4dead/npc_axe.mdl");
PrecacheModel("models/blop4dead/npc_drink.mdl");
PrecacheModel("models/blop4dead/npc_cigar.mdl");
PrecacheModel("models/blop4dead/npc_phone.mdl");
PrecacheSound("cutscene/rpgshoot01.mp3");
PrecacheSound("sfx/weapons/mininukelaunchershoot.mp3");
PrecacheSound("sfx/explosions/megaexplosion01.mp3");

for (local i = 0; i < maleModels.len(); i++) 
{
    if ("model" in maleModels[i])
    {
        local modelPath = maleModels[i].model;
        
        if (!IsModelPrecached(modelPath))
        {
            PrecacheModel(modelPath);
        }
    }
}

function PrecacheVoiceSets(voiceSets) {
    local categories = {
        "idle": "totalIdleSounds", "laugh": "totalLaughSounds", "combat": "totalCombatSounds",
        "taunt": "totalTauntSounds", "hurt": "totalHurtSounds", "scream": "totalScreamSounds",
        "dialogue_start": "totalDialogueStartSounds", "dialogue_respond": "totalDialogueRespondSounds",
        "dialogue_end" : "totalDialogueEndSounds", "confusion" : "totalConfusionSounds",
        "miscaction" : "totalMiscActionSounds", "death" : "totalDeathSounds", "victory" : "totalVictorySounds",
        "retreat" : "totalRetreatSounds", "assist" : "totalAssistSounds", "negative" : "totalNegativeSounds",
        "spot" : "totalSpotSounds"
    };
    foreach (set in voiceSets) {
        foreach (prefix, tableKey in categories) {
            local count = (tableKey in set) ? set[tableKey] : 0;
            for (local i = 1; i <= count; i++) {
                PrecacheSound(set.soundDirectory + prefix + i + ".mp3");
            }
        }
    }
}
PrecacheVoiceSets(::maleVoiceSets);