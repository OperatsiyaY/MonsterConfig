class MCWaveInfo extends MCObject
	ParseConfig
	PerObjectConfig
	config(MonsterConfig);

/*struct PerPlayerWaveInfo
{
	var int		MonstersTotal;
	var int		MonstersMaxAtOnce;
	var int		Fund;
	var float	DelayBetweenSquadsCoeff
	var float	DelayBetweenSquadsCoeffMax;
};*/
var config array<string>		Squad, SpecialSquad;
var config float				SquadDelay;
var config int					MonstersTotal;
var config int					MonstersMaxAtOnce;

//var config PerPlayerWaveInfo	PerPlayer;
var config int					PerPlayerMonstersTotal;
var config int					PerPlayerMonstersMaxAtOnce;
var config int					PerPlayerFund;
var config float				PerPlayerSquadDelayMod;
var config float				PerPlayerSquadDelayModMin;
var config float				PerPlayerSquadDelayModMax;

var config float				Position;
var config float				TimeBetweenThisWaveCoeff;
var config bool					bMapSpecific;
//var config int					PerPlayerFund; // фонд на игрока
//--------------------------------------------------------------------------------------------------
simulated function UnSerialize(string S)
{
	local name tName;
	local int i,n;

	tName = StringToName(Get(S));
	
	Squad.Remove(0,Squad.Length);
	GetI(S, n);
	Squad.Insert(0,n);
	for (i=0; i<n; i++)
		Get(S, Squad[i]);
	
	SpecialSquad.Remove(0,SpecialSquad.Length);
	GetI(S, n);
	SpecialSquad.Insert(0,n);
	for (i=0; i<n; i++)
		Get(S, SpecialSquad[i]);
	
	GetF(S, SquadDelay);
	GetI(S, MonstersTotal);
	GetI(S, MonstersMaxAtOnce);
	GetI(S, PerPlayerMonstersTotal);
	GetI(S, PerPlayerMonstersMaxAtOnce);
	GetF(S, PerPlayerSquadDelayMod);
	GetF(S, PerPlayerSquadDelayModMin);
	GetF(S, PerPlayerSquadDelayModMax);
	GetI(S, PerPlayerFund);
	GetF(S, Position);
	GetF(S, TimeBetweenThisWaveCoeff);
	bMapSpecific = bool(Get(S));
}
//--------------------------------------------------------------------------------------------------
simulated function string Serialize()
{
	local string S;
	local int i;

	Push(S, string(Name));
	
	PushI(S, Squad.Length);
	for (i=0; i<Squad.Length; i++)
		Push(S, Squad[i]);
	
	PushI(S, SpecialSquad.Length);
	for (i=0; i<SpecialSquad.Length; i++)
		Push(S, SpecialSquad[i]);
	
	PushF(S, SquadDelay);
	PushI(S, MonstersTotal);
	PushI(S, MonstersMaxAtOnce);
	PushI(S, PerPlayerMonstersTotal);
	PushI(S, PerPlayerMonstersMaxAtOnce);
	PushF(S, PerPlayerSquadDelayMod);
	PushF(S, PerPlayerSquadDelayModMin);
	PushF(S, PerPlayerSquadDelayModMax);
	PushI(S, PerPlayerFund);
	PushF(S, Position);
	PushF(S, TimeBetweenThisWaveCoeff);
	Push(S, string(bMapSpecific));

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
	bMapSpecific=false
	MonstersTotal=70
	MonstersMaxAtOnce=50
	Position=-1
	TimeBetweenThisWaveCoeff=1.0
	
	SquadDelay=3.0
	PerPlayerSquadDelayMod=1.0
	PerPlayerSquadDelayModMin=0.1
	PerPlayerSquadDelayModMax=0.99
	
	PerPlayerFund=0
	PerPlayerMonstersTotal=0
	PerPlayerMonstersMaxAtOnce=0
	//PerPlayer=(Fund=0,MonstersTotal=0,MonstersMaxAtOnce=0,DelayBetweenSquadsCoeff=1.0,DelayBetweenSquadsCoeffMax=0.5)
}