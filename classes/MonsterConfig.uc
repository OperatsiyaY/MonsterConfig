/*
 * 1. ��� ��� ����� ��� ������ �������� �������� �� ���������, � ��������� ������� � ZombieVolume,
 * �� ��� ����� �������� �� ���. � CheckReplacement ������� ��� ZombieVolume, � ���� ��� �� ��������
 * ������ MCZombieVolume,�� ����������� ���� bReplaceZombieVolumes. � Tick ���� ���� ������� �
 * ���������� ������� ReplaceZombieVolumes, ������� �������� ��� ZombieVolume � 
 * KFGameType.ZedSpawnList �� ���� MCZombieVolume
 * 
 * ������
 */
class MonsterConfig extends Mutator;

// �����
local KFGametype GT;

// ������ ZombieVolume �� �� MCZombieVolume
var bool bReplaceZombieVolumes;

//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
	// Replace ZombieVolumes with Our MCZombieVolume
	if (ZombieVolume(Other)!=none && MCZombieVolume(Other)==none)
		bReplaceZombieVolumes=true;
	return true;
}
//--------------------------------------------------------------------------------------------------
simulated function Tick(float dt)
{
	local int i;
	local vector loc;
	local rotator rot;
	local UMZombieVolume ZV;

	if (bReplaceZombieVolumes)
	{
		ReplaceZombieVolumes();
		bReplaceZombieVolumes=false;
	}
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