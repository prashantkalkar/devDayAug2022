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

#### Allow access to port range from bastion to nodes

Create additional security groups to allow access to k8s nodes from bastion node on port ranged used by k8s for NodePort
service.

Copy the node and bastion security group ids from AWS Console (Most likely named as `nodes.devday2022.cluster.k8s.local` and `bastion.devday2022.cluster.k8s.local`)

```shell
cd kops-k8s-node-bastion-access
terraform init -backend-config="bucket=$TF_S3_BUCKET_NAME" -backend-config=../backend.hcl
terraform plan -out tfplan -var="created_by_tag=prashantk" -var="node_security_group_id=sg-07fdc39cbc5ce763e" -var="bastion_security_group_id=sg-01c0dac4f86bb63ff"
terraform apply tfplan
```

#### Deploy nginx ingress controller

Install the ingress controller with following command. (Install helm if required)

```shell
helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx \
  --create-namespace --version='<4'
```

#### Destroy cluster

The cluster can be destroyed as follows. Do it **at the end of the session** to ensure **cost is not accumulated** for unused clusters. 

```shell
kops_1.18.2 delete cluster --name $CLUSTER_NAME --yes
```

Delete the state buckets created using terraform as well (`terraform plan -out tfplan -destroy && terraform apply tfplan`)

---

# Example Application details

