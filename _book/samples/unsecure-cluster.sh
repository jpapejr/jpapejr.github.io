#!/bin/bash
# Unsecure IKS/ROKS public and private interfaces
# References:
# - https://cloud.ibm.com/docs/containers?topic=containers-network_policies#isolate_workers_public
# - https://cloud.ibm.com/docs/containers?topic=containers-network_policies#isolate_workers
# - https://github.com/IBM-Cloud/kube-samples/tree/master/calico-policies

if test  -z "$SECURE_REGION" || test -z "$CALICO_CONFIG";
  then
    echo "Supply a region value to secure a cluster in that region: (Valid regions: au-syd, eu-de, eu-gb, jp-tok, us-east, us-south)"
    exit 99
  else
    echo "Unsecuring target cluster for $SECURE_REGION with calico policies.."
fi

git clone https://github.com/IBM-Cloud/kube-samples.git /tmp/kube-samples
cd /tmp/kube-samples

#Public interface policies (with optionals)
calicoctl delete -f calico-policies/public-network-isolation/$SECURE_REGION/allow-egress-pods-public.yaml -c "$CALICO_CONFIG"
calicoctl delete -f calico-policies/public-network-isolation/$SECURE_REGION/allow-ibm-ports-public.yaml -c "$CALICO_CONFIG"
calicoctl delete -f calico-policies/public-network-isolation/$SECURE_REGION/allow-public-service-endpoint.yaml -c "$CALICO_CONFIG"
calicoctl delete -f calico-policies/public-network-isolation/$SECURE_REGION/deny-all-outbound-public.yaml -c "$CALICO_CONFIG"
calicoctl delete -f calico-policies/public-network-isolation/$SECURE_REGION/allow-public-services-pods.yaml -c "$CALICO_CONFIG"
calicoctl delete -f calico-policies/public-network-isolation/$SECURE_REGION/allow-public-services.yaml -c "$CALICO_CONFIG"

#Private interface policies (with optionals)
calicoctl delete -f calico-policies/private-network-isolation/calico-v3/$SECURE_REGION/allow-all-workers-private.yaml -c "$CALICO_CONFIG"
calicoctl delete -f calico-policies/private-network-isolation/calico-v3/$SECURE_REGION/allow-egress-pods-private.yaml -c "$CALICO_CONFIG"
calicoctl delete -f calico-policies/private-network-isolation/calico-v3/$SECURE_REGION/allow-ibm-ports-private.yaml -c "$CALICO_CONFIG"
calicoctl delete -f calico-policies/private-network-isolation/calico-v3/$SECURE_REGION/allow-icmp-private.yaml -c "$CALICO_CONFIG"
calicoctl delete -f calico-policies/private-network-isolation/calico-v3/$SECURE_REGION/allow-private-service-endpoint.yaml -c "$CALICO_CONFIG"
calicoctl delete -f calico-policies/private-network-isolation/calico-v3/$SECURE_REGION/allow-sys-mgmt-private.yaml -c "$CALICO_CONFIG"
calicoctl delete -f calico-policies/private-network-isolation/calico-v3/$SECURE_REGION/allow-private-services.yaml -c "$CALICO_CONFIG"
calicoctl delete -f calico-policies/private-network-isolation/calico-v3/$SECURE_REGION/allow-private-services-pods.yaml -c "$CALICO_CONFIG"
calicoctl delete -f calico-policies/private-network-isolation/calico-v3/$SECURE_REGION/allow-vrrp-private.yaml -c "$CALICO_CONFIG"
calicoctl delete -f calico-policies/private-network-isolation/calico-v3/$SECURE_REGION/deny-all-private-default.yaml -c "$CALICO_CONFIG"

cd -
rm -fr /tmp/kube-samples