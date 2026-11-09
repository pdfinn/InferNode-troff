implement Md2troff;

#
# md2troff - Markdown as troff's input, for book(1) and the macros -mbook
#
#	md2troff [-m macros] [-q gb|us|none] [-k key] [file.md]
#
# Reads Markdown, CommonMark's with GitHub's tables, task lists,
# strikethrough and bare links and pandoc's front matter, footnotes,
# citations, mathematics, heading attributes, figures, fenced divs and
# raw troff, and writes troff for -mbook or a class built on it
# (article, memo, slides: -m, or macros: in the front matter).
#
# The blocks: headings as .chapter, .section, .subsection and
# .subsubsection (in an article, memorandum or talk one level up), a
# heading's {#label} its label, {-} or {.unnumbered} unnumbered (the
# macro with *), {.appendix} .appendix before it; a lone first heading
# of the first level is the title when the front matter gives none;
# the highest level of heading the text then has is the first, a
# chapter (or a section), and a level deeper than the macros go is set
# as their deepest.  Paragraphs .p; block quotations .quote;
# lists .list (1, a, i or bullet; a list that begins elsewhere than at
# one, or with ")", has its marks given), task lists' items marked ☐ and
# ☒; code, fenced or indented, .code; a horizontal rule a centred * * *
# (in a talk, a new slide); a pipe table tbl's, with a caption (pandoc's
# "Table: ..." or ": ...", before it or after) a floating .table; an
# image alone in its paragraph a .figure, its text the caption, its
# title or its text the .alt; $$ ... $$ a display for eqn; ::: divs
# (columns, column, epigraph, abstract, notes, and any other, whose
# text is set as it is); ```{=troff} and `...`{=troff} troff as written;
# HTML not set, a comment dropped.
#
# In the line: emphasis, strong emphasis (an emphasis within a font
# that is italic already set roman), code in Libertinus Mono,
# ~~strikethrough~~, ^superscript^ and ~subscript~; links .link, a bare
# address .url, either with the punctuation after it joined; [^note]s
# and ^[inline notes] .fn (or .en, with notes: endnotes), the
# punctuation after a mark set before it; [@key, place; @key2]
# citations .cite, the same; a key that is a label, [@fig:curve], a
# cross-reference, \*[ref label]; $...$ eqn's mathematics, in eqn's
# language, not TeX's; entities; hard line breaks .br.
#
# Typography: -- an en dash, --- an em dash, ... an ellipsis; a
# straight double quote the first quotation mark and a straight single
# one, where it is not an apostrophe, the second (a quotation within a
# quotation): British, ‘ ’ and “ ”, or American, “ ” and ‘ ’, from -q,
# or quotes: in the front matter, or its lang:, or the curly marks the
# text already has; failing all of these British, and said.  -q none
# leaves straight quotes as they are.  Curly quotes are left as they
# are written.
#
# The front matter: title, subtitle, author (one, or a list, each a
# name or name, affiliation, email, location, extension), date,
# abstract, keywords, lang, quotes, macros, numbersections (false: no
# heading numbered), toc (true: .contents), notes (endnotes),
# bibliography and citestyle (for book(1)), papersize, columns, and a
# memorandum's org, case, file, number, kind and memotype, a talk's
# aspect and typeface.  -k prints one of them (macros as it is
# resolved), for book(1).
#

include "sys.m";
	sys: Sys;
include "draw.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "string.m";
	str: String;

Md2troff: module
{
	init:	fn(nil: ref Draw->Context, args: list of string);
};

SP: con 16r01;		# a space an output line may be broken at
WIDTH: con 72;		# output lines are filled to this

Attr: adt {
	id:	string;
	classes:	list of string;
	kv:	list of (string, string);
};

Block: adt {
	pick {
	Para =>
		text:	string;
	Head =>
		level:	int;
		text:	string;
		attr:	ref Attr;
	Code =>
		info:	string;
		lines:	list of string;
	Raw =>
		fmt:	string;
		lines:	list of string;
	Math =>
		lines:	list of string;
	Quote =>
		blocks:	list of ref Block;
	List =>
		kind:	string;	# 1, a, i, bullet
		delim:	int;	# . or ) after an ordered list's numbers
		start:	int;
		tight:	int;
		items:	list of ref Item;
	Rule =>
		n:	int;
	Pause =>
		n:	int;
	Table =>
		aligns:	array of int;
		head:	array of string;
		rows:	list of array of string;
		caption:	string;
		attr:	ref Attr;
	Div =>
		attr:	ref Attr;
		blocks:	list of ref Block;
	}
};

Item: adt {
	task:	int;	# -1 not a task, 0 to do, 1 done
	blocks:	list of ref Block;
};

Inl: adt {
	pick {
	Text =>
		s:	string;
		lit:	int;	# escaped: no typography
	Code =>
		s:	string;
	Em =>
		kids:	list of ref Inl;
	Strong =>
		kids:	list of ref Inl;
	Strike =>
		kids:	list of ref Inl;
	Sup =>
		kids:	list of ref Inl;
	Sub =>
		kids:	list of ref Inl;
	Link =>
		url:	string;
		title:	string;
		kids:	list of ref Inl;
		auto:	int;
	Image =>
		url:	string;
		title:	string;
		kids:	list of ref Inl;
		attr:	ref Attr;
	Note =>
		blocks:	list of ref Block;
	Cite =>
		items:	list of (string, string);	# key, place
	Math =>
		s:	string;
	Raw =>
		s:	string;
	Break =>
		n:	int;
	Soft =>
		n:	int;
	}
};

# a token of a line while its emphasis is found: an element, or a
# run of * _ ~ that may open or close one
Tok: adt {
	inl:	ref Inl;
	dc:	int;
	n:	int;
	orig:	int;
	opener:	int;
	closer:	int;
};

Author: adt {
	name:	string;
	affil:	string;
	email:	string;
	loc:	string;
	ext:	string;
};

# how a run of text is being set
Ctx: adt {
	base:	string;	# its font: R, B, I or BI
	em:	int;
	strong:	int;
	code:	int;
	font:	string;	# the font troff is in
	arg:	int;	# a macro's argument: no requests, no breaks
	buf:	string;
	changed:	int;
};

stderr: ref Sys->FD;
fname := "stdin";
macros := "";
qstyle := "";
numbered := 1;
endnotes := 0;
shift := 0;
slidelevel := 1;

notedefs: list of (string, list of ref Block);
linkrefs: list of (string, string, string);
labels: list of string;
warned: list of string;
metas: list of (string, string);
metal: list of (string, list of string);
authors: list of ref Author;

mathused := 0;
citesused := 0;
bibset := 0;
qguess := 0;		# the quotation marks' style a guess: said when one is set

out: list of string;	# the output's lines, last first
cur := "";		# the line being filled
lastc := 0;		# the last character set, for quotation marks
sopen := 0;		# second quotation marks open
figq: list of ref Inl;	# images met in a paragraph, set after it

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
	str = load String String->PATH;
	stderr = sys->fildes(2);
	key := "";
	mopt := "";
	if(args != nil)
		args = tl args;
	while(args != nil && len hd args > 1 && (hd args)[0] == '-'){
		o := hd args;
		args = tl args;
		if(o != "-m" && o != "-q" && o != "-k")
			usage();
		if(args == nil)
			usage();
		v := hd args;
		args = tl args;
		case o {
		"-m" =>
			mopt = v;
		"-q" =>
			qstyle = qnorm(v);
			if(qstyle == "")
				usage();
		"-k" =>
			key = str->tolower(v);
		}
	}
	if(len args > 1)
		usage();
	b: ref Iobuf;
	if(args == nil)
		b = bufio->fopen(sys->fildes(0), Bufio->OREAD);
	else{
		fname = hd args;
		b = bufio->open(fname, Bufio->OREAD);
		if(b == nil){
			sys->fprint(stderr, "md2troff: cannot open %s: %r\n", fname);
			raise "fail:open";
		}
	}
	ls := readall(b);
	ls = frontmatter(ls);
	macros = mopt;
	if(macros == "")
		macros = metav("macros");
	if(macros == "")
		macros = metav("class");
	if(macros == "")
		macros = "book";
	if(str->prefix("-m", macros))
		macros = macros[2:];
	if(key != ""){
		if(key == "macros")
			sys->print("%s\n", macros);
		else{
			v := metav(key);
			if(v == "")
				v = join(metalv(key), " ");
			if(v != "")
				sys->print("%s\n", v);
		}
		return;
	}
	if(macros != "book" && macros != "article" && macros != "memo" && macros != "slides")
		warn("macros " + macros + ": not one md2troff knows (book, article, memo, slides); its headings set as -mbook's");
	quotestyle(ls);
	v := str->tolower(metav("numbersections"));
	if(v == "false" || v == "no" || v == "0")
		numbered = 0;
	v = str->tolower(metav("notes"));
	if(v == "endnotes" || v == "end")
		endnotes = 1;
	bl := parse(ls);
	bl = titlefrom(bl);
	# the highest level of heading the text has is the macros' first
	m := minlevel(bl, 7);
	if(m < 7 && m - 1 > shift)
		shift = m - 1;
	findlabels(bl);
	slidelevel = 1;
	if(macros == "slides" && haslevel(bl, 2 + shift))
		slidelevel = 2;
	head();
	blocks(bl, 0);
	if(citesused && !bibset)
		req(".bibliography");
	if(endnotes)
		req(".notes");
	v = str->tolower(metav("signature"));
	if(macros == "memo" && (v == "true" || v == "yes"))
		req(".signature");
	flush();
	o := bufio->fopen(sys->fildes(1), Bufio->OWRITE);
	o.puts(".\\\" set from " + fname + " by md2troff\n");
	if(mathused)
		o.puts(".EQ\ndelim $$\n.EN\n");
	for(l := rev(out); l != nil; l = tl l)
		o.puts(hd l + "\n");
	o.flush();
}

usage()
{
	sys->fprint(stderr, "usage: md2troff [-m macros] [-q gb|us|none] [-k key] [file.md]\n");
	raise "fail:usage";
}

warn(s: string)
{
	sys->fprint(stderr, "md2troff: %s: %s\n", fname, s);
}

# a warning given once, however often its cause is met
warn1(k, s: string)
{
	for(l := warned; l != nil; l = tl l)
		if(hd l == k)
			return;
	warned = k :: warned;
	warn(s);
}

#
# characters and strings
#

chr(c: int): string
{
	s := " ";
	s[0] = c;
	return s;
}

isspace(c: int): int
{
	return c == ' ' || c == '\t' || c == '\n' || c == '\r';
}

isdigit(c: int): int
{
	return c >= '0' && c <= '9';
}

isalpha(c: int): int
{
	return c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= 16rC0 && c != 16rD7 && c != 16rF7 && c < 16r2000;
}

isalnum(c: int): int
{
	return isalpha(c) || isdigit(c);
}

ispunct(c: int): int
{
	case c {
	'!' to '/' or ':' to '@' or '[' to '`' or '{' to '~' =>
		return 1;
	16r2010 to 16r2027 or 16rA1 to 16rBF =>
		return 1;
	}
	return 0;
}

blank(s: string): int
{
	for(i := 0; i < len s; i++)
		if(s[i] != ' ' && s[i] != '\t')
			return 0;
	return 1;
}

indent(s: string): int
{
	i := 0;
	while(i < len s && s[i] == ' ')
		i++;
	return i;
}

stripind(s: string, n: int): string
{
	i := 0;
	while(i < n && i < len s && s[i] == ' ')
		i++;
	return s[i:];
}

