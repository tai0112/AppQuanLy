package vn.lht.lht_money

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.DecimalFormat
import java.text.DecimalFormatSymbols
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import kotlin.math.max
import kotlin.math.min

/**
 * Widget màn hình chính: chi/thu kỳ này, biểu đồ cột chi tiêu theo Tuần/Tháng, số ngày yêu,
 * lịch trình hôm nay và nút thêm nhanh giao dịch.
 * Chỉ đọc dữ liệu app đã lưu sẵn (SharedPreferences) → không mạng, không chạy nền.
 * Mọi thứ phụ thuộc "hôm nay" được tính lại ở mỗi lần cập nhật nên vẫn đúng khi qua ngày mới.
 */
class LHTWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
    for (id in appWidgetIds) render(context, appWidgetManager, id, widgetData)
  }

  override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, newOptions: Bundle) {
    super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    render(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context)) // đổi kích thước → vẽ lại biểu đồ cho vừa
  }

  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action == ACTION_PERIOD) {
      context.getSharedPreferences(OWN_PREFS, Context.MODE_PRIVATE).edit().putString(KEY_PERIOD, intent.getStringExtra(KEY_PERIOD) ?: WEEK).apply()
      val mgr = AppWidgetManager.getInstance(context)
      onUpdate(context, mgr, mgr.getAppWidgetIds(ComponentName(context, LHTWidgetProvider::class.java)), HomeWidgetPlugin.getData(context))
      return
    }
    super.onReceive(context, intent)
  }

  private fun render(context: Context, mgr: AppWidgetManager, id: Int, d: SharedPreferences) {
    val today = LocalDate.now()
    val period = context.getSharedPreferences(OWN_PREFS, Context.MODE_PRIVATE).getString(KEY_PERIOD, WEEK) ?: WEEK
    val money = MoneyFmt(d)

    val monthEnd = date(d.getString("month_end", null))
    val monthValid = monthEnd != null && today.isBefore(monthEnd)
    val loveDays = date(d.getString("love_start", null))?.let { ChronoUnit.DAYS.between(it, today) + 1 }
    val events = (d.getString("events", "") ?: "")
      .split('\n')
      .mapNotNull { line -> line.split('|', limit = 3).takeIf { it.size == 3 && it[0] == today.toString() } }
      .take(2)
      .joinToString("\n") { "${it[1]}  ${it[2]}" }

    // Biểu đồ: các ngày của tuần/kỳ tháng chứa hôm nay
    val daily = HashMap<String, Double>()
    (d.getString("daily_expense", "") ?: "").split('\n').forEach { line ->
      val p = line.split('|')
      if (p.size == 2) p[1].toDoubleOrNull()?.let { daily[p[0]] = it }
    }
    val (start, end) = if (period == MONTH) monthRange(today, int(d, "month_start_day", 1)) else weekRange(today, int(d, "first_day_of_week", 1))
    val days = generateSequence(start) { it.plusDays(1) }.takeWhile { it.isBefore(end) }.toList()
    val values = days.map { daily[it.toString()] ?: 0.0 }

    val v = RemoteViews(context.packageName, R.layout.lht_widget)
    v.setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
    v.setOnClickPendingIntent(R.id.add_expense, launch(context, "lhtmoney://tx/add?type=1"))
    v.setOnClickPendingIntent(R.id.add_income, launch(context, "lhtmoney://tx/add?type=2"))
    v.setOnClickPendingIntent(R.id.seg_week, periodIntent(context, WEEK, 1))
    v.setOnClickPendingIntent(R.id.seg_month, periodIntent(context, MONTH, 2))
    v.setInt(R.id.seg_week, "setBackgroundResource", if (period == WEEK) R.drawable.lht_widget_seg_on else 0)
    v.setInt(R.id.seg_month, "setBackgroundResource", if (period == MONTH) R.drawable.lht_widget_seg_on else 0)
    v.setTextColor(R.id.seg_week, if (period == WEEK) ACCENT else MUTED)
    v.setTextColor(R.id.seg_month, if (period == MONTH) ACCENT else MUTED)

    v.setTextViewText(R.id.month_label, if (monthValid) d.getString("month_label", "") else "Mở app để cập nhật")
    v.setTextViewText(R.id.expense, if (monthValid) d.getString("month_expense", "—") else "—")
    v.setTextViewText(R.id.income, if (monthValid) d.getString("month_income", "—") else "—")
    v.setTextViewText(R.id.chart_title, if (period == MONTH) "Chi kỳ này" else "Chi tuần này")
    v.setTextViewText(R.id.chart_total, money.full(values.sum()))
    if (loveDays != null && loveDays > 0) {
      v.setViewVisibility(R.id.love, View.VISIBLE)
      v.setTextViewText(R.id.love, "♥ $loveDays ngày")
    } else {
      v.setViewVisibility(R.id.love, View.GONE)
    }
    v.setTextViewText(R.id.events, events.ifEmpty { "Không có lịch trình" })

    val opts = mgr.getAppWidgetOptions(id)
    // Dọc màn hình: rộng = MIN_WIDTH, cao = MAX_HEIGHT. Biểu đồ lấp phần còn lại sau các dòng chữ (~180dp).
    val widthDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0).takeIf { it > 0 } ?: 300
    val heightDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0).takeIf { it > 0 } ?: 250
    val chartDp = (heightDp - OTHER_CONTENT_DP).coerceIn(48, 160)
    v.setImageViewBitmap(R.id.chart, drawChart(context, widthDp - 28, chartDp, days, values, today, period, money))
    mgr.updateAppWidget(id, v)
  }

  /** Vẽ biểu đồ cột thành ảnh nhỏ. Màu chọn để đọc được trên cả nền sáng lẫn tối (ảnh không tự đổi theo theme). */
  private fun drawChart(context: Context, wDp: Int, hDp: Int, days: List<LocalDate>, values: List<Double>, today: LocalDate, period: String, money: MoneyFmt): Bitmap {
    val scale = min(context.resources.displayMetrics.density, 2.5f) // giới hạn độ phân giải → ảnh nhẹ
    val w = max(wDp, 120) * scale
    val h = hDp * scale
    val bmp = Bitmap.createBitmap(w.toInt(), h.toInt(), Bitmap.Config.ARGB_8888)
    val c = Canvas(bmp)
    val labelH = 13 * scale
    val topPad = 13 * scale
    val chartH = h - labelH - topPad
    val n = values.size
    val slot = w / n
    val barW = min(slot * (if (n > 10) 0.62f else 0.5f), 22 * scale)
    val maxV = values.maxOrNull()?.takeIf { it > 0 } ?: 1.0
    val r = min(barW / 2, 4 * scale)

    val bar = Paint(Paint.ANTI_ALIAS_FLAG)
    val text = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 9.5f * scale; textAlign = Paint.Align.CENTER; color = MUTED }
    val value = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 9.5f * scale; textAlign = Paint.Align.CENTER; color = EXPENSE; typeface = Typeface.DEFAULT_BOLD }
    val weekNames = arrayOf("T2", "T3", "T4", "T5", "T6", "T7", "CN")
    val todayIdx = days.indexOf(today)

    for (i in 0 until n) {
      val cx = slot * i + slot / 2
      val day = days[i]
      val bh = max((values[i] / maxV * chartH).toFloat(), 2.5f * scale) // ngày 0đ vẫn có vạch mờ để thấy nhịp của kỳ
      bar.color = when {
        day == today -> EXPENSE
        day.isAfter(today) -> FUTURE
        values[i] <= 0 -> FUTURE
        else -> EXPENSE_SOFT
      }
      c.drawRoundRect(RectF(cx - barW / 2, topPad + chartH - bh, cx + barW / 2, topPad + chartH), r, r, bar)

      val showLabel = if (n <= 10) true else (i == 0 || i == todayIdx || ((i % 5 == 4) && kotlin.math.abs(i - todayIdx) > 2))
      if (showLabel) {
        val label = if (period == MONTH) day.dayOfMonth.toString() else weekNames[day.dayOfWeek.value - 1]
        text.color = if (day == today) EXPENSE else MUTED
        text.typeface = if (day == today) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
        c.drawText(label, cx, h - 2 * scale, text)
      }
    }
    // Số tiền hôm nay trên đỉnh cột (dạng rút gọn), kẹp trong khung để không bị cắt ở mép
    if (todayIdx >= 0 && values[todayIdx] > 0) {
      val cx = slot * todayIdx + slot / 2
      val bh = (values[todayIdx] / maxV * chartH).toFloat()
      val s = money.compact(values[todayIdx])
      val half = value.measureText(s) / 2
      c.drawText(s, cx.coerceIn(half, w - half), max(topPad + chartH - bh - 3 * scale, value.textSize), value)
    }
    return bmp
  }

  private fun launch(context: Context, uri: String): PendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))

  private fun periodIntent(context: Context, period: String, code: Int): PendingIntent {
    val i = Intent(context, LHTWidgetProvider::class.java).setAction(ACTION_PERIOD).putExtra(KEY_PERIOD, period)
    var flags = PendingIntent.FLAG_UPDATE_CURRENT
    if (Build.VERSION.SDK_INT >= 23) flags = flags or PendingIntent.FLAG_IMMUTABLE
    return PendingIntent.getBroadcast(context, code, i, flags)
  }

  private fun weekRange(today: LocalDate, firstDay: Int): Pair<LocalDate, LocalDate> {
    val s = today.minusDays(((today.dayOfWeek.value - firstDay + 7) % 7).toLong())
    return s to s.plusDays(7)
  }

  /** Giống Finance.monthRange bên app: kỳ tháng bắt đầu từ ngày cấu hình. */
  private fun monthRange(today: LocalDate, startDay: Int): Pair<LocalDate, LocalDate> {
    fun at(m: LocalDate) = m.withDayOfMonth(min(startDay.coerceAtLeast(1), m.lengthOfMonth()))
    var s = at(today)
    if (today.isBefore(s)) s = at(today.minusMonths(1))
    return s to at(s.plusMonths(1))
  }

  private fun date(s: String?): LocalDate? = s?.takeIf { it.isNotEmpty() }?.let { runCatching { LocalDate.parse(it) }.getOrNull() }

  private fun int(d: SharedPreferences, key: String, def: Int) = runCatching { d.getInt(key, def) }.getOrDefault(def)

  /** Định dạng tiền giống Fmt.money của app (kiểu vi-VN: 1.234.567 ₫). */
  private class MoneyFmt(d: SharedPreferences) {
    private val symbol = d.getString("cur_symbol", "₫") ?: "₫"
    private val before = runCatching { d.getBoolean("cur_before", false) }.getOrDefault(false)
    private val decimals = runCatching { d.getInt("cur_decimals", 0) }.getOrDefault(0)
    private val sym = DecimalFormatSymbols().apply { groupingSeparator = '.'; decimalSeparator = ',' }

    fun full(v: Double): String {
      val f = DecimalFormat(if (decimals > 0) "#,##0." + "0".repeat(decimals) else "#,##0", sym)
      val s = f.format(v)
      return if (before) "$symbol$s" else "$s $symbol"
    }

    fun compact(v: Double): String {
      val f = DecimalFormat("#,##0.#", sym)
      return when {
        v >= 1_000_000_000 -> f.format(v / 1_000_000_000) + "tỷ"
        v >= 1_000_000 -> f.format(v / 1_000_000) + "tr"
        v >= 1_000 -> DecimalFormat("#,##0", sym).format(v / 1_000) + "k"
        else -> DecimalFormat("#,##0", sym).format(v)
      }
    }
  }

  companion object {
    private const val ACTION_PERIOD = "vn.lht.lht_money.WIDGET_PERIOD"
    private const val OWN_PREFS = "lht_widget"
    private const val KEY_PERIOD = "period"
    private const val WEEK = "week"
    private const val MONTH = "month"
    private const val OTHER_CONTENT_DP = 182

    // Màu trung tính đọc được trên cả nền sáng và tối
    private val EXPENSE = Color.parseColor("#F0534F")
    private val EXPENSE_SOFT = Color.parseColor("#8CF0534F")
    private val FUTURE = Color.parseColor("#338A9199")
    private val MUTED = Color.parseColor("#8A9199")
    private val ACCENT = Color.parseColor("#12A594")
  }
}
