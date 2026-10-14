package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	_ "unsafe"
	"x-ui/config"
	"x-ui/database"
	"x-ui/logger"
	"x-ui/v2ui"
	"x-ui/web"
	"x-ui/web/global"
	"x-ui/web/service"

	"github.com/op/go-logging"
)

func runWebServer() {
	log.Printf("%v %v", config.GetName(), config.GetVersion())

	switch config.GetLogLevel() {
	case config.Debug:
		logger.InitLogger(logging.DEBUG)
	case config.Info:
		logger.InitLogger(logging.INFO)
	case config.Warn:
		logger.InitLogger(logging.WARNING)
	case config.Error:
		logger.InitLogger(logging.ERROR)
	default:
		log.Fatal("Cấp độ nhật ký không hợp lệ: ", config.GetLogLevel())
	}

	err := database.InitDB(config.GetDBPath())
	if err != nil {
		log.Fatal(err)
	}

	var server *web.Server

	server = web.NewServer()
	global.SetWebServer(server)
	err = server.Start()
	if err != nil {
		log.Println(err)
		return
	}

	sigCh := make(chan os.Signal, 1)
	// Xử lý tín hiệu hệ thống
	signal.Notify(sigCh, syscall.SIGHUP, syscall.SIGTERM, syscall.SIGKILL)
	for {
		sig := <-sigCh

		switch sig {
		case syscall.SIGHUP:
			err := server.Stop()
			if err != nil {
				logger.Warning("Không thể dừng máy chủ: ", err)
			}
			server = web.NewServer()
			global.SetWebServer(server)
			err = server.Start()
			if err != nil {
				log.Println(err)
				return
			}
		default:
			server.Stop()
			return
		}
	}
}

func resetSetting() {
	err := database.InitDB(config.GetDBPath())
	if err != nil {
		fmt.Println(err)
		return
	}

	settingService := service.SettingService{}
	err = settingService.ResetSettings()
	if err != nil {
		fmt.Println("Khôi phục cài đặt thất bại:", err)
	} else {
		fmt.Println("Đã khôi phục cài đặt thành công")
	}
}

func showSetting(show bool) {
	if show {
		settingService := service.SettingService{}
		port, err := settingService.GetPort()
		if err != nil {
			fmt.Println("Không lấy được cổng hiện tại:", err)
		}
		userService := service.UserService{}
		userModel, err := userService.GetFirstUser()
		if err != nil {
			fmt.Println("Không lấy được thông tin người dùng hiện tại:", err)
			return
		}
		username := userModel.Username
		userpasswd := userModel.Password
		if (username == "") || (userpasswd == "") {
			fmt.Println("Tên đăng nhập hoặc mật khẩu hiện tại đang trống")
		}
		fmt.Println("Cài đặt bảng điều khiển hiện tại:")
		fmt.Println("Tên đăng nhập:", username)
		fmt.Println("Mật khẩu:", userpasswd)
		fmt.Println("Cổng:", port)
	}
}

func updateTgbotEnableSts(status bool) {
	settingService := service.SettingService{}
	currentTgSts, err := settingService.GetTgbotenabled()
	if err != nil {
		fmt.Println(err)
		return
	}
	logger.Infof("Trạng thái bot Telegram hiện tại [%v], sẽ cập nhật thành [%v]", currentTgSts, status)
	if currentTgSts != status {
		err := settingService.SetTgbotenabled(status)
		if err != nil {
			fmt.Println(err)
			return
		} else {
			logger.Infof("Đã cập nhật trạng thái bot Telegram thành [%v]", status)
		}
	}
	return
}

func updateTgbotSetting(tgBotToken string, tgBotChatid int, tgBotRuntime string) {
	err := database.InitDB(config.GetDBPath())
	if err != nil {
		fmt.Println(err)
		return
	}

	settingService := service.SettingService{}

	if tgBotToken != "" {
		err := settingService.SetTgBotToken(tgBotToken)
		if err != nil {
			fmt.Println(err)
			return
		} else {
			logger.Info("Đã cập nhật mã token của bot Telegram")
		}
	}

	if tgBotRuntime != "" {
		err := settingService.SetTgbotRuntime(tgBotRuntime)
		if err != nil {
			fmt.Println(err)
			return
		} else {
			logger.Infof("Đã cập nhật lịch chạy bot Telegram [%s]", tgBotRuntime)
		}
	}

	if tgBotChatid != 0 {
		err := settingService.SetTgBotChatId(tgBotChatid)
		if err != nil {
			fmt.Println(err)
			return
		} else {
			logger.Info("Đã cập nhật ID cuộc trò chuyện Telegram")
		}
	}
}

