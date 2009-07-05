{
 * Copyright © Kemka Andrey aka Andru
 * mail: dr.andru@gmail.com
 * site: http://andru-kun.inf.ua
 *
 * This file is part of ZenGL
 *
 * ZenGL is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; either version 2.1 of
 * the License, or (at your option) any later version.
 *
 * ZenGL is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
}
unit zgl_mouse;

{$I zgl_config.cfg}

interface
uses
  Windows;

const
  M_BLEFT  = 0;
  M_BMIDLE = 1;
  M_BRIGHT = 2;
  M_WUP    = 0;
  M_WDOWN  = 1;

function mouse_X : Integer;
function mouse_Y : Integer;
function mouse_DX : Integer;
function mouse_DY : Integer;
function mouse_Down( const Button : Byte ) : Boolean;
function mouse_Up( const Button : Byte ) : Boolean;
function mouse_Click( const Button : Byte ) : Boolean;
function mouse_Wheel( const Axis : Byte ) : Boolean;
procedure mouse_ClearState;
procedure mouse_Lock;

var
  mouseX        : Integer;
  mouseY        : Integer;
  mouseDown     : array[ 0..2 ] of Boolean;
  mouseUp       : array[ 0..2 ] of Boolean;
  mouseClick    : array[ 0..2 ] of Boolean;
  mouseCanClick : array[ 0..2 ] of Boolean;
  mouseWheel    : array[ 0..1 ] of Boolean;
  mouseLock     : Boolean;
  cursorpos     : TPoint;

implementation
uses
  zgl_window,
  zgl_screen;

function mouse_X;
begin
  GetCursorPos( cursorpos );
  if wnd_FullScreen Then
    Result := cursorpos.X
  else
    Result := cursorpos.X - wnd_X - wnd_BrdSizeX;
  Result := Round( ( Result - scr_AddCX ) / scr_ResCX );
end;

function mouse_Y;
begin
  GetCursorPos( cursorpos );
  if wnd_FullScreen Then
    Result := cursorpos.Y
  else
    Result := cursorpos.Y - wnd_Y - wnd_BrdSizeY - wnd_CpnSize;
  Result := Round( ( Result - scr_AddCY ) / scr_ResCY );
end;

function mouse_DX;
begin
  Result := mouse_X() - wnd_Width div 2;
end;

function mouse_DY;
begin
  Result := mouse_Y() - wnd_Height div 2;
end;

function mouse_Down;
begin
  Result := mouseDown[ Button ];
end;

function mouse_Up;
begin
  Result := mouseUp[ Button ];
end;

function mouse_Click;
begin
  Result := mouseClick[ Button ];
end;

function mouse_Wheel;
begin
  Result := mouseWheel[ Axis ];
end;

procedure mouse_ClearState;
begin
  mouseUp[ M_BLEFT  ] := FALSE;
  mouseUp[ M_BMIDLE ] := FALSE;
  mouseUp[ M_BRIGHT ] := FALSE;

  mouseClick[ M_BLEFT  ] := FALSE;
  mouseClick[ M_BMIDLE ] := FALSE;
  mouseClick[ M_BRIGHT ] := FALSE;

  mouseCanClick[ M_BLEFT  ] := TRUE;
  mouseCanClick[ M_BMIDLE ] := TRUE;
  mouseCanClick[ M_BRIGHT ] := TRUE;

  mouseWheel[ M_WUP   ] := FALSE;
  mouseWheel[ M_WDOWN ] := FALSE;
end;

procedure mouse_Lock;
begin
  SetCursorPos( wnd_X + wnd_BrdSizeX + wnd_Width div 2, wnd_Y + wnd_BrdSizeY + wnd_CpnSize + wnd_Height div 2 );
end;

end.
