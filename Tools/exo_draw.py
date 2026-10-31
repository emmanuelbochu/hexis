"""Drawing kit for Tools/exo_images.py: a shaded mannequin (side, front or back view) and Matrix-like gym equipment.
`use_her_figure()` turns the mannequin into a woman (Hexis Elle): ponytail, sports top, cycling shorts, narrower waist and
shoulders, and her rose-gold accent on the worked muscles.

Scene units: 100 x 100, y down, angles in degrees (0 right, 90 down, -90 up). A side figure faces right.
"""
import math
from contextlib import contextmanager
from PIL import Image, ImageDraw, ImageFilter

OUT = 640
SS = 3
S = OUT * SS / 100
FLOOR_Y = 92

BG_TOP, BG_BOTTOM = (36, 37, 44), (18, 18, 22)
SKIN, SKIN_HI, SKIN_LO = (206, 210, 222), (236, 238, 245), (160, 165, 181)
FAR, FAR_HI = (112, 117, 134), (132, 137, 154)
SHORTS, SHORTS_FAR = (74, 78, 92), (54, 57, 68)
SHOE, SHOE_FAR = (88, 92, 106), (62, 65, 76)
HAIR = (70, 72, 82)
ACC, ACC_HI = (123, 140, 255), (178, 188, 255)
FRAME, FRAME_HI = (64, 67, 78), (96, 100, 114)
SHROUD, SHROUD_HI, SHROUD_LO = (150, 155, 170), (190, 194, 206), (112, 116, 130)
PAD, PAD_HI = (62, 64, 74), (112, 115, 130)
STEEL, STEEL_HI = (128, 132, 146), (196, 200, 212)
CABLE = (214, 218, 228)

L = dict(torso=26, neck=4.2, head=5.0, thigh=20, shin=19, ua=13.5, fa=12, foot=7)

HER = False
TOP = (92, 74, 84)
SHO_W = 9.6     # half the shoulder width, front view
HIP_W = 4.6     # half the distance between the hip joints, front view


def use_her_figure():
    """Hexis Elle: a woman's figure and her accent (Theme.Colors.accent, dark value)."""
    global HER, ACC, ACC_HI, SHO_W, HIP_W
    HER = True
    ACC, ACC_HI = (227, 168, 155), (248, 212, 202)
    SHO_W, HIP_W = 8.6, 5.0
    L.update(torso=25, ua=13, fa=11.5)  # in place: exo_images holds the same dict


def d(a):
    return math.cos(math.radians(a)), math.sin(math.radians(a))


def add(p, ln, a):
    dx, dy = d(a)
    return (p[0] + ln * dx, p[1] + ln * dy)


def lerp(p, q, t):
    return (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)


def angle(p, q):
    return math.degrees(math.atan2(q[1] - p[1], q[0] - p[0]))


def shade(col, k):
    return tuple(max(0, min(255, int(c * k))) for c in col)


def spline(points, closed=True, steps=8):
    """Catmull-Rom through the points, for smooth body outlines."""
    n = len(points)
    out = []
    rng = range(n) if closed else range(n - 1)
    for i in rng:
        p0, p1 = points[(i - 1) % n] if closed or i > 0 else points[0], points[i]
        p2 = points[(i + 1) % n]
        p3 = points[(i + 2) % n] if closed or i + 2 < n else points[-1]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                                    + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3) for k in (0, 1)))
    if not closed:
        out.append(points[-1])
    return out


