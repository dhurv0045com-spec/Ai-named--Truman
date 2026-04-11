from fastapi import APIRouter

router = APIRouter()

@router.get("/health")
def health():
    return {
        "status": "ok",
        "service": "TRUMAN Backend",
        "phase": 4
    }
