program TestPCG32Random;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  PCG32Random in 'PCG32Random.pas';

const
  cMaxValue = 20;

  procedure Test();
  var
    i:Integer;
  begin
    System.Writeln('32 bits values :');
    for i := 1 to cMaxValue do Writeln(PCG32_Random());

    System.Writeln('Dice values :');
    for i := 1 to cMaxValue do Writeln(PCG32_Random(6)+1);
  end;
begin
  try
    System.Writeln('Init with System Time...');
    PCG32_Randomize();

    Test();

    System.Writeln('Init with Windows GUID...');
    if PCG32_Randomize_GUID() then Test()
    else System.Writeln('Failed!');

    System.Writeln('Init with truly random raw bytes from www.random.org...');
    if PCG32_Randomize_Online() then Test()
    else System.Writeln('Failed!');

    System.Write('Done.. press <Enter> key to quit.');
    System.Readln;

  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
end.
