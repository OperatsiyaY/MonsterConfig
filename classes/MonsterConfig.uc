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
	dependson(MCMonsterList)
	ParseConfig
	config(MonsterConfig);

// для работы LinkMesh
#exec obj load file="KF_Freaks_Trip.ukx"
#exec obj load file="KF_Freaks2_Trip.ukx"
#exec obj load file="KF_Specimens_Trip_T"
#exec obj load file="KF_Specimens_Trip_T_Two"

var config int		FakedPlayersNum;
var config float	MonstersMaxAtOnceMod,MonstersTotalMod;
var config float	MonsterBodyHPMod,MonsterHeadHPMod,MonsterSpeedMod,MonsterDamageMod;
var config float	HealedToScoreCoeff;

// общие
var MCGameType		GT;
var FileLog			MCLog; // отдельный лог
var config class<KFGameType>	GameTypeClass; // позволить юзерам наследовать уже свой GameType, наследованынй от нашего

// замена ZombieVolume на на MCZombieVolume
var array<ZombieVolume> PendingZombieVolumes; // Массив ZombieVolumes, будут заменены в след.тике на наши

// массивы настроек
var array<MCMonsterInfo>		Monsters;
var array<MCSquadInfo>			Squads;
var array<MCWaveInfo>			Waves;
var MCMapInfo					MapInfo;

// для системы наград от Тело
var config bool					bWaveFundSystem; // указывает какая система фонда будет использоваться
var MCPerkStats					PerkStats;
var array<PlayerController>		PendingPlayers; // игроки, которым присвоить MCRepInfo

// для LinkMesh на клиенте
var array<KFMonster>			PendingMonsters;
var MCMonsterList				MList, MListClient; // связный список монстров для репликации клиенту
var int							MListRevision;

// выключение стандартных киллсмесседж KillsMessageOff()
var bool bKillsMessageReplace, bKillsMessageReplaceClient;
//var MCKillMessageRoutines LMRoutine;

