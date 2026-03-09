# TDD Examples for Go Backend

## Service TDD — UserService.Create

Full 3-cycle TDD example for a service method.

### Cycle 1: Happy Path

**RED:**
```go
func TestUserService_Create_ValidInput_ReturnsUser(t *testing.T) {
    repo := mocks.NewUserRepository(t)
    svc := NewUserService(repo)

    repo.EXPECT().
        Create(mock.Anything, mock.MatchedBy(func(p CreateUserParams) bool {
            return p.Name == "Alice" && p.Email == "alice@example.com"
        })).
        Return(&User{ID: "usr-123", Name: "Alice", Email: "alice@example.com"}, nil)

    user, err := svc.Create(context.Background(), CreateUserInput{
        Name:  "Alice",
        Email: "alice@example.com",
    })

    require.NoError(t, err)
    assert.Equal(t, "usr-123", user.ID)
    assert.Equal(t, "Alice", user.Name)
}
// Run: go test ./internal/service/... → FAIL (Create method doesn't exist)
```

**GREEN:**
```go
type UserService struct {
    repo UserRepository
}

func NewUserService(repo UserRepository) *UserService {
    return &UserService{repo: repo}
}

func (s *UserService) Create(ctx context.Context, input CreateUserInput) (*User, error) {
    return s.repo.Create(ctx, CreateUserParams{
        Name:  input.Name,
        Email: input.Email,
    })
}
// Run: go test ./internal/service/... → PASS
```

**REFACTOR:** Minimal code — nothing to refactor yet.

### Cycle 2: Validation Error

**RED:**
```go
func TestUserService_Create_EmptyName_ReturnsError(t *testing.T) {
    repo := mocks.NewUserRepository(t)
    svc := NewUserService(repo)

    _, err := svc.Create(context.Background(), CreateUserInput{
        Name:  "",
        Email: "alice@example.com",
    })

    require.Error(t, err)
    assert.True(t, errors.Is(err, ErrInvalidInput))
}
// Run: go test → FAIL (Create doesn't validate, calls repo with empty name)
```

**GREEN:**
```go
var ErrInvalidInput = errors.New("invalid input")

func (s *UserService) Create(ctx context.Context, input CreateUserInput) (*User, error) {
    const op = "UserService.Create"
    if input.Name == "" {
        return nil, fmt.Errorf("%s: name required: %w", op, ErrInvalidInput)
    }
    return s.repo.Create(ctx, CreateUserParams{
        Name:  input.Name,
        Email: input.Email,
    })
}
// Run: go test → PASS
```

**REFACTOR:** Extract validation to method:
```go
func (input CreateUserInput) Validate() error {
    if input.Name == "" {
        return fmt.Errorf("name required: %w", ErrInvalidInput)
    }
    return nil
}

func (s *UserService) Create(ctx context.Context, input CreateUserInput) (*User, error) {
    const op = "UserService.Create"
    if err := input.Validate(); err != nil {
        return nil, fmt.Errorf("%s: %w", op, err)
    }
    return s.repo.Create(ctx, CreateUserParams{Name: input.Name, Email: input.Email})
}
// Run: go test → PASS (refactor preserved behavior)
```

### Cycle 3: Repository Error Propagation

**RED:**
```go
func TestUserService_Create_RepoError_WrapsError(t *testing.T) {
    repo := mocks.NewUserRepository(t)
    svc := NewUserService(repo)

    repoErr := errors.New("connection refused")
    repo.EXPECT().Create(mock.Anything, mock.Anything).Return(nil, repoErr)

    _, err := svc.Create(context.Background(), CreateUserInput{
        Name:  "Alice",
        Email: "alice@example.com",
    })

    require.Error(t, err)
    assert.Contains(t, err.Error(), "UserService.Create")
    assert.True(t, errors.Is(err, repoErr))
}
// Run: go test → FAIL (repo error returned unwrapped)
```

**GREEN:**
```go
func (s *UserService) Create(ctx context.Context, input CreateUserInput) (*User, error) {
    const op = "UserService.Create"
    if err := input.Validate(); err != nil {
        return nil, fmt.Errorf("%s: %w", op, err)
    }
    user, err := s.repo.Create(ctx, CreateUserParams{Name: input.Name, Email: input.Email})
    if err != nil {
        return nil, fmt.Errorf("%s: %w", op, err)
    }
    return user, nil
}
// Run: go test → PASS
```

---

## Repository TDD — UserRepository.FindByID

