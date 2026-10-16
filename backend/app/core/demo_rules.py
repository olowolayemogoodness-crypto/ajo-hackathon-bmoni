import hashlib
from pathlib import Path

DEMO_RULES_VERSION = "ajo-demo-rules-1.0.0"
DEMO_RULES_SHA256 = "f429b547a39056b526cb76c33214e80a0b23e73c419a4359dd8470e55ba998de"
DEMO_RULES_PATH = (
    Path(__file__).resolve().parents[3]
    / "docs"
    / "architecture"
    / "circle-rules"
    / "ajo-demo-rules-1.0.0.md"
)


def load_demo_rules() -> str:
    content = DEMO_RULES_PATH.read_bytes().replace(b"\r\n", b"\n")
    if hashlib.sha256(content).hexdigest() != DEMO_RULES_SHA256:
        raise RuntimeError("The pinned local demo rules content has changed")
    return content.decode("utf-8")