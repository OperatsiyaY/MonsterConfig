class MCMonsterInfo extends Object
	ParseConfig
	PerObjectConfig
	config(MonsterConfig);
	
var const string ConfigFile;
var int revision;

// сколько хп добавлять к мобу за каждого игрока
struct PerPlayerSettings
{
	var int Health;
	var int HeadHealth;
};
// настройки резиста к дамагу
struct ResistSettings
{
	var class<DamageType> DamType;
	var float Coeff;
};

// непосредственно то, что будет в конфиге
var config class<KFMonster>		MonsterClass;
var config int					Health, HeadHealth;
var config int					HealthMax, HeadHealthMax;
var config PerPlayerSettings	PerPlayer;	//PerPlayerAdd=(Health=10, HeadHealth=2)
var config array<ResistSettings> Resist;	//Resist=(DamType="KFMod.DamTypeChainsaw", coeff=0.9)
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