Class MCMonRepInfo extends LinkedReplicationInfo;

var MonsterConfig SandboxController;
var name MonsterInfoName;
var bool bInitialized;

replication
{
	reliable if(ROLE == Role_Authority)
		SandboxController, MonsterInfoName;
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
simulated function PostBeginPlay()
{
	local PlayerReplicationInfo PRI;
	local LinkedReplicationInfo L;

	Super.PostBeginPlay();
	
	PRI = Controller(Owner).PlayerReplicationInfo;
	if (PRI.CustomReplicationInfo == none)
		PRI.CustomReplicationInfo = self;
	else
	{
		for( L=PRI.CustomReplicationInfo; L!=none; L=L.NextReplicationInfo )
		{
			if (L.Class == self.default.Class)
			{
				warn(L.Class@"already loaded for"@PRI.PlayerName);
				return;
			}
		}

		for( L=PRI.CustomReplicationInfo; L!=none; L=L.NextReplicationInfo )
		{
			if( L.NextReplicationInfo==none )
			{
				L.NextReplicationInfo = L; // Add to the end of the chain.
				log(L.Class@"loaded for"@PRI.PlayerName);
				return;
			}
		}
	}
	SetTimer(0.1,false);
}
//--------------------------------------------------------------------------------------------------
simulated function Timer()
{
	SandboxController.PendingMonsters[SandboxController.PendingMonsters.Length] = Controller(Owner);
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