unit Interfaces;

interface

uses
  System.Classes, System.Generics.Collections;

type
  TMunicipioInput = record
    Nome: String;
    Populacao: Integer;
  end;

  TMunicipioIBGE = record
    ID: Integer;
    Nome: String;
    UF: String;
    Regiao: String;
  end;

  TResultadoProcessamento = record
    MunicipioInput: String;
    PopulacaoInput: Integer;
    MunicipioIBGE: String;
    UF: String;
    Regiao: String;
    IdIBGE: Integer;
    Status: String;
  end;

  TEstatisticas = record
    TotalMunicipios: Integer;
    TotalOK: Integer;
    TotalNaoEncontrado: Integer;
    TotalErroAPI: Integer;
    PopTotalOK: Int64;
    MediasPorRegiao: TDictionary<string, Double>;
    constructor Create(ADummy: Integer);
  end;

  IFileReader = interface
    ['{A1B2C3D4-E5F6-4890-ABCD-EF1234567890}']
    function LerCSVInput(const AFileName: String): TList<TMunicipioInput>;
  end;

  IHttpClient = interface
    ['{B2C3D4E5-F6A7-4901-BCDE-F12345678901}']
    function ObterMunicipiosIBGE: TList<TMunicipioIBGE>;
    function EnviarResultadoParaAPI(const AStatsJSON: String): String;
  end;

  IMunicipioMatcher = interface
    ['{D4E5F6A7-B8C9-0123-DEF1-234567890123}']
    function Compatibilizar(const AInput: TMunicipioInput;
                   const AMunicipiosIBGE: TList<TMunicipioIBGE>): TResultadoProcessamento;
  end;

  IStatisticsCalculator = interface
    ['{E5F6A7B8-C9D0-1234-EF12-345678901234}']
    function Calcular(const AResultados: TList<TResultadoProcessamento>): TEstatisticas;
  end;

  IOutputGenerator = interface
    ['{F6A7B8C9-D0E1-2345-F123-456789012345}']
    procedure SalvarResultadoCSV(const AResultados: TList<TResultadoProcessamento>;
                                const AFileName: String);
    function GerarStatsJSON(const AStats: TEstatisticas): String;
  end;

implementation

{ TEstatisticas }

constructor TEstatisticas.Create(ADummy: Integer);
begin
  TotalMunicipios := 0;
  TotalOK := 0;
  TotalNaoEncontrado := 0;
  TotalErroAPI := 0;
  PopTotalOK := 0;
  MediasPorRegiao := TDictionary<String, Double>.Create;
end;

end.
