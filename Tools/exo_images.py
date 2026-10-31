"""Draws one illustration per exercise of Program.json: shaded mannequin on its Matrix-like machine,
worked muscle in the accent colour, an arrow for the movement. Drawing kit: Tools/exo_draw.py.

Run from the repo root:  python3 Tools/exo_images.py [--elle] [--sheet out.png] [names…]
Writes Hexis/Assets.xcassets/exo-<slug>.imageset (slug = ExerciseImage.assetName), or a contact sheet with --sheet.
--elle: Hexis Elle's program (HexisElle/Program.json) drawn with a woman's figure in her accent, written to
HexisElle/Assets.xcassets/elle-exo-<slug>.imageset (looked up first by her app, see ExerciseImage.assetNames).
"""
import json, math, os, sys, unicodedata
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from exo_draw import *  # noqa: E402,F403

SCENES = {}


def scene(*names):
    def register(fn):
        for n in names:
            SCENES[n] = fn
        return fn
    return register


# --- shared set-ups ---------------------------------------------------------------------------------------------
SEAT_HIP = (42, 70)


def seat(c, hip=SEAT_HIP, back=-92, back_len=28, seat=(-7, 13), post=None):
    """Machine seat: pad under the hips, backrest, central post on a base."""
    ys = hip[1] + 4.6
    x = hip[0] + 2 if post is None else post
    c.base(hip[0] - 16, hip[0] + 18)
    c.tube((x, ys + 2), (x, FLOOR_Y - 2), 3.2)
    if back is not None:
        start = (hip[0] - 5.6, ys - 1)
        c.tube((hip[0] - 4, ys + 1), add(start, back_len * 0.5, back), 2.4)
        c.pad(add(start, 1.5, back), add(start, back_len, back), 5)
    c.pad((hip[0] + seat[0], ys), (hip[0] + seat[1], ys), 5)


def seated(hip=SEAT_HIP, tor=-90, th=0, sh=90, ua=95, fa=10, **k):
    return Side(hip, tor, th, sh, ua, fa, **k)


def standing(x=48, tor=-90, th=90, sh=90, ua=92, fa=92, **k):
    return Side((x, FLOOR_Y - 1.5 - L["thigh"] - L["shin"]), tor, th, sh, ua, fa, **k)


def front_seated(cx=50, hip_y=68, **k):
    return Front(cx, hip_y, seated=True, legs=k.pop("legs", (100, 90)), **k)


def front_standing(cx=50, **k):
    return Front(cx, FLOOR_Y - 2.5 - L["thigh"] - L["shin"], **k)


def front_seat(c, p, back=True):
    """Seat seen from the front: pad under the hips, post, base; backrest behind the torso."""
    y = p.hip_y + 4
    c.base(p.cx - 16, p.cx + 16)
    c.tube((p.cx, y + 2), (p.cx, FLOOR_Y - 2), 3.2)
    if back:
        c.rect(p.cx - 9, p.sho_y - 4, p.cx + 9, y - 2, PAD_HI, 2.5)
        c.rect(p.cx - 8.4, p.sho_y - 3.4, p.cx + 8.4, y - 2.6, PAD, 2.2)
    c.rect(p.cx - 11, y - 2.2, p.cx + 11, y + 2.4, PAD_HI, 2)
    c.rect(p.cx - 10.4, y - 1.6, p.cx + 10.4, y + 1.8, PAD, 1.8)


# --- legs -------------------------------------------------------------------------------------------------------
@scene("Leg extension")
def leg_extension(c):
    c.stack(4, 22, FLOOR_Y - 2)
    seat(c, back=-98)
    p = seated(th=-4, sh=-20, ua=100, fa=40)
    with c.ghost():
        g = seated(th=-4, sh=88, ua=100, fa=40)
        draw_side(c, g, (), far_arm=False)
        c.roller(add(g.an, 2.8, angle(g.kn, g.an) - 90))
    c.tube(p.kn, (p.kn[0] + 1, FLOOR_Y - 2), 2.4)
    c.tube(p.kn, add(p.an, 1, angle(p.kn, p.an)), 2.0, STEEL, STEEL_HI)
    draw_side(c, p, ("quads",))
    c.roller(add(p.an, 2.8, angle(p.kn, p.an) - 90))
    c.handle(add(p.hip, 6, 120), 0, 4)
    c.arc_arrow(p.kn, 25, 62, -8)
    c.shadow(25, 80)


@scene("Leg curl assis")
def leg_curl_seated(c):
    c.stack(84, 22, FLOOR_Y - 2)
    seat(c, back=-100)
    p = seated(th=-2, sh=112, ua=100, fa=40)
    with c.ghost():
        g = seated(th=-2, sh=10, ua=100, fa=40)
        draw_side(c, g, (), far_arm=False)
        c.roller(add(g.an, 3.0, angle(g.kn, g.an) + 90))
    c.tube(p.kn, add(p.an, 1, angle(p.kn, p.an)), 2.0, STEEL, STEEL_HI)
    draw_side(c, p, ("hams",))
    c.roller(add(p.an, 3.0, angle(p.kn, p.an) + 90))
    knee_pad = add(lerp(p.hip, p.kn, 0.82), 6.4, -90)
    c.pad(add(knee_pad, -5, 0), add(knee_pad, 5, 0), 4.6)
    c.tube(add(knee_pad, 5, 0), (84, knee_pad[1]), 2.2)
    c.handle(add(p.hip, 6, 120), 0, 4)
    c.arc_arrow(p.kn, 24, 52, 118)
    c.shadow(25, 80)


def leg_press(c, near_ankle, far_ankle=None, lit=("quads",), foot=-82, arrow=True):
    hip = (30, 70)
    c.stack(86, 22, FLOOR_Y - 2)
    c.base(14, 96)
    c.tube((24, 76), (24, FLOOR_Y - 2), 3)
    c.tube((74, 50), (86, 40), 2.4)
    c.tube((74, 80), (86, 80), 2.4)
    c.pad((hip[0] - 7, hip[1] + 4.6), (hip[0] + 10, hip[1] + 4.6), 5)
    back = add((hip[0] - 4, hip[1] + 2), 30, -128)
    c.tube((hip[0] - 2, hip[1] + 5), lerp((hip[0] - 4, hip[1] + 2), back, 0.4), 2.4)
    c.pad((hip[0] - 4, hip[1] + 2), back, 5)
    th, sh = leg_to(hip, near_ankle)
    far = {}
    if far_ankle:
        th2, sh2 = leg_to(hip, far_ankle)
        far = dict(th2=th2, sh2=sh2, foot2=-80 if far_ankle[0] > 70 else 0)
    p = Side(hip, -126, th, sh, 60, 20, foot=foot, **far)
    p.wr = add(p.el, L["fa"], 20)
    draw_side(c, p, lit)
    c.rect(71.4, 36, 76.4, 84, SHROUD_LO, 2)
    c.rect(71.9, 36.5, 75.4, 83.5, SHROUD, 2)
    c.handle(p.hand, 0, 4)
    if arrow:
        c.arrow([(lerp(p.kn, p.an, 0.5)[0], p.kn[1] - 9), (lerp(p.kn, p.an, 0.5)[0] + 13, p.kn[1] - 9)])
    c.shadow(14, 90)
    return p


