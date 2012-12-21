class MCMapInfo extends Object
	ParseConfig
	PerObjectConfig
	config(MonsterConfig);

var const string ConfigFile;

struct PerPlayerMapInfo
{
	var float	DelayBetweenSquadsCoeff;
};
	
var config array<string>	Waves; // additional map-specific waves
var config float			DelayBetweenSquadsCoeff;
var config float			MonstersTotalCoeff;
var config float			MonstersMaxAtOnceCoeff;
var config bool				bUseZombieVolumeWaveDisabling;


var config float	MonsterBodyHPMod,MonsterHeadHPMod,MonsterSpeedMod,MonsterDamageMod;

var config PerPlayerMapInfo	PerPlayer;
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
	
	DelayBetweenSquadsCoeff=1.0
	MonstersTotalCoeff=1.0
	MonstersMaxAtOnceCoeff=1.0

	PerPlayer=(DelayBetweenSquadsCoeff=1.0)
	
	MonsterBodyHPMod = 1.00
	MonsterHeadHPMod = 1.00
	MonsterSpeedMod = 1.00
	MonsterDamageMod = 1.00
	bUseZombieVolumeWaveDisabling = true
}