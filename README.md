# CloudCost — Optimized Multi-Tier Web App on AWS

Production-grade task manager built to demonstrate cost-aware cloud architecture: auto-scaling, self-healing, secrets management, CI/CD, and full observability — all on a sub-$1/day budget.

[![Status](https://img.shields.io/badge/Status-Complete-brightgreen)]()
[![IaC](https://img.shields.io/badge/IaC-Terraform-7B42BC)]()
[![Cloud](https://img.shields.io/badge/Cloud-AWS-FF9900)]()
[![CI/CD](https://img.shields.io/badge/CI/CD-Jenkins-D24939)]()
[![Backend](https://img.shields.io/badge/Backend-Python%20Flask-3776AB)]()
[![Monitoring](https://img.shields.io/badge/Monitoring-CloudWatch-FF4F8B)]()
[![Cost](https://img.shields.io/badge/Cost-~%241%2Fday-brightgreen)]()
---
## Stack

| Layer | Technology |
|---|---|
| Frontend | HTML / CSS / Vanilla JS |
| Backend | Python Flask + SQLAlchemy |
| Database | SQLite (local) → AWS RDS Postgres 15 (cloud) |
| IaC | Terraform (AWS provider 5.x) |
| CI/CD | Jenkins (Dockerized, local) |
| Monitoring | AWS CloudWatch (metrics, alarms, dashboard) |
| Secrets | AWS Secrets Manager |
| Load Balancing | AWS Application Load Balancer |
| Auto-scaling | AWS Auto Scaling Group + Launch Template |
| Testing | pytest (unit + integration) |

---

## Phases

- [x] Phase 1 — Backend + Frontend
- [x] Phase 2 — Database Integration (SQLite → RDS Postgres)
- [x] Phase 3 — Infrastructure as Code (Terraform)
- [x] Phase 4 — CI/CD with Jenkins
- [x] Phase 5 — Monitoring (CloudWatch)
- [x] Phase 6 — Auto-scaling + Load Balancing + Self-healing
- [x] Phase 7 — Security (Secrets Manager + locked-down security groups)
- [x] Phase 8 — Cost Optimization
- [x] Phase 9 — Testing
- [x] Phase 10 — Documentation

---

## Architecture

```
Internet
   │
   ▼
[ALB — port 80]         ← 2 public subnets (us-east-1a, us-east-1b)
   │
   ▼
[Auto Scaling Group]    min=1  desired=1  max=3
   │  EC2 t3.micro (Launch Template)
   │  ├── Docker: cloudcost-backend (--restart unless-stopped)
   │  ├── CloudWatch Agent (metrics + logs)
   │  └── Pulls DB password from Secrets Manager on boot
   │
   ▼
[RDS Postgres 15]       ← 2 private subnets (us-east-1a, us-east-1b)
   db.t3.micro · 20GB · no public access · single-AZ
```

Traffic: `Internet → ALB :80 → EC2 :5000 → RDS :5432`

No direct internet access to EC2 or RDS. All traffic must pass through the ALB.

---

## Cost Profile

| Resource | Type | Est. Cost |
|---|---|---|
| EC2 (×1 baseline) | t3.micro | ~$0.01/hr |
| RDS Postgres | db.t3.micro | ~$0.018/hr |
| ALB | per hour + LCU | ~$0.008/hr |
| CloudWatch | basic monitoring | free |
| Secrets Manager | 1 secret | ~$0.40/mo |
| Data transfer | low traffic | ~$0.00 |
| **Total (idle)** | | **~$1.00/day** |

Cost scales linearly with ASG instance count under load (max 3×EC2). Scale-in kicks in at 30% CPU — no idle capacity waste.

### FinOps Decisions

- **`us-east-1`** — cheapest AWS region, widest service availability
- **`t3.micro`** — burstable, free-tier eligible (first 12 months), right-sized for low traffic
- **`multi_az = false`** — saves ~50% on RDS in dev; flip to `true` for production
- **`skip_final_snapshot = true`** — avoids snapshot storage cost on teardown
- **Single-AZ ASG baseline** — min=1 keeps cost at one instance; ASG handles recovery on failure
- **7-day log retention** — CloudWatch logs auto-expire, no unbounded storage growth
- **Basic monitoring only** — 5-minute metric intervals are free; detailed (1-min) costs extra
- **`docker image prune -f` post-build** — prevents disk bloat on the Jenkins build machine
- **`BUILD_NUMBER` image tagging** — enables rollback without storing redundant images
- **Jenkins runs locally** — zero EC2 cost for the CI/CD server
- **Resource tags on everything** — `Project` + `Environment` tags enable per-project cost filtering in AWS Cost Explorer
- **`recovery_window_in_days = 0`** — immediate Secrets Manager deletion on destroy, no 30-day retention charge
- **ALB access logs disabled** — S3 logging costs avoided in dev
- **Always `terraform destroy` when done** — RDS is the biggest cost driver at ~$13/month running 24/7

---

## Auto-scaling + Self-healing

### Scaling policies

| Trigger | Action | Cooldown |
|---|---|---|
| CPU > 70% for 2 consecutive minutes | +1 EC2 instance | 300s |
| CPU < 30% for 2 consecutive minutes | −1 EC2 instance | 300s |

CloudWatch alarms on the `AutoScalingGroupName` dimension fire directly into the ASG scaling policies.

### Self-healing flow

1. Instance fails ALB health check (`GET /tasks` returns non-200 or times out)
2. ALB stops routing traffic to the unhealthy instance
3. ASG detects the failed health check and terminates the instance
4. ASG launches a replacement from the Launch Template
5. New instance runs `user_data`: installs Docker, pulls `latest` from Docker Hub, starts container with `--restart unless-stopped`
6. ALB health check passes → instance rejoins the target group
7. Traffic resumes — full recovery with zero manual intervention

### Two layers of recovery

- **Container-level** — `--restart unless-stopped` restarts the Flask process in seconds if it crashes inside the container
- **Instance-level** — ASG replaces the entire EC2 instance in minutes if the host itself fails

---

## Security

### Network isolation

- RDS in private subnets — no internet route, no public IP
- EC2 port 5000 blocked from internet — ALB SG is the only allowed source
- SSH (port 22) locked to a single `/32` IP

### Security groups

| SG | Port | Source |
|---|---|---|
| ALB | 80 | 0.0.0.0/0 |
| EC2 | 5000 | ALB SG only |
| EC2 | 22 | Your IP /32 only |
| RDS | 5432 | EC2 SG only |

### Secrets

- RDS password lives only in AWS Secrets Manager — never in code, `.tf` files, env vars, or Docker images
- Flask calls `boto3` at startup to fetch the secret; falls back to SQLite if `DB_SECRET_NAME` is unset
- EC2 IAM role has `secretsmanager:GetSecretValue` scoped to that single secret ARN — least privilege
- `TF_VAR_db_password` passed at apply time, marked `sensitive = true` — never printed to terminal
- `.tfstate` excluded from Git — contains plaintext resource details including ARNs

### CI/CD

- Docker Hub uses a personal access token, not the account password
- Jenkins credentials encrypted at rest, masked in build logs
- SSH key injected via `withCredentials` — never written to disk in plaintext
- No hardcoded AWS keys anywhere — EC2 accesses AWS via IAM role only

---

## Monitoring

| Alarm | Metric | Threshold | Action |
|---|---|---|---|
| `cloudcost-webapp-cpu-high` | EC2 CPUUtilization | > 70% | ASG scale-out |
| `cloudcost-webapp-cpu-low` | EC2 CPUUtilization | < 30% | ASG scale-in |
| `cloudcost-webapp-rds-cpu-high` | RDS CPUUtilization | > 70% | — |
| `cloudcost-webapp-rds-storage-low` | RDS FreeStorageSpace | < 1GB | — |

CloudWatch dashboard with 4 widgets: ASG CPU, RDS CPU, RDS free storage, ASG instance count.

Flask container logs ship to `/cloudcost/app` log group via the `awslogs` Docker driver. 7-day retention.

---

## CI/CD Pipeline (Jenkins)

```
Checkout → Build → Push → [Post: prune]
```

1. **Checkout** — pulls latest from GitHub
2. **Build** — `docker build`, tags `BUILD_NUMBER` + `latest`
3. **Push** — pushes both tags to Docker Hub via stored credentials
4. **Post** — `docker image prune -f`

No deploy stage — ASG Launch Template handles it. Every new instance boots and pulls `latest` automatically.

### Jenkins credentials required

| ID | Kind | Value |
|---|---|---|
| `dockerhub-credentials` | Username + Password | Docker Hub PAT |
| `ec2-ssh-key` | SSH private key | EC2 keypair `.pem` |
| `github-credentials` | Username + Password | GitHub PAT |

```bash
cd jenkins
docker-compose up -d    # start — data persists in jenkins_home volume
docker-compose down     # stop
```

---

## Testing

```bash
# from project root, venv activated
pytest tests/ -v
```

| Test | Covers |
|---|---|
| `test_get_tasks_empty` | GET /tasks → 200 + empty list |
| `test_create_task` | POST /tasks → 201 + correct fields |
| `test_create_task_missing_title` | POST /tasks no body → 400 |
| `test_delete_task` | DELETE /tasks/:id → 200 + gone |
| `test_delete_task_not_found` | DELETE /tasks/999 → 404 |

Each test uses a fresh `sqlite:///:memory:` instance. `DB_SECRET_NAME` is unset — `boto3` is never called, no AWS API calls, no cost.

---

## Workflow

### Step 1 — Provision infrastructure

```bash
cd terraform
export TF_VAR_db_password="yourpassword"
terraform apply
```

Note `alb_dns_name` from outputs — this is your app URL.

### Step 2 — Start Jenkins

```bash
cd jenkins
docker-compose up -d
```

Jenkins UI at `http://localhost:8080`

### Step 3 — Run the pipeline

Dashboard → cloudcost-pipeline → Build Now

### Step 4 — Verify

```bash
curl http://YOUR_ALB_DNS/tasks
```

### Step 5 — Check monitoring

Open `cloudwatch_dashboard_url` from terraform outputs. CloudWatch → Alarms → 4 alarms should be active.

### Step 6 — Tear down

```bash
cd terraform && terraform destroy
cd ../jenkins && docker-compose down
```

---

## Local Development

```bash
cd backend
python -m venv venv
source venv/Scripts/activate    # Windows Git Bash
pip install -r requirements.txt
python app.py
# http://127.0.0.1:5000 — SQLite backend
```

```bash
docker build -t cloudcost-backend .
docker run -p 5000:5000 cloudcost-backend
```

---

## API Reference

| Method | Endpoint | Body | Response |
|---|---|---|---|
| GET | `/tasks` | — | 200 + JSON array |
| POST | `/tasks` | `{ "title": "..." }` | 201 + task object |
| DELETE | `/tasks/<id>` | — | 200 or 404 |

---

## Terraform Quick Reference

```bash
terraform init      # once
terraform plan      # preview
terraform apply     # deploy
terraform destroy   # tear down
```

| Output | Description |
|---|---|
| `alb_dns_name` | App endpoint |
| `rds_endpoint` | RDS connection string |
| `cloudwatch_dashboard_url` | CloudWatch dashboard |
| `secrets_manager_secret_name` | Secret name |

---

## Folder Structure

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
│   ├── main.tf          # VPC, subnets, SGs, RDS, IAM
│   ├── autoscaling.tf   # Launch Template, ALB, ASG, scaling policies
│   ├── cloudwatch.tf    # alarms, dashboard, log group
│   ├── secrets.tf
│   └── outputs.tf
├── jenkins/
│   ├── Jenkinsfile
│   └── docker-compose.yml
├── tests/
│   ├── test_app.py
│   └── requirements-test.txt
├── .gitignore
└── README.md
```

---

## Problems & Fixes

| Problem | Fix |
|---|---|
| PowerShell `mkdir` won't take multiple args | Use semicolons: `mkdir a; mkdir b` or use Git Bash |
| Flask empty reply in Docker | Was binding to `127.0.0.1` — fix: `app.run(host='0.0.0.0')` |
| Flask 404 on all routes in Docker | `app.run()` above route definitions — move to bottom inside `__main__` |
| RDS username `admin` rejected | Postgres reserves it — changed to `dbadmin` |
| AMI not found | AMI IDs are region-specific — re-ran `describe-images --region us-east-1` |
| Key pair not found on apply | Key created in wrong region — recreated in `us-east-1` |
| `docker: not found` in Jenkins | Docker CLI not installed by default — added `apt-get install docker.io` to entrypoint |
| Jenkins git `fatal: not a git directory` | Added `git config --global --add safe.directory '*'` to entrypoint |
| Docker Hub `unauthorized` in pipeline | Account passwords rejected via API — switched to personal access token |
| Git Bash translates `/var/...` paths | Prefix with `//` to prevent path translation |
| CloudWatch dashboard `invalid` | Widgets require explicit `region` property — added `region = var.aws_region` |
| Secrets Manager `already exists` on re-apply | Set `recovery_window_in_days = 0` for immediate deletion |
| pytest `ModuleNotFoundError: backend` | Added `sys.path.insert` in test file to resolve module path |
| pytest fixture using stale SQLite file | `db.drop_all()` before `create_all()` inside app context resets state cleanly |

---

## Things to Improve

- S3 remote state with DynamoDB locking for team use
- HTTPS on the ALB via ACM certificate
- `PATCH /tasks/<id>` to toggle task completion
- GitHub webhook for automatic pipeline triggers on push
- SNS notifications on CloudWatch alarms (email / Slack)
- WAF on the ALB for web application firewall protection
- `multi_az = true` + `deletion_protection = true` for production RDS
- Scheduled ASG scale-down overnight for dev (EventBridge scaling schedule)

---

## Dev Environment

- OS: Windows, Git Bash
- Editor: VS Code
- Tools: Git, Docker, Terraform, AWS CLI, pytest
- Accounts: GitHub + AWS + Docker Hub