@scene("Presse à cuisses")
def leg_press_both(c):
    leg_press(c, (69, 55))


@scene("Presse horizontale unilatérale")
def leg_press_single(c):
    leg_press(c, (69, 48), far_ankle=(50, 84))


@scene("Mollets à la presse")
def calf_press(c):
    p = leg_press(c, (66, 72), lit=("calves",), foot=-62, arrow=False)
    c.arc_arrow(p.an, 9, -10, -70)


def seated_calf(c, hold_it=False):
    hip = (40, 68)
    c.base(22, 96)
    c.tube((42, 74), (42, FLOOR_Y - 2), 3)
    c.pad((hip[0] - 7, hip[1] + 4.6), (hip[0] + 10, hip[1] + 4.6), 5)
    p = Side(hip, -88, 0, 90, 70, -10, foot=-14)
    c.rect(62, 84, 74, FLOOR_Y - 2, FRAME, 1)
    c.rect(62, 84, 74, 85.2, FRAME_HI, 0.5)
    draw_side(c, p, ("calves",))
    pad_c = add(p.kn, 6.6, -90)
    c.pad(add(pad_c, -6, 0), add(pad_c, 3, 0), 5)
    c.tube(add(pad_c, 3, 0), (84, pad_c[1]), 2.6)
    c.tube((84, pad_c[1]), (88, FLOOR_Y - 2), 2.6)
    plate(c, (84, pad_c[1]), 8)
    c.handle(add(pad_c, -4, -90), 0, 4)
    if hold_it:
        hold(c, (80, 30))
    else:
        c.arrow([(52, FLOOR_Y - 1), (52, 79)])
    c.shadow(24, 92)


@scene("Mollets assis presse")
def seated_calf_raise(c):
    seated_calf(c)


@scene("Isométrie mollets assis")
def seated_calf_hold(c):
    seated_calf(c, hold_it=True)


@scene("Leg curl allongé")
def leg_curl_lying(c):
    c.stack(4, 30, FLOOR_Y - 2)
    c.base(14, 92)
    for x in (30, 76):
        c.tube((x, 66), (x, FLOOR_Y - 2), 2.6)
    c.pad((24, 64.5), (82, 64.5), 5)
    with c.ghost():
        draw_side(c, Side((50, 59.5), 0, 180, 180, 100, 40, head=0, foot=-90), (), far_arm=False)
    p = Side((50, 59.5), 0, 180, -58, 100, 40, head=0, foot=-150)
    c.tube((p.kn[0], 64), add(p.an, 1, angle(p.kn, p.an)), 2.0, STEEL, STEEL_HI)
    draw_side(c, p, ("hams",))
    c.roller(add(p.an, 3.0, angle(p.kn, p.an) - 90))
    c.handle(p.hand, 0, 4)
    c.arc_arrow(p.kn, 21, 196, 262)
    c.shadow(20, 90)


@scene("Abduction machine")
def abduction(c):
    def pose(spread):
        return front_seated(legs_l=(spread, 95), legs_r=(spread, 95), arms=(100, 85), thigh=12)
    p = pose(40)
    c.rect(p.cx - 26, 14, p.cx + 26, 18, FRAME, 1.4)
    for s in (-1, 1):
        c.tube((p.cx + 26 * s, 16), (p.cx + 26 * s, FLOOR_Y - 2), 3)
    c.base(p.cx - 30, p.cx + 30)
    front_seat(c, p)

    def knee_pads(q):
        for s in (-1, 1):
            k = q[s]["kn"]
            c.rect(k[0] + 4.6 * s - 2, k[1] - 6, k[0] + 4.6 * s + 2, k[1] + 6, PAD_HI, 1.5)
            c.rect(k[0] + 4.6 * s - 1.5, k[1] - 5.5, k[0] + 4.6 * s + 1.5, k[1] + 5.5, PAD, 1.2)
            c.tube((k[0] + 4.6 * s, k[1] + 6), (p.cx + 3 * s, p.hip_y + 8), 1.6, STEEL, STEEL_HI)
    with c.ghost(0.3):
        g = pose(88)
        draw_front(c, g, ())
        knee_pads(g)
    draw_front(c, p, ("glutes_out",))
    knee_pads(p)
    for s in (-1, 1):
        k = p[s]["kn"]
        c.arrow([(k[0] + 9 * s, k[1] - 11), (k[0] + 19 * s, k[1] - 11)])
        c.handle(p[s]["hand"], 90, 4)
    c.shadow(26, 74)


@scene("Shrugs haltères debout")
def shrugs_standing(c):
    p = front_standing(arms=(86, 90))
    p.sho_y -= 2
    draw_front(c, p, ("traps",))
    for s in (-1, 1):
        c.dumbbell(p[s]["hand"], 90, 2.2, 2.8)
        c.arrow([(p.cx + 15 * s, p.sho_y + 2), (p.cx + 15 * s, p.sho_y - 9)])
    c.shadow(32, 68)


@scene("Shrugs haltères assis")
def shrugs_seated(c):
    c.bench(SEAT_HIP, -100)
    p = seated(tor=-98, ua=92, fa=92)
    draw_side(c, p, ("traps",))
    c.dumbbell(p.hand, 0, 0.1, 2.8)
    c.arrow([(p.sho[0] + 10, p.sho[1] + 2), (p.sho[0] + 10, p.sho[1] - 9)])
    c.shadow(25, 75)