func updateSetting(port int, username string, password string) {
	err := database.InitDB(config.GetDBPath())
	if err != nil {
		fmt.Println(err)
		return
	}

	settingService := service.SettingService{}

	if port > 0 {
		err := settingService.SetPort(port)
		if err != nil {
			fmt.Println("Cài đặt cổng thất bại:", err)
		} else {
			fmt.Printf("Đã đặt cổng thành %v\n", port)
		}
	}
	if username != "" || password != "" {
		userService := service.UserService{}
		err := userService.UpdateFirstUser(username, password)
		if err != nil {
			fmt.Println("Đổi tên đăng nhập và mật khẩu thất bại:", err)
		} else {
			fmt.Println("Đã đổi tên đăng nhập và mật khẩu")
		}
	}
}

func main() {
	if len(os.Args) < 2 {
		runWebServer()
		return
	}

	var showVersion bool
	flag.BoolVar(&showVersion, "v", false, "Xem phiên bản")

	runCmd := flag.NewFlagSet("run", flag.ExitOnError)

	v2uiCmd := flag.NewFlagSet("v2-ui", flag.ExitOnError)
	var dbPath string
	v2uiCmd.StringVar(&dbPath, "db", "/etc/v2-ui/v2-ui.db", "Đường dẫn cơ sở dữ liệu v2-ui")

	settingCmd := flag.NewFlagSet("setting", flag.ExitOnError)
	var port int
	var username string
	var password string
	var tgbottoken string
	var tgbotchatid int
	var enabletgbot bool
	var tgbotRuntime string
	var reset bool
	var show bool
	settingCmd.BoolVar(&reset, "reset", false, "Khôi phục tất cả cài đặt")
	settingCmd.BoolVar(&show, "show", false, "Xem cài đặt hiện tại")
	settingCmd.IntVar(&port, "port", 0, "Đặt cổng bảng điều khiển")
	settingCmd.StringVar(&username, "username", "", "Đặt tên đăng nhập")
	settingCmd.StringVar(&password, "password", "", "Đặt mật khẩu đăng nhập")
	settingCmd.StringVar(&tgbottoken, "tgbottoken", "", "Đặt token bot Telegram")
	settingCmd.StringVar(&tgbotRuntime, "tgbotRuntime", "", "Đặt lịch chạy bot Telegram")
	settingCmd.IntVar(&tgbotchatid, "tgbotchatid", 0, "Đặt ID cuộc trò chuyện Telegram")
	settingCmd.BoolVar(&enabletgbot, "enabletgbot", false, "Bật thông báo Telegram")

	oldUsage := flag.Usage
	flag.Usage = func() {
		oldUsage()
		fmt.Println()
		fmt.Println("Các lệnh:")
		fmt.Println("    run            Chạy bảng điều khiển web")
		fmt.Println("    v2-ui          Chuyển dữ liệu từ v2-ui")
		fmt.Println("    setting        Thay đổi cài đặt")
	}

	flag.Parse()
	if showVersion {
		fmt.Println(config.GetVersion())
		return
	}

	switch os.Args[1] {
	case "run":
		err := runCmd.Parse(os.Args[2:])
		if err != nil {
			fmt.Println(err)
			return
		}
		runWebServer()
	case "v2-ui":
		err := v2uiCmd.Parse(os.Args[2:])
		if err != nil {
			fmt.Println(err)
			return
		}
		err = v2ui.MigrateFromV2UI(dbPath)
		if err != nil {
			fmt.Println("Chuyển dữ liệu từ v2-ui thất bại:", err)
		}
	case "setting":
		err := settingCmd.Parse(os.Args[2:])
		if err != nil {
			fmt.Println(err)
			return
		}
		if reset {
			resetSetting()
		} else {
			updateSetting(port, username, password)
		}
		if show {
			showSetting(show)
		}
		if (tgbottoken != "") || (tgbotchatid != 0) || (tgbotRuntime != "") {
			updateTgbotSetting(tgbottoken, tgbotchatid, tgbotRuntime)
		}
	default:
		fmt.Println("Lệnh không hợp lệ. Hãy dùng 'run', 'v2-ui' hoặc 'setting'.")
		fmt.Println()
		runCmd.Usage()
		fmt.Println()
		v2uiCmd.Usage()
		fmt.Println()
		settingCmd.Usage()
	}
}
