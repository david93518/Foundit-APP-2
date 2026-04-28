package com.example.foundit.util

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit

/** Long (timestamp ms) → 易讀時間字串 */
fun Long.toDateString(pattern: String = "yyyy/MM/dd HH:mm"): String {
    val sdf = SimpleDateFormat(pattern, Locale.TAIWAN)
    return sdf.format(Date(this))
}

/** 計算距離現在的相對時間（幾分鐘前、幾小時前等）*/
fun Long.toRelativeTime(): String {
    val now = System.currentTimeMillis()
    val diff = now - this
    return when {
        diff < TimeUnit.MINUTES.toMillis(1) -> "剛剛"
        diff < TimeUnit.HOURS.toMillis(1) -> "${TimeUnit.MILLISECONDS.toMinutes(diff)} 分鐘前"
        diff < TimeUnit.DAYS.toMillis(1) -> "${TimeUnit.MILLISECONDS.toHours(diff)} 小時前"
        diff < TimeUnit.DAYS.toMillis(7) -> "${TimeUnit.MILLISECONDS.toDays(diff)} 天前"
        else -> this.toDateString("MM/dd")
    }
}

/** 手機號碼格式化（顯示用，隱藏中間 4 位）*/
fun String.maskPhoneNumber(): String {
    if (length < 10) return this
    return "${take(4)}****${takeLast(3)}"
}

/** 金額格式化（加入千分位）*/
fun Int.toCurrencyString(): String {
    return "NT\$ %,d".format(this)
}

/** 確認字串非空白 */
fun String?.isNotBlankOrNull(): Boolean = !this.isNullOrBlank()

/** 截斷過長文字 */
fun String.truncate(maxLength: Int = 50): String {
    return if (length > maxLength) "${take(maxLength)}…" else this
}