trim(s: string): string
{
	i := 0;
	while(i < len s && isspace(s[i]))
		i++;
	j := len s;
	while(j > i && isspace(s[j-1]))
		j--;
	return s[i:j];
}

ltrim(s: string): string
{
	i := 0;
	while(i < len s && isspace(s[i]))
		i++;
	return s[i:];
}

suffix(t, s: string): int
{
	return len s >= len t && s[len s - len t:] == t;
}

contains(s, t: string): int
{
	if(len t == 0)
		return 1;
	for(i := 0; i + len t <= len s; i++)
		if(s[i:i+len t] == t)
			return 1;
	return 0;
}

# s with every t in it replaced by u
replace(s, t, u: string): string
{
	r := "";
	i := 0;
	while(i < len s){
		if(i + len t <= len s && s[i:i+len t] == t){
			r += u;
			i += len t;
		}else{
			r[len r] = s[i];
			i++;
		}
	}
	return r;
}

# the run of c at the head of s, dropped
dropc(s: string, c: int): string
{
	i := 0;
	while(i < len s && s[i] == c)
		i++;
	return s[i:];
}

rtrimc(s: string, c: int): string
{
	j := len s;
	while(j > 0 && s[j-1] == c)
		j--;
	return s[0:j];
}

join(l: list of string, sep: string): string
{
	s := "";
	for(; l != nil; l = tl l){
		if(s != "")
			s += sep;
		s += hd l;
	}
	return s;
}

rev(l: list of string): list of string
{
	r: list of string;
	for(; l != nil; l = tl l)
		r = hd l :: r;
	return r;
}

revb(l: list of ref Block): list of ref Block
{
	r: list of ref Block;
	for(; l != nil; l = tl l)
		r = hd l :: r;
	return r;
}

revi(l: list of ref Inl): list of ref Inl
{
	r: list of ref Inl;
	for(; l != nil; l = tl l)
		r = hd l :: r;
	return r;
}

toarr(l: list of string): array of string
{
	a := array[len l] of string;
	for(i := 0; l != nil; l = tl l)
		a[i++] = hd l;
	return a;
}

# a label as reference links are matched: case and spacing aside
fold(s: string): string
{
	s = str->tolower(trim(s));
	r := "";
	sp := 0;
	for(i := 0; i < len s; i++){
		if(isspace(s[i])){
			sp = 1;
			continue;
		}
		if(sp && r != "")
			r[len r] = ' ';
		sp = 0;
		r[len r] = s[i];
	}
	return r;
}

#
# input
#

readall(b: ref Iobuf): array of string
{
	l: list of string;
	while((s := b.gets('\n')) != nil){
		if(len s > 0 && s[len s-1] == '\n')
			s = s[0:len s-1];
		if(len s > 0 && s[len s-1] == '\r')
			s = s[0:len s-1];
		l = untab(s) :: l;
	}
	return toarr(rev(l));
}

# tabs as spaces, to stops four apart
untab(s: string): string
{
	if(!contains(s, "\t"))
		return s;
	r := "";
	for(i := 0; i < len s; i++){
		if(s[i] == '\t'){
			do
				r[len r] = ' ';
			while(len r % 4 != 0);
		}else
			r[len r] = s[i];
	}
	return r;
}

#
# the front matter, a little of YAML's
#

frontmatter(ls: array of string): array of string
{
	if(len ls < 2 || trim(ls[0]) != "---")
		return ls;
	(k, nil) := splitkey(ls[1]);
	if(k == "")
		return ls;
	e := 1;
	for(; e < len ls; e++){
		t := trim(ls[e]);
		if(t == "---" || t == "...")
			break;
	}
	if(e == len ls)
		return ls;
	yaml(ls[1:e]);
	return ls[e+1:];
}

# "key: value" as (key, value); a key of letters, digits, - and _
splitkey(s: string): (string, string)
{
	s = trim(s);
	for(i := 0; i < len s; i++){
		c := s[i];
		if(c == ':' && (i+1 == len s || s[i+1] == ' '))
			break;
		if(!isalnum(c) && c != '-' && c != '_')
			return ("", s);
	}
	if(i == 0 || i == len s)
		return ("", s);
	k := str->tolower(s[0:i]);
	v := "";
	if(i+1 < len s)
		v = trim(s[i+1:]);
	return (k, v);
}

unq(v: string): string
{
	v = trim(v);
	if(len v >= 2 && v[0] == '"' && v[len v-1] == '"')
		return replace(replace(v[1:len v-1], "\\\"", "\""), "\\\\", "\\");
	if(len v >= 2 && v[0] == '\'' && v[len v-1] == '\'')
		return replace(v[1:len v-1], "''", "'");
	return v;
}

yaml(ls: array of string)
{
	n := len ls;
	i := 0;
	while(i < n){
		l := ls[i];
		t := trim(l);
		if(t == "" || t[0] == '#' || indent(l) > 0){
			i++;
			continue;
		}
		(k, v) := splitkey(l);
		i++;
		if(k == "")
			continue;
		if(v == "|" || v == "|-" || v == ">" || v == ">-"){
			lines: list of string;
			ind := -1;
			while(i < n && (blank(ls[i]) || indent(ls[i]) > 0)){
				if(!blank(ls[i]) && ind < 0)
					ind = indent(ls[i]);
				lines = stripind(ls[i], ind) :: lines;
				i++;
			}
			while(lines != nil && blank(hd lines))
				lines = tl lines;
			lines = rev(lines);
			text := "";
			if(v[0] == '|')
				text = join(lines, "\n");
			else{
				for(; lines != nil; lines = tl lines){
					if(blank(hd lines))
						text += "\n\n";
					else if(text == "" || suffix("\n", text))
						text += trim(hd lines);
					else
						text += " " + trim(hd lines);
				}
			}
			metas = (k, text) :: metas;
		}else if(v == ""){
			items: list of string;
			auts: list of ref Author;
			a: ref Author;
			while(i < n && (blank(ls[i]) || indent(ls[i]) > 0)){
				u := trim(ls[i]);
				i++;
				if(u == "")
					continue;
				if(u == "-" || str->prefix("- ", u)){
					u = trim(u[1:]);
					(k2, v2) := splitkey(u);
					if(k2 != ""){
						a = ref Author("", "", "", "", "");
						authorfield(a, k2, unq(v2));
						auts = a :: auts;
					}else{
						a = nil;
						items = unq(u) :: items;
						auts = ref Author(unq(u), "", "", "", "") :: auts;
					}
				}else{
					(k2, v2) := splitkey(u);
					if(k2 == "")
						continue;
					if(a != nil)
						authorfield(a, k2, unq(v2));
					else
						metas = (k + "." + k2, unq(v2)) :: metas;
				}
			}
			metal = (k, rev(items)) :: metal;
			if(k == "author" || k == "authors"){
				r: list of ref Author;
				for(; auts != nil; auts = tl auts)
					r = hd auts :: r;
				for(; r != nil; r = tl r)
					authors = hd r :: authors;
			}
		}else if(v[0] == '['){
			v = trim(v[1:]);
			if(suffix("]", v))
				v = v[0:len v-1];
			items: list of string;
			(nil, parts) := sys->tokenize(v, ",");
			for(; parts != nil; parts = tl parts)
				items = unq(hd parts) :: items;
			metal = (k, rev(items)) :: metal;
			if(k == "author" || k == "authors")
				for(l2 := rev(items); l2 != nil; l2 = tl l2)
					authors = ref Author(hd l2, "", "", "", "") :: authors;
		}else{
			metas = (k, unq(v)) :: metas;
			if(k == "author" || k == "authors")
				authors = ref Author(unq(v), "", "", "", "") :: authors;
		}
	}
	# authors in the order written
	r: list of ref Author;
	for(; authors != nil; authors = tl authors)
		r = hd authors :: r;
	authors = r;
}

authorfield(a: ref Author, k, v: string)
{
	case k {
	"name" =>
		a.name = v;
	"affiliation" or "affil" or "institute" or "organization" =>
		a.affil = v;
	"email" =>
		a.email = v;
	"location" or "room" =>
		a.loc = v;
	"extension" or "phone" =>
		a.ext = v;
	}
}

metav(k: string): string
{
	for(l := metas; l != nil; l = tl l){
		(k2, v) := hd l;
		if(k2 == k)
			return v;
	}
	return "";
}

metalv(k: string): list of string
{
	for(l := metal; l != nil; l = tl l){
		(k2, v) := hd l;
		if(k2 == k)
			return v;
	}
	return nil;
}

#
# quotation marks: British, American, or as typed
#

qnorm(v: string): string
{
	case str->tolower(trim(v)) {
	"gb" or "uk" or "british" or "en-gb" or "single" or "oxford" =>
		return "gb";
	"us" or "american" or "en-us" or "double" =>
		return "us";
	"none" or "straight" or "typed" =>
		return "none";
	}
	return "";
}

quotestyle(ls: array of string)
{
	if(qstyle == "")
		qstyle = qnorm(metav("quotes"));
	if(qstyle == ""){
		lang := str->tolower(metav("lang"));
		if(lang == "")
			lang = str->tolower(metav("language"));
		if(str->prefix("en-us", lang) || str->prefix("en-ca", lang) || str->prefix("en-ph", lang))
			qstyle = "us";
		else if(str->prefix("en-", lang) || str->prefix("en_", lang))
			qstyle = "gb";
	}
	s1 := 0;
	d1 := 0;
	for(i := 0; i < len ls; i++){
		l := ls[i];
		for(j := 0; j < len l; j++){
			c := l[j];
			if(c == 16r2018 && (j == 0 || !isalnum(l[j-1])))
				s1++;
			if(c == 16r201C)
				d1++;
		}
	}
	if(qstyle == "" && s1 + d1 > 0){
		if(s1 >= d1)
			qstyle = "gb";
		else
			qstyle = "us";
	}
	if(qstyle == ""){
		qstyle = "gb";
		qguess = 1;
	}
}

#
# blocks
#

