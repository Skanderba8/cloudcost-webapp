# CloudCost Optimized Multi-Tier Web App

Multi-tier web app on AWS with Terraform, Jenkins CI/CD, auto-scaling,
monitoring, and cost optimization.

## Stack
- Frontend: HTML / CSS / Vanilla JS
- Backend: Python Flask + SQLAlchemy
- Database: SQLite (local) -> AWS RDS Postgres (cloud)
- IaC: Terraform
- CI/CD: Jenkins (Phase 4)
- Monitoring: CloudWatch (Phase 5)

## Phases
- [x] Phase 1 - Backend + Frontend
- [x] Phase 2 - Database Integration
- [x] Phase 3 - Infrastructure as Code (Terraform + AWS)
- [x] Phase 4 - CI/CD with Jenkins
- [x] Phase 5 - Monitoring (CloudWatch)
- [ ] Phase 6 - Auto-scaling
- [ ] Phase 7 - Security
- [ ] Phase 8 - Cost Optimization
- [ ] Phase 9 - Testing
- [ ] Phase 10 - Documentation

## Folder Structure
```
cloudcost-webapp/
  backend/
    app.py
    Dockerfile
    requirements.txt
    .dockerignore
    venv/
  frontend/
    index.html
  terraform/
    provider.tf
    variables.tf
    main.tf
    outputs.tf
    cloudwatch.tf
  jenkins/
    Jenkinsfile
    docker-compose.yml
  monitoring/
  .gitignore
  README.md
```

---

## Workflow

This is the full workflow to bring the project back up from zero and
deploy end to end. Run these steps in order every time.

### Step 1 - Provision infrastructure
```
cd terraform
export TF_VAR_db_password="yourpassword"
terraform apply
```
Note the ec2_public_ip from the outputs.

### Step 2 - Update EC2 IP in Jenkinsfile
Open jenkins/Jenkinsfile and update:
```
EC2_IP = "YOUR_NEW_EC2_IP"
```
Commit and push:
```
git add jenkins/Jenkinsfile
git commit -m "update EC2 IP"
git push origin main
```

### Step 3 - Start Jenkins
```
cd jenkins
docker-compose up -d
```
Jenkins UI at http://localhost:8080

### Step 4 - Run the pipeline
Dashboard -> cloudcost-pipeline -> Build Now
Watch Console Output. Pipeline builds image, pushes to Docker Hub,
SSHs into EC2, pulls image, starts container.

### Step 5 - Verify
```
curl http://YOUR_EC2_IP:5000/tasks
```
Should return JSON list of tasks.

### Step 6 - Check monitoring
Open CloudWatch dashboard URL from terraform outputs.
Check CloudWatch -> Alarms -> All alarms, should show 3 alarms.

### Step 7 - Tear down when done
```
cd terraform
terraform destroy
cd ../jenkins
docker-compose down
```

---

# Dev Notes

## Setup
- OS: Windows, using Git Bash (switched from PowerShell early on)
- Editor: VS Code
- Tools: Git, VS Code, Docker, Terraform, AWS CLI
- Accounts: GitHub + AWS

---

## Phase 1 - Backend + Frontend

### What was built
Simple full-stack task manager app running locally.
- Backend: Python Flask REST API (3 endpoints)
- Frontend: Single HTML file with vanilla JS

### Backend routes
- GET    /tasks          returns all tasks as JSON
- POST   /tasks          creates a task, expects { "title": "..." }
- DELETE /tasks/<id>     deletes task by id

### Key concepts
- Flask routes use @app.route decorator
- HTTP methods: GET = read, POST = create, DELETE = remove
- request.get_json() reads the JSON body from the request
- jsonify() converts Python data to JSON to send back
- 200 = OK, 201 = created, 404 = not found
- debug=True auto-restarts Flask on file changes

### Virtual environment
```
python -m venv venv
source venv/Scripts/activate   # Windows Git Bash
pip install flask flask-cors
```
flask-cors needed so browser doesn't block requests from frontend to backend.
Always activate venv before using pip or running app.py.

### Testing with curl
```
curl http://127.0.0.1:5000/tasks
curl -X POST http://127.0.0.1:5000/tasks -H "Content-Type: application/json" -d '{"title": "task"}'
curl -X DELETE http://127.0.0.1:5000/tasks/1
```
- -X sets HTTP method
- -H adds a header
- -d is the request body

