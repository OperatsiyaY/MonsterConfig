class MCWaveInfo extends Object
	ParseConfig
	PerObjectConfig
	config(MonsterConfig);

var const string ConfigFile;
	
struct PerPlayerWaveInfo
{
	var int MonstersTotal;
	var int MonstersMaxAtOnce;
};

var config array<string>		Squad, SpecialSquad;
var config float				DelayBetweenSquads;
var config int					MonstersTotal;
var config int					MonstersMaxAtOnce;
var config PerPlayerWaveInfo	PerPlayer;
var config float				Position;

// если true, волна будет подгружена только если будет указана в MapSpecific настройках
var config bool				bMapSpecific;
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
	
	bUseZombieVolumeWaveDisabling = true
	bMapSpecific=false
	DelayBetweenSquads=3.0
	MonstersTotal=70
	MonstersMaxAtOnce=50
}