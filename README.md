# Projeto de estoque: EC2 única, Terraform local e acesso só por VPN

Uma EC2 na AWS roda o sistema inteiro e só pode ser acessada por VPN. O IP público pode ser divulgado, mas **ninguém de fora consegue acessar nada**: só quem tem a chave da VPN entra.

```
Notebook ─► VPN WireGuard (UDP 51820) ─► EC2 (10.8.0.1): SSH e site na porta 8080
Terceiros ─► IP público da EC2 ─► nada responde
Dentro da EC2: Nginx ─► app1 | app2 ─► Postgres (criados pelo Terraform + Docker)
```

**Por que ninguém de fora acessa:** o security group deixa aberta só a porta UDP 51820 (WireGuard), que não responde a quem não tem a chave. O SSH (porta 22) e o site (porta 8080) ficam fechados para a internet e só funcionam por dentro do túnel, no endereço `10.8.0.1`.

## O que tem no projeto

```
app/             aplicação Flask (Dockerfile, app.py, requirements.txt)
nginx/           nginx.conf (balanceamento entre app1 e app2)
terraform-local/ Terraform com provider Docker: rede, volume, Postgres, app1, app2 e Nginx
ec2/             setup-ec2.sh (instala Docker, Terraform e WireGuard na EC2)
                 novo-cliente.sh (cria o acesso VPN de um notebook ou celular)
```

## Passo a passo

### Fase 0: preparar o notebook (Windows ou Linux)

1. Instale Git e WireGuard.
   - Windows (PowerShell): `winget install Git.Git` e `winget install WireGuard.WireGuard`. Feche e abra o PowerShell.
   - Linux: `sudo apt install git wireguard`
2. Crie a chave SSH, se ainda não tiver (Enter nas perguntas):
   ```
   ssh-keygen -t ed25519
   ```
   Para ver a chave pública, que você vai colar na AWS:
   - Windows: `type $HOME\.ssh\id_ed25519.pub`
   - Linux: `cat ~/.ssh/id_ed25519.pub`
3. No GitHub, crie um repositório **público** chamado `projeto-infra-estoque`. A EC2 faz o `git clone` sem senha.
4. Na pasta do projeto, confirme que o arquivo `.gitattributes` existe (ele evita quebrar os scripts no Linux por causa do fim de linha do Windows). Se não existir, crie:
   - Windows: `Set-Content -Path .gitattributes -Value '* text=auto eol=lf'`
   - Linux: `echo '* text=auto eol=lf' > .gitattributes`
5. Envie o projeto ao GitHub (a pasta que contém `app/`, `ec2/` e `terraform-local/`):
   ```
   git config --global user.name 'Seu Nome'
   git config --global user.email 'seu@email.com'
   git init
   git add .
   git commit -m 'projeto de estoque'
   git branch -M main
   git remote add origin https://github.com/SEU_USUARIO/projeto-infra-estoque.git
   git push -u origin main
   ```
6. Confirme que nenhum segredo subiu. O resultado deve ser vazio:
   - Windows: `git ls-files | Select-String 'tfvars|tfstate|pem'`
   - Linux: `git ls-files | grep -E 'tfvars|tfstate|pem'`

### Fase A: criar a EC2 (console do AWS Academy)

7. No curso do AWS Academy, abra o **Learner Lab**, clique em **Start Lab**, espere a bolinha ficar verde e clique em **AWS** para abrir o console. Confira a região (normalmente us-east-1).
8. Importe a chave SSH: busque **EC2**, abra **Key pairs**, Actions, **Import key pair**, e cole o conteúdo do `id_ed25519.pub`.
9. Em EC2, clique em **Launch instance**:
   - Nome: `estoque`
   - Imagem: **Ubuntu Server 24.04 LTS**
   - Tipo: `t3.small` (2 GB de RAM; se não estiver liberado, use `t3.micro`)
   - Key pair: a que você importou
10. Em **Network settings**, clique em Edit, escolha **Create security group** com o nome `estoque-vpn` e deixe só estas duas regras de entrada:

    | Tipo | Porta | Origem |
    |---|---|---|
    | SSH | 22 | My IP (temporária, só para preparar) |
    | Custom UDP | 51820 | Anywhere (0.0.0.0/0) |

11. Em Storage, coloque 16 GiB e clique em **Launch instance**.
12. Crie um IP fixo: EC2, **Elastic IPs**, Allocate Elastic IP address, Allocate. Selecione o IP, Actions, **Associate Elastic IP address**, escolha a instância `estoque` e confirme. **Esse é o IP público fixo da instância.** Sem o IP elástico, o IP público muda toda vez que a instância é parada e a VPN do notebook quebra.

### Fase B: preparar a EC2

13. Conecte pelo notebook (PowerShell ou terminal Linux). Na primeira vez, digite `yes`:
    ```
    ssh ubuntu@IP_ELASTICO
    ```
