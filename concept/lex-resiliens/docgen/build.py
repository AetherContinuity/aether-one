#!/usr/bin/env python3
"""
build.py

Renderoi template_*.md.j2 -tiedoston facts.yaml + formulas.yaml -datalla.
Ei mitaan kasin kirjoitettua lukua paase templaten lapi tarkistamatta -
jos template viittaa muuttujaan jota ei ole namespacessa, Jinja2 kaataa
(StrictUndefined).
"""
from __future__ import annotations
import sys
from datetime import datetime, timezone
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, StrictUndefined

from engine import compute_all, load_facts, FormulaError


def build(template_name: str, output_path: Path, base_dir: Path) -> None:
    namespace = compute_all(base_dir / "facts.yaml", base_dir / "formulas.yaml")
    facts_raw = load_facts(base_dir / "facts.yaml")

    env = Environment(
        loader=FileSystemLoader(str(base_dir)),
        undefined=StrictUndefined,  # kaataa jos template viittaa puuttuvaan muuttujaan
    )
    template = env.get_template(template_name)

    rendered = template.render(
        facts=facts_raw,
        build_time=datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        **namespace,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered, encoding="utf-8")
    print(f"Kirjoitettu: {output_path}")


if __name__ == "__main__":
    base = Path(__file__).parent
    try:
        build("template_lr2030.md.j2", base / "output" / "LR2030_v3.md", base)
    except FormulaError as e:
        print(f"BUILD EPAONNISTUI (facts/formulas-virhe): {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"BUILD EPAONNISTUI ({type(e).__name__}): {e}", file=sys.stderr)
        sys.exit(1)
