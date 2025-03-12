![Build Status](https://github.com/cloudacademy/stocks-app-ecs/actions/workflows/release.yml/badge.svg) 
![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/cloudacademy/stocks-app-ecs)

## ECS and Stocks Cloud Native App Deployment
The following instructions are provided to demonstrate how to provision a new ECS cluster and automatically deploy a fully functional Stocks cloud native web application into it.

An equivalent **EKS** setup is located here:
https://github.com/cloudacademy/stocks-app-eks

![Stocks App](/docs/ecs-stocks-ui.png)

### ECS Architecture
The following architecture diagram documents an ECS Fargate Cluster, Services, Tasks, ALB, Aurora RDS DB (serverless v1), Secrets Manager, Cloud Map (service discovery), and Stocks cloud native web application setup:

![Stocks App](/docs/ecs-stocks-v3.png)

### Web Application Architecture
The Stocks cloud native web app consists of the following 3 main components:

#### Stocks App (frontend)

Implements a web UI using the following languages/frameworks:

- React 16
- Yarn
- Nginx

Source Code and Artifacts:

- GitHub Repo: https://github.com/cloudacademy/stocks-app
- Container Image: [cloudacademydevops/stocks-app:v3](https://hub.docker.com/r/cloudacademydevops/stocks-app)

#### Stocks API

Implements a RESTful based API using the following languages/frameworks:

- Java 17
- Spring Boot
- Maven 3

Source Code and Artifacts:

- GitHub Repo: https://github.com/cloudacademy/stocks-api
- Container Image: [cloudacademydevops/stocks-api:v2](https://hub.docker.com/r/cloudacademydevops/stocks-api)

#### Stocks DB

Aurora RDS DB (serverless v2) SQL database:

- MySQL 8.0

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

    1.2. Provision a new ECS Fargate cluster, Services, Tasks, ALB, Aurora RDS DB (serverless v1), Cloud Map (service discovery), and Stocks cloud native web application automatically. Execute the following command:

    ```
    terraform apply -auto-approve
    ```

    1.3. After the Terraforming completes successfully, an additional **1-2 minutes** is required for the entire system to stabilise. A pre-formatted script is provided in the Terraform output, named `web_app_wait_command`. Copy this script and execute it locally to be notified when the Stock App is ready to be browsed to:

    Example Script:
    ```
    until curl -Is --max-time 5 http://ecs-demo-public-alb-1234567890.us-west-2.elb.amazonaws.com/api/stocks/csv | grep 'HTTP/1.1 200'; do echo preparing...; sleep 5; done; echo; echo -e 'Ready...'
    ```

    Example Output:
    ```
    preparing...
    preparing...
    preparing...
    preparing...
    preparing...
    HTTP/1.1 200

    Ready...
    ```

    1.4. Generate a URL for Stock App. Execute the following command:
    ```
    echo http://$(terraform output --raw public-alb-fqdn)
    ```

    Browse to the URL and confirm that the full Stock App system is online:

    ![Stocks App](/docs/ecs-stocks-ui.png)

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

    **Note**: Review the `environment` block. This contains the database connection string used by the **Stocks API** to connect to the Aurora RDS backend database.

    ```
    "environment": [
        {
            "name": "DB_CONNSTR",
            "value": "jdbc:mysql://cloudacademy.cluster-abcd1234.us-west-2.rds.amazonaws.com:3306/cloudacademy"
        }
    ]
    ```

    **Note**: Review the `secrets` block. This contains the credentials used by the **Stocks API** to authenticate against the Aurora RDS backend database.

    ```
    "secrets": [
        {
            "name": "DB_USER",
            "valueFrom": "arn:aws:secretsmanager:us-west-2:1234567890:secret:db-creds-abcde1234567890-1234abcd:username::"
        },
        {
            "name": "DB_PASSWORD",
            "valueFrom": "arn:aws:secretsmanager:us-west-2:1234567890:secret:db-creds-abcde1234567890-1234abcd:password::"
        }
    ]
    ```

    2.4.2. Display the **Stocks App** (frontend) Task Definition 

    ```
    TASK_DEFN=$(aws ecs describe-services --cluster ecs-demo-cluster --region us-west-2 --service stocksapp-Service --query "services[].taskDefinition" | jq -r ".[0]" | cut -d"/" -f2)
    aws ecs describe-task-definition --region us-west-2 --task-definition $TASK_DEFN
    ```

    **Note**: Review the `environment` block. This should now contain the ALB FQDN, the API service discovery FQDN, and the VPC's DNS IP address. Terraform injects the correct values at provisioning time dynamically.

    ```
    "environment": [
        {
            "name": "REACT_APP_APIHOSTPORT",
            "value": "ecs-demo-public-alb-1234567890.us-west-2.elb.amazonaws.com"
        },
        {
            "name": "NGINX_APP_APIHOSTPORT",
            "value": "api.cloudacademy.terraform.local:8080"
        },
        {
          name  = "NGINX_DNS_RESOLVER"
          value = "10.10.0.2"
        }
    ]
    ```

    - `REACT_APP_APIHOSTPORT` represents the public facing ALB that the Stock App sits behind. This value is loaded dynamically into the web app, informing it where to route all AJAX calls to (back via the ALB).

    - `NGINX_APP_APIHOSTPORT` is dynamically inserted at launch time into the Stock App's Nginx config file (see below) to proxy API traffic downstream to the API tasks. [AWS Cloud Map](https://aws.amazon.com/cloud-map/) is used to provide service discovery for the API tasks. The FQDN `api.cloudacademy.terraform.local` is automatically registered within Route53 by Cloud Map and contains records for each individual API task (private IP address) spun up in the ECS cluster.

    - `NGINX_DNS_RESOLVER` is dynamically inserted at launch time into the Stock App's Nginx config file (see below) to resolve the `proxy_pass` target host FQDN.

    **Before** (Stocks App Container Image)
    ```
    server {
        listen 8080;
        set $target ${NGINX_APP_APIHOSTPORT};

        add_header Cache-Control no-cache;

        location / {
            root   /usr/share/nginx/html;
            index  index.html index.htm;
            try_files $uri $uri/ /index.html;
            expires -1;
        }

        location /api/stocks/csv {
            resolver         ${NGINX_DNS_RESOLVER} valid=300s;
            resolver_timeout 10s;

            proxy_pass http://$target;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }
    ```

    **After** (Stocks App Container Instance)
    ```
    server {
        listen 8080;
        set $target api.cloudacademy.terraform.local:8080;

        add_header Cache-Control no-cache;

        location / {
            root   /usr/share/nginx/html;
            index  index.html index.htm;
            try_files $uri $uri/ /index.html;
            expires -1;
        }

        location /api/stocks/csv {
            resolver         10.10.0.2 valid=300s;
            resolver_timeout 10s;

            proxy_pass http://$target;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }
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

5. Generate and Test Stocks App (frontend) Endpoint

    Execute the following command to generate Stocks API URL:

    ```
    ALB_FQDN=$(aws elbv2 describe-load-balancers --region us-west-2 | jq -r --arg name "ecs-demo-public-alb" '.LoadBalancers | .[] | select(.LoadBalancerName=="\($name)") | .DNSName')
    echo http://$ALB_FQDN
    ```

    Copy the URL from the previous output and browse to it within your own browser. Confirm that the Stocks App (frontend) loads successfully.

6. Troubleshooting

    [ECS Exec](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html) has been enabled on the ECS services (App and API). Exec into any running task to troubleshoot using the following command:

    Note: The Session Manager plugin for the AWS CLI needs to be installed locally.

    ```
    aws ecs execute-command \
    --cluster ecs-demo-cluster \
    --task <TASK ID> \
    --container <CONTAINER NAME> \
    --interactive --command <COMMAND>
    ```

    App (frontend) Task Exec Example:

    ```
    aws ecs execute-command \
    --cluster ecs-demo-cluster \
    --task 852341be5e0049809b5502360ada5a87 \
    --container stocksapp \
    --interactive --command "bash"
    ```

    API Task Exec Example:

    ```
    aws ecs execute-command \
    --cluster ecs-demo-cluster \
    --task 852341be5e0049809b5502360ada5a87 \
    --container stocksapi \
    --interactive --command "sh"
    ```