14. Na EC2, baixe o projeto e rode o preparo (2 a 4 minutos):
    ```
    git clone https://github.com/SEU_USUARIO/projeto-infra-estoque.git
    cd projeto-infra-estoque
    sudo bash ec2/setup-ec2.sh
    ```
    Se o clone criou uma pasta dentro de outra, entre na que contém a pasta `ec2`. O script instala Docker, Terraform e WireGuard, sobe o servidor da VPN (`10.8.0.1`) e cria a senha do banco em `terraform-local/terraform.tfvars`.
15. Saia com `exit` e conecte de novo no SSH, para o grupo `docker` valer.

### Fase C: subir o sistema com o Terraform (na EC2)

16. Rode:
    ```
    cd projeto-infra-estoque/terraform-local
    terraform init
    terraform apply
    ```
    Digite `yes`.
17. Confira: `docker ps` deve listar 4 containers (db, app1, app2 e nginx) e `curl http://localhost:8080/health` deve responder `ok`.

### Fase D: VPN do notebook

18. Na EC2, gere o acesso do notebook (o `2` é o final do IP dele na VPN, `10.8.0.2`):
    ```
    cd ~/projeto-infra-estoque
    sudo bash ec2/novo-cliente.sh notebook 2
    ```
    Isso cria `~/clientes/notebook.conf`, já com o IP público da EC2.
19. No notebook, em outro terminal, copie o arquivo (o comando é o mesmo no Windows e no Linux):
    ```
    scp ubuntu@IP_ELASTICO:clientes/notebook.conf .
    ```
20. Ative o túnel.
    - **Windows:** no app WireGuard, **Import tunnel(s) from file**, escolha `notebook.conf` e clique em **Activate**.
    - **Linux:**
      ```
      sudo cp notebook.conf /etc/wireguard/aws.conf
      sudo chmod 600 /etc/wireguard/aws.conf
      sudo wg-quick up aws
      ```
      Para desligar: `sudo wg-quick down aws`.
21. Teste com a VPN ativa:
    - `ping 10.8.0.1` (no Linux, `ping -c 3 10.8.0.1`)
    - `ssh ubuntu@10.8.0.1`
    - No navegador, `http://10.8.0.1:8080`. Recarregue: app1 e app2 alternam.
22. Celular (opcional): na EC2, `sudo bash ec2/novo-cliente.sh celular 3` e `qrencode -t ansiutf8 < ~/clientes/celular.conf`. Escaneie o QR no app WireGuard (**+**, **Ler código QR**).

### Fase E: trancar o acesso

23. **Só depois de confirmar o SSH por `10.8.0.1` no passo 21**, abra no console EC2, Security Groups, `estoque-vpn`, Edit inbound rules, apague a regra do SSH (porta 22) e salve. Fica apenas a UDP 51820.
24. Prove que está fechado. Com a VPN **desativada**, `ssh ubuntu@IP_ELASTICO` deve dar timeout e `http://IP_ELASTICO:8080` não abre.
    - Windows: `Test-NetConnection IP_ELASTICO -Port 22` mostra `TcpTestSucceeded : False`
    - Linux: `nc -vz -w 3 IP_ELASTICO 22`

    Com a VPN **ativa**, `ssh ubuntu@10.8.0.1` continua funcionando.
25. Pronto: o IP elástico pode ser divulgado, e quem não tem a chave da VPN não consegue acessar.

Se ficar sem acesso por engano, adicione de novo a regra SSH com origem My IP no security group.

## Demonstração

- Mostre as regras de entrada do security group: só a UDP 51820.
- Tente o SSH no IP público a partir de uma rede sem a VPN e mostre o timeout.
- Com a VPN ativa, mostre o site em `10.8.0.1:8080`, o `docker ps` na EC2 e o Terraform: `docker rm -f estoque-app1`, depois `terraform plan` (detecta a falta) e `terraform apply` (recria).
- Explique por que o WireGuard não responde sem chave, por que o Terraform usa o provider Docker aqui e a limitação: uma EC2 só é ponto único de falha, e o site usa HTTP sem TLS.

## Encerrar

O Learner Lab para as instâncias quando a sessão acaba. Ao iniciar o laboratório de novo, a EC2 liga com o mesmo IP elástico e os containers voltam sozinhos. Ao terminar o trabalho: na EC2, `terraform destroy`; no console, **Terminate** na instância e **Release** no IP elástico.

## Problemas comuns

- **`permission denied` no Docker ou no Terraform:** você não saiu e entrou de novo no SSH depois do `setup-ec2.sh`.
- **O `scp` ou o SSH falha depois de trancar:** a regra 22 foi apagada. Adicione de novo com origem My IP, ou use o SSH por `10.8.0.1` com a VPN ativa.
- **Sem handshake na VPN:** confira se a UDP 51820 está aberta no security group, se o `Endpoint` do `.conf` é o IP elástico e se o laboratório está ligado.
- **Site não abre em `10.8.0.1:8080`:** na EC2, rode `docker ps` e `curl http://localhost:8080/health`.
- **Falta de memória no build:** use `t3.small`.
- **`bad interpreter` ao rodar um script:** o arquivo ficou com fim de linha do Windows. Confira o `.gitattributes` e envie de novo ao GitHub.
