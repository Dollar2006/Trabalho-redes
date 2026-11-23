variable "docker_host" {
  type        = string
  description = "Socket do Docker. Linux: unix:///var/run/docker.sock | Windows: npipe:////.//pipe//docker_engine"
  default     = "unix:///var/run/docker.sock"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "web_port" {
  type        = number
  description = "Porta do PC onde o Nginx publica o site."
  default     = 8080
}
