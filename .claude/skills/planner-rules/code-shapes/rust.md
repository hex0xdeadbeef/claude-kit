# Rust — code completeness reference shape

Resolved when `PROJECT-KNOWLEDGE.md → LANGUAGE = rust`. Idiomatic Rust with
ERROR_WRAP form via `thiserror`-style enum variants carrying `#[source]`.

## Reference scenario — `Service::get(item_id)` retrieves a domain item

```rust
pub async fn get(&self, item_id: &str) -> Result<Item, ServiceError> {
    let item = self.repo.find_by_id(item_id).await
        .map_err(|err| ServiceError::Repo {
            ctx: format!("get item {item_id}"),
            source: err,
        })?;
    item.ok_or_else(|| ServiceError::NotFound {
        ctx: format!("get item {item_id}"),
    })
}
```

Invariants illustrated:
1. Full body — no `unimplemented!()` or `todo!()`.
2. ERROR_WRAP — `map_err` attaches context to every error path; `#[source]` chains.
3. Explicit types — `&str` param, `Result<Item, ServiceError>` return, no inferred `_`.
4. No truncation — `?` on repo error, `ok_or_else` on `None`, return on `Some`.
