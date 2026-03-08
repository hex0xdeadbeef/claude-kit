# Planner Examples

purpose: "Examples of complete vs incomplete code for plans"

---

examples:
  code_completeness:
    bad:
      code: "func (uc *UseCase) Do(ctx context.Context) error"
      why: "Incomplete example — only signature without body"

    good:
      code: |
        func (s *Service) Do(ctx context.Context, id string) error {
            result, err := s.repo.Get(ctx, id)
            if err != nil {
                return fmt.Errorf("get item: %w", err)
            }
            return nil
        }
      why: "Full example with function body, error wrapping, context propagation"
