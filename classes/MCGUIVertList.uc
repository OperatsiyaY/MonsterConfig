/*
	
*/
//--------------------------------------------------------------------------------------------------
class MCGUIVertList extends GUIVertList;

var Material InfoBackground;
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
function DrawStat(Canvas Canvas, int CurIndex, float X, float Y, float Width, float Height, bool bSelected, bool bPending)
{
	local float TempX, TempY;
	local float TempWidth, TempHeight;

	// Offset for the Background
	TempX = X;
	TempY = Y;

	// Initialize the Canvas
	Canvas.Style = 1;
	Canvas.Font = class'ROHUD'.Static.GetSmallMenuFont(Canvas);
	Canvas.SetDrawColor(255, 255, 255, 255);

	// Draw Item Background
	Canvas.SetPos(TempX, TempY);
	Canvas.DrawTileStretched(InfoBackground, Width, Height);

	// Select Text Color
	Canvas.SetDrawColor(0, 0, 0, 255);

	// Draw progress type.
	Canvas.TextSize("test",TempWidth,TempHeight);
	TempX += Width*0.1f;
	TempY += (Height-TempHeight)*0.5f;
	Canvas.SetPos(TempX, TempY);
	Canvas.DrawText("test"$":");

	// Draw current progress.
	Canvas.TextSize("test2",TempWidth,TempHeight);
	Canvas.SetPos(X + Width*0.88f - TempWidth, TempY);
	Canvas.DrawText("test2");
}
//--------------------------------------------------------------------------------------------------
function bool PreDraw(Canvas Canvas)
{
	return false;
}
//--------------------------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
defaultproperties
{
	OnDrawItem=DrawStat
	OnPreDraw=PreDraw

	InfoBackground=Texture'KF_InterfaceArt_tex.Menu.Item_box_bar'

	FontScale=FNS_Medium
	//GetItemHeight=PerkHeight
}