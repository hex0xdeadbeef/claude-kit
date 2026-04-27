# Default TDD-shape (pseudocode)

Loaded by /coder when `PROJECT-KNOWLEDGE.md → LANGUAGE` is unset OR not one of
`{go, python, typescript, rust, java}`. Demonstrates the three invariants
without committing to a concrete syntax.

## Reference scenario — `Service.get(itemId)` — 3 cycles Red-Green-Refactor

### Cycle 1: happy path

**RED** — failing test first:
```pseudocode
test "service.get returns item when found":
    repo = MockRepo()
    repo.findById("123") -> returns Item(id="123", name="Test")
    service = Service(repo)
    item = service.get("123")
    assert item.id == "123"
    assert item.name == "Test"
# Run project test command. MUST FAIL — Service.get does not exist yet.
```

**GREEN** — minimal implementation:
```pseudocode
class Service:
    constructor(repo): self.repo = repo
    function get(itemId):
        return self.repo.findById(itemId)
# Run test. MUST PASS.
```

**REFACTOR** — none needed for this minimal case.

### Cycle 2: not-found error

**RED**:
```pseudocode
test "service.get raises when item missing":
    repo = MockRepo()
    repo.findById("999") -> returns None
    service = Service(repo)
    assert raises NotFoundError: service.get("999")
# Run test. MUST FAIL — current implementation returns None silently.
```

**GREEN**:
```pseudocode
function get(itemId):
    item = self.repo.findById(itemId)
    if item is None:
        raise NotFoundError("get item " + itemId)
    return item
# Run test. MUST PASS. Cycle 1 still passes.
```

### Cycle 3: repo error wrapping

**RED**:
```pseudocode
test "service.get wraps repo errors":
    repo = MockRepo()
    repo.findById("123") -> raises RepoError("db down")
    service = Service(repo)
    err = capture: service.get("123")
    assert err is ServiceError
    assert err.message contains "get item 123"
    assert err.cause is RepoError
```

**GREEN**:
```pseudocode
function get(itemId):
    try:
        item = self.repo.findById(itemId)
    catch RepoError as err:
        raise ServiceError("get item " + itemId, cause=err)
    if item is None:
        raise NotFoundError("get item " + itemId)
    return item
# Run test. All 3 cycles MUST PASS.
```

Invariants illustrated:
1. RED phase shown FIRST in every cycle, before GREEN.
2. Test names are descriptive (`service.get returns item when found`, not `test1`).
3. All 3 paths covered: happy / not-found / repo-error-wrap.