#!/usr/bin/env bash
# fail MESSAGE: print MESSAGE to stderr and return 1, so `assertion || fail "why"`
# fails the test with that message (bats prints a failing test's output).
# A local stand-in for bats-assert's fail; nothing else is loaded.
fail() {
    printf '%s\n' "$*" >&2
    return 1
}