class Canvas:
    def __init__(self, transparent=False):
        self.img = Image.new("RGBA", (OUT * SS, OUT * SS))
        g = ImageDraw.Draw(self.img)
        self.g = g
        self.lit = []
        self.zoom = None       # (x, y, size) in scene units: square shown instead of the whole scene
        if transparent:
            return
        for y in range(OUT * SS):
            t = y / (OUT * SS)
            g.line([(0, y), (OUT * SS, y)], fill=tuple(int(BG_TOP[k] + (BG_BOTTOM[k] - BG_TOP[k]) * t) for k in range(3)))
        self.g = g
        self.lit = []          # accent shapes drawn last with a glow, so a muscle reads at thumbnail size
        self.floor()

    # --- primitives
    def pt(self, p):
        return (p[0] * S, p[1] * S)

    def circ(self, p, r, col, g=None):
        x, y = self.pt(p)
        (g or self.g).ellipse([x - r * S, y - r * S, x + r * S, y + r * S], fill=col)

    def poly(self, pts, col, g=None):
        (g or self.g).polygon([self.pt(p) for p in pts], fill=col)

    def capsule(self, p, q, r1, r2=None, col=SKIN, g=None):
        r2 = r1 if r2 is None else r2
        a = angle(p, q)
        n1, n2 = a + 90, a - 90
        self.poly([add(p, r1, n1), add(q, r2, n1), add(q, r2, n2), add(p, r1, n2)], col, g)
        self.circ(p, r1, col, g)
        self.circ(q, r2, col, g)

    def limb(self, p, q, r1, r2, col, hi, lo=None):
        """Shaded limb: base, darker underside, highlight on the upper side (light from the top-left)."""
        self.capsule(p, q, r1, r2, lo or shade(col, 0.82))
        a = angle(p, q)
        up = a - 90 if math.sin(math.radians(a - 90)) <= 0 else a + 90
        off1, off2 = add(p, r1 * 0.18, up), add(q, r2 * 0.18, up)
        self.capsule(off1, off2, r1 * 0.86, r2 * 0.86, col)
        self.capsule(add(p, r1 * 0.45, up), add(q, r2 * 0.45, up), r1 * 0.32, r2 * 0.32, hi)

    def rect(self, x0, y0, x1, y1, col, r=1.0):
        self.g.rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius=r * S, fill=col)

    def layer(self):
        im = Image.new("RGBA", self.img.size)
        return im, ImageDraw.Draw(im)

    def blend(self, im, opacity=1.0, blur=0):
        if blur:
            im = im.filter(ImageFilter.GaussianBlur(blur * S))
        if opacity < 1:
            a = im.getchannel("A").point(lambda v: int(v * opacity))
            im.putalpha(a)
        self.img.alpha_composite(im)

    # --- scene
    def floor(self):
        self.rect(0, FLOOR_Y, 100, 100, (24, 24, 29), 0)
        self.g.line([(0, FLOOR_Y * S), (100 * S, FLOOR_Y * S)], fill=(52, 53, 62), width=int(0.5 * S))

    def shadow(self, x0, x1, y=FLOOR_Y):
        im, g = self.layer()
        g.ellipse([x0 * S, (y - 1.6) * S, x1 * S, (y + 1.6) * S], fill=(0, 0, 0, 200))
        self.blend(im, 0.8, 1.2)

    def arrow(self, pts, width=1.7, head=3.6):
        """Movement arrow along a path (2+ points, smoothed), accent colour with a dark outline."""
        path = spline(pts, closed=False, steps=10) if len(pts) > 2 else pts
        a = angle(path[-2], path[-1])
        tip = add(path[-1], head * 0.6, a)
        body = path[:-1] + [add(tip, -head * 0.8, a)]
        im, g = self.layer()
        for col, w, h in ((BG_BOTTOM + (255,), width + 1.6, head + 1.4), (ACC + (255,), width, head)):
            g.line([self.pt(p) for p in body], fill=col, width=int(w * S), joint="curve")
            for p in (body[0],):
                self.circ(p, w / 2, col, g)
            self.poly([add(tip, h * 0.25, a), add(tip, -h, a + 28), add(tip, -h, a - 28)], col, g)
        self.blend(im, 0.95)

    def arc_arrow(self, center, r, a0, a1, **k):
        n = 6
        self.arrow([add(center, r, a0 + (a1 - a0) * i / n) for i in range(n + 1)], **k)

    @contextmanager
    def ghost(self, opacity=0.32):
        """Whatever is drawn inside is blended faintly: the start position of the movement."""
        im, g = self.layer()
        old_g, old_lit = self.g, self.lit
        self.g, self.lit = g, []
        try:
            yield
        finally:
            self.g, self.lit = old_g, old_lit
            self.blend(im, opacity)

    def paste_rotated(self, other, degrees, dx=0, dy=0):
        """Composite another (transparent) canvas turned by `degrees` (clockwise) and shifted, in scene units."""
        im = other.img.rotate(-degrees, resample=Image.BICUBIC)
        moved = Image.new("RGBA", self.img.size)
        moved.paste(im, (int(dx * S), int(dy * S)), im)
        self.img.alpha_composite(moved)

    def glow_lit(self):
        if not self.lit:
            return
        im, g = self.layer()
        for kind, args in self.lit:
            if kind == "capsule":
                self.capsule(*args, col=ACC + (255,), g=g)
            else:
                self.poly(args[0], ACC + (255,), g)
        self.blend(im, 0.35, 2.4)

    def framed(self):
        im = self.img.convert("RGB")
        if self.zoom:
            x, y, size = self.zoom
            im = im.crop((int(x * S), int(y * S), int((x + size) * S), int((y + size) * S)))
        return im

    def save(self, path):
        self.framed().resize((OUT, OUT), Image.LANCZOS).save(path, optimize=True)

    def thumb(self, size):
        return self.framed().resize((size, size), Image.LANCZOS)

    # --- equipment
    def tube(self, p, q, w=2.4, col=FRAME, hi=FRAME_HI):
        self.capsule(p, q, w / 2, w / 2, col)
        a = angle(p, q)
        up = a - 90 if math.sin(math.radians(a - 90)) <= 0 else a + 90
        self.capsule(add(p, w * 0.22, up), add(q, w * 0.22, up), w * 0.14, w * 0.14, hi)

    def pad(self, p, q, thick=4.5, col=PAD, hi=PAD_HI):
        """Upholstered pad (seat, backrest, roller seen from the side)."""
        self.capsule(p, q, thick / 2, thick / 2, hi)
        self.capsule(p, q, thick / 2 - 0.5, thick / 2 - 0.5, col)
        a = angle(p, q)
        up = a - 90 if math.sin(math.radians(a - 90)) <= 0 else a + 90
        self.capsule(add(p, thick * 0.28, up), add(q, thick * 0.28, up), 0.35, 0.35, shade(hi, 1.15))

    def roller(self, p, r=2.8):
        self.circ(p, r, PAD_HI)
        self.circ(p, r - 0.5, PAD)
        self.circ(p, r * 0.32, STEEL)

    def shroud(self, x0, y0, x1, y1):
        """Silver plastic cover of a Matrix machine."""
        self.rect(x0, y0, x1, y1, SHROUD_LO, 2)
        self.rect(x0, y0, x1 - 0.8, y1 - 0.8, SHROUD, 2)
        self.rect(x0 + 0.8, y0 + 0.8, x0 + 2.2, y1 - 2, SHROUD_HI, 1)

    def stack(self, x, y0, y1, w=10):
        """Weight stack: silver shroud with a window on the plates, guide rods, pin."""
        self.shroud(x, y0, x + w, y1)
        wx0, wx1 = x + 2.2, x + w - 2.2
        self.rect(wx0, y0 + 4, wx1, y1 - 3, (26, 27, 32), 1)
        y = y1 - 4
        while y > y0 + 20:
            self.rect(wx0 + 0.5, y - 2.6, wx1 - 0.5, y, (70, 73, 84), 0.4)
            self.rect(wx0 + 0.5, y - 2.6, wx1 - 0.5, y - 2.0, (104, 108, 122), 0.3)
            y -= 3.1
        self.g.line([self.pt((wx0 + 1.2, y0 + 4)), self.pt((wx0 + 1.2, y1 - 3))], fill=STEEL_HI, width=int(0.4 * S))
        self.g.line([self.pt((wx1 - 1.2, y0 + 4)), self.pt((wx1 - 1.2, y1 - 3))], fill=STEEL_HI, width=int(0.4 * S))
        self.rect(x + w / 2 - 0.4, y0 + 5, x + w / 2 + 0.4, y + 2, STEEL_HI, 0.2)

    def base(self, x0, x1, y=FLOOR_Y):
        self.rect(x0, y - 2.2, x1, y, FRAME, 0.8)
        self.rect(x0, y - 2.2, x1, y - 1.6, FRAME_HI, 0.3)

    def cable(self, p, q):
        self.g.line([self.pt(p), self.pt(q)], fill=CABLE, width=max(2, int(0.45 * S)))

    def pulley(self, p):
        self.circ(p, 2.0, STEEL)
        self.circ(p, 0.8, FRAME)

    def tower(self, x, top=6, w=5):
        self.shroud(x - w / 2, top, x + w / 2, FLOOR_Y)
        self.rect(x - 0.6, top + 3, x + 0.6, FLOOR_Y - 3, (30, 31, 37), 0.4)

    def handle(self, p, a=90, ln=5):
        self.capsule(add(p, ln / 2, a), add(p, -ln / 2, a), 0.9, 0.9, STEEL_HI)

    def rope(self, p, a=90):
        self.capsule(p, add(p, 4, a - 12), 0.8, 0.8, (40, 40, 46))
        self.capsule(p, add(p, 4, a + 12), 0.8, 0.8, (60, 60, 70))
        self.circ(add(p, 4, a - 12), 1.1, (30, 30, 34))
        self.circ(add(p, 4, a + 12), 1.1, (30, 30, 34))

    def dumbbell(self, p, a=0, ln=8.5, r=2.6):
        """Hex dumbbell: handle along `a`, heads at both ends."""
        self.capsule(add(p, ln / 2, a), add(p, -ln / 2, a), 0.6, 0.6, STEEL)
        for q in (add(p, ln / 2, a), add(p, -ln / 2, a)):
            pts = [add(q, r, a + 30 + 60 * i) for i in range(6)]
            self.poly(pts, (48, 50, 58))
            self.poly([add(q, r * 0.7, a + 30 + 60 * i) for i in range(6)], (68, 71, 82))

    def bench(self, hip, back_angle=None, seat=(-6, 12), y_seat=None, back_len=26):
        """Adjustable bench: seat under the hips, optional backrest along `back_angle`, legs to the floor."""
        ys = (hip[1] + 4.6) if y_seat is None else y_seat
        x0, x1 = hip[0] + seat[0], hip[0] + seat[1]
        self.tube((x0 + 2, ys + 2), (x0 + 2, FLOOR_Y - 1), 2.2)
        self.tube((x1 - 2, ys + 2), (x1 - 2, FLOOR_Y - 1), 2.2)
        self.base(x0 - 3, x1 + 3)
        if back_angle is not None:
            start = add((hip[0] - 1, ys - 1), 4.2, back_angle - 90)
            self.tube(lerp(start, add(start, back_len, back_angle), 0.5), (x0 + 2, ys + 2), 1.8)
            self.pad(start, add(start, back_len, back_angle), 4.4)
        self.pad((x0, ys), (x1, ys), 4.4)

    def step(self, x0, x1, h=6):
        self.rect(x0, FLOOR_Y - h, x1, FLOOR_Y, (52, 54, 64), 1)
        self.rect(x0, FLOOR_Y - h, x1, FLOOR_Y - h + 1.2, (92, 95, 108), 0.6)

    def upright(self, x, top=10):
        self.tube((x, top), (x, FLOOR_Y - 1), 3)
        self.base(x - 5, x + 5)


