class MCMonsterList	extends ReplicationInfo;

var MCMonsterList Prev,Next;
var MonsterConfig SandboxController;

var KFMonster	Monster;
var Controller	Controller;
var String		MonsterInfoName; // репликация name не работает как надо. на клиенте все реплицированные Name == "TexEnvMap"
var bool		bDeleted, bDeletedClient;
var byte		revision, revisionClient;

var byte		listRevision, listRevisionClient;
var Name clearName;

replication
{
	reliable if (bNetInitial && ROLE == ROLE_Authority)
		SandboxController;
	reliable if (ROLE == ROLE_Authority)
		bDeleted;
	reliable if (bDeleted==false && ROLE == ROLE_Authority)
		Monster, MonsterInfoName, revision;
		/*Next, revision, listRevision;*/
		/*Controller,*/
		/*Prev,*/
}
//--------------------------------------------------------------------------------------------------
function PostBeginPlay()
{
	super.PostBeginPlay();
	SandboxController = MonsterConfig(Owner);
}
//--------------------------------------------------------------------------------------------------
simulated function PostNetReceive()
{
	if (bDeleted && bDeletedClient!=bDeleted)
	{
		Controller = none;
		Monster = none;
		MonsterInfoName = "";
		bDeletedClient = bDeleted;
	}
	else if (!bDeleted && revision!=revisionClient && Monster!=none && Len(MonsterInfoName)>0)
	{
		SandboxController.InitMonster(Monster, MonsterInfoName);
		revisionClient = revision;
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
function Add(Controller C, string MIName)
{
	if (Controller == C || bDeleted)
	{
		Controller	= C;
		Monster		= KFMonster(C.Pawn);
		if (Len(MIName)>0)
			MonsterInfoName = MIName;
		bDeleted = false;
		revision++;
		SandboxController.InitMonster(Monster, MonsterInfoName);
		NetUpdateTime = Level.TimeSeconds-1.f;
	}
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
}
//--------------------------------------------------------------------------------------------------
function Del(Controller C)
{
	local MCMonsterList MList;
	local MCMonsterList CacheNext;

	CacheNext = Next;
	if( C!=none && Controller==C )
	{
		// удаляем
		Controller = none;
		MonsterInfoName = "";//clearName;
		revision++;
		revisionClient = revision;
		bDeleted=true;
		//NetUpdateTime = Level.TimeSeconds-1.f;
		
		// перемещаем в конец
		if (Prev!=none)
		{
			MList = GetLast();
			if ( MList != self ) // если последний, или и так попорядку всё, тоже
			{
				// выдергиваем себя из списка
				Prev.Next = Next;
				Next.Prev = Prev;
				
				// ставим себя после последнего найденного элемента
				Next = none;
				Prev = MList;
				
				MList.Next = self;
			}
		}

	}
	else if (CacheNext!=none && !CacheNext.bDeleted)  // else возможно убрать, чтобы числил весь лист от C
		CacheNext.Del(C);
}
//--------------------------------------------------------------------------------------------------
function Clear()
{
	bDeleted = true;
	Controller = none;
	MonsterInfoName = "";//clearName;
	if (Next != none /*&& !Next.bDeleted*/)
		Next.Clear();
}
//--------------------------------------------------------------------------------------------------
function MCMonsterList GetLast()
{
	local MCMonsterList MList;
	for (MList=self; MList!=none; MList=MList.Next)
		if (MList.Next==none)
			return MList;
	
	log("Error: MonsterConfig->MCMonsterList error in GetLast()");
	return none;
}
//--------------------------------------------------------------------------------------------------
// внутренняя функция для работы Del
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
	
	bNetNotify=true
	RemoteROLE=ROLE_SimulatedProxy
	bAlwaysRelevant=true
}