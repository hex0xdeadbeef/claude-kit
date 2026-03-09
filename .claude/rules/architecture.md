---
globs:
  - "internal/**/*.go"
---
# Go Architecture Rules (active when editing Go files)

Import Matrix (STRICT):
- handler → service/controller → repository → models
- handler NEVER imports repository directly
- models: only stdlib imports
- service: may import repository, NEVER handler

Domain Purity:
- NO encoding/json tags in domain entities (tags belong in DTOs)
