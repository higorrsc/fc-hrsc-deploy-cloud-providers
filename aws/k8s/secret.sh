kubectl create secret generic fc-hrsc-db-secret \
  --from-literal=username=root \
  --from-literal=password=root \
  -n codeflix

kubectl create secret generic fc-hrsc-rabbitmq-secret \
  --from-literal=username=adm_videos \
  --from-literal=password=123456 \
  -n codeflix
