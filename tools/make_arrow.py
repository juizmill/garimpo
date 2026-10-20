# Writes a 64x64 gold arrow pointing up as an uncompressed 32-bit TGA (top-left origin).
import sys, struct

SIZE, SS = 64, 4  # supersampling for smooth edges
OUTER = [(32, 3), (60, 54), (32, 42), (4, 54)]
INNER = [(32, 9), (53, 50), (32, 39), (11, 50)]

def inside(poly, x, y):
    c = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            c = not c
    return c

pixels = bytearray()
for py in range(SIZE):
    for px in range(SIZE):
        outer = inner = 0
        for sy in range(SS):
            for sx in range(SS):
                x, y = px + (sx + 0.5) / SS, py + (sy + 0.5) / SS
                if inside(OUTER, x, y):
                    outer += 1
                    if inside(INNER, x, y):
                        inner += 1
        n = SS * SS
        a = outer / n
        f = inner / outer if outer else 0
        # gold fill with a dark brown outline
        r = int(255 * f + 40 * (1 - f))
        g = int(209 * f + 26 * (1 - f))
        b = int(0 * f + 8 * (1 - f))
        pixels += bytes((b, g, r, int(255 * a)))

header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)
with open(sys.argv[1], "wb") as fh:
    fh.write(header + pixels)
print("wrote", sys.argv[1])
