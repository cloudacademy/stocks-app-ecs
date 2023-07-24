## ECS and Stocks Cloud Native App Deployment
The following instructions are provided to demonstrate how to provision a new ECS cluster and automatically deploy a fully functional Stocks cloud native web application into it.

![Stocks App](/docs/stocks.png)

### ECS Architecture
The following architecture diagram documents an ECS Fargate cluster, Services, Tasks, ALB, Cloud Map (service registration and discovery), and Stocks cloud native web application setup:

![Stocks App](/docs/ecs-stocks.png)

### Web Application Architecture
The Stocks cloud native web app consists of the following 3 main components:

#### Stocks Frontend (App)

Implements a web UI using the following languages/frameworks:

- React 16
- Yarn

Source Code and Artifacts:

- GitHub Repo: https://github.com/cloudacademy/stocks-app
- Container Image: [cloudacademydevops/stocks-app](https://hub.docker.com/r/cloudacademydevops/stocks-app)

#### Stocks API

Implements a RESTful based API using the following languages/frameworks:

- Java 17
- Spring Boot
- Maven 3

Source Code and Artifacts:

- GitHub Repo: https://github.com/cloudacademy/stocks-api
- Container Image: [cloudacademydevops/stocks-api](https://hub.docker.com/r/cloudacademydevops/stocks-api)

#### Stocks DB

Provisons and populates a SQL database using the following technology:

- MySQL 8

Source Code and Artifacts:

- GitHub Repo: https://github.com/cloudacademy/stocks-db
- Container Image: [cloudacademydevops/stocks-db](https://hub.docker.com/r/cloudacademydevops/stocks-db)

### Prerequisites
Ensure that the following tools are installed and configured appropriately.

- Terraform CLI
- AWS CLI

Note: The terraforming commands below have been tested successfully using the following tools:

- `terraform`: 1.5.3
- `aws`: aws-cli/2.13.2

### Installation

1. Application Deployment

    1.1. Initialise the Terraform working directory. Execute the following commands:

    ```
    cd terraform
    terraform init
    ```

    1.2. Provision a new ECS Fargate cluster, Services, Tasks, ALB, Cloud Map (service registration and discovery), and Stocks cloud native web application automatically. Execute the following command:

    ```
    terraform apply -auto-approve
    ```

2. Examine ECS Cluster Resources

    2.1. List Clusters

    ```
    aws ecs list-clusters --region us-east-1
    ```

    2.2. List Cluster Services

    ```
    aws ecs list-services --cluster ecs-demo-cluster --region us-east-1
    ```

    2.3. List Cluster Tasks
    ```
    aws ecs list-tasks --cluster ecs-demo-cluster --region us-east-1
    ```

    2.4. List Task Definitions

    ```
    aws ecs list-task-definitions --region us-east-1
    ```

    2.4.1. Display StocksDB Task Definition 

    ```
    TASK_DEFN=$(aws ecs describe-services --cluster ecs-demo-cluster --region us-east-1 --service stocksdb-Service --query "services[].taskDefinition" | jq -r ".[0]" | cut -d"/" -f2)
    aws ecs describe-task-definition --region us-east-1 --task-definition $TASK_DEFN
    ```

    2.4.2. Display StocksAPI Task Definition 

    ```
    TASK_DEFN=$(aws ecs describe-services --cluster ecs-demo-cluster --region us-east-1 --service stocksapi-Service --query "services[].taskDefinition" | jq -r ".[0]" | cut -d"/" -f2)
    aws ecs describe-task-definition --region us-east-1 --task-definition $TASK_DEFN
    ```

    2.4.3. Display StocksAPP Task Definition 

    ```
    TASK_DEFN=$(aws ecs describe-services --cluster ecs-demo-cluster --region us-east-1 --service stocksapp-Service --query "services[].taskDefinition" | jq -r ".[0]" | cut -d"/" -f2)
    aws ecs describe-task-definition --region us-east-1 --task-definition $TASK_DEFN
    ```

3. Examine Cloud Map Service Discovery Resources

    3.1. List Namespaces

    ```
    aws servicediscovery list-namespaces --region us-east-1
    ```

    3.2. List Services

    ```
    aws servicediscovery list-services --region us-east-1
    ```

    3.3. Check Route53 Hosted Zone

    ```
    aws route53 list-hosted-zones-by-name --dns-name cloudacademy.terraform.local
    ```

    3.4. Check Route53 Hosted Zone Resource Records

    ```
    ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name cloudacademy.terraform.local | jq -r --arg name "cloudacademy.terraform.local." '.HostedZones | .[] | select(.Name=="\($name)") | .Id')
    aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID
    ```

4. Generate and Test Stocks URL Endpoint

    Execute the following command to generate Stocks URL:

    ```
    ALB_FQDN=$(aws elbv2 describe-load-balancers --region us-east-1 | jq -r --arg name "ecs-demo-public-alb" '.LoadBalancers | .[] | select(.LoadBalancerName=="\($name)") | .DNSName')
    echo http://$ALB_FQDN
    ```

    Copy the URL from the previous output and browse to it within your own browser.