replication
{
	reliable if (ROLE==ROLE_Authority)
		MList;
}
//--------------------------------------------------------------------------------------------------
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
	
	if (Level!=none && Level.NetMode != NM_Client)
		MList = Spawn(class'MCMonsterList', self);

	if (bWaveFundSystem)
		PerkStats = new(None, "PerkStats") class'MCPerkStats';

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

	GT.PostInit(Self);
}
//--------------------------------------------------------------------------------------------------
// Инициализируем все параметры монстра вызывается из MCZombieVolume
function InitMonster(KFMonster M, MCMonsterInfo MI)
{
	local int PlayersCount;
	local MonsterConfig SC;
	local float TempDamage, F;

//	local class<KFMonster> KFM;

	SC = MCGameType(Level.Game).SandboxController;
	if (SC==none)
	{
		Log("MCZombieVolume->MCInitMonster->Failed to load MCGameType.SandboxController. So exit");
		return;
	}
	PlayersCount = SC.GetNumPlayers(true) - 1; // ВЫЧИТАЕМ УЖЕ ТУТ

/*
	// редефайн имени монстра для Killmessages mut'а
	// TODO проверить где он еще используется кроме Killmessages, и не накосячит ли чего эта замена
	// т.к. killmessages сначала пытается брать имя монстра из его Default.MenuName, то дефолт мы обнуляем
	// а обычный MenuName ставим. Если не указан, то ставим в дефолтовый, для этого дефолтовые значениясм
	// сохраняем в массиве.
	// код из killmessages:
	// if( Len(M.Default.MenuName)==0 )
	//		return string(M.Name);
	// return M.Default.MenuName;
	if (Len(M.default.MenuName) > 0)
		SaveDefaultMenuName(M.Class);

	if (Len(MI.MenuName)>0)
	{
		M.default.MenuName="";
		M.MenuName = MI.MenuName$"s";
	}
	else
		M.MenuName = GetDefaultMenuName(M.Class)$"s";
	//KFM = M.Class;
	//KFM.default.MenuName = "s3";
*/
	// HEALTH
	if (MI.Health != -1)
		F = MI.Health;
	else
		F = M.Health;
	F += MI.PerPlayer.Health * Max(0,PlayersCount);
	if (MI.HealthMax != -1)
		F = Min(MI.HealthMax, F);
	M.Health = F * (SC.MonsterBodyHPMod * SC.MapInfo.MonsterBodyHPMod);
	M.HealthMax = M.Health;

	if (MI.HeadHealth != -1)
		F = MI.HeadHealth;
	else
		F = M.HeadHealth;
	F += MI.PerPlayer.HeadHealth * Max(0,PlayersCount);
	if (MI.HeadHealthMax != -1)
		F = Min(MI.HeadHealthMax, F);
	M.HeadHealth = F * (SC.MonsterHeadHPMod * SC.MapInfo.MonsterHeadHPMod);

	M.default.Health = M.Health;
	M.default.HeadHealth = M.HeadHealth;

	if ( MI.Speed <= 0 )
	{
		M.OriginalGroundSpeed *= MI.SpeedMod;
		M.GroundSpeed = M.OriginalGroundSpeed;
		M.WaterSpeed *= MI.SpeedMod;
		M.AirSpeed *= MI.SpeedMod;
	}
	else
	{
		M.OriginalGroundSpeed = MI.Speed;
		M.GroundSpeed = M.OriginalGroundSpeed;
		M.WaterSpeed = M.GroundSpeed * 0.90;
		M.AirSpeed = M.GroundSpeed * 1.10;
	}

	M.OriginalGroundSpeed *= SC.MonsterSpeedMod * SC.MapInfo.MonsterSpeedMod;
	M.GroundSpeed = M.OriginalGroundSpeed;
	M.WaterSpeed *= SC.MonsterSpeedMod * SC.MapInfo.MonsterSpeedMod;
	M.AirSpeed *= SC.MonsterSpeedMod * SC.MapInfo.MonsterSpeedMod;

	TempDamage = M.MeleeDamage * SC.MonsterDamageMod * SC.MapInfo.MonsterDamageMod;
	M.MeleeDamage = TempDamage;
	TempDamage = TempDamage - float(M.MeleeDamage);

	if ( FRand() < TempDamage )
	{
		M.MeleeDamage += 1;
	}

	TempDamage = M.ScreamDamage * SC.MonsterDamageMod * SC.MapInfo.MonsterDamageMod;
	M.MeleeDamage = TempDamage;
	TempDamage = TempDamage - float(M.MeleeDamage);

	if ( FRand() < TempDamage )
	{
		M.ScreamDamage += 1;
	}

	if (true || MI.MonsterSize!=1.0)
	{
		F = FRand()*2.3; //Clamp(MI.MonsterSize, 0.1, 5);
		F = FClamp(F, 0.8, 1.2);
		M.SetDrawScale(M.default.DrawScale * F);
		M.SetCollisionSize(M.default.CollisionRadius * F, M.default.CollisionHeight * F);
		M.BaseEyeHeight = M.default.BaseEyeHeight * F;
		M.EyeHeight     = M.default.EyeHeight * F;

		M.MeleeRange	= M.default.MeleeRange * F;
		if (F>1.)
			M.PrePivot.Z	= M.default.PrePivot.Z * F + ((M.default.ColOffset.Z + M.default.ColHeight)/2.f) * F;
		if (F<1.)
			M.PrePivot.Z	= M.default.PrePivot.Z * F - ((M.default.ColOffset.Z + M.default.ColHeight)/2.f) * F;

		M.OriginalGroundSpeed *= F;
		M.GroundSpeed *= F;
		//M.PlayTeleportEffect(true, true);
		//C.Pawn.bCanCrouch = False;
		//C.Pawn.CrouchHeight  *= newPlayerSize;
		//C.Pawn.CrouchRadius  *= newPlayerSize;
	}
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

			// если трипы удалили Mesh в очередной раз
			if (tMonsterInfo.MonsterClass.default.Mesh==none && tMonsterInfo.Mesh.Length==0)
				tMonsterInfo.Mesh[0] = GetDefaultMesh(tMonsterInfo.MonsterClass);
			if( (tMonsterInfo.MonsterClass.default.Skins.Length==0
				||tMonsterInfo.MonsterClass.default.Skins[0]==none) && tMonsterInfo.Skins.Length==0 )
				GetDefaultSkins(tMonsterInfo.MonsterClass, tMonsterInfo.Skins);

			Monsters[Monsters.Length] = tMonsterInfo;
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
	/*if (KillsMessage(Other)!=none)
	{
		log("Replacing killsmessage");
		ReplaceWith(Other, "MonsterConfig.MCKillsMessage");
		return false;
	}*/

	if (bWaveFundSystem)
	{
		// Спавним MCRepInfo наш Linked ReplicationInfo с доп.статистикой
		if (PlayerController(Other)!=none)
		{
			PendingPlayers[PendingPlayers.Length] = PlayerController(Other);
			SetTimer(0.1,false);
		}
	}
	else if (KFMonster(Other)!=none)
	{	// через 0.1 сек, смотрим MonsterInfo этого монстра, формируем массив для репликации клиенту
		// и на клиенте делаем LinkMesh
		PendingMonsters[PendingMonsters.Length] = KFMonster(Other);
		SetTimer(0.1, false);
	}
	// Замена ZombieVolumes на MCZombieVolume
	else if ( ZombieVolume(Other)!=none && MCZombieVolume(Other)==none )
	{
//		bReplaceZombieVolumes=true;
		PendingZombieVolumes.Insert(0,1);
		PendingZombieVolumes[0] = ZombieVolume(Other);
	}
	return true;
}
//--------------------------------------------------------------------------------------------------
simulated function PostNetReceive()
{
	if (bKillsMessageReplace != bKillsMessageReplaceClient)
	{
		bKillsMessageReplaceClient = bKillsMessageReplace;
		KillsMessageOff();
	}
	if (MListClient != MList)
	{
		LM("Got new MList from server");
		MListClient = MList;
	}
}
//--------------------------------------------------------------------------------------------------
simulated function Tick(float dt)
{
	local MCMonsterList tMList;
	local int i;
	if (Level != none && Level.NetMode != NM_Client)
	{
		if (GT == none)
		{
			GT = MCGameType(Level.Game);
			if ( GT == none )
				return;
		}
		while ( PendingZombieVolumes.Length > 0 )
		{
			ReplaceZombieVolume(PendingZombieVolumes[0]);
			PendingZombieVolumes.Remove(0,1);
		}
	}
	// Обрабатываем прибывшие LinkMesh'и на клиенте
	if (MListRevision != MList.ListRevision)
	{
		LM("Got new MList ListRevision"@MList.ListRevision);
		MListRevision = MList.ListRevision;
		for (tMList = MList; tMList != none; tMList = tMList.GetNext())
		{
			LM("tMList iteration");
			if( tMList.revision != tMList.revisionClient
				&& tMList.Mon != none
				&& (tMList.MonMesh != none || tMList.Skins[0]!=none) )
			{
				tMList.revisionClient = tMList.revision;
				LM("tMList"@string(tMList.Mon.Name)@"is new rev."@tMList.revision);
				if (tMList.MonMesh!=none)
				{
					LM("tMList monmesh !=none");
					tMList.Mon.LinkMesh(tMList.MonMesh);
					LM("LinkMesh"@string(tMList.MonMesh));
					//tMList.Mon.UpdateDefaultMesh(tMList.MonMesh);
					//tMList.Mon.default.Mesh = tMList.MonMesh;
				}
				if (tMList.Mon.Mesh!=none && tMList.MonSkins[0]!=none)
					for (i=0;i<arraycount(tMList.MonSkins); i++)
						if (tMList.MonSkins[i]!=none)
						{
							tMList.Mon.Skins[i] = tMList.MonSkins[i];
							LM("applyskin"@string(tMList.MonSkins[i]));
						}
			}
		}
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

	NewVol.SandboxController = self;

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
	MCLog.CloseLog();
	Super.Destroyed();
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
	local int i,j,n;
	local MCRepInfo RInfo;
	local KFMonster Mon;
	local bool bFound;
	local MCMonsterList.MListInput	MI;

	if ( MCLog != none )
	{
		MCLog.CloseLog();
		MCLog.OpenLog("MonsterConfigLog","log",false);
	}
	SetTimer(15,false);

	if (PendingMonsters.Length>0)
	{
		for (i=0;i<PendingMonsters.Length;i++)
		{
			Mon = PendingMonsters[i];
			bFound = false;
			for (j=GT.AliveMonsters.Length-1; j>=0; j--)
				if (Mon == GT.AliveMonsters[j].Mon)
				{
					if( GT.AliveMonsters[j].MonType.Mesh.Length>0
						|| GT.AliveMonsters[j].MonType.Skins.Length>0 )
					{
						MI.Mesh = GT.AliveMonsters[j].MonType.Mesh;
						for (n=0;n<GT.AliveMonsters[j].MonType.Skins.Length; n++)
							if (GT.AliveMonsters[j].MonType.Skins[n]!=none)
								MI.Skins[n] = GT.AliveMonsters[j].MonType.Skins[n];
						/*n = Rand(GT.AliveMonsters[j].MonType.Mesh.Length-1);
						n = Max(0,n);*/
						//MList.AddMInfo(Mon, GT.AliveMonsters[j].MonType/*GT.AliveMonsters[j].MonType.Mesh[n]*/);
					}
					bFound=true;
					break;
				}
			if (bFound==false) // только для монстров, заспавленных не через MCZombieVolume
			{
				MI.Mesh[0] = GetDefaultMesh(Mon.Class);
				GetDefaultSkins(Mon.Class, MI.Skins);
			}
			if (MI.Mesh[0]!=none || MI.Skins[0]!=none)
				MList.Add(Mon, MI);
		}
		PendingMonsters.Remove(0,PendingMonsters.Length);
	}

	if (bWaveFundSystem)
	{
		for( i=0; i<PendingPlayers.Length; i++ )
		{
			if (PendingPlayers[i] == none)
			{
				PendingPlayers.Remove(i,1);
				i--;
				continue;
			}
			else if( PendingPlayers[i].Player != none
					&& PendingPlayers[i].PlayerReplicationInfo != none )
			{
				RInfo = GetMCRepInfo(PendingPlayers[i].PlayerReplicationInfo);
				if (RInfo==none)
					RInfo = Spawn(class'MCRepInfo', PendingPlayers[i]); // вставится в CustomRepLink цепочку сама
				if (GetHealedStats(PendingPlayers[i].PlayerReplicationInfo, RInfo.HealedStat))
				{
					PendingPlayers.Remove(i,1);
					i--;
				}
			}
		}
		if (PendingPlayers.Length>0) //PendingPlayers.Length = 0;
			SetTimer(0.1,false);
	}
	Super.Timer();

}
//--------------------------------------------------------------------------------------------------
function AddCustomReplicationInfo(PlayerReplicationInfo PRI, LinkedReplicationInfo L)
{
	if (PRI.CustomReplicationInfo == none)
		PRI.CustomReplicationInfo = L;
	else
	{
		for( L=PRI.CustomReplicationInfo; L!=none; L=L.NextReplicationInfo )
		{
			if (L.Class==L.Class)
			{
				warn(L.Class@"already loaded for"@PRI.PlayerName);
				return;
			}
		}

		for( L=PRI.CustomReplicationInfo; L!=none; L=L.NextReplicationInfo )
		{
			if( L.NextReplicationInfo==none )
			{
				L.NextReplicationInfo = L; // Add to the end of the chain.
				log(L.Class@"loaded for"@PRI.PlayerName);
				return;
			}
		}
	}
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
function bool GetDefaultSkins(class<KFMonster> KCM, out array<Material> Skins)
{
	if( KCM==None )
		return false;
	if( Class<ZombieBloatBase>(KCM)!=None )
	{
		Skins[0] = Combiner'KF_Specimens_Trip_T.bloat_cmb';
	}
	else if( Class<ZombieBossBase>(KCM)!=None )
	{
		Skins[0]=Combiner'KF_Specimens_Trip_T.gatling_cmb';
		Skins[1]=Combiner'KF_Specimens_Trip_T.patriarch_cmb';
	}
	else if( Class<ZombieClotBase>(KCM)!=None )
	{
		Skins[0]=Combiner'KF_Specimens_Trip_T.clot_cmb';
	}
	else if( Class<ZombieCrawlerBase>(KCM)!=None )
	{
		Skins[0]=Combiner'KF_Specimens_Trip_T.crawler_cmb';
	}
	else if( Class<ZombieFleshPoundBase>(KCM)!=None )
	{
		Skins[0]=Combiner'KF_Specimens_Trip_T.fleshpound_cmb';
		Skins[1]=Shader'KFCharacters.FPAmberBloomShader';
	}
	else if( Class<ZombieGorefastBase>(KCM)!=None )
	{
		Skins[0]=Combiner'KF_Specimens_Trip_T.gorefast_cmb';
	}
	else if( Class<ZombieHuskBase>(KCM)!=None )
	{
		Skins[0]=Texture'KF_Specimens_Trip_T_Two.burns.burns_tatters';
		Skins[1]=Shader'KF_Specimens_Trip_T_Two.burns.burns_shdr';
	}
	else if( Class<ZombieScrakeBase>(KCM)!=None )
	{
		Skins[0]=Shader'KF_Specimens_Trip_T.scrake_FB';
		Skins[1]=TexPanner'KF_Specimens_Trip_T.scrake_saw_panner';
	}
	else if( Class<ZombieSirenBase>(KCM)!=None )
	{
		Skins[0]=FinalBlend'KF_Specimens_Trip_T.siren_hair_fb';
		Skins[1]=Combiner'KF_Specimens_Trip_T.siren_cmb';
	}
	else if( Class<ZombieStalkerBase>(KCM)!=None )
	{
		Skins[0]=Shader'KF_Specimens_Trip_T.stalker_invisible';
		Skins[1]=Shader'KF_Specimens_Trip_T.stalker_invisible';
	}
	else
		return false;
	return true;
}
//--------------------------------------------------------------------------------------------------
function Mesh GetDefaultMesh(class<KFMonster> KCM)
{
	if(KCM==None)
		return none;
	else if (KCM.Default.Mesh != none)
		return KCM.Default.Mesh;
	else if( Class<ZombieBloatBase>(KCM)!=None )
		return Mesh'Bloat_Freak';
	else if( Class<ZombieBossBase>(KCM)!=None )
		return Mesh'Patriarch_Freak';
	else if( Class<ZombieClotBase>(KCM)!=None )
		return Mesh'CLOT_Freak';
	else if( Class<ZombieCrawlerBase>(KCM)!=None )
		return Mesh'Crawler_Freak';
	else if( Class<ZombieFleshPoundBase>(KCM)!=None )
		return Mesh'FleshPound_Freak';
	else if( Class<ZombieGorefastBase>(KCM)!=None )
		return Mesh'GoreFast_Freak';
	else if( Class<ZombieHuskBase>(KCM)!=None )
		return Mesh'Burns_Freak';
	else if( Class<ZombieScrakeBase>(KCM)!=None )
		return Mesh'Scrake_Freak';
	else if( Class<ZombieSirenBase>(KCM)!=None )
		return Mesh'Siren_Freak';
	else if( Class<ZombieStalkerBase>(KCM)!=None )
		return Mesh'Stalker_Freak';
}
//--------------------------------------------------------------------------------------------------
function MCRepInfo GetMCRepInfo(PlayerReplicationInfo PRI)
{
	local LinkedReplicationInfo L;
	for( L=PRI.CustomReplicationInfo; L!=None; L=L.NextReplicationInfo )
		if( MCRepInfo(L)!=none )
			return MCRepInfo(L);
	return none;
}
//--------------------------------------------------------------------------------------------------
// PRI is not none here (checked before call)
function bool GetHealedStats(PlayerReplicationInfo PRI, out int Ret)
{
	// Trying to get stats from ServerPerks if loaded
	// God Marko thank you
	local LinkedReplicationInfo L;

	for( L=PRI.CustomReplicationInfo; L!=None; L=L.NextReplicationInfo )
		if( L.IsA('ClientPerkRepLink') )
		{
			Ret = int(L.GetPropertyText("RWeldingPointsStat"));
			Log("GetHealedStats()->found RDamageHealed for"@PRI.PlayerName@":"@ret);
			return true;
		}

	// trying to get stats from usual SteamStatsAndAchievements
	if (KFSteamStatsAndAchievements(PRI.SteamStatsAndAchievements)!=none)
	{
		Ret = KFSteamStatsAndAchievements(PRI.SteamStatsAndAchievements).DamageHealedStat.Value;
		Log("GetHealedStats()->found DamageHealed for"@PRI.PlayerName@":"@ret);
		return true;
	}

	// Because ServerPerks below v6.1 have server-side bug that ClientPerkRepLink dont added to List,
	// try to find it with next routine
	foreach DynamicActors(class'LinkedReplicationInfo',L)
		if (L.IsA('ClientPerkRepLink'))
			if (PlayerController(L.Owner) == PlayerController(PRI.Owner))
			{
				Ret = int(L.GetPropertyText("RWeldingPointsStat"));
				Log("GetHealedStats()->found RDamageHealed for"@PRI.PlayerName@":"@ret@"With DynamicActors routine");
				// Marco said DynamicActors is SLOW operation, so add it to LinkedRepInfoList
				AddCustomReplicationInfo(PRI, L);
				return true;
			}

	Log("GetHealedStats()->Failed to load any Stats class");
	return false;
}
//--------------------------------------------------------------------------------------------------
simulated function LM(string M)
{
	if (Level==none || Level.NetMode==NM_DedicatedServer)
		return;
	log(M);
	Level.GetLocalPlayerController().ClientMessage(M);
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
defaultproperties
{
	bAlwaysRelevant=true
	RemoteRole=ROLE_SimulatedProxy
	bNetNotify=true

	FakedPlayersNum = 0
	MonstersTotalMod = 1.00
	MonstersMaxAtOnceMod = 1.00

	MonsterBodyHPMod = 1.00
	MonsterHeadHPMod = 1.00
	MonsterSpeedMod = 1.00
	MonsterDamageMod = 1.00

	// В конце волны вычисляем сколько игрок похилил
	// и к его очкам за волну добавляем значение, умноженное на этот коэффициент
	HealedToScoreCoeff = 5.00

	bWaveFundSystem = false
}