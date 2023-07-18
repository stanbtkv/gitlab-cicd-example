# Momo Store aka Пельменная №2

<img width="900" alt="image" src="https://user-images.githubusercontent.com/9394918/167876466-2c530828-d658-4efe-9064-825626cc6db5.png">

## Проект для демонстрации полного цикла сборки и поставки приложения с помощью практик и инструментов CI/CD.

**Для реализации проекта использованы**:

 - GitLab для управления репозиториями, процессами CI/CD и SAST-анализа кода
 - Nexus и Docker Hub для хранения артефактов
 - SonarQube для измерения качества программного кода
 - Terraform для декларативного управления инфраструктурой с использованием подхода Infrastructure as code
 - Kubernetes - платформа оркестрации контейнеризированных приложений
 - Helm - пакетный менеджер для Kubernetes
 - ArgoCD - инструмент continuous delivery для Kubernetes, позволяющий реализовать подход GitOps
 - Grafana, Loki, Promtail, Prometheus для сбора данных и визуализации мониторинга

**Чек-лист по функционалу, реализованному в проекте**:

- [x] Код хранится в GitLab с использованием любого git-flow
- [x] В проекте присутствует .gitlab-ci.yml, в котором описаны шаги сборки
- [x] Артефакты сборки (бинарные файлы, docker-образы или др.) публикуются в систему хранения (Nexus или аналоги)
- [x] Артефакты сборки версионируются
- [x] Написаны Dockerfile'ы для сборки Docker-образов бэкенда и фронтенда
- [x] Бэкенд: бинарный файл Go в Docker-образе
- [x] Фронтенд: HTML-страница раздаётся с Nginx
- [x] В GitLab CI описан шаг сборки и публикации артефактов
- [x] В GitLab CI описан шаг тестирования
- [x] В GitLab CI описан шаг деплоя
- [x] Развёрнут Kubernetes-кластер в облаке
- [x] Kubernetes-кластер описан в виде кода, и код хранится в репозитории GitLab
- [x] Конфигурация всех необходимых ресурсов описана согласно IaC
- [x] Состояние Terraform'а хранится в S3
- [x] Картинки, которые использует сайт, или другие небинарные файлы, необходимые для работы, хранятся в S3
- [x] Секреты не хранятся в открытом виде
- [x] Написаны Kubernetes-манифесты для публикации приложения
- [x] Написан Helm-чарт для публикации приложения
- [x] Helm-чарты публикуются и версионируются в Nexus
- [x] Приложение подключено к системам логирования и мониторинга
- [x] Есть дашборд, в котором можно посмотреть логи и состояние приложения

### Предварительная подготовка для работы с проектом

 - Установить [yc](https://cloud.yandex.ru/docs/cli/operations/install-cli)
 - Установить [Terraform](https://cloud.yandex.ru/docs/tutorials/infrastructure-management/terraform-quickstart) и настроить провайдер Yandex Cloud
 - Установить [kubectl](https://kubernetes.io/ru/docs/tasks/tools/install-kubectl/)
 - Установить [helm3](https://helm.sh/docs/intro/install/)
 - Установить [Argocd CLI](https://github.com/argoproj/argo-cd) (опционально)


### Установка кластера Managed Kubernetes в Yandex Cloud
Кластер Managed Kubernetes устанавливается с помощью Terraform.
Состояние Terraform хранится в Yandex Object Storage, конфигурация описана в файле backend.conf.
Перед установкой необходимо заполнить файлы **backend.conf** и **secret.auto.tfvars** собственными данными. Примеры заполнения файлов backend.conf и secret.auto.tfvars находятся в файлах **backend.conf.example** и **secret.auto.tfvars.example**.



Порядок выполнения команд Terraform для инициализации кластера Managed Kubernetes:
   ```
    terraform init -backend-config=backend.conf
    terraform validate
    terraform plan
    terraform apply
   ```
После успешного выполнения операции в консоль будет выведен идентификатор кластера, который нужно использовать на следующем шаге ("ID_кластера").

После инициализации кластера необходимо:

 - сформировать конфигурационный файл для подключения к кластеру с помощью yc

    yc managed-kubernetes cluster get-credentials --id ID_кластера --internal


 - установить [NGINX Ingress Controller](https://cloud.yandex.ru/docs/managed-kubernetes/tutorials/ingress-cert-manager) с менеджером для сертификатов Let's Encrypt


### Как происходит работа с репозиторием и обновление приложения
После появления новой версии frontend или backend в результате выполнения пайплайна GitLab собирается новый docker image, Helm-чарт формируется, версионируется и публикуется в Nexus.
ArgoCD настроен на обновление приложений в режиме Auto-Sync и при появлении новой версии Helm-чарта в Nexus обновление произойдет автоматически.


### Ссылки на приложение и инструменты
 - [ ] https://argocd.momo-store.ru/
 - [ ] https://grafana.momo-store.ru/

**Helm-чарты**
 - [ ] https://nexus.praktikum-services.ru/#browse/browse:helmfront11
 - [ ] https://nexus.praktikum-services.ru/#browse/browse:helmback11

**Docker Hub**
 - [ ] https://hub.docker.com/repository/docker/stanbtkv/momo-frontend
 - [ ] https://hub.docker.com/repository/docker/stanbtkv/momo-backend


**И самое главное - наша новая пельменная**:
 - [ ] https://momo-store.ru/