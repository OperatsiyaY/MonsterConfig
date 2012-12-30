class MCMonsterList	extends ReplicationInfo;

struct MListInput
{
	var array<Mesh>		Mesh;
	var array<Material>	Skins;
};

var MCMonsterList Prev, Next;

var KFMonster	Mon;
var Mesh		MonMesh;
var Material	MonSkins[5];
var bool		bDeleted;
var int			revision;
var int			revisionClient;

var int			ListRevision;

replication
{
	reliable if (ROLE == ROLE_Authority)
		Prev, Next, Mon, MonMesh, MonSkins, bDeleted, revision, ListRevision;
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
function Add(KFMonster M, MListInput MI)
{
	local MCMonsterList MList;

	if (M==none)
	{
		toLog("MonsterInfo M==none");
		return;
	}
	else if( (MI.Mesh.Length==0 || MI.Mesh[0]==none) && (MI.Skins.Length==0 || MI.Skins[0]==none) )
	{
		toLog("MonsterInfo->Add()->Mesh == none && Skins == none");
		return;		
	}

	MList = Find(M);
	if (MList!=none /*&& MList.MonMesh != RandomMesh*/)
		SetMList(M, MList,MI);
	else if (Mon==none || (MonMesh==none && MonSkins[0]==none) || bDeleted)
		SetMList(M, self,MI);
	else
	{
		if (Next==none)
			Next = Spawn(class'MCMonsterList',Owner);
		Next.Add(M,MI);
	}
	ListRevision++;
}
//--------------------------------------------------------------------------------------------------
function SetMList(KFMonster M, MCMonsterList MList, MListInput MI)
{
	local int n;
	MList.bDeleted = false;
	
	MList.Mon = M;

	MList.MonMesh = none;
	if (MI.Mesh.Length>0 && MI.Mesh[0]!=none)
	{
		n = Rand(MI.Mesh.Length-1);
		n = Max(0,n);
		MList.MonMesh = MI.Mesh[n];
	}
	
	//MList.MonSkins.Remove(0,MList.MonSkins.Length);
	for (n=0;n<arraycount(MList.MonSkins);n++)
		MList.MonSkins[n]=none;
	for (n=0;n<MI.Skins.Length && n<arraycount(MList.MonSkins);n++)
		MList.MonSkins[n] = MI.Skins[n];

	MList.revision++;
}
//--------------------------------------------------------------------------------------------------
function Del(KFMonster M)
{
	local int n;
	if (Mon==M || Mon == none || (MonMesh==none && MonSkins[0]==none))
	{
		Mon = none;
		MonMesh = none;
		//MonSkins.Remove(0,MonSkins.Length);
		for (n=0;n<arraycount(MonSkins);n++)
			MonSkins[n]=none;
		bDeleted=true;
	}
	if (Next != none)
		Next.Del(M);
}
//--------------------------------------------------------------------------------------------------
simulated function MCMonsterList GetNext()
{
	if (Next==none)
	{
		log("GetNext() return none");
		return none;
	}
	else if (Next.bDeleted || Next.Mon==none || Next.MonMesh==none)
	{
		log("GetNext() return Next getNext");
		return Next.GetNext();
	}
	else
	{
		log("GetNext() return Next");
		return Next;
	}
}
//--------------------------------------------------------------------------------------------------
function MCMonsterList Find(KFMonster M)
{
	if (Mon==M)
		return self;
	else if (Next!=none)
		return Next.Find(M);
	else
		return none;
}
//--------------------------------------------------------------------------------------------------
simulated function toLog(string M)
{
	log("MCMonsterList->"$M);
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
defaultproperties
{
	
}