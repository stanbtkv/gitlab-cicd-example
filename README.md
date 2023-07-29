
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

#### Предварительная подготовка для работы с проектом
Перед началом работы необходимо установить:
 - [yc](https://cloud.yandex.ru/docs/cli/operations/install-cli)
 - [Terraform](https://cloud.yandex.ru/docs/tutorials/infrastructure-management/terraform-quickstart)
 - [Yandex.Cloud Terraform Provider](https://cloud.yandex.ru/docs/tutorials/infrastructure-management/terraform-quickstart)
 - [kubectl](https://kubernetes.io/ru/docs/tasks/tools/install-kubectl/)
 - [helm3](https://helm.sh/docs/intro/install/)
 - [Argo CD CLI](https://github.com/argoproj/argo-cd)

#### Установка кластера Managed Kubernetes в Yandex Cloud
Кластер Managed Kubernetes настраивается с помощью Terraform.
Состояние Terraform хранится в Yandex Object Storage, конфигурация описана в файле backend.conf.
Перед установкой необходимо заполнить файлы **backend.conf** и **secret.auto.tfvars** собственными данными. Примеры заполнения файлов backend.conf и secret.auto.tfvars находятся в файлах **backend.conf.example** и **secret.auto.tfvars.example**.

Порядок выполнения команд Terraform для инициализации кластера Managed Kubernetes:
   ```
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
В примере конфигурационного файла `\infrastructure\local\docker-compose\gitlab-runner\config.toml` блок
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
отвечает за настройку хранения кэша раннера в объектном храненилище MinIO.

### Настройка кластера Kubernetes
<a name="kubernetes_setup"></a>