parse(ls: array of string): list of ref Block
{
	bl: list of ref Block;
	n := len ls;
	i := 0;
	while(i < n){
		l := ls[i];
		if(blank(l)){
			i++;
			continue;
		}
		ind := indent(l);
		if(ind >= 4){
			cl: list of string;
			j := i;
			while(j < n && (blank(ls[j]) || indent(ls[j]) >= 4)){
				cl = stripind(ls[j], 4) :: cl;
				j++;
			}
			while(cl != nil && blank(hd cl))
				cl = tl cl;
			bl = ref Block.Code("", rev(cl)) :: bl;
			i = j;
			continue;
		}
		t := l[ind:];
		(fc, fcount, info) := fence(t);
		if(fc != 0){
			cl: list of string;
			j := i+1;
			while(j < n){
				u := ls[j];
				if(indent(u) < 4 && closes(u[indent(u):], fc, fcount))
					break;
				cl = stripind(u, ind) :: cl;
				j++;
			}
			i = j+1;
			fmt := rawfmt(trim(info));
			if(fmt != "")
				bl = ref Block.Raw(fmt, rev(cl)) :: bl;
			else
				bl = ref Block.Code(trim(info), rev(cl)) :: bl;
			continue;
		}
		if(str->prefix("$$", t)){
			tt := trim(t);
			if(len tt > 4 && suffix("$$", tt)){
				bl = ref Block.Math(trim(tt[2:len tt-2]) :: nil) :: bl;
				i++;
				continue;
			}
			ml: list of string;
			if(trim(tt[2:]) != "")
				ml = trim(tt[2:]) :: ml;
			j := i+1;
			while(j < n){
				u := trim(ls[j]);
				if(suffix("$$", u)){
					u = trim(u[0:len u-2]);
					if(u != "")
						ml = u :: ml;
					break;
				}
				if(u != "")
					ml = u :: ml;
				j++;
			}
			i = j+1;
			bl = ref Block.Math(rev(ml)) :: bl;
			continue;
		}
		if(str->prefix(":::", t)){
			rest := trim(rtrimc(trim(dropc(t, ':')), ':'));
			i++;
			if(rest == "")
				continue;
			depth := 1;
			dl: list of string;
			while(i < n){
				u := trim(ls[i]);
				if(str->prefix(":::", u)){
					r := trim(rtrimc(trim(dropc(u, ':')), ':'));
					if(r == ""){
						if(--depth == 0)
							break;
					}else
						depth++;
				}
				dl = ls[i] :: dl;
				i++;
			}
			i++;
			bl = ref Block.Div(divattr(rest), parse(toarr(rev(dl)))) :: bl;
			continue;
		}
		(hl, ht) := atx(t);
		if(hl > 0){
			(ht2, attr) := headattr(ht);
			bl = ref Block.Head(hl, ht2, attr) :: bl;
			i++;
			continue;
		}
		if(isrule(t)){
			bl = ref Block.Rule(0) :: bl;
			i++;
			continue;
		}
		if(trim(t) == ". . ."){
			bl = ref Block.Pause(0) :: bl;
			i++;
			continue;
		}
		if(t[0] == '>'){
			ql: list of string;
			j := i;
			while(j < n){
				u := ls[j];
				if(blank(u))
					break;
				iu := indent(u);
				if(iu < 4 && u[iu] == '>'){
					v := u[iu+1:];
					if(len v > 0 && v[0] == ' ')
						v = v[1:];
					ql = v :: ql;
				}else if(ql != nil && !blank(hd ql) && !startsblock(u))
					ql = u :: ql;
				else
					break;
				j++;
			}
			bl = ref Block.Quote(parse(toarr(rev(ql)))) :: bl;
			i = j;
			continue;
		}
		if(str->prefix("<!--", t)){
			j := i;
			while(j < n && !contains(ls[j], "-->"))
				j++;
			i = j+1;
			continue;
		}
		if(htmlblock(t)){
			j := i;
			while(j < n && !blank(ls[j]))
				j++;
			warn1("html", "HTML is not set: troff has no HTML");
			i = j;
			continue;
		}
		if(str->prefix("[^", t)){
			(id, rest, ok) := notedef(t);
			if(ok){
				nl := rest :: nil;
				j := i+1;
				while(j < n){
					u := ls[j];
					if(blank(u)){
						k := j;
						while(k < n && blank(ls[k]))
							k++;
						if(k < n && indent(ls[k]) >= 4){
							for(; j < k; j++)
								nl = "" :: nl;
							continue;
						}
						break;
					}
					if(indent(u) >= 4)
						nl = u[4:] :: nl;
					else if(!blank(hd nl) && !startsblock(u))
						nl = u :: nl;
					else
						break;
					j++;
				}
				notedefs = (id, parse(toarr(rev(nl)))) :: notedefs;
				i = j;
				continue;
			}
		}
		if(t[0] == '['){
			(lab, url, title, ok) := refdef(t);
			if(ok){
				linkrefs = (fold(lab), url, title) :: linkrefs;
				i++;
				continue;
			}
		}
		if(tablestart(ls, i)){
			al := delimrow(ls[i+1]);
			hc := cells(trim(t), len al);
			rows: list of array of string;
			j := i+2;
			while(j < n && !blank(ls[j]) && contains(ls[j], "|")){
				rows = cells(trim(ls[j]), len al) :: rows;
				j++;
			}
			r: list of array of string;
			for(; rows != nil; rows = tl rows)
				r = hd rows :: r;
			cap := "";
			if(bl != nil){
				pick p := hd bl {
				Para =>
					(c, ok) := capline(p.text);
					if(ok){
						cap = c;
						bl = tl bl;
					}
				}
			}
			if(cap == ""){
				k := j;
				while(k < n && blank(ls[k]))
					k++;
				if(k < n){
					(c, ok) := capline(trim(ls[k]));
					if(ok){
						k++;
						while(k < n && !blank(ls[k]))
							c += " " + trim(ls[k++]);
						cap = c;
						j = k;
					}
				}
			}
			(cap2, cattr) := headattr(cap);
			bl = ref Block.Table(al, hc, r, cap2, cattr) :: bl;
			i = j;
			continue;
		}
		(mk, nil, nil, md) := marker(t);
		if(mk != ""){
			(lb, j) := listblock(ls, i, mk, md, t[0]);
			bl = lb :: bl;
			i = j;
			continue;
		}
		# a paragraph, or a heading underlined
		pl := ltrim(l) :: nil;
		j := i+1;
		level := 0;
		while(j < n){
			u := ls[j];
			if(blank(u))
				break;
			if(indent(u) < 4){
				s := trim(u);
				if(allof(s, '=')){
					level = 1;
					break;
				}
				if(allof(s, '-')){
					level = 2;
					break;
				}
			}
			if(interrupts(ls, j))
				break;
			pl = ltrim(u) :: pl;
			j++;
		}
		text := join(rev(pl), "\n");
		if(level > 0){
			(ht2, attr) := headattr(trim(text));
			bl = ref Block.Head(level, ht2, attr) :: bl;
			i = j+1;
		}else{
			bl = ref Block.Para(text) :: bl;
			i = j;
		}
	}
	return revb(bl);
}

allof(s: string, c: int): int
{
	if(s == "")
		return 0;
	for(i := 0; i < len s; i++)
		if(s[i] != c)
			return 0;
	return 1;
}

# ``` or ~~~: (the character, how many, the info string)
fence(t: string): (int, int, string)
{
	if(len t < 3 || t[0] != '`' && t[0] != '~')
		return (0, 0, "");
	c := t[0];
	n := 0;
	while(n < len t && t[n] == c)
		n++;
	if(n < 3)
		return (0, 0, "");
	info := t[n:];
	if(c == '`' && contains(info, "`"))
		return (0, 0, "");
	return (c, n, info);
}

closes(t: string, c, n: int): int
{
	k := 0;
	while(k < len t && t[k] == c)
		k++;
	return k >= n && blank(t[k:]);
}

# a fenced block's raw format: {=troff} or =troff
rawfmt(info: string): string
{
	if(str->prefix("{=", info) && suffix("}", info))
		info = info[2:len info-1];
	else if(str->prefix("=", info))
		info = info[1:];
	else
		return "";
	f := str->tolower(trim(info));
	case f {
	"troff" or "roff" or "groff" or "ms" or "man" or "nroff" =>
		return "troff";
	}
	return f;
}

atx(t: string): (int, string)
{
	n := 0;
	while(n < len t && t[n] == '#')
		n++;
	if(n == 0 || n > 6 || n < len t && t[n] != ' ')
		return (0, "");
	s := trim(t[n:]);
	# a closing run of #, after a space
	e := len s;
	while(e > 0 && s[e-1] == '#')
		e--;
	if(e < len s && (e == 0 || s[e-1] == ' '))
		s = trim(s[0:e]);
	return (n, s);
}

isrule(t: string): int
{
	t = trim(t);
	if(len t < 3)
		return 0;
	c := t[0];
	if(c != '-' && c != '*' && c != '_')
		return 0;
	k := 0;
	for(i := 0; i < len t; i++){
		if(t[i] == c)
			k++;
		else if(t[i] != ' ')
			return 0;
	}
	return k >= 3;
}

# a list item's marker: (kind, its number, the width to its text, its
# delimiter), or ("", ...) if t does not begin with one
marker(t: string): (string, int, int, int)
{
	if(t == "")
		return ("", 0, 0, 0);
	kind := "";
	num := 1;
	d := 0;
	w := 0;
	c := t[0];
	if(c == '-' || c == '*' || c == '+'){
		kind = "bullet";
		d = c;
		w = 1;
	}else if(isdigit(c)){
		while(w < len t && w < 9 && isdigit(t[w]))
			w++;
		if(w >= len t || t[w] != '.' && t[w] != ')')
			return ("", 0, 0, 0);
		num = int t[0:w];
		d = t[w];
		w++;
		kind = "1";
	}else if(c >= 'a' && c <= 'z'){
		while(w < len t && t[w] >= 'a' && t[w] <= 'z')
			w++;
		if(w >= len t || t[w] != '.' && t[w] != ')')
			return ("", 0, 0, 0);
		tok := t[0:w];
		if(w == 1 && c != 'i'){
			kind = "a";
			num = c - 'a' + 1;
		}else if(roman(tok) > 0){
			kind = "i";
			num = roman(tok);
		}else
			return ("", 0, 0, 0);
		d = t[w];
		w++;
	}else
		return ("", 0, 0, 0);
	if(w < len t && t[w] != ' ')
		return ("", 0, 0, 0);
	# a letter's or numeral's item needs text after it, so that "a." in
	# a line of prose is not taken for one
	if(kind == "a" || kind == "i"){
		if(w+1 >= len t || blank(t[w:]))
			return ("", 0, 0, 0);
	}
	k := 0;
	while(w + k < len t && t[w+k] == ' ')
		k++;
	if(w + k >= len t)
		return (kind, num, w + 1, d);
	if(k > 4)
		k = 1;
	return (kind, num, w + k, d);
}

roman(s: string): int
{
	v := 0;
	prev := 0;
	for(i := len s - 1; i >= 0; i--){
		x := 0;
		case s[i] {
		'i' =>	x = 1;
		'v' =>	x = 5;
		'x' =>	x = 10;
		'l' =>	x = 50;
		'c' =>	x = 100;
		* =>	return 0;
		}
		if(x < prev)
			v -= x;
		else{
			v += x;
			prev = x;
		}
	}
	return v;
}

# a list from line i: its items, and the line after it
listblock(ls: array of string, i: int, kind: string, delim, bullet: int): (ref Block, int)
{
	n := len ls;
	items: list of ref Item;
	tight := 1;
	start := -1;
	j := i;
	while(j < n){
		u := ls[j];
		iu := indent(u);
		if(iu >= 4 || blank(u))
			break;
		(k2, s2, w2, d2) := marker(u[iu:]);
		if(k2 == "")
			break;
		if(kind == "bullet"){
			if(k2 != "bullet" || u[iu] != bullet)
				break;
		}else if(kind == "1"){
			if(k2 != "1" || d2 != delim)
				break;
		}else if(d2 != delim)
			break;
		else if(kind == "a" && k2 == "i"){
			# a numeral of one letter goes on a list of letters, as its next
			if(s2 > 10 || u[iu+1] != delim || u[iu] != 'a' + len items + start0(start) - 1)
				break;
		}else if(k2 != kind)
			break;
		if(start < 0){
			start = s2;
			if(kind == "a" && k2 == "a")
				start = u[iu] - 'a' + 1;
		}
		off := iu + w2;
		first := "";
		if(off < len u)
			first = u[off:];
		il := first :: nil;
		j++;
		while(j < n){
			v := ls[j];
			if(blank(v)){
				il = "" :: il;
				j++;
				continue;
			}
			if(indent(v) >= off){
				il = v[off:] :: il;
				j++;
				continue;
			}
			if(hd il != "" && !startsblock(v) && !isitem(v, kind)){
				il = ltrim(v) :: il;
				j++;
				continue;
			}
			break;
		}
		nb := 0;
		while(il != nil && blank(hd il)){
			il = tl il;
			nb++;
		}
		ia := toarr(rev(il));
		if(innerblank(ia))
			tight = 0;
		if(nb > 0 && j < n && isitem(ls[j], kind))
			tight = 0;
		task := -1;
		if(len ia > 0){
			s := ia[0];
			if(str->prefix("[ ] ", s) || s == "[ ]"){
				task = 0;
				ia[0] = ltrim(s[3:]);
			}else if(str->prefix("[x] ", s) || str->prefix("[X] ", s) || s == "[x]" || s == "[X]"){
				task = 1;
				ia[0] = ltrim(s[3:]);
			}
		}
		items = ref Item(task, parse(ia)) :: items;
	}
	r: list of ref Item;
	for(; items != nil; items = tl items)
		r = hd items :: r;
	if(start < 0)
		start = 1;
	return (ref Block.List(kind, delim, start, tight, r), j);
}

