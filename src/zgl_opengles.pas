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
unit zgl_opengles;

{$I zgl_config.cfg}
{$IF ( DEFINED(WIN32) or DEFINED(WIN64) or DEFINED(DARWIN) ) and not DEFINED(USE_GLES_ON_DESKTOP)}
  {$ERROR Are you seriously want to compile embedded OpenGL ES code for Windows/MacOS X? :)}
{$IFEND}

interface
uses
  {$IFDEF LINUX}
  X, XLib, XUtil,
  {$ENDIF}
  {$IFDEF WINDOWS}
  windows,
  {$ENDIF}
  zgl_opengles_all;

const
  TARGET_SCREEN  = 1;
  TARGET_TEXTURE = 2;

function  gl_Create : Boolean;
procedure gl_Destroy;
function  gl_Initialize : Boolean;
procedure gl_ResetState;
procedure gl_LoadEx;

var
  oglzDepth     : Byte;
  oglStencil    : Byte;
  oglFSAA       : Byte;
  oglAnisotropy : Byte;
  oglFOVY       : Single = 45;
  oglzNear      : Single = 0.1;
  oglzFar       : Single = 100;
  oglMTexActive : array[ 0..8 ] of Boolean;
  oglMTexture   : array[ 0..8 ] of LongWord;

  oglMode    : Integer = 2; // 2D/3D Modes
  oglTarget  : Integer = TARGET_SCREEN;
  oglTargetW : Integer;
  oglTargetH : Integer;

  oglWidth  : Integer;
  oglHeight : Integer;
  oglClipX  : Integer;
  oglClipY  : Integer;
  oglClipW  : Integer;
  oglClipH  : Integer;
  oglClipR  : Integer;

  oglRenderer      : AnsiString;
  oglExtensions    : AnsiString;
  ogl3DAccelerator : Boolean;
  oglCanVSync      : Boolean;
  oglCanAnisotropy : Boolean;
  oglCanCompressA  : Boolean;
  oglCanCompressE  : Boolean;
  oglCanAutoMipMap : Boolean;
  oglCanARB        : Boolean; // ARBvp/ARBfp шейдеры
  oglCanGLSL       : Boolean; // GLSL шейдеры
  oglCanVBO        : Boolean;
  oglCanFBO        : Boolean;
  oglCanFBODepth24 : Boolean;
  oglCanFBODepth32 : Boolean;
  oglCanPBuffer    : Boolean;
  oglMaxLights     : Integer;
  oglMaxTexSize    : Integer;
  oglMaxFBOSize    : Integer;
  oglMaxAnisotropy : Integer;
  oglMaxTexUnits   : Integer;
  oglSeparate      : Boolean;

  oglDisplay : EGLDisplay;
  oglConfig  : EGLConfig;
  oglSurface : EGLSurface;
  oglContext : EGLContext;

  oglAttr : array[ 0..31 ] of EGLint;
  {$IFDEF LINUX}
  oglVisualInfo : PXVisualInfo;
  {$ENDIF}

implementation
uses
  zgl_application,
  zgl_screen,
  zgl_window,
  zgl_log,
  zgl_utils;

function gl_Create : Boolean;
  var
    i, j : EGLint;
