# CloudCost Optimized Multi-Tier Web App

Multi-tier task manager app deployed on AWS with Terraform, Jenkins CI/CD, auto-scaling, self-healing, load balancing, secrets management, and CloudWatch monitoring.

---

## Stack

| Layer | Technology |
|---|---|
| Frontend | HTML / CSS / Vanilla JS |
| Backend | Python Flask + SQLAlchemy |
| Database | SQLite (local dev) → AWS RDS Postgres 15 (cloud) |
| IaC | Terraform (AWS provider 5.x) |
| CI/CD | Jenkins (local Docker) |
| Monitoring | AWS CloudWatch |
| Secrets | AWS Secrets Manager |
| Load Balancing | AWS Application Load Balancer |
| Auto-scaling | AWS Auto Scaling Group + Launch Template |

---

## Phases

- [x] Phase 1 - Backend + Frontend
- [x] Phase 2 - Database Integration (SQLite → RDS Postgres)
- [x] Phase 3 - Infrastructure as Code (Terraform + AWS)
- [x] Phase 4 - CI/CD with Jenkins
- [x] Phase 5 - Monitoring (CloudWatch)
- [x] Phase 6 - Auto-scaling + Load Balancing + Self-healing
- [x] Phase 7 - Security (Secrets Manager + locked-down security groups)
- [ ] Phase 8 - Cost Optimization
- [ ] Phase 9 - Testing
- [ ] Phase 10 - Documentation

---

## Architecture

```
Internet
   │
   ▼
[ALB - port 80]  ← public subnets (us-east-1a, us-east-1b)
   │
   ▼
[Auto Scaling Group]  min=1, max=3, desired=1
   │  EC2 t3.micro instances (Launch Template)
   │  - Docker container: cloudcost-backend
   │  - CloudWatch Agent
   │  - Pulls DB password from Secrets Manager on boot
   │
   ▼
[RDS Postgres 15]  ← private subnets (us-east-1a, us-east-1b)
   db.t3.micro, 20GB, no public access
```

Traffic flow: `Internet → ALB (port 80) → EC2 (port 5000) → RDS (port 5432)`

---

## Folder Structure

```
cloudcost-webapp/
├── backend/
│   ├── app.py              # Flask API + SQLAlchemy models
│   ├── Dockerfile
│   ├── requirements.txt
│   └── .dockerignore
├── frontend/
│   └── index.html
├── terraform/
│   ├── provider.tf         # AWS provider + region
│   ├── variables.tf        # all variable definitions
│   ├── main.tf             # VPC, subnets, SGs, RDS, IAM
│   ├── autoscaling.tf      # Launch Template, ALB, ASG, scaling policies
│   ├── cloudwatch.tf       # alarms, dashboard, log group
│   ├── secrets.tf          # Secrets Manager secret + version
│   └── outputs.tf          # alb_dns_name, rds_endpoint, dashboard URL, etc.
├── jenkins/
│   ├── Jenkinsfile
│   └── docker-compose.yml
├── monitoring/
├── .gitignore
└── README.md
```

---

## Workflow

Full end-to-end workflow from zero to deployed. Run in order.

### Step 1 - Provision infrastructure

```bash
cd terraform
export TF_VAR_db_password="yourpassword"
terraform apply
```

Note the `alb_dns_name` from the outputs — this is your app URL.

### Step 2 - Start Jenkins

```bash
cd jenkins
docker-compose up -d
```

Jenkins UI at http://localhost:8080

### Step 3 - Run the pipeline

Dashboard → cloudcost-pipeline → Build Now

The pipeline builds the Docker image, tags it with `BUILD_NUMBER` and `latest`, and pushes both to Docker Hub. The ASG Launch Template pulls `latest` automatically on every new instance boot.

### Step 4 - Verify

```bash
curl http://YOUR_ALB_DNS/tasks
```

Should return a JSON list of tasks.

### Step 5 - Check monitoring

Open the CloudWatch dashboard URL from terraform outputs.

Check CloudWatch → Alarms → All alarms. You should see 4 alarms:
- `cloudcost-webapp-cpu-high` — triggers scale-out at 70% CPU
- `cloudcost-webapp-cpu-low` — triggers scale-in at 30% CPU
- `cloudcost-webapp-rds-cpu-high` — RDS CPU above 70%
- `cloudcost-webapp-rds-storage-low` — RDS free storage below 1GB

### Step 6 - Tear down when done

```bash
cd terraform
terraform destroy
cd ../jenkins
docker-compose down
```

---

## API Reference

| Method | Endpoint | Description |
|---|---|---|
| GET | `/tasks` | Returns all tasks as JSON |
| POST | `/tasks` | Creates a task — body: `{ "title": "..." }` |
| DELETE | `/tasks/<id>` | Deletes task by ID |

---

## Infrastructure Details

### Networking

- VPC `10.0.0.0/16` with DNS hostnames enabled
- 2 public subnets: `10.0.1.0/24` (us-east-1a), `10.0.2.0/24` (us-east-1b)
- 2 private subnets: `10.0.3.0/24` (us-east-1a), `10.0.4.0/24` (us-east-1b)
- Internet Gateway + public route table

