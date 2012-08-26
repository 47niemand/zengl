program demo08;

{$I zglCustomConfig.cfg}

{$IFDEF WINDOWS}
  {$R *.res}
{$ENDIF}

uses
  {$IFDEF USE_ZENGL_STATIC}
  zgl_main,
  zgl_screen,
  zgl_window,
  zgl_timers,
  zgl_keyboard,
  zgl_render_2d,
  zgl_fx,
  zgl_textures,
  zgl_textures_png,
  zgl_textures_jpg,
  zgl_sprite_2d,
  zgl_sengine_2d,
  zgl_primitives_2d,
  zgl_font,
  zgl_text,
  zgl_math_2d,
  zgl_utils
  {$ELSE}
  zglHeader
  {$ENDIF}
  ;

type
  zglPMikuSprite = ^zglTMikuSprite;
  zglTMikuSprite = record
    // RU: ������������ ����� ������ ���� �������.
    // EN: New type should start with this.
    Sprite : zglTSprite2D;

    // RU: ����� ���������.
    // EN: New params.
    Speed  : zglTPoint2D;
  end;

var
  dirRes    : UTF8String {$IFNDEF MACOSX} = '../data/' {$ENDIF};
  fntMain   : zglPFont;
  texLogo   : zglPTexture;
  texMiku   : zglPTexture;
  time      : Integer;
  sengine2d : zglTSEngine2D;

// Miku
procedure MikuInit( var Miku : zglTMikuSprite );
begin
  with Miku, Miku.Sprite do
    begin
      X := 800 + random( 800 );
      Y := random( 600 - 128 );

      // RU: ������ �������� ��������.
      // EN: Set the moving speed.
      Speed.X := -random( 10 ) / 5 - 0.5;
      Speed.Y := ( random( 10 ) - 5 ) / 5;
    end;
end;

procedure MikuDraw( var Miku : zglTMikuSprite );
begin
  with Miku.Sprite do
    asprite2d_Draw( Texture, X, Y, W, H, Angle, Round( Frame ), Alpha, FxFlags );
end;

procedure MikuProc( var Miku : zglTMikuSprite );
begin
  with Miku, Miku.Sprite do
    begin
      X := X + Speed.X;
      Y := Y + Speed.Y;
      Frame := Frame + ( abs( speed.X ) + abs( speed.Y ) ) / 25;
      if Frame > 8 Then
        Frame := 1;

      // RU: ���� ������ ������� �� ������� �� X, ����� �� ������� ���.
      // EN: Delete the sprite if it goes beyond X.
      if X < -128 Then sengine2d_DelSprite( ID );

      // RU: ���� ������ ������� �� ������� �� Y, ������ ��� � ������� �� ��������.
      // EN: Add sprite to queue for delete if it goes beyond Y.
      if Y < -128 Then Destroy := TRUE;
      if Y > 600  Then Destroy := TRUE;
    end;
end;

procedure MikuFree( var Miku : zglTMikuSprite );
begin
end;

// RU: �������� 100 ��������.
// EN: Add 100 sprites.
procedure AddMiku;
  var
    i : Integer;
begin
  // RU: ��� ���������� ������� � �������� �������� ����������� ��������, ����(��������� �� Z) � ��������� �� �������� ������� - �������������, ������, ��������� � �����������.
  // EN: For adding sprite to sprite engine must be set next parameters: texture, layer(Z-coordinate) and pointers to Initialization, Render, Process and Destroy functions.
  for i := 1 to 100 do
    sengine2d_AddCustom( texMiku, SizeOf( zglTMikuSprite ), random( 10 ), @MikuInit, @MikuDraw, @MikuProc, @MikuFree );
end;

// RU: ������� 100 ��������.
// EN: Delete 100 sprites.
procedure DelMiku;
  var
    i : Integer;
begin
  // RU: ������ 100 �������� �� ��������� ID.
  // EN: Delete 100 sprites with random ID.
  for i := 1 to 100 do
    sengine2d_DelSprite( random( sengine2d.Count ) );
end;

procedure Init;
  var
    i : Integer;
begin
  texLogo := tex_LoadFromFile( dirRes + 'zengl.png' );

  texMiku := tex_LoadFromFile( dirRes + 'miku.png' );
  tex_SetFrameSize( texMiku, 128, 128 );

  // RU: ������������� ������� ���������� �������� ����.
  // EN: Set own sprite engine as current.
  sengine2d_Set( @sengine2d );

  // RU: �������� 1000 �������� Miku-chan :)
  // EN: Create 1000 sprites of Miku-chan :)
  for i := 0 to 9 do
    AddMiku();

  fntMain := font_LoadFromFile( dirRes + 'font.zfi' );
end;

procedure Draw;
begin
  batch2d_Begin();
  // RU: ������ ��� ������� ����������� � ������� ���������� ���������.
  // EN: Render all sprites contained in current sprite engine.
  if time > 255 Then
    sengine2d_Draw();

  if time <= 255 Then
    ssprite2d_Draw( texLogo, 400 - 256, 300 - 128, 512, 256, 0, time )
  else
    if time < 510 Then
      begin
        pr2d_Rect( 0, 0, 800, 600, $000000, 510 - time, PR2D_FILL );
        ssprite2d_Draw( texLogo, 400 - 256, 300 - 128, 512, 256, 0, 510 - time );
      end;

  if time > 255 Then
    begin
      pr2d_Rect( 0, 0, 256, 64, $000000, 200, PR2D_FILL );
      text_Draw( fntMain, 0, 0, 'FPS: ' + u_IntToStr( zgl_Get( RENDER_FPS ) ) );
      text_Draw( fntMain, 0, 20, 'Sprites: ' + u_IntToStr( sengine2d.Count ) );
      text_Draw( fntMain, 0, 40, 'Up/Down - Add/Delete Miku :)' );
    end;
  batch2d_End();
end;

procedure Timer;
begin
  INC( time, 2 );

  // RU: ��������� ��������� ���� �������� � ������� ���������� ���������.
  // EN: Process all sprites contained in current sprite engine.
  sengine2d_Proc();

  // RU: �� ������� ������� �������� ��� �������.
  // EN: Delete all sprites if space was pressed.
  if key_Press( K_SPACE ) Then sengine2d_ClearAll();
  if key_Press( K_UP ) Then AddMiku();
  if key_Press( K_DOWN ) Then DelMiku();

  if key_Press( K_ESCAPE ) Then zgl_Exit();

  key_ClearState();
end;

procedure Quit;
begin
  // RU: ������� ������ �� ��������� ��������.
  // EN: Free allocated memory for sprites.
  sengine2d_Set( @sengine2d );
  sengine2d_ClearAll();
end;

Begin
  {$IFNDEF USE_ZENGL_STATIC}
  if not zglLoad( libZenGL ) Then exit;
  {$ENDIF}

  randomize;

  timer_Add( @Timer, 16 );
  timer_Add( @AddMiku, 1000 );

  zgl_Reg( SYS_LOAD, @Init );
  zgl_Reg( SYS_DRAW, @Draw );
  zgl_Reg( SYS_EXIT, @Quit );

  wnd_SetCaption( '08 - Sprite Engine' );

  wnd_ShowCursor( TRUE );

  scr_SetOptions( 800, 600, REFRESH_MAXIMUM, FALSE, FALSE );

  zgl_Init();
End.
