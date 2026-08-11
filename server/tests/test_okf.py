import frontmatter
import pytest

from app.okf import Bundle, OkfError


@pytest.fixture()
def bundle(tmp_path):
    (tmp_path / "index.md").write_text('---\nokf_version: "0.2"\n---\n\n# Ben\'s Memories\n')
    (tmp_path / "log.md").write_text("# Log\n")
    return Bundle(tmp_path, "America/New_York")


def make_meta(**over):
    meta = {
        "type": "memory",
        "title": "Coffee with Sam",
        "description": "Met Sam for coffee downtown.",
        "tags": ["people"],
        "generated": {"by": "recall-agent/test", "at": "2026-08-11T10:00:00-04:00"},
        "status": "stable",
    }
    meta.update(over)
    return meta


def test_write_concept_is_conformant(bundle):
    rel = bundle.write_concept(make_meta(), "# Coffee\n\nMet Sam.")
    post = frontmatter.load(bundle.root / rel)
    assert post.metadata["type"] == "memory"
    assert post.content.startswith("# Coffee")
    assert bundle.validate() == []


def test_type_is_required(bundle):
    with pytest.raises(OkfError):
        bundle.write_concept(make_meta(type=""), "body")


def test_filename_collision_gets_suffix(bundle):
    a = bundle.write_concept(make_meta(), "one")
    b = bundle.write_concept(make_meta(), "two")
    assert a != b


def test_notifications_validated_and_extracted(bundle):
    meta = make_meta(notifications=[
        {"at": "2026-08-14T09:00:00-04:00", "title": "Call Sam", "body": "You said you'd call."}
    ])
    rel = bundle.write_concept(meta, "body")
    notes = bundle.notifications()
    assert len(notes) == 1
    assert notes[0]["memory_path"] == rel
    assert notes[0]["id"]  # auto-assigned uuid
    with pytest.raises(OkfError):
        bundle.write_concept(make_meta(notifications=[{"at": "", "title": "x", "body": "y"}]), "b")


def test_index_regeneration_groups_by_type(bundle):
    bundle.write_concept(make_meta(), "body")
    bundle.write_concept(make_meta(type="reminder", title="Dentist"), "body")
    bundle.regenerate_index()
    index = (bundle.root / "index.md").read_text()
    assert index.startswith('---\nokf_version: "0.2"\n---')
    assert "## Memory" in index and "## Reminder" in index
    assert "[Coffee with Sam]" in index


def test_log_newest_first(bundle):
    bundle.append_log("Added first memory.")
    bundle.append_log("Added second memory.")
    log = (bundle.root / "log.md").read_text()
    assert log.index("second") < log.index("first")
    assert log.startswith("# Log")


def test_malformed_neighbor_tolerated(bundle):
    (bundle.root / "memories" / "bad.md").write_text("no frontmatter at all")
    bundle.write_concept(make_meta(), "body")
    assert len(bundle.list_concepts()) == 1
    assert any("bad.md" in p for p in bundle.validate())
