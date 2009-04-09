{
 * Copyright © Kemka Andrey aka Andru
 * mail: dr.andru@gmail.com
 * site: http://andru-kun.ru
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
unit zgl_gui_render;

{$I zgl_config.cfg}

interface
uses
  zgl_gui_types;

const
  COLOR_WINDOW = $646866;
  COLOR_WIDGET = $424644;
  COLOR_LIGHT  = $BBBBBB;
  COLOR_DARK   = $202422;
  COLOR_EDIT   = $36342E;
  COLOR_SELECT = $DBB095;

  SCROLL_SIZE  = 16;

procedure gui_DrawWidget( const Widget : zglPWidget );

procedure gui_DrawButton     ( const Widget : zglPWidget );
procedure gui_DrawCheckBox   ( const Widget : zglPWidget );
procedure gui_DrawRadioButton( const Widget : zglPWidget );
procedure gui_DrawLabel      ( const Widget : zglPWidget );
procedure gui_DrawEditBox    ( const Widget : zglPWidget );
procedure gui_DrawListBox    ( const Widget : zglPWidget );
procedure gui_DrawGroupBox   ( const Widget : zglPWidget );
procedure gui_DrawSpin       ( const Widget : zglPWidget );
procedure gui_DrawScrollBar  ( const Widget : zglPWidget );

implementation
uses
  zgl_types,
  zgl_opengl_all,
  zgl_opengl_simple,
  zgl_mouse,
  zgl_primitives_2d,
  zgl_text,
  zgl_gui_main,
  zgl_gui_utils,
  zgl_math_2d,
  zgl_collision_2d;

procedure _button_draw( const x, y, w, h : Single; const pressed : Boolean );
  var
    color : DWORD;
begin
  color := COLOR_WIDGET;
  pr2d_Rect( x, y, w, h, color, 255, PR2D_FILL );
  pr2d_Rect( x, y, w, h, $000000, 255, 0 );

  color := COLOR_LIGHT;
  if pressed Then color := COLOR_DARK;
  pr2d_Line( x + 1, y + 1, x + w - 1, y + 1, color, 255, 0 );
  pr2d_Line( x + 1, y + 1, x + 1, y + h - 1, color, 255, 0 );
  color := COLOR_DARK;
  if pressed Then color := COLOR_LIGHT;
  pr2d_Line( x + 1, y + h - 2, x + w - 1, y + h - 2, color, 255, 0 );
  pr2d_Line( x + w - 2, y + 1, x + w - 2, y + h, color, 255, 0 );
  if pressed Then
    pr2d_Rect( X, Y, W, H, COLOR_SELECT, 25, PR2D_FILL );
end;

procedure _scrolls_draw( const X1, Y1, X2, Y2, Size : Single; const Vertical, UPressed, DPressed : Boolean );
begin
  _button_draw( X1, Y1, Size, Size, UPressed );
  glColor4f( 0, 0, 0, 1 );
  if Vertical Then
    begin
      glBegin( GL_TRIANGLES );
        gl_Vertex2f( X1 + Size / 2 + Byte( UPressed ), Y1 + 2 + Byte( UPressed ) );
        gl_Vertex2f( X1 + Size - 2 + Byte( UPressed ), Y1 + Size - 2 + Byte( UPressed ) );
        gl_Vertex2f( X1 + 2 + Byte( UPressed ),        Y1 + Size - 2 + Byte( UPressed ) );
      glEnd;
    end else
      begin
        glBegin( GL_TRIANGLES );
          gl_Vertex2f( X1 + 2 + Byte( UPressed ),        Y1 + Size / 2 + Byte( UPressed ) );
          gl_Vertex2f( X1 + Size - 2 + Byte( UPressed ), Y1 + 2 + Byte( UPressed )        );
          gl_Vertex2f( X1 + Size - 2 + Byte( UPressed ), Y1 + Size - 2 + Byte( UPressed ) );
        glEnd;
      end;

  _button_draw( X2, Y2, Size, Size, DPressed );
  glColor4f( 0, 0, 0, 1 );
  if Vertical Then
    begin
      glBegin( GL_TRIANGLES );
        gl_Vertex2f( X2 + 2 + Byte( DPressed ),        Y2 + 2 + Byte( DPressed ) );
        gl_Vertex2f( X2 + Size - 2 + Byte( DPressed ), Y2 + 2 + Byte( DPressed ) );
        gl_Vertex2f( X2 + Size / 2 + Byte( DPressed ), Y2 + Size - 2 + Byte( DPressed ) );
      glEnd;
    end else
      begin
        glBegin( GL_TRIANGLES );
          gl_Vertex2f( X2 + 2 + Byte( DPressed ),        Y2 + 2 + Byte( DPressed ) );
          gl_Vertex2f( X2 + Size - 2 + Byte( DPressed ), Y2 + Size / 2 + Byte( DPressed ) );
          gl_Vertex2f( X2 + 2 + Byte( DPressed ),        Y2 + Size - 2 + Byte( DPressed ) );
        glEnd;
      end;
end;

procedure gui_DrawWidget;
  var
    w : zglPWidget;
begin
  if not Assigned( Widget ) Then exit;

  if Assigned( Widget.OnDraw ) Then Widget.OnDraw( Widget );
  if Assigned( Widget.child ) Then
    begin
      w := Widget.child;
      repeat
        _clip( w.parent );
        w := w.Next;
        gui_DrawWidget( w );
        scissor_End;
      until not Assigned( w.Next );
    end;
end;

procedure gui_DrawButton;
begin
  with zglTButtonDesc( Widget.desc^ ), Widget.rect do
    begin
      _button_draw( X, Y, W, H, Pressed );

      if Widget.focus Then
        pr2d_Rect( X - 1, Y - 1, W + 2, H + 2, COLOR_SELECT, 155 );

      _clip( Widget, X + 2, Y + 2, W - 4, H - 4 );
      text_Draw( Font, Round( X + ( W - text_GetWidth( Font, Caption ) ) / 2 ) + Byte( Pressed ),
                       Round( Y + ( H - Font.MaxHeight ) / 2 ) + Byte( Pressed ), Caption );
      scissor_End;
    end;
end;

procedure gui_DrawCheckBox;
begin
  with zglTCheckBoxDesc( Widget.desc^ ), Widget.rect do
    begin
      pr2d_Rect( X, Y, W, H, COLOR_WIDGET, 255, PR2D_FILL );
      pr2d_Rect( X, Y, W, H, $000000, 255, 0 );
      if Widget.mousein Then
        pr2d_Rect( X + 1, Y + 1, W - 2, H - 2, COLOR_SELECT, 55, PR2D_FILL );
      if Checked Then
        pr2d_Rect( X + 3, Y + 3, W - 6, H - 6, $000000, 255, PR2D_FILL );
      if Widget.focus Then
        pr2d_Rect( X - 1, Y - 1, W + 2, H + 2, COLOR_SELECT, 155 );

      text_Draw( Font, X + W + Font.CharDesc[ Byte( ' ' ) ].ShiftP, Round( Y + ( H - Font.MaxHeight ) / 2 ), Caption );
    end;
end;

procedure gui_DrawRadioButton;
begin
  with zglTRadioButtonDesc( Widget.desc^ ), Widget.rect do
    begin
      pr2d_Circle( X + W / 2, Y + H / 2, W / 2, COLOR_WIDGET, 255, 8, PR2D_FILL );
      pr2d_Circle( X + W / 2, Y + H / 2, W / 2, $000000, 255, 8 );
      if Widget.mousein Then
        pr2d_Circle( X + W / 2, Y + H / 2, W / 2 - 1, COLOR_SELECT, 55, 8, PR2D_FILL );
      if Checked Then
        pr2d_Circle( X + W / 2, Y + H / 2, W / 3, $000000, 255, 8, PR2D_FILL );
      if Widget.focus Then
        pr2d_Circle( X + W / 2, Y + H / 2, W / 2 + 1, COLOR_SELECT, 155, 8 );

      text_Draw( Font, X + W + Font.CharDesc[ Byte( ' ' ) ].ShiftP, Round( Y + ( H - Font.MaxHeight ) / 2 ), Caption );
    end;
end;

procedure gui_DrawLabel;
begin
  with zglTCheckBoxDesc( Widget.desc^ ), Widget.rect do
    text_Draw( Font, X, Y, Caption );
end;

procedure gui_DrawEditBox;
  var
    tw, th : Single;
begin
  with zglTEditBoxDesc( Widget.desc^ ), Widget.rect do
    begin
      pr2d_Rect( X, Y, W, H, COLOR_EDIT, 255, PR2D_FILL );
      pr2d_Rect( X, Y, W, H, COLOR_WIDGET, 255, 0 );
      pr2d_Rect( X + 1, Y + 1, W - 2, H - 2, $000000, 255, 0 );
      if Widget.mousein Then
        pr2d_Rect( X + 1, Y + 1, W - 2, H - 2, COLOR_SELECT, 55, PR2D_FILL );
      if Widget.focus Then
        pr2d_Rect( X, Y, W, H, COLOR_SELECT, 155 );

      _clip( Widget, X + 2, Y + 2, W - 4, H - 2 );
      th := Y + Round( ( H - Font.MaxHeight ) / 2 ) + 1;
      text_Draw( Font, X + Font.CharDesc[ Byte( ' ' ) ].ShiftP, th, Text );

      if Widget.focus Then
        begin
          tw := X + Font.CharDesc[ Byte( ' ' ) ].ShiftP + text_GetWidth( Font, Text );
          pr2d_Line( tw, th, tw, th + Font.MaxHeight - Font.MaxShiftY, $FFFFFF, 255 * Byte( cursorAlpha < 25 ) );
        end;
      scissor_End;
    end;
end;

procedure gui_DrawListBox;
  var
    i, ty  : Integer;
    iShift : Integer;
    subW   : Integer;
begin
  with zglTListBoxDesc( Widget.desc^ ), Widget.rect do
    begin
      subW := ( SCROLL_SIZE + 1 ) * Byte( Assigned( Widget.child ) );
      pr2d_Rect( X, Y, W - subW, H, COLOR_EDIT, 255, PR2D_FILL );
      pr2d_Rect( X, Y, W - subW, H, COLOR_WIDGET, 255, 0 );
      pr2d_Rect( X + 1, Y + 1, W - 2 - subW, H - 2, $000000, 255, 0 );
      if Widget.focus Then
        pr2d_Rect( X, Y, W - subW, H, COLOR_SELECT, 155 );

      _clip( Widget, X + 2, Y + 2, W - subW + 1 - 4, H - 4 );
      if Assigned( Widget.child ) Then
        iShift := zglTScrollBarDesc( Widget.child.Next.desc^ ).Position
      else
        iShift := 0;
      for i := 0 to List.Count - 1 do
        begin
          ty := Round( Y + ( i - iShift ) * Font.MaxHeight + ( i  - iShift ) * 3 + 3 );
          if ( ty >= Y - Font.MaxHeight ) and ( ty <= Y + H + Font.MaxHeight ) Then
            text_Draw( Font, X + Font.CharDesc[ Byte( ' ' ) ].ShiftP, ty, List.Items[ i ] );
        end;

      if ItemIndex > -1 Then
        begin
          pr2d_Rect( X + 2, Y + 3 + ( ItemIndex - iShift ) * Font.MaxHeight + ( ItemIndex - iShift ) * 3,
                     W - 4 - subW, Font.MaxHeight, COLOR_SELECT, 55, PR2D_FILL );
          pr2d_Rect( X + 2, Y + 3 + ( ItemIndex - iShift ) * Font.MaxHeight + ( ItemIndex - iShift ) * 3,
                     W - 4 - subW, Font.MaxHeight, COLOR_SELECT, 155 );
        end;
      scissor_End;
    end;
end;

procedure gui_DrawGroupBox;
  var
    th : Integer;
begin
  with zglTGroupBoxDesc( Widget.desc^ ), Widget.rect do
    begin
      th := Trunc( Font.MaxHeight / 2 );
      pr2d_Rect( X, Y, W, H, COLOR_WINDOW, 255, PR2D_FILL );

      pr2d_Rect( X, Y, W - 1, H - 1, COLOR_WIDGET, 255, 0 );
      pr2d_Rect( X + 1, Y + 1, W - 1, H - 1, COLOR_LIGHT, 255, 0 );
      pr2d_Rect( X + Font.CharDesc[ Byte( ' ' ) ].ShiftP, Y, text_GetWidth( Font, Caption ), th, COLOR_WINDOW, 255, PR2D_FILL );

      text_Draw( Font, X + Font.CharDesc[ Byte( ' ' ) ].ShiftP, Y - th, Caption );
    end;
end;

procedure gui_DrawSpin;
begin
  with zglTSpinDesc( Widget.desc^ ), Widget.rect do
    begin
      _button_draw( X, Y, W, H / 2, UPressed );
      glColor4f( 0, 0, 0, 1 );
      glBegin( GL_TRIANGLES );
        gl_Vertex2f( X + W / 2 + Byte( UPressed ), Y + 2 + Byte( UPressed ) );
        gl_Vertex2f( X + W - 2 + Byte( UPressed ), Y + H / 2 - 2 + Byte( UPressed ) );
        gl_Vertex2f( X + 2 + Byte( UPressed ),     Y + H / 2 - 2 + Byte( UPressed ) );
      glEnd;

      _button_draw( X, Y + H / 2, W, H / 2, DPressed );
      glColor4f( 0, 0, 0, 1 );
      glBegin( GL_TRIANGLES );
        gl_Vertex2f( X + 2 + Byte( DPressed ),     Y + H / 2 + 2 + Byte( DPressed ) );
        gl_Vertex2f( X + W - 2 + Byte( DPressed ), Y + H / 2 + 2 + Byte( DPressed ) );
        gl_Vertex2f( X + W / 2 + Byte( DPressed ), Y + H - 2 + Byte( DPressed ) );
      glEnd;
    end;
end;

procedure gui_DrawScrollBar;
  var
    r : zglTRect;
begin
  with zglTScrollBarDesc( Widget.desc^ ), Widget.rect do
    begin
      pr2d_Rect( X, Y, W, H, COLOR_WIDGET, 255, PR2D_FILL );
      pr2d_Rect( X, Y, W, H, $000000, 255 );

      r := gui_GetScrollRect( Widget );
      _button_draw( r.X, r.Y, r.W, r.H, false );

      if Kind = SCROLLBAR_VERTICAL Then
        _scrolls_draw( X, Y, X, Y + H - SCROLL_SIZE, SCROLL_SIZE, TRUE, UPressed, DPressed )
      else
        _scrolls_draw( X, Y, X + W - SCROLL_SIZE, Y, SCROLL_SIZE, FALSE, UPressed, DPressed );
    end;
end;

end.