class Side:
    """Side-view pose from joint angles; the far limbs copy the near ones unless overridden (`th2`, `ua2`…)."""

    def __init__(self, hip, tor, th, sh, ua, fa, head=None, foot=None, **far):
        self.hip, self.tor = hip, tor
        self.sho = add(hip, L["torso"], tor)
        self.head_a = tor if head is None else head
        self.neck = add(self.sho, L["neck"], self.head_a)
        self.head = add(self.neck, L["head"] + 0.6, self.head_a)
        self.kn, self.an = add(hip, L["thigh"], th), None
        self.an = add(self.kn, L["shin"], sh)
        self.foot_a = sh - 90 if foot is None else foot
        self.el = add(self.sho, L["ua"], ua)
        self.wr = add(self.el, L["fa"], fa)
        self.hand = add(self.wr, 1.6, fa)
        th2, sh2 = far.get("th2", th), far.get("sh2", sh)
        self.kn2 = add(hip, L["thigh"], th2)
        self.an2 = add(self.kn2, L["shin"], sh2)
        self.foot2_a = far.get("foot2", sh2 - 90 if "sh2" in far else self.foot_a)
        ua2, fa2 = far.get("ua2", ua), far.get("fa2", fa)
        self.el2 = add(self.sho, L["ua"], ua2)
        self.wr2 = add(self.el2, L["fa"], fa2)
        self.hand2 = add(self.wr2, 1.6, fa2)
        self.fa_a, self.fa2_a = fa, fa2
        self.front = tor + 90          # chest side normal
        self.lift = far.get("lift", 0)


