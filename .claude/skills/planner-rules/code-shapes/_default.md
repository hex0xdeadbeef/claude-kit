# Default code-shape (pseudocode)

Loaded by /planner when `PROJECT-KNOWLEDGE.md → LANGUAGE` is unset OR not one of
{go, python, typescript, rust, java}. Demonstrates the four invariants without
committing to a concrete syntax.

## Reference scenario — `Service.Get(itemId)` retrieves a domain item

```pseudocode
function get(itemId):
    item, err = repo.findById(itemId)
    if err is not None:
        return wrap(err, "get item " + itemId)   # ERROR_WRAP convention
    if item is None:
        return error("get item " + itemId + ": not found")
    return item
```

Notes:
- Full body (no `…` placeholder).
- Error context attached on every error path.
- Both `nil` and error cases handled — no silent drop-through.
- `wrap`/`error` are abstract — the project's ERROR_WRAP slot pins them concretely.
