# ============================================================
#  CommuteShare API — Backend completo
#  FastAPI + SQLAlchemy + JWT + WebSockets
# ============================================================

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect, Depends, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from typing import List, Optional
from uuid import uuid4
from datetime import datetime, timedelta
from sqlalchemy import Column, String, Float, Integer, Boolean, ForeignKey, Text, create_engine, func
from sqlalchemy.orm import relationship, sessionmaker, joinedload
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.exc import SQLAlchemyError
from jose import JWTError, jwt
import bcrypt
import json

# ============================================================
#  CONFIGURACIÓN
# ============================================================

DATABASE_URL = "sqlite:///./test.db"
SECRET_KEY = "commuteshare_secret_key_change_in_production"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30
REFRESH_TOKEN_EXPIRE_DAYS = 7

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

app = FastAPI(title="CommuteShare API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================
#  HELPER FUNCTIONS
# ============================================================

def hash_password(password: str) -> str:
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password.encode("utf-8"), salt).decode("utf-8")

def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))

def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    to_encode.update({"exp": datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def create_refresh_token(data: dict) -> str:
    to_encode = data.copy()
    to_encode.update({"exp": datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS), "type": "refresh"})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        raise HTTPException(status_code=401, detail="Token inválido o expirado")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def now_iso() -> str:
    return datetime.utcnow().isoformat()

# ============================================================
#  MODELOS SQLALCHEMY
# ============================================================

# ── Legacy (existente) ────────────────────────────────────────

class DriverDB(Base):
    __tablename__ = "drivers"
    id = Column(String, primary_key=True, index=True)
    name = Column(String)
    last_name = Column(String)
    email = Column(String, unique=True, index=True)
    password = Column(String)
    phone = Column(String)
    active = Column(Boolean, default=True)
    offers = relationship("OfferDB", back_populates="driver")

class OfferDB(Base):
    __tablename__ = "offers"
    id = Column(String, primary_key=True, index=True)
    driver_name = Column(String, index=True)
    driver_last_name = Column(String)
    driver_phone = Column(String)
    rating = Column(Float)
    job = Column(String)
    trips = Column(Integer)
    price = Column(Float)
    distance = Column(String)
    time = Column(String)
    hour = Column(String)
    color = Column(String)
    avatar = Column(String)
    home_lat = Column(Float)
    home_lng = Column(Float)
    destination_lat = Column(Float)
    destination_lng = Column(Float)
    recogida = Column(String)
    destino = Column(String)
    color_text = Column(String)
    modelo_auto = Column(String)
    mapa_theme = Column(String)
    placa_auto = Column(String)
    active = Column(Boolean, default=True)
    driver_id = Column(String, ForeignKey("drivers.id"))

OfferDB.driver = relationship("DriverDB", back_populates="offers")

# ── User Profile (extiende DriverDB) ──────────────────────────

class UserProfileDB(Base):
    __tablename__ = "user_profiles"
    id = Column(String, primary_key=True)
    driver_id = Column(String, ForeignKey("drivers.id"), unique=True)
    bio = Column(String, default="")
    role = Column(String, default="passenger")
    is_verified = Column(Boolean, default=False)
    trips_completed = Column(Integer, default=0)
    trips_offered = Column(Integer, default=0)
    rating = Column(Float, default=5.0)
    avatar_url = Column(String, default="")
    created_at = Column(String)
    updated_at = Column(String)

# ── Chat ──────────────────────────────────────────────────────

class ConversationDB(Base):
    __tablename__ = "conversations"
    id = Column(String, primary_key=True)
    user1_id = Column(String, ForeignKey("drivers.id"))
    user2_id = Column(String, ForeignKey("drivers.id"))
    last_message = Column(String, default="")
    last_time = Column(String)
    created_at = Column(String)

class MessageDB(Base):
    __tablename__ = "messages"
    id = Column(String, primary_key=True)
    conversation_id = Column(String, ForeignKey("conversations.id"))
    sender_id = Column(String, ForeignKey("drivers.id"))
    text = Column(Text)
    created_at = Column(String)
    is_read = Column(Boolean, default=False)

# ── Notifications ─────────────────────────────────────────────

class NotificationDB(Base):
    __tablename__ = "notifications"
    id = Column(String, primary_key=True)
    user_id = Column(String, ForeignKey("drivers.id"))
    title = Column(String)
    body = Column(Text)
    icon = Column(String, default="notifications")
    color = Column(String, default="#0066FF")
    is_read = Column(Boolean, default=False)
    created_at = Column(String)

# ── Reviews ───────────────────────────────────────────────────

class ReviewDB(Base):
    __tablename__ = "reviews"
    id = Column(String, primary_key=True)
    reviewer_id = Column(String, ForeignKey("drivers.id"))
    reviewee_id = Column(String, ForeignKey("drivers.id"))
    trip_id = Column(String, ForeignKey("offers.id"), nullable=True)
    rating = Column(Integer)
    comment = Column(Text)
    created_at = Column(String)

# ── Payment Methods ───────────────────────────────────────────

class PaymentMethodDB(Base):
    __tablename__ = "payment_methods"
    id = Column(String, primary_key=True)
    user_id = Column(String, ForeignKey("drivers.id"))
    type = Column(String)  # card, paypal, cash, applePay
    label = Column(String)
    detail = Column(String)
    is_default = Column(Boolean, default=False)
    created_at = Column(String)

# ── Refresh Tokens ────────────────────────────────────────────

class RefreshTokenDB(Base):
    __tablename__ = "refresh_tokens"
    id = Column(String, primary_key=True)
    user_id = Column(String, ForeignKey("drivers.id"))
    token = Column(String, unique=True, index=True)
    expires_at = Column(String)
    created_at = Column(String)

# ============================================================
#  SCHEMAS PYDANTIC
# ============================================================

class LoginData(BaseModel):
    email: EmailStr
    password: str

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class TokenRefresh(BaseModel):
    refresh_token: str

# ── Legacy schemas (sin cambios) ──────────────────────────────

class Offer(BaseModel):
    id: str
    driver_name: str
    driver_last_name: str
    driver_phone: str
    rating: float
    job: str
    trips: int
    price: float
    distance: str
    time: str
    hour: str
    color: str
    avatar: str
    home_lat: float
    home_lng: float
    destination_lat: float
    destination_lng: float
    recogida: str
    destino: str
    color_text: str
    modelo_auto: str
    mapa_theme: str
    placa_auto: str
    active: bool

    class Config:
        from_attributes = True

class Offer_update(BaseModel):
    driver_phone: Optional[str] = None
    rating: Optional[float] = None
    job: Optional[str] = None
    trips: Optional[int] = None
    price: Optional[float] = None
    distance: Optional[str] = None
    time: Optional[str] = None
    hour: Optional[str] = None
    avatar: Optional[str] = None
    home_lat: Optional[float] = None
    home_lng: Optional[float] = None
    destination_lat: Optional[float] = None
    destination_lng: Optional[float] = None
    recogida: Optional[str] = None
    destino: Optional[str] = None
    modelo_auto: Optional[str] = None
    mapa_theme: Optional[str] = None
    placa_auto: Optional[str] = None
    active: Optional[bool] = None

class OfferCreate(BaseModel):
    recogida: str
    destino: str
    price: float
    trips: int = 4
    hour: str = ""
    time: str = ""
    modelo_auto: str = ""
    placa_auto: str = ""
    color: str = ""
    color_text: str = ""

class active_offer(BaseModel):
    activeOffer: bool
    acriveDriver: bool

class Driver(BaseModel):
    id: str
    name: str
    last_name: str
    email: EmailStr
    password: str
    phone: str
    offers: List[Offer] = []
    active: bool = True

    class Config:
        from_attributes = True

class RegisterData(BaseModel):
    name: str
    last_name: str = ""
    email: EmailStr
    password: str
    phone: str = ""
    role: str = "passenger"

# ── User schemas ──────────────────────────────────────────────

class UserProfileResponse(BaseModel):
    id: str
    name: str
    last_name: str
    email: str
    phone: str
    bio: str = ""
    role: str = "passenger"
    is_verified: bool = False
    trips_completed: int = 0
    trips_offered: int = 0
    rating: float = 5.0
    avatar_url: str = ""
    active: bool = True

    class Config:
        from_attributes = True

class UserProfileUpdate(BaseModel):
    name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None

class RoleUpdate(BaseModel):
    role: str  # "passenger" | "driver"

# ── Chat schemas ──────────────────────────────────────────────

class ConversationCreate(BaseModel):
    user1_id: str
    user2_id: str

class ConversationResponse(BaseModel):
    id: str
    user1_id: str
    user2_id: str
    last_message: str = ""
    last_time: Optional[str] = None
    created_at: str

    class Config:
        from_attributes = True

class MessageCreate(BaseModel):
    sender_id: str
    text: str

class MessageResponse(BaseModel):
    id: str
    conversation_id: str
    sender_id: str
    text: str
    created_at: str
    is_read: bool = False

    class Config:
        from_attributes = True

# ── Notification schemas ──────────────────────────────────────

class NotificationResponse(BaseModel):
    id: str
    user_id: str
    title: str
    body: str
    icon: str = "notifications"
    color: str = "#0066FF"
    is_read: bool = False
    created_at: str

    class Config:
        from_attributes = True

class NotificationCreate(BaseModel):
    user_id: str
    title: str
    body: str
    icon: str = "notifications"
    color: str = "#0066FF"

# ── Review schemas ────────────────────────────────────────────

class ReviewCreate(BaseModel):
    reviewer_id: str
    reviewee_id: str
    trip_id: Optional[str] = None
    rating: int
    comment: str

class ReviewResponse(BaseModel):
    id: str
    reviewer_id: str
    reviewee_id: str
    trip_id: Optional[str] = None
    rating: int
    comment: str
    created_at: str

    class Config:
        from_attributes = True

# ── Payment schemas ───────────────────────────────────────────

class PaymentMethodCreate(BaseModel):
    user_id: str
    type: str
    label: str
    detail: str

class PaymentMethodResponse(BaseModel):
    id: str
    user_id: str
    type: str
    label: str
    detail: str
    is_default: bool = False
    created_at: str

    class Config:
        from_attributes = True

# ── Password Reset ────────────────────────────────────────────

class PasswordResetRequest(BaseModel):
    email: EmailStr
    id: str = ""
    new_password: str

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

# ============================================================
#  CREATE TABLES
# ============================================================

Base.metadata.create_all(bind=engine)

# ============================================================
#  WEB SOCKET MANAGER (Chat en tiempo real)
# ============================================================

class ConnectionManager:
    def __init__(self):
        self.active_connections: dict[str, list[WebSocket]] = {}

    async def connect(self, conversation_id: str, ws: WebSocket):
        await ws.accept()
        if conversation_id not in self.active_connections:
            self.active_connections[conversation_id] = []
        self.active_connections[conversation_id].append(ws)

    async def disconnect(self, conversation_id: str, ws: WebSocket):
        if conversation_id in self.active_connections:
            self.active_connections[conversation_id].remove(ws)
            if not self.active_connections[conversation_id]:
                del self.active_connections[conversation_id]

    async def broadcast(self, conversation_id: str, message: dict):
        for ws in self.active_connections.get(conversation_id, []):
            try:
                await ws.send_json(message)
            except Exception:
                pass

manager = ConnectionManager()

# ============================================================
#  ENDPOINTS LEGACY (sin cambios, compatibilidad)
# ============================================================

@app.post("/Create_driver/", response_model=Driver)
async def create_driver(data: RegisterData):
    ids = str(uuid4())
    db = SessionLocal()
    try:
        if db.query(DriverDB).filter(DriverDB.email == data.email).first():
            raise HTTPException(status_code=400, detail="Email ya existe")

        hashed_password = hash_password(data.password)
        db_driver = DriverDB(
            id=ids,
            name=data.name,
            last_name=data.last_name,
            email=data.email,
            password=hashed_password,
            phone=data.phone,
            active=True
        )

        db.add(db_driver)
        db.commit()
        db.refresh(db_driver)

        profile = UserProfileDB(
            id=str(uuid4()),
            driver_id=db_driver.id,
            bio="",
            role=data.role,
            is_verified=False,
            trips_completed=0,
            trips_offered=0,
            rating=5.0,
            created_at=now_iso(),
            updated_at=now_iso()
        )
        db.add(profile)
        db.commit()

        return Driver(
            id=db_driver.id,
            name=db_driver.name,
            last_name=db_driver.last_name,
            email=db_driver.email,
            password="",
            phone=db_driver.phone,
            offers=[],
            active=db_driver.active
        )
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(status_code=500, detail="Error en la base de datos")
    finally:
        db.close()

@app.put("/drivers/", response_model=Driver)
async def update_driver(email: str, password: str, driver_update: Driver):
    db = SessionLocal()
    db_driver = db.query(DriverDB).filter(DriverDB.email == email).first()
    if not db_driver:
        db.close()
        raise HTTPException(status_code=404, detail="Driver no encontrado")
    if not verify_password(password, db_driver.password):
        db.close()
        raise HTTPException(status_code=401, detail="Contraseña incorrecta")
    if db_driver.email != driver_update.email:
        existing_driver = db.query(DriverDB).filter(DriverDB.email == driver_update.email).first()
        if existing_driver:
            db.close()
            raise HTTPException(status_code=400, detail="El correo electrónico ya está en uso")
    db_driver.name = driver_update.name
    db_driver.last_name = driver_update.last_name
    db_driver.email = driver_update.email
    db_driver.phone = driver_update.phone
    db_driver.active = driver_update.active
    if driver_update.password:
        db_driver.password = hash_password(driver_update.password)
    for offer in db_driver.offers:
        offer.driver_name = driver_update.name
        offer.driver_last_name = driver_update.last_name
        offer.driver_phone = driver_update.phone
        offer.active = driver_update.active
    db.commit()
    db.refresh(db_driver)
    db.close()
    return driver_update

@app.get("/offers-key/", response_model=List[Offer])
async def get_offers(email: str, password: str):
    db = SessionLocal()
    try:
        db_driver = db.query(DriverDB).filter(DriverDB.email == email).first()
        if not db_driver or not verify_password(password, db_driver.password):
            raise HTTPException(status_code=401, detail="Email o contraseña incorrectos")
        db_offers = db.query(OfferDB).filter(OfferDB.driver_id == db_driver.id).all()
        if not db_offers:
            raise HTTPException(status_code=404, detail="No se encontraron ofertas para este conductor")
        return db_offers
    finally:
        db.close()

@app.put("/offers_update/", response_model=List[Offer])
async def update_offers_legacy(email: str, password: str, offer_data: Offer_update):
    db = SessionLocal()
    try:
        db_driver = db.query(DriverDB).filter(DriverDB.email == email).first()
        if not db_driver or not verify_password(password, db_driver.password):
            raise HTTPException(status_code=401, detail="Email o contraseña incorrectos")
        db_offer = db.query(OfferDB).filter(OfferDB.driver_id == db_driver.id).first()
        if not db_offer:
            raise HTTPException(status_code=404, detail="No se encontraron ofertas para este conductor")
        update_data = {k: v for k, v in offer_data.dict().items() if v is not None}
        for key, value in update_data.items():
            setattr(db_offer, key, value)
        db.commit()
        db.refresh(db_offer)
        return [db_offer]
    finally:
        db.close()

@app.put("/offers/", response_model=List[Offer])
async def update_offers_active(email: str, password: str, offer_data: active_offer):
    db = SessionLocal()
    try:
        db_driver = db.query(DriverDB).filter(DriverDB.email == email).first()
        if not db_driver or not verify_password(password, db_driver.password):
            raise HTTPException(status_code=401, detail="Email o contraseña incorrectos")
        db_offer = db.query(OfferDB).filter(OfferDB.driver_id == db_driver.id).first()
        if not db_offer:
            raise HTTPException(status_code=404, detail="No se encontraron ofertas para este conductor")
        db_offer.active = offer_data.activeOffer
        db_driver.active = offer_data.acriveDriver
        db.commit()
        db.refresh(db_offer)
        return [db_offer]
    finally:
        db.close()

@app.get("/offers", response_model=List[Offer])
async def get_active_offers():
    db = SessionLocal()
    offers = db.query(OfferDB).filter(OfferDB.active == True).all()
    db.close()
    return offers

@app.get("/offers_list", response_model=List[Offer])
async def get_all_offers_list():
    db = SessionLocal()
    offers = db.query(OfferDB).all()
    db.close()
    return offers

@app.get("/drivers/{driver_id}/offers", response_model=List[Offer])
async def get_driver_offers(driver_id: str):
    db = SessionLocal()
    db_driver = db.query(DriverDB).options(joinedload(DriverDB.offers)).filter(DriverDB.id == driver_id).first()
    if not db_driver:
        db.close()
        raise HTTPException(status_code=404, detail="Driver no encontrado")
    offers = db_driver.offers
    db.close()
    return offers

@app.post("/login/offers", response_model=List[Offer])
async def login_offers(data: LoginData):
    db = SessionLocal()
    try:
        db_driver = db.query(DriverDB).filter(DriverDB.email == data.email).first()
        if db_driver and verify_password(data.password, db_driver.password):
            offers = db.query(OfferDB).filter(OfferDB.driver_id == db_driver.id).all()
            return offers
        raise HTTPException(status_code=401, detail="Email o contraseña incorrectos")
    finally:
        db.close()

@app.post("/login", response_model=List[Driver])
async def login_legacy(email: EmailStr, password: str):
    db = SessionLocal()
    try:
        db_driver = db.query(DriverDB).filter(DriverDB.email == email).first()
        if db_driver and verify_password(password, db_driver.password):
            return [db_driver]
        raise HTTPException(status_code=401, detail="Email o contraseña incorrectos")
    finally:
        db.close()

@app.get("/all_drivers", response_model=List[Driver])
async def get_all_drivers():
    db = SessionLocal()
    try:
        return db.query(DriverDB).all()
    finally:
        db.close()

# ============================================================
#  ENDPOINTS NUEVOS — AUTH JWT
# ============================================================

@app.post("/login_jwt", response_model=TokenResponse)
async def login_jwt(data: LoginData):
    db = SessionLocal()
    try:
        driver = db.query(DriverDB).filter(DriverDB.email == data.email).first()
        if not driver or not verify_password(data.password, driver.password):
            raise HTTPException(status_code=401, detail="Credenciales inválidas")

        token_data = {"sub": driver.id, "email": driver.email}
        access_token = create_access_token(token_data)
        refresh_token = create_refresh_token(token_data)

        rt = RefreshTokenDB(
            id=str(uuid4()),
            user_id=driver.id,
            token=refresh_token,
            expires_at=(datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)).isoformat(),
            created_at=now_iso()
        )
        db.add(rt)
        db.commit()

        return TokenResponse(access_token=access_token, refresh_token=refresh_token)
    finally:
        db.close()

