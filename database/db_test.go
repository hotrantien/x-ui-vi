package database

import (
	"path/filepath"
	"testing"

	"x-ui/database/model"
)

func TestInitDBRequiresWorkingSQLiteDriver(t *testing.T) {
	path := filepath.Join(t.TempDir(), "db", "test.db")
	if err := InitDB(path); err != nil {
		t.Fatalf("Không khởi tạo được SQLite (kiểm tra CGO khi build): %v", err)
	}
	if _, err := GetDB().DB(); err != nil {
		t.Fatalf("Không mở được kết nối SQLite: %v", err)
	}
	var users int64
	if err := GetDB().Model(&model.User{}).Count(&users).Error; err != nil {
		t.Fatalf("Không thể đọc bảng người dùng: %v", err)
	}
	if users != 1 {
		t.Fatalf("Mong đợi một tài khoản khởi tạo, nhận %d", users)
	}
}
