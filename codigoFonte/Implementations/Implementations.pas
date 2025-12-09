unit Implementations;

interface

uses
  Interfaces, System.Classes, System.SysUtils, System.JSON,
  System.Generics.Collections, System.StrUtils, System.Math,
  REST.Client, REST.Types, Data.Bind.Components, Data.Bind.ObjectScope;

type
  TFileReader = class(TInterfacedObject, IFileReader)
  public
    function LerCSVInput(const AFileName: String): TList<TMunicipioInput>;
  end;

  THttpClient = class(TInterfacedObject, IHttpClient)
  private
    FRESTClient: TRESTClient;
    FRESTRequest: TRESTRequest;
    FRESTResponse: TRESTResponse;
  public
    constructor Create;
    destructor Destroy; override;
    function ObterMunicipiosIBGE: TList<TMunicipioIBGE>;
    function EnviarResultadoParaAPI(const AStatsJSON: String): String;
  end;

  TMunicipioMatcher = class(TInterfacedObject, IMunicipioMatcher)
  private
    function RemoverAcento(const AStr: String): String;
    function CalcularSimilaridade(const AStr1, AStr2: String): Double;
  public
    function Compatibilizar(const AInput: TMunicipioInput;
                   const AMunicipiosIBGE: TList<TMunicipioIBGE>): TResultadoProcessamento;
  end;

  TStatisticsCalculator = class(TInterfacedObject, IStatisticsCalculator)
  public
    function Calcular(const AResultados: TList<TResultadoProcessamento>): TEstatisticas;
  end;

  TOutputGenerator = class(TInterfacedObject, IOutputGenerator)
  public
    procedure SalvarResultadoCSV(const AResultados: TList<TResultadoProcessamento>;
                                const AFileName: String);
    function GerarStatsJSON(const AStats: TEstatisticas): String;
  end;

implementation

{ TFileReader }

function TFileReader.LerCSVInput(const AFileName: String): TList<TMunicipioInput>;
var
  LLines: TStringList;
  I: Integer;
  LParts: TArray<string>;
  LMunicipio: TMunicipioInput;
begin
  Result := TList<TMunicipioInput>.Create;
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(AFileName, TEncoding.UTF8);

    // Começa em 1 para pular cabeçalho
    for I := 1 to Pred(LLines.Count) do
    begin
      if Trim(LLines[I]) = EmptyStr then
        Continue;

      LParts := LLines[I].Split([',']);
      if Length(LParts) >= 2 then
      begin
        LMunicipio.Nome := Trim(LParts[0]);
        LMunicipio.Populacao := StrToIntDef(Trim(LParts[1]), 0);
        Result.Add(LMunicipio);
      end;
    end;
  finally
    LLines.Free;
  end;
end;

{ THttpClient }

constructor THttpClient.Create;
begin
  inherited;
  FRESTClient := TRESTClient.Create(nil);
  FRESTResponse := TRESTResponse.Create(nil);
  FRESTRequest := TRESTRequest.Create(nil);

  FRESTRequest.Client := FRESTClient;
  FRESTRequest.Response := FRESTResponse;
end;

destructor THttpClient.Destroy;
begin
  FRESTRequest.Free;
  FRESTResponse.Free;
  FRESTClient.Free;
  inherited;
end;

function THttpClient.ObterMunicipiosIBGE: TList<TMunicipioIBGE>;
var
  LJsonArray: TJSONArray;
  LJsonObj, LUFObj, LRegiaoObj: TJSONObject;
  LMunicipio: TMunicipioIBGE;
  I: Integer;
  LJsonValue: TJSONValue;
