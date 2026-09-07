---
name: expert-research-access
description: Read paywalled papers (IEEE, Elsevier, Springer, Wiley, ACS, JSTOR, PMC, SciFinder) through the research-gateway MCP server using institutional SSO. Use when a paper, DOI, or citation is behind a paywall, or when the user asks to search a publisher portal directly.
---

The `research-gateway` MCP server fetches full text through the user's
university login. Tools: `list_portals`, `check_session`,
`authenticate_portal`, `search_papers`, `fetch_paper`,
`configure_institution`.

## Order of operations

1. **Try the open web first.** arXiv, PMC, the author's page, or an
   institutional repository. If the PDF is free, this skill is wasted effort.
2. `check_session(portal_key)` before any fetch. Sessions expire on the
   institution's policy (8–24h), and an expired one fails as "access denied",
   not as "logged out".
3. `authenticate_portal(portal_key)` if the session is dead. **This opens a
   real browser window and blocks until the user finishes SSO.** Tell them it
   is opening and what to do, then wait — don't fire it speculatively or
   in parallel across portals.
4. `fetch_paper(portal_key, doi=...)` — DOI is more reliable than `url`.
   `search_papers(portal_key, query, max_results)` when you only have a title
   or topic.

## Picking the portal

Route by publisher, not by guess: `ieee` (IEEE/IET), `elsevier`
(ScienceDirect), `springer` (Springer + Nature), `wiley`, `acs`, `jstor`,
`pmc` (open, no login needed), `scifinder` (CAS). A DOI prefix usually
settles it — `10.1109` → ieee, `10.1016` → elsevier, `10.1007` → springer,
`10.1002` → wiley, `10.1021` → acs.

## First run on a new machine

`configure_institution(name="University of Waterloo", wayf_name="University of
Waterloo")` — the WAYF name must match the entry in the publisher's
institution dropdown, so if login lands on a "select your institution" page
and stalls, that string is wrong.

## Failure modes

| Symptom | Cause |
|---------|-------|
| "Access denied" | Session expired → re-authenticate |
| Empty text, no error | JS-rendered page → retry with the PDF URL |
| Login page never advances | `wayf_name` doesn't match the dropdown entry |
| Server missing from tools | `research-gateway` not on PATH → `~/Documents/Desktop/nixos/rebuild.sh` |

## Handling the text

`fetch_paper` returns up to ~100k chars of extracted text. Quote and cite
from it; don't paste the whole body back to the user. If the user is building
notes, the vault convention (one idea per note, bare titles) applies to what
you write from it.

Never ask the user for their password — the browser handles credentials, the
server only ever sees session cookies.
