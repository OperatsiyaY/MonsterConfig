class MCSquadInfo extends MCObject
	ParseConfig
	PerObjectConfig
	config(MonsterConfig);

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
simulated function UnSerialize(string S)
{
	local name tName;
	local int i,n, j,k;

	tName = StringToName(Get(S));
	
	Monster.Remove(0,Monster.Length);
	GetI(S, n);
	Monster.Insert(0,n);
	for (i=0;i<n;i++)
	{
		Monster[i].MonsterName.Remove(0, Monster[i].MonsterName.Length);
		GetI(S, k);
		Monster[i].MonsterName.Insert(0,k);
		for (j=0; j<k; j++)
			Get(S, Monster[i].MonsterName[j]);
		
		GetI(S, Monster[i].Num);
	}
	GetI(S, Freq);
	GetI(S, FreqRand);
	GetI(S, InitialCounter);
}
//--------------------------------------------------------------------------------------------------
simulated function string Serialize()
{
	local string S;
	local int i,n;

	Push(S, string(Name));
	
	PushI(S, Monster.Length);
	for (i=0;i<Monster.Length;i++)
	{
		PushI(S, Monster[i].MonsterName.Length);
		for (n=0; n<Monster[i].MonsterName.Length; n++)
			Push(S, Monster[i].MonsterName[n]);
		
		PushI(S, Monster[i].Num);
	}
	PushI(S, Freq);
	PushI(S, FreqRand);
	PushI(S, InitialCounter);

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
	Freq = 100
	FreqRand = 20
}