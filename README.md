
<p align="center">
  <img src="https://storage.yandexcloud.net/git-example/logo.png">
</p>


- [Описание репозитория](#repo_desc)
- [Содержание CI/CD-пайплайна](#cicd_pipeline)
- [Задачи, выполняемые на каждом из этапов CI/CD](#cicd_pipeline_tasks)
  - [Test](#cicd_pipeline_test)
  - [Build](#cicd_pipeline_build)
  - [Release](#cicd_pipeline_release)
  - [Deploy](#cicd_pipeline_deploy)
- [Мониторинг](#monitoring)
  - [Мониторинг приложения](#app_monitoring)
  - [Мониторинг кластера Kubernetes](#k8s_monitoring)
- [Подготовка инфраструктуры](#infrastructure)
  - [Yandex.Cloud](#cloud_infrastructure)
  - [Для локального тестирования](#local_infrastructure)
    - [Настройка GitLab Runner](#gitlab_runner_setup)
    - [Настройка кластера Kubernetes](#kubernetes_setup)  


## Описание репозитория
<a name="repo_desc"></a>
В репозитории находится CI/CD-пайплайн для веб-приложения, реализованного на [Go](https://go.dev/) и [Node.js](https://nodejs.org/en).
Используются следующие инструменты:

- [GitLab](https://about.gitlab.com/)
- [MinIO](https://min.io/)
- [Sonatype Nexus](https://www.sonatype.com/products/sonatype-nexus-repository)
- [SonarQube](https://www.sonarsource.com/products/sonarqube/)
- [Kubernetes](https://kubernetes.io/)
- [MetalLB](https://metallb.universe.tf/)
- [cert-manager](https://cert-manager.io/)
- [Helm](https://helm.sh/)
- [Argo CD](https://argo-cd.readthedocs.io/)
- [Grafana](https://grafana.com/)
- [Prometheus](https://prometheus.io/)

Подготовка инфраструктуры для приложения происходит с помощью [Terraform](https://www.terraform.io/) и [Yandex.Cloud Provider](https://cloud.yandex.ru/docs/tutorials/infrastructure-management/terraform-quickstart).

## Содержание CI/CD-пайплайна
<a name="cicd_pipeline"></a>

<p align="center">
  <img src="https://storage.yandexcloud.net/git-example/ci-cd-pipeline.png">
</p>

Пайплайн непрерывной интеграции / непрерывной доставки содержит следующие этапы:
  - Test
  - Build
  - Release
  - Deploy

Используется механизм GitLab [Downstream pipeline](https://docs.gitlab.com/ee/ci/pipelines/downstream_pipelines.html), позволяющий одновременно и независимо выполнять задачи пайплайна для фронтенда и бэкенда.  
`Child pipeline backend/.gitlab-ci.yml` будет запущен только при изменениях в каталоге `backend`.  
`Child pipeline frontend/.gitlab-ci.yml` будет запущен только при изменениях в каталоге `frontend`.  

![](https://storage.yandexcloud.net/git-example/module-pipeline.gif)

При определении успешности статуса выполнения пайплайнов `module-backend` и `module-frontend` происходит [ожидание](https://docs.gitlab.com/ee/ci/yaml/index.html#triggerstrategy) окончания выполнения пайплайнов `backend/.gitlab-ci.yml` и `frontend/.gitlab-ci.yml`.


### Задачи, выполняемые на каждом из этапов CI/CD
<a name="cicd_pipeline_tasks"></a>

<p align="center">
  <img src="https://storage.yandexcloud.net/git-example/backend-pipeline-1.png">
</p>


#### **Test**
<a name="cicd_pipeline_test"></a>

  - [go test](https://pkg.go.dev/testing)
    - Находит все тесты для всех файлов в директории `backend` и запускает их.
  - [go vet](https://pkg.go.dev/cmd/vet)
    - Проверяет код на наличие синтаксических ошибок и подозрительных конструкций.
  - [semgrep-sast](https://semgrep.dev/)
    - Запускает инструмент статического анализа для поиска ошибок в коде.
  - [sonarqube-backend](https://docs.sonarsource.com/sonarqube/latest/analyzing-source-code/languages/go/)
    - Запускает платформу для непрерывной оценки качества кода путем статического анализа. После окончания работы формируется [отчет](https://storage.yandexcloud.net/git-example/sonarqube.png) с рекомендациями по устранению найденных ошибок.

#### **Build**
<a name="cicd_pipeline_build"></a>

  - [compile](https://storage.yandexcloud.net/git-example/compile.png)
    - Выполняет команду [go build](https://pkg.go.dev/cmd/go#hdr-Compile_packages_and_dependencies). В результате формируется и становится [артефактом](https://docs.gitlab.com/ee/ci/jobs/job_artifacts.html) исполняемый файл `$CI_PROJECT_DIR/backend/bin/api`
  - [docker-backend-image-build](https://storage.yandexcloud.net/git-example/docker-image-build.png)
    - Формирует Docker image, проставляет tag с номером версии вместе с `latest`. Публикация полученного Docker image происходит в [GitLab Container Registry](https://docs.gitlab.com/ee/user/packages/container_registry/) и [Docker Hub](https://hub.docker.com/r/stanbtkv/momo-backend/tags).
  - [package](https://storage.yandexcloud.net/git-example/package-registry.png)
    - Помещает артефакт `$CI_PROJECT_DIR/backend/bin/api` в [GitLab Package Registry](https://docs.gitlab.com/ee/user/packages/package_registry/)

Версионирование происходит согласно правилам [SemVer](https://semver.org/lang/ru/) в формате _мажорная.минорная.патч_, где в качестве _.патч_-номера используется переменная GitLab `${CI_PIPELINE_ID}`.

#### **Release**
<a name="cicd_pipeline_release"></a>

  - [helm-release](https://storage.yandexcloud.net/git-example/helm-release.png)
    - Выполняет команду `helm package . --app-version ${VERSION} --version ${VERSION}` в каталоге `/helm/backend`. В результате создаётся helm-чарт с заполненными [полями](https://helm.sh/docs/topics/charts/#the-chartyaml-file) `Chart version` и `App version`. Затем helm-чарт выгружается в репозиторий [Sonatype Nexus](https://storage.yandexcloud.net/git-example/nexus-repo.png).


#### **Deploy**
<a name="cicd_pipeline_deploy"></a>

<p align="center">
  <img src="https://storage.yandexcloud.net/git-example/argocd.png">
</p>

Непрерывное развертывание реализовано с помощью [Argo CD](https://argo-cd.readthedocs.io/) через Pull deployment в кластер Kubernetes. 

![](https://storage.yandexcloud.net/git-example/argocd-apps.gif)

##### Добавление репозитория и приложения в Argo CD
  - [argocd repo add](https://argo-cd.readthedocs.io/en/latest/user-guide/commands/argocd_repo_add/)
    - Добавляет репозиторий Nexus c Helm-чартами для приложения.
  - [argocd app create](https://argo-cd.readthedocs.io/en/latest/user-guide/commands/argocd_app_create/)
    - Добавляет приложение для синхронизации с кластером Kubernetes. Для автоматической синхронизации необходим параметр `--sync-policy auto`.


## **Мониторинг**
<a name="monitoring"></a>

### Мониторинг приложения
<a name="app_monitoring"></a>


![](https://storage.yandexcloud.net/git-example/golden-signals.png)


Существует несколько широко распространенных методологий мониторинга приложений:
  - ["Золотые сигналы"](https://sre.google/sre-book/monitoring-distributed-systems/)
    - Задержка (Latency), Трафик (Traffic), Ошибки (Errors), Насыщенность (Saturation).
  - [Метод USE](https://www.brendangregg.com/usemethod.html)
    - Использование (Utilization), Насыщенность (Saturation), Ошибки (Errors).
  - [Метод RED](https://grafana.com/blog/2018/08/02/the-red-method-how-to-instrument-your-services/)
    - Частота (Rate), Ошибки (Errors), Продолжительность (Duration).  


Запросы PromQL по методологии "Золотых сигналов" будут выглядеть следующим образом:

**Задержка (Latency)**
```
sum(response_timing_ms_sum{handler="/products/"})/sum(response_timing_ms_count{handler="/products/"})
```

**Трафик (Traffic)**
```
sum(rate(requests_count[5m]))
```

**Ошибки (Errors)**
```
sum(rate(http_request_duration_seconds_count{code!="200"}[10m]))
```

**Насыщенность (Saturation)**
```
100 - (avg by (node) (irate(node_cpu_seconds_total{node="int-kubernetes-master"}[5m])) * 100)
100 - (avg by (node) (irate(node_cpu_seconds_total{node="int-node-1"}[5m])) * 100)
100 - (avg by (node) (irate(node_cpu_seconds_total{node="int-node-2"}[5m])) * 100)
```




### Мониторинг кластера Kubernetes
<a name="k8s_monitoring"></a>

Для [визуализации](https://storage.yandexcloud.net/git-example/grafana-cluster-monitoring.gif) мониторинга кластера Kubernetes подходят [готовые](https://grafana.com/grafana/dashboards/8588-1-kubernetes-deployment-statefulset-daemonset-metrics/) [дашборды](https://grafana.com/grafana/dashboards/18882-well-kubernetes-nodes/).  

Получившийся результат:  

<p align="center">
  <img src="https://storage.yandexcloud.net/git-example/kubernetes-dashboards-lossy.gif">
</p>



## Подготовка инфраструктуры
<a name="infrastructure"></a>

### Yandex.Cloud
<a name="cloud_infrastructure"></a>

#### Предварительная подготовка
Перед началом работы необходимо установить:
 - [yc](https://cloud.yandex.ru/docs/cli/operations/install-cli)
 - [Terraform](https://cloud.yandex.ru/docs/tutorials/infrastructure-management/terraform-quickstart)
 - [Yandex.Cloud Terraform Provider](https://cloud.yandex.ru/docs/tutorials/infrastructure-management/terraform-quickstart)
 - [kubectl](https://kubernetes.io/ru/docs/tasks/tools/install-kubectl/)
 - [helm3](https://helm.sh/docs/intro/install/)
 - [Argo CD CLI](https://github.com/argoproj/argo-cd)

#### Установка кластера Managed Kubernetes в Yandex Cloud
Кластер Managed Kubernetes настраивается с помощью Terraform.
Состояние Terraform хранится в Yandex Object Storage, конфигурация описана в файле `backend.conf`.
Перед установкой необходимо заполнить файлы `backend.conf` и `secret.auto.tfvars` собственными данными. Примеры заполнения файлов `backend.conf` и `secret.auto.tfvars` находятся в файлах `backend.conf.example` и `secret.auto.tfvars.example`.

Порядок выполнения команд Terraform для инициализации кластера Managed Kubernetes:
   ```bash
    terraform init -backend-config=backend.conf
    terraform validate
    terraform plan
    terraform apply
   ```

После успешного выполнения операции в консоль будет выведен идентификатор кластера, который нужно использовать на следующем шаге (`ID_кластера`).

После инициализации кластера необходимо:
 - сформировать конфигурационный файл для подключения к кластеру с помощью yc
    `yc managed-kubernetes cluster get-credentials --id ID_кластера --internal`
 - установить [NGINX Ingress Controller](https://cloud.yandex.ru/docs/managed-kubernetes/tutorials/ingress-cert-manager) с менеджером для сертификатов Let's Encrypt


### Подготовка инфраструктуры для локального тестирования
<a name="local_infrastructure"></a>

YAML-файлы для установки всех сервисов с помощью Docker Compose находятся в каталоге `infrastructure\local\docker-compose\`. Перед использованием необходимо переименовать `example.env` в `.env` и заполнить эти файлы собственными значениями.

Для автоматического [получения](https://doc.traefik.io/traefik/https/acme/) сертификатов LetsEncrypt необходимо [делегировать](https://developers.cloudflare.com/dns/zone-setups/full-setup/setup/) домен на DNS-серверы CloudFlare и указать переменные `CLOUDFLARE_EMAIL`, `CLOUDFLARE_DNS_API_TOKEN`.

#### Настройка GitLab Runner
<a name="gitlab_runner_setup"></a>

Для [настройки](https://docs.gitlab.com/runner/configuration/autoscale.html#distributed-runners-caching) хранения кэша раннера в объектном хранилище MinIO в конфигурационный файл `config.toml` нужно добавить:

```yaml
  [runners.cache]
    Type = "s3"
    Path = "runner/cache"
    Shared = true
    [runners.cache.s3]
      ServerAddress = "minio.example.com"
      AccessKey = "AccessKey_content"
      SecretKey = "AccessKey_content"
      BucketName = "gitlab_bucket"
      Insecure = false
```

### Настройка кластера Kubernetes
<a name="kubernetes_setup"></a>

#### Предварительная подготовка, установка пакетов

**Отключение swap на всех ВМ**
```bash
# swapoff -a

# nano /etc/fstab
# /swap.img      none    swap    sw      0       0
```

**Проверка [уникальности](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#verify-mac-address) MAC-адресов и параметра `product_uuid` на всех ВМ**

```bash
# ip link
# sudo cat /sys/class/dmi/id/product_uuid
```

**Установка ebtables и ethtool**
```bash
apt install ebtables ethtool
```

**Установка kubeadm, kubelet, kubectl**
```bash
apt-get install -y apt-transport-https ca-certificates curl

curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

**Проверка версий установленных пакетов**
```bash
# kubeadm version
kubeadm version: &version.Info{Major:"1", Minor:"27", GitVersion:"v1.27.3", GitCommit:"25b4e43193bcda6c7328a6d147b1fb73a33f1598", GitTreeState:"clean", BuildDate:"2023-06-14T09:52:26Z", GoVersion:"go1.20.5", Compiler:"gc", Platform:"linux/amd64"}

# kubelet
I0704 20:26:51.995307    2029 server.go:415] "Kubelet version" kubeletVersion="v1.27.3"

# kubectl version --short
Flag --short has been deprecated, and will be removed in the future. The --short output will become the default.
Client Version: v1.27.3
Kustomize Version: v5.0.1
The connection to the server localhost:8080 was refused - did you specify the right host or port?
```


**Установка containerd**
```bash
wget https://github.com/containerd/containerd/releases/download/v1.7.0/containerd-1.7.0-linux-amd64.tar.gz
tar xvf containerd-1.7.0-linux-amd64.tar.gz
mv bin/* /usr/local/bin/
```

**Настройка containerd.service**
```bash
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
mkdir -p /usr/local/lib/systemd/system/
mv containerd.service /usr/local/lib/systemd/system/containerd.service

systemctl daemon-reload
systemctl enable --now containerd
```

**Добавление конфигурационного файла** `/etc/containerd/config.toml`
```bash
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
```

В файле `/etc/containerd/config.toml` необходимо исправить параметр  `SystemdCgroup` на `"true"` и перезагрузить containerd.
```bash
...
            SystemdCgroup = true
...
# service containerd restart
```


**Установка runc**
```bash
wget https://github.com/opencontainers/runc/releases/download/v1.1.7/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc
```

Проверка корректности установки и версии runc
```bash
# runc -v
runc version 1.1.7
commit: v1.1.7-0-g860f061b
spec: 1.0.2-dev
go: go1.20.3
libseccomp: 2.5.4
```

**Установка CNI plugins**
```bash
wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.3.0.tgz
```

**Настройка параметров** `/etc/sysctl.conf` **и автозагрузка модулей** `overlay`, `br_netfilter`.
```bash
# nano /etc/sysctl.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1

# modprobe br_netfilter overlay
# sysctl -p
```

```bash
# nano /etc/modules-load.d/k8s.conf
overlay
br_netfilter
```

#### Инициализация control plane

```bash
# 10.120.0.94 - IP-адрес ВМ, на которой будет работать control plane
# 10.200.0.0/16 - пул IP-адресов для запуска pod'ов, он должен отличаться от адресов, используемых в локальной сети.

# kubeadm init --apiserver-advertise-address=10.120.0.94 --pod-network-cidr=10.200.0.0/16
```

Результат выполнения команды:
```bash
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.120.0.94:6443 --token nbqhxd.rfplipgk4fjz6xki \
        --discovery-token-ca-cert-hash sha256:d48b757aaa9cfdcad1059b6e304ed0feeb7e553e71181bbd6ed6372a4b9eb996
```


Копирование конфигурационного файла для доступа к кластеру в домашнюю директорию пользователя:
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

export KUBECONFIG=$HOME/.kube/config
```

#### Установка Calico

Установка происходит в соответствии с официальной [документацией](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises).

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml

curl https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml -O

# ВАЖНО! Файл custom-resources.yaml необходимо отредактировать, по умолчанию в нем используется сеть 192.168.0.0/16, в нашем случае нужно установить 10.200.0.0/16
kubectl create -f custom-resources.yaml
```


После установки Calico статус Nodes сменился на Ready:
```bash
# kubectl get nodes
NAME                    STATUS   ROLES           AGE     VERSION
int-kubernetes-master   Ready    control-plane   19m     v1.27.3
int-node-1              Ready    <none>          7m22s   v1.27.3
```

Проверка статуса подов Calico:
```bash
# kubectl get pods -n calico-system
NAME                                       READY   STATUS    RESTARTS      AGE
calico-kube-controllers-594d4558bf-9lxpv   1/1     Running   0             2m22s
calico-node-6zqfw                          1/1     Running   2 (91s ago)   2m22s
calico-node-9lwl6                          1/1     Running   0             2m22s
calico-typha-594587b645-n2mmc              1/1     Running   1 (52s ago)   2m22s
csi-node-driver-2kpcv                      2/2     Running   0             2m22s
csi-node-driver-n6bvq                      2/2     Running   2 (14s ago)   2m22s
```

Установка `calicoctl`
```bash
curl -L https://github.com/projectcalico/calico/releases/latest/download/calicoctl-linux-amd64 -o calicoctl
chmod +x ./calicoctl
mv calicoctl /usr/local/bin/
```

Проверка выделенного пула адресов. Он должен соответствовать выделенному ранее пулу 10.200.0.0/16
```bash
# calicoctl get ippool -o wide
NAME                  CIDR            NAT    IPIPMODE   VXLANMODE     DISABLED   DISABLEBGPEXPORT   SELECTOR
default-ipv4-ippool   10.200.0.0/16   true   Never      CrossSubnet   false      false              all()
```

#### Присоединение Worker nodes к кластеру

```bash
kubeadm join 10.120.0.94:6443 --token nbqhxd.rfplipgk4fjz6xki \
        --discovery-token-ca-cert-hash sha256:d48b757aaa9cfdcad1059b6e304ed0feeb7e553e71181bbd6ed6372a4b9eb996
```


Результат выполнения команды:
```bash
[preflight] Running pre-flight checks
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

Проверка статуса присоединенной Node:
```bash
# kubectl get nodes
NAME     STATUS   ROLES           AGE     VERSION
master   Ready    control-plane   14m     v1.27.3
node1    Ready    <none>          2m19s   v1.27.3
```

Проверка статуса подов в неймспейсе kube-system после присоединения к кластеру двух нод:
```bash
# kubectl get pods -n kube-system -o wide

NAME                                            READY   STATUS    RESTARTS       AGE    IP               NODE                    NOMINATED NODE   READINESS GATES
coredns-5d78c9869d-2knrr                        1/1     Running   1 (91m ago)    144m   10.200.204.197   int-kubernetes-master   <none>           <none>
coredns-5d78c9869d-l7jrs                        1/1     Running   10 (96m ago)   144m   10.200.67.101    int-node-1              <none>           <none>
etcd-int-kubernetes-master                      1/1     Running   6 (91m ago)    144m   10.120.0.94      int-kubernetes-master   <none>           <none>
kube-apiserver-int-kubernetes-master            1/1     Running   6 (91m ago)    145m   10.120.0.94      int-kubernetes-master   <none>           <none>
kube-controller-manager-int-kubernetes-master   1/1     Running   8 (91m ago)    144m   10.120.0.94      int-kubernetes-master   <none>           <none>
kube-proxy-5hxf2                                1/1     Running   7 (91m ago)    144m   10.120.0.94      int-kubernetes-master   <none>           <none>
kube-proxy-fzknk                                1/1     Running   10 (91m ago)   134m   10.120.0.95      int-node-1              <none>           <none>
kube-proxy-r2p8k                                1/1     Running   1 (91m ago)    95m    10.120.0.96      int-node-2              <none>           <none>
kube-scheduler-int-kubernetes-master            1/1     Running   7 (91m ago)    144m   10.120.0.94      int-kubernetes-master   <none>           <none>
```


#### Итоговая проверка состояния кластера

```bash
# kubectl get nodes -o wide
NAME                    STATUS   ROLES           AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
int-kubernetes-master   Ready    control-plane   55m     v1.27.3   10.120.0.94   <none>        Ubuntu 22.04.2 LTS   5.15.0-76-generic   containerd://1.7.0
int-node-1              Ready    <none>          44m     v1.27.3   10.120.0.95   <none>        Ubuntu 22.04.2 LTS   5.15.0-76-generic   containerd://1.7.0
int-node-2              Ready    <none>          5m17s   v1.27.3   10.120.0.96   <none>        Ubuntu 22.04.2 LTS   5.15.0-76-generic   containerd://1.7.0
```

```bash
# kubectl get pods -o wide -A
NAMESPACE          NAME                                            READY   STATUS    RESTARTS         AGE     IP               NODE                    NOMINATED NODE   READINESS GATES
calico-apiserver   calico-apiserver-6dd8b6c769-pmrhr               1/1     Running   1 (74s ago)      35m     10.200.204.196   int-kubernetes-master   <none>           <none>
calico-apiserver   calico-apiserver-6dd8b6c769-w4879               1/1     Running   10 (3m51s ago)   35m     10.200.67.99     int-node-1              <none>           <none>
calico-system      calico-kube-controllers-594d4558bf-9lxpv        1/1     Running   4 (77s ago)      36m     10.200.67.100    int-node-1              <none>           <none>
calico-system      calico-node-6zqfw                               1/1     Running   8 (3m ago)       36m     10.120.0.95      int-node-1              <none>           <none>
calico-system      calico-node-9lwl6                               1/1     Running   1 (74s ago)      36m     10.120.0.94      int-kubernetes-master   <none>           <none>
calico-system      calico-node-wplbg                               1/1     Running   1 (67s ago)      4m34s   10.120.0.96      int-node-2              <none>           <none>
calico-system      calico-typha-594587b645-6l6mf                   1/1     Running   2 (29s ago)      4m30s   10.120.0.96      int-node-2              <none>           <none>
calico-system      calico-typha-594587b645-n2mmc                   1/1     Running   10 (26s ago)     36m     10.120.0.95      int-node-1              <none>           <none>
calico-system      csi-node-driver-2kpcv                           2/2     Running   2 (74s ago)      36m     10.200.204.198   int-kubernetes-master   <none>           <none>
calico-system      csi-node-driver-h6z6h                           2/2     Running   2 (67s ago)      4m34s   10.200.16.66     int-node-2              <none>           <none>
calico-system      csi-node-driver-n6bvq                           2/2     Running   16 (77s ago)     36m     10.200.67.102    int-node-1              <none>           <none>
kube-system        coredns-5d78c9869d-2knrr                        1/1     Running   1 (74s ago)      54m     10.200.204.197   int-kubernetes-master   <none>           <none>
kube-system        coredns-5d78c9869d-l7jrs                        1/1     Running   10 (5m55s ago)   54m     10.200.67.101    int-node-1              <none>           <none>
kube-system        etcd-int-kubernetes-master                      1/1     Running   6 (74s ago)      53m     10.120.0.94      int-kubernetes-master   <none>           <none>
kube-system        kube-apiserver-int-kubernetes-master            1/1     Running   6 (74s ago)      54m     10.120.0.94      int-kubernetes-master   <none>           <none>
kube-system        kube-controller-manager-int-kubernetes-master   1/1     Running   8 (74s ago)      53m     10.120.0.94      int-kubernetes-master   <none>           <none>
kube-system        kube-proxy-5hxf2                                1/1     Running   7 (74s ago)      54m     10.120.0.94      int-kubernetes-master   <none>           <none>
kube-system        kube-proxy-fzknk                                1/1     Running   10 (77s ago)     43m     10.120.0.95      int-node-1              <none>           <none>
kube-system        kube-proxy-r2p8k                                1/1     Running   1 (67s ago)      4m34s   10.120.0.96      int-node-2              <none>           <none>
kube-system        kube-scheduler-int-kubernetes-master            1/1     Running   7 (74s ago)      53m     10.120.0.94      int-kubernetes-master   <none>           <none>
tigera-operator    tigera-operator-5f4668786-mv57z                 1/1     Running   10 (22s ago)     37m     10.120.0.95      int-node-1              <none>           <none>
```

Под calico-node-xxxx должен быть запущен на каждой ноде:
```bash
# kubectl get pods -n calico-system -o wide | grep calico-node
calico-node-6zqfw                          1/1     Running   10 (8m50s ago)   24h   10.120.0.95      int-node-1              <none>           <none>
calico-node-9lwl6                          1/1     Running   3 (9m14s ago)    24h   10.120.0.94      int-kubernetes-master   <none>           <none>
calico-node-wplbg                          1/1     Running   8 (8m43s ago)    24h   10.120.0.96      int-node-2              <none>           <none>
```

```bash
# Команду calicoctl node status нужно запустить на каждой ноде
# calicoctl node status
Calico process is running.

IPv4 BGP status
+--------------+-------------------+-------+----------+-------------+
| PEER ADDRESS |     PEER TYPE     | STATE |  SINCE   |    INFO     |
+--------------+-------------------+-------+----------+-------------+
| 10.120.0.95  | node-to-node mesh | up    | 09:12:32 | Established |
| 10.120.0.96  | node-to-node mesh | up    | 09:12:32 | Established |
+--------------+-------------------+-------+----------+-------------+

IPv6 BGP status
No IPv6 peers found.
```

<details>
  <summary>Проверка Kubernetes API health endpoints</summary>
  
  ```bash
    # kubectl get --raw='/readyz?verbose'
  [+]ping ok
  [+]log ok
  [+]etcd ok
  [+]etcd-readiness ok
  [+]informer-sync ok
  [+]poststarthook/start-kube-apiserver-admission-initializer ok
  [+]poststarthook/generic-apiserver-start-informers ok
  [+]poststarthook/priority-and-fairness-config-consumer ok
  [+]poststarthook/priority-and-fairness-filter ok
  [+]poststarthook/storage-object-count-tracker-hook ok
  [+]poststarthook/start-apiextensions-informers ok
  [+]poststarthook/start-apiextensions-controllers ok
  [+]poststarthook/crd-informer-synced ok
  [+]poststarthook/start-system-namespaces-controller ok
  [+]poststarthook/bootstrap-controller ok
  [+]poststarthook/rbac/bootstrap-roles ok
  [+]poststarthook/scheduling/bootstrap-system-priority-classes ok
  [+]poststarthook/priority-and-fairness-config-producer ok
  [+]poststarthook/start-cluster-authentication-info-controller ok
  [+]poststarthook/start-kube-apiserver-identity-lease-controller ok
  [+]poststarthook/start-deprecated-kube-apiserver-identity-lease-garbage-collector ok
  [+]poststarthook/start-kube-apiserver-identity-lease-garbage-collector ok
  [+]poststarthook/start-legacy-token-tracking-controller ok
  [+]poststarthook/aggregator-reload-proxy-client-cert ok
  [+]poststarthook/start-kube-aggregator-informers ok
  [+]poststarthook/apiservice-registration-controller ok
  [+]poststarthook/apiservice-status-available-controller ok
  [+]poststarthook/kube-apiserver-autoregistration ok
  [+]autoregister-completion ok
  [+]poststarthook/apiservice-openapi-controller ok
  [+]poststarthook/apiservice-openapiv3-controller ok
  [+]poststarthook/apiservice-discovery-controller ok
  [+]shutdown ok
  readyz check passed
  ```

  ```bash
  # curl -k https://localhost:6443/livez?verbose
  
  [+]ping ok
  [+]log ok
  [+]etcd ok
  [+]poststarthook/start-kube-apiserver-admission-initializer ok
  [+]poststarthook/generic-apiserver-start-informers ok
  [+]poststarthook/priority-and-fairness-config-consumer ok
  [+]poststarthook/priority-and-fairness-filter ok
  [+]poststarthook/storage-object-count-tracker-hook ok
  [+]poststarthook/start-apiextensions-informers ok
  [+]poststarthook/start-apiextensions-controllers ok
  [+]poststarthook/crd-informer-synced ok
  [+]poststarthook/start-system-namespaces-controller ok
  [+]poststarthook/bootstrap-controller ok
  [+]poststarthook/rbac/bootstrap-roles ok
  [+]poststarthook/scheduling/bootstrap-system-priority-classes ok
  [+]poststarthook/priority-and-fairness-config-producer ok
  [+]poststarthook/start-cluster-authentication-info-controller ok
  [+]poststarthook/start-kube-apiserver-identity-lease-controller ok
  [+]poststarthook/start-deprecated-kube-apiserver-identity-lease-garbage-collector ok
  [+]poststarthook/start-kube-apiserver-identity-lease-garbage-collector ok
  [+]poststarthook/start-legacy-token-tracking-controller ok
  [+]poststarthook/aggregator-reload-proxy-client-cert ok
  [+]poststarthook/start-kube-aggregator-informers ok
  [+]poststarthook/apiservice-registration-controller ok
  [+]poststarthook/apiservice-status-available-controller ok
  [+]poststarthook/kube-apiserver-autoregistration ok
  [+]autoregister-completion ok
  [+]poststarthook/apiservice-openapi-controller ok
  [+]poststarthook/apiservice-openapiv3-controller ok
  [+]poststarthook/apiservice-discovery-controller ok
  livez check passed
  ```
</details>




```bash
# kubectl get componentstatuses
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE                         ERROR
scheduler            Healthy   ok
controller-manager   Healthy   ok
etcd-0               Healthy   {"health":"true","reason":""}
```

```bash
# kubectl get events --all-namespaces --sort-by=.metadata.creationTimestamp
```