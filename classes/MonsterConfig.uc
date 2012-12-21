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
	
var config int		FakedPlayersNum;
var config float	MonstersMaxAtOnceMod,MonstersTotalMod;
var config float	MonsterBodyHPMod,MonsterHeadHPMod,MonsterSpeedMod,MonsterDamageMod;

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

// выключение стандартных киллсмесседж KillsMessageOff()
var bool bKillsMessageReplace, bKillsMessageReplaceClient;
//var MCKillMessageRoutines LMRoutine;
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
simulated function PostNetReceive()
{
	if (bKillsMessageReplace != bKillsMessageReplaceClient)
	{
		bKillsMessageReplaceClient = bKillsMessageReplace;
		KillsMessageOff();
	}
}
//--------------------------------------------------------------------------------------------------
function PostBeginPlay()
{
	toLog("PostBeginPlay()");
	if (GameTypeClass==none || !ClassIsChildOf(GameTypeClass, class'MCGameType') )
	{
		toLog("Specified GameTypeClass is not valid, so using MCGameType. Check MonsterConfig.ini");
		GameTypeClass=class'MCGameType';
	}
	if ( (Level.Game).Class != GameTypeClass && !ClassIsChildOf((Level.Game).Class, class'MCGameType'))
	{
		toLog("Travelling to"@string(GameTypeClass));
		Level.ServerTravel("?game="$string(GameTypeClass), true);
		return;
	}
	GT = MCGameType(Level.Game);

	ReadConfig();

	/* KFGameType->InitGame:
	 * Установка KFGameType.MaxPlayers
	 * Установка KFLRules.WaveSpawnPeriod который используется в CalcNextSquadSpawnTime()
	 * или переписать его полностью, чтобы использовал наш DelayBetweenSquads из WaveInfo
	 *
	 * KFGameType.DoWaveEnd
	 * Дает вознаграждение выжившим
	 * Устанавливает отчет до следующей волны WaveCountDown = Max(TimeBetweenWaves,1);  <--- переписать
	 * Увеличивает номер волны
	 * Меняет выбранный перк
	 * Респавнит мертвых
	 * Зачисляет стату
	 * Респавнит двери
	 * 
	 * KFGameType.InitMapWaveCfg
	 * Выключает ZombieVolume, исходя из ZombieVolume.DisabledWaveNums
	 * 
	 * KFGameType.StartWaveBoss
	 * Устанавливает NextSpawnSquad.Length = 1
	 * Устанавливает NextSpawnSquad[0] - босса
	 * KFGameReplicationInfo(Level.Game.GameReplicationInfo).MaxMonsters = 1;
	 * TotalMaxMonsters = 1;
	 * bWaveBossInProgress = True;
	 */ 

	bKillsMessageReplace = true;
	KillsMessageOff();
	//LMRoutine = spawn(class'MCKillMessageRoutines', self);

	MCGameType(GT).PostInit(Self);	
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
			// для KillsMessage
			tMonsterInfo.MNameObj = new(None, string(tMonsterInfo.Name)) class'MCMonsterNameObj';
			tMonsterInfo.MNameObj.MonsterName  = tMonsterInfo.MonsterName;
			tMonsterInfo.MNameObj.MonsterClass = tMonsterInfo.MonsterClass;
			
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
			if ( GetMonster(tSquadInfo.Monster[j].MonsterName) == none )
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

		if (isValidWave(tWaveInfo)) // проверяет есть ли валидные сквады в волне
		{
			if (tWaveInfo.Position==-1) // если для волны не указали Position
			{
				// пытаемся выяснить номер волны исходя из названия волны (Wave_4lol) = 4я волна
				if ( !TryGetNumber(string(tWaveInfo.Name), tWaveInfo.Position) )
				{
					tWaveInfo.Position = FMax(GetLastWave().Position,0.f) + 0.1;
					toLog("Wave:"@string(tWaveInfo.Name)@"Position not specified. Also no numbers in WaveName. So position will be"@tWaveInfo.Position@". Check"@class'MCWaveInfo'.default.ConfigFile$".ini");
				}
				// TODO делать ли tWaveInfo.SaveConfig(), чтобы записать только что найденый Position?? Тогда из конфига удалятся невалидные сквады
			}
			while (bWavePositionAlreadyExist(tWaveInfo.Position))
			{
				toLog("Wave:"@string(tWaveInfo.Name)@"Position"@tWaveInfo.Position@"already exists. Check"@class'MCWaveInfo'.default.ConfigFile$".ini");
				tWaveInfo.Position+=0.1;
			}
			toLog("Wave:"@string(tWaveInfo.Name)@"loaded with position"@tWaveInfo.Position);
			Waves[Waves.Length] = tWaveInfo;
		}
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
			toLog("MapInfo:"@string(tMapInfo.Name)@" | WaveName"@tMapInfo.Waves[i]@"is not valid. Check"@class'MCWaveInfo'.default.ConfigFile$".ini");
			tMapInfo.Waves.Remove(i,1);
			i--;
			continue;
		}
		// если волна уже загружена. Эта проверка обязательно нужна. иначе при загрузке волны ниже,
		// уже у загруженной волны может сбиться Position, установленный выше.
		if (GetWave(tMapInfo.Waves[i]) != none)
		{
			tMapInfo.Waves.Remove(i,1);
			i--;			
			continue;
		}
		tWaveInfo = new(None, tMapInfo.Waves[i]) class'MCWaveInfo';
		if (tWaveInfo.bMapSpecific==false) // обычная волна, она и так будет загружена
		{
			toLog("MapInfo:"@string(tMapInfo.Name)@"| WaveName"@string(tWaveInfo.Name)@"is not map-specific, so already loaded. Check"@class'MCWaveInfo'.default.ConfigFile$".ini");
			tMapInfo.Waves.Remove(i,1);
			i--;
			continue;
		}
		if (isValidWave(tWaveInfo))
		{
			if (tWaveInfo.Position==-1) // если для волны не указали Position
			{
				// пытаемся выяснить номер волны исходя из названия волны (Wave_4lol) = 4я волна
				if ( !TryGetNumber(string(tWaveInfo.Name), tWaveInfo.Position) )
				{
					tWaveInfo.Position = FMax(GetLastWave().Position,0.f) + 0.1;
					toLog("Wave:"@string(tWaveInfo.Name)@"Position not specified. Also no numbers in WaveName. So position will be"@tWaveInfo.Position@". The wave is map-specific, and specified for map"@string(tMapInfo.Name)@". Check"@class'MCWaveInfo'.default.ConfigFile$".ini");
				}
				// TODO делать ли tWaveInfo.SaveConfig(), чтобы записать только что найденый Position?? Тогда из конфига удалятся невалидные сквады
			}
			while (bWavePositionAlreadyExist(tWaveInfo.Position))
			{
				toLog("Wave:"@string(tWaveInfo.Name)@"Position"@tWaveInfo.Position@"already exists. Check"@class'MCWaveInfo'.default.ConfigFile$".ini");
				tWaveInfo.Position+=0.1;
			}
			toLog("Map-specific Wave ("$string(tMapInfo.Name)$"):"@string(tWaveInfo.Name)@"loaded with position"@tWaveInfo.Position);
			Waves[Waves.Length] = tWaveInfo;
		}
		else
		{
			tMapInfo.Waves.Remove(i,1);
			i--;
			toLog("Map-specific Wave:"$string(tWaveInfo.Name)$"has no valid Squad or SpecialSquad records, so it wont be loaded");
		}
	}
	MapInfo = tMapInfo;
}
//--------------------------------------------------------------------------------------------------
function bool bWavePositionAlreadyExist(float F)
{
	local int i;
	for (i=0;i<Waves.Length;i++)
		if (Waves[i].Position == F)
			return true;
	return false;
}
//--------------------------------------------------------------------------------------------------
function MCWaveInfo GetLastWave()
{
	local int i;
	local MCWaveInfo Wave;
	Wave = Waves[0];
	toLog("GetLastWave() Best Wave:"@string(Wave.Name)@Wave.Position);
	for (i=0;i<Waves.Length;i++)
	{
		toLog("GetLastWave() Check Wave:"@string(Waves[i].Name)@Waves[i].Position);	
		if (Waves[i].Position > Wave.Position)
		{
			Wave = Waves[i];
			toLog("GetLastWave() Best Wave:"@string(Wave.Name)@Wave.Position);
		}
	}
	return Wave;
}
//--------------------------------------------------------------------------------------------------
function MCWaveInfo GetFirstWave()
{
	local int i;
	local MCWaveInfo Wave;
	Wave = Waves[0];
	toLog("GetFirstWave() Best Wave:"@string(Wave.Name)@Wave.Position);
	for (i=0;i<Waves.Length;i++)
	{
		toLog("GetFirstWave() Check Wave:"@string(Waves[i].Name)@Waves[i].Position);	
		if (Waves[i].Position < Wave.Position)
		{
			Wave = Waves[i];
			toLog("GetFirstWave() Best Wave:"@string(Wave.Name)@Wave.Position);
		}
	}
	return Wave;
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
		if ( GetSquad(tWaveInfo.Squad[j]) == none )
		{
			toLog("Wave:"@string(tWaveInfo.Name)@"Squad"@tWaveInfo.Squad[j]@"not found. Check"@class'MCWaveInfo'.default.ConfigFile$".ini");
			tWaveInfo.Squad.Remove(j,1);
			j--;
		}
	}
	for (j=0; j < tWaveInfo.SpecialSquad.Length; j++)
	{
		// удаляем сквады, имен которых нет в конфиге
		if ( GetSquad(tWaveInfo.SpecialSquad[j]) == none )
		{
			toLog("Wave:"@string(tWaveInfo.Name)@"SpecialSquad"@tWaveInfo.SpecialSquad[j]@"not found. Check"@class'MCWaveInfo'.default.ConfigFile$".ini");
			tWaveInfo.SpecialSquad.Remove(j,1);
			j--;
		}
	}
	return (tWaveInfo.Squad.Length > 0 || tWaveInfo.SpecialSquad.Length > 0);
}
//--------------------------------------------------------------------------------------------------
function MCSquadInfo GetSquad(string SquadName)
{
	local int i;
	for (i=0;i<Squads.Length;i++)
		if (SquadName == string(Squads[i].Name))
			return Squads[i];
	return None;
}
//--------------------------------------------------------------------------------------------------
function MCMonsterInfo GetMonster(string MonsterName)
{
	local int i;
	for (i=0; i<Monsters.Length; i++)
		if (MonsterName == string(Monsters[i].Name))
			return Monsters[i];
	return None;
}
//--------------------------------------------------------------------------------------------------
function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
	if (KillsMessage(Other)!=none)
	{
		log("Replacing killsmessage");
		ReplaceWith(Other, "MonsterConfig.MCKillsMessage");
		return false;
	}

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
function toLog(string M, optional Object Sender)
{
	local string Spec;

	// инициализируем лог
	if (MCLog==none)
	{
		MCLog = Spawn(class'FileLog');
		MCLog.OpenLog("MonsterConfigLog","log",true); // overwrite
		MCLog.LogF("---------------------------------------------");
		SetTimer(15,false);
	}
	if ( Sender != none )
		Spec = String(Sender.Name)$"->";
	else
		Spec = string(self.name)$"->";
		
	MCLog.LogF(Spec $ M);
	Log(Spec $ M);
}
//--------------------------------------------------------------------------------------------------
function Destroyed()
{
	Super.Destroyed();
	MCLog.CloseLog();
}
//--------------------------------------------------------------------------------------------------
// функция на вход получает строку Wave_1 на выходе выдает 1 (float)
function bool TryGetNumber(string S, out float F)
{
	local int i;
	local string tS;
	i=1;
	while (Len(S)>0)
	{
		tS = Right(S,i);
		if (IsNumber(tS))
		{
			while (IsNumber(tS) && i<=Len(S))
			{
				i++;
				tS = Right(S,i);
			}
			tS = Right(S,i-1);
			F = float(tS);
			return true;
		}
		else
			S = Left(S,Len(S)-1);
	}
	return false;
}
//--------------------------------------------------------------------------------------------------
function bool IsNumber(string Num)
{
	if ( Num > Chr(47) && Num < Chr(58) )
		return true;

	return false;
}
//--------------------------------------------------------------------------------------------------
/*function MCWaveInfo GetNextWaveInfo(MCWaveInfo CurWave)
{
	local float BestPos;
	local int i,n;
	local MCWaveInfo Ret;
	
	Ret = CurWave;
	n = Waves.Length;
	BestPos = CurWave.Position;
	
	for(i=0; i<n; i++)
	{
		if ( Waves[i].Position < CurWave.Position )
			continue;
		
		if ( BestPos == CurWave.Position )
		{
			Ret = Waves[i];
			BestPos = Ret.Position;
			continue;
		}
		
		if ( Waves[i].Position < BestPos )
		{
			Ret = Waves[i];
			BestPos = Ret.Position;
		}
	}
	
	if ( Ret == CurWave )
		return none;
		
	return Ret;
}*/
//--------------------------------------------------------------------------------------------------
// функция возвращает следующую после CurWave волну, а при неудаче возвращает none
function MCWaveInfo GetNextWaveInfo(MCWaveInfo CurWave)
{
	local int i;
	local float BestPos;
	local MCWaveInfo Ret;

	if (CurWave==none) // при первой волне
		return GetFirstWave();

	BestPos = CurWave.Position;
	for (i=0;i<Waves.Length;i++)
	{
		if ( Waves[i].Position <= BestPos )	// ищем только волны, следующие за текущей, 
			continue;						//а предыдущие и равные текущей пропускаем
		if (BestPos == CurWave.Position)	// если еще ничего не нашли,
		{									// то берем первую попавшуюся волну
			Ret = Waves[i];
			BestPos = Waves[i].Position;
		}
		else if (Waves[i].Position < BestPos) // а дальше уже отсеиваем с наименьшим номером
		{
			Ret = Waves[i];
			BestPos = Waves[i].Position;
		}
	}
	if (Ret==CurWave)
		return none;

	return Ret;
}
//--------------------------------------------------------------------------------------------------
function MCWaveInfo GetWave(string W)
{
	local int i;
	for (i=0;i<Waves.Length;i++)
		if (string(Waves[i].Name)~=W)
			return Waves[i];
	return none;
}
//--------------------------------------------------------------------------------------------------
function int GetWaveNum(MCWaveInfo Wave)
{
	local int i, num;
	num = 1;
	for (i=0;i<Waves.Length;i++)
	{
		if (Waves[i].Position < Wave.Position)
			num++;
	}
	toLog("GetWaveNum->Wave"@string(Wave.Name)@"WaveNum is"@num);
	return num;
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
function float GetNumPlayers(optional bool bOnlyAlive, optional bool bNotCountFaked)
{
	local int NumPlayers;
	local Controller C;
	
	For( C=Level.ControllerList; C!=None; C=C.NextController )
	{
		if( C.bIsPlayer && ( !bOnlyAlive || (C.Pawn!=None && C.Pawn.Health > 0 ) ) )
		{
			NumPlayers++;
		}
	}
	if ( !bNotCountFaked )
		return NumPlayers + FakedPlayersNum;
		
	return NumPlayers;
}
//--------------------------------------------------------------------------------------------------
simulated function Timer()
{
	Super.Timer();
	
	if ( MCLog != none )
	{
		MCLog.CloseLog();
		MCLog.OpenLog("MonsterConfigLog","log",false);
	}
	
	SetTimer(15,false);
}
//--------------------------------------------------------------------------------------------------
simulated function KillsMessageOff()
{
	local PlayerController PC;
	local HudKillingFloor H;
	PC = Level.GetLocalPlayerController();
 	H = HudKillingFloor(PC.myHud);
    H.bTallySpecimenKills = false;
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
defaultproperties
{
	bAlwaysRelevant = true
	RemoteRole = ROLE_SimulatedProxy
	bNetNotify = true
	
	FakedPlayersNum = 0
	MonstersTotalMod = 1.00
	MonstersMaxAtOnceMod = 1.00
	
	MonsterBodyHPMod = 1.00
	MonsterHeadHPMod = 1.00
	MonsterSpeedMod = 1.00
	MonsterDamageMod = 1.00
}