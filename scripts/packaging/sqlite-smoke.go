//go:build ignore
// +build ignore

package main

import (
	"fmt"
	"os"
	"path/filepath"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func main() {
	directory, err := os.MkdirTemp("", "x-ui-sqlite-")
	if err != nil {
		panic(err)
	}
	defer os.RemoveAll(directory)

	database, err := gorm.Open(sqlite.Open(filepath.Join(directory, "test.db")), &gorm.Config{})
	if err != nil {
		panic(fmt.Errorf("SQLite CGO không mở được DB: %w", err))
	}
	if err := database.Exec("CREATE TABLE probes (value INTEGER NOT NULL)").Error; err != nil {
		panic(fmt.Errorf("SQLite CREATE thất bại: %w", err))
	}
	if err := database.Exec("INSERT INTO probes(value) VALUES (42)").Error; err != nil {
		panic(fmt.Errorf("SQLite INSERT thất bại: %w", err))
	}
	var result int
	if err := database.Raw("SELECT value FROM probes LIMIT 1").Scan(&result).Error; err != nil {
		panic(fmt.Errorf("SQLite SELECT thất bại: %w", err))
	}
	if result != 42 {
		panic(fmt.Errorf("SQLite trả về %d, mong đợi 42", result))
	}
	fmt.Println("PASS: SQLite CGO đã CREATE/INSERT/SELECT trên DB tạm.")
}
