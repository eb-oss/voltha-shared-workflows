# Using BBSim Tests Action from External Repositories

## Overview

This action is specifically designed to be used as a **shared/reusable action** from external repositories. All implementation details are self-contained within the `action.yaml` file, with no dependencies on external script files that could cause path resolution issues.

## Why This Matters

When a GitHub Action is called from an external repository (e.g., `uses: opencord/shared-workflows/.github/actions/bbsim-tests@master`), the action runs in the context of the **calling repository**, not the action's repository. This means:

- ❌ Relative paths like `./execute_test.sh` won't work
- ❌ `${{ github.action_path }}/script.sh` may not be accessible
- ✅ Inline scripts work perfectly
- ✅ Scripts created at runtime in `/tmp` work perfectly

## Implementation Approach

### The Problem (Original Approach)

```yaml
# This DOES NOT work from external repositories
- name: Execute test
  shell: bash
  run: |
    bash ${{ github.action_path }}/execute_test.sh
```

When called from `opencord/bbsim` repository, `github.action_path` points to a directory that doesn't exist in the caller's context.

### The Solution (Current Approach)

```yaml
# This WORKS from external repositories
- name: Create test execution script
  shell: bash
  run: |
    cat > /tmp/execute_test.sh <<'SCRIPT'
    #!/bin/bash
    # ... entire script embedded here ...
    SCRIPT
    chmod +x /tmp/execute_test.sh

- name: Execute test
  shell: bash
  run: |
    bash /tmp/execute_test.sh
```

The script is created dynamically at runtime, ensuring it's always available regardless of where the action is called from.

## Usage Pattern

### From External Repository (Standard Usage)

```yaml
name: BBSim Tests

on:
  push:
    branches: [master]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Run BBSim Tests
        uses: opencord/shared-workflows/.github/actions/bbsim-tests@master
        with:
          branch: master
          test-targets: |
            - target: functional-single-kind-dt
              workflow: dt
              flags: ""
              teardown: true
              logging: true
              vgcEnabled: false
```

**No special steps required!** The action handles everything automatically.

### Repository Setup Required

The calling repository needs:
- GitHub Actions enabled
- Sufficient runner resources (minimum 8GB RAM, 2 CPUs)
- Network access to pull Docker images and Helm charts

The calling repository does **NOT** need:
- The `shared-workflows` repository checked out locally
- Any of the action's script files
- Special permissions or configurations

## What Gets Checked Out

When the action runs, it automatically checks out these repositories into the runner's workspace:

1. **voltha-system-tests** - Contains the Robot Framework test suites
2. **voltha-helm-charts** - Contains Helm charts for deployment (if using patches or release branches)
3. **project** (optional) - If testing a specific component patch

The calling repository is **not** automatically checked out. If you need files from your repository, add a checkout step:

```yaml
steps:
  - name: Checkout calling repository
    uses: actions/checkout@v4
    with:
      path: my-repo

  - name: Run BBSim Tests
    uses: opencord/shared-workflows/.github/actions/bbsim-tests@master
    with:
      branch: master
      test-targets: |
        ...
```

## File System Layout

When the action runs, the file system looks like this:

```
/home/runner/work/
└── <calling-repo-name>/
    ├── <calling-repo-name>/        (only if explicitly checked out)
    ├── voltha-system-tests/        (checked out by action)
    ├── voltha-helm-charts/         (checked out by action, if needed)
    ├── <project>/                  (checked out by action, if specified)
    ├── bin/                        (created by action for tools)
    ├── logs/                       (created by action for test results)
    └── tmp/
        └── execute_test.sh         (created by action at runtime)
```

## Environment Variables

The action sets these environment variables automatically:

- `GITHUB_WORKSPACE` - Base workspace directory
- `KUBECONFIG` - Kubernetes configuration file location
- `VOLTCONFIG` - VOLTHA CLI configuration location
- `PATH` - Extended with tool directories
- `DIAGS_PROFILE` - VOLTHA diagnostics profile
- `SSHPASS` - ONOS SSH password

All test-specific variables are passed to the execution script via environment.

## Troubleshooting External Usage

### Issue: Action not found

**Error**: `Unable to resolve action 'opencord/shared-workflows/.github/actions/bbsim-tests@master'`

**Solutions**:
1. Verify the repository path is correct
2. Check that the action exists at that path in the repository
3. Ensure you have access to the repository (public or proper permissions)
4. Try using a specific commit SHA instead of branch name

### Issue: Permission denied errors

**Error**: `Permission denied` when running tests

**Solutions**:
1. Ensure the runner has Docker access
2. Check that the runner has sufficient permissions to create kind clusters
3. Verify network access to required registries

### Issue: Tests can't find voltha-system-tests

**Error**: `No such file or directory: voltha-system-tests`

**Solutions**:
1. This should not happen - the action checks out the repository automatically
2. If it does occur, check the action's checkout step logs
3. Verify network connectivity to GitHub

## Version Pinning

For production use, always pin to a specific version:

### Using Tags (Recommended)
```yaml
uses: opencord/shared-workflows/.github/actions/bbsim-tests@v1.0.0
```

### Using Commit SHA (Most Secure)
```yaml
uses: opencord/shared-workflows/.github/actions/bbsim-tests@abc123def456...
```

### Using Branch (Development Only)
```yaml
uses: opencord/shared-workflows/.github/actions/bbsim-tests@master
```

## Benefits of This Approach

✅ **Portability**: Works from any repository without modifications
✅ **Self-Contained**: No external dependencies to manage
✅ **Maintainability**: Single file to update (action.yaml)
✅ **Testability**: Easy to test from different repositories
✅ **Security**: No risk of path traversal issues
✅ **Transparency**: All logic visible in one place

## Real-World Example

See the actual usage in the BBSim repository:

**Repository**: `opencord/bbsim`
**Workflow File**: `.github/workflows/bbsim-basic-test.yaml`

```yaml
name: BBSim Tests

on:
  push:
    branches: [master]
  pull_request:

jobs:
  bbsim-tests:
    runs-on: ubuntu-latest
    steps:
      - name: Run BBSim Tests
        uses: opencord/shared-workflows/.github/actions/bbsim-tests@master
        with:
          branch: master
          test-targets: |
            - target: functional-single-kind-dt
              workflow: dt
              flags: ""
              teardown: true
              logging: true
              vgcEnabled: false
```

This works perfectly without any additional setup!

## Developer Notes

If you're modifying this action:

1. **Never use relative paths** to script files - they won't work from external repos
2. **Always test from an external repository** before considering the change complete
3. **Keep all logic in action.yaml** or create files dynamically at runtime
4. **Use absolute paths** when referring to files created by the action itself
5. **Document any new inputs** thoroughly in README.md

## Migration from Jenkins

Unlike Jenkins shared libraries, GitHub Actions composite actions run in the caller's context. This means:

| Jenkins | GitHub Actions |
|---------|----------------|
| Library code runs in shared space | Action code runs in caller's workspace |
| Can reference shared files directly | Must inline or create files at runtime |
| `@Library('shared')` imports | `uses: org/repo/.github/actions/name` |
| Groovy functions | Composite action steps |

The conversion required embedding all shell script logic directly into the action definition to ensure cross-repository compatibility.

## Support

If you encounter issues using this action from your repository:

1. Check this document first
2. Review the action's README.md
3. Examine the workflow logs in GitHub Actions UI
4. Verify your test-targets YAML syntax
5. Ensure your runner has sufficient resources

For bugs or feature requests, open an issue in the `shared-workflows` repository.