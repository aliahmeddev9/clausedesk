# ClauseDesk portfolio showcase

## Project description

ClauseDesk is an original Rails 8.1, React, TypeScript and PostgreSQL application for reviewing contract facts alongside their source evidence. It demonstrates tenant-scoped authorization, document intake, explicit uncertainty, review/audit workflows, optimistic concurrency, safe exports and an optional schema-constrained AI integration.

Hosted demonstration: https://a3-clausedesk.fly.dev — normally stopped, available after operator start. Public requests do not wake it. Hosted isolation, review, approval and CSV export verified October 27, 2026; live-provider evaluation remains pending. See [operator instructions](DEPLOYMENT.md) before scheduling a walkthrough.

## A short walkthrough

1. Open the app and choose **Try a private demo** when enabled. This creates an isolated workspace, without sharing a password.
2. Select the fictional Northstar agreement. Show the source and five labeled values; the governing-law field is intentionally absent.
3. Accept supported facts. Explain and omit the missing field. Show that approval stays disabled until every field is reviewed.
4. Approve, export the CSV, and inspect the actor-attributed activity history.
5. Explain the optional non-demo AI flow: explicit source transfer, strict schema, literal citation validation, revision checks and mandatory human review. Present this as an implemented adapter with mocked-provider verification until live evaluation is recorded.

## Evidence and honest limits

- Source and CI: https://github.com/aliahmeddev9/clausedesk
- Desktop/mobile screenshots: `docs/images/`.
- Tests cover authorization, stale changes, approval locks, citation failures and demo isolation.
- Synthetic data and original code; no client delivery or measured business savings are claimed.
- This is a portfolio demonstration, not legal advice or a production legal-review platform.
- Hosted URL and live model results remain pending. Do not advertise either as verified until evidence is added.

For a relevant Upwork proposal: “I built ClauseDesk, a Rails/React portfolio application demonstrating evidence-linked document review, tenant isolation, approval controls and an optional structured AI extraction adapter. Its repository includes a runnable demo, tests and an architecture walkthrough.”
