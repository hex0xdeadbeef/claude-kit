# Java — TDD reference shape

Resolved when `PROJECT-KNOWLEDGE.md → LANGUAGE = java`. Idiomatic Java 17+ with
JUnit 5 (`@Test`, `assertEquals`, `assertThrows`), Mockito, `@ParameterizedTest`.

## Reference scenario — `Service.get(itemId)` — 3 cycles Red-Green-Refactor

### Cycle 1: happy path

**RED**:
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
// Run: mvn test -Dtest=ServiceTest#getReturnsItemWhenFound → FAIL (Service.get does not exist).
```

**GREEN**:
```java
public class Service {
    private final Repository repo;
    public Service(Repository repo) { this.repo = repo; }

    public Item get(String itemId) {
        return repo.findById(itemId);
    }
}
// Run: mvn test → PASS.
```

**REFACTOR**: none needed.

### Cycle 2: not-found error

**RED**:
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
// FAIL — returns null silently.
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

**RED**:
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
// FAIL — repo error propagated unwrapped.
```

**GREEN**:
```java
public class ServiceException extends RuntimeException {
    public ServiceException(String message, Throwable cause) { super(message, cause); }
}

public class Service {
    private final Repository repo;
    public Service(Repository repo) { this.repo = repo; }

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
// All 3 cycles PASS.
```

Invariants illustrated:
1. RED shown first in every cycle with `// FAIL` annotation.
2. Test names descriptive (`getReturnsItemWhenFound`, `getThrowsNotFoundWhenMissing`).
3. All 3 paths: happy / not-found / repo-error-wrap via `Throwable` cause.