def draw_side(c, p, lit=(), far_arm=True, far_leg=True, arm_behind=False):
    """Shaded side mannequin. `lit`: muscles in the accent colour."""
    off = (-1.6, -0.8)
    mv = lambda q: (q[0] + off[0], q[1] + off[1])
    on = lambda m: m in lit
    if far_arm:
        c.limb(mv(p.sho), mv(p.el2), 3.0, 2.5, FAR, FAR_HI)
        c.limb(mv(p.el2), mv(p.wr2), 2.5, 1.9, FAR, FAR_HI)
        c.circ(mv(p.hand2), 2.0, FAR)
    if far_leg:
        c.limb(mv(p.hip), mv(p.kn2), 4.8, 3.5, ACC if on("quads") or on("hams") else FAR, FAR_HI)
        c.capsule(mv(p.hip), mv(lerp(p.hip, p.kn2, SHORTS_LEN())), 5.0, 4.0 if not HER else 3.7, SHORTS_FAR)
        c.limb(mv(p.kn2), mv(p.an2), 3.4, 2.2, FAR, FAR_HI)
        c.capsule(mv(lerp(p.kn2, p.an2, 0.18)), mv(lerp(p.kn2, p.an2, 0.5)), 3.6, 2.8, ACC if on("calves") else FAR)
        foot(c, mv(p.an2), p.foot2_a, SHOE_FAR)

    # torso: smooth outline from back to chest
    a, n = p.tor, p.front
    hip, sho = p.hip, p.sho
    at = lambda t, side, w: add(lerp(hip, sho, t), w, n if side > 0 else n + 180)
    if HER:  # waist in, hips and bust a little out, shoulders a little narrower
        outline = [at(-0.02, -1, 6.4), at(0.45, -1, 3.9), at(0.82, -1, 4.5), at(1.0, -1, 3.0), at(1.04, 1, 0.5), at(0.98, 1, 2.9),
                   at(0.8, 1, 6.4), at(0.64, 1, 4.6), at(0.42, 1, 4.0), at(0.1, 1, 5.6)]
    else:
        outline = [at(0, -1, 5.4), at(0.45, -1, 4.4), at(0.82, -1, 5.0), at(1.0, -1, 3.4), at(1.04, 1, 0.5), at(0.98, 1, 3.2),
                   at(0.84, 1, 6.0), at(0.68, 1, 5.4), at(0.4, 1, 4.8), at(0.08, 1, 5.2)]
    body = spline(outline)
    c.poly(body, SKIN_LO)
    c.poly([add(q, 0.5, a + 180 + 30) for q in body], SKIN)
    if HER:  # sports top
        c.poly(spline([at(0.96, -1, 3.4), at(0.62, -1, 4.3), at(0.6, 1, 5.0), at(0.8, 1, 6.5), at(0.95, 1, 3.4)]), TOP)
    if on("chest"):
        pts = spline([at(0.98, 1, 1.0), at(0.86, 1, 6.6), at(0.66, 1, 5.6), at(0.7, 1, 1.0)])
        c.poly(pts, ACC); c.lit.append(("poly", (pts,)))
    if on("abs"):
        pts = spline([at(0.62, 1, 5.6), at(0.3, 1, 5.4), at(0.08, 1, 5.2), at(0.1, 1, 1.5), at(0.6, 1, 1.5)])
        c.poly(pts, ACC); c.lit.append(("poly", (pts,)))
    if on("lats"):
        pts = spline([at(0.88, -1, 5.0), at(0.5, -1, 4.6), at(0.3, -1, 4.8), at(0.4, -1, 0.5), at(0.85, -1, 0.5)])
        c.poly(pts, ACC); c.lit.append(("poly", (pts,)))
    if not HER:
        c.capsule(at(0.5, 1, 4.2), at(0.85, 1, 4.6), 0.4, 0.4, SKIN_HI)
    # shorts
    c.poly(spline([at(0.2, -1, 5.4), at(0.2, 1, 5.4), at(-0.06, 1, 5.6), at(-0.12, -1, 5.8)]), SHORTS)

    # near leg
    thigh_col = ACC if on("quads") or on("hams") else SKIN
    c.limb(p.hip, p.kn, 5.2, 3.7, thigh_col, ACC_HI if thigh_col == ACC else SKIN_HI)
    if thigh_col == ACC: c.lit.append(("capsule", (p.hip, p.kn, 5.2, 3.7)))
    c.capsule(p.hip, lerp(p.hip, p.kn, SHORTS_LEN()), 5.5, 4.3 if not HER else 3.9, SHORTS)
    if on("glutes"):
        g = add(p.hip, 3.2, n + 180)
        c.circ(g, 4.6, ACC); c.lit.append(("capsule", (g, g, 4.6, 4.6)))
    c.limb(p.kn, p.an, 3.6, 2.3, SKIN, SKIN_HI)
    calf_a, calf_b = lerp(p.kn, p.an, 0.15), lerp(p.kn, p.an, 0.52)
    back = angle(p.kn, p.an) + (90 if math.cos(math.radians(p.foot_a - angle(p.kn, p.an) - 90)) > 0 else -90)
    calf_a, calf_b = add(calf_a, 0.9, back), add(calf_b, 0.6, back)
    c.capsule(calf_a, calf_b, 3.7, 2.7, ACC if on("calves") else SKIN)
    if on("calves"): c.lit.append(("capsule", (calf_a, calf_b, 3.7, 2.7)))
    foot(c, p.an, p.foot_a, SHOE)

    def near_arm():
        sho_col = ACC if on("shoulders") or on("rear") else SKIN
        ua_col = ACC if on("biceps") or on("triceps") else SKIN
        c.limb(p.sho, p.el, 3.3, 2.7, ua_col, ACC_HI if ua_col == ACC else SKIN_HI)
        if ua_col == ACC: c.lit.append(("capsule", (p.sho, p.el, 3.3, 2.7)))
        c.circ(p.sho, 3.9, sho_col)
        c.circ(add(p.sho, 1.2, -120), 1.6, ACC_HI if sho_col == ACC else SKIN_HI)
        if sho_col == ACC: c.lit.append(("capsule", (p.sho, p.sho, 3.9, 3.9)))
        c.limb(p.el, p.wr, 2.7, 2.0, SKIN, SKIN_HI)
        c.circ(p.hand, 2.1, SKIN_LO)
        c.circ(add(p.hand, 0.4, -120), 1.6, SKIN)


    if arm_behind:
        near_arm()
    # neck and head
    c.limb(p.sho, p.neck, 2.6, 2.4, ACC if on("neck") else SKIN, ACC_HI if on("neck") else SKIN_HI)
    if on("neck"): c.lit.append(("capsule", (lerp(p.sho, p.neck, 0.2), p.neck, 2.6, 2.4)))
    if on("traps"):
        t1, t2 = add(p.sho, 2.0, n + 180), add(p.neck, 1.0, n + 180)
        c.capsule(t1, t2, 3.0, 2.2, ACC); c.lit.append(("capsule", (t1, t2, 3.0, 2.2)))
    head(c, p.head, p.head_a)

    if not arm_behind:
        near_arm()


