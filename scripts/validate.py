#!/usr/bin/env python3
"""Valida os apps do Glass Store.

Regras: docs/SPEC.md. Saída não-zero em qualquer erro.
Dependência: pyyaml (pip install pyyaml).
"""

import datetime
import pathlib
import re
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
APPS_DIR = ROOT / "apps"

SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9_-]*$")
PINNED_IMAGE_RE = re.compile(r"^[^:\s/@]+/[^:\s@]+:[A-Za-z0-9._-]+(@sha256:[a-f0-9]{64})?$|^[^:\s@/]+:[A-Za-z0-9._-]+$")
CATEGORIES = {"multimedia", "productivity", "networking", "home", "security", "devops", "other"}
ARCHITECTURES = {"amd64", "arm", "arm64", "riscv64", "mips64"}
LOCALES = {"pt_br", "en_us"}


class Invalid(Exception):
    pass


def fail(app: str, message: str) -> None:
    raise Invalid(f"{app}: {message}")


def localized(value, app: str, field: str) -> str:
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, dict) and value:
        for key in ("pt_br", "en_us"):
            if isinstance(value.get(key), str) and value[key].strip():
                return value[key].strip()
        first = next(iter(value.values()))
        if isinstance(first, str):
            return first.strip()
    fail(app, f"x-glass.{field} deve ser string ou mapa localizado")


def check_asset_path(app_dir: pathlib.Path, value: str, app: str, field: str) -> None:
    if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*://", value):
        return
    target = (app_dir / value).resolve()
    try:
        target.relative_to(ROOT)
    except ValueError:
        fail(app, f"{field}: caminho escapa da pasta do app")
    if not target.exists():
        fail(app, f"{field}: arquivo inexistente {value}")


def validate_compose(path: pathlib.Path) -> None:
    app = path.parent.name
    if not SLUG_RE.match(app):
        fail(app, "nome de pasta fora do padrão")

    try:
        compose = yaml.safe_load(path.read_text())
    except yaml.YAMLError as error:
        fail(app, f"yaml inválido: {error}")

    if not isinstance(compose, dict):
        fail(app, "compose deve ser um mapa")
    name = compose.get("name")
    if not isinstance(name, str) or not SLUG_RE.match(name):
        fail(app, "top-level `name` ausente ou inválido")
    if name != app:
        fail(app, f"`name` ({name}) difere da pasta ({app})")

    services = compose.get("services")
    if not isinstance(services, dict) or not services:
        fail(app, "`services` precisa de ao menos um serviço")

    for service_name, service in services.items():
        if not isinstance(service, dict):
            fail(app, f"service `{service_name}` deve ser um mapa")
        image = service.get("image")
        if not isinstance(image, str) or ":latest" in image or not PINNED_IMAGE_RE.match(image):
            fail(app, f"imagem de `{service_name}` não está pinada: {image!r}")

    meta = compose.get("x-glass") or compose.get("x-casaos")
    is_casaos = "x-glass" not in compose and "x-casaos" in compose
    if not isinstance(meta, dict):
        fail(app, "bloco x-glass (ou x-casaos) ausente")

    for field in ("title", "description"):
        if not localized(meta.get(field), app, field):
            fail(app, f"{field} é obrigatório")
    tagline = localized(meta.get("tagline"), app, "tagline") if meta.get("tagline") else ""
    if is_casaos and not tagline:
        tagline = localized(meta.get("title"), app, "title")
    if len(tagline) > 160:
        fail(app, "tagline muito longa (>160)")

    if not isinstance(meta.get("developer"), str) or not meta["developer"].strip():
        fail(app, "developer é obrigatório")

    version = meta.get("version")
    if not isinstance(version, str) or not version.strip():
        fail(app, "version é obrigatório")

    category = meta.get("category")
    if is_casaos:
        category = str(category or "").strip().lower() or "other"
    if category not in CATEGORIES:
        fail(app, f"categoria inválida: {category!r}")

    architectures = meta.get("architectures") or []
    if not isinstance(architectures, list) or any(a not in ARCHITECTURES for a in architectures):
        fail(app, f"architectures inválidas: {architectures!r}")

    updated = meta.get("updatedAt") or meta.get("update_at")
    if updated:
        try:
            datetime.date.fromisoformat(str(updated))
        except ValueError:
            fail(app, f"updatedAt fora do formato YYYY-MM-DD: {updated!r}")

    entrypoint = meta.get("entrypoint") or {}
    main_service = entrypoint.get("main") or (meta.get("main") if is_casaos else None)
    if not isinstance(main_service, str) or main_service not in services:
        fail(app, f"entrypoint.main `{main_service}` não existe em services")

    port_map = entrypoint.get("portMap") or (meta.get("port_map") if is_casaos else None)
    if port_map is not None and not re.match(r"^\d+$", str(port_map)):
        fail(app, "portMap deve ser string numérica entre aspas")

    icon = meta.get("icon")
    if not isinstance(icon, str) or not icon.strip():
        fail(app, "icon é obrigatório")
    check_asset_path(path.parent, icon, app, "icon")

    background = meta.get("background") or meta.get("thumbnail")
    if isinstance(background, str) and background.strip():
        check_asset_path(path.parent, background, app, "background")

    screenshots = meta.get("screenshots") or meta.get("screenshot_link") or []
    if not isinstance(screenshots, list):
        fail(app, "screenshots deve ser lista")
    for screenshot in screenshots:
        if isinstance(screenshot, str):
            check_asset_path(path.parent, screenshot, app, "screenshots")

    requirements = meta.get("requirements") or {}
    if not isinstance(requirements, dict):
        fail(app, "requirements deve ser mapa")
    for row in requirements.values():
        if not isinstance(row, dict) or "minimum" not in row or "recommended" not in row:
            fail(app, "linhas de requirements exigem minimum/recommended")

    print(f"  ok  {app}")


def main() -> int:
    if not APPS_DIR.is_dir():
        print(f"diretório {APPS_DIR} não encontrado", file=sys.stderr)
        return 1

    manifests = sorted(APPS_DIR.glob("*/docker-compose.y*ml"))
    if not manifests:
        print("nenhum app encontrado em apps/", file=sys.stderr)
        return 1

    errors = []
    for manifest in manifests:
        try:
            validate_compose(manifest)
        except Invalid as error:
            errors.append(str(error))
        except Exception as error:  # noqa: BLE001
            errors.append(f"{manifest.parent.name}: erro inesperado {error}")

    if errors:
        print("\n".join(f"ERRO {error}" for error in errors), file=sys.stderr)
        print(f"\n{len(errors)} app(s) inválido(s)", file=sys.stderr)
        return 1

    print(f"{len(manifests)} app(s) válido(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
