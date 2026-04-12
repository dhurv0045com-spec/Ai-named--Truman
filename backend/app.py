from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from db.database import init_db
from routes.health import router as health_router
from routes.chat import router as chat_router
from routes.vault import router as vault_router
from routes.build import router as build_router
from routes.lab import router as lab_router
from routes.cosmos import router as cosmos_router
from routes.insights import router as insights_router
from config import DEFAULT_MODEL  # noqa: keep config imported for startup logging


@asynccontextmanager
async def lifespan(application: FastAPI):
    # Startup
    init_db()
    print("")
    print("TRUMAN Workspace — All systems online")
    print("http://localhost:8000")
    print("http://localhost:8000/docs")
    print("")
    yield
    # Shutdown
    print("TRUMAN Workspace — Shutting down")


app = FastAPI(title="TRUMAN Workspace API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router)
app.include_router(chat_router,    prefix="/chat")
app.include_router(vault_router,   prefix="/vault")
app.include_router(build_router,   prefix="/build")
app.include_router(lab_router,     prefix="/lab")
app.include_router(cosmos_router,  prefix="/cosmos")
app.include_router(insights_router, prefix="/insights")
