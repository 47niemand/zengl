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
{$IFDEF iOS}
  {$modeswitch objectivec1}
  {$LINKFRAMEWORK OpenGLES}
  {$LINKFRAMEWORK QuartzCore}
{$ENDIF}
{$IF ( DEFINED(WIN32) or DEFINED(WIN64) or DEFINED(MACOSX) ) and not DEFINED(USE_GLES_ON_DESKTOP)}
  {$ERROR Are you seriously want to compile embedded OpenGL ES code for Windows/MacOS X? :)}
{$IFEND}

interface
uses
  {$IFDEF LINUX}
  X, XLib, XUtil,
  {$ENDIF}
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  {$IFDEF iOS}
  iPhoneAll, CGGeometry,
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

{$IFDEF iOS}
type
  // dummy class, which does almost nothing... :)
  zglCiOSEAGLView = objcclass(UIView)
  public
    class function layerClass: Pobjc_class; override;
  end;
{$ENDIF}


var
  oglColor      : Byte;
  oglzDepth     : Byte;
  oglStencil    : Byte;
  oglFSAA       : Byte;
  oglAnisotropy : Byte;
  oglFOVY       : Single = 45;
  oglzNear      : Single = 0.1;
  oglzFar       : Single = 100;

  oglMode    : Integer = 2; // 2D/3D Modes
  oglTarget  : Integer = TARGET_SCREEN;
  oglTargetW : Integer;
  oglTargetH : Integer;
  oglWidth   : Integer;
  oglHeight  : Integer;

  oglVRAMUsed : LongWord;

  oglRenderer      : AnsiString;
  oglExtensions    : AnsiString;
  ogl3DAccelerator : Boolean;
  oglCanVSync      : Boolean;
  oglCanAnisotropy : Boolean;
  oglCanPVRTC      : Boolean;
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

  oglReadPixelsFBO : LongWord;

  {$IFNDEF iOS}
  oglDisplay : EGLDisplay;
  oglConfig  : EGLConfig;
  oglSurface : EGLSurface;
  oglContext : EGLContext;

  oglAttr : array[ 0..31 ] of EGLint;
  {$IFDEF LINUX}
  oglVisualInfo : PXVisualInfo;
  {$ENDIF}
  {$ELSE}
  eglContext      : EAGLContext;
  eglSurface      : CAEAGLLayer;
  eglView         : zglCiOSEAGLView;
  eglFramebuffer  : GLuint;
  eglRenderbuffer : GLuint;
  {$ENDIF}

implementation
uses
  zgl_application,
  zgl_screen,
  zgl_window,
  zgl_log,
  zgl_utils;

function gles_GetErrorStr( ErrorCode : LongWord ) : String;
begin
{$IFNDEF iOS}
  case ErrorCode of
    EGL_NOT_INITIALIZED: Result := 'EGL_NOT_INITIALIZED';
    EGL_BAD_ACCESS: Result := 'EGL_BAD_ACCESS';
    EGL_BAD_ALLOC: Result := 'EGL_BAD_ALLOC';
    EGL_BAD_ATTRIBUTE: Result := 'EGL_BAD_ATTRIBUTE';
    EGL_BAD_CONFIG: Result := 'EGL_BAD_CONFIG';
    EGL_BAD_CONTEXT: Result := 'EGL_BAD_CONTEXT';
    EGL_BAD_CURRENT_SURFACE: Result := 'EGL_BAD_CURRENT_SURFACE';
    EGL_BAD_DISPLAY: Result := 'EGL_BAD_DISPLAY';
    EGL_BAD_MATCH: Result := 'EGL_BAD_MATCH';
    EGL_BAD_NATIVE_PIXMAP: Result := 'EGL_BAD_NATIVE_PIXMAP';
    EGL_BAD_NATIVE_WINDOW: Result := 'EGL_BAD_NATIVE_WINDOW';
    EGL_BAD_PARAMETER: Result := 'EGL_BAD_PARAMETER';
    EGL_BAD_SURFACE: Result := 'EGL_BAD_SURFACE';
    EGL_CONTEXT_LOST: Result := 'EGL_CONTEXT_LOST';
  else
    Result := 'Error code not recognized';
  end;
{$ELSE}
    Result := 'Error codes are not implemented for iOS';
{$ENDIF}
end;

