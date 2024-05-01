#!/bin/bash
# Usage: ./privileged-node-shell.sh -n <node_name>

while getopts n:i: flag
do
    case "${flag}" in
        n) node=${OPTARG};;
    esac
done

image=docker.io/library/alpine:latest
 
json="{\"spec\":{\"volumes\":[{\"name\":\"host-root\",\"hostPath\":{\"path\":\"/\",\"type\":\"\"}},{\"name\":\"kube-api-access\",\"projected\":{\"sources\":[{\"serviceAccountToken\":{\"expirationSeconds\":3607,\"path\":\"token\"}},{\"configMap\":{\"name\":\"kube-root-ca.crt\",\"items\":[{\"key\":\"ca.crt\",\"path\":\"ca.crt\"}]}},{\"downwardAPI\":{\"items\":[{\"path\":\"namespace\",\"fieldRef\":{\"apiVersion\":\"v1\",\"fieldPath\":\"metadata.namespace\"}}]}}],\"defaultMode\":420}}],\"containers\":[{\"name\":\"debugger\",\"image\":\"${image}\",\"volumeMounts\":[{\"name\":\"host-root\",\"mountPath\":\"/host\"},{\"name\":\"kube-api-access\",\"readOnly\":true,\"mountPath\":\"/var/run/secrets/kubernetes.io/serviceaccount\"}],\"securityContext\":{\"privileged\":true,\"allowPrivilegeEscalation\":true},\"terminationMessagePath\":\"/dev/termination-log\",\"terminationMessagePolicy\":\"File\",\"stdin\":true,\"tty\":true}],\"restartPolicy\":\"Never\",\"terminationGracePeriodSeconds\":30,\"dnsPolicy\":\"ClusterFirst\",\"serviceAccountName\":\"default\",\"serviceAccount\":\"default\",\"nodeName\":\"${node}\",\"hostNetwork\":true,\"hostPID\":true,\"hostIPC\":true,\"schedulerName\":\"default-scheduler\",\"tolerations\":[{\"operator\":\"Exists\"}],\"priority\":0,\"enableServiceLinks\":true,\"preemptionPolicy\":\"PreemptLowerPriority\"}}"

randomNum=$(echo $RANDOM)
echo "Creating node-debugger-${randomNum}..."
kubectl run node-debugger-${randomNum} --rm -it --overrides=$json  --image null
