"""Minimal PNG reading and writing with only the Python standard library.

Reads 8-bit RGB, RGBA, grey and palette PNGs (non-interlaced) and writes
8-bit RGBA. Used by the placeholder maker and the art cleanup tool, so no
add-on library is needed.
"""
import struct
import zlib


def write_png(path, width, height, rgba):
    """rgba is a bytes-like of width*height*4 values."""
    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw.extend(rgba[y * stride:(y + 1) * stride])

    def chunk(kind, data):
        c = struct.pack(">I", len(data)) + kind + data
        return c + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    out = b"\x89PNG\r\n\x1a\n"
    out += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    out += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    out += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(out)


def _paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def read_png(path):
    """Returns (width, height, bytearray RGBA)."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG: %s" % path)
    pos = 8
    idat = bytearray()
    palette = None
    trns = None
    width = height = bitdepth = ctype = interlace = None
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, bitdepth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
        elif kind == b"PLTE":
            palette = body
        elif kind == b"tRNS":
            trns = body
        elif kind == b"IDAT":
            idat.extend(body)
        elif kind == b"IEND":
            break
    if bitdepth != 8 or interlace != 0:
        raise ValueError("unsupported PNG (bit depth %s, interlace %s): %s" % (bitdepth, interlace, path))
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    raw = zlib.decompress(bytes(idat))
    stride = width * channels
    pixels = bytearray(height * stride)
    prev = bytearray(stride)
    i = 0
    for y in range(height):
        ftype = raw[i]
        line = bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        if ftype == 1:
            for x in range(channels, stride):
                line[x] = (line[x] + line[x - channels]) & 0xFF
        elif ftype == 2:
            for x in range(stride):
                line[x] = (line[x] + prev[x]) & 0xFF
        elif ftype == 3:
            for x in range(stride):
                left = line[x - channels] if x >= channels else 0
                line[x] = (line[x] + ((left + prev[x]) >> 1)) & 0xFF
        elif ftype == 4:
            for x in range(stride):
                left = line[x - channels] if x >= channels else 0
                upleft = prev[x - channels] if x >= channels else 0
                line[x] = (line[x] + _paeth(left, prev[x], upleft)) & 0xFF
        pixels[y * stride:(y + 1) * stride] = line
        prev = line
    if ctype == 6:
        return width, height, pixels
    out = bytearray(width * height * 4)
    n = width * height
    if ctype == 2:
        out[0::4] = pixels[0::3]
        out[1::4] = pixels[1::3]
        out[2::4] = pixels[2::3]
        out[3::4] = b"\xff" * n
    elif ctype == 0:
        out[0::4] = pixels
        out[1::4] = pixels
        out[2::4] = pixels
        out[3::4] = b"\xff" * n
    elif ctype == 4:
        out[0::4] = pixels[0::2]
        out[1::4] = pixels[0::2]
        out[2::4] = pixels[0::2]
        out[3::4] = pixels[1::2]
    elif ctype == 3:
        for p in range(n):
            idx = pixels[p]
            out[p * 4:p * 4 + 3] = palette[idx * 3:idx * 3 + 3]
            out[p * 4 + 3] = trns[idx] if trns and idx < len(trns) else 255
    return width, height, out