begin
  Result := TList<TMunicipioIBGE>.Create;
  try
    FRESTClient.BaseURL := 'https://servicodados.ibge.gov.br/api/v1/localidades';
    FRESTRequest.Resource := 'municipios';
    FRESTRequest.Method := TRESTRequestMethod.rmGET;
    FRESTRequest.Execute;

    LJsonValue := TJSONObject.ParseJSONValue(FRESTResponse.Content);
    if not Assigned(LJsonValue) then
      raise Exception.Create('Resposta da API inválida');

    if not (LJsonValue is TJSONArray) then
    begin
      LJsonValue.Free;
      raise Exception.Create('Resposta da API não é um array JSON');
    end;

    LJsonArray := LJsonValue as TJSONArray;
    try
      for I := 0 to Pred(LJsonArray.Count) do
      begin
        if not (LJsonArray.Items[I] is TJSONObject) then
          Continue;

        LJsonObj := LJsonArray.Items[I] as TJSONObject;

        LMunicipio.ID := 0;
        LMunicipio.Nome := EmptyStr;
        LMunicipio.UF := EmptyStr;
        LMunicipio.Regiao := EmptyStr;

        if LJsonObj.TryGetValue<Integer>('id', LMunicipio.ID) then
          LJsonObj.TryGetValue<string>('nome', LMunicipio.Nome);

        if LJsonObj.TryGetValue<TJSONObject>('microrregiao', LUFObj) then
        begin
          if LUFObj.TryGetValue<TJSONObject>('mesorregiao', LUFObj) then
          begin
            if LUFObj.TryGetValue<TJSONObject>('UF', LUFObj) then
            begin
              LUFObj.TryGetValue<string>('sigla', LMunicipio.UF);

              if LUFObj.TryGetValue<TJSONObject>('regiao', LRegiaoObj) then
                LRegiaoObj.TryGetValue<string>('nome', LMunicipio.Regiao);
            end;
          end;
        end;

        if (LMunicipio.ID > 0) and (LMunicipio.Nome <> EmptyStr) then
          Result.Add(LMunicipio);
      end;
    finally
      LJsonArray.Free;
    end;
  except
    on E: Exception do
    begin
      Result.Free;
      raise Exception.Create('Erro ao consultar API do IBGE: ' + E.Message);
    end;
  end;
end;

function THttpClient.EnviarResultadoParaAPI(const AStatsJSON: String): String;
var
  LAccessToken: String;
  LParam: TRESTRequestParameter;
begin
  LAccessToken := 'eyJhbGciOiJIUzI1NiIsImtpZCI6ImR0TG03UVh1SkZPVDJwZEciLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL215bnhsdWJ5a3lsbmNpbnR0Z2d1LnN1cGFiYXNlLmNvL2F1dGgvdjEiLCJzdWIiOiJkNWU1OTE0Ny01ODE2LTRmMmYtODUwNy00ZTg3ZjcxMGY5M2MiLCJhdWQiOiJhdXRoZW50aWNhdGVkIiwiZXhwIjoxNzY1MjI5MjMyLCJpYXQiOjE3NjUyMjU2MzIsImVtYWlsIjoicHJzY2huZWlkZXI5OEBnbWFpbC5jb20iLCJwaG9uZSI6IiIsImFwcF9tZXRhZGF0YSI6eyJwcm92aWRlciI6ImVtYWlsIiwicHJvdmlkZXJzIjpbImVtYWlsIl19LCJ1c2VyX21ldGFkYXRhIjp7ImVtYWlsIjoicHJzY2huZWlkZXI5OEBnbWFpbC5jb20iLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwibm9tZSI6IlBhdWxvIFJpY2FyZG8gRG9ybmVsbGVzIFNjaG5laWRlciIsInBob25lX3ZlcmlmaWVkIjpmYWxzZSwic3ViIjoiZDVlNTkxNDctNTgxNi00ZjJmLTg1MDctNGU4N2Y3MTBmOTNjIn0sInJvbGUiOiJhdXRoZW50aWNhdGVkIiwiYWFsIjoiYWFsMSIsImFtciI6W3sibWV0aG9kIjoicGFzc3dvcmQiLCJ0aW1lc3RhbXAiOjE3NjUyMjU2MzJ9XSwic2Vzc2lvbl9pZCI6ImMxZTEzYTAwLTkxNTItNDhlMS04YjNiLTFlNmQ0NmFkNjM5MCIsImlzX2Fub255bW91cyI6ZmFsc2V9.6G1EX8nYcrjsMpOHcrP4N9mu1MnTJMDDQkp3NeKp4zQ';
  Result := EmptyStr;
  
  try
    // Limpar requisição anterior
    FRESTRequest.Params.Clear;
    FRESTRequest.Body.ClearBody;
    
    // Configurar requisição
    FRESTClient.BaseURL := 'https://mynxlubykylncinttggu.supabase.co';
    FRESTRequest.Resource := 'functions/v1/ibge-submit';
    FRESTRequest.Method := TRESTRequestMethod.rmPOST;
    FRESTRequest.Accept := 'application/json';
    FRESTRequest.AcceptCharset := 'UTF-8';
    
    // Adicionar headers via Params com tipo pkHTTPHEADER
    LParam := FRESTRequest.Params.AddItem;
    LParam.Name := 'Authorization';
    LParam.Value := 'Bearer ' + LAccessToken;
    LParam.Kind := pkHTTPHEADER;
    LParam.Options := LParam.Options + [poDoNotEncode];

    LParam := FRESTRequest.Params.AddItem;
    LParam.Name := 'apikey';
    LParam.Value := LAccessToken;
    LParam.Kind := pkHTTPHEADER;
    LParam.Options := LParam.Options + [poDoNotEncode];
    
    // Adicionar o body com content-type correto
    FRESTRequest.AddBody(AStatsJSON, ctAPPLICATION_JSON);
    
    // Executar
    FRESTRequest.Execute;
    
    // Processar resposta: retornar apenas o score quando possível
    if FRESTResponse.StatusCode = 200 then
    begin
      var LJsonResp := TJSONObject.ParseJSONValue(FRESTResponse.Content) as TJSONObject;
      try
        if Assigned(LJsonResp) then
        begin
          if not LJsonResp.TryGetValue<String>('score', Result) then
            Result := FRESTResponse.Content; // fallback
        end
        else
          Result := FRESTResponse.Content;
      finally
        if Assigned(LJsonResp) then
          LJsonResp.Free;
      end;
    end
    else
      Result := 'Erro ' + IntToStr(FRESTResponse.StatusCode) + ': ' + FRESTResponse.StatusText + 
                ' - ' + FRESTResponse.Content;
  except
    on E: Exception do
      Result := 'Erro ao enviar: ' + E.Message;
  end;
