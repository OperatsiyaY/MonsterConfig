/* 
 * TODO:
 * 1. Сделать GUI
 * 2. Тестить
 *
 */
//--------------------------------------------------------------------------------------------------
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

// глобальные множители перенесены в GameInfo

// общие
var MCGameType					GT;
var FileLog						MCLog; // отдельный лог
var config class<KFGameType>	GameTypeClass; // позволить юзерам наследовать уже свой GameType, наследованынй от нашего

// замена ZombieVolume на наши MCZombieVolume
var array<ZombieVolume>			PendingZombieVolumes; // будут заменены в след.тике

// массивы настроек
var array<MCMonsterInfo>		Monsters;
var array<MCSquadInfo>			Squads;
var array<MCWaveInfo>			Waves;
var MCMapInfo					MapInfo;
var MCGameInfo					GameInfo; // глобальные коэффициенты перенесеты сюда, чтобы можно было перечитывать конфиг

var array<name> AddToServerPackages; // массив добавляет не стандартные классы из MonsterInfo;

// фикс меши по новому
struct FixMeshStruct
{
	var class<KFMonster>	MClass;
	var Mesh				Mesh;
	var array<Material>		Skins;
};
var config array<FixMeshStruct>	FixMeshInfoConfig;	// массив чтения из конфига
var array<MCFixMeshInfo>		FixMeshInfo;		// основной массив
var MCFixMeshInfo				tFixMeshInfo;		// временный массив для распаковки прибывших мешей
var array<KFMonster>			PendingMonsters;	// через этот массив ищем и добавляем не своих монстров
var bool						bFixChars;			// флаг, указывающий что все меши пофикшены

// репликация значений на клиенты
var const string				RDataDelim;
var MCStringReplicationInfo		RDataMonsters;
var MCStringReplicationInfo		RDataMapInfo;
var MCStringReplicationInfo		RDataFixMeshInfo;
var MCStringReplicationInfo		RDataGameInfo;
var MCMonsterList				AliveMonsters; // массив сопоставления "Монстр - string(MonsterInfoName)"

// GUI
var byte						menuRev, menuRevClient; // определяем, что меню нужно открыть
var PlayerController			menuPC;	// какому игроку открыть меню
var MCStringReplicationInfo		RDataGUI;
var const string				RDataGUIdelim;

// для системы наград от Тело (если GameInfo.bWaveFundSystem==true)
var MCPerkStats					PerkStats;
var array<PlayerController>		PendingPlayers; // игроки, которым присвоить MCRepInfo

// В профайлере обнаружилось, что GetNumPlayers довольно тяжелая функция
// поэтому кэшируем значение и обновляем его реже. NumPlayers так же реплицируется на клиенты
var int		NumPlayers;
var float	NumPlayersRecalcTime;