Refer Slides [here](#slides)

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

Refer Slides [here](#slides)

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

Refer Slides [here](#slides)

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

## Adding a clusterIP service to access application with stable IP

Create service 

```shell
$ ktl apply -f resources/customers_clusterip_service.yaml
$ ktl get services
NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
customers    ClusterIP   100.64.222.177   <none>        8080/TCP   22s
kubernetes   ClusterIP   100.64.0.1       <none>        443/TCP    47h
```

Access customer service with stable IP and port

```shell
serviceIP=100.64.222.177
ktl exec nginx -- curl --no-progress-meter http://$serviceIP:8080/customers/1 | jq "."
```
### Service Endpoints

An endpoint resource is created for every clusterIP service. 
 
```shell
$ ktl get endpoints
```
Endpoint resource reflect the changes in the pod ips supported by the service.
Delete a pod and see the changes are reflected or not.

```shell
$ ktl delete pod customers-568c95b849-4spdd
$ ktl describe endpoints customers
```

### Service DNS & Well known port

```shell
$ ktl apply -f resources/customers_clusterip_WellknownPort.yaml
$ ktl get services
NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
customers    ClusterIP   100.64.222.177   <none>        80/TCP    68m
```

Try accessing the application without the port (default http port 80 will be used)

```shell
$ serviceIP=100.64.222.177
$ ktl exec nginx -- curl --no-progress-meter http://$serviceIP/customers/1 | jq "."
```

### What about Domain Name 

Services are resolvable with service name inside k8s cluster.
That means this should work.

```shell
ktl exec nginx -- curl --no-progress-meter http://customers/customers/1 | jq "."
```

### How does DNS works in this case?

To add later.

### But how do I access the service from outside? 

How will we run the customer service using docker locally.

```shell
docker run -p 18080:8080 amitsadafule/customer-service:1.0.0
```

Access the application using link: [http://localhost:18080/customers/1](http://localhost:18080/customers/1)

Here we are doing a port mapping. Host port 18080 is mapped to port 8080 on the container.

Similarly, can be map container port to the k8s node port? 

### NotePort Service

```shell
ktl apply -f resources/customers_nodeport_service.yaml
```
Now the Port 30001 is mapped to the container pod on the k8s node and should be accessible as follows:

```shell
k8sNodeIP=172.20.112.185
curl -s -S http://$k8sNodeIP:30001/customers/1 | jq "."
```
### Can't really use single nodeIP

Refer Slides [here](#slides)

### Load balancer Service

Instead of just using NodePort use load balancer service if provided by the cloud provider
Create LB type service

```shell
ktl apply -f resources/customers_loadbalancer_service.yaml
```

#### Use dynamic Node Port

```shell
ktl apply -f resources/customers_loadbalancer_dynamicport.yaml
```

### Install products service

```shell
ktl apply -f resources/products_deployment.yaml
```

Add service resource for the products service

```shell
ktl apply -f resources/products_clusterip_WellknownPort.yaml
```

Check products service connectivity

```shell
ktl exec nginx -- curl --no-progress-meter http://products/products/1 | jq "."
{
  "id": "PROD_0001",
  "name": "Product Name",
  "price": 10
}
```

### Ingress Controller

Check ingress controller deployed

```shell
$ ktl get pods -n ingress-nginx
NAME                                        READY   STATUS    RESTARTS   AGE
ingress-nginx-controller-776cb4b9dd-4nm2c   1/1     Running   0          18h
```

### Create ingress controllers for our services

Update customers service back to ClusterIP type service. 

```shell
ktl apply -f resources/customers_clusterip_WellknownPort.yaml --force
```

Add the ingress resource for the customers service

```shell
ktl apply -f resources/customers_ingress.yaml
```

Add the ingress resource for the products service

```shell
ktl apply -f resources/products_ingress.yaml
```

### Test connectivity by using ingress controller

Get ingress controller IPs address

```shell
$ ktl get pods -n ingress-controller -o wide
NAME                                        READY   STATUS    RESTARTS   AGE   IP               NODE                                          NOMINATED NODE   READINESS GATES
ingress-nginx-controller-776cb4b9dd-4nm2c   1/1     Running   0          21h   100.112.44.136   ip-172-20-50-30.ap-south-1.compute.internal   <none>           <none>
```

Send request to ingress controller pod IP instead of customers service or pod IP. 

```shell
$ ingressControllerPod=100.112.44.136
$ ktl exec nginx -it -- curl --resolve test.ap-south-1.elb.amazonaws.com:80:$ingressControllerPod http://test.ap-south-1.elb.amazonaws.com/customers/1 | jq "."
{
  "id": "CUST_0001",
  "name": "Customer Name",
  "phoneNumber": "+911233243335",
  "gender": "M"
}
```

Now we are sending the request to the ingress controller Pod IP which is in turn sent to the customers service Pod.

Check the same for products service

```shell
$ ingressControllerPod=100.112.44.136
$ ktl exec nginx -it -- curl --resolve test.ap-south-1.elb.amazonaws.com:80:$ingressControllerPod http://test.ap-south-1.elb.amazonaws.com/products/1 | jq "."
{
  "id": "PROD_0001",
  "name": "Product Name",
  "price": 10
}
```

## How traffic can be sent to ingress pod?

A load balancer service can be added for the ingress controller. 
Such a service is already created for ingress deployment

```shell
$ ktl get services -n ingress-nginx
NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP                                                                PORT(S)                      AGE
ingress-nginx-controller             LoadBalancer   100.71.89.35     a17676a4bcc284ea5a83aa3eed5bb866-1255914040.ap-south-1.elb.amazonaws.com   80:30060/TCP,443:31577/TCP   22h
```
That means nginx controller pods are reachable at address: http://a17676a4bcc284ea5a83aa3eed5bb866-1255914040.ap-south-1.elb.amazonaws.com

Let's try to access customers and product endpoint from load balancer DNS. 

```shell
$ curl -s http://a17676a4bcc284ea5a83aa3eed5bb866-1255914040.ap-south-1.elb.amazonaws.com/customers/1 | jq "."
{
  "id": "CUST_0001",
  "name": "Customer Name",
  "phoneNumber": "+911233243335",
  "gender": "M"
}

$ curl -s http://a17676a4bcc284ea5a83aa3eed5bb866-1255914040.ap-south-1.elb.amazonaws.com/products/1 | jq "."
{
  "id": "PROD_0001",
  "name": "Product Name",
  "price": 10
}
```

---

# Slides

Refer Slides [here](TBA)

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

### Kops Bastion access

(Steps taken from kops documentation here: https://kops.sigs.k8s.io/bastion/)

Get the kops dns name for the bastion host

```shell
kops_1.18.2 toolbox dump -ojson | grep 'bastion.*elb.amazonaws.com'
```
Copy the DNSName. 

Add key to ssh agent (this is same key we used while cluster creation)

```shell
$ ssh-add ~/.ssh/id_rsa
```
Verify if key is added 
```shell
$ ssh-add -L
```

SSH into bastion node
```shell
ssh -A ubuntu@<bastion_elb_a_record>
ssh ubuntu@<master_ip>
```