@scene("Ab wheel")
def ab_wheel(c):
    kn = (22, FLOOR_Y - 3.6)
    hip = add(kn, L["thigh"], -32)
    p = Side(hip, -12, angle(hip, kn), 180, 0, 0, foot=100)
    ua, fa = arm_to(p.sho, (p.sho[0] + 22, FLOOR_Y - 6.5))
    p = Side(hip, -12, angle(hip, kn), 180, ua, fa, foot=100)
    c.rect(4, FLOOR_Y - 1.2, 40, FLOOR_Y, (60, 62, 72), 0.5)
    draw_side(c, p, ("abs",))
    w = (p.hand[0], FLOOR_Y - 6.2)
    c.circ(w, 6.2, (40, 41, 48)); c.circ(w, 5.0, (70, 72, 84)); c.circ(w, 1.6, STEEL_HI)
    c.capsule(add(w, -3, 0), add(w, 3, 0), 0.9, 0.9, STEEL_HI)
    c.arrow([(48, 56), (72, 56)])
    c.shadow(10, 95)


# --- neck -------------------------------------------------------------------------------------------------------
def neck_plate(c, p, side):
    """Weight plate held on the head (seen edge on): `side` is the angle from the head centre to the plate."""
    centre = add(p.head, L["head"] + 1.3, side)
    a = side + 90
    c.capsule(add(centre, 6.5, a), add(centre, -6.5, a), 1.4, 1.4, (40, 41, 48))
    c.capsule(add(centre, 6.0, a), add(centre, -6.0, a), 0.8, 0.8, (78, 80, 92))
    return centre


@scene("Neck extension")
def neck_extension(c):
    c.bench((40, 61.5), seat=(-36, 26))
    start = dict(head=24)
    def pose(head):
        hip = (40, 61.5)
        sho = add(hip, L["torso"], 0)
        probe = Side(hip, 0, 180, 180, 90, 0, head=head)
        plate_c = add(probe.head, L["head"] + 1.3, head - 90)
        ua, fa = arm_to(sho, add(plate_c, -2.6, head + 90 - 90), elbow_down=True)
        return Side(hip, 0, 178, 186, ua, fa, head=head, foot=95)
    with c.ghost():
        g = pose(start["head"])
        draw_side(c, g, (), far_leg=False, arm_behind=True)
        neck_plate(c, g, g.head_a - 90)
    p = pose(-24)
    draw_side(c, p, ("neck", "traps"), far_leg=False, arm_behind=True)
    neck_plate(c, p, p.head_a - 90)
    c.arc_arrow(p.neck, 15, 14, -36)
    c.shadow(6, 74)
    c.zoom = (40, 30, 60)


@scene("Neck flexion")
def neck_flexion(c):
    hip = (58, 61.5)
    c.bench(hip, seat=(-30, 12))
    th, sh = leg_to(hip, (80, 89))
    def pose(head):
        probe = Side(hip, 180, th, sh, 0, 0, head=head)
        plate_c = add(probe.head, L["head"] + 1.3, head + 90)
        ua, fa = arm_to(probe.sho, add(plate_c, 2.4, head), elbow_down=False)
        return Side(hip, 180, th, sh, ua, fa, head=head)
    with c.ghost():
        g = pose(168)
        draw_side(c, g, (), arm_behind=True)
        neck_plate(c, g, g.head_a + 90)
    p = pose(212)
    draw_side(c, p, ("neck",), arm_behind=True)
    neck_plate(c, p, p.head_a + 90)
    c.arc_arrow(p.neck, 15, 168, 222)
    c.shadow(16, 90)
    c.zoom = (2, 30, 62)


@scene("Flexion latérale nuque")
def neck_side(c):
    """Lying on the side on a flat bench, head past the end, plate on the upper side of the head (front view, turned)."""
    def figure(tilt, lit):
        f = Canvas(transparent=True)
        p = Front(50, FLOOR_Y - 2.5 - L["thigh"] - L["shin"], tilt=tilt, arms_r=(90, 90))
        plate_c = add(p.head, L["head"] + 1.3, 180 + tilt)
        abs_ua, abs_fa = arm_to(p[-1]["sho"], add(plate_c, 2.4, -90 + tilt), elbow_down=False)
        p = Front(50, p.hip_y, tilt=tilt, arms_r=(90, 90), arms_l=(180 - abs_ua, 180 - abs_fa))
        draw_front(f, p, lit, arms_behind_head=True)
        a = 90 + tilt
        f.capsule(add(plate_c, 6.5, a), add(plate_c, -6.5, a), 1.4, 1.4, (40, 41, 48))
        f.capsule(add(plate_c, 6.0, a), add(plate_c, -6.0, a), 0.8, 0.8, (78, 80, 92))
        f.glow_lit()
        return f, p
    c.bench((40, 66), seat=(-36, 34))
    g, _ = figure(0, ())
    faded = g.img.copy()
    faded.putalpha(faded.getchannel("A").point(lambda v: int(v * 0.26)))
    g.img = faded
    c.paste_rotated(g, 90, 0, 7)
    f, p = figure(-22, ("neck",))
    c.paste_rotated(f, 90, 0, 7)
    neck = (100 - p.neck[1], p.neck[0] + 7)
    c.arc_arrow(neck, 16, -8, -58)
    c.shadow(4, 78)
    c.zoom = (38, 24, 62)


# --- shoulders, chest -------------------------------------------------------------------------------------------
@scene("Développé épaules convergent")
def shoulder_press(c):
    p = front_seated(arms=(-38, -98))
    c.rect(p.cx - 9, p.sho_y - 10, p.cx + 9, p.sho_y - 4, PAD_HI, 2)
    front_seat(c, p)
    for s in (-1, 1):
        c.tube(p[s]["hand"], (p.cx + 20 * s, p.hip_y), 2.4, STEEL, STEEL_HI)
        c.tube((p.cx + 20 * s, p.hip_y), (p.cx + 20 * s, FLOOR_Y - 2), 2.6)
    c.base(p.cx - 26, p.cx + 26)
    draw_front(c, p, ("shoulders",))
    for s in (-1, 1):
        c.handle(p[s]["hand"], 0, 5)
        c.arrow([(p[s]["hand"][0] + 7 * s, p[s]["hand"][1] + 6), (p[s]["hand"][0] + 5 * s, p[s]["hand"][1] - 6)])
    c.shadow(24, 76)


