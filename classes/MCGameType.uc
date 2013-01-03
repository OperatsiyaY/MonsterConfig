class MCGameType extends KFGameType;

#exec obj load file="MCKillsMessage.u" Package="MonsterConfig"

struct AliveMonsterInfo
{
	var KFMonster		Mon;
	var Controller		Controller;
	var Name			MName;
	var MCMonsterInfo	MonType;
};
var bool					bReady; // флаг выставляется в PostInit(),
									// который вызывается SandboxController.PostBeginPlay()
									
var bool					bBossView;

var MonsterConfig			SandboxController;
var MCWaveInfo				CurWaveInfo; // инфо о текущей волне
var array<MCSquadInfo>		Squads, SpecSquads;// сквады для текущей волны
var array<MCSquadInfo>		SquadsToPick;	 // рабочий массив отрядов из него дергаем рандомно
var array<MCMonsterInfo>	SquadToSpawn; // текущий отряд (массив MonsterInfo)
var MCSquadInfo				CurrentSquad; // текущий отряд
var int						BossHelpSquadNum; // номер отряда подмоги босса
//var array<AliveMonsterInfo> AliveMonsters;	// для сопоставления с MonsterInfo в ReduceDamage
//var array<AliveMonsterInfo>	DeadMonsters;	// т.к. ScoreKill вызывается после Killed
											// то AliveMonsters должнны удаляться в следующем тике
											// поэтому заполняем DeadMonsters и удаляем их из AliveMonsters
											// в след.тике
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
// Disabled

// Вызывается auto State PendingMatch->Begin->DetermineEvent()->NotifyGameEvent( )
// исходя из Event'а выставляет нужный MonsterCollection и вызывает LoadUpMonsterList()
function NotifyGameEvent(int EventNumIn);

// Вызывается из InitGame и из NotifyGameEvent (второй раз). Нам не нужен.
function LoadUpMonsterList();
function PrepareSpecialSquads(); // заменена на нашу PrepareSpecSquads()
function UpdateGameLength();
function BuildNextSquad();
function AddSpecialSquad();
//--------------------------------------------------------------------------------------------------
// TODO
// что делать с NumMonsters
// что делать с InitialWave -> Timer (if ( WaveNum != InitialWave && !bTradingDoorsOpen ))
// Timer -> KFGameReplicationInfo(GameReplicationInfo).TimeToNextWave = WaveCountDown;
// что делать с флагом bUserEndGameBoss -> if( WaveNum == FinalWave && bUseEndGameBoss )

// работа KFGameType с WaveNum:
// MatchInProgress -> BeginState() -> WaveNum = InitialWave
// 						DoWaveEnd()  ->   WaveNum++;
// InvasionGameReplicationInfo(GameReplicationInfo).WaveNumber = WaveNum;

// спавн Босса
// смотреть функцию function StartWaveBoss()
// NextSpawnSquad.Length = 1;
// TotalMaxMonsters = 1;
// bWaveBossInProgress = True;
//--------------------------------------------------------------------------------------------------
event InitGame( string Options, out string Error )
{
//	local int i,j;
	local KFLevelRules KFLRit;
	local ShopVolume SH;
	local ZombieVolume ZZ;
	local string InOpt;

	Super(Invasion).InitGame(Options, Error);

	// MaxPlayers = Clamp(GetIntOption( Options, "MaxPlayers", MaxPlayers ),0,6);
	// default.MaxPlayers = Clamp( default.MaxPlayers, 0, 6 );

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

	toLog("InitGame->ZedSpawnList count:"@ZedSpawnList.Length);

	//provide default rules if mapper did not need custom one
	if(KFLRules==none)
		KFLRules = spawn(class'KFLevelRules');

	log("KFLRules = "$KFLRules);

	InOpt = ParseOption(Options, "UseBots");
	if ( InOpt != "" )
		bNoBots = bool(InOpt);

    bCustomGameLength = false;
}
//--------------------------------------------------------------------------------------------------
 // Вызывается в SandboxController.PostBeginPlay()
