from fastapi import APIRouter

router = APIRouter()

@router.get("/health")
def health():
    return {
        "status": "ok",
        "service": "AN-RA Backend",
        "phase": 4
    }
