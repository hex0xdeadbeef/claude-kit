# Python — code completeness reference shape

Resolved when `PROJECT-KNOWLEDGE.md → LANGUAGE = python`. Idiomatic Python 3.10+
with ERROR_WRAP form `raise XError("context") from err`.

## Reference scenario — `Service.get(item_id)` retrieves a domain item

```python
def get(self, item_id: str) -> Item:
    try:
        item = self._repo.find_by_id(item_id)
    except RepoError as err:
        raise ServiceError(f"get item {item_id}") from err
    if item is None:
        raise NotFoundError(f"get item {item_id}: not found")
    return item
```

Invariants illustrated:
1. Full body — no `pass` or `...`.
2. ERROR_WRAP — `raise XError(...) from err` for chaining.
3. Type hints — `item_id: str` and `-> Item`.
4. No truncation — repo error, not-found, success all explicit.
