#!/bin/bash

PROFILE="$HOME/.bash_profile"

NAMESPACE="default"

# 导入 PATH 变量
export PATH=${HELM_PATH}:${BIN_PATH}:$PATH

# 日志记录
logfile="/var/log/deepflow_patch.log"
FGC_START="\033[1;"
FGC_END="\033[0m"
FGC_YELLOW="33m"
FGC_RED="31m"
FGC_GREEN="32m"
FGC_WHITE="37m"


logger()
{
    local level=$1
    shift
    local msg="$@"

    local color=""
    local msg_datetime=$(date +"[%F %T]")

    case "$level" in
        [Ii][Nn][Ff][Oo]*)
            color=$FGC_GREEN
            ;;
        [Ww][Aa][Rr][Nn]*)
            color=$FGC_YELLOW
            ;;
        [Ee][Rr][Rr]*)
            color=$FGC_RED
            ;;
        *)
            color=$FGC_WHITE
            ;;
    esac
    echo -e "$msg_datetime" "$level" "${FGC_START}${color}$msg${FGC_END}" | tee -a $logfile 1>&2
}

function install_istio()
{
    cd istio-1.13.2
    chmod +x bin/istioctl
    export PATH=$PWD/bin:$PATH
    echo "export PATH=$PWD/bin:$PATH" >> ${PROFILE}
    istioctl install --set profile=demo -y
    logger info " ... "
    kubectl label ${NAMESPACE} default istio-injection=enabled
}

function deploy_bookinfo () {
    logger info "Start deploying bookinfo demo with kubectl apply ... "
    kubectl -n ${NAMESPACE} apply -f samples/bookinfo/platform/kube/bookinfo.yaml
    logger info "Checking curl"
    kubectl -n ${NAMESPACE}  exec "$(kubectl  -n ${NAMESPACE}  get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}')" -c ratings -- curl -s productpage:9080/productpage | grep -o "<title>.*</title>"
    logger info "Deploying bookinfo ingress gateway rules ..."
    kubectl -n ${NAMESPACE}  apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
    logger info "Deploying bookinfo destination rules ..."
    kubectl -n ${NAMESPACE}  apply -f samples/bookinfo/networking/destination-rule-all.yaml
    logger info "Deploying bookinfo virtual service ..."
    kubectl -n ${NAMESPACE}  apply -f samples/bookinfo/networking/virtual-service-all-v1.yaml
    kubectl -n ${NAMESPACE}  apply -f samples/bookinfo/networking/virtual-service-reviews-test-v2.yaml
    kubectl apply -f samples/addons
}




function write_profile () {
    echo "export PATH=$PWD/bin:$PATH" >> ${PROFILE}
    echo "export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')" >> ${PROFILE}
    echo "export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')" >> ${PROFILE}
    echo "export INGRESS_HOST=$(kubectl get po -l istio=ingressgateway -n istio-system -o jsonpath='{.items[0].status.hostIP}')" >> ${PROFILE}
    echo "export JAEGER_PORT=$(kubectl -n istio-system get service tracing -o jsonpath='{.spec.ports[?(@.name=="http-query")].nodePort}')" >> ${PROFILE}
    echo "export GRAFANA_PORT=$(kubectl -n istio-system get service grafana -o jsonpath='{.spec.ports[?(@.name=="service")].nodePort}')" >> ${PROFILE}
    echo "export KIALI_PORT=$(kubectl -n istio-system get service kiali -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')" >> ${PROFILE}
    echo "export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT" >> ${PROFILE}
    source ${PROFILE}
}

function install_travel_demo () {

    logger info "✈ Deploying travel Demo ... "
    cd ..
    kubectl create namespace travel-agency || true
    kubectl create namespace travel-portal || true
    kubectl create namespace travel-control || true
    kubectl apply -f travels/travel_agency.yaml -n travel-agency
    kubectl apply -f travels/travel_portal.yaml -n travel-portal
    kubectl apply -f travels/travel_control.yaml -n travel-control
    logger Warn "Need to write local hosts file first:'${INGRESS_HOST} control.travel-control.istio-cluster.org'"
    logger Warn "Reference Doc : https://kiali.io/docs/tutorials/travels/03-first-steps/ "
}

function checkinfo () {
    export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
    export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
    export INGRESS_HOST=$(kubectl get po -l istio=ingressgateway -n istio-system -o jsonpath='{.items[0].status.hostIP}')
    export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
    logger info "-------------------------------------------------------------------------------------------------------------------------------------------------------"
    logger info "GateWay URL: $GATEWAY_URL"
    logger info "Kiali URL: http://$INGRESS_HOST:${KIALI_PORT}"
    logger info "Jaeger URL: http://$INGRESS_HOST:${JAEGER_PORT}"
    logger info "Grafana URL: http://$INGRESS_HOST:${GRAFANA_PORT}"
    logger info "BookInfo Demo URL: http://$GATEWAY_URL/productpage"
    logger info "Travel Demo URL: control.travel-control.istio-cluster.org (need to write local hosts file first)"
}


function disable_mtls () {
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: "default"
  namespace: "istio-system"
spec:
  mtls:
    mode: DISABLE
EOF
}

function delete_demo () {
    cd istio-1.13.2
    kubectl -n ${NAMESPACE} delete -f samples/bookinfo/platform/kube/bookinfo.yaml || true
    kubectl -n ${NAMESPACE} delete -f samples/bookinfo/networking/bookinfo-gateway.yaml || true
    kubectl -n ${NAMESPACE} delete -f samples/bookinfo/networking/destination-rule-all.yaml || true
    kubectl -n ${NAMESPACE} delete -f samples/bookinfo/networking/virtual-service-all-v1.yaml || true
    kubectl -n ${NAMESPACE} delete -f samples/bookinfo/networking/virtual-service-reviews-test-v2.yaml || true
    kubectl -n ${NAMESPACE} delete -f samples/addons || true
    kubectl -n ${NAMESPACE} delete namespace istio-system || true
    kubectl label namespace ${NAMESPACE} istio-injection- || true
    kubectl delete namespace travel-agency || true
    kubectl delete namespace travel-portal || true
    kubectl delete namespace travel-control || true
    logger info "Delete All demo resource"
}

function main () {
    install_istio
    deploy_bookinfo
    write_profile
    install_travel_demo
    disable_mtls
    checkinfo
}


function usage()
{
cat <<- EOF

    e.g. bash istio-demo.sh install
    install             Install all                  [安装 Istio Demo]
    uninstall           Uninstall all                [卸载 Istio Demo]
EOF
exit 0
}


while [[ $# -ge 1 ]]; do
    key="$1"
    case $key in
        install)
            main
            ;;
        uninstall)
            delete_demo
            ;;
        *)
            usage
            ;;
    esac
    shift
done

exit 0