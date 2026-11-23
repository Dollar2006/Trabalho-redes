# Infra de Estoque (Terraform + AWS) — versão econômica

```
Internet ─► EC2 app [ Nginx ─► app1 | app2 ] ─► EC2 db (Postgres em Docker)
Você ─► EC2 VPN (WireGuard) ─► SSH nas EC2 app e db
```
3 instâncias EC2, sem ALB. O balanceamento é feito pelo Nginx (round-robin) dentro da EC2 da app.

## 1. Testar local (com balanceamento)
```
docker compose up --build      # http://localhost:8080 (recarregue: app1 / app2 alternam)
```

## 2. Subir pro GitHub
`terraform.tfvars`, `*.tfstate`, chaves e `vpn/clientes/` já estão no `.gitignore`.

## 3. Provisionar
```
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edite os valores
terraform init
terraform plan
terraform apply
```
Aguarde ~3 min (o `user_data` instala Docker, clona o repo e sobe o compose). Abra o `app_url`.

## 4. VPN
```
./vpn/gerar-config.sh <vpn_public_ip> ~/.ssh/id_ed25519 meu-notebook 2
```
Importe `vpn/clientes/meu-notebook.conf` no WireGuard, conecte e use `ssh ubuntu@<app_private_ip>`.

## 5. Destruir
```
terraform destroy
```

## Para explicar na apresentação
- Load balancing: Nginx reparte as requisições entre app1 e app2 (o nome no topo da página alterna).
- Limitação: se a EC2 da app cair, as duas caem juntas. Alta disponibilidade real = ALB + instâncias em AZs diferentes.
- Banco isolado em outra EC2; só a app e a VPN alcançam a porta 5432.
- SSH só pela VPN; a única porta pública da app é a 80.
- Segredos fora do Git; senha no `user_data`/state é aceitável só para estudo.

## Terraform local
A pasta `terraform-local/` cria app, banco e Nginx no próprio PC com o provider Docker (alternativa ao docker-compose). Veja o README dela.