function PostInit(MonsterConfig Sender)
{
	SandboxController = Sender;
	GameDifficulty = SandboxController.StandartGameDifficulty; // для стандартных мобов типо сталкеров на карте
	
	FinalWave = SandboxController.Waves.Length - 1;
	toLog("PostInit->FinalWave:"@FinalWave);

	bReady = true;
}
//--------------------------------------------------------------------------------------------------
function SetupWave()
{
	local int i;
	TraderProblemLevel = 0; // Для дебага выкидывания игроков из магаза
	ZombiesKilled = 0; // Мобы убитые за волну
	WaveMonsters = 0; // Мобы, заспавненные за волну
	rewardFlag = false; // выданы ли уже деньги за победу, команде
	//	WaveNumClasses = 0;	- количество классов для спавна рандомного моба, функция AddMonster
	//	TotalMaxMonsters	- задаём в своей функции
	//	MaxMonsters			- задаём в своей функции
	WaveEndTime = Level.TimeSeconds + 255; // очень странная переменная, непонятно на что влияет
	AdjustedDifficulty = GameDifficulty; // Ни на что не влияет

	for( i=ZedSpawnList.Length-1; i>=0; --i )
		ZedSpawnList[i].Reset();

	MCSetupWave();
}
//--------------------------------------------------------------------------------------------------
// Определяем номер волны относительно других
function int GetWaveNum(MCWaveInfo Wave)
{
	return SandboxController.GetWaveNum(Wave);
}
//--------------------------------------------------------------------------------------------------
function MCSetupWave()
{
	local int PlayersCount;
	local MCWaveInfo tWaveInfo;
	toLog("MCSetupWave");

	// TODO
	// определять свой диффикалти, для таблицы (можно кустом в тру выставить при инит)
	// если сквад заспавнился не полностью, некст спавн тайм обнулять и обновлять только после полногоспавна
	CurWaveInfo = SandboxController.GetNextWaveInfo(CurWaveInfo);
	toLog("MCSetupWave->CurWaveInfo:"@string(CurWaveInfo.Name));

	WaveNum = GetWaveNum(CurWaveInfo) - 1;
	InvasionGameReplicationInfo(GameReplicationInfo).WaveNumber = WaveNum;

	FinalWave = SandboxController.Waves.Length - 1;
	toLog("MCSetupWave->FinalWave="@FinalWave);

	PlayersCount = SandboxController.GetNumPlayers(true);
	toLog("MCSetupWave->PlayersCount="@PlayersCount);

	// ставим время между волнами
	TimeBetweenWaves = SandboxController.MapInfo.TimeBetweenWaves;
	// узнаем время между волнами для следующей волны
	tWaveInfo = SandboxController.GetNextWaveInfo(CurWaveInfo);
	if (tWaveInfo!=none)
		TimeBetweenWaves *= tWaveInfo.TimeBetweenThisWaveCoeff;
	TimeBetweenWaves = Max(TimeBetweenWaves,1);

	// количество монстров за волну
	TotalMaxMonsters	= SandboxController.MonstersTotalMod * SandboxController.MapInfo.MonstersTotalCoeff
						* ( CurWaveInfo.MonstersTotal + CurWaveInfo.PerPlayer.MonstersTotal * (PlayersCount - 1) );
	toLog("MCSetupWave->TotalMaxMonsters:"@TotalMaxMonsters);


	// Мобы, одновременно находящиеся на карте
	MaxMonsters	= SandboxController.MonstersMaxAtOnceMod * SandboxController.MapInfo.MonstersMaxAtOnceCoeff
				* ( CurWaveInfo.MonstersMaxAtOnce + CurWaveInfo.PerPlayer.MonstersMaxAtOnce * (PlayersCount - 1) );
	toLog("MCSetupWave->MaxMonsters:"@MaxMonsters);

	KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonsters = TotalMaxMonsters;
	KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonstersOn = true;

	// формируем отряды на текущую волну
	PrepareSquads();
	PrepareSpecSquads();
	// SquadsToPickFill();
}
//--------------------------------------------------------------------------------------------------
// вызываем при MCSetupWave() - заполняет массив Squads - сквадами на волну
function PrepareSquads()
{
	local int i,n;
	Squads.Remove(0,Squads.Length);

	n = CurWaveInfo.Squad.Length;
	for(i=0; i<n; i++)
	{
		Squads.Insert(0,1);
		Squads[0] = SandboxController.GetSquad(CurWaveInfo.Squad[i]);
	}
	toLog("PrepareSquads()->Squads count:"@Squads.Length);
}
//--------------------------------------------------------------------------------------------------
// вызываем при MCSetupWave() - заполняет массив SpecSquads - спец.сквадами на волну
function PrepareSpecSquads()
{
	local int i;
	SpecSquads.Remove(0,SpecSquads.Length);
	SpecSquads.Insert(0,CurWaveInfo.SpecialSquad.Length);
	for(i=CurWaveInfo.SpecialSquad.Length-1; i>=0; --i)
	{
		SpecSquads[i] = SandboxController.GetSquad(CurWaveInfo.SpecialSquad[i]);
		SpecSquads[i].Counter = SpecSquads[i].InitialCounter;
		SpecSquads[i].CurFreq = SpecSquads[i].Freq + Rand(SpecSquads[i].FreqRand+1);
	}
	toLog("PrepareSpecSquads()->SpecSquads count"@SpecSquads.Length);
}
//--------------------------------------------------------------------------------------------------
function bool MCAddSquad(optional bool bBoss, optional bool bBossHelpSquad)
{
	local int numspawned;
	local int ZombiesAtOnceLeft;
	local int TotalZombiesValue, TempTotalMaxMonsters;
	local int i,n;
	local bool lDebug;
	lDebug=false;

	if( LastZVol == none || SquadToSpawn.Length == 0 || bBossHelpSquad)
	{
		if (bWaveBossInProgress || bBoss)
		{
			if (bBoss)
				CurrentSquad = Squads[0];
			else if (bBossHelpSquad)
				CurrentSquad = GetSpecialSquad(true); // Counter Special сквада обнулился внутри уже тут
			
			CurrentSquad.bSpecialSquad = true;
		}
		else
		{
			CurrentSquad = GetSpecialSquad(); // Counter Special сквада обнулился внутри уже тут
			if ( CurrentSquad == none )
			{
				CurrentSquad = GetRandomSquad();
				CurrentSquad.bSpecialSquad = false;
			}
			else
			{
				if (lDebug) toLog("AddSquad()->Will spawn special squad");
				CurrentSquad.bSpecialSquad = true;
			}
		}
		SquadToMonsters(CurrentSquad,SquadToSpawn);

		LastZVol = FindSpawningVolume(bBoss);
		if( LastZVol != None )
			LastSpawningVolume = LastZVol;
	}
	if (lDebug) toLog("AddSquad()->CurrentSquad:"@string(CurrentSquad.Name)@"("$SquadToSpawn.Length$" monsters)");

	if( LastZVol == None )
	{
		if (lDebug) toLog("AddSquad()-> No ZombieVolume's found. So just return.");

		// исключаем пропуск SpecialSquad'ов из-за временных проблем со спавном
		if (!CurrentSquad.bSpecialSquad)
		{
			SquadToSpawn.Remove(0,SquadToSpawn.Length);
			// TODO хак, чтобы не переписывать ВЕСЬ ТАЙМЕР!!!! так как в нем идет проверка
			// на nextSpawnSquad.Length если отрят не смог заспавниться полностью, то NextSpawnTime ставится +0.1
			// и остальные мобы спавнятся почти сразу, а не через стандартные CalcNextSquadSpawnTime();
			// можно наш массив SquadToSpawn обозвать по ихнему, но компилятор будет каждый раз ругаться
			// на обфускацию
			nextSpawnSquad.Length = SquadToSpawn.Length;
		}
		return false;
	}

	// How many zombies can we have left to spawn at once
	if (bBossHelpSquad)
	{
		ZombiesAtOnceLeft = 999;
		TempTotalMaxMonsters = 999;
	}
    else
	{
		ZombiesAtOnceLeft = MaxMonsters - NumMonsters;
		TempTotalMaxMonsters = TotalMaxMonsters;
	}
	if (lDebug) toLog("AddSquad()->We can spawn only ZombiesAtOnceLeft:"@ZombiesAtOnceLeft@"(MaxMonsters:"@MaxMonsters@"NumMonsters:"@NumMonsters@")");
	
	if( MCZombieVolume(LastZVol).MCSpawnInHere(
		SquadToSpawn,		// out массив MCMonsterInfo для спавна
		,					// bTest если true лишь возвращает возможность заспавнить монстров тут
		numspawned,			// out int возвращает количество заспавленых монстров
		TempTotalMaxMonsters,	// out TotalMaxMonsters
		ZombiesAtOnceLeft,	// int MaxMonstersAtOnceLeft
		TotalZombiesValue,	// out int TotalZombiesValue
		false) )			// bTryAllSpawns - если false, делает только 3 попытки спавна,
							// если true - пытается заспавнить во всех SpawnPoints волума
							// TODO - ставить тут true?
	{
		if (lDebug) toLog("AddSquad()->ZombiesSpawned:"@numspawned);

		if (!bBossHelpSquad)
			TotalMaxMonsters = TempTotalMaxMonsters;
		
		// спецсквады не считаются
		if (!CurrentSquad.bSpecialSquad || bBoss)
		{
			NumMonsters += numspawned;
			WaveMonsters+= numspawned;

			// обновляем counter'ы для SpecSquads
			n = SpecSquads.Length;
			for(i=0; i<n; i++)
				SpecSquads[i].Counter += numspawned;
		}

		// TODO хак, чтобы не переписывать ВЕСЬ ТАЙМЕР!!!! так как в нем идет проверка
		// на nextSpawnSquad.Length если отрят не смог заспавниться полностью, то NextSpawnTime ставится +0.1
		// и остальные мобы спавнятся почти сразу, а не через стандартные CalcNextSquadSpawnTime();
		// можно наш массив SquadToSpawn обозвать по ихнему, но компилятор будет каждый раз ругаться
		// на обфускацию
		// можно даже заполнять его class<KFMonster>, взятыми из SquadToSpawn, если нужно
		nextSpawnSquad.Length = SquadToSpawn.Length;

		// тут же вызываем таймер, чтобы поскорее заспавнить оставшихся
		if (SquadToSpawn.Length>0) 
			Timer();

    	return true;
    }
    else
    {
		if (lDebug) toLog("AddSquad()->ZombiesSpawned: 0. So call TryToSpawnInAnotherVolume()");
        TryToSpawnInAnotherVolume(bBoss);
        return false;
    }
}
//--------------------------------------------------------------------------------------------------
function bool AddSquad()
{
	return MCAddSquad();
}
//--------------------------------------------------------------------------------------------------
function MCSquadInfo GetSpecialSquad(optional bool bBossHelpSquad)
{
	local int i;
	local bool lDebug;
	lDebug = false;

	if (SpecSquads.Length==0)
		return none;

	if (bBossHelpSquad)
	{
		if (FinalSquadNum >= SpecSquads.Length)
			FinalSquadNum = SpecSquads.Length-1; // возвращаем последний SpecialSquad (самый сильный)
		return SpecSquads[FinalSquadNum++];
	}
	else
	{
		for(i=SpecSquads.Length-1; i>=0; --i)
		{
			if ( SpecSquads[i].CurFreq <= SpecSquads[i].Counter )
			{
				SpecSquads[i].Counter = 0;
				SpecSquads[i].CurFreq = SpecSquads[i].Freq + Rand(SpecSquads[i].FreqRand+1);
				if (lDebug) toLog("GetSpecialSquad()->Returning"@string(SpecSquads[i].Name));
				return SpecSquads[i];
			}
		}
	}
	if (lDebug) toLog("GetSpecialSquad()->Returning"@none);
	return none;
}
//--------------------------------------------------------------------------------------------------
// выдергиваем рандомно CurrentSquad  из SquadsToPick
function MCSquadInfo GetRandomSquad()
{
	local int n;
	local MCSquadInfo Ret;

	if ( SquadsToPick.Length <= 0 )
		SquadsToPickFill();

	n = Rand(SquadsToPick.Length); // -1 убрал т.к. Rand возвращает уже с -1
	Ret = SquadsToPick[n];
	SquadsToPick.Remove(n,1);

	return Ret;
}
//--------------------------------------------------------------------------------------------------
// заполняем массив SquadsToPick, из которого будем рандомно дёргать CurrentSquad'ы
function SquadsToPickFill()
{
	local int i;
	local bool lDebug;
	lDebug = false;
	SquadsToPick.Remove(0,SquadsToPick.Length);

	SquadsToPick.Insert(0,Squads.Length);
	for (i=Squads.Length-1; i>=0; --i)
		SquadsToPick[i] = Squads[i];

	if (lDebug) toLog("SquadsToPickFill()->SquadsToPick count:"@SquadsToPick.Length);
}
//--------------------------------------------------------------------------------------------------
function bool SquadToMonsters(MCSquadInfo CurSquad, out array<MCMonsterInfo> Ret)
{
	local int i,n,c,j,k,ntry;
	local string RandomMonsterName;
	local MCMonsterInfo CurMon;
	local bool lDebug;
	lDebug = false;
	
	Ret.Remove(0,Ret.Length);

	if (lDebug) toLog("SquadToMonsters()->CurSquad"@string(CurSquad.Name));

	n = CurSquad.Monster.Length;
	if ( n <= 0 )
	{
		if (lDebug) toLog("SquadToMonsters()->CurSquad: no monsters specified. Squad:"@string(CurSquad.Name));
		return false;
	}

	// перебор всех монстров в скваде
	for(i=n-1; i>=0; --i)
	{
		// добавляем указанное num число монстров
		ntry=0;
		for(j=CurSquad.Monster[i].Num; j>0; --j)
		{
			// в скваде могут быть указаны несколько MonsterName, берем их рандомно
			k = Rand(CurSquad.Monster[i].MonsterName.Length);
			k = Max(0,k);
			RandomMonsterName = CurSquad.Monster[i].MonsterName[k];
			CurMon = SandboxController.GetMonster(RandomMonsterName);
			if (CurMon==none)
				{j++;ntry++;if (ntry>CurSquad.Monster[i].Num*2) break; continue;} // монстр не валидный, пробуем еще раз
			else
				Ret[c++] = CurMon;
		}
	}
	if (lDebug) toLog("SquadToMonsters()->Returning"@Ret.Length@"monsters");

	// TODO хак, чтобы не переписывать ВЕСЬ ТАЙМЕР!!!! так как в нем идет проверка
	// на nextSpawnSquad.Length если отрят не смог заспавниться полностью, то NextSpawnTime ставится +0.1
	// и остальные мобы спавнятся почти сразу, а не через стандартные CalcNextSquadSpawnTime();
	// можно наш массив SquadToSpawn обозвать по ихнему, но компилятор будет каждый раз ругаться
	// на обфускацию
	nextSpawnSquad.Length = SquadToSpawn.Length;

	return true;
}
//--------------------------------------------------------------------------------------------------
//---------------------------------------------- БОСС ----------------------------------------------
function bool AddBoss()
{
	local bool bRet;

	bRet = MCAddSquad(true); // bBoss = true
	if (bRet)
	{
		// только если успешно заспавнили хотябы одного босса
		FinalSquadNum = 0;
		bHasSetViewYet = false; 
		Timer();
	}
	return bRet;
/*	Оригинальный код TWI
	local int ZombiesAtOnceLeft;
	local int numspawned;
	FinalSquadNum = 0;
    // Force this to the final boss class
	NextSpawnSquad.Length = 1;
	if( KFGameLength != GL_Custom)
 	    NextSpawnSquad[0] = Class<KFMonster>(DynamicLoadObject(MonsterCollection.default.EndGameBossClass,Class'Class'));
    else
    {
        NextSpawnSquad[0] = Class<KFMonster>(DynamicLoadObject(EndGameBossClass,Class'Class'));
        //override the monster with its event version
        if(NextSpawnSquad[0].default.EventClasses.Length > eventNum)
            NextSpawnSquad[0] = Class<KFMonster>(DynamicLoadObject(NextSpawnSquad[0].default.EventClasses[eventNum],Class'Class'));
    }
	if( LastZVol==none )
	{
		LastZVol = FindSpawningVolume(false, true);
		if(LastZVol!=None)
			LastSpawningVolume = LastZVol;
	}
	if(LastZVol == None)
	{
		LastZVol = FindSpawningVolume(true, true);
		if( LastZVol!=None )
			LastSpawningVolume = LastZVol;
		if( LastZVol == none )
		{
            //log("Error!!! Couldn't find a place for the Patriarch after 2 tries, trying again later!!!");
            TryToSpawnInAnotherVolume(true);
            return false;
		}
	}
    // How many zombies can we have left to spawn at once
    ZombiesAtOnceLeft = MaxMonsters - NumMonsters;
    //log("Patrarich spawn, MaxMonsters = "$MaxMonsters$" NumMonsters = "$NumMonsters$" ZombiesAtOnceLeft = "$ZombiesAtOnceLeft$" TotalMaxMonsters = "$TotalMaxMonsters);
	if(LastZVol.SpawnInHere(NextSpawnSquad,,numspawned,TotalMaxMonsters,32,,true))
	{
        //log("Spawned Patriarch - numspawned = "$numspawned);
        NumMonsters+=numspawned;
        WaveMonsters+=numspawned;
        return true;
	}
    else
    {
        //log("Failed Spawned Patriarch - numspawned = "$numspawned);
        TryToSpawnInAnotherVolume(true);
        return false;
    }*/
}
//--------------------------------------------------------------------------------------------------
function AddBossBuddySquad()
{
	MCAddSquad(false, true); //bBoss==false, bBossHelpSquad==true;
	return;
/*	Оригинальный код TWI
	local int numspawned;
	local int TotalZombiesValue;
	local int i;
	local int TempMaxMonsters;
	local int TotalSpawned;
	local int TotalZeds;
	local int SpawnDiff;
    // Scale the number of helpers by the number of players
    if( NumPlayers == 1 )
    {
        TotalZeds = 8;
    }
    else if( NumPlayers <= 3 )
    {
        TotalZeds = 12;
    }
    else if( NumPlayers <= 5 )
    {
        TotalZeds = 14;
    }
    else if( NumPlayers >= 6 )
    {
        TotalZeds = 16;
    }

	for ( i = 0; i < 10; i++ )
    {
        if( TotalSpawned >= TotalZeds )
        {
            FinalSquadNum++;
            //log("Too many monsters, returning");
            return;
        }

        numspawned = 0;

        // Set up the squad for spawning
        NextSpawnSquad.length = 0;
        AddSpecialPatriarchSquad();

		LastZVol = FindSpawningVolume();
		if( LastZVol!=None )
			LastSpawningVolume = LastZVol;

    	if(LastZVol == None)
    	{
    		LastZVol = FindSpawningVolume();
    		if( LastZVol!=None )
    			LastSpawningVolume = LastZVol;

    		if( LastZVol == none )
    		{
                log("Error!!! Couldn't find a place for the Patriarch squad after 2 tries!!!");
    		}
    	}

        // See if we've reached the limit
        if( (NextSpawnSquad.Length + TotalSpawned) > TotalZeds )
        {
            SpawnDiff = (NextSpawnSquad.Length + TotalSpawned) - TotalZeds;

            if( NextSpawnSquad.Length > SpawnDiff )
            {
                NextSpawnSquad.Remove(0, SpawnDiff);
            }
            else
            {
                FinalSquadNum++;
                return;
            }

            if( NextSpawnSquad.Length == 0 )
            {
                FinalSquadNum++;
                return;
            }
        }

        // Spawn the squad
        TempMaxMonsters =999;
    	if( LastZVol.SpawnInHere(NextSpawnSquad,,numspawned,TempMaxMonsters,999,TotalZombiesValue) )
    	{
        	NumMonsters += numspawned;
        	WaveMonsters+= numspawned;
        	TotalSpawned += numspawned;

        	NextSpawnSquad.Remove(0, numspawned);
        }
    }

    FinalSquadNum++;*/
}
//--------------------------------------------------------------------------------------------------
function AddSpecialPatriarchSquadFromGameType();
function AddSpecialPatriarchSquadFromCollection();
function AddSpecialPatriarchSquad();
//--------------------------------------------------------------------------------------------------
// SloMo + отключение монстров
function DoBossDeath()
{
    local Controller C;
    local Controller nextC;
    local int num;

	toLog("DoBossDeath()");

    bZEDTimeActive =  true;
    bSpeedingBackUp = false;
    LastZedTimeEvent = Level.TimeSeconds;
    CurrentZEDTimeDuration = ZEDTimeDuration*2;
    SetGameSpeed(ZedTimeSlomoScale);

	// выключаем монстров, только если действительно все убиты
	if (TotalMaxMonsters<=0 && NumMonsters <= 0)
	{
		num = NumMonsters;

		// turn off all the other zeds so they don't attack the player
		c = Level.ControllerList;
		while (c != none && num > 0)
		{
			nextC = c.NextController;
			if (KFMonsterController(C)!=None)
			{
				C.GotoState('GameEnded');
				--num;
			}
			c = nextC;
		}
	}
}
//--------------------------------------------------------------------------------------------------
function SetupWaveBoss()
{
	SetupWave();
	bWaveBossInProgress = True;
	return;
	/*	Оригинальный код TWI
	local int i,l;
	
	l = ZedSpawnList.Length;
	for( i=0; i<l; i++ )
		ZedSpawnList[i].Reset();
	bHasSetViewYet = False;
	WaveEndTime = Level.TimeSeconds+60;
	NextSpawnSquad.Length = 1;

	if( KFGameLength != GL_Custom )
	{
		NextSpawnSquad[0] = Class<KFMonster>(DynamicLoadObject(MonsterCollection.default.EndGameBossClass,Class'Class'));
		NextspawnSquad[0].static.PreCacheAssets(Level);
	}
	else
	{
		NextSpawnSquad[0] = Class<KFMonster>(DynamicLoadObject(EndGameBossClass,Class'Class'));
		if(NextSpawnSquad[0].default.EventClasses.Length > eventNum)
		{
			NextSpawnSquad[0] = Class<KFMonster>(DynamicLoadObject(NextSpawnSquad[0].default.EventClasses[eventNum],Class'Class'));
		}
		NextspawnSquad[0].static.PreCacheAssets(Level);
	}

	if( NextSpawnSquad[0]==None )
		NextSpawnSquad[0] = Class<KFMonster>(FallbackMonster);
	KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonsters = 1;
	TotalMaxMonsters = 1;
	bWaveBossInProgress = True;*/
}
//--------------------------------------------------------------------------------------------------
// Награда за киллы
function ScoreKill(Controller Killer, Controller Other)
{
	local PlayerReplicationInfo OtherPRI;
	// переменные для bWaveFundSystem==false
	local float KillScore;
	local MCMonsterInfo tMonsterInfo;

	OtherPRI = Other.PlayerReplicationInfo;
	if ( OtherPRI != None )
	{
		OtherPRI.NumLives++;
		OtherPRI.Score -= (OtherPRI.Score * (GameDifficulty * 0.05));	// you Lose 35% of your current cash on Hell on Earth, 15% on normal.
		OtherPRI.Team.Score -= (OtherPRI.Score * (GameDifficulty * 0.05));

		if (OtherPRI.Score < 0 )
			OtherPRI.Score = 0;
		if (OtherPRI.Team.Score < 0 )
			OtherPRI.Team.Score = 0;

		OtherPRI.Team.NetUpdateTime = Level.TimeSeconds - 1;
		OtherPRI.bOutOfLives = true;
		if( Killer!=None && Killer.PlayerReplicationInfo!=None && Killer.bIsPlayer )
			BroadcastLocalizedMessage(class'KFInvasionMessage',1,OtherPRI,Killer.PlayerReplicationInfo);
		else if( Killer==None || Monster(Killer.Pawn)==None )
			BroadcastLocalizedMessage(class'KFInvasionMessage',1,OtherPRI);
		else BroadcastLocalizedMessage(class'KFInvasionMessage',1,OtherPRI,,Killer.Pawn.Class);
		CheckScore(None);
	}

	if ( GameRulesModifiers != None )
		GameRulesModifiers.ScoreKill(Killer, Other);

	if ( MonsterController(Killer) != None )
		return;

	if( (killer == Other) || (killer == None) )
	{
		if ( Other.PlayerReplicationInfo != None )
		{
			Other.PlayerReplicationInfo.Score -= 1;
			Other.PlayerReplicationInfo.NetUpdateTime = Level.TimeSeconds - 1;
			ScoreEvent(Other.PlayerReplicationInfo,-1,"self_frag");
		}
	}

	if ( Killer==None || !Killer.bIsPlayer || (Killer==Other) )
		return;

	if ( Other.bIsPlayer )
	{
		Killer.PlayerReplicationInfo.Score -= 5;
		Killer.PlayerReplicationInfo.Team.Score -= 2;
		Killer.PlayerReplicationInfo.NetUpdateTime = Level.TimeSeconds - 1;
		Killer.PlayerReplicationInfo.Team.NetUpdateTime = Level.TimeSeconds - 1;
		ScoreEvent(Killer.PlayerReplicationInfo, -5, "team_frag");
		return;
	}

	if (Killer.PlayerReplicationInfo !=none)
	{
		Killer.PlayerReplicationInfo.Kills++;
		if (SandboxController.bWaveFundSystem==false)
		{	
			//GetAliveMonsterInfo(Other, Other.Pawn);
			tMonsterInfo = SandboxController.GetMonInfo(Other);

			if( tMonsterInfo==none || tMonsterInfo.RewardScore == tMonsterInfo.default.RewardScore )
			{
				if (LastKilledMonsterClass != none)
					KillScore = LastKilledMonsterClass.Default.ScoringValue;
				else
				{
					toLog("ScoreKill->Failed to found RewardScore for monster, so Score is 1");
					KillScore = 1;
				}
			}
			else
				KillScore = tMonsterInfo.RewardScore;

			if( tMonsterInfo!=none
				&& tMonsterInfo.RewardScoreCoeff != tMonsterInfo.default.RewardScoreCoeff )
				KillScore *= tMonsterInfo.RewardScoreCoeff;

			KillScore = Max(1,int(KillScore));
			Killer.PlayerReplicationInfo.Team.Score += KillScore;
			TeamScoreEvent(Killer.PlayerReplicationInfo.Team.TeamIndex, 1, "tdm_frag");

			// в bWaveFundSystem не нужен, так как очки и так распределяются исходя из дамага
			ScoreKillAssists(KillScore, Other, Killer);
		}
		Killer.PlayerReplicationInfo.NetUpdateTime = Level.TimeSeconds - 1;
		Killer.PlayerReplicationInfo.Team.NetUpdateTime = Level.TimeSeconds - 1;

		if (Killer.PlayerReplicationInfo.Score < 0)
			Killer.PlayerReplicationInfo.Score = 0;
	}

	SandboxController.NotifyMonsterKill(Other);
    /* Marco's Kill Messages перенесены из ScoreKill в Killed, т.к. в Killed KFMonsterPawn еще жив */
}
//--------------------------------------------------------------------------------------------------
function bool RewardWithFundSystem()
{
	local int Healed, HealedStat;
	local float WaveScore, Fund, RealFund, F;
	local Controller C;
	local MCRepInfo	RInfo;
	local PlayerReplicationInfo PRI;

	// после килла патрика ниче не делаем, просто выходим
	if (WaveNum > FinalWave)
		return true;

	for ( C = Level.ControllerList; C != none; C = C.NextController )
	{
		PRI = C.PlayerReplicationInfo;
		if ( PRI != none )
		{
			RInfo = SandboxController.GetMCRepInfo(PRI);
			// HealedStat - общая стата из перков сколько игкрок вылечил всего
			SandboxController.GetHealedStats(PRI, HealedStat); // берем из перков
			if( C.Pawn != none
				&& PRI.bOutOfLives==false ) // остался жив
			{
				if (RInfo.HealedStat > 0)
				{
					// сравниваем с предыдущим значением
					Healed = HealedStat - RInfo.HealedStat;
					SandboxController.LM(PRI.PlayerName@"Healed"@Healed);
					F = float(Healed) * SandboxController.HealedToScoreCoeff;
					// добавили в общие очки игрока
					RInfo.WaveScore += F;
				}
				RInfo.HealedStat = HealedStat;

				RInfo.GameScore += F; /*RInfo.WaveScore*/

				// считаем общую стату за волну, чтобы потом правильно распределить
				WaveScore += RInfo.WaveScore;
			}
			// для тех, кто не выжил, просто удаляем прогресс, к сожалению.
			// фонд за них получат другие
			RInfo.HealedStat = HealedStat;
		}
	}
	// определяем фонд
	Fund = float(CurWaveInfo.PerPlayerFund) * float(Max(1, SandboxController.GetNumPlayers(true)-1));
	toLog("RewardSurvivingPlayers()->Fund is"@Fund);
	if (Fund==0)
		return true;
	// еще раз проходим массив живых, на этот раз вручая денюжку
	for ( C = Level.ControllerList; C != none; C = C.NextController )
	{
		PRI = C.PlayerReplicationInfo;
		if( PRI != none )
			RInfo = SandboxController.GetMCRepInfo(PRI);
		if (RInfo != none)
		{
			if ( C.Pawn != none
				&& PRI.bOutOfLives == false )
			{

				F = SandboxController.PerkStats.GetPerkScoreCoeff(KFPlayerReplicationInfo(PRI).ClientVeteranSkill);
				F *= Fund * (RInfo.WaveScore / WaveScore);
				toLog("RewardSurvivingPlayers()->"$PRI.PlayerName@"got"@F);
				PRI.Score += F;
				PRI.NetUpdateTime = Level.TimeSeconds - 1;
				RealFund += F;
				SandboxController.PerkStats.AddPerkScore(KFPlayerReplicationInfo(PRI).ClientVeteranSkill, int(F));
			}
		}
		RInfo.WaveScore  = 0;
	}
	toLog("RewardSurvivingPlayers()->RealFund is"@RealFund);
	return true;
}
//--------------------------------------------------------------------------------------------------
function bool RewardSurvivingPlayers()
{
	local Controller C;
	local int moneyPerPlayer,div;
	local TeamInfo T;

	// если используем систему наград с фондом
	if (SandboxController.bWaveFundSystem)
		return RewardWithFundSystem();

	for ( C = Level.ControllerList; C != none; C = C.NextController )
	{
		if ( C.Pawn != none && C.PlayerReplicationInfo != none && C.PlayerReplicationInfo.Team != none )
		{
			T = C.PlayerReplicationInfo.Team;
			div++;
		}
	}

	if ( T == none || T.Score <= 0 )
	{
		return false;
	}

	moneyPerPlayer = int(T.Score / float(div));

	for ( C = Level.ControllerList; C != none; C = C.NextController )
	{
		if ( C.Pawn != none && C.PlayerReplicationInfo != none && C.PlayerReplicationInfo.Team != none )
		{
			if ( div == 1 )
			{
				C.PlayerReplicationInfo.Score += T.Score;
				T.Score = 0;
			}
			else
			{
				C.PlayerReplicationInfo.Score += moneyPerPlayer;
				T.Score-=moneyPerPlayer;
				div--;
			}

			C.PlayerReplicationInfo.NetUpdateTime = Level.TimeSeconds - 1;

			if( T.Score <= 0 )
			{
				T.Score = 0;
				Break;
			}
		}
	}

	T.NetUpdateTime = Level.TimeSeconds - 1;

	return true;
}
//--------------------------------------------------------------------------------------------------
state MatchInProgress
{
 	function DoWaveEnd()
	{
		super.DoWaveEnd();

		if (SandboxController.bWaveFundSystem)
			SandboxController.PerkStats.SaveConfig();

		SquadToSpawn.Remove(0,SquadToSpawn.Length);
		nextSpawnSquad.Remove(0,nextSpawnSquad.Length);
		
		SandboxController.WaveEnd(); // очищается массив AliveMonsters
	}
	//----------------------------------------------------------------------------------------------
	// определяем через какое время спавнить монстров
	// Функция используется в Timer'е:
	// NextMonsterTime = Level.TimeSeconds + CalcNextSquadSpawnTime();
	function float CalcNextSquadSpawnTime()
	{
		local float NextSpawnTime;
		local float SineMod, F, F2, F3;
		local bool lDebug;
		lDebug = false;

		SineMod = 1.0 - Abs(sin(WaveTimeElapsed * SineWaveFreq));

		//NextSpawnTime = KFLRules.WaveSpawnPeriod;
		F = CurWaveInfo.DelayBetweenSquads;
		F *= SandboxController.MapInfo.DelayBetweenSquadsCoeff;

		F2 = FMax(0.f, (1.0 - SandboxController.MapInfo.PerPlayer.DelayBetweenSquadsCoeff));
		F3 = SandboxController.GetNumPlayers(true) - 1;
		if (F2>0 && F3>0)
			 F *= FMax(0.1, F2*F3);

		NextSpawnTime =  F;

		NextSpawnTime += SineMod * (NextSpawnTime * 2);

		if (lDebug) toLog("CalcNextSquadSpawnTime()->WaveTimeElapsed:"@WaveTimeElapsed@"SineMod:"@SineMod@"NextSpawnTime:"@NextSpawnTime);

		return NextSpawnTime;
	}
	//----------------------------------------------------------------------------------------------
	// активизация/выключение волумов в зависимости от номера волны (используется строителями карт)
	function InitMapWaveCfg()
	{
		local int i,l;

		// используем стандартные настройки волумов
		if ( SandboxController.MapInfo.bUseZombieVolumeWaveDisabling )
		{
			Super.InitMapWaveCfg();
		}
		else // если нет, то включаем все волумы
		{
			l = ZedSpawnList.Length;
			for( i=0; i<l; i++ )
			{
				if( !ZedSpawnList[i].bVolumeIsEnabled )
				{
					ZedSpawnList[i].bVolumeIsEnabled = True;
					ZedSpawnList[i].TriggerEvent(ZedSpawnList[i].ToggledEnabledEvent,ZedSpawnList[i],None);
				}
			}
		}
	}
	//----------------------------------------------------------------------------------------------
	function StartWaveBoss()
	{
		SetupWaveBoss(); // наша функция
	}
	//----------------------------------------------------------------------------------------------
	function Timer()
	{
		local Controller C;
		local bool bOneMessage;
		local Bot B;

		Global.Timer();

		if ( Level.TimeSeconds > HintTime_1 && bTradingDoorsOpen && bShowHint_2 ) {
			for ( C = Level.ControllerList; C != None; C = C.NextController )
			{
				if( C.Pawn != none && KFPlayerController(C) != none && C.Pawn.Health > 0 ) // TELO FIX
				{
					KFPlayerController(C).CheckForHint(32);
					HintTime_2 = Level.TimeSeconds + 11;
				}
			}

			bShowHint_2 = false;
		}
		if ( Level.TimeSeconds > HintTime_2 && bTradingDoorsOpen && bShowHint_3 ) {
			for ( C = Level.ControllerList; C != None; C = C.NextController )
			{
				if( C.Pawn != None && KFPlayerController(C)!=none && C.Pawn.Health > 0 ) // TELO FIX
				{
					KFPlayerController(C).CheckForHint(33);
				}
			}

			bShowHint_3 = false;
		}
		if ( !bFinalStartup ) {
			bFinalStartup = true;
			PlayStartupMessage();
		}
		if ( NeedPlayers() && AddBot() && (RemainingBots > 0) )
			RemainingBots--;
		ElapsedTime++;
		GameReplicationInfo.ElapsedTime = ElapsedTime;

		if( !UpdateMonsterCount() ) {
			EndGame(None,"TimeLimit");
			return;
		}

		if( bUpdateViewTargs )
			UpdateViews();

		if (!bNoBots && !bBotsAdded) {
			if(KFGameReplicationInfo(GameReplicationInfo) != none)

			if((NumPlayers + NumBots) < MaxPlayers && KFGameReplicationInfo(GameReplicationInfo).PendingBots > 0 )
			{
				AddBots(1);
				KFGameReplicationInfo(GameReplicationInfo).PendingBots --;
			}

			if (KFGameReplicationInfo(GameReplicationInfo).PendingBots == 0)
			{
				bBotsAdded = true;
				return;
			}
		}

		// Close Trader doors
		if (bWaveBossInProgress || bWaveInProgress) {
			if (bTradingDoorsOpen)
			{
				CloseShops();
				TraderProblemLevel = 0;
			}
			if( TraderProblemLevel<4 )
			{
				if( BootShopPlayers() )
					TraderProblemLevel = 0;
				else TraderProblemLevel++;
			}
		}

		// БОСС
		if( bWaveBossInProgress )
		{
			// Ставим камеру на Босса, когда он спавнится
			if( !bHasSetViewYet && NumMonsters>0 /*&& TotalMaxMonsters<=0*/)
			{
				bHasSetViewYet = true;
				for ( C = Level.ControllerList; C != None; C = C.NextController )
					if ( KFMonster(C.Pawn)!=none && KFMonster(C.Pawn).MakeGrandEntry() )
					{
						ViewingBoss = KFMonster(C.Pawn);
						break;
					}
				if( ViewingBoss != none )
				{
					bBossView = true;
					ViewingBoss.bAlwaysRelevant = true;
					for ( C=Level.ControllerList; C!=None; C=C.NextController )
					{
						if( PlayerController(C) != none )
						{
							PlayerController(C).SetViewTarget(ViewingBoss);
							PlayerController(C).ClientSetViewTarget(ViewingBoss);
							PlayerController(C).bBehindView = True;
							PlayerController(C).ClientSetBehindView(True);
							PlayerController(C).ClientSetMusic(BossBattleSong,MTRAN_FastFade);
						}
						if ( C.PlayerReplicationInfo!=None && bRespawnOnBoss )
						{
							C.PlayerReplicationInfo.bOutOfLives = false;
							C.PlayerReplicationInfo.NumLives = 0;
							if ( (C.Pawn == None) && !C.PlayerReplicationInfo.bOnlySpectator && PlayerController(C)!=None )
								C.GotoState('PlayerWaiting');
						}
					}
				}
			}
			// Убираем камеру с босса
			else if( bBossView && (ViewingBoss==none || (ViewingBoss!=None && !ViewingBoss.bShotAnim) ) )
			{
				bBossView = false;
				ViewingBoss = None;
				for ( C = Level.ControllerList; C != None; C = C.NextController )
					if( PlayerController(C)!=None )
					{
						if( C.Pawn==None && !C.PlayerReplicationInfo.bOnlySpectator && bRespawnOnBoss )
							C.ServerReStartPlayer();
						if( C.Pawn!=None )
						{
							PlayerController(C).SetViewTarget(C.Pawn);
							PlayerController(C).ClientSetViewTarget(C.Pawn);
						}
						else
						{
							PlayerController(C).SetViewTarget(C);
							PlayerController(C).ClientSetViewTarget(C);
						}
						PlayerController(C).bBehindView = False;
						PlayerController(C).ClientSetBehindView(False);
					}
			}

			// Всех перебили
			if( (TotalMaxMonsters<=0 || Level.TimeSeconds > WaveEndTime) && NumMonsters<=0)
					DoWaveEnd();
			else if (MaxMonsters - NumMonsters > 0) // if we can spawn more
				AddBoss();
		}
		// Обычная ВОЛНА
		else if(bWaveInProgress)
		{
			WaveTimeElapsed += 1.0;

			if(!MusicPlaying)
				StartGameMusic(True);

			if( TotalMaxMonsters<=0 )
			{
				// TWI's Check for STUCK monsters БЫЛА бажная, убивает монстров при спавне сразу
				if ( NumMonsters <= 5 && WaveTimeElapsed > 10.0/*|| Level.TimeSeconds>WaveEndTime*/ )
				{
					for ( C = Level.ControllerList; C != None; C = C.NextController )
					{
						if( KFMonsterController(C)!=None && KFMonster(C.Pawn) != none
							//&& KFMonsterController(C).CanKillMeYet()
							&& (Level.TimeSeconds-KFMonster(C.Pawn).LastSeenOrRelevantTime > 8) )
						{
							toLog("MonsterStuck so kill"@KFMonster(C.Pawn).MenuName);
							C.Pawn.KilledBy( C.Pawn );
							break;
						}
					}
				}
				// if everyone's spawned and they're all dead
				if ( NumMonsters <= 0 )
                    DoWaveEnd();
			} // all monsters spawned
			else if ( NextMonsterTime < Level.TimeSeconds && (NumMonsters/* + NextSpawnSquad.Length */</*=*/ MaxMonsters) )
			{
				WaveEndTime = Level.TimeSeconds+160;
				if( !bDisableZedSpawning )
                    AddSquad(); // Comment this out to prevent zed spawning

				if(nextSpawnSquad.length>0)
                	NextMonsterTime = Level.TimeSeconds;// + 0.2;
				else
                    NextMonsterTime = Level.TimeSeconds + CalcNextSquadSpawnTime();
  			}
		}
		else if ( NumMonsters <= 0 )
		{
			if ( WaveNum == FinalWave && !bUseEndGameBoss )
			{
				if( bDebugMoney )
					log("$$$$$$$$$$$$$$$$ Final TotalPossibleMatchMoney = "$TotalPossibleMatchMoney,'Debug');
				EndGame(None,"TimeLimit");
				return;
			}
			else if( WaveNum == (FinalWave + 1) && bUseEndGameBoss )
			{
				if( bDebugMoney )
					log("$$$$$$$$$$$$$$$$ Final TotalPossibleMatchMoney = "$TotalPossibleMatchMoney,'Debug');
				EndGame(None,"TimeLimit");
				return;
			}

			WaveCountDown--;
			if ( !CalmMusicPlaying )
			{
				InitMapWaveCfg();
				StartGameMusic(False);
			}

			// Open Trader doors
			if ( !bTradingDoorsOpen && WaveNum != InitialWave )
			{
				bTradingDoorsOpen=true;
            	OpenShops();
			}
			// Select a shop if one isn't open
            if ( KFGameReplicationInfo(GameReplicationInfo).CurrentShop == none )
                SelectShop();

			KFGameReplicationInfo(GameReplicationInfo).TimeToNextWave = WaveCountDown;
			// Have Trader tell players that they've got 30 seconds
			if ( WaveCountDown == 30 )
			{
				for ( C = Level.ControllerList; C != None; C = C.NextController )
					if ( KFPlayerController(C) != None )
						KFPlayerController(C).ClientLocationalVoiceMessage(C.PlayerReplicationInfo, none, 'TRADER', 4);
			}
			// Have Trader tell players that they've got 10 seconds
			else if ( WaveCountDown == 10 )
			{
				for ( C = Level.ControllerList; C != None; C = C.NextController )
					if ( KFPlayerController(C) != None )
						KFPlayerController(C).ClientLocationalVoiceMessage(C.PlayerReplicationInfo, none, 'TRADER', 5);
			}
			else if ( WaveCountDown == 5 )
			{
				KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonstersOn=false;
				InvasionGameReplicationInfo(GameReplicationInfo).WaveNumber = WaveNum;
			}
			else if ( (WaveCountDown > 0) && (WaveCountDown < 5) )
			{
				if( WaveNum == FinalWave && bUseEndGameBoss )
				    BroadcastLocalizedMessage(class'KFMod.WaitingMessage', 3);
				else
                    BroadcastLocalizedMessage(class'KFMod.WaitingMessage', 1);
			}
			else if ( WaveCountDown <= 1 )
			{
				bWaveInProgress = true;
				KFGameReplicationInfo(GameReplicationInfo).bWaveInProgress = true;

				// Randomize the ammo pickups again
				if( WaveNum > 0 )
					SetupPickups();

				if( WaveNum == FinalWave && bUseEndGameBoss )
				    StartWaveBoss();
				else
				{
					SetupWave();

					for ( C = Level.ControllerList; C != none; C = C.NextController )
					{
						if ( PlayerController(C) != none )
						{
							PlayerController(C).LastPlaySpeech = 0;
							if ( KFPlayerController(C) != none )
								KFPlayerController(C).bHasHeardTraderWelcomeMessage = false;
						}

						if ( Bot(C) != none )
						{
							B = Bot(C);
							InvasionBot(B).bDamagedMessage = false;
							B.bInitLifeMessage = false;
							if ( !bOneMessage && (FRand() < 0.65) )
							{
								bOneMessage = true;
								if ( (B.Squad.SquadLeader != None) && B.Squad.CloseToLeader(C.Pawn) )
								{
									B.SendMessage(B.Squad.SquadLeader.PlayerReplicationInfo, 'OTHER', B.GetMessageIndex('INPOSITION'), 20, 'TEAM');
									B.bInitLifeMessage = false;
								}
							}
						}
					}
			    }
		    }
		}
	}
	//----------------------------------------------------------------------------------------------
	function BeginState()
	{
		Super.BeginState();
		WaveNum = InitialWave;
		InvasionGameReplicationInfo(GameReplicationInfo).WaveNumber = WaveNum;
		// Ten second initial countdown. Modify to make it take long for zeds to spawn initially
		WaveCountDown = 10;
		SetupPickups();
	}
	//----------------------------------------------------------------------------------------------
	function EndState()
	{
		local Controller C;
		Super.EndState();

		// Tell all players to stop showing the path to the trader
		for( C=Level.ControllerList; C!=None; C=C.NextController )
			if( C.Pawn!=None && C.Pawn.Health>0 )
				if( KFPlayerController(C) !=None )
					KFPlayerController(C).SetShowPathToTrader(false);
	}
}
//--------------------------------------------------------------------------------------------------
// Обработка резистов монстров + считаем очки при bWaveFundSystem
function int ReduceDamage(int Damage, pawn injured, pawn instigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
	local int i,n;
	local KFMonster M;
	local MCMonsterInfo MonInfo;
	local MCRepInfo tMCRepInfo;
	local bool lDebug;
	lDebug=false;

	if (lDebug) toLog("ReduceDamage() Original Damage:"@Damage);
	M = KFMonster(Injured);
	if (M!=none)
		MonInfo = SandboxController.GetMonInfo(M.Controller);
	if (MonInfo!=none)
	{
		n = MonInfo.Resist.Length;
		for(i=0; i<n; i++)
		{
			if ( MonInfo.Resist[i].DamType == DamageType
				|| (!MonInfo.Resist[i].bNotCheckChild
					&& ClassIsChildOf( DamageType, MonInfo.Resist[i].DamType) ) )
			{
				Damage = round(float(Damage) * MonInfo.Resist[i].Coeff);
				if (lDebug) toLog("ReduceDamage() Reduced Damage:"@Damage@"MonInfo"@string(MonInfo.Name));
				break;
			}
		}
	}
	Damage = Super.ReduceDamage(Damage,injured,instigatedBy,HitLocation,Momentum,DamageType);
	
	// добавляем очки игроку (если bWaveFundSystem)
	if (SandboxController.bWaveFundSystem)
	{
		if (M!=none
			&& instigatedBy.PlayerReplicationInfo != none
			&& PlayerController(instigatedBy.Controller) != none)
		{
			tMCRepInfo = SandboxController.GetMCRepInfo(instigatedBy.PlayerReplicationInfo);
			if (tMCRepInfo!=none)
			{
				tMCRepInfo.WaveScore+=Damage;
				tMCRepInfo.GameScore+=Damage;
			}
		}
	}
	return Damage;
}
//--------------------------------------------------------------------------------------------------
/* Функция переопределена для правильной работы KillMessages (если монстр имеет MonsterInfo, 
 * то высвечивается его имя)																		*/
