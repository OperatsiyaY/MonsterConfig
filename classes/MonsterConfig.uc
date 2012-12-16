/*
 * 1. Так как нужно при спавне монстров заменять их параметры, а спавнятся монстры в ZombieVolume,
 * то его нужно заменить на наш. В CheckReplacement ловятся все ZombieVolume, и если они не являются
 * нашими MCZombieVolume,то поднимается флаг bReplaceZombieVolumes. В Tick этот флаг ловится и
 * вызывается функция ReplaceZombieVolumes, которая заменяет все ZombieVolume в 
 * KFGameType.ZedSpawnList на наши MCZombieVolume
 * 
 * ываыва
 */
class MonsterConfig extends Mutator;

// общие
local KFGametype GT;

// замена ZombieVolume на на MCZombieVolume
var bool bReplaceZombieVolumes;

var array<ZombieVolume> ZMV;

//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
	// Replace ZombieVolumes with Our MCZombieVolume
	if ( ZombieVolume(Other)!=none && MCZombieVolume(Other)==none )
	{
		bReplaceZombieVolumes=true;
		ZMV.Insert(0,1);
		ZMV[0] = ZombieVolume(Other);
	}
	return true;
}
//--------------------------------------------------------------------------------------------------
simulated function Tick(float dt)
{
	while ( ZMV.Length > 0 )
	{
		ReplaceZombieVolume(ZMV[0]);
		ZMV.Remove(0,1);
	}
/*
	if ( bReplaceZombieVolumes )
	{
		ReplaceZombieVolumes();
		bReplaceZombieVolumes=false;
	}
*/
}
//--------------------------------------------------------------------------------------------------
function bool ReplaceZombieVolume(ZombieVolume CurZMV)
{
	local int i,n,j;
	local MCZombieVolume NewVol;
	
	n = GT.ZedSpawnList.Length;
	
	for(i=0; i<n; i++)
	{
		if ( CurZMV == GT.ZedSpawnList[i] )
		{
			break;
		}
	}
	
	if ( i >= n )
	{
		return false; // Fail
	}
	
	NewVol = Spawn(class'MCZombieVolume',Level,,CurZMV.Location,CurZMV.Rotation);
	
	n = CurZMV.SpawnPos.Length;
	for(j=0; j<n; j++)
		NewVol.SpawnPos[j] = CurZMV.SpawnPos[j];
	
	if ( n > 0 )
		NewVol.bHasInitSpawnPoints = true;

	n = CurZMV.DisabledWaveNums.Length;
	for(j=0; j<n; j++)
		NewVol.DisabledWaveNums[j] = CurZMV.DisabledWaveNums[j];
	
	n = CurZMV.DisallowedZeds.Length;
	for(j=0; j<n; j++)
		NewVol.DisallowedZeds[j] = CurZMV.DisallowedZeds[j];
		
	n = CurZMV.OnlyAllowedZeds.Length;
	for(j=0; j<n; j++)
		NewVol.OnlyAllowedZeds[j] = CurZMV.OnlyAllowedZeds[j];
		
	n = CurZMV.RoomDoorsList.Length;
	for(j=0; j<n; j++)
		NewVol.RoomDoorsList[j] = CurZMV.RoomDoorsList[j];

	NewVol.CanRespawnTime = CurZMV.CanRespawnTime;
	NewVol.bMassiveZeds = CurZMV.bMassiveZeds;
	NewVol.bLeapingZeds = CurZMV.bLeapingZeds;
	NewVol.bNormalZeds = CurZMV.bNormalZeds;
	NewVol.bRangedZeds = CurZMV.bRangedZeds;
	NewVol.TouchDisableTime = CurZMV.TouchDisableTime;
	NewVol.ZombieCountMulti = CurZMV.ZombieCountMulti;
	NewVol.bVolumeIsEnabled = CurZMV.bVolumeIsEnabled;
	NewVol.SpawnDesirability = CurZMV.SpawnDesirability;
	NewVol.MinDistanceToPlayer = CurZMV.MinDistanceToPlayer;
	NewVol.bNoZAxisDistPenalty = CurZMV.bNoZAxisDistPenalty;
//	NewVol. = CurZMV.;
	
//	CurZMV.Destroy(); // не уничтожаем, возможно нужны для мапперов
	GT.ZedSpawnList[i] = NewVol;
	
	return true;
}
//--------------------------------------------------------------------------------------------------
simulated function ReplaceZombieVolumes()
{
	local ZombieVolume ZV;
	local UMZombieVolume UZV;
	local KFGametype GT;
	local int i,j;
	
	GT = KFGametype(Level.Game);
	if (GT==none)
	{
		log("cant find KFGameType");
		return;
	}
	for (i=0; i<GT.ZedSpawnList.Length; i++)
	{
		if (UMZombieVolume(GT.ZedSpawnList[i])!=none)
			continue;
		//ReplaceWith(aZVol[i],"UnitedMut_v57.UMZombieVolume");
		log("Spawn UMZombieVolume");
		UZV = Spawn(class'UMZombieVolume', Level);
		ZV = GT.ZedSpawnList[i];
		UZV.SetLocation(ZV.Location);
		UZV.SetRotation(ZV.Rotation);
		
		//thanks to Marco
		for (j=0;j<ZV.SpawnPos.Length;j++)
			UZV.SpawnPos[j] = ZV.SpawnPos[j];
		
		UZV.bDebugZombieSpawning = true;
		UZV.bDebugZoneSelection = true;
		UZV.bDebugSpawnSelection = true;
		GT.ZedSpawnList[i].Destroy();
		GT.ZedSpawnList[i] = UZV;
	}
}
//--------------------------------------------------------------------------------------------------
defaultproperties
{
	bAlwaysRelevant=true
	RemoteRole = ROLE_SimulatedProxy
}