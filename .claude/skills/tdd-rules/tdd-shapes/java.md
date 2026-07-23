# Java — TDD reference shape

Resolved when `PROJECT-KNOWLEDGE.md → LANGUAGE = java`. Idiomatic Java 17+ with
JUnit 5 (`@Test`, `assertEquals`, `assertThrows`), Mockito, `@ParameterizedTest`.

## Reference scenario — `Service.get(itemId)` — 3 cycles Red-Green-Refactor

### Cycle 1: happy path

**RED** — `mvn test -Dtest=ServiceTest#getReturnsItemWhenFound` must fail here: `Service.get` does not exist yet.
```java
class ServiceTest {
    @Test
    void getReturnsItemWhenFound() {
        Repository repo = mock(Repository.class);
        when(repo.findById("123")).thenReturn(new Item("123", "Test"));
        Service svc = new Service(repo);

        Item item = svc.get("123");

        assertEquals("123", item.id());
        assertEquals("Test", item.name());
        verify(repo).findById("123");
    }
}
```

**GREEN** — `mvn test` now passes.
```java
public class Service {
    private final Repository repo;
    public Service(Repository repo) { this.repo = repo; }

    public Item get(String itemId) {
        return repo.findById(itemId);
    }
}
```

**REFACTOR**: none needed.

### Cycle 2: not-found error

**RED** — `mvn test` must fail here: `get` returns `null` silently.
```java
@Test
void getThrowsNotFoundWhenMissing() {
    Repository repo = mock(Repository.class);
    when(repo.findById("999")).thenReturn(null);
    Service svc = new Service(repo);

    NotFoundException err = assertThrows(NotFoundException.class,
        () -> svc.get("999"));
    assertTrue(err.getMessage().contains("get item 999"));
}
```

**GREEN**:
```java
public class NotFoundException extends RuntimeException {
    public NotFoundException(String message) { super(message); }
}

public class Service {
    private final Repository repo;
    public Service(Repository repo) { this.repo = repo; }

    public Item get(String itemId) {
        Item item = repo.findById(itemId);
        if (item == null) {
            throw new NotFoundException("get item " + itemId + ": not found");
        }
        return item;
    }
}
```

### Cycle 3: repo error wrapping (@ParameterizedTest)

**RED** — `mvn test` must fail here: the repository error is propagated unwrapped.
```java
@ParameterizedTest
@MethodSource("repoErrorCases")
void getWrapsRepoErrors(RepoException repoErr, String expectedMsg) {
    Repository repo = mock(Repository.class);
    when(repo.findById("123")).thenThrow(repoErr);
    Service svc = new Service(repo);

    ServiceException err = assertThrows(ServiceException.class,
        () -> svc.get("123"));
    assertTrue(err.getMessage().contains(expectedMsg));
    assertSame(repoErr, err.getCause());
}

static Stream<Arguments> repoErrorCases() {
    return Stream.of(
        Arguments.of(new RepoException("connection refused"), "get item 123")
    );
}
```

**GREEN** — all 3 cycles pass.
```java
public class ServiceException extends RuntimeException {
    public ServiceException(String message, Throwable cause) { super(message, cause); }
}

public class Service {
    private final Repository repo;
    public Service(Repository repo) { this.repo = repo; }

    /**
     * Returns the item stored under {@code itemId}.
     *
     * @throws NotFoundException when no such item exists
     * @throws ServiceException  wrapping any {@link RepoException}, tagged with the
     *                           item id so callers can attribute the failure without
     *                           inspecting the repository layer
     */
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
}
```

Note the Javadoc on the final `get`: it states what the method returns and the error
contract callers rely on. It says nothing about the TDD cycle that produced it —
per `coder-rules/SKILL.md` § Comment Policy, comments describe the code, never the
process. Cycle status belongs in this prose, not in the code.

Invariants illustrated:
1. RED shown first in every cycle.
2. Test names descriptive (`getReturnsItemWhenFound`, `getThrowsNotFoundWhenMissing`).
3. All 3 paths: happy / not-found / repo-error-wrap via `Throwable` cause.