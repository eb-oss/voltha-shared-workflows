# BBSim Tests GitHub Action - Deployment Checklist

## Pre-Deployment Verification

### 1. File Structure
- [ ] All required files are present:
  - [ ] `action.yaml` - Main action definition
  - [ ] `execute_test.sh` - Test execution script
  - [ ] `README.md` - User documentation
  - [ ] `QUICKSTART.md` - Quick start guide
  - [ ] `CONVERSION-NOTES.md` - Technical conversion details
  - [ ] `example-workflow.yaml` - Example usage
  - [ ] `DEPLOYMENT-CHECKLIST.md` - This file

### 2. File Permissions
- [ ] `execute_test.sh` is executable (755)
  ```bash
  chmod +x .github/actions/bbsim-tests/execute_test.sh
  ```

### 3. Action Validation
- [ ] `action.yaml` syntax is valid (YAML lint)
  ```bash
  yamllint .github/actions/bbsim-tests/action.yaml
  ```
- [ ] All required inputs are documented
- [ ] All outputs are defined
- [ ] Steps use correct shell types

### 4. Script Validation
- [ ] `execute_test.sh` has proper shebang (`#!/bin/bash`)
- [ ] Script uses `set -euo pipefail` for safety
- [ ] All environment variables are properly referenced
- [ ] No hardcoded paths (uses `$GITHUB_WORKSPACE`, etc.)

## Testing Phase

