import os
import json
import boto3
from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy


def get_db_password():
    secret_name = os.environ.get('DB_SECRET_NAME')

    # fall back to SQLite if no secret name provided (local dev)
    if not secret_name:
        return None

    client = boto3.client('secretsmanager', region_name='us-east-1')
    response = client.get_secret_value(SecretId=secret_name)
    return response['SecretString']


def build_database_url():
    secret = get_db_password()

    # local dev - use SQLite
    if not secret:
        return 'sqlite:///tasks.db'

    # production - use RDS Postgres
    db_host = os.environ.get('DB_HOST')
    db_name = os.environ.get('DB_NAME', 'cloudcost')
    db_user = os.environ.get('DB_USER', 'dbadmin')
    db_password = secret

    return f'postgresql://{db_user}:{db_password}@{db_host}/{db_name}'


app = Flask(__name__)
CORS(app)
app.config['SQLALCHEMY_DATABASE_URI'] = build_database_url()
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)


class Task(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    done = db.Column(db.Boolean, default=False)

    def to_dict(self):
        return {
            'id': self.id,
            'title': self.title,
            'done': self.done
        }


@app.route('/tasks', methods=['GET'])
def get_tasks():
    tasks = Task.query.all()
    return jsonify([task.to_dict() for task in tasks])


@app.route('/tasks', methods=['POST'])
def create_task():
    data = request.get_json()
    if not data or 'title' not in data:
        return jsonify({'message': 'title is required'}), 400
    task = Task(title=data['title'])
    db.session.add(task)
    db.session.commit()
    return jsonify(task.to_dict()), 201


@app.route('/tasks/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    task = Task.query.get(task_id)
    if not task:
        return jsonify({'message': 'Task not found'}), 404
    db.session.delete(task)
    db.session.commit()
    return jsonify({'message': 'Task deleted'}), 200


with app.app_context():
    db.create_all()

if __name__ == '__main__':
    app.run(host='0.0.0.0', debug=False)