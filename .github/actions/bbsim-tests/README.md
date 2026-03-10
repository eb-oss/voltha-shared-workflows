# BBSim Tests GitHub Action

This action runs VOLTHA end-to-end tests using BBSim (Broadband Simulator) to simulate OLT/ONU devices. It's a conversion of the Jenkins pipeline from `ci-management/jjb/pipeline/voltha/bbsim-tests.groovy` to GitHub Actions.

## Important Note

This action is designed to be used as a **shared/reusable action** from external repositories. All test execution logic is embedded directly in the `action.yaml` file (no external script dependencies), making it compatible with GitHub Actions' composite action model when called from other repositories.

## Overview

The action performs the following steps:

1. **Setup Environment**: Installs all required dependencies (kubectl, helm, kind, kail, voltctl)
2. **Checkout Repositories**: Clones voltha-system-tests and voltha-helm-charts
3. **Build Components**: Optionally builds VOLTHA components from Gerrit patches
4. **Create Kubernetes Cluster**: Sets up a kind cluster for testing
5. **Deploy Infrastructure**: Deploys VOLTHA, ONOS, and BBSim instances
6. **Run Tests**: Executes Robot Framework test suites
7. **Collect Artifacts**: Gathers logs, test results, and metrics

## Inputs

### Required Inputs

- **`branch`**: Branch to test (e.g., `master`, `voltha-2.15`)
- **`test-targets`**: YAML string defining test targets to run (see format below)

### Optional Inputs

- **`gerrit-project`**: Gerrit project name if building a patch (default: `""`)
- **`gerrit-refspec`**: Gerrit refspec if building a patch (default: `""`)
- **`voltha-system-tests-change`**: Gerrit change number for voltha-system-tests (default: `""`)
- **`voltha-helm-charts-change`**: Gerrit change number for voltha-helm-charts (default: `""`)
- **`extra-helm-flags`**: Additional Helm flags for deployment (default: `""`)
- **`log-level`**: Log level for VOLTHA components: DEBUG, INFO, WARN, ERROR (default: `"WARN"`)
- **`timeout`**: Timeout in minutes for the entire action (default: `"240"`)
- **`cluster-name`**: Name of the kind cluster (default: `"kind-ci"`)
- **`docker-registry`**: Docker registry to use (default: `"linuxfoundation.jfrog.io/voltha-docker"`)
- **`olts`**: Number of OLTs to simulate (default: `"1"`)
- **`with-monitoring`**: Enable monitoring with Prometheus (default: `false`)
- **`enable-mac-learning`**: Enable MAC learning in VOLTHA (default: `false`)
- **`extra-robot-args`**: Additional arguments for Robot Framework (default: `""`)

## Outputs

- **`test-results`**: Path to test results directory

## Test Targets Format

The `test-targets` input should be a YAML array with the following structure:

```yaml
- target: functional-single-kind-dt
  workflow: dt
  flags: "--set someFlag=value"
  teardown: true
  logging: true
  vgcEnabled: false
- target: functional-single-kind-att
  workflow: att
  flags: ""
  teardown: true
  logging: true
  vgcEnabled: false
```

### Test Target Fields

- **`target`**: Make target from voltha-system-tests (e.g., `functional-single-kind-dt`)
- **`workflow`**: VOLTHA workflow type (e.g., `dt`, `att`, `tt`)
- **`flags`**: Additional Helm flags specific to this test (optional)
- **`teardown`**: Whether to tear down and redeploy VOLTHA (default: `true`)
- **`logging`**: Enable test logging (default: `true`)
- **`vgcEnabled`**: Enable VOLTHA Go Controller (default: `false`)

## Usage Examples

### Basic Usage (from External Repository)

This is the most common usage pattern - calling the action from another repository:

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

**Note**: Replace `@master` with a specific version tag or commit SHA for production use.

### Usage from Local Repository

If you're developing or testing the action within the `shared-workflows` repository itself:

```yaml
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

### Advanced Usage with Multiple Tests

```yaml
name: BBSim Multi-Workflow Tests

on:
  schedule:
    - cron: '0 2 * * *'  # Run nightly

jobs:
  bbsim-tests:
    runs-on: ubuntu-latest
    timeout-minutes: 300
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Run BBSim Tests
        uses: ./.github/actions/bbsim-tests
        with:
          branch: master
          log-level: INFO
          olts: "2"
          with-monitoring: true
          extra-helm-flags: "--set global.some_option=true"
          test-targets: |
            - target: functional-single-kind-dt
              workflow: dt
              flags: ""
              teardown: true
              logging: true
              vgcEnabled: false
            - target: functional-single-kind-att
              workflow: att
              flags: ""
              teardown: true
              logging: true
              vgcEnabled: false
            - target: functional-single-kind-tt
              workflow: tt
              flags: ""
              teardown: true
              logging: true
              vgcEnabled: false

      - name: Publish Test Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: logs/
```

### Testing a Gerrit Patch

```yaml
name: Test Gerrit Patch

on:
  workflow_dispatch:
    inputs:
      gerrit_project:
        description: 'Gerrit project name'
        required: true
        type: string
      gerrit_refspec:
        description: 'Gerrit refspec'
        required: true
        type: string

