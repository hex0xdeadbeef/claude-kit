# TypeScript — TDD reference shape

Resolved when `PROJECT-KNOWLEDGE.md → LANGUAGE = typescript`. Idiomatic TypeScript
with Jest/Vitest (`describe`/`it`/`expect`), `jest.fn()` mocks, `it.each` for table-driven.

## Reference scenario — `Service.get(itemId)` — 3 cycles Red-Green-Refactor

### Cycle 1: happy path

**RED**:
```typescript
describe('Service.get', () => {
  it('returns item when found', async () => {
    const repo = { findById: jest.fn().mockResolvedValue({ id: '123', name: 'Test' }) };
    const svc = new Service(repo);

    const item = await svc.get('123');

    expect(item.id).toBe('123');
    expect(item.name).toBe('Test');
    expect(repo.findById).toHaveBeenCalledWith('123');
  });
});
// Run: npx jest --testNamePattern 'returns item when found' → FAIL (Service.get does not exist).
```

**GREEN**:
```typescript
class Service {
  constructor(private readonly repo: Repository) {}

  async get(itemId: string): Promise<Item> {
    return this.repo.findById(itemId);
  }
}
// Run: npx jest → PASS.
```

**REFACTOR**: none needed.

### Cycle 2: not-found error

**RED**:
```typescript
it('throws NotFoundError when item missing', async () => {
  const repo = { findById: jest.fn().mockResolvedValue(null) };
  const svc = new Service(repo);

  await expect(svc.get('999')).rejects.toThrow(/get item 999/);
});
// Run: jest → FAIL (returns null silently).
```

**GREEN**:
```typescript
class NotFoundError extends Error {}

class Service {
  constructor(private readonly repo: Repository) {}

  async get(itemId: string): Promise<Item> {
    const item = await this.repo.findById(itemId);
    if (item === null) {
      throw new NotFoundError(`get item ${itemId}: not found`);
    }
    return item;
  }
}
```

### Cycle 3: repo error wrapping (it.each)

**RED**:
```typescript
it.each([
  { repoErr: new Error('connection refused'), expectedMsg: 'get item 123' },
])('wraps repo error: $repoErr.message', async ({ repoErr, expectedMsg }) => {
  const repo = { findById: jest.fn().mockRejectedValue(repoErr) };
  const svc = new Service(repo);

  try {
    await svc.get('123');
    fail('expected throw');
  } catch (err: any) {
    expect(err).toBeInstanceOf(ServiceError);
    expect(err.message).toContain(expectedMsg);
    expect(err.cause).toBe(repoErr);
  }
});
// FAIL — repo error propagated unwrapped.
```

**GREEN**:
```typescript
class ServiceError extends Error {
  constructor(message: string, options: { cause?: Error } = {}) {
    super(message);
    if (options.cause) (this as any).cause = options.cause;
  }
}

class Service {
  constructor(private readonly repo: Repository) {}

  async get(itemId: string): Promise<Item> {
    let item: Item | null;
    try {
      item = await this.repo.findById(itemId);
    } catch (err) {
      throw new ServiceError(`get item ${itemId}`, { cause: err as Error });
    }
    if (item === null) {
      throw new NotFoundError(`get item ${itemId}: not found`);
    }
    return item;
  }
}
// All 3 cycles PASS.
```

Invariants illustrated:
1. RED shown first in every cycle.
2. Test names descriptive (`returns item when found`, `throws NotFoundError when item missing`).
3. All 3 paths: happy / not-found / repo-error-wrap.