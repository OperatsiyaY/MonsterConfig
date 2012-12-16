class MCMapInfo extends Object
	ParseConfig
	PerObjectConfig
	config(MonsterConfig);

var const string ConfigFile;
	
var config array<string>	Waves; // additional map-specific waves
var config float			DelayBetweenSquadsCoeff;
var config int				MonstersTotalCoeff;
var config int				MonstersMaxAtOnceCoeff;
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
}