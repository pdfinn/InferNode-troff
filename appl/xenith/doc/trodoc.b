implement Docengine;

#
# trodoc - troff for Xenith's document view (docengine(2)).
#
# Two kinds of document: troff's output (troff(6)), shown as it is,
# and troff's input (a .ms or .man file and the like), set by troff(1)
# and shown beside its text. A sheet a page, at scale 100 in points,
# painted by troffpage(2) with the device's outline fonts: sharp at
# any zoom.
#
# Input is set with the macro package its name says (.ms -ms, .man
# -man, .me -me, .mm -m), troff run in the file's directory so that
# .so finds what it names. A book's, an article's or a memorandum's
# (-mbook or a class built on it) is set by book(1) -l, preprocessors,
# references and all, as book(1) would set it to print: it is one when
# a line near its top says how,
#
#	.\" book -m article -S numeric -p works.bib
#
# (book(1)'s options: -f, -m, -p, -S; the file's name may follow), or
# when it uses -mbook's headings (.chapter, .section, .part,
# .maketitle) or paragraphs (.p); a talk's slides (book -m slides)
# when it has a .slide. Its cross-references
# are taken from book.aux beside it, where book(1) left them, the first
# time; then from the last time it was set, kept in /tmp.
#

include "sys.m";
	sys: Sys;

include "draw.m";
	draw: Draw;
	Display, Image, Point, Rect: import draw;

include "sh.m";

include "troffpage.m";
	troffpage: Troffpage;
	Doc: import troffpage;

include "docengine.m";

MAXREAD: con 64*1024*1024;
TROFF: con "/dis/troff.dis";
SH: con "/dis/sh.dis";
BOOK: con "/dis/book";

State: adt {
	doc:	ref Doc;
	source:	int;		# set from troff's input
	text:	array of string;	# each page's text, once asked for
	runs:	array of array of Run;
	links:	array of array of Link;
};

display: ref Display;
docs: array of ref State;

init(d: ref Display): string
{
	sys = load Sys Sys->PATH;
	draw = load Draw Draw->PATH;
	display = d;
	return nil;
}

loadpage(): string
{
	if(troffpage != nil)
		return nil;
	t := load Troffpage Troffpage->PATH;
	if(t == nil)
		return sys->sprint("cannot load %s: %r", Troffpage->PATH);
	if((err := t->init(display)) != nil)
		return err;
	troffpage = t;
	return nil;
}

open(data: array of byte, name: string, nil: ref Style): (int, string)
{
	if((err := loadpage()) != nil)
		return (-1, err);
	if(data == nil && (data = readfile(name)) == nil)
		return (-1, sys->sprint("cannot read %s: %r", name));
	source := 0;
	if(!troffpage->istroff(data)){
		source = 1;
		msgs: string;
		(data, msgs) = settroff(data, name);
		if(data == nil || !troffpage->istroff(data)){
			if(msgs == nil)
				msgs = "troff wrote nothing";
			return (-1, "troff: " + msgs);
		}
	}
	# (its images' names are from its directory, as troff read them)
	(doc, e) := troffpage->opendir(data, nil, dirname(name));
	if(doc == nil)
		return (-1, "troff: " + e);
	if(doc.npages == 0)
		return (-1, "troff: no pages");
	n := doc.npages;
	return (add(ref State(doc, source, array[n] of string, array[n] of array of Run, array[n] of array of Link)), nil);
}

# the macro package for a file of troff input, by its name
macros(name: string): list of string
{
	ext := "";
	for(i := len name - 1; i >= 0 && name[i] != '/'; i--)
		if(name[i] == '.'){
			ext = name[i:];
			break;
		}
	case ext {
	".ms" =>
		return "-ms" :: nil;
	".man" =>
		return "-man" :: nil;
	".me" =>
		return "-me" :: nil;
	".mm" =>
		return "-m" :: nil;
	}
	return nil;
}

