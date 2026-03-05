# BBSim Tests - Quick Start Guide

This guide will help you get started with the BBSim Tests GitHub Action in under 5 minutes.

## Prerequisites

- A GitHub repository with GitHub Actions enabled
- Access to the `shared-workflows` repository containing this action
- Basic understanding of VOLTHA and BBSim

## Minimal Example

Create `.github/workflows/bbsim-test.yaml` in your repository:

```yaml
name: BBSim Tests

on:
  push:
    branches: [master]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout shared-workflows
        uses: actions/checkout@v4
        with:
          repository: opencord/shared-workflows
          path: shared-workflows

      - name: Run BBSim Tests
        uses: ./shared-workflows/.github/actions/bbsim-tests
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

That's it! Commit and push this file to trigger your first BBSim test.

## What This Does

1. **Installs dependencies**: kubectl, helm, kind, kail, voltctl
2. **Creates a Kubernetes cluster**: 3-node kind cluster
3. **Deploys VOLTHA**: Complete VOLTA stack with BBSim
4. **Runs tests**: Executes the specified Robot Framework tests
5. **Collects results**: Uploads logs and test reports as artifacts

## Common Test Targets

### DT Workflow
```yaml
- target: functional-single-kind-dt
  workflow: dt
  flags: ""
  teardown: true
  logging: true
  vgcEnabled: false
```

### ATT Workflow
```yaml
- target: functional-single-kind-att
  workflow: att
  flags: ""
  teardown: true
  logging: true
  vgcEnabled: false
```

### TT Workflow
```yaml
- target: functional-single-kind-tt
  workflow: tt
  flags: ""
  teardown: true
  logging: true
  vgcEnabled: false
```

### Sanity Tests (Quick)
```yaml
- target: sanity-single-kind
  workflow: dt
  flags: ""
  teardown: true
  logging: true
  vgcEnabled: false
```

## Running Multiple Tests

Just add more entries to the `test-targets` list:

```yaml
test-targets: |
  - target: sanity-single-kind
    workflow: dt
    flags: ""
    teardown: true
    logging: true
    vgcEnabled: false
  - target: functional-single-kind-dt
    workflow: dt
    flags: ""
    teardown: true
    logging: true
    vgcEnabled: false
```

## Enabling Debug Logging

Set `log-level` to `DEBUG`:

```yaml
- name: Run BBSim Tests
  uses: ./shared-workflows/.github/actions/bbsim-tests
  with:
    branch: master
    log-level: DEBUG
    test-targets: |
      ...
```

## Enabling Monitoring

Add `with-monitoring: true` to collect memory consumption metrics:

```yaml
- name: Run BBSim Tests
  uses: ./shared-workflows/.github/actions/bbsim-tests
  with:
    branch: master
    with-monitoring: true
    test-targets: |
      ...
```

## Testing Multiple OLTs

Set the `olts` parameter:

```yaml
- name: Run BBSim Tests
  uses: ./shared-workflows/.github/actions/bbsim-tests
  with:
    branch: master
    olts: "2"
    test-targets: |
      ...
```

## Viewing Results

After the workflow completes:

1. Go to the **Actions** tab in your repository
2. Click on the workflow run
3. Scroll to the bottom to see **Artifacts**
4. Download the test results artifact
5. Open `report.html` in a browser to see the Robot Framework report

## Manual Trigger

Add `workflow_dispatch` to trigger tests manually:

```yaml
name: BBSim Tests

on:
  workflow_dispatch:
    inputs:
      branch:
        description: 'Branch to test'
        required: true
        default: 'master'
      log_level:
        description: 'Log level'
        required: false
        default: 'WARN'
        type: choice
        options:
          - DEBUG
          - INFO
          - WARN
          - ERROR

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          repository: opencord/shared-workflows
          path: shared-workflows

      - uses: ./shared-workflows/.github/actions/bbsim-tests
        with:
          branch: ${{ inputs.branch }}
          log-level: ${{ inputs.log_level }}
          test-targets: |
            - target: functional-single-kind-dt
              workflow: dt
              flags: ""
              teardown: true
              logging: true
              vgcEnabled: false
```

Now you can trigger tests from the GitHub UI!

## Troubleshooting

### Test Fails Immediately

Check that your runner has enough resources:
- Minimum: 8GB RAM, 2 CPUs
- Recommended: 16GB RAM, 4 CPUs

Free up disk space before running:
```yaml
- name: Free disk space
  run: |
    sudo rm -rf /usr/share/dotnet
    sudo rm -rf /opt/ghc
    sudo rm -rf /usr/local/share/boost
    sudo rm -rf "$AGENT_TOOLSDIRECTORY"
```

### Cluster Creation Fails

The kind cluster name might conflict. Try a unique name:
```yaml
with:
  cluster-name: "my-test-cluster"
```

### Tests Time Out

Increase the job timeout:
```yaml
jobs:
  test:
    timeout-minutes: 480  # 8 hours
```

### Need Help?

1. Check the [README.md](README.md) for detailed documentation
2. Look at [example-workflow.yaml](example-workflow.yaml) for complete examples
3. Review [CONVERSION-NOTES.md](CONVERSION-NOTES.md) for technical details
4. Check GitHub Actions logs for specific error messages

## Next Steps

- **Customize**: Adjust parameters for your specific needs
- **Schedule**: Add `schedule` triggers for nightly tests
- **Integrate**: Add to PR workflows for automated testing
- **Monitor**: Enable monitoring to track resource usage
- **Optimize**: Adjust timeouts and resource limits

## Full Example with All Options

```yaml
name: Complete BBSim Tests

on:
  push:
    branches: [master]
  pull_request:
  schedule:
    - cron: '0 2 * * *'
  workflow_dispatch:

jobs:
  bbsim-tests:
    runs-on: ubuntu-latest
    timeout-minutes: 360
    
    steps:
      - name: Free up disk space
        run: |
          sudo rm -rf /usr/share/dotnet
          sudo rm -rf /opt/ghc
          sudo rm -rf /usr/local/share/boost
          sudo rm -rf "$AGENT_TOOLSDIRECTORY"
      
      - name: Checkout shared-workflows
        uses: actions/checkout@v4
        with:
          repository: opencord/shared-workflows
          path: shared-workflows
      
      - name: Run BBSim Tests
        uses: ./shared-workflows/.github/actions/bbsim-tests
        with:
          branch: master
          log-level: INFO
          cluster-name: kind-ci
          docker-registry: mirror.registry.opennetworking.org
          olts: "2"
          with-monitoring: true
          enable-mac-learning: false
          extra-helm-flags: "--set global.some_option=value"
          extra-robot-args: "-v some_var:some_value"
          test-targets: |
            - target: sanity-single-kind
              workflow: dt
              flags: ""
              teardown: true
              logging: true
              vgcEnabled: false
            - target: functional-single-kind-dt
              workflow: dt
              flags: ""
              teardown: true
              logging: true
              vgcEnabled: false
      
      - name: Upload results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results-${{ github.run_id }}
          path: logs/
          retention-days: 30
```

---

**Happy Testing!** 🚀