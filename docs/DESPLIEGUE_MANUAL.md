# Despliegue manual (sin AWS) en minikube + Istio

Los scripts de `scripts/` solo automatizan estos comandos. Si prefieres ejecutarlos uno a uno
(o estás en Windows/PowerShell), son estos. Todos se ejecutan desde la raíz del repositorio.

## 0. Requisitos

`docker` (o el driver que uses con minikube), `minikube`, `kubectl`, `istioctl` (misma versión menor que los
addons; en clases se usó 1.26.x) y `curl`. Los scripts `.sh` necesitan bash (Linux, macOS, WSL o Git Bash).

## 1. Cluster, Istio y addons

```bash
minikube start --cpus 4 --memory 6144
minikube addons enable metrics-server

istioctl install -y --set profile=demo \
  --set values.pilot.resources.requests.memory=256Mi --set values.pilot.resources.requests.cpu=100m \
  --set values.global.proxy.resources.requests.cpu=50m --set values.global.proxy.resources.requests.memory=128Mi

# addons de la misma versión menor que istioctl (ejemplo 1.26)
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/addons/grafana.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/addons/kiali.yaml
kubectl get pods -n istio-system
```

## 2. Pushgateway y dashboard

```bash
kubectl apply -f k8s/monitoring/pushgateway.yaml
# Dashboard: Grafana -> Dashboards -> New -> Import -> subir k8s/monitoring/dashboards/artelab-observabilidad.json
istioctl dashboard grafana      # abre Grafana en el navegador
```

## 3. Construir las imágenes dentro de minikube

```bash
minikube image build -t artelab-usuarios:v1 ./usuarios
minikube image build -t artelab-artelab:v1  ./artelab
```

## 4. Namespace, secretos y políticas

```bash
kubectl apply -f k8s/00-namespace.yaml
kubectl -n artelab create secret generic usuarios-secrets --from-literal=jwt-secret="$(openssl rand -hex 32)"
kubectl -n artelab create secret generic artelab-secrets \
  --from-literal=jwt-secret="$(openssl rand -hex 32)" \
  --from-literal=auth-username=admin --from-literal=auth-password='<una-clave-a-eleccion>'
kubectl apply -f k8s/istio/00-peer-authentication.yaml -f k8s/istio/30-telemetry.yaml
```

## 5. Microservicios y rutas

Los manifiestos usan la imagen `artelab-<servicio>:local`. Cambia el tag por el que construiste (aquí `v1`)
**editando los dos archivos** o aplicando con sed:

```bash
sed 's|artelab-usuarios:local|artelab-usuarios:v1|' k8s/10-usuarios.yaml | kubectl apply -f -
sed 's|artelab-artelab:local|artelab-artelab:v1|'   k8s/20-artelab.yaml  | kubectl apply -f -
kubectl apply -f k8s/istio/10-gateway.yaml -f k8s/istio/20-authorization-policies.yaml
kubectl -n artelab get pods        # esperar READY 2/2 (app + istio-proxy)
```

## 6. Acceso y pruebas

```bash
kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80
curl -X POST http://localhost:8080/usuarios/api/v1/auth/login -H 'Content-Type: application/json' \
     -d '{"correo":"admin@mail.cl","clave":"admin123"}'

istioctl dashboard kiali           # grafo de servicios
istioctl dashboard prometheus      # consultas PromQL
```

## 7. Diagnóstico

```bash
kubectl -n artelab get pods,svc,pvc
kubectl -n artelab describe pod <pod>
kubectl -n artelab logs <pod> -c usuarios              # logs JSON de la app
kubectl -n artelab logs <pod> -c istio-proxy           # access logs de Envoy
kubectl -n artelab exec deploy/usuarios -c istio-proxy -- curl -s localhost:15020/stats/prometheus | grep jvm_memory_used_bytes | head
istioctl analyze -n artelab                            # valida la configuración de Istio
kubectl top pods -n artelab                            # CPU/memoria (metrics-server)
```

## 8. Limpieza

```bash
kubectl delete namespace artelab monitoring
minikube delete
```
