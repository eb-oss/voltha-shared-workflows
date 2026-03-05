#!/bin/bash
# -----------------------------------------------------------------------
# Copyright 2025 Open Networking Foundation Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# -----------------------------------------------------------------------
# SPDX-FileCopyrightText: 2025 Open Networking Foundation Contributors
# SPDX-License-Identifier: Apache-2.0
# -----------------------------------------------------------------------
# Helper script to execute a single bbsim test
# -----------------------------------------------------------------------

set -euo pipefail

# Get environment variables
TEST_TARGET="${TEST_TARGET:-functional-single-kind-dt}"
WORKFLOW="${WORKFLOW:-dt}"
TEST_FLAGS="${TEST_FLAGS:-}"
TEARDOWN="${TEARDOWN:-true}"
TEST_LOGGING="${TEST_LOGGING:-True}"
VGC_ENABLED="${VGC_ENABLED:-false}"
INFRA_NAMESPACE="${INFRA_NAMESPACE:-default}"
VOLTHA_NAMESPACE="${VOLTHA_NAMESPACE:-voltha}"
LOGS_DIR="${LOGS_DIR:-$GITHUB_WORKSPACE/logs}"
EXTRA_HELM_FLAGS="${EXTRA_HELM_FLAGS:-}"
LOG_LEVEL="${LOG_LEVEL:-WARN}"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-mirror.registry.opennetworking.org}"
OLTS="${OLTS:-1}"
WITH_MONITORING="${WITH_MONITORING:-false}"
ENABLE_MAC_LEARNING="${ENABLE_MAC_LEARNING:-false}"
EXTRA_ROBOT_ARGS="${EXTRA_ROBOT_ARGS:-}"
BRANCH="${BRANCH:-master}"
GERRIT_PROJECT="${GERRIT_PROJECT:-}"

# -----------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------
banner() {
    echo ""
    echo "** -----------------------------------------------------------------------"
    echo "** $1"
    echo "** -----------------------------------------------------------------------"
    echo ""
}

cleanup_port_forward() {
    echo "Cleaning up port-forward processes..."
    pkill -f "kubectl.*port-forward" || true
}

get_pods_info() {
    local logs_dir=$1
    mkdir -p "$logs_dir"

    kubectl get pods --all-namespaces -o wide > "$logs_dir/pods.txt" || true
    kubectl get nodes -o wide > "$logs_dir/nodes.txt" || true
    kubectl describe pods -n "$VOLTHA_NAMESPACE" > "$logs_dir/voltha-pods-describe.txt" || true
    kubectl describe pods -n "$INFRA_NAMESPACE" > "$logs_dir/infra-pods-describe.txt" || true
}

# -----------------------------------------------------------------------
# Stage: Cleanup (if teardown enabled)
# -----------------------------------------------------------------------
if [ "$TEARDOWN" = "true" ]; then
    banner "Cleanup - Helm Teardown"

    cleanup_port_forward

    # Helm teardown
    for namespace in default "$INFRA_NAMESPACE" "$VOLTHA_NAMESPACE"; do
        echo "Cleaning up Helm releases in namespace: $namespace"
        helm list -n "$namespace" -q | xargs -r helm uninstall -n "$namespace" || true
    done

    # Wait for pods to terminate
    echo "Waiting for pods to terminate..."
    kubectl wait --for=delete pods --all -n "$VOLTHA_NAMESPACE" --timeout=120s || true
    kubectl wait --for=delete pods --all -n "$INFRA_NAMESPACE" --timeout=120s || true
fi

# -----------------------------------------------------------------------
# Stage: Deploy Common Infrastructure
# -----------------------------------------------------------------------
banner "Deploying Common Infrastructure"

if [ "$WITH_MONITORING" = "true" ]; then
    echo "Deploying monitoring stack..."
    helm install nem-monitoring onf/nem-monitoring \
        --set prometheus.alertmanager.enabled=false \
        --set prometheus.pushgateway.enabled=false \
        --set kpi_exporter.enabled=false \
        --set dashboards.xos=false \
        --set dashboards.onos=false \
        --set dashboards.aaa=false \
        --set dashboards.voltha=false \
        --wait || true
fi

