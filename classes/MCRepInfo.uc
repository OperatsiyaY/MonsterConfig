Class MCRepInfo extends LinkedReplicationInfo;

var MonsterConfig SandboxController; // чтобы из ClientKilledMonster иметь доступ к Monsters[i].MonsterName

var float	WaveScore; // очки за текущую волну (используется при начислении денег)
var float	GameScore; // очки за всю игру

// общая стата из перков сколько игрок вылечил
// сохраняем значение перед волной, чтобы потом сравнить и правильно посчитать очки
var int		HealedStat; 

replication
{
	reliable if(ROLE == Role_Authority)
		WaveScore, GameScore, ClientKilledMonster, SandboxController;
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
simulated function ClientKilledMonster( string MName, optional PlayerReplicationInfo KillerPRI )
{
	local int i;
	local MCMonsterInfo	MInfo;

	//SandboxController.LM("ClientKilledMonster"@MName);
	
	for (i=0; i<SandboxController.Monsters.Length; i++)
		if (SandboxController.Monsters[i].MonsterName ~= MName)
		{
			MInfo = SandboxController.Monsters[i];
			break;
		}
	// TODO for standart monsters there is no MonsterInfo, so no messages
	Level.GetLocalPlayerController().ReceiveLocalizedMessage(Class'MCKillsMessage ',,KillerPRI,,MInfo.MNameObj);
}
//--------------------------------------------------------------------------------------------------
function PostBeginPlay()
{
	local PlayerController PC;
	local PlayerReplicationInfo PRI;
	local LinkedReplicationInfo L;
	
	// определяем хозяина
	PC = PlayerController(Owner);
	if (PC!=none)
		PRI = PC.PlayerReplicationInfo;
	if (PC==none || PRI==none)
	{
		log("MonsterConfig Error: MCRepInfo failed at PostBeginPlay()");
		return;
	}
	
	// подгружаем себя к хозяину
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
	// нам нужно отображать это по табу в статистике
	bAlwaysRelevant=true

	// у Марко так
	/*bAlwaysRelevant=false
	bOnlyRelevantToOwner=true
	bOnlyDirtyReplication=true*/
}