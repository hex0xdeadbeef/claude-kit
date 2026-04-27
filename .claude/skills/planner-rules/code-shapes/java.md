# Java — code completeness reference shape

Resolved when `PROJECT-KNOWLEDGE.md → LANGUAGE = java`. Idiomatic Java 17+ with
ERROR_WRAP form `throw new XException("context", err)` (Throwable cause arg).

## Reference scenario — `Service.get(itemId)` retrieves a domain item

```java
public Item get(String itemId) {
    Item item;
    try {
        item = repo.findById(itemId);
    } catch (RepoException err) {
        throw new ServiceException("get item " + itemId, err);
    }
    if (item == null) {
        throw new NotFoundException("get item " + itemId + ": not found");
    }
    return item;
}
```

Invariants illustrated:
1. Full body — no `// TODO` stubs, no `throw new UnsupportedOperationException`.
2. ERROR_WRAP — `new ServiceException(message, cause)` chains via `Throwable` arg.
3. Explicit types — `String` param, `Item` return, no `var` left ambiguous on returns.
4. No truncation — repo failure, null check, success path all explicit.