replication
{
	reliable if (ROLE==ROLE_Authority)
		AliveMonsters, RDataMonsters, RDataMapInfo, RDataFixMeshInfo, RDataGameInfo,
		menuPC, menuRev;

	reliable if (bNetOwner && ROLE==ROLE_Authority)
		RDataGUI;
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
function PostBeginPlay()
{
	local int i;
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
	CheckConfig();
	// добавляем в ServerPackages новые пэкэджи, которые выявили при CheckConfig()
	for( i=AddToServerPackages.Length-1; i>=0; --i )
	{
		LM("MonsterConfig->adding to ServerPackages:"@AddToServerPackages[i]);
		AddToPackageMap(string(AddToServerPackages[i]));
	}

	if (GameInfo.bWaveFundSystem)
		PerkStats = new(None, "PerkStats") class'MCPerkStats';
	
	//SaveConfig(); // портит все закомментированные строчки, пока отключим

	// создаем и формируем массивы репликации клиентам
	RDataMonsters	 = spawn(class'MCStringReplicationInfo',self);
	RDataMapInfo	 = spawn(class'MCStringReplicationInfo',self);
	RDataFixMeshInfo = spawn(class'MCStringReplicationInfo',self);
	RDataGameInfo	 = spawn(class'MCStringReplicationInfo',self);
	MakeRData();

	AliveMonsters	 = spawn(class'MCMonsterList', self);

	GT.PostInit(Self);
}
//--------------------------------------------------------------------------------------------------
function MakeRData()
{
	local int i, bBadCRC;
	local string S, prevS;

	// Формируем строку со всеми MonsterInfo для репликации клиентам
	prevS = RDataMonsters.GetString(bBadCRC); S="";
	for (i=0;i<Monsters.Length;i++)
	{
		if (Len(S)>0)
			S $= rDataDelim;
		S $= Monsters[i].Serialize();
	}
	if (prevS != S)
		RDataMonsters.SetString(S); // увеличивает revision, что даёт клиенту понять о необходимости применения полученых настроек

	// Формируем строку MapInfo для репликации клиентам
	prevS = RDataMapInfo.GetString(bBadCRC); S="";
	S = MapInfo.Serialize();
	if (prevS != S)
		RDataMapInfo.SetString(S);

	// Формируем строку FixMeshInfo
	prevS = RDataFixMeshInfo.GetString(bBadCRC); S="";
	for (i=0;i<FixMeshInfo.Length;i++)
	{
		if (Len(S)>0)
			S $= rDataDelim;
		S $= FixMeshInfo[i].Serialize();
	}
	if (prevS != S)
		RDataFixMeshInfo.SetString(S);
		
	// Формируем GameInfo (глобальные коэффициенты)
	prevS = RDataGameInfo.GetString(bBadCRC); S="";
	S = GameInfo.Serialize();
	if (prevS != S)
		RDataGameInfo.SetString(S);
}
//--------------------------------------------------------------------------------------------------
function string MakeRDataGUI()
{
	local int		i;
	local string	S, retS;

// Monsters
	S="";
	for (i=0;i<Monsters.Length;i++)
	{
		if (Len(S)>0)
			S $= rDataDelim;
		S $= Monsters[i].Serialize();
	}
	if (Len(S)>0)
		retS = "Monsters:" $ S;
// Squads
	S="";
	for (i=0;i<Squads.Length;i++)
	{
		if (Len(S)>0)
			S $= rDataDelim;
		S $= Squads[i].Serialize();
	}
	if (Len(S)>0)
		retS = retS $ RDataGUIdelim $ "Squads:" $ S;
// Waves
	S="";
	for (i=0;i<Waves.Length;i++)
	{
		if (Len(S)>0)
			S $= rDataDelim;
		S $= Waves[i].Serialize();
	}
	if (Len(S)>0)
		retS = retS $ RDataGUIdelim $ "Waves:" $ S;
// MapInfo
	S=""; S = MapInfo.Serialize();
	if (Len(S)>0)
		retS = retS $ RDataGUIdelim $ "MapInfo:" $ S;
// GameInfo
	S=""; S = GameInfo.Serialize();
	if (Len(S)>0)
		retS = retS $ RDataGUIdelim $ "GameInfo:" $ S;
	
	return retS;
}
//--------------------------------------------------------------------------------------------------
simulated function ExtractRDataGUI(string input)
{
	local int i, n;
	local string S;
	local array<string> iData;
	//S = RDataGUI.Unserialize();
	n = Split(input, RDataGUIdelim, iData);
	for (i=0; i<n; i++)
	{
		S = iData[i]; // TODO заменить S на iData[i]
		if (InStr(iData[i], "Monsters:")==0)
			ExtractMonsters( Right(S, Len(S)-Len("Monsters:")), true );
			
		else if (InStr(iData[i], "Squads:")==0)
			ExtractSquads( Right(S, Len(S)-Len("Squads:")), true );
			
		else if (InStr(iData[i], "Waves:")==0)
			ExtractWaves( Right(S, Len(S)-Len("Waves:")), true );
			
		else if (InStr(iData[i], "MapInfo:")==0)
			ExtractMapInfo( Right(S, Len(S)-Len("MapInfo:")) );

		else if (InStr(iData[i], "GameInfo:")==0)
			ExtractGameInfo( Right(S, Len(S)-Len("GameInfo:")) );
	}
}
//--------------------------------------------------------------------------------------------------
// Инициализируем все параметры монстра вызывается из MCZombieVolume
simulated function InitMonster(KFMonster M, string MIName)
{
	local int i, PlayersCount;
	local ZombieBoss Z;
	local float TempDamage, F;
	local MCMonsterInfo MI;
	local Mesh tMesh;
	local array<Material> tSkins;
	local bool lDebug;

	// если это стандартный моб, проверяем и фиксим ему меш и скин
	lDebug = true;
	if (MIName=="_def_")
		goto 'InitMesh';

	MI = GetMonInfoByName(MIName);
	if (MI==none)
	{
		LM("Error: InitMonster MonsterInfo load failed:"@MIName);
		return;
	}
	PlayersCount = GetNumPlayers(true) - 1; // ВЫЧИТАЕМ УЖЕ ТУТ

	lDebug=false;
	if (lDebug) LM("-------------");
	if (lDebug) LM("Init 1"@MI.MonsterName@"Health:"@MI.Health@"HealthMax:"@MI.HealthMax);
	// HEALTH
	if (MI.Health != -1)
		F = MI.Health;
	else
		F = M.Health;
	F += float(MI.PerPlayer.Health * Max(0,PlayersCount));
	if (MI.HealthMax != -1)
		F = FMin(MI.HealthMax, F);
	M.Health = F * (GameInfo.MonsterBodyHPMod * MapInfo.MonsterBodyHPMod);

	Z = ZombieBoss(M);
	if (Z!=none)
	{
		Z.HealingLevels[0] = Z.Health/1.25; // Around 5600 HP
		Z.HealingLevels[1] = Z.Health/2.f; // Around 3500 HP
		Z.HealingLevels[2] = Z.Health/3.2; // Around 2187 HP
		Z.HealingAmount = Z.Health/4; // 1750 HP
	}

	M.HealthMax = M.Health;

	if (MI.HeadHealth != -1)
		F = MI.HeadHealth;
	else
		F = M.HeadHealth;
	F += MI.PerPlayer.HeadHealth * Max(0,PlayersCount);
	if (MI.HeadHealthMax != -1)
		F = FMin(MI.HeadHealthMax, F);
	M.HeadHealth = F * (GameInfo.MonsterHeadHPMod * MapInfo.MonsterHeadHPMod);
	if (lDebug) LM("Init 2"@MI.MonsterName@"M.Health:"@M.Health@"M.HealthMax:"@M.HealthMax);

	// не знаю зачем я это добавлял, но из-за этого если картодел спавнит клота, для командоса
	// на хелсбаре у него будут отображаться не те жизни, т.к. надо еще HealthMax менять, похоже
	//M.default.Health = M.Health;
	//M.default.HeadHealth = M.HeadHealth;

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

	M.OriginalGroundSpeed *= GameInfo.MonsterSpeedMod * MapInfo.MonsterSpeedMod;
	M.GroundSpeed = M.OriginalGroundSpeed;
	M.WaterSpeed *= GameInfo.MonsterSpeedMod * MapInfo.MonsterSpeedMod;
	M.AirSpeed *= GameInfo.MonsterSpeedMod * MapInfo.MonsterSpeedMod;

	TempDamage = M.MeleeDamage * GameInfo.MonsterDamageMod * MapInfo.MonsterDamageMod;
	M.MeleeDamage = TempDamage;
	TempDamage = TempDamage - float(M.MeleeDamage);

	if ( FRand() < TempDamage )
	{
		M.MeleeDamage += 1;
	}

	TempDamage = M.ScreamDamage * GameInfo.MonsterDamageMod * MapInfo.MonsterDamageMod;
	M.MeleeDamage = TempDamage;
	TempDamage = TempDamage - float(M.MeleeDamage);

	if ( FRand() < TempDamage )
	{
		M.ScreamDamage += 1;
	}
/*
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
*/

InitMesh:
	lDebug=false;
	if (MI!=none)
	{
		if (lDebug) LM("Init mesh for"@MI.MonsterName@"Mesh"@string(MI.Mesh[0]));
		if (MI.Mesh.Length>0 && MI.Mesh[0] != none)
			M.LinkMesh(MI.Mesh[0]);
		if (lDebug) LM("Init skins for"@MI.MonsterName@"Skin[0]"@string(MI.Skins[0]));
		if (MI.Skins.Length>0 && MI.Skins[0] != none)
			for (i=0; i<MI.Skins.Length;i++)
			{
				if (lDebug) LM("MI.Skins["$i$"]:"@string(MI.Skins[i]));
				if (MI.Skins[i]!=none)
					M.Skins[i] = MI.Skins[i];
			}
	}

	if (M.Mesh==none)
	{
		if (lDebug) LM("InitMonster->Repair Mesh...");
		tMesh = GetDefaultMesh(M.Class);
		M.UpdateDefaultMesh(tMesh);
		M.static.UpdateDefaultMesh(tMesh);
		M.Class.static.UpdateDefaultMesh(tMesh);
		M.LinkMesh(tMesh);
	}
	if (M.Skins[0]==none)
	{
		if (lDebug) LM("InitMonster->Repair Skins...");
		GetDefaultSkins(M.Class, tSkins);
		for (i=0; i<tSkins.Length; i++)
		{
			M.Skins[i] = tSkins[i];
			M.default.Skins[i] = tSkins[i];
		}
	}
}
//--------------------------------------------------------------------------------------------------
final function AddServerPackage(name N)
{
	local int i;

	if (N=='KFMod' || N=='KFChar')
		return;

	for( i=AddToServerPackages.Length-1; i>=0; --i )
		if( AddToServerPackages[i]==N )
			return;
	AddToServerPackages[AddToServerPackages.Length] = N;
}
//--------------------------------------------------------------------------------------------------
function Mutate(string input, PlayerController PC)
{
	local int n;
	local array<string> iSplit;
	local bool lDebug;
	lDebug = true;
	super.Mutate(input,PC);
	log("MonsterConfig mutate input"@input);
	n = Split(input," ", iSplit);
	if ( n<2 || Caps(iSplit[0]) != "MC" )
		return;
	if (iSplit[1]~="reinit")
	{
		CheckConfig();
		ReInit();
		PC.ClientMessage("MonsterConfig->CheckConfig(), ReInit()");
		return;
	}
	else if (iSplit[1]~="menu")
	{
		menuPC = PC;
		menuRev++;
		if (RDataGUI==none)
			RDataGUI = Spawn(class'MCStringReplicationInfo', PC);
		RDataGUI.SetOwner(PC);
		RDataGUI.OwnerPC = PC;
		RDataGUI.bMenuStr = true;
		RDataGUI.SetString( MakeRDataGUI() );
		RDataGUI.revisionClient = RDataGUI.revision; // сервер отреагирует, после того как клиент изменит
		if (lDebug) PC.ClientMessage("MonsterConfig: Open Menu #"$menuRev);
		return;
	}
	PC.ClientMessage("MonsterConfig Commandlet"@iSplit[1]@"not found");
}
//--------------------------------------------------------------------------------------------------
// При получении новых данных от GUI, в Tick() вызывается эта функция
// переинициализирует настройки GameType в соответсвии с полученными данными
// TODO проверить
function ReInit()
{
	local int i;
	local MCWaveInfo tWaveInfo;
	
	//InitGame
	GT.GameDifficulty = GameInfo.GameDifficulty;

	if (GT.CurWaveInfo!=none)
	{
		i = GT.CurWaveInfo.Position;
		tWaveInfo = GT.CurWaveInfo;
		GT.CurWaveInfo = GetWave(string(GT.CurWaveInfo.Name));
	}
	if (GT.CurWaveInfo==none)
		GT.CurWaveInfo = GetNextWaveInfo(tWaveInfo);
	
	GT.MCSetupWave(true); // bReinit = true;
}
//--------------------------------------------------------------------------------------------------
/*function ReReadConfig() // УДАЛИТЬ перечитать конфиг нельзя
{
	local int i;
	local MCWaveInfo tWaveInfo;
	// очистка массивов перед чтением
	if (GameInfo!=none)
	{
		Level.ObjectPool.FreeObject(GameInfo);
		GameInfo = none;
	}
	if (MapInfo!=none)
	{
		MapInfo.Waves.Remove(0,MapInfo.Waves.Length);
		Level.ObjectPool.FreeObject(MapInfo);
		MapInfo = none;
	}
	for (i=Monsters.Length-1; i>=0; --i)
	{
		Monsters[i].MonsterClass.Remove(0,Monsters[i].MonsterClass.Length);
		Monsters[i].Resist.Remove(0,Monsters[i].Resist.Length);
		Monsters[i].Mesh.Remove(0,Monsters[i].Mesh.Length);
		Monsters[i].Skins.Remove(0,Monsters[i].Skins.Length);
		Level.ObjectPool.FreeObject(Monsters[i]);
		Monsters[i]=none;
		Monsters.Remove(i,1);
	}
	for (i=Squads.Length-1; i>=0; --i)
	{
		Squads[i].Monster.Remove(0,Squads[i].Monster.Length);
		Level.ObjectPool.FreeObject(Squads[i]);
		Squads[i]=none;
		Squads.Remove(i,1);		
	}
	for (i=Waves.Length-1; i>=0; --i)
	{
		Waves[i].Squad.Remove(0,Waves[i].Squad.Length);
		Waves[i].SpecialSquad.Remove(0,Waves[i].SpecialSquad.Length);
		Level.ObjectPool.FreeObject(Waves[i]);
		Waves[i]=none;
		Waves.Remove(i,1);		
	}
	
	ReadConfig();
	CheckConfig();
	
	//InitGame
	GT.GameDifficulty = GameInfo.GameDifficulty;
	
	//SetupWave
	//GT.AdjustedDifficulty = GameInfo.GameDifficulty;
	//GT.FinalWave = Waves.Length - 1;
	if (GT.CurWaveInfo!=none)
	{
		i = GT.CurWaveInfo.Position;
		tWaveInfo = GT.CurWaveInfo;
		GT.CurWaveInfo = GetWave(string(GT.CurWaveInfo.Name));
	}
	if (GT.CurWaveInfo==none)
		GT.CurWaveInfo = GetNextWaveInfo(tWaveInfo);
	
	GT.MCSetupWave(true); // bReinit = true;
	
	MakeRData();
}*/
//--------------------------------------------------------------------------------------------------
function ReadConfig()
{
	local int i,j,n;
	local array<string> Names;

	// чтение FixMeshInfo's
	if (FixMeshInfo.Length==0)
		for (i=0; i<FixMeshInfoConfig.Length; i++)
		{
			if (FixMeshInfoConfig[i].Mesh==none) 
				FixMeshInfoConfig[i].Mesh = GetDefaultMesh(FixMeshInfoConfig[i].MClass);
			if (FixMeshInfoConfig[i].Skins.Length==0 || FixMeshInfoConfig[i].Skins[0]==none)
				GetDefaultSkins(FixMeshInfoConfig[i].MClass, FixMeshInfoConfig[i].Skins);
			
			n = FixMeshInfo.Length;
			FixMeshInfo.Insert(n,1);
			FixMeshInfo[n] = new(none) class'MCFixMeshInfo';
			FixMeshInfo[n].MClass = FixMeshInfoConfig[i].MClass;
			FixMeshInfo[n].Mesh = FixMeshInfoConfig[i].Mesh;
			if (FixMeshInfo[n].Skins.Length < FixMeshInfoConfig[i].Skins.Length)
				FixMeshInfo[n].Skins.Length = FixMeshInfoConfig[i].Skins.Length;
			for (j=0;j<FixMeshInfoConfig[i].Skins.Length; j++)
				FixMeshInfo[n].Skins[j] = FixMeshInfoConfig[i].Skins[j];
		}
	GameInfo = new(None, "GameInfo") class'MCGameInfo';

// МОНСТРЫ
	Names = class'MCMonsterInfo'.static.GetNames();
	for (i = 0; i < Names.length; i++)
	{
		if (Len(Names[i])==0) continue;
		Monsters[Monsters.Length] = new(None, Names[i]) class'MCMonsterInfo';
	}
// ОТРЯДЫ
	Names = class'MCSquadInfo'.static.GetNames();
	for (i = 0; i < Names.length; i++)
	{
		if (Len(Names[i])==0) continue;
		Squads[Squads.Length] = new(None, Names[i]) class'MCSquadInfo';
	}
// ВОЛНЫ
	Names = class'MCWaveInfo'.static.GetNames();
	for (i = 0; i < Names.length; i++)
	{
		if (Len(Names[i])==0) continue;
		Waves[Waves.Length] = new(None, Names[i]) class'MCWaveInfo';
	}
// КАРТО-зависимые переменные
	Names = class'MCMapInfo'.static.GetNames();
	for (i = 0; i < Names.length; i++)
		if (string(Level.outer.name) ~= Names[i])
			{MapInfo = new(None, Names[i]) class'MCMapInfo'; break;}
	// если для данной карты нет переменных, читаем default значения
	if (MapInfo==none)
		MapInfo = new(None, "default") class'MCMapInfo';
}
//--------------------------------------------------------------------------------------------------
/*function ReadConfigOld()
{
	local int i,j,n;
	local array<string> Names;
	local MCMonsterInfo	tMonsterInfo;
	local MCSquadInfo	tSquadInfo;
	local MCWaveInfo	tWaveInfo;
	local MCMapInfo		tMapInfo;

	// чтение FixMeshInfo's
	if (FixMeshInfo.Length==0)
		for (i=0;i<FixMeshInfoConfig.Length;i++)
		{
			if (FixMeshInfoConfig[i].Mesh==none) 
				FixMeshInfoConfig[i].Mesh = GetDefaultMesh(FixMeshInfoConfig[i].MClass);
			if (FixMeshInfoConfig[i].Skins.Length==0 || FixMeshInfoConfig[i].Skins[0]==none)
				GetDefaultSkins(FixMeshInfoConfig[i].MClass, FixMeshInfoConfig[i].Skins);
			
			n = FixMeshInfo.Length;
			FixMeshInfo.Insert(n,1);
			FixMeshInfo[n] = new(none) class'MCFixMeshInfo';
			FixMeshInfo[n].MClass = FixMeshInfoConfig[i].MClass;
			FixMeshInfo[n].Mesh = FixMeshInfoConfig[i].Mesh;
			if (FixMeshInfo[n].Skins.Length < FixMeshInfoConfig[i].Skins.Length)
				FixMeshInfo[n].Skins.Length = FixMeshInfoConfig[i].Skins.Length;
			for (j=0;j<FixMeshInfoConfig[i].Skins.Length; j++)
				FixMeshInfo[n].Skins[j] = FixMeshInfoConfig[i].Skins[j];
		}

	GameInfo = new(None, "GameInfo") class'MCGameInfo';

// МОНСТРЫ
	Names = class'MCMonsterInfo'.static.GetNames();
	for (i = 0; i < Names.length; i++)
	{
		if (Len(Names[i])==0) continue;
		tMonsterInfo = new(None, Names[i]) class'MCMonsterInfo';
		for (j=tMonsterInfo.MonsterClass.Length-1; j>=0; --j)
		{
			if (tMonsterInfo.MonsterClass[j] != none)
			{
				// если трипы удалили Mesh в очередной раз
				/*if (tMonsterInfo.MonsterClass[j].default.Mesh==none && tMonsterInfo.Mesh.Length==0)
					tMonsterInfo.Mesh[0] = GetDefaultMesh(tMonsterInfo.MonsterClass[j]);
				if( (tMonsterInfo.MonsterClass[j].default.Skins.Length==0
					||tMonsterInfo.MonsterClass[j].default.Skins[0]==none) && tMonsterInfo.Skins.Length==0 )
					GetDefaultSkins(tMonsterInfo.MonsterClass[j], tMonsterInfo.Skins);*/

				AddServerPackage( tMonsterInfo.MonsterClass[j].Outer.Name );
			}
			else
			{
				tMonsterInfo.MonsterClass.Remove(j,1);
				toLog("Monster:"@string(tMonsterInfo.Name)$". MonsterClass["$j$"] not found. Check settings in"@class'MCMonsterInfo'.default.ConfigFile$".ini");
			}
		}
		if (tMonsterInfo.MonsterClass.Length>0)
			Monsters[Monsters.Length] = tMonsterInfo;
		else
			toLog("Monster:"@string(tMonsterInfo.Name)$". Will be not loaded. No valid MonsterClasses found. Check settings in"@class'MCMonsterInfo'.default.ConfigFile$".ini");
	}
	if (Monsters.Length==0)
		toLog("No valid Monsters found! So no monsters will spawn");

