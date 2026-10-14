package xray

import (
	"path/filepath"
	"strings"
	"testing"
)

func TestXrayUsesLocalBinaryPath(t *testing.T) {
	if got, want := filepath.ToSlash(GetBinaryPath()), "bin/"+GetBinaryName(); got != want {
		t.Fatalf("GetBinaryPath() = %q; want local path %q", got, want)
	}
	for _, path := range []string{GetGeositePath(), GetGeoipPath()} {
		if !strings.HasPrefix(filepath.ToSlash(path), "bin/") {
			t.Errorf("data file path %q is not local", path)
		}
	}
}

func TestStoppedXrayProcessReportsVietnameseStatus(t *testing.T) {
	p := newProcess(&Config{})
	if got := p.GetVersion(); got != "Không xác định" {
		t.Fatalf("default Xray version = %q; want Vietnamese unknown state", got)
	}
	if err := p.Stop(); err == nil || err.Error() != "Xray chưa chạy" {
		t.Fatalf("Stop() error = %v; expected Vietnamese not running message", err)
	}
}
