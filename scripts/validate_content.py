#!/usr/bin/env python3
"""Validate packaged question/lesson bank structure before shipping."""
import json
from pathlib import Path
p=Path(__file__).resolve().parents[1]/'assets/review_content.json'
d=json.loads(p.read_text(encoding='utf-8'))
subjects=d['subjects']; questions=d['questions']; lessons=d['lessons']
ids={s['id'] for s in subjects}
assert len(ids)==len(subjects), 'Duplicate subject IDs'
assert len({q['id'] for q in questions})==len(questions), 'Duplicate question IDs'
for q in questions:
    assert q['subjectId'] in ids, f'Unknown subject: {q}'
    assert isinstance(q['options'],list) and len(q['options'])>=2
    assert isinstance(q['correctIndex'],int) and 0<=q['correctIndex']<len(q['options'])
    assert q['prompt'].strip() and q['explanation'].strip()
    assert q['levels'] and set(q['levels']) <= {'Professional','Subprofessional'}
for lesson in lessons:
    assert lesson['subjectId'] in ids
    assert lesson['body'].strip()
print(f'PASS: {len(subjects)} subjects, {len(lessons)} lessons, {len(questions)} sample questions')
