# Glass Store

Catálogo de aplicativos da [Glass Stack](https://github.com/ipetinate/glass-stack).

Cada aplicativo é um `docker-compose.yaml` padrão com um bloco de extensão
`x-glass` contendo os metadados que a loja usa para exibir, instalar e
atualizar o app. O daemon da Glass Stack sincroniza este repositório
periodicamente (ou sob demanda) e monta o catálogo local.

## Estrutura

```
apps/
└── jellyfin/
    ├── docker-compose.yaml   # compose real + metadados x-glass
    ├── icon.png              # 512×512 (opcional se usar URL)
    ├── background.webp       # hero 16:9 para destaque (opcional)
    └── screenshots/*.webp    # 2–5 imagens 16:9 (opcional)
docs/SPEC.md                  # especificação completa do x-glass
scripts/validate.py           # validador local
.github/workflows/validate.yml# valida todos os PRs
```

## Publicar um app

1. Crie a pasta `apps/<slug>/` (slug em minúsculas, `[a-z0-9_-]`).
2. Escreva o `docker-compose.yaml` com imagem **pinada** (nunca `:latest`).
3. Adicione o bloco `x-glass` com os metadados (veja [SPEC](docs/SPEC.md)).
4. Rode `python3 scripts/validate.py` localmente.
5. Abra o PR — o CI valida automaticamente.

Exemplo mínimo:

```yaml
name: uptime-kuma
services:
  uptime-kuma:
    image: louislam/uptime-kuma:1.23.16
    restart: unless-stopped
    ports:
      - "3001:3001"
    volumes:
      - /DATA/AppData/uptime-kuma/data:/app/data

x-glass:
  title:
    pt_br: Uptime Kuma
    en_us: Uptime Kuma
  tagline:
    pt_br: Monitor de disponibilidade self-hosted.
  description:
    pt_br: |
      Monitore sites e serviços com alertas...
  developer: Louis Lam
  category: devops
  tags: [Monitoring]
  architectures: [amd64, arm64]
  version: "1.23.16"
  updatedAt: "2026-08-24"
  icon: https://cdn.jsdelivr.net/gh/IceWhaleTech/CasaOS-AppStore@main/Apps/UptimeKuma/icon.png
  entrypoint:
    main: uptime-kuma
    index: /
    portMap: "3001"
    scheme: http
```

## Compatibilidade CasaOS

Compose files com bloco `x-casaos` são aceitos automaticamente — o parser
mapeia `title/tagline/description`, `icon/thumbnail/screenshot_link`,
`main/index/port_map/scheme`, `version/update_at`, etc. Veja o mapeamento
completo na [SPEC](docs/SPEC.md#casaos).

Isso significa que apontar a loja para o
[IceWhaleTech/CasaOS-AppStore](https://github.com/IceWhaleTech/CasaOS-AppStore)
também funciona.
