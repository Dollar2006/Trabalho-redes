import os
import socket
import time
from contextlib import closing

import psycopg2
from psycopg2.extras import RealDictCursor
from flask import Flask, redirect, render_template_string, request

app = Flask(__name__)

DB = dict(
    host=os.getenv("DB_HOST", "localhost"),
    port=int(os.getenv("DB_PORT", "5432")),
    dbname=os.getenv("DB_NAME", "estoque"),
    user=os.getenv("DB_USER", "estoque"),
    password=os.getenv("DB_PASSWORD", "estoque"),
    connect_timeout=5,
)


def run(sql, params=(), fetch=False):
    with closing(psycopg2.connect(**DB)) as conn:
        with conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, params)
            return cur.fetchall() if fetch else None


def init_db():
    for _ in range(30):  # o banco pode demorar a subir
        try:
            run("SELECT pg_advisory_xact_lock(42)")
            run(
                """CREATE TABLE IF NOT EXISTS produtos (
                       id SERIAL PRIMARY KEY,
                       nome TEXT NOT NULL,
                       quantidade INTEGER NOT NULL DEFAULT 0,
                       preco NUMERIC(10,2) NOT NULL DEFAULT 0
                   )"""
            )
            return
        except psycopg2.OperationalError:
            time.sleep(2)
        except psycopg2.errors.UniqueViolation:
            return  # outro worker criou ao mesmo tempo
    raise RuntimeError("Banco indisponível")


init_db()

PAGE = """
<!doctype html><html lang="pt-br"><meta charset="utf-8">
<title>Controle de Estoque</title>
<style>
 body{font-family:system-ui;max-width:760px;margin:2rem auto;padding:0 1rem}
 table{width:100%;border-collapse:collapse} th,td{padding:.5rem;border-bottom:1px solid #ddd;text-align:left}
 form.inline{display:inline} input{padding:.3rem} button{padding:.3rem .6rem;cursor:pointer}
 small{color:#666}
</style>
<h1>Controle de Estoque</h1>
<h2>Seja bem vindo!</h2>
<small>Atendido por: <b>{{ host }}</b> (recarregue e veja o load balancer alternar)</small>
<h3>Novo produto</h3>
<form method="post" action="/produtos">
 <input name="nome" placeholder="Nome" required>
 <input name="quantidade" type="number" min="0" value="0" required>
 <input name="preco" type="number" step="0.01" min="0" value="0" required>
 <button>Adicionar</button>
</form>
<h3>Produtos</h3>
<table>
 <tr><th>ID</th><th>Nome</th><th>Qtd</th><th>Preço</th><th>Ações</th></tr>
 {% for p in produtos %}
 <tr>
  <td>{{ p.id }}</td><td>{{ p.nome }}</td><td>{{ p.quantidade }}</td><td>R$ {{ p.preco }}</td>
  <td>
   <form class="inline" method="post" action="/produtos/{{ p.id }}/ajustar"><input type="hidden" name="delta" value="1"><button>+1</button></form>
   <form class="inline" method="post" action="/produtos/{{ p.id }}/ajustar"><input type="hidden" name="delta" value="-1"><button>-1</button></form>
   <form class="inline" method="post" action="/produtos/{{ p.id }}/remover"><button>Remover</button></form>
  </td>
 </tr>
 {% else %}<tr><td colspan="5">Nenhum produto.</td></tr>{% endfor %}
</table></html>
"""


@app.get("/")
def index():
    produtos = run("SELECT * FROM produtos ORDER BY id", fetch=True)
    return render_template_string(PAGE, produtos=produtos, host=socket.gethostname())


@app.post("/produtos")
def criar():
    run(
        "INSERT INTO produtos (nome, quantidade, preco) VALUES (%s, %s, %s)",
        (request.form["nome"], int(request.form["quantidade"]), request.form["preco"]),
    )
    return redirect("/")


@app.post("/produtos/<int:pid>/ajustar")
def ajustar(pid):
    run(
        "UPDATE produtos SET quantidade = GREATEST(quantidade + %s, 0) WHERE id = %s",
        (int(request.form["delta"]), pid),
    )
    return redirect("/")


@app.post("/produtos/<int:pid>/remover")
def remover(pid):
    run("DELETE FROM produtos WHERE id = %s", (pid,))
    return redirect("/")


@app.get("/health")
def health():
    return "ok", 200