@scene("Pec deck")
def pec_deck(c):
    p = front_seated(arms_l=(-25, -100), arms_r=(-25, -100))
    c.rect(p.cx - 24, 8, p.cx + 24, 12, FRAME, 1.4)
    for s in (-1, 1):
        c.tube((p.cx + 24 * s, 10), (p.cx + 24 * s, FLOOR_Y - 2), 3)
    c.base(p.cx - 28, p.cx + 28)
    front_seat(c, p)
    with c.ghost():
        draw_front(c, front_seated(arms_l=(-10, -60), arms_r=(-10, -60)), ())
    draw_front(c, p, ("chest",))
    for s in (-1, 1):
        q = p[s]
        c.pad(add(q["wr"], -3, 90), add(q["wr"], 9, 90), 4.6)
        c.tube(add(q["wr"], -4, 90), (q["wr"][0], 11), 1.8, STEEL, STEEL_HI)
        c.arrow([(q["wr"][0] + 5 * s, q["wr"][1] + 15), (q["wr"][0] - 6 * s, q["wr"][1] + 15)])
    c.shadow(28, 72)


@scene("Oiseau machine")
def rear_delt(c):
    p = front_seated(back=True, arms_l=(-4, -4), arms_r=(-4, -4))
    c.rect(p.cx - 30, 8, p.cx + 30, 12, FRAME, 1.4)
    c.tube((p.cx, 12), (p.cx, p.sho_y - 6), 3)
    c.rect(p.cx - 9, p.sho_y - 8, p.cx + 9, p.hip_y, PAD_HI, 2.5)
    c.rect(p.cx - 8.4, p.sho_y - 7.4, p.cx + 8.4, p.hip_y - 0.6, PAD, 2.2)
    front_seat(c, p, back=False)
    draw_front(c, p, ("rear",))
    for s in (-1, 1):
        q = p[s]
        c.tube(add(q["hand"], 2.5, -90), (q["hand"][0], 11), 1.8, STEEL, STEEL_HI)
        c.handle(q["hand"], 90, 5)
        c.arrow([(p.cx + 14 * s, p.sho_y - 7), (p.cx + 30 * s, p.sho_y - 7)])
    c.shadow(28, 72)


def side_pulley_raise(c, lit=("shoulders",)):
    p = front_standing(cx=54, arms_r=(-4, -4), arms_l=(8, 0))
    c.tower(18)
    c.pulley((20, 86))
    c.cable((20, 86), p[1]["hand"])
    with c.ghost():
        draw_front(c, front_standing(cx=54, arms_r=(84, 86), arms_l=(8, 0)), ())
    draw_front(c, p, lit)
    c.handle(p[1]["hand"], 90, 4)
    c.arc_arrow(p[1]["sho"], 30, 62, 4)
    c.shadow(30, 74)


@scene("Élévations latérales poulie")
def lateral_cable(c):
    side_pulley_raise(c)


@scene("Élévations latérales haltères")
def lateral_bench(c):
    p = front_seated(back=True, arms=(-2, -2))
    c.rect(p.cx - 7, p.sho_y - 9, p.cx + 7, p.sho_y, PAD_HI, 2)
    c.rect(p.cx - 6.4, p.sho_y - 8.4, p.cx + 6.4, p.sho_y - 0.5, PAD, 1.8)
    front_seat(c, p, back=False)
    with c.ghost():
        draw_front(c, front_seated(back=True, arms=(86, 88)), ())
    draw_front(c, p, ("shoulders",))
    for s in (-1, 1):
        c.dumbbell(p[s]["hand"], 90, 2.2, 2.6)
        c.arc_arrow(p[s]["sho"], 28, 60 if s > 0 else 120, 6 if s > 0 else 174)
    c.shadow(28, 72)


@scene("Développé incliné haltères")
def incline_db(c):
    hip = (58, 68)
    c.bench(hip, -150, seat=(-6, 10), back_len=30)
    th, sh = leg_to(hip, (78, 89))
    p = Side(hip, -150, th, sh, -88, -92)
    draw_side(c, p, ("chest",))
    c.dumbbell(p.hand, 0, 0.1, 3.0)
    c.arrow([(p.hand[0] + 8, p.hand[1] + 12), (p.hand[0] + 8, p.hand[1] - 1)])
    c.shadow(22, 86)


@scene("Développé incliné convergent ou Smith 30°", "Développé pectoraux convergent")
def incline_machine(c, name=None):
    hip = (40, 70)
    seat(c, hip, back=-128, back_len=30)
    sho = add(hip, L["torso"], -132)
    ua, fa = arm_to(sho, add(sho, 22, -40))
    p = Side(hip, -132, 2, 92, ua, fa)
    c.tube((10, 10), (26, 10), 3)
    c.tube(p.hand, (24, 10), 2.4, STEEL, STEEL_HI)
    c.tower(10, 6, 6)
    draw_side(c, p, ("chest",))
    c.handle(p.hand, 50, 5)
    c.arrow([add(p.hand, 4, 50), add(add(p.hand, 4, 50), 12, -40)])
    c.shadow(18, 76)


# --- back -------------------------------------------------------------------------------------------------------
def pulldown(c, neutral):
    p = front_seated(back=True, arms=(-40, -112) if not neutral else (-52, -100))
    c.rect(p.cx - 14, 4, p.cx + 14, 8, FRAME, 1.2)
    c.pulley((p.cx, 9))
    front_seat(c, p, back=False)
    for s in (-1, 1):
        c.pad((p.cx + 2 * s, p.hip_y - 4), (p.cx + 11 * s, p.hip_y - 4), 4)
    y = p[1]["hand"][1]
    draw_front(c, p, ("lats",))
    if neutral:
        for s in (-1, 1):
            h = p[s]["hand"]
            c.tube(h, (p.cx + 3 * s, 8), 2.2, STEEL, STEEL_HI)
            c.handle(h, 90, 5)
    else:
        c.cable((p.cx, 9), (p.cx, y - 1))
        c.capsule((p.cx - 27, y - 1), (p.cx + 27, y - 1), 0.9, 0.9, STEEL_HI)
        for s in (-1, 1):
            c.capsule((p.cx + 27 * s, y - 1), (p.cx + 24 * s, y + 2.5), 0.9, 0.9, STEEL_HI)
    for s in (-1, 1):
        c.arrow([(p.cx + 31 * s, y - 11), (p.cx + 31 * s, y + 2)])
    c.shadow(28, 72)


@scene("Tirage vertical convergent")
def lat_pulldown_wide(c):
    pulldown(c, False)


@scene("Tirage vertical large")
def lat_pulldown_neutral(c):
    pulldown(c, True)


