# Runbook de clase: CI/CD con OpenTofu + GitHub Actions

**Duración: 50 minutos**
**Modo: Demo en pantalla del instructor**
**Sin tarea entregable**

---

## Antes de la clase (preparación del instructor)

**Crítico: hazlo el día anterior, no minutos antes.**

### 1. Bootstrap completo

```bash
git clone <este-repo> demo-cicd-tofu
cd demo-cicd-tofu/bootstrap

# Edita variables.tf con tu repo de GitHub real
# (default: "tu-usuario/demo-cicd-tofu" -> cambialo)
tofu init
tofu apply
# Anota los outputs.
```

### 2. Configurar proyecto principal

```bash
cd ..
# Edita backend.tf con el bucket del bootstrap
# Edita .github/workflows/tofu.yml con el role ARN del bootstrap
```

### 3. Push inicial al repo

```bash
git init
git add .
git commit -m "initial bootstrap done"
git remote add origin git@github.com:tu-usuario/demo-cicd-tofu.git
git push -u origin main
```

GitHub Actions correrá su primer apply automáticamente. **Espera a que termine**, ve los outputs en el log, copia el `api_url`. Pruébalo con curl. Si funciona, estás listo para clase.

### 4. Estado inicial en clase

Antes de empezar, abre estas 4 pestañas:

1. **Editor de código** con el repo abierto, archivo `.github/workflows/tofu.yml` visible
2. **Terminal** dentro del repo
3. **GitHub** en la pestaña Actions del repo
4. **AWS Console** en API Gateway o Lambda (algo visible que demuestre que ya existe)

### 5. Para la demo en clase

La demo central es: **modificar algo del código, abrir un PR, ver el plan, hacer merge, ver el apply**. Decide ANTES qué cambio vas a hacer. Sugerencias:

- Cambiar `CODE_LENGTH` de 6 a 8 en `lambda/handler.py`
- Agregar un endpoint `GET /health` que regrese `{"status": "ok"}`
- Cambiar `retention_in_days` del log group de 7 a 14

**Recomiendo el primero**: es el cambio más visible (el comportamiento cambia, los códigos pasan de 6 a 8 caracteres) y no toca infraestructura nueva.

---

## Estructura de la clase (50 min)

| Min | Bloque | Diapositiva mental |
|---|---|---|
| 0-5 | El problema y el patrón | "Hasta ahora aplicaron desde laptop. ¿Y si son 5 ingenieros?" |
| 5-15 | OIDC y por qué importa | "Cómo se autentica GitHub a AWS sin guardar secretos" |
| 15-30 | Recorrido del repo | El bootstrap, el workflow, el state remoto |
| 30-45 | LA DEMO: PR + merge | Cambio real + plan + apply automático |
| 45-50 | Próximos pasos en producción | Tu workflow real como teaser |

---

## Bloque 1 (0-5 min): El problema

### Lo que dices

"En la clase pasada cada uno de ustedes desplegó su Step Function corriendo `tofu apply` desde su laptop. Funcionó. Pero piensen en este escenario: trabajan en una empresa, son 5 ingenieros en el mismo proyecto.

- ¿Qué pasa si dos personas corren `tofu apply` al mismo tiempo? El state local se corrompe.
- ¿Qué pasa si Juan cambia algo en su laptop y se le olvida hacer push? Producción y código divergen.
- ¿Qué pasa si necesitan pasar las credenciales de AWS a un servidor de CI? ¿Las pegan como secrets? ¿Las rotan cada cuánto?

CI/CD con IaC resuelve los tres. Hoy vamos a ver el patrón canónico: **plan automático en pull requests, apply automático al hacer merge a main**. Y nos autenticamos con OIDC, sin guardar credenciales en ninguna parte."

### Lo que muestras

Solo tu cara y la pizarra/slide con esto:

```
Antes:                    Hoy:
laptop -> AWS             GitHub -> AWS
                          (via OIDC, sin keys)

state local               state remoto en S3
                          + locks en DynamoDB

manual: "tofu apply"      automatico: PR + merge
```

---

## Bloque 2 (5-15 min): OIDC explicado

Este es el bloque conceptual más denso. Explícalo bien o se confunden el resto de la clase.

### Lo que dices

"OIDC es la respuesta a una pregunta: ¿cómo le doy permisos a GitHub para entrar a mi cuenta AWS sin pegarle un access key?

