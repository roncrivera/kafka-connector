# Installing kafka-connector via Helm

[Helm](https://github.com/kubernetes/helm) is a client CLI used to deploy Kubernetes applications. It supports templating of configuration files, but also needs a server component installing called `tiller`.

For more information on using Helm, refer to the Helm's [documentation](https://docs.helm.sh/using_helm/#quickstart-guide).

You can use this [chart](chart/kafka-connector) to install the kafka-connector to your OpenFaaS cluster.

## Prerequisites

* Install Helm

On Linux and Mac/Darwin:

```sh
$ curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash
```

Or via Homebrew on Mac:

```sh
$ brew install kubernetes-helm
```

* Create RBAC permissions for Tiller

```sh
$ kubectl -n kube-system create sa tiller \
 && kubectl create clusterrolebinding tiller \
      --clusterrole cluster-admin \
      --serviceaccount=kube-system:tiller
```

* Install the server-side Tiller component on your cluster

```sh
$ helm init --skip-refresh --upgrade --service-account tiller
```

> Note: this step installs a server component in your cluster. It can take anywhere between a few seconds to a few minutes to be installed properly. You should see tiller appear on: `kubectl get pods -n kube-system`.

* Generate secrets for basic authentication

```sh
# generate a random password
$ PASSWORD=$(head -c 12 /dev/urandom | shasum| cut -d' ' -f1)

$ kubectl -n openfaas create secret generic basic-auth \
--from-literal=basic-auth-user=admin \
--from-literal=basic-auth-password="$PASSWORD"
```

## Deploy from the chart repo

* Add the kafka-connector chart repo:

```sh
$ helm repo add kafka-connector https://openfaas-incubator.github.io/kafka-connector/
```

* Install the helm chart

```sh
$ helm upgrade kafka-connector --install openfaas-incubator/kafka-connector \
    --namespace openfaas
```

> The above command will also update your helm repo to pull in any new releases.

## Deploy with `helm template`
This option is good for those that have issues with installing Tiller, the server/cluster component of helm. Using the `helm` CLI, we can pre-render and then apply the templates using `kubectl`.

1. Clone the kafka-connector repository
    ```sh
    $ git clone https://github.com/openfaas-incubator/kafka-connector.git
    ```

2. Render the chart to a Kubernetes manifest called `kafka-connector.yaml`
    ```sh
    $ helm template kafka-connector/chart/kafka-connector \
        --name kafka-connector \
        --namespace openfaas > $HOME/kafka-connector.yaml
    ```
    You can set the values and overrides just as you would in the install/upgrade commands.

3. Install the components using `kubectl`
    ```sh
    $ kubectl apply -f $HOME/kafka-connector.yaml
    ```

## Deploy for development / testing

You can run the following command from within the `kafka-connector/chart` folder in the `kafka-connector` repo.

```sh
$ helm install --namespace openfaas --name kafka-connector ./kafka-connector
```

## Verify the installation

* Verify that the pods are running:

```sh
$ kubectl -n openfaas get pod
NAME                              READY   STATUS    RESTARTS   AGE
alertmanager-59f4bcdd98-2mm8d     1/1     Running   0          14m
faas-idler-57596ffb59-8pntr       1/1     Running   1          14m
gateway-865d95f5fc-xcg4t          2/2     Running   1          14m
kafka-broker-c745cc45f-r6m5t      1/1     Running   0          8m53s
kafka-connector-d6c8b456c-k5cnq   1/1     Running   0          8m53s
nats-7b7fc46674-j7hhz             1/1     Running   0          14m
prometheus-56cf774986-ggt6g       1/1     Running   0          14m
queue-worker-84f7467cbd-hwfk9     1/1     Running   1          14m
zookeeper-fb474868b-2tcdb         1/1     Running   0          8m53s
```

* Deploy a function with a topic annotation:

```sh
$ faas store deploy figlet --annotation topic="faas-request" --gateway <gateway-url>
```

Then wait for the function pod to be on a ready state:

```sh
$ kubectl -n openfaas-fn get pod
NAME                     READY   STATUS    RESTARTS   AGE
figlet-7bc757f58-h52ml   1/1     Running   0          25s
```

* Login to the broker to send messages to the topic:

```sh
BROKER=$(kubectl get pods -n openfaas -l component=kafka-broker -o name|cut -d'/' -f2)
kubectl exec -n openfaas -t -i $BROKER -- /opt/kafka_2.12-0.11.0.1/bin/kafka-console-producer.sh --broker-list kafka:9092 --topic faas-request

>Hello OpenFaaS!
>FaasFriday
```

* Check the connector logs to see the figlet function was invoked:

```sh
CONNECTOR=$(kubectl get pods -n openfaas -o name|grep kafka-connector|cut -d'/' -f2)
kubectl logs -n openfaas -f --tail 100 $CONNECTOR

[...]
[...]
[...]

[#1] Received on [faas-request,0]: 'Hello OpenFaaS!'
2019/01/29 02:07:53 Invoke function: figlet
2019/01/29 02:07:53 Response [200] from figlet  _   _      _ _          ___                   _____           ____  _
| | | | ___| | | ___    / _ \ _ __   ___ _ __ |  ___|_ _  __ _/ ___|| |
| |_| |/ _ \ | |/ _ \  | | | | '_ \ / _ \ '_ \| |_ / _` |/ _` \___ \| |
|  _  |  __/ | | (_) | | |_| | |_) |  __/ | | |  _| (_| | (_| |___) |_|
|_| |_|\___|_|_|\___/   \___/| .__/ \___|_| |_|_|  \__,_|\__,_|____/(_)
                             |_|
2019/01/29 02:07:54 Syncing topic map
2019/01/29 02:07:57 Syncing topic map
[#2] Received on [faas-request,0]: 'FaaSFriday'
2019/01/29 02:07:59 Invoke function: figlet
2019/01/29 02:07:59 Response [200] from figlet  _____           ____  _____     _     _
|  ___|_ _  __ _/ ___||  ___| __(_) __| | __ _ _   _
| |_ / _` |/ _` \___ \| |_ | '__| |/ _` |/ _` | | | |
|  _| (_| | (_| |___) |  _|| |  | | (_| | (_| | |_| |
|_|  \__,_|\__,_|____/|_|  |_|  |_|\__,_|\__,_|\__, |
                                               |___/
2019/01/29 02:08:00 Syncing topic map
2019/01/29 02:08:03 Syncing topic map
2019/01/29 02:08:06 Syncing topic map
```

## Configuration

Additional kafka-connector options in `values.yaml`.

| env_var               | description                                                 |
| --------------------- |----------------------------------------------------------   |
| `upstream_timeout`      | Go duration - maximum timeout for upstream function call    |
| `rebuild_interval`      | Go duration - interval for rebuilding function to topic map |
| `topics`                | Topics to which the connector will bind                     |
| `gateway_url`           | The URL for the API gateway i.e. http://gateway:8080 or http://gateway.openfaas:8080 for Kubernetes       |
| `broker_host`           | Default is `kafka`                                          |
| `print_response`        | Default is `true` - this will output the response of calling a function in the logs |

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`.
See values.yaml for detailed configuration.

## Removing the kafka-connector

All control plane components can be cleaned up with helm:

```sh
$ helm delete --purge kafka-connector
```