@app.post("/auth/refresh", response_model=TokenResponse)
async def refresh_token(data: TokenRefresh):
    db = SessionLocal()
    try:
        payload = decode_token(data.refresh_token)
        if payload.get("type") != "refresh":
            raise HTTPException(status_code=401, detail="Token no es de tipo refresh")

        stored = db.query(RefreshTokenDB).filter(
            RefreshTokenDB.token == data.refresh_token
        ).first()
        if not stored:
            raise HTTPException(status_code=401, detail="Refresh token no encontrado")

        token_data = {"sub": payload["sub"], "email": payload["email"]}
        new_access = create_access_token(token_data)
        new_refresh = create_refresh_token(token_data)

        db.delete(stored)
        rt = RefreshTokenDB(
            id=str(uuid4()),
            user_id=payload["sub"],
            token=new_refresh,
            expires_at=(datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)).isoformat(),
            created_at=now_iso()
        )
        db.add(rt)
        db.commit()

        return TokenResponse(access_token=new_access, refresh_token=new_refresh)
    finally:
        db.close()

@app.post("/auth/logout")
async def logout(token: str = Query(...)):
    db = SessionLocal()
    try:
        payload = decode_token(token)
        db.query(RefreshTokenDB).filter(RefreshTokenDB.user_id == payload["sub"]).delete()
        db.commit()
        return {"message": "Sesión cerrada exitosamente"}
    finally:
        db.close()