begin
  Result := TRUE;

  if not InitGLES() Then
    begin
      log_Add( 'Cannot load GLES library' );
      exit;
    end;

  {$IFDEF LINUX}
  GetMem( oglVisualInfo, SizeOf( TXVisualInfo ) );
  XMatchVisualInfo( scrDisplay, scrDefault, DefaultDepth( scrDisplay, scrDefault ), TrueColor, oglVisualInfo );

  oglDisplay := eglGetDisplay( scrDisplay );
  {$ENDIF}
  {$IFDEF WINDOWS}
  oglDisplay := eglGetDisplay( EGL_DEFAULT_DISPLAY );
  {$ENDIF}

  if not eglInitialize( oglDisplay, @i, @j ) Then
    begin
      log_Add( 'eglInitialize failed: ' + u_IntToStr( eglGetError() ) );
      exit;
    end;

  j := 0;
  oglzDepth := 24;
  repeat
    oglAttr[ 0  ] := EGL_SURFACE_TYPE;
    oglAttr[ 1  ] := EGL_WINDOW_BIT;
    oglAttr[ 2  ] := EGL_RENDERABLE_TYPE;
    oglAttr[ 3  ] := EGL_OPENGL_ES_BIT;
    oglAttr[ 4  ] := EGL_RED_SIZE;
    oglAttr[ 5  ] := 8;
    oglAttr[ 6  ] := EGL_GREEN_SIZE;
    oglAttr[ 7  ] := 8;
    oglAttr[ 8  ] := EGL_BLUE_SIZE;
    oglAttr[ 9  ] := 8;
    oglAttr[ 10 ] := EGL_ALPHA_SIZE;
    oglAttr[ 11 ] := 0;
    oglAttr[ 12 ] := EGL_DEPTH_SIZE;
    oglAttr[ 13 ] := oglzDepth;
    i := 14;
    if oglStencil > 0 Then
      begin
        oglAttr[ i     ] := EGL_STENCIL_SIZE;
        oglAttr[ i + 1 ] := oglStencil;
        INC( i, 2 );
      end;
    if oglFSAA > 0 Then
      begin
        oglAttr[ i     ] := EGL_SAMPLES;
        oglAttr[ i + 1 ] := oglFSAA;
        INC( i, 2 );
      end;
    oglAttr[ i ] := EGL_NONE;

    log_Add( 'eglChooseConfig: zDepth = ' + u_IntToStr( oglzDepth ) + '; ' + 'stencil = ' + u_IntToStr( oglStencil ) + '; ' + 'fsaa = ' + u_IntToStr( oglFSAA )  );
    eglChooseConfig( oglDisplay, @oglAttr[ 0 ], @oglConfig, 1, @j );
    if ( j <> 1 ) and ( oglzDepth = 1 ) Then
      begin
        if oglFSAA = 0 Then
          break
        else
          begin
            oglzDepth := 24;
            DEC( oglFSAA, 2 );
          end;
      end else
        if j <> 1 Then DEC( oglzDepth, 8 );
    if oglzDepth = 0 Then oglzDepth := 1;
  until j = 1;

  Result := j = 1;
end;

procedure gl_Destroy;
begin
  {$IFDEF LINUX}
  FreeMem( oglVisualInfo );
  {$ENDIF}

  eglMakeCurrent( oglDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT );
  eglTerminate( oglDisplay );

  FreeGLES();
end;

function gl_Initialize : Boolean;
begin
  oglSurface := eglCreateWindowSurface( oglDisplay, oglConfig, wndHandle, nil );
  if eglGetError() <> EGL_SUCCESS Then
    begin
      log_Add( 'Cannot create Windows surface' );
      exit;
    end;
  oglContext := eglCreateContext( oglDisplay, oglConfig, nil, nil );
  if eglGetError() <> EGL_SUCCESS Then
    begin
      log_Add( 'Cannot create OpenGL ES context' );
      exit;
    end;
  eglMakeCurrent( oglDisplay, oglSurface, oglSurface, oglContext );
  if eglGetError() <> EGL_SUCCESS Then
    begin
      log_Add( 'Cannot set current OpenGL ES context' );
      exit;
    end;

  oglRenderer := glGetString( GL_RENDERER );
  log_Add( 'GL_VERSION: ' + glGetString( GL_VERSION ) );
  log_Add( 'GL_RENDERER: ' + oglRenderer );

{$IFDEF LINUX}
  ogl3DAccelerator := oglRenderer <> 'Software Rasterizer';
{$ELSE}
  ogl3DAccelerator := TRUE;
{$ENDIF}
  if not ogl3DAccelerator Then
    u_Warning( 'Cannot find 3D-accelerator! Application run in software-mode, it''s very slow' );

  gl_LoadEx();
  gl_ResetState();

  Result := TRUE;
end;

procedure gl_ResetState;
begin
  glHint( GL_LINE_SMOOTH_HINT,            GL_NICEST );
  glHint( GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST );
  glHint( GL_FOG_HINT,                    GL_DONT_CARE );
  glShadeModel( GL_SMOOTH );

  glClearColor( 0, 0, 0, 0 );

  glDepthFunc ( GL_LEQUAL );
  glClearDepth( 1.0 );

  glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA );
  glAlphaFunc( GL_GREATER, 0 );

  if oglSeparate Then
    begin
      glBlendEquation( GL_FUNC_ADD_EXT );
      glBlendFuncSeparate( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA );
    end;

  glDisable( GL_BLEND );
  glDisable( GL_ALPHA_TEST );
  glDisable( GL_DEPTH_TEST );
  glDisable( GL_TEXTURE_2D );
  glEnable ( GL_NORMALIZE );
end;

