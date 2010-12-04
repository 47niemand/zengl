program demo08;

{$R *.res}
{$DEFINE STATIC}

uses
  {$IFNDEF STATIC}
  zglHeader
  {$ELSE}
  zgl_main,
  zgl_screen,
  zgl_window,
  zgl_timers,
  zgl_keyboard,
  zgl_mouse,
  zgl_render_2d,
  zgl_fx,
  zgl_textures,
  zgl_textures_png,
  zgl_font,
  zgl_text,
  zgl_sprite_2d,
  zgl_sound,
  zgl_sound_wav,    // RU: Включает поддержку wav.
                    // EN: Enabling support of wav.
  zgl_sound_ogg,    // RU: Включает поддержку ogg.
                    // Для декодирования ogg-файлов понадобятся libogg.dll, libvorbis.dll и libvorbisfile.dll.
                    // Но можно обойтись и статической сборкой. Все нужные файлы можно найти тут:
                    // http://andru-kun.inf.ua/zengl_extra.html
                    //
                    // EN: Enabling support of ogg.
                    // For decoding ogg-files will be needed libogg.dll, libvorbis.dll and libvorbisfile.dll.
                    // Or not, if static linking will be used. All needed files can be found here:
                    // http://andru-kun.inf.ua/zengl_extra.html
  zgl_math_2d,
  zgl_collision_2d,
  zgl_utils
  {$ENDIF}
  ;

const
  SCREEN_WIDTH  = 800;
  SCREEN_HEIGHT = 600;

var
  dirRes : String = '../../res/';
  fnt    : zglPFont;
  icon   : array[ 0..1 ] of zglPTexture;
  sound  : zglPSound;
  audio  : Integer;
  state  : Integer;

// RU: Т.к. звуковая подсистема нацелена на 3D, для позиционирования звуков в 2D нужны некоторые ухищрения
// EN: Because sound subsystem using 3D, there is some tricky way to calculate sound position in 2D
function CalcX2D( const X : Single ) : Single;
begin
  Result := ( X - SCREEN_WIDTH / 2 ) * ( 1 / SCREEN_WIDTH / 2 );
end;

function CalcY2D( const Y : Single ) : Single;
begin
  Result := ( Y - SCREEN_HEIGHT / 2 ) * ( 1 / SCREEN_HEIGHT / 2 );
end;

procedure Init;
  var
    i : Integer;
begin
  {$IFDEF DARWIN}
  dirRes := PChar( zgl_Get( APP_DIRECTORY ) ) + 'Contents/Resources/';
  {$ENDIF}

  // RU: Инициализируем звуковую подсистему.
  // Для Windows можно сделать выбор между DirectSound и OpenAL глянув файл zgl_config.cfg
  //
  // EN: Initializing sound subsystem
  // For Windows can be used DirectSound or OpenAL, see zgl_config.cfg
  snd_Init();

  // RU: Загружаем звуковой файл и устанавливаем для него максимальноe количество проигрываемых семплов в 2.
  // EN: Load the sound file and set maximum count of samples that can be played to the 2.
  sound := snd_LoadFromFile( dirRes + 'click.wav', 2 );

  // RU: Загружаем текстуры, которые будут индикаторами.
  // EN: Load the textures, that will be indicators.
  icon[ 0 ] := tex_LoadFromFile( dirRes + 'audio-stop.png', $FF000000, TEX_DEFAULT_2D );
  icon[ 1 ] := tex_LoadFromFile( dirRes + 'audio-play.png', $FF000000, TEX_DEFAULT_2D );

  fnt := font_LoadFromFile( dirRes + 'font.zfi' );
end;

procedure Draw;
  var
    r : zglTRect;
