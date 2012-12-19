class MCGameType extends KFGameType;

var bool bReady;

var MonsterConfig SandboxController;

var MCWaveInfo CurrentWaveInfo;

var array<MCSquadInfo> SquadsMain,SpecSquads,SquadsCurrent;

var array<MCMonsterInfo> SquadToSpawn;

var MCSquadInfo SelectedSquad;

struct AliveMonsterInfo
{
	var KFMonster		Mon;
	var MCMonsterInfo	MonType;
};

var array<AliveMonsterInfo> AliveMonsters;

// Disabled
function NotifyGameEvent(int EventNumIn);
function LoadUpMonsterList();
function PrepareSpecialSquads();
function UpdateGameLength();
function BuildNextSquad();
function AddSpecialSquad();

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

	//provide default rules if mapper did not need custom one
	if(KFLRules==none)
		KFLRules = spawn(class'KFLevelRules');

	log("KFLRules = "$KFLRules);

	InOpt = ParseOption(Options, "UseBots");
	if ( InOpt != "" )
	{
		bNoBots = bool(InOpt);
	}

    bCustomGameLength = false;
}

function PostInit(MonsterConfig Sender) // Вызывается, когда мутатор подготовил данные
{
	toLog("PostInit");
	SandboxController = Sender;
	// Инициализация
	
	FinalWave = 1000000;
	
	bReady = true;
}

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
	
	SetupCurrentWave();
	
//	BuildNextSquad(); //  Трипы ламеры, он тут не нужен
}