def SHORTS_LEN():
    """How far down the thigh the shorts go (hers: cycling shorts)."""
    return 0.72 if HER else 0.4


def foot(c, ankle, a, col):
    heel = add(ankle, 1.6, a + 180)
    toe = add(ankle, L["foot"], a)
    down = a + 90 if math.sin(math.radians(a + 90)) >= 0 else a - 90
    c.capsule(heel, toe, 2.0, 1.4, col)
    c.capsule(add(heel, 1.2, down), add(toe, 0.9, down), 1.0, 0.8, shade(col, 0.7))


def head(c, p, axis, view="side", tilt=0):
    """Head with hair at the back and top, nose and ear: the facing direction reads at a glance."""
    r = L["head"]
    front = axis + 90
    c.circ(p, r, SKIN_LO)
    c.circ(add(p, 0.4, -120), r - 0.5, SKIN)
    x, y = c.pt(p)
    box = [x - r * S, y - r * S, x + r * S, y + r * S]
    if HER and view in ("side", "back"):
        back = front + 180 if view == "side" else axis + 180
        down = axis + 180
        tail = math.degrees(math.atan2(math.sin(math.radians(back)) + 1.3 * math.sin(math.radians(down)),
                                       math.cos(math.radians(back)) + 1.3 * math.cos(math.radians(down))))
        root = add(p, r * (0.8 if view == "side" else 0.2), back if view == "side" else axis)
        c.capsule(root, add(root, 7.5, tail), 1.9, 0.8, HAIR)
        c.circ(root, 1.3, shade(HAIR, 0.7))
    if view == "side":
        c.g.pieslice(box, front + 150 if HER else front + 165, front + 320 if HER else front + 315, fill=HAIR)
        c.circ(add(p, r * 0.98, front - 8), 1.2, SKIN)                 # nose
        c.circ(add(p, 0.6, front + 180), 1.3, SKIN_LO)                # ear
        c.circ(add(add(p, r * 0.45, front), r * 0.25, axis), 0.55, (60, 62, 72))   # eye
    elif view == "front":
        c.g.pieslice(box, axis - (100 if HER else 80) + tilt, axis + (100 if HER else 80) + tilt, fill=HAIR)
        for s in (-1, 1):
            c.circ(add(add(p, 1.8 * s, axis + 90), 0.6, axis + 180), 0.6, (60, 62, 72))
    else:
        c.g.ellipse(box, fill=HAIR)
        c.circ(add(p, r * 0.92, axis + 90 + 180), 1.2, SKIN_LO)
        c.circ(add(p, r * 0.92, axis + 90), 1.2, SKIN_LO)


