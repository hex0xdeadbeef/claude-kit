# TypeScript — TDD reference shape

Resolved when `.claude/PROJECT-KNOWLEDGE.md → LANGUAGE = typescript`. Idiomatic TypeScript
with Jest/Vitest (`describe`/`it`/`expect`), `jest.fn()` mocks, `it.each` for table-driven.

## Reference scenario — `Service.get(itemId)` — 3 cycles Red-Green-Refactor

### Cycle 1: happy path

**RED** — `npx jest --testNamePattern 'returns item when found'` must fail here: `Service.get` does not exist yet.
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
```

**GREEN** — `npx jest` now passes.
```typescript
class Service {
  constructor(private readonly repo: Repository) {}

  async get(itemId: string): Promise<Item> {
    return this.repo.findById(itemId);
  }
}
```

**REFACTOR**: none needed.

### Cycle 2: not-found error

**RED** — `npx jest` must fail here: `get` returns `null` silently.
```typescript
it('throws NotFoundError when item missing', async () => {
  const repo = { findById: jest.fn().mockResolvedValue(null) };
  const svc = new Service(repo);

  await expect(svc.get('999')).rejects.toThrow(/get item 999/);
});
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

**RED** — `npx jest` must fail here: the repository error is propagated unwrapped.
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
```

**GREEN** — all 3 cycles pass.
```typescript
class ServiceError extends Error {
  constructor(message: string, options: { cause?: Error } = {}) {
    super(message);
    if (options.cause) (this as any).cause = options.cause;
  }
}

class Service {
  constructor(private readonly repo: Repository) {}

  /**
   * Returns the item stored under `itemId`. Throws `NotFoundError` when no such item
   * exists, and throws `ServiceError` wrapping any repository failure with the item id
   * so callers can attribute the failure without inspecting the repository layer.
   */
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
```

Note the doc comment on the final `get`: it states what the function returns and the
error contract callers rely on. It says nothing about the TDD cycle that produced it —
per `coder-rules/SKILL.md` § Comment Policy, comments describe the code, never the
process. Cycle status belongs in this prose, not in the code.

Invariants illustrated:
1. RED shown first in every cycle.
2. Test names descriptive (`returns item when found`, `throws NotFoundError when item missing`).
3. All 3 paths: happy / not-found / repo-error-wrap.