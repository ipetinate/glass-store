# Especificação — bloco `x-glass`

Versão: `1` · Aplicável a `apps/<slug>/docker-compose.yaml`.

Um app da loja é um **docker-compose válido** (https://docs.docker.com/reference/compose-file/)
com um bloco de extensão top-level `x-glass`. O Compose ignora blocos `x-*`,
então o arquivo continua rodando em qualquer lugar com `docker compose up`.

## Identidade

- O campo top-level `name` do compose é o **id do app** na loja.
  Regex: `^[a-z0-9][a-z0-9_-]*$` e deve ser igual ao nome da pasta.
- A imagem do serviço principal deve estar **pinada** (tag específica ou digest).
  `:latest` e tags flutuantes são rejeitadas.

## Campos do `x-glass`

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `title` | texto \| localizado | sim | Nome exibido |
| `tagline` | texto \| localizado | sim | Frase curta (card, ≤120 chars) |
| `description` | texto \| localizado | sim | Descrição longa (tela de detalhe) |
| `developer` | string | sim | Autor original do app |
| `author` | string | não | Empacotador/ mantenedor do compose |
| `category` | enum | sim | `multimedia` \| `productivity` \| `networking` \| `home` \| `security` \| `devops` \| `other` |
| `tags` | string[] | não | Etiquetas livres exibidas coloridas no detalhe |
| `architectures` | enum[] | recomendado | Subconjunto de `amd64` `\|` `arm` `\|` `arm64` `\|` `riscv64` `\|` `mips64` |
| `version` | string | sim | Versão do app (seguir semver quando possível) |
| `updatedAt` | data | não | `YYYY-MM-DD`, alimenta ordenação "recentes" |
| `icon` | caminho \| URL | sim | Quadrado, fundo transparente, ≥256px |
| `background` | caminho \| URL | não | Imagem hero usada no destaque |
| `screenshots` | (caminho\|URL)[] | não | 2–5 imagens 16:9 |
| `website` / `source` / `docs` | URL | não | Links exibidos no detalhe |
| `entrypoint` | objeto | sim | Ver abaixo |
| `customInstall` | bool | não | Default `true`; habilita porta/volume customizados na instalação |
| `requirements` | objeto | não | Tabela mínimos/recomendados; sem ele a loja usa defaults |

### `entrypoint`

```yaml
entrypoint:
  main: jellyfin      # nome do service com UI web (deve existir em services)
  index: /            # path aberto pelo navegador
  portMap: "8096"     # porta web (string, entre aspas)
  scheme: http        # http | https
```

### `requirements`

```yaml
requirements:
  memory:
    minimum: 2GB
    recommended: 4GB+
  storage:
    minimum: 50GB
    recommended: 100GB+
  processor:
    minimum: Dual Core 64 bits
    recommended: Six Core ARM
```

Campos ausentes recebem defaults da loja (2GB/4GB+, 50GB/100GB+).

## Campos localizados

Qualquer campo textual aceita string simples ou mapa de locale:

```yaml
title: Jellyfin                    # simples
tagline:
  pt_br: Sua mídia, seu servidor.  # localizado
  en_us: Your media, your server.
```

Resolução: `pt_br` → `en_us` → primeiro valor disponível.

## Assets locais

Caminhos relativos (`./icon.png`) são resolvidos dentro da pasta do app.
O sincronizador baixa assets remotos (URLs) para o cache local do dispositivo;
falhas de download são toleradas (o app usa fallback gráfico).

Recomendações:

- `icon`: 512×512 PNG/SVG, fundo transparente
- `background`: 1920×1080 WEBP/JPG, ≤500KB
- `screenshots`: 1280×720+, WEBP/JPG, 2–5 arquivos

## Validação

- Local: `python3 scripts/validate.py`
- CI roda o mesmo script em todo PR
- O daemon revalida durante o sync; apps inválidos são ignorados com log

## CasaOS

Se o compose não tiver `x-glass` mas tiver `x-casaos`, o parser aplica o
seguinte mapeamento (CasaOS v2, top-level):

| `x-casaos` | `x-glass` equivalente |
|---|---|
| `id` (ou `name` do compose) | id |
| `title` / `tagline` / `description` (localizados) | idem |
| `icon` | `icon` |
| `thumbnail` | `background` |
| `screenshot_link` | `screenshots` |
| `developer` / `author` | idem |
| `category` | mapeado p/ enum da loja quando conhecido, senão `other` |
| `architectures` | idem (`amd64`→exibido como x86-64) |
| `version` / `update_at` | `version` / `updatedAt` |
| `website` / `repo` / `docs` / `support` | `website` / `source` / `docs` / `support` |
| `main` / `index` / `port_map` / `scheme` | `entrypoint.main/index/portMap/scheme` |

Blocos service-level `x-casaos` (descrições de ports/volumes/envs) são
aceitos e usados como dicas na instalação customizada; nunca obrigatórios.

## Versionamento da spec

Mudanças incompatíveis incrementam `specVersion` no validador e exigem
atualização simultânea do daemon. Campos novos devem ser opcionais.
