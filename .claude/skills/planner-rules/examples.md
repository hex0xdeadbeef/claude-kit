# Planner Examples

purpose: "Examples of complete vs incomplete code for plans, in 2 languages — to demonstrate the principle is language-agnostic."

---

examples:
  code_completeness:
    bad_go:
      code: "func (uc *UseCase) Do(ctx context.Context) error"
      why: "Incomplete example — only signature without body"

    good_go:
      code: |
        func (s *Service) Do(ctx context.Context, id string) error {
            result, err := s.repo.Get(ctx, id)
            if err != nil {
                return fmt.Errorf("get item: %w", err)
            }
            return nil
        }
      why: "Full example with function body, error wrapping per ERROR_WRAP, context propagation"

    bad_python:
      code: "def do(self, request_id: str) -> None: ..."
      why: "Incomplete example — only signature, no body"

    good_python:
      code: |
        def do(self, request_id: str) -> None:
            try:
                result = self._repo.get(request_id)
            except RepoError as err:
                raise ServiceError(f"get item {request_id}") from err
      why: "Full example with function body, exception chaining per ERROR_WRAP, explicit type annotations"