function gl_Create : Boolean;
  {$IFNDEF iOS}
  var
    i, j : EGLint;
  {$ENDIF}
begin
  Result := FALSE;

  if not InitGLES() Then
    begin
      u_Error( 'Cannot load GLES libraries' );
      exit;
    end;

{$IFNDEF iOS}
{$IFDEF LINUX}
  GetMem( oglVisualInfo, SizeOf( TXVisualInfo ) );
  XMatchVisualInfo( scrDisplay, scrDefault, DefaultDepth( scrDisplay, scrDefault ), TrueColor, oglVisualInfo );

  oglColor := DefaultDepth( scrDisplay, scrDefault );

  oglDisplay := eglGetDisplay( scrDisplay );
{$ENDIF}
{$IFDEF WINDOWS}
  wnd_Create( wndWidth, wndHeight );

  oglColor := scrDesktop.dmBitsPerPel;

  oglDisplay := eglGetDisplay( wndDC );
{$ENDIF}

  if oglDisplay = EGL_NO_DISPLAY Then
    begin
      log_Add( 'eglGetDisplay: EGL_DEFAULT_DISPLAY' );
      oglDisplay := eglGetDisplay( EGL_DEFAULT_DISPLAY );
    end;

  if not eglInitialize( oglDisplay, @i, @j ) Then
    begin
      u_Error( 'Failed to initialize EGL. Error code - ' + gles_GetErrorStr( eglGetError() ) );
      {$IFDEF WINDOWS}
      wnd_Destroy;
      {$ENDIF}
      exit;
    end;

  j := 0;
  oglzDepth := 24;
  repeat
    oglAttr[ 0 ] := EGL_SURFACE_TYPE;
    oglAttr[ 1 ] := EGL_WINDOW_BIT;
    oglAttr[ 2 ] := EGL_DEPTH_SIZE;
    oglAttr[ 3 ] := oglzDepth;
    if oglColor > 16 Then
      begin
        oglAttr[ 4  ] := EGL_RED_SIZE;
        oglAttr[ 5  ] := 8;
        oglAttr[ 6  ] := EGL_GREEN_SIZE;
        oglAttr[ 7  ] := 8;
        oglAttr[ 8  ] := EGL_BLUE_SIZE;
        oglAttr[ 9  ] := 8;
        oglAttr[ 10 ] := EGL_ALPHA_SIZE;
        oglAttr[ 11 ] := 0;
      end else
        begin
          oglAttr[ 4  ] := EGL_RED_SIZE;
          oglAttr[ 5  ] := 5;
          oglAttr[ 6  ] := EGL_GREEN_SIZE;
          oglAttr[ 7  ] := 6;
          oglAttr[ 8  ] := EGL_BLUE_SIZE;
          oglAttr[ 9  ] := 5;
          oglAttr[ 10 ] := EGL_ALPHA_SIZE;
          oglAttr[ 11 ] := 0;
        end;
    i := 12;
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
{$ELSE}
  Result := TRUE;
{$ENDIF}
end;

procedure gl_Destroy;
begin
  if oglReadPixelsFBO <> 0 Then
    glDeleteFramebuffers( 1, @oglReadPixelsFBO );

{$IFNDEF iOS}
{$IFDEF LINUX}
  FreeMem( oglVisualInfo );
{$ENDIF}

  eglMakeCurrent( oglDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT );
  eglTerminate( oglDisplay );
{$ELSE}
  eglView.dealloc();

  glDeleteFramebuffers( 1, @eglFramebuffer );
  glDeleteRenderbuffers( 1, @eglRenderbuffer );

  EAGLContext.setCurrentContext( nil );
  eglContext.release();
{$ENDIF}

  FreeGLES();
end;

function gl_Initialize : Boolean;
  var
    err : LongWord;
    {$IFDEF iOS}
    frame : CGRect;
    {$ENDIF}