# -----------------------------------------------------------------------
# Stage: Deploy VOLTHA
# -----------------------------------------------------------------------
if [ "$TEARDOWN" = "true" ]; then
    banner "Deploying VOLTHA"

    # Start kail for logging
    ONOS_LOG="${LOGS_DIR}/onos-voltha-startup-combined.log"
    mkdir -p "$LOGS_DIR"
    touch "$ONOS_LOG"

    _TAG=kail-startup kail -n "${INFRA_NAMESPACE}" -n "${VOLTHA_NAMESPACE}" > "$ONOS_LOG" &
    KAIL_PID=$!

    # Determine if using local charts
    LOCAL_CHARTS="false"
    if [ -d "$GITHUB_WORKSPACE/voltha-helm-charts" ]; then
        LOCAL_CHARTS="true"
    fi

    # Build Helm flags
    HELM_FLAGS="--set global.log_level=${LOG_LEVEL^^}"

    if [ "$VGC_ENABLED" != "true" ]; then
        HELM_FLAGS="$HELM_FLAGS --set onos-classic.onosSshPort=30115"
        HELM_FLAGS="$HELM_FLAGS --set onos-classic.onosApiPort=30120"
        HELM_FLAGS="$HELM_FLAGS --set onos-classic.onosOfPort=31653"
        HELM_FLAGS="$HELM_FLAGS --set onos-classic.individualOpenFlowNodePorts=true"
    fi

    if [ -n "$EXTRA_HELM_FLAGS" ]; then
        HELM_FLAGS="$HELM_FLAGS $EXTRA_HELM_FLAGS"
    fi

    if [ -n "$TEST_FLAGS" ]; then
        HELM_FLAGS="$HELM_FLAGS $TEST_FLAGS"
    fi

    # Add image flags if building a component
    if [ -n "$GERRIT_PROJECT" ] && [ "$GERRIT_PROJECT" != "voltctl" ]; then
        IMAGE_TAG="citest"
        case "$GERRIT_PROJECT" in
            voltha-go)
                HELM_FLAGS="$HELM_FLAGS --set voltha.image.tag=$IMAGE_TAG"
                ;;
            voltha-openolt-adapter)
                HELM_FLAGS="$HELM_FLAGS --set voltha-adapter-openolt.image.tag=$IMAGE_TAG"
                ;;
            voltha-openonu-adapter-go)
                HELM_FLAGS="$HELM_FLAGS --set voltha-adapter-openonu.image.tag=$IMAGE_TAG"
                ;;
            ofagent-go)
                HELM_FLAGS="$HELM_FLAGS --set voltha.ofagent.image.tag=$IMAGE_TAG"
                ;;
            bbsim)
                HELM_FLAGS="$HELM_FLAGS --set bbsim.image.tag=$IMAGE_TAG"
                ;;
        esac
    fi

    # Deploy VOLTHA
    echo "Deploying VOLTHA with workflow: $WORKFLOW"
    echo "Helm flags: $HELM_FLAGS"

    if [ "$LOCAL_CHARTS" = "true" ]; then
        echo "Using local charts from $GITHUB_WORKSPACE/voltha-helm-charts"
        helm dependency update "$GITHUB_WORKSPACE/voltha-helm-charts/voltha-infra" || true
        helm dependency update "$GITHUB_WORKSPACE/voltha-helm-charts/voltha-stack" || true

        helm install voltha-infra "$GITHUB_WORKSPACE/voltha-helm-charts/voltha-infra" \
            -n "$INFRA_NAMESPACE" \
            --create-namespace \
            --wait \
            --timeout 10m

        helm install voltha "$GITHUB_WORKSPACE/voltha-helm-charts/voltha-stack" \
            -n "$VOLTHA_NAMESPACE" \
            --create-namespace \
            --set global.stack_name=voltha \
            --set global.voltha_infra_name=voltha-infra \
            --set global.voltha_infra_namespace="$INFRA_NAMESPACE" \
            $(echo "$HELM_FLAGS") \
            --wait \
            --timeout 10m
    else
        echo "Using charts from Helm repository"
        helm install voltha-infra onf/voltha-infra \
            -n "$INFRA_NAMESPACE" \
            --create-namespace \
            --wait \
            --timeout 10m

        helm install voltha onf/voltha-stack \
            -n "$VOLTHA_NAMESPACE" \
            --create-namespace \
            --set global.stack_name=voltha \
            --set global.voltha_infra_name=voltha-infra \
            --set global.voltha_infra_namespace="$INFRA_NAMESPACE" \
            $(echo "$HELM_FLAGS") \
            --wait \
            --timeout 10m
    fi

    # Deploy BBSim instances
    for i in $(seq 0 $((OLTS - 1))); do
        echo "Deploying bbsim${i}..."
        if [ "$LOCAL_CHARTS" = "true" ]; then
            helm install "bbsim${i}" "$GITHUB_WORKSPACE/voltha-helm-charts/bbsim" \
                -n "$VOLTHA_NAMESPACE" \
                --set olt_id="${i}" \
                --wait || true
        else
            helm install "bbsim${i}" onf/bbsim \
                -n "$VOLTHA_NAMESPACE" \
                --set olt_id="${i}" \
                --wait || true
        fi
    done

    # Stop kail
    if [ -n "${KAIL_PID:-}" ]; then
        kill "$KAIL_PID" || true
        wait "$KAIL_PID" 2>/dev/null || true
    fi

    # Compress startup log
    gzip -f "$ONOS_LOG" || true

    # Setup port forwarding
    echo "Setting up port forwarding..."

    # Kafka port forward
    kubectl port-forward --address 0.0.0.0 -n "$INFRA_NAMESPACE" svc/voltha-infra-kafka 9092:9092 &

    # BBSim DMI port forwards
    bbsim_dmi_port=50075
    for i in $(seq 0 $((OLTS - 1))); do
        kubectl port-forward --address 0.0.0.0 -n "$VOLTHA_NAMESPACE" "svc/bbsim${i}" "${bbsim_dmi_port}:50075" &
        ((bbsim_dmi_port++))
    done

    # Monitoring port forward
    if [ "$WITH_MONITORING" = "true" ]; then
        kubectl port-forward --address 0.0.0.0 -n default svc/nem-monitoring-prometheus-server 31301:80 &
    fi

    # VGC port forward
    if [ "$VGC_ENABLED" = "true" ]; then
        kubectl port-forward --address 0.0.0.0 -n "$VOLTHA_NAMESPACE" svc/voltha-voltha-go-controller 8181:8181 &
    fi

    # Wait for port forwards to establish
    sleep 5

    # Set ONOS log levels
    echo "Setting ONOS log levels..."
    # This would require voltctl or ONOS CLI access
    # Skipping for now as it requires additional setup
