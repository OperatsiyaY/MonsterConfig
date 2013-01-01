class MCMonsterList	extends ReplicationInfo;

var MCMonsterList Prev,Next;
var MonsterConfig SandboxController;

var Controller	Controller;
var string		MonsterInfoName;
var bool		bDeleted, bDeletedClient;
var int			revision, revisionClient;

var int			listRevision, listRevisionClient;

replication
{
	reliable if (ROLE == ROLE_Authority)
		Controller, MonsterInfoName, bDeleted,
		Prev, Next, revision, listRevision;
}
//--------------------------------------------------------------------------------------------------
simulated function PostBeginPlay()
{
	super.PostBeginPlay();
	SandboxController = MonsterConfig(Owner);
}
//--------------------------------------------------------------------------------------------------
simulated function Tick( float dt )
{
	local int i,n;
	if( revisionClient != revision )
	{
		if ( Controller!=none && bDeleted==false )
		{
			n = SandboxController.AliveMonstersCache.Length;
			SandboxController.AliveMonstersCache.Insert(n,1);
			SandboxController.AliveMonstersCache[n].Mon	= KFMonster(Controller.Pawn);
			SandboxController.AliveMonstersCache[n].Controller = Controller;
			SandboxController.AliveMonstersCache[n].MonsterInfoName = MonsterInfoName;
			SandboxController.AliveMonstersCache[n].revision = revision;
			revisionClient = revision;
		}
		if( bDeleted && bDeletedClient != bDeleted )
		{
			n = SandboxController.AliveMonstersCache.Length;
			for (i = SandboxController.AliveMonstersCache.Length-1; i>=0; --i)
				if (SandboxController.AliveMonstersCache[i].Controller == Controller)
					SandboxController.AliveMonstersCache.Remove(i,1);
			bDeletedClient = bDeleted;
			revisionClient = revision;
		}
	}
}
//--------------------------------------------------------------------------------------------------
function int CountAll()
{
	if (Next==none)
		return 1;
	else return 1+Next.CountAll();
}
//--------------------------------------------------------------------------------------------------
function int Count()
{
	local int n;
	if (!bDeleted)
		n = 1;

	if (Next!=none)
		n += Next.Count();
	return n;
}
//--------------------------------------------------------------------------------------------------
function Add(Controller C, optional string MIName)
{
/*	MList = Find(C);
	if (MList!=none)
	{
		SandboxController.LM("NASHOL 4OTO!!!!!!!!!!!!!!!");
		SetMList(MList, C, MIName);
	}*/
	if (Controller == C || bDeleted)
		SetMList(self, C, MIName);
	else
	{
		if (Next==none)
		{
			Next = Spawn(class'MCMonsterList',Owner);
			Next.Prev = self;
		}
		Next.Add(C, MIName);
	}
	listRevision++;
	NetUpdateTime = Level.TimeSeconds-1.f;
}
//--------------------------------------------------------------------------------------------------
function SetMList(MCMonsterList MList, Controller C, string MIName)
{
	MList.Controller	= C;
	if (Len(MIName)>0)
		MList.MonsterInfoName = MIName;
	MList.bDeleted		= false;
	MList.revision++;
}
//--------------------------------------------------------------------------------------------------
function Del(Controller C)
{
	local MCMonsterList MList;
	local MCMonsterList CacheNext;

	CacheNext = Next;
	if( C!=none && Controller==C )
	{
		if (Prev!=none && Next != none) // первый элемент, на который ссылкаетс€ SandboxController, перемещать в коенц нельз€
		{
			MList = Next.GetFirstDeleted();
			if ( MList!=none && MList != Next ) // если последний, или и так попор€дку всЄ, тоже
			{
				// выдергиваем себ€ из списка
				Prev.Next = Next;
				Next.Prev = Prev;
				
				// ставим себ€ перед первым найденным удалЄнным элементом
				Next = MList;
				Prev = MList.Prev;

				MList.Prev = self;
			}
		}
		if (Prev!=none)
			bDeleted=true;
		Controller = none;
		MonsterInfoName = "";
		revision++;
		NetUpdateTime = Level.TimeSeconds-1.f;
	}
	else if (CacheNext!=none && !CacheNext.bDeleted)  // else возможно убрать, чтобы числил весь лист от C
		CacheNext.Del(C);
}
//--------------------------------------------------------------------------------------------------
function Clear()
{
	bDeleted = true;
	Controller = none;
	MonsterInfoName = "";
	if (Next != none /*&& !Next.bDeleted*/)
		Next.Clear();
}
//--------------------------------------------------------------------------------------------------
// внутренн€€ функци€ дл€ работы Del
function function MCMonsterList GetFirstDeleted()
{
	if (bDeleted)
		return self;
	else if (Next!=none)
		Next.GetFirstDeleted();
	else
		return none;
}
//--------------------------------------------------------------------------------------------------
simulated function MCMonsterList GetNext()
{
	if (Next==none || Next.bDeleted)
		return none;
	else
		return Next;
}
//--------------------------------------------------------------------------------------------------
simulated function MCMonsterList Find(Controller C)
{
	if( C!=none && Controller==C )
		return self;
	else if (Next != none && !Next.bDeleted)
		return Next.Find(C);
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
	bNetNotify=true;
}