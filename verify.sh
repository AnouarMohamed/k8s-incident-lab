#!/usr/bin/env bash
NS=incident-lab
PASS="\033[32mPASS\033[0m"
FAIL="\033[31mFAIL\033[0m"

check() {
  local label=$1
  local result=$2
  if [ "$result" = "0" ]; then
    echo -e "[$label] $PASS"
  else
    echo -e "[$label] $FAIL"
  fi
}

# 1. postgres
kubectl -n $NS get pod -l app=postgres -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q Running
pg=$?
check "postgres" $pg

# 2. payment: pod running and no OOMKilled in recent state, stable
sleep 5
kubectl -n $NS get pod -l app=payment -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null > /tmp/pay_restarts_1
sleep 15
kubectl -n $NS get pod -l app=payment -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null > /tmp/pay_restarts_2
kubectl -n $NS get pod -l app=payment -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q Running
pay_running=$?
if [ "$pay_running" = "0" ] && [ "$(cat /tmp/pay_restarts_1)" = "$(cat /tmp/pay_restarts_2)" ]; then
  pay=0
else
  pay=1
fi
check "payment" $pay

# 3. network: checkout -> payment
kubectl -n $NS run netcheck-$RANDOM --image=curlimages/curl:8.8.0 --restart=Never --rm -i --timeout=30s \
  --overrides='{"spec":{"containers":[{"name":"netcheck","image":"curlimages/curl:8.8.0","command":["curl","-s","-o","/dev/null","-w","%{http_code}","--max-time","5","http://payment.incident-lab.svc.cluster.local:8080/"]}]}}' \
  2>/dev/null | grep -q 200
# note: this test pod itself is not labeled app=checkout, so it validates cluster DNS/service
# reachability only if NetworkPolicy allows default namespace traffic; real check below execs from checkout pod
kubectl -n $NS exec deploy/checkout -- wget -q -O- --timeout=5 http://payment:8080/ >/dev/null 2>&1
net=$?
check "network (checkout->payment)" $net

# 4. controller: status configmap updates after touching feature-flags
kubectl -n $NS get configmap flag-controller-status -o jsonpath='{.data.observed_generation}' 2>/dev/null > /tmp/gen_before
kubectl -n $NS patch configmap feature-flags --type merge -p "{\"data\":{\"ping\":\"$RANDOM\"}}" >/dev/null 2>&1
sleep 10
kubectl -n $NS get configmap flag-controller-status -o jsonpath='{.data.observed_generation}' 2>/dev/null > /tmp/gen_after
if [ -s /tmp/gen_after ] && [ "$(cat /tmp/gen_before)" != "$(cat /tmp/gen_after)" ]; then
  ctrl=0
else
  ctrl=1
fi
check "controller" $ctrl

# 5. ingress via traefik nodeport
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost:30080/)
if [ "$code" = "200" ]; then
  ing=0
else
  ing=1
fi
check "ingress" $ing

echo ""
fails=0
for r in $pg $pay $net $ctrl $ing; do
  [ "$r" != "0" ] && fails=$((fails + 1))
done
if [ "$fails" = "0" ]; then
  echo "All checks passing. Incident resolved."
else
  echo "$fails / 5 checks failing. Keep digging."
fi
