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

## Install Kind

Install kind as shown [here](https://kind.sigs.k8s.io/docs/user/quick-start/#installation).

### For MacOS
```shell
brew install kind
```

## Create a kind cluster

Create a kind cluster (v1.18.x)

```shell
kind create cluster --image kindest/node:v1.18.20 --name kind18  --wait 5m
ktl get pods 
```

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
$ ktl exec customers -- curl http://localhost:8080
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
NAME        READY   STATUS    RESTARTS   AGE   IP           NODE                   NOMINATED NODE   READINESS GATES
customers   1/1     Running   0          46m   10.244.0.8   kind18-control-plane   <none>           <none>
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
customers   1/1     Running   0          73m
nginx       1/1     Running   0          26s
```

## Access the pod with the pod IP

```shell
$ podIP=10.244.0.8
$ ktl exec nginx -- curl --no-progress-meter http://$podIP:8080/customers/1 | jq "."
{
  "id": "CUST_0001",
  "name": "Customer Name",
  "phoneNumber": "+911233243335",
  "gender": "M"
}
```

# Application as a deployments (instead of pods)

## Remove pod

```shell
ktl delete pod details
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
NAME                         READY   STATUS    RESTARTS   AGE   IP            NODE                   NOMINATED NODE   READINESS GATES
customers-568c95b849-7jhh5   1/1     Running   0          45s   10.244.0.10   kind18-control-plane   <none>           <none>
customers-568c95b849-x2q54   1/1     Running   0          45s   10.244.0.11   kind18-control-plane   <none>           <none>
nginx                        1/1     Running   0          18h   10.244.0.9    kind18-control-plane   <none>           <none>
```

Access application with any's ip address

```shell
ktl exec nginx -- curl --no-progress-meter http://10.244.0.14:9080/details/1
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