def chest_row(c, one_arm):
    c.stack(86, 20, FLOOR_Y - 2)
    seat(c, back=None)
    p = seated(tor=-90, ua=4, fa=0, **({"ua2": 85, "fa2": 0} if one_arm else {}))
    chest = add(p.sho, 8.6, p.front)
    c.tube((chest[0] + 3, chest[1] + 10), (chest[0] + 3, FLOOR_Y - 2), 2.6)
    c.base(chest[0] - 4, 96)
    c.tube((p.hand[0] + 2, p.hand[1]), (86, 26), 2.4)
    draw_side(c, p, ("lats",))
    c.pad(add(chest, 7, -90), add(chest, -9, -90), 5.6)
    c.handle(p.hand, 90, 6)
    c.arrow([(p.hand[0] - 2, p.hand[1] - 8), (p.hand[0] - 15, p.hand[1] - 8)])
    c.shadow(25, 92)


@scene("Rowing machine")
def row_chest(c):
    chest_row(c, False)


@scene("Rowing poulie large")
def row_wide(c):
    chest_row(c, False)


@scene("Face pull")
def face_pull(c):
    p = front_standing(back=True, arms=(-14, -100))
    y = p.head[1] + 2
    c.tower(p.cx, 6, 6)
    c.pulley((p.cx, y))
    for s in (-1, 1):
        c.cable((p.cx, y), p[s]["hand"])
    draw_front(c, p, ("rear",))
    for s in (-1, 1):
        c.circ(p[s]["hand"], 1.4, (40, 40, 46))
        c.arrow([(p.cx + 14 * s, p.sho_y - 16), (p.cx + 28 * s, p.sho_y - 16)])
    c.shadow(32, 68)


@scene("Pull-over poulie")
def pullover(c):
    with c.ghost():
        draw_side(c, standing(x=40, tor=-78, th=94, sh=88, ua=-24, fa=-24), (), far_arm=False)
    p = standing(x=40, tor=-78, th=94, sh=88, ua=48, fa=48)
    c.tower(86)
    c.pulley((84, 10))
    c.cable((84, 10), p.hand)
    draw_side(c, p, ("lats",))
    c.rope(p.hand, 48)
    c.arc_arrow(p.sho, 31, -24, 60)
    c.shadow(28, 92)


# --- Hexis Elle ---------------------------------------------------------------------------------------------------
@scene("Hip thrust barre (ou machine)", "Hip thrust barre")
def hip_thrust(c):
    """Shoulder blades on a bench, feet flat: the hips drive up under a barbell until the torso is level; ghost: hips down."""
    sho, ankle = (30, 62.5), (68, FLOOR_Y - 1.5)
    def pose(drop):
        hip = add(sho, L["torso"], drop)
        th, sh = leg_to(hip, ankle)
        tor = angle(hip, sho)
        ua, fa = arm_to(add(hip, L["torso"], tor), add(hip, 3, -90))
        return Side(hip, tor, th, sh, ua, fa, head=tor + 20)
    c.bench((sho[0] + 1, sho[1]), seat=(-16, 3), y_seat=sho[1] + 4.4)
    with c.ghost():
        g = pose(28)
        draw_side(c, g, (), far_arm=False)
        plate(c, add(g.hip, 4.5, -90), 7)
    p = pose(2)
    draw_side(c, p, ("glutes",))
    plate(c, add(p.hip, 4.5, -90), 7)
    c.arrow([(p.hip[0] + 10, p.hip[1] + 16), (p.hip[0] + 10, p.hip[1] + 2)])
    c.shadow(16, 82)


@scene("Hack squat ou squat Smith, profond", "Squat Smith")
def smith_squat(c):
    """Deep squat under a Smith bar (rails on both sides), thighs just below parallel, chest up."""
    ankle = (52, FLOOR_Y - 1.5)
    hip = hip_from(ankle, -6, 114)
    tor = -66
    sho = add(hip, L["torso"], tor)
    bar = add(sho, 2.4, tor - 90)
    ua, fa = arm_to(sho, add(bar, 2.5, 200), elbow_down=True)
    p = Side(hip, tor, -6, 114, ua, fa)
    for x in (bar[0] - 13, bar[0] + 13):
        c.tube((x, 6), (x, FLOOR_Y - 1), 2.6)
    c.base(bar[0] - 19, bar[0] + 19)
    draw_side(c, p, ("quads", "glutes"))
    plate(c, bar, 6)
    c.arrow([(bar[0] + 22, hip[1] + 6), (bar[0] + 22, hip[1] - 16)])
    c.shadow(24, 76)


@scene("Soulevé de terre jambes tendues (RDL)", "RDL")
def romanian_deadlift(c):
    """Hip hinge, hips pushed back, soft knees, back flat, the bar sliding down the legs to mid-shin; ghost: standing tall."""
    ankle = (50, FLOOR_Y - 1.5)
    with c.ghost():
        g = standing(x=50, tor=-90, th=90, sh=92, ua=92, fa=92)
        draw_side(c, g, (), far_arm=False)
        plate(c, add(g.hand, 1.5, 90), 7)
    hip = hip_from(ankle, 74, 98)
    tor = -26
    sho = add(hip, L["torso"], tor)
    p = Side(hip, tor, 74, 98, 90, 90, head=tor + 6)
    draw_side(c, p, ("hams", "glutes"))
    plate(c, (p.hand[0], min(p.hand[1] + 1.5, FLOOR_Y - 7.2)), 7)
    c.arc_arrow(hip, 22, -84, -36)
    c.shadow(26, 80)


@scene("Presse à cuisses")
def leg_press_high(c):
    leg_press(c, (67, 47), lit=("glutes", "hams"))


@scene("Tirage vertical prise neutre", "Tirage vertical")
def lat_pulldown_neutral_close(c):
    pulldown(c, True)


@scene("Développé incliné haltères")
def incline_db_hers(c):
    incline_db(c)


@scene("Élévations latérales à la poulie")
def lateral_cable_hers(c):
    side_pulley_raise(c)


@scene("Abduction machine")
def abduction_hers(c):
    abduction(c)


@scene("Rowing poitrine appuyée")
def chest_supported_row(c):
    chest_row(c, False)


@scene("Élévations latérales haltères")
def lateral_standing(c):
    p = front_standing(arms=(-2, -2))
    with c.ghost():
        g = front_standing(arms=(86, 88))
        draw_front(c, g, ())
        for s in (-1, 1):
            c.dumbbell(g[s]["hand"], 90, 2.2, 2.6)
    draw_front(c, p, ("shoulders",))
    for s in (-1, 1):
        c.dumbbell(p[s]["hand"], 90, 2.2, 2.6)
        c.arc_arrow(p[s]["sho"], 28, 60 if s > 0 else 120, 6 if s > 0 else 174)
    c.shadow(28, 72)