// ОТРЯДЫ
	Names = class'MCSquadInfo'.static.GetNames();
	for (i = 0; i < Names.length; i++)
	{
		if (Len(Names[i])==0) continue;
		tSquadInfo = new(None, Names[i]) class'MCSquadInfo';
		for (j=0; j<tSquadInfo.Monster.Length; j++)
		{
			for (n=0;n<tSquadInfo.Monster[j].MonsterName.Length;n++)
				if ( GetMonster(tSquadInfo.Monster[j].MonsterName[n]) == none )
				{
					toLog("Squad:"@string(tSquadInfo.Name)@"Monster"@tSquadInfo.Monster[j].MonsterName[n]@"not found. Check settings in"@class'MCSquadInfo'.default.ConfigFile$".ini");
					tSquadInfo.Monster[j].MonsterName.Remove(n,1);
					n--;
				}
			if (tSquadInfo.Monster[j].MonsterName.Length==0)
			{
				toLog("Squad:"@string(tSquadInfo.Name)@"MonsterRecord["$j$"] - No valid monsters found. Check settings in"@class'MCSquadInfo'.default.ConfigFile$".ini");
				tSquadInfo.Monster.Remove(j,1);
				j--;
			}
		}
		if (tSquadInfo.Monster.Length > 0)
		{
			Squads.Insert(0,1);
			Squads[0] = tSquadInfo;
		}
		else
			toLog("Squad:"@string(tSquadInfo.Name)@"No valid monster records found. Check settings in"@class'MCSquadInfo'.default.ConfigFile$".ini");
	}
	if (Squads.Length==0)
		toLog("No valid Squads found! So no monsters will spawn");

