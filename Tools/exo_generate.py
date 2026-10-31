"""Generates a photorealistic picture of every exercise of Program.json with Gemini (gemini-3-pro-image), then imports them.

Needs billing enabled on the Gemini key (image models are not in the free tier); ~0.13 $ per picture.
From the repo root:  python3 Tools/exo_generate.py            (only the missing ones)
                     python3 Tools/exo_generate.py "Pec deck"  (redo these)
Pictures land in Tools/generated/ (ignored by Git), then Tools/exo_import.py turns them into assets.
"""
import base64, json, os, plistlib, subprocess, sys, time, urllib.error, urllib.request

MODEL = "gemini-3-pro-image"
OUT = "Tools/generated"

STYLE = (
    "High-quality 3D anatomical fitness illustration, square 1:1, like a premium workout app (Muscle & Motion style). "
    "Smooth matte light-grey 3D male figure with visible muscle definition, athletic build, no clothes details, no face details. "
    "The muscles worked by the exercise are highlighted in bright RED, every other muscle stays light grey. "
    "Equipment rendered in clean 3D: Matrix Fitness machines as found in Basic-Fit, black frame, silver-grey covers, "
    "black upholstery, weight stack with pin, accurate proportions. "
    "Plain very dark charcoal background, soft studio light, subtle floor shadow. "
    "Anatomically correct body, natural grip. Whole machine and whole body visible, centered, nothing cropped. "
    "No text, no labels, no arrows, no logos, no watermark. "
)