start0(s: int): int
{
	if(s < 1)
		return 1;
	return s;
}

isitem(u, kind: string): int
{
	iu := indent(u);
	if(iu >= 4)
		return 0;
	(k, nil, nil, nil) := marker(u[iu:]);
	if(kind == "bullet")
		return k == "bullet";
	return k != "" && k != "bullet";
}

# a blank line between two of an item's lines, outside code
innerblank(a: array of string): int
{
	infence := 0;
	for(i := 1; i < len a - 1; i++){
		(fc, nil, nil) := fence(ltrim(a[i-1]));
		if(fc != 0)
			infence = !infence;
		if(!infence && blank(a[i]) && !blank(a[i-1]))
			return 1;
	}
	return 0;
}

# would line j begin a block, ending a paragraph?
interrupts(ls: array of string, j: int): int
{
	if(startsblock(ls[j]))
		return 1;
	return tablestart(ls, j);
}

startsblock(u: string): int
{
	iu := indent(u);
	if(iu >= 4)
		return 0;
	t := u[iu:];
	if(t == "")
		return 0;
	(hl, nil) := atx(t);
	if(hl > 0)
		return 1;
	(fc, nil, nil) := fence(t);
	if(fc != 0)
		return 1;
	if(t[0] == '>' || isrule(t) || str->prefix("$$", t) || str->prefix(":::", t))
		return 1;
	if(str->prefix("<!--", t) || htmlblock(t))
		return 1;
	(mk, num, mw, nil) := marker(t);
	if(mk == "bullet" && mw < len t && !blank(t[mw:]))
		return 1;
	if(mk == "1" && num == 1 && mw < len t && !blank(t[mw:]))
		return 1;
	return 0;
}

htmlblock(t: string): int
{
	if(len t < 2 || t[0] != '<')
		return 0;
	i := 1;
	if(t[i] == '/')
		i++;
	j := i;
	while(j < len t && isalnum(t[j]))
		j++;
	if(j == i)
		return 0;
	tag := str->tolower(t[i:j]);
	if(j < len t && t[j] != '>' && t[j] != ' ' && t[j] != '/')
		return 0;
	case tag {
	"address" or "article" or "aside" or "blockquote" or "details" or "dialog" or
	"div" or "dl" or "fieldset" or "figcaption" or "figure" or "footer" or "form" or
	"h1" or "h2" or "h3" or "h4" or "h5" or "h6" or "header" or "hr" or "li" or
	"main" or "nav" or "ol" or "p" or "pre" or "section" or "summary" or "table" or
	"ul" or "center" or "script" or "style" or "iframe" or "video" or "audio" or
	"picture" or "svg" or "canvas" or "noscript" or "dd" or "dt" or "tbody" or
	"thead" or "tr" or "td" or "th" or "caption" or "img" =>
		return 1;
	}
	return 0;
}

# [^id]: text
notedef(t: string): (string, string, int)
{
	for(i := 2; i < len t; i++){
		if(t[i] == ']')
			break;
		if(isspace(t[i]))
			return ("", "", 0);
	}
	if(i == 2 || i+1 >= len t || t[i+1] != ':')
		return ("", "", 0);
	return (t[2:i], ltrim(t[i+2:]), 1);
}

# [label]: url "title"
refdef(t: string): (string, string, string, int)
{
	if(len t < 2 || t[1] == '^' || t[1] == '@')
		return ("", "", "", 0);
	for(i := 1; i < len t && t[i] != ']'; i++)
		if(t[i] == '[')
			return ("", "", "", 0);
	if(i+1 >= len t || t[i+1] != ':')
		return ("", "", "", 0);
	lab := t[1:i];
	r := ltrim(t[i+2:]);
	if(r == "" || trim(lab) == "")
		return ("", "", "", 0);
	url := "";
	if(r[0] == '<'){
		(u, rest) := str->splitl(r[1:], ">");
		if(rest == "")
			return ("", "", "", 0);
		url = u;
		r = ltrim(rest[1:]);
	}else{
		(u, rest) := str->splitl(r, " ");
		url = u;
		r = ltrim(rest);
	}
	title := "";
	if(r != ""){
		c := r[0];
		e := c;
		if(c == '(')
			e = ')';
		if((c == '"' || c == '\'' || c == '(') && len r >= 2 && r[len r-1] == e)
			title = r[1:len r-1];
		else
			return ("", "", "", 0);
	}
	return (lab, url, title, 1);
}

tablestart(ls: array of string, i: int): int
{
	if(i+1 >= len ls || !contains(ls[i], "|") || indent(ls[i]) >= 4)
		return 0;
	al := delimrow(ls[i+1]);
	if(al == nil)
		return 0;
	return len cells(trim(ls[i]), 0) == len al;
}

# |:---|:--:|---:| as the columns' alignments, l c r
delimrow(s: string): array of int
{
	s = trim(s);
	if(!contains(s, "-") || !contains(s, "|") && !str->prefix("-", s) && !str->prefix(":", s))
		return nil;
	c := cells(s, 0);
	if(len c == 0)
		return nil;
	a := array[len c] of int;
	for(i := 0; i < len c; i++){
		x := trim(c[i]);
		if(x == "")
			return nil;
		l := x[0] == ':';
		r := x[len x-1] == ':';
		m := x;
		if(l)
			m = m[1:];
		if(r && len m > 0)
			m = m[0:len m-1];
		if(!allof(m, '-'))
			return nil;
		a[i] = 'l';
		if(l && r)
			a[i] = 'c';
		else if(r)
			a[i] = 'r';
	}
	return a;
}

# a table row's cells, as many as n (if n > 0), an escaped \| kept
cells(s: string, n: int): array of string
{
	if(str->prefix("|", s))
		s = s[1:];
	if(suffix("|", s) && !suffix("\\|", s))
		s = s[0:len s-1];
	l: list of string;
	c := "";
	code := 0;
	for(i := 0; i < len s; i++){
		if(s[i] == '\\' && i+1 < len s && s[i+1] == '|'){
			c[len c] = '|';
			i++;
			continue;
		}
		if(s[i] == '`')
			code = !code;
		if(s[i] == '|' && !code){
			l = trim(c) :: l;
			c = "";
			continue;
		}
		c[len c] = s[i];
	}
	l = trim(c) :: l;
	a := toarr(rev(l));
	if(n <= 0 || len a == n)
		return a;
	b := array[n] of {* => ""};
	for(i = 0; i < n && i < len a; i++)
		b[i] = a[i];
	return b;
}

capline(s: string): (string, int)
{
	s = trim(s);
	if(str->prefix("Table:", s))
		return (trim(s[6:]), 1);
	if(str->prefix(": ", s))
		return (trim(s[2:]), 1);
	return ("", 0);
}

# a heading's text and its {#id .class -} attributes
headattr(s: string): (string, ref Attr)
{
	s = trim(s);
	if(suffix("}", s)){
		for(i := len s - 1; i >= 0 && s[i] != '{'; i--)
			;
		if(i >= 0 && (i == 0 || s[i-1] == ' ')){
			a := parseattr(s[i:]);
			if(a != nil)
				return (trim(s[0:i]), a);
		}
	}
	return (s, ref Attr("", nil, nil));
}

# {#id .class key=value key="a value" -}
parseattr(s: string): ref Attr
{
	if(!str->prefix("{", s) || !suffix("}", s))
		return nil;
	s = s[1:len s-1];
	a := ref Attr("", nil, nil);
	i := 0;
	while(i < len s){
		while(i < len s && s[i] == ' ')
			i++;
		if(i >= len s)
			break;
		j := i;
		while(j < len s && s[j] != ' ' && s[j] != '='){
			j++;
		}
		w := s[i:j];
		if(j < len s && s[j] == '='){
			j++;
			v := "";
			if(j < len s && (s[j] == '"' || s[j] == '\'')){
				q := s[j++];
				k := j;
				while(j < len s && s[j] != q)
					j++;
				v = s[k:j];
				j++;
			}else{
				k := j;
				while(j < len s && s[j] != ' ')
					j++;
				v = s[k:j];
			}
			a.kv = (w, v) :: a.kv;
		}else if(str->prefix("#", w))
			a.id = w[1:];
		else if(str->prefix(".", w))
			a.classes = w[1:] :: a.classes;
		else if(w == "-")
			a.classes = "unnumbered" :: a.classes;
		else
			return nil;
		i = j;
	}
	return a;
}

# a div's attributes: {#id .class key=value} or a word
divattr(s: string): ref Attr
{
	if(str->prefix("{", s)){
		a := parseattr(s);
		if(a != nil)
			return a;
	}
	(w, nil) := str->splitl(s, " ");
	return ref Attr("", w :: nil, nil);
}

hasclass(a: ref Attr, c: string): int
{
	if(a == nil)
		return 0;
	for(l := a.classes; l != nil; l = tl l)
		if(hd l == c)
			return 1;
	return 0;
}

attrv(a: ref Attr, k: string): string
{
	if(a == nil)
		return "";
	for(l := a.kv; l != nil; l = tl l){
		(k2, v) := hd l;
		if(k2 == k)
			return v;
	}
	return "";
}

# a lone first heading is the title, if nothing else gives one
titlefrom(bl: list of ref Block): list of ref Block
{
	if(metav("title") != "" || bl == nil)
		return bl;
	h1 := 0;
	for(l := bl; l != nil; l = tl l)
		pick h := hd l {
		Head =>
			if(h.level == 1)
				h1++;
		}
	if(h1 != 1)
		return bl;
	pick h := hd bl {
	Head =>
		if(h.level != 1)
			return bl;
		metas = ("title", h.text) :: metas;
		shift = 1;
		return tl bl;
	}
	return bl;
}

minlevel(bl: list of ref Block, m: int): int
{
	for(; bl != nil; bl = tl bl)
		pick h := hd bl {
		Head =>
			if(h.level < m)
				m = h.level;
		Div =>
			m = minlevel(h.blocks, m);
		}
	return m;
}

haslevel(bl: list of ref Block, lv: int): int
{
	for(; bl != nil; bl = tl bl)
		pick h := hd bl {
		Head =>
			if(h.level == lv)
				return 1;
		Div =>
			if(haslevel(h.blocks, lv))
				return 1;
		}
	return 0;
}

# the labels a citation key may be: headings', tables', figures', divs'
findlabels(bl: list of ref Block)
{
	for(; bl != nil; bl = tl bl)
		pick b := hd bl {
		Head =>
			if(b.attr.id != "")
				labels = b.attr.id :: labels;
		Table =>
			if(b.attr.id != "")
				labels = b.attr.id :: labels;
		Para =>
			s := b.text;
			for(i := 0; i+2 < len s; i++)
				if(s[i] == '{' && s[i+1] == '#'){
					j := i+2;
					while(j < len s && s[j] != ' ' && s[j] != '}')
						j++;
					labels = s[i+2:j] :: labels;
				}
		Quote =>
			findlabels(b.blocks);
		Div =>
			if(b.attr.id != "")
				labels = b.attr.id :: labels;
			findlabels(b.blocks);
		List =>
			for(l := b.items; l != nil; l = tl l)
				findlabels((hd l).blocks);
		}
}

