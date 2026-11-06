import os
import time
import socket
import logging
from typing import List, Optional
from datetime import datetime

from fastapi import FastAPI, HTTPException, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("backend")

app = FastAPI(
    title="Community Pulse API",
    description="Microservice Backend for Kubernetes Praxistransferprojekt",
    version="1.0.0"
)

# CORS Middleware (allows Frontend in cluster to query API)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Environment configuration
POD_NAME = os.getenv("POD_NAME", socket.gethostname())
NODE_NAME = os.getenv("NODE_NAME", "unknown-node")
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")

DB_HOST = os.getenv("DB_HOST", "postgres")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "community_db")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "postgrespassword")

# Prometheus Metrics
REQUEST_COUNTER = Counter("http_requests_total", "Total HTTP Requests", ["method", "endpoint", "status"])
REQUEST_DURATION = Histogram("http_request_duration_seconds", "HTTP Request Duration", ["endpoint"])

# In-memory fallback if DB is not yet available
in_memory_posts = [
    {
        "id": 1,
        "title": "Willkommen im Kubernetes-Cluster!",
        "content": "Dieses System läuft auf einem K3s-Multi-Node-Cluster auf AWS EC2.",
        "author": "System",
        "created_at": datetime.utcnow().isoformat()
    }
]

class PostCreate(BaseModel):
    title: str
    content: str
    author: Optional[str] = "Gast"

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        connect_timeout=2
    )

def init_db():
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute("""
                CREATE TABLE IF NOT EXISTS posts (
                    id SERIAL PRIMARY KEY,
                    title VARCHAR(255) NOT NULL,
                    content TEXT NOT NULL,
                    author VARCHAR(100) DEFAULT 'Gast',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
            """)
            conn.commit()
            logger.info("Database schema initialized successfully.")
        conn.close()
    except Exception as e:
        logger.warning(f"Could not initialize DB on startup: {e}")

@app.on_event("startup")
def startup_event():
    init_db()

@app.middleware("http")
async def track_metrics_middleware(request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time
    
    endpoint = request.url.path
    status = str(response.status_code)
    REQUEST_COUNTER.labels(method=request.method, endpoint=endpoint, status=status).inc()
    REQUEST_DURATION.labels(endpoint=endpoint).observe(duration)
    
    return response

@app.get("/healthz", summary="Liveness Probe")
def healthz():
    return {"status": "ok", "pod": POD_NAME, "node": NODE_NAME}

@app.get("/ready", summary="Readiness Probe")
def ready():
    # Verify DB connectivity if required
    try:
        conn = get_db_connection()
        conn.close()
        return {"status": "ready", "database": "connected"}
    except Exception as e:
        return {"status": "ready", "database": "in-memory-fallback", "db_error": str(e)}

@app.get("/metrics", summary="Prometheus Metrics")
def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.get("/api/v1/info", summary="Cluster Info")
def cluster_info():
    db_status = "connected"
    try:
        conn = get_db_connection()
        conn.close()
    except Exception:
        db_status = "disconnected (in-memory mode)"

    return {
        "service": "community-backend",
        "pod_name": POD_NAME,
        "node_name": NODE_NAME,
        "environment": ENVIRONMENT,
        "database_status": db_status,
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/api/v1/posts", summary="Get all posts")
def get_posts():
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT id, title, content, author, created_at FROM posts ORDER BY id DESC LIMIT 50;")
            rows = cur.fetchall()
            posts = [dict(row) for row in rows]
        conn.close()
        return posts
    except Exception as e:
        logger.info(f"Using in-memory posts fallback: {e}")
        return in_memory_posts

@app.post("/api/v1/posts", summary="Create new post")
def create_post(post: PostCreate):
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "INSERT INTO posts (title, content, author) VALUES (%s, %s, %s) RETURNING id, title, content, author, created_at;",
                (post.title, post.content, post.author)
            )
            new_post = dict(cur.fetchone())
            conn.commit()
        conn.close()
        return new_post
    except Exception as e:
        logger.warning(f"DB insert failed, saving to in-memory fallback: {e}")
        new_post = {
            "id": len(in_memory_posts) + 1,
            "title": post.title,
            "content": post.content,
            "author": post.author,
            "created_at": datetime.utcnow().isoformat()
        }
        in_memory_posts.insert(0, new_post)
        return new_post

@app.get("/api/v1/work", summary="CPU Load Generator for HPA Testing")
def compute_work(iterations: int = 500000):
    """Generates CPU load to demonstrate Horizontal Pod Autoscaler (HPA) in action."""
    start = time.time()
    total = 0
    for i in range(iterations):
        total += i * i
    elapsed = time.time() - start
    return {
        "status": "completed",
        "iterations": iterations,
        "duration_seconds": round(elapsed, 4),
        "handled_by_pod": POD_NAME,
        "handled_by_node": NODE_NAME
    }
