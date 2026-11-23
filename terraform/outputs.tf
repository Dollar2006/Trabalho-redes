output "app_url" {
  value = "http://${aws_eip.app.public_ip}"
}

output "vpn_public_ip" {
  value = aws_eip.vpn.public_ip
}

output "app_private_ip" {
  value = aws_instance.app.private_ip
}

output "db_private_ip" {
  value = aws_instance.db.private_ip
}

output "gerar_cliente_vpn" {
  value = "./vpn/gerar-config.sh ${aws_eip.vpn.public_ip} ~/.ssh/id_ed25519 meu-notebook 2"
}