### Security Groups

| SG | Inbound | Source |
|---|---|---|
| ALB SG | port 80 | 0.0.0.0/0 (internet) |
| EC2 SG | port 5000 | ALB SG only |
| EC2 SG | port 22 (SSH) | your IP only (locked to /32) |
| RDS SG | port 5432 | EC2 SG only |

EC2 is not directly reachable from the internet on port 5000 — all traffic must go through the ALB.

### Load Balancer

- Application Load Balancer across both public subnets
- Listener on port 80 forwards to target group
- Health check: `GET /tasks` every 30s, 2 healthy / 2 unhealthy thresholds
- Outputs `alb_dns_name` — use this as your app endpoint

### Auto Scaling + Self-healing

- Launch Template defines the EC2 blueprint (AMI, instance type, IAM profile, user_data)
- ASG: min=1, max=3, desired=1 across both public subnets
- Scale-out policy: +1 instance when CPU > 70% for 2 consecutive minutes
- Scale-in policy: -1 instance when CPU < 30% for 2 consecutive minutes
- Self-healing: if an instance fails its health check, the ASG automatically terminates it and launches a replacement
- Docker container runs with `--restart unless-stopped` for process-level self-healing

### Secrets Management

- RDS password stored in AWS Secrets Manager (`cloudcost-webapp-db-password`)
- EC2 IAM role has `secretsmanager:GetSecretValue` permission scoped to that secret ARN
- Flask reads the secret at startup via `boto3` — no passwords in environment variables, Dockerfiles, or code
- `recovery_window_in_days = 0` for easy teardown in dev

### IAM

- IAM role `cloudcost-webapp-ec2-cloudwatch-role` attached to all EC2 instances via instance profile
- Policies attached:
  - `CloudWatchAgentServerPolicy` (AWS managed) — push metrics and logs
  - Inline policy — `secretsmanager:GetSecretValue` on the DB secret only
- No hardcoded AWS keys anywhere

### RDS

- Postgres 15, `db.t3.micro`, 20GB storage
- Private subnets only, `publicly_accessible = false`
- `multi_az = false` (dev cost saving)
- `skip_final_snapshot = true` for easy teardown

### CloudWatch

- Log group `/cloudcost/app` — Flask container logs via `awslogs` Docker driver, 7-day retention
- 4 alarms wired to ASG scaling policies and RDS
- Dashboard with 4 widgets: ASG CPU, RDS CPU, RDS free storage, ASG instance count

---

## CI/CD Pipeline (Jenkins)

Stages:
1. Checkout — pulls latest code from GitHub
2. Build — `docker build`, tags with `BUILD_NUMBER` and `latest`
3. Push — pushes both tags to Docker Hub using stored credentials
4. Post — `docker image prune -f` to clean dangling images

Deploy stage removed — the ASG Launch Template handles deployment. New instances always pull `latest` on boot.

### Jenkins credentials required

| ID | Type | Value |
|---|---|---|
| `dockerhub-credentials` | Username + Password | Docker Hub username + personal access token |
| `ec2-ssh-key` | SSH private key | EC2 keypair `.pem` (ec2-user) |
| `github-credentials` | Username + Password | GitHub username + personal access token |

### How Jenkins runs locally

```bash
cd jenkins
docker-compose up -d    # start, data persists in jenkins_home volume
docker-compose down     # stop
```

The `docker-compose.yml` entrypoint installs `docker.io` and sets `git safe.directory *` before Jenkins starts, so the pipeline can run Docker commands and Git operations without permission errors.

---

## Local Development

### Backend setup

```bash
cd backend
python -m venv venv
source venv/Scripts/activate   # Windows Git Bash
pip install -r requirements.txt
python app.py
```

Runs on `http://127.0.0.1:5000` with SQLite (`instance/tasks.db`).

### Docker

```bash
docker build -t cloudcost-backend .
docker run -p 5000:5000 cloudcost-backend
```

### Test with curl

```bash
curl http://127.0.0.1:5000/tasks
curl -X POST http://127.0.0.1:5000/tasks -H "Content-Type: application/json" -d '{"title": "my task"}'
curl -X DELETE http://127.0.0.1:5000/tasks/1
```

---

## Security Notes

- RDS in private subnets, no public IP, unreachable from internet
- EC2 port 5000 only reachable via ALB, not directly from internet
- SSH (port 22) locked to a single /32 IP, not open to 0.0.0.0/0
- DB password stored in Secrets Manager, never in code, env vars, or `.tf` files
- Passwords passed via `TF_VAR_db_password` env variable at apply time
- `db_password` marked `sensitive = true` in Terraform — hidden from terminal output
- `.tfstate` excluded from Git (contains sensitive resource details)
- IAM role uses least privilege — only the two policies it actually needs
- EC2 accesses AWS services via IAM role, no hardcoded access keys
- Jenkins credentials encrypted at rest, masked in build logs
- Docker Hub uses personal access token, not account password
- SSH key passed via `withCredentials`, never written to disk in plaintext

