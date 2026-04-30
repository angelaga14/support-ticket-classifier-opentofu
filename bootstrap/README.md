# Bootstrap

Esta carpeta crea, **una sola vez**, los recursos que el proyecto principal necesita para funcionar:

1. **Bucket S3 + tabla DynamoDB** para el state remoto de OpenTofu.
2. **OIDC provider** de GitHub en AWS.
3. **Rol IAM** que GitHub Actions asume al correr `tofu plan` y `tofu apply`.

## El bootstrap problem

> Para usar OpenTofu con remote state necesitas un bucket S3.
> Para crear ese bucket S3 con OpenTofu... necesitas state.
> ¿Quién creó el primer bucket?

Respuesta: este bootstrap. Tiene **state local** (no remoto), porque es la infraestructura de la infraestructura.

```
bootstrap/                     <- esta carpeta. State local. Se corre 1 vez.
├── main.tf
├── variables.tf
├── outputs.tf
└── terraform.tfstate          <- local, conservalo

../                            <- proyecto principal. State remoto.
├── backend.tf                 <- usa el bucket creado aqui
├── main.tf
└── ...
```

## Cómo correrlo (una vez, antes de la clase)

```bash
cd bootstrap

tofu init
tofu apply

# Anota los outputs:
#   state_bucket  -> pegalo en ../backend.tf
#   role_arn      -> pegalo en .github/workflows/tofu.yml
```

## Importante

- **No borres `terraform.tfstate` de esta carpeta.** Si lo pierdes, la única forma de destruir estos recursos es a mano por la consola.
- **Cambia `var.github_repo` antes del primer apply** o no funcionará el OIDC trust.
- Estos recursos **persisten entre clases**. No corras `tofu destroy` aquí cada vez.
