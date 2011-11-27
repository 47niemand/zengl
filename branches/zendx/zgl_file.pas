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
unit zgl_file;

{$I zgl_config.cfg}

interface

uses
  Windows,
  {$IFDEF USE_ZIP}
  zgl_lib_zip,
  {$ENDIF}
  zgl_types;

type zglTFile = THandle;

type zglTFileList = zglTStringList;

const
  FILE_ERROR = Ptr( -1 );

  // Open Mode
  FOM_CREATE = $01; // Create
  FOM_OPENR  = $02; // Read
  FOM_OPENRW = $03; // Read&Write

  // Seek Mode
  FSM_SET    = $01;
  FSM_CUR    = $02;
  FSM_END    = $03;

function  file_Open( var FileHandle : zglTFile; const FileName : String; Mode : Byte ) : Boolean;
function  file_MakeDir( const Directory : String ) : Boolean;
function  file_Remove( const Name : String ) : Boolean;
function  file_Exists( const Name : String ) : Boolean;
function  file_Seek( FileHandle : zglTFile; Offset, Mode : Integer ) : LongWord;
function  file_GetPos( FileHandle : zglTFile ) : LongWord;
function  file_Read( FileHandle : zglTFile; var Buffer; Bytes : LongWord ) : LongWord;
function  file_Write( FileHandle : zglTFile; const Buffer; Bytes : LongWord ) : LongWord;
function  file_GetSize( FileHandle : zglTFile ) : LongWord;
procedure file_Flush( FileHandle : zglTFile );
procedure file_Close( var FileHandle : zglTFile );
procedure file_Find( const Directory : String; var List : zglTFileList; FindDir : Boolean );
function  file_GetName( const FileName : String ) : String;
function  file_GetExtension( const FileName : String ) : String;
function  file_GetDirectory( const FileName : String ) : String;
procedure file_SetPath( const Path : String );

{$IFDEF USE_ZIP}
function  file_OpenArchive( const FileName : String; const Password : String = '' ) : Boolean;
procedure file_CloseArchive;
{$ENDIF}

function _file_GetName( const FileName : String ) : PChar;
function _file_GetExtension( const FileName : String ) : PChar;
function _file_GetDirectory( const FileName : String ) : PChar;

implementation
uses
  zgl_main,
  zgl_utils;

var
  filePath : String = '';
  {$IFDEF USE_ZIP}
  zipCurrent : Pzip;
  {$ENDIF}

function GetDir( const Path : String ) : String;
  var
    len : Integer;