begin
{$IFNDEF iOS}
  oglSurface := eglCreateWindowSurface( oglDisplay, oglConfig, wndHandle, nil );
  err := eglGetError();
  if err <> EGL_SUCCESS Then
    begin
      u_Error( 'Cannot create Windows surface - ' + gles_GetErrorStr( err ) );
      exit;
    end;
  oglContext := eglCreateContext( oglDisplay, oglConfig, nil, nil );
  err := eglGetError();
  if err <> EGL_SUCCESS Then
    begin
      u_Error( 'Cannot create OpenGL ES context - ' + gles_GetErrorStr( err ) );
      exit;
    end;
  eglMakeCurrent( oglDisplay, oglSurface, oglSurface, oglContext );
  err := eglGetError();
  if err <> EGL_SUCCESS Then
    begin
      u_Error( 'Cannot set current OpenGL ES context - ' + gles_GetErrorStr( err ) );
      exit;
    end;
{$ELSE}
  FillChar( frame, SizeOf( CGRect ), 0 );
  frame.size.width  := oglWidth;
  frame.size.height := oglHeight;
  eglView := zglCiOSEAGLView.alloc().initWithFrame( frame );
  // iPhone Retina display
  if ( UIDevice.currentDevice.systemVersion.floatValue >= 3.2 ) and ( UIScreen.mainScreen.currentMode.size.width = 640 ) and ( UIScreen.mainScreen.currentMode.size.height = 960 ) Then
    begin
      eglView.setContentScaleFactor( 2 );
      log_Add( 'Retina display detected' );
    end;

  eglSurface := CAEAGLLayer( eglView.layer );
  eglSurface.setOpaque( TRUE );
  eglSurface.setDrawableProperties( NSDictionary.dictionaryWithObjectsAndKeys(
                                    NSNumber.numberWithBool( FALSE ),
                                    u_GetNSString( 'kEAGLDrawablePropertyRetainedBacking' ),
                                    u_GetNSString( 'kEAGLColorFormatRGBA8' ),
                                    u_GetNSString( 'kEAGLDrawablePropertyColorFormat' ),
                                    nil ) );
  wndViewCtrl.view.addSubview( eglView );

  eglContext := EAGLContext.alloc().initWithAPI( kEAGLRenderingAPIOpenGLES1 );
  EAGLContext.setCurrentContext( eglContext );
{$ENDIF}

  oglRenderer := glGetString( GL_RENDERER );
  log_Add( 'GL_VERSION: ' + glGetString( GL_VERSION ) );
  log_Add( 'GL_RENDERER: ' + oglRenderer );

  ogl3DAccelerator := TRUE;

  gl_LoadEx();
{$IFDEF iOS}
  glGenFramebuffers( 1, @eglFramebuffer );
  glBindFramebuffer( GL_FRAMEBUFFER, eglFramebuffer );

  glGenRenderbuffers( 1, @eglRenderbuffer );
  glBindRenderbuffer( GL_RENDERBUFFER, eglRenderbuffer );

  eglContext.renderbufferStorage_fromDrawable( GL_RENDERBUFFER, eglSurface );

  glFramebufferRenderbuffer( GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, eglRenderbuffer );

  {if oglCanFBODepth24 Then
     oglzDepth := 24
  else
     oglzDepth := 16;

  if oglzDepth > 0 Then
     begin
       case oglzDepth of
         16: glRenderbufferStorage( GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, oglWidth, oglHeight );
         24: glRenderbufferStorage( GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, oglWidth, oglHeight );
       end;
       glFramebufferRenderbuffer( GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, eglRenderbuffer );
     end;}
{$ENDIF}
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

  glCompressedTexImage2D := gl_GetProc( 'glCompressedTexImage2D' );
  oglCanPVRTC := gl_IsSupported( 'GL_IMG_texture_compression_pvrtc', oglExtensions );
  log_Add( 'GL_EXT_TEXTURE_COMPRESSION_PVRTC: ' + u_BoolToStr( oglCanPVRTC ) );

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
{$IFNDEF iOS}
  oglCanVSync := Assigned( eglSwapInterval );
  if oglCanVSync Then
    scr_SetVSync( scrVSync );
{$ELSE}
  oglCanVSync := FALSE;
{$ENDIF}
  log_Add( 'Support WaitVSync: ' + u_BoolToStr( oglCanVSync ) );
end;

{$IFDEF iOS}
class function zglCiOSEAGLView.layerClass : Pobjc_class;
begin
  Result := CAEAGLLayer.classClass;
end;
{$ENDIF}

end.