fi

# -----------------------------------------------------------------------
# Stage: Run Tests
# -----------------------------------------------------------------------
banner "Running test ${TEST_TARGET} on workflow ${WORKFLOW}"

# Monitor memory consumption (if monitoring enabled)
if [ "$WITH_MONITORING" = "true" ]; then
    echo "Collecting initial memory consumption..."
    mkdir -p "$GITHUB_WORKSPACE/voltha-pods-mem-consumption-${WORKFLOW}"

    cd "$GITHUB_WORKSPACE/voltha-system-tests"
    if [ -f "requirements.txt" ]; then
        python3 -m venv .venv || true
        source .venv/bin/activate || true
        pip install -r requirements.txt || true

        if [ -f "scripts/mem_consumption.py" ]; then
            python scripts/mem_consumption.py \
                -o "$GITHUB_WORKSPACE/voltha-pods-mem-consumption-${WORKFLOW}" \
                -a 0.0.0.0:31301 \
                -n "$VOLTHA_NAMESPACE" || true
        fi
    fi
fi

# Run Robot Framework tests
echo "Running Robot Framework tests..."
mkdir -p "$LOGS_DIR"

export ROBOT_MISC_ARGS="-d ${LOGS_DIR} ${EXTRA_ROBOT_ARGS}"
ROBOT_MISC_ARGS="${ROBOT_MISC_ARGS} -v ONOS_SSH_PORT:30115"
ROBOT_MISC_ARGS="${ROBOT_MISC_ARGS} -v ONOS_REST_PORT:30120"
ROBOT_MISC_ARGS="${ROBOT_MISC_ARGS} -v NAMESPACE:${VOLTHA_NAMESPACE}"
ROBOT_MISC_ARGS="${ROBOT_MISC_ARGS} -v INFRA_NAMESPACE:${INFRA_NAMESPACE}"
ROBOT_MISC_ARGS="${ROBOT_MISC_ARGS} -v container_log_dir:${LOGS_DIR}"
ROBOT_MISC_ARGS="${ROBOT_MISC_ARGS} -v logging:${TEST_LOGGING}"
export ROBOT_MISC_ARGS

export KVSTOREPREFIX="voltha/voltha_voltha"

cd "$GITHUB_WORKSPACE/voltha-system-tests"
make "${TEST_TARGET}" || TEST_RESULT=$?

# Collect pod info
get_pods_info "$LOGS_DIR"

# Collect final memory consumption (if monitoring enabled)
if [ "$WITH_MONITORING" = "true" ]; then
    echo "Collecting final memory consumption..."
    cd "$GITHUB_WORKSPACE/voltha-system-tests"
    source .venv/bin/activate || true

    if [ -f "scripts/mem_consumption.py" ]; then
        python scripts/mem_consumption.py \
            -o "$GITHUB_WORKSPACE/voltha-pods-mem-consumption-${WORKFLOW}" \
            -a 0.0.0.0:31301 \
            -n "$VOLTHA_NAMESPACE" || true
    fi
fi

# Compress logs
echo "Compressing logs..."
cd "$LOGS_DIR"
gzip *-combined.log 2>/dev/null || true

banner "Test execution completed"

exit ${TEST_RESULT:-0}
