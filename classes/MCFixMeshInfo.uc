class MCFixMeshInfo extends Object
	/*ParseConfig
	PerObjectConfig
	config(MonsterConfig)*/;
var const string delim;

var class<KFMonster>	MClass;
var Mesh				Mesh;
var array<Material>		Skins;
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
simulated function GetI(out string s, out int I)
{
	I = int(Get(S));
}
//--------------------------------------------------------------------------------------------------
simulated function GetF(out string s, out float F)
{
	F = float(Get(S));
}
//--------------------------------------------------------------------------------------------------
simulated static function string Get(out string s, optional out string str)
{
	local string l;
	local int n;
	n = InStr(s,default.delim);
	while (n==0)
	{
		s = Right(s, Len(s)-1);
		n = InStr(s,default.delim);
	}
	if (n==-1)
	{
		l=s;
		s="";
	}
	else
	{
		l = Left(s,n);
		s = Right(s, Len(s)-(n+1));
	}
	str = l;
	return l;
}
//--------------------------------------------------------------------------------------------------
simulated static function string UnSerializeName(string S)
{
	return Get(S);
}
//--------------------------------------------------------------------------------------------------
simulated function UnSerialize(string S)
{
	local int i,n;
	local class<Material> MaterialClass;

	MClass = class<KFMonster>(DynamicLoadObject(Get(S), Class'Class'));
		
	Mesh = Mesh(DynamicLoadObject(Get(S), Class'Mesh'));

	Skins.Remove(0,Skins.Length);
	GetI(S, n);
	Skins.Insert(0,n);
	for (i=0;i<n;i++)
	{
		MaterialClass	= class<Material>(DynamicLoadObject(Get(S), class'Class'));
		Skins[i]		= Material(DynamicLoadObject(Get(S), MaterialClass));
		// Marco said that we can use only this. And it works, but.... dunno why, 
		// I want to specify the class of Material.
		//Skins[i] = Material(DynamicLoadObject(t2, class'Material'));		
	}
}
//--------------------------------------------------------------------------------------------------
simulated function string Serialize()
{
	local string S, t;
	local int i;
	
	Push(S, string(MClass));
	Push(S, string(Mesh));
	
	PushI(S, Skins.Length);
	for (i=0;i<Skins.Length;i++)
	{
		t = string(Skins[i].Class); // save the class (Shader, Combiner, Texture, others...)
		Push(S, t);
		
		t = string(Skins[i]);
		Push(S, t);
	}
	return S;
}
//--------------------------------------------------------------------------------------------------
simulated function PushI(out string s, int input)
{
	Push(s, string(input));
}
//--------------------------------------------------------------------------------------------------
simulated function PushF(out string s, float input)
{
	Push(s, string(input));
}
//--------------------------------------------------------------------------------------------------
simulated function Push(out string s, string input)
{
	if (Len(s) == 0)
		s = input;
	else
		s $= delim$input;
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
defaultproperties
{
	delim = "+"
}