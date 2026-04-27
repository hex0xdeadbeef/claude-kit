# Python — TDD reference shape

Resolved when `PROJECT-KNOWLEDGE.md → LANGUAGE = python`. Idiomatic Python 3.10+
with pytest, `unittest.mock`, `pytest.mark.parametrize`.

## Reference scenario — `Service.get(item_id)` — 3 cycles Red-Green-Refactor

### Cycle 1: happy path

**RED**:
```python
def test_service_get_returns_item_when_found():
    repo = MagicMock()
    repo.find_by_id.return_value = Item(id="123", name="Test")
    service = Service(repo)

    item = service.get("123")

    assert item.id == "123"
    assert item.name == "Test"
    repo.find_by_id.assert_called_once_with("123")
# Run: pytest -k test_service_get_returns_item_when_found → FAIL (Service.get does not exist).
```

**GREEN**:
```python
class Service:
    def __init__(self, repo: Repository) -> None:
        self._repo = repo

    def get(self, item_id: str) -> Item:
        return self._repo.find_by_id(item_id)
# Run: pytest → PASS.
```

**REFACTOR**: none needed.

### Cycle 2: not-found error

**RED**:
```python
def test_service_get_raises_not_found_when_missing():
    repo = MagicMock()
    repo.find_by_id.return_value = None
    service = Service(repo)

    with pytest.raises(NotFoundError, match="get item 999"):
        service.get("999")
# Run: pytest → FAIL (returns None silently).
```

**GREEN**:
```python
class NotFoundError(Exception): pass

class Service:
    def __init__(self, repo: Repository) -> None:
        self._repo = repo

    def get(self, item_id: str) -> Item:
        item = self._repo.find_by_id(item_id)
        if item is None:
            raise NotFoundError(f"get item {item_id}: not found")
        return item
```

### Cycle 3: repo error wrapping (parametrised)

**RED**:
```python
@pytest.mark.parametrize("repo_err,expected_in_message", [
    (RepoError("connection refused"), "get item 123"),
])
def test_service_get_wraps_repo_errors(repo_err, expected_in_message):
    repo = MagicMock()
    repo.find_by_id.side_effect = repo_err
    service = Service(repo)

    with pytest.raises(ServiceError) as exc_info:
        service.get("123")
    assert expected_in_message in str(exc_info.value)
    assert exc_info.value.__cause__ is repo_err
# FAIL — repo error propagated unwrapped.
```

**GREEN**:
```python
class ServiceError(Exception): pass

class Service:
    def __init__(self, repo: Repository) -> None:
        self._repo = repo

    def get(self, item_id: str) -> Item:
        try:
            item = self._repo.find_by_id(item_id)
        except RepoError as err:
            raise ServiceError(f"get item {item_id}") from err
        if item is None:
            raise NotFoundError(f"get item {item_id}: not found")
        return item
# All 3 cycles PASS.
```

Invariants illustrated:
1. RED shown first in every cycle.
2. Test names descriptive (`test_service_get_raises_not_found_when_missing`).
3. All 3 paths: happy / not-found / repo-error-wrap. Parametrize case added incrementally.