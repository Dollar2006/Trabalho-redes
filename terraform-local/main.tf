locals {
  apps = toset(["app1", "app2"]) # os nomes precisam bater com o upstream do nginx/nginx.conf
}

# ---------- Rede e volume ----------
resource "docker_network" "estoque" {
  name = "estoque-net"
}

resource "docker_volume" "pgdata" {
  name = "estoque-pgdata"
}

# ---------- Imagens ----------
resource "docker_image" "postgres" {
  name         = "postgres:16-alpine"
  keep_locally = true
}

resource "docker_image" "nginx" {
  name         = "nginx:alpine"
  keep_locally = true
}

resource "docker_image" "app" {
  name = "estoque-app:local"

  build {
    context = "${path.module}/../app"
    tag     = ["estoque-app:local"]
  }

  # rebuild automático quando qualquer arquivo da app mudar
  triggers = {
    app_sha = sha1(join("", [
      for f in sort(fileset("${path.module}/../app", "**")) :
      filesha1("${path.module}/../app/${f}")
    ]))
  }
}

# ---------- Banco ----------
resource "docker_container" "db" {
  name    = "estoque-db"
  image   = docker_image.postgres.image_id
  restart = "unless-stopped"

  env = [
    "POSTGRES_DB=estoque",
    "POSTGRES_USER=estoque",
    "POSTGRES_PASSWORD=${var.db_password}",
  ]

  volumes {
    volume_name    = docker_volume.pgdata.name
    container_path = "/var/lib/postgresql/data"
  }

  networks_advanced {
    name    = docker_network.estoque.name
    aliases = ["db"]
  }
}

# ---------- Aplicação (2 instâncias) ----------
resource "docker_container" "app" {
  for_each = local.apps

  name     = "estoque-${each.key}"
  hostname = each.key
  image    = docker_image.app.image_id
  restart  = "unless-stopped"

  env = [
    "DB_HOST=db",
    "DB_PORT=5432",
    "DB_NAME=estoque",
    "DB_USER=estoque",
    "DB_PASSWORD=${var.db_password}",
  ]

  networks_advanced {
    name    = docker_network.estoque.name
    aliases = [each.key]
  }

  depends_on = [docker_container.db]
}

# ---------- Nginx (load balancer) ----------
resource "docker_container" "nginx" {
  name    = "estoque-nginx"
  image   = docker_image.nginx.image_id
  restart = "unless-stopped"

  ports {
    internal = 80
    external = var.web_port
  }

  upload {
    file    = "/etc/nginx/conf.d/default.conf"
    content = file("${path.module}/../nginx/nginx.conf")
  }

  networks_advanced {
    name = docker_network.estoque.name
  }

  depends_on = [docker_container.app]
}