function SetupCurrentWave()
{
	local int PlayersCount;
	toLog("SetupCurrentWave");
	
	// TODO
	
	CurrentWaveInfo = GetNextWaveInfo(CurrentWaveInfo);
	
	if ( CurrentWaveInfo == None )
	{
		FinalWave = WaveNum;
	}
	else if ( GetNextWaveInfo(CurrentWaveInfo) == None )
	{
		FinalWave = WaveNum + 1;
	}
	FinalWave = SandboxController.Waves.Length;	// <-------
	
	
	PlayersCount = SandboxController.GetNumPlayers(true);
	// количество монстров за волну
	TotalMaxMonsters	= SandboxController.MonstersTotalMod * SandboxController.MapInfo.MonstersTotalCoeff
						* ( CurrentWaveInfo.MonstersTotal + CurrentWaveInfo.PerPlayer.MonstersTotal * (PlayersCount - 1) );
	// Мобы, одновременно находящиеся на карте
	MaxMonsters	= SandboxController.MonstersMaxAtOnceMod * SandboxController.MapInfo.MonstersMaxAtOnceCoeff
				* ( CurrentWaveInfo.MonstersMaxAtOnce + CurrentWaveInfo.PerPlayer.MonstersMaxAtOnce * (PlayersCount - 1) );

	KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonsters = TotalMaxMonsters;
	KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonstersOn = true;
	
	PrepareSquadsTemplate();
	PrepareSpecSquads();
//	FillCurrentSquads();
}
//--------------------------------------------------------------------------------------------------
function PrepareSquadsTemplate()
{
	local int i,n;
	toLog("PrepareSquadsTemplate()");
	SquadsMain.Remove(0,SquadsMain.Length);
	
	n = CurrentWaveInfo.Squad.Length;
	
	for(i=0; i<n; i++)
	{
		SquadsMain.Insert(0,1);
		SquadsMain[0] = SandboxController.GetSquad(CurrentWaveInfo.Squad[i]);
	}
}
//--------------------------------------------------------------------------------------------------
function PrepareSpecSquads()
{
	local int i,n;

	toLog("PrepareSpecSquads()");

	SpecSquads.Remove(0,SpecSquads.Length);
	
	n = CurrentWaveInfo.SpecialSquad.Length;
	
	for(i=0; i<n; i++)
	{
		SpecSquads.Insert(0,1);
		SpecSquads[0] = SandboxController.GetSquad(CurrentWaveInfo.SpecialSquad[i]);
		SpecSquads[0].Counter = SpecSquads[0].InitialCounter;
		SpecSquads[0].CurFreq = SpecSquads[0].Freq + Rand(SpecSquads[0].FreqRand+1);
	}
}
//--------------------------------------------------------------------------------------------------
function FillCurrentSquads()
{
	local int i;
	toLog("FillCurrentSquads()");
	SquadsCurrent.Remove(0,SquadsCurrent.Length);

	i = SquadsMain.Length;
	
	while ( i-- > 0 )
	{
		SquadsCurrent.Insert(0,1);
		SquadsCurrent[0] = SquadsMain[i];
	}
}
//--------------------------------------------------------------------------------------------------
function bool AddSquad()
{
	local int numspawned;
	local int ZombiesAtOnceLeft;
	local int TotalZombiesValue;
	local int i,n;
	
	toLog("AddSquad()");
	
	if( LastZVol == none || SquadToSpawn.Length == 0 )
	{
		SelectedSquad = GetNeededSpecSquad();

		if ( SelectedSquad == none )
			SelectedSquad = GetNeededSquad();

		FillSquads(SelectedSquad,SquadToSpawn);

		LastZVol = FindSpawningVolume();

		if( LastZVol != None )
			LastSpawningVolume = LastZVol;
	}
	
	if( LastZVol == None )
	{
		SquadToSpawn.Remove(0,SquadToSpawn.Length);
		return false;
	}
	
	// How many zombies can we have left to spawn at once
    ZombiesAtOnceLeft = MaxMonsters - NumMonsters;
	
	if( MCZombieVolume(LastZVol).MCSpawnInHere(SquadToSpawn,,numspawned,TotalMaxMonsters,ZombiesAtOnceLeft,TotalZombiesValue) )
	{
    	NumMonsters += numspawned;
    	WaveMonsters+= numspawned;

		n = SpecSquads.Length;
		for(i=0; i<n; i++)
		{
			SpecSquads[i].Counter += numspawned;
		}
		
    	SquadToSpawn.Remove(0, numspawned);

    	return true;
    }
    else
    {
        TryToSpawnInAnotherVolume();
        return false;
    }

}
//--------------------------------------------------------------------------------------------------
function MCSquadInfo GetNeededSpecSquad()
{
	local int i,n;

	n = SpecSquads.Length;
	for(i=0; i<n; i++)
	{
		if ( SpecSquads[i].Counter >= SpecSquads[i].CurFreq )
		{
			SpecSquads[i].Counter = 0;
			SpecSquads[i].CurFreq = SpecSquads[i].Freq + Rand(SpecSquads[i].FreqRand+1);
			return SpecSquads[i];
		}
	}
	return none;
}
//--------------------------------------------------------------------------------------------------
function MCSquadInfo GetNeededSquad()
{
	local int n;
	local MCSquadInfo Ret;

	if ( SquadsCurrent.Length <= 0 )
		FillCurrentSquads();

	n = Rand(SquadsCurrent.Length-1);
	Ret = SquadsCurrent[n];
	SquadsCurrent.Remove(n,1);

	return Ret;
}
//--------------------------------------------------------------------------------------------------
function bool FillSquads(MCSquadInfo CurSquad, out array<MCMonsterInfo> Ret)
{
	local int i,n,c,j;
	local MCMonsterInfo CurMon;
	
	Ret.Remove(0,Ret.Length);
	
	n = CurSquad.Monster.Length;
	
	if ( n <= 0 )
		return false;
	
	c = 0;

	for(i=0; i<n; i++)
	{
		CurMon = SandboxController.GetMonster(CurSquad.Monster[i].MonsterName);
		for(j=CurSquad.Monster[i].Num; j>0; j--)
		{
			Ret[c++] = CurMon;
		}
	}
	
	return true;
}
//--------------------------------------------------------------------------------------------------
//function bool AddBoss();
//function AddBossBuddySquad();
//--------------------------------------------------------------------------------------------------
state MatchInProgress
{
	function float CalcNextSquadSpawnTime() // частота респов мобов
	{
		local float NextSpawnTime;
		local float SineMod;

		SineMod = 1.0 - Abs(sin(WaveTimeElapsed * SineWaveFreq));

		//NextSpawnTime = KFLRules.WaveSpawnPeriod;
        NextSpawnTime = CurrentWaveInfo.DelayBetweenSquads * SandboxController.MapInfo.DelayBetweenSquadsCoeff
						* ( ( SandboxController.GetNumPlayers(true) - 1 ) * SandboxController.MapInfo.PerPlayer.DelayBetweenSquadsCoeff );
		
		NextSpawnTime += SineMod * (NextSpawnTime * 2);

		return NextSpawnTime;
	}
	//--------------------------------------------------------------------------------------------------
	function InitMapWaveCfg() // активизация/выключение волумов в зависимости от волны
	{
		local int i,l;

		if ( SandboxController.MapInfo.bUseZombieVolumeWaveDisabling ) // используем стандартные настройки волумов
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
function MCWaveInfo GetNextWaveInfo(MCWaveInfo CurWave)
{
	return SandboxController.GetNextWaveInfo(CurWave);
}
//--------------------------------------------------------------------------------------------------
function int GetAliveMonsterIndex(KFMonster M)
{
	local int i,n;
	
	n = AliveMonsters.Length;
	
	for(i=0; i<n; i++)
	{
		if ( AliveMonsters[i].Mon == M )
		{
			return i;
		}
	}
	
	return -1;
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
		{
			AliveMonsters.Remove(i,1);
		}
	}
	Super.Killed(Killer,Killed,KilledPawn,damageType);
}
//--------------------------------------------------------------------------------------------------
function int ReduceDamage(int Damage, pawn injured, pawn instigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType)
{
	local int index,i,n;
	local KFMonster M;
	local MCMonsterInfo MonInfo;
	toLog("ReduceDamage()"@Damage);
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
					toLog("ReduceDamage()->Reduced"@Damage@"MonInfo"@string(MonInfo.Name));
					break;
				}
			}
		}
	}
	return Super.ReduceDamage(Damage,injured,instigatedBy,HitLocation,Momentum,DamageType);
}
//--------------------------------------------------------------------------------------------------
function NotifyMonsterSpawn(KFMonster Mon, MCMonsterInfo MonInfo)
{
	toLog("NotifyMonsterSpawn()"@string(MonInfo.Name));
	AliveMonsters.Insert(0,1);
	AliveMonsters[0].Mon = Mon;
	AliveMonsters[0].MonType = MonInfo;
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