islabel(s: string): int
{
	for(l := labels; l != nil; l = tl l)
		if(hd l == s)
			return 1;
	return 0;
}

#
# the line: its elements
#

inlines(s: string): list of ref Inl
{
	toks: list of ref Tok;
	n := len s;
	txt := "";
	p := 0;
	while(p < n){
		c := s[p];
		special := 0;
		case c {
		'\\' or '`' or '<' or '!' or '^' or '[' or '*' or '_' or '~' or '$' or '&' or '\n' =>
			special = 1;
		'h' or 'w' =>
			special = (p == 0 || !isalnum(s[p-1])) && (str->prefix("http://", s[p:]) || str->prefix("https://", s[p:]) || str->prefix("www.", s[p:]));
		}
		if(!special){
			txt[len txt] = c;
			p++;
			continue;
		}
		# what a special character begins, if anything
		e: ref Inl;
		q := p + 1;
		case c {
		'\\' =>
			if(p+1 < n && s[p+1] == '\n'){
				e = ref Inl.Break(0);
				q = p+2;
			}else if(p+1 < n && ispunct(s[p+1])){
				e = ref Inl.Text(chr(s[p+1]), 1);
				q = p+2;
			}
		'`' =>
			k := p;
			while(k < n && s[k] == '`')
				k++;
			m := k - p;
			x := k;
			while(x < n){
				if(s[x] != '`'){
					x++;
					continue;
				}
				y := x;
				while(y < n && s[y] == '`')
					y++;
				if(y - x == m)
					break;
				x = y;
			}
			if(x < n){
				code := replace(s[k:x], "\n", " ");
				if(len code >= 2 && code[0] == ' ' && code[len code-1] == ' ' && !blank(code))
					code = code[1:len code-1];
				q = x + m;
				if(str->prefix("{=", s[q:])){
					(nil, r) := str->splitl(s[q:], "}");
					if(r != ""){
						f := str->tolower(s[q+2:q+len s[q:]-len r]);
						q += len s[q:] - len r + 1;
						if(f == "troff" || f == "ms" || f == "roff")
							e = ref Inl.Raw(code);
						else
							e = ref Inl.Text("", 1);
					}
				}
				if(e == nil)
					e = ref Inl.Code(code);
			}else{
				e = ref Inl.Text(s[p:k], 1);
				q = k;
			}
		'<' =>
			(x, k) := angle(s, p);
			if(x != nil){
				e = x;
				q = k;
			}
		'!' =>
			if(p+1 < n && s[p+1] == '['){
				(x, k) := link(s, p+1, 1);
				if(x != nil){
					e = x;
					q = k;
				}
			}
		'^' =>
			if(p+1 < n && s[p+1] == '['){
				k := closebr(s, p+1);
				if(k > 0){
					e = ref Inl.Note(ref Block.Para(s[p+2:k]) :: nil);
					q = k+1;
				}
			}else{
				k := p+1;
				while(k < n && s[k] != '^' && !isspace(s[k]))
					k++;
				if(k < n && s[k] == '^' && k > p+1){
					e = ref Inl.Sup(inlines(s[p+1:k]));
					q = k+1;
				}
			}
		'[' =>
			(x, k) := bracket(s, p);
			if(x != nil){
				e = x;
				q = k;
			}
		'*' or '_' or '~' =>
			k := p;
			while(k < n && s[k] == c)
				k++;
			m := k - p;
			if(c == '~' && m == 1){
				x := p+1;
				while(x < n && s[x] != '~' && !isspace(s[x]))
					x++;
				if(x < n && s[x] == '~' && x > p+1 && (x+1 >= n || s[x+1] != '~')){
					e = ref Inl.Sub(inlines(s[p+1:x]));
					q = x+1;
				}else{
					e = ref Inl.Text("~", 1);
					q = p+1;
				}
			}else{
				before := ' ';
				if(p > 0)
					before = s[p-1];
				after := ' ';
				if(k < n)
					after = s[k];
				lf := !isspace(after) && (!ispunct(after) || isspace(before) || ispunct(before));
				rf := !isspace(before) && (!ispunct(before) || isspace(after) || ispunct(after));
				op := lf;
				cl := rf;
				if(c == '_'){
					op = lf && (!rf || ispunct(before));
					cl = rf && (!lf || ispunct(after));
				}
				if(txt != ""){
					toks = ref Tok(ref Inl.Text(txt, 0), 0, 0, 0, 0, 0) :: toks;
					txt = "";
				}
				toks = ref Tok(nil, c, m, m, op, cl) :: toks;
				p = k;
				continue;
			}
		'$' =>
			if(p+1 < n && !isspace(s[p+1]) && s[p+1] != '$'){
				k := p+1;
				while(k < n && !(s[k] == '$' && !isspace(s[k-1]) && s[k-1] != '\\'))
					k++;
				if(k < n && (k+1 >= n || !isdigit(s[k+1]))){
					e = ref Inl.Math(replace(s[p+1:k], "\n", " "));
					q = k+1;
				}
			}
		'&' =>
			(x, k) := entity(s, p);
			if(x != ""){
				e = ref Inl.Text(x, 1);
				q = k;
			}
		'\n' =>
			# two spaces before it, a hard break
			if(suffix("  ", txt)){
				txt = rtrimsp(txt);
				e = ref Inl.Break(0);
			}else{
				txt = rtrimsp(txt);
				e = ref Inl.Soft(0);
			}
			while(q < n && s[q] == ' ')
				q++;
		'h' or 'w' =>
			k := p;
			while(k < n && !isspace(s[k]) && s[k] != '<')
				k++;
			# not the punctuation after it
			while(k > p && str->in(s[k-1], "?!.,:*_~'\";"))
				k--;
			if(k > p && s[k-1] == ')' && count(s[p:k], '(') < count(s[p:k], ')'))
				k--;
			u := s[p:k];
			href := u;
			if(str->prefix("www.", u))
				href = "http://" + u;
			e = ref Inl.Link(href, "", ref Inl.Text(u, 1) :: nil, 1);
			q = k;
		}
		if(e == nil){
			txt[len txt] = c;
			p++;
			continue;
		}
		if(txt != ""){
			toks = ref Tok(ref Inl.Text(txt, 0), 0, 0, 0, 0, 0) :: toks;
			txt = "";
		}
		toks = ref Tok(e, 0, 0, 0, 0, 0) :: toks;
		p = q;
	}
	if(txt != "")
		toks = ref Tok(ref Inl.Text(txt, 0), 0, 0, 0, 0, 0) :: toks;
	a := array[len toks] of ref Tok;
	for(i := len a - 1; toks != nil; toks = tl toks)
		a[i--] = hd toks;
	return flat(emphasis(a));
}

rtrimsp(s: string): string
{
	j := len s;
	while(j > 0 && s[j-1] == ' ')
		j--;
	return s[0:j];
}

count(s: string, c: int): int
{
	k := 0;
	for(i := 0; i < len s; i++)
		if(s[i] == c)
			k++;
	return k;
}

# CommonMark's delimiter runs, matched into emphasis
emphasis(a: array of ref Tok): array of ref Tok
{
	c := 0;
	for(;;){
		while(c < len a && (a[c].inl != nil || !a[c].closer || a[c].n == 0))
			c++;
		if(c >= len a)
			break;
		cl := a[c];
		o := c - 1;
		for(; o >= 0; o--){
			op := a[o];
			if(op.inl != nil || op.dc != cl.dc || !op.opener || op.n == 0)
				continue;
			if(cl.dc == '~'){
				if(op.n >= 2 && cl.n >= 2)
					break;
				continue;
			}
			if((op.closer || cl.opener) && (op.orig + cl.orig) % 3 == 0 && (op.orig % 3 != 0 || cl.orig % 3 != 0))
				continue;
			break;
		}
		if(o < 0){
			if(!cl.opener)
				cl.closer = 0;
			c++;
			continue;
		}
		op := a[o];
		use := 1;
		if(op.n >= 2 && cl.n >= 2)
			use = 2;
		kids := flat(a[o+1:c]);
		e: ref Inl;
		if(cl.dc == '~')
			e = ref Inl.Strike(kids);
		else if(use == 2)
			e = ref Inl.Strong(kids);
		else
			e = ref Inl.Em(kids);
		op.n -= use;
		cl.n -= use;
		b := array[o + 2 + len a - c] of ref Tok;
		b[0:] = a[0:o+1];
		b[o+1] = ref Tok(e, 0, 0, 0, 0, 0);
		b[o+2:] = a[c:];
		a = b;
		c = o + 2;
	}
	return a;
}

flat(a: array of ref Tok): list of ref Inl
{
	r: list of ref Inl;
	for(i := 0; i < len a; i++){
		t := a[i];
		if(t.inl != nil)
			r = t.inl :: r;
		else if(t.n > 0){
			s := "";
			for(k := 0; k < t.n; k++)
				s[len s] = t.dc;
			r = ref Inl.Text(s, 1) :: r;
		}
	}
	return revi(r);
}

# the ] that closes the [ at s[p], or -1: brackets nested, escapes
# and code passed over
closebr(s: string, p: int): int
{
	d := 0;
	for(i := p; i < len s; i++){
		case s[i] {
		'\\' =>
			i++;
		'`' =>
			k := i;
			while(k < len s && s[k] == '`')
				k++;
			m := k - i;
			x := k;
			while(x < len s){
				if(s[x] != '`'){
					x++;
					continue;
				}
				y := x;
				while(y < len s && s[y] == '`')
					y++;
				if(y - x == m)
					break;
				x = y;
			}
			if(x < len s)
				i = x + m - 1;
			else
				i = k - 1;
		'[' =>
			d++;
		']' =>
			if(--d == 0)
				return i;
		}
	}
	return -1;
}

# what a [ begins: a note's mark, a citation, a link, or nothing
bracket(s: string, p: int): (ref Inl, int)
{
	k := closebr(s, p);
	if(k < 0)
		return (nil, 0);
	in := s[p+1:k];
	if(str->prefix("^", in) && !contains(in, " ")){
		id := in[1:];
		for(l := notedefs; l != nil; l = tl l){
			(id2, bl) := hd l;
			if(id2 == id)
				return (ref Inl.Note(bl), k+1);
		}
		warn1("note " + id, "[^" + id + "]: no such note");
		return (nil, 0);
	}
	if(k+1 >= len s || s[k+1] != '(' && s[k+1] != '['){
		items := citation(in);
		if(items != nil)
			return (ref Inl.Cite(items), k+1);
	}
	return link(s, p, 0);
}

# [@key, place; see @key2 p. 4] as (key, place) pairs, or nil
citation(in: string): list of (string, string)
{
	if(!contains(in, "@"))
		return nil;
	(nil, parts) := sys->tokenize(in, ";");
	r: list of (string, string);
	for(; parts != nil; parts = tl parts){
		x := trim(hd parts);
		(pre, rest) := str->splitl(x, "@");
		if(rest == "")
			return nil;
		pre = trim(pre);
		if(pre == "-")
			pre = "";
		if(pre != "")
			warn1("prefix", "a citation's prefix (\"" + pre + "\") is not set: .cite has none; put it in the text");
		rest = rest[1:];
		i := 0;
		while(i < len rest && (isalnum(rest[i]) || str->in(rest[i], "-_:.#$%&+?<>~/")))
			i++;
		while(i > 0 && str->in(rest[i-1], ".:"))
			i--;
		key := rest[0:i];
		if(key == "")
			return nil;
		place := trim(rest[i:]);
		if(str->prefix(",", place))
			place = trim(place[1:]);
		r = (key, place) :: r;
	}
	rr: list of (string, string);
	for(; r != nil; r = tl r)
		rr = hd r :: rr;
	return rr;
}

