# CloudCost Optimized Multi-Tier Web App

This project is a multi-tier web application deployed on AWS, designed with a focus on cost optimization, scalability, and security. It features a Python Flask backend, a simple HTML/JS frontend, and leverages a suite of AWS services provisioned via Terraform. The entire application is deployed and managed through a CI/CD pipeline powered by Jenkins.

---

## Tech Stack

| Category      | Technology                                                              |
|---------------|-------------------------------------------------------------------------|
| **Frontend**  | HTML, CSS, Vanilla JavaScript                                           |
| **Backend**   | Python, Flask, SQLAlchemy                                               |
| **Database**  | AWS RDS (Postgres)                                                      |
| **IaC**       | Terraform (VPC, ALB, ASG, RDS, Secrets Manager)                         |
| **CI/CD**     | Jenkins, Docker                                                         |
| **Monitoring**| AWS CloudWatch (Metrics, Alarms, Logs)                                  |

---

## Project Structure

```
cloudcost-webapp/
├── backend/
│   ├── app.py
│   ├── Dockerfile
│   ├── requirements.txt
│   └── .dockerignore
├── frontend/
│   └── index.html
├── terraform/
│   ├── provider.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── cloudwatch.tf
│   └── autoscaling.tf
├── jenkins/
│   ├── Jenkinsfile
│   └── docker-compose.yml
├── .gitignore
└── README.md
```

---

## Getting Started

Follow these steps to provision the infrastructure and deploy the application.

### Prerequisites

