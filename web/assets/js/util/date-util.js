const oneMinute = 1000 * 60; // Số mili giây trong một phút
const oneHour = oneMinute * 60; // Số mili giây trong một giờ
const oneDay = oneHour * 24; // Số mili giây trong một ngày
const oneWeek = oneDay * 7; // Số mili giây trong một tuần
const oneMonth = oneDay * 30; // Số mili giây trong một tháng (30 ngày)

/**
 * Trừ số ngày
 *
 * @param days Số ngày cần trừ
 */
Date.prototype.minusDays = function (days) {
    return this.minusMillis(oneDay * days);
};

/**
 * Cộng số ngày
 *
 * @param days Số ngày cần cộng
 */
Date.prototype.plusDays = function (days) {
    return this.plusMillis(oneDay * days);
};

/**
 * Trừ số giờ
 *
 * @param hours Số giờ cần trừ
 */
Date.prototype.minusHours = function (hours) {
    return this.minusMillis(oneHour * hours);
};

/**
 * Cộng số giờ
 *
 * @param hours Số giờ cần cộng
 */
Date.prototype.plusHours = function (hours) {
    return this.plusMillis(oneHour * hours);
};

/**
 * Trừ số phút
 *
 * @param minutes Số phút cần trừ
 */
Date.prototype.minusMinutes = function (minutes) {
    return this.minusMillis(oneMinute * minutes);
};

/**
 * Cộng số phút
 *
 * @param minutes Số phút cần cộng
 */
Date.prototype.plusMinutes = function (minutes) {
    return this.plusMillis(oneMinute * minutes);
};

/**
 * Trừ số mili giây
 *
 * @param millis Số mili giây cần trừ
 */
Date.prototype.minusMillis = function(millis) {
    let time = this.getTime() - millis;
    let newDate = new Date();
    newDate.setTime(time);
    return newDate;
};

/**
 * Cộng số mili giây
 *
 * @param millis Số mili giây cần cộng
 */
Date.prototype.plusMillis = function(millis) {
    let time = this.getTime() + millis;
    let newDate = new Date();
    newDate.setTime(time);
    return newDate;
};

/**
 * Đặt thời gian về đầu ngày: 00:00:00.000
 */
Date.prototype.setMinTime = function () {
    this.setHours(0);
    this.setMinutes(0);
    this.setSeconds(0);
    this.setMilliseconds(0);
    return this;
};

/**
 * Đặt thời gian về cuối ngày: 23:59:59.999
 */
Date.prototype.setMaxTime = function () {
    this.setHours(23);
    this.setMinutes(59);
    this.setSeconds(59);
    this.setMilliseconds(999);
    return this;
};

/**
 * Định dạng ngày tháng
 */
Date.prototype.formatDate = function () {
    return this.getFullYear() + "-" + addZero(this.getMonth() + 1) + "-" + addZero(this.getDate());
};

/**
 * Định dạng thời gian
 */
Date.prototype.formatTime = function () {
    return addZero(this.getHours()) + ":" + addZero(this.getMinutes()) + ":" + addZero(this.getSeconds());
};

/**
 * Định dạng ngày và thời gian
 *
 * @param split Ký tự phân tách ngày và giờ, mặc định là một khoảng trắng
 */
Date.prototype.formatDateTime = function (split = ' ') {
    return this.formatDate() + split + this.formatTime();
};

class DateUtil {

    // Chuyển chuỗi thành đối tượng Date
    static parseDate(str) {
        return new Date(str.replace(/-/g, '/'));
    }

    static formatMillis(millis) {
        return moment(millis).format('YYYY-M-D H:m:s')
    }

    static firstDayOfMonth() {
        const date = new Date();
        date.setDate(1);
        date.setMinTime();
        return date;
    }
}