# a link or image whose [ is at s[p]: [text](url "title"), [text][ref],
# [text][], [text]
link(s: string, p: int, image: int): (ref Inl, int)
{
	k := closebr(s, p);
	if(k < 0)
		return (nil, 0);
	text := s[p+1:k];
	url := "";
	title := "";
	q := k+1;
	found := 0;
	if(q < len s && s[q] == '('){
		(u, t, e, ok) := dest(s, q);
		if(ok){
			url = u;
			title = t;
			q = e;
			found = 1;
		}
	}
	if(!found && q < len s && s[q] == '['){
		e := closebr(s, q);
		if(e > 0){
			lab := s[q+1:e];
			if(trim(lab) == "")
				lab = text;
			(u, t, ok) := lookref(lab);
			if(ok){
				url = u;
				title = t;
				q = e+1;
				found = 1;
			}
		}
	}
	if(!found){
		(u, t, ok) := lookref(text);
		if(!ok)
			return (nil, 0);
		url = u;
		title = t;
	}
	attr := ref Attr("", nil, nil);
	if(q < len s && s[q] == '{'){
		(nil, r) := str->splitl(s[q:], "}");
		if(r != ""){
			e := q + len s[q:] - len r + 1;
			a := parseattr(s[q:e]);
			if(a != nil){
				attr = a;
				q = e;
			}
		}
	}
	kids := inlines(text);
	if(image)
		return (ref Inl.Image(url, title, kids, attr), q);
	return (ref Inl.Link(url, title, kids, 0), q);
}

lookref(lab: string): (string, string, int)
{
	f := fold(lab);
	for(l := linkrefs; l != nil; l = tl l){
		(f2, u, t) := hd l;
		if(f2 == f)
			return (u, t, 1);
	}
	return ("", "", 0);
}

# (url "title") at s[q]
dest(s: string, q: int): (string, string, int, int)
{
	i := q+1;
	n := len s;
	while(i < n && isspace(s[i]))
		i++;
	url := "";
	if(i < n && s[i] == '<'){
		j := i+1;
		while(j < n && s[j] != '>' && s[j] != '\n')
			j++;
		if(j >= n || s[j] != '>')
			return ("", "", 0, 0);
		url = s[i+1:j];
		i = j+1;
	}else{
		d := 0;
		j := i;
		while(j < n && !isspace(s[j])){
			if(s[j] == '\\' && j+1 < n){
				j += 2;
				continue;
			}
			if(s[j] == '(')
				d++;
			else if(s[j] == ')'){
				if(d == 0)
					break;
				d--;
			}
			j++;
		}
		url = s[i:j];
		i = j;
	}
	while(i < n && isspace(s[i]))
		i++;
	title := "";
	if(i < n && (s[i] == '"' || s[i] == '\'' || s[i] == '(')){
		e := s[i];
		if(e == '(')
			e = ')';
		j := i+1;
		while(j < n && s[j] != e){
			if(s[j] == '\\')
				j++;
			j++;
		}
		if(j >= n)
			return ("", "", 0, 0);
		title = s[i+1:j];
		i = j+1;
		while(i < n && isspace(s[i]))
			i++;
	}
	if(i >= n || s[i] != ')')
		return ("", "", 0, 0);
	return (url, title, i+1, 1);
}

# <...> at s[p]: an address, an e-mail address, HTML (a <br> a break,
# other tags not set), or nothing
angle(s: string, p: int): (ref Inl, int)
{
	n := len s;
	if(str->prefix("<!--", s[p:])){
		for(k := p+4; k+3 <= n; k++)
			if(s[k:k+3] == "-->")
				return (ref Inl.Text("", 1), k+3);
		return (nil, 0);
	}
	j := p+1;
	while(j < n && s[j] != '>' && s[j] != '<' && s[j] != ' ' && s[j] != '\n')
		j++;
	if(j < n && s[j] == '>' && j > p+1){
		u := s[p+1:j];
		(sch, r) := str->splitl(u, ":");
		if(r != "" && len sch >= 2 && isalpha(sch[0]))
			return (ref Inl.Link(u, "", ref Inl.Text(u, 1) :: nil, 1), j+1);
		if(contains(u, "@") && !contains(u, "/"))
			return (ref Inl.Link("mailto:" + u, "", ref Inl.Text(u, 1) :: nil, 1), j+1);
	}
	# a tag: <name ...>, </name>
	i := p+1;
	if(i < n && s[i] == '/')
		i++;
	if(i >= n || !isalpha(s[i]))
		return (nil, 0);
	k := i;
	while(k < n && (isalnum(s[k]) || s[k] == '-'))
		k++;
	name := str->tolower(s[i:k]);
	while(k < n && s[k] != '>' && s[k] != '<')
		k++;
	if(k >= n || s[k] != '>')
		return (nil, 0);
	if(name == "br")
		return (ref Inl.Break(0), k+1);
	warn1("htmltag", "HTML tags (<" + name + ">) are not set; the text between them is");
	return (ref Inl.Text("", 1), k+1);
}

entity(s: string, p: int): (string, int)
{
	n := len s;
	k := p+1;
	while(k < n && k < p+32 && s[k] != ';' && !isspace(s[k]))
		k++;
	if(k >= n || s[k] != ';' || k == p+1)
		return ("", 0);
	name := s[p+1:k];
	if(name[0] == '#'){
		v := 0;
		if(len name > 1 && (name[1] == 'x' || name[1] == 'X'))
			(v, nil) = str->toint(name[2:], 16);
		else
			(v, nil) = str->toint(name[1:], 10);
		if(v <= 0 || v > 16rFFFF)
			return ("", 0);
		return (chr(v), k+1);
	}
	c := 0;
	case name {
	"amp" =>	c = '&';
	"lt" =>	c = '<';
	"gt" =>	c = '>';
	"quot" =>	c = '"';
	"apos" =>	c = '\'';
	"nbsp" =>	c = 16rA0;
	"ensp" =>	c = 16r2002;
	"emsp" =>	c = 16r2003;
	"thinsp" =>	c = 16r2009;
	"shy" =>	c = 16rAD;
	"ndash" =>	c = 16r2013;
	"mdash" =>	c = 16r2014;
	"hellip" =>	c = 16r2026;
	"lsquo" =>	c = 16r2018;
	"rsquo" =>	c = 16r2019;
	"sbquo" =>	c = 16r201A;
	"ldquo" =>	c = 16r201C;
	"rdquo" =>	c = 16r201D;
	"bdquo" =>	c = 16r201E;
	"laquo" =>	c = 16rAB;
	"raquo" =>	c = 16rBB;
	"lsaquo" =>	c = 16r2039;
	"rsaquo" =>	c = 16r203A;
	"copy" =>	c = 16rA9;
	"reg" =>	c = 16rAE;
	"trade" =>	c = 16r2122;
	"deg" =>	c = 16rB0;
	"plusmn" =>	c = 16rB1;
	"times" =>	c = 16rD7;
	"divide" =>	c = 16rF7;
	"minus" =>	c = 16r2212;
	"sect" =>	c = 16rA7;
	"para" =>	c = 16rB6;
	"middot" =>	c = 16rB7;
	"bull" =>	c = 16r2022;
	"dagger" =>	c = 16r2020;
	"Dagger" =>	c = 16r2021;
	"permil" =>	c = 16r2030;
	"prime" =>	c = 16r2032;
	"Prime" =>	c = 16r2033;
	"frac12" =>	c = 16rBD;
	"frac14" =>	c = 16rBC;
	"frac34" =>	c = 16rBE;
	"pound" =>	c = 16rA3;
	"euro" =>	c = 16r20AC;
	"yen" =>	c = 16rA5;
	"cent" =>	c = 16rA2;
	"larr" =>	c = 16r2190;
	"rarr" =>	c = 16r2192;
	"uarr" =>	c = 16r2191;
	"darr" =>	c = 16r2193;
	"harr" =>	c = 16r2194;
	"eacute" =>	c = 16rE9;
	"egrave" =>	c = 16rE8;
	"aacute" =>	c = 16rE1;
	"agrave" =>	c = 16rE0;
	"ouml" =>	c = 16rF6;
	"uuml" =>	c = 16rFC;
	"auml" =>	c = 16rE4;
	"szlig" =>	c = 16rDF;
	"ccedil" =>	c = 16rE7;
	"ntilde" =>	c = 16rF1;
	* =>
		return ("", 0);
	}
	return (chr(c), k+1);
}

#
# output
#

put(x: ref Ctx, s: string)
{
	if(x != nil && x.arg){
		x.buf += replace(s, chr(SP), " ");
		return;
	}
	cur += s;
}

# the line filled so far, out, in lines no longer than WIDTH
flush()
{
	if(cur == "")
		return;
	line := "";
	w := "";
	for(i := 0; i <= len cur; i++){
		if(i < len cur && cur[i] != SP){
			w[len w] = cur[i];
			continue;
		}
		if(w == "")
			continue;
		if(line == "")
			line = w;
		else if(len line + 1 + len w > WIDTH){
			emit(line);
			line = w;
		}else
			line += " " + w;
		w = "";
	}
	if(line != "")
		emit(line);
	cur = "";
}

emit(line: string)
{
	if(line != "" && (line[0] == '.' || line[0] == '\''))
		line = "\\&" + line;
	out = line :: out;
}

# a request, on a line of its own
req(s: string)
{
	flush();
	(nil, l) := sys->tokenize(s, "\n");
	for(; l != nil; l = tl l)
		out = hd l :: out;
}

# a line as written: troff's own
raw(s: string)
{
	flush();
	out = s :: out;
}

# a macro's argument, quoted
argq(s: string): string
{
	s = replace(s, "\"", "\\(dq");
	s = replace(s, "\n", " ");
	return "\"" + s + "\"";
}

newctx(base: string, arg: int): ref Ctx
{
	return ref Ctx(base, 0, 0, 0, base, arg, "", 0);
}

fontof(x: ref Ctx): string
{
	if(x.code)
		return "CR";
	b := contains(x.base, "B");
	i := contains(x.base, "I");
	if(x.strong)
		b = 1;
	if(x.em % 2)
		i = !i;
	if(b && i)
		return "BI";
	if(b)
		return "B";
	if(i)
		return "I";
	return "R";
}

setfont(x: ref Ctx)
{
	f := fontof(x);
	if(f != x.font){
		put(x, "\\f[" + f + "]");
		x.font = f;
		x.changed = 1;
	}
}

# the context's font its own again: a macro that sets its argument in
# a font and then \fP finds the roman before it
endfont(x: ref Ctx)
{
	x.em = x.strong = x.code = 0;
	setfont(x);
	if(x.arg && x.changed && x.base != "R")
		put(x, "\\f[R]\\f[" + x.base + "]");
}

# inline elements set as a macro's argument, in font base
argtext(l: list of ref Inl, base: string): string
{
	x := newctx(base, 1);
	l0 := lastc;
	s0 := sopen;
	lastc = 0;
	sopen = 0;
	elems(x, l);
	endfont(x);
	lastc = l0;
	sopen = s0;
	return trim(x.buf);
}

