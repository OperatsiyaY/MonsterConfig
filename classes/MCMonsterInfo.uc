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
var MCMonsterNameObj			MNameObj; // для MCKillsMessage
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