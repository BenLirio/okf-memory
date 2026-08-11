"""OpenAI integration: Whisper STT, GPT-5.6 memory generation & query answering, TTS."""

import base64
import datetime as dt
import io
import json
from zoneinfo import ZoneInfo

from openai import OpenAI

from . import config

_client: OpenAI | None = None


def client() -> OpenAI:
    global _client
    if _client is None:
        _client = OpenAI(api_key=config.OPENAI_API_KEY)
    return _client


def transcribe(data: bytes, filename: str) -> str:
    f = io.BytesIO(data)
    f.name = filename
    result = client().audio.transcriptions.create(model=config.STT_MODEL, file=f)
    return result.text.strip()


MEMORY_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": ["files", "log_entry"],
    "properties": {
        "files": {
            "type": "array",
            "items": {
                "type": "object",
                "additionalProperties": False,
                "required": ["type", "title", "description", "tags", "body", "notifications"],
                "properties": {
                    "type": {"type": "string", "description": "lowercase concept kind, e.g. memory, reminder, person, place, idea"},
                    "title": {"type": "string"},
                    "description": {"type": "string", "description": "single sentence"},
                    "tags": {"type": "array", "items": {"type": "string"}},
                    "body": {"type": "string", "description": "markdown body; structural markdown preferred"},
                    "notifications": {
                        "type": "array",
                        "description": "reminders worth surfacing; empty when nothing should be scheduled",
                        "items": {
                            "type": "object",
                            "additionalProperties": False,
                            "required": ["at", "title", "body"],
                            "properties": {
                                "at": {"type": "string", "description": "ISO 8601 local datetime with offset"},
                                "title": {"type": "string"},
                                "body": {"type": "string"},
                            },
                        },
                    },
                },
            },
        },
        "log_entry": {"type": "string", "description": "one changelog line for log.md"},
    },
}

GENERATION_INSTRUCTIONS = """\
You maintain Ben's personal memory store, an OKF v0.2 bundle of markdown concepts.
Given a capture (voice-note transcript, photo, and/or text), produce one or more concept
files. Usually one file; split only when the capture clearly contains independent memories.

- `type`: short lowercase kind (memory, reminder, person, place, idea, ...). Reuse existing
  types from the index when they fit.
- `body`: faithful, well-structured markdown. Keep Ben's meaning; don't invent facts.
- `notifications`: if the capture implies something Ben should be reminded of (an event,
  a deadline, a follow-up, medication, a promise made), schedule notification(s) at
  sensible local times (e.g. morning of the day, or shortly before a timed event).
  If nothing needs remembering later, return an empty list. Times must be ISO 8601 with
  the local UTC offset, and must be in the future relative to the current time given.
- `log_entry`: one concise past-tense line describing what was added.
- Cross-link: when a new memory relates to existing concepts listed in the index
  (same person, place, project, or follow-up), link them inline or under a
  `## Related` heading using bundle-absolute markdown links, e.g.
  `[Lunch with Sarah](/memories/2026-08-11-lunch-with-sarah.md)`. Only link concepts
  that actually appear in the index, and only when the connection is real — these
  links form the memory web.
"""


def generate_memory(
    transcript: str | None,
    text_note: str | None,
    image: tuple[bytes, str] | None,
    index_md: str,
    source_rel_path: str | None,
) -> dict:
    now = dt.datetime.now(ZoneInfo(config.TIMEZONE))
    parts: list[dict] = []
    prompt = f"Current local time: {now.isoformat()} ({config.TIMEZONE})\n\n"
    prompt += f"Bundle index (existing memories):\n{index_md}\n\n"
    if transcript:
        prompt += f"Voice-note transcript:\n{transcript}\n\n"
    if text_note:
        prompt += f"Typed note:\n{text_note}\n\n"
    if image:
        prompt += "A photo is attached; describe what matters about it as part of the memory.\n"
    parts.append({"type": "input_text", "text": prompt})
    if image:
        data, mime = image
        parts.append({
            "type": "input_image",
            "image_url": f"data:{mime};base64,{base64.b64encode(data).decode()}",
        })

    resp = client().responses.create(
        model=config.GENERATION_MODEL,
        instructions=GENERATION_INSTRUCTIONS,
        input=[{"role": "user", "content": parts}],
        text={"format": {"type": "json_schema", "name": "okf_memory", "strict": True,
                          "schema": MEMORY_SCHEMA}},
    )
    result = json.loads(resp.output_text)
    if source_rel_path:
        for f in result["files"]:
            f["source"] = source_rel_path
    return result


ANSWER_INSTRUCTIONS = """\
You answer questions about Ben's personal memory store (OKF markdown concepts, provided
in full). Answer in a natural spoken register — the reply will be read aloud by TTS.
Be concise and direct; mention which memory the answer comes from when helpful.
If the memories don't contain the answer, say so plainly.
"""


def answer_query(question: str, concepts: list[dict]) -> str:
    corpus = "\n\n---\n\n".join(
        f"[{c['path']}]\n{json.dumps(c['frontmatter'], default=str)}\n{c['body']}" for c in concepts
    ) or "(the memory store is empty)"
    now = dt.datetime.now(ZoneInfo(config.TIMEZONE))
    resp = client().responses.create(
        model=config.GENERATION_MODEL,
        instructions=ANSWER_INSTRUCTIONS,
        input=f"Current local time: {now.isoformat()}\n\nMemory store:\n{corpus}\n\nQuestion: {question}",
    )
    return resp.output_text.strip()


def tts(text: str) -> bytes:
    resp = client().audio.speech.create(
        model=config.TTS_MODEL,
        voice=config.TTS_VOICE,
        input=text,
        response_format="mp3",
    )
    return resp.content
