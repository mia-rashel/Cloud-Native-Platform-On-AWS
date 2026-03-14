from fastapi.testclient import TestClient
from unittest.mock import patch, AsyncMock
from main import app

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    assert response.json()["service"] == "python-app"


@patch("main.get_db")
def test_stats(mock_get_db):
    mock_conn = AsyncMock()
    mock_conn.fetchval.return_value = 5
    mock_get_db.return_value = mock_conn

    response = client.get("/api/stats")
    assert response.status_code == 200
    assert response.json()["service"] == "python-app"
    assert "total_items" in response.json()


@patch("main.get_db")
def test_create_item(mock_get_db):
    mock_conn = AsyncMock()
    mock_conn.fetchrow.return_value = {
        "id": 1,
        "name": "test",
        "value": "hello",
        "created_at": "2026-01-01"
    }
    mock_get_db.return_value = mock_conn

    response = client.post("/api/items", json={"name": "test", "value": "hello"})
    assert response.status_code == 200