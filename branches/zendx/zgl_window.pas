{
 *  Copyright © Kemka Andrey aka Andru
 *  mail: dr.andru@gmail.com
 *  site: http://andru-kun.inf.ua
 *
 *  This file is part of ZenGL.
 *
 *  ZenGL is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as
 *  published by the Free Software Foundation, either version 3 of
 *  the License, or (at your option) any later version.
 *
 *  ZenGL is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with ZenGL. If not, see http://www.gnu.org/licenses/
}
unit zgl_window;

{$I zgl_config.cfg}

interface
uses
  Windows,
  zgl_direct3d,
  zgl_direct3d_all;

function  wnd_Create( Width, Height : Integer ) : Boolean;
procedure wnd_Destroy;
procedure wnd_Update;

procedure wnd_SetCaption( const NewCaption : String );
procedure wnd_SetSize( Width, Height : Integer );
procedure wnd_SetPos( X, Y : Integer );
procedure wnd_ShowCursor( Show : Boolean );
procedure wnd_Select;

var
  wnd_X          : Integer;
  wnd_Y          : Integer;
  wnd_Width      : Integer = 800;
  wnd_Height     : Integer = 600;
  wnd_FullScreen : Boolean;
  wnd_Caption    : String;

  wnd_Handle    : HWND;
  wnd_DC        : HDC;
  wnd_INST      : HINST;
  wnd_Class     : TWndClassExW;
  wnd_ClassName : PWideChar = 'ZenGL';
  wnd_Style     : LongWord;
  wnd_CpnSize   : Integer;
  wnd_BrdSizeX  : Integer;
  wnd_BrdSizeY  : Integer;
  wnd_CaptionW  : PWideChar;

implementation
uses
  zgl_main,
  zgl_application,
  zgl_screen,
  zgl_utils;

{$IFNDEF FPC}
// Various versions of Delphi... sucks again
function LoadCursorW(hInstance: HINST; lpCursorName: PWideChar): HCURSOR; stdcall; external user32 name 'LoadCursorW';
{$ENDIF}

function wnd_Create( Width, Height : Integer ) : Boolean;
begin
  Result     := FALSE;
  wnd_Width  := Width;
  wnd_Height := Height;

  if app_Flags and WND_USE_AUTOCENTER > 0 Then
    begin
      wnd_X := ( zgl_Get( DESKTOP_WIDTH ) - wnd_Width ) div 2;
      wnd_Y := ( zgl_Get( DESKTOP_HEIGHT ) - wnd_Height ) div 2;
    end;

  wnd_CpnSize  := GetSystemMetrics( SM_CYCAPTION  );
  wnd_BrdSizeX := GetSystemMetrics( SM_CXDLGFRAME );
  wnd_BrdSizeY := GetSystemMetrics( SM_CYDLGFRAME );

  with wnd_Class do
    begin
      cbSize        := SizeOf( TWndClassExW );
      style         := CS_DBLCLKS or CS_OWNDC;
      lpfnWndProc   := @app_ProcessMessages;
      cbClsExtra    := 0;
      cbWndExtra    := 0;
      hInstance     := wnd_INST;
      hIcon         := LoadIconW  ( wnd_INST, 'MAINICON' );
      hIconSm       := LoadIconW  ( wnd_INST, 'MAINICON' );
      hCursor       := LoadCursorW( wnd_INST, PWideChar( IDC_ARROW ) );
      lpszMenuName  := nil;
      hbrBackGround := GetStockObject( BLACK_BRUSH );
      lpszClassName := wnd_ClassName;
    end;

  if RegisterClassExW( wnd_Class ) = 0 Then
    begin
      u_Error( 'Cannot register window class' );
      exit;
    end;

  if wnd_FullScreen Then
    begin
      wnd_X     := 0;
      wnd_Y     := 0;
      wnd_Style := WS_POPUP or WS_VISIBLE or WS_SYSMENU;
    end else
      wnd_Style := WS_CAPTION or WS_MINIMIZEBOX or WS_SYSMENU or WS_VISIBLE;
  wnd_Handle := CreateWindowExW( WS_EX_APPWINDOW or WS_EX_TOPMOST * Byte( wnd_FullScreen ), wnd_ClassName, wnd_CaptionW, wnd_Style, wnd_X, wnd_Y,
                                 wnd_Width  + ( wnd_BrdSizeX * 2 ) * Byte( not wnd_FullScreen ),
                                 wnd_Height + ( wnd_BrdSizeY * 2 + wnd_CpnSize ) * Byte( not wnd_FullScreen ), 0, 0, wnd_INST, nil );

  if wnd_Handle = 0 Then
    begin
      u_Error( 'Cannot create window' );
      exit;
    end;

  wnd_DC := GetDC( wnd_Handle );
  if wnd_DC = 0 Then
    begin
      u_Error( 'Cannot get device context' );
      exit;
    end;
  wnd_Select;

  Result := TRUE;