dirname(name: string): string
{
	for(i := len name - 1; i >= 0; i--)
		if(name[i] == '/'){
			if(i == 0)
				return "/";
			return name[0:i];
		}
	return ".";
}

# set troff's input data, named name; its output, and what it said on its standard error
settroff(data: array of byte, name: string): (array of byte, string)
{
	(isbook, opts) := bookopts(data);
	if(isbook)
		return setbook(data, name, opts);
	return run(TROFF, "troff" :: macros(name), dirname(name), data);
}

# run cmd, with args, in dir, data its standard input: its standard
# output, and what it said on its standard error
run(cmd: string, args: list of string, dir: string, data: array of byte): (array of byte, string)
{
	inp := array[2] of ref Sys->FD;
	outp := array[2] of ref Sys->FD;
	errp := array[2] of ref Sys->FD;
	if(sys->pipe(inp) < 0 || sys->pipe(outp) < 0 || sys->pipe(errp) < 0)
		return (nil, sys->sprint("cannot make pipes: %r"));
	sync := chan of int;
	spawn runcmd(cmd, args, dir, inp[0], outp[1], errp[1], sync);
	<-sync;
	inp[0] = outp[1] = errp[1] = nil;
	spawn feed(inp[1], data);
	inp[1] = nil;
	errc := chan of string;
	spawn drain(errp[0], errc);
	errp[0] = nil;
	out := readall(outp[0]);
	msgs := <-errc;
	return (out, msgs);
}

runcmd(cmd: string, args: list of string, dir: string, in, out, err: ref Sys->FD, sync: chan of int)
{
	sys->pctl(Sys->NEWFD|Sys->FORKNS, in.fd :: out.fd :: err.fd :: nil);
	sys->dup(in.fd, 0);
	sys->dup(out.fd, 1);
	sys->dup(err.fd, 2);
	in = out = err = nil;
	sys->chdir(dir);
	sync <-= 1;
	t := load Command cmd;
	if(t == nil){
		sys->fprint(sys->fildes(2), "cannot load %s: %r\n", cmd);
		return;
	}
	{
		t->init(nil, args);
	} exception {
	"fail:*" =>
		;
	}
}

# ---- a book's (-mbook's) ----

# whether data is a book's to be set by book(1), and book's options for it
bookopts(data: array of byte): (int, list of string)
{
	heads := 0;
	slides := 0;
	nl := 0;
	for(i := 0; i < len data; ){
		e := i;
		while(e < len data && data[e] != byte '\n')
			e++;
		line := string data[i:e];
		i = e + 1;
		if(++nl <= 20 && (o := directive(line)) != nil)
			return (1, tl o);
		if(prefix(line, ".chapter") || prefix(line, ".section") || prefix(line, ".part ") ||
				prefix(line, ".maketitle") || line == ".p")
			heads = 1;
		if(prefix(line, ".slide"))
			slides = 1;
	}
	# a talk's slides (-mslides'), by their .slide
	if(slides)
		return (1, "-m" :: "slides" :: nil);
	return (heads, nil);
}

# a comment saying how the file is set, "book" and book's options, or
# nil: .\" book -m article -p works.bib (its source's name, and what
# follows it, may be there too: .\"	book -p works.bib chapter.ms)
directive(line: string): list of string
{
	if(!prefix(line, ".\\\""))
		return nil;
	(nil, w) := sys->tokenize(line[3:], " \t\r");
	if(w == nil || hd w != "book")
		return nil;
	if(tl w != nil && (hd tl w)[0] != '-' && macros(hd tl w) == nil)
		return nil;
	return "book" :: options(tl w);
}

# the options book(1) is given by a directive's words: -f, and -m, -p
# and -S with their values; anything else left out
options(w: list of string): list of string
{
	o: list of string;
	for(; w != nil; w = tl w)
		case hd w {
		"-f" =>
			o = "-f" :: o;
		"-m" or "-p" or "-S" =>
			if(tl w != nil){
				o = hd tl w :: hd w :: o;
				w = tl w;
			}
		}
	return rev(o);
}