# What the picture must show. The orientation (where he faces, what touches what) is the part generators get wrong: be explicit.
SCENES = {
    "Squat 1 jambe tenu": "Single-leg quarter squat hold, no weights: standing on the RIGHT leg only, right foot flat on the floor, right knee slightly bent, LEFT leg held straight out in front just above the floor, torso upright, right hand lightly holding a rack upright for balance, holding still. Side view.",
    "Squat 1 jambe tenu au point": "Single-leg half squat hold, no weights: standing on the RIGHT leg only, right foot flat, right knee bent about 60 degrees so the ankle is well flexed, LEFT leg held straight out in front, torso slightly forward, one hand lightly on a rack upright, holding still. Side view.",
    "Skull crusher haltères": "Incline dumbbell skull crusher on an adjustable bench at 45 degrees: back and head against the backrest, ONE dumbbell in EACH hand, palms facing each other, upper arms angled back past vertical toward the head, elbows bent so the dumbbells are lowered behind the head. Side view.",
    "Isométrie mollets assis": "Seated calf raise machine (Matrix). He sits, thighs under the padded lever just above the knees, balls of the feet on the foot platform, heels lowered slightly below the platform and held still. Side view.",
    "Relevés 1 pied genou tendu": "Single-leg calf raise on the edge of a low step platform: ball of the right foot on the edge, heel hanging below, right knee straight, left foot lifted behind, one hand lightly on a rack upright for balance. Side view.",
    "Relevés 1 pied genou fléchi": "Single-leg calf raise on the edge of a low step platform with the right knee bent about 25 degrees: ball of the right foot on the edge, heel hanging below, left foot lifted, one hand on a rack upright. Side view.",
    "Fente isométrique angle douloureux": "Static split squat hold without weights: right foot forward flat, left foot back on the toes, both knees bent, torso upright, one hand on a rack upright for balance, holding still. Side view.",
    "Relevés 1 pied haltère": "Single-leg calf raise on the edge of a low step: holding one dumbbell in the right hand along the body, left hand on a rack upright, standing on the ball of the right foot with the heel at the bottom, left foot lifted. Side view.",
    "Descente lente 1 jambe": "Slow step-down: standing on the right leg on a 15 cm aerobic step, slowly lowering the left heel towards the floor in front of the step, right knee bent and aligned over the toes, arms forward for balance. Three-quarter front view.",
    "Fente bulgare haltères légère": "Bulgarian split squat with two light dumbbells: rear (left) foot laces down on a flat bench behind him, right foot forward on the floor, descending with torso upright, dumbbells hanging at his sides. Side view.",
    "Montée de marche en poussée": "Step-up onto a flat bench: right foot on the bench, pushing up, left leg trailing below, torso upright, arms relaxed. Side view.",
    "Pistol sur box": "Single-leg box squat: sitting down onto a flat bench on the right leg only, left leg extended straight forward off the floor, arms forward. Side view.",
    "Petits sauts sur place": "Small pogo hops in place on the gym floor, feet together, both feet slightly off the floor, knees soft, arms relaxed. Front three-quarter view.",
    "Presse horizontale unilatérale": "Matrix seated horizontal leg press (seated leg press, he sits leaning back, the vertical foot platform in front of him). Only his RIGHT foot is on the platform, placed HIGH on the plate; left foot resting on the floor/frame; knee bent, back against the backrest, hands on the side handles. Side view.",
    "Leg curl assis": "Matrix seated leg curl machine: he sits upright, thighs held down by the thigh pad, the lower leg pad behind his ankles, knees bent pulling the pad down and back under the seat, toes pointed, hands on the handles. Side view.",
    "Leg extension": "Matrix leg extension machine: he sits upright, back against the backrest, ankle pad on the front of his shins, legs extended straight forward at the top of the movement, hands on the side handles. Side view.",
    "Mollets assis presse": "Matrix seated calf raise machine: he sits, the padded lever resting on his thighs just above the knees, balls of both feet on the foot block, heels lowered below it at the stretched bottom position. Side view.",
    "Shrugs haltères debout": "Standing dumbbell shrugs: standing tall, a heavy dumbbell in each hand at his sides, arms straight, shoulders raised up towards his ears. Front view.",
    "Extension triceps nuque incliné 60°": "Overhead dumbbell triceps extension on an adjustable bench set at 60 degrees incline: he sits with his back on the bench, holding ONE dumbbell with both hands behind his head, elbows pointing up to the ceiling, forearms lowered behind the head. Side view.",
    "Curl incliné haltères": "Incline dumbbell curl: lying back on an adjustable bench at 45 degrees, arms hanging straight down behind the line of the torso, palms forward, curling the dumbbells up with elbows fixed. Side view.",
    "Abduction machine": "Matrix hip abduction machine (inner/outer thigh): he sits with the outer pads against the OUTSIDE of his knees, pushing his legs apart, torso leaning slightly forward, hands on the handles. Front view.",
    "Ab wheel": "Kneeling ab wheel rollout on a mat: on his knees, both hands on the handles of an ab wheel rolled forward, arms straight, body extended in a straight line, lower back neutral, not sagging. Side view.",
    "Neck extension": "Neck extension with a weight plate, no machine: he lies FACE DOWN on a flat bench, shoulders at the end of the bench, head hanging past the end, a weight plate on a towel on the BACK of his head held with both hands, raising his head up. Side view.",
    "Neck flexion": "Neck flexion with a weight plate, no machine: he lies on his BACK on a flat bench, shoulders at the end of the bench, head hanging past the end, a weight plate on a towel on his FOREHEAD held with both hands, lifting his chin toward his chest. Feet flat on the floor. Side view.",
    "Flexion latérale nuque": "Lateral neck flexion with a weight plate, no machine: he lies on his SIDE on a flat bench, shoulder at the end of the bench, head past the end, a weight plate on the upper side of his head held with one hand, raising his ear toward his upper shoulder. View from the front of his body.",
    "Développé épaules convergent": "Matrix converging shoulder press machine: he sits upright, back against the backrest, gripping the handles at shoulder height, pressing them overhead, elbows under the wrists. Front three-quarter view.",
    "Tirage vertical convergent": "Matrix converging lat pulldown machine (separate handles): he sits facing the machine, thighs under the knee pads, both handles held with a wide overhand grip, pulling them down to his upper chest, chest up, elbows down. Side three-quarter view from behind.",
    "Développé incliné haltères": "Incline dumbbell press on an adjustable bench at 30 degrees: lying back, shoulder blades squeezed, pressing two dumbbells up above the upper chest, feet flat on the floor. Side view.",
    "Rowing machine": "Matrix seated row machine with chest pad: he sits facing the machine, chest pressed against the chest pad, pulling the handles back towards his torso, elbows driving back. Side view.",
    "Élévations latérales poulie": "Single-arm cable lateral raise: standing side-on to a cable tower, the cable comes from the LOW pulley and passes BEHIND his back to his far hand, he raises that straight arm out to the side up to shoulder height, the other hand on the tower. Front view.",
    "Extension triceps corde": "Cable triceps pushdown with a rope: standing facing a cable tower, rope attached to the HIGH pulley, elbows tucked at his sides, arms extended down, rope ends spread apart at the bottom. Side view.",
    "Curl marteau": "Standing dumbbell hammer curl: palms facing each other (neutral grip), one dumbbell curled up to the shoulder, elbow fixed at the side. Front three-quarter view.",
    "Shrugs haltères assis": "Seated dumbbell shrugs on an adjustable bench set almost upright (80 degrees): his back against the backrest, a dumbbell in each hand hanging at his sides, shoulders raised to his ears. Front three-quarter view.",
    "Presse à cuisses": "Matrix seated horizontal leg press: he sits leaning back against the backrest, BOTH feet in the middle-upper part of the vertical foot platform in front of him, knees bent at the bottom of the movement, hands on the side handles. Side view.",
    "Mollets à la presse": "Calf press on a Matrix seated horizontal leg press: legs almost straight, only the balls of both feet on the BOTTOM edge of the foot platform, heels hanging off, ankles extended. Side view.",
    "Leg curl allongé": "Matrix lying (prone) leg curl machine: he lies FACE DOWN on the bench, hips pressed into the pad, the roller pad behind his ankles, curling his heels up towards his glutes, hands on the front handles. Side view.",
    "Face pull": "Cable face pull: standing facing a cable tower, rope attached at eye height, pulling the rope towards his face, elbows high and wide, hands spreading apart beside his ears. Side three-quarter view.",
    "Pull-over poulie": "Standing cable straight-arm pulldown with a rope: facing a cable tower, rope on the HIGH pulley, hips hinged slightly, arms nearly straight bringing the rope down from overhead to his thighs. Side view.",
    "Rowing poulie large": "Seated cable row station: he sits facing the machine, chest against the pad, pulling a long straight bar with a wide overhand grip (palms down) to his lower chest, elbows back and out. Side view.",
    "Tirage vertical large": "Cable lat pulldown station: he sits facing the machine, thighs under the pads, pulling a wide bar with neutral-grip handles (palms facing each other) down to his upper chest, chest up. Front three-quarter view.",
    "Développé incliné convergent ou Smith 30°": "Matrix incline chest press machine (converging): he sits leaning back on an inclined backrest about 30 degrees, pressing the handles forward and up in front of his upper chest. Side view.",
    "Oiseau machine": "Matrix rear delt / pec fly combination machine used for REAR DELT fly: he sits FACING the machine, chest pressed against the backrest pad, arms nearly straight holding the handles in front, opening them out and backwards. View from behind at three-quarter.",
    "Pec deck": "Matrix pec fly / pec deck machine: he sits with his BACK against the backrest, arms open wide holding the handles with elbows soft, bringing them together in front of his chest. Front view.",
    "Élévations latérales haltères": "Chest-supported dumbbell lateral raise: he leans his chest against an adjustable bench set at 80 degrees (nearly upright), facing the backrest, raising two dumbbells out to the sides to shoulder height. Front three-quarter view.",
    "Extension triceps allongée haltères banc plat": "Lying dumbbell triceps extension on a flat bench: lying on his back, upper arms pointing up to the ceiling, elbows bent, two dumbbells lowered beside and behind his head. Side view.",
    "Curl haltères assis banc 80°": "Seated dumbbell curl on an adjustable bench at 80 degrees: back against the backrest, curling two dumbbells with palms up (supinated), elbows fixed at his sides. Front three-quarter view.",
    "Vélo intervalles": "Matrix upright exercise bike: he rides seated, hands on the handlebars, sweating slightly, legs pedalling hard. Side view.",
}


