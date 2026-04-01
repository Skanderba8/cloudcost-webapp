# CloudCost Optimized Multi-Tier Web App

Multi-tier web app on AWS with Terraform, Jenkins CI/CD, auto-scaling,
monitoring, and cost optimization.

## Stack
- Frontend: HTML / CSS / Vanilla JS
- Backend: Python Flask
- Database: AWS RDS / DynamoDB (Phase 2)
- IaC: Terraform (Phase 3)
- CI/CD: Jenkins (Phase 4)
- Monitoring: CloudWatch / Grafana (Phase 5)

## Phases
- [x] Phase 1 - Backend + Frontend
- [ ] Phase 2 - Database Integration
- [ ] Phase 3 - Infrastructure as Code
- [ ] Phase 4 - CI/CD with Jenkins
- [ ] Phase 5 - Auto-scaling & Monitoring
- [ ] Phase 6 - Security
- [ ] Phase 7 - Cost Optimization
- [ ] Phase 8 - Testing
- [ ] Phase 9 - Documentation


---


# Dev Notes


## Setup

- OS: Windows, using Git Bash (switched from PowerShell early on)
- Editor: VS Code
- Tools already installed: Git, VS Code, Docker
- Accounts: GitHub + AWS both ready


## Problem: mkdir doesn't work in PowerShell for multiple folders

PowerShell's mkdir only accepts one folder at a time.

This fails:
```
mkdir frontend backend terraform jenkins monitoring
```

Fix - use semicolons in PowerShell:
```
mkdir frontend; mkdir backend; mkdir terraform; mkdir jenkins; mkdir monitoring
```

Or just switch to Git Bash where the original command works fine.
Decided to use Git Bash for everything going forward.


## Problem: pip not found when running from wrong folder

Ran `pip freeze > requirements.txt` from the frontend folder by mistake.
pip wasn't found because the virtual environment was activated in the backend folder.

Fix:
```
cd ~/Documents/vscode/cloudcost-webapp/backend
source venv/Scripts/activate
pip freeze > requirements.txt
```

Always check which folder you're in before running commands.
Always make sure (venv) is visible in the terminal before using pip.


---


## Phase 1 - Backend + Frontend


### What was built

A simple full-stack task manager app running locally.

Backend: Python Flask REST API with 3 endpoints
Frontend: Single HTML file with vanilla JS that calls the API


### Backend - app.py

Routes built:
- GET  /tasks         returns all tasks as JSON
- POST /tasks         creates a new task, expects { "title": "..." } in body
- DELETE /tasks/<id>  deletes task by id

Data is stored in memory (a Python list), resets when Flask restarts.
Database will fix this in Phase 2.

Key concepts learned:
- Flask routes and decorators (@app.route)
- HTTP methods: GET, POST, DELETE and what each means
- request.get_json() reads the JSON body sent by the client
- jsonify() converts Python data to JSON to send back
- List comprehension used to filter out deleted task
- global keyword needed when reassigning a variable defined outside a function
- 201 = created, 200 = ok (HTTP status codes)
- debug=True auto-restarts Flask on file changes


### Virtual environment

Created with:
```
python -m venv venv
```

Activated with (Windows Git Bash):
```
source venv/Scripts/activate
```

(venv) appears in terminal when active. Always activate before using pip or running app.py.

Installed packages:
```
pip install flask flask-cors
```

flask-cors is needed so the browser doesn't block requests from the frontend to the backend (CORS policy).


### Testing the API with curl

GET all tasks:
```
curl http://127.0.0.1:5000/tasks
```

POST a new task:
```
curl -X POST http://127.0.0.1:5000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "my first task"}'
```

DELETE a task:
```
curl -X DELETE http://127.0.0.1:5000/tasks/1
```

curl flags explained:
- -X       sets the HTTP method (POST, DELETE, etc), default is GET
- -H       adds a header, Content-Type: application/json tells Flask the body is JSON
- -d       the data/body being sent with the request


### Frontend - index.html

Single HTML file, no frameworks.
Uses fetch() to call the Flask API.

fetch() is the browser equivalent of curl.
- GET request:  fetch(url)
- POST request: fetch(url, { method: 'POST', headers: {...}, body: JSON.stringify({...}) })
- DELETE:       fetch(url, { method: 'DELETE' })

async/await used because network requests take time.
await pauses the function until the response arrives.

Flow when user adds a task:
1. addTask() runs
2. fetch() sends POST to Flask
3. Flask adds task to list, returns it as JSON
4. addTask() calls fetchTasks()
5. fetchTasks() sends GET to Flask
6. Flask returns full task list
7. Browser redraws the list


### Docker - backend

Dockerfile created in backend/:
```
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["python", "app.py"]
```

Key points:
- requirements.txt copied and installed before the rest of the code
  (Docker caches each step, this avoids reinstalling packages on every build)
- EXPOSE 5000 documents the port, doesn't actually publish it
- CMD is what runs when the container starts

.dockerignore created to exclude:
```
venv/
__pycache__/
*.pyc
.env
```

Build command:
```
docker build -t cloudcost-backend .
```

-t gives the image a name
. tells Docker to look for Dockerfile in current folder


---

Problem: Empty reply from server
Flask inside the container was binding to 127.0.0.1 by default which means it only listens inside the container, not from outside.
Fix — change the last line in app.py:
python# before
app.run(debug=True)

# after
app.run(host='0.0.0.0', debug=True)
0.0.0.0 means listen on all interfaces, allowing traffic from outside the container.

Problem: 404 Not Found after fixing host
app.run() was accidentally placed at the top of the file before any routes were defined. Flask started before it knew about any routes so nothing was registered.
Also CORS(app) was missing.
Fix — app.run() belongs only at the bottom inside if __name__ == '__main__': and CORS(app) must be right after app = Flask(__name__).


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
  jenkins/
  monitoring/
  .gitignore
  README.md
```


---


## Things to improve later

- Add a PATCH /tasks/<id> route to mark tasks as done
- Add input validation on the backend (what if title is missing?)
- Frontend could show a loading state while fetching
- Data resets on restart, Phase 2 (database) will fix this
- Flask dev server not suitable for production, will be replaced later