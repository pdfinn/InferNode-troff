#!/bin/sh
#
# slides_test.sh — -mslides, a talk's slides on -mbook's macros:
#
#	book -m slides on examples/slides.ms: a page a slide and a page
#	for each step of a slide with .pause, 10 by 5.625 inches; the
#	title slide, its title a heading (H1); a slide's steps each on a
#	page, each page the one before with more, what was shown before
#	where it was; the pages' labels the slides' numbers (3 3 3 3);
#	the structure each slide's once, in a Sect of its own, its title a
#	heading (H3, under a section's H2), the pages before a slide's last
#	artifacts, with no link on them and its links on its last; the
#	bookmarks the sections, the slides under them, each to the slide's
#	first page; columns side by side, a display centred in its column;
#	the program's text on its tint; numbered citations, without -S
#	(book's default for slides), the references a slide; claiming
#	PDF/UA-1;
#	a slide too tall said, with by how much, its text running off its
#	page and not onto another; one that fits not said; .pause within
#	.columns said; .aspect 4:3; an untitled slide; \*[ref] a slide's
#	number, a link to it; a link on a slide with .pause made on its
#	last page alone;
#	images: one first on a slide below its title, one first in a column
#	beside a list (each was set upward, over the title, where a slide's
#	or column's top has no space to make room in), one in a figure with
#	its caption, one given no size its own fitted to the room below the
#	title (its width the line's, its height the room's), one shown on a
#	slide's second step only; each a Figure once, with its description;
#	an apostrophe in a title, a subtitle, a caption: set, not broken;
#	-mbook: a chapter titled with an apostrophe keeps its running head
#	(the head's width was measured with ' as \w's delimiter);
#	troff: a line reread from a diversion into another keeps its own
#	spacing (it took the environment's: a program's text, set at 16 on
#	21 points, came out at 25 in a slide).

. "$(dirname "$0")/common.sh"
cd "$ROOT"

[ -x "$EMU" ] || { echo "slides_test: SKIP (no emu)"; exit 77; }
[ -f "$ROOT/dis/troff.dis" ] && [ -f "$ROOT/dis/tr2pdf.dis" ] && [ -f "$ROOT/dis/refer/numeric.dis" ] ||
    { echo "slides_test: SKIP (dis not built)"; exit 77; }
command -v python3 >/dev/null 2>&1 && command -v pdftotext >/dev/null 2>&1 ||
    { echo "slides_test: SKIP (no python3 or poppler)"; exit 77; }
