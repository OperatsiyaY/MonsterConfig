/*
 * 1. Так как нужно при спавне монстров заменять их параметры, а спавнятся монстры в ZombieVolume,
 * то его нужно заменить на наш. В CheckReplacement ловятся все ZombieVolume, и если они не являются
 * нашими MCZombieVolume,то поднимается флаг bReplaceZombieVolumes. В Tick этот флаг ловится и
 * вызывается функция ReplaceZombieVolumes, которая заменяет все ZombieVolume в
 * KFGameType.ZedSpawnList на наши MCZombieVolume
 *
 */
class MonsterConfig extends Mutator
	dependson(MCSquadInfo)
	ParseConfig
	config(MonsterConfig);

// общие
var KFGametype		GT;
var FileLog			MCLog; // отдельный лог
var config class<KFGameType>	GameTypeClass; // позволить юзерам наследовать уже свой GameType, наследованынй от нашего

// замена ZombieVolume на на MCZombieVolume
var array<ZombieVolume> PendingZombieVolumes; // Массив ZombieVolumes, будут заменены в след.тике на наши

// массивы настроек
var array<MCMonsterInfo>		Monsters;
var array<MCSquadInfo>			Squads;
var array<MCWaveInfo>			Waves;
var MCMapInfo					MapInfo;
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
function PostBeginPlay()
{
	if (GameTypeClass==none || !ClassIsChildOf(GameTypeClass, class'MCGameType') )
	{
		toLog("Specified GameTypeClass is not valid, so using MCGameType. Check MonsterConfig.ini");
		GameTypeClass=class'MCGameType';
	}
	if ( (Level.Game).Class != GameTypeClass )
	{
		//Level.ServerTravel("?game="$string(GameTypeClass), true);
		//return;
	}

	ReadConfig();

	MCGameType(GT).bReady = true;
}
//--------------------------------------------------------------------------------------------------
function ReadConfig()
{
	local int i,j;
	local array<string> Names;
	local MCMonsterInfo	tMonsterInfo;
	local MCSquadInfo	tSquadInfo;
	local MCWaveInfo	tWaveInfo;
	local MCMapInfo		tMapInfo;


	// чтение описаний монстров
	Names = class'MCMonsterInfo'.static.GetNames();
	for (i = 0; i < Names.length; i++)
	{
		if (Len(Names[i])==0) continue;
		tMonsterInfo = new(None, Names[i]) class'MCMonsterInfo';
		if (tMonsterInfo.MonsterClass != none)
		{
			Monsters.Insert(0,1);
			Monsters[0] = tMonsterInfo;
		}
		else
			toLog("Monster:"@string(tMonsterInfo.Name)$". MClass not found. Check settings in"@class'MCMonsterInfo'.default.ConfigFile$".ini");
	}
	if (Monsters.Length==0)
		toLog("No valid Monsters found! So no monsters will spawn");

	// чтение описаний отрядов
	Names = class'MCSquadInfo'.static.GetNames();
	for (i = 0; i < Names.length; i++)
	{
		if (Len(Names[i])==0) continue;
		tSquadInfo = new(None, Names[i]) class'MCSquadInfo';
		for (j=0; j<tSquadInfo.Monster.Length; j++)
		{
			if ( !isValidMonsterName(tSquadInfo.Monster[j].MonsterName) )
			{
				toLog("Squad:"@string(tSquadInfo.Name)@"Monster"@tSquadInfo.Monster[j].MonsterName@"not found. Check settings in"@class'MCSquadInfo'.default.ConfigFile$".ini");
				tSquadInfo.Monster.Remove(j,1);
				j--;
			}
		}
		if (tSquadInfo.Monster.Length > 0)
		{
			Squads.Insert(0,1);
			Squads[0] = tSquadInfo;
		}
	}
	if (Squads.Length==0)
		toLog("No valid Squads found! So no monsters will spawn");

	// чтение описаний волн
	Names = class'MCWaveInfo'.static.GetNames();
	for (i = 0; i < Names.length; i++)
	{
		if (Len(Names[i])==0) continue;
		tWaveInfo = new(None, Names[i]) class'MCWaveInfo';
		 // пропускаем в этом месте, если волна сконфигурена только для определенных карт
		if (tWaveInfo.bMapSpecific)
			continue;

		if (isValidWave(tWaveInfo))
			Waves[Waves.Length] = tWaveInfo;
		else
			toLog("Wave:"@string(tWaveInfo.Name)@"has no valid Squad or SpecialSquad records, so it wont be loaded");
	}
	if(Waves.Length==0)
		toLog("No valid WaveInfo's found! So no monsters will spawn");

	// чтение переменных, зависимых от карты
	tMapInfo=none;
	Names = class'MCMapInfo'.static.GetNames();
	for (i = 0; i < Names.length; i++)
	{
		if (string(Level.outer.name) ~= Names[i])
		{
			tMapInfo = new(None, Names[i]) class'MCMapInfo';
			break;
		}
	}
	// если для данной карты нет переменных, читаем default значения
	if (tMapInfo==none)
		tMapInfo = new(None, "default") class'MCMapInfo';

	for (i=0; i<tMapInfo.Waves.Length; i++)
	{
		if ( Len(tMapInfo.Waves[i])==0 || !isValidWaveName(tMapInfo.Waves[i]) )
		{
			toLog("MapInfo:"@string(tMapInfo.Name)@" | WaveName"@string(tWaveInfo.Name)@"is not valid. Check"@class'MCWaveInfo'.default.ConfigFile$".ini");
			tMapInfo.Waves.Remove(i,1);
			i--;
			continue;
		}
		tWaveInfo = new(None, tMapInfo.Waves[i]) class'MCWaveInfo';
		if (tWaveInfo.bMapSpecific==false) // обычная волна, она и так будет загружена
		{
			toLog("MapInfo:"@string(tMapInfo.Name)@" | WaveName"@string(tWaveInfo.Name)@"is not map-specific, so already loaded. Check"@class'MCWaveInfo'.default.ConfigFile$".ini");
			tMapInfo.Waves.Remove(i,1);
			i--;
			continue;
		}
		if (isValidWave(tWaveInfo))
		{
			toLog("Map-specific wave"@string(tWaveInfo.Name)@"added.");
			Waves[Waves.Length] = tWaveInfo;
		}
		else
		{
			tMapInfo.Waves.Remove(i,1);
			i--;
			toLog("Map-specific Wave:"@string(tWaveInfo.Name)@"has no valid Squad or SpecialSquad records, so it wont be loaded");
		}
	}
	MapInfo = tMapInfo;
}
//--------------------------------------------------------------------------------------------------
function bool isValidWaveName(string WaveName)
{
	local array<string> Names;
	local int i;
	Names = class'MCWaveInfo'.static.GetNames();
	for (i=0; i<Names.Length; i++)
		if (WaveName ~= Names[i])
			return true;
	return false;
}
//--------------------------------------------------------------------------------------------------
function bool isValidWave(out MCWaveInfo tWaveInfo)
{
	local int j;
	for (j=0; j < tWaveInfo.Squad.Length; j++)
	{
		// удаляем сквады, имен которых нет в конфиге
		if (!isValidSquad(tWaveInfo.Squad[j]))
		{
			toLog("Wave:"@string(tWaveInfo.Name)@"Squad"@tWaveInfo.Squad[j]@"not found. Check"@class'MCWaveInfo'.default.ConfigFile$".ini");
			tWaveInfo.Squad.Remove(j,1);
			j--;
		}
	}
	for (j=0; j < tWaveInfo.SpecialSquad.Length; j++)
	{
		// удаляем сквады, имен которых нет в конфиге
		if (!isValidSquad(tWaveInfo.SpecialSquad[j]))
		{
			toLog("Wave:"@string(tWaveInfo.Name)@"SpecialSquad"@tWaveInfo.SpecialSquad[j]@"not found. Check"@class'MCWaveInfo'.default.ConfigFile$".ini");
			tWaveInfo.SpecialSquad.Remove(j,1);
			j--;
		}
	}
	return (tWaveInfo.Squad.Length > 0 || tWaveInfo.SpecialSquad.Length > 0);
}
//--------------------------------------------------------------------------------------------------
function bool isValidSquad(string SquadName)
{
	local int i;
	for (i=0;i<Squads.Length;i++)
		if (SquadName == string(Squads[i].Name))
			return true;
	return false;
}
//--------------------------------------------------------------------------------------------------
function bool isValidMonsterName(string MonsterName)
{
	local int i;
	for (i=0; i<Monsters.Length; i++)
		if (MonsterName == string(Monsters[i].Name))
			return true;
	return false;
}
//--------------------------------------------------------------------------------------------------
function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
	// Замена ZombieVolumes на MCZombieVolume
	if ( ZombieVolume(Other)!=none && MCZombieVolume(Other)==none )
	{
//		bReplaceZombieVolumes=true;
		PendingZombieVolumes.Insert(0,1);
		PendingZombieVolumes[0] = ZombieVolume(Other);
	}
	return true;
}
//--------------------------------------------------------------------------------------------------
simulated function Tick(float dt)
{
	if ( GT == none )
	{
		GT = KFGameType(Level.Game);
		if ( GT == none )
			return;
	}
	while ( PendingZombieVolumes.Length > 0 )
	{
		ReplaceZombieVolume(PendingZombieVolumes[0]);
		PendingZombieVolumes.Remove(0,1);
	}
}
//--------------------------------------------------------------------------------------------------
function bool ReplaceZombieVolume(ZombieVolume CurZMV)
{
	local int i,n,j;
	local MCZombieVolume NewVol;

	// определяем что ZombieVolume есть в листе ZedSpawnList, иначе не заменяем.
	// TELO: Зачем эта проверка? заменять любой волум, попавшийся CheckReplacement'у и пришедший сюда
	n = GT.ZedSpawnList.Length;
	for(i=0; i<n; i++)
		if ( CurZMV == GT.ZedSpawnList[i] )
			break;
	if ( i >= n )
	{
		toLog("ReplaceZombieVolume: ZombieVolume not found");
		return false; // ZombieVolume не найден, выход
	}

	NewVol = Spawn(class'MCZombieVolume',Level,,CurZMV.Location,CurZMV.Rotation);

	// копируем точки спавна
	n = CurZMV.SpawnPos.Length;
	for(j=0; j<n; j++)
		NewVol.SpawnPos[j] = CurZMV.SpawnPos[j];
	if ( n > 0 )
		NewVol.bHasInitSpawnPoints = true;

	n = CurZMV.DisabledWaveNums.Length;
	for(j=0; j<n; j++)
		NewVol.DisabledWaveNums[j] = CurZMV.DisabledWaveNums[j];

	n = CurZMV.DisallowedZeds.Length;
	for(j=0; j<n; j++)
		NewVol.DisallowedZeds[j] = CurZMV.DisallowedZeds[j];

	n = CurZMV.OnlyAllowedZeds.Length;
	for(j=0; j<n; j++)
		NewVol.OnlyAllowedZeds[j] = CurZMV.OnlyAllowedZeds[j];

	n = CurZMV.RoomDoorsList.Length;
	for(j=0; j<n; j++)
		NewVol.RoomDoorsList[j] = CurZMV.RoomDoorsList[j];

	NewVol.CanRespawnTime = CurZMV.CanRespawnTime;
	NewVol.bMassiveZeds = CurZMV.bMassiveZeds;
	NewVol.bLeapingZeds = CurZMV.bLeapingZeds;
	NewVol.bNormalZeds = CurZMV.bNormalZeds;
	NewVol.bRangedZeds = CurZMV.bRangedZeds;
	NewVol.TouchDisableTime = CurZMV.TouchDisableTime;
	NewVol.ZombieCountMulti = CurZMV.ZombieCountMulti;
	NewVol.bVolumeIsEnabled = CurZMV.bVolumeIsEnabled;
	NewVol.SpawnDesirability = CurZMV.SpawnDesirability;
	NewVol.MinDistanceToPlayer = CurZMV.MinDistanceToPlayer;
	NewVol.bNoZAxisDistPenalty = CurZMV.bNoZAxisDistPenalty;
	// NewVol. = CurZMV.;

	// CurZMV.Destroy(); // не уничтожаем, возможно нужны для мапперов
	GT.ZedSpawnList[i] = NewVol;

	return true;
}
//--------------------------------------------------------------------------------------------------
function toLog(string M)
{
	// инициализируем лог
	if (MCLog==none)
	{
		MCLog = Spawn(class'FileLog');
		MCLog.OpenLog("MonsterConfigLog","log",true); // overwrite
		MCLog.LogF("---------------------------------------------");
	}
	MCLog.LogF(M);
	Log("MonsterConfig:"@M);
}
//--------------------------------------------------------------------------------------------------
function Destroyed()
{
	Super.Destroyed();
	MCLog.CloseLog();
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
defaultproperties
{
	bAlwaysRelevant=true
	RemoteRole = ROLE_SimulatedProxy
}