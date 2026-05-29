# Deployment Guide

## Local Docker

```bash
cp .env.example .env
docker compose up --build
```

## Production Checklist

- Set `JWT_SECRET` to a long random secret.
- Restrict `CLIENT_ORIGIN` to approved app or web origins.
- Use MongoDB Atlas or a managed replica set.
- Use managed Redis with persistence and high availability.
- Place the backend behind a TLS load balancer.
- Enable Socket.IO sticky sessions or use the Redis adapter across pods.
- Configure Google identity verification before issuing app JWTs.
- Store audio and image assets in the mobile bundle or CDN.
- Add crash reporting and analytics in Flutter.

## Kubernetes

Apply manifests:

```bash
kubectl apply -f k8s/
```

The backend deployment expects a secret named `capture-tens-secrets`.

```bash
kubectl create secret generic capture-tens-secrets \
  --from-literal=JWT_SECRET='replace-me' \
  --from-literal=MONGO_URI='mongodb://mongo:27017/capture_tens' \
  --from-literal=REDIS_URL='redis://redis:6379'
```
