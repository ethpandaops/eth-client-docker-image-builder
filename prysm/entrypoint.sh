#!/bin/sh
if [ -n "${MINIMAL_CONFIG}" ]; then
    exec "${ENTRY}" --minimal-config "$@"
else
    exec "${ENTRY}" "$@"
fi