procedure gl_LoadEx;
begin
  oglExtensions := glGetString( GL_EXTENSIONS );

  // Texture size
  glGetIntegerv( GL_MAX_TEXTURE_SIZE, @oglMaxTexSize );
  log_Add( 'GL_MAX_TEXTURE_SIZE: ' + u_IntToStr( oglMaxTexSize ) );

  {oglCanCompressA := gl_IsSupported( 'GL_ARB_texture_compression', oglExtensions );
  log_Add( 'GL_ARB_TEXTURE_COMPRESSION: ' + u_BoolToStr( oglCanCompressA ) );
  oglCanCompressE := gl_IsSupported( 'GL_EXT_texture_compression_s3tc', oglExtensions );
  log_Add( 'GL_EXT_TEXTURE_COMPRESSION_S3TC: ' + u_BoolToStr( oglCanCompressE ) );}

  oglCanAutoMipMap := TRUE;

  // Multitexturing
  glGetIntegerv( GL_MAX_TEXTURE_UNITS_ARB, @oglMaxTexUnits );
  log_Add( 'GL_MAX_TEXTURE_UNITS_ARB: ' + u_IntToStr( oglMaxTexUnits ) );

  // Anisotropy
  oglCanAnisotropy := gl_IsSupported( 'GL_EXT_texture_filter_anisotropic', oglExtensions );
  if oglCanAnisotropy Then
    begin
      glGetIntegerv( GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, @oglMaxAnisotropy );
      oglAnisotropy := oglMaxAnisotropy;
    end else
      oglAnisotropy := 0;
  log_Add( 'GL_EXT_TEXTURE_FILTER_ANISOTROPIC: ' + u_BoolToStr( oglCanAnisotropy ) );
  log_Add( 'GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT: ' + u_IntToStr( oglMaxAnisotropy ) );

  glBlendEquation     := gl_GetProc( 'glBlendEquation' );
  glBlendFuncSeparate := gl_GetProc( 'glBlendFuncSeparate' );
  oglSeparate := Assigned( glBlendEquation ) and Assigned( glBlendFuncSeparate ) and gl_IsSupported( 'GL_OES_blend_func_separate', oglExtensions );
  log_Add( 'glBlendEquation: ' + u_BoolToStr( Assigned( glBlendEquation ) ) );
  log_Add( 'glBlendFuncSeparate: ' + u_BoolToStr( Assigned( glBlendFuncSeparate ) ) );
  log_Add( 'GL_OES_BLEND_FUNC_SEPARATE: ' + u_BoolToStr( oglSeparate ) );

  // FBO
  if gl_IsSupported( 'OES_framebuffer_object', oglExtensions ) Then
    begin
      oglCanFBO                 := TRUE;
      glBindRenderbuffer        := gl_GetProc( 'glBindRenderbuffer'        );
      glIsRenderbuffer          := gl_GetProc( 'glIsRenderbuffer'          );
      glDeleteRenderbuffers     := gl_GetProc( 'glDeleteRenderbuffers'     );
      glGenRenderbuffers        := gl_GetProc( 'glGenRenderbuffers'        );
      glRenderbufferStorage     := gl_GetProc( 'glRenderbufferStorage'     );
      glIsFramebuffer           := gl_GetProc( 'glIsFramebuffer'           );
      glBindFramebuffer         := gl_GetProc( 'glBindFramebuffer'         );
      glDeleteFramebuffers      := gl_GetProc( 'glDeleteFramebuffers'      );
      glGenFramebuffers         := gl_GetProc( 'glGenFramebuffers'         );
      glCheckFramebufferStatus  := gl_GetProc( 'glCheckFramebufferStatus'  );
      glFramebufferTexture2D    := gl_GetProc( 'glFramebufferTexture2D'    );
      glFramebufferRenderbuffer := gl_GetProc( 'glFramebufferRenderbuffer' );

      glGetIntegerv( GL_MAX_RENDERBUFFER_SIZE, @oglMaxFBOSize );
      log_Add( 'GL_MAX_RENDERBUFFER_SIZE: ' + u_IntToStr( oglMaxFBOSize ) );
    end else
      oglCanFBO := FALSE;
  oglCanFBODepth24 := gl_IsSupported( 'GL_OES_depth24', oglExtensions );
  oglCanFBODepth32 := gl_IsSupported( 'GL_OES_depth32', oglExtensions );
  log_Add( 'GL_OES_FRAMEBUFFER_OBJECT: ' + u_BoolToStr( oglCanFBO ) );

  // WaitVSync
  oglCanVSync := TRUE;
  scr_SetVSync( scrVSync );
  log_Add( 'Support WaitVSync: ' + u_BoolToStr( oglCanVSync ) );
end;

end.
