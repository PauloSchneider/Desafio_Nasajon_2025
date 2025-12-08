NASAJON – Desafio Técnico
====================================

Visão geral
-----------
Aplicação VCL (Delphi) que lê um CSV de municípios e populações, consulta a API pública do IBGE, faz o matching mais próximo por similaridade de nome e gera `resultado.csv` com o status de cada linha e estatísticas resumidas (também exibidas na tela).

Pré-requisitos
--------------
- Delphi - O projeto foi codificado na versão Delphi 12 Athens Comunity Edition.
- Acesso à internet para a API do IBGE (`https://servicodados.ibge.gov.br/api/v1/localidades/municipios`).

Como executar (GUI)
-------------------
1. Rode o executável `NASAJON.exe` ou Abra `NASAJON.dproj` no Delphi e compile.
3. Clique em "Selecionar" e escolha o CSV de entrada (UTF-8). Formato esperado (com cabeçalho):

	```csv
	municipio,populacao
   Niteroi,515317
   Sao Gonçalo,1091737
   Sao Paulo,12396372
   Belo Horzionte,2530701
   Florianopolis,516524
   Santo Andre,723889
   Santoo Andre,700000
   Rio de Janeiro,6718903
   Curitba,1963726
   Brasilia,3094325
	```

4. Clique em "Processar":
	- Baixa a lista completa de municípios do IBGE.
	- Faz matching e preenche a grade.
	- Salva `resultado.csv` na mesma pasta do arquivo de entrada.
	- Mostra estatísticas e o JSON correspondente em tela.

Saídas
------
- `resultado.csv`: `municipio_input,populacao_input,municipio_ibge,uf,regiao,id_ibge,status`.
- Estatísticas exibidas na tela e também serializadas em JSON (médias de população por região, totais e contagens de status).

Notas técnicas (decisões-chave)
-------------------------------
- **Client IBGE**: REST Client nativo do Delphi; simples GET em `/localidades/municipios`, parse em `TJSONArray`.
- **Normalização de nomes**: remove acentos e usa `UpperCase` antes de comparar.
- **Similaridade**: distância de Levenshtein convertida para score 0–1. Regra: match exato pós-normalização sai imediato; caso contrário, escolhe melhor score >= 0.92 como OK; entre 0.85 e 0.92 só aceita se não houver múltiplos similares. Empates >= 0.90 preferem regiões Sudeste/Sul.
- **Concorrência**: processamento roda em `TTask.Run` para não travar a UI; atualizações de progresso/status sincronizadas via `TThread.Synchronize`.
- **Estatísticas**: totais por status, soma de população dos OK e média de população por região; JSON gerado via `TJSONObject`.
- **Persistência**: `resultado.csv` salvo com cabeçalho e os campos originais + dados IBGE; entrada lida como UTF-8.

Arquivos principais
-------------------
- `codigoFonte/Principal/Uprincipal.pas`: formulário VCL, orquestra fluxo, progresso e UI.
- `codigoFonte/Implementations/Implementations.pas`: leitura CSV, client IBGE, matcher, estatísticas e geração de saída.
- `codigoFonte/Interfaces/Interfaces.pas`: contratos e records de dados.

Limitações atuais
-----------------
- Não há cache da lista do IBGE; cada processamento faz uma nova requisição.
- Similaridade depende apenas de nome; não há apoio geográfico ou por UF informado no input.
- Sem linha de comando; apenas interface gráfica.
