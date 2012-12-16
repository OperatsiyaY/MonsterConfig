class MCSquadInfo extends Object
	PerObjectConfig
	config(MonsterConfig);
var const string ConfigFile;
var int revision;

struct SquadMonsterInfo
{
	var string	Name;
	var int		Num;
};

// непосредственно то, что будет в конфиге
var config array<SquadMonsterInfo> Monster;
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
}