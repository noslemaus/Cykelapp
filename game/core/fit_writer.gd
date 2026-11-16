extends RefCounted
## Minimal FIT activity encoder (Garmin FIT protocol 2.0): file_id, start/stop events,
## one record per second, one lap per workout segment, a session and an activity message.
## Strava, Garmin Connect and the garmin-dashboard decoder all read this subset.

const FIT_EPOCH := 631065600   # 1989-12-31 00:00:00 UTC as unix time
const PROFILE_VERSION := 2160

const ENUM := 0x00
const UINT8 := 0x02
const UINT16 := 0x84
const UINT32 := 0x86
const UINT32Z := 0x8C

const SPORT_CYCLING := 2
const SUB_SPORT_INDOOR := 6
const SUB_SPORT_VIRTUAL := 58   # Strava shows these as Virtual Ride

const CRC_TABLE: Array[int] = [
    0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
    0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400,
]

# [local type, global message number, [[field number, base type], ...]]
const FILE_ID := [0, 0, [[0, ENUM], [1, UINT16], [2, UINT16], [3, UINT32Z], [4, UINT32]]]
const EVENT := [1, 21, [[253, UINT32], [0, ENUM], [1, ENUM]]]
const RECORD := [2, 20, [[253, UINT32], [7, UINT16], [4, UINT8], [3, UINT8], [6, UINT16], [5, UINT32], [2, UINT16]]]
const LAP := [3, 19, [[253, UINT32], [254, UINT16], [0, ENUM], [1, ENUM], [2, UINT32], [7, UINT32], [8, UINT32],
    [9, UINT32], [19, UINT16], [20, UINT16], [15, UINT8], [16, UINT8], [17, UINT8], [25, ENUM]]]
const SESSION := [4, 18, [[253, UINT32], [254, UINT16], [0, ENUM], [1, ENUM], [2, UINT32], [5, ENUM], [6, ENUM],
    [7, UINT32], [8, UINT32], [9, UINT32], [11, UINT16], [14, UINT16], [15, UINT16], [16, UINT8], [17, UINT8],
    [18, UINT8], [20, UINT16], [21, UINT16], [22, UINT16], [25, UINT16], [26, UINT16], [34, UINT16], [35, UINT16],
    [36, UINT16], [45, UINT16]]]
const ACTIVITY := [5, 34, [[253, UINT32], [0, UINT32], [1, UINT16], [2, ENUM], [3, ENUM], [4, ENUM], [5, UINT32]]]

var _body := StreamPeerBuffer.new()


## samples: [{"t": unix, "power", "cadence", "hr", "speed" (m/s), "distance" (m), "altitude" (m)}]
## laps: [{"first": sample index, "last": sample index (inclusive)}]
## summary: the ride summary dictionary from Ride.
func encode(samples: Array, laps: Array, summary: Dictionary) -> PackedByteArray:
    _body = StreamPeerBuffer.new()
    _body.big_endian = false
    if samples.is_empty():
        return PackedByteArray()
    var start := _fit_time(samples[0]["t"])
    var end := _fit_time(samples[-1]["t"])

    _message(FILE_ID, [4, 255, 1, 1, start])   # activity file, manufacturer "development"
    _message(EVENT, [start, 0, 0])              # timer start
    _define(RECORD)
    for s in samples:
        _data(RECORD, [_fit_time(s["t"]), s["power"], s["cadence"], s["hr"] if s["hr"] > 0 else null,
            roundi(s["speed"] * 1000.0), roundi(s["distance"] * 100.0), roundi((s["altitude"] + 500.0) * 5.0)])
    _message(EVENT, [end, 0, 4])                # timer stop_all

    _define(LAP)
    for i in laps.size():
        var lap: Dictionary = laps[i]
        var part := samples.slice(lap["first"], lap["last"] + 1)
        var st := _stats(part)
        var lap_start := _fit_time(part[0]["t"])
        var lap_end := _fit_time(part[-1]["t"])
        var seconds := (lap_end - lap_start + 1) * 1000
        var distance: float = part[-1]["distance"] - (samples[lap["first"] - 1]["distance"] if lap["first"] > 0 else 0.0)
        _data(LAP, [lap_end, i, 9, 1, lap_start, seconds, seconds, roundi(distance * 100.0),
            st["avg_power"], st["max_power"], st["avg_hr"], st["max_hr"], st["avg_cadence"], SPORT_CYCLING])

    var all := _stats(samples)
    var elapsed := (end - start + 1) * 1000
    var timer := roundi(summary.get("moving_time", end - start + 1) * 1000.0)
    var sub_sport := SUB_SPORT_VIRTUAL if str(summary.get("world", "")) != "" else SUB_SPORT_INDOOR
    _message(SESSION, [end, 0, 8, 1, start, SPORT_CYCLING, sub_sport, elapsed, timer,
        roundi(samples[-1]["distance"] * 100.0), roundi(summary.get("kj", 0.0)),
        roundi(all["avg_speed"] * 1000.0), roundi(all["max_speed"] * 1000.0), all["avg_hr"], all["max_hr"],
        all["avg_cadence"], roundi(summary.get("avg_power", all["avg_power"])), all["max_power"], roundi(summary.get("elevation_gain", 0.0)),
        0, laps.size(), roundi(summary.get("np", 0.0)), roundi(summary.get("tss", 0.0) * 10.0),
        roundi(summary.get("if", 0.0) * 1000.0), summary.get("ftp", null)])
    var local_offset: int = Time.get_time_zone_from_system().get("bias", 0) * 60
    _message(ACTIVITY, [end, timer, 1, 0, 26, 1, end + local_offset])

    var body := _body.data_array
    var header := StreamPeerBuffer.new()
    header.big_endian = false
    header.put_u8(14)
    header.put_u8(0x20)
    header.put_u16(PROFILE_VERSION)
    header.put_u32(body.size())
    header.put_data(".FIT".to_ascii_buffer())
    header.put_u16(crc16(header.data_array))
    var out := header.data_array + body
    var crc := crc16(out)
    out.append(crc & 0xFF)
    out.append(crc >> 8)
    return out


