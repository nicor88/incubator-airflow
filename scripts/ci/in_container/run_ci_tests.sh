#!/usr/bin/env bash

#
#  Licensed to the Apache Software Foundation (ASF) under one
#  or more contributor license agreements.  See the NOTICE file
#  distributed with this work for additional information
#  regarding copyright ownership.  The ASF licenses this file
#  to you under the Apache License, Version 2.0 (the
#  "License"); you may not use this file except in compliance
#  with the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing,
#  software distributed under the License is distributed on an
#  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
#  KIND, either express or implied.  See the License for the
#  specific language governing permissions and limitations
#  under the License.

# Bash sanity settings (error on exit, complain for undefined vars, error when pipe fails)
set -euo pipefail

MY_DIR=$(cd "$(dirname "$0")" || exit 1; pwd)

# shellcheck source=./_in_container_utils.sh
. "${MY_DIR}/_in_container_utils.sh"

in_container_basic_sanity_check

in_container_script_start

# any argument received is overriding the default nose execution arguments:
NOSE_ARGS=( "$@" )

KUBERNETES_VERSION=${KUBERNETES_VERSION:=""}

if [[ "${KUBERNETES_VERSION}" == "" ]]; then
    echo "Initializing the DB"
    yes | airflow db init || true
    airflow db reset -y

    kinit -kt "${KRB5_KTNAME}" airflow
fi

echo
echo "Starting the tests with those nose arguments: ${NOSE_ARGS[*]}"
echo
set +e
nosetests "${NOSE_ARGS[@]}"
RES=$?

set +x
if [[ "${RES}" != "0" ]]; then
    if [[ -f "${XUNIT_FILE:=}" ]]; then
        SEPARATOR_WIDTH=$(tput cols)
        echo
        printf '=%.0s' $(seq "${SEPARATOR_WIDTH}")
        echo
        echo "   Summary of failed tests"
        echo
        python "${AIRFLOW_SOURCES:=}/tests/test_utils/print_tests.py" \
            --xunit-file "${XUNIT_FILE}" --only-failed
        echo
        printf '=%.0s' $(seq "${SEPARATOR_WIDTH}")
    else
        echo
        echo " Not printing summary of failed tests. Missing file: ${XUNIT_FILE}"
        echo
    fi
else
    echo "All tests successful"
    bash <(curl -s https://codecov.io/bash)
fi

in_container_script_end

exit "${RES}"
