/*
 * Класс обеспечивает функционирование и репликацию на клиенты связного списка Монстр-МонстрИнфоName
 */
class MCMonsterList	extends ReplicationInfo;

var MCMonsterList Prev,Next;
var MonsterConfig SandboxController;

var KFMonster	Monster;
var Controller	Controller;		 // на клиенте контроллеры не спавнятся, поэтому используем Monster
var string		MonsterInfoName; // репликация name не работает как надо. на клиенте все реплицированные Name == "TexEnvMap"

var bool		bDeleted, bDeletedClient;
var byte		revision, revisionClient;

var bool		bDebug;

replication
{
	reliable if (bNetInitial && ROLE == ROLE_Authority)
		SandboxController;
	reliable if (ROLE == ROLE_Authority)
		bDeleted;
	reliable if (bDeleted==false && ROLE == ROLE_Authority)
		Monster, MonsterInfoName, revision;
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
		Controller		= none;
		Monster			= none;
		MonsterInfoName	= "";
		bDeletedClient	= bDeleted;
	}
	else if (!bDeleted && revision!=revisionClient && Monster!=none && Len(MonsterInfoName)>0)
	{
		SandboxController.InitMonster(Monster, MonsterInfoName);
		revisionClient = revision;
	}
}
//--------------------------------------------------------------------------------------------------
function Print()
{
	local MCMonsterList MList;
	local int i;
	for (MList=self; MList!=none; MList=MList.Next)
	{
		log("MList["$i++$"] Controller:"$string(MList.Controller)@"Monster:"$string(MList.Monster)@"MonsterInfo:"$MList.MonsterInfoName);
	}
	log("--------------");
}
//--------------------------------------------------------------------------------------------------
function Add(Controller C, string MIName)
{
	if (bDebug && Prev==none)
	{
		log("pre add Controller:"$string(C)@"MonsterInfoName:"$MIName);
		Print();
	}
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

	// если монстр исчез без нашего оповещения (Controller==none), удаляем запись
	if (Prev!=none && !bDeleted && Controller==none)
	{
		DelSelf();
	}
	
	if (bDebug && Prev==none)
	{
		log("post add Controller:"$string(C)@"MonsterInfoName:"$MIName);
		Print();
	}
}
//--------------------------------------------------------------------------------------------------
function DelSelf()
{
	local MCMonsterList MList;
	// удаляем
	Controller = none;
	Monster = none;
	MonsterInfoName = "";
	revision++;
	revisionClient = revision;
	bDeleted=true;
	//NetUpdateTime = Level.TimeSeconds-1.f;

	// перемещаем в конец
	if (Prev!=none)
	{
		MList = GetLast();
		if ( MList != self ) // если я не последний
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
//--------------------------------------------------------------------------------------------------
function Del(Controller C)
{
	//local MCMonsterList CacheNext;
	local MCMonsterList MList;
	
	if (bDebug && Prev==none)
	{
		log("pre del Controller:"$string(C));
		Print();
	}

	for (MList=self; MList!=none; MList=MList.Next)
	{
		if (MList.Controller==none)
		{
			MList.DelSelf();
			continue;
		}
		if (MList.Controller == C)
		{
			MList.DelSelf();
			break;
		}
	}
/*	
	CacheNext = Next;
	if( C!=none && Controller==C )
		DelSelf();

	else if (CacheNext!=none && !CacheNext.bDeleted)  // else возможно убрать, чтобы числил весь лист от C
		CacheNext.Del(C);
*/	
	if (bDebug && Prev==none)
	{
		log("post del Controller:"$string(C));
		Print();
	}
}
//--------------------------------------------------------------------------------------------------
function Clear()
{
	local MCMonsterList MList;
	for (MList=self; MList!=none; MList=MList.Next)
	{
		MList.bDeleted = true;
		MList.Controller = none;
		MList.Monster = none;
		MList.MonsterInfoName = "";
	}
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
/*simulated function MCMonsterList GetNext()
{
	if (Next==none || Next.bDeleted)
		return none;
	else
		return Next;
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
}*/
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
defaultproperties
{
	bDeleted=true
	bDebug=false

	bNetNotify=true
	RemoteROLE=ROLE_SimulatedProxy
	bAlwaysRelevant=true
}