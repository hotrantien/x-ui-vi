moment.defineLocale('vi', {
    months: 'tháng 1_tháng 2_tháng 3_tháng 4_tháng 5_tháng 6_tháng 7_tháng 8_tháng 9_tháng 10_tháng 11_tháng 12'.split('_'),
    monthsShort: 'thg 1_thg 2_thg 3_thg 4_thg 5_thg 6_thg 7_thg 8_thg 9_thg 10_thg 11_thg 12'.split('_'),
    weekdays: 'chủ nhật_thứ hai_thứ ba_thứ tư_thứ năm_thứ sáu_thứ bảy'.split('_'),
    weekdaysShort: 'CN_T2_T3_T4_T5_T6_T7'.split('_'),
    weekdaysMin: 'CN_T2_T3_T4_T5_T6_T7'.split('_'),
    longDateFormat: {
        LT: 'HH:mm',
        LTS: 'HH:mm:ss',
        L: 'DD/MM/YYYY',
        LL: 'D MMMM [năm] YYYY',
        LLL: 'D MMMM [năm] YYYY HH:mm',
        LLLL: 'dddd, D MMMM [năm] YYYY HH:mm'
    },
    calendar: {
        sameDay: '[Hôm nay lúc] LT',
        nextDay: '[Ngày mai lúc] LT',
        nextWeek: 'dddd [lúc] LT',
        lastDay: '[Hôm qua lúc] LT',
        lastWeek: 'dddd [tuần trước lúc] LT',
        sameElse: 'L'
    },
    relativeTime: {
        future: '%s nữa',
        past: '%s trước',
        s: 'vài giây',
        ss: '%d giây',
        m: 'một phút',
        mm: '%d phút',
        h: 'một giờ',
        hh: '%d giờ',
        d: 'một ngày',
        dd: '%d ngày',
        M: 'một tháng',
        MM: '%d tháng',
        y: 'một năm',
        yy: '%d năm'
    },
    week: { dow: 1, doy: 4 }
});
moment.locale('vi');

const uiLocale = {
    ...antd.locales.vi_VN,
    Table: {
        ...antd.locales.vi_VN.Table,
        filterTitle: 'Bộ lọc',
        filterReset: 'Đặt lại',
        filterConfirm: 'Xác nhận',
        selectAll: 'Chọn tất cả',
        selectInvert: 'Đảo ngược lựa chọn'
    },
    Modal: {
        okText: 'Xác nhận',
        cancelText: 'Hủy',
        justOkText: 'Đã hiểu'
    },
    Popconfirm: {
        okText: 'Xác nhận',
        cancelText: 'Hủy'
    },
    DatePicker: {
        ...antd.locales.vi_VN.DatePicker,
        lang: {
            ...antd.locales.vi_VN.DatePicker.lang,
            ok: 'Xác nhận'
        }
    }
};
