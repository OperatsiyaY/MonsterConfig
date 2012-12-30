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

var MonsterConfig			SandboxController;
var MCWaveInfo				CurWaveInfo; // инфо о текущей волне
var array<MCSquadInfo>		Squads, SpecSquads;// сквады для текущей волны
var array<MCSquadInfo>		SquadsToPick;	 // рабочий массив отрядов из него дергаем рандомно
var array<MCMonsterInfo>	SquadToSpawn; // текущий отряд (массив MonsterInfo)
var MCSquadInfo				CurrentSquad; // текущий отряд
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

	toLog("InitGame");

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

	toLog("InitGame->ZedSpawnList count:"@ZedSpawnList.Length);

	//provide default rules if mapper did not need custom one
	if(KFLRules==none)
		KFLRules = spawn(class'KFLevelRules');

	log("KFLRules = "$KFLRules);

	InOpt = ParseOption(Options, "UseBots");
	if ( InOpt != "" )
	{
		bNoBots = bool(InOpt);
	}

    bCustomGameLength = true;
}
//--------------------------------------------------------------------------------------------------
 // Вызывается в SandboxController.PostBeginPlay()
function PostInit(MonsterConfig Sender)
{
	toLog("PostInit");
	SandboxController = Sender;

	// Инициализация
	FinalWave = SandboxController.Waves.Length;
	toLog("PostInit->FinalWave:"@FinalWave);

	bReady = true;
}
//--------------------------------------------------------------------------------------------------
function SetupWave()
{
	local int i,j;
	toLog("SetupWave");
	TraderProblemLevel = 0; // Для дебага выкидывания игроков из магаза
	ZombiesKilled = 0; // Мобы убитые за волну
	WaveMonsters = 0; // Мобы, заспавненные за волну
//	rewardFlag = false; // выдавать ли деньги за победу, команде
//	WaveNumClasses = 0; // количество классов для спавна рандомного моба, функция AddMonster
//	TotalMaxMonsters - задаём в своей функции
//	MaxMonsters - задаём в своей функции
	WaveEndTime = Level.TimeSeconds + 255; // очень странная переменная, непонятно на что влияет
	AdjustedDifficulty = GameDifficulty; // Ни на что не влияет

	j = ZedSpawnList.Length;
	for( i=0; i<j; i++ )
		ZedSpawnList[i].Reset();

	MCSetupWave();
	// BuildNextSquad(); // Будет вызываться в AddSquad() Трипы ламеры, он тут не нужен
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
	CurWaveInfo = GetNextWaveInfo(CurWaveInfo);
	toLog("MCSetupWave->CurWaveInfo:"@string(CurWaveInfo.Name));

	WaveNum = GetWaveNum(CurWaveInfo) - 1;
	InvasionGameReplicationInfo(GameReplicationInfo).WaveNumber = WaveNum;

	FinalWave = SandboxController.Waves.Length;
	toLog("MCSetupWave->FinalWave="@FinalWave);

	PlayersCount = SandboxController.GetNumPlayers(true);
	toLog("MCSetupWave->PlayersCount="@PlayersCount);

	// ставим время между волнами
	TimeBetweenWaves = SandboxController.MapInfo.TimeBetweenWaves;
	// узнаем время между волнами для следующей волны
	tWaveInfo = GetNextWaveInfo(CurWaveInfo);
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
	local int i,n;
	SpecSquads.Remove(0,SpecSquads.Length);

	n = CurWaveInfo.SpecialSquad.Length;
	for(i=0; i<n; i++)
	{
		SpecSquads.Insert(0,1);
		SpecSquads[0] = SandboxController.GetSquad(CurWaveInfo.SpecialSquad[i]);
		SpecSquads[0].Counter = SpecSquads[0].InitialCounter;
		SpecSquads[0].CurFreq = SpecSquads[0].Freq + Rand(SpecSquads[0].FreqRand+1);
	}

	toLog("PrepareSpecSquads()->SpecSquads count"@SpecSquads.Length);
}
//--------------------------------------------------------------------------------------------------
function bool AddSquad()
{
	local int numspawned;
	local int ZombiesAtOnceLeft;
	local int TotalZombiesValue;
	local int i,n;

	toLog("AddSquad() bGameEnded"@bGameEnded);

	if( LastZVol == none || SquadToSpawn.Length == 0 )
	{
		CurrentSquad = GetSpecialSquad();
		if ( CurrentSquad == none )
		{
			CurrentSquad = GetRandomSquad();
			CurrentSquad.bSpecialSquad = false;
		}
		else
		{
			toLog("AddSquad()->Will spawn special squad");
			CurrentSquad.bSpecialSquad = true;
		}
		SquadToMonsters(CurrentSquad,SquadToSpawn);

		LastZVol = FindSpawningVolume();
		if( LastZVol != None )
			LastSpawningVolume = LastZVol;
	}
	toLog("AddSquad()->CurrentSquad:"@string(CurrentSquad.Name)@"("$SquadToSpawn.Length$" monsters)");

	if( LastZVol == None )
	{
		toLog("AddSquad()-> No ZombieVolume's found. So just return.");

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
    ZombiesAtOnceLeft = MaxMonsters - NumMonsters;
	toLog("AddSquad()->We can spawn only ZombiesAtOnceLeft:"@ZombiesAtOnceLeft@"(MaxMonsters:"@MaxMonsters@"NumMonsters:"@NumMonsters@")");

	if( MCZombieVolume(LastZVol).MCSpawnInHere(
		SquadToSpawn,		// out массив MCMonsterInfo для спавна
		,					// bTest если true лишь возвращает возможность заспавнить монстров тут
		numspawned,			// out int возвращает количество заспавленых монстров
		TotalMaxMonsters,	// out TotalMaxMonsters
		ZombiesAtOnceLeft,	// int MaxMonstersAtOnceLeft
		TotalZombiesValue,	// out int TotalZombiesValue
		false) )			// bTryAllSpawns - если false, делает только 3 попытки спавна,
							// если true - пытается заспавнить во всех SpawnPoints волума
							// TODO - ставить тут true?
	{
		// спецсквады не считаются
		toLog("AddSquad()->ZombiesSpawned:"@numspawned);
		NumMonsters += numspawned;
		WaveMonsters+= numspawned;


		// TODO хак, чтобы не переписывать ВЕСЬ ТАЙМЕР!!!! так как в нем идет проверка
		// на nextSpawnSquad.Length если отрят не смог заспавниться полностью, то NextSpawnTime ставится +0.1
		// и остальные мобы спавнятся почти сразу, а не через стандартные CalcNextSquadSpawnTime();
		// можно наш массив SquadToSpawn обозвать по ихнему, но компилятор будет каждый раз ругаться
		// на обфускацию
		// можно даже заполнять его class<KFMonster>, взятыми из SquadToSpawn, если нужно
		nextSpawnSquad.Length = SquadToSpawn.Length;

		// перенесено внутрь MCSpawnInHere - там мы удаляем именно тех, кого получилось заспавнить,
		// а не первых numspawned в массиве
		// SquadToSpawn.Remove(0, numspawned);

		// обновляем counter'ы для SpecSquads
		n = SpecSquads.Length;
		for(i=0; i<n; i++)
			SpecSquads[i].Counter += numspawned;

    	return true;
    }
    else
    {
		toLog("AddSquad()->ZombiesSpawned: 0. So call TryToSpawnInAnotherVolume()");
        TryToSpawnInAnotherVolume();
        return false;
    }
}
//--------------------------------------------------------------------------------------------------
function MCSquadInfo GetSpecialSquad()
{
	local int i,n;
	n = SpecSquads.Length;
	for(i=0; i<n; i++)
	{
		if ( SpecSquads[i].CurFreq <= SpecSquads[i].Counter/* + SpecSquads[i].InitialCounter*/ )
		{
			SpecSquads[i].Counter = 0;
			SpecSquads[i].CurFreq = SpecSquads[i].Freq + Rand(SpecSquads[i].FreqRand+1);
			toLog("GetSpecialSquad()->Returning"@string(SpecSquads[i].Name));
			return SpecSquads[i];
		}
	}
	toLog("GetSpecialSquad()->Returning"@none);
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

	n = Rand(SquadsToPick.Length-1);
	Ret = SquadsToPick[n];
	SquadsToPick.Remove(n,1);

	return Ret;
}
//--------------------------------------------------------------------------------------------------
// заполняем массив SquadsToPick, из которого будем дёргать CurrentSquad'ы
function SquadsToPickFill()
{
	local int i;
	SquadsToPick.Remove(0,SquadsToPick.Length);

	i = Squads.Length;
	while ( i-- > 0 )
	{
		SquadsToPick.Insert(0,1);
		SquadsToPick[0] = Squads[i];
	}

	toLog("SquadsToPickFill()->SquadsToPick count:"@SquadsToPick.Length);
}
//--------------------------------------------------------------------------------------------------
function bool SquadToMonsters(MCSquadInfo CurSquad, out array<MCMonsterInfo> Ret)
{
	local int i,n,c,j;
	local MCMonsterInfo CurMon;
	Ret.Remove(0,Ret.Length);

	toLog("SquadToMonsters()->CurSquad"@string(CurSquad.Name));

	n = CurSquad.Monster.Length;
	if ( n <= 0 )
	{
		toLog("SquadToMonsters()->CurSquad: no monsters specified. Squad:"@string(CurSquad.Name));
		return false;
	}

	for(i=0; i<n; i++)
	{
		CurMon = SandboxController.GetMonster(CurSquad.Monster[i].MonsterName);
		for(j=CurSquad.Monster[i].Num; j>0; j--)
			Ret[c++] = CurMon;
	}
	toLog("SquadToMonsters()->Returning"@Ret.Length@"monsters");

	// TODO хак, чтобы не переписывать ВЕСЬ ТАЙМЕР!!!! так как в нем идет проверка
	// на nextSpawnSquad.Length если отрят не смог заспавниться полностью, то NextSpawnTime ставится +0.1
	// и остальные мобы спавнятся почти сразу, а не через стандартные CalcNextSquadSpawnTime();
	// можно наш массив SquadToSpawn обозвать по ихнему, но компилятор будет каждый раз ругаться
	// на обфускацию
	nextSpawnSquad.Length = SquadToSpawn.Length;

	return true;
}
//--------------------------------------------------------------------------------------------------
//function bool AddBoss();
//function AddBossBuddySquad();
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
			tMonsterInfo = SandboxController.GetMonInfo(KFMonster(Other.Pawn), Other);

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
    /* Begin Marco's Kill Messages DELETED */
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

		SandboxController.WaveEnd();
		//DeadMonsters.Remove(0,DeadMonsters.Length);
		//AliveMonsters.Remove(0,AliveMonsters.Length);
	}
	//----------------------------------------------------------------------------------------------
	// определяем через какое время спавнить монстров
	// Функция используется в Timer'е:
	// NextMonsterTime = Level.TimeSeconds + CalcNextSquadSpawnTime();
	function float CalcNextSquadSpawnTime()
	{
		local float NextSpawnTime;
		local float SineMod, F, F2, F3;

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

		toLog("CalcNextSquadSpawnTime()->WaveTimeElapsed:"@WaveTimeElapsed@"SineMod:"@SineMod@"NextSpawnTime:"@NextSpawnTime);

		return NextSpawnTime;
	}
	//--------------------------------------------------------------------------------------------------
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

	// только для отладки. удалить TODO
	function bool UpdateMonsterCount() // To avoid invasion errors.
	{
		local Controller C;
		local int i,j;

		For( C=Level.ControllerList; C!=None; C=C.NextController )
		{
			if( C.Pawn!=None && C.Pawn.Health>0 )
			{
				if( Monster(C.Pawn)!=None )
					i++;
				else j++;
			}
		}
		NumMonsters = i;
		Return (j>0);
	}

	function Timer()
	{
		local Controller C;
		local bool bOneMessage;
		local Bot B;

		Global.Timer();

		if ( Level.TimeSeconds > HintTime_1 && bTradingDoorsOpen && bShowHint_2 )
		{
			for ( C = Level.ControllerList; C != None; C = C.NextController )
			{
				if( C.Pawn != none && C.Pawn.Health > 0 )
				{
					KFPlayerController(C).CheckForHint(32);
					HintTime_2 = Level.TimeSeconds + 11;
				}
			}

			bShowHint_2 = false;
		}

		if ( Level.TimeSeconds > HintTime_2 && bTradingDoorsOpen && bShowHint_3 )
		{
			for ( C = Level.ControllerList; C != None; C = C.NextController )
			{
				if( C.Pawn != None && C.Pawn.Health > 0 )
				{
					KFPlayerController(C).CheckForHint(33);
				}
			}

			bShowHint_3 = false;
		}

		if ( !bFinalStartup )
		{
			bFinalStartup = true;
			PlayStartupMessage();
		}
		if ( NeedPlayers() && AddBot() && (RemainingBots > 0) )
			RemainingBots--;
		ElapsedTime++;
		GameReplicationInfo.ElapsedTime = ElapsedTime;
		if( !UpdateMonsterCount() )
		{
			EndGame(None,"TimeLimit");
			Return;
		}

		if( bUpdateViewTargs )
			UpdateViews();

		if (!bNoBots && !bBotsAdded)
		{
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

		if( bWaveBossInProgress )
		{
			// Close Trader doors
			if( bTradingDoorsOpen )
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
			if( !bHasSetViewYet && TotalMaxMonsters<=0 && NumMonsters>0 )
			{
				bHasSetViewYet = True;
				for ( C = Level.ControllerList; C != None; C = C.NextController )
					if ( C.Pawn!=None && KFMonster(C.Pawn)!=None && KFMonster(C.Pawn).MakeGrandEntry() )
					{
						ViewingBoss = KFMonster(C.Pawn);
						Break;
					}
				if( ViewingBoss!=None )
				{
					ViewingBoss.bAlwaysRelevant = True;
					for ( C = Level.ControllerList; C != None; C = C.NextController )
					{
						if( PlayerController(C)!=None )
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
			else if( ViewingBoss!=None && !ViewingBoss.bShotAnim )
			{
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
			if( TotalMaxMonsters<=0 || (Level.TimeSeconds>WaveEndTime) )
			{
				// if everyone's spawned and they're all dead
				if ( NumMonsters <= 0 )
					DoWaveEnd();
			}
			else AddBoss();
		}
		else if(bWaveInProgress)
		{
			WaveTimeElapsed += 1.0;

			// Close Trader doors
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
			if(!MusicPlaying)
				StartGameMusic(True);

			if( TotalMaxMonsters<=0 )
			{
				if ( NumMonsters <= 5 /*|| Level.TimeSeconds>WaveEndTime*/ )
				{
					for ( C = Level.ControllerList; C != None; C = C.NextController )
						if ( KFMonsterController(C)!=None && KFMonsterController(C).CanKillMeYet() )
						{
							C.Pawn.KilledBy( C.Pawn );
							Break;
						}
				}
				// if everyone's spawned and they're all dead
				if ( NumMonsters <= 0 )
				{
                    DoWaveEnd();
				}
			} // all monsters spawned
			else if ( (Level.TimeSeconds > NextMonsterTime) && (NumMonsters+NextSpawnSquad.Length <= MaxMonsters) )
			{
				WaveEndTime = Level.TimeSeconds+160;
				if( !bDisableZedSpawning )
				{
                    AddSquad(); // Comment this out to prevent zed spawning
                }

				if(nextSpawnSquad.length>0)
				{
                	NextMonsterTime = Level.TimeSeconds + 0.2;
				}
				else
                {
                    NextMonsterTime = Level.TimeSeconds + CalcNextSquadSpawnTime();
                }
  			}
		}
		else if ( NumMonsters <= 0 )
		{
			if ( WaveNum == FinalWave && !bUseEndGameBoss )
			{
				if( bDebugMoney )
				{
					log("$$$$$$$$$$$$$$$$ Final TotalPossibleMatchMoney = "$TotalPossibleMatchMoney,'Debug');
				}

				EndGame(None,"TimeLimit");
				return;
			}
			else if( WaveNum == (FinalWave + 1) && bUseEndGameBoss )
			{
				if( bDebugMoney )
				{
					log("$$$$$$$$$$$$$$$$ Final TotalPossibleMatchMoney = "$TotalPossibleMatchMoney,'Debug');
				}

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
			if ( WaveNum != InitialWave && !bTradingDoorsOpen )
			{
            	OpenShops();
			}

			// Select a shop if one isn't open
            if (	KFGameReplicationInfo(GameReplicationInfo).CurrentShop == none )
            {
                SelectShop();
            }

			KFGameReplicationInfo(GameReplicationInfo).TimeToNextWave = WaveCountDown;
			if ( WaveCountDown == 30 )
			{
				for ( C = Level.ControllerList; C != None; C = C.NextController )
				{
					if ( KFPlayerController(C) != None )
					{
						// Have Trader tell players that they've got 30 seconds
						KFPlayerController(C).ClientLocationalVoiceMessage(C.PlayerReplicationInfo, none, 'TRADER', 4);
					}
				}
			}
			else if ( WaveCountDown == 10 )
			{
				for ( C = Level.ControllerList; C != None; C = C.NextController )
				{
					if ( KFPlayerController(C) != None )
					{
						// Have Trader tell players that they've got 10 seconds
						KFPlayerController(C).ClientLocationalVoiceMessage(C.PlayerReplicationInfo, none, 'TRADER', 5);
					}
				}
			}
			else if ( WaveCountDown == 5 )
			{
				KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonstersOn=false;
				InvasionGameReplicationInfo(GameReplicationInfo).WaveNumber = WaveNum;
			}
			else if ( (WaveCountDown > 0) && (WaveCountDown < 5) )
			{
				if( WaveNum == FinalWave && bUseEndGameBoss )
				{
				    BroadcastLocalizedMessage(class'KFMod.WaitingMessage', 3);
				}
				else
				{
                    BroadcastLocalizedMessage(class'KFMod.WaitingMessage', 1);
                }
			}
			else if ( WaveCountDown <= 1 )
			{
				bWaveInProgress = true;
				KFGameReplicationInfo(GameReplicationInfo).bWaveInProgress = true;

				// Randomize the ammo pickups again
				if( WaveNum > 0 )
				{
					SetupPickups();
				}

				if( WaveNum == FinalWave && bUseEndGameBoss )
				{
				    StartWaveBoss();
				}
				else
				{
					SetupWave();

					for ( C = Level.ControllerList; C != none; C = C.NextController )
					{
						if ( PlayerController(C) != none )
						{
							PlayerController(C).LastPlaySpeech = 0;

							if ( KFPlayerController(C) != none )
							{
								KFPlayerController(C).bHasHeardTraderWelcomeMessage = false;
							}
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

	function BeginState()
	{
		Super.BeginState();

		WaveNum = InitialWave;
		InvasionGameReplicationInfo(GameReplicationInfo).WaveNumber = WaveNum;

		// Ten second initial countdown
		WaveCountDown = 10;// Modify this if we want to make it take long for zeds to spawn initially

		SetupPickups();
	}

	function EndState()
	{
		local Controller C;

		Super.EndState();

		// Tell all players to stop showing the path to the trader
		For( C=Level.ControllerList; C!=None; C=C.NextController )
		{
			if( C.Pawn!=None && C.Pawn.Health>0 )
			{
				if( KFPlayerController(C) !=None )
				{
					KFPlayerController(C).SetShowPathToTrader(false);
				}
			}
		}
	}
}
//--------------------------------------------------------------------------------------------------
// Достаёт из массива следующую за текущей волну, если текущая волна последняя, возвращает none
// используется в MCSetupWave:  CurWaveInfo = GetNextWaveInfo(CurWaveInfo);
function MCWaveInfo GetNextWaveInfo(MCWaveInfo CurWave)
{
	return SandboxController.GetNextWaveInfo(CurWave);
}
//--------------------------------------------------------------------------------------------------
// Считает коэффициент дамага монстру исходя из MonsterInfo->Resist
function int ReduceDamage(int Damage, pawn injured, pawn instigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
	local int i,n;
	local KFMonster M;
	local MCMonsterInfo MonInfo;
	local MCRepInfo tMCRepInfo;

	toLog("ReduceDamage()->Orig:"@Damage);
	M = KFMonster(Injured);
	if (M!=none)
		MonInfo = SandboxController.GetMonInfo(M, M.Controller);
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
				toLog("ReduceDamage()->Reduced:"@Damage@"MonInfo"@string(MonInfo.Name));
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
/*// Заполняем массив AliveMonsters, для сопоставления Monster и его MonsterInfo (для ReduceDamage)
function NotifyMonsterSpawn(KFMonster Mon, MCMonsterInfo MonInfo)
{
	local int n;
	n = AliveMonsters.Length;
	toLog("NotifyMonsterSpawn()"@string(MonInfo.Name));
	AliveMonsters.Insert(n,1);
	AliveMonsters[n].Mon		= Mon;
	AliveMonsters[n].Controller = Mon.Controller;
	AliveMonsters[n].MName		= Mon.Name;
	AliveMonsters[n].MonType	= MonInfo;
}*/
//--------------------------------------------------------------------------------------------------
function Killed(Controller Killer, Controller Killed, Pawn KilledPawn, class<DamageType> damageType)
{
	//local int i;
	local Controller C;
	local KFMonster M;
	local MCMonsterInfo MI;

	M = KFMonster(KilledPawn);
	if (M!=none)
	{
		//GetAliveMonsterInfo(M, Killed);
		MI = SandboxController.GetMonInfo(KFMonster(KilledPawn), Killed);
		if (MI==none)
		{
			toLog("Killed->Failed to load Killed Monsterinfo with GetAliveMonsterInfo");
		}
		else if (MI!=none)
		{
			/* Begin Marco's Kill Messages */

			if( Class'HUDKillingFloor'.Default.MessageHealthLimit<=M.HealthMax
				|| Class'HUDKillingFloor'.Default.MessageMassLimit<=M.Mass )
			{
				for( C=Level.ControllerList; C!=None; C=C.nextController )
					if( C.bIsPlayer && xPlayer(C)!=None )
					{
						toLog("ScoreKill->KillMessage for"@MI.MNameObj.MonsterName);
						xPlayer(C).ReceiveLocalizedMessage(Class'MCKillsMessage',1,Killer.PlayerReplicationInfo, M.PlayerReplicationInfo,MI.MNameObj);
					}
			}
			else
				if( xPlayer(Killer)!=None )
				{
					toLog("ScoreKill->KillMessage for"@MI.MNameObj.MonsterName);
					xPlayer(Killer).ReceiveLocalizedMessage(Class'MCKillsMessage',,, M.PlayerReplicationInfo,MI.MNameObj);
				}
			/* End Marco's Kill Messages */
			 
			SandboxController.NotifyMonsterKill(M, Killed);

			/*DeadMonsters.Insert(0,1);
			DeadMonsters[0].Mon = M;
			DeadMonsters[0].Controller = Killed;
			DeadMonsters[0].MName = M.Name;

			SandboxController.MList.Del(M); // реплицируемый массив для LinkMesh на стороне клиента
			*/
		}

		/*i = GetAliveMonsterIndex(M, Killed);
		if ( i != -1 )
		{
			toLog("Tick->Clearing AliveMonsters for Monster:"@GetAliveMonsterInfo(M, Killed).MonsterName);
			AliveMonsters.Remove(i,1);
		}*/
	}
	Super.Killed(Killer,Killed,KilledPawn,damageType);
}
//--------------------------------------------------------------------------------------------------
function Tick( float dt )
{
	//local int i,j;
	Super.Tick(dt);

	/*for (i=0;i<DeadMonsters.Length;i++)
	{
		j = GetAliveMonsterIndex(DeadMonsters[i].Controller, DeadMonsters[i].Mon, DeadMonsters[i].MName);
		if ( j != -1 )
		{
			toLog("Tick->Clearing AliveMonsters for Monster:"@GetAliveMonsterInfo(DeadMonsters[i].Controller, DeadMonsters[i].Mon).MonsterName);
			AliveMonsters.Remove(j,1);
		}
		else
			toLog("Tick->DeadMonsters cleanup = bad condition");
		DeadMonsters.Remove(i,1);
	}*/
}
//--------------------------------------------------------------------------------------------------
/*function MCMonsterInfo GetAliveMonsterInfo(Actor A, optional Actor B)
{
	local int i,n;
	local Controller C;
	local KFMonster	 M;

	C = Controller(A);
	if (C==none)
		C = Controller(B);
	M = KFMonster(A);
	if (M==none)
		M = KFMonster(B);

	if (C!=none || M!=none)
	{
		n = AliveMonsters.Length;
		for(i=0; i<n; i++)
			if ( (M !=none && AliveMonsters[i].Mon == M)
				|| (C != none && AliveMonsters[i].Controller == C) )
				return AliveMonsters[i].MonType;
	}
	toLog("GetAliveMonsterInfo->Failed");
	return none;
}*/
//--------------------------------------------------------------------------------------------------
// Используется в ReduceDamage для сопоставления Монстра к его MonsterInfo (нужны коэффициенты)
/*function int GetAliveMonsterIndex(Actor A, optional Actor B, optional Name MName)
{
	local int i,n;
	local Controller C;
	local KFMonster	 M;

	C = Controller(A);
	if (C==none)
		C = Controller(B);
	M = KFMonster(A);
	if (M==none)
		M = KFMonster(B);

	if (C!=none || M!=none || Len(MName)>0 )
	{
		n = AliveMonsters.Length;
		for(i=0; i<n; i++)
		{
			if ( (M !=none && AliveMonsters[i].Mon == M)
				||(C != none && AliveMonsters[i].Controller == C) )
				return i;
			if( MName == AliveMonsters[i].MName )
			{
				toLog("GetAliveMonsterIndex->Found by MName <------");
				return i;
			}
		}
	}
	toLog("GetAliveMonsterIndex->Failed");
	return -1;
}*/
//--------------------------------------------------------------------------------------------------
function ToLog(string Mess, optional Object Sender)
{
	if ( Sender == none )
		Sender = Self;
	if (SandboxController!=none)
		SandboxController.ToLog(Mess,Sender);
	else
		Log(string(Sender.Name)$"->"$Mess);
}
//--------------------------------------------------------------------------------------------------
// Функции, скопированные чисто для дебага и логов, удалить в финальной версии
//--------------------------------------------------------------------------------------------------

// Force slomo for a longer period of time when the boss dies
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

    num = NumMonsters;

    c = Level.ControllerList;

    // turn off all the other zeds so they don't attack the player
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
//--------------------------------------------------------------------------------------------------
// Скопировано из KFGameType для отладки и логов, ничего не менялось, удалить в финале
function ZombieVolume FindSpawningVolume(optional bool bIgnoreFailedSpawnTime, optional bool bBossSpawning)
{
	local ZombieVolume BestZ;
	local float BestScore,tScore;
	local int i,l;
	local Controller C;
	local array<Controller> CL;

	// First pass, pick a random player.
	for( C=Level.ControllerList; C!=None; C=C.NextController )
	{
		if( C.bIsPlayer && C.Pawn!=None && C.Pawn.Health>0 )
			CL[CL.Length] = C;
	}
	if( CL.Length>0 )
		C = CL[Rand(CL.Length)];
	else if( C==None )
		return None; // Shouldnt get to this case, but just to be sure...

	// Second pass, figure out best spawning point.
	l = ZedSpawnList.Length;
	for( i=0; i<l; i++ )
	{
        tScore = ZedSpawnList[i].RateZombieVolume(Self,LastSpawningVolume,C,bIgnoreFailedSpawnTime, bBossSpawning);
		if( tScore<0 )
			continue;
		if( BestZ==None || (tScore>BestScore) )
		{
			BestScore = tScore;
			BestZ = ZedSpawnList[i];
		}
	}
	return BestZ;
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
defaultproperties
{
	bReady = false

	rewardFlag = false
	WaveNumClasses = 0
}