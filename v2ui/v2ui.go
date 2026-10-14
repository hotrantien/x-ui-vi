package v2ui

import (
	"fmt"
	"x-ui/config"
	"x-ui/database"
	"x-ui/database/model"
	"x-ui/util/common"
	"x-ui/web/service"
)

func MigrateFromV2UI(dbPath string) error {
	err := initDB(dbPath)
	if err != nil {
		return common.NewError("Không thể khởi tạo cơ sở dữ liệu v2-ui:", err)
	}
	err = database.InitDB(config.GetDBPath())
	if err != nil {
		return common.NewError("Không thể khởi tạo cơ sở dữ liệu x-ui:", err)
	}

	v2Inbounds, err := getV2Inbounds()
	if err != nil {
		return common.NewError("Không thể lấy kết nối vào từ v2-ui:", err)
	}
	if len(v2Inbounds) == 0 {
		fmt.Println("Đã chuyển 0 kết nối vào từ v2-ui")
		return nil
	}

	userService := service.UserService{}
	user, err := userService.GetFirstUser()
	if err != nil {
		return common.NewError("Không thể lấy tài khoản x-ui:", err)
	}

	inbounds := make([]*model.Inbound, 0)
	for _, v2inbound := range v2Inbounds {
		inbounds = append(inbounds, v2inbound.ToInbound(user.Id))
	}

	inboundService := service.InboundService{}
	err = inboundService.AddInbounds(inbounds)
	if err != nil {
		return common.NewError("Không thể thêm kết nối vào x-ui:", err)
	}

	fmt.Println("Số kết nối vào đã chuyển từ v2-ui:", len(inbounds))

	return nil
}
