class MCMonsterList	extends ReplicationInfo;

var MCMonsterList Prev,Next;

var MonsterConfig SandboxController;

var KFMonster	Monster;
var Controller	Controller;
var string		MonsterName;
var string		MonsterInfoName;
var int			revision, revisionClient;
var bool		bDeleted;

var int			listRevision, listRevisionClient;

replication
{
	reliable if (ROLE == ROLE_Authority)
		Monster, Controller, MonsterName, MonsterInfoName, bDeleted,
		Next, revision, ListRevision;
}
//--------------------------------------------------------------------------------------------------
simulated function PostBeginPlay()
{
	SandboxController = MonsterConfig(Owner);
	super.PostBeginPlay();
}
//--------------------------------------------------------------------------------------------------
function Add(KFMonster M, Controller C, optional string MIName)
{
	local MCMonsterList MList;
	MList = Find(M, C);
	if (MList!=none)
		SetMList(MList, M, C, MIName);
	else if (bDeleted)
		SetMList(self, M, C, MIName);
	else
	{
		if (Next==none)
		{
			Next = Spawn(class'MCMonsterList',Owner);
			Next.Prev = self;
		}
		Next.Add(M, C, MIName);
	}
	listRevision++;
}
//--------------------------------------------------------------------------------------------------
function SetMList(MCMonsterList MList, KFMonster M, Controller C, string MIName)
{
	MList.Monster		= M;
	MList.Controller	= C;
	MList.MonsterName	= string(M);
	if (Len(MIName)>0)
		MList.MonsterInfoName = MIName;
	MList.bDeleted		= false;
	MList.revision++;
}
//--------------------------------------------------------------------------------------------------
function Del(KFMonster M, Controller C, optional string N)
{
	if( (M!=none && Monster==M)
		|| (C!=none && Controller == C)
		|| (Len(N)>0 && MonsterName == N)
		/*|| Monster == none || Controller == none*/)
	{
		bDeleted=true;
		Monster = none;
		Controller = none;
		MonsterName = "";
		MonsterInfoName = "";
	}
	if (Next != none)
		Next.Del(M, C, N);
}
//--------------------------------------------------------------------------------------------------
function Clear()
{
	bDeleted=true;
	if (Next!=none)
		Next.Clear();
}
//--------------------------------------------------------------------------------------------------
simulated function MCMonsterList GetNext()
{
	if (Next==none)
		return none;
	else if (Next.bDeleted)
		return Next.GetNext();
	else
		return Next;
}
//--------------------------------------------------------------------------------------------------
simulated function MCMonsterList Find(KFMonster M, optional Controller C, optional string N, optional string MIName)
{
	if( (M!=none && Monster==M)
		|| (C!=none && Controller==C)
		|| (Len(N)>0 && MonsterName==N) )
		return self;
	else if (Next != none)
		return Next.Find(M, C, N, MIName);
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
	bDeleted=true
}