@scene("Extension triceps poulie au-dessus de la tête", "Extension triceps poulie")
def overhead_cable_ext(c):
    """Back to a low pulley, staggered stance, rope behind the head, elbows up, forearms extended forward overhead."""
    c.tower(12)
    c.pulley((14, 84))
    with c.ghost():
        g = standing(x=50, tor=-70, ua=-112, fa=150, th=78, sh=96, th2=106, sh2=92)
        draw_side(c, g, (), far_arm=False)
    p = standing(x=50, tor=-70, ua=-112, fa=-82, th=78, sh=96, th2=106, sh2=92)
    c.cable((14, 84), add(p.hand, 1, 180))
    draw_side(c, p, ("triceps",))
    c.rope(p.hand, -82 + 180)
    c.arc_arrow(p.el, 15, 150, 280)
    c.shadow(30, 80)


@scene("Hip thrust machine")
def hip_thrust_machine(c):
    """Hip thrust machine: back on the backrest, feet on the platform, a padded lever across the hips driven up; ghost: hips down."""
    sho, ankle = (30, 62.5), (68, FLOOR_Y - 3.5)
    def pose(drop):
        hip = add(sho, L["torso"], drop)
        th, sh = leg_to(hip, ankle)
        tor = angle(hip, sho)
        ua, fa = arm_to(add(hip, L["torso"], tor), add(hip, 4, -110))
        return Side(hip, tor, th, sh, ua, fa, head=tor + 20)
    c.base(12, 84)
    c.step(56, 84, 2.5)
    c.pad((14, sho[1] + 2), (sho[0] + 3, sho[1] + 6), 5)
    c.tube((22, sho[1] + 6), (22, FLOOR_Y - 2), 3)
    c.tube((14, 34), (14, FLOOR_Y - 2), 3)
    with c.ghost():
        g = pose(28)
        draw_side(c, g, (), far_arm=False)
        c.pad(add(g.hip, 5, -100), add(g.hip, 5, -60), 4.6)
    p = pose(2)
    c.tube((14, 34), add(p.hip, 5.5, -80), 2.6)
    draw_side(c, p, ("glutes",))
    c.pad(add(p.hip, 5, -100), add(p.hip, 5, -60), 4.6)
    plate(c, (14, 34), 6)
    c.arrow([(p.hip[0] + 10, p.hip[1] + 16), (p.hip[0] + 10, p.hip[1] + 2)])
    c.shadow(12, 84)


@scene("Rowing machine")
def plate_row(c):
    """Plate-loaded chest-supported row: chest on the pad, handles pulled back, plates on the lever horn."""
    seat(c, back=None)
    p = seated(tor=-90, ua=4, fa=0)
    chest = add(p.sho, 8.6, p.front)
    c.tube((chest[0] + 3, chest[1] + 10), (chest[0] + 3, FLOOR_Y - 2), 2.6)
    c.base(chest[0] - 4, 96)
    pivot = (84, 30)
    c.tube((84, 30), (84, FLOOR_Y - 2), 3)
    c.tube(p.hand, pivot, 2.4)
    plate(c, add(pivot, 6, 120), 7)
    draw_side(c, p, ("lats",))
    c.pad(add(chest, 7, -90), add(chest, -9, -90), 5.6)
    c.handle(p.hand, 90, 6)
    c.arrow([(p.hand[0] - 2, p.hand[1] - 8), (p.hand[0] - 15, p.hand[1] - 8)])
    c.shadow(25, 92)


@scene("Curl haltères debout")
def standing_curl(c):
    p = standing(ua=96, fa=-60, ua2=92, fa2=92)
    with c.ghost():
        g = standing(ua=92, fa=92)
        draw_side(c, g, ())
        c.dumbbell(g.hand, 90, 6.5, 2.2)
    draw_side(c, p, ("biceps",))
    c.dumbbell(p.hand, 90, 6.5, 2.2)
    c.arc_arrow(p.el, 16, 80, -40)
    c.shadow(36, 64)


@scene("Curl incliné haltères")
def incline_curl_hers(c):
    incline_curl(c)


# --- arms -------------------------------------------------------------------------------------------------------
@scene("Extension triceps corde")
def pushdown(c):
    with c.ghost():
        draw_side(c, standing(x=42, tor=-84, ua=96, fa=-30), (), far_arm=False)
    p = standing(x=42, tor=-84, ua=96, fa=72)
    c.tower(80)
    c.pulley((78, 10))
    c.cable((78, 10), p.hand)
    draw_side(c, p, ("triceps",))
    c.rope(p.hand, 90)
    c.arc_arrow(p.el, 16, -10, 64)
    c.shadow(30, 88)


@scene("Curl marteau")
def hammer_curl(c):
    p = standing(ua=96, fa=-60, ua2=92, fa2=92)
    with c.ghost():
        g = standing(ua=92, fa=92)
        draw_side(c, g, ())
        c.dumbbell(g.hand, 0, 6.5, 2.2)
    draw_side(c, p, ("biceps",))
    c.dumbbell(p.hand, -60 - 90, 6.5, 2.2)
    c.arc_arrow(p.el, 16, 80, -40)
    c.shadow(36, 64)


@scene("Curl incliné haltères")
def incline_curl(c):
    hip = (58, 70)
    c.bench(hip, -135, seat=(-6, 10), back_len=30)
    th, sh = leg_to(hip, (78, 89))
    p = Side(hip, -133, th, sh, 100, 40)
    with c.ghost():
        g = Side(hip, -133, th, sh, 100, 102)
        draw_side(c, g, (), far_arm=False)
    draw_side(c, p, ("biceps",))
    c.dumbbell(p.hand, 0, 0.1, 2.8)
    c.arc_arrow(p.el, 16, 106, 22)
    c.shadow(22, 88)


@scene("Curl haltères assis banc 80°")
def seated_curl(c):
    c.bench(SEAT_HIP, -100)
    p = seated(tor=-98, ua=94, fa=-30)
    with c.ghost():
        draw_side(c, seated(tor=-98, ua=94, fa=94), (), far_arm=False)
    draw_side(c, p, ("biceps",))
    c.dumbbell(p.hand, 0, 0.1, 2.8)
    c.arc_arrow(p.el, 16, 80, -50)
    c.shadow(25, 75)


