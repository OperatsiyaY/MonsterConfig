class MCSpecialSquadInfo extends MCSquadInfo
	PerObjectConfig
	config(MonsterConfig);

// непосредственно то, что будет в конфиге
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

	InitialCounter = 0
	FreqRand = 0
}