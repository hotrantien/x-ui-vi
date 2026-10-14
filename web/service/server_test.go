package service

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
	"x-ui/xray"
)

func TestXrayOnlineManagementIsDisabled(t *testing.T) {
	s := &ServerService{}
	versions, err := s.GetXrayVersions()
	if !errors.Is(err, ErrXrayOnlineManagementDisabled) {
		t.Fatalf("GetXrayVersions() error = %v; expected online management disabled", err)
	}
	if versions != nil {
		t.Fatalf("GetXrayVersions() = %v; expected no remote versions", versions)
	}

	for _, version := range []string{"v1.0.0", "", "../local-binary"} {
		if err := s.UpdateXray(version); !errors.Is(err, ErrXrayOnlineManagementDisabled) {
			t.Errorf("UpdateXray(%q) error = %v; expected online management disabled", version, err)
		}
	}
}

func TestUpdateXrayDoesNotOverwriteLocalBinary(t *testing.T) {
	originalDir, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	workDir := t.TempDir()
	if err := os.Chdir(workDir); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if err := os.Chdir(originalDir); err != nil {
			t.Errorf("restore working directory: %v", err)
		}
	})

	if err := os.Mkdir("bin", 0755); err != nil {
		t.Fatal(err)
	}
	files := map[string]string{
		xray.GetBinaryPath():  "existing Xray executable",
		xray.GetGeositePath(): "existing geosite",
		xray.GetGeoipPath():   "existing geoip",
	}
	for name, contents := range files {
		if err := os.WriteFile(filepath.FromSlash(name), []byte(contents), 0600); err != nil {
			t.Fatal(err)
		}
	}

	s := &ServerService{}
	if err := s.UpdateXray("v99.0.0"); !errors.Is(err, ErrXrayOnlineManagementDisabled) {
		t.Fatalf("UpdateXray() error = %v; expected online management disabled", err)
	}
	for name, want := range files {
		got, err := os.ReadFile(filepath.FromSlash(name))
		if err != nil {
			t.Fatalf("read %s: %v", name, err)
		}
		if string(got) != want {
			t.Errorf("UpdateXray() overwrote %s: got %q, want %q", name, got, want)
		}
	}
}
