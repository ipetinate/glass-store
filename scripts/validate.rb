#!/usr/bin/env ruby
# frozen_string_literal: true

# Valida os apps do Glass Store.
# Regras: docs/SPEC.md. Saída não-zero em qualquer erro.
# Sem dependências externas — usa apenas stdlib (yaml/psych).

require "yaml"
require "pathname"
require "date"

ROOT = Pathname.new(__dir__).expand_path.parent
APPS_DIR = ROOT / "apps"

SLUG_RE = /^[a-z0-9][a-z0-9_-]*$/
PINNED_IMAGE_RE = %r{^[^:\s/@]+/[^:\s@]+:[A-Za-z0-9._-]+(@sha256:[a-f0-9]{64})?$|^[^:\s@/]+:[A-Za-z0-9._-]+$}
CATEGORIES = %w[multimedia productivity networking home security devops other].to_set
ARCHITECTURES = %w[amd64 arm arm64 riscv64 mips64].to_set
LOCALES = %w[pt_br en_us].to_set

class Invalid < StandardError; end

def fail!(app, message)
  raise Invalid, "#{app}: #{message}"
end

def localized(value, app, field)
  case value
  when String then value.strip
  when Hash
    return nil if value.empty?
    %w[pt_br en_us].each do |key|
      v = value[key]
      return v.strip if v.is_a?(String) && !v.strip.empty?
    end
    first = value.values.first
    return first.strip if first.is_a?(String)
    fail!(app, "x-glass.#{field} deve ser string ou mapa localizado")
  else
    fail!(app, "x-glass.#{field} deve ser string ou mapa localizado")
  end
end

def check_asset_path(app_dir, value, app, field)
  return if value.match?(%r{^[a-zA-Z][a-zA-Z0-9+.-]*://})

  target = (app_dir / value).expand_path
  begin
    target.relative_path_from(ROOT)
  rescue ArgumentError
    fail!(app, "#{field}: caminho escapa da pasta do app")
  end
  fail!(app, "#{field}: arquivo inexistente #{value}") unless target.exist?
end

def validate_compose(path)
  app = path.dirname.basename.to_s
  fail!(app, "nome de pasta fora do padrão") unless app.match?(SLUG_RE)

  begin
    compose = YAML.safe_load_file(path.to_s, permitted_classes: [Date])
  rescue Psych::SyntaxError => error
    fail!(app, "yaml inválido: #{error}")
  end

  fail!(app, "compose deve ser um mapa") unless compose.is_a?(Hash)

  name = compose["name"]
  fail!(app, "top-level `name` ausente ou inválido") unless name.is_a?(String) && name.match?(SLUG_RE)
  fail!(app, "`name` (#{name}) difere da pasta (#{app})") if name != app

  services = compose["services"]
  unless services.is_a?(Hash) && !services.empty?
    fail!(app, "`services` precisa de ao menos um serviço")
  end

  services.each do |service_name, service|
    fail!(app, "service `#{service_name}` deve ser um mapa") unless service.is_a?(Hash)
    image = service["image"]
    unless image.is_a?(String) && !image.include?(":latest") && image.match?(PINNED_IMAGE_RE)
      fail!(app, "imagem de `#{service_name}` não está pinada: #{image.inspect}")
    end
  end

  meta = compose["x-glass"] || compose["x-casaos"]
  casaos = !compose.key?("x-glass") && compose.key?("x-casaos")
  fail!(app, "bloco x-glass (ou x-casaos) ausente") unless meta.is_a?(Hash)

  %w[title description].each do |f|
    fail!(app, "#{f} é obrigatório") unless localized(meta[f], app, f)
  end
  tagline = meta["tagline"] ? localized(meta["tagline"], app, "tagline") : ""
  tagline = localized(meta["title"], app, "title") if casaos && tagline.nil?
  fail!(app, "tagline muito longa (>160)") if tagline && tagline.length > 160

  developer = meta["developer"]
  fail!(app, "developer é obrigatório") unless developer.is_a?(String) && !developer.strip.empty?

  version = meta["version"]
  fail!(app, "version é obrigatório") unless version.is_a?(String) && !version.strip.empty?

  category = meta["category"]
  category = (category || "").to_s.strip.downcase
  category = "other" if category.empty? && casaos
  fail!(app, "categoria inválida: #{category.inspect}") unless CATEGORIES.include?(category)

  architectures = meta["architectures"] || []
  unless architectures.is_a?(Array) && (architectures - ARCHITECTURES.to_a).empty?
    fail!(app, "architectures inválidas: #{architectures.inspect}")
  end

  updated = meta["updatedAt"] || meta["update_at"]
  if updated
    begin
      Date.iso8601(updated.to_s)
    rescue ArgumentError
      fail!(app, "updatedAt fora do formato YYYY-MM-DD: #{updated.inspect}")
    end
  end

  entrypoint = meta["entrypoint"] || {}
  main_service = entrypoint["main"] || (casaos ? meta["main"] : nil)
  unless main_service.is_a?(String) && services.key?(main_service)
    fail!(app, "entrypoint.main `#{main_service}` não existe em services")
  end

  port_map = entrypoint["portMap"] || (casaos ? meta["port_map"] : nil)
  if port_map && !port_map.to_s.match?(/^\d+$/)
    fail!(app, "portMap deve ser string numérica entre aspas")
  end

  icon = meta["icon"]
  fail!(app, "icon é obrigatório") unless icon.is_a?(String) && !icon.strip.empty?
  check_asset_path(path.dirname, icon, app, "icon")

  background = meta["background"] || meta["thumbnail"]
  check_asset_path(path.dirname, background, app, "background") if background.is_a?(String) && !background.strip.empty?

  screenshots = meta["screenshots"] || meta["screenshot_link"] || []
  fail!(app, "screenshots deve ser lista") unless screenshots.is_a?(Array)
  screenshots.each do |s|
    check_asset_path(path.dirname, s, app, "screenshots") if s.is_a?(String)
  end

  requirements = meta["requirements"] || {}
  fail!(app, "requirements deve ser mapa") unless requirements.is_a?(Hash)
  requirements.each do |_, row|
    unless row.is_a?(Hash) && row.key?("minimum") && row.key?("recommended")
      fail!(app, "linhas de requirements exigem minimum/recommended")
    end
  end

  puts "  ok  #{app}"
end

def main
  unless APPS_DIR.directory?
    $stderr.puts "diretório #{APPS_DIR} não encontrado"
    exit 1
  end

  manifests = APPS_DIR.glob("*/docker-compose.y*ml").sort
  if manifests.empty?
    $stderr.puts "nenhum app encontrado em apps/"
    exit 1
  end

  errors = []
  manifests.each do |manifest|
    validate_compose(manifest)
  rescue Invalid => error
    errors << error.message
  rescue => error
    errors << "#{manifest.dirname.basename}: erro inesperado #{error}"
  end

  unless errors.empty?
    errors.each { |e| $stderr.puts "ERRO #{e}" }
    $stderr.puts "\n#{errors.length} app(s) inválido(s)"
    exit 1
  end

  puts "#{manifests.length} app(s) válido(s)"
end

main