end;

{ TMunicipioMatcher }

{ TMunicipioMatcher }

function TMunicipioMatcher.RemoverAcento(const AStr: String): String;
const
  ComAcento = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÌÍÎÏìíîïÙÚÛÜùúûüÿÑñÇç';
  SemAcento = 'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeIIIIiiiiUUUUuuuuyNnCc';
var
  I: Integer;
  LPos: Integer;
begin
  Result := UpperCase(Trim(AStr));

  for I := 1 to Length(Result) do
  begin
    LPos := Pos(Result[I], ComAcento);
    if LPos > 0 then
      Result[I] := SemAcento[LPos];
  end;
end;

function TMunicipioMatcher.CalcularSimilaridade(const AStr1, AStr2: String): Double;
var
  LNorm1, LNorm2: String;
  LDistancia, LMaxLen: Integer;
  I, J, LCost: Integer;
  LMatriz: array of array of Integer;
begin
  LNorm1 := RemoverAcento(AStr1);
  LNorm2 := RemoverAcento(AStr2);

  // Se são iguais, retorna 100%
  if LNorm1 = LNorm2 then
    Exit(1.0);

  if (Length(LNorm1) = 0) then
    Exit(0.0);
  if (Length(LNorm2) = 0) then
    Exit(0.0);

  // Algoritmo de Levenshtein (distância de edição)
  SetLength(LMatriz, Length(LNorm1) + 1, Length(LNorm2) + 1);

  for I := 0 to Length(LNorm1) do
    LMatriz[I, 0] := I;
  for J := 0 to Length(LNorm2) do
    LMatriz[0, J] := J;

  for I := 1 to Length(LNorm1) do
  begin
    for J := 1 to Length(LNorm2) do
    begin
      if LNorm1[I] = LNorm2[J] then
        LCost := 0
      else
        LCost := 1;

      LMatriz[I, J] := Min(
        Min(LMatriz[I-1, J] + 1,      // Deleção
            LMatriz[I, J-1] + 1),      // Inserção
        LMatriz[I-1, J-1] + LCost      // Substituição
      );
    end;
  end;

  LDistancia := LMatriz[Length(LNorm1), Length(LNorm2)];
  LMaxLen := Max(Length(LNorm1), Length(LNorm2));

  // Converte distância para similaridade (0 a 1)
  Result := 1.0 - (LDistancia / LMaxLen);
end;

function TMunicipioMatcher.Compatibilizar(const AInput: TMunicipioInput;
                                  const AMunicipiosIBGE: TList<TMunicipioIBGE>): TResultadoProcessamento;
var
  I: Integer;
  LNomeInputNormalizado: String;
  LNomeMunicipioNormalizado: String;
  LScore: Double;
  LMelhorScore: Double;
  LMelhorIndice: Integer;
  
  function PrioridadeUF(const AUF: String): Integer;
  begin
    // Retorna prioridade maior para UFs mais populosas/importantes
    if AUF = 'SP' then Exit(10);
    if AUF = 'RJ' then Exit(9);
    if AUF = 'MG' then Exit(8);
    if AUF = 'DF' then Exit(7);
    if AUF = 'PR' then Exit(6);
    if AUF = 'RS' then Exit(5);
    if AUF = 'BA' then Exit(4);
    if AUF = 'SC' then Exit(3);
    if AUF = 'PE' then Exit(2);
    Result := 1;
  end;
  