Pensemos en access keys primero. Si los uso:
- Tengo que crearlos en mi cuenta AWS
- Pegarlos como secrets en GitHub
- Rotarlos cada 90 días (la mayoría no lo hace)
- Si se filtran, alguien puede entrar a mi AWS

OIDC le da la vuelta. El flujo es:

1. GitHub Actions, durante un workflow, le dice a GitHub: 'dame un token JWT firmado que pruebe que soy este repo en este branch'.
2. GitHub firma el token. Es de corta vida (15 min) y específico a este workflow.
3. Mi código manda ese token a AWS STS junto con un 'quiero asumir este rol'.
4. AWS verifica la firma del token contra un OIDC provider que YO configuré previamente. El provider conoce las llaves públicas de GitHub.
5. Si todo cuadra, AWS le devuelve credenciales temporales (también de corta vida).
6. El workflow usa esas credenciales para los siguientes 15 minutos. Cuando expiran, ya nadie las puede usar.

Beneficios:
- Cero secrets en GitHub
- Credenciales de corta vida, no las puedes filtrar accidentalmente
- Puedes restringir QUE workflow asume el rol: 'solo desde este repo, solo en main, solo en pull_request'"

### Lo que muestras

Abre `bootstrap/main.tf` en el editor. Ve directo al bloque de la trust policy:

```hcl
data "aws_iam_policy_document" "gha_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo}:ref:refs/heads/main",
        "repo:${var.github_repo}:pull_request",
      ]
    }
  }
}
```

Explica línea por línea:

- "`Federated` con el OIDC provider de GitHub: confío en tokens que vengan firmados por GitHub."
- "`aud = sts.amazonaws.com`: el audience claim. GitHub solo emite tokens con este audience cuando estamos pidiendo acceso a AWS específicamente. Es para que GitHub no se haga pasar por sí mismo en otros sistemas."
- "`sub` con `StringLike`: este es el más importante. Le digo: solo permite que asuman este rol los workflows que vengan del branch `main` o que sean pull requests, **de este repo específico**."

Y la moraleja: "Si alguien clona mi código a su repo y trata de correr GitHub Actions desde ahí, el `sub` no va a coincidir con el filtro y AWS rechaza la petición. Aunque el código sea idéntico."

---

## Bloque 3 (15-30 min): Recorrido del repo

### Lo que muestras (en orden)

#### 3.1 Estructura general (1 min)

```bash
ls -la
# .github/  bootstrap/  lambda/
# backend.tf  main.tf  iam.tf  variables.tf  outputs.tf
```

"Dos partes. La carpeta `bootstrap/` es la infra de la infra: se corrió una vez con `tofu apply` desde mi laptop, creó el bucket de state, el OIDC provider y el rol GHA. Eso fue ANTES de la clase."

"La raíz es el proyecto real: la API URL shortener. Esto lo despliega GitHub Actions."

#### 3.2 El backend remoto (3 min)

Abre `backend.tf`:

```hcl
backend "s3" {
  bucket         = "demo-cicd-tofu-state-a3f9b2c1"
  key            = "url-shortener/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "demo-cicd-tofu-locks"
  encrypt        = true
}
```

"En vez de un `terraform.tfstate` local, ahora vive en S3. El bucket lo creó el bootstrap. La tabla DynamoDB hace algo importante: locks. Cuando alguien corre `tofu apply`, escribe un registro en esa tabla diciendo 'estoy aplicando, espérense'. Si otro empieza al mismo tiempo, ve el lock y falla con un mensaje claro. Sin locks, el state se corrompería."

"Pregunta de comprensión: ¿quién creó el bucket de state si el state vive en el bucket?"

(Espera respuesta. Si nadie contesta, di:)

"El bootstrap. Que tiene state local. Es la única forma de romper el círculo: alguna parte tiene que vivir fuera del sistema. Por eso muchos equipos en producción usan herramientas como CloudFormation StackSets o scripts manuales solo para crear el primer bucket de state. De ahí en adelante, todo es OpenTofu/Terraform."

#### 3.3 La arquitectura (3 min)

Abre `main.tf` y muéstrales rápido:

- `aws_dynamodb_table.urls` — guarda los códigos
- `aws_s3_bucket.logs` — para analytics (logs de visitas)
- `aws_lambda_function.url_handler` — la lógica
- `aws_apigatewayv2_api.api` — el API público