class Front:
    """Front (or back) view: symmetric body, each arm and leg set by angles given for the viewer's right side.

    `arms=(ua, fa)` or `arms_l`/`arms_r`; `legs=(th, sh)`; `seated=True` foreshortens the thighs toward the viewer.
    """

    def __init__(self, cx, hip_y, arms=(90, 90), legs=(90, 90), seated=False, back=False, tilt=0, thigh=7.5, **k):
        self.cx, self.hip_y, self.back, self.seated, self.tilt = cx, hip_y, back, seated, tilt
        self.sho_y = hip_y - 24
        self.sides = {}
        for s in (-1, 1):
            ua, fa = k.get("arms_r" if s > 0 else "arms_l", arms)
            th, sh = k.get("legs_r" if s > 0 else "legs_l", legs)
            mir = (lambda a: a) if s > 0 else (lambda a: 180 - a)
            sho = (cx + SHO_W * s, self.sho_y + 1.5)
            el = add(sho, L["ua"], mir(ua))
            wr = add(el, L["fa"], mir(fa))
            hip = (cx + HIP_W * s, hip_y)
            kn = add(hip, thigh if seated else L["thigh"], mir(th))
            an = add(kn, L["shin"], mir(sh))
            self.sides[s] = dict(sho=sho, el=el, wr=wr, hand=add(wr, 1.6, mir(fa)), hip=hip, kn=kn, an=an)
        self.neck = (cx, self.sho_y - 2)
        self.head = add((cx, self.sho_y - 2.5), L["neck"] + L["head"] - 1, -90 + tilt)

    def __getitem__(self, s):
        return self.sides[s]


