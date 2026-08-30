// Copyright (c) Tailscale Inc & contributors
// SPDX-License-Identifier: BSD-3-Clause

package main

import (
	"os/exec"
	"path/filepath"
	"runtime"
	"testing"
)

func buildTailcatTestBinary(t *testing.T) string {
	t.Helper()
	name := "tailcat"
	if runtime.GOOS == "windows" {
		name += ".exe"
	}
	bin := filepath.Join(t.TempDir(), name)
	if out, err := exec.Command("go", "build", "-o", bin, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v\n%s", err, out)
	}
	return bin
}

func testNoopCommand() []string {
	if runtime.GOOS == "windows" {
		return []string{"cmd.exe", "/d", "/c", "exit", "/b", "0"}
	}
	return []string{"true"}
}