"4 servicios AWS. Una arquitectura serverless típica. No es el foco de la clase pero quería algo más realista que solo un bucket."

#### 3.4 EL WORKFLOW (8 min)

Este es el bloque clave. Abre `.github/workflows/tofu.yml`:

```yaml
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
```

"Dos triggers: pull request a main, y push a main."

```yaml
permissions:
  id-token: write
  contents: read
```

"`id-token: write` es lo que le permite a GitHub Actions pedir el token OIDC. Sin este permiso, OIDC no funciona aunque el rol esté bien configurado. **Este es el error más común**, anótenlo."

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ env.AWS_ROLE }}
    aws-region: ${{ env.AWS_REGION }}
    role-session-name: gha-${{ github.run_id }}
```

"Esta es la action oficial de AWS. Hace todo el flow OIDC que les expliqué hace rato: pide el token, llama a STS, deja credenciales temporales en variables de entorno. Las siguientes acciones de OpenTofu las usan automáticamente."

```yaml
- name: tofu apply
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  run: tofu apply -no-color -auto-approve tfplan
```

"Y aquí el patrón canon: **apply solo si el evento es push a main**. En PRs, este step se brinca. Lo importante es que el plan corre **siempre**, así que en un PR ves QUE va a pasar antes de mergear."

---

## Bloque 4 (30-45 min): LA DEMO

Aquí pasas de explicar a hacer. Sigue este script al pie de la letra.

### 4.1 Crear branch y hacer cambio (2 min)

En tu terminal:

```bash
git checkout -b demo/codigo-mas-largo

# Edita lambda/handler.py: cambia CODE_LENGTH de 6 a 8
# (lo haces visible en la pantalla, comentando "este es nuestro cambio")
```

```bash
git add lambda/handler.py
git commit -m "make codes 8 chars long"
git push -u origin demo/codigo-mas-largo
```

### 4.2 Abrir PR (2 min)

Ve a GitHub. Verás el banner amarillo "Compare & pull request". Click. Pon un título descriptivo. Click "Create pull request".

**Inmediatamente** ve a la pestaña Actions del repo.

### 4.3 Mientras corre el workflow (5 min)

Esto va a tomar 60-90 segundos. **No te quedes callado**. Aprovecha:

"Mientras corre, déjenme explicarles qué está haciendo en este momento.

1. GitHub está creando una VM efímera de Ubuntu solo para nosotros.
2. Ahí descarga nuestro código (`actions/checkout`).
3. Le pide a GitHub OIDC un token JWT.
4. Llama a AWS STS con ese token y dice 'asume el rol'.
5. AWS le devuelve credenciales temporales válidas por 15 min.
6. Descarga OpenTofu.
7. Hace `tofu init` que conecta al bucket de state.
8. Hace `tofu plan`.

Cuando termine, vamos a abrir los logs y ver paso a paso lo que pasó."

Cuando termine, abre el job. Ve directo al step `tofu plan`. Mostrar:

```
No changes. Your infrastructure matches the configuration.
```

Espera. Eso es porque el cambio es solo en código Python, no en infraestructura. **Excelente momento didáctico**, NO lo arregles, explícalo:

"Fíjense: el plan dice 'no changes'. ¿Por qué? Porque OpenTofu solo gestiona infraestructura, no código. Cambiamos `CODE_LENGTH` que es Python, pero la Lambda como recurso es la misma."

"... pero esperen. ¿Cómo va a llegar entonces el código nuevo a AWS?"

(Pausa dramática.)

"Porque OpenTofu sí ve el `source_code_hash`. Es un hash del archivo zip de la Lambda. Veamos."

Ve al step `tofu plan` y haz scroll. Si tu lambda cambió, deberías ver algo como:

```
~ source_code_hash = "abc123..." -> "def456..."
~ (in-place update)
```

"Aquí está el cambio. El hash del zip cambió porque el contenido del zip cambió. OpenTofu va a actualizar la Lambda, pero como solo cambia el código, es un update in-place. Sin downtime."

### 4.4 Hacer merge (2 min)

Vuelve al PR. Click "Merge pull request". Confirma.

Vuelve a Actions. Verás un nuevo workflow corriendo: este es el de `push a main`. **Va a hacer apply esta vez**.

### 4.5 Verificar (4 min)

Mientras corre el apply (otros 60-90 seg), abre AWS Console en Lambda. Muestra la versión actual.

Cuando termine GHA, refresca Lambda. Mira el `Last modified` actualizado.

Ahora prueba la API:

```bash
API="https://abc123.execute-api.us-east-1.amazonaws.com"
curl -X POST $API/shorten \
  -H "Content-Type: application/json" \
  -d '{"url":"https://www.uag.mx"}'