@scene("Extension triceps nuque incliné 60°")
def overhead_ext(c):
    hip = (56, 70)
    c.bench(hip, -122, seat=(-6, 10), back_len=30)
    th, sh = leg_to(hip, (76, 89))
    p = Side(hip, -120, th, sh, -98, 158)
    with c.ghost():
        draw_side(c, Side(hip, -120, th, sh, -98, -100), (), far_arm=False)
    draw_side(c, p, ("triceps",))
    c.dumbbell(p.hand, 158 + 90, 5, 2.4)
    c.arc_arrow(p.el, 16, 165, 255)
    c.shadow(22, 86)


@scene("Skull crusher haltères")
def incline_skull(c):
    hip = (58, 70)
    c.bench(hip, -135, seat=(-6, 10), back_len=30)
    th, sh = leg_to(hip, (78, 89))
    p = Side(hip, -133, th, sh, -124, 172)
    with c.ghost():
        draw_side(c, Side(hip, -133, th, sh, -124, -124), (), far_arm=False)
    draw_side(c, p, ("triceps",))
    c.dumbbell(p.hand, 0, 0.1, 2.8)
    c.arc_arrow(p.el, 17, 182, 250)
    c.shadow(22, 88)


@scene("Extension triceps allongée haltères banc plat")
def lying_ext(c):
    hip = (62, 63)
    c.bench(hip, seat=(-38, 8))
    th, sh = leg_to(hip, (80, 89))
    p = Side(hip, 180, th, sh, -96, 172, head=180)
    with c.ghost():
        draw_side(c, Side(hip, 180, th, sh, -96, -94, head=180), (), far_arm=False)
    draw_side(c, p, ("triceps",))
    c.dumbbell(p.hand, 90, 0.1, 2.8)
    c.arc_arrow(p.el, 16, 182, 268)
    c.shadow(20, 90)


# --- cardio, legacy ---------------------------------------------------------------------------------------------
@scene("Vélo intervalles")
def bike(c):
    crank, seat_p, bars, wheel = (52, 80), (36, 55), (68, 42), (76, 76)
    c.base(22, 88)
    c.circ(wheel, 10, (44, 45, 52)); c.circ(wheel, 8.8, SHROUD_LO); c.circ(wheel, 7.6, SHROUD); c.circ(wheel, 2, FRAME)
    c.tube((38, 60), (46, FLOOR_Y - 2), 3)
    c.tube((40, 64), crank, 3)
    c.tube(crank, wheel, 3)
    c.tube(wheel, (70, 46), 3)
    c.tube((38, 60), seat_p, 2)
    hip = (seat_p[0], seat_p[1] - 3)
    near_p, far_p = add(crank, 7, 50), add(crank, 7, 230)
    th, sh = leg_to(hip, add(near_p, 3.2, -90))
    th2, sh2 = leg_to(hip, add(far_p, 3.2, -90))
    sho = add(hip, L["torso"], -58)
    ua, fa = arm_to(sho, add(bars, -1.6, 0))
    p = Side(hip, -58, th, sh, ua, fa, foot=0, th2=th2, sh2=sh2, foot2=0)
    c.capsule(far_p, crank, 0.9, 0.9, STEEL)
    draw_side(c, p, ("quads",))
    c.capsule(crank, near_p, 0.9, 0.9, STEEL_HI)
    c.pad((seat_p[0] - 5, seat_p[1]), (seat_p[0] + 4, seat_p[1]), 3.2)
    c.tube((70, 46), (bars[0] + 2, bars[1]), 2.4)
    c.circ(crank, 2.2, STEEL)
    c.arc_arrow(wheel, 15, -150, -30)
    c.shadow(22, 90)


@scene("Pallof press")
def pallof(c):
    p = front_standing(cx=54, arms=(-2, -2))
    c.tower(12)
    c.pulley((14, p[1]["hand"][1]))
    c.cable((14, p[1]["hand"][1]), (p.cx, p[1]["hand"][1]))
    p.sides[1]["el"] = p.sides[1]["wr"] = p.sides[1]["hand"] = (p.cx + 2, p[1]["sho"][1] + 8)
    p.sides[-1]["el"] = p.sides[-1]["wr"] = p.sides[-1]["hand"] = (p.cx - 2, p[-1]["sho"][1] + 8)
    draw_front(c, p, ("abs",))
    c.arrow([(p.cx - 6, p.sho_y - 10), (p.cx + 6, p.sho_y - 10)])
    c.shadow(32, 76)


# --- calf rehab -------------------------------------------------------------------------------------------------
STEP_TOP = FLOOR_Y - 7


def calf_raise(c, knee_bend=0, dumbbell=False, hold_it=False):
    c.step(46, 72, 7)
    c.upright(84, 30)
    ankle = (47.5, STEP_TOP - 3.2)
    th, sh = 90 - knee_bend, 90 + knee_bend * 0.6
    hip = hip_from(ankle, th, sh)
    sho = add(hip, L["torso"], -90)
    ua, fa = arm_to(sho, (82, sho[1] + 10))
    k = dict(ua2=ua, fa2=fa) if dumbbell else {}
    near_ua, near_fa = (92, 92) if dumbbell else (ua, fa)
    p = Side(hip, -90, th, sh, near_ua, near_fa, foot=-22, th2=120, sh2=150, foot2=60, **k)
    draw_side(c, p, ("calves",))
    if dumbbell:
        c.dumbbell(p.hand, 0, 0.1, 2.8)
    c.arrow([(38, FLOOR_Y - 2), (38, STEP_TOP - 12)])
    c.shadow(40, 76, STEP_TOP)


@scene("Relevés 1 pied genou tendu")
def calf_straight(c):
    calf_raise(c)


@scene("Relevés 1 pied genou fléchi")
def calf_bent(c):
    calf_raise(c, knee_bend=24)


@scene("Relevés 1 pied haltère")
def calf_db(c):
    calf_raise(c, dumbbell=True)


def split(c, front_ankle, back_ankle, lift_back=False, dumbbells=False, support=True, lit=("calves",)):
    hip = (front_ankle[0] - 12, front_ankle[1] - 27)
    th, sh = leg_to(hip, front_ankle)
    th2, sh2 = leg_to(hip, back_ankle)
    sho = add(hip, L["torso"], -90)
    if support:
        c.upright(84, 30)
        ua, fa = arm_to(sho, (82, sho[1] + 12))
    else:
        ua, fa = 92, 92
    p = Side(hip, -90, th, sh, ua, fa, th2=th2, sh2=sh2, foot2=80 if not lift_back else -180, ua2=92, fa2=92)
    draw_side(c, p, lit)
    if dumbbells:
        c.dumbbell(p.hand, 0, 0.1, 2.8)
    return p


