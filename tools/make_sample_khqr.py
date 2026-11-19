"""Generate sample KHQR strings + PNGs for testing (fictional merchants)."""
import sys, time
def tlv(i, v): return f"{i}{len(v):02d}{v}"
def crc16(s):
    c = 0xFFFF
    for b in s.encode():
        c ^= b << 8
        for _ in range(8):
            c = ((c << 1) ^ 0x1021) & 0xFFFF if c & 0x8000 else (c << 1) & 0xFFFF
    return f"{c:04X}"
def khqr(dynamic, merchant, name, city, cur, amount=None, bill=None, expire_ms=None):
    acct = tlv("00", "sokha_cafe@rdlb") + (tlv("01", "1234567") + tlv("02", "Romdoul Bank") if merchant else "")
    s = tlv("00", "01") + tlv("01", "12" if dynamic else "11") + tlv("30" if merchant else "29", acct)
    s += tlv("52", "5999") + tlv("53", "116" if cur == "KHR" else "840")
    if amount is not None: s += tlv("54", amount)
    s += tlv("58", "KH") + tlv("59", name) + tlv("60", city)
    if bill: s += tlv("62", tlv("01", bill) + tlv("03", "Riverside"))
    if expire_ms: s += tlv("99", tlv("00", str(int(time.time()*1000))) + tlv("01", str(expire_ms)))
    s += "6304"
    return s + crc16(s)
if __name__ == "__main__":
    assert crc16("123456789") == "29B1", "CRC-16/CCITT-FALSE check value"
    samples = {
        "static_khr_individual": khqr(False, False, "DARA SOK", "Phnom Penh", "KHR"),
        "dynamic_usd_merchant": khqr(True, True, "SOKHA CAFE", "Phnom Penh", "USD", "2.50", "INV-1024", 4102444800000),
        "dynamic_khr_merchant": khqr(True, True, "SOKHA CAFE", "Siem Reap", "KHR", "20000", "INV-1025", 4102444800000),
        "expired_usd": khqr(True, True, "OLD SHOP", "Kampot", "USD", "5.00", None, 1600000000000),
    }
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    import qrcode
    for k, v in samples.items():
        print(f"{k}: {v}")
        qrcode.make(v, box_size=10, border=4).save(f"{out}/{k}.png")
