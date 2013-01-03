class MCSquadInfo extends Object
	ParseConfig
	PerObjectConfig
	config(MonsterConfig);

var const string ConfigFile;
var int revision;

struct SquadMonsterInfo
{
	var array<string>	MonsterName;
	var int				Num;
};

// непосредственно то, что будет в конфиге
var config array<SquadMonsterInfo> Monster;

// переменные для SpecialSquads
var config int Freq;		// через сколько монстров появляется отряд
var config int FreqRand;	// добавим рандома
var config int InitialCounter; // вначале волны проверяем число заспавненых мобов с этим значением

// рабочие переменные
var int	Counter,CurFreq;
var bool bSpecialSquad; // используется в MCGameType->AddSquad() при формировании отряда для спавна.
						// Если волум для спавна не найден, обычный отряд переформируется, а 
						// bSpecialSquad отряд будет ожидать до тех пор, пока не появится
						// возможность его заспавнить. т.е. исключаем возможность пропуска 
						// спешил сквадов

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
	Freq = 100
	FreqRand = 20
}