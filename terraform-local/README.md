# Terraform local (provider Docker)

Mesmo ambiente do docker-compose (rede, volume, Postgres, app1, app2 e Nginx), criado pelo Terraform.

## Antes de começar
- Docker rodando.
- Pare o compose, para liberar a porta 8080: `docker compose down` (na raiz do projeto).
- Terraform instalado (`terraform -version`).

## Usar
```
cd terraform-local
cp terraform.tfvars.example terraform.tfvars    # Windows: copy terraform.tfvars.example terraform.tfvars
# edite a senha (e, no Windows, descomente a linha docker_host)
terraform init
terraform plan
terraform apply
```
Abra o `site_url` (http://localhost:8080) ou, pelo celular, http://10.8.0.1:8080 com a VPN ativa.

## Testes
- `docker ps`: deve listar estoque-db, estoque-app1, estoque-app2 e estoque-nginx.
- Recarregue o site: app1 e app2 alternam.
- Drift: `docker rm -f estoque-app1` e depois `terraform plan` (mostra que vai recriar) e `terraform apply` (recria).
- Mudança no código: edite algo em `app/` e rode `terraform apply` (rebuild da imagem e recriação das apps).
- `terraform destroy` remove containers, rede e volume (os dados do banco somem).

## Notas
- Se a porta 8080 estiver em uso, rode `terraform apply -var web_port=8081`.
- O firewall do Windows e a VPN seguem como no guia (o Terraform não mexe neles).
- O state (`terraform.tfstate`) guarda a senha do banco. Não suba para o Git.
