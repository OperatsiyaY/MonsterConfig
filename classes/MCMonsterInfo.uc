class MCMonsterInfo extends Object
	ParseConfig
	PerObjectConfig
	config(MonsterConfig);
	
var const string	ConfigFile;
var int				revision;

// сколько хп добавлять к мобу за каждого игрока
struct PerPlayerSettings
{
	var int Health;
	var int HeadHealth;
};
// настройки резиста к дамагу
struct ResistSettings
{
	var class<DamageType>	DamType;
	var float				Coeff;
	var bool				bNotCheckChild;
};

// непосредственно то, что будет в конфиге
var config class<KFMonster>		MonsterClass;
var config int					Health, HeadHealth;
var config int					HealthMax, HeadHealthMax;
var config int 					Speed;
var config float				SpeedMod;
var config string				MonsterName;//редефайн, чтобы в KillMessages писало по своему
var config PerPlayerSettings	PerPlayer;	//PerPlayerAdd=(Health=10, HeadHealth=2)
var config array<ResistSettings> Resist;	//Resist=(DamType="KFMod.DamTypeChainsaw", coeff=0.9)
var config float				RewardScore;
var config float				RewardScoreCoeff;
var config float				MonsterSize;
var config array<Mesh>			Mesh;
var config array<Material>		Skins;

// рабочие
//var MCMonsterNameObj			MNameObj; // для MCKillsMessage
var const string delim;
var name NameConversionHack;
//--------------------------------------------------------------------------------------------------
static function array<string> GetNames()
{
	return GetPerObjectNames(default.ConfigFile);
}
//--------------------------------------------------------------------------------------------------
simulated function GetI(out string s, out int I)
{
	I = int(Get(S));
}
//--------------------------------------------------------------------------------------------------
simulated function GetF(out string s, out float F)
{
	F = float(Get(S));
}
//--------------------------------------------------------------------------------------------------
simulated static function string Get(out string s, optional out string str)
{
	local string l;
	local int n;
	n = InStr(s,default.delim);
	while (n==0)
	{
		s = Right(s, Len(s)-1);
		n = InStr(s,default.delim);
	}
	if (n==-1)
	{
		l=s;
		s="";
	}
	else
	{
		l = Left(s,n);
		s = Right(s, Len(s)-(n+1));
	}
	str = l;
	return l;
}
//--------------------------------------------------------------------------------------------------
simulated static function string UnSerializeName(string S)
{
	return Get(S);
}
//--------------------------------------------------------------------------------------------------
simulated function UnSerialize(string S)
{
	local int i,n;
	local Name tName;
	
	tName = StringToName(Get(S));
	MonsterClass = class<KFMonster>(DynamicLoadObject(Get(S), Class'Class'));
	GetI(S, Health);
	GetI(S, HeadHealth);
	GetI(S, HealthMax);
	GetI(S, HeadHealthMax);
	GetI(S, Speed);
	GetF(S, SpeedMod);
	Get(S,	MonsterName);
	GetI(S, PerPlayer.Health);
	GetI(S, PerPlayer.HeadHealth);
	
	Resist.Remove(0,Resist.Length);
	GetI(S, n);
	Resist.Insert(0,n);
	for (i=0;i<n;i++)
	{
		Resist[i].DamType = class<DamageType>(DynamicLoadObject(Get(S), Class'Class'));
		GetF(S, Resist[i].Coeff);
		Resist[i].bNotCheckChild = bool(Get(S));
	}
	GetF(S, RewardScore);
	GetF(S, RewardScoreCoeff);
	GetF(S, MonsterSize);
	
	Mesh.Remove(0,Mesh.Length);
	GetI(S, n);
	Mesh.Insert(0,n);
	for (i=0;i<n;i++)
		Mesh[i] = Mesh(DynamicLoadObject(Get(S), Class'Mesh'));

	Skins.Remove(0,Skins.Length);
	GetI(S, n);
	Skins.Insert(0,n);
	for (i=0;i<n;i++)
		Skins[i] = Material(DynamicLoadObject(Get(S), Class'Material'));
}
//--------------------------------------------------------------------------------------------------
simulated function string Serialize()
{
	local string S;
	local int i;
	Push(S, string(Name));
	Push(S, string(MonsterClass));
	PushI(S, Health);
	PushI(S, HeadHealth);
	PushI(S, HealthMax);
	PushI(S, HeadHealthMax);
	PushI(S, Speed);
	PushF(S, SpeedMod);
	Push(S,	MonsterName);
	PushI(S, PerPlayer.Health);
	PushI(S, PerPlayer.HeadHealth);
	
	PushI(S, Resist.Length);
	for (i=0;i<Resist.Length;i++)
	{
		Push(S, string(Resist[i].DamType));
		PushF(S, Resist[i].Coeff);
		Push(S, string(Resist[i].bNotCheckChild));
	}
	PushF(S, RewardScore);
	PushF(S, RewardScoreCoeff);
	PushF(S, MonsterSize);
	
	PushI(S, Mesh.Length);
	for (i=0;i<Mesh.Length;i++)
		Push(S, string(Mesh[i]));

	PushI(S, Skins.Length);
	for (i=0;i<Skins.Length;i++)
		Push(S, string(Skins[i]));
	return S;
}
//--------------------------------------------------------------------------------------------------
simulated function PushI(out string s, int input)
{
	Push(s, string(input));
}
//--------------------------------------------------------------------------------------------------
simulated function PushF(out string s, float input)
{
	Push(s, string(input));
}
//--------------------------------------------------------------------------------------------------
simulated function Push(out string s, string input)
{
	if (Len(s) == 0)
		s = input;
	else
		s $= delim$input;
}
//--------------------------------------------------------------------------------------------------
simulated function name StringToName(string str)
{
  SetPropertyText("NameConversionHack", str);
  return NameConversionHack;
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
defaultproperties
{
	ConfigFile = "MonsterConfig"
	delim = "+"
	
	// если юзер просто не указал это в конфиге, мы учтем это и не будем присваивать
	Health=-1
	HeadHealth=-1
	HealthMax=-1
	HeadHealthMax=-1
	PerPlayer=(Health=0,HeadHealth=0)
	
	Speed = 0
	SpeedMod = 1.0
	
	RewardScore = -1.0
	RewardScoreCoeff = 1.0
	
	MonsterSize = 1.0
}