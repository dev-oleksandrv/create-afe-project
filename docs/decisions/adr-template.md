---
status: proposed
date: YYYY-MM-DD
decision-makers: {who decides}
scope: {stack | architecture | data | security | operations | process}
summary: "In the context of {situation}, facing {concern}, we decided {chosen option} and rejected {alternatives}, to achieve {quality}, accepting {downside}."
supersedes: []
---

# {the decision as a short statement}

## Context and Problem Statement

{Two to five sentences, or a question: the problem, the forces, and the scope of the decision.
Link the requirements and documents involved instead of copying them. Only for a decision that
meets `docs/documentation-rules.md`, section 5; keep the whole record to about one page.}

## Considered Options

* {chosen option}
* {real alternative}

## Decision Outcome

Chosen option: "{chosen option}", because {justification}. {Rules, parameters, and design details
belong in their owner document; link it here instead of listing them.}

Rejected: {each alternative, with the reason in one clause}.

### Consequences

* Good, because {positive consequence}
* Bad, because {negative consequence}

### Confirmation

{The check that verifies the decision: a script, a test, a contract check, or a review step. Or
"Not checked yet:" followed by what will check it and when.}
