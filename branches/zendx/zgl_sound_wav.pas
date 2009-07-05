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
unit zgl_sound_wav;

{$I zgl_config.cfg}

interface

uses
  {$IFDEF USE_OPENAL}
  zgl_sound_openal,
  {$ELSE}
  zgl_sound_dsound,
  {$ENDIF}
  zgl_types,
  zgl_file,
  zgl_memory;

const
  WAV_STANDARD  = $0001;
  WAV_IMA_ADPCM = $0011;
  WAV_MP3       = $0055;

type
  zglPWAVHeader = ^zglTWAVHeader;
  zglTWAVHeader = record
    RIFFHeader       : array[ 1..4 ] of Char;
    FileSize         : Integer;
    WAVEHeader       : array[ 1..4 ] of Char;
    FormatHeader     : array[ 1..4 ] of Char;
    FormatHeaderSize : Integer;
    FormatCode       : Word;
    ChannelNumber    : Word;
    SampleRate       : DWORD;
    BytesPerSecond   : DWORD;
    BytesPerSample   : Word;
    BitsPerSample    : Word;
 end;

procedure wav_Load( var Data : Pointer; var Size, Format, Frequency : DWORD );
procedure wav_LoadFromFile( const FileName : String; var Data : Pointer; var Size, Format, Frequency : DWORD );
procedure wav_LoadFromMemory( const Memory : zglTMemory; var Data : Pointer; var Size, Format, Frequency : DWORD );

implementation
uses
  zgl_main,
  zgl_log;

var
  wavMemory : zglTMemory;
  wavHeader : zglTWAVHeader;

procedure wav_Load;
  var
    chunkName : array[ 0..3 ] of Char;
    skip      : Integer;
begin
  mem_Read( wavMemory, wavHeader, SizeOf( zglTWAVHeader ) );

  Frequency := wavHeader.SampleRate;

{$IFDEF USE_OPENAL}
  if wavHeader.ChannelNumber = 1 Then
    case WavHeader.BitsPerSample of
      8:  format := AL_FORMAT_MONO8;
      16: format := AL_FORMAT_MONO16;
    end;

  if WavHeader.ChannelNumber = 2 then
    case WavHeader.BitsPerSample of
      8:  format := AL_FORMAT_STEREO8;
      16: format := AL_FORMAT_STEREO16;
    end;
{$ELSE}
  with wavHeader do
    begin
      BytesPerSample := ( BitsPerSample div 8 ) * ChannelNumber;
      BytesPerSecond := SampleRate * BytesPerSample;
    end;
  format := Ptr( @WavHeader.FormatCode );
{$ENDIF}

  mem_Seek( wavMemory, ( 8 - 44 ) + 12 + 4 + wavHeader.FormatHeaderSize + 4, FSM_CUR );
  repeat
    mem_Read( wavMemory, chunkName, 4 );
    if chunkName = 'data' then
      begin
        mem_Read( wavMemory, Size, 4 );
        if wavHeader.BitsPerSample = 8 then INC( Size );

        zgl_GetMem( Data, Size );
        mem_Read( wavMemory, Data^, Size );

        if wavHeader.FormatCode = WAV_IMA_ADPCM Then log_Add( 'Unsupported wav format - IMA ADPCM' );
        if wavHeader.FormatCode = WAV_MP3 Then       log_Add( 'Unsupported wav format - MP3' );
      end else
        begin
          mem_Read( wavMemory, skip, 4 );
          mem_Seek( wavMemory, skip, FSM_CUR );
        end;
  until wavMemory.Position >= wavMemory.Size;

  mem_Free( wavMemory );
end;

procedure wav_LoadFromFile;
begin
  mem_LoadFromFile( wavMemory, FileName );
  wav_Load( Data, Size, Format, Frequency );
end;

procedure wav_LoadFromMemory;
begin
  wavMemory.Size     := Memory.Size;
  zgl_GetMem( wavMemory.Memory, Memory.Size );
  wavMemory.Position := Memory.Position;
  Move( Memory.Memory^, wavMemory.Memory^, Memory.Size );
  wav_Load( Data, Size, Format, Frequency );
end;

initialization
  zgl_Reg( SND_FORMAT_EXTENSION, PChar( 'WAV' ) );
  zgl_Reg( SND_FORMAT_FILE_LOADER, @wav_LoadFromFile );
  zgl_Reg( SND_FORMAT_MEM_LOADER,  @wav_LoadFromMemory );

end.
