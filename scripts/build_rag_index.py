#!/usr/bin/env python3
"""Build and validate PAWLINK's deterministic local RAG index.

The index is lexical by design: it can be generated offline and does not send
the private knowledge base to an embedding provider. The source Markdown stays
authoritative; this file only derives searchable chunks and postings from it.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "assets/ai_logic/knowledge/core_knowledge_base.md"
DEFAULT_OUTPUT = ROOT / "assets/ai_logic/knowledge/rag_index.json"
HEADING_RE = re.compile(r"^(#{2,3})\s+(.+?)\s*$")
ANCHOR_RE = re.compile(r'^<a id="([^"]+)"></a>$')
TAG_RE = re.compile(r"\[([^\]]+)\]")
DOC_RE = re.compile(r"\[Doc-(\d{3})\]")
LINK_RE = re.compile(r"\[([^\]]+)\]\([^)]+\)")
URL_RE = re.compile(r"https?://\S+")
ASCII_WORD_RE = re.compile(r"[a-z0-9][a-z0-9_-]+")
CJK_SPAN_RE = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff]+")
SKIP_TITLES = {"目錄"}
KNOWN_TAGS = {"R", "P", "S", "理論", "規範", "案例", "安全", "共通"}
QUERY_EXPANSIONS = {
    "一直叫": "吠叫 哀鳴",
    "沒有尿": "無尿 排尿 尿道阻塞",
    "尿不出": "無尿 排尿 尿道阻塞",
    "打架": "衝突 攻擊",
    "獨自在家": "獨處 分離困擾",
    "撿到": "拾食 物品",
    "老貓": "高齡貓",
}


def normalize_source(raw: bytes) -> str:
    return raw.decode("utf-8-sig").replace("\r\n", "\n").replace("\r", "\n")


def plain_text(markdown: str) -> str:
    text = LINK_RE.sub(r"\1", markdown)
    text = URL_RE.sub(" ", text)
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"[`*_#>|]", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def terms(text: str) -> set[str]:
    value = plain_text(text).lower()
    found = set(ASCII_WORD_RE.findall(value))
    for span in CJK_SPAN_RE.findall(value):
        for size in (2, 3):
            found.update(span[i : i + size] for i in range(len(span) - size + 1))
    return found


def safety_level(text: str, tags: list[str]) -> str:
    urgent = ("立即", "急診", "危及生命", "呼吸困難", "無尿", "大出血")
    if ("安全" in tags or "S" in tags) and any(word in text for word in urgent):
        return "red_flag"
    if "安全" in tags or "S" in tags:
        return "caution"
    return "normal"


def parse_chunks(source: str, version: str) -> list[dict]:
    lines = source.splitlines()
    sections: list[dict] = []
    pending_anchor = ""
    current: dict | None = None

    for line_number, line in enumerate(lines, 1):
        anchor = ANCHOR_RE.match(line.strip())
        if anchor:
            pending_anchor = anchor.group(1)
            continue
        heading = HEADING_RE.match(line)
        if heading:
            if current:
                current["line_end"] = line_number - 1
                sections.append(current)
            current = {
                "level": len(heading.group(1)),
                "title_raw": heading.group(2),
                "anchor": pending_anchor,
                "line_start": line_number,
                "body": [],
            }
            pending_anchor = ""
        elif current:
            current["body"].append(line)
    if current:
        current["line_end"] = len(lines)
        sections.append(current)

    chunks = []
    used_ids: Counter[str] = Counter()
    for section in sections:
        title_raw = section["title_raw"]
        title = TAG_RE.sub("", title_raw).strip()
        body = "\n".join(section["body"]).strip()
        content = plain_text(body)
        if title in SKIP_TITLES or len(content) < 40:
            continue
        combined = f"{title_raw}\n{body}"
        doc_match = DOC_RE.search(combined)
        document_id = f"doc-{doc_match.group(1)}" if doc_match else "shared"
        raw_id = section["anchor"] or f"{document_id}-{section['line_start']}"
        used_ids[raw_id] += 1
        chunk_id = raw_id if used_ids[raw_id] == 1 else f"{raw_id}-{used_ids[raw_id]}"
        tags = sorted({tag for tag in TAG_RE.findall(combined) if tag in KNOWN_TAGS})
        chunk = {
            "id": chunk_id,
            "document_id": document_id,
            "section_id": section["anchor"] or chunk_id,
            "title": title,
            "heading_level": section["level"],
            "tags": tags,
            "safety_level": safety_level(combined, tags),
            "content": content,
            "source": {
                "path": "assets/ai_logic/knowledge/core_knowledge_base.md",
                "line_start": section["line_start"],
                "line_end": section["line_end"],
            },
            "version": version,
        }
        chunks.append(chunk)
    return chunks


def build_index(source_path: Path, version: str) -> dict:
    source = normalize_source(source_path.read_bytes())
    chunks = parse_chunks(source, version)
    postings: dict[str, list[str]] = defaultdict(list)
    for chunk in chunks:
        searchable = f"{chunk['title']} {' '.join(chunk['tags'])} {chunk['content']}"
        for term in terms(searchable):
            postings[term].append(chunk["id"])
    max_document_frequency = max(4, len(chunks) // 2)
    filtered = {
        term: ids
        for term, ids in sorted(postings.items())
        if len(ids) <= max_document_frequency
    }
    normalized = source.encode("utf-8")
    return {
        "schema_version": 1,
        "knowledge_version": version,
        "index_type": "lexical_cjk_ngram_v1",
        "source": {
            "path": "assets/ai_logic/knowledge/core_knowledge_base.md",
            "sha256": hashlib.sha256(normalized).hexdigest(),
        },
        "stats": {
            "chunk_count": len(chunks),
            "term_count": len(filtered),
            "red_flag_chunk_count": sum(c["safety_level"] == "red_flag" for c in chunks),
            "caution_chunk_count": sum(c["safety_level"] == "caution" for c in chunks),
        },
        "chunks": chunks,
        "inverted_index": filtered,
    }


def serialized(index: dict) -> str:
    return json.dumps(index, ensure_ascii=False, indent=2, sort_keys=False) + "\n"


def validate(index: dict, source_path: Path, version: str) -> None:
    expected = build_index(source_path, version)
    if index != expected:
        raise ValueError("RAG index is stale; run scripts/build_rag_index.py")
    ids = [chunk["id"] for chunk in index["chunks"]]
    if len(ids) != len(set(ids)):
        raise ValueError("duplicate chunk IDs")
    known = set(ids)
    if any(not set(postings) <= known for postings in index["inverted_index"].values()):
        raise ValueError("inverted index contains an unknown chunk ID")
    if not any(chunk["document_id"] == "doc-006" for chunk in index["chunks"]):
        raise ValueError("Doc-006 is missing")


def query(index: dict, text: str, limit: int) -> list[dict]:
    chunk_by_id = {chunk["id"]: chunk for chunk in index["chunks"]}
    scores: Counter[str] = Counter()
    expanded = text + " " + " ".join(
        addition for phrase, addition in QUERY_EXPANSIONS.items() if phrase in text
    )
    query_terms = terms(expanded)
    for term in query_terms:
        postings = index["inverted_index"].get(term, [])
        weight = 1.0 + 1.0 / max(1, len(postings))
        for chunk_id in postings:
            scores[chunk_id] += weight
    for chunk in index["chunks"]:
        title_terms = terms(chunk["title"])
        scores[chunk["id"]] += 2.0 * len(query_terms & title_terms)
        if scores[chunk["id"]] > 0 and "P" in chunk["tags"]:
            scores[chunk["id"]] += 3.5
    return [
        {
            "id": chunk_id,
            "title": chunk_by_id[chunk_id]["title"],
            "safety_level": chunk_by_id[chunk_id]["safety_level"],
            "score": round(score, 3),
        }
        for chunk_id, score in scores.most_common(limit)
        if score > 0
    ]


def version_from_pubspec() -> str:
    pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    match = re.search(r"(?m)^version:\s*([^+\s]+)", pubspec)
    if not match:
        raise ValueError("version is missing from pubspec.yaml")
    return match.group(1)


def smoke_test(index: dict) -> None:
    cases = {
        "貓咪一直在貓砂盆用力但沒有尿": ("doc006-litter", 1),
        "新貓到家和原本的貓打架": ("doc006-multicat", 1),
        "狗狗獨自在家一直叫": ("doc004-separation", 1),
        "狗狗撿到東西會護食": ("doc005-guarding", 2),
        "寵物走失怎麼搜尋": ("doc006-care", 1),
        "高齡貓晚上一直叫": ("doc006-aging", 1),
    }
    failures = []
    for text, (expected, max_rank) in cases.items():
        ids = [item["id"] for item in query(index, text, 5)]
        if expected not in ids[:max_rank]:
            failures.append(
                f"{text}: expected {expected} within rank {max_rank}, got {ids}"
            )
    if failures:
        raise ValueError("retrieval smoke test failed: " + "; ".join(failures))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--query")
    parser.add_argument("--limit", type=int, default=5)
    args = parser.parse_args()
    version = version_from_pubspec()

    if args.check or args.query:
        index = json.loads(args.output.read_text(encoding="utf-8"))
        validate(index, args.source, version)
        smoke_test(index)
        if args.query:
            print(json.dumps(query(index, args.query, args.limit), ensure_ascii=False, indent=2))
        else:
            print(json.dumps(index["stats"], ensure_ascii=False))
        return 0

    index = build_index(args.source, version)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(serialized(index), encoding="utf-8", newline="\n")
    validate(index, args.source, version)
    smoke_test(index)
    print(f"Wrote {args.output.relative_to(ROOT)}: {index['stats']}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
