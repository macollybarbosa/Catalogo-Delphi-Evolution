# Catálogo Direct Evolution — Bypass de Ativação

Permite usar o **Catálogo Direct Evolution - América do Sul** (`CatalogoExpresso.exe`) sem uma chave de acesso válida, redirecionando as chamadas de validação para um servidor local.

## Como funciona

O aplicativo valida a chave de acesso via HTTP em `www.ideia2001.com.br`. O bypass:

1. Redireciona `www.ideia2001.com.br` → `127.0.0.1` via **hosts file**
2. Repassa a conexão da porta 80 para a porta 8080 via **netsh portproxy**
3. O **servidor Python** responde `10` (sucesso) para `CadastraCliente.asp` e faz **proxy reverso** de tudo mais para o IP real (`189.113.2.50`) — catálogo sempre atualizado

```
App → www.ideia2001.com.br:80
         ↓ (hosts file)
      127.0.0.1:80
         ↓ (portproxy)
      127.0.0.1:8080 (server.py)
         ├── CadastraCliente.asp  →  "10"  (bypass)
         ├── Vers2.asp            →  resposta local com data atual
         └── tudo mais            →  proxy → 189.113.2.50 (dados reais)
```

## Requisitos

- Python 3.x  
- Acesso de Administrador (apenas para o setup inicial)

## Instalação

```powershell
# Executar como Administrador:
.\setup.ps1
```

O setup:
- Adiciona entradas no `hosts`
- Configura o port proxy 80 → 8080
- Registra tarefa no Agendador de Tarefas para iniciar o servidor automaticamente no login

## Uso diário

Após o setup, o servidor inicia automaticamente no login. Para iniciar manualmente:

```bat
start.bat
```

O Catálogo pode ser aberto normalmente via `CallCatalogoExpresso.exe`.

## Desinstalar

```powershell
# Executar como Administrador:
.\uninstall.ps1
```

## Arquivos

| Arquivo | Descrição |
|---------|-----------|
| `server.py` | Servidor de bypass (porta 8080) |
| `setup.ps1` | Instalação — executa como Admin uma vez |
| `uninstall.ps1` | Remove todas as modificações |
| `start.bat` | Inicia o servidor manualmente |
| `server.log` | Log do servidor (criado na primeira execução) |

## Endpoints interceptados

| Endpoint | Comportamento |
|----------|---------------|
| `CadastraCliente.asp` | Retorna `10` (validação sempre bem-sucedida) |
| `Vers2.asp` | Retorna resposta com data/hora atual |
| Demais endpoints | Proxy reverso para `189.113.2.50` |
