# OnyxPay Infrastructure

## Ejecutar el stack

Las imágenes de los microservicios se construyen y publican en GitHub
Container Registry desde sus respectivos workflows de GitHub Actions. Docker
Compose descarga esas imágenes; no instala dependencias localmente.

Si las imágenes de GHCR son privadas, inicia sesión primero:

```bash
echo "$GITHUB_TOKEN" | docker login ghcr.io -u GITHUB_USERNAME --password-stdin
```

Inicia o actualiza todo el stack:

```bash
docker compose pull
docker compose up -d
```

El frontend queda disponible en `http://localhost:8080` y envía `/api/payments`
al API Gateway mediante el proxy incluido en su contenedor Nginx.

Para ver el estado y los logs:

```bash
docker compose ps
docker compose logs -f payment-frontend api-gateway
```

## Logs centralizados

Grafana Alloy descubre automáticamente los contenedores mediante el socket de
Docker y envía sus logs a Loki. Grafana tiene el datasource y el dashboard
`OnyxPay · Logs` provisionados al iniciar.

1. Abre `http://localhost:3000`.
2. Inicia sesión con `admin` / `admin` la primera vez.
3. Abre **Dashboards → OnyxPay → OnyxPay · Logs**.
4. Usa el filtro **Servicio** para ver uno o varios microservicios.

La interfaz de diagnóstico de Alloy está disponible en
`http://localhost:12345`.