### 5. Local Validation (Optional)
- [ ] Install [act](https://github.com/nektos/act) for local testing
- [ ] Test action locally if possible:
  ```bash
  act -W .github/workflows/test-bbsim.yaml
  ```

### 6. Repository Setup
- [ ] Fork or access to `opencord/shared-workflows` repository
- [ ] GitHub Actions enabled in the repository
- [ ] Sufficient runner resources available:
  - [ ] Minimum 8GB RAM, 2 CPUs
  - [ ] Minimum 50GB disk space
  - [ ] Network access to required registries

### 7. Create Test Workflow
- [ ] Create `.github/workflows/test-bbsim-action.yaml`
- [ ] Use minimal test configuration from QUICKSTART.md
- [ ] Test with single workflow (DT) first

### 8. Initial Test Run
- [ ] Trigger test workflow manually
- [ ] Verify all dependencies install correctly:
  - [ ] kubectl
  - [ ] helm
  - [ ] kind
  - [ ] kail
  - [ ] voltctl
- [ ] Verify kind cluster creation succeeds
- [ ] Verify VOLTHA deployment succeeds
- [ ] Verify test execution starts

### 9. Test Scenarios
Run tests for each scenario:
- [ ] **Sanity test** (quick validation)
  - Target: `sanity-single-kind`
  - Expected duration: ~15 minutes
  
- [ ] **Single workflow test** (DT)
  - Target: `functional-single-kind-dt`
  - Expected duration: ~45 minutes
  
- [ ] **Multiple workflows**
  - Targets: DT, ATT, TT in sequence
  - Expected duration: ~2 hours
  
- [ ] **With monitoring enabled**
  - Set `with-monitoring: true`
  - Verify prometheus metrics collected
  
- [ ] **Multiple OLTs**
  - Set `olts: "2"`
  - Verify both BBSim instances deploy
  
- [ ] **Debug logging**
  - Set `log-level: DEBUG`
  - Verify increased log verbosity

### 10. Artifact Verification
- [ ] Artifacts are uploaded after test completion
- [ ] Robot Framework reports are present (`report.html`)
- [ ] Test logs are included
- [ ] VOLTHA logs are captured
- [ ] Pod information is collected
- [ ] Compressed logs exist (`*.gz`)

### 11. Failure Scenario Testing
- [ ] Test intentional failures (modify test to fail)
- [ ] Verify artifacts are still collected on failure
- [ ] Verify logs show failure reason
- [ ] Verify GitHub Actions marks job as failed

### 12. Gerrit Patch Testing (If Applicable)
- [ ] Test with a known Gerrit patch:
  - [ ] `gerrit-project: voltha-go`
  - [ ] Valid `gerrit-refspec`
- [ ] Verify project is checked out
- [ ] Verify project builds successfully
- [ ] Verify image loads into kind cluster
- [ ] Verify tests run with patched component

## Documentation Review

### 13. Documentation Completeness
- [ ] README.md covers all inputs/outputs
- [ ] README.md includes usage examples
- [ ] README.md has troubleshooting section
- [ ] QUICKSTART.md provides minimal working example
- [ ] example-workflow.yaml demonstrates all features
- [ ] CONVERSION-NOTES.md documents Jenkins migration

### 14. Documentation Accuracy
- [ ] All example code tested and working
- [ ] Parameter descriptions match action.yaml
- [ ] Version numbers are current
- [ ] Links to external resources are valid

## Integration Testing

### 15. Integration with Existing Workflows
- [ ] Test action in context of existing CI/CD pipeline
- [ ] Verify compatibility with other actions
- [ ] Check for naming conflicts
- [ ] Validate matrix builds (if applicable)

### 16. Performance Testing
- [ ] Measure baseline test duration
- [ ] Verify resource usage is acceptable
- [ ] Check for memory leaks or resource exhaustion
- [ ] Validate timeout values are appropriate

### 17. Parallel Execution
- [ ] Test multiple workflow runs simultaneously
- [ ] Verify cluster names don't conflict
- [ ] Confirm proper cleanup between runs

## Production Readiness

### 18. Security Review
- [ ] No hardcoded secrets or credentials
- [ ] API keys properly managed (documented, not stored)
- [ ] File permissions are appropriate
- [ ] No arbitrary code execution vulnerabilities
- [ ] Docker images from trusted registries

### 19. Error Handling
- [ ] Network failures handled gracefully
- [ ] Timeout scenarios tested
- [ ] Resource exhaustion scenarios considered
- [ ] Clear error messages for common failures

### 20. Monitoring and Alerting
- [ ] Workflow failure notifications configured
- [ ] Success/failure metrics tracked
- [ ] Performance metrics baseline established
- [ ] Alert thresholds defined

### 21. Rollout Plan
- [ ] Define rollout phases:
  - [ ] Phase 1: Parallel operation with Jenkins
  - [ ] Phase 2: Primary testing platform
  - [ ] Phase 3: Jenkins deprecation
- [ ] Communication plan for stakeholders
- [ ] Rollback procedure documented
- [ ] Support process defined

## Post-Deployment

### 22. Monitoring Period
- [ ] Monitor first week of production usage
- [ ] Track success/failure rates
- [ ] Collect user feedback
- [ ] Document common issues

### 23. Optimization
- [ ] Identify performance bottlenecks
- [ ] Optimize slow steps
- [ ] Reduce artifact sizes if needed
- [ ] Improve error messages based on feedback

### 24. Maintenance Plan
- [ ] Schedule for dependency updates
- [ ] Process for handling breaking changes
- [ ] Documentation update schedule
- [ ] Version tagging strategy

## Sign-Off

### 25. Team Review
- [ ] Code review completed
- [ ] Documentation review completed
- [ ] Security review completed
- [ ] QA sign-off obtained

### 26. Final Verification
- [ ] All checklist items completed
- [ ] No outstanding issues or blockers
- [ ] Rollback plan tested
- [ ] Support team trained

### 27. Deployment Approval
- [ ] Technical lead approval: _________________ Date: _______
- [ ] Product owner approval: _________________ Date: _______
- [ ] Security approval: _________________ Date: _______

## Quick Reference Commands

### Test the Action Locally
```bash
# Navigate to repository
cd shared-workflows

# Validate YAML syntax
yamllint .github/actions/bbsim-tests/action.yaml

# Check file permissions
ls -la .github/actions/bbsim-tests/execute_test.sh

# Run shellcheck on bash script
shellcheck .github/actions/bbsim-tests/execute_test.sh
```

### Trigger Test Workflow
```bash
# Using GitHub CLI
gh workflow run test-bbsim-action.yaml

# With parameters
gh workflow run test-bbsim-action.yaml \
  -f branch=master \
  -f log_level=DEBUG \
  -f workflow_type=dt
```

### Check Workflow Status
```bash
# List recent runs
gh run list --workflow=test-bbsim-action.yaml

# View specific run
gh run view <run-id>

# Download artifacts
gh run download <run-id>
```

### Cleanup
```bash
# Delete kind cluster if stuck
kind delete cluster --name kind-ci

# Clean up old artifacts
gh api repos/:owner/:repo/actions/artifacts --paginate | \
  jq -r '.artifacts[] | select(.expired == false) | .id' | \
  xargs -I {} gh api -X DELETE repos/:owner/:repo/actions/artifacts/{}
```

## Troubleshooting Common Issues

### Issue: Action not found
**Solution**: Ensure path is correct: `./shared-workflows/.github/actions/bbsim-tests`

### Issue: Permission denied on execute_test.sh
**Solution**: `chmod +x .github/actions/bbsim-tests/execute_test.sh`

### Issue: Kind cluster creation fails
**Solution**: Check Docker is running, sufficient resources available

### Issue: Tests timeout
**Solution**: Increase `timeout-minutes` in job configuration

### Issue: Disk space errors
**Solution**: Add disk cleanup step before action

## Success Criteria

- [ ] ✅ All test scenarios pass consistently
- [ ] ✅ Artifacts successfully uploaded and accessible
- [ ] ✅ Documentation is clear and complete
- [ ] ✅ Performance meets or exceeds Jenkins baseline
- [ ] ✅ Team is trained and confident in using action
- [ ] ✅ Monitoring and alerting in place
- [ ] ✅ Rollback plan tested and ready

---

**Deployment Date**: _______________  
**Deployed By**: _______________  
**Version**: 1.0.0  
**Status**: ☐ In Progress  ☐ Completed  ☐ On Hold