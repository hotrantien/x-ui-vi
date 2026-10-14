package service

import (
	"path/filepath"
	"testing"
	"x-ui/database"
)

func TestFreshInstallListensOnAllIPv4Interfaces(t *testing.T) {
	path := filepath.Join(t.TempDir(), "x-ui.db")
	if err := database.InitDB(path); err != nil {
		t.Fatalf("Khởi tạo DB mới: %v", err)
	}
	listen, err := (&SettingService{}).GetListen()
	if err != nil {
		t.Fatalf("GetListen() lỗi: %v", err)
	}
	if listen != "0.0.0.0" {
		t.Fatalf("WebListen khi cài mới = %q; cần 0.0.0.0", listen)
	}
}