rev(l: list of string): list of string
{
	r: list of string;
	for(; l != nil; l = tl l)
		r = hd l :: r;
	return r;
}

prefix(s, p: string): int
{
	return len s >= len p && s[0:len p] == p;
}

nbook := 0;

# set a book's text by book -l: written to /tmp (it may not be saved),
# set in its own directory; its cross-references kept in /tmp between
# times, and taken from its book.aux the first time
setbook(data: array of byte, name: string, opts: list of string): (array of byte, string)
{
	dir := dirname(name);
	keep := sys->sprint("/tmp/trodoc.%ux.aux", hash(name));
	stem := sys->sprint("/tmp/trodoc.%ux.%d.%d", hash(name), sys->pctl(0, nil), nbook++);
	src := stem + ".ms";
	if(writefile(src, data) < 0)
		return (nil, sys->sprint("cannot write %s: %r", src));
	aux := readfile(keep);
	if(aux == nil){
		s := name;
		for(i := len s - 1; i >= 0 && s[i] != '/'; i--)
			if(s[i] == '.'){
				s = s[0:i];
				break;
			}
		if(s[0] != '/')
			s = dir + "/" + s;
		aux = readfile(s + ".aux");
	}
	if(aux == nil)
		aux = array[0] of byte;
	writefile(stem + ".aux", aux);
	args := src :: nil;
	for(r := rev(opts); r != nil; r = tl r)
		args = hd r :: args;
	(out, msgs) := run(SH, "sh" :: BOOK :: "-l" :: args, dir, array[0] of byte);
	if((aux = readfile(stem + ".aux")) != nil)
		writefile(keep, aux);
	sys->remove(src);
	sys->remove(stem + ".aux");
	sys->remove(stem + ".ind");
	return (out, msgs);
}

hash(s: string): int
{
	h := 0;
	for(i := 0; i < len s; i++)
		h = h * 31 + s[i];
	return h & 16r7FFFFFFF;
}

writefile(path: string, data: array of byte): int
{
	fd := sys->create(path, Sys->OWRITE, 8r600);
	if(fd == nil)
		return -1;
	if(len data > 0 && sys->write(fd, data, len data) != len data)
		return -1;
	return 0;
}

feed(fd: ref Sys->FD, data: array of byte)
{
	for(i := 0; i < len data; ){
		n := len data - i;
		if(n > Sys->ATOMICIO)
			n = Sys->ATOMICIO;
		if(sys->write(fd, data[i:i+n], n) != n)
			break;
		i += n;
	}
}

drain(fd: ref Sys->FD, c: chan of string)
{
	c <-= string readall(fd);
}

readall(fd: ref Sys->FD): array of byte
{
	b := array[64*1024] of byte;
	n := 0;
	for(;;){
		if(n == len b){
			nb := array[2 * len b] of byte;
			nb[0:] = b;
			b = nb;
		}
		m := sys->read(fd, b[n:], len b - n);
		if(m <= 0)
			break;
		n += m;
	}
	return b[0:n];
}

close(h: int)
{
	if((s := get(h)) != nil)
		s.doc.close();
	if(h >= 0 && h < len docs)
		docs[h] = nil;
}

nsheets(h: int): int
{
	if((s := get(h)) == nil)
		return 0;
	return s.doc.npages;
}

sheetsize(h: int, n: int): Point
{
	s := get(h);
	if(s == nil || n < 0 || n >= s.doc.npages)
		return Point(0, 0);
	return Point(s.doc.width, s.doc.height);
}

restyle(nil: int, nil: ref Style): string
{
	return nil;
}

scalable(nil: int): int
{
	return 1;
}

pinned(nil: int): int
{
	return 0;
}

