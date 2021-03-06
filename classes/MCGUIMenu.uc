class MCGUIMenu extends LargeWindow;
var MonsterConfig MC;

// основные контроллы
var GUIVertScrollBar	VScroll;
var int					ScrollPos;
var GUIButton			bExit, bSave;

struct GUIComboBoxA
{
	var GUIComboBox	combo;
	var GUIButton	button;
	var string		Name;
	var int			WinTop;
	var int			row;
};
var array<GUIComboBoxA> combos;

struct GUIParamEditBox
{
	var GUILabel	label;
	var GUIEditBox	ebox;
	var string		Name;
	var int			WinTop;
	var int			row;
};
var array<GUIParamEditBox> paramsEBox;

struct GUILabelS
{
	var GUILabel	label;
	var string		Name;
	var int			WinTop;
	var int			row;
};
var array<GUILabelS> labels;

enum EMethods
{
	GET, SET,
};

var int ExitBtnAreaHeight;	// высота области кнопок OK Cancel (не прокручивается скроллом)
var int gap;				// дефолтный зазор
var int rowH, colW;		// стандартная высота и ширина контрола
var int eboxW; // стандартная ширина eboxa

var GUIComboBox CB;
var GUIButton CBB;

var bool bInitialized;
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
event HandleParameters(string Param1, string Param2)
{
	log("HandleParameters"@ActualHeight()@t_WindowTitle.ActualHeight());
	foreach PlayerOwner().DynamicActors(class'MonsterConfig', MC)
		break;
	if (MC==none)
	{
		PlayerOwner().ClientMessage("MCGUIMenu: MonsterConfig not found, so exit");
		PlayerOwner().ClientCloseMenu(True,False); //CloseAll(false,true);
		return;
	}

	gap 			  = 2;
	ExitBtnAreaHeight = 90;
	rowH 			  = 30;
	colW 			  = 160;
	eboxW 			  = 60;
	
	bInitialized = false;
	SetTimer(0.5, false);
	//SetupGUIValues();
}
//--------------------------------------------------------------------------------------------------
// вызывает первоначальную иницилазацию контроллов
function Timer()
{
	if (!bInitialized)
	{
		InitControls();
		bInitialized = true;
	}
	
}
//--------------------------------------------------------------------------------------------------
function string GetGameInfo(string P)
{
	local float ret;
	if (P ~= "GIFakedPlayersNum")
		ret = MC.GameInfo.FakedPlayersNum;
	else if (P ~= "GIMonsterBodyHPMod")
		ret = MC.GameInfo.MonsterBodyHPMod;
	else if (P ~= "GIMonsterHeadHPMod")
		ret = MC.GameInfo.MonsterHeadHPMod;
	else if (P ~= "GIMonsterSpeedMod")
		ret = MC.GameInfo.MonsterSpeedMod;
	else if (P ~= "GIMonsterDamageMod")
		ret = MC.GameInfo.MonsterDamageMod;
	else if (P ~= "GIbWaveFundSystem")
		ret = float(MC.GameInfo.bWaveFundSystem);
	else if (P ~= "GIHealedToScoreCoeff")
		ret = MC.GameInfo.HealedToScoreCoeff;
	else if (P ~= "GIMoneyMod")
		ret = MC.GameInfo.MoneyMod;
	else if (P ~= "GIMonstersMaxAtOnceMod")
		ret = MC.GameInfo.MonstersMaxAtOnceMod;
	else if (P ~= "GIMonstersTotalMod")
		ret = MC.GameInfo.MonstersTotalMod;
	else if (P ~= "GIBroadcastKillmessagesMass")
		ret = MC.GameInfo.BroadcastKillmessagesMass;
	else if (P ~= "GIBroadcastKillmessagesHealth")
		ret = MC.GameInfo.BroadcastKillmessagesHealth;
	else if (P ~= "GIGameDifficulty")
		ret = MC.GameInfo.GameDifficulty;

	return string(ret);
}
//--------------------------------------------------------------------------------------------------
function RefreshGameInfo()
{
	local int i;
	for (i=paramsEBox.length; i>=0; --i)
		if (InStr(paramsEBox[i].Name, "GI")==0)
			paramsEBox[i].ebox.SetText( GetGameInfo(paramsEBox[i].Name) );
}
//--------------------------------------------------------------------------------------------------
function string GetMapInfo(string P)
{
	local float ret;
	if (P ~= "MISquadDelayMod")
		ret = MC.MapInfo.SquadDelayMod;
	else if (P ~= "MIMonstersTotalCoeff")
		ret = MC.MapInfo.MonstersTotalCoeff;
	else if (P ~= "MIMonstersMaxAtOnceCoeff")
		ret = MC.MapInfo.MonstersMaxAtOnceCoeff;
	else if (P ~= "MIbUseZombieVolumeWaveDisabling")
		ret = float(MC.MapInfo.bUseZombieVolumeWaveDisabling);
	else if (P ~= "MITimeBetweenWaves")
		ret = MC.MapInfo.TimeBetweenWaves;
	else if (P ~= "MIMonsterBodyHPMod")
		ret = MC.MapInfo.MonsterBodyHPMod;
	else if (P ~= "MIMonsterHeadHPMod")
		ret = MC.MapInfo.MonsterHeadHPMod;
	else if (P ~= "MIMonsterSpeedMod")
		ret = MC.MapInfo.MonsterSpeedMod;
	else if (P ~= "MIMonsterDamageMod")
		ret = MC.MapInfo.MonsterDamageMod;
	else if (P ~= "MIPerPlayerSquadDelayMod")
		ret = MC.MapInfo.PerPlayerSquadDelayMod;
	else if (P ~= "MIPerPlayerSquadDelayModMin")
		ret = MC.MapInfo.PerPlayerSquadDelayModMin;
	else if (P ~= "MIPerPlayerSquadDelayModMax")
		ret = MC.MapInfo.PerPlayerSquadDelayModMax;

	return string(ret);
}
//--------------------------------------------------------------------------------------------------
function RefreshMapInfo(string MapName)
{
	local int i;
	//if (MapName ~= string(MC.MapInfo.Name))
	for (i=paramsEBox.length; i>=0; --i)
		if (InStr(paramsEBox[i].Name, "MI")==0)
			paramsEBox[i].ebox.SetText( GetMapInfo(paramsEBox[i].Name) );
}
//--------------------------------------------------------------------------------------------------
function MapInfoComboChange(GUIComponent Sender)
{
	local GUIComboBox CBox;
	CBox = GUIComboBox(Sender);
	if (CBox.TextStr ~= string(MC.MapInfo.Name) 
		|| CBox.TextStr ~= "default")
		RefreshMapInfo(CBox.TextStr);
	else
		CBox.SetText(string(MC.MapInfo.Name));
}
//--------------------------------------------------------------------------------------------------
// Создает и инициализирует стандартные контроллы
function InitControls()
{
	local int i;
	local int row,col,nrows,ncols, idx;
	
	if (VScroll==none)
	{
		VScroll                 = GUIVertScrollBar(AddComponent("XInterface.GUIVertScrollBar"));
		VScroll.bBoundToParent  = true;
		VScroll.bNeverScale     = true;
		VScroll.bScaleToParent  = false;
		VScroll.ScalingType     = SCALE_Y;
		VScroll.PositionChanged = PositionChanged;
		VScroll.ItemCount       = 1200;
		VScroll.ItemsPerPage    = 400;
	}
	if (bExit==none)
	{
		bExit				 = GUIButton(AddComponent("XInterface.GUIButton"));
		bExit.bBoundToParent = true;
		bExit.bNeverScale    = true;
		bExit.Caption        = "Cancel";
	}
	if (bSave==none)
	{
		bSave				 = GUIButton(AddComponent("XInterface.GUIButton"));
		bSave.bBoundToParent = true;
		bSave.bNeverScale 	 = true;
		bSave.Caption 		 = "OK";
	}
	
	row=1; ncols=2; col=1; nrows=1;
	InitLabel(1,ncols,row,nrows,"Game", TXTA_Center);
	InitLabel(3,ncols,row,nrows,"MapInfo", TXTA_Center);

	col=1; row=2; nrows=1; ncols=2;
	InitParam(col,ncols,row++,nrows,"GIFakedPlayersNum"            , "FakedPlayersNum");
	InitParam(col,ncols,row++,nrows,"GIMonstersMaxAtOnceMod"       , "MonstersMaxAtOnceMod");
	InitParam(col,ncols,row++,nrows,"GIMonsterTotalMod"            , "MonsterTotalMod");
	InitParam(col,ncols,row++,nrows,"GIMonsterBodyHPMod"           , "MonsterBodyHPMod");
	InitParam(col,ncols,row++,nrows,"GIMonsterHeadHPMod"           , "MonsterHeadHPMod");
	InitParam(col,ncols,row++,nrows,"GIMonsterSpeedMod"            , "MonsterSpeedMod");
	InitParam(col,ncols,row++,nrows,"GIMonsterDamageMod"           , "MonsterDamageMod");
	InitParam(col,ncols,row++,nrows,"GIHealedToScoreCoeff"         , "HealedToScoreCoeff");
	InitParam(col,ncols,row++,nrows,"GIBroadcastKillmessagesMass"  , "BroadcastKillmessagesMass");
	InitParam(col,ncols,row++,nrows,"GIBroadcastKillmessagesHealth", "BroadcastKillmessagesHealth");
	InitParam(col,ncols,row++,nrows,"GIGameDifficulty"             , "GameDifficulty");
	InitParam(col,ncols,row++,nrows,"GIMoneyMod","MoneyMod");
	RefreshGameInfo();
	
	InitLabel(1,ncols,row++,nrows,"MonsterInfo", TXTA_Center);
	idx = InitCombo(col,ncols,row++,nrows,"MonInfoMName");	// основное комбо
	for (i=0; i<MC.Monsters.Length; i++)
		combos[idx].combo.AddItem(string(MC.Monsters[i].Name));
	//combos[idx].combo.OnChange                = MonsterInfoComboChange;
	combos[idx].combo.bReadOnly               = false;
	combos[idx].combo.bIgnoreChangeWhenTyping = false;
// класс моба
	idx = InitCombo(col,ncols,row++,nrows,"MonInfoMClass");
	//combos[idx].combo.OnChange                = MonsterInfoMClassComboChange;
	combos[idx].combo.bReadOnly               = false;
	combos[idx].combo.bIgnoreChangeWhenTyping = false;
	InitParam(col,ncols,row++,nrows,"MonInfoHealth",              "Health");
	InitParam(col,ncols,row++,nrows,"MonInfoHeadHealth",          "HeadHealth");
	InitParam(col,ncols,row++,nrows,"MonInfoSpeed",               "Speed");
	InitParam(col,ncols,row++,nrows,"MonInfoSpeedMod",            "SpeedMod");
	InitParam(col,ncols,row++,nrows,"MonInfoMonsterName",         "MonsterName");
	InitParam(col,ncols,row++,nrows,"MonInfoPerPlayerHealth",     "PerPlayerHealth");
	InitParam(col,ncols,row++,nrows,"MonInfoPerPlayerHealHealth", "PerPlayerHealHealth");
// резисты
	idx = InitCombo(col,ncols,row++,nrows,"MonInfoResist");
	//combos[idx].combo.OnChange                = MonsterInfoResistComboChange;
	combos[idx].combo.bReadOnly               = false;
	combos[idx].combo.bIgnoreChangeWhenTyping = false;
	InitParam(col,ncols,row++,nrows,"MonInfoRewardScore",      "RewardScore");
	InitParam(col,ncols,row++,nrows,"MonInfoRewardScoreCoeff", "RewardScoreCoeff");
	InitParam(col,ncols,row++,nrows,"MonInfoMonsterSize",      "MonsterSize");
// меши
	idx = InitCombo(col,ncols,row++,nrows,"MonInfoMesh");
	//combos[idx].combo.OnChange                = MonsterInfoMeshComboChange;
	combos[idx].combo.bReadOnly               = false;
	combos[idx].combo.bIgnoreChangeWhenTyping = false;
// скины
	idx = InitCombo(col,ncols,row++,nrows,"MonInfoSkin");
	//combos[idx].combo.OnChange                = MonsterInfoSkinComboChange;
	combos[idx].combo.bReadOnly               = false;
	combos[idx].combo.bIgnoreChangeWhenTyping = false;

	
	col=3; row=2; nrows=1; ncols=2;
	idx = InitCombo(col,ncols,row++,nrows,"MapInfoName",true); // true - инициализировать без кнопки
	combos[idx].combo.AddItem("default");
	combos[idx].combo.AddItem(string(PlayerOwner().Level.outer.name));
	//combos[idx].combo.OnChange                = MapInfoComboChange;
	combos[idx].combo.bReadOnly               = true;
	combos[idx].combo.bIgnoreChangeWhenTyping = true;
	//combos[idx].combo.Edit.OnChange 
	//combos[idx].button.Caption = string(MC.MapInfo.Name)@string(PlayerOwner().Level.outer.name);
	InitParam(col,ncols,row++,nrows,"MISquadDelayMod"                , "SquadDelayMod");
	InitParam(col,ncols,row++,nrows,"MIMonstersTotalCoeff"           , "MonstersTotalCoeff");
	InitParam(col,ncols,row++,nrows,"MIMonstersMaxAtOnceCoeff"       , "MonstersMaxAtOnceCoeff");
	InitParam(col,ncols,row++,nrows,"MIbUseZombieVolumeWaveDisabling", "bUseZombieVolumeWaveDisabling");
	InitParam(col,ncols,row++,nrows,"MITimeBetweenWaves"             , "TimeBetweenWaves");
	InitParam(col,ncols,row++,nrows,"MIMonsterBodyHPMod"             , "MonsterBodyHPMod");
	InitParam(col,ncols,row++,nrows,"MIMonsterHeadHPMod"             , "MonsterHeadHPMod");
	InitParam(col,ncols,row++,nrows,"MIMonsterSpeedMod"              , "MonsterSpeedMod");
	InitParam(col,ncols,row++,nrows,"MIMonsterDamageMod"             , "MonsterDamageMod");
	InitParam(col,ncols,row++,nrows,"MIPerPlayerSquadDelayMod"       , "PerPlayerSquadDelayMod");
	InitParam(col,ncols,row++,nrows,"MIPerPlayerSquadDelayModMin"    , "PerPlayerSquadDelayModMin");
	InitParam(col,ncols,row++,nrows,"MIPerPlayerSquadDelayModMax"    , "PerPlayerSquadDelayModMax");
	combos[idx].combo.SetText(string(MC.MapInfo.Name),true); // вызываем onchange и прописываем значения
	
	ReInitControls();
}
/*--------------------------------------------------------------------------------------------------
									секция MonsterInfo
--------------------------------------------------------------------------------------------------*/
function MonsterInfoComboChange(GUIController L)
{
/*	local int i, idx;
	local GUIComboBox CBox;
	local string S;
	local MCMonsterInfo MI;
	
//	CBox = GUIComboBox(L);
	S    = CBox.GetText();
	MI   = MC.GetMonInfoByName(S);
	if (Len(CBox.find(S)>0))
	if (MI != none)
	{
		// проверить есть ли в комбо-боксе этот пункт
		
			// если нет - зажечь кнопку добавить
			// выйти
		// выделить нужный элемент в комбо-боксе
		// зажечь кнопку DEL
		// прочитать параметры
	}
	else
	{
		// зажечь кнопку ADD
		// обнулить параметры
	}*/
}
/*--------------------------------------------------------------------------------------------------
								конец секции MonsterInfo
--------------------------------------------------------------------------------------------------*/
// Вызывается во время изменения параметров окна или движения скролла
function ReInitControls()
{
	local int i;

	VScroll.WinTop    = t_WindowTitle.ActualHeight()+1;
	VScroll.WinHeight = ActualHeight() - VScroll.WinTop - ExitBtnAreaHeight + 1;
	VScroll.WinWidth  = 30;
	VScroll.WinLeft   = ActualWidth() - VScroll.WinWidth - 3;
	
	bExit.WinLeft   = ActualWidth() / 2 + gap;
	bExit.WinWidth  = ActualWidth() / 2 - gap*2;
	bExit.WinHeight = ExitBtnAreaHeight - gap*2;
	bExit.WinTop    = ActualHeight() - ExitBtnAreaHeight + gap;
	
	bSave.WinLeft   = gap;
	bSave.WinWidth  = ActualWidth() / 2 - gap*2;
	bSave.WinHeight = ExitBtnAreaHeight - gap*2;
	bSave.WinTop    = ActualHeight() - ExitBtnAreaHeight + gap;

	for (i=labels.length-1; i>=0; --i)
		ScrollComponent(labels[i].label, labels[i].WinTop);
	for (i=paramsEBox.length-1; i>=0; --i)
	{
		ScrollComponent(paramsEBox[i].label, paramsEBox[i].WinTop);
		ScrollComponent(paramsEBox[i].ebox, paramsEBox[i].WinTop);
	}
	for (i=combos.length-1; i>=0; --i)
	{
		ScrollComponent(combos[i].combo, combos[i].WinTop);
		ScrollComponent(combos[i].button, combos[i].WinTop);
	}
	/*ScrollComponent(B1, B1.default.WinTop);
	B1.Caption = t_WindowTitle.ActualHeight()@ActualHeight()@VScroll.WinTop@VScroll.WinHeight;*/
}
//--------------------------------------------------------------------------------------------------
// ресайз будет запрещен. от этого мало толку
function SetPosition( float NewLeft, float NewTop, float NewWidth, float NewHeight, optional bool bForceRelative )
{
	Super.SetPosition(NewLeft, NewTop, NewWidth, NewHeight, bForceRelative);
	ReInitControls();
}
//--------------------------------------------------------------------------------------------------
// если крутится скролл
function PositionChanged(int NewPos)
{
	ScrollPos = NewPos;
	ReInitControls();
}
//--------------------------------------------------------------------------------------------------
function ScrollComponent(GUIComponent L, int WTop)
{
	if (L==none) return;

	L.WinTop = WTop - ScrollPos;

	if (L.WinTop + L.WinHeight > ActualHeight() - ExitBtnAreaHeight - 3 // если ниже допустимого
	 || L.WinTop < t_WindowTitle.ActualHeight()+3) // или выше допустимого
		L.bVisible = false;
	else
		L.bVisible = true;
}
//--------------------------------------------------------------------------------------------------
function int InitCombo(int col, int ncols, int row, int nrows, string Name, optional bool bCBoxOnly)
{
	local int i, idx, w;
	for (i=combos.length; i>=0; --i)
		if (combos[i].Name == Name)
			{idx=i;break;}
	if (i<0)
	{
		idx = combos.Length;
		combos.Insert(idx,1);
	}
	
	combos[idx].Name = Name;
	combos[idx].row  = row;
	
	combos[idx].WinTop = gap + (row-1)*rowH;
	combos[idx].WinTop += t_WindowTitle.ActualHeight()+5;
	
	w = ncols*colW;
	if (!bCBoxOnly)
		w -= eboxW + gap;
		
	
	InitComboBase(combos[idx].combo,
				combos[idx].WinTop,				// TOP
				nrows*rowH,						// Height
				gap + (col-1)*colW,				// Left
				w,		// Width
				TXTA_Left );					// Horizontal text align
	if (!bCBoxOnly)
		InitButtonBase(combos[idx].button,
				combos[idx].WinTop,				// TOP
				nrows*rowH,						// Height
				gap + (col-1)*colW + (ncols*colW) - eboxW,				// Left
				eboxW,		// Width
				TXTA_Left );					// Horizontal text align
	
	return idx;
}
//--------------------------------------------------------------------------------------------------
function InitParam(int col, int ncols, int row, int nrows, string Name, string Cap)
{
	local int i, idx;
	for (i=paramsEBox.length; i>=0; --i)
		if (paramsEBox[i].Name == Name)
			{idx=i;break;}
	if (i<0)
	{
		idx = paramsEBox.Length;
		paramsEBox.Insert(idx,1);
	}
	
	paramsEBox[idx].Name = Name;
	paramsEBox[idx].row	 = row;
	
	paramsEBox[idx].WinTop = gap + (row-1)*rowH;
	paramsEBox[idx].WinTop += t_WindowTitle.ActualHeight()+5;
	
	InitLabelBase(paramsEBox[idx].label,
					Cap,
					paramsEBox[idx].WinTop, 		// Top
					nrows*rowH,						// Height
					gap + (col-1)*colW,				// Left
					ncols*colW - (eboxW + gap),		// Width
					TXTA_Left );					// Horizontal text align

	InitEBoxBase(paramsEBox[idx].ebox,
					paramsEBox[idx].WinTop,						// Top
					nrows*rowH,									// Height
					gap + (col-1)*colW + (ncols*colW) - eboxW,	// Left
					eboxW,										// Width
					TXTA_Center);								// Horizontal text align
}
//--------------------------------------------------------------------------------------------------
function InitLabel(int col, int ncols, int row, int nrows, string Name, eTextAlign A)
{
	local int i,j,idx;
	
	for (i=labels.length-1; i>=0; --i)
		if (labels[i].Name == Name)
			{ idx = i; break; } // если лэйбл с этим name уже существует
	if (i<0)
	{
		j = labels.length;
		labels.insert(j,1);
		idx = j;
	}

	// сохраняем дефолтную позицию для работы скролла
	labels[idx].WinTop = gap + (row-1)*rowH;
	labels[idx].WinTop += t_WindowTitle.ActualHeight()+5;
	
	InitLabelBase(labels[idx].label, 
		Name,
		labels[idx].WinTop, // TOP
		nrows*rowH,			// Height
		gap + (col-1)*colW,	// Left
		ncols*colW,
		A );		// Width
}
//--------------------------------------------------------------------------------------------------
function InitComponentBase(GUIComponent L, int Top, int Height, int Left, int Width)
{
	L.bBoundToParent = true;
	L.bNeverScale = true;
	L.WinTop = Top;
	L.WinHeight = Height;
	L.WinLeft = Left;
	L.WinWidth = Width;
}
//--------------------------------------------------------------------------------------------------
function InitComboBase(out GUIComboBox L, int Top, int Height, int Left, int Width, eTextAlign A)
{
	if (L==none)
		L = GUIComboBox(AddComponent("XInterface.GUIComboBox"));
	InitComponentBase(L,Top,Height,Left,Width);
	/*L.Caption = Caption;
	L.bNeverFocus = true;
	L.VertAlign = TXTA_Center;
	L.TextAlign = A;
	L.TextColor.R=255;
	L.TextColor.G=255;
	L.TextColor.B=255;
	L.TextColor.A=255;
	
	L.FontScale = FNS_Small;
	L.Style = Controller.GetStyle("EditBox", L.FontScale);*/
}
//--------------------------------------------------------------------------------------------------
function InitButtonBase(out GUIButton L, int Top, int Height, int Left, int Width, eTextAlign A)
{
	if (L==none)
		L = GUIButton(AddComponent("XInterface.GUIButton"));
	InitComponentBase(L,Top,Height,Left,Width);
}
//--------------------------------------------------------------------------------------------------
function InitLabelBase(out GUILabel L, string Caption, int Top, int Height, int Left, int Width, eTextAlign A)
{
	if (L==none)
		L = GUILabel(AddComponent("XInterface.GUILabel"));
	InitComponentBase(L,Top,Height,Left,Width);
	L.Caption = Caption;
	L.bNeverFocus = true;
	L.VertAlign = TXTA_Center;
	L.TextAlign = A;
	L.TextColor.R=255;
	L.TextColor.G=255;
	L.TextColor.B=255;
	L.TextColor.A=255;
	
	L.FontScale = FNS_Small;
	L.Style = Controller.GetStyle("EditBox", L.FontScale);
}
//--------------------------------------------------------------------------------------------------
function InitEBoxBase(out GUIEditBox E, int Top, int Height, int Left, int Width, eTextAlign A)
{
	if (E==none)
		E = GUIEditBox(AddComponent("XInterface.GUIEditBox"));
	InitComponentBase(E, Top,Height,Left,Width);
	
	E.FontScale = FNS_Small;
	E.Style = Controller.GetStyle("EditBox", E.FontScale);
	
	//E.TextAlign = A;
}
//--------------------------------------------------------------------------------------------------
/*function InitComponent( GUIController MyController, GUIComponent MyOwner )
{
	log("InitComponent"@ActualHeight()@t_WindowTitle.ActualHeight());
	Super.InitComponent( MyController, MyOwner );
}
//--------------------------------------------------------------------------------------------------
function OnOpen()
{
	log("OnOpen()"@ActualHeight()@t_WindowTitle.ActualHeight());
}*/
//--------------------------------------------------------------------------------------------------
function bool InternalOnKeyEvent( out byte Key, out byte KeyState, float Delta )
{
	local Interactions.EInputKey iKey;

	iKey = EInputKey(Key);
	
	log("InternalOnKeyEvent"@string(Key)@string(iKey));
	
	if ( KeyState == 3 && ikey == IK_MouseWheelUp )   { VScroll.WheelUp();   return true; }
	if ( KeyState == 3 && ikey == IK_MouseWheelDown ) { VScroll.WheelDown(); return true; }
	if ( KeyState != 1 ) return false;
	return false;
}
//--------------------------------------------------------------------------------------------------
/*
var struct GUIParam
{
	var  GUILabel	caption;
	var  GUIEditBox value;
	var  GUIEditBox bonus;
	var  GUIEditBox log;
	var  GUIEditBox stat0;
	var  GUIEditBox stat1;
	var  GUIEditBox stat2;
} Damage0, Damage1, HeadMult0, HeadMult1, FireRate0, FireRate1,
	Capacity0, Capacity1, MagSize, Cost, Weight, ReloadRate, Spread0, Spread1, 
	RecoilX0, RecoilX1, RecoilY0, RecoilY1, InShopLvl;

var GUILabel titValue, titBonus, titLog, titStats, titLvl0, titLvl1, titLvl2;

var GUIEditBox	PerkBox;
var GUIListBox	PerkList;
var GUIButton	PerkBtn;
var GUILabel	PerkLabel;

enum valueType
{
	HEADMULT0,
	HEADMULT1,
	USUAL,
	USUAL_INVERSE,
	NO_STATS,
	FIRERATE0,
	FIRERATE1,
};
enum varType
{
	FLOAT,
	INTEGER,
};
enum EBoxEdit
{
	NO_EDIT,
	CAN_EDIT,
};

var GUIButton bSaveExit, bCancel;
var localized string WinCaption;

var WeaponConfigObject WI;
var StringReplicationInfo RDataGUI;

var float gapU, gapD, gapL, gapR, gapBetweenX, gapBetweenY, gapLabel;
var float ParamLabelWidth, ParamHeight, ParamEditBoxWidth;
var color LabelTextColor;
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
function SetupGUIValues()
{
	local int row;
	local float width;
	t_WindowTitle.SetCaption(WI.WeaponClass);
	
	LabelTextColor.R=255;
	LabelTextColor.G=255;
	LabelTextColor.B=255;
	LabelTextColor.A=255;

	gapL = 30;
	gapU = 30;
	gapLabel = 8.f;
	gapBetweenX = 25.f;
	gapBetweenY = 1.f;
	ParamLabelWidth = 85.0;
	ParamHeight = 30.0;
	ParamEditBoxWidth = 75.f;
	
	titValue = InitLabel(0, 1, "Value");
	titValue.WinTop	+= ParamHeight / 2 ;
	
	titBonus = InitLabel(0, 2, "Bonus");
	titBonus.WinTop += ParamHeight / 2;
	
	titLog	= InitLabel(0, 3, "Log");
	titLog.WinTop += ParamHeight / 2;
	
	titStats = InitLabel(0, 5, "Stats");
	titLvl0 = InitLabel(1, 4, "lvl 0");
	titLvl1 = InitLabel(1, 5, "lvl 1/2");
	titLvl2 = InitLabel(1, 6, "lvl 1");
	
	row=2;
	InitParameter(Damage0,	"Damage0", WI.Damage[0], row++, USUAL, FLOAT);
	InitParameter(Damage1,	"Damage1", WI.Damage[1], row++, USUAL, FLOAT);
	InitParameter(HeadMult0,"HeadMult0", WI.HeadMult[0], row++, HEADMULT0, FLOAT);
	InitParameter(HeadMult1,"HeadMult1", WI.HeadMult[1], row++, HEADMULT1, FLOAT);
	InitParameter(FireRate0,"FireRate0", WI.FireRate[0], row++, FIRERATE0, FLOAT);
	InitParameter(FireRate1,"FireRate1", WI.FireRate[1], row++, FIRERATE1, FLOAT);
	InitParameter(Capacity0,"Capacity0", WI.Capacity[0], row++, USUAL, INTEGER);
	InitParameter(Capacity1,"Capacity1", WI.Capacity[1], row++, USUAL, INTEGER);
	InitParameter(MagSize,	"MagSize", WI.MagSize, row++, USUAL, INTEGER);
	InitParameter(Cost,		"Cost", WI.Cost, row++, USUAL_INVERSE, INTEGER);
	InitParameter(Weight,	"Weight", WI.Weight, row++, USUAL_INVERSE, INTEGER);
	InitParameter(ReloadRate,"ReloadRate", WI.ReloadRate, row++, USUAL, FLOAT);
	InitParameter(Spread0,	"Spread0", WI.Spread[0], row++, USUAL_INVERSE, FLOAT);
	InitParameter(Spread1,	"Spread1", WI.Spread[1], row++, NO_STATS, FLOAT);
	PerkLabel = InitLabel(row-1,5,"Perks");
	InitPerkList(row,4);
	
	RecoilX0.caption	= InitLabel(row,0,"RecoilX0");
	RecoilX0.value		= InitEditBox(row,1,WI.RecoilX[0], INTEGER, CAN_EDIT);
	RecoilY0.caption	= InitLabel(row,2,"RecoilY0");
	RecoilY0.value	= InitEditBox(row,3,WI.RecoilY[0], INTEGER, CAN_EDIT);
	row++;
	RecoilX1.caption	= InitLabel(row,0,"RecoilX1");
	RecoilX1.value		= InitEditBox(row,1,WI.RecoilX[1], INTEGER, CAN_EDIT);
	RecoilY1.caption	= InitLabel(row,2,"RecoilY1");
	RecoilY1.value		= InitEditBox(row,3,WI.RecoilY[1], INTEGER, CAN_EDIT);
	row++;
	InitPerkBtn(row, 6);
	InitPerkBox(row, 4);
	InitParameter(InShopLvl, "InShopLvl", WI.AllowInShopAt, row++, NO_STATS, FLOAT);
	

	width = ParamLabelWidth + gapLabel + 5*gapBetweenX + 6*ParamEditBoxWidth;
	bSaveExit = GUIButton(AddComponent("XInterface.GUIButton"));
	bSaveExit.bBoundToParent=true;
	bSaveExit.bNeverScale = True;
	bSaveExit.bTabStop=false;
	bSaveExit.Caption = "Ok";
	//bSaveExit.FontScale = FNS_Small;
	bSaveExit.WinLeft	= gapL;
	bSaveExit.WinTop	= gapU + row * ParamHeight + row * gapBetweenY + (gapBetweenY*2);
	bSaveExit.WinWidth	= width/2 - gapBetweenX/4;
	bSaveExit.WinHeight = ParamHeight*3 + gapBetweenY*2;
	bSaveExit.OnClick = InternalOnClick;

	bCancel = GUIButton(AddComponent("XInterface.GUIButton"));
	bCancel.bBoundToParent=true;
	bCancel.bNeverScale = True;
	bCancel.bTabStop=false;
	bCancel.Caption = "Cancel";
	//bCancel.FontScale = FNS_Small;
	bCancel.WinLeft	= gapL + width/2 + gapBetweenX/4;
	bCancel.WinTop	= gapU + row * ParamHeight + row * gapBetweenY + (gapBetweenY*2);
	bCancel.WinWidth = width/2 - gapBetweenX/4;
	bCancel.WinHeight = ParamHeight*3 + gapBetweenY*2;
	bCancel.OnClick = InternalOnClick;	

	row+=3;
	
	WinWidth = width + gapL*2;
	WinHeight = gapU + row * ParamHeight + row * gapBetweenY + (gapBetweenY*2) + gapU/2;
	return;
}
//--------------------------------------------------------------------------------------------------
function GUILabel PreInitLabel(string Caption)
{
	local GUILabel L;
	L = GUILabel(AddComponent("XInterface.GUILabel"));
	L.bBoundToParent=true;
	L.bNeverScale = True;
	L.TextColor = LabelTextColor;
	L.Caption = Caption;
	
	L.FontScale = FNS_Small;
	L.Style = Controller.GetStyle("EditBox", FontScale);
	//L.StyleName = "TextLabel";
	
	L.VertAlign=TXTA_Center;
	L.bAcceptsInput=false;
	L.bCaptureMouse=false;
	L.bNeverFocus=true;
	L.bTabStop=false;
		
	return L;
}
//--------------------------------------------------------------------------------------------------
function InitPerkBtn(int row, int col)
{
	local GUIButton L;
	L = GUIButton(AddComponent("XInterface.GUIButton"));
	L.bBoundToParent=true;
	L.bNeverScale = True;
	L.bTabStop=false;
	
	L.FontScale = FNS_Small;
	
	L.WinLeft	= gapL + ParamLabelWidth + gapLabel + (col-1) * gapBetweenX + (col-1)*ParamEditBoxWidth;
	L.WinTop	= gapU + row * ParamHeight + row * gapBetweenY;
	L.WinWidth	= ParamEditBoxWidth;
	L.WinHeight = ParamHeight;
	//L.OnChange	= OnChangePerkBox;
	L.DisableMe();
	PerkBtn = L;
	return;
}
//--------------------------------------------------------------------------------------------------
function bool OnPerkBtnDel(GUIComponent Sender)
{
	
	PerkList.List.Remove(PerkList.List.Index);
/*	for (i=0;i<PerkList.List.SelectedElements.Length; i++)
	{
		PerkBox.TextStr = PerkList.List.SelectedElements[i].Item;
		PerkList.List.RemoveElement(PerkList.List.SelectedElements[i]);
	}*/
	return true;
}
//--------------------------------------------------------------------------------------------------
function bool OnPerkBtnAdd(GUIComponent Sender)
{
	PerkList.List.Add(PerkBox.TextStr);
	OnPerkBoxChange(Sender);
	return true;
}
//--------------------------------------------------------------------------------------------------
function InitPerkList(int row, int col)
{
	local GUIListBox L;
	local int i;
	L = GUIListBox(AddComponent("XInterface.GUIListBox"));
	L.bBoundToParent=true;
	L.bNeverScale = True;
	L.bTabStop=false;
	L.bVisibleWhenEmpty = true;
	L.List.bVisibleWhenEmpty = true;
	

	L.List.FontScale = FNS_Small;
	L.Style = Controller.GetStyle("SmallListBox", FontScale);
	
	
	L.WinLeft	= gapL + ParamLabelWidth + gapLabel + (col-1) * gapBetweenX + (col-1)*ParamEditBoxWidth;
	L.WinTop	= gapU + row * ParamHeight + row * gapBetweenY;
	L.WinWidth	= ParamEditBoxWidth*3 + gapBetweenX*2;
	L.WinHeight = ParamHeight*2 + gapBetweenY*1;
	L.List.TextAlign	= TXTA_Left;
	L.List.OnChange		= OnPerkListChange;
	L.List.OnActivate	= OnPerkListActivate;

	for (i=0;i<WI.BonusFor.Length;i++)
		L.List.Add(string(WI.BonusFor[i].Name));
	
	PerkList = L;
	return;
}
//--------------------------------------------------------------------------------------------------
function OnPerkListActivate()
{
	if (PerkList.List.ItemCount > 0)
	{
		PerkBtn.Caption = "Del";
		PerkBtn.OnClick = OnPerkBtnDel;
	}
}
//--------------------------------------------------------------------------------------------------
function OnPerkListChange(GUIComponent Sender)
{
	if (PerkList==none || PerkList.List == none || PerkBtn == none)
		return;

	if (PerkList.List.Index != -1)
		PerkBtn.EnableMe();
	else
		PerkBtn.DisableMe();
	return;
}
//--------------------------------------------------------------------------------------------------
function InitPerkBox(int row, int col)
{
	local GUIEditBox L;
	L = GUIEditBox(AddComponent("XInterface.GUIEditBox"));
	L.FontScale = FNS_Small;
	L.bBoundToParent=true;
	L.bNeverScale = True;
	L.bTabStop=false;
	
	L.WinLeft	= gapL + ParamLabelWidth + gapLabel + (col-1) * gapBetweenX + (col-1)*ParamEditBoxWidth;
	L.WinTop	= gapU + row * ParamHeight + row * gapBetweenY;
	L.WinWidth	= ParamEditBoxWidth*2 + gapBetweenX;
	L.WinHeight = ParamHeight;
	L.OnActivate = OnPerkBoxActivate;
	L.OnChange	= OnPerkBoxChange;
	L.TextStr = string(KFPlayerReplicationInfo(PlayerOwner().PlayerReplicationInfo).ClientVeteranSkill.Name);
	OnPerkBoxChange(L);
	PerkBox = L;
	return;
}
//--------------------------------------------------------------------------------------------------
function OnPerkBoxActivate()
{
	PerkBtn.OnClick = OnPerkBtnAdd;
	OnPerkBoxChange(PerkBox);

}
//--------------------------------------------------------------------------------------------------
function OnPerkBoxChange(GUIComponent Sender)
{
	local class<KFVeterancyTypes> vet;
	local int n;
	local string pkg;
	
	if (PerkBtn==none)
		return;
	
	pkg = string(KFPlayerReplicationInfo(PlayerOwner().PlayerReplicationInfo).ClientVeteranSkill);
	n = InStr(pkg,".");
	pkg = Left(pkg,n);
	vet = class<KFVeterancyTypes>(DynamicLoadObject(pkg$"."$PerkBox.TextStr, Class'Class'));
	if (vet!=none && PerkList.List.FindIndex(string(vet.name))== -1 )
	{
		PerkBtn.Caption = "Add";
		PerkBtn.EnableMe();
	}
	else
	{
		PerkBtn.Caption = "Add";
		PerkBtn.DisableMe();
	}
	return;
}
//--------------------------------------------------------------------------------------------------
function GUILabel InitLabel(int row, int col, string Caption)
{
	local GUILabel L;
	L = PreInitLabel(Caption);
	if (col==0)
	{
		L.WinWidth	= ParamLabelWidth;
		L.WinLeft	= gapL;
	}
	if (col>0)
	{
		L.TextAlign = TXTA_Center;
		L.WinLeft	= gapL + ParamLabelWidth + gapLabel + (col-1) * ParamEditBoxWidth + (col-1) * gapBetweenX;
		L.WinWidth	= ParamEditBoxWidth;
	}
	L.WinTop	= gapU + row * ParamHeight + row * gapBetweenY ;
	
	L.WinHeight = ParamHeight;
	return L;
}
//--------------------------------------------------------------------------------------------------
function OnChange(GUIComponent Sender)
{
	local int row;
	local bool bOnlyCalcStats;
	bOnlyCalcStats = true;

	ReadInfo();
	
	InitParameter(Damage0, "Damage0", WI.Damage[0], row++, USUAL, FLOAT,bOnlyCalcStats);
	InitParameter(Damage1, "Damage1", WI.Damage[1], row++, USUAL, FLOAT,bOnlyCalcStats);
	InitParameter(HeadMult0, "HeadMult0", WI.HeadMult[0], row++, HEADMULT0, FLOAT,bOnlyCalcStats);
	InitParameter(HeadMult1, "HeadMult1", WI.HeadMult[1], row++, HEADMULT1, FLOAT,bOnlyCalcStats);
	InitParameter(FireRate0, "FireRate0", WI.FireRate[0], row++, FIRERATE0, FLOAT,bOnlyCalcStats);
	InitParameter(FireRate1, "FireRate1", WI.FireRate[1], row++, FIRERATE1, FLOAT,bOnlyCalcStats);
	InitParameter(Capacity0, "Capacity0", WI.Capacity[0], row++, USUAL, INTEGER,bOnlyCalcStats);
	InitParameter(Capacity1, "Capacity1", WI.Capacity[1], row++, USUAL, INTEGER,bOnlyCalcStats);
	InitParameter(MagSize, "MagSize", WI.MagSize, row++, USUAL, INTEGER,bOnlyCalcStats);
	InitParameter(Cost, "Cost", WI.Cost, row++, USUAL_INVERSE, INTEGER,bOnlyCalcStats);
	InitParameter(Weight, "Weight", WI.Weight, row++, USUAL_INVERSE, INTEGER,bOnlyCalcStats);
	InitParameter(Spread0, "Spread0", WI.Spread[0], row++, USUAL_INVERSE, FLOAT,bOnlyCalcStats);
	InitParameter(Spread1, "Spread1", WI.Spread[1], row++, NO_STATS, FLOAT,bOnlyCalcStats);
	InitParameter(ReloadRate, "ReloadRate", WI.ReloadRate, row++, USUAL, FLOAT,bOnlyCalcStats);
	InitParameter(InShopLvl, "InShopLvl", WI.AllowInShopAt, row++, NO_STATS, FLOAT,bOnlyCalcStats);
}
//--------------------------------------------------------------------------------------------------
function GUIEditBox InitEditBox(int row, int col, float val, optional varType varType, optional EBoxEdit Edit)
{
	local GUIEditBox L;
	L = GUIEditBox(AddComponent("XInterface.GUIEditBox"));
	L.bBoundToParent=true;
	L.bNeverScale = True;
	L.bTabStop=false;
	
	L.FontScale = FNS_Small;
	
	L.WinLeft	= gapL + ParamLabelWidth + gapLabel + (col-1) * gapBetweenX + (col-1)*ParamEditBoxWidth;
	L.WinTop	= gapU + row * ParamHeight + row * gapBetweenY;
	L.WinWidth	= ParamEditBoxWidth;
	L.WinHeight = ParamHeight;
	if (varType == INTEGER)
	{
		L.TextStr	= string(int(val));
		L.bIntOnly = true;
	}
	else
		L.TextStr	= string(val);
	if (Edit == NO_EDIT)
	{
		L.bAcceptsInput=false;
		L.bCaptureMouse=false;
		L.bNeverFocus=true;
		L.bTabStop=false;
		L.bReadOnly=true;
	}
	else
		L.OnChange = OnChange;
		
	return L;
}
//--------------------------------------------------------------------------------------------------
/*function InitComponent(GUIController MyController, GUIComponent MyOwner)
{
	Super.InitComponent(MyController, MyOwner);
}*/
//--------------------------------------------------------------------------------------------------
//InitParameter(Damage0, "Damage0", WI.Damage[0]);
function InitParameter(out GUIParam GP, string Cap, WeaponConfigObject.Param P, int row, valueType vType, varType varType, optional bool bOnlyCalcStats)
{
	local int i;
	local float f,f2;
	local float fl[3];
	if (bOnlyCalcStats==false)
	{
		GP.caption	= InitLabel(row,0,Cap);
		GP.value	= InitEditBox(row,1,P.value, varType, CAN_EDIT);
		GP.bonus	= InitEditBox(row,2,P.BonusMax,,CAN_EDIT);
		GP.log		= InitEditBox(row,3,P.BonusLog,,CAN_EDIT);
	}
	if (vType == NO_STATS)
		return;
	else if (vType==USUAL_INVERSE)
	{
		for (i=0;i<3;i++)
		{
			fl[i] = class'WeaponConfig'.static.GetCoeff(P, i*0.5f, true);
			fl[i] *= P.value;
		}
	}
	else if (vType==USUAL)
	{
		for (i=0;i<3;i++)
		{
			fl[i] = class'WeaponConfig'.static.GetCoeff(P, i*0.5f);
			fl[i] *= P.value;
		}
	}
	else if (vType==HEADMULT0)
	{
		for (i = 0; i<3; i++)
		{
			f = class'WeaponConfig'.static.GetCoeff(WI.Damage[0], i*0.5f);
			f *= WI.Damage[0].value;
			f2 = class'WeaponConfig'.static.GetCoeff(WI.HeadMult[0], i*0.5f);
			f2 *= WI.HeadMult[0].value;
			f *= f2;
			fl[i] = f;
		}
	}
	else if (vType==HEADMULT1)
	{
		for (i = 0; i<3; i++)
		{
			f = class'WeaponConfig'.static.GetCoeff(WI.Damage[1], i*0.5f);
			f *= WI.Damage[1].value;
			f2 = class'WeaponConfig'.static.GetCoeff(WI.HeadMult[1], i*0.5f);
			f2 *= WI.HeadMult[1].value;
			f *= f2;
			fl[i] = f;
		}
	}
	else if (vType==FIRERATE0)
	{
		for (i = 0; i<3; i++)
		{
			f = class'WeaponConfig'.static.GetCoeff(WI.FireRate[0], i*0.5f);
			f = WI.FireRate[0].value / f;
			fl[i] = f;
		}
	}
	else if (vType==FIRERATE1)
	{
		for (i = 0; i<3; i++)
		{
			f = class'WeaponConfig'.static.GetCoeff(WI.FireRate[1], i*0.5f);
			f = WI.FireRate[1].value / f;
			fl[i] = f;
		}		
	}
	for (i=0;i<3;i++)
	{
		if (bOnlyCalcStats)
		{
			if (i==0) GP.stat0.SetText(string(fl[i]));
			if (i==1) GP.stat1.SetText(string(fl[i]));
			if (i==2) GP.stat2.SetText(string(fl[i]));
		}
		else
		{
			if (i==0) GP.stat0	= InitEditBox(row,4+i, fl[i],,NO_EDIT);
			if (i==1) GP.stat1	= InitEditBox(row,4+i, fl[i],,NO_EDIT);
			if (i==2) GP.stat2	= InitEditBox(row,4+i, fl[i],,NO_EDIT);
		}
	}
	//static function float GetCoeff(WeaponConfigObject.Param P, float lvlmult, optional bool bInverseCoeff)
}
//--------------------------------------------------------------------------------------------------
function OnOpen()
{
	Super.OnOpen();
}
//--------------------------------------------------------------------------------------------------
/*function WriteParameter(GUIParam GP, out WeaponConfigObject.Param P)
{
	P.value		= float(GP.value.TextStr);
	P.BonusMax	= float(GP.bonus.TextStr);
	P.BonusLog	= float(GP.log.TextStr);
}
//--------------------------------------------------------------------------------------------------
function WriteInfo()
{
	WriteParameter(Damage0, WI.Damage[0]);
	WriteParameter(Damage1, WI.Damage[1]);
	WriteParameter(HeadMult0, WI.HeadMult[0]);
	WriteParameter(HeadMult1, WI.HeadMult[1]);
	WriteParameter(FireRate0, WI.FireRate[0]);
	WriteParameter(FireRate1, WI.FireRate[1]);
	WriteParameter(Capacity0, WI.Capacity[0]);
	WriteParameter(Capacity1, WI.Capacity[1]);
	WriteParameter(MagSize, WI.MagSize);
	WriteParameter(Cost, WI.Cost);
	WriteParameter(Weight, WI.Weight);
	WriteParameter(Recoil0, WI.Recoil[0]);
	WriteParameter(Recoil1, WI.Recoil[1]);
	WriteParameter(InShopLvl, WI.AllowInShopAt);
}*/
//--------------------------------------------------------------------------------------------------
function ReadParameter(GUIParam GP, out WeaponConfigObject.Param P)
{
	P.value		= float(GP.value.TextStr);
	P.BonusMax	= float(GP.bonus.TextStr);
	P.BonusLog	= float(GP.log.TextStr);
}
//--------------------------------------------------------------------------------------------------
function ReadInfo()
{
	local int i;
	local string vet, pkg;
	local class<KFVeterancyTypes> v;
	
	ReadParameter(Damage0, WI.Damage[0]);
	ReadParameter(Damage1, WI.Damage[1]);
	ReadParameter(HeadMult0, WI.HeadMult[0]);
	ReadParameter(HeadMult1, WI.HeadMult[1]);
	ReadParameter(FireRate0, WI.FireRate[0]);
	ReadParameter(FireRate1, WI.FireRate[1]);
	ReadParameter(Capacity0, WI.Capacity[0]);
	ReadParameter(Capacity1, WI.Capacity[1]);
	ReadParameter(MagSize, WI.MagSize);
	ReadParameter(Cost, WI.Cost);
	ReadParameter(Weight, WI.Weight);
	ReadParameter(Spread0, WI.Spread[0]);
	ReadParameter(Spread1, WI.Spread[1]);
	ReadParameter(ReloadRate, WI.ReloadRate);
	ReadParameter(InShopLvl, WI.AllowInShopAt);
	WI.RecoilX[0] = int(RecoilX0.value.TextStr);
	WI.RecoilY[0] = int(RecoilY0.value.TextStr);
	WI.RecoilX[1] = int(RecoilX1.value.TextStr);
	WI.RecoilY[1] = int(RecoilY1.value.TextStr);
	WI.BonusFor.Remove(0,WI.BonusFor.Length);
	pkg = string(KFPlayerReplicationInfo(PlayerOwner().PlayerReplicationInfo).ClientVeteranSkill);
	pkg = Left(pkg,InStr(pkg,"."));
	for (i=0; i<PerkList.List.ItemCount;i++)
	{
		vet = PerkList.List.Elements[i].Item;
		//PerkList.List.GetAtIndex(i,vet);
		v = class<KFVeterancyTypes>(DynamicLoadObject(pkg$"."$vet, Class'Class'));
		if (v!=none)
			WI.BonusFor[WI.BonusFor.Length] = v;
	}
}
//--------------------------------------------------------------------------------------------------
function SaveData()
{
	local array<string> S;
	local string tStr;
	local int i,mLen, fLen;
	mLen = 200;
	ReadInfo();
	// Отправляем новые настройки через консоль mutate (а мутатор должен их поймать)
	tStr = WI.Serialize();
	fLen = Len(tStr);
	while (Len(tStr)>0)
	{
		if (Len(tStr)>mLen)
		{
			S[S.Length] = Left(tStr,mLen);
			tStr = Right(tStr, Len(tStr)-mLen);
		}
		else
		{
			S[S.Length] = tStr;
			tStr="";
			break;
		}
	}
	RDataGUI.revision++;
	for (i=0;i<S.Length;i++)
		RDataGUI.SetStringClient(S[i], i, S.Length, fLen);
}
//--------------------------------------------------------------------------------------------------
/*function OnClose(optional Bool bCancelled)
{
	Super.OnClose(bCancelled);
}*/
//--------------------------------------------------------------------------------------------------
function bool InternalOnClick(GUIComponent Sender)
{
	local PlayerController PC;
	PC = PlayerOwner();
	
	switch (GUIButton(Sender))
	{
		case bSaveExit:
			SaveData();
			PC.ClientCloseMenu(True,False); //CloseAll(false,true);
			break;
		case bCancel:
			PC.ClientCloseMenu(True,False); //CloseAll(false,true);
			break;
	}
    return false;
}
*/
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
defaultproperties
{
	/*Begin Object Class=GUIButton Name=obSaveExit
      Caption="Ok"
      OnClick=InternalOnClick
      TabOrder=2
      bBoundToParent=true
      bScaleToParent=false
		WinWidth=0.298585
		WinHeight=0.100143
		WinLeft=0.036077
		WinTop=0.872991
	End Object
	bSaveExit=obSaveExit

	Begin Object Class=GUIButton Name=obCancel
      Caption="Cancel"
      OnClick=InternalOnClick
      TabOrder=1
      bBoundToParent=true
      bScaleToParent=false
		WinWidth=0.298585
		WinHeight=0.100143
		WinLeft=0.505391
		WinTop=0.872991
	End Object
	bCancel=obCancel
	*/
	
	WindowName="Monster Config"
	bResizeWidthAllowed=true
	bResizeHeightAllowed=true
	bMoveAllowed=true
	DefaultLeft=100
	DefaultTop=100
	DefaultWidth=724
	DefaultHeight=645
	bRequire640x480=False

	//OnOpen = OnOpen

	//bNeverScale = true
	//bScaleToParent = false
	WinWidth=0.670293
	WinHeight=0.569336
	WinLeft=0.146113
	WinTop=0.185547

	bAllowedAsLast=True // If this is true, closing this page will not bring up the main menu if last on the stack.	
	bPersistent=False // If set in defprops, page is kept in memory across open/close/reopen
	bRestorable=False // When the GUIController receives a call to CloseAll(), should it reopen this page the next time main is opened?
}
