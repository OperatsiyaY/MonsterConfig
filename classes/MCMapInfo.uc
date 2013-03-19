class MCMapInfo extends MCObject
	ParseConfig
	PerObjectConfig
	config(MonsterConfig);

/*struct PerPlayerMapInfo
{
	var float	DelayBetweenSquadsCoeff;
};*/

var config array<string>	Waves; // additional map-specific waves
var config float			SquadDelayMod; //DelayBetweenSquadsCoeff;
var config float			MonstersTotalCoeff;
var config float			MonstersMaxAtOnceCoeff;
var config bool				bUseZombieVolumeWaveDisabling;
var config float			TimeBetweenWaves;
var config float			MonsterBodyHPMod,MonsterHeadHPMod,MonsterSpeedMod,MonsterDamageMod;
//var config PerPlayerMapInfo	PerPlayer;
var config float			PerPlayerSquadDelayMod; //PerPlayerDelayBetweenSquadsCoeff;
var config float			PerPlayerSquadDelayModMin; //PerPlayerDelayBetweenSquadsCoeffMax;
var config float			PerPlayerSquadDelayModMax; //PerPlayerDelayBetweenSquadsCoeffMax;
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

	GetF(S, SquadDelayMod);
	GetF(S, MonstersTotalCoeff);
	GetF(S, MonstersMaxAtOnceCoeff);
	bUseZombieVolumeWaveDisabling = bool(Get(S));
	GetF(S, TimeBetweenWaves);
	GetF(S, MonsterBodyHPMod);
	GetF(S, MonsterHeadHPMod);
	GetF(S, MonsterSpeedMod);
	GetF(S, MonsterDamageMod);
	GetF(S, PerPlayerSquadDelayMod);
	GetF(S, PerPlayerSquadDelayModMin);
	GetF(S, PerPlayerSquadDelayModMax);
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

	PushF(S, SquadDelayMod);
	PushF(S, MonstersTotalCoeff);
	PushF(S, MonstersMaxAtOnceCoeff);
	Push(S, string(bUseZombieVolumeWaveDisabling));
	PushF(S, TimeBetweenWaves);
	PushF(S, MonsterBodyHPMod);
	PushF(S, MonsterHeadHPMod);
	PushF(S, MonsterSpeedMod);
	PushF(S, MonsterDamageMod);
	PushF(S, PerPlayerSquadDelayMod);
	PushF(S, PerPlayerSquadDelayModMin);
	PushF(S, PerPlayerSquadDelayModMax);
	return S;
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
	
	MonstersTotalCoeff=1.0
	MonstersMaxAtOnceCoeff=1.0

	SquadDelayMod=1.0
	PerPlayerSquadDelayMod=1.0
	PerPlayerSquadDelayModMin=0.1
	PerPlayerSquadDelayModMax=1.9
	
	MonsterBodyHPMod = 1.00
	MonsterHeadHPMod = 1.00
	MonsterSpeedMod = 1.00
	MonsterDamageMod = 1.00
	bUseZombieVolumeWaveDisabling = true
	TimeBetweenWaves=90
}