### Frontend
fetch() is the browser equivalent of curl.
async/await used because network requests take time.
Frontend never touches data directly, always goes through the API.

### Docker
```
docker build -t cloudcost-backend .
docker run -p 5000:5000 cloudcost-backend
```
Dockerfile copies requirements first then code (Docker layer caching).
.dockerignore excludes venv/, __pycache__/, .env

---

## Phase 2 - Database Integration

### What changed
Replaced in-memory Python list with SQLite using SQLAlchemy ORM.
Data now persists across Flask restarts.

### SQLAlchemy basics
- Task class extends db.Model -> becomes a database table
- db.session.add(task) -> stages record
- db.session.commit() -> writes to database
- Task.query.all() -> SELECT * FROM task
- Task.query.get(id) -> fetch by primary key
- db.create_all() -> creates tables if they don't exist, safe to run every time

### SQLite vs RDS
SQLite stores data in tasks.db file locally. Good for dev, no server needed.
Problem in Docker: tasks.db lives inside container, lost on rebuild.
RDS in Phase 3 fixes this - lives outside the container permanently.

---

## Phase 3 - Terraform + AWS

### What was provisioned
- VPC (10.0.0.0/16)
- 2 public subnets (us-east-1a, us-east-1b)
- 2 private subnets (us-east-1a, us-east-1b)
- Internet Gateway + Route Table
- EC2 security group (ports 22, 80, 5000 open)
- RDS security group (port 5432, EC2 only)
- RDS Postgres db.t3.micro in private subnets
- EC2 t3.micro in public subnet with Docker installed via user_data

### Terraform file structure
- provider.tf  -> AWS provider config and region
- variables.tf -> all variable definitions
- main.tf      -> all resources
- outputs.tf   -> ec2_public_ip, rds_endpoint, vpc_id
- cloudwatch.tf -> CloudWatch alarms, dashboard, log group (added Phase 5)

### Key Terraform commands
```
terraform init     # download providers, run once
terraform plan     # preview changes before applying
terraform apply    # create infrastructure
terraform destroy  # tear everything down
```

### Key concepts
- Resources reference each other: aws_instance.app.public_ip
- Terraform builds a dependency graph, order doesn't matter
- (known after apply) means value only exists after resource is created
- Tags on every resource for cost tracking and organization
- sensitive = true on variables hides values from terminal output

### Passing secrets
Never hardcode passwords in .tf files.
Use environment variables instead:
```
export TF_VAR_db_password="yourpassword"
```
Terraform picks up any TF_VAR_ prefixed env variable automatically.

### Deploying the container to EC2
```
# on local machine
docker tag cloudcost-backend username/cloudcost-backend:latest
docker push username/cloudcost-backend:latest

# on EC2 via SSH
ssh -i ~/.ssh/cloudcost-keypair.pem ec2-user@YOUR_EC2_IP
docker pull username/cloudcost-backend:latest
docker run -d -p 5000:5000 username/cloudcost-backend:latest
```
-d runs container in background (detached mode)

### Verified working
curl http://98.92.237.199:5000/tasks returned tasks from EC2 on AWS.

---

## Phase 4 - CI/CD with Jenkins

### What was built
Full CI/CD pipeline running Jenkins locally in Docker.
On every build, Jenkins automatically builds, tags, pushes, and deploys
the backend to EC2 without any manual steps.

### Pipeline stages
- Checkout  -> pulls latest code from GitHub
- Build     -> docker build, tags image with BUILD_NUMBER and latest
- Push      -> pushes both tags to Docker Hub
- Deploy    -> SSHs into EC2, pulls new image, restarts container
- Post      -> docker image prune to clean up dangling images

### How Jenkins runs locally
```
cd jenkins
docker-compose up -d    # start Jenkins
docker-compose down     # stop, data preserved in jenkins_home volume
```
Jenkins UI at http://localhost:8080

### docker-compose.yml explained
- image: jenkins/jenkins:lts -> stable long term support image
- user: root -> needed to install packages and access Docker socket
- ports 8080:8080 -> Jenkins UI
- ports 50000:50000 -> Jenkins agent communication
- /var/run/docker.sock -> gives Jenkins access to host Docker daemon
- jenkins_home volume -> persists all Jenkins config across restarts
- entrypoint installs docker.io and sets git safe.directory before
  Jenkins starts so pipeline can run docker commands and git operations
  inside the container without ownership errors

