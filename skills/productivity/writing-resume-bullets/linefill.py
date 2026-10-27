#!/usr/bin/env python3
"""Report bullets whose last line is under-filled or that run past 2 lines.

usage: linefill.py FILE.pdf [min_fill=0.90]
Needs poppler's pdftotext. A bullet is a line starting with a bullet glyph;
following lines indented past the glyph are its continuation.
"""
import re, subprocess, sys
from collections import defaultdict

BULLETS = {"•", "∙", "◦", "·"}


def lines(pdf):
    html = subprocess.run(["pdftotext", "-bbox-layout", pdf, "-"],
                          capture_output=True, text=True, check=True).stdout
    for p, page in enumerate(html.split("<page ")[1:], 1):
        for m in re.finditer(r'<line xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)"[^>]*>(.*?)</line>', page, re.S):
            words = re.findall(r">([^<]*)</word>", m.group(4))
            if words:
                yield p, float(m.group(1)), float(m.group(2)), float(m.group(3)), words


def bullets(pdf):
    out, cur, edge = [], None, defaultdict(float)
    for p, x0, y, x1, words in lines(pdf):
        edge[p] = max(edge[p], x1)
        if words[0] in BULLETS:
            cur = {"page": p, "x": x0, "rows": [(x1, " ".join(words[1:]))]}
            out.append(cur)
        elif cur and cur["page"] == p and x0 > cur["x"] and len(cur["rows"]) < 6:
            cur["rows"].append((x1, " ".join(words)))
        else:
            cur = None
    return out, edge


def main(pdf, min_fill=0.90):
    bs, edge = bullets(pdf)  # edge: page's right text margin (widest line)
    bad = 0
    for b in bs:
        width = edge[b["page"]] - b["x"]
        fill = (b["rows"][-1][0] - b["x"]) / width
        n = len(b["rows"])
        if n > 2 or fill < min_fill:
            bad += 1
            print(f"p{b['page']} lines={n} fill={fill:.0%}  {b['rows'][0][1][:70]}")
    print(f"{len(bs)} bullets, {bad} flagged")
    return bad


if __name__ == "__main__":
    sys.exit(1 if main(sys.argv[1], *map(float, sys.argv[2:])) else 0)