def names():
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

    walk(json.load(open("Hexis/Resources/Program.json")))
    return found


def generate(key, name):
    body = {
        "contents": [{"parts": [{"text": STYLE + "Exercise: " + SCENES[name]}]}],
        "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": "1:1"}},
    }
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={key}"
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    for attempt in range(3):
        try:
            reply = json.load(urllib.request.urlopen(req, timeout=240))
            for part in reply["candidates"][0]["content"]["parts"]:
                if "inlineData" in part:
                    return base64.b64decode(part["inlineData"]["data"])
            return None
        except urllib.error.HTTPError as e:
            message = json.loads(e.read()).get("error", {}).get("message", "")
            if e.code == 429 and "free_tier" in message:
                sys.exit("Gemini: image models need billing on this key (free tier = 0).")
            print(f"  {e.code} {message[:120]}, retry")
            time.sleep(20 * (attempt + 1))
    return None


def main():
    with open("Hexis/Secrets.plist", "rb") as f:
        key = plistlib.load(f)["GeminiAPIKey"]
    os.makedirs(OUT, exist_ok=True)
    wanted = sys.argv[1:] or names()
    missing = [n for n in wanted if n not in SCENES]
    if missing:
        sys.exit(f"No scene for: {missing}")
    for name in wanted:
        path = f"{OUT}/{name}.png"
        if not sys.argv[1:] and os.path.exists(path):
            continue
        print("…", name)
        data = generate(key, name)
        if data:
            open(path, "wb").write(data)
    subprocess.run([sys.executable, "Tools/exo_import.py", OUT], check=True)


main()