argmd(s, base: string): string
{
	return argtext(inlines(s), base);
}

# the text of elements, without fonts or marks: for .alt
plain(l: list of ref Inl): string
{
	s := "";
	for(; l != nil; l = tl l)
		pick e := hd l {
		Text =>
			s += e.s;
		Code =>
			s += e.s;
		Math =>
			s += e.s;
		Em =>
			s += plain(e.kids);
		Strong =>
			s += plain(e.kids);
		Strike =>
			s += plain(e.kids);
		Sup =>
			s += plain(e.kids);
		Sub =>
			s += plain(e.kids);
		Link =>
			s += plain(e.kids);
		Image =>
			s += plain(e.kids);
		Soft or Break =>
			s += " ";
		}
	return s;
}

esc(c: int): string
{
	case c {
	'\\' =>
		return "\\e";
	'$' =>
		return "\\(Do";
	' ' or '\n' =>
		return chr(SP);
	}
	return chr(c);
}

opens(c: int): int
{
	return c == 0 || isspace(c) || c == SP || str->in(c, "([{/-") || c == 16r2013 || c == 16r2014 || c == 16r2018 || c == 16r201C;
}

# text, with its typography
text(x: ref Ctx, s: string, lit: int)
{
	n := len s;
	for(i := 0; i < n; i++){
		c := s[i];
		if(lit){
			put(x, esc(c));
			lastc = c;
			continue;
		}
		next := ' ';
		if(i+1 < n)
			next = s[i+1];
		r := "";
		case c {
		'"' =>
			if(qstyle == "none")
				r = "\\(dq";
			else if(opens(lastc)){
				r = qmark(1, 1);
			}else
				r = qmark(1, 0);
		'\'' =>
			if(qstyle == "none")
				r = "'";
			else if(i+2 < n && isalpha(next) && s[i+2] == '\'' && (i+3 >= n || !isalnum(s[i+3]))){
				# a letter between two: rock 'n' roll, apostrophes both
				r = chr(16r2019) + chr(next) + chr(16r2019);
				i += 2;
			}else if(opens(lastc) && !isspace(next) && !isdigit(next)){
				r = qmark(2, 1);
				sopen++;
			}else if(sopen > 0 && !isalnum(next)){
				r = qmark(2, 0);
				sopen--;
			}else
				r = chr(16r2019);
		'-' =>
			if(i+2 < n && s[i+1] == '-' && s[i+2] == '-'){
				r = chr(16r2014);
				i += 2;
			}else if(i+1 < n && s[i+1] == '-'){
				r = chr(16r2013);
				i++;
			}else
				r = "-";
		'.' =>
			if(i+2 < n && s[i+1] == '.' && s[i+2] == '.'){
				r = chr(16r2026);
				i += 2;
			}else
				r = ".";
		* =>
			r = esc(c);
		}
		put(x, r);
		if(r == chr(SP))
			lastc = ' ';
		else
			lastc = r[len r - 1];
	}
}

# a quotation mark: the first (1) or second (2), opening or closing
qmark(which, open: int): string
{
	if(qguess)
		warn1("quotes", "nothing says how to set quotation marks (quotes: or lang: in the front matter, or curly ones in the text): straight quotes set as British, ‘ ’ and “ ”; quotes: us sets them as American");
	gb := qstyle == "gb";
	if(which == 1 && gb || which == 2 && !gb){
		if(open)
			return chr(16r2018);
		return chr(16r2019);
	}
	if(open)
		return chr(16r201C);
	return chr(16r201D);
}

# the punctuation at the head of the next element, if it is text: to be
# set before a note's mark, or after a link
leadpunct(l: list of ref Inl): (string, list of ref Inl)
{
	if(l == nil)
		return ("", l);
	pick t := hd l {
	Text =>
		if(t.lit)
			return ("", l);
		i := 0;
		while(i < len t.s && str->in(t.s[i], ".,;:!?)\"'") || i < len t.s && (t.s[i] == 16r2019 || t.s[i] == 16r201D))
			i++;
		if(i == 0)
			return ("", l);
		rest := tl l;
		if(i < len t.s)
			rest = ref Inl.Text(t.s[i:], 0) :: rest;
		return (t.s[0:i], rest);
	}
	return ("", l);
}

elems(x: ref Ctx, l: list of ref Inl)
{
	while(l != nil){
		e := hd l;
		l = tl l;
		pick y := e {
		Text =>
			if(y.s != ""){
				setfont(x);
				text(x, y.s, y.lit);
			}
		Code =>
			x.code++;
			setfont(x);
			for(i := 0; i < len y.s; i++){
				c := y.s[i];
				if(c == ' ')
					put(x, chr(SP));
				else
					put(x, esc(c));
				lastc = c;
			}
			x.code--;
		Em =>
			x.em++;
			elems(x, y.kids);
			x.em--;
		Strong =>
			x.strong++;
			elems(x, y.kids);
			x.strong--;
		Strike =>
			setfont(x);
			(nil, words) := sys->tokenize(argtext(y.kids, fontof(x)), " ");
			for(first := 1; words != nil; words = tl words){
				w := hd words;
				if(!first)
					put(x, chr(SP));
				first = 0;
				put(x, "\\Z^" + w + "^\\v'-0.28m'\\D'l \\w^" + w + "^u 0'\\v'0.28m'");
			}
			lastc = 'x';
		Sup =>
			setfont(x);
			put(x, "\\v'-0.35m'\\s[-2]" + argtext(y.kids, fontof(x)) + "\\s[+2]\\v'0.35m'");
			x.font = "";
			lastc = 'x';
		Sub =>
			setfont(x);
			put(x, "\\v'0.25m'\\s[-2]" + argtext(y.kids, fontof(x)) + "\\s[+2]\\v'-0.25m'");
			x.font = "";
			lastc = 'x';
		Math =>
			mathused = 1;
			c := "$" + y.s + "$";
			put(x, c);
			lastc = 'x';
		Raw =>
			put(x, y.s);
		Soft =>
			put(x, chr(SP));
			lastc = ' ';
		Break =>
			if(x.arg)
				put(x, " ");
			else
				req(".br");
			lastc = ' ';
		Link =>
			if(str->prefix("#", y.url)){
				id := y.url[1:];
				if(y.kids == nil && islabel(id))
					put(x, "\\*[ref " + id + "]");
				else
					elems(x, y.kids);
				continue;
			}
			if(x.arg){
				elems(x, y.kids);
				continue;
			}
			(p, rest) := leadpunct(l);
			l = rest;
			setfont(x);
			t := argtext(y.kids, x.font);
			after := "";
			if(p != ""){
				z := newctx(x.font, 1);
				text(z, p, 0);
				after = z.buf;
			}
			joinprev();
			s := "";
			if(y.auto || t == y.url)
				s = ".url " + argq(y.url);
			else
				s = ".link " + argq(y.url) + " " + argq(t);
			if(after != "")
				s += " " + argq(after);
			req(s);
			lastc = 'x';
		Image =>
			figq = e :: figq;
		Note =>
			if(x.arg){
				warn1("noteinarg", "a note in a heading, caption or link is not set");
				continue;
			}
			(p, rest) := leadpunct(l);
			l = rest;
			cur = rtrimsp2(cur);
			if(p != "")
				text(x, p, 0);
			if(cur != ""){
				cur += "\\c";
				flush();
			}
			if(endnotes)
				req(".en");
			else
				req(".fn");
			l0 := lastc;
			s0 := sopen;
			q0 := figq;
			lastc = 0;
			sopen = 0;
			blocks(y.blocks, 1);
			lastc = l0;
			sopen = s0;
			figq = q0;
			if(endnotes)
				req(".ee");
			else
				req(".fe");
		Cite =>
			refs := 1;
			first := 1;
			c: list of (string, string);
			for(c = y.items; c != nil; c = tl c){
				(k, nil) := hd c;
				if(!islabel(k))
					refs = 0;
			}
			if(refs){
				for(c = y.items; c != nil; c = tl c){
					(k, nil) := hd c;
					if(!first){
						if(tl c == nil)
							put(x, chr(SP) + "and" + chr(SP));
						else
							put(x, "," + chr(SP));
					}
					first = 0;
					put(x, "\\*[ref " + k + "]");
				}
				lastc = 'x';
				continue;
			}
			if(x.arg){
				warn1("citeinarg", "a citation in a heading, caption or link is not set");
				continue;
			}
			(p, rest) := leadpunct(l);
			l = rest;
			cur = rtrimsp2(cur);
			if(p != "")
				text(x, p, 0);
			s := ".cite";
			first = 1;
			for(c = y.items; c != nil; c = tl c){
				(k, place) := hd c;
				if(!first)
					s += " ;";
				first = 0;
				s += " " + k;
				if(place != "")
					s += " " + replace(place, "\n", " ");
			}
			req(s);
			citesused = 1;
			lastc = 'x';
		}
	}
}

# the text before an element that is a request (a link) joined to it,
# unless a space is between them
joinprev()
{
	if(cur == "")
		return;
	if(cur[len cur - 1] == SP){
		cur = rtrimsp2(cur);
		flush();
		return;
	}
	cur += "\\c";
	flush();
}

rtrimsp2(s: string): string
{
	j := len s;
	while(j > 0 && (s[j-1] == SP || s[j-1] == ' '))
		j--;
	return s[0:j];
}

#
# blocks, set
#

blocks(bl: list of ref Block, first: int)
{
	for(; bl != nil; bl = tl bl){
		b := hd bl;
		pick y := b {
		Para =>
			l := inlines(y.text);
			if(isfigure(l)){
				pick im := hd figonly(l) {
				Image =>
					figure(im);
				}
				first = 0;
				continue;
			}
			if(!first)
				req(".p");
			first = 0;
			para(l);
		Head =>
			heading(y);
			first = 0;
		Code =>
			if(y.lines == nil)
				continue;
			req(".code");
			for(c := y.lines; c != nil; c = tl c){
				s := "";
				for(i := 0; i < len hd c; i++){
					ch := (hd c)[i];
					case ch {
					'\\' =>	s += "\\e";
					'$' =>	s += "\\(Do";
					* =>	s[len s] = ch;
					}
				}
				if(s == "")
					s = "\\&";
				else if(s[0] == '.' || s[0] == '\'')
					s = "\\&" + s;
				raw(s);
			}
			req(".endcode");
			first = 0;
		Raw =>
			if(y.fmt == "troff"){
				for(c := y.lines; c != nil; c = tl c){
					if(str->prefix(".bibliography", hd c))
						bibset = 1;
					raw(hd c);
				}
			}
		Math =>
			req(".EQ");
			for(c := y.lines; c != nil; c = tl c){
				s := hd c;
				if(s[0] == '.' || s[0] == '\'')
					s = "\\&" + s;
				raw(s);
			}
			req(".EN");
			first = 0;
		Quote =>
			req(".quote");
			blocks(y.blocks, 1);
			req(".endquote");
			first = 0;
		List =>
			listout(y);
			first = 0;
		Rule =>
			if(macros == "slides")
				req(".slide");
			else{
				req(".p");
				req(".ce");
				raw("*\\ \\ \\ *\\ \\ \\ *");
			}
			first = 0;
		Pause =>
			if(macros == "slides")
				req(".pause");
		Table =>
			table(y);
			first = 0;
		Div =>
			div(y);
			first = 0;
		}
	}
}

