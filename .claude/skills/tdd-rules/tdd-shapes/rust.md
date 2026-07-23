# Rust — TDD reference shape

Resolved when `.claude/PROJECT-KNOWLEDGE.md → LANGUAGE = rust`. Idiomatic Rust with
`#[test]`, `assert_eq!`, `mockall`-style mocks, parameterised via `rstest`.

## Reference scenario — `Service::get(item_id)` — 3 cycles Red-Green-Refactor

### Cycle 1: happy path

**RED** — `cargo test` must fail here: `Service::get` does not exist yet.
```rust
#[tokio::test]
async fn service_get_returns_item_when_found() {
    let mut repo = MockRepository::new();
    repo.expect_find_by_id()
        .with(eq("123"))
        .returning(|_| Ok(Some(Item { id: "123".into(), name: "Test".into() })));
    let svc = Service::new(repo);

    let item = svc.get("123").await.unwrap();

    assert_eq!(item.id, "123");
    assert_eq!(item.name, "Test");
}
```

**GREEN** — `cargo test` now passes (intentionally panicky — refined in cycle 2).
```rust
pub struct Service<R: Repository> { repo: R }

impl<R: Repository> Service<R> {
    pub fn new(repo: R) -> Self { Self { repo } }

    pub async fn get(&self, item_id: &str) -> Result<Item, ServiceError> {
        Ok(self.repo.find_by_id(item_id).await.unwrap().unwrap())
    }
}
```

### Cycle 2: not-found error

**RED** — `cargo test` must fail here: the current GREEN panics on `None`.
```rust
#[tokio::test]
async fn service_get_returns_not_found_when_missing() {
    let mut repo = MockRepository::new();
    repo.expect_find_by_id()
        .with(eq("999"))
        .returning(|_| Ok(None));
    let svc = Service::new(repo);

    let err = svc.get("999").await.unwrap_err();

    assert!(matches!(err, ServiceError::NotFound { .. }));
    assert!(format!("{err}").contains("get item 999"));
}
```

**GREEN**:
```rust
#[derive(thiserror::Error, Debug)]
pub enum ServiceError {
    #[error("get item {item_id}: not found")]
    NotFound { item_id: String },
    #[error("get item {item_id}")]
    Repo { item_id: String, #[source] source: RepoError },
}

impl<R: Repository> Service<R> {
    /// Returns the item stored under `item_id`. Returns `ServiceError::NotFound` when no
    /// such item exists, and `ServiceError::Repo` — carrying the item id and the underlying
    /// repository failure as its `#[source]` — so callers can attribute the failure without
    /// inspecting the repository layer.
    pub async fn get(&self, item_id: &str) -> Result<Item, ServiceError> {
        let item = self.repo.find_by_id(item_id).await
            .map_err(|err| ServiceError::Repo {
                item_id: item_id.to_string(), source: err,
            })?;
        item.ok_or_else(|| ServiceError::NotFound {
            item_id: item_id.to_string(),
        })
    }
}
```

Note the doc comment on the final `get`: it states what the function returns and the
error contract callers rely on. It says nothing about the TDD cycle that produced it —
per `coder-rules/SKILL.md` § Comment Policy, comments describe the code, never the
process. Cycle status belongs in this prose, not in the code.

### Cycle 3: repo error wrapping (rstest parameterised)

**RED** (incremental — add ONE case per cycle) — this case already passes: the repo-error
wrapping landed in the cycle 2 GREEN, so the REFACTOR step follows directly.
```rust
#[rstest]
#[case(RepoError::Connection("refused".into()), "get item 123")]
#[tokio::test]
async fn service_get_wraps_repo_errors(#[case] repo_err: RepoError, #[case] expected_msg: &str) {
    let mut repo = MockRepository::new();
    repo.expect_find_by_id()
        .with(eq("123"))
        .returning(move |_| Err(repo_err.clone()));
    let svc = Service::new(repo);

    let err = svc.get("123").await.unwrap_err();

    assert!(matches!(err, ServiceError::Repo { .. }));
    assert!(format!("{err}").contains(expected_msg));
    use std::error::Error;
    assert!(err.source().is_some());
}
```

**REFACTOR** — extract repo-error mapping if `map_err` repeats; all 3 cycles still pass:
```rust
fn wrap_repo_err(item_id: &str) -> impl Fn(RepoError) -> ServiceError + '_ {
    move |source| ServiceError::Repo { item_id: item_id.to_string(), source }
}
```

Invariants illustrated:
1. RED shown first in every cycle.
2. Test names descriptive (`service_get_returns_not_found_when_missing`).
3. All 3 paths: happy / not-found / repo-error-wrap with `#[source]` chain.
