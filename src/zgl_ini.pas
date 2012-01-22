{
 *  Copyright © Kemka Andrey aka Andru
 *  mail: dr.andru@gmail.com
 *  site: http://zengl.org
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
unit zgl_ini;

{$I zgl_config.cfg}

interface
uses
  zgl_memory;

type
  zglPINIKey = ^zglTINIKey;
  zglTINIKey = record
    Hash  : LongWord;
    Name  : UTF8String;
    Value : UTF8String;
end;

type
  zglPINISection = ^zglTINISection;
  zglTINISection = record
    Hash : LongWord;
    Name : UTF8String;
    Keys : LongWord;
    Key  : array of zglTINIKey;
end;

type
  zglPINI = ^zglTINI;
  zglTINI = record
    FileName : UTF8String;
    Sections : Integer;
    Section  : array of zglTINISection;
end;

function  ini_LoadFromFile( const FileName : UTF8String ) : Boolean;
procedure ini_SaveToFile( const FileName : UTF8String );
procedure ini_Add( const Section, Key : UTF8String );
procedure ini_Del( const Section, Key : UTF8String );
procedure ini_Clear( const Section : UTF8String );
function  ini_IsSection( const Section : UTF8String ) : Boolean;
function  ini_IsKey( const Section, Key : UTF8String ) : Boolean;
function  ini_ReadKeyStr( const Section, Key : UTF8String ) : UTF8String;
function  ini_ReadKeyInt( const Section, Key : UTF8String ) : Integer;
function  ini_ReadKeyFloat( const Section, Key : UTF8String ) : Single;
function  ini_ReadKeyBool( const Section, Key : UTF8String ) : Boolean;
function  ini_WriteKeyStr( const Section, Key, Value : UTF8String ) : Boolean;
function  ini_WriteKeyInt( const Section, Key : UTF8String; Value : Integer ) : Boolean;
function  ini_WriteKeyFloat( const Section, Key : UTF8String; Value : Single; Digits : Integer = 2 ) : Boolean;
function  ini_WriteKeyBool( const Section, Key : UTF8String; Value : Boolean ) : Boolean;

procedure ini_CopyKey( var k1, k2 : zglTINIKey );
procedure ini_CopySection( var s1, s2 : zglTINISection );
function  ini_GetID( const S, K : UTF8String; var idS, idK : Integer ) : Boolean;
procedure ini_Process;
procedure ini_Free;

function _ini_ReadKeyStr( const Section, Key : UTF8String ) : PAnsiChar;

var
  iniRec : zglTINI;
  iniMem : zglTMemory;

implementation
uses
  zgl_file,
  zgl_utils;

function delSpaces( const str : UTF8String ) : UTF8String;
  var
    i, b, e : Integer;
begin
  b := 1;
  e := length( str );
  for i := 1 to length( str ) do
    if str[ i ] = ' ' Then
      INC( b )
    else
      break;

  for i := length( str ) downto 1 do
    if str[ i ] = ' ' Then
      DEC( e )
    else
      break;

  Result := copy( str, b, e - b + 1 );
end;

procedure addData( const str : UTF8String );
  var
    i, j, s, k, len : Integer;
begin
  if str = '' Then exit;
  if str[ 1 ] = ';' Then exit;
  len := length( str );

  if ( str[ 1 ] = '[' ) and ( str[ len ] = ']' ) Then
    begin
      INC( iniRec.Sections );
      s := iniRec.Sections - 1;

      SetLength( iniRec.Section, iniRec.Sections );

      iniRec.Section[ s ].Name := copy( str, 2, len - 2 );
      iniRec.Section[ s ].Name := delSpaces( iniRec.Section[ s ].Name );
      iniRec.Section[ s ].Hash := u_Hash( iniRec.Section[ s ].Name );
    end else
      begin
        s := iniRec.Sections - 1;
        if s < 0 Then exit;
        INC( iniRec.Section[ s ].Keys );
        k := iniRec.Section[ s ].Keys - 1;

        SetLength( iniRec.Section[ s ].Key, iniRec.Section[ s ].Keys );
        for i := 1 to len do
          if str[ i ] = '=' Then
            begin
              iniRec.Section[ s ].Key[ k ].Name := copy( str, 1, i - 1 );
              j := i;
              break;
            end;
        iniRec.Section[ s ].Key[ k ].Name := delSpaces( iniRec.Section[ s ].Key[ k ].Name );
        iniRec.Section[ s ].Key[ k ].Hash := u_Hash( iniRec.Section[ s ].Key[ k ].Name );

        iniRec.Section[ s ].Key[ k ].Value := copy( str, j + 1, len - j );
        iniRec.Section[ s ].Key[ k ].Value := delSpaces( iniRec.Section[ s ].Key[ k ].Value );
      end;
end;

function ini_LoadFromFile( const FileName : UTF8String ) : Boolean;
begin
  Result := FALSE;
  ini_Free();
  if not file_Exists( FileName ) Then exit;
  iniRec.FileName := u_CopyUTF8Str( FileName );

  mem_LoadFromFile( iniMem, FileName );
  ini_Process();
  mem_Free( iniMem );
  Result := TRUE;
end;

procedure ini_SaveToFile( const FileName : UTF8String );
  var
    f    : zglTFile;
    i, j : Integer;
    s    : UTF8String;
begin
  file_Open( f, FileName, FOM_CREATE );
  for i := 0 to iniRec.Sections - 1 do
    begin
      s := '[ ' + iniRec.Section[ i ].Name + ' ]' + #13#10;
      file_Write( f, s[ 1 ], length( s ) );
      for j := 0 to iniRec.Section[ i ].Keys - 1 do
        begin
          s := iniRec.Section[ i ].Key[ j ].Name + ' = ';
          file_Write( f, s[ 1 ], length( s ) );
          s := iniRec.Section[ i ].Key[ j ].Value + #13#10;
          file_Write( f, s[ 1 ], length( s ) );
        end;
      if i = iniRec.Sections - 1 Then break;
        begin
          s := #13#10;
          file_Write( f, s[ 1 ], 2 );
        end;
    end;
  file_Close( f );
end;

procedure ini_Add( const Section, Key : UTF8String );
  var
    s, k   : UTF8String;
    ns, nk : Integer;
begin
  s := u_CopyUTF8Str( Section );
  k := u_CopyUTF8Str( Key );

  ini_GetID( s, k, ns, nk );

  if ns = -1 Then
    begin
      INC( iniRec.Sections );
      ns := iniRec.Sections - 1;

      SetLength( iniRec.Section, iniRec.Sections );
      iniRec.Section[ ns ].Hash := u_Hash( s );
      iniRec.Section[ ns ].Name := s;
    end;

  if nk = -1 Then
    begin
      INC( iniRec.Section[ ns ].Keys );
      nk := iniRec.Section[ ns ].Keys - 1;

      SetLength( iniRec.Section[ ns ].Key, iniRec.Section[ ns ].Keys );
      iniRec.Section[ ns ].Key[ nk ].Hash := u_Hash( k );
      iniRec.Section[ ns ].Key[ nk ].Name := k;
    end;
end;

procedure ini_Del( const Section, Key : UTF8String );
  var
    s, k : UTF8String;
    i, ns, nk : Integer;
begin
  s := Section;
  k := Key;

  if ( k <> '' ) and ini_IsKey( s, k ) and ini_GetID( s, k, ns, nk ) Then
    begin
      DEC( iniRec.Section[ ns ].Keys );
      for i := nk to iniRec.Section[ ns ].Keys - 1 do
        ini_CopyKey( iniRec.Section[ ns ].Key[ i ], iniRec.Section[ ns ].Key[ i + 1 ] );
      SetLength( iniRec.Section[ ns ].Key, iniRec.Section[ ns ].Keys + 1 );
    end else
      if ini_IsSection( s ) Then
        begin
          ini_GetID( s, k, ns, nk );

          DEC( iniRec.Sections );
          for i := ns to iniRec.Sections - 1 do
            ini_CopySection( iniRec.Section[ i ], iniRec.Section[ i + 1 ] );
          iniRec.Section[ iniRec.Sections ].Keys := 0;
          SetLength( iniRec.Section, iniRec.Sections + 1 );
        end;
end;

procedure ini_Clear( const Section : UTF8String );
  var
    s : UTF8String;
    ns, nk : Integer;
begin
  s := Section;

  if s = '' Then
    begin
      for ns := 0 to iniRec.Sections - 1 do
        begin
          iniRec.Section[ ns ].Name := '';
          for nk := 0 to iniRec.Section[ ns ].Keys - 1 do
            begin
              iniRec.Section[ ns ].Key[ nk ].Name  := '';
              iniRec.Section[ ns ].Key[ nk ].Value := '';
            end;
          iniRec.Section[ ns ].Keys := 0;
          SetLength( iniRec.Section[ ns ].Key, 0 );
        end;
      iniRec.Sections := 0;
      SetLength( iniRec.Section, 0 );
    end else
      if ini_IsSection( s ) Then
        begin
          ini_GetID( s, '', ns, nk );

          for nk := 0 to iniRec.Section[ ns ].Keys - 1 do
            begin
              iniRec.Section[ ns ].Key[ nk ].Name  := '';
              iniRec.Section[ ns ].Key[ nk ].Value := '';
            end;
          iniRec.Section[ ns ].Keys := 0;
          SetLength( iniRec.Section[ ns ].Key, 0 );
        end;
end;

function ini_IsSection( const Section : UTF8String ) : Boolean;
  var
    s : UTF8String;
    i, j : Integer;
begin
  s := Section;

  i := -1;
  ini_GetID( s, '', i, j );
  Result := i <> -1;
end;

function ini_IsKey( const Section, Key : UTF8String ) : Boolean;
  var
    s, k : UTF8String;
    i, j : Integer;
begin
  s := Section;
  k := Key;

  Result := ini_GetID( s, k, i, j );
end;

function ini_ReadKeyStr( const Section, Key : UTF8String ) : UTF8String;
  var
    s, k : UTF8String;
    i, j : Integer;
begin
  Result := '';
  s := Section;
  k := Key;

  if ini_GetID( s, k, i, j ) Then
    Result := iniRec.Section[ i ].Key[ j ].Value;
end;

function ini_ReadKeyInt( const Section, Key : UTF8String ) : Integer;
  var
    s, k : UTF8String;
    i, j : Integer;
begin
  Result := 0;
  s := UTF8String( Section );
  k := UTF8String( Key );

  if ini_GetID( s, k, i, j ) Then
    Result := u_StrToInt( iniRec.Section[ i ].Key[ j ].Value );
end;

function ini_ReadKeyFloat( const Section, Key : UTF8String ) : Single;
  var
    s, k : UTF8String;
    i, j : Integer;
begin
  Result := 0;
  s := Section;
  k := Key;

  if ini_GetID( s, k, i, j ) Then
    Result := u_StrToFloat( iniRec.Section[ i ].Key[ j ].Value );
end;

function ini_ReadKeyBool( const Section, Key : UTF8String ) : Boolean;
  var
    s, k : UTF8String;
    i, j : Integer;
begin
  Result := FALSE;
  s := UTF8String( Section );
  k := UTF8String( Key );

  if ini_GetID( s, k, i, j ) Then
    Result := u_StrToBool( iniRec.Section[ i ].Key[ j ].Value );
end;

function ini_WriteKeyStr( const Section, Key, Value : UTF8String ) : Boolean;
  var
    s, k : UTF8String;
    i, j : Integer;
begin
  s := Section;
  k := Key;

  if ini_GetID( s, k, i, j ) Then
    begin
      iniRec.Section[ i ].Key[ j ].Value := u_CopyUTF8Str( Value );
      Result := TRUE;
    end else
      begin
        ini_Add( Section, Key );
        ini_WriteKeyStr( Section, Key, Value );
        Result := FALSE;
      end;
end;

function ini_WriteKeyInt( const Section, Key : UTF8String; Value : Integer ) : Boolean;
  var
    s, k : UTF8String;
    i, j : Integer;
begin
  s := Section;
  k := Key;

  if ini_GetID( s, k, i, j ) Then
    begin
      iniRec.Section[ i ].Key[ j ].Value := u_IntToStr( Value );
      Result := TRUE;
    end else
      begin
        ini_Add( Section, Key );
        ini_WriteKeyInt( Section, Key, Value );
        Result := FALSE;
      end;
end;

function ini_WriteKeyFloat( const Section, Key : UTF8String; Value : Single; Digits : Integer = 2 ) : Boolean;
  var
    s, k : UTF8String;
    i, j : Integer;
begin
  s := Section;
  k := Key;

  if ini_GetID( s, k, i, j ) Then
    begin
      iniRec.Section[ i ].Key[ j ].Value := u_FloatToStr( Value, Digits );
      Result := TRUE;
    end else
      begin
        ini_Add( Section, Key );
        ini_WriteKeyFloat( Section, Key, Value, Digits );
        Result := FALSE;
      end;
end;

function ini_WriteKeyBool( const Section, Key : UTF8String; Value : Boolean ) : Boolean;
  var
    s, k : UTF8String;
    i, j : Integer;
begin
  s := Section;
  k := Key;

  if ini_GetID( s, k, i, j ) Then
    begin
      iniRec.Section[ i ].Key[ j ].Value := u_BoolToStr( Value );
      Result := TRUE;
    end else
      begin
        ini_Add( Section, Key );
        ini_WriteKeyBool( Section, Key, Value );
        Result := FALSE;
      end;
end;

procedure ini_CopyKey( var k1, k2 : zglTINIKey );
begin
  k1.Hash  := k2.Hash;
  k1.Name  := k2.Name;
  k1.Value := k2.Value;
end;

procedure ini_CopySection( var s1, s2 : zglTINISection );
  var
    i : Integer;
begin
  s1.Hash := s2.Hash;
  s1.Name := s2.Name;
  s1.Keys := s2.Keys;
  SetLength( s1.Key, s1.Keys );
  for i := 0 to s1.Keys - 1 do
    ini_CopyKey( s1.Key[ i ], s2.Key[ i ] );
end;

function ini_GetID( const S, K : UTF8String; var idS, idK : Integer ) : Boolean;
  var
    h1, h2 : LongWord;
    i, j   : Integer;
begin
  idS := -1;
  idK := -1;
  h1  := u_Hash( S );
  h2  := u_Hash( K );

  Result := FALSE;
  for i := 0 to iniRec.Sections - 1 do
    if h1 = iniRec.Section[ i ].Hash Then
      begin
        idS := i;
        for j := 0 to iniRec.Section[ i ].Keys - 1 do
          if h2 = iniRec.Section[ i ].Key[ j ].Hash Then
            begin
              idK := j;
              Result := TRUE;
              exit;
            end;
        exit;
      end;
end;

procedure ini_Process;
  var
    c : AnsiChar;
    s : UTF8String;
    i : Integer;
begin
  s := '';
  for i := 0 to iniMem.Size - 1 do
    begin
      mem_Read( iniMem, c, 1 );
      if ( c <> #13 ) and ( c <> #10 ) Then
        s := s + c
      else
        begin
          addData( s );
          s := '';
        end;
    end;
  addData( s );
end;

procedure ini_Free;
begin
  iniRec.Sections := 0;
  SetLength( iniRec.Section, 0 );
end;

function _ini_ReadKeyStr( const Section, Key : UTF8String ) : PAnsiChar;
begin
  Result := u_GetPAnsiChar( ini_ReadKeyStr( Section, Key ) );
end;

end.
