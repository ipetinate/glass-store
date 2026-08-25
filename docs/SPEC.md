# Specification — `x-glass` block

Version: `1` · Applies to `apps/<slug>/docker-compose.yaml`.

A store app is a **valid docker-compose file** (https://docs.docker.com/reference/compose-file/)
with a top-level `x-glass` extension block. Compose ignores `x-*` blocks,
so the file still runs anywhere with `docker compose up`.

## Identity

- The top-level `name` field in the compose file is the **app id** in the store.
  Regex: `^[a-z0-9][a-z0-9_-]*$` and must match the folder name.
- The main service image must be **pinned** (specific tag or digest).
  `:latest` and floating tags are rejected.

## `x-glass` fields

| Field | Type | Required | Description |
|---|---|---|---|
| `title` | string \| localized | yes | Display name |
| `tagline` | string \| localized | yes | Short phrase (card, ≤120 chars) |
| `description` | string \| localized | yes | Long description (detail screen) |
| `developer` | string | yes | Original app author |
| `author` | string | no | Packager / compose maintainer |
| `category` | enum | yes | `multimedia` \| `productivity` \| `networking` \| `home` \| `security` \| `devops` \| `other` |
| `tags` | string[] | no | Free-form tags displayed as chips in the detail view |
| `architectures` | enum[] | recommended | Subset of `amd64` \| `arm` \| `arm64` \| `riscv64` \| `mips64` |
| `version` | string | yes | App version (follow semver when possible) |
| `updatedAt` | date | no | `YYYY-MM-DD`, powers the "recent" sort |
| `icon` | path \| URL | yes | Square, transparent background, ≥256px |
| `background` | path \| URL | no | Hero image used in the featured spot |
| `screenshots` | (path \| URL)[] | no | 2–5 images, 16:9 aspect ratio |
| `website` / `source` / `docs` | URL | no | Links shown in the detail view |
| `entrypoint` | object | yes | See below |
| `customInstall` | bool | no | Default `true`; enables custom port/volume during installation |
| `requirements` | object | no | Min/recommended specs table; if omitted the store uses defaults |

### `entrypoint`

```yaml
entrypoint:
  main: jellyfin      # service name with a web UI (must exist in services)
  index: /            # path opened by the browser
  portMap: "8096"     # web port (string, quoted)
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
    minimum: Dual Core 64-bit
    recommended: Six Core ARM
```

Missing fields receive store defaults (2GB/4GB+, 50GB/100GB+).

## Localized fields

Any text field accepts either a plain string or a locale map:

```yaml
title: Jellyfin                     # plain
tagline:
  pt_br: Sua mídia, seu servidor.   # localized
  en_us: Your media, your server.
```

Resolution order: `pt_br` → `en_us` → first available value.

## Local assets

Relative paths (`./icon.png`) are resolved inside the app folder.
The syncer downloads remote assets (URLs) to the device's local cache;
download failures are tolerated (the app falls back to a placeholder graphic).

Recommendations:

- `icon`: 512×512 PNG/SVG, transparent background
- `background`: 1920×1080 WEBP/JPG, ≤500KB
- `screenshots`: 1280×720+, WEBP/JPG, 2–5 files

## Validation

- Local: `ruby scripts/validate.rb`
- CI runs the same script on every PR
- The daemon revalidates during sync; invalid apps are skipped with a log entry

## CasaOS

If the compose file has no `x-glass` but has `x-casaos`, the parser applies
the following mapping (CasaOS v2, top-level):

| `x-casaos` | Equivalent `x-glass` |
|---|---|
| `id` (or compose `name`) | id |
| `title` / `tagline` / `description` (localized) | same |
| `icon` | `icon` |
| `thumbnail` | `background` |
| `screenshot_link` | `screenshots` |
| `developer` / `author` | same |
| `category` | mapped to store enum when known, otherwise `other` |
| `architectures` | same (`amd64` → displayed as x86-64) |
| `version` / `update_at` | `version` / `updatedAt` |
| `website` / `repo` / `docs` / `support` | `website` / `source` / `docs` / `support` |
| `main` / `index` / `port_map` / `scheme` | `entrypoint.main/index/portMap/scheme` |

Service-level `x-casaos` blocks (port/volume/env descriptions) are
accepted and used as hints during custom installation; never required.

## Spec versioning

Breaking changes increment `specVersion` in the validator and require a
simultaneous daemon update. New fields must be optional.
