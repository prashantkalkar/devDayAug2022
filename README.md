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

Slides [here](TBA)

# Pod Application access 

## Install detailed Service

```shell
ktl apply -f resources/details_pod.yaml
ktl get pods -w
```
Wait till pod is running

```shell
$ ktl get pods
NAME      READY   STATUS    RESTARTS   AGE
details   1/1     Running   0          50m
```

## Install supporting pod to access the pod

Run a supporting container to access the application. 

```shell
$ ktl run nginx --image=nginx
$ ktl get pods -w
$ ktl get pods
NAME      READY   STATUS    RESTARTS   AGE
details   1/1     Running   0          50m
nginx     1/1     Running   0          24m
```

## Access the pod with the pod IP

```shell
$ podIP=$(ktl get pods details -o json | jq -r ".status.podIP")
$ ktl exec nginx -- curl --no-progress-meter http://$podIP:9080/details/1 | jq "."
{
  "id": 1,
  "author": "William Shakespeare",
  "year": 1595,
  "type": "paperback",
  "pages": 200,
  "publisher": "PublisherA",
  "language": "English",
  "ISBN-10": "1234567890",
  "ISBN-13": "123-1234567890"
}
```

# Application as a deployments (instead of pods)

## Remove pod

```shell
ktl delete pod details
```

## Deploy application as deployment with multiple replicas

```shell
$ ktl apply -f resources/details_deployment.yaml
$ ktl get pods
NAME                       READY   STATUS    RESTARTS   AGE
details-7d8cc45485-26sz5   1/1     Running   0          14m
details-7d8cc45485-sdhpr   1/1     Running   0          4m54s
nginx                      1/1     Running   0          79m
```

# Switching kubectl context and namespaces

## List all contexts

```shell
ktl config get-contexts
```
or list just context names

```shell
ktl config get-contexts -o name
```

## Switch context

```shell
ktl config use-context kind-kind18
```
`kind-kind18` will become the current context.  

## List all namespaces

```shell
ktl get namespaces
```

## Switch current kubectl context namespace

```shell
ktl config set-context --current --namespace=kube-system
```
`kube-system` will become current namespace for current context. 

```shell
ktl get pods
```
Will provide pods running in current selected namespace for current context.

TIP: It is recommended to install [kubectx](https://github.com/ahmetb/kubectx) to make it easy to switch between contexts and namespaces.  
