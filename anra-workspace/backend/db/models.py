from sqlalchemy import Column, Integer, String, Text, DateTime
from datetime import datetime
from db.database import Base


class ChatMessage(Base):
    __tablename__ = "chat_messages"
    id         = Column(Integer, primary_key=True, autoincrement=True)
    session_id = Column(String, index=True, nullable=False)
    role       = Column(String, nullable=False)
    content    = Column(Text, nullable=False)
    timestamp  = Column(DateTime, default=datetime.utcnow)


class VaultItem(Base):
    __tablename__ = "vault_items"
    id         = Column(Integer, primary_key=True, autoincrement=True)
    title      = Column(String, nullable=False)
    content    = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
