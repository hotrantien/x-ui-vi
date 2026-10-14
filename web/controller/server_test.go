package controller

import (
	"encoding/json"
	"net/http/httptest"
	"strings"
	"testing"
	"x-ui/web/entity"

	"github.com/gin-gonic/gin"
)

func TestXrayVersionEndpointsReportDisabledOnlineManagement(t *testing.T) {
	gin.SetMode(gin.TestMode)
	a := &ServerController{}
	for _, test := range []struct {
		name   string
		handle gin.HandlerFunc
		prefix string
	}{
		{"get versions", a.getXrayVersion, "Lấy phiên bản thất bại:"},
		{"install version", a.installXray, "Cài đặt Xray thất bại:"},
	} {
		t.Run(test.name, func(t *testing.T) {
			recorder := httptest.NewRecorder()
			ctx, _ := gin.CreateTestContext(recorder)
			ctx.Params = gin.Params{{Key: "version", Value: "v99.0.0"}}
			test.handle(ctx)
			var response entity.Msg
			if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
				t.Fatalf("decode response: %v", err)
			}
			if response.Success || !strings.HasPrefix(response.Msg, test.prefix) ||
				!strings.Contains(response.Msg, "Xray trực tuyến") {
				t.Fatalf("unexpected API response: %#v", response)
			}
		})
	}
}
