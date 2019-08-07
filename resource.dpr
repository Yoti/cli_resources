{ ------------------------------------
  История изменений:
  0.1.0 - расшифровка файлов под xor
  0.2.0 - распаковка файлов под zlib
  0.3.0 - переименование и расширение
  0.3.1 - оптимизация кода дешифровки
  0.4.0 - распаковка сжатой таблицы
  0.5.0 - оптимизация кода сж. таблицы
  0.6.0 - распаковка без врем. файла
  0.7.0 - добавлено оформление проги
  0.8.0 - возможность указать output
  0.8.1 - убрано добавление расш. "gz"
 ------------------------------------ }

program resource;

{$APPTYPE CONSOLE}
{$R *.dres}

uses
  Classes,
  SysUtils,
  SysUtilsMy,
  Windows,
  ZLib;

const
  TitleStr: String = 'resources tool v0.8.1 by yoti';
  FileSign: AnsiString = #$64 + #$53 + '.resources';

type
  Header = Record
    Sign: Array[$00..$0B] of Byte;
    Count: Cardinal;
    unk1: Cardinal;
    whdrsz: Cardinal; // header + table size
    tbsize: Cardinal; // table size (packed)
    unsize: Cardinal; // table size (unpacked)
  end; // $20
  Table = Record
    size: Cardinal;
    offset: Cardinal;
    _type: Cardinal;
    unsize: Cardinal;
    _07dd: Cardinal;

    unk1: Cardinal;
    unk2: Cardinal;
    unk3: Cardinal;
    unk4: Cardinal;
    unk5: Cardinal;
  end; // $28

var
  ConsoleTitle: String;

function GetFileSign(const inFilePath: String): Cardinal;
var
  inFileStrm: TFileStream;
  c: Cardinal;
begin
  inFileStrm:=TFileStream.Create(inFilePath, fmOpenRead or fmShareDenyWrite);
  inFileStrm.Read(c, SizeOf(c));
  inFileStrm.Free;

  Result:=c;
end;

procedure UnXorMemStrm(MemStrm: TMemoryStream; const Key: Byte);
var
  tmpMemStrm: TMemoryStream;
  Read: Integer;
  Buf: Array[0..1023] of Byte;
  i: Integer;
begin
  tmpMemStrm:=TMemoryStream.Create;
  tmpMemStrm.CopyFrom(MemStrm, 0);
  tmpMemStrm.Seek(0, soFromBeginning);

  MemStrm.Clear;
  repeat
    Read:=tmpMemStrm.Read(Buf, SizeOf(Buf));

    for i:=0 to SizeOf(Buf) - 1
    do Buf[i]:=Buf[i] xor Key;

    MemStrm.Write(Buf, Read);
  until Read < 1024;

  MemStrm.Seek(0, soFromBeginning);
  tmpMemStrm.Free;
end;

procedure UnZLibMemStrm(MemStrm: TMemoryStream);
var
  tmpMemStrm: TMemoryStream;
  tmpDcmpStrm: TDecompressionStream;
begin
  tmpMemStrm:=TMemoryStream.Create;
  tmpDcmpStrm:=TDecompressionStream.Create(MemStrm);

  tmpMemStrm.CopyFrom(tmpDcmpStrm, 0);
  tmpMemStrm.Seek(0, soFromBeginning);
  tmpDcmpStrm.Free;

  MemStrm.Clear;
  MemStrm.CopyFrom(tmpMemStrm, tmpMemStrm.Size);
  MemStrm.Seek(0, soFromBeginning);
  tmpMemStrm.Free;
end;

procedure unpack(inFilePath, outDirPath: String);
var
  inMS: TMemoryStream;
  Head: Array of AnsiChar;
  Sign: AnsiString;
  tmpSL: TStringList;
  MyHeader: Header;
  tmpMS: TMemoryStream;
  Offset: Int64;
  i: Integer;
  b: Byte;
  s: String;
  MyTable: Table;
