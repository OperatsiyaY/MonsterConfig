class MCMonsterList	extends ReplicationInfo;

var MCMonsterList Next;


var KFMonster	Monster;
var Controller	Controller;
var Name		MonsterName;
var string		MonsterInfoName;
var int			revision, revisionClient;
var bool		bDeleted;

var int			ListRevision, ListRevisionClient;

replication
{
	reliable if (ROLE == ROLE_Authority)
		Monster, Controller, MonsterName, MonsterInfoName, bDeleted,
		Next, revision, ListRevision;
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
function Add(KFMonster M, Controller C, Name N, optional string MIName)
{
	local MCMonsterList MList;
	MList = Find(M, C, N);
	if (MList!=none)
		SetMList(MList, M, C, N, MIName);
	else if (bDeleted)
		SetMList(self, M, C, N, MIName);
	else
	{
		if (Next==none)
			Next = Spawn(class'MCMonsterList',Owner);
		Next.Add(M, C, N, MIName);
	}
}
//--------------------------------------------------------------------------------------------------
function SetMList(MCMonsterList MList, KFMonster M, Controller C, Name N, string MIName)
{
	MList.Monster		= M;
	MList.Controller	= C;
	MList.MonsterName	= N;
	MList.MonsterInfoName = MIName;
	MList.bDeleted		= false;
	MList.revision++;
}
//--------------------------------------------------------------------------------------------------
function Del(KFMonster M, Controller C, Name N)
{
	if (Monster==M || Controller == C ||  MonsterName == N || Monster == none || Controller == none)
		bDeleted=true;
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
simulated function MCMonsterList Find(KFMonster M, optional Controller C, optional Name N, optional string MIName)
{
	if( (M!=none && Monster==M)
		|| (C!=none && Controller==C)
		|| (Len(string(N))>0 && MonsterName==N) )
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