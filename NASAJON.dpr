program NASAJON;

uses
  Vcl.Forms,
  Uprincipal in 'codigoFonte\Principal\Uprincipal.pas' {Fprincipal},
  Interfaces in 'codigoFonte\Interfaces\Interfaces.pas',
  Implementations in 'codigoFonte\Implementations\Implementations.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFprincipal, Fprincipal);
  Application.Run;
end.