begin
  {$IFDEF RELEASE}
  if (outDirPath = '')
  then outDirPath:=ChangeFileExt(inFilePath, '');
  if (outDirPath[Length(outDirPath)] = '\')
  then outDirPath:=Copy(outDirPath, 1, Length(outDirPath)-1);
  {$ENDIF}

  if (ExtractFilePath(inFilePath) = '')
  then inFilePath:=ExtractFilePath(ParamStr(0)) + inFilePath;
  if (ExtractFilePath(outDirPath) = '')
  then outDirPath:=ExtractFilePath(inFilePath) + outDirPath;

  WriteLn('Input File: ' + ExtractFileName(inFilePath));
  WriteLn('Output Dir: ' + ExtractDirName(outDirPath));

  {$IFDEF RELEASE}
  if (DirectoryExists(outDirPath) = True) then begin
    WriteLn('error: output dir exists');
    ExitCode:=3;
    Exit;
  end;
  {$ENDIF}

  inMS:=TMemoryStream.Create;
  inMS.LoadFromFile(inFilePath);

  SetLength(Head, Length(FileSign));
  FillChar(Head[0], Length(Head), $00);
  inMS.Read(&Head[1], Length(Head));
  Sign:='';
  SetString(Sign, PAnsiChar(@Head[1]), Length(Head));
  if (Sign <> FileSign) then begin
    inMS.Free;
    WriteLn('error: wrong file header');
    ExitCode:=4;
    Exit;
  end;

  tmpSL:=TStringList.Create;

  inMS.Seek(0, soFromBeginning);
  FillChar(MyHeader, SizeOf(MyHeader), $00);
  inMS.Read(MyHeader, SizeOf(MyHeader));
  WriteLn('Count: ' + IntToStr(MyHeader.Count));

  tmpMS:=TMemoryStream.Create;
  tmpMS.CopyFrom(inMS, MyHeader.tbsize);
  tmpMS.Seek(0, soFromBeginning);

  if (MyHeader.tbsize <> MyHeader.unsize)
  then UnZLibMemStrm(tmpMS);

  for i:=1 to MyHeader.Count do begin
    s:='';
    repeat
      tmpMS.Read(b, SizeOf(b));
      s:=s + Chr(b);
    until b = $00;
    s:=Copy(s, 1, Length(s) - 1);
    s:=StringReplace(s, '/', '\', [rfReplaceAll]);
    tmpSL.Add(s);
  end;

  tmpMS.Free;

  for i:=1 to MyHeader.Count do begin
    FillChar(MyTable, SizeOf(MyTable), $00);
    inMS.Read(MyTable, SizeOf(MyTable));

    s:=outDirPath + '\' + tmpSL.Strings[i-1];
    ForceDirectories(ExtractFilePath(s));

    tmpMS:=TMemoryStream.Create;
    Offset:=inMS.Position;
    inMS.Seek(MyTable.offset, soFromBeginning);
    tmpMS.CopyFrom(inMS, MyTable.size);
    inMS.Seek(Offset, soFromBeginning);
    tmpMS.Seek(0, soFromBeginning);

    if (MyTable.size = MyTable.unsize) then begin // файл зашифрован
      UnXorMemStrm(tmpMS, $55);
      WriteLn(tmpSL.Strings[i-1] + ' (' + IntToStr(MyTable.size) + ')');
    end else if (MyTable.size <> MyTable.unsize) then begin // файл сжат
      UnZLibMemStrm(tmpMS);
      WriteLn(tmpSL.Strings[i-1] + ' (' + IntToStr(MyTable.unsize) + ')');
    end;

    tmpMS.SaveToFile(s);
    tmpMS.Free;
  end;

  tmpSL.Free;
  inMS.Free;
end;

begin
  ExitCode:=0;
  GetConsoleTitle(PChar(ConsoleTitle), MAX_PATH);
  SetConsoleTitle(PChar(ChangeFileExt(ExtractFileName(ParamStr(0)), '')));
  if (TitleStr <> '') then WriteLn(TitleStr);

  if (ParamCount < 1) then begin
    WriteLn('usage: ' + ExtractFileName(ParamStr(0)) + ' <input> [output]');
    ExitCode:=1;
  end else

  if (FileExists(ParamStr(1)) = False) then begin
    WriteLn('usage: ' + ExtractFileName(ParamStr(0)) + ' <input> [output]');
    ExitCode:=2;
  end else

  unpack(ParamStr(1), ParamStr(2));

  if (ExitCode = 0)
  then WriteLn('the job was done with success')
  else WriteLn('the job was done with failure');
  SetConsoleTitle(PChar(ConsoleTitle));
  Exit;
end.
