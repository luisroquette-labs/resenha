---
name: delete-comment
description: Audit Resenha code comments, preserve decisions in ADRs, and lower the per-file comment ratchet.
---

# Delete comments

1. Read tracked first-party source and configuration comments with nearby code. Classify each as tautology, stale, excuse, or decision record. Keep licensed vendor files, the generated Xcode project, and required tool directives intact.
2. Delete tautologies and stale comments. Delete excuses and file a specific issue for the underlying implementation. Move non-obvious decisions to `docs/adr/` with context and consequences.
3. Lower `Tools/comment-baseline.json` for each cleaned file and run `python3 Tools/check-comments.py`. A new file starts with an allowance of zero; another file's deletion cannot offset an increase.
4. Run targeted checks, review the diff, then use the project's canonical local preflight once on the final SHA. Deliver through one PR.
5. Report removed comment-only lines, remaining debt, vendor exclusions, issues, ADRs, and final-environment proof still pending.
