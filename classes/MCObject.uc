/*
	Это базовый объект в который вынесены базовые функции перевода в строку и обратно
*/
//--------------------------------------------------------------------------------------------------
class MCObject extends Object;

var int		revision;
var string	ConfigFile;
var name	NameConversionHack;
var const string delim;
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
simulated function name StringToName(string str)
{
  SetPropertyText("NameConversionHack", str);
  return NameConversionHack;
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
defaultproperties
{
	delim = "+"
}