para(l: list of ref Inl)
{
	figq = nil;
	sopen = 0;
	lastc = 0;
	x := newctx("R", 0);
	elems(x, l);
	endfont(x);
	flush();
	if(figq != nil){
		q := figq;
		figq = nil;
		r: list of ref Inl;
		for(; q != nil; q = tl q)
			r = hd q :: r;
		for(; r != nil; r = tl r)
			pick im := hd r {
			Image =>
				warn1("inlineimage", "an image in a line is set as a figure after its paragraph");
				figure(im);
			}
	}
}

# an image alone in its paragraph
figonly(l: list of ref Inl): list of ref Inl
{
	r: list of ref Inl;
	for(; l != nil; l = tl l){
		pick t := hd l {
		Text =>
			if(blank(t.s))
				continue;
		Soft =>
			continue;
		}
		r = hd l :: r;
	}
	return r;
}

isfigure(l: list of ref Inl): int
{
	r := figonly(l);
	if(r == nil || tl r != nil)
		return 0;
	pick im := hd r {
	Image =>
		return 1;
	}
	return 0;
}

figure(im: ref Inl.Image)
{
	s := ".figure";
	if(im.attr.id != "")
		s += " " + im.attr.id;
	req(s);
	desc := im.title;
	if(desc == "")
		desc = trim(plain(im.kids));
	if(desc != "")
		req(".alt " + argq(desc));
	else
		warn("image " + im.url + " has no description: its PDF will not claim PDF/UA");
	s = ".image " + argq(im.url);
	w := size(attrv(im.attr, "width"));
	h := size(attrv(im.attr, "height"));
	if(w != "" || h != ""){
		if(w == "")
			w = "\"\"";
		s += " " + w;
		if(h != "")
			s += " " + h;
	}
	req(s);
	cap := argtext(im.kids, "R");
	if(cap != "")
		req(".caption " + argq(cap));
	req(".endfigure");
}

# a width or height: 50% of the measure, or troff's own (3i, 6c, 200p;
# a number alone, pixels at 96 to the inch)
size(v: string): string
{
	v = trim(v);
	if(v == "")
		return "";
	if(suffix("%", v))
		return "(\\n[.l]u-\\n[.i]u)*" + v[0:len v-1] + "/100";
	if(suffix("px", v))
		return v[0:len v-2] + "i/96";
	if(suffix("in", v))
		return v[0:len v-2] + "i";
	if(suffix("cm", v))
		return v[0:len v-2] + "c";
	if(suffix("mm", v))
		return v[0:len v-2] + "c/10";
	if(suffix("pt", v))
		return v[0:len v-2] + "p";
	if(allof(v, '0') || isdigit(v[len v-1]))
		return v + "i/96";
	return v;
}

heading(h: ref Block.Head)
{
	lv := h.level - shift;
	if(lv < 1)
		lv = 1;
	unnum := !numbered || hasclass(h.attr, "unnumbered") || hasclass(h.attr, "unlisted");
	if(hasclass(h.attr, "appendix"))
		req(".appendix");
	name := "";
	base := "B";
	case macros {
	"article" or "memo" =>
		case lv {
		1 =>	name = "section";
		2 =>	name = "subsection"; base = "I";
		* =>	name = "subsubsection"; base = "BI";
		}
	"slides" =>
		if(slidelevel == 2){
			case lv {
			1 =>	name = "section";
			2 =>	name = "slide";
			}
		}else if(lv == 1)
			name = "slide";
		unnum = 0;
	* =>
		case lv {
		1 =>	name = "chapter"; base = "R";
		2 =>	name = "section";
		3 =>	name = "subsection"; base = "I";
		* =>	name = "subsubsection"; base = "BI";
		}
	}
	if(name == ""){
		# below a talk's slides: a paragraph in bold
		req(".p");
		cur += "\\f[B]" + argmd(h.text, "B") + "\\f[R]";
		flush();
		return;
	}
	t := argmd(h.text, base);
	if(unnum && name != "subsubsection" && name != "slide")
		name += "*";
	s := "." + name + " " + argq(t);
	if(h.attr.id != "" && name != "chapter*")
		s += " " + h.attr.id;
	req(s);
}

listout(l: ref Block.List)
{
	kind := l.kind;
	given := l.start != 1 || l.delim == ')' && kind == "1" || l.delim == '.' && kind == "a";
	req(".list " + kind);
	k := l.start;
	for(it := l.items; it != nil; it = tl it){
		item := hd it;
		mark := "";
		if(item.task == 0)
			mark = chr(16r2610);
		else if(item.task == 1)
			mark = chr(16r2612);
		else if(given && kind != "bullet"){
			case kind {
			"1" =>	mark = string k;
			"a" =>	mark = chr('a' + (k-1) % 26);
			"i" =>	mark = toroman(k);
			}
			mark[len mark] = l.delim;
		}
		if(mark != "")
			req(".item " + argq(mark));
		else
			req(".item");
		k++;
		bl := item.blocks;
		if(bl == nil)
			continue;
		pick p := hd bl {
		Para =>
			pl := inlines(p.text);
			if(!isfigure(pl)){
				para(pl);
				bl = tl bl;
			}
		}
		blocks(bl, 0);
	}
	req(".endlist");
}

toroman(n: int): string
{
	vals := array[] of {1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1};
	syms := array[] of {"m", "cm", "d", "cd", "c", "xc", "l", "xl", "x", "ix", "v", "iv", "i"};
	s := "";
	for(i := 0; i < len vals; i++)
		while(n >= vals[i]){
			s += syms[i];
			n -= vals[i];
		}
	return s;
}

table(t: ref Block.Table)
{
	nc := len t.aligns;
	long := 0;
	cl := t.head :: t.rows;
	i := 0;
	for(r := cl; r != nil; r = tl r)
		for(i = 0; i < len hd r; i++)
			if(len (hd r)[i] > 40)
				long = 1;
	float := t.caption != "" || t.attr.id != "";
	if(float){
		s := ".table";
		if(t.attr.id != "")
			s += " " + t.attr.id;
		req(s);
		if(t.caption != "")
			req(".caption " + argq(argmd(t.caption, "R")));
	}
	req(".TS");
	if(long)
		req("expand;");
	else
		req("center;");
	hf := "";
	bf := "";
	for(i = 0; i < nc; i++){
		if(i > 0){
			hf += " ";
			bf += " ";
		}
		hf += chr(t.aligns[i]) + "B";
		bf += chr(t.aligns[i]);
	}
	req(hf);
	req(bf + ".");
	req("_");
	row(t.head, "B");
	req("_");
	for(r = t.rows; r != nil; r = tl r)
		row(hd r, "R");
	req("_");
	req(".TE");
	if(float)
		req(".endtable");
}

row(cells: array of string, base: string)
{
	flush();
	line := "";
	for(i := 0; i < len cells; i++){
		if(i > 0)
			line += "\t";
		c := argmd(cells[i], base);
		if(len c > 40){
			# a block of text, filled in its column
			line += "T{";
			out = line :: out;
			cur = replace(c, " ", chr(SP));
			flush();
			line = "T}";
			continue;
		}
		if(c == "" )
			c = "\\&";
		else if(c[0] == '.' || c[0] == '\'' || c == "_" || c == "=")
			c = "\\&" + c;
		line += c;
	}
	out = line :: out;
}

div(d: ref Block.Div)
{
	a := d.attr;
	if(hasclass(a, "columns")){
		req(".columns");
		blocks(d.blocks, 1);
		req(".endcolumns");
		return;
	}
	if(hasclass(a, "column")){
		w := size(attrv(a, "width"));
		if(w != "")
			req(".column " + w);
		else
			req(".column");
		blocks(d.blocks, 1);
		return;
	}
	if(hasclass(a, "epigraph")){
		req(".epigraph");
		blocks(d.blocks, 1);
		at := attrv(a, "attrib");
		if(at == "")
			at = attrv(a, "source");
		if(at != "")
			req(".attrib " + argq(argmd(at, "R")));
		req(".endepigraph");
		return;
	}
	if(hasclass(a, "notes") || hasclass(a, "speaker-notes")){
		return;
	}
	if(hasclass(a, "abstract") && (macros == "article" || macros == "memo")){
		req(".abstract");
		blocks(d.blocks, 1);
		req(".endabstract");
		return;
	}
	for(l := a.classes; l != nil; l = tl l)
		case hd l {
		"frontmatter" or "mainmatter" or "backmatter" or "appendix" =>
			req("." + hd l);
		}
	blocks(d.blocks, 0);
}

# the document's head: its page, title, authors and abstract
head()
{
	v := "";
	if((v = metav("lang")) != "")
		req(".ds book-lang " + v);
	if((v = metav("papersize")) != "")
		req(".papersize " + v);
	case macros {
	"article" =>
		if((v = metav("columns")) != "")
			req(".columns " + v);
	"slides" =>
		if((v = metav("aspect")) != "" || (v = metav("aspectratio")) != ""){
			if(v == "169")
				v = "16:9";
			if(v == "43")
				v = "4:3";
			req(".aspect " + v);
		}
		if((v = metav("typeface")) != "")
			req(".typeface " + v);
	"memo" =>
		if((v = metav("org")) != "" || (v = metav("organization")) != "")
			req(".org " + argq(v));
		if((v = metav("kind")) != "")
			req(".kind " + v);
		if((v = metav("memotype")) != "")
			req(".memotype " + argq(v));
	}
	title := metav("title");
	if(title != "")
		req(".title " + argq(argmd(title, "B")));
	if((v = metav("subtitle")) != "")
		req(".subtitle " + argq(argmd(v, "I")));
	if(macros == "book"){
		names: list of string;
		for(a := authors; a != nil; a = tl a)
			names = (hd a).name :: names;
		names = rev(names);
		if(names != nil){
			s := hd names;
			for(names = tl names; names != nil; names = tl names){
				if(tl names == nil)
					s += " and " + hd names;
				else
					s += ", " + hd names;
			}
			req(".author " + argq(argmd(s, "R")));
		}
	}else{
		for(a := authors; a != nil; a = tl a){
			au := hd a;
			if(macros == "memo"){
				s := ".author " + argq(au.name);
				if(au.loc != "" || au.ext != "")
					s += " " + argq(au.loc);
				if(au.ext != "")
					s += " " + argq(au.ext);
				req(s);
				continue;
			}
			req(".author " + argq(argmd(au.name, "R")));
			if(au.affil != "")
				req(".affil " + argq(argmd(au.affil, "R")));
			if(au.email != "" && macros == "article")
				req(".email " + argq(au.email));
		}
	}
	if((v = metav("date")) != "")
		req(".date " + argq(argmd(v, "R")));
	if(macros == "memo"){
		if((v = metav("case")) != "")
			req(".case " + argq(v));
		if((v = metav("file")) != "")
			req(".file " + argq(v));
		if((v = metav("number")) != "")
			req(".number " + argq(v));
	}
	if((v = metav("abstract")) != ""){
		if(macros == "article" || macros == "memo"){
			req(".abstract");
			blocks(parse(lines(v)), 1);
			req(".endabstract");
		}else
			warn("abstract: -m" + macros + " has none; not set");
	}
	kw := metav("keywords");
	if(kw == "")
		kw = join(metalv("keywords"), ", ");
	if(kw != "" && macros == "article")
		req(".keywords " + argq(kw));
	if(title != "")
		req(".maketitle");
	v = str->tolower(metav("toc"));
	if(v == "true" || v == "yes")
		req(".contents");
}

lines(s: string): array of string
{
	l: list of string;
	t := "";
	for(i := 0; i < len s; i++){
		if(s[i] == '\n'){
			l = t :: l;
			t = "";
		}else
			t[len t] = s[i];
	}
	l = t :: l;
	return toarr(rev(l));
}
