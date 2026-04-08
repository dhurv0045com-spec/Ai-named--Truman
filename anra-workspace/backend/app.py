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
from config import CORS_ALLOW_ORIGINS

app = FastAPI(title="AN-RA Workspace API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ALLOW_ORIGINS,
    allow_credentials=True,
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


@app.on_event("startup")
def startup():
    init_db()
    print("")
    print("AN-RA Workspace — All systems online")
    print("http://localhost:8000")
    print("http://localhost:8000/docs")
    print("")
