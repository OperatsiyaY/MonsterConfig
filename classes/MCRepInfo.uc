Class MCRepInfo extends LinkedReplicationInfo;

var MonsterConfig SandboxController; // ����� �� ClientKilledMonster ����� ������ � Monsters[i].MonsterName
var name NameConversionHack;

var float	WaveScore; // ���� �� ������� ����� (������������ ��� ���������� �����)
var float	GameScore; // ���� �� ��� ����

// ����� ����� �� ������ ������� ����� �������
// ��������� �������� ����� ������, ����� ����� �������� � ��������� ��������� ����
var int		HealedStat; 

replication
{
	reliable if(bNetInitial && ROLE == Role_Authority)
		SandboxController;
	reliable if(ROLE == Role_Authority)
		WaveScore, GameScore, ClientKilledMonster;
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
simulated function ClientKilledMonster( string MonsterInfoStr, optional PlayerReplicationInfo KillerPRI )
{
	local int i;
	for (i=SandboxController.Monsters.Length-1; i>=0; --i)
		if (string(SandboxController.Monsters[i].Name) ~= MonsterInfoStr)
		{
			Level.GetLocalPlayerController().ReceiveLocalizedMessage(Class'MCKillsMessage ',,KillerPRI,,SandboxController.Monsters[i]);
			return;
		}

	// ERROR condition
	if (SandboxController==none)
		log("Error: MCRepInfo->ClientKilledMonster() SandboxController==none");
	SandboxController.LM("Error: MCRepInfo->ClientKilledMonster() Failed to found"@MonsterInfoStr);
	for (i=SandboxController.Monsters.Length-1; i>=0; --i)
		SandboxController.LM(string(SandboxController.Monsters[i].Name));
}
//--------------------------------------------------------------------------------------------------
function PostBeginPlay()
{
	local PlayerController PC;
	local PlayerReplicationInfo PRI;
	local LinkedReplicationInfo L;
	local bool lDebug;
	lDebug=true;
	
	// ���������� �������
	PC = PlayerController(Owner);
	if (PC!=none)
		PRI = PC.PlayerReplicationInfo;
	if (PC==none || PRI==none)
	{
		warn("MonsterConfig Error: MCRepInfo failed at PostBeginPlay()");
		return;
	}
	
	// ���������� ���� � ������� thanks to Flame
	if (PRI.CustomReplicationInfo == none)
	{
		PRI.CustomReplicationInfo = self;
		if (lDebug) log("MCRepInfo loaded for"@PRI.PlayerName);
	}
	else
	{
		for( L=PRI.CustomReplicationInfo; L!=none; L=L.NextReplicationInfo )
		{
			if (L.Class==default.Class)
			{
				warn("MCRepInfo already loaded for"@PRI.PlayerName);
				return;
			}
		}

		for( L=PRI.CustomReplicationInfo; L!=none; L=L.NextReplicationInfo )
		{
			if( L.NextReplicationInfo==none )
			{
				L.NextReplicationInfo = self; // Add to the end of the chain.
				if (lDebug) log("MCRepInfo loaded for"@PRI.PlayerName);
				return;
			}
		}
	}
}
//--------------------------------------------------------------------------------------------------
simulated function name StringToName(string str)
{
  SetPropertyText("NameConversionHack", str);
  return NameConversionHack;
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
defaultproperties
{
	// ��� ����� ���������� ��� �� ���� � ����������
	bAlwaysRelevant=true

	// � ����� ���
	/*bAlwaysRelevant=false
	bOnlyRelevantToOwner=true
	bOnlyDirtyReplication=true*/
}