def draw_front(c, p, lit=(), arms_behind_head=False, behind=None):
    """Front or back mannequin; `behind(c)` is drawn after the far parts (equipment between arms and body)."""
    on = lambda m: m in lit
    cx, sy, hy = p.cx, p.sho_y, p.hip_y
    # legs
    for s in (-1, 1):
        q = p[s]
        thigh = ACC if on("quads") or on("glutes_out") else SKIN
        if p.seated:
            c.capsule(q["hip"], q["kn"], 5.4, 5.0, SHORTS)
            c.circ(q["kn"], 4.4, thigh if on("quads") else SKIN)
        else:
            c.limb(q["hip"], q["kn"], 5.4, 3.8, thigh, ACC_HI if thigh == ACC else SKIN_HI)
            c.capsule(q["hip"], lerp(q["hip"], q["kn"], SHORTS_LEN() + 0.02), 5.9 if not HER else 5.1, 5.0 if not HER else 3.9, SHORTS)
        c.limb(q["kn"], q["an"], 3.7, 2.4, SKIN, SKIN_HI)
        c.capsule(q["an"], add(q["an"], 1.6, 90), 2.3, 2.0, SHOE)
        c.capsule(add(q["an"], 1.6, 90), add(q["an"], 3.2, 90 if p.back else (90 - 70 * s) if False else 90), 2.0, 1.8, SHOE)
        if on("glutes_out"):
            g = add(q["hip"], 3.0, 0 if s > 0 else 180)
            c.capsule(g, add(g, 6, 90), 3.2, 3.2, ACC); c.lit.append(("capsule", (g, add(g, 6, 90), 3.2, 3.2)))
    # torso
    if HER:
        outline = [(cx - 9.2, sy), (cx - 8.0, sy + 8), (cx - 6.0, sy + 15), (cx - 8.6, hy + 2), (cx + 8.6, hy + 2),
                   (cx + 6.0, sy + 15), (cx + 8.0, sy + 8), (cx + 9.2, sy), (cx + 3.6, sy - 2.2), (cx - 3.6, sy - 2.2)]
    else:
        outline = [(cx - 10.4, sy), (cx - 8.8, sy + 8), (cx - 7.0, sy + 16), (cx - 7.6, hy + 2), (cx + 7.6, hy + 2),
                   (cx + 7.0, sy + 16), (cx + 8.8, sy + 8), (cx + 10.4, sy), (cx + 4, sy - 2.2), (cx - 4, sy - 2.2)]
    body = spline(outline)
    c.poly(body, SKIN_LO)
    c.poly([(x - 0.4, y - 0.4) for x, y in body], SKIN)
    if HER:  # sports top (racer back seen from behind)
        c.poly(spline([(cx - 7.6, sy + 1.2), (cx + 7.6, sy + 1.2), (cx + 7.4, sy + 9.5), (cx, sy + 10.2), (cx - 7.4, sy + 9.5)]), TOP)
    w = 8.0 if HER else 7.6
    c.poly(spline([(cx - w, hy - 3), (cx + w, hy - 3), (cx + w + 0.2, hy + 4), (cx, hy + 5), (cx - w - 0.2, hy + 4)]), SHORTS)
    if on("chest") and not p.back:
        for s in (-1, 1):
            pts = spline([(cx + 0.6 * s, sy + 1.5), (cx + 9 * s, sy + 1.5), (cx + 8.4 * s, sy + 7.5), (cx + 1 * s, sy + 8.5)])
            c.poly(pts, ACC); c.lit.append(("poly", (pts,)))
    if on("abs") and not p.back:
        pts = spline([(cx - 4.4, sy + 10), (cx + 4.4, sy + 10), (cx + 4.4, hy - 3), (cx - 4.4, hy - 3)])
        c.poly(pts, ACC); c.lit.append(("poly", (pts,)))
    if on("lats") and p.back:
        for s in (-1, 1):
            pts = spline([(cx + 2 * s, sy + 4), (cx + 9 * s, sy + 5), (cx + 7 * s, sy + 15), (cx + 2 * s, sy + 19)])
            c.poly(pts, ACC); c.lit.append(("poly", (pts,)))
    if p.back:
        c.g.line([c.pt((cx, sy + 2)), c.pt((cx, hy - 3))], fill=SKIN_LO, width=int(0.5 * S))
    else:
        c.g.line([c.pt((cx, sy + 2.5)), c.pt((cx, sy + 8))], fill=SKIN_LO, width=int(0.35 * S))
    # neck, traps, head
    c.capsule((cx, sy), p.neck, 2.9, 2.6, ACC if on("neck") else SKIN)
    if on("neck"): c.lit.append(("capsule", ((cx, sy), p.neck, 2.9, 2.6)))
    if on("traps"):
        for s in (-1, 1):
            c.capsule((cx + 2.2 * s, sy - 2), (cx + 7.5 * s, sy), 1.8, 1.4, ACC)
            c.lit.append(("capsule", ((cx + 2.2 * s, sy - 2), (cx + 7.5 * s, sy), 1.8, 1.4)))
    def arms():
        for s in (-1, 1):
            q = p[s]
            sho_col = ACC if on("shoulders") or (on("rear") and p.back) else SKIN
            ua_col = ACC if on("biceps") or on("triceps") else SKIN
            c.limb(q["sho"], q["el"], 3.3, 2.7, ua_col, ACC_HI if ua_col == ACC else SKIN_HI)
            if ua_col == ACC: c.lit.append(("capsule", (q["sho"], q["el"], 3.3, 2.7)))
            c.limb(q["el"], q["wr"], 2.7, 2.0, SKIN, SKIN_HI)
            c.circ(q["hand"], 2.1, SKIN_LO)
            c.circ(q["sho"], 4.0, sho_col)
            if sho_col == ACC: c.lit.append(("capsule", (q["sho"], q["sho"], 4.0, 4.0)))


    if arms_behind_head:
        arms()
    head(c, p.head, -90 + p.tilt, "back" if p.back else "front", 0)
    if behind:
        behind(c)
    if not arms_behind_head:
        arms()

