# Mac Prepreqs

1. Run the following command to install `helm`, `docker`, `kubectl` and `minikube` using Homebrew:

   `brew install docker kubectl minikube helm`

2. Verify minikube is installed:

    `minikube version`

# Run the demo

1. Create a kubernetes integration cluster in Coralogix and obtain the key

2. Execute:
```
export CORALOGIX_APIKEY=<key>
bash startup.sh
```

3. TO create the resources needed get an API key (not the k8s key) and 
```
export CORALOGIX_API_KEY=<key>
docker-compose up
curl -X POST "https://api.coralogix.com/api/v1/dashboards" \
-H "Authorization: Bearer ${CORALOGIX_API_KEY}" \
-H "Content-Type: application/json" \
-d @dashboard.json
```

# Cleanup

`bash teardown.sh`