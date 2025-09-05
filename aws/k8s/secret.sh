kubectl create secret generic fc-hrsc-db-secret \
  --from-literal=username=root \
  --from-literal=password=root \
  -n codeflix
