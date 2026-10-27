# Extraction evaluation

`test/fixtures/ai/contracts.json` contains three hand-authored synthetic cases: unlabeled prose, contradictory dates, and a forged citation. The offline command feeds these authored outputs through the real provider-response parser and citation validator. All 18 expected field decisions matched on October 26. This tests application behavior; it is **not live model accuracy**, and the outputs were not recorded from a provider.

The live command excludes the intentionally forged provider output and sends the two source fixtures to the configured model. It reports exact field matches and returned usage. Two synthetic documents are too small and narrow to support any general accuracy claim. Real evaluation requires more formats, paraphrases, tables, multilingual inputs and adversarial text, independently annotated by reviewers. Exact matching also penalizes legitimate alternative spans.

Current verified scope: strict schema, explicit uncertainty, incorrect page/quotation/value rejection, incomplete/refused/malformed output handling, review conflicts, roles and tenant boundaries. Network requests to a real provider are pending configuration.
