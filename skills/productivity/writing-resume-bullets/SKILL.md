---
name: writing-resume-bullets
description: Write or rewrite resume, CV, or portfolio bullet points in Google's XYZ form. Use when the user drafts, reviews, or tailors resume bullets.
---

Every bullet is an **XYZ** bullet (Laszlo Bock, Google): _Accomplished **X** as measured by **Y**, by doing **Z**._

- **X**: the result. Lead with a strong past-tense verb (Designed, Cut, Shipped). Use present tense only for active work.
- **Y**: the number that proves X. That can be a %, $, time, count, scale, or a comparison ("of 50 teams", "vs. Yosys default"). If you have both a % and an absolute number, give both.
- **Z**: how you got X. Name the technique and the tools, so the reader sees what you actually did.

Example: _"Resolved 277 CDC violations in the chip-to-host interconnect using SpyGlass, closing timing for tape-in."_ Its parts are X = resolved, Y = 277, Z = SpyGlass.

## Rules

- **Grounded Y.** Take every number from a source: a README, benchmark log, sim result, or the user's own words. If no number exists, ask the user for one or write the bullet as X+Z. Never invent a number.
- **Full lines.** A bullet is exactly one or two lines, and its last line reaches at least ~90% of the width, so it doesn't end in a stub of a few words. A bullet with a short last line either grows (add a sharper Y, or name a tool in Z) or shrinks back to one line. A bullet that runs to a third line gets cut: shorten Z to its most specific noun. Check the rendered PDF, because counting characters is not enough.
- **Results over duties.** A bullet that reads "Responsible for…" or "Worked on…" is written as a duty. Rewrite it as the result.
- **Plain.** End each bullet on a concrete fact. A trailing "-ing" clause like "…, enabling X" or "…, ensuring Y" is usually filler, so cut it. Use "used" rather than "leveraged" and "built" rather than "spearheaded". Leave out words like "comprehensive" and "robust", and don't use em dashes. For a full pass, run /humanizer on the bullets.
- **Tailored.** Pull the job description's keywords into the Z clauses and order bullets by how relevant they are to the role.
- **Proofread.** Check tool names against their official spelling, e.g. Synopsys, cocotb, ngspice.

## Rewriting a set

1. Label each existing bullet with the parts it contains: X, Y, Z.
2. For each part that's missing, find it in the sources above. If you can't find it, write down the question to ask the user.
3. Rewrite the bullet.
4. Render the PDF and look at every bullet. Done when each bullet has X and Z, has Y or an open question for the user, and fills one or two full lines.

Before/after:
- ✗ "Achieved annual business plan commitments"
- ✓ "Contributed to 21% advertiser spend increase by achieving 158% of customer contact targets (80 weekly)"

Sources: Bock, _My Personal Formula for a Winning Resume_ (LinkedIn, 2014); Google Careers resume tips video.
