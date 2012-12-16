class MCGameType extends KFGameType;

var bool bReady;

// Disabled

function NotifyGameEvent(int EventNumIn);
function LoadUpMonsterList();
PrepareSpecialSquads();
function UpdateGameLength();

event InitGame( string Options, out string Error )
{
//	local int i,j;
	local KFLevelRules KFLRit;
	local ShopVolume SH;
	local ZombieVolume ZZ;
	local string InOpt;

	Super(Invasion).InitGame(Options, Error);

//	MaxPlayers = Clamp(GetIntOption( Options, "MaxPlayers", MaxPlayers ),0,6);
//	default.MaxPlayers = Clamp( default.MaxPlayers, 0, 6 );

	foreach DynamicActors(class'KFLevelRules',KFLRit)
	{
		if(KFLRules==none)
			KFLRules = KFLRit;
		else Warn("MULTIPLE KFLEVELRULES FOUND!!!!!");
	}
	foreach AllActors(class'ShopVolume',SH)
		ShopList[ShopList.Length] = SH;
	foreach AllActors(class'ZombieVolume',ZZ)
		ZedSpawnList[ZedSpawnList.Length] = ZZ;

	//provide default rules if mapper did not need custom one
	if(KFLRules==none)
		KFLRules = spawn(class'KFLevelRules');

	log("KFLRules = "$KFLRules);

	InOpt = ParseOption(Options, "UseBots");
	if ( InOpt != "" )
	{
		bNoBots = bool(InOpt);
	}

    log("Game length = "$KFGameLength);

    bCustomGameLength = true;
}

function SetupWave()
{
	local int i,j;
	local float NewMaxMonsters;
	//local int m;
	local float DifficultyMod, NumPlayersMod;
	local int UsedNumPlayers;

	TraderProblemLevel = 0;
	rewardFlag = false;
	ZombiesKilled = 0;
	WaveMonsters = 0;
	WaveNumClasses = 0;
	NewMaxMonsters = Waves[WaveNum].WaveMaxMonsters;

	// TODO
    if ( GameDifficulty >= 7.0 ) // Hell on Earth
    {
    	DifficultyMod=1.7;
    }
    else if ( GameDifficulty >= 5.0 ) // Suicidal
    {
    	DifficultyMod=1.5;
    }
    else if ( GameDifficulty >= 4.0 ) // Hard
    {
    	DifficultyMod=1.3;
    }
    else if ( GameDifficulty >= 2.0 ) // Normal
    {
    	DifficultyMod=1.0;
    }
    else //if ( GameDifficulty == 1.0 ) // Beginner
    {
    	DifficultyMod=0.7;
    }

    UsedNumPlayers = NumPlayers + NumBots;

    // TODO
	switch ( UsedNumPlayers )
	{
        default:
            NumPlayersMod=UsedNumPlayers*0.8; // in case someone makes a mutator with > 6 players
	}

    NewMaxMonsters = NewMaxMonsters * DifficultyMod * NumPlayersMod;

    TotalMaxMonsters = Max(5,TotalMaxMonsters);

	MaxMonsters = Clamp(TotalMaxMonsters,5,MaxZombiesOnce);

	KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonsters=TotalMaxMonsters;
	KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonstersOn=true;
	WaveEndTime = Level.TimeSeconds + 255;
	AdjustedDifficulty = GameDifficulty;

	j = ZedSpawnList.Length;
	for( i=0; i<j; i++ )
		ZedSpawnList[i].Reset();
	j = 1;

	// PrepareSquadsTemplate();
	// FillCurrentSquads();

    // Save this for use elsewhere
    InitialSquadsToUseSize = SquadsToUse.Length;
    bUsedSpecialSquad=false;
    SpecialListCounter=1;

	//Now build the first squad to use
	BuildNextSquad();
}

/*
function bool AddSquad()
{
	local int numspawned;
	local int ZombiesAtOnceLeft;
	local int TotalZombiesValue;

	if(LastZVol==none || NextSpawnSquad.length==0)
	{
        // Throw in the special squad if the time is right
        if( KFGameLength != GL_Custom && !bUsedSpecialSquad &&
            (MonsterCollection.default.SpecialSquads.Length >= WaveNum || SpecialSquads.Length >= WaveNum)
            && MonsterCollection.default.SpecialSquads[WaveNum].ZedClass.Length > 0
            && (SpecialListCounter%2 == 1))
		{
            AddSpecialSquad();
		}
		else
		{
            BuildNextSquad();
        }
		LastZVol = FindSpawningVolume();
		if( LastZVol!=None )
			LastSpawningVolume = LastZVol;
	}

	if(LastZVol == None)
	{
		NextSpawnSquad.length = 0;
		return false;
	}

    // How many zombies can we have left to spawn at once
    ZombiesAtOnceLeft = MaxMonsters - NumMonsters;

	//Log("Spawn on"@LastZVol.Name);
	if( LastZVol.SpawnInHere(NextSpawnSquad,,numspawned,TotalMaxMonsters,ZombiesAtOnceLeft,TotalZombiesValue) )
	{
    	NumMonsters += numspawned; //NextSpawnSquad.Length;
    	WaveMonsters+= numspawned; //NextSpawnSquad.Length;

    	NextSpawnSquad.Remove(0, numspawned);

    	return true;
    }
    else
    {
        TryToSpawnInAnotherVolume();
        return false;
    }
}
*/

/*
function bool AddBoss()
{
}
*/

/*
function AddBossBuddySquad()
{
}
*/

function BuildNextSquad()
{
	local int i, j, RandNum;
	//local int m;

	/*
	if ( CurrentSquads.Length <= 0 )
	{
		FillCurrentSquads();
	}
	*/

	RandNum = Rand(SquadsToUse.Length);
	NextSpawnSquad = InitSquads[SquadsToUse[RandNum]].MSquad;

	// Take this squad out of the list so we don't get repeats
	SquadsToUse.Remove(RandNum,1);

}

/*
function AddSpecialSquad()
{
}
*/

defaultproperties
{
	bReady = false
}