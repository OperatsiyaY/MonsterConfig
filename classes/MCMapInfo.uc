class MCMapInfo extends Object
	ParseConfig
	PerObjectConfig
	config(MonsterConfig);

var const string ConfigFile;
var const string delim;
var name NameConversionHack;

struct PerPlayerMapInfo
{
	var float	DelayBetweenSquadsCoeff;
};
	
var config array<string>	Waves; // additional map-specific waves
var config float			DelayBetweenSquadsCoeff;
var config float			MonstersTotalCoeff;
var config float			MonstersMaxAtOnceCoeff;
var config bool				bUseZombieVolumeWaveDisabling;
var config float			TimeBetweenWaves;

var config float			MonsterBodyHPMod,MonsterHeadHPMod,MonsterSpeedMod,MonsterDamageMod;

var config PerPlayerMapInfo	PerPlayer;
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
	
	Waves.Remove(0,Waves.Length);
	GetI(S, n);
	Waves.Insert(0,n);
	for (i=0;i<n;i++)
		Get(S, Waves[i]);

	GetF(S, DelayBetweenSquadsCoeff);
	GetF(S, MonstersTotalCoeff);
	GetF(S, MonstersMaxAtOnceCoeff);
	bUseZombieVolumeWaveDisabling = bool(Get(S));
	GetF(S, TimeBetweenWaves);
	GetF(S, MonsterBodyHPMod);
	GetF(S, MonsterHeadHPMod);
	GetF(S, MonsterSpeedMod);
	GetF(S, MonsterDamageMod);
	GetF(S, PerPlayer.DelayBetweenSquadsCoeff);
}
//--------------------------------------------------------------------------------------------------
simulated function string Serialize()
{
	local string S;
	local int i;
	Push(S, string(Name));
	
	PushI(S, Waves.Length);
	for (i=0;i<Waves.Length;i++)
		Push(S, Waves[i]);

	PushF(S, DelayBetweenSquadsCoeff);
	PushF(S, MonstersTotalCoeff);
	PushF(S, MonstersMaxAtOnceCoeff);
	Push(S, string(bUseZombieVolumeWaveDisabling));
	PushF(S, TimeBetweenWaves);
	PushF(S, MonsterBodyHPMod);
	PushF(S, MonsterHeadHPMod);
	PushF(S, MonsterSpeedMod);
	PushF(S, MonsterDamageMod);
	PushF(S, PerPlayer.DelayBetweenSquadsCoeff);
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
static function array<string> GetNames()
{
	return GetPerObjectNames(default.ConfigFile);
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
defaultproperties
{
	ConfigFile = "MonsterConfig"
	delim = "+"
	
	DelayBetweenSquadsCoeff=1.0
	MonstersTotalCoeff=1.0
	MonstersMaxAtOnceCoeff=1.0

	PerPlayer=(DelayBetweenSquadsCoeff=1.0)
	
	MonsterBodyHPMod = 1.00
	MonsterHeadHPMod = 1.00
	MonsterSpeedMod = 1.00
	MonsterDamageMod = 1.00
	bUseZombieVolumeWaveDisabling = true
	TimeBetweenWaves=90
}