python3 -c 'import pypdf' 2>/dev/null || { echo "slides_test: SKIP (no pypdf)"; exit 77; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/slides.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

ex="$(cd "$(dirname "$0")/../.." && pwd)/examples"
[ -f "$ex/slides.ms" ] || ex="$ROOT/examples"
cp "$ex/slides.ms" "$ex/works.bib" "$tmp/"

python3 -I - "$tmp" <<'PY'
import sys
d = sys.argv[1]
s = ['.slide "Too much"']
for i in range(1, 13):
    s += ['.item', 'item %d' % i]
s += ['.slide "Fits"']
for i in range(1, 10):
    s += ['.item', 'fits %d' % i]
open(d + '/over.ms', 'w').write('\n'.join(s) + '\n')
open(d + '/odd.ms', 'w').write('''.aspect 4:3
.slide
An untitled slide.
.slide "Two columns" cols
.columns
.column
left
.pause
.column
right
.endcolumns
.slide "Back"
See slide \\*[ref cols].
.slide "Linked"
.url https://example.org
.pause
And more.
''')
# images in plain colours, found again on the page by their colour
import struct, zlib
def chunk(t, b):
    return struct.pack('>I', len(b)) + t + b + struct.pack('>I', zlib.crc32(t + b) & 0xffffffff)
def png(name, w, h, rgb):
    row = b'\x00' + bytes(rgb) * w
    p = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
    open(d + '/' + name, 'wb').write(p + chunk(b'IDAT', zlib.compress(row * h)) + chunk(b'IEND', b''))
png('red.png', 400, 200, (255, 0, 0))
png('green.png', 200, 200, (0, 255, 0))
png('blue.png', 300, 150, (0, 0, 255))
png('huge.png', 2000, 1500, (255, 0, 255))
open(d + '/img.ms', 'w').write('''.title "Images' Places"
.subtitle "Kernighan's, O'Reilly's"
.slide "First on a slide"
.alt "A red rectangle."
.image red.png 4i
.slide "First in a column"
.columns
.column 4.5i
.item
A list
.column 3.5i
.alt "A green square."
.image green.png 2i
.endcolumns
.slide "Gauss's figure"
.figure f
.alt "A blue rectangle."
.image blue.png 3i
.caption "Gauss's blue rectangle."
.endfigure
.slide "No size given"
.alt "A magenta rectangle."
.image huge.png
.slide "Built"
.item
A point
.pause
.alt "A red rectangle."
.image red.png 2i
''')
words = ' '.join(['words'] * 12) + '.'
open(d + '/chap.ms', 'w').write('.chapter "Gauss\'s Law of Error"\n' + '\n'.join([words] * 120) + '\n')
open(d + '/vs.tr', 'w').write('''.vs 25p
.ev c
.vs 10p
.nf
.di A
one
two
three
.br
.di
.ev
.di B
.nf
.A
.br
.di
.B
''')
PY

SDL_VIDEODRIVER=dummy with_timeout 300 "$EMU" -c1 -pheap=1024m -pmain=1024m -r"$ROOT" /dis/sh.dis -c \
    "cd '#U*$tmp'; book -m slides -p works.bib slides.ms >[2] slides.err;
     book -m slides over.ms >[2] over.err; book -m slides odd.ms >[2] odd.err;
     book -m slides img.ms >[2] img.err; book chap.ms >[2] chap.err;
     troff vs.tr > vs.out >[2] vs.err" </dev/null >"$tmp/emu.log" 2>&1

fail=0
python3 -I - "$tmp" <<'PY' || fail=1
import re, subprocess, sys
import pypdf
d = sys.argv[1]
fail = 0
def check(ok, what, why=''):
    global fail
    print(('PASS: ' if ok else 'FAIL: ') + what + ('' if ok else ': ' + str(why)[:500]))
    fail |= not ok
def read(f):
    try:
        return open(d + '/' + f, encoding='utf-8').read()
    except Exception:
        return ''
def words(pdf):
    x = subprocess.run(['pdftotext', '-bbox', d + '/' + pdf, '-'], capture_output=True, text=True).stdout
    pages = []
    for p in re.split(r'<page ', x)[1:]:
        W, H = map(float, re.search(r'width="([\d.]+)" height="([\d.]+)"', p).groups())
        ws = [(float(a), float(b), float(c), float(e), t) for a, b, c, e, t in
              re.findall(r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" yMax="([\d.]+)">([^<]*)</word>', p)]
        pages.append((W, H, ws))
    return pages
def find(ws, t):
    return [w for w in ws if w[4] == t]

# troff: the spacing a line keeps through two diversions
v = [int(x) for x in re.findall(r'^V(\d+)$', read('vs.out'), re.M)]
gaps = [b - a for a, b in zip(v, v[1:]) if 0 < b - a < 5000]
check(gaps[:2] == [1000, 1000], 'troff: a line reread from a diversion into another keeps its spacing', v)

pg = words('slides.pdf')
err = read('slides.err')
check(len(pg) == 15 and all((W, H) == (720, 405) for W, H, _ in pg), 'slides: 15 pages, 10 by 5.625 inches', (len(pg), err[-300:]))
check('slides:' not in err and 'book:' not in err, 'slides: nothing said', err[-300:])
if len(pg) == 15:
    W, H, ws = pg[0]
    t = find(ws, 'Setting')
    check(t and abs((t[0][0] + find(ws, 'Whole')[0][2]) / 2 - W / 2) < 6, 'slides: the title slide, its title centred', t)
    # slide 3's four pages: the first step, then the first two ...
    marks = ['Troff', 'loose', 'helped,', 'Plass']
    steps = []
    for p in range(2, 6):
        ws = pg[p][2]
        steps.append([m for m in marks if find(ws, m)])
    check(steps == [marks[:1], marks[:2], marks[:3], marks], 'slides: each .pause a page, each page the one before with more', steps)
    pos = [[find(pg[p][2], m)[0][:2] for m in marks[:1 + i]] for i, p in enumerate(range(2, 6))]
    check(all(pos[i] == pos[-1][:len(pos[i])] for i in range(4)), 'slides: what was shown before where it was', pos)
    # columns: a display centred in its column, the program's text beside it
    W, H, ws = pg[8]
    code = find(ws, 'over')
    eq = [w for w in ws if w[4].startswith('2') and w[0] > W / 2]
    check(code and eq and code[0][2] < eq[0][0], 'slides: columns side by side', (code, eq))
    W, H, ws = pg[6]
    dd = find(ws, '=')
    check(dd and dd[0][0] > 54 + 4.6 * 72 + 0.4 * 72, 'slides: a display centred in its column, not the page', dd)
    W, H, ws = pg[14]
    refs = [w[4] for w in ws if re.match(r'\[\d\]$', w[4])]
    check(find(ws, 'References') and refs == ['[1]', '[2]', '[3]', '[4]', '[5]'], 'slides: numbered citations, the references a slide', refs)

r = pypdf.PdfReader(d + '/slides.pdf')
labels = list(r.page_labels)
check(labels == ['1', '2', '3', '3', '3', '3', '4', '5', '6', '7', '7', '8', '9', '10', '11'], 'slides: pages labelled with their slides\' numbers', labels)
def walk(e, out, depth=0):
    e = e.get_object()
    if isinstance(e, dict) and '/S' in e:
        out.append((depth, e['/S'], e))
        k = e.get('/K')
        if k is not None:
            for c in (k if isinstance(k, list) else [k]):
                walk(c, out, depth + 1)
    return out
st = r.trailer['/Root']['/StructTreeRoot']
els = walk(st['/K'], [])
kinds = [k for _, k, _ in els]
check(kinds.count('/Sect') == 7 and kinds.count('/H3') == 7 and kinds.count('/H2') == 3 and kinds.count('/H1') == 1,
      'slides: each slide once in the structure, a Sect with its heading', (kinds.count('/Sect'), kinds.count('/H3'), kinds.count('/H2')))
check(kinds.count('/L') == 3 and kinds.count('/Table') == 1 and kinds.count('/Figure') == 1 and kinds.count('/Code') == 2,
      'slides: a slide\'s list, table, figure and code once, not each time a page repeats it', kinds)
ids = {p.indirect_reference.idnum: i for i, p in enumerate(r.pages)}
# the pages an element's content is on (its own /Pg, or its marked
# content's)
def pages(e):
    out = set()
    if '/Pg' in e:
        out.add(ids[e.raw_get('/Pg').idnum])
    k = e.get('/K')
    for c in (k if isinstance(k, list) else [k] if k is not None else []):
        c = c.get_object() if hasattr(c, 'get_object') else c
        if isinstance(c, dict):
            out |= pages(c)
    return out
pgs = sorted(set().union(*[pages(e) for _, k, e in els if k == '/H3']))
check(pgs == [5, 6, 8, 10, 12, 13, 14], 'slides: a slide\'s structure on its last page, its pages before artifacts', pgs)
def ol(o, depth, out):
    for x in o:
        if isinstance(x, list):
            ol(x, depth + 1, out)
        else:
            out.append((depth, x.title, r.get_destination_page_number(x) + 1))
    return out
o = ol(r.outline, 0, [])
check(o[0] == (0, 'Lines', 2) and o[1] == (1, 'A line at a time', 3) and (1, 'Measured against LaTeX', 10) in o and
      (0, 'Slides', 12) in o, 'slides: bookmarks, the slides under their sections, each to its first page', o)

t = subprocess.run(['pdftotext', d + '/slides.pdf', '-'], capture_output=True, text=True).stdout
raw = open(d + '/slides.pdf', 'rb').read()
check(b'pdfuaid' in raw, 'slides: claiming PDF/UA-1')

# too tall: said, by how much; run off its page, not onto another
err = read('over.err')
m = re.findall(r'slides: slide (\d+) \(at \d+ of [^)]*\) is too tall for its page by (\d+) points', err)
check(m == [('1', m[0][1] if m else '')] and m and 40 < int(m[0][1]) < 120 and len(m) == 1, 'slides: a slide too tall said, with by how much; one that fits not', err)
pg = words('over.pdf')
check(len(pg) == 2 and find(pg[0][2], '10') and not find(pg[1][2], 'item'), 'slides: a slide too tall runs off its page, not onto another', [len(pg)])

err = read('odd.err')
check('.pause within .columns is not supported' in err, 'slides: .pause within .columns said', err)
pg = words('odd.pdf')
check(len(pg) == 5 and (pg[0][0], pg[0][1]) == (720, 540), 'slides: .aspect 4:3', [(W, H) for W, H, _ in pg])
if len(pg) == 5:
    un = find(pg[0][2], 'untitled')
    check(un and un[0][1] < 0.75 * 72, 'slides: an untitled slide, its text from the top', un)
    left, right = find(pg[1][2], 'left'), find(pg[1][2], 'right')
    check(left and right and abs(left[0][1] - right[0][1]) < 1, 'slides: columns, after a .pause within them refused', (left, right))
    check(find(pg[2][2], '2.'), 'slides: \\*[ref] the slide\'s number', pg[2][2])
r = pypdf.PdfReader(d + '/odd.pdf')
a = [x.get_object()['/A'] for x in r.pages[2].get('/Annots', [])]
check(any(x.get('/D') == '/lab-cols' for x in a) and r.get_destination_page_number(r.named_destinations['/lab-cols']) == 1,
      'slides: \\*[ref] a link to the slide', a)
links = [i for i, p in enumerate(r.pages) if p.get('/Annots')]
check(links == [2, 4] and find(pg[3][2], 'https://example.org') if len(pg) == 5 else 0,
      'slides: no link on a page before a slide\'s last, its link on its last', links)

# images: where each is, by its colour on the page drawn at 72 to the inch
def colour(pdf, page, rgb):
    x = subprocess.run(['pdftoppm', '-r', '72', '-f', str(page), '-l', str(page), d + '/' + pdf],
                       capture_output=True).stdout
    m = re.match(rb'P6\s+(\d+)\s+(\d+)\s+255\s', x)
    if not m:
        return None
    W, H = int(m.group(1)), int(m.group(2))
    px = x[m.end():]
    xs, ys = [], []
    for y in range(0, H, 2):
        r = px[3 * W * y:3 * W * (y + 1)]
        for xx in range(0, W, 2):
            c = r[3 * xx:3 * xx + 3]
            if all(abs(c[i] - rgb[i]) < 40 for i in range(3)):
                xs.append(xx)
                ys.append(y)
    if not xs:
        return None
    return (min(xs), min(ys), max(xs), max(ys))
err = read('img.err')
pg = words('img.pdf')
check(len(pg) == 7, 'images: seven pages', (len(pg), err[-300:]))
if len(pg) == 7:
    t = find(pg[0][2], 'Places')
    check(t and find(pg[0][2], 'Kernighan’s,') and find(pg[0][2], 'O’Reilly’s'), 'images: a title and subtitle with apostrophes set', pg[0][2][:6])
    tb = max(w[3] for w in pg[1][2] if w[4] in ('First', 'slide'))
    r = colour('img.pdf', 2, (255, 0, 0))
    check(r and r[1] > tb and abs((r[2] - r[0]) - 288) < 4, 'images: one first on a slide, below its title, as wide as given', (r, tb))
    W, H, ws = pg[2]
    tb = max(w[3] for w in ws if w[4] == 'column')
    li = find(ws, 'list')
    g = colour('img.pdf', 3, (0, 255, 0))
    check(g and li and g[1] > tb and g[0] > li[0][2] and abs(g[1] - li[0][1]) < 20,
          'images: one first in a column, beside the list, below the title', (g, li, tb))
    ws = pg[3][2]
    cap = find(ws, 'Gauss’s')
    b = colour('img.pdf', 4, (0, 0, 255))
    check(len(cap) == 2 and b and cap[1][1] > b[3] and not find(ws, 'ce') and not [w for w in ws if '<=' in w[4]],
          'images: one in a figure, its caption below it, an apostrophe in the caption and the title', ([w[4] for w in ws], b))
    m = colour('img.pdf', 5, (255, 0, 255))
    tb = max(w[3] for w in pg[4][2] if w[4] in ('No', 'size', 'given'))
    check(m and m[1] > tb and m[3] <= H - 0.45 * 72 and abs((m[2] - m[0]) / (m[3] - m[1]) - 4 / 3) < 0.05 and 'too tall' not in err,
          'images: one given no size fitted to the room below the title, its proportions kept', (m, H, err))
    check(colour('img.pdf', 6, (255, 0, 0)) is None and colour('img.pdf', 7, (255, 0, 0)) is not None,
          'images: one after a .pause on the slide\'s second page only')
r = pypdf.PdfReader(d + '/img.pdf')
els = walk(r.trailer['/Root']['/StructTreeRoot']['/K'], [])
alts = [str(e.get('/Alt')) for _, k, e in els if k == '/Figure']
check(alts == ['A red rectangle.', 'A green square.', 'A blue rectangle.', 'A magenta rectangle.', 'A red rectangle.'],
      'images: each a Figure once, with its description', alts)

# -mbook: the running head of a chapter titled with an apostrophe
heads = []
for p in (3, 5):
    x = subprocess.run(['pdftotext', '-f', str(p), '-l', str(p), d + '/chap.pdf', '-'], capture_output=True, text=True).stdout
    heads.append(x.strip().split('\n')[0])
check(heads and all('Law of Error' in h for h in heads), '-mbook: a chapter titled with an apostrophe keeps its running head', heads)
sys.exit(fail)
PY

if [ $fail -ne 0 ]; then
    echo "slides_test: FAIL"
    sed -n '1,20p' "$tmp/emu.log"
    exit 1
fi
echo "slides_test: PASS"
