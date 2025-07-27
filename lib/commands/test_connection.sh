#!/bin/bash
# Test connection command implementation

# Test connection command with mock or real API
cmd_test_connection() {
    if [[ "${1:-}" == "--mock" ]]; then
        test_api_connection_mock
    else
        test_api_connection
    fi
}