# ============================================================
#  ENDPOINTS NUEVOS — USERS / PROFILE
# ============================================================

def _get_user_from_token(token: str, db):
    payload = decode_token(token)
    driver = db.query(DriverDB).filter(DriverDB.id == payload["sub"]).first()
    if not driver:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
    return driver

def _build_user_profile(driver: DriverDB, profile: Optional[UserProfileDB]) -> UserProfileResponse:
    return UserProfileResponse(
        id=driver.id,
        name=driver.name,
        last_name=driver.last_name,
        email=driver.email,
        phone=driver.phone,
        bio=profile.bio if profile else "",
        role=profile.role if profile else "passenger",
        is_verified=profile.is_verified if profile else False,
        trips_completed=profile.trips_completed if profile else 0,
        trips_offered=profile.trips_offered if profile else 0,
        rating=profile.rating if profile else 5.0,
        avatar_url=profile.avatar_url if profile else "",
        active=driver.active
    )

@app.get("/users/me", response_model=UserProfileResponse)
async def get_my_profile(token: str = Query(...)):
    db = SessionLocal()
    try:
        driver = _get_user_from_token(token, db)
        profile = db.query(UserProfileDB).filter(UserProfileDB.driver_id == driver.id).first()
        return _build_user_profile(driver, profile)
    finally:
        db.close()