begin
  ssprite2d_Draw( icon[ state ], ( SCREEN_WIDTH - 128 ) / 2, ( SCREEN_HEIGHT - 128 ) / 2, 128, 128, 0 );
  text_Draw( fnt, SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2 + 64, 'Skillet - Comatose - Whispers In The Dark', TEXT_HALIGN_CENTER );

  r.X := ( SCREEN_WIDTH - 128 ) / 2;
  r.Y := ( SCREEN_HEIGHT - 128 ) / 2;
  r.W := 128;
  r.H := 128;
  if col2d_PointInRect( mouse_X, mouse_Y, r ) Then
    begin
      fx_SetBlendMode( FX_BLEND_ADD );
      ssprite2d_Draw( icon[ state ], ( SCREEN_WIDTH - 132 ) / 2, ( SCREEN_HEIGHT - 132 ) / 2, 132, 132, 0, 155 );
      fx_SetBlendMode( FX_BLEND_NORMAL );
    end;
end;

procedure Proc;
  var
    r : zglTRect;
    p : Integer;
begin
  // RU: Проверяем играет ли музыка(1 - играет, 0 - не играет). Так же можно проверить и звуки - подставив zglPSound и ID вот так:
  // snd_Get( Sound, ID...
  // ID возвращается функцией snd_Play
  //
  // EN: Check if music playing(1 - playing, 0 - not playing). Sounds also can be checked this way - just use zglPSound and ID:
  // snd_Get( Sound, ID...
  // ID returns by function snd_Play.
  state := snd_Get( zglPSound( audio ), SND_STREAM, SND_STATE_PLAYING );
  if state = 0 Then
    audio := 0;

  if mouse_Click( M_BLEFT ) Then
    begin
      // RU: В данном случаи мы начинаем воспроизводить звук сразу в указанных координатах, но их можно менять и в процессе используя процедуру snd_SetPos.
      // Важно: Для OpenAL можно позиционировать только mono-звуки
      //
      // EN: In this case, we begin to play the sound directly in these coordinates, but they can be changed later using procedure snd_SetPos.
      // Important: OpenAL can position only mono-sounds.
      snd_Play( sound, FALSE, CalcX2D( mouse_X ), CalcY2D( mouse_Y ) );

      r.X := ( SCREEN_WIDTH - 128 ) / 2;
      r.Y := ( SCREEN_HEIGHT - 128 ) / 2;
      r.W := 128;
      r.H := 128;
      if col2d_PointInRect( mouse_X, mouse_Y, r ) and ( audio = 0 ) Then
        audio := snd_PlayFile( dirRes + 'music.ogg');
    end;

  // RU: Получаем в процентах позицию проигрывания аудиопотока и ставим громкость для плавных переходов.
  // EN: Get position in percent's for audio stream and set volume for smooth playing.
  p := snd_Get( zglPSound( audio ), SND_STREAM, SND_STATE_PERCENT );
  if ( p >= 0 ) and ( p < 25 ) Then
    snd_SetVolume( zglPSound( audio ), SND_STREAM, ( 1 / 24 ) * p );
  if ( p >= 75 ) and ( p < 100 ) Then
    snd_SetVolume( zglPSound( audio ), SND_STREAM, 1 - ( 1 / 24 ) * ( p - 75 ) );

  if key_Press( K_ESCAPE ) Then zgl_Exit();
  key_ClearState();
  mouse_ClearState();
end;

Begin
  {$IFNDEF STATIC}
  zglLoad( libZenGL );
  {$ENDIF}

  randomize();

  timer_Add( @Proc, 16 );

  zgl_Reg( SYS_LOAD, @Init );
  zgl_Reg( SYS_DRAW, @Draw );

  // RU: Т.к. модуль сохранен в кодировке UTF-8 и в нем используются строковые переменные
  // следует указать использование этой кодировки.
  // EN: Enable using of UTF-8, because this unit saved in UTF-8 encoding and here used
  // string variables.
  zgl_Enable( APP_USE_UTF8 );

  wnd_SetCaption( '08 - Sound' );

  wnd_ShowCursor( TRUE );

  scr_SetOptions( SCREEN_WIDTH, SCREEN_HEIGHT, REFRESH_MAXIMUM, FALSE, FALSE );

  zgl_Init();
End.
