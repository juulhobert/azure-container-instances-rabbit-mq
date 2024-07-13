# azure-container-instances-rabbit-mq
Azure container instances RabbitMq

## Import image into private ACR

```bash
az acr login --name juulstechacr
docker pull rabbitmq:3-management-alpine
docker tag rabbitmq:3-management-alpine juulstechacr.azurecr.io/rabbitmq:3-management-alpine
docker push juulstechacr.azurecr.io/rabbitmq:3-management-alpine
```