"""FastAPI server: capture → OKF, viewer data, voice query, notification schedule."""

import base64
import datetime as dt
import logging
import mimetypes
from zoneinfo import ZoneInfo

from fastapi import Depends, FastAPI, HTTPException, UploadFile, Form
from fastapi.responses import FileResponse, JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from . import config, gitsync, llm
from .okf import Bundle, OkfError

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("okf-memory")

app = FastAPI(title="okf-memory")
bundle = Bundle(config.MEMORIES_DIR, config.TIMEZONE)
_bearer = HTTPBearer(auto_error=False)

AUDIO_TYPES = {"audio/mp4", "audio/m4a", "audio/x-m4a", "audio/mpeg", "audio/wav", "audio/webm", "audio/aac"}


def auth(cred: HTTPAuthorizationCredentials | None = Depends(_bearer)) -> None:
    if not config.API_TOKEN:
        raise HTTPException(500, "server has no API_TOKEN configured")
    if cred is None or cred.credentials != config.API_TOKEN:
        raise HTTPException(401, "bad token")


@app.get("/api/health")
def health() -> dict:
    return {"ok": True, "memories": len(bundle.concept_paths())}


@app.get("/api/memories", dependencies=[Depends(auth)])
def list_memories() -> list[dict]:
    out = []
    for c in bundle.list_concepts():
        fm = c["frontmatter"]
        out.append({
            "path": c["path"],
            "type": fm.get("type"),
            "title": fm.get("title", c["path"]),
            "description": fm.get("description", ""),
            "tags": fm.get("tags", []),
            "status": fm.get("status", "stable"),
            "generated_at": str((fm.get("generated") or {}).get("at", "")),
            "notification_count": len(fm.get("notifications") or []),
        })
    return out


@app.get("/api/memories/{path:path}", dependencies=[Depends(auth)])
def get_memory(path: str) -> dict:
    try:
        return bundle.load_concept(path)
    except (OkfError, FileNotFoundError):
        raise HTTPException(404, f"no such memory: {path}")


@app.get("/api/references/{path:path}", dependencies=[Depends(auth)])
def get_reference(path: str) -> FileResponse:
    full = (bundle.root / "references" / path).resolve()
    if not full.is_relative_to((bundle.root / "references").resolve()) or not full.is_file():
        raise HTTPException(404, "no such reference")
    return FileResponse(full)


@app.get("/api/notifications", dependencies=[Depends(auth)])
def notifications() -> list[dict]:
    return bundle.notifications()


@app.post("/api/capture", dependencies=[Depends(auth)])
async def capture(file: UploadFile | None = None, text: str | None = Form(default=None)) -> dict:
    if file is None and not text:
        raise HTTPException(422, "provide an audio file, an image file, or text")

    transcript = None
    image = None
    source_rel = None
    if file is not None:
        data = await file.read()
        mime = file.content_type or mimetypes.guess_type(file.filename or "")[0] or ""
        if mime in AUDIO_TYPES or mime.startswith("audio/"):
            source_rel = bundle.save_reference("audio", file.filename or "note.m4a", data)
            transcript = llm.transcribe(data, file.filename or "note.m4a")
        elif mime.startswith("image/"):
            source_rel = bundle.save_reference("images", file.filename or "photo.jpg", data)
            image = (data, mime)
        else:
            raise HTTPException(415, f"unsupported content type: {mime}")

    index_md = (bundle.root / "index.md").read_text(encoding="utf-8")
    result = llm.generate_memory(transcript, text, image, index_md, source_rel)

    now = dt.datetime.now(ZoneInfo(config.TIMEZONE)).isoformat(timespec="seconds")
    written = []
    for f in result["files"]:
        meta = {
            "type": f["type"],
            "title": f["title"],
            "description": f["description"],
            "tags": f["tags"],
            "generated": {"by": config.AGENT_ACTOR, "at": now},
            "status": "stable",
        }
        if f.get("source"):
            meta["sources"] = [{"id": "capture", "resource": f"/{f['source']}",
                                "title": "original capture"}]
        if f["notifications"]:
            meta["notifications"] = f["notifications"]
        try:
            rel = bundle.write_concept(meta, f["body"])
        except OkfError as e:
            raise HTTPException(502, f"model produced non-conformant concept: {e}")
        written.append(rel)

    bundle.regenerate_index()
    bundle.append_log(result["log_entry"])
    gitsync.sync_async(bundle.root, f"Capture: {result['log_entry'][:72]}", config.GIT_PUSH_ENABLED)

    return {
        "written": written,
        "transcript": transcript,
        "log_entry": result["log_entry"],
        "memories": [bundle.load_concept(rel) for rel in written],
        "notifications": bundle.notifications(),
    }


@app.post("/api/query", dependencies=[Depends(auth)])
async def query(file: UploadFile | None = None, text: str | None = Form(default=None)) -> JSONResponse:
    if file is not None:
        data = await file.read()
        question = llm.transcribe(data, file.filename or "question.m4a")
    elif text:
        question = text
    else:
        raise HTTPException(422, "provide an audio file or text")

    answer = llm.answer_query(question, bundle.list_concepts())
    audio = llm.tts(answer)
    return JSONResponse({
        "question": question,
        "answer": answer,
        "audio_mime": "audio/mpeg",
        "audio_b64": base64.b64encode(audio).decode(),
    })
