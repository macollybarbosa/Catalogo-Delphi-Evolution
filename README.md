# Catálogo Direct Evolution — Bypass de Ativação

Permite usar o **Catálogo Direct Evolution - América do Sul** (`CatalogoExpresso.exe`) sem uma chave de acesso válida, redirecionando as chamadas de validação para um servidor local.

## Instalação (duplo clique)

```
instalar.bat  ←  duplo clique, aceita UAC, feito
```

O instalador:
1. Edita o `hosts` file: `www.ideia2001.com.br → 127.0.0.1`
2. Configura port proxy: `:80 → :8080` (via netsh)
3. Instala **Windows Service** `CatalogoExpressoBypass` (início automático, sem login)
4. Instala `pywin32` via pip se necessário

## Desinstalação

```
desinstalar.bat  ←  duplo clique, aceita UAC, feito
```

## Como funciona

```
App → www.ideia2001.com.br:80
         ↓ hosts file
      127.0.0.1:80
         ↓ portproxy
      127.0.0.1:8080  ←  service.py (Windows Service)
         ├─ CadastraCliente.asp  →  "10"  (bypass: chave sempre válida)
         ├─ Vers2.asp            →  resposta local com data atual
         └─ tudo mais            →  proxy reverso → 189.113.2.50 (dados reais)
```

O catálogo permanece com dados reais e atualizados porque todos os outros endpoints são proxiados para o servidor original.

## Requisitos

- Windows 10/11
- Python 3.x com `pip` ([python.org](https://python.org), marque "Add Python to PATH")
- Conexão com a internet (para dados do catálogo via proxy)

## Arquivos

| Arquivo | Descrição |
|---------|-----------|
| `instalar.bat` | **Instalação — duplo clique** (auto-eleva para Admin) |
| `desinstalar.bat` | **Desinstalação — duplo clique** (auto-eleva para Admin) |
| `server.py` | Servidor de bypass standalone (porta 8080) |
| `service.py` | Wrapper Windows Service para server.py |
| `setup.ps1` | Script de setup chamado por instalar.bat |
| `uninstall.ps1` | Script de remoção chamado por desinstalar.bat |
| `installer.iss` | Script Inno Setup para gerar `.exe` installer |
| `service.log` | Log do serviço (criado na primeira execução) |

## Gerar instalador .exe (opcional)

Se tiver o [Inno Setup](https://jrsoftware.org/isinfo.php) instalado:

```bat
ISCC.exe installer.iss
```

Gera `Output\CatalogoBypass_Setup.exe` — instalador completo em único arquivo.

## Endpoints interceptados

| Endpoint | Comportamento |
|----------|---------------|
| `CadastraCliente.asp` | Retorna `10` (validação sempre bem-sucedida) |
| `Vers2.asp` | Retorna resposta com data/hora atual |
| Demais endpoints | Proxy reverso para `189.113.2.50` |