begin
  len := length( Path );
  if ( len > 0 ) and ( Path[ len ] <> '/' ) {$IFDEF WINDOWS} and ( Path[ len ] <> '\' ) {$ENDIF} Then
    Result := Path + '/'
  else
    Result := u_CopyStr( Path );
end;

function file_Open( var FileHandle : zglTFile; const FileName : String; Mode : Byte ) : Boolean;
begin
  {$IFDEF USE_ZIP}
  if Assigned( zipCurrent ) Then
    begin
      zgl_GetMem( Pointer( FileHandle ), SizeOf( zglZipFile ) );
      zglPZipFile( FileHandle ).file_ := zip_fopen( zipCurrent, PAnsiChar( filePath + FileName ), ZIP_FL_UNCHANGED );
      if not Assigned( zglPZipFile( FileHandle ).file_ ) Then
        zgl_FreeMem( Pointer( FileHandle ) )
      else
        zglPZipFile( FileHandle ).name := u_GetPAnsiChar( filePath + FileName );

      Result := FileHandle <> 0;
      if ( Mode = FOM_CREATE ) or ( Mode = FOM_OPENRW ) Then
        begin
          FileHandle := 0;
          Result := FALSE;
        end;
      exit;
    end;
  {$ENDIF}

  case Mode of
    FOM_CREATE: FileHandle := CreateFile( PChar( filePath + FileName ), GENERIC_READ or GENERIC_WRITE, 0, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0 );
    FOM_OPENR:  FileHandle := CreateFile( PChar( filePath + FileName ), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, 0, 0 );
    FOM_OPENRW: FileHandle := CreateFile( PChar( filePath + FileName ), GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0 );
  end;
  Result := FileHandle <> FILE_ERROR;
end;

function file_MakeDir( const Directory : String ) : Boolean;
begin
  {$IFDEF USE_ZIP}
  if Assigned( zipCurrent ) Then
    begin
      Result := FALSE;
      exit;
    end;
  {$ENDIF}

  Result := CreateDirectory( PChar( filePath + Directory ), nil );
end;

function file_Remove( const Name : String ) : Boolean;
  var
    attr : LongWord;
    i    : Integer;
    dir  : Boolean;
    path : String;
    list : zglTFileList;
begin
  {$IFDEF USE_ZIP}
  if Assigned( zipCurrent ) Then
    begin
      Result := FALSE;
      exit;
    end;
  {$ENDIF}

  if not file_Exists( Name ) Then
    begin
      Result := FALSE;
      exit;
    end;

  attr := GetFileAttributes( PChar( filePath + Name ) );
  dir  := attr and FILE_ATTRIBUTE_DIRECTORY > 0;

  if dir Then
    begin
      path := GetDir( Name );

      file_Find( path, list, FALSE );
      for i := 0 to list.Count - 1 do
        file_Remove( path + list.Items[ i ] );

      file_Find( path, list, TRUE );
      for i := 2 to list.Count - 1 do
        file_Remove( path + list.Items[ i ] );

      Result := RemoveDirectory( PChar( filePath + Name ) );
    end else
      Result := DeleteFile( PChar( filePath + Name ) );
end;

function file_Exists( const Name : String ) : Boolean;
  {$IFDEF USE_ZIP}
  var
    zipStat : Tzip_stat;
  {$ENDIF}
begin
  {$IFDEF USE_ZIP}
  if Assigned( zipCurrent ) Then
    begin
      Result := zip_stat( zipCurrent, PAnsiChar( Name ), 0, zipStat ) = 0;
      exit;
    end;
  {$ENDIF}
  Result := GetFileAttributes( PChar( filePath + Name ) ) <> $FFFFFFFF;
end;

function file_Seek( FileHandle : zglTFile; Offset, Mode : Integer ) : LongWord;
begin
  {$IFDEF USE_ZIP}
  if Assigned( zipCurrent ) Then
    begin
      Result := 0;
      exit;
    end;
  {$ENDIF}

  case Mode of
    FSM_SET: Result := SetFilePointer( FileHandle, Offset, nil, FILE_BEGIN );
    FSM_CUR: Result := SetFilePointer( FileHandle, Offset, nil, FILE_CURRENT );
    FSM_END: Result := SetFilePointer( FileHandle, Offset, nil, FILE_END );
  end;
end;

function file_GetPos( FileHandle : zglTFile ) : LongWord;
begin
  {$IFDEF USE_ZIP}
  if Assigned( zipCurrent ) Then
    begin
      Result := 0;
      exit;
    end;
  {$ENDIF}

  Result := SetFilePointer( FileHandle, 0, nil, FILE_CURRENT );
end;

function file_Read( FileHandle : zglTFile; var Buffer; Bytes : LongWord ) : LongWord;
begin
  {$IFDEF USE_ZIP}
  if Assigned( zipCurrent ) Then
    begin
      Result := zip_fread( zglPZipFile( FileHandle ).file_, Buffer, Bytes );
      exit;
    end;
  {$ENDIF}

  ReadFile( FileHandle, Buffer, Bytes, Result, nil );
end;

function file_Write( FileHandle : zglTFile; const Buffer; Bytes : LongWord ) : LongWord;
begin
  {$IFDEF USE_ZIP}
  if Assigned( zipCurrent ) Then
    begin
      Result := 0;
      exit;
    end;
  {$ENDIF}
  WriteFile( FileHandle, Buffer, Bytes, Result, nil );
end;

function file_GetSize( FileHandle : zglTFile ) : LongWord;
  {$IFDEF USE_ZIP}
  var
    zipStat : Tzip_stat;
  {$ENDIF}
begin
  {$IFDEF USE_ZIP}
  if Assigned( zipCurrent ) Then
    begin
      if zip_stat( zipCurrent, zglPZipFile( FileHandle ).name, 0, zipStat ) = 0 Then
        Result := zipStat.size;
      exit;
    end;
  {$ENDIF}

  Result := GetFileSize( FileHandle, nil );
end;

procedure file_Flush( FileHandle : zglTFile );
begin
  {$IFDEF USE_ZIP}
  if Assigned( zipCurrent ) Then exit;
  {$ENDIF}

  FlushFileBuffers( FileHandle );
end;

procedure file_Close( var FileHandle : zglTFile );
begin
  {$IFDEF USE_ZIP}
  if Assigned( zipCurrent ) Then
    begin
      zip_fclose( zglPZipFile( FileHandle ).file_ );
      zgl_FreeMem( Pointer( zglPZipFile( FileHandle ).name ) );
      zgl_FreeMem( Pointer( FileHandle ) );
      FileHandle := 0;
      exit;
    end;
  {$ENDIF}

  CloseHandle( FileHandle );
  FileHandle := FILE_ERROR;
end;

procedure file_Find( const Directory : String; var List : zglTFileList; FindDir : Boolean );
  var
    First : THandle;
    FList : WIN32_FIND_DATA;
  {$IFDEF USE_ZIP}
    count : Integer;
    name  : PAnsiChar;
    len   : Integer;
  {$ENDIF}
begin
  List.Count := 0;

  {$IFDEF USE_ZIP}
  if Assigned( zipCurrent ) Then
    begin
      for count := 0 to zip_get_num_entries( zipCurrent, ZIP_FL_UNCHANGED ) do
        begin
          name := zip_get_name( zipCurrent, count, ZIP_FL_UNCHANGED );
          len  := Length( name );
          if ( file_GetDirectory( name ) = Directory ) and ( ( FindDir and ( name[ len - 1 ] = '/' ) ) or ( ( not FindDir ) and ( name[ len - 1 ] <> '/' ) ) ) Then
            begin
              SetLength( List.Items, List.Count + 1 );
              List.Items[ List.Count ] := u_CopyStr( name );
              INC( List.Count );
            end;
        end;

      if List.Count > 2 Then
        u_SortList( List, 0, List.Count - 1 );
      exit;
    end;
  {$ENDIF}

  First := FindFirstFile( PChar( GetDir( filePath + Directory ) + '*' ), FList );
  repeat
    if FindDir Then
      begin
        if FList.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY = 0 Then continue;
      end else
        if FList.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY > 0 Then continue;
    SetLength( List.Items, List.Count + 1 );
    List.Items[ List.Count ] := FList.cFileName;
    INC( List.Count );
  until not FindNextFile( First, FList );
  FindClose( First );

  if List.Count > 2 Then
    u_SortList( List, 0, List.Count - 1 );
end;

procedure GetStr( const Str : String; var Result : String; const d : Char; const b : Boolean );
  var
    i, pos, l : Integer;
begin
  pos := 0;
  l := length( Str );
  for i := l downto 1 do
    if Str[ i ] = d Then
      begin
        pos := i;
        break;
      end;
  if b Then
    Result := copy( Str, 1, pos )
  else
    Result := copy( Str, l - ( l - pos ) + 1, ( l - pos ) );
end;

function file_GetName( const FileName : String ) : String;
  var
    tmp : String;
begin
  GetStr( FileName, Result, '/', FALSE );
  if Result = FileName Then
    GetStr( FileName, Result, '\', FALSE );
  GetStr( Result, tmp, '.', FALSE );
  if Result <> tmp Then
    Result := copy( Result, 1, length( Result ) - length( tmp ) - 1 );
end;

function file_GetExtension( const FileName : String ) : String;
  var
    tmp : String;
begin
  GetStr( FileName, tmp, '/', FALSE );
  if tmp = FileName Then
    GetStr( FileName, tmp, '\', FALSE );
  GetStr( tmp, Result, '.', FALSE );
  if tmp = Result Then
    Result := '';
end;

function file_GetDirectory( const FileName : String ) : String;
begin
  GetStr( FileName, Result, '/', TRUE );
  if Result = '' Then
    GetStr( FileName, Result, '\', TRUE );
end;

procedure file_SetPath( const Path : String );
begin
  filePath := GetDir( Path );
end;

{$IFDEF USE_ZIP}
function file_OpenArchive( const FileName : String; const Password : String = '' ) : Boolean;
  var
    error : Integer;
begin
  zipCurrent := zip_open( PAnsiChar( FileName ), 0, error );
  Result     := zipCurrent <> nil;
  if Password = '' Then
    zip_set_default_password( zipCurrent, nil )
  else
    zip_set_default_password( zipCurrent, PAnsiChar( Password ) );
end;

procedure file_CloseArchive;
begin
  zip_close( zipCurrent );
  zipCurrent := nil;
end;
{$ENDIF}

function _file_GetName( const FileName : String ) : PChar;
begin
  Result := u_GetPChar( file_GetName( FileName ) );
end;

function _file_GetExtension( const FileName : String ) : PChar;
begin
  Result := u_GetPChar( file_GetExtension( FileName ) );
end;

function _file_GetDirectory( const FileName : String ) : PChar;
begin
  Result := u_GetPChar( file_GetDirectory( FileName ) );
end;

end.
