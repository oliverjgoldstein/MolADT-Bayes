#!/usr/bin/env sh
set -eu

stack run moladtbayes -- perceive-sdf "$@"