### Credentials stored in Jenkins
- dockerhub-credentials -> Docker Hub username + personal access token
- ec2-ssh-key -> SSH private key for EC2 (ec2-user)
- github-credentials -> GitHub username + personal access token

### Key concepts
- BUILD_NUMBER tag gives every image a unique version, enables rollbacks
- withCredentials block masks secrets in logs, never hardcoded in code
- docker login uses --password-stdin, never -p flag
- || true on docker stop/rm prevents failure if container doesn't exist yet
- jenkins_home named volume survives docker-compose down
- Docker socket mount lets Jenkins control Docker on the host machine
- git safe.directory * set in entrypoint to fix Git ownership error
- Docker Hub requires personal access token, not account password

### Verified working
Full pipeline ran successfully, curl http://3.210.201.67:5000/tasks
returned live data from container running on EC2.

---

## Phase 5 - Monitoring (CloudWatch)

### What was built
Full AWS CloudWatch monitoring setup provisioned via Terraform.
EC2 and RDS metrics collected automatically, alarms fire when
thresholds are crossed, dashboard gives single view of all metrics.

### What was added to Terraform
New file cloudwatch.tf with:
- CloudWatch Log Group for Flask app logs
- EC2 CPU alarm - fires if CPU above 70% for 2 consecutive minutes
- RDS CPU alarm - fires if RDS CPU above 70% for 2 consecutive minutes
- RDS storage alarm - fires if free storage drops below 1GB
- CloudWatch dashboard with 4 metric widgets

main.tf changes:
- IAM role for EC2 with CloudWatchAgentServerPolicy attached
- IAM instance profile wrapping the role
- EC2 now references the instance profile
- user_data installs and starts amazon-cloudwatch-agent on boot

### CloudWatch concepts
- Metrics -> numerical data points AWS collects automatically
  (CPU %, network bytes, storage bytes)
- Alarms -> watch a metric and change state when threshold is crossed
  OK = normal, ALARM = threshold crossed, Insufficient data = not enough
  data collected yet (normal on first startup)
- Log Group -> named bucket where application logs are stored
- Dashboard -> visual grid of metric widgets in AWS console
- Dimensions -> filter metrics to a specific resource
  (InstanceId filters EC2 metrics to your specific instance)
- evaluation_periods + period -> alarm checks every N seconds,
  must breach threshold for M consecutive checks before firing
  prevents false alarms from brief spikes
- retention_in_days = 7 on log group -> logs auto-deleted after 7 days,
  saves storage cost

### IAM concepts
- IAM Role -> an identity with permissions, EC2 can assume it
- assume_role_policy -> defines who is allowed to take on this role
  in this case ec2.amazonaws.com meaning any EC2 instance
- CloudWatchAgentServerPolicy -> AWS managed policy with all permissions
  needed to push metrics and logs to CloudWatch
- Instance Profile -> wrapper required to attach an IAM role to EC2
  EC2 cannot use a role directly, must go through a profile

### Outputs added
- cloudwatch_dashboard_url -> direct link to dashboard in AWS console
- cloudwatch_log_group -> log group name for Flask logs
- ec2_cloudwatch_alarm -> EC2 CPU alarm name
- rds_cloudwatch_alarm_cpu -> RDS CPU alarm name
- rds_cloudwatch_alarm_storage -> RDS storage alarm name

### Verified working
- 3 alarms visible in CloudWatch -> Alarms -> All alarms
- Dashboard showing 4 widgets at cloudwatch_dashboard_url output
- curl http://50.17.136.208:5000/tasks returned live data

---

## Problems & Fixes

### PowerShell mkdir doesn't accept multiple folders
```
# fails in PowerShell
mkdir frontend backend terraform jenkins monitoring

# fix - use semicolons
mkdir frontend; mkdir backend; mkdir terraform; mkdir jenkins; mkdir monitoring

# or just use Git Bash
```

### pip not found
Was in wrong folder. Always cd to backend and activate venv first.

### Docker empty reply from server
Flask was binding to 127.0.0.1 (container only).
Fix: app.run(host='0.0.0.0', debug=True)

