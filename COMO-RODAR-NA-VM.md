# Como rodar a API Tomada Vital na VM do Azure

Passo a passo para o Thiago. Tudo de **a** a **i** foi testado com estes arquivos na máquina do Diego em 10/11/2026 (Docker Desktop 4.88.1, Compose v5.4.0). **Na VM do Azure ainda não foi testado** (não há Azure nesta máquina).

## 0. Antes, no seu fork (uma vez só)

1. Copie para a **raiz** do fork os 6 arquivos: `Dockerfile`, `docker-compose.yml`, `.dockerignore`, `.env.example`, `deploy-azure.sh`, `destroy-azure.sh`. Faça commit e push.
   O `.env` (com as senhas) **nunca** vai para o Git: ele já está no `.gitignore` do projeto.
2. Troque o RM nos **dois** scripts, com o mesmo valor:
   - `deploy-azure.sh`, linha 6: `RM="RM000000"`
   - `destroy-azure.sh`, linha 4: `RM="RM000000"`

## 1. Criar a VM (no Azure Cloud Shell, modo Bash)

```bash
git clone https://github.com/<seu-usuario>/API-Tomada-Vital.git
cd API-Tomada-Vital
chmod +x deploy-azure.sh destroy-azure.sh
./deploy-azure.sh
```

No fim aparece `Pronto. IP publico: <IP>`. **Anote o IP.** Se o Azure recusar a região, troque `LOCAL="eastus2"` no script (ex.: `brazilsouth`, `eastus`). O script abre só as portas 22 (SSH) e 8080 (API). A 3306 do MySQL fica fechada para a internet de propósito: o SELECT é feito por `docker exec`.

## 2. Entrar na VM

```bash
ssh azureuser@<IP>
docker version
docker compose version
```

Se aparecer `permission denied ... docker.sock`, dê `exit` e entre de novo com o `ssh`: a permissão do grupo `docker` só vale a partir de um novo login.

## 3. Baixar o fork e criar o `.env` (dentro da VM)

```bash
git clone https://github.com/<seu-usuario>/API-Tomada-Vital.git
cd API-Tomada-Vital
cp .env.example .env
nano .env
```

Troque `DB_PASSWORD`, `DB_ROOT_PASSWORD` e `JWT_SECRET` (o JWT precisa ter **32 caracteres ou mais**; sem ele a API não sobe). Salve com Ctrl+O, Enter, Ctrl+X. **Não mostre o `.env` no vídeo.**
(Se o `git` não existir na VM: `sudo apt-get update && sudo apt-get install -y git`.)

## 4. Subir os containers

```bash
docker compose up -d --build
docker compose logs -f api
```

Espere a linha `Carga inicial: 12 usuários, 10 pacientes, 11 equipamentos, 10 ocorrências, 10 atendimentos` e saia do log com Ctrl+C (os containers continuam rodando). Na máquina do Diego o build levou 1min20; na VM (B2s) deve demorar mais.

⚠️ O `/actuator/health` responde `UP` uns 2 segundos **antes** dessa linha. Espere a linha da carga antes de testar.

## 5. Evidências para o professor (a até i)

Para **e** e **f**, rode no **Cloud Shell ou no seu PC**, usando o IP público. Assim fica provado que a API não roda só em localhost. O resto roda dentro da VM, na pasta `API-Tomada-Vital`.

**a) Containers rodando**
```bash
docker compose ps
```
Esperado: `tomadavital-api` **Up** e `tomadavital-db` **Up (healthy)**, portas `8080` e `3306`.

**b) Usuário, diretório de trabalho e estrutura**
```bash
docker exec tomadavital-api whoami
docker exec tomadavital-api pwd
docker exec tomadavital-api ls -la /app
```
Esperado: `tomadavital` (não é root), `/app`, e o `app.jar` pertencendo a `tomadavital`.

**c) Variáveis de ambiente**
```bash
docker exec tomadavital-api env | grep -E "SPRING_PROFILES_ACTIVE|TZ"
docker exec tomadavital-db env | grep -E "^(MYSQL_DATABASE|MYSQL_USER)="
```
Esperado: `SPRING_PROFILES_ACTIVE=docker`, `TZ=America/Sao_Paulo`, `MYSQL_DATABASE=tomadavital`, `MYSQL_USER=tomadavital`.
⚠️ Nunca rode `env` **sem** o `grep`: ele mostraria as senhas e o `JWT_SECRET`.

**d) Volume e rede**
```bash
docker volume ls
docker network ls
```
Esperado: o volume `tomadavital-dados` e a rede `tomadavital-net`.

**e) Login e fila, pelo IP público** (Cloud Shell ou PC)
```bash
IP=<ip-da-vm>
curl -u operador:123456 -X POST http://$IP:8080/autenticacao/login
TOKEN=$(curl -s -u operador:123456 -X POST http://$IP:8080/autenticacao/login | sed -E 's/.*"accessToken":"([^"]+)".*/\1/')
curl -s -H "Authorization: Bearer $TOKEN" http://$IP:8080/api/ocorrencias/fila | grep -o '"nomePaciente":"[^"]*"'
```
Esperado: o token (`"tokenType":"Bearer","expiresIn":3600`) e **7 nomes nesta ordem**: Lúcia, Maria, Raimundo, Antônia, Helena, José, Sebastião. (Mostre a fila **antes** do item f: depois da queda do TV-011 ela passa a ter 8.)
No navegador: `http://<IP>:8080/swagger-ui/index.html`.

