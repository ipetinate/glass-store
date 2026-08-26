<div align="center">
  <img src="https://github.com/ipetinate/glass-stack/raw/main/docs/images/glass-stack.png" alt="Glass Stack" width="256" />
</div>

<h1 align="center">Glass Store</h1>

<p align="center">
  <em>App catalog for Glass Stack</em>
</p>

---

<div align="center">
  <a href="https://github.com/ipetinate/glass-store/actions"><img src="https://github.com/ipetinate/glass-store/actions/workflows/validate.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/ipetinate/glass-store/blob/main/LICENSE"><img src="https://img.shields.io/github/license/ipetinate/glass-store" alt="License"></a>
  <a href="https://github.com/ipetinate/glass-store/stargazers"><img src="https://img.shields.io/github/stars/ipetinate/glass-store" alt="Stars"></a>
</div>

---

## About

Glass Store is the official application catalog for [Glass Stack](https://github.com/ipetinate/glass-stack). It provides a curated collection of Docker-based applications ready to install on your server.

Each application is a standard `docker-compose.yaml` file with an `x-glass` extension block containing the metadata the store uses to display, install, and update apps. The Glass Stack daemon syncs this repository periodically (or on demand) and builds the local catalog.

### Features

- **Curated Catalog** — A growing collection of self-hosted applications vetted for quality and compatibility.
- **Standard Format** — Every app is a `docker-compose.yaml` with a consistent metadata schema (`x-glass`).
- **CasaOS Compatible** — Compose files with `x-casaos` blocks are parsed automatically, enabling compatibility with the [IceWhaleTech/CasaOS-AppStore](https://github.com/IceWhaleTech/CasaOS-AppStore).
- **CI Validated** — All PRs are automatically validated for correct structure and metadata.

## Structure

```
apps/
└── jellyfin/
    ├── docker-compose.yaml   # compose + x-glass metadata
    ├── icon.png              # 512x512 (optional if using URL)
    ├── background.webp       # 16:9 hero image (optional)
    └── screenshots/*.webp    # 2-5 16:9 images (optional)
docs/SPEC.md                  # full x-glass specification
scripts/validate.rb           # local validator
.github/workflows/validate.yml # validates all PRs
```

## Publishing an App

1. Create the folder `apps/<slug>/` (slug in lowercase, `[a-z0-9_-]`).
2. Write the `docker-compose.yaml` with a **pinned** image (never `:latest`).
3. Add the `x-glass` block with metadata (see [SPEC](docs/SPEC.md)).
4. Run `ruby scripts/validate.rb` locally.
5. Open the PR — CI validates automatically.

### Minimum Example

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
      Monitore sites e servicos com alertas...
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

## CasaOS Compatibility

Compose files with an `x-casaos` block are accepted automatically — the parser maps `title/tagline/description`, `icon/thumbnail/screenshot_link`, `main/index/port_map/scheme`, `version/update_at`, and more. See the full mapping in the [SPEC](docs/SPEC.md#casaos).

This means pointing the store to the
[IceWhaleTech/CasaOS-AppStore](https://github.com/IceWhaleTech/CasaOS-AppStore) also works.

## Useful Links

- [Glass Stack](https://github.com/ipetinate/glass-stack)
- [Glass Store SPEC](docs/SPEC.md)
- [GitHub Issues](https://github.com/ipetinate/glass-store/issues)
