# OPERATION SHADOW — Test Plan

## Testing Strategy

### Unit Tests (GDScript-based)
| Test ID | System | Test | Status |
|---------|--------|------|--------|
| UT-001 | Weapon | Damage calculation correctness | ✅ |
| UT-002 | Weapon | Fire-rate enforcement (no faster than configured rate) | ✅ |
| UT-003 | Weapon | Ammo consumption (decrements per shot) | ✅ |
| UT-004 | Weapon | Reload timing (correct duration) | ✅ |
| UT-005 | Weapon | Magazine overflow prevention | ✅ |
| UT-006 | Weapon | Headshot multiplier accuracy | ✅ |
| UT-007 | Enemy | AI state transitions (Idle→Alert→Chase→Attack) | ✅ |
| UT-008 | Enemy | Dead enemies stop attacking | ✅ |
| UT-009 | Mission | Objective progress tracking | ✅ |
| UT-010 | Mission | Mission completion conditions | ✅ |
| UT-011 | Mission | Mission failure conditions | ✅ |
| UT-012 | Mission | Level unlock prerequisites | ✅ |
| UT-013 | Save | Save and load round-trip | ✅ |
| UT-014 | Save | Missing save file handling | ✅ |
| UT-015 | Save | Corrupt save file handling | ✅ |
| UT-016 | Save | Save version migration | ✅ |
| UT-017 | Player | Health damage and death | ✅ |
| UT-018 | Difficulty | Configuration application | ✅ |

### Integration Tests
| Test ID | Systems | Test | Status |
|---------|---------|------|--------|
| IT-001 | Player+Level | Player spawns at correct position | ✅ |
| IT-002 | Player+Weapon | Weapon pickup changes active weapon | ✅ |
| IT-003 | Enemy+Player | Enemy detects player in range | ✅ |
| IT-004 | Enemy+Health | Enemy death on HP depletion | ✅ |
| IT-005 | Mission+Scene | Mission restart resets state | ✅ |
| IT-006 | Game+Pause | Pause stops game, resume continues | ✅ |
| IT-007 | Scene+Scene | Scene transitions don't break state | ✅ |
| IT-008 | Campaign | Level completion unlocks next level | ✅ |

### Regression Tests
| Test ID | Test | Status |
|---------|------|--------|
| RT-001 | Completed missions remain playable after code changes | ✅ |
| RT-002 | Scene changes don't break saved progress | ✅ |
| RT-003 | Repeated firing doesn't duplicate damage events | ✅ |
| RT-004 | Mission restart resets all temporary state | ✅ |
| RT-005 | Dead enemies don't continue attacking | ✅ |
| RT-006 | Mission completion doesn't trigger repeatedly | ✅ |

### End-to-End Journey Test
See Phase 18 in GAME_DEVELOPMENT_PLAN.md for the complete player journey checklist.

## QA Checklist (Manual)
- [ ] Launch game → Main menu renders
- [ ] Select character → Character appears in gameplay
- [ ] Start Level 0 → Tutorial loads
- [ ] Complete tutorial → Level 1 unlocks
- [ ] Play Level 1 → Enemies spawn, weapons work
- [ ] Die in mission → Failure screen appears with retry
- [ ] Complete mission → Summary screen with next level
- [ ] Save and restart app → Progress persists
- [ ] Test all 5 environment themes
- [ ] Test touch controls on Android
- [ ] Test desktop controls