@scene("Fente isométrique angle douloureux")
def split_hold(c):
    split(c, (60, FLOOR_Y - 3.4), (26, FLOOR_Y - 4.5))
    hold(c, (14, 40))
    c.shadow(18, 72)


@scene("Fente bulgare haltères légère", "Fente bulgare Smith")
def bulgarian(c, name=None):
    c.bench((18, 70), seat=(-10, 10))
    p = split(c, (62, FLOOR_Y - 3.4), (25, 71), lift_back=True, dumbbells=True, support=False, lit=("quads",))
    c.arrow([(p.hip[0] + 14, p.hip[1] - 12), (p.hip[0] + 14, p.hip[1] + 2)])
    c.shadow(8, 72)


@scene("Descente lente 1 jambe", "Step-down lent")
def step_down(c):
    c.step(20, 46, 13)
    top = FLOOR_Y - 13
    near = (40, top - 3.2)
    hip = (near[0] - 10, near[1] - 22)
    th, sh = leg_to(hip, near)
    th2, sh2 = leg_to(hip, (50, FLOOR_Y - 4.2))
    p = Side(hip, -84, th, sh, 8, -4, th2=th2, sh2=sh2, foot2=-8)
    draw_side(c, p, ("quads",))
    c.arrow([(68, FLOOR_Y - 26), (68, FLOOR_Y - 6)])
    c.shadow(22, 64, top)


def single_leg_hold(c, th, sh, tor):
    """Right leg bent and held still, left leg straight in front, hand on an upright."""
    c.upright(72, 30)
    ankle = (44, FLOOR_Y - 3.4)
    hip = hip_from(ankle, th, sh)
    sho = add(hip, L["torso"], tor)
    ua, fa = arm_to(sho, (71, sho[1] + 8))
    p = Side(hip, tor, th, sh, ua, fa, th2=8, sh2=10, foot2=-70, ua2=ua, fa2=fa)
    draw_side(c, p, ("calves", "quads"))
    hold(c, (16, 34))
    c.shadow(26, 66)


@scene("Squat 1 jambe tenu")
def single_leg_quarter(c):
    single_leg_hold(c, th=58, sh=112, tor=-82)


@scene("Squat 1 jambe tenu au point")
def single_leg_deep(c):
    single_leg_hold(c, th=32, sh=122, tor=-72)


@scene("Montée de marche en poussée")
def step_up(c):
    c.bench((64, 70), seat=(-10, 14))
    hip = (50, 48)
    th, sh = leg_to(hip, (60, 72.2 - 3.2))
    th2, sh2 = leg_to(hip, (36, FLOOR_Y - 4))
    p = Side(hip, -86, th, sh, 96, 80, th2=th2, sh2=sh2, foot2=40, ua2=80, fa2=60)
    draw_side(c, p, ("quads",))
    c.arrow([(30, 56), (30, 40)])
    c.shadow(30, 80)


@scene("Pistol sur box")
def box_pistol(c):
    c.bench((30, 70), seat=(-12, 10))
    hip = (36, 66)
    th, sh = leg_to(hip, (52, FLOOR_Y - 3.4))
    p = Side(hip, -62, th, sh, -6, -6, th2=-6, sh2=-4, foot2=-90)
    draw_side(c, p, ("quads",))
    c.arrow([(18, 64), (18, 48)])
    c.shadow(14, 70)


@scene("Petits sauts sur place")
def pogo(c):
    lift = 5
    p = Side((48, FLOOR_Y - 1.5 - L["thigh"] - L["shin"] - lift - 2), -90, 92, 88, 96, 60, foot=30)
    draw_side(c, p, ("calves",))
    c.arrow([(70, FLOOR_Y - 4), (70, FLOOR_Y - 20)])
    c.arrow([(76, FLOOR_Y - 20), (76, FLOOR_Y - 4)])
    c.shadow(38, 62)


# --- output -----------------------------------------------------------------------------------------------------
def slug(name):
    folded = unicodedata.normalize("NFD", name).encode("ascii", "ignore").decode().lower()
    word, out = "", []
    for ch in folded:
        if ch.isalnum(): word += ch
        elif word: out.append(word); word = ""
    if word: out.append(word)
    return "exo-" + "-".join(out)


PROGRAM = "Hexis/Resources/Program.json"
ASSETS, PREFIX = "Hexis/Assets.xcassets", ""


def program_names():
    found = []

    def walk(o):
        if isinstance(o, dict):
            if "name" in o and "muscleGroup" in o and o["name"] not in found:
                found.append(o["name"])
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)

    walk(json.load(open(PROGRAM)))
    return found


def render(name):
    c = Canvas()
    SCENES[name](c)
    c.glow_lit()
    return c


def main():
    global PROGRAM, ASSETS, PREFIX
    args = sys.argv[1:]
    if "--elle" in args:
        args.remove("--elle")
        use_her_figure()
        PROGRAM, ASSETS, PREFIX = "HexisElle/Program.json", "HexisElle/Assets.xcassets", "elle-"
    sheet = None
    if "--sheet" in args:
        i = args.index("--sheet")
        sheet = args[i + 1]
        del args[i:i + 2]
    names = args or [n for n in program_names() if n in SCENES] + ([] if PREFIX else [n for n in SCENES if n not in program_names()])
    if sheet:
        cols, cell = 4, 300
        rows = math.ceil(len(names) / cols)
        im = Image.new("RGB", (cols * cell, rows * (cell + 18)))
        g = ImageDraw.Draw(im)
        for i, name in enumerate(names):
            x, y = (i % cols) * cell, (i // cols) * (cell + 18)
            im.paste(render(name).thumb(cell), (x, y))
            g.text((x + 4, y + cell + 3), name[:44], fill=(255, 255, 255))
        im.save(sheet)
        print(len(names), "drawn,", [n for n in program_names() if n not in SCENES], "missing")
        return
    for name in names:
        asset = PREFIX + slug(name)
        folder = f"{ASSETS}/{asset}.imageset"
        os.makedirs(folder, exist_ok=True)
        render(name).save(f"{folder}/{asset}.png")
        json.dump({"images": [{"filename": f"{asset}.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}},
                  open(f"{folder}/Contents.json", "w"), indent=2)
    print(len(names), "images written")


if __name__ == "__main__":
    main()