end;

procedure wnd_Destroy;
begin
  if ( wnd_DC > 0 ) and ( ReleaseDC( wnd_Handle, wnd_DC ) = 0 ) Then
    begin
      u_Error( 'Cannot release device context' );
      wnd_DC := 0;
    end;

  if ( wnd_Handle <> 0 ) and ( not DestroyWindow( wnd_Handle ) ) Then
    begin
      u_Error( 'Cannot destroy window' );
      wnd_Handle := 0;
    end;

  if not UnRegisterClassW( wnd_ClassName, wnd_INST ) Then
    begin
      u_Error( 'Cannot unregister window class' );
      wnd_INST := 0;
    end;
end;

procedure wnd_Update;
  var
    FullScreen : Boolean;
begin
  if app_Focus Then
    FullScreen := wnd_FullScreen
  else
    FullScreen := FALSE;

  if FullScreen Then
    wnd_Style := WS_POPUP or WS_VISIBLE or WS_SYSMENU
  else
    wnd_Style := WS_CAPTION or WS_MINIMIZEBOX or WS_SYSMENU or WS_VISIBLE;

  SetWindowLongW( wnd_Handle, GWL_STYLE, wnd_Style );
  SetWindowLongW( wnd_Handle, GWL_EXSTYLE, WS_EX_APPWINDOW or WS_EX_TOPMOST * Byte( FullScreen ) );

  app_Work := TRUE;
  wnd_SetCaption( wnd_Caption );
  wnd_SetSize( wnd_Width, wnd_Height );

  if app_Flags and WND_USE_AUTOCENTER > 0 Then
    wnd_SetPos( ( zgl_Get( DESKTOP_WIDTH ) - wnd_Width ) div 2, ( zgl_Get( DESKTOP_HEIGHT ) - wnd_Height ) div 2 );
end;

procedure wnd_SetCaption( const NewCaption : String );
  var
    i,len : Integer;
begin
  wnd_Caption := NewCaption + #0;

  {$IFNDEF FPC}
  if SizeOf( Char ) = 2 Then
    begin
      len := 2;
      wnd_CaptionW := PWideChar( wnd_Caption );
    end else
  {$ENDIF}
  len := 1;
  if len = 1 Then
    begin
      if app_Flags and APP_USE_UTF8 = 0 Then
        wnd_Caption := AnsiToUtf8( wnd_Caption );
      len := MultiByteToWideChar( CP_UTF8, 0, @wnd_Caption[ 1 ], length( wnd_Caption ), nil, 0 );
      if Assigned( wnd_CaptionW ) Then
        FreeMem( wnd_CaptionW );
      GetMem( wnd_CaptionW, len * 2 + 2 );
      wnd_CaptionW[ len ] := #0;
      MultiByteToWideChar( CP_UTF8, 0, @wnd_Caption[ 1 ], length( wnd_Caption ), wnd_CaptionW, len );
      if app_Flags and APP_USE_UTF8 = 0 Then
        wnd_Caption := wnd_CaptionW;
    end;

  if wnd_Handle <> 0 Then
    SetWindowTextW( wnd_Handle, wnd_CaptionW );
end;

procedure wnd_SetSize( Width, Height : Integer );
begin
  wnd_Width  := Width;
  wnd_Height := Height;

  if not app_InitToHandle Then
    wnd_SetPos( wnd_X, wnd_Y );

  d3d_Restore();

  ogl_Width  := Width;
  ogl_Height := Height;
  if app_Flags and CORRECT_RESOLUTION > 0 Then
    scr_CorrectResolution( scr_ResW, scr_ResH )
  else
    SetCurrentMode();
end;

procedure wnd_SetPos( X, Y : Integer );
begin
  wnd_X := X;
  wnd_Y := Y;

  if wnd_Handle <> 0 Then
    if ( not wnd_FullScreen ) or ( not app_Focus ) Then
      SetWindowPos( wnd_Handle, HWND_NOTOPMOST, wnd_X, wnd_Y, wnd_Width + ( wnd_BrdSizeX * 2 ), wnd_Height + ( wnd_BrdSizeY * 2 + wnd_CpnSize ), SWP_NOACTIVATE )
    else
      SetWindowPos( wnd_Handle, HWND_TOPMOST, 0, 0, wnd_Width, wnd_Height, SWP_NOACTIVATE );
end;

procedure wnd_ShowCursor( Show : Boolean );
begin
  app_ShowCursor := Show;
end;

procedure wnd_Select;
begin
  BringWindowToTop( wnd_Handle );
end;

initialization
  wnd_Caption := cs_ZenGL;

end.