function Killed(Controller Killer, Controller Killed, Pawn KilledPawn, class<DamageType> damageType)
{
	local Controller C;
	local KFMonster M;
	local MCMonsterInfo MI;
	local MCRepInfo RInfo;

	M = KFMonster(KilledPawn);
	if (M!=none && PlayerController(Killer) != none && Killer.PlayerReplicationInfo != none && SandboxController!=none )
	{
		MI = SandboxController.GetMonInfo(Killed);
		if (MI==none)
			SandboxController.LM("Killed KillMessages - MonserInfo not found for"@string(KilledPawn.Name));

		if( SandboxController.BroadcastKillmessagesMass < M.Mass
			|| SandboxController.BroadcastKillmessagesHealth < M.HealthMax)
		{
			for( C=Level.ControllerList; C!=None; C=C.nextController )
				if( C.bIsPlayer && PlayerController(C) != none && C.PlayerReplicationInfo != none )
				{
					if (MI==none)
						PlayerController(C).ReceiveLocalizedMessage(Class'KillsMessage',1,Killer.PlayerReplicationInfo,,KilledPawn.Class);
					else
					{
						//SandboxController.LM("Broadcast KillMessage for:"@C.PlayerReplicationInfo.PlayerName);
						RInfo = SandboxController.GetMCRepInfo(C.PlayerReplicationInfo);
						if (RInfo!=none)
							RInfo.ClientKilledMonster(string(MI.Name), Killer.PlayerReplicationInfo);
						else
							SandboxController.LM("Killed->KillMessage for Monster:"@MI.MonsterName@"RInfo not found for"@C.PlayerReplicationInfo.PlayerName);
					}
				}
		}
		else
		{
			if (MI==none)
				xPlayer(Killer).ReceiveLocalizedMessage(Class'KillsMessage',,,,KilledPawn.Class);
			else
			{
				RInfo = SandboxController.GetMCRepInfo(Killer.PlayerReplicationInfo);
				if (RInfo!=none)
					RInfo.ClientKilledMonster(string(MI.Name));
				else
					SandboxController.LM("Killed->KillMessage for Monster:"@MI.MonsterName@"RInfo not found for"@Killer.PlayerReplicationInfo.PlayerName);
			}
		}
	}
	Super.Killed(Killer,Killed,KilledPawn,damageType);
}
//--------------------------------------------------------------------------------------------------
function toLog(string Mess, optional Object Sender)
{
	if ( Sender == none )
		Sender = Self;
	if (SandboxController!=none)
		SandboxController.ToLog(Mess,Sender);
	else
		Log(string(Sender.Name)$"->"$Mess);
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
// Функции, скопированные чисто для дебага и логов, удалить в финальной версии
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
defaultproperties
{
	bReady = false
	rewardFlag = false
	WaveNumClasses = 0
}