func _fit_time(unix: float) -> int:
    return int(unix) - FIT_EPOCH


func _stats(part: Array) -> Dictionary:
    var p_sum := 0.0
    var p_max := 0
    var hr_sum := 0.0
    var hr_n := 0
    var hr_max := 0
    var cad_sum := 0.0
    var cad_n := 0
    var v_sum := 0.0
    var v_max := 0.0
    for s in part:
        p_sum += s["power"]
        p_max = maxi(p_max, s["power"])
        v_sum += s["speed"]
        v_max = maxf(v_max, s["speed"])
        if s["hr"] > 0:
            hr_sum += s["hr"]
            hr_n += 1
            hr_max = maxi(hr_max, s["hr"])
        if s["cadence"] > 0:
            cad_sum += s["cadence"]
            cad_n += 1
    var n := maxi(part.size(), 1)
    return {
        "avg_power": roundi(p_sum / n),
        "max_power": p_max,
        "avg_hr": roundi(hr_sum / hr_n) if hr_n > 0 else null,
        "max_hr": hr_max if hr_n > 0 else null,
        "avg_cadence": roundi(cad_sum / cad_n) if cad_n > 0 else null,
        "avg_speed": v_sum / n,
        "max_speed": v_max,
    }


func _message(def: Array, values: Array) -> void:
    _define(def)
    _data(def, values)


func _define(def: Array) -> void:
    var fields: Array = def[2]
    _body.put_u8(0x40 | def[0])
    _body.put_u8(0)            # reserved
    _body.put_u8(0)            # little endian
    _body.put_u16(def[1])
    _body.put_u8(fields.size())
    for f in fields:
        _body.put_u8(f[0])
        _body.put_u8(_size(f[1]))
        _body.put_u8(f[1])


func _data(def: Array, values: Array) -> void:
    var fields: Array = def[2]
    _body.put_u8(def[0])
    for i in fields.size():
        var v = values[i]
        match fields[i][1]:
            ENUM, UINT8:
                _body.put_u8(0xFF if v == null else clampi(int(v), 0, 0xFE))
            UINT16:
                _body.put_u16(0xFFFF if v == null else clampi(int(v), 0, 0xFFFE))
            UINT32:
                _body.put_u32(0xFFFFFFFF if v == null else clampi(int(v), 0, 0xFFFFFFFE))
            UINT32Z:
                _body.put_u32(0 if v == null else int(v))


func _size(base_type: int) -> int:
    match base_type:
        UINT16:
            return 2
        UINT32, UINT32Z:
            return 4
    return 1


## Garmin's CRC-16 over the given bytes.
static func crc16(bytes: PackedByteArray) -> int:
    var crc := 0
    for b in bytes:
        var tmp := CRC_TABLE[crc & 0xF]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ CRC_TABLE[b & 0xF]
        tmp = CRC_TABLE[crc & 0xF]
        crc = (crc >> 4) & 0x0FFF
        crc = crc ^ tmp ^ CRC_TABLE[(b >> 4) & 0xF]
    return crc