@app.patch("/users/me", response_model=UserProfileResponse)
async def update_my_profile(data: UserProfileUpdate, token: str = Query(...)):
    db = SessionLocal()
    try:
        driver = _get_user_from_token(token, db)
        profile = db.query(UserProfileDB).filter(UserProfileDB.driver_id == driver.id).first()
        if not profile:
            profile = UserProfileDB(
                id=str(uuid4()),
                driver_id=driver.id,
                created_at=now_iso(),
                updated_at=now_iso()
            )
            db.add(profile)

        if data.name is not None:
            driver.name = data.name
        if data.last_name is not None:
            driver.last_name = data.last_name
        if data.email is not None:
            if data.email != driver.email:
                existing = db.query(DriverDB).filter(DriverDB.email == data.email).first()
                if existing:
                    raise HTTPException(status_code=400, detail="Email ya en uso")
            driver.email = data.email
        if data.phone is not None:
            driver.phone = data.phone
        if data.bio is not None:
            profile.bio = data.bio
        if data.avatar_url is not None:
            profile.avatar_url = data.avatar_url

        profile.updated_at = now_iso()
        db.commit()
        db.refresh(driver)
        return _build_user_profile(driver, profile)
    finally:
        db.close()

@app.post("/users/verify")
async def verify_user(token: str = Query(...)):
    db = SessionLocal()
    try:
        driver = _get_user_from_token(token, db)
        profile = db.query(UserProfileDB).filter(UserProfileDB.driver_id == driver.id).first()
        if not profile:
            raise HTTPException(status_code=404, detail="Perfil no encontrado")
        profile.is_verified = True
        profile.updated_at = now_iso()
        db.commit()
        return {"message": "Identidad verificada", "is_verified": True}
    finally:
        db.close()