begin
  Result.MunicipioInput := AInput.Nome;
  Result.PopulacaoInput := AInput.Populacao;
  Result.MunicipioIBGE := EmptyStr;
  Result.UF := EmptyStr;
  Result.Regiao := EmptyStr;
  Result.IdIBGE := 0;
  Result.Status := 'NAO_ENCONTRADO';

  LNomeInputNormalizado := RemoverAcento(AInput.Nome);

  LMelhorScore := 0;
  LMelhorIndice := -1;
  
  for I := 0 to Pred(AMunicipiosIBGE.Count) do
  begin
    LNomeMunicipioNormalizado := RemoverAcento(AMunicipiosIBGE[I].Nome);

    if LNomeInputNormalizado = LNomeMunicipioNormalizado then
    begin
      // Match exato - mas pode haver múltiplos, escolher por prioridade de UF
      if LMelhorIndice < 0 then
        LMelhorIndice := I
      else if PrioridadeUF(AMunicipiosIBGE[I].UF) > PrioridadeUF(AMunicipiosIBGE[LMelhorIndice].UF) then
        LMelhorIndice := I;
    end;
  end;

  // Se encontrou match exato, retornar
  if LMelhorIndice >= 0 then
  begin
    Result.MunicipioIBGE := AMunicipiosIBGE[LMelhorIndice].Nome;
    Result.UF := AMunicipiosIBGE[LMelhorIndice].UF;
    Result.Regiao := AMunicipiosIBGE[LMelhorIndice].Regiao;
    Result.IdIBGE := AMunicipiosIBGE[LMelhorIndice].ID;
    Result.Status := 'OK';
    Exit;
  end;

  // Buscar por similaridade - pegar o melhor score >= 0.85
  LMelhorScore := 0;
  LMelhorIndice := -1;

  for I := 0 to Pred(AMunicipiosIBGE.Count) do
  begin
    LScore := CalcularSimilaridade(AInput.Nome, AMunicipiosIBGE[I].Nome);

    // Validação: a diferença de tamanho não pode ser maior que 2 caracteres
    // para evitar matches com typos muito graves como "Santoo Andre"
    if Abs(Length(AMunicipiosIBGE[I].Nome) - Length(AInput.Nome)) > 2 then
      Continue;

    if LScore >= 0.85 then
    begin
      // Priorizar matches com score mais alto
      if LScore > LMelhorScore then
      begin
        LMelhorScore := LScore;
        LMelhorIndice := I;
      end
      // Em caso de empate muito próximo (< 0.01), desempatar por UF
      else if (Abs(LScore - LMelhorScore) < 0.01) and (LMelhorIndice >= 0) then
      begin
        if PrioridadeUF(AMunicipiosIBGE[I].UF) > PrioridadeUF(AMunicipiosIBGE[LMelhorIndice].UF) then
        begin
          LMelhorIndice := I;
        end;
      end
      // Se empate menos próximo (< 0.05) e tamanho do nome é mais similar, considerar
      else if (Abs(LScore - LMelhorScore) < 0.05) and (LMelhorIndice >= 0) then
      begin
        // Preferir o que tem tamanho mais próximo ao input
        if (Abs(Length(AMunicipiosIBGE[I].Nome) - Length(AInput.Nome)) < 
            Abs(Length(AMunicipiosIBGE[LMelhorIndice].Nome) - Length(AInput.Nome))) or
           ((Abs(Length(AMunicipiosIBGE[I].Nome) - Length(AInput.Nome)) = 
             Abs(Length(AMunicipiosIBGE[LMelhorIndice].Nome) - Length(AInput.Nome))) and
            (PrioridadeUF(AMunicipiosIBGE[I].UF) > PrioridadeUF(AMunicipiosIBGE[LMelhorIndice].UF))) then
        begin
          LMelhorScore := LScore;
          LMelhorIndice := I;
        end;
      end;
    end;
  end;

  // Se encontrou um candidato válido
  if LMelhorIndice >= 0 then
  begin
    Result.MunicipioIBGE := AMunicipiosIBGE[LMelhorIndice].Nome;
    Result.UF := AMunicipiosIBGE[LMelhorIndice].UF;
    Result.Regiao := AMunicipiosIBGE[LMelhorIndice].Regiao;
    Result.IdIBGE := AMunicipiosIBGE[LMelhorIndice].ID;
    Result.Status := 'OK';
  end;