jobs:
  test-patch:
    runs-on: ubuntu-latest
    steps:
      - name: Run BBSim Tests with Patch
        uses: opencord/shared-workflows/.github/actions/bbsim-tests@master
        with:
          branch: master
          gerrit-project: ${{ inputs.gerrit_project }}
          gerrit-refspec: ${{ inputs.gerrit_refspec }}
          test-targets: |
            - target: sanity-single-kind
              workflow: dt
              flags: ""
              teardown: true
              logging: true
              vgcEnabled: false
```

### Testing with voltha-system-tests Changes

```yaml
name: Test System Tests Changes

on:
  pull_request:
    paths:
      - 'tests/**'

jobs:
  test-changes:
    runs-on: ubuntu-latest
    steps:
      - name: Run BBSim Tests
        uses: opencord/shared-workflows/.github/actions/bbsim-tests@master
        with:
          branch: master
          voltha-system-tests-change: "refs/changes/12/34512/1"
          test-targets: |
            - target: functional-single-kind-dt
              workflow: dt
              flags: ""
              teardown: true
              logging: true
              vgcEnabled: false
```

## How It Works

This action is implemented as a **composite action** with all logic embedded directly in the `action.yaml` file. When called from an external repository:

1. The test execution script is created dynamically at runtime in `/tmp/execute_test.sh`
2. No local file paths or relative references are needed
3. All dependencies are installed fresh in each run
4. The action is fully self-contained and portable

This design ensures the action works correctly whether called from:
- External repositories (most common use case)
- The shared-workflows repository itself (for development/testing)
- Forked repositories

## Dependencies

This action automatically installs the following dependencies:

- **kubectl**: Kubernetes CLI
- **helm**: Kubernetes package manager
- **kind**: Kubernetes in Docker (for local cluster)
- **kail**: Kubernetes log viewer
- **voltctl**: VOLTHA CLI tool
- **Python 3**: For Robot Framework tests
- **System packages**: curl, wget, git, make, jq, sshpass, rsync

## Artifacts

The action automatically uploads the following artifacts:

- Robot Framework test reports (HTML)
- Robot Framework test logs
- Robot Framework output XML
- VOLTHA pod logs
- Kubernetes events and pod information
- Memory consumption metrics (if monitoring enabled)
- Combined startup logs (compressed)

Artifacts are retained for 30 days and can be downloaded from the GitHub Actions UI.

## Architecture

### Components

1. **BBSim**: Simulates OLT/ONU devices
2. **VOLTHA**: Open source VOLT management system
3. **ONOS**: SDN controller
4. **Kafka**: Message broker for VOLTHA
5. **ETCD**: Key-value store for VOLTHA
6. **Robot Framework**: Test automation framework

### Namespaces

- **default**: Infrastructure components (optional monitoring)
- **voltha**: VOLTHA stack and BBSim instances

### Port Forwarding

The action sets up the following port forwards:

- **9092**: Kafka (voltha-infra-kafka)
- **30115**: ONOS SSH
- **30120**: ONOS REST API
- **31301**: Prometheus (if monitoring enabled)
- **50075+**: BBSim DMI ports (one per OLT instance)
- **8181**: VOLTHA Go Controller (if VGC enabled)

## Troubleshooting

### Tests Fail to Start

- Check that the cluster was created successfully
- Verify that all pods are running: `kubectl get pods -A`
- Check pod logs: `kubectl logs -n voltha <pod-name>`

### Timeout Issues

- Increase the `timeout` input value
- Check resource constraints on the runner
- Verify network connectivity

### Image Pull Errors

- Verify the `docker-registry` input is correct
- Check if images exist for the specified branch
- Ensure the runner has network access to the registry

### Port Forward Issues

Port forwards may fail if:
- Ports are already in use
- Pods are not ready
- Network policies block access

Check port-forward processes: `ps aux | grep port-forward`

### Test Failures

1. Check the Robot Framework logs in artifacts
2. Review VOLTHA pod logs
3. Check Kubernetes events
4. Verify test configuration matches the workflow

## Migration from Jenkins

This action replaces the Jenkins pipeline `bbsim-tests.groovy`. Key differences:

1. **No shared library**: All functionality is self-contained
2. **Declarative syntax**: Uses GitHub Actions YAML instead of Groovy
3. **Native artifact handling**: Uses GitHub Actions artifact upload
4. **Simplified configuration**: Direct input parameters instead of Jenkins parameters
5. **Better isolation**: Each run gets a fresh environment

### Parameter Mapping

| Jenkins Parameter | GitHub Action Input |
|------------------|---------------------|
| `branch` | `branch` |
| `testTargets` | `test-targets` |
| `gerritProject` | `gerrit-project` |
| `gerritRefspec` | `gerrit-refspec` |
| `volthaSystemTestsChange` | `voltha-system-tests-change` |
| `volthaHelmChartsChange` | `voltha-helm-charts-change` |
| `extraHelmFlags` | `extra-helm-flags` |
| `logLevel` | `log-level` |
| `timeout` | `timeout` |
| `registry` | `docker-registry` |
| `olts` | `olts` |
| `withMonitoring` | `with-monitoring` |
| `enableMacLearning` | `enable-mac-learning` |
| `extraRobotArgs` | `extra-robot-args` |

## Contributing

When modifying this action:

1. Test changes locally using [act](https://github.com/nektos/act)
2. Update this README with any new inputs or behavior changes
3. Follow the existing code structure and style
4. Add comments for complex logic
5. Update version numbers appropriately

## License

Copyright 2025 Open Networking Foundation Contributors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
