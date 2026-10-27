# ClauseDesk delivery milestones

## Milestone 1 — Reviewable facts

Deliver a runnable, original Rails/React application with fictional data:

- Workspace-scoped sign-in, reviewer/viewer permissions.
- Bounded text-PDF and TXT intake with original extracted text preserved.
- Six fields, page-bound evidence and unresolved missing/ambiguous values.
- Explainable corrections and omissions, approval, immutable approved records.
- CSV export, actor-attributed history and stale-edit conflict protection.
- Responsive interface, synthetic samples, repeatable setup and CI.

Completion evidence: backend integration/model tests, a real browser journey through approval/export, desktop/mobile screenshots, TypeScript production build and static security check. Consult the repository's CI run for remote validation; local checks and remote CI are separate.

## Milestone 2 — Evaluated AI extraction

- Add a provider interface with strict output schemas and explicit live/replay modes.
- Preserve exact source citations, reject unsupported references and expose uncertainty.
- Run fixed synthetic documents through an evaluation harness; report field accuracy and citation validity with dataset limitations.
- Add durable background jobs, processing status, retry bounds and provider-cost accounting.

Implemented: optional OpenAI Responses adapter, strict schema, literal citation checks, withheld uncertainty, audit provenance, per-document attempt bound, synchronous request timeout and token-count records. Offline hand-authored fixtures and mocked-provider tests cover failure and conflict paths.

Pending: actual live-provider evaluation with an operator-selected model/key; durable background jobs/retries and dollar-cost accounting. Offline fixture pass rates are not model accuracy.

## Milestone 3 — Team operations

- Invitations, password reset, better session management.
- New document revisions and explicit supersession; never silently rewrite approved records.
- Real deployment with shared rate limiting, storage/retention policy, upload limits, monitoring and operational backups.
- PDF visual preview and OCR only after acceptance tests exist for those paths.

No fabricated commit dates, clients, outcomes or accuracy claims. Each increment is committed when actually built and tested.
