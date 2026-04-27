# TypeScript — code completeness reference shape

Resolved when `PROJECT-KNOWLEDGE.md → LANGUAGE = typescript`. Idiomatic
TypeScript with ERROR_WRAP form `throw new XError("context", { cause: err })`.

## Reference scenario — `Service.get(itemId)` retrieves a domain item

```typescript
async get(itemId: string): Promise<Item> {
  let item: Item | null;
  try {
    item = await this.repo.findById(itemId);
  } catch (err) {
    throw new ServiceError(`get item ${itemId}`, { cause: err });
  }
  if (item === null) {
    throw new NotFoundError(`get item ${itemId}: not found`);
  }
  return item;
}
```

Invariants illustrated:
1. Full body — no `// TODO` or stub.
2. ERROR_WRAP — `Error` constructor with `{ cause }` (Node 16+/ES2022).
3. Explicit return type — `Promise<Item>`; param `string`; intermediate `Item | null`.
4. No truncation — try/catch + null check + happy path.
