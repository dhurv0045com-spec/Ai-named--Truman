from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from datetime import datetime
from db.database import get_db
from db.crud import get_vault, save_vault_item, delete_vault_item

router = APIRouter()


class VaultCreate(BaseModel):
    title: str
    content: str


class VaultResponse(BaseModel):
    id: int
    title: str
    content: str
    created_at: datetime

    class Config:
        from_attributes = True


@router.get("", response_model=list[VaultResponse])
def list_vault(db: Session = Depends(get_db)):
    return get_vault(db)


@router.post("", response_model=VaultResponse)
def create_vault_item(item: VaultCreate,
                      db: Session = Depends(get_db)):
    return save_vault_item(db, item.title, item.content)


@router.delete("/{item_id}")
def remove_vault_item(item_id: int,
                      db: Session = Depends(get_db)):
    success = delete_vault_item(db, item_id)
    if not success:
        raise HTTPException(status_code=404, detail="Item not found")
    return {"deleted": item_id}


@router.get("/count")
def vault_count(db: Session = Depends(get_db)):
    return {"count": len(get_vault(db))}