paint(h: int, n: int, scale: int, dst: ref Image, r: Rect, org: Point): string
{
	s := get(h);
	if(s == nil || n < 0 || n >= s.doc.npages)
		return "no such page";
	return s.doc.paint(n, real scale / 100.0, dst, r, org);
}

text(h: int): string
{
	s := get(h);
	if(s == nil)
		return nil;
	t := "";
	for(n := 0; n < s.doc.npages; n++){
		if(n > 0)
			t += "\n\n--- Page " + string (n+1) + " ---\n\n";
		t += sheettext(h, n);
	}
	return t;
}

sheettext(h: int, n: int): string
{
	s := get(h);
	if(s == nil || n < 0 || n >= s.doc.npages)
		return nil;
	if(s.text[n] == nil)
		s.text[n] = s.doc.text(n);
	return s.text[n];
}

runs(h: int, n: int): array of Run
{
	s := get(h);
	if(s == nil || n < 0 || n >= s.doc.npages)
		return nil;
	if(s.runs[n] == nil){
		w := s.doc.words(n);
		a := array[len w] of Run;
		for(i := 0; i < len w; i++)
			a[i] = Run(w[i].text, w[i].r);
		s.runs[n] = a;
	}
	return s.runs[n];
}

links(h: int): array of Link
{
	s := get(h);
	if(s == nil)
		return nil;
	l: list of Link;
	k := 0;
	for(n := s.doc.npages - 1; n >= 0; n--){
		a := pagelinks(s, n);
		for(i := len a - 1; i >= 0; i--){
			l = a[i] :: l;
			k++;
		}
	}
	r := array[k] of Link;
	for(i := 0; l != nil; l = tl l)
		r[i++] = hd l;
	return r;
}

linkat(h: int, n: int, p: Point): string
{
	s := get(h);
	if(s == nil || n < 0 || n >= s.doc.npages)
		return nil;
	a := pagelinks(s, n);
	for(i := len a - 1; i >= 0; i--)
		if(p.in(a[i].r))
			return a[i].url;
	return nil;
}

pagelinks(s: ref State, n: int): array of Link
{
	if(s.links[n] == nil){
		l := s.doc.links(n);
		a := array[len l] of Link;
		for(i := 0; i < len l; i++)
			a[i] = Link(n, l[i].r, l[i].url);
		s.links[n] = a;
	}
	return s.links[n];
}

lineto(nil: int, nil: int): (int, int)
{
	return (0, 0);
}

lineat(nil: int, nil: int, nil: int): int
{
	return 0;
}

viewing(nil: int, nil: int, nil: int)
{
}

commands(nil: int): list of string
{
	return nil;
}

command(nil: int, cmd, nil: string): string
{
	return "unknown command " + cmd;
}

events(nil: int): chan of string
{
	return nil;
}

name(nil: int): string
{
	return nil;
}

click(nil: int, nil: int, nil: Point): string
{
	return nil;
}

key(nil: int, nil: int): string
{
	return nil;
}

files(nil: int): string
{
	return nil;
}

add(s: ref State): int
{
	for(i := 0; i < len docs; i++)
		if(docs[i] == nil){
			docs[i] = s;
			return i;
		}
	n := array[len docs + 4] of ref State;
	n[0:] = docs;
	n[len docs] = s;
	h := len docs;
	docs = n;
	return h;
}

get(h: int): ref State
{
	d := docs;
	if(h < 0 || h >= len d)
		return nil;
	return d[h];
}

readfile(path: string): array of byte
{
	fd := sys->open(path, Sys->OREAD);
	if(fd == nil)
		return nil;
	(ok, dir) := sys->fstat(fd);
	if(ok != 0 || dir.length <= big 0 || dir.length > big MAXREAD)
		return nil;
	n := int dir.length;
	b := array[n] of byte;
	for(t := 0; t < n; ){
		m := sys->read(fd, b[t:], n - t);
		if(m <= 0)
			return nil;
		t += m;
	}
	return b;
}
