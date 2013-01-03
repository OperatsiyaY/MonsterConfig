class MCStringReplicationInfo extends ReplicationInfo;

const MaxSize = 255;

var string Str;
var MCStringReplicationInfo Next;
var int length;
var int revision;
var int revisionClient;

var bool bMenuStr;
var PlayerController OwnerPC;
var array<string> ClientStr;

replication 
{
	reliable if ( /*bNetDirty && */Role == ROLE_Authority )
		Str, Next, length, revision,
		OwnerPC, bMenuStr;

	reliable if ( Role != ROLE_Authority )	
		SetStringClient;
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
simulated function SetStringClient(string value, int chunkNum, int chunkCount, int sLen)
{
	local int i;
	local string S;
	if (ClientStr.Length < chunkCount)
		ClientStr.Insert(ClientStr.Length, chunkCount - ClientStr.Length);
	
	ClientStr[chunkNum] = value;
	S="";
	for (i=0;i<ClientStr.Length;i++)
		S $= ClientStr[i];

	if (Len(S) == sLen)
	{
		SetString(S);
		ClientStr.Remove(0,ClientStr.Length);
	}
}
/*simulated function SetStringClient(string value, optional bool bAdd)
{
	if (bAdd)
		SetString(GetString() $ value);
	else
		SetString(value);	
}*/
//--------------------------------------------------------------------------------------------------
simulated function SetString(string value)
{
	ClearString();
	
	revision++;
	
	length = Len(value);
	if ( len(value) <= MaxSize )
		Str = value;
	else
	{
		Str = Left(value, MaxSize);
		Next = spawn(self.class, self);
		Next.SetString(Right(value, len(value) - MaxSize));
	}
}

simulated function string GetString(optional out int bBadCRC, optional bool bNext)
{
	local string ret;
	if (!bNext)
	{
		bBadCRC = 0;
		bNext=true;
	}

	if (Next==none)
		ret = Str;
	else
		ret = Str $ Next.GetString(bBadCRC, bNext);
		
	if (length != Len(ret))
		bBadCRC=1;

	return ret;
/*	{
		if (Next.GetString(S, bNext)==false)
			return false;
		else
		{
			S = Str $ S;
			return true;
		}
	}*/
	//return Str $ Next.GetString(bFull);
}

simulated function ClearString()
{
	Str = "";
	if ( Next != none )
	{
		Next.ClearString();
		Next.Destroy();
		Next = none;
	}
}