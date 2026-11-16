extends Control
## Your riding over time, like a training log: this week and
## last, weeks in a row, totals, fitness and form, and every ride (newest first). Click a ride for its
## details. Pretend-trainer rides are marked.

const Style = preload("res://ui/style.gd")
const FormChart = preload("res://ui/form_chart.gd")

const DAYS_SV := ["mån", "tis", "ons", "tors", "fre", "lör", "sön"]
const MONTHS_SV := ["jan", "feb", "mar", "apr", "maj", "jun", "jul", "aug", "sep", "okt", "nov", "dec"]

var app
var args := {}


func _ready() -> void:
    var root := Style.vbox(16)
    add_child(Style.margin(root, 32))
    root.add_child(Style.header(tr("Historik"), tr("Meny"), func(): app.go("menu")))

    var top := Style.hbox(14)
    top.add_child(_week_card(tr("DEN HÄR VECKAN"), Progress.week_totals(0)))
    top.add_child(_week_card(tr("FÖRRA VECKAN"), Progress.week_totals(1)))
    var life := Progress.lifetime()
    var streak := Progress.streak_weeks()
    top.add_child(_card(tr("SVIT"), tr("%d veckor i rad") % streak if streak != 1 else tr("1 vecka"),
        tr("med minst en tur i veckan")))
    top.add_child(_card(tr("TOTALT"), rides_text(life["rides"]),
        "%s  ·  %s km  ·  %d hm" % [Style.minutes(life["seconds"]), Style.dec(life["km"], 0), roundi(life["elev"])]))
    root.add_child(top)

    var chart := FormChart.new()
    chart.data = Progress.fitness(90)
    chart.custom_minimum_size = Vector2(0, 170)
    root.add_child(chart)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    var list := Style.vbox(8)
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(list)
    root.add_child(scroll)
    var rides: Array = Progress.data["rides"]
    if rides.is_empty():
        list.add_child(Style.label(tr("Inga turer än. När du har cyklat syns de här, med tid, watt, XP och rekord."), 18, Style.TEXT_DIM, 600))
    for i in range(rides.size() - 1, -1, -1):
        list.add_child(_ride_row(rides[i]))


func _card(title: String, big: String, small: String) -> Control:
    var card := Style.panel(Style.PANEL, 14, 14)
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var box := Style.vbox(2)
    card.add_child(box)
    box.add_child(Style.label(title, 12, Style.TEXT_DIM, 800))
    box.add_child(Style.label(big, 24, Style.TEXT, 900))
    var s := Style.label(small, 14, Style.TEXT_DIM, 600)
    s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(s)
    return card


func _week_card(title: String, w: Dictionary) -> Control:
    return _card(title, Style.minutes(w["seconds"]) if w["seconds"] > 0 else "–",
        tr("%s  ·  %s km  ·  %d TSS") % [rides_text(w["rides"]), Style.dec(w["km"], 0), roundi(w["tss"])])


## "1 tur" / "3 turer" ("1 ride" / "3 rides").
static func rides_text(n: int) -> String:
    return str(TranslationServer.translate("%d tur" if n == 1 else "%d turer")) % n


static func when(t: float) -> String:
    var bias := float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0
    var d := Time.get_datetime_dict_from_unix_time(int(t + bias))
    var weekday := (int(d["weekday"]) + 6) % 7          # Godot: 0 = Sunday
    return "%s %d %s  %02d:%02d" % [TranslationServer.translate(DAYS_SV[weekday]), d["day"],
        TranslationServer.translate(MONTHS_SV[int(d["month"]) - 1]), d["hour"], d["minute"]]


func _ride_row(r: Dictionary) -> Control:
    var card := PanelContainer.new()
    card.add_theme_stylebox_override("panel", Style.flat(Style.PANEL, 12, 12))
    var row := Style.hbox(18)
    card.add_child(row)
    var date := Style.label(when(float(r.get("date", 0.0))), 15, Style.TEXT_DIM, 700)
    date.custom_minimum_size.x = 150
    row.add_child(date)
    var text := Style.vbox(0)
    text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var title := Style.label(tr(str(r.get("name", ""))), 19, Style.TEXT, 800)
    title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    title.custom_minimum_size.x = 10
    text.add_child(title)
    var where: String = tr(str(r.get("world", ""))) if str(r.get("world", "")) != "" else tr("Gymskärm")
    var plan = r.get("plan")
    if plan is Array:
        var p: Dictionary = app.find_plan(plan[0])
        if not p.is_empty():
            where += "  ·  " + tr("Pass %d av %d i planen %s.") % [int(plan[1]) + 1, p["sessions"].size(), tr(p["name"])]
    text.add_child(Style.label(where, 14, Style.TEXT_DIM, 600))
    row.add_child(text)
    for fact in [[Style.clock(float(r.get("seconds", 0.0))), tr("tid")], [Style.dec(float(r.get("km", 0.0)), 1), "km"],
            ["%d" % roundi(float(r.get("avg_w", 0.0))), tr("W snitt")], ["%d" % roundi(float(r.get("tss", 0.0))), "TSS"],
            ["+%d" % int(r.get("xp", 0)), "XP"]]:
        var col := Style.vbox(-2)
        col.custom_minimum_size.x = 78
        col.add_child(Style.label(fact[0], 18, Style.TEXT, 800))
        col.add_child(Style.label(fact[1], 12, Style.TEXT_DIM, 700))
        row.add_child(col)
    var badges := Style.hbox(6)
    badges.custom_minimum_size.x = 210
    if r.get("completed", false):
        badges.add_child(_badge(tr("✓ Genomfört"), Style.ACCENT))
    var records: int = r.get("bests", []).size() + r.get("segments", []).filter(func(s): return s.get("pr", false)).size()
    if records > 0 and not r.get("pretend", false):
        badges.add_child(_badge("★ %d" % records, Color("ffd34d")))
    if str(r.get("strava", "")) != "":
        badges.add_child(_badge("Strava", Color("fc5200")))
    if r.get("pretend", false):
        badges.add_child(_badge(tr("Låtsas"), Color("8a8f9c")))
    row.add_child(badges)
    Style.clickable(card, func(): app.go("ride_detail", {"ride": r}))
    return card


func _badge(text: String, colour: Color) -> Control:
    var b := Style.panel(Color(colour, 0.22), 8, 6)
    b.add_child(Style.label(text, 13, colour.lightened(0.2), 800))
    b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    return b