end;

{ TStatisticsCalculator }

function TStatisticsCalculator.Calcular(const AResultados: TList<TResultadoProcessamento>): TEstatisticas;
var
  I: Integer;
  LResultado: TResultadoProcessamento;
  LPopPorRegiao: TDictionary<String, Int64>;
  LCountPorRegiao: TDictionary<String, Integer>;
  LRegiao: String;
  LPop: Int64;
  LCount: Integer;
begin
  Result := TEstatisticas.Create(0);
  LPopPorRegiao := TDictionary<string, Int64>.Create;
  LCountPorRegiao := TDictionary<string, Integer>.Create;
  try
    Result.TotalMunicipios := AResultados.Count;

    for I := 0 to Pred(AResultados.Count) do
    begin
      LResultado := AResultados[I];

      if LResultado.Status = 'OK' then
      begin
        Inc(Result.TotalOK);
        Result.PopTotalOK := Result.PopTotalOK + LResultado.PopulacaoInput;

        // Acumular por região
        if LResultado.Regiao <> EmptyStr then
        begin
          if not LPopPorRegiao.TryGetValue(LResultado.Regiao, LPop) then
            LPop := 0;
          LPopPorRegiao.AddOrSetValue(LResultado.Regiao, LPop + LResultado.PopulacaoInput);

          if not LCountPorRegiao.TryGetValue(LResultado.Regiao, LCount) then
            LCount := 0;
          LCountPorRegiao.AddOrSetValue(LResultado.Regiao, LCount + 1);
        end;
      end
      else if LResultado.Status = 'NAO_ENCONTRADO' then
        Inc(Result.TotalNaoEncontrado)
      else if LResultado.Status = 'ERRO_API' then
        Inc(Result.TotalErroAPI);
    end;

    // Calcular médias por região
    for LRegiao in LPopPorRegiao.Keys do
    begin
      LPop := LPopPorRegiao[LRegiao];
      LCount := LCountPorRegiao[LRegiao];
      if LCount > 0 then
        Result.MediasPorRegiao.Add(LRegiao, LPop / LCount);
    end;
  finally
    LPopPorRegiao.Free;
    LCountPorRegiao.Free;
  end;
end;

{ TOutputGenerator }

procedure TOutputGenerator.SalvarResultadoCSV(const AResultados: TList<TResultadoProcessamento>;
                                              const AFileName: String);
var
  LLines: TStringList;
  I: Integer;
  LResultado: TResultadoProcessamento;
begin
  LLines := TStringList.Create;
  try
    // Cabeçalho
    LLines.Add('municipio_input,populacao_input,municipio_ibge,uf,regiao,id_ibge,status');

    // Dados
    for I := 0 to Pred(AResultados.Count) do
    begin
      LResultado := AResultados[I];
      LLines.Add(Format('%s,%d,%s,%s,%s,%d,%s', [
        LResultado.MunicipioInput,
        LResultado.PopulacaoInput,
        LResultado.MunicipioIBGE,
        LResultado.UF,
        LResultado.Regiao,
        LResultado.IdIBGE,
        LResultado.Status
      ]));
    end;

    LLines.SaveToFile(AFileName);
  finally
    LLines.Free;
  end;
end;

function TOutputGenerator.GerarStatsJSON(const AStats: TEstatisticas): String;
var
  LJson: TJSONObject;
  LStats: TJSONObject;
  LMedias: TJSONObject;
  LRegiao: String;
begin
  LJson := TJSONObject.Create;
  try
    LStats := TJSONObject.Create;
    LJson.AddPair('stats', LStats);

    LStats.AddPair('total_municipios', TJSONNumber.Create(AStats.TotalMunicipios));
    LStats.AddPair('total_ok', TJSONNumber.Create(AStats.TotalOK));
    LStats.AddPair('total_nao_encontrado', TJSONNumber.Create(AStats.TotalNaoEncontrado));
    LStats.AddPair('total_erro_api', TJSONNumber.Create(AStats.TotalErroAPI));
    LStats.AddPair('pop_total_ok', TJSONNumber.Create(AStats.PopTotalOK));

    LMedias := TJSONObject.Create;
    LStats.AddPair('medias_por_regiao', LMedias);

    for LRegiao in AStats.MediasPorRegiao.Keys do
      LMedias.AddPair(LRegiao, TJSONNumber.Create(AStats.MediasPorRegiao[LRegiao]));

    Result := LJson.ToJSON;
  finally
    LJson.Free;
  end;
end;

end.
