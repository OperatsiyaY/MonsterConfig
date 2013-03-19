/*
	В этом классе хранятся глобальные множители на которые будет все домножаться.

	Пришлось перенести их из MonsterConfig в связи с тем, что нужна была возможнсоть 
	перечитывать значения из конфига во время игры.
*/
//--------------------------------------------------------------------------------------------------
class MCGameInfo extends MCObject
	ParseConfig
	PerObjectConfig
	config(MonsterConfig);

// глобальные множители
// общие
var config int		FakedPlayersNum;

// инициализация монстров
var config float	MonsterBodyHPMod;
var config float	MonsterHeadHPMod;
var config float	MonsterSpeedMod;
var config float	MonsterDamageMod;

// инициализация GameType
var config bool		bWaveFundSystem; // какая система вознаграждения будет использоваться
var config float	HealedToScoreCoeff; // коэффициент перевода хила в очки RepInfo.WaveScore
var config float	MoneyMod;	// если используется система фонда, фонд за волну умножается на это значение

var config float	MonstersMaxAtOnceMod;
var config float	MonstersTotalMod;
var config int		BroadcastKillmessagesMass;
var config int		BroadcastKillmessagesHealth;
var config float	GameDifficulty; // стложность в понимании TWI, понадобится для 
									// стандартных мобов типо сталкеров на карте Stalker
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
simulated function UnSerialize(string S)
{
	local name tName;

	tName = StringToName(Get(S));
	
	GetI(S, FakedPlayersNum);
	GetF(S, MonstersMaxAtOnceMod);
	GetF(S, MonstersTotalMod);
	GetF(S, MonsterBodyHPMod);
	GetF(S, MonsterHeadHPMod);
	GetF(S, MonsterSpeedMod);
	GetF(S, MonsterDamageMod);
	GetF(S, HealedToScoreCoeff);
	GetI(S, BroadcastKillmessagesMass);
	GetI(S, BroadcastKillmessagesHealth);
	GetF(S, GameDifficulty);
	GetF(S, MoneyMod);
}
//--------------------------------------------------------------------------------------------------
simulated function string Serialize()
{
	local string S;

	Push(S, string(Name));
	
	PushI(S, FakedPlayersNum);
	PushF(S, MonstersMaxAtOnceMod);
	PushF(S, MonstersTotalMod);
	PushF(S, MonsterBodyHPMod);
	PushF(S, MonsterHeadHPMod);
	PushF(S, MonsterSpeedMod);
	PushF(S, MonsterDamageMod);
	PushF(S, HealedToScoreCoeff);
	PushI(S, BroadcastKillmessagesMass);
	PushI(S, BroadcastKillmessagesHealth);
	PushF(S, GameDifficulty);
	PushF(S, MoneyMod);
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
	delim = "+"
	
	GameDifficulty = 4.0 // Hard

	FakedPlayersNum = 0
	MonstersTotalMod = 1.00
	MonstersMaxAtOnceMod = 1.00

	MonsterBodyHPMod = 1.00
	MonsterHeadHPMod = 1.00
	MonsterSpeedMod = 1.00
	MonsterDamageMod = 1.00
	MoneyMod = 1.00

	BroadcastKillmessagesMass = 1500
	BroadcastKillmessagesHealth = 999

	bWaveFundSystem = false
	// В конце волны вычисляем сколько игрок похилил
	// и к его очкам за волну добавляем значение, умноженное на этот коэффициент
	HealedToScoreCoeff = 5.00
}