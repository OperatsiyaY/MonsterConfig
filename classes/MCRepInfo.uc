Class MCRepInfo extends LinkedReplicationInfo;

var float	WaveScore; // ���� �� ������� ����� (������������ ��� ���������� �����)
var float	GameScore; // ���� �� ��� ����

// ����� ����� �� ������ ������� ����� �������
// ��������� �������� ����� ������, ����� ����� �������� � ��������� ��������� ����
var int		HealedStat; 

replication
{
	reliable if(ROLE == Role_Authority)
		WaveScore, GameScore;
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
function PostBeginPlay()
{
	local PlayerController PC;
	local PlayerReplicationInfo PRI;
	local LinkedReplicationInfo L;
	
	// ���������� �������
	PC = PlayerController(Owner);
	if (PC!=none)
		PRI = PC.PlayerReplicationInfo;
	if (PC==none || PRI==none)
	{
		log("MonsterConfig Error: MCRepInfo failed at PostBeginPlay()");
		return;
	}
	
	// ���������� ���� � �������
	// thanks to Flame
	if (PRI.CustomReplicationInfo == none)
		PRI.CustomReplicationInfo = self;
	else
	{
		for( L=PRI.CustomReplicationInfo; L!=none; L=L.NextReplicationInfo )
		{
			if (L.Class==self.Class)
			{
				warn("MCCustomRepInfo already loaded for"@PRI.PlayerName);
				return;
			}
		}
			
		for( L=PRI.CustomReplicationInfo; L!=none; L=L.NextReplicationInfo )
		{
			if( L.NextReplicationInfo==none )
			{
				L.NextReplicationInfo = self; // Add to the end of the chain.
				log("MCRepInfo loaded for"@PRI.PlayerName);
				return;
			}
		}
	}
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