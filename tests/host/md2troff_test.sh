#!/bin/sh
#
# md2troff_test.sh — md2troff(1), Markdown as troff's input for -mbook
# and the classes on it, and book(1) given Markdown:
#
#	md2troff's troff for each of tests/md2troff's documents is what it
#	was: doc.md (an article: its front matter, every block and element
#	of a line, notes, citations, cross-references, a table, a figure),
#	book.md (chapters, endnotes, levels deeper than the macros go, an
#	appendix), memo.md, slides.md (parts, slides, a pause, columns),
#	unnum.md (unnumbered headings), quotes.md under -q gb, us and none
#	(British marks, American, and straight ones as typed; apostrophes;
#	curly marks and escaped ones left as they are);
#	-k gives the front matter's macros and bibliography;
#	book sets doc.md as a PDF that claims PDF/UA-1, every word of its
#	text (k001 ...) set once, its comment's and speaker notes' (k998,
#	k999) not at all; its structure has Code, Note, L, Table, Caption,
#	BlockQuote, Figure, Link and Formula; its quotation marks are
#	British, as its lang: says;
#	a second paragraph in a quotation, and in a list's item, begins at
#	their indent, not at the page's margin (-mbook's .p, which set it
#	there);
#	book sets unnum.md's unnumbered chapter, section and subsection
#	without numbers, and numbers the others on;
#	book -l sets Markdown for a document view (troff's output);
#	book2tex writes .code as LaTeX's verbatim, troff's escapes undone,
#	.subsection* as \subsection*, every brace and environment closed;
#	md2troff says what it does not set: an image with no description,
#	a note not there, HTML.

. "$(dirname "$0")/common.sh"
cd "$ROOT"

[ -x "$EMU" ] || { echo "md2troff_test: SKIP (no emu)"; exit 77; }
[ -f "$ROOT/dis/md2troff.dis" ] && [ -f "$ROOT/dis/troff.dis" ] && [ -f "$ROOT/dis/tr2pdf.dis" ] &&
    [ -f "$ROOT/dis/book2tex.dis" ] || { echo "md2troff_test: SKIP (dis not built)"; exit 77; }
command -v python3 >/dev/null 2>&1 || { echo "md2troff_test: SKIP (no python3)"; exit 77; }
command -v pdftotext >/dev/null 2>&1 || { echo "md2troff_test: SKIP (no pdftotext)"; exit 77; }

