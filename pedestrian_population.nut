//paramters as it follows://
/*
npcClass: 1 = Unarmed, 2 = Armed, 3 = Projectile, 4 = Nuclear Projectile, 5 = Melee.
health: total health of NPC
modelID: the model to use for the NPC.
gender: gender of NPC seems obsolete for now.
voiceID: the voice line set for the NPC.
type: doesn't actually do anything.
affiliation: 0 = neutral (works exactly as 2), 1 = friendly to survivors, 2 = hostile to survivors
aggression: 0 = literally coward, 0.5 = courage towards common infected, 0.7 = can assist npcs and survivors in combat 1 = don't scared of tanks at all.
canTaunt: seems obsolete right now the NPCs with either 0 or 1 can still taunt.
totalBody: the bodygroup set to use for the NPC, this is used to determine the clothing of the NPC.
skin: the skin to use for the NPC, if set to -1 it will be random.
npcRange: the range for the NPC to detect survivors and infected.
npcWeapon: the weapon for the NPC to use, if set to -1 it will be random based on the npcClass, doesn't work on unarmed npcs.
WEAPON CHOICES: 1 = PISTOL, 2 = RIFLE, 3 = SHOTGUN, 4 = SNIPER RIFLE, 5 = GRENADE LAUNCHER, 6 = MOLOTOV, 7 = ROCKET LAUNCHER, 8 = MINI NUKE LAUNCHER
MELEE CHOICES: 0 = FISTS, 1 = BASEBALLBAT, 2 = SWORD, 3 = KATANA, 4 = SHOVEL, 5 = PAN, 6 = SLEDGEHAMMER, 7 = BATON, 8 = AXE, 9 = KNIFE, 10 = SIGN
damageMultiplier: multiplies the damage of melee
*/

DEFAULT_POPULATION <- //Default Population (if the map doesn't match any of the below)
[
    [1, 100, 1, 0, 2, 0, 1, 0.5, 1, 0, -1, 1000, -1], //unarmed NPC, the most basic npc ever.
    [2, 150, 2, 0, 0, 0, 1, 0.8, 1, 94, -1, 1500, 1], //armed police officer, uses pistol
    [5, 100, 2, 0, 0, 0, 1, 1.0, 1, 94, -1, 750, 7, 1.5], //police officer with baton.
    [2, 120, 1, 0, 0, 0, 1, 0.8, 1, 100, -1, 1500, 2], //armed tourist, uses rifle
    [3, 200, 1, 0, 2, 0, 1, 1.0, 1, 12, -1, 2200, 7], //soldier, uses rocket launcher
    [3, 200, 1, 0, 2, 0, 1, 1.0, 1, 12, -1, 2200, 5], //soldier, uses grenade launcher
    [5, 85, 1, 0, 2, 0, 1, 0.6, 1, -2, -1, 750, -1, 1.5], //melee npc with random melee (penguin 1)
    [5, 85, 2, 0, 2, 0, 1, 0.6, 1, -2, -1, 750, -1, 1.5], //melee npc with random melee (penguin 2)
    [2, 150, 1, 0, 0, 0, 1, 0.6, 1, -1, -1, 1500, -1], //armed npc with random weapon (penguin 1)
    [2, 150, 2, 0, 0, 0, 1, 0.6, 1, -2, -1, 1500, -1], //armed npc with random weapon (penguin 2)
    [3, 150, 2, 0, 0, 0, 1, 0.8, 1, -2, -1, 1500, -1] //armed npc with random projectile weapon (penguin 2)
]

TSP_NPCTEST_POPULATION <- DEFAULT_POPULATION //tsp_npctest population (test map for npcs). just same as default population

FIGHTFIGHTFIGHT_POPULATION <-
[
    [5, 85, 2, 0, 2, 0, 1, 0.6, 1, -2, -1, 750, 0, 1.5], //melee npc with fists (penguin 2)
    [5, 85, 1, 0, 2, 0, 1, 0.6, 1, -2, -1, 750, 0, 1.5], //melee npc with fists (penguin 1)
]


BLOP4DEAD_03_POPULATION <- //Bloopers 4 Dead 3rd map population (Club Penguin)
[
    
]

BLOP4DEAD_04_POPULATION <- //Bloopers 4 Dead 4th map population (Badger Badger Town)
[
    
]
