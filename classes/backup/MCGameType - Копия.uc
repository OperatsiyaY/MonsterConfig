class MCGameType extends KFGameType;

#exec obj load file="MCKillsMessage.u" Package="MonsterConfig"

struct AliveMonsterInfo
{
	var KFMonster		Mon;
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
var array<AliveMonsterInfo> AliveMonsters;	// для сопоставления с MonsterInfo в ReduceDamage
var array<KFMonster>		DeadMonsters;
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
function ScoreKill(Controller Killer, Controller Other)
{
//	local PlayerController PC;
//	local int i,n;
//	local HudBase H;
	local Controller C;
	
	local KFMonster M;
	local MCMonsterInfo MI;
	//local MCMonsterNameObj MObj;
	
	M = KFMonster(Other.Pawn);
	if (M!=none)
		MI = GetAliveMonsterInfo(M);
	if (MI!=none)
	{
		//MObj = new (None, "monobj") class'MCMonsterNameObj';
		//MObj.MonsterName = M.MenuName;

	    /* Begin Marco's Kill Messages */

        if( Class'HUDKillingFloor'.Default.MessageHealthLimit<=Other.Pawn.Default.Health
			|| Class'HUDKillingFloor'.Default.MessageMassLimit<=Other.Pawn.Default.Mass )
		{
			for( C=Level.ControllerList; C!=None; C=C.nextController )
                if( C.bIsPlayer && xPlayer(C)!=None )
                    xPlayer(C).ReceiveLocalizedMessage(Class'MCKillsMessage',1,Killer.PlayerReplicationInfo,Other.Pawn.PlayerReplicationInfo,MI.MNameObj);
        }
		else
            if( xPlayer(Killer)!=None )
                xPlayer(Killer).ReceiveLocalizedMessage(Class'MCKillsMessage',,,Other.Pawn.PlayerReplicationInfo,MI.MNameObj);
		/* End Marco's Kill Messages */
		//Level.ObjectPool.FreeObject(MObj);
	}
	
	Super.ScoreKill(Killer,Other);
}
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
	toLog("MCSetupWave");

	// TODO
	// определять свой диффикалти, для таблицы (можно кустом в тру выставить при инит)
	// если сквад заспавнился не полностью, некст спавн тайм обнулять и обновлять только после полногоспавна
	CurWaveInfo = GetNextWaveInfo(CurWaveInfo);
	toLog("MCSetupWave->CurWaveInfo:"@string(CurWaveInfo.Name));
	
	WaveNum = GetWaveNum(CurWaveInfo);
	if ( CurWaveInfo == None )
		FinalWave = WaveNum;
	else if ( GetNextWaveInfo(CurWaveInfo) == None )
		FinalWave = WaveNum + 1;

	FinalWave = SandboxController.Waves.Length;
	toLog("MCSetupWave->FinalWave="@FinalWave);
	
	PlayersCount = SandboxController.GetNumPlayers(true);
	toLog("MCSetupWave->PlayersCount="@PlayersCount);
	
	
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
		toLog("AddSquad()->ZombiesSpawned:"@numspawned);
    	NumMonsters += numspawned;
    	WaveMonsters+= numspawned;

		// перенесено внутрь MCSpawnInHere - там мы удаляем именно тех, кого получилось заспавнить,
		// а не первых numspawned в массиве
		// SquadToSpawn.Remove(0, numspawned);
		
		// TODO хак, чтобы не переписывать ВЕСЬ ТАЙМЕР!!!! так как в нем идет проверка 
		// на nextSpawnSquad.Length если отрят не смог заспавниться полностью, то NextSpawnTime ставится +0.1
		// и остальные мобы спавнятся почти сразу, а не через стандартные CalcNextSquadSpawnTime();
		// можно наш массив SquadToSpawn обозвать по ихнему, но компилятор будет каждый раз ругаться
		// на обфускацию
		nextSpawnSquad.Length = SquadToSpawn.Length;

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
		if ( SpecSquads[i].CurFreq <= SpecSquads[i].Counter + SpecSquads[i].InitialCounter )
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
state MatchInProgress
{

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
	local int index,i,n;
	local KFMonster M;
	local MCMonsterInfo MonInfo;
	toLog("ReduceDamage()->Orig:"@Damage);
	M = KFMonster(Injured);
	if (M!=none)
	{
		index = GetAliveMonsterIndex(M);
		
		if ( index != -1 )
		{
			MonInfo = AliveMonsters[index].MonType;
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
	}
	return Super.ReduceDamage(Damage,injured,instigatedBy,HitLocation,Momentum,DamageType);
}
//--------------------------------------------------------------------------------------------------
// Заполняем массив AliveMonsters, для сопоставления Monster и его MonsterInfo (для ReduceDamage)
function NotifyMonsterSpawn(KFMonster Mon, MCMonsterInfo MonInfo)
{
	toLog("NotifyMonsterSpawn()"@string(MonInfo.Name));
	AliveMonsters.Insert(0,1);
	AliveMonsters[0].Mon = Mon;
	AliveMonsters[0].MonType = MonInfo;
}
//--------------------------------------------------------------------------------------------------
function Killed(Controller Killer, Controller Killed, Pawn KilledPawn, class<DamageType> damageType)
{
	local int i;
	local KFMonster M;
	M = KFMonster(KilledPawn);
	if (M!=none)
	{
		i = GetAliveMonsterIndex(M);
		if ( i != -1 )
			AliveMonsters.Remove(i,1);
	}
	Super.Killed(Killer,Killed,KilledPawn,damageType);
}
//--------------------------------------------------------------------------------------------------
function MCMonsterInfo GetAliveMonsterInfo(KFMonster M)
{
	local int i,n;
	n = AliveMonsters.Length;
	for(i=0; i<n; i++)
		if ( AliveMonsters[i].Mon == M )
			return AliveMonsters[i].MonType;
	return none;
}
//--------------------------------------------------------------------------------------------------
// Используется в ReduceDamage для сопоставления Монстра к его MonsterInfo (нужны коэффициенты)
function int GetAliveMonsterIndex(KFMonster M)
{
	local int i,n;
	n = AliveMonsters.Length;
	for(i=0; i<n; i++)
		if ( AliveMonsters[i].Mon == M )
			return i;
	return -1;
}
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