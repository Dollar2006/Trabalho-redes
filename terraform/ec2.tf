resource "aws_key_pair" "main" {
  key_name   = "${var.project}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# ---------- VPN (WireGuard) ----------
resource "aws_instance" "vpn" {
  ami                         = data.aws_ssm_parameter.ubuntu.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.vpn.id]
  key_name                    = aws_key_pair.main.key_name
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/vpn.sh.tftpl", {
    vpn_network   = local.vpn_network
    vpn_server_ip = local.vpn_server_ip
  })

  tags = { Name = "${var.project}-vpn" }
}

resource "aws_eip" "vpn" {
  instance = aws_instance.vpn.id
  domain   = "vpc"
}

# ---------- Banco (Postgres em Docker) ----------
resource "aws_instance" "db" {
  ami                         = data.aws_ssm_parameter.ubuntu.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.db.id]
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = true # só para baixar imagens; o SG bloqueia acesso externo
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/db.sh.tftpl", {
    repo_url    = var.repo_url
    db_password = var.db_password
  })

  tags = { Name = "${var.project}-db" }
}

# ---------- App: 1 instância com Nginx + 2 containers da aplicação ----------
resource "aws_instance" "app" {
  ami                         = data.aws_ssm_parameter.ubuntu.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = aws_key_pair.main.key_name
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/templates/app.sh.tftpl", {
    repo_url    = var.repo_url
    db_host     = aws_instance.db.private_ip
    db_password = var.db_password
  })

  tags = { Name = "${var.project}-app" }
}

resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"
}