**f) CRUD completo e uma queda nova** (Cloud Shell ou PC, mesmo `IP`)
```bash
TF=$(curl -s -u familia10:123456 -X POST http://$IP:8080/autenticacao/login | sed -E 's/.*"accessToken":"([^"]+)".*/\1/')
RESP=$(curl -s -w "\nHTTP %{http_code}" -X POST http://$IP:8080/api/pacientes -H "Authorization: Bearer $TF" -H "Content-Type: application/json" -d '{"nome":"Paciente Teste VM","bairro":"Centro","cidade":"Osasco","telefone":"(11) 90000-0099"}'); echo "$RESP"
PID=$(echo "$RESP" | grep -o '"id":[0-9]*' | cut -d: -f2); echo "PID=$PID"
curl -s -w "\nHTTP %{http_code}\n" -H "Authorization: Bearer $TF" http://$IP:8080/api/pacientes/$PID
curl -s -w "\nHTTP %{http_code}\n" -X PUT http://$IP:8080/api/pacientes/$PID -H "Authorization: Bearer $TF" -H "Content-Type: application/json" -d '{"nome":"Paciente Teste VM","bairro":"Jardim Bela Vista","cidade":"Osasco","telefone":"(11) 90000-0100"}'
curl -s -w "HTTP %{http_code}\n" -X DELETE -H "Authorization: Bearer $TF" http://$IP:8080/api/pacientes/$PID

TA=$(curl -s -u admin:123456 -X POST http://$IP:8080/autenticacao/login | sed -E 's/.*"accessToken":"([^"]+)".*/\1/')
curl -s -w "\nHTTP %{http_code}\n" -X POST http://$IP:8080/api/ocorrencias -H "Authorization: Bearer $TA" -H "Content-Type: application/json" -d '{"codigoDispositivo":"TV-011","bateriaPercentual":50}'
```
Esperado: POST **201**, GET **200**, PUT **200** (bairro mudou), DELETE **204**. A queda do TV-011 dá **201**, `"prioridade":"CRITICA"`, `"minutosRestantes":60`, e o `"inicio"` sai no **horário de Brasília** (é o `TZ` do compose).
Mandar a mesma queda de novo dá **400** "Já existe uma queda em aberto para o dispositivo TV-011". Isso é a regra de negócio, não é erro.

**g) SELECT direto no banco** (dentro da VM)
```bash
docker exec tomadavital-db sh -c 'mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -e "SHOW TABLES; SELECT id, nome, bairro FROM paciente; SELECT o.id, e.codigo_dispositivo, o.status FROM ocorrencia o JOIN equipamento e ON e.id = o.equipamento_id;"'
```
O comando usa as variáveis do próprio container, então a senha **não aparece na tela**.
Esperado: 10 tabelas (`atendimento`, `equipamento`, `ocorrencia`, `paciente`, `usuario` e as 5 `*_seq`), os 10 pacientes com acento certo, e o JOIN terminando em `11  TV-011  ABERTA` (a queda que a API acabou de gravar).
As tabelas `*_seq` são normais: o MySQL não tem `sequence`, então o Hibernate guarda o próximo id numa tabela. O aviso `[Warning] Using a password on the command line` também é normal.

**h) Persistência** (dentro da VM)
```bash
docker compose down
docker volume ls
docker compose up -d
docker compose logs -f api
```
⚠️ O `down` é **sem `-v`**: o `-v` apagaria o volume e os dados.
Esperado: depois do `down` o volume `tomadavital-dados` continua na lista; depois do `up`, o log diz `Carga inicial já existente` (Ctrl+C para sair). Rode o comando do item **g** de novo: o `TV-011 ABERTA` continua lá.

**i) Logs**
```bash
docker compose logs api --tail 30
docker compose logs api | grep -E "Started Application|Carga inicial"
docker compose logs api | grep -c " ERROR 1 "
```
Esperado: o último comando mostra `0` (nenhuma linha de erro). Os `WARN` do log são esperados: open-in-view, SpringDoc e AuthenticationProvider. Um deles termina com a palavra "to ERROR" (é só o texto do aviso), por isso o `grep` procura `" ERROR 1 "`, que é o nível do log.

## 6. Recomeçar ou apagar tudo

- **Recomeçar com os dados originais** (na VM): `docker compose down -v && docker compose up -d`. Isso apaga o volume, então faça só **depois** de mostrar a persistência.
- **Apagar a VM e tudo no Azure** (no Cloud Shell, na pasta do fork): `./destroy-azure.sh`. O script espera o Azure terminar e mostra `Grupo existe ainda? false`.

## O que cada evidência prova

| Item | O professor cobra | Onde está no arquivo |
|---|---|---|
| a | dois containers integrados, rodando em segundo plano, portas | `docker-compose.yml` (serviços `db` e `api`, `ports`, `up -d`) |
| b | usuário **não privilegiado**, WORKDIR, estrutura de diretórios, `docker exec` | `Dockerfile` (`useradd`, `USER tomadavital`, `WORKDIR /app`) |
| c | variáveis de ambiente da API e do banco | `Dockerfile` (`ENV`) e `docker-compose.yml` (`environment`, valores do `.env`) |
| d | volume **nomeado** e rede do compose | `docker-compose.yml` (`volumes:` e `networks:`) |
| e | API acessível de fora (não só localhost), login com JWT | `ports: "8080:8080"` + porta aberta pelo `deploy-azure.sh` |
| f | CRUD funcionando de ponta a ponta | a API gravando no MySQL pela rede `tomadavital-net` (`SPRING_DATASOURCE_URL` aponta para `db`) |
| g | SELECT direto no banco, tabelas relacionadas | o JOIN `ocorrencia` → `equipamento` pela FK `equipamento_id` |
| h | persistência | o volume `tomadavital-dados` em `/var/lib/mysql` sobrevive ao `down` |
| i | logs | `docker compose logs` |
| — | `depends_on` | a API só sobe quando o `healthcheck` do banco diz `healthy` (no item a: `Up (healthy)`) |
