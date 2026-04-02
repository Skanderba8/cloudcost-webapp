import pytest
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'backend'))
from app import app, db


@pytest.fixture
def client():
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'

    with app.app_context():
        db.drop_all()
        db.create_all()
        with app.test_client() as client:
            yield client
        db.drop_all()


def test_get_tasks_empty(client):
    res = client.get('/tasks')
    assert res.status_code == 200
    assert res.get_json() == []


def test_create_task(client):
    res = client.post('/tasks', json={'title': 'test task'})
    assert res.status_code == 201
    data = res.get_json()
    assert data['title'] == 'test task'
    assert data['done'] is False
    assert 'id' in data


def test_create_task_missing_title(client):
    res = client.post('/tasks', json={})
    assert res.status_code == 400


def test_delete_task(client):
    created = client.post('/tasks', json={'title': 'to delete'})
    task_id = created.get_json()['id']

    res = client.delete(f'/tasks/{task_id}')
    assert res.status_code == 200

    res = client.get('/tasks')
    assert res.get_json() == []


def test_delete_task_not_found(client):
    res = client.delete('/tasks/999')
    assert res.status_code == 404