# DevDayAug2022

Notes: 
All the following steps are tested on k8s version 1.18.x
$ is used to present command prompt wherever required

# Pre-requisite

## Install kubectl
Install kubectl (v1.18.0) (as shown [here] https://kubernetes.io/docs/tasks/tools/#kubectl)

### For MacOS
```shell
curl -LO "https://dl.k8s.io/release/v1.18.0/bin/darwin/amd64/kubectl"
chmod +x kubectl
./kubectl version --client
mv kubectl /usr/local/bin/kubectl 
```

Create an alias `ktl` for `kubectl`

## Setup Kops cluster on AWS

Setup and configure AWS CLI and use correct profile for your AWS account 
**NOTE:** **This setup might incur cost**. Please evaluate first. The kops setup that is created is following **HA setup**.

#### Ensure your AWS user has following permissions

(Follow Kops documentation [here](https://kops.sigs.k8s.io/getting_started/aws/))

- AmazonEC2FullAccess
- AmazonRoute53FullAccess
- AmazonS3FullAccess
- IAMFullAccess
- AmazonVPCFullAccess
- AmazonSQSFullAccess
- AmazonEventBridgeFullAccess

#### Create Terraform s3 state bucket

**Note:** Make sure to update the bucket name. It has to be globally unique
Also, created by tag is added to identify which user created the resources. This is useful in case of shared AWS account (Company account) 

```shell
export TF_S3_BUCKET_NAME=k8s-devday-2022-tfstate-bucket
```

```shell
cd tf-s3-state-bucket
terraform init
terraform plan -out tfplan -var="tf_s3_bucket_name=$TF_S3_BUCKET_NAME" -var="created_by_tag=prashantk"
terraform apply tfplan
```

#### Create bucket for KOPS state

```shell
export KOPS_STATE_BUCKET=devday-2022-kops-cluster-state
```

```shell
cd kops-state-bucket
terraform init -backend-config="bucket=$TF_S3_BUCKET_NAME" -backend-config=../backend.hcl
terraform plan -out tfplan -var="kops_state_bucket_name=$KOPS_STATE_BUCKET" -var="created_by_tag=prashantk"
terraform apply tfplan
```

#### Create kops cluster

Install kops binary as **kops_1.18.2** (version 1.18.2)
Create a public-private key pair (if not already created)
This key can be used to ssh into the instances.

**NOTE:** Make sure the cluster name ends with .k8s.local to use gossip based setup.

```shell
cd kops_cluster_tf
export CLUSTER_NAME=devday2022.cluster.k8s.local
export KOPS_STATE_STORE=s3://devday-2022-kops-cluster-state
kops_1.18.2 create cluster \
    --name ${CLUSTER_NAME} \
    --cloud=aws \
    --node-count 2 \
    --zones ap-south-1a,ap-south-1b,ap-south-1c \
    --master-zones ap-south-1a,ap-south-1b,ap-south-1c \
    --topology private \
    --networking calico \
    --ssh-public-key=~/.ssh/id_rsa.pub \
    --bastion="true" \
    --cloud-labels="created_by=prashantk,usage=k8sDevDayTalk2022" \
    --yes
```

Note: For production cluster, further improvements has to be done e.g. Restricting k8s API to specific CIDR or created internal ELB etc.

#### Validate cluster and access the cluster

Validate the cluster state

```shell
kops_1.18.2 validate cluster --name $CLUSTER_NAME --wait 10m
```

Validate kubectl access

```shell
ktl get nodes
NAME                                            STATUS   ROLES    AGE   VERSION
ip-172-20-105-15.ap-south-1.compute.internal    Ready    master   20m   v1.18.20
ip-172-20-112-185.ap-south-1.compute.internal   Ready    node     18m   v1.18.20
ip-172-20-45-107.ap-south-1.compute.internal    Ready    master   19m   v1.18.20
ip-172-20-50-30.ap-south-1.compute.internal     Ready    node     18m   v1.18.20
ip-172-20-86-189.ap-south-1.compute.internal    Ready    master   19m   v1.18.20
```

#### Destroy cluster

The cluster can be destroyed as follows. Do it **at the end of the session** to ensure **cost is not accumulated** for unused clusters. 

```shell
kops_1.18.2 delete cluster --name $CLUSTER_NAME --yes
```

Delete the state buckets created using terraform as well (`terraform plan -out tfplan -destroy && terraform apply tfplan`)

---

# Example Application details

Refer Slides [here](TBA)

# Pod Application access 

## Install customer Service

```shell
ktl apply -f resources/customer_pod.yaml
watch -n 5 "kubectl get pods"
```
Wait till pod is running

```shell
$ ktl get pods
NAME        READY   STATUS    RESTARTS   AGE
customers   1/1     Running   0          7m15s
```

## How do I access the pod?

#### Access using pod SSH

```shell
$ ktl exec customers -- curl -s -S http://localhost:8080/customers/1
{
  "id": "CUST_0001",
  "name": "Customer Name",
  "phoneNumber": "+911233243335",
  "gender": "M"
}
```

(Install curl if not available. The image linux is debian i.e. `apt-get update && apt-get -y install curl` should work)

### what do we need to access network application?

Refer Slides [here](TBA)

#### Pod IP 

```shell
$ ktl get pods -o wide
NAME        READY   STATUS    RESTARTS   AGE     IP                NODE                                            NOMINATED NODE   READINESS GATES
customers   1/1     Running   0          3m31s   100.105.198.130   ip-172-20-112-185.ap-south-1.compute.internal   <none>           <none>
```

#### Pod Port

```shell
$ ktl get pods customers -o yaml
  ...
    ports:
    - containerPort: 8080
      protocol: TCP
  ...
```

### Install supporting pod to access the pod

Run a supporting container to access the application. 

```shell
$ ktl run nginx --image=nginx
$ ktl get pods -w
$ ktl get pods
NAME        READY   STATUS    RESTARTS   AGE
customers   1/1     Running   0          5m33s
nginx       1/1     Running   0          28s
```

## Access the pod with the pod IP

```shell
$ podIP=100.105.198.130
$ ktl exec nginx -- curl --no-progress-meter http://$podIP:8080/customers/1 | jq "."
{
  "id": "CUST_0001",
  "name": "Customer Name",
  "phoneNumber": "+911233243335",
  "gender": "M"
}
```

## But I deploy multiple pods per service

Refer Slides [here](TBA)

# Application as a deployment (instead of pods)

## Remove pod

```shell
ktl delete pod customers
```

## Deploy application as deployment with multiple replicas

```shell
$ ktl apply -f resources/customers_deployment.yaml
$ ktl get pods
NAME                         READY   STATUS    RESTARTS   AGE
customers-568c95b849-7jhh5   1/1     Running   0          8s
customers-568c95b849-x2q54   1/1     Running   0          8s
nginx                        1/1     Running   0          18h
```

## Accessing application deployed as deployment

Get pod ips for deployment pods

```shell
$ ktl get pods -o wide
NAME                         READY   STATUS    RESTARTS   AGE     IP                NODE                                            NOMINATED NODE   READINESS GATES
customers-568c95b849-7rj67   1/1     Running   0          31s     100.112.44.132    ip-172-20-50-30.ap-south-1.compute.internal     <none>           <none>
customers-568c95b849-x5jqj   1/1     Running   0          31s     100.105.198.131   ip-172-20-112-185.ap-south-1.compute.internal   <none>           <none>
nginx                        1/1     Running   0          4m48s   100.112.44.131    ip-172-20-50-30.ap-south-1.compute.internal     <none>           <none>
```

Access application with any's ip address

```shell
podIP=100.112.44.132
ktl exec nginx -- curl --no-progress-meter http://$podIP:8080/customers/1 | jq "."
```
But accessing application with individual pod ip defeats the whole purpose of using deployment. 
Pods are ephemeral and can change IPs or scale out or scale in any time. 

---

# Additional sections
## Switching kubectl context and namespaces

### List all contexts

```shell
ktl config get-contexts
```
or list just context names

```shell
ktl config get-contexts -o name
```

### Switch context

```shell
ktl config use-context kind-kind18
```
`kind-kind18` will become the current context.  

### List all namespaces

```shell
ktl get namespaces
```

### Switch current kubectl context namespace

```shell
ktl config set-context --current --namespace=kube-system
```
`kube-system` will become current namespace for current context. 

```shell
ktl get pods
```
Will provide pods running in current selected namespace for current context.

TIP: 
It is recommended to install [kubectx](https://github.com/ahmetb/kubectx) to make it easy to switch between contexts and namespaces.
Also install [kube-ps1](https://github.com/jonmosco/kube-ps1) to add context and namespace information to commandline. 