```

Verás:
```json
{"code":"Xz3aB9wK","short_url":"...","original_url":"..."}
```

"¿Notan algo? **El código tiene 8 caracteres**. Antes eran 6. El cambio llegó a producción sin que yo tocara AWS."

---

## Bloque 5 (45-50 min): Lo que viene en producción

### Lo que dices

"Lo que vimos hoy es el patrón básico. En empresas reales esto crece a:

- **Ambientes múltiples**: dev, staging, prod. Cada uno con su workflow, su rol, su state separado.
- **Approvals manuales** antes del apply en prod. GitHub Environments con required reviewers.
- **Comentar el plan en el PR**: en vez de tener que abrir Actions y leer logs, el plan se postea como comentario en el PR. Mucho más visible para code review.
- **Multi-account**: cada cliente o ambiente vive en una cuenta AWS distinta. Esto se maneja con un patrón hub-and-spoke: GitHub se autentica a una cuenta central, y de ahí salta a la cuenta destino."

(Aquí, si quieres, abres tu workflow real de producción 30 segundos:)

"Esto es un workflow real que uso en proyectos serios. Tiene los issue forms, los `/apply` y `/destroy` por comentario, hub-and-spoke. Fíjense que el corazón es lo mismo que vieron hoy: OIDC, plan, apply. Todo lo demás son refinamientos para procesos de equipo."

### Cierre

"Lo que se llevan:

1. **OIDC > access keys**. Siempre. No hay excusa para pegar AWS keys en GitHub Secrets en 2026.
2. **Plan en PR, apply en main** es el patrón mínimo viable. Empiecen ahí.
3. **Remote state con locking** es no negociable cuando hay más de una persona en el proyecto.
4. **El bootstrap problem es real**: siempre va a haber UNA cosa que se crea fuera del sistema. Está bien, no peleen contra eso, solo documenten muy bien qué fue.

¿Preguntas?"

---

## Errores comunes que pueden pasar en la demo (y cómo recuperarte)

### "Could not assume role"
El rol GHA no está configurado bien o el `repo` en la trust policy no coincide con tu repo. Solución: revisa `bootstrap/variables.tf` y vuelve a aplicar el bootstrap.

### "Error acquiring the state lock"
Hay un lock viejo en DynamoDB de una corrida anterior. Solución rápida en clase:

```bash
tofu force-unlock <ID_DEL_LOCK_EN_EL_ERROR>
```

### "BucketAlreadyExists" o el bootstrap no creó algo
Probablemente alguien más en la clase tiene un bucket con el mismo nombre. Cambia `random_id` byte_length a 8 para más entropía y reaplica.

### El apply de la lambda da timeout en `archive_file`
Pasa cuando el directorio `lambda/` tiene archivos basura (`.DS_Store`, `__pycache__`). Limpiar:

```bash
find lambda/ -name '__pycache__' -type d -exec rm -rf {} +
find lambda/ -name '.DS_Store' -delete
```

### "Plan diff inesperado en la demo"
Pasa si entre tu prep y la clase alguien cambió cosas en la consola. Solución: corre `tofu apply` antes de empezar la clase para reconciliar el state.

---

## Después de la clase

**Crítico para no acumular costos**:

```bash
# 1. Destruye el proyecto principal
tofu destroy

# 2. Si no vas a usar el repo otra vez en un par de semanas,
#    también destruye el bootstrap (state bucket + locks + OIDC):
cd bootstrap
# Edita main.tf: cambia force_destroy = true en aws_s3_bucket.state
tofu apply
tofu destroy
```

El bucket de state cobra ~$0.025/mes. La tabla DynamoDB en on-demand: $0 si no se usa. El OIDC provider: gratis. Total: **~30 centavos al mes** si dejas el bootstrap. Pero por higiene, destrúyelo si ya no lo vas a usar.