// ВОЛНЫ
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
			while (bWavePositionAlreadyExist(tWaveInfo.Position)>1)
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

// КАРТЫ
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
}*/
//--------------------------------------------------------------------------------------------------
function CheckConfig()
{
	local int i,j,n;
	local bool bFound;

// МОНСТРЫ
	for (i=Monsters.Length-1; i>=0; --i)
	{
	// Валидность MonsterClass'ов
		for (j=Monsters[i].MonsterClass.Length-1; j>=0; --j)
		{
			if (Monsters[i].MonsterClass[j] == none)
			{
				toLog("Monster:"@string(Monsters[i].Name)$". MonsterClass["$j$"] not found. Check settings in"@class'MCMonsterInfo'.default.ConfigFile$".ini");
				Monsters[i].MonsterClass.Remove(j,1); continue;
			}
			else
				AddServerPackage( Monsters[i].MonsterClass[j].Outer.Name );
		}
		if (Monsters[i].MonsterClass.Length==0)
		{
			toLog("Monster:"@string(Monsters[i].Name)$". Will be not loaded. No valid MonsterClasses found. Check settings in"@class'MCMonsterInfo'.default.ConfigFile$".ini");
			Monsters.Remove(i,1);
			continue;
		}
	// Валидность Резистов
		for (j=Monsters[i].Resist.Length-1; j>=0; --j)
			if (Monsters[i].Resist[j].DamType==none)
			{
				toLog("Monster:"@string(Monsters[i].Name)$". Invalid DamType for Resist["$j$"]. Check settings in"@class'MCMonsterInfo'.default.ConfigFile$".ini");
				Monsters[i].Resist.Remove(j,1); continue;
			}		
	}
	if (Monsters.Length==0)
		toLog("No valid Monsters found! So no monsters will spawn");
// ОТРЯДЫ
	for (i=Squads.Length-1; i>=0; --i)
	{
	// Валидность Squads[i]
		for (j=Squads[i].Monster.Length-1; j>=0; --j)
		{
		// Проверяем Monster[j]
			for (n=Squads[i].Monster[j].MonsterName.Length-1; n>=0; --n)
				if ( GetMonster(Squads[i].Monster[j].MonsterName[n]) == none )
				{
					toLog("Squad:"@string(Squads[i].Name)@"Monster"@Squads[i].Monster[j].MonsterName[n]@"not found. Check settings in"@class'MCSquadInfo'.default.ConfigFile$".ini");
					Squads[i].Monster[j].MonsterName.Remove(n,1);					
					continue;
				}
			if (Squads[i].Monster[j].MonsterName.Length==0)
			{
				toLog("Squad:"@string(Squads[i].Name)@"MonsterRecord["$j$"] - No valid monsters found. Check settings in"@class'MCSquadInfo'.default.ConfigFile$".ini");
				Squads[i].Monster.Remove(j,1);
			}
		}
		if (Squads[i].Monster.Length==0)
		{
			toLog("Squad:"@string(Squads[i].Name)@"No valid monster records found. Check settings in"@class'MCSquadInfo'.default.ConfigFile$".ini");
			Squads.Remove(i,1);
		}
	}
	if (Squads.Length==0)
		toLog("No valid Squads found! So no monsters will spawn");

// ВОЛНЫ загружаем ВСЕ волны (в которых есть отряды)
	for (i=Waves.Length-1; i>=0; --i)
	{
		//if (Waves[i].bMapSpecific) // на этом этапе удаляем все bMapSpecific волны (грузим их позже)
		//	{Waves.Remove(i,1); continue;}

		// удаляем Squad'ы, имен которых нет в конфиге
		for (j=Waves[i].Squad.Length-1; j>=0; --j)
			if ( GetSquad(Waves[i].Squad[j]) == none )
				Waves[i].Squad.Remove(j,1);
		// удаляем SpecialSquad'ы, имен которых нет в конфиге
		for (j=Waves[i].SpecialSquad.Length-1; j>=0; --j)
			if ( GetSquad(Waves[i].SpecialSquad[j]) == none )
				Waves[i].SpecialSquad.Remove(j,1);
		// Если валидных сквадов не осталось, удаляем волну
		if (Waves[i].Squad.Length==0 && Waves[i].SpecialSquad.Length==0)
		{
			toLog("Wave:" @ string(Waves[i].Name) @ "Dont have valid squads. Check"@class'MCWaveInfo'.default.ConfigFile$".ini");
			Waves.Remove(i,1); continue;
		}

	}
// MapInfo - удаляем не валидные названия волн.
	for (i=MapInfo.Waves.Length-1; i>=0; --i)
		if ( Len(MapInfo.Waves[i])==0 || !isValidWaveName(MapInfo.Waves[i]) )
		{
			toLog("MapInfo:"@string(MapInfo.Name)@" | WaveName"@MapInfo.Waves[i]@"is not valid. Check"@class'MCWaveInfo'.default.ConfigFile$".ini");
			MapInfo.Waves.Remove(i,1); continue;
		}
// В загруженных волнах ищем bMapSpecific и оставляем только те, которые указаны в MapInfo
	for (i=Waves.Length-1; i>=0; --i)
		if (Waves[i].bMapSpecific)
		{
			bFound = false;
			for (j=MapInfo.Waves.Length-1; j>=0; --j)
				if( string(Waves[i].Name) ~= MapInfo.Waves[j] )
					{bFound=true; break;}
			if (!bFound)
				Waves.Remove(i,1);
		}
// Проверяем Position волн
	for (i=Waves.Length-1; i>=0; --i)
	{
		// Position не указан - пытаемся выяснить номер волны исходя из названия "Wave_4lol" - 4я волна
		if (Waves[i].Position==-1)
			TryGetNumber(string(Waves[i].Name), Waves[i].Position);
		while (bWavePositionAlreadyExist(Waves[i].Position)>1 || Waves[i].Position==-1)
		{
			toLog("Wave:"@string(Waves[i].Name)@"Position"@Waves[i].Position@Eval(bWavePositionAlreadyExist(Waves[i].Position)>1,"already exists","not specified") @ "Check"@class'MCWaveInfo'.default.ConfigFile$".ini");
			Waves[i].Position+=0.1;
		}
		// TODO делать ли tWaveInfo.SaveConfig(), чтобы записать только что найденый Position?? Тогда из конфига удалятся невалидные сквады
		toLog("Wave:"@string(Waves[i].Name)@"loaded with position"@Waves[i].Position);
	}
	if (Waves.Length==0)
		toLog("No valid WaveInfo's found! So no monsters will spawn");
}
//--------------------------------------------------------------------------------------------------
function int bWavePositionAlreadyExist(float F)
{
	local int i, n;
	for (i=Waves.Length-1; i>=0; --i)
		if (Waves[i].Position == F)
			n++;
	return n;
}
//--------------------------------------------------------------------------------------------------
function MCWaveInfo GetLastWave()
{
	local int i;
	local MCWaveInfo Wave;
	Wave = Waves[0];
	toLog("GetLastWave() Best Wave:"@string(Wave.Name)@Wave.Position);
	for (i=Waves.Length-1; i>=0; --i)
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
	for (i=Waves.Length-1; i>=0; --i)
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
	for (i=Names.Length-1; i>=0; --i)
		if (WaveName ~= Names[i])
			return true;
	return false;
}
//--------------------------------------------------------------------------------------------------
// УЖЕ НЕ ИСПОЛЬЗУЕТСЯ, можно подчистить
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
	for (i=Squads.Length-1; i>=0; --i)
		if (SquadName ~= string(Squads[i].Name))
			return Squads[i];
	return None;
}
//--------------------------------------------------------------------------------------------------
function MCMonsterInfo GetMonster(string MonsterName)
{
	local int i;
	for (i=Monsters.Length-1; i>=0; --i)
		if (MonsterName ~= string(Monsters[i].Name))
			return Monsters[i];
	return None;
}
//--------------------------------------------------------------------------------------------------
function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
	// Спавним MCRepInfo наш Linked ReplicationInfo с доп.статистикой и своим KillsMessage
	if (PlayerController(Other)!=none)
	{
		PendingPlayers[PendingPlayers.Length] = PlayerController(Other);
		SetTimer(0.1,false);
	}

	// Mesh-фикс не наших монстров
	else if (KFMonster(Other)!=none)
	{
		PendingMonsters[PendingMonsters.Length] = KFMonster(Other);
		SetTimer(0.1, false);
	}

	// Замена ZombieVolumes на MCZombieVolume
	else if ( ZombieVolume(Other)!=none && MCZombieVolume(Other)==none )
		PendingZombieVolumes[PendingZombieVolumes.Length] = ZombieVolume(Other);

	return true;
}
//--------------------------------------------------------------------------------------------------
// разворачиваем на клиенте реплицированную строку MapInfo
simulated function ExtractMapInfo(string input)
{
	local string tName;
	/*	
	if (MapInfo!=none)
	{
		MapInfo.Waves.Remove(0,MapInfo.Waves.Length);
		Level.ObjectPool.FreeObject(MapInfo);
		MapInfo = none;
	}
	*/
	tName = class'MCMapInfo'.static.UnSerializeName(input);
	if (MapInfo==none)
		MapInfo = new(None, tName) class'MCMapInfo';
	MapInfo.Unserialize(input);
	LM("Client got MapInfo. Name"@tName@"Level.outer.name"@string(Level.outer.name));
}
//--------------------------------------------------------------------------------------------------
// разворачиваем на клиенте реплицированную строку содержащую MonsterInfo's
// разворачиваем на сервере информацию из GUI (флаг bClear указывает, что вначале нужно все стереть)
simulated function ExtractMonsters(string input, optional bool bClear)
{
	local int				i,j,n;
	local string			MInfoStr, S;
	local array<string>		iSplit;
	local bool				bFound;

	if (bClear)
		for (i=Monsters.Length-1; i>=0; --i)
		{
			Monsters[i].MonsterClass.Remove(0,Monsters[i].MonsterClass.Length);
			Monsters[i].Resist.Remove(0,Monsters[i].Resist.Length);
			Monsters[i].Mesh.Remove(0,Monsters[i].Mesh.Length);
			Monsters[i].Skins.Remove(0,Monsters[i].Skins.Length);
			Level.ObjectPool.FreeObject(Monsters[i]);
			Monsters[i]=none;
			Monsters.Remove(i,1);
		}
	
	n = Split(input, rDataDelim, iSplit);
	for (i=0;i<n;i++)
	{
		MInfoStr = iSplit[i];
		S = class'MCMonsterInfo'.static.UnserializeName(MInfoStr);
		bFound=false;
		for (j=0;j<Monsters.Length;j++)
			if (string(Monsters[j].Name) ~= S)
			{
				bFound=true;
				Monsters[j].Unserialize(MInfoStr);
				LM("Client got MonsterInfo for"@S@string(Monsters[j].Name));
				break;
			}
		if (bFound==false)
		{
			j = Monsters.Length;
			Monsters.Insert(j,1);
			Monsters[j] = new(None, S) class'MCMonsterInfo';
			Monsters[j].Unserialize(MInfoStr);
			LM("Client got MonsterInfo for"@S@string(Monsters[j].Name));
		}
	}
}
//--------------------------------------------------------------------------------------------------
// TODO проверить работоспособность
simulated function ExtractSquads(string input, optional bool bClear)
{
	local int i,j,n;
	local array<string> iSplit;
	local string S;
	local bool bFound;
	
	if (bClear)
		for (i=Squads.Length-1; i>=0; --i)
		{
			Squads[i].Monster.Remove(0,Squads[i].Monster.Length);
			Level.ObjectPool.FreeObject(Squads[i]);
			Squads[i]=none;
			Squads.Remove(i,1);		
		}

	n = Split(input, rDataDelim, iSplit);
	for (i=0;i<n;i++)
	{
		S = class'MCSquadInfo'.static.UnserializeName(iSplit[i]);
		bFound=false;
		for (j=0;j<Squads.Length;j++)
			if (string(Squads[j].Name) ~= S)
			{
				bFound=true;
				Squads[j].Unserialize(iSplit[i]);
				LM("Client got SquadInfo for"@S@string(Squads[j].Name));
				break;
			}
		if (bFound==false)
		{
			j = Squads.Length;
			Squads.Insert(j,1);
			Squads[j] = new(None, S) class'MCSquadInfo';
			Squads[j].Unserialize(iSplit[i]);
			LM("Client got SquadInfo for"@S@string(Squads[j].Name));
		}
	}
}
//--------------------------------------------------------------------------------------------------
// TODO проверить работоспособность
simulated function ExtractWaves(string input, optional bool bClear)
{
	local int i,j,n;
	local array<string> iSplit;
	local string S;
	local bool bFound;

	if (bClear)
		for (i=Waves.Length-1; i>=0; --i)
		{
			Waves[i].Squad.Remove(0,Waves[i].Squad.Length);
			Waves[i].SpecialSquad.Remove(0,Waves[i].SpecialSquad.Length);
			Level.ObjectPool.FreeObject(Waves[i]);
			Waves[i]=none;
			Waves.Remove(i,1);		
		}

	n = Split(input, rDataDelim, iSplit);
	for (i=0;i<n;i++)
	{
		S = class'MCWaveInfo'.static.UnserializeName(iSplit[i]);
		bFound=false;
		for (j=0;j<Waves.Length;j++)
			if (string(Waves[j].Name) ~= S)
			{
				bFound=true;
				Waves[j].Unserialize(iSplit[i]);
				LM("Client got WaveInfo for"@S@string(Waves[j].Name));
				break;
			}
		if (bFound==false)
		{
			j = Waves.Length;
			Waves.Insert(j,1);
			Waves[j] = new(None, S) class'MCWaveInfo';
			Waves[j].Unserialize(iSplit[i]);
			LM("Client got WaveInfo for"@S@string(Waves[j].Name));
		}
	}
}
//--------------------------------------------------------------------------------------------------
simulated function ExtractGameInfo(string input)
{
	/*if (GameInfo!=none)
	{
		Level.ObjectPool.FreeObject(GameInfo);
		GameInfo = none;
	}*/
	GameInfo.Unserialize(input);
}
//--------------------------------------------------------------------------------------------------
simulated function ExtractFixMeshInfo(string input)
{
	local int				i,j,n;
	local string			S;
	local array<string>		iSplit;
	local bool				bFound;

	n = Split(input, rDataDelim, iSplit);
	for (i=0;i<n;i++)
	{
		S = iSplit[i];
		if (tFixMeshInfo==none)
			tFixMeshInfo = new(none) class'MCFixMeshInfo';
		tFixMeshInfo.Unserialize(S);
		bFound=false;
		for (j=0;j<FixMeshInfo.Length;j++)
			if (tFixMeshInfo.MClass == FixMeshInfo[j].MClass)
			{
				bFound = true;
				FixMeshInfo[j].Unserialize(iSplit[i]);
				LM("Arrived FixMeshInfo for"@string(FixMeshInfo[j].MClass)@"(already haved it)");
				break;
			}
		if (bFound==false)
		{
			j = FixMeshInfo.Length;
			FixMeshInfo[j] = new(none) class'MCFixMeshInfo';
			FixMeshInfo[j].Unserialize(S);
			LM("Arrived new FixMeshInfo for"@string(FixMeshInfo[j].MClass));
		}
	}
}
//--------------------------------------------------------------------------------------------------
simulated function FixMeshInfos()
{
	local int i,j;
	local MCFixMeshInfo tFixInfo;
	local bool lDebug;
	lDebug = false;

	for (i=FixMeshInfo.Length-1; i>=0; --i)
	{
		tFixInfo = FixMeshInfo[i];
		if (tFixInfo.MClass==none)
		{
			toLog("Error in FixMeshInfo["$i$"]: MClass==none");
			continue;
		}
		if (tFixInfo.Mesh!=none)
		{
			tFixInfo.MClass.static.UpdateDefaultMesh(tFixInfo.Mesh);
			if (lDebug) LM("Fixed mesh for"@string(tFixInfo.MClass)@"Mesh"@string(tFixInfo.Mesh));
		}
		else
			toLog("Error in FixMeshInfo: Mesh==none for"@string(tFixInfo.MClass));

		for (j=0;j<tFixInfo.Skins.Length;j++)
		{
			if (tFixInfo.Skins[j] != none)
			{
				tFixInfo.MClass.default.Skins[j] = tFixInfo.Skins[j];
				if (lDebug) LM("Fixed skin for"@string(tFixInfo.MClass)@"Skin["$j$"]"@tFixInfo.Skins[j]);
			}
			else
				toLog("Error in FixMeshInfo Skins["$j$"]==none for"@string(tFixInfo.MClass));
		}
	}
}
//--------------------------------------------------------------------------------------------------
simulated function Tick(float dt)
{
	local int bBadCRC;
	local string S;
	local bool lDebug;
	lDebug = true;

	if (Level == none)
		return;

// ВСЕ
	// Фиксим FixMeshInfo
	if (bFixChars==false
		&& RDataFixMeshInfo!=none
		&& RDataFixMeshInfo.revisionClient != RDataFixMeshInfo.revision)
	{
		S = RDataFixMeshInfo.GetString(bBadCRC);
		if (bBadCRC==0 && Len(S)>0)
		{
			LM("Tick: Got RDataFixMeshInfo");
			ExtractFixMeshInfo(S);
			FixMeshInfos();
			RDataFixMeshInfo.revisionClient = RDataFixMeshInfo.revision;
			bFixChars=true;
		}
	}

// СЕРВЕР или STANDALONE
	if (Level.NetMode != NM_Client)
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
		
		// Apply arrived new RDataGUI on ServerSide, and prepare new RDataServer
		/*
		if (RDataGUI != none && RDataGUI.revisionClient != RDataGUI.revision)
		{
			S = RDataGUI.GetString(bBadCRC);
			if (bBadCRC==0)
			{
				RDataGUI.revisionClient = RDataGUI.revision;
				ExtractRDataGUI(S);	// разворачиваем пришедшие данные
				CheckConfig();		// проверяем пришедшие данные
				
				// тут баг. в Standalone вызывает постоянный прием RDataGUI и вызов ExtractALL
				/*ScriptLog: LM:Client got MonsterInfo for clot clot
				ScriptLog: LM:Client got MonsterInfo for GoreFast GoreFast
				ScriptLog: LM:Client got MonsterInfo for Crawler Crawler
				ScriptLog: LM:Client got MonsterInfo for Bloat Bloat
				ScriptLog: LM:Client got MonsterInfo for Stalker Stalker
				ScriptLog: LM:Client got MonsterInfo for siren siren
				ScriptLog: LM:Client got MonsterInfo for Husk Husk
				ScriptLog: LM:Client got MonsterInfo for Scrake Scrake
				ScriptLog: LM:Client got MonsterInfo for Fleshpound Fleshpound
				ScriptLog: LM:Client got MonsterInfo for Boss Boss
				ScriptLog: LM:Client got MonsterInfo for Brute Brute
				ScriptLog: LM:Client got MonsterInfo for Jason Jason
				ScriptLog: LM:Client got MonsterInfo for Fatale Fatale
				ScriptLog: LM:Client got MonsterInfo for ClotBossInvis ClotBossInvis
				ScriptLog: LM:Client got MonsterInfo for BruteDTDK BruteDTDK
				ScriptLog: LM:Client got SquadInfo for sq_Clot sq_Clot
				ScriptLog: LM:Client got SquadInfo for sq_Cl_Gf_Cr sq_Cl_Gf_Cr
				ScriptLog: LM:Client got SquadInfo for sq_Gorefast sq_Gorefast
				ScriptLog: LM:Client got SquadInfo for sq_Crawler sq_Crawler
				ScriptLog: LM:Client got SquadInfo for sq_Stalker sq_Stalker
				ScriptLog: LM:Client got SquadInfo for sq_Siren sq_Siren
				ScriptLog: LM:Client got SquadInfo for sq_Husk sq_Husk
				ScriptLog: LM:Client got SquadInfo for sq_Brute sq_Brute
				ScriptLog: LM:Client got SquadInfo for sq_Scrake sq_Scrake
				ScriptLog: LM:Client got SquadInfo for sq_Jason sq_Jason*/
				//MakeRData();		// реплицируем новые данные клиентам 
				
				ReInit();
			}
		}*/
	}

