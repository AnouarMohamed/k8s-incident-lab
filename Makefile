NS := incident-lab

.PHONY: apply verify status events logs-controller network ingress forward-traefik

apply:
	kubectl apply -f manifests/

verify:
	./verify.sh

status:
	kubectl -n $(NS) get pods,pvc,svc,netpol

events:
	kubectl -n $(NS) get events --sort-by=.lastTimestamp

logs-controller:
	kubectl -n $(NS) logs deploy/flag-controller --tail=100

network:
	kubectl -n $(NS) exec deploy/checkout -- wget -q -O- --timeout=5 http://payment:8080/

ingress:
	curl -s -o /dev/null -w '%{http_code}\n' --max-time 5 http://localhost:30080/

forward-traefik:
	kubectl -n traefik port-forward --address 127.0.0.1 service/traefik 30080:80