---

## FinOps Notes

- `us-east-1` is the cheapest AWS region
- EC2 `t3.micro` ~$0.01/hr — free tier eligible (first 12 months)
- RDS `db.t3.micro` ~$0.018/hr (~$13/month) — not free tier
- `multi_az = false` saves ~50% on RDS cost in dev
- `skip_final_snapshot = true` avoids snapshot storage cost
- ASG min=1 keeps cost at single instance baseline; scales only under load
- Scale-in policy removes instances when CPU drops below 30% — no idle capacity waste
- CloudWatch basic monitoring is free (5-min intervals); detailed monitoring costs extra
- Log retention set to 7 days — auto-deleted to avoid storage cost buildup
- `docker image prune -f` after every build prevents disk bloat on the build machine
- `BUILD_NUMBER` versioning enables rollbacks without storing extra images
- Jenkins runs locally — no EC2 cost for the CI/CD server
- Tags on every resource (`Project`, `Environment`) enable cost filtering in AWS Cost Explorer
- Always run `terraform destroy` when done testing

---

## Terraform Quick Reference

```bash
terraform init      # download providers, run once
terraform plan      # preview changes
terraform apply     # create/update infrastructure
terraform destroy   # tear everything down
```

Key outputs after apply:

| Output | Description |
|---|---|
| `alb_dns_name` | App endpoint (use this, not EC2 IP) |
| `rds_endpoint` | RDS connection string |
| `cloudwatch_dashboard_url` | Direct link to CloudWatch dashboard |
| `secrets_manager_secret_name` | Secret name in Secrets Manager |

---

## Problems & Fixes

### PowerShell mkdir doesn't accept multiple folders
```bash
# fails in PowerShell
mkdir frontend backend terraform jenkins monitoring

# fix - use semicolons or just use Git Bash
mkdir frontend; mkdir backend; mkdir terraform; mkdir jenkins; mkdir monitoring
```

### pip not found
Was in wrong folder. Always `cd backend` and activate venv first.

### Docker empty reply from server
Flask was binding to `127.0.0.1` (container-only). Fix: `app.run(host='0.0.0.0')`.

### Docker 404 not found
`app.run()` was placed before routes were defined. Fix: `app.run()` belongs at the bottom inside `if __name__ == '__main__'`.

### RDS username 'admin' is reserved
Postgres doesn't allow `admin` as master username. Fix: changed to `dbadmin`.

### AMI not found
AMI ID was region-specific. Fix: re-ran `describe-images` with `--region us-east-1`.

### Key pair not found on apply
Key pair was created in the wrong region. Fix:
```bash
rm ~/.ssh/cloudcost-keypair.pem
aws ec2 create-key-pair --key-name cloudcost-keypair --region us-east-1 \
  --query 'KeyMaterial' --output text > ~/.ssh/cloudcost-keypair.pem
chmod 400 ~/.ssh/cloudcost-keypair.pem
```

### docker: not found in Jenkins pipeline
Jenkins runs inside a container — Docker CLI is not installed by default even with the socket mounted. Fix: added `apt-get install docker.io` to the `docker-compose.yml` entrypoint.

### Jenkins git fatal: not in a git directory
Newer Git blocks operations in directories owned by a different user. Fix: added `git config --global --add safe.directory '*'` to the entrypoint. Manual fix: `docker exec -it jenkins git config --global --add safe.directory '*'`.

### Docker Hub unauthorized in pipeline
Docker Hub rejects account passwords via API. Fix: generate a personal access token in Docker Hub settings and use that in the `dockerhub-credentials` Jenkins credential.

### Git Bash translates absolute paths in docker exec
Git Bash converts `/var/...` to `C:/Program Files/Git/var/...`. Fix: prefix paths with `//` to prevent translation.

### CloudWatch dashboard invalid - missing region property
Dashboard widgets require an explicit `region` property. Fix: added `region = var.aws_region` to every widget's `properties` block.

### Secrets Manager secret already exists on re-apply
If `terraform destroy` didn't fully clean up, the secret name may still be reserved. Fix: `recovery_window_in_days = 0` forces immediate deletion so re-apply works cleanly.

---

## Things to Improve Later

- Store `tfstate` in S3 with DynamoDB locking for team sharing and safety
- Add HTTPS to the ALB with ACM certificate
- Add PATCH `/tasks/<id>` to mark tasks as done
- Add input validation on the backend
- Move Jenkins to EC2 and add GitHub webhook for automatic pipeline triggers
- Add SNS topic to CloudWatch alarms for email/Slack notifications on alarm
- Add WAF to the ALB for web application firewall protection
- Enable RDS `multi_az = true` for production high availability
- Add `deletion_protection = true` on RDS for production

---

## Dev Environment

- OS: Windows, Git Bash
- Editor: VS Code
- Tools: Git, Docker, Terraform, AWS CLI
- Accounts: GitHub + AWS + Docker Hub
