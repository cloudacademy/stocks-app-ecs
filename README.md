## ECS and Stocks Cloud Native App Deployment
The following instructions are provided to demonstrate how to provision a new ECS cluster and automatically deploy a fully functional Stocks cloud native web application into it.

An equivalent **EKS** setup is located here:
https://github.com/cloudacademy/stocks-app-eks

![Stocks App](/docs/stocks.png)

### ECS Architecture
The following architecture diagram documents an ECS Fargate cluster, Services, Tasks, ALB, Aurora RDS DB (serverless v1), Secrets Manager, and Stocks cloud native web application setup:

![Stocks App](/docs/ecs-stocks-v2.png)

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

Aurora RDS DB (serverless v1) SQL database:

- MySQL 5.7

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

    1.2. Provision a new ECS Fargate cluster, Services, Tasks, ALB, Aurora RDS DB (serverless v1), and Stocks cloud native web application automatically. Execute the following command:

    ```
    terraform apply -auto-approve
    ```

2. Examine ECS Cluster Resources

    2.1. List Clusters

    ```
    aws ecs list-clusters --region us-west-2
    ```

    2.2. List Cluster Services

    ```
    aws ecs list-services --cluster ecs-demo-cluster --region us-west-2
    ```

    2.3. List Cluster Tasks
    ```
    aws ecs list-tasks --cluster ecs-demo-cluster --region us-west-2
    ```

    2.4. List Task Definitions

    ```
    aws ecs list-task-definitions --region us-west-2
    ```

    2.4.1. Display the **Stocks API** Task Definition 

    ```
    TASK_DEFN=$(aws ecs describe-services --cluster ecs-demo-cluster --region us-west-2 --service stocksapi-Service --query "services[].taskDefinition" | jq -r ".[0]" | cut -d"/" -f2)
    aws ecs describe-task-definition --region us-west-2 --task-definition $TASK_DEFN
    ```

    **Note**: Review the `environment` block. This contains the credentials and a connection string used by the **Stocks API** to connect to the Aurora RDS backend database.

    ```
    "environment": [
        {
            "name": "DB_CONNSTR",
            "value": "jdbc:mysql://cloudacademy.cluster-abcd1234.us-west-2.rds.amazonaws.com:3306/cloudacademy"
        },
        {
            "name": "DB_USER",
            "value": "root"
        },
        {
            "name": "DB_PASSWORD",
            "value": "followthewhiterabbit"
        }
    ]
    ```

    2.4.2. Display the **Stocks APP** (frontend) Task Definition 

    ```
    TASK_DEFN=$(aws ecs describe-services --cluster ecs-demo-cluster --region us-west-2 --service stocksapp-Service --query "services[].taskDefinition" | jq -r ".[0]" | cut -d"/" -f2)
    aws ecs describe-task-definition --region us-west-2 --task-definition $TASK_DEFN
    ```

    **Note**: Review the `environment` block. This should now contain the ALB FQDN. Terraform injects the correct value at provisioning time dynamically. At runtime, this value is loaded into the web app, informing it where to route all AJAX calls (back via the ALB to the API target group).

    ```
    "environment": [
        {
            "name": "REACT_APP_APIHOSTPORT",
            "value": "ecs-demo-public-alb-1100561753.us-west-2.elb.amazonaws.com"
        }
    ]
    ```

3. Examine Aurora RDS DB

    3.1. List Database Clusters

    ```
    aws rds describe-db-clusters --region us-west-2
    ```

    3.2. List Database Cluster Endpoints

    ```
    aws rds describe-db-cluster-endpoints --db-cluster-identifier cloudacademy --region us-west-2
    ```

4. Generate and Test Stocks API Endpoint

    Execute the following command to generate Stocks API URL:

    ```
    ALB_FQDN=$(aws elbv2 describe-load-balancers --region us-west-2 | jq -r --arg name "ecs-demo-public-alb" '.LoadBalancers | .[] | select(.LoadBalancerName=="\($name)") | .DNSName')
    echo http://$ALB_FQDN/api/stocks/csv
    ```

    Copy the URL from the previous output and browse to it within your own browser. Confirm that the Stocks CSV formatted data is accessible.

5. Generate and Test Stocks APP (frontend) Endpoint

    Execute the following command to generate Stocks API URL:

    ```
    ALB_FQDN=$(aws elbv2 describe-load-balancers --region us-west-2 | jq -r --arg name "ecs-demo-public-alb" '.LoadBalancers | .[] | select(.LoadBalancerName=="\($name)") | .DNSName')
    echo http://$ALB_FQDN
    ```

    Copy the URL from the previous output and browse to it within your own browser. Confirm that the Stocks App (frontend) loads successfully.