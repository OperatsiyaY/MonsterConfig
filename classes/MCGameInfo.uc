/*
	� ���� ������ �������� ���������� ��������� �� ������� ����� ��� �����������.

	�������� ��������� �� �� MonsterConfig � ����� � ���, ��� ����� ���� ����������� 
	������������ �������� �� ������� �� ����� ����.
*/
//--------------------------------------------------------------------------------------------------
class MCGameInfo extends MCObject
	ParseConfig
	PerObjectConfig
	config(MonsterConfig);

// ���������� ���������
// �����
var config int		FakedPlayersNum;

// ������������� ��������
var config float	MonsterBodyHPMod;
var config float	MonsterHeadHPMod;
var config float	MonsterSpeedMod;
var config float	MonsterDamageMod;

// ������������� GameType
var config bool		bWaveFundSystem; // ����� ������� �������������� ����� ��������������
var config float	HealedToScoreCoeff; // ����������� �������� ���� � ���� RepInfo.WaveScore
var config float	MoneyMod;	// ���� ������������ ������� �����, ���� �� ����� ���������� �� ��� ��������

var config float	MonstersMaxAtOnceMod;
var config float	MonstersTotalMod;
var config int		BroadcastKillmessagesMass;
var config int		BroadcastKillmessagesHealth;
var config float	GameDifficulty; // ���������� � ��������� TWI, ����������� ��� 
									// ����������� ����� ���� ��������� �� ����� Stalker
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
	// � ����� ����� ��������� ������� ����� �������
	// � � ��� ����� �� ����� ��������� ��������, ���������� �� ���� �����������
	HealedToScoreCoeff = 5.00
}