- [AWS CLI](https://aws.amazon.com/cli/) configured with your credentials.
- [Terraform](https://www.terraform.io/downloads.html) installed.
- [Docker Desktop](https://www.docker.com/products/docker-desktop) installed and running.

### 1. Provision Infrastructure

Navigate to the `terraform` directory and run the following commands. You will be prompted to enter a database password.

```bash
cd terraform
export TF_VAR_db_password="yoursecurepassword"
terraform init
terraform apply
```

Take note of the `alb_dns_name` and `rds_endpoint` from the Terraform outputs.

### 2. Start Jenkins

The Jenkins server runs locally via Docker Compose.

```bash
cd ../jenkins
docker-compose up -d
```

You can access the Jenkins UI at `http://localhost:8080`.

### 3. Run the CI/CD Pipeline

In the Jenkins UI, find the `cloudcost-pipeline` and trigger a new build by clicking **Build Now**. This pipeline will:
1.  Check out the latest code from your repository.
2.  Build a new Docker image for the backend application.
3.  Push the image to Docker Hub.

### 4. Deploy the New Version

The application is deployed to an Auto Scaling Group (ASG). To roll out the new version, you must trigger an "Instance Refresh" in the AWS Console.

1.  Go to **EC2 > Auto Scaling Groups**.
2.  Select your group.
3.  Go to the **Instance Refresh** tab and click **Start Instance Refresh**.

AWS will automatically terminate old instances and launch new ones, which will pull the latest Docker image on startup.

### 5. Verify the Deployment

You can verify that the application is running by sending a request to the ALB's DNS name.

```bash
curl http://<your_alb_dns_name>/tasks
```

### 6. Tear Down

When you are finished, destroy all the AWS resources to avoid incurring further costs.

```bash
cd ../terraform
terraform destroy
```

---

## Development & Architectural Notes

This section contains detailed notes on the project's evolution through different phases, from a simple local application to a fully cloud-native, auto-scaling architecture.

<details>
<summary>Phase 1 - Local Backend & Frontend</summary>

-   **Backend**: A simple Flask REST API with three endpoints (`GET /tasks`, `POST /tasks`, `DELETE /tasks/<id>`) using an in-memory list as a database.
-   **Frontend**: A single `index.html` file using vanilla JavaScript and the `fetch()` API to interact with the backend.
-   **Key Concepts**: Flask routing, JSON serialization, virtual environments, and CORS.

</details>

<details>
<summary>Phase 2 - Database Integration (SQLite)</summary>

-   **Change**: Replaced the in-memory list with a local SQLite database using SQLAlchemy as the ORM.
-   **Key Concepts**: `db.Model` for table schemas, `db.session` for transactions, and the difference between a local file-based database and a managed service like RDS.

</details>

<details>
<summary>Phase 3 - Infrastructure as Code (Terraform)</summary>

-   **Infrastructure**: Provisioned the core AWS networking (VPC, Subnets), compute (EC2), and database (RDS) resources using Terraform.
-   **Key Concepts**: Terraform resource dependencies, passing sensitive variables via environment (`TF_VAR_`), and using `user_data` to bootstrap the EC2 instance.

</details>

<details>
<summary>Phase 4 - CI/CD with Jenkins</summary>

-   **Pipeline**: Set up a Jenkins server locally using `docker-compose`. The Jenkinsfile defines a pipeline that automates the building and pushing of the backend Docker image to Docker Hub.
-   **Key Concepts**: Docker-in-Docker (via socket mounting), managing credentials securely within Jenkins, and using `BUILD_NUMBER` for versioning.

</details>

<details>
<summary>Phase 5 - Monitoring with CloudWatch</summary>

-   **Monitoring**: Added CloudWatch resources to the Terraform configuration, including Log Groups, Alarms, and a Dashboard.
-   **Key Concepts**: CloudWatch Metrics vs. Logs, creating Alarms based on thresholds, and using IAM Roles to grant EC2 instances permission to send logs to CloudWatch.

</details>

<details>
<summary>Phase 6 - High Availability & Auto-Scaling</summary>

-   **Architecture**: Replaced the single EC2 instance with an Application Load Balancer (ALB), an Auto Scaling Group (ASG), and a Launch Template.
-   **Deployment**: The deployment strategy shifted from a "push" model (SSH) to a "pull" model where the ASG's "Instance Refresh" feature triggers a rolling update.
-   **Key Concepts**: Self-healing infrastructure, health checks, and declarative scaling policies.

</details>

<details>
<summary>Phase 7 - Advanced Security & Logging</summary>

-   **Security**: Migrated the database password from an environment variable to AWS Secrets Manager. The Flask application now fetches the password at runtime using `boto3` and an IAM Role.
-   **Logging**: Configured the Docker daemon on the EC2 instances to use the `awslogs` driver, streaming container logs directly to CloudWatch. This ensures logs persist even after an instance is terminated.
-   **Key Concepts**: The "Chain of Trust" (IAM Roles, Secrets Manager), network isolation, and centralized logging for ephemeral infrastructure.

</details>

---

## Security Best Practices

-   **Zero Hardcoded Secrets**: The application uses `boto3` and an IAM Role to fetch the database password from AWS Secrets Manager at runtime.
-   **Network Isolation**: The RDS database is in private subnets with a security group that only allows traffic from the EC2 instances, making it completely unreachable from the public internet.
-   **Least Privilege IAM**: The EC2 instance role has narrowly-scoped permissions to only read its specific secret and write to its designated CloudWatch Log Group.
-   **Infrastructure as Code**: All security group rules and IAM policies are explicitly defined in Terraform, making them auditable and version-controlled.

---

## Cost Optimization (FinOps)

-   **Auto-Scaling**: The scale-in policy terminates idle instances, ensuring you only pay for the compute capacity you need.
-   **Managed Services**: Using RDS and CloudWatch eliminates the operational overhead and cost of managing database and monitoring servers.
-   **Log Management**: CloudWatch Log Groups are configured with a 7-day retention period to automatically delete old logs and cap storage costs.
-   **Resource Cleanup**: `terraform destroy` tears down all resources, preventing orphaned resources and unwanted charges.

---

## Future Improvements

-   [ ] Implement a `PATCH /tasks/<id>` endpoint to mark tasks as complete.
-   [ ] Add backend input validation and error handling.
-   [ ] Move the Jenkins server to a dedicated EC2 instance and trigger builds automatically via GitHub webhooks.
-   [ ] Store Terraform state (`.tfstate`) in an S3 backend for team collaboration and safety.
-   [ ] Send CloudWatch alarm notifications via SNS email.
-   [ ] Restrict the SSH security group rule to a specific IP address instead of `0.0.0.0/0`.
