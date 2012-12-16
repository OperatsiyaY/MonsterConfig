class MCSquadInfo extends Object
	ParseConfig
	PerObjectConfig
	config(MonsterConfig);
var const string ConfigFile;
var int revision;

struct SquadMonsterInfo
{
	var string	MonsterName;
	var int		Num;
};

// непосредственно то, что будет в конфиге
var config array<SquadMonsterInfo> Monster;

// переменные для SpecialSquads
var config int Freq; // через сколько монстров появляется отряд
var config int FreqRand; // добавим рандома
var config int InitialCounter; // вначале волны проверяем число заспавненых мобов с этим значением
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