def two_link(root, target, l1, l2, bend=1):
    """Angles (first, second) of a two-segment limb from `root` reaching `target`; `bend` picks the side of the middle joint."""
    dist = min(math.dist(root, target), l1 + l2 - 0.01)
    a = angle(root, target)
    off = math.degrees(math.acos(max(-1, min(1, (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)))))
    first = a - off * bend
    mid = add(root, l1, first)
    return first, angle(mid, target)


def leg_to(hip, ankle):
    """Thigh and shin angles putting the ankle at `ankle`, knee bent toward the front/floor."""
    return two_link(hip, ankle, L["thigh"], L["shin"], 1)


def arm_to(sho, wrist, elbow_down=True):
    a = angle(sho, wrist)
    sign = 1 if (math.cos(math.radians(a)) >= 0) == elbow_down else -1
    return two_link(sho, wrist, L["ua"], L["fa"], -sign)


def hip_from(ankle, th, sh):
    """Hip position for a leg ending at `ankle` with the given thigh and shin angles."""
    kn = add(ankle, -L["shin"], sh)
    return add(kn, -L["thigh"], th)


def hold(c, p):
    """Isometric hold: pause sign in an accent ring."""
    im, g = c.layer()
    c.circ(p, 5.2, ACC + (255,), g)
    c.circ(p, 4.0, BG_TOP + (255,), g)
    for dx in (-1.3, 1.3):
        x, y = c.pt((p[0] + dx, p[1]))
        g.rounded_rectangle([x - 0.55 * S, y - 2 * S, x + 0.55 * S, y + 2 * S], radius=0.4 * S, fill=ACC + (255,))
    c.blend(im)


def plate(c, p, r=7):
    """Weight plate seen face on (plate-loaded machines)."""
    c.circ(p, r, (40, 41, 48))
    c.circ(p, r - 1.2, (58, 60, 70))
    c.circ(p, r * 0.45, (44, 45, 52))
    c.circ(p, 1.2, STEEL_HI)