### Cycle 1: Found

**RED:**
```go
func TestUserRepository_FindByID_Exists_ReturnsUser(t *testing.T) {
    db := setupTestDB(t) // test helper with migration
    repo := NewUserRepository(db)

    // Seed test data
    seedUser(t, db, "usr-1", "Alice")

    user, err := repo.FindByID(context.Background(), "usr-1")
    require.NoError(t, err)
    assert.Equal(t, "Alice", user.Name)
}
```

**GREEN:**
```go
func (r *UserRepository) FindByID(ctx context.Context, id string) (*User, error) {
    const op = "UserRepository.FindByID"
    row := r.db.QueryRowContext(ctx,
        `SELECT id, name, email FROM users WHERE id = $1`, id)

    var u User
    if err := row.Scan(&u.ID, &u.Name, &u.Email); err != nil {
        return nil, fmt.Errorf("%s: %w", op, err)
    }
    return &u, nil
}
```

### Cycle 2: Not Found

**RED:**
```go
func TestUserRepository_FindByID_Missing_ReturnsErrNotFound(t *testing.T) {
    db := setupTestDB(t)
    repo := NewUserRepository(db)

    _, err := repo.FindByID(context.Background(), "nonexistent")
    require.Error(t, err)
    assert.True(t, errors.Is(err, ErrNotFound))
}
// FAIL: returns sql.ErrNoRows, not ErrNotFound
```

**GREEN:**
```go
if err := row.Scan(&u.ID, &u.Name, &u.Email); err != nil {
    if errors.Is(err, sql.ErrNoRows) {
        return nil, fmt.Errorf("%s: %w", op, ErrNotFound)
    }
    return nil, fmt.Errorf("%s: %w", op, err)
}
```

---

## Handler TDD — CreateUserHandler

### Cycle 1: Success Response

**RED:**
```go
func TestCreateUserHandler_ValidJSON_Returns201(t *testing.T) {
    svc := mocks.NewUserService(t)
    handler := NewCreateUserHandler(svc)

    body := `{"name":"Alice","email":"alice@example.com"}`
    req := httptest.NewRequest(http.MethodPost, "/users", strings.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    rec := httptest.NewRecorder()

    svc.EXPECT().
        Create(mock.Anything, mock.Anything).
        Return(&User{ID: "usr-123", Name: "Alice"}, nil)

    handler.ServeHTTP(rec, req)

    assert.Equal(t, http.StatusCreated, rec.Code)
    assert.Contains(t, rec.Body.String(), "usr-123")
}
```

### Cycle 2: Validation Error Response

**RED:**
```go
func TestCreateUserHandler_EmptyBody_Returns400(t *testing.T) {
    svc := mocks.NewUserService(t)
    handler := NewCreateUserHandler(svc)

    req := httptest.NewRequest(http.MethodPost, "/users", strings.NewReader(`{}`))
    req.Header.Set("Content-Type", "application/json")
    rec := httptest.NewRecorder()

    svc.EXPECT().
        Create(mock.Anything, mock.Anything).
        Return(nil, fmt.Errorf("validate: %w", ErrInvalidInput))

    handler.ServeHTTP(rec, req)

    assert.Equal(t, http.StatusBadRequest, rec.Code)
}
```

### Cycle 3: Table-Driven Error Codes (incremental)

```go
func TestCreateUserHandler_ErrorMapping(t *testing.T) {
    tests := []struct {
        name       string
        svcErr     error
        wantStatus int
    }{
        // Cycle 3a: first case
        {name: "invalid input", svcErr: ErrInvalidInput, wantStatus: http.StatusBadRequest},
        // Cycle 3b: add after 3a passes
        // {name: "not found", svcErr: ErrNotFound, wantStatus: http.StatusNotFound},
        // Cycle 3c: add after 3b passes
        // {name: "internal", svcErr: errors.New("db down"), wantStatus: http.StatusInternalServerError},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            svc := mocks.NewUserService(t)
            handler := NewCreateUserHandler(svc)

            req := httptest.NewRequest(http.MethodPost, "/users",
                strings.NewReader(`{"name":"x","email":"x@x.com"}`))
            req.Header.Set("Content-Type", "application/json")
            rec := httptest.NewRecorder()

            svc.EXPECT().Create(mock.Anything, mock.Anything).Return(nil, tt.svcErr)

            handler.ServeHTTP(rec, req)
            assert.Equal(t, tt.wantStatus, rec.Code)
        })
    }
}
```
