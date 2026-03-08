# Planner Examples

purpose: "Примеры полного vs неполного кода для планов"
loaded_by: [planner]
when: "Reference when writing code examples in plan (PHASE 4: DOCUMENT)"
source: "Extracted from planner.md (lines 389-404) for deferred loading (4.4)"

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