// КЛИЕНТ или STANDALONE
	if (Level.NetMode!=NM_DedicatedServer)
	{
	// Открываем GUI
		if ( menuRevClient != menuRev && menuPC != none )
		{
			if( menuPC != Level.GetLocalPlayerController() )
				menuRevClient = menuRev;
			else if( RDataGUI != none )					
			{
				S = RDataGUI.GetString(bBadCRC);
				if (bBadCRC==0 && Len(S)>0)
				{
					ExtractRDataGUI(S);
					menuRevClient = menuRev;
					menuPC.ClientOpenMenu(string(Class'MCGUIMenu'),,,);
					if (lDebug) menuPC.ClientMessage("MonsterConfig: Now you must see the GUI menu");
				}
			}
		}
		
	// Принимаем Monsters
		if (RDataMonsters!=none
			&& RDataMonsters.revisionClient != RDataMonsters.revision)
		{
			S = RDataMonsters.GetString(bBadCRC);
			if (bBadCRC==0 && Len(S)>0)
			{
				LM("Tick: Got RDataMonsters");
				RDataMonsters.revisionClient = RDataMonsters.revision;
				ExtractMonsters(S);
			}
		}

	// Принимаем MapInfo
		if (RDataMapInfo!=none
			&& RDataMapInfo.revisionClient != RDataMapInfo.revision)
		{
			S = RDataMapInfo.GetString(bBadCRC);
			if (bBadCRC==0 && Len(S)>0)
			{
				RDataMapInfo.revisionClient = RDataMapInfo.revision;
				ExtractMapInfo(S);
			}
		}
		
	// Принимаем GameInfo
		if (RDataGameInfo!=none
			&& RDataGameInfo.revisionClient != RDataGameInfo.revision)
		{
			S = RDataGameInfo.GetString(bBadCRC);
			if (bBadCRC==0 && Len(S)>0)
			{
				RDataGameInfo.revisionClient = RDataGameInfo.revision;
				if (GameInfo==none)
					GameInfo = new(None, "GameInfo") class'MCGameInfo';
				toLog("GameInfo arrived");
				GameInfo.Unserialize(S);
			}
		}
	}
}
//--------------------------------------------------------------------------------------------------
simulated function MCMonsterInfo GetMonInfoByName(string MName)
{
	local int j;
	for (j=Monsters.Length-1; j>=0; --j)
		if (MName ~= string(Monsters[j].Name))
			return Monsters[j];
	return none;
}
//--------------------------------------------------------------------------------------------------
function MCMonsterInfo GetMonInfo(Controller C)
{
	local int j;
	local MCMonsterList AM;

	 for (AM=AliveMonsters; (AM!=none && (AM==AliveMonsters || !AM.bDeleted)); AM = AM.Next)
		if (AM.Controller == C && Len(AM.MonsterInfoName)>0)
			for (j=Monsters.Length-1; j>=0; --j)
				if (AM.MonsterInfoName ~= string(Monsters[j].Name))
					return Monsters[j];
	return none;
}
//--------------------------------------------------------------------------------------------------
simulated function WaveEnd()
{
	AliveMonsters.Clear();
}
//--------------------------------------------------------------------------------------------------
// Заполняем массив AliveMonsters, для сопоставления Monster и его MonsterInfo (для ReduceDamage)
function NotifyMonsterSpawn(Controller Controller, MCMonsterInfo MonInfo)
{
	AliveMonsters.Add(Controller, string(MonInfo.Name));
}
//--------------------------------------------------------------------------------------------------
function NotifyMonsterKill(Controller Controller)
{
	AliveMonsters.Del(Controller);
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
	/*
	 * if (MCLog==none)
	{
		MCLog = Spawn(class'FileLog');
		MCLog.OpenLog("MonsterConfigLog","log",true); // overwrite
		MCLog.LogF("---------------------------------------------");
		SetTimer(15,false);
	}*/
	if ( Sender != none )
		Spec = String(Sender.Name)$"->";
	else
		Spec = string(self.name)$"->";

	//MCLog.LogF(Spec $ M);
	Log(Spec $ M);
}
//--------------------------------------------------------------------------------------------------
function Destroyed()
{
	if (MCLog!=none)
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
	local bool lDebug;
	lDebug=true;

	if (CurWave==none) // при первой волне
	{
		Ret = GetFirstWave();
		if (lDebug) toLog("GetNextWaveInfo(): CurWave==none, returning FirstWave"@string(Ret.Name));
		return Ret;
	}

	BestPos = CurWave.Position;
	for (i=Waves.Length-1; i>=0; --i)
	{
		if ( Waves[i].Position <= CurWave.Position )	// ищем только волны, следующие за текущей,
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
	{
		if (lDebug) toLog("GetNextWaveInfo(): Ret == CurWave"@string(CurWave.Name)@"so return none");
		return none;
	}
	
	if (lDebug) toLog("GetNextWaveInfo(): CurWave"@string(CurWave.Name)@"NextWave"@string(Ret.Name));
	return Ret;
}
//--------------------------------------------------------------------------------------------------
function MCWaveInfo GetWave(string W)
{
	local int i;
	for (i=Waves.Length-1; i>=0; --i)
		if (W ~= string(Waves[i].Name))
			return Waves[i];
	return none;
}
//--------------------------------------------------------------------------------------------------
function int GetWaveNum(MCWaveInfo Wave)
{
	local int i, num;
	num = 1;
	for (i=Waves.Length-1; i>=0; --i)
	{
		if (Waves[i].Position < Wave.Position)
			num++;
	}
	toLog("GetWaveNum->Wave"@string(Wave.Name)@"WaveNum is"@num);
	return num;
}
//--------------------------------------------------------------------------------------------------
simulated function float GetNumPlayers(optional bool bOnlyAlive, optional bool bNotCountFaked)
{
	local Controller C;

	// пересчет только на сервере (controllerы на клиенте не спавнятся)
	// пересчитанный numplayers реплицируется на клиенты, для них эта функция остается рабочей
	if (Level.NetMode != NM_Client)
	{
		if (NumPlayersRecalcTime<Level.TimeSeconds) // кэшируем значение, пересчет каждые 5 сек
		{
			NumPlayers=0;
			for( C=Level.ControllerList; C!=None; C=C.NextController )
				if( C.bIsPlayer && ( !bOnlyAlive || (C.Pawn!=None && C.Pawn.Health > 0 ) ) )
					NumPlayers++;
			NumPlayersRecalcTime = Level.TimeSeconds + 5.f;
		}
	}

	if ( !bNotCountFaked )
		return NumPlayers + GameInfo.FakedPlayersNum;
	return NumPlayers;
}
//--------------------------------------------------------------------------------------------------
function Timer()
{
	local int i;
	local MCRepInfo RInfo;
	local KFMonster Mon;

	/*// Скидываем лог на диск
	if ( MCLog != none )
	{
		MCLog.CloseLog();
		MCLog.OpenLog("MonsterConfigLog","log",false);
	}
	SetTimer(15,false);*/

	if (Level!=none && Level.NetMode != NM_Client)
	{
		// Спавним MCCustomRepInfo (для работы Killmessages) и bWaveFundSystem
		for( i=PendingPlayers.Length-1; i>=0; --i )
		{
			if (PendingPlayers[i] == none)
			{
				PendingPlayers.Remove(i,1);
				continue;
			}
			else if( PendingPlayers[i].Player != none
					&& PendingPlayers[i].PlayerReplicationInfo != none )
			{
				RInfo = GetMCRepInfo(PendingPlayers[i].PlayerReplicationInfo);
				if (RInfo==none)
					RInfo = Spawn(class'MCRepInfo', PendingPlayers[i]); // вставится в CustomRepLink цепочку сама

				RInfo.SandboxController = self; // для ClientKilledMonster, чтобы иметь доступ к Monsters и именам монстров

				if (GetHealedStats(PendingPlayers[i].PlayerReplicationInfo, RInfo.HealedStat))
					PendingPlayers.Remove(i,1);
			}
		}
		if (PendingPlayers.Length>0)
			SetTimer(0.1,false);

		// Добавляем только тех, у которых Mesh==none (по сути, до AliveMonsters.Find не доходит никто)
		for (i=PendingMonsters.Length-1; i>=0; --i)
		{
			Mon = PendingMonsters[i];
			if( Mon != none && Mon.Controller != none
				&& (Mon.Mesh==none || (Mon.Skins.Length==0 || Mon.Skins[0] == none))
				&& AliveMonsters.Find(Mon.Controller)==none )
			{
				LM("Adding PendingMonsters as Default AliveMonsters");
				AliveMonsters.Add(Mon.Controller,"_def_");
			}
			PendingMonsters.Remove(i,1);
		}
	}
	Super.Timer();
}
//--------------------------------------------------------------------------------------------------
function AddCustomReplicationInfo(PlayerReplicationInfo PRI, LinkedReplicationInfo iL)
{
	local LinkedReplicationInfo L;
	if (PRI.CustomReplicationInfo == none)
		PRI.CustomReplicationInfo = iL;
	else
	{
		for( L=PRI.CustomReplicationInfo; L!=none; L=L.NextReplicationInfo )
		{
			if (L.Class==iL.Class)
			{
				warn(L.Class@"already loaded for"@PRI.PlayerName);
				return;
			}
		}

		for( L=PRI.CustomReplicationInfo; L!=none; L=L.NextReplicationInfo )
		{
			if( L.NextReplicationInfo==none )
			{
				L.NextReplicationInfo = iL; // Add to the end of the chain.
				log(iL.Class@"loaded for"@PRI.PlayerName);
				return;
			}
		}
	}
}
//--------------------------------------------------------------------------------------------------
simulated function bool GetDefaultSkins(class<KFMonster> KCM, out array<Material> Skins)
{
	local int i,j;
	if( KCM==None )
		return false;

	for (i=FixMeshInfo.Length-1; i>=0; --i)
		if ( ClassIsChildOf(KCM, FixMeshInfo[i].MClass) )
		{
			if (Skins.Length < FixMeshInfo[i].Skins.Length)
				Skins.Length = FixMeshInfo[i].Skins.Length;
			for (j=0; j<FixMeshInfo[i].Skins.Length; j++)
				if (FixMeshInfo[i].Skins[j] != none)
					Skins[j] = FixMeshInfo[i].Skins[j];
			return true;
		}

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
simulated function Mesh GetDefaultMesh(class<KFMonster> KCM)
{
	local int i;
	if(KCM==None)
		return none;
	for (i=FixMeshInfo.Length-1; i>=0; --i)
		if ( ClassIsChildOf(KCM, FixMeshInfo[i].MClass) )
			return FixMeshInfo[i].Mesh;

	if (KCM.Default.Mesh != none)
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
	return none;
}
//--------------------------------------------------------------------------------------------------
function MCRepInfo GetMCRepInfo(PlayerReplicationInfo PRI)
{
	local LinkedReplicationInfo L;
	local MCRepInfo RInfo;
	local PlayerController PC;
	for( L=PRI.CustomReplicationInfo; L!=none; L=L.NextReplicationInfo )
		if( MCRepInfo(L)!=none )
		{
			//LM("MCRepInfo for"@PRI.PlayerName@"found with CustomReplicationInfo list");
			return MCRepInfo(L);
		}

	// если не получилось найти, пробуем использовать способ с DynamicActors
	PC = PlayerController(PRI.Owner);
	if (PC!=none)
	{
		foreach DynamicActors(class'MCRepInfo', RInfo)
			if (RInfo.Owner == PRI.Owner)
			{
				warn("MonsterConfig: MCRepInfo for"@PRI.PlayerName@"found with DynamicActors");
				AddCustomReplicationInfo(PRI,RInfo);
				return RInfo;
			}
	}
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
			Ret = int(L.GetPropertyText("RDamageHealed")); // RWeldingPointsStat
			Log("GetHealedStats()->found RDamageHealed for"@PRI.PlayerName@":"@ret);
			return true;
		}

	// trying to get stats from usual SteamStatsAndAchievements
	if (KFSteamStatsAndAchievements(PRI.SteamStatsAndAchievements)!=none)
	{
		Ret = KFSteamStatsAndAchievements(PRI.SteamStatsAndAchievements).DamageHealedStat.Value;
		//Ret = KFSteamStatsAndAchievements(PRI.SteamStatsAndAchievements).WeldingPointsStat.Value;
		Log("GetHealedStats()->found DamageHealed for"@PRI.PlayerName@":"@ret);
		return true;
	}

	// Because ServerPerks below v6.1 have server-side bug that ClientPerkRepLink dont added to List,
	// try to find it with next routine
	foreach DynamicActors(class'LinkedReplicationInfo',L)
		if (L.IsA('ClientPerkRepLink'))
			if (PlayerController(L.Owner) == PlayerController(PRI.Owner))
			{
				Ret = int(L.GetPropertyText("RDamageHealed"));
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
	log("LM:"$M);
	if (Level!=none && Level.GetLocalPlayerController()!=none)
		Level.GetLocalPlayerController().ClientMessage("LM:"$M);
}

//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
defaultproperties
{
	bAddToServerPackages=True

	bAlwaysRelevant=true
	RemoteRole=ROLE_SimulatedProxy
	//bNetNotify=true
	RDataDelim = "***"
	RDataGUIdelim = "==="

	FixMeshInfoConfig(0)=(MClass=Class'KFChar.ZombieClot',Mesh=SkeletalMesh'KF_Freaks_Trip.CLOT_Freak',Skins=(Combiner'KF_Specimens_Trip_T.clot_cmb'))
	FixMeshInfoConfig(1)=(MClass=Class'KFChar.ZombieGorefast',Mesh=SkeletalMesh'KF_Freaks_Trip.GoreFast_Freak',Skins=(Combiner'KF_Specimens_Trip_T.gorefast_cmb'))
	FixMeshInfoConfig(2)=(MClass=Class'KFChar.ZombieCrawler',Mesh=SkeletalMesh'KF_Freaks_Trip.Crawler_Freak',Skins=(Combiner'KF_Specimens_Trip_T.crawler_cmb'))
	FixMeshInfoConfig(3)=(MClass=Class'KFChar.ZombieBloat',Mesh=SkeletalMesh'KF_Freaks_Trip.Bloat_Freak',Skins=(Combiner'KF_Specimens_Trip_T.bloat_cmb'))
	FixMeshInfoConfig(4)=(MClass=Class'KFChar.ZombieStalker',Mesh=SkeletalMesh'KF_Freaks_Trip.Stalker_Freak',Skins=(Shader'KF_Specimens_Trip_T.stalker_invisible',Shader'KF_Specimens_Trip_T.stalker_invisible'))
	FixMeshInfoConfig(5)=(MClass=Class'KFChar.ZombieSiren',Mesh=SkeletalMesh'KF_Freaks_Trip.Siren_Freak',Skins=(FinalBlend'KF_Specimens_Trip_T.siren_hair_fb',Combiner'KF_Specimens_Trip_T.siren_cmb'))
	FixMeshInfoConfig(6)=(MClass=Class'KFChar.ZombieHusk',Mesh=SkeletalMesh'KF_Freaks2_Trip.Burns_Freak',Skins=(Texture'KF_Specimens_Trip_T_Two.burns.burns_tatters',Shader'KF_Specimens_Trip_T_Two.burns.burns_shdr'))
	FixMeshInfoConfig(7)=(MClass=Class'KFChar.ZombieScrake',Mesh=SkeletalMesh'KF_Freaks_Trip.Scrake_Freak',Skins=(Shader'KF_Specimens_Trip_T.scrake_FB',TexPanner'KF_Specimens_Trip_T.scrake_saw_panner'))
	FixMeshInfoConfig(8)=(MClass=Class'KFChar.ZombieFleshPound',Mesh=SkeletalMesh'KF_Freaks_Trip.FleshPound_Freak',Skins=(Combiner'KF_Specimens_Trip_T.fleshpound_cmb',Shader'KFCharacters.FPAmberBloomShader'))
	FixMeshInfoConfig(9)=(MClass=Class'KFChar.ZombieBoss',Mesh=SkeletalMesh'KF_Freaks_Trip.Patriarch_Freak',Skins=(Combiner'KF_Specimens_Trip_T.gatling_cmb',Combiner'KF_Specimens_Trip_T.patriarch_cmb'))
}