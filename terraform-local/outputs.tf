output "site_url" {
  value = "http://localhost:${var.web_port}"
}

output "containers" {
  value = concat(
    [docker_container.db.name, docker_container.nginx.name],
    [for c in docker_container.app : c.name]
  )
}