### Docker 404 not found
app.run() was placed at the top of app.py before routes were defined.
Also CORS(app) was missing.
Fix: app.run() belongs only at the bottom inside if __name__ == '__main__'

### RDS username 'admin' is reserved
Postgres doesn't allow 'admin' as master username.
Fix: changed to 'dbadmin' in variables.tf

### AMI not found
AMI ID was region-specific and didn't exist in us-east-1.
Fix: re-ran describe-images command with --region us-east-1 flag.

### Key pair not found on apply
Key pair was created in wrong region (not us-east-1).
Fix: deleted local .pem file and recreated with --region us-east-1.
```
rm ~/.ssh/cloudcost-keypair.pem   # type y when prompted
aws ec2 create-key-pair --key-name cloudcost-keypair --region us-east-1 \
  --query 'KeyMaterial' --output text > ~/.ssh/cloudcost-keypair.pem
chmod 400 ~/.ssh/cloudcost-keypair.pem
```

### Permission denied on .pem file
chmod 400 makes the file read-only to protect it.
If you need to delete it, type y when rm asks for confirmation.

### docker: not found in Jenkins pipeline
Jenkins runs inside a container. Even with the Docker socket mounted,
the Docker CLI binary is not installed by default.
Fix: added entrypoint to docker-compose.yml that runs apt-get install
docker.io before Jenkins starts.

### Jenkins git fatal: not in a git directory
Newer Git versions block operations in directories owned by a different user.
This happens after docker-compose down/up because the workspace ownership changes.
Root fix: added git config --global --add safe.directory '*' to the
entrypoint in docker-compose.yml so it runs automatically on every startup.
Manual fix if needed: docker exec -it jenkins git config --global --add safe.directory '*'

### Docker Hub unauthorized in pipeline
Docker Hub rejects account passwords via the API.
Fix: generate a personal access token in Docker Hub settings and use
that as the password in the dockerhub-credentials Jenkins credential.

### Git Bash translates absolute paths in docker exec
Git Bash converts /var/... paths to C:/Program Files/Git/var/...
Fix: prefix paths with // to prevent translation.
Example: docker exec -it jenkins ls //var/jenkins_home/workspace/

### CloudWatch dashboard invalid - missing region property
CloudWatch dashboard widgets require an explicit region property even
though the Terraform provider already knows the region.
Fix: added region = var.aws_region to every widget's properties block.

---

## Security Notes
- RDS in private subnets, no public IP, unreachable from internet
- RDS security group only allows traffic from EC2 security group
- db_password marked sensitive = true in Terraform
- Passwords passed via TF_VAR_ env variables, never in code
- .tfstate excluded from Git (contains sensitive resource details)
- SSH port 22 open to 0.0.0.0/0 - acceptable for dev, restrict in prod
- Jenkins credentials encrypted at rest, masked in build logs
- Docker Hub uses personal access token, not account password
- SSH key passed via withCredentials, never written to disk in plaintext
- IAM role uses least privilege - only CloudWatchAgentServerPolicy attached
- EC2 accesses CloudWatch via IAM role, no hardcoded AWS keys anywhere

## FinOps Notes
- us-east-1 is cheapest AWS region
- t3.micro EC2 ~$0.01/hour, free tier eligible under 12 months
- db.t3.micro RDS ~$0.018/hour (~$13/month), not free tier
- multi_az = false saves ~50% on RDS cost in dev
- skip_final_snapshot = true avoids snapshot storage cost
- Always run terraform destroy when done testing
- Tags on every resource enable cost filtering in AWS Cost Explorer
- docker image prune after every build prevents disk bloat
- BUILD_NUMBER versioning enables rollbacks without storing extra images
- Jenkins runs locally, no EC2 cost for CI/CD server
- CloudWatch log retention set to 7 days, logs auto-deleted to avoid
  storage cost buildup
- CloudWatch basic monitoring is free, detailed monitoring costs extra
  basic monitoring collects metrics every 5 minutes

## Things to improve later
- Restrict SSH to your IP only instead of 0.0.0.0/0
- Store tfstate in S3 for team sharing and safety
- Connect Flask to RDS Postgres instead of SQLite
- Add PATCH /tasks/<id> to mark tasks as done
- Add input validation on backend
- Move Jenkins to EC2 and add GitHub webhook for automatic pipeline triggers
- Add SNS topic to CloudWatch alarms to send email notifications on alarm