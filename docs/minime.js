/* OnPace mini-me — browser canvas port of Steps/Characters.swift (SwiftUI Canvas).
 *
 * Classic script, no dependencies. Defines window.MiniMe:
 *   MiniMe.draw(ctx, { avatar, mood, t, look, x, y, size, prop })
 *   MiniMe.options            every option, same ids as the Swift raw values
 *   MiniMe.defaultLook(body)  Look.starter (female = starter after switchTo(.female))
 *   MiniMe.originalLook()     Look() — turban, full beard, purple & gold
 *   MiniMe.classicLook(avatar) Look.classic(avatar) — what the watch draws when look is nil
 *   MiniMe.switchBody(look, body)  Look.switchTo: returns a new look with matching defaults
 *   MiniMe.partner(swatchId)  Swatch.partner: the trim color the builder picks for a main color
 *   MiniMe.mount(canvas, getState) -> stop()
 *
 * Like the app, everyone is drawn on a 100 x 140 grid. All numbers below are the
 * app's own numbers; keep them in step with Characters.swift.
 */
(function (root) {
  'use strict';

  // ---------- Colors (r, g, b in 0...1, exactly as in the Swift) ----------

  var SKIN = {
    light: [0.98, 0.84, 0.73], fair: [0.93, 0.74, 0.58], tan: [0.78, 0.56, 0.40],
    medium: [0.63, 0.43, 0.29], brown: [0.47, 0.31, 0.20], deep: [0.31, 0.20, 0.14]
  };
  var HAIR_COLOR = {
    black: [0.10, 0.09, 0.08], darkBrown: [0.25, 0.16, 0.10], brown: [0.45, 0.30, 0.18],
    blonde: [0.86, 0.70, 0.40], red: [0.70, 0.30, 0.15], gray: [0.72, 0.72, 0.72]
  };
  var LIPS = {
    natural: [0.95, 0.6, 0.6], pink: [0.96, 0.38, 0.62], red: [0.84, 0.10, 0.18], berry: [0.55, 0.12, 0.32]
  };
  var SWATCH = {
    purple: [0.36, 0.16, 0.56], gold: [0.99, 0.73, 0.15], navy: [0.12, 0.22, 0.50],
    blue: [0.20, 0.48, 0.90], red: [0.85, 0.18, 0.20], orange: [0.96, 0.52, 0.12],
    green: [0.15, 0.55, 0.30], teal: [0.10, 0.62, 0.62], pink: [0.95, 0.45, 0.65],
    black: [0.12, 0.12, 0.13], white: [0.96, 0.96, 0.96], gray: [0.50, 0.50, 0.53]
  };
  var BLACK = [0, 0, 0], WHITE = [1, 1, 1];
  var EYES = [0.10, 0.09, 0.08];            // Pen.hair
  var PANTS = [0.86, 0.83, 0.75];           // Golfer.pants
  var BALL = [0.93, 0.48, 0.15];            // Baller.ballColor
  var WOOD = [0.55, 0.36, 0.20], PACK = [0.30, 0.45, 0.25];

  function gray(w) { return [w, w, w]; }
  function lighten(c) { return [c[0] + (1 - c[0]) * 0.3, c[1] + (1 - c[1]) * 0.3, c[2] + (1 - c[2]) * 0.3]; }
  function css(c, a) {
    var r = Math.round(c[0] * 255), g = Math.round(c[1] * 255), b = Math.round(c[2] * 255);
    return (a === undefined || a >= 1) ? 'rgb(' + r + ',' + g + ',' + b + ')'
                                       : 'rgba(' + r + ',' + g + ',' + b + ',' + a + ')';
  }
  function hex(c) {
    return '#' + c.map(function (v) {
      var h = Math.round(v * 255).toString(16); return h.length < 2 ? '0' + h : h;
    }).join('');
  }
  function swatchLight(id) {                 // Swatch.light (turban folds)
    if (id === 'navy') return [0.24, 0.36, 0.66];
    if (id === 'white') return gray(0.78);
    return lighten(SWATCH[id]);
  }
  function partner(id) {                     // Swatch.partner
    if (id === 'gold' || id === 'orange' || id === 'pink' || id === 'white') return 'navy';
    if (id === 'gray') return 'black';
    return 'white';
  }

  // ---------- Looks ----------

  function originalLook() {                  // Look()
    return { skin: 'tan', hair: 'turban', hairColor: 'black', beard: 'full', glasses: 'none',
             body: 'male', lashes: false, lips: 'natural', bottoms: 'pants', top: 'tank',
             hat: 'navy', hatTrim: null, main: 'purple', accent: 'gold', letter: 'J' };
  }
  function starterLook() {                   // Look.starter
    var l = originalLook();
    l.skin = 'medium'; l.hair = 'short'; l.hairColor = 'darkBrown'; l.beard = 'none';
    l.hat = 'navy'; l.main = 'blue'; l.accent = 'white'; l.letter = '1';
    return l;
  }
  function classicLook(avatar) {             // Look.classic(avatar)
    var l = originalLook();
    if (avatar === 'golfer') l.glasses = 'sunglasses';
    else if (avatar === 'baller') { l.hat = 'purple'; l.hatTrim = 'gold'; }
    return l;
  }
  function bodyId(b) {                       // the app saves male/female as "straight"/"curvy"
    return (b === 'female' || b === 'curvy') ? 'female' : 'male';
  }
  var HAIR_FOR = {
    male: ['turban', 'short', 'curly', 'bald', 'cap'],
    female: ['hijab', 'short', 'long', 'longCurly', 'ponytail', 'braids', 'bun', 'cap']
  };
  function switchBody(look, body) {          // Look.switchTo
    var l = normalize(look), nb = bodyId(body);
    if (nb === l.body) return l;
    l.body = nb;
    if (nb === 'female') {
      l.lashes = true; l.lips = 'pink'; l.beard = 'none';
      if (HAIR_FOR.female.indexOf(l.hair) < 0) l.hair = 'ponytail';
      l.bottoms = 'skort'; l.top = 'sportsTop';
    } else {
      var s = starterLook();
      l.lashes = false; l.lips = 'natural'; l.beard = s.beard;
      if (HAIR_FOR.male.indexOf(l.hair) < 0) l.hair = s.hair;
      l.hat = s.hat; l.hatTrim = null; l.bottoms = 'pants'; l.top = 'tank';
    }
    return l;
  }
  function defaultLook(body) {
    return bodyId(body) === 'female' ? switchBody(starterLook(), 'female') : starterLook();
  }
  // Missing or unknown fields fall back to the defaults (like the Swift decoder).
  function normalize(look) {
    var d = originalLook(), l = look || {}, o = {};
    function pick(key, table) { o[key] = (l[key] != null && table[l[key]] !== undefined) ? l[key] : d[key]; }
    pick('skin', SKIN);
    o.hair = HAIR_NAMES[l.hair] ? l.hair : d.hair;
    pick('hairColor', HAIR_COLOR);
    o.beard = BEARD_NAMES[l.beard] ? l.beard : d.beard;
    o.glasses = GLASSES_NAMES[l.glasses] ? l.glasses : d.glasses;
    o.body = l.body == null ? d.body : bodyId(l.body);
    o.lashes = l.lashes == null ? d.lashes : !!l.lashes;
    pick('lips', LIPS);
    o.bottoms = l.bottoms === 'skort' ? 'skort' : (l.bottoms === 'pants' ? 'pants' : d.bottoms);
    o.top = l.top === 'sportsTop' ? 'sportsTop' : (l.top === 'tank' ? 'tank' : d.top);
    pick('hat', SWATCH);
    o.hatTrim = (l.hatTrim != null && SWATCH[l.hatTrim]) ? l.hatTrim : null;
    pick('main', SWATCH);
    pick('accent', SWATCH);
    o.letter = l.letter == null ? d.letter : String(l.letter);
    return o;
  }

  var HAIR_NAMES = { turban: 'Turban', hijab: 'Hijab', short: 'Short', long: 'Long', longCurly: 'Long curly',
                     ponytail: 'Ponytail', braids: 'Braids', curly: 'Curly', bun: 'Bun', bald: 'Bald', cap: 'Cap' };
  var BEARD_NAMES = { none: 'No beard', stubble: 'Stubble', mustache: 'Mustache', full: 'Full' };
  var GLASSES_NAMES = { none: 'None', glasses: 'Glasses', sunglasses: 'Sunglasses' };

  // ---------- Drawing helpers (Pen) ----------

  var c = null;   // the 2D context being drawn into

  function reach(from, deg, length) {        // 0 = straight down, + = toward screen right
    var a = deg * Math.PI / 180;
    return { x: from.x + Math.sin(a) * length, y: from.y + Math.cos(a) * length };
  }
  function P(x, y) { return { x: x, y: y }; }

  function line(a, b, color, width, alpha) { // Pen.line: round caps
    c.beginPath(); c.moveTo(a.x, a.y); c.lineTo(b.x, b.y);
    c.strokeStyle = css(color, alpha); c.lineWidth = width; c.lineCap = 'round'; c.lineJoin = 'miter';
    c.stroke();
  }
  function dot(p, r, color, alpha) {
    c.beginPath(); c.arc(p.x, p.y, r, 0, Math.PI * 2);
    c.fillStyle = css(color, alpha); c.fill();
  }
  function ellipsePath(x, y, w, h) {         // Path(ellipseIn:)
    c.beginPath(); c.ellipse(x + w / 2, y + h / 2, w / 2, h / 2, 0, 0, Math.PI * 2);
  }
  function rrPath(x, y, w, h, r) {           // Path(roundedRect:cornerRadius:) (circular corners)
    r = Math.min(r, w / 2, h / 2);
    c.beginPath();
    c.moveTo(x + r, y);
    c.arcTo(x + w, y, x + w, y + h, r);
    c.arcTo(x + w, y + h, x, y + h, r);
    c.arcTo(x, y + h, x, y, r);
    c.arcTo(x, y, x + w, y, r);
    c.closePath();
  }
  function fill(color, alpha) { c.fillStyle = css(color, alpha); c.fill(); }
  function stroke(color, width, alpha, round, roundJoin) {   // SwiftUI default: butt caps, miter joins
    c.strokeStyle = css(color, alpha); c.lineWidth = width;
    c.lineCap = round ? 'round' : 'butt'; c.lineJoin = roundJoin ? 'round' : 'miter';
    c.stroke();
  }
  function fillRect(x, y, w, h, color, alpha) { c.fillStyle = css(color, alpha); c.fillRect(x, y, w, h); }

  function shadow() {
    ellipsePath(28, 131, 44, 7); fill(BLACK, 0.3);
  }
  function shoe(foot, color) {
    rrPath(foot.x - 6, foot.y - 2, 12, 6, 3); fill(color || WHITE);
  }
  // An hourglass torso for the female body: shoulders, a narrower waist, wider hips.
  function hourglassPath(y0, y1, sw, ww, hw) {
    var mid = (y0 + y1) / 2 + 4;
    c.beginPath();
    c.moveTo(50 - sw, y0);
    c.lineTo(50 + sw, y0);
    c.quadraticCurveTo(50 + ww, mid, 50 + hw, y1);
    c.lineTo(50 - hw, y1);
    c.quadraticCurveTo(50 - ww, mid, 50 - sw, y0);
    c.closePath();
  }
  function mouth(y, smile, color, width) {
    c.beginPath(); c.moveTo(46, y);
    c.quadraticCurveTo(50, smile ? y + 4 : y - 3.5, 54, y);
    stroke(color, width, 1, true);
  }

  // Your head, drawn from your look: hair or headwear, beard, glasses.
  function head(look, tilt, drop, smile) {
    c.save();
    c.translate(50, 50 + drop);
    c.rotate(tilt * Math.PI / 180);
    c.translate(-50, -50);
    var skin = SKIN[look.skin], hairColor = HAIR_COLOR[look.hairColor];
    var hat = SWATCH[look.hat];
    var fold = look.hatTrim ? SWATCH[look.hatTrim] : swatchLight(look.hat);
    var accent = SWATCH[look.accent];
    var h = look.hair, i, x, y;

    // Behind the head: long hair falls to the shoulders, a bun sits on top.
    if (h === 'long' || h === 'longCurly') { rrPath(34, 19, 32, 40, 13); fill(hairColor); }
    if (h === 'longCurly') {
      for (i = 0; i < 6; i++) {              // stride 26...58 by 6.4
        y = 26 + i * 6.4;
        dot(P(33.5, y), 4.6, hairColor); dot(P(66.5, y), 4.6, hairColor);
      }
    }
    if (h === 'bun') dot(P(50, 16), 5.5, hairColor);
    if (h === 'ponytail') {
      c.beginPath(); c.moveTo(58, 21); c.quadraticCurveTo(72, 24, 69, 44);
      stroke(hairColor, 6.5, 1, true);
    }
    if (h === 'hijab') {                     // scarf around the head, draping over the shoulders
      c.beginPath();
      c.moveTo(36, 30);
      c.quadraticCurveTo(35, 13, 50, 13);
      c.quadraticCurveTo(65, 13, 64, 30);
      c.lineTo(66, 48);
      c.quadraticCurveTo(66, 57, 70, 62);
      c.lineTo(30, 62);
      c.quadraticCurveTo(34, 57, 34, 48);
      c.closePath();
      fill(hat);
    } else {
      fillRect(46, 44, 8, 9, skin);          // neck
    }
    ellipsePath(37, 22, 26, 28); fill(skin); // face

    if (look.beard === 'full' || look.beard === 'stubble') {
      c.beginPath();
      c.moveTo(37.5, 36);
      c.quadraticCurveTo(38, 56, 50, 58);
      c.quadraticCurveTo(62, 56, 62.5, 36);
      c.quadraticCurveTo(50, 44, 37.5, 36);
      fill(hairColor, look.beard === 'full' ? 1 : 0.3);
    }
    mouth(46, smile, LIPS[look.lips], look.lips === 'natural' ? 1.8 : 2.3);
    if (look.beard === 'mustache') {
      c.beginPath(); c.moveTo(44.5, 44); c.quadraticCurveTo(50, 40.5, 55.5, 44);
      stroke(hairColor, 2.6, 1, true);
    }

    // Eyes (always dark), eyebrows in your hair color (hidden under a cap's brim).
    if (look.glasses !== 'sunglasses') {
      dot(P(45, 34), 1.7, EYES); dot(P(55, 34), 1.7, EYES);
      if (look.lashes) {
        line(P(43.4, 33.2), P(41.6, 31.8), EYES, 1.1);
        line(P(56.6, 33.2), P(58.4, 31.8), EYES, 1.1);
      }
      if (h !== 'cap') {
        line(P(42.5, 30.5), P(47.5, 30), hairColor, 1.4);
        line(P(52.5, 30), P(57.5, 30.5), hairColor, 1.4);
      }
    }
    if (look.glasses === 'glasses') {
      [45, 55].forEach(function (gx) {
        ellipsePath(gx - 4.2, 29.8, 8.4, 8.4); stroke(BLACK, 1.2, 0.85);
      });
      line(P(49.2, 33.5), P(50.8, 33.5), BLACK, 1.2, 0.85);
    } else if (look.glasses === 'sunglasses') {
      rrPath(40, 31, 9, 6, 2.5); fill(BLACK);
      rrPath(51, 31, 9, 6, 2.5); fill(BLACK);
      line(P(49, 33), P(51, 33), BLACK, 1.5);
      line(P(42, 32.5), P(44.5, 32.5), WHITE, 1, 0.7);
    }

    // On top: hair or headwear.
    if (h === 'turban') {
      c.beginPath();
      c.moveTo(36, 31);
      c.quadraticCurveTo(34, 14, 50, 12);
      c.quadraticCurveTo(66, 14, 64, 31);
      c.quadraticCurveTo(50, 25, 36, 31);
      fill(hat);
      c.beginPath();
      c.moveTo(39, 26); c.quadraticCurveTo(46, 18, 58, 16);
      c.moveTo(61, 27); c.quadraticCurveTo(55, 18, 43, 16);
      stroke(fold, 1.5);
    } else if (h === 'hijab') {              // band framing the forehead
      c.beginPath();
      c.moveTo(36.5, 33);
      c.quadraticCurveTo(35.5, 18, 50, 18);
      c.quadraticCurveTo(64.5, 18, 63.5, 33);
      c.lineTo(61.5, 27.5);
      c.quadraticCurveTo(50, 22.5, 38.5, 27.5);
      c.closePath();
      fill(hat);
      c.beginPath(); c.moveTo(38.5, 27.5); c.quadraticCurveTo(50, 22.5, 61.5, 27.5);
      stroke(fold, 1.2);
    } else if (h === 'bald') {
      ellipsePath(42, 23.5, 6, 3); fill(WHITE, 0.3);
    } else if (h === 'cap') {
      c.beginPath();
      c.moveTo(36.5, 29);
      c.quadraticCurveTo(36, 17, 50, 17);
      c.quadraticCurveTo(64, 17, 63.5, 29);
      c.closePath();
      fill(hat);
      rrPath(34, 26.5, 32, 4.5, 2.25); fill(hat);
      rrPath(34, 26.5, 32, 4.5, 2.25); fill(BLACK, 0.2);
      dot(P(50, 17.5), 1.5, fold);
    } else {                                 // short, long, longCurly, bun, curly, ponytail, braids
      c.beginPath();                         // hair over the top of the head, hairline at the forehead
      c.moveTo(37, 34);
      c.quadraticCurveTo(36, 19, 50, 19);
      c.quadraticCurveTo(64, 19, 63, 34);
      c.lineTo(61.5, 28);
      c.quadraticCurveTo(50, 23, 38.5, 28);
      c.closePath();
      fill(hairColor);
      if (h === 'long') {                    // strands down the sides of the face
        line(P(37.5, 29), P(36.5, 54), hairColor, 3.5);
        line(P(62.5, 29), P(63.5, 54), hairColor, 3.5);
      }
      if (h === 'ponytail') dot(P(59, 21.5), 2, accent);   // hair tie
      if (h === 'braids') {                  // two braids down over the shoulders
        [37, 63].forEach(function (bx) {
          var dir = bx < 50 ? -1 : 1;
          for (var k = 0; k < 7; k++) dot(P(bx + dir * k * 0.3, 32 + k * 4.6), 3.1, hairColor);
          dot(P(bx + dir * 2, 62), 1.8, accent);
        });
      }
      if (h === 'longCurly') {               // curls framing the face (stride 31...53 by 5.5)
        for (i = 0; i < 5; i++) {
          y = 31 + i * 5.5;
          dot(P(37, y), 3.2, hairColor); dot(P(63, y), 3.2, hairColor);
        }
      }
      if (h === 'curly' || h === 'longCurly') {   // a ring of curls around the top (-15...195 by 26.25)
        for (i = 0; i < 9; i++) {
          var a = (-15 + i * 26.25) * Math.PI / 180;
          dot(P(50 + Math.cos(a) * 13, 30 - Math.sin(a) * 12), 4.6, hairColor);
        }
      }
    }
    c.restore();
  }

  // ---------- Session props (hiking stick, dog, shopping bags, balloon, dumbbells) ----------

  function propBehind(prop) {
    if (prop !== 'hikingStick') return;
    rrPath(29, 51, 42, 32, 8); fill(PACK);
  }
  // Called while the context is shifted down by `bob`; the dog walks on the unshifted ground.
  function propFront(prop, handL, handR, bob, t, look) {
    if (!prop) return;
    var skin = SKIN[look.skin];
    if (prop === 'hikingStick') {
      line(P(handR.x + 1, handR.y - 8), P(handR.x + 5, 134 - bob), WOOD, 2.2);
      dot(handR, 3.6, skin);
    } else if (prop === 'dog') {
      c.save(); c.translate(0, -bob);
      var trot = Math.sin(t * 10);
      var dogColor = [0.72, 0.50, 0.30], dark = [0.40, 0.25, 0.15];
      [[75, 1], [79, -1], [85, -1], [89, 1]].forEach(function (l) {
        line(P(l[0], 125), P(l[0] + 2.5 * trot * l[1], 134), dogColor, 2.6);
      });
      line(P(73, 121), P(68 + 2 * Math.sin(t * 14), 113), dogColor, 2.4);
      rrPath(71, 118, 21, 9, 4.5); fill(dogColor);
      dot(P(93, 115), 5, dogColor);
      ellipsePath(88.5, 111, 4, 8); fill(dark);
      dot(P(98, 116), 1.4, BLACK);
      dot(P(94.5, 113.5), 0.9, BLACK);
      line(P(90, 118), P(90, 121), SWATCH[look.accent], 2);
      var hand = P(handR.x, handR.y + bob);
      c.beginPath(); c.moveTo(hand.x, hand.y);
      c.quadraticCurveTo((hand.x + 90) / 2, Math.max(hand.y, 119) + 6, 90, 119);
      stroke(BLACK, 1, 0.7);
      c.restore();
    } else if (prop === 'bags') {
      [[handL, SWATCH[look.main]], [handR, SWATCH[look.accent]]].forEach(function (b) {
        var hd = b[0];
        c.beginPath(); c.moveTo(hd.x - 3, hd.y + 4);
        c.quadraticCurveTo(hd.x, hd.y - 3, hd.x + 3, hd.y + 4);
        stroke(BLACK, 1, 0.6);
        rrPath(hd.x - 5.5, hd.y + 3, 11, 13, 1.5); fill(b[1]);
        fillRect(hd.x - 5.5, hd.y + 3, 11, 2.5, BLACK, 0.15);
        dot(hd, 3.4, skin);
      });
    } else if (prop === 'balloon') {
      var top = P(84 + 2 * Math.sin(t * 1.3), 22 + 2 * Math.sin(t * 2));
      c.beginPath(); c.moveTo(handR.x, handR.y);
      c.quadraticCurveTo(handR.x + 14, (handR.y + top.y) / 2, top.x, top.y + 9);
      stroke(BLACK, 0.8, 0.5);
      ellipsePath(top.x - 7, top.y - 8, 14, 17); fill(SWATCH.red);
      ellipsePath(top.x - 4, top.y - 5, 3, 5); fill(WHITE, 0.5);
      dot(P(top.x, top.y + 9), 1.3, SWATCH.red);
    } else if (prop === 'dumbbells') {
      [handL, handR].forEach(function (hd) {
        line(P(hd.x - 6, hd.y), P(hd.x + 6, hd.y), gray(0.6), 2.2);
        [-6, 6].forEach(function (dx) { rrPath(hd.x + dx - 2, hd.y - 4.5, 4, 9, 1); fill(gray(0.25)); });
        dot(hd, 3.6, skin);
      });
    }
  }

  // ---------- Golfer (shown as "Casual"): polo in your main color with an accent collar ----------

  function golferArm(shoulder, hand, look, elbow) {
    elbow = elbow || P((shoulder.x + hand.x) / 2, (shoulder.y + hand.y) / 2);
    line(elbow, hand, SKIN[look.skin], 6);
    line(shoulder, elbow, SWATCH[look.main], 9);   // polo sleeve
    dot(hand, 3.5, SKIN[look.skin]);
  }

  function drawGolfer(mood, t, look, prop) {
    shadow();
    var bob = 0, spread = 5, liftL = 0, liftR = 0, armL = -8, armR = 8;
    var headTilt = 0, headDrop = 0, smile = true, club = null;

    if (mood === 'stand') {
      bob = -1.2 * (Math.sin(t * 2) + 1) / 2;
      armL = -8 - 2 * Math.sin(t * 2);
      armR = 8 + 2 * Math.sin(t * 2);
    } else if (mood === 'walk') {
      var w = Math.sin(t * 6);
      bob = -Math.abs(w) * 2;
      liftL = Math.max(0, w) * 7;
      liftR = Math.max(0, -w) * 7;
      armL = -10 - 12 * w;
      armR = 10 - 12 * w;
    } else if (mood === 'slump') {
      bob = 2;
      headTilt = 10 + 3 * Math.sin(t * 1.5);
      headDrop = 3;
      armL = -3; armR = 3;
      smile = false;
    } else if (mood === 'celebrate') {
      var j = Math.abs(Math.sin(t * 5));
      bob = -8 * j;
      spread = 10;
      liftL = 3 * j; liftR = 3 * j;
      armL = -30;
      armR = 168 + 12 * Math.sin(t * 10);   // fist pump
    } else if (mood === 'swing') {
      spread = 10;
      var p = (t % 2.6) / 2.6;
      if (p < 0.4) club = -125 * (p / 0.4);                         // backswing
      else if (p < 0.55) club = -125 + 265 * ((p - 0.4) / 0.15);    // downswing
      else if (p < 0.85) club = 140;                                // hold the finish
      else club = 140 * (1 - (p - 0.85) / 0.15);                    // reset
    }

    c.save();
    c.translate(0, bob);

    var skort = look.bottoms === 'skort';
    [[45, -spread, liftL], [55, spread, liftR]].forEach(function (l) {
      var hip = P(l[0], 90), foot = reach(hip, l[1], 38 - l[2]);
      line(hip, foot, skort ? SKIN[look.skin] : PANTS, skort ? 7 : 9);
      shoe(foot);
    });
    if (skort) {
      c.beginPath(); c.moveTo(36, 88); c.lineTo(64, 88); c.lineTo(67, 104); c.lineTo(33, 104); c.closePath();
      fill(PANTS);
    }

    propBehind(prop);
    var curvy = look.body === 'female';
    // Polo with the accent collar and a belt.
    if (curvy) hourglassPath(52, 92, 12, 5, 15); else rrPath(35, 52, 30, 40, 9);
    fill(SWATCH[look.main]);
    c.beginPath(); c.moveTo(43, 52); c.lineTo(50, 61); c.lineTo(57, 52);
    stroke(SWATCH[look.accent], 2.5, 1, true, true);
    fillRect(35, 86, 30, 4, BLACK, 0.6);

    var sL = P(curvy ? 40 : 38, 57), sR = P(curvy ? 60 : 62, 57);
    if (club !== null) {
      var hands = reach(P(50, 60), club, 26);
      var clubHead = reach(hands, club, 32);
      line(hands, clubHead, gray(0.85), 2);
      ellipsePath(clubHead.x - 3.5, clubHead.y - 2.5, 7, 5); fill(gray(0.7));
      golferArm(sL, hands, look);
      golferArm(sR, hands, look);
    } else {
      var handL = reach(sL, armL, 28), handR = reach(sR, armR, 28);
      golferArm(sL, handL, look);
      golferArm(sR, handR, look);
      propFront(prop, handL, handR, bob, t, look);
    }

    head(look, headTilt, headDrop, smile);
    c.restore();
  }

  // ---------- Baller: jersey with your letter, dribbles, dunks, spins the ball ----------

  function ball(p, spin) {
    dot(p, 7, BALL);
    c.save();
    c.translate(p.x, p.y);
    c.rotate(spin);
    c.beginPath();
    c.moveTo(-7, 0); c.lineTo(7, 0);
    c.moveTo(0, -7); c.lineTo(0, 7);
    stroke(BLACK, 1, 0.55);
    ellipsePath(-7, -7, 14, 14); stroke(BLACK, 1, 0.55);
    c.restore();
  }

  function drawBaller(mood, t, look, prop) {
    var skin = SKIN[look.skin], main = SWATCH[look.main], accent = SWATCH[look.accent];
    shadow();

    var bob = 0, spread = 6, armL = -12, armR = 12;
    var headTilt = 0, headDrop = 0, smile = true;
    var ballAt = P(75, 127), ballInBody = false, spin = 0;

    if (mood === 'walk' && prop) {           // walking with a prop instead of the ball
      var w = Math.sin(t * 6);
      bob = -Math.abs(w) * 2;
      armL = -10 - 12 * w;
      armR = 10 - 12 * w;
      ballAt = P(-100, -100);
    } else if (mood === 'walk') {            // dribbling
      var b = Math.abs(Math.sin(t * 3.5));
      var handY = 80 + 5 * (1 - b);
      armR = 22;
      ballAt = P(72, 127 - b * (127 - (handY + 8)));
      spin = t * 3;
    } else if (mood === 'stand') {           // ball held at the hip
      bob = -1.2 * (Math.sin(t * 2) + 1) / 2;
      armR = 20;
      ballAt = P(72, 92);
      ballInBody = true;
    } else if (mood === 'slump') {           // ball parked, head down
      bob = 2;
      headTilt = 10 + 3 * Math.sin(t * 1.5);
      headDrop = 3;
      armL = -3; armR = 3;
      smile = false;
    } else if (mood === 'celebrate') {       // dunk jump
      bob = -12 * Math.abs(Math.sin(t * 4));
      spread = 12;
      armL = -150; armR = 160;
      ballInBody = true;
      spin = t * 2;
    } else if (mood === 'swing') {           // spinning the ball on a finger
      armL = -20; armR = 165;
      ballInBody = true;
      spin = t * 9;
    }

    c.save();
    c.translate(0, bob);

    // Legs, high-tops, shorts
    [[45, -spread], [55, spread]].forEach(function (l) {
      var hip = P(l[0], 92), foot = reach(hip, l[1], 36);
      line(hip, foot, skin, 8);
      shoe(foot, accent);
    });
    rrPath(35, 84, 30, 22, 5); fill(main);
    line(P(36, 86), P(36, 104), accent, 1.5);
    line(P(64, 86), P(64, 104), accent, 1.5);

    // Jersey in your accent color with your letter (trim in the main color, unless it matches)
    propBehind(prop);
    var curvy = look.body === 'female';
    var trim = look.main === look.accent ? (look.accent === 'white' ? BLACK : WHITE) : main;
    if (curvy) hourglassPath(52, 88, 11, 5, 14); else rrPath(37, 52, 26, 36, 6);
    fill(accent);
    c.beginPath(); c.moveTo(44, 52); c.quadraticCurveTo(50, 59, 56, 52);
    stroke(trim, 2);
    var letter = look.letter, fs = letter.length > 1 ? 10 : 12;
    c.font = '800 ' + fs + 'px -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", "Segoe UI", Arial, sans-serif';
    c.textAlign = 'center';
    c.textBaseline = 'alphabetic';
    c.fillStyle = css(trim);
    // SwiftUI centers the text's line box on (50, 71); for the system font the baseline sits ~0.355 em below that.
    c.fillText(letter, 50, 71 + fs * 0.355);

    // Bare arms
    var sL = P(curvy ? 40 : 39, 57), sR = P(curvy ? 60 : 61, 57);
    var handL = reach(sL, armL, 27), handR = reach(sR, armR, 27);
    line(sL, handL, skin, 7);
    line(sR, handR, skin, 7);
    dot(handL, 3.5, skin);
    dot(handR, 3.5, skin);
    propFront(prop, handL, handR, bob, t, look);

    head(look, headTilt, headDrop, smile);

    // Ball goes on top of everything
    if (ballInBody) {
      ball(P(handR.x, handR.y - 9), spin);
      c.restore();
    } else {
      c.restore();
      ball(ballAt, spin);
    }
  }

  // ---------- Ripped (shown as "Gym"): tank or sports top, jogs, flexes ----------

  function rippedArm(shoulder, look, upper, fore, flex) {
    var elbow = reach(shoulder, upper, 16), hand = reach(elbow, fore, 15);
    var slim = look.body === 'female', skin = SKIN[look.skin];
    line(shoulder, elbow, skin, slim ? 8 : 10);
    line(elbow, hand, skin, slim ? 7 : 8);
    var bicep = P((shoulder.x + elbow.x) / 2, (shoulder.y + elbow.y) / 2);
    dot(bicep, (slim ? 4.5 : 5.5) + flex, skin);
    dot(P(bicep.x - 1, bicep.y - 1.5), 1.8 + flex / 3, lighten(skin));   // shine
    dot(hand, 4.5, skin);   // fist
    return hand;
  }

  function golfBag(hand, look) {
    [-3, 0, 3].forEach(function (dx) {       // club heads sticking out
      line(P(hand.x + dx, hand.y + 2), P(hand.x + dx, hand.y - 5), gray(0.8), 1.2);
      dot(P(hand.x + dx, hand.y - 6), 1.6, gray(0.7));
    });
    rrPath(hand.x - 6, hand.y + 1, 12, 26, 4); fill(SWATCH[look.main]);
    fillRect(hand.x - 6, hand.y + 8, 12, 3, SWATCH[look.accent]);
  }

  // Torso: V-shaped with big shoulders, or an hourglass for the female body
  function rippedTorso(look) {
    var curvy = look.body === 'female', skin = SKIN[look.skin];
    var shoulderX = curvy ? 13 : 17;
    dot(P(50 - shoulderX, 59), curvy ? 5 : 6.5, skin);
    dot(P(50 + shoulderX, 59), curvy ? 5 : 6.5, skin);
    function torsoPath() {
      if (curvy) hourglassPath(55, 90, 13, 5, 14);
      else { c.beginPath(); c.moveTo(32, 55); c.lineTo(68, 55); c.lineTo(61, 90); c.lineTo(39, 90); c.closePath(); }
    }
    torsoPath(); fill(skin);
    c.save();
    torsoPath(); c.clip();
    if (look.top === 'sportsTop') {          // crop top in your accent color, midriff showing
      c.beginPath();
      c.moveTo(28, 73); c.lineTo(28, 61); c.lineTo(40, 55);
      c.quadraticCurveTo(50, 64, 60, 55);
      c.lineTo(72, 61); c.lineTo(72, 73); c.closePath();
      fill(SWATCH[look.accent]);
    } else if (curvy) {
      c.beginPath();
      c.moveTo(28, 95); c.lineTo(28, 63); c.lineTo(41, 55);
      c.quadraticCurveTo(50, 66, 59, 55);
      c.lineTo(72, 63); c.lineTo(72, 95); c.closePath();
      fill(WHITE);
    }
    c.restore();
    if (look.top === 'tank' && !curvy) {
      c.beginPath();
      c.moveTo(40, 55);
      c.quadraticCurveTo(50, 66, 60, 55);
      c.lineTo(64, 70); c.lineTo(61, 90); c.lineTo(39, 90); c.lineTo(36, 70); c.closePath();
      fill(WHITE);
      c.beginPath();
      c.moveTo(41, 70); c.quadraticCurveTo(45.5, 74, 50, 70);
      c.moveTo(50, 70); c.quadraticCurveTo(54.5, 74, 59, 70);
      stroke(BLACK, 1.2, 0.15);
    }
  }

  function drawRipped(mood, t, look, prop) {
    var shorts = SWATCH[look.main], skin = SKIN[look.skin];
    shadow();

    var bob = 0, liftL = 0, liftR = 0;
    var upL = -12, foreL = -8, upR = 12, foreR = 8, flex = 0;
    var headTilt = 0, headDrop = 0, smile = true, seated = false, curling = false, w;

    if (mood === 'walk' && prop) {           // brisk walk, arms low so the prop hangs
      w = Math.sin(t * 6);
      bob = -Math.abs(w) * 2;
      liftL = Math.max(0, w) * 7;
      liftR = Math.max(0, -w) * 7;
      upL = -12 - 14 * w; foreL = upL + 6;
      upR = 12 - 14 * w; foreR = upR - 6;
    } else if (mood === 'walk') {            // jogging
      w = Math.sin(t * 8);
      bob = -Math.abs(w) * 4;
      liftL = Math.max(0, w) * 10;
      liftR = Math.max(0, -w) * 10;
      upL = -15 + 20 * w; foreL = 140 + 20 * w;
      upR = 15 + 20 * w; foreR = -140 + 20 * w;
    } else if (mood === 'stand') {           // standing tall, breathing
      bob = -1.2 * (Math.sin(t * 2) + 1) / 2;
    } else if (mood === 'slump') {           // sitting on a bench
      seated = true;
      bob = 14;
      upL = -25; foreL = 10;
      upR = 25; foreR = -10;
      headTilt = 14 + 3 * Math.sin(t * 1.5);
      headDrop = 4;
      smile = false;
    } else if (mood === 'celebrate') {       // double-bicep flex
      var pump = (Math.sin(t * 6) + 1) / 2;
      bob = -1.5 * pump;
      upL = -95; foreL = -178;
      upR = 95; foreR = 178;
      flex = 1 + 2 * pump;
    } else if (mood === 'swing') {           // curling the golf bag
      curling = true;
      upR = 10;
      foreR = 10 + 150 * (Math.sin(t * 3) + 1) / 2;
      flex = 2 * (Math.sin(t * 3) + 1) / 2;
    }

    if (seated) {                            // bench
      rrPath(20, 105, 60, 6, 2); fill([0.45, 0.30, 0.20]);
      line(P(26, 111), P(26, 134), gray(0.5), 3);
      line(P(74, 111), P(74, 134), gray(0.5), 3);
    }

    c.save();
    c.translate(0, bob);

    if (seated) {
      [[44, 39], [56, 61]].forEach(function (l) {
        var knee = P(l[1], 110 - bob), foot = P(l[1], 133 - bob);
        line(P(l[0], 92), knee, shorts, 11);
        line(knee, foot, skin, 8);
        shoe(foot);
      });
    } else {
      [[44, -6, liftL], [56, 6, liftR]].forEach(function (l) {
        var hip = P(l[0], 90), foot = reach(hip, l[1], 38 - l[2]);
        line(hip, foot, skin, 9);
        shoe(foot);
      });
      rrPath(35, 84, 30, 17, 4); fill(shorts);
    }

    propBehind(prop);
    rippedTorso(look);
    var shoulderX = look.body === 'female' ? 13 : 17;

    var sL = P(50 - shoulderX, 59), sR = P(50 + shoulderX, 59);
    var handL = rippedArm(sL, look, upL, foreL, curling ? 0 : flex);
    if (curling) {
      var elbow = reach(sR, upR, 16);
      golfBag(reach(elbow, foreR, 15), look);
    }
    var handR = rippedArm(sR, look, upR, foreR, flex);
    propFront(prop, handL, handR, bob, t, look);

    head(look, headTilt, headDrop, smile);
    c.restore();
  }

  // ---------- Public API ----------

  var MOODS = { walk: 1, stand: 1, celebrate: 1, slump: 1, swing: 1 };
  var PROPS = { hikingStick: 1, dog: 1, bags: 1, balloon: 1, dumbbells: 1 };

  // opts: { avatar, mood, t, look, x, y, size, prop }
  //   size = height of the character's box in canvas units; the box is size * 100/140 wide
  //   (the app's 100 x 140 grid). Or pass width + height and the grid is fitted and centered
  //   in that box, exactly like the SwiftUI Canvas does.
  //   look = null/undefined -> the classic look for that avatar (what the watch draws).
  function draw(ctx, opts) {
    opts = opts || {};
    var avatar = (opts.avatar === 'baller' || opts.avatar === 'ripped') ? opts.avatar : 'golfer';
    var mood = MOODS[opts.mood] ? opts.mood : 'walk';
    var t = +opts.t || 0;
    var look = normalize(opts.look == null ? classicLook(avatar) : opts.look);
    var prop = (mood === 'walk' && PROPS[opts.prop]) ? opts.prop : null;   // props only while walking
    var x = +opts.x || 0, y = +opts.y || 0, w, h;
    if (opts.width && opts.height) { w = opts.width; h = opts.height; }
    else { h = opts.size || 140; w = h * 100 / 140; }
    var s = Math.min(w / 100, h / 140);

    var prev = c;
    c = ctx;
    c.save();
    c.translate(x + (w - 100 * s) / 2, y + (h - 140 * s) / 2);
    c.scale(s, s);
    try {
      if (avatar === 'golfer') drawGolfer(mood, t, look, prop);
      else if (avatar === 'baller') drawBaller(mood, t, look, prop);
      else drawRipped(mood, t, look, prop);
    } finally {
      c.restore();
      c = prev;
    }
  }

  // Just the head (the builder's option chips): the head lives in x 28...72, y 8...62 of the grid.
  function drawHead(ctx, opts) {
    opts = opts || {};
    var look = normalize(opts.look);
    var x = +opts.x || 0, y = +opts.y || 0, w, h;
    if (opts.width && opts.height) { w = opts.width; h = opts.height; }
    else { h = opts.size || 54; w = h * 44 / 54; }
    var s = Math.min(w / 44, h / 54);
    var prev = c;
    c = ctx;
    c.save();
    c.translate(x + (w - 44 * s) / 2, y + (h - 54 * s) / 2);
    c.scale(s, s);
    c.translate(-28, -8);
    try { head(look, 0, 0, true); } finally { c.restore(); c = prev; }
  }

  function list(table, names) {
    return Object.keys(table).map(function (id) {
      var label = names && names[id] ? names[id] : id.charAt(0).toUpperCase() + id.slice(1);
      return { id: id, label: label, color: hex(table[id]) };
    });
  }
  function names(map) { return Object.keys(map).map(function (id) { return { id: id, label: map[id] }; }); }

  var swatches = list(SWATCH).map(function (s) {
    s.partner = partner(s.id);               // the trim the builder sets when you pick this outfit color
    s.light = hex(swatchLight(s.id));        // turban fold color when hatTrim is null
    return s;
  });

  var options = {
    avatar: [{ id: 'golfer', label: 'Casual' }, { id: 'baller', label: 'Baller' }, { id: 'ripped', label: 'Gym' }],
    // Labels are the builder's pose picker; "stand" and "swing" are not in the picker.
    mood: [{ id: 'walk', label: 'Walking' }, { id: 'celebrate', label: 'Goal hit' }, { id: 'slump', label: 'Behind' },
           { id: 'stand', label: 'Standing' }, { id: 'swing', label: 'Swing' }],
    // `raw` is what the app saves; draw() accepts either.
    body: [{ id: 'male', raw: 'straight', label: 'Male' }, { id: 'female', raw: 'curvy', label: 'Female' }],
    skin: list(SKIN),
    hair: names(HAIR_NAMES).map(function (o) {
      o.wearsHat = o.id === 'turban' || o.id === 'cap' || o.id === 'hijab';   // shows the "<Hair> color" row
      return o;
    }),
    hairFor: { male: HAIR_FOR.male.slice(), female: HAIR_FOR.female.slice() },
    hairColor: list(HAIR_COLOR, { darkBrown: 'Dark brown' }),
    beard: names(BEARD_NAMES),
    glasses: names(GLASSES_NAMES),
    lashes: [{ id: false, label: 'Off' }, { id: true, label: 'On' }],          // "Eyelashes" toggle
    lips: list(LIPS),
    bottoms: [{ id: 'pants', label: 'Pants' }, { id: 'skort', label: 'Skort' }],          // Casual only
    top: [{ id: 'tank', label: 'Tank top' }, { id: 'sportsTop', label: 'Sports top' }],   // Gym only
    swatch: swatches,
    hat: swatches, hatTrim: swatches, main: swatches, accent: swatches,
    prop: [{ id: 'hikingStick', label: 'Hike' }, { id: 'dog', label: 'Dog walk' }, { id: 'bags', label: 'Shopping' },
           { id: 'balloon', label: 'Theme park' }, { id: 'dumbbells', label: 'Workout' }],
    // Section titles as shown in the app's "Build your mini-me" screen.
    titles: { body: 'Male or female', avatar: 'Outfit', bottoms: 'Bottoms', top: 'Top', main: 'Outfit color',
              letter: 'Jersey letter', skin: 'Skin tone', hair: 'Hair', hairColor: 'Hair & beard color',
              lashes: 'Eyelashes', lips: 'Lip color', beard: 'Beard', glasses: 'Glasses' },
    letterMaxLength: 2                        // uppercased, at most 2 characters
  };

  // Sizes the canvas for devicePixelRatio and animates. getState() -> { avatar, mood, look } (+ optional prop, t).
  // Returns a stop function. With prefers-reduced-motion it draws a still frame and only redraws on changes.
  function mount(canvas, getState) {
    var ctx = canvas.getContext('2d');
    var mq = root.matchMedia ? root.matchMedia('(prefers-reduced-motion: reduce)') : null;
    var raf = 0, stopped = false, lastKey = null, cssW = 0, cssH = 0;
    var now = function () { return (root.performance && performance.now ? performance.now() : Date.now()) / 1000; };
    var STILL_T = 0.2;                        // a mid-stride frame for the still picture

    function fit() {
      var dpr = root.devicePixelRatio || 1;
      var w = canvas.clientWidth || canvas.width, h = canvas.clientHeight || canvas.height;
      var pw = Math.max(1, Math.round(w * dpr)), ph = Math.max(1, Math.round(h * dpr));
      var changed = canvas.width !== pw || canvas.height !== ph;
      if (changed) { canvas.width = pw; canvas.height = ph; }
      cssW = w; cssH = h;
      return changed;
    }
    function frame() {
      if (stopped) return;
      raf = root.requestAnimationFrame(frame);
      var st = (typeof getState === 'function' ? getState() : getState) || {};
      var resized = fit();
      var still = !!(mq && mq.matches);
      if (still) {
        var key = JSON.stringify([st.avatar, st.mood, st.look, st.prop, st.t]);
        if (key === lastKey && !resized) return;
        lastKey = key;
      } else {
        lastKey = null;
      }
      var dpr = canvas.width / (cssW || 1);
      ctx.setTransform(dpr, 0, 0, canvas.height / (cssH || 1), 0, 0);
      ctx.clearRect(0, 0, cssW, cssH);
      draw(ctx, { avatar: st.avatar, mood: st.mood, look: st.look, prop: st.prop,
                  t: st.t != null ? st.t : (still ? STILL_T : now()),
                  x: 0, y: 0, width: cssW, height: cssH });
    }
    raf = root.requestAnimationFrame(frame);
    return function stop() { stopped = true; root.cancelAnimationFrame(raf); };
  }

  root.MiniMe = {
    draw: draw,
    drawHead: drawHead,
    options: options,
    defaultLook: defaultLook,
    originalLook: originalLook,
    classicLook: classicLook,
    switchBody: switchBody,
    partner: partner,
    mount: mount,
    GRID: { width: 100, height: 140 }
  };
})(typeof window !== 'undefined' ? window : this);