fail=0
tmp=$(mktemp -d "${TMPDIR:-/tmp}/md2troff.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
cp tests/md2troff/* "$tmp/"

inferno() {
    with_timeout 300 "$EMU" -c1 -r"$ROOT" /dis/sh.dis -c "cd '#U*$tmp'; $1" </dev/null >>"$tmp/emu.log" 2>&1
}

pass() { echo "PASS: $1"; }
failed() { echo "FAIL: $1"; fail=1; }

# a grey square, for the figure
python3 -I - "$tmp/fig.png" <<'PY'
import struct, sys, zlib
w = h = 16
raw = b''.join(b'\x00' + bytes([128]) * w for _ in range(h))
def chunk(t, d):
    return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
open(sys.argv[1], 'wb').write(b'\x89PNG\r\n\x1a\n' +
    chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 0, 0, 0, 0)) +
    chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))
PY

# the troff each document makes is what it made
for f in doc book memo slides unnum; do
    inferno "md2troff $f.md >$f.got >[2]$f.err"
    if cmp -s "$tmp/$f.got" "tests/md2troff/$f.ms"; then
        pass "$f.md's troff is what it was"
    else
        failed "$f.md's troff differs: $(diff "tests/md2troff/$f.ms" "$tmp/$f.got" | head -8 | tr '\n' ' ')"
    fi
done
for q in gb us none; do
    inferno "md2troff -q $q quotes.md >quotes.$q.got"
    if cmp -s "$tmp/quotes.$q.got" "tests/md2troff/quotes.$q.ms"; then
        pass "quotes.md under -q $q"
    else
        failed "quotes.md under -q $q: $(diff "tests/md2troff/quotes.$q.ms" "$tmp/quotes.$q.got" | tr '\n' ' ')"
    fi
done
for f in doc book memo slides unnum; do
    [ -s "$tmp/$f.err" ] && failed "$f.md: md2troff said: $(cat "$tmp/$f.err")"
done

# -k: what book(1) asks of the front matter
inferno "md2troff -k macros doc.md >k1; md2troff -k bibliography doc.md >k2; md2troff -k macros book.md >k3"
[ "$(cat "$tmp/k1")" = article ] && [ "$(cat "$tmp/k2")" = works.bib ] && [ "$(cat "$tmp/k3")" = book ] &&
    pass "-k gives the macros and the bibliography" ||
    failed "-k: $(cat "$tmp/k1" "$tmp/k2" "$tmp/k3" | tr '\n' ' ')"

# the article, set
inferno "book doc.md"
if [ ! -s "$tmp/doc.pdf" ]; then
    failed "book doc.md made no PDF: $(grep -v fsqid "$tmp/emu.log" | tail -5)"
else
    [ -f "$tmp/doc.md.tr" ] && failed "book left its troff (doc.md.tr) behind"
    python3 -I - "$tmp/doc.md" "$tmp/doc.pdf" <<'PY' || fail=1
import re, subprocess, sys
md, pdf = sys.argv[1], sys.argv[2]
fail = 0
def check(ok, what):
    global fail
    print(('PASS: ' if ok else 'FAIL: ') + what)
    if not ok:
        fail = 1

text = subprocess.run(['pdftotext', pdf, '-'], capture_output=True, text=True).stdout
want = sorted(set(re.findall(r'k0\d\d', open(md, encoding='utf-8').read())))
got = re.findall(r'k\d\d\d', text)
counts = {w: got.count(w) for w in want}
missing = [w for w in want if counts[w] == 0]
twice = [w for w in want if counts[w] > 1]
check(not missing and not twice, 'every word of doc.md set once (%d of them)%s%s' % (len(want),
    ' missing: ' + ' '.join(missing) if missing else '', ' twice: ' + ' '.join(twice) if twice else ''))
check('k998' not in got and 'k999' not in got, 'a comment and speaker notes are not set')
check('‘k012 quoted’' in text and '“k013 inner”' in text, 'its quotation marks British, as lang: en-GB has them')
check('k014’s' in text and 'k015…' in text and '–' in text and '—' in text,
    'apostrophes, dashes and an ellipsis set')

raw = open(pdf, 'rb').read()
check(b'pdfuaid:part' in raw, 'the PDF claims PDF/UA-1')
try:
    import pypdf
except ImportError:
    pypdf = None
if pypdf:
    r = pypdf.PdfReader(pdf)
    types = set()
    def walk(e):
        e = e.get_object()
        if isinstance(e, pypdf.generic.DictionaryObject):
            if '/S' in e:
                types.add(str(e['/S'])[1:])
            k = e.get('/K')
            if k is not None:
                walk(k)
        elif isinstance(e, pypdf.generic.ArrayObject):
            for x in e:
                walk(x)
    walk(r.trailer['/Root']['/StructTreeRoot'])
    need = ['Code', 'Note', 'L', 'Table', 'Caption', 'BlockQuote', 'Figure', 'Link', 'Formula']
    check(all(t in types for t in need), 'its structure has %s (%s)' % (', '.join(need),
        ' '.join(sorted(t for t in need if t not in types)) or 'all'))

# each line's left edge, by a word on it
bbox = subprocess.run(['pdftotext', '-bbox', pdf, '-'], capture_output=True, text=True).stdout
words = []
for pg, page in enumerate(bbox.split('<page ')[1:]):
    words += [(pg, float(m.group(1)), float(m.group(2)), m.group(3)) for m in
        re.finditer(r'<word xMin="([\d.]+)" yMin="([\d.]+)"[^>]*>([^<]*)</word>', page)]
def start(w):
    for pg, x, y, t in words:
        if t == w:
            return min(x2 for pg2, x2, y2, t2 in words if pg2 == pg and abs(y2 - y) < 1)
    return None
def at(w):
    for pg, x, y, t in words:
        if t == w:
            return x
    return None
q1, q2 = start('k033'), start('k034')
check(q1 is not None and q2 is not None and q2 >= q1,
    'a quotation\'s second paragraph begins at its indent (%s, its first at %s)' % (q2, q1))
i1, i2 = at('k037'), start('k038')
check(i1 is not None and i2 is not None and i2 >= i1 - 0.5,
    'an item\'s second paragraph begins at its indent (%s, its text at %s)' % (i2, i1))
sys.exit(fail)
PY
fi

# the unnumbered headings, set
inferno "book unnum.md"
if [ -s "$tmp/unnum.pdf" ]; then
    t=$(pdftotext "$tmp/unnum.pdf" - | tr -s ' \n' '  ')
    case "$t" in
    *"1.1 Numbered"*"Plain"*"Also plain"*"1.1.1 Numbered again"*)
        case "$t" in
        *[0-9]" Plain"*|*[0-9]" Also plain"*|*[0-9]" Opening"*) failed "an unnumbered heading has a number: $t" ;;
        *) pass "unnumbered chapter, section and subsection set without numbers, the others numbered on" ;;
        esac ;;
    *) failed "unnum.md: $t" ;;
    esac
else
    failed "book unnum.md made no PDF"
fi

# a document view's live preview
inferno "book -l memo.md >live.out"
head -c 3 "$tmp/live.out" | grep -q 'x T' && pass "book -l sets Markdown for a document view" ||
    failed "book -l memo.md: $(head -c 80 "$tmp/live.out")"

# as LaTeX
inferno "book2tex -m article -p works.bib -o doc.tex doc.ms; md2troff -m article unnum.md >u.ms; book2tex -m article -o u.tex u.ms"
python3 -I - "$tmp/doc.tex" "$tmp/u.tex" <<'PY' || fail=1
import re, sys
fail = 0
def check(ok, what):
    global fail
    print(('PASS: ' if ok else 'FAIL: ') + what)
    if not ok:
        fail = 1
d = open(sys.argv[1], encoding='utf-8').read()
u = open(sys.argv[2], encoding='utf-8').read()
m = re.search(r'\\begin\{verbatim\}\n(.*?)\\end\{verbatim\}', d, re.S)
check(m and 'int k048 = 1;   /* a $ and a \\ */' in m.group(1) and ".k049 at a line's start" in m.group(1),
    '.code as LaTeX\'s verbatim, troff\'s escapes undone')
check('\\section*{Opening}' in u and '\\subsection*{Plain}' in u and '\\subsection{Numbered}' in u,
    '.section* and .subsection* as LaTeX\'s')
def closed(s):
    s = re.sub(r'\\begin\{verbatim\}.*?\\end\{verbatim\}', '', s, flags=re.S)
    s = re.sub(r'\\[{}%$&#_]', '', s)
    s = re.sub(r'(?<!\\)%.*', '', s)
    if s.count('{') != s.count('}'):
        return False
    return sorted(re.findall(r'\\begin\{([^}]*)\}', s)) == sorted(re.findall(r'\\end\{([^}]*)\}', s))
check(closed(d) and closed(u), 'every brace and environment closed')
sys.exit(fail)
PY

# what it does not set, said
inferno "md2troff warn.md >warn.got >[2]warn.err"
e=$(cat "$tmp/warn.err")
case "$e" in
*"no description"*) case "$e" in
    *"no such note"*) case "$e" in
        *"HTML"*) pass "md2troff says what it does not set" ;;
        *) failed "no word of the HTML: $e" ;;
        esac ;;
    *) failed "no word of the missing note: $e" ;;
    esac ;;
*) failed "no word of the image with no description: $e" ;;
esac

exit $fail
