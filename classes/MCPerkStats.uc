class MCPerkStats extends Object
	ParseConfig
	PerObjectConfig
	config(MonsterConfig_stats);

var const string ConfigFile;

struct PerkStatStruct
{
	var int					PerkIndex;
	var class<KFVeterancyTypes> Perk;
	var float				Score;	// среднее WaveScore за волну для перка
	var int					Num;	// число значений для вычисления среднего
};
var config array<PerkStatStruct>	PerkStats;

// рабочие переменные
var int	MidScore;
//--------------------------------------------------------------------------------------------------
function AddPerkScore(class<KFVeterancyTypes> Perk, int Score)
{
	local int i;
	for (i=0;i<PerkStats.Length;i++)
		if (PerkStats[i].PerkIndex == Perk.default.PerkIndex)
		{
			// пересчитать среднее Score за волну для перка
			PerkStats[i].Score = ((PerkStats[i].Score * float(PerkStats[i].Num)) + float(Score)) / float(PerkStats[i].Num+1);
			PerkStats[i].Num++;
			return;
		}
	// если досюда дошли, добавляем новый
	PerkStats.Insert(0,1);
	PerkStats[0].PerkIndex	= Perk.default.PerkIndex;
	PerkStats[0].Perk		= Perk;
	PerkStats[0].Score		= Score;
	PerkStats[0].Num		= 1;	
}
//--------------------------------------------------------------------------------------------------
function float GetPerkScoreCoeff(class<KFVeterancyTypes> Perk)
{
	local int i;
	local float ret;
	CalcMidScore();
	for (i=0; i<PerkStats.Length; i++)
		if (PerkStats[i].PerkIndex == Perk.default.PerkIndex)
		{
			ret = MidScore / PerkStats[i].Score;
			break;
		}
	if (ret>0)
		return ret;
	else return 1.f;
}
//--------------------------------------------------------------------------------------------------
function CalcMidScore()
{
	local int i,n;
	for (i=0;i<PerkStats.Length;i++)
	{
		MidScore += PerkStats[i].Score;
		n++;
	}
	MidScore /= n;
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
	ConfigFile = "MonsterConfig_stats"
	MidScore = -1
}