@app.patch("/users/role", response_model=UserProfileResponse)
async def change_role(data: RoleUpdate, token: str = Query(...)):
    db = SessionLocal()
    try:
        if data.role not in ("passenger", "driver"):
            raise HTTPException(status_code=400, detail="Rol inválido. Usa 'passenger' o 'driver'")
        driver = _get_user_from_token(token, db)
        profile = db.query(UserProfileDB).filter(UserProfileDB.driver_id == driver.id).first()
        if not profile:
            raise HTTPException(status_code=404, detail="Perfil no encontrado")
        profile.role = data.role
        profile.updated_at = now_iso()
        db.commit()
        return _build_user_profile(driver, profile)
    finally:
        db.close()

@app.get("/users/{user_id}", response_model=UserProfileResponse)
async def get_user(user_id: str):
    db = SessionLocal()
    try:
        driver = db.query(DriverDB).filter(DriverDB.id == user_id).first()
        if not driver:
            raise HTTPException(status_code=404, detail="Usuario no encontrado")
        profile = db.query(UserProfileDB).filter(UserProfileDB.driver_id == driver.id).first()
        return _build_user_profile(driver, profile)
    finally:
        db.close()

# ============================================================
#  ENDPOINTS NUEVOS — OFFERS (JWT)
# ============================================================

@app.post("/offers/create", response_model=Offer)
async def create_my_offer(data: OfferCreate, token: str = Query(...)):
    db = SessionLocal()
    try:
        driver = _get_user_from_token(token, db)
        existing = db.query(OfferDB).filter(
            OfferDB.driver_id == driver.id, OfferDB.active == True
        ).first()
        if existing:
            existing.active = False
            db.flush()

        offer = OfferDB(
            id=str(uuid4()),
            driver_name=driver.name,
            driver_last_name=driver.last_name,
            driver_phone=driver.phone,
            rating=5.0,
            job="",
            trips=data.trips,
            price=data.price,
            distance="",
            time=data.time,
            hour=data.hour,
            color=data.color,
            avatar="",
            home_lat=0.0,
            home_lng=0.0,
            destination_lat=0.0,
            destination_lng=0.0,
            recogida=data.recogida,
            destino=data.destino,
            color_text=data.color_text,
            modelo_auto=data.modelo_auto,
            mapa_theme="",
            placa_auto=data.placa_auto,
            active=True,
            driver_id=driver.id,
        )
        db.add(offer)
        db.commit()
        db.refresh(offer)
        return offer
    except SQLAlchemyError:
        db.rollback()
        raise HTTPException(status_code=500, detail="Error al crear la oferta")
    finally:
        db.close()

@app.get("/offers_list_jdwt", response_model=List[Offer])
async def get_my_offers_jwt(token: str = Query(...)):
    db = SessionLocal()
    try:
        driver = _get_user_from_token(token, db)
        offers = db.query(OfferDB).filter(OfferDB.driver_id == driver.id).all()
        return offers
    finally:
        db.close()

@app.patch("/offers_update_jwt", response_model=List[Offer])
async def update_offer_jwt(offer_data: Offer_update, token: str = Query(...)):
    db = SessionLocal()
    try:
        driver = _get_user_from_token(token, db)
        db_offer = db.query(OfferDB).filter(OfferDB.driver_id == driver.id).first()
        if not db_offer:
            raise HTTPException(status_code=404, detail="No se encontraron ofertas")
        update_data = {k: v for k, v in offer_data.dict().items() if v is not None}
        for key, value in update_data.items():
            setattr(db_offer, key, value)
        db.commit()
        db.refresh(db_offer)
        return [db_offer]
    finally:
        db.close()

# ============================================================
#  ENDPOINTS NUEVOS — CHAT / CONVERSATIONS
# ============================================================

@app.get("/conversations", response_model=List[ConversationResponse])
async def get_conversations(user_id: str = Query(...)):
    db = SessionLocal()
    try:
        convs = db.query(ConversationDB).filter(
            (ConversationDB.user1_id == user_id) | (ConversationDB.user2_id == user_id)
        ).order_by(ConversationDB.last_time.desc()).all()
        return convs
    finally:
        db.close()

@app.post("/conversations", response_model=ConversationResponse)
async def create_conversation(data: ConversationCreate):
    db = SessionLocal()
    try:
        existing = db.query(ConversationDB).filter(
            ((ConversationDB.user1_id == data.user1_id) & (ConversationDB.user2_id == data.user2_id)) |
            ((ConversationDB.user1_id == data.user2_id) & (ConversationDB.user2_id == data.user1_id))
        ).first()
        if existing:
            return existing

        conv = ConversationDB(
            id=str(uuid4()),
            user1_id=data.user1_id,
            user2_id=data.user2_id,
            last_message="",
            last_time=now_iso(),
            created_at=now_iso()
        )
        db.add(conv)
        db.commit()
        db.refresh(conv)
        return conv
    finally:
        db.close()

@app.get("/conversations/{conv_id}/messages", response_model=List[MessageResponse])
async def get_messages(conv_id: str):
    db = SessionLocal()
    try:
        conv = db.query(ConversationDB).filter(ConversationDB.id == conv_id).first()
        if not conv:
            raise HTTPException(status_code=404, detail="Conversación no encontrada")
        messages = db.query(MessageDB).filter(
            MessageDB.conversation_id == conv_id
        ).order_by(MessageDB.created_at.asc()).all()
        return messages
    finally:
        db.close()

@app.post("/conversations/{conv_id}/messages", response_model=MessageResponse)
async def send_message(conv_id: str, data: MessageCreate):
    db = SessionLocal()
    try:
        conv = db.query(ConversationDB).filter(ConversationDB.id == conv_id).first()
        if not conv:
            raise HTTPException(status_code=404, detail="Conversación no encontrada")

        msg = MessageDB(
            id=str(uuid4()),
            conversation_id=conv_id,
            sender_id=data.sender_id,
            text=data.text,
            created_at=now_iso(),
            is_read=False
        )
        db.add(msg)

        conv.last_message = data.text
        conv.last_time = now_iso()
        db.commit()
        db.refresh(msg)
        return msg
    finally:
        db.close()

@app.patch("/conversations/{conv_id}/read")
async def mark_conversation_read(conv_id: str, user_id: str = Query(...)):
    db = SessionLocal()
    try:
        db.query(MessageDB).filter(
            MessageDB.conversation_id == conv_id,
            MessageDB.sender_id != user_id,
            MessageDB.is_read == False
        ).update({"is_read": True})
        db.commit()
        return {"message": "Marcado como leído"}
    finally:
        db.close()

# ============================================================
#  WEB SOCKET — Chat en tiempo real
# ============================================================

@app.websocket("/ws/chat/{conversation_id}")
async def websocket_chat(ws: WebSocket, conversation_id: str):
    await manager.connect(conversation_id, ws)
    try:
        while True:
            raw = await ws.receive_text()
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                data = {"text": raw}

            db = SessionLocal()
            try:
                conv = db.query(ConversationDB).filter(ConversationDB.id == conversation_id).first()
                if conv and "sender_id" in data and "text" in data:
                    msg = MessageDB(
                        id=str(uuid4()),
                        conversation_id=conversation_id,
                        sender_id=data["sender_id"],
                        text=data["text"],
                        created_at=now_iso(),
                        is_read=False
                    )
                    db.add(msg)
                    conv.last_message = data["text"]
                    conv.last_time = now_iso()
                    db.commit()

                    response = {
                        "type": "new_message",
                        "id": msg.id,
                        "conversation_id": conversation_id,
                        "sender_id": data["sender_id"],
                        "text": data["text"],
                        "created_at": msg.created_at
                    }
                    await manager.broadcast(conversation_id, response)
            finally:
                db.close()
    except WebSocketDisconnect:
        await manager.disconnect(conversation_id, ws)

# ============================================================
#  ENDPOINTS NUEVOS — NOTIFICATIONS
# ============================================================

@app.get("/notifications", response_model=List[NotificationResponse])
async def get_notifications(user_id: str = Query(...)):
    db = SessionLocal()
    try:
        notifs = db.query(NotificationDB).filter(
            NotificationDB.user_id == user_id
        ).order_by(NotificationDB.created_at.desc()).all()
        return notifs
    finally:
        db.close()

@app.post("/notifications", response_model=NotificationResponse)
async def create_notification(data: NotificationCreate):
    db = SessionLocal()
    try:
        notif = NotificationDB(
            id=str(uuid4()),
            user_id=data.user_id,
            title=data.title,
            body=data.body,
            icon=data.icon,
            color=data.color,
            is_read=False,
            created_at=now_iso()
        )
        db.add(notif)
        db.commit()
        db.refresh(notif)
        return notif
    finally:
        db.close()

@app.patch("/notifications/{notif_id}/read", response_model=NotificationResponse)
async def mark_notification_read(notif_id: str):
    db = SessionLocal()
    try:
        notif = db.query(NotificationDB).filter(NotificationDB.id == notif_id).first()
        if not notif:
            raise HTTPException(status_code=404, detail="Notificación no encontrada")
        notif.is_read = True
        db.commit()
        db.refresh(notif)
        return notif
    finally:
        db.close()

@app.patch("/notifications/read-all")
async def mark_all_notifications_read(user_id: str = Query(...)):
    db = SessionLocal()
    try:
        db.query(NotificationDB).filter(
            NotificationDB.user_id == user_id,
            NotificationDB.is_read == False
        ).update({"is_read": True})
        db.commit()
        return {"message": "Todas las notificaciones marcadas como leídas"}
    finally:
        db.close()

# ============================================================
#  ENDPOINTS NUEVOS — REVIEWS
# ============================================================

@app.get("/reviews/{user_id}", response_model=List[ReviewResponse])
async def get_user_reviews(user_id: str):
    db = SessionLocal()
    try:
        reviews = db.query(ReviewDB).filter(
            ReviewDB.reviewee_id == user_id
        ).order_by(ReviewDB.created_at.desc()).all()
        return reviews
    finally:
        db.close()

@app.post("/reviews", response_model=ReviewResponse)
async def create_review(data: ReviewCreate):
    db = SessionLocal()
    try:
        if data.rating < 1 or data.rating > 5:
            raise HTTPException(status_code=400, detail="Rating debe estar entre 1 y 5")
        if data.reviewer_id == data.reviewee_id:
            raise HTTPException(status_code=400, detail="No puedes auto-review")

        review = ReviewDB(
            id=str(uuid4()),
            reviewer_id=data.reviewer_id,
            reviewee_id=data.reviewee_id,
            trip_id=data.trip_id,
            rating=data.rating,
            comment=data.comment,
            created_at=now_iso()
        )
        db.add(review)

        avg = db.query(ReviewDB).filter(ReviewDB.reviewee_id == data.reviewee_id).with_entities(
            func.avg(ReviewDB.rating)
        ).scalar()

        profile = db.query(UserProfileDB).filter(UserProfileDB.driver_id == data.reviewee_id).first()
        if profile:
            profile.rating = round(avg, 1) if avg else data.rating

        db.commit()
        db.refresh(review)
        return review
    finally:
        db.close()

@app.get("/reviews/my", response_model=List[ReviewResponse])
async def get_my_reviews(token: str = Query(...)):
    db = SessionLocal()
    try:
        driver = _get_user_from_token(token, db)
        reviews = db.query(ReviewDB).filter(
            ReviewDB.reviewee_id == driver.id
        ).order_by(ReviewDB.created_at.desc()).all()
        return reviews
    finally:
        db.close()

# ============================================================
#  ENDPOINTS NUEVOS — PAYMENT METHODS
# ============================================================

@app.get("/payments/methods", response_model=List[PaymentMethodResponse])
async def get_payment_methods(user_id: str = Query(...)):
    db = SessionLocal()
    try:
        methods = db.query(PaymentMethodDB).filter(
            PaymentMethodDB.user_id == user_id
        ).order_by(PaymentMethodDB.is_default.desc()).all()
        return methods
    finally:
        db.close()

@app.post("/payments/methods", response_model=PaymentMethodResponse)
async def add_payment_method(data: PaymentMethodCreate):
    db = SessionLocal()
    try:
        existing = db.query(PaymentMethodDB).filter(
            PaymentMethodDB.user_id == data.user_id
        ).count()
        method = PaymentMethodDB(
            id=str(uuid4()),
            user_id=data.user_id,
            type=data.type,
            label=data.label,
            detail=data.detail,
            is_default=(existing == 0),
            created_at=now_iso()
        )
        db.add(method)
        db.commit()
        db.refresh(method)
        return method
    finally:
        db.close()

@app.delete("/payments/methods/{method_id}")
async def delete_payment_method(method_id: str):
    db = SessionLocal()
    try:
        method = db.query(PaymentMethodDB).filter(PaymentMethodDB.id == method_id).first()
        if not method:
            raise HTTPException(status_code=404, detail="Método de pago no encontrado")
        was_default = method.is_default
        user_id = method.user_id
        db.delete(method)

        if was_default:
            first_other = db.query(PaymentMethodDB).filter(
                PaymentMethodDB.user_id == user_id
            ).first()
            if first_other:
                first_other.is_default = True
        db.commit()
        return {"message": "Método de pago eliminado"}
    finally:
        db.close()

@app.patch("/payments/methods/{method_id}/default", response_model=PaymentMethodResponse)
async def set_default_payment_method(method_id: str):
    db = SessionLocal()
    try:
        method = db.query(PaymentMethodDB).filter(PaymentMethodDB.id == method_id).first()
        if not method:
            raise HTTPException(status_code=404, detail="Método de pago no encontrado")

        db.query(PaymentMethodDB).filter(
            PaymentMethodDB.user_id == method.user_id
        ).update({"is_default": False})

        method.is_default = True
        db.commit()
        db.refresh(method)
        return method
    finally:
        db.close()

# ============================================================
#  ENDPOINTS NUEVOS — PASSWORD RESET
# ============================================================

@app.patch("/password_reset_jwt")
async def reset_password_jwt(data: PasswordResetRequest):
    db = SessionLocal()
    try:
        if data.id:
            driver = db.query(DriverDB).filter(DriverDB.id == data.id).first()
        else:
            driver = db.query(DriverDB).filter(DriverDB.email == data.email).first()
        if not driver:
            raise HTTPException(status_code=404, detail="Usuario no encontrado")
        driver.password = hash_password(data.new_password)
        db.commit()
        return {"message": "Contraseña actualizada exitosamente"}
    finally:
        db.close()

@app.patch("/password_reset")
async def reset_password_legacy(email: str, new_password: str):
    db = SessionLocal()
    try:
        driver = db.query(DriverDB).filter(DriverDB.email == email).first()
        if not driver:
            raise HTTPException(status_code=404, detail="Usuario no encontrado")
        driver.password = hash_password(new_password)
        db.commit()
        return {"message": "Contraseña actualizada exitosamente"}
    finally:
        db.close()

@app.post("/auth/change-password")
async def change_password(data: ChangePasswordRequest, token: str = Query(...)):
    db = SessionLocal()
    try:
        driver = _get_user_from_token(token, db)
        if not verify_password(data.current_password, driver.password):
            raise HTTPException(status_code=401, detail="Contraseña actual incorrecta")
        driver.password = hash_password(data.new_password)
        db.commit()
        return {"message": "Contraseña cambiada exitosamente"}
    finally:
        db.close()

# ============================================================
#  HEALTH CHECK
# ============================================================

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "version": "2.0",
        "timestamp": now_iso()
    }
