# Demo CI/CD con OpenTofu y GitHub Actions

URL Shortener mínimo desplegado vía GitHub Actions con OIDC (sin access keys).

## Arquitectura

```
   POST /shorten         GET /{code}
        │                     │
        └──────┬──────────────┘
               │
        ┌──────▼───────┐
        │ API Gateway  │  HTTP API
        └──────┬───────┘
               │
        ┌──────▼───────┐
        │   Lambda     │  Python 3.12
        └──┬────────┬──┘
           │        │
    ┌──────▼──┐ ┌──▼──────────┐
    │DynamoDB │ │  S3 logs    │
    │ (urls)  │ │ (analytics) │
    └─────────┘ └─────────────┘
```

## Flujo CI/CD

```
┌──────────────────────┐
│ Pull request -> main │ ──> tofu plan (solo)
└──────────────────────┘

┌──────────────────────┐
│ Push -> main         │ ──> tofu plan + tofu apply
└──────────────────────┘
```

GitHub Actions asume un rol IAM en AWS via **OIDC**. Sin access keys, sin secrets.

## Estructura

```
.
├── .github/workflows/tofu.yml    # CI/CD pipeline
├── bootstrap/                     # State backend + OIDC + rol GHA. UNA VEZ.
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── README.md
├── lambda/handler.py              # Codigo Python de la Lambda
├── backend.tf                     # State remoto en S3
├── main.tf                        # API GW + Lambda + DDB + S3
├── iam.tf                         # Rol IAM de la Lambda
├── variables.tf
└── outputs.tf
```

## Setup completo (primera vez)

### 1. Bootstrap

Esto crea el bucket de state, el OIDC provider y el rol GHA. Solo se hace una vez.

```bash
cd bootstrap
# Edita variables.tf: cambia var.github_repo a "tu-usuario/tu-repo"
tofu init
tofu apply
# Anota los outputs: state_bucket y gha_role_arn
```

### 2. Configurar el proyecto principal

```bash
cd ..

# Edita backend.tf: pega state_bucket
# Edita .github/workflows/tofu.yml: pega gha_role_arn como AWS_ROLE
```

### 3. Subir a GitHub y dejar que el CI/CD haga el resto

```bash
git init
git add .
git commit -m "initial commit"
git remote add origin git@github.com:tu-usuario/tu-repo.git
git push -u origin main
```

GitHub Actions correrá automáticamente: `plan` + `apply`. Verifica en la pestaña Actions del repo.

## Probar la API

```bash
# Despues de que GHA aplique, busca el output api_url en el log de Actions.
API="https://abc123.execute-api.us-east-1.amazonaws.com"

# Acortar
curl -X POST $API/shorten \
  -H "Content-Type: application/json" \
  -d '{"url":"https://www.uag.mx"}'
# Respuesta: {"code":"Xz3aB9","short_url":"https://abc123.../Xz3aB9","original_url":"..."}

# Visitar
curl -L $API/Xz3aB9
# Sigue el 302 a https://www.uag.mx
```

## Limpieza

```bash
# 1. Destruye el proyecto principal (lo puedes hacer via GHA borrando todo,
#    o localmente):
tofu destroy

# 2. Si quieres destruir TAMBIEN el bootstrap (state bucket + OIDC + rol):
cd bootstrap
# Edita main.tf: cambia force_destroy a true en aws_s3_bucket.state
tofu apply  # aplica el cambio
tofu destroy
```
