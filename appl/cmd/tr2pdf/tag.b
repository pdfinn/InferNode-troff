#
# tag.b: a tagged PDF (ISO 32000-1, 14.7 and 14.8; PDF/UA-1), its
# structure given by troff's output (not Neatpost's):
#
#	x X tag push S [id] [Key=value ...]	an element S in the one open (a
#					grouping one, as BlockQuote, after the
#					block open is closed)
#	x X tag pop			the last pushed closed, and all open in it
#	x X tag close S			closed back through the innermost S
#	x X tag S [id] [Key=value ...]	a block S (P, H1, TD ...): the block
#					open closed, S opened in its place
#	x X tag end			the block open closed
#	x X tag art, tag endart		what is set between them an artifact
#					(running heads, folios)
#	x X tag alt text		the open element's alternate description
#	x X tag lang L			the open element's language
#	x X lang L			the document's
#
# An element given an id is opened again by it: a note continued on the
# next page is one note. Text set where only a grouping element is open
# (Document, BlockQuote, Table ...) is a paragraph of its own until the
# next x X tag. Lines drawn are artifacts but in a Figure or a Formula.
# A link (x X link) is a Link element in the one open: the text set in
# its rectangle its content, its annotation its object, described by
# that text (/Contents). Each element's content is marked with its
# MCID, each page's in the parent tree.
#
# Tagging begins at the first x X tag, the document's root (Document)
# made then; with none the PDF has no structure, as before.
#

tagged := 0;		# x X tag seen
pdfua := 0;		# -u: PDF/UA-1 claimed, in the metadata
doc_lang: string;	# the document's language (x X lang)

# an element of the structure
Selem: adt {
	typ:	string;		# its type: P, H1, Note ...
	id:	string;		# the id it was given, if any
	parent:	int;		# its parent; -1, the root
	kids:	list of ref Skid;	# its kids, the last first
	alttext:	string;
	lang:	string;
	attrs:	string;		# its attributes' entries (/ColSpan 2)
	obj:	int;		# its object
	keep:	int;		# written: it has content
};

# a kid: an element, a page's marked content, or an annotation
Skid: adt {
	e:	int;		# the element; -1, not one
	page:	int;		# the page (its index) marked
	mcid:	int;
	annot:	int;		# the annotation's object; 0, not one
};

selems: array of ref Selem;
selem_n := 0;

# what is open: the elements, and how each was opened
TPUSH, TBLOCK, TIMPL, TLINK: con iota;
tstk: array of int;
tkind: array of int;
tdepth := 0;
tart := 0;		# artifacts open (x X tag art)

# the page's marked content: none, an element's, an artifact's
MCNONE, MCELEM, MCART: con iota;
mc_kind := MCNONE;
mc_elem := -1;
pg_mcids: list of int;	# each MCID's element, the last first
pg_mcn := 0;
in_text := 0;		# a text object (BT) open

# the parent tree's entries: a page's MCIDs, or an annotation's element
ptree: list of (int, string);
ptree_n := 0;

# a link open: its element, annotation, rectangle and text so far
lnk_e := -1;
lnk_ann := 0;
lnk_dict: string;	# its annotation, all but /Contents
lnk_key := 0;
lnk_h0, lnk_h1, lnk_v0, lnk_v1: int;
lnk_text: string;
lnk_endh := -1;		# where its last glyph ended

# elements whose text needs a paragraph of its own
grouping(t: string): int
{
	case t {
	"Document" or "Part" or "Art" or "Sect" or "Div" or "BlockQuote" or
	"TOC" or "Index" or "L" or "Table" or "THead" or "TBody" or "TFoot" or
	"TR" or "NonStruct" =>
		return 1;
	}
	return 0;
}

tag_on()
{
	if(tagged || compat)
		return;
	tagged = 1;
	selems = array[256] of ref Selem;
	tstk = array[64] of int;
	tkind = array[64] of int;
	e := selemnew("Document", nil, nil, -1);
	tpush(e, TPUSH);
}

selemnew(typ, id, attrs: string, parent: int): int
{
	if(selem_n == len selems){
		n := array[2 * selem_n] of ref Selem;
		n[0:] = selems;
		selems = n;
	}
	e := selem_n++;
	selems[e] = ref Selem(typ, id, parent, nil, nil, nil, attrs, obj_map(), 0);
	if(parent >= 0)
		selems[parent].kids = ref Skid(e, 0, 0, 0) :: selems[parent].kids;
	return e;
}

# an element in the one open, or the one given the id, opened again
selemopen(typ, id, attrs: string): int
{
	if(id != nil)
		for(i := 0; i < selem_n; i++)
			if(selems[i].id == id)
				return i;
	return selemnew(typ, id, attrs, parentfor(typ));
}

# what an element of type t is put in: the one open, unless that holds
# only its own kinds (a table its rows, a row its cells), then the
# nearest open that holds it: a note set at a page's foot between a
# table's rows is the table's neighbour, not its row
parentfor(t: string): int
{
	for(i := tdepth - 1; i > 0; i--)
		if(holds(selems[tstk[i]].typ, t))
			break;
	return tstk[i];
}

holds(p, t: string): int
{
	k: string;
	case p {
	"Table" =>
		k = " TR THead TBody TFoot Caption ";
	"THead" or "TBody" or "TFoot" =>
		k = " TR ";
	"TR" =>
		k = " TH TD ";
	"L" =>
		k = " LI L Caption ";
	"TOC" =>
		k = " TOCI TOC Caption ";
	* =>
		return 1;
	}
	return contains(k, " " + t + " ");
}

tpush(e, kind: int)
{
	if(tdepth == len tstk){
		n := array[2 * tdepth] of int;
		n[0:] = tstk;
		tstk = n;
		k := array[2 * tdepth] of int;
		k[0:] = tkind;
		tkind = k;
	}
	tstk[tdepth] = e;
	tkind[tdepth++] = kind;
}

tpop()
{
	if(tdepth <= 1)
		return;
	if(tkind[tdepth - 1] == TLINK)
		lnkdone();
	tdepth--;
}

# a link or a paragraph opened for text closed
tcloseimpl()
{
	while(tdepth > 1 && (tkind[tdepth - 1] == TLINK || tkind[tdepth - 1] == TIMPL))
		tpop();
}

# the block open closed, and all open in it
tcloseblock()
{
	while(tdepth > 1 && tkind[tdepth - 1] != TPUSH)
		tpop();
}

# x X tag ...
tag_cmd(arg: string)
{
	tag_on();
	if(!tagged)
		return;
	(op, rest) := word(arg);
	if(op == nil)
		return;
	# an artifact is outside the structure: what is tagged within it (a
	# slide's page repeated before its last, -mslides') is not
	if(tart > 0 && op != "art" && op != "endart")
		return;
	tcloseimpl();
	case op {
	"push" =>
		(typ, id, attrs) := tagargs(rest);
		if(typ == nil)
			break;
		# a grouping element is not in a paragraph: the block open closed
		if(grouping(typ))
			tcloseblock();
		tpush(selemopen(typ, id, attrs), TPUSH);
	"pop" =>
		tcloseblock();
		tpop();
	"close" =>
		(typ, nil) := word(rest);
		for(i := tdepth - 1; i > 0; i--)
			if(selems[tstk[i]].typ == typ){
				while(tdepth > i)
					tpop();
				break;
			}
	"end" =>
		tcloseblock();
	"art" =>
		tart++;
	"endart" =>
		if(tart > 0)
			tart--;
	"alt" =>
		selems[tstk[tdepth - 1]].alttext = titletext(rest);
	"lang" =>
		(l, nil) := word(rest);
		selems[tstk[tdepth - 1]].lang = l;
	* =>
		tcloseblock();
		(nil, id, attrs) := tagargs(arg);
		tpush(selemopen(op, id, attrs), TBLOCK);
	}
}

# an element's type, id and attributes (Key=value: a number, or a name)
tagargs(s: string): (string, string, string)
{
	typ, id, attrs: string;
	(typ, s) = word(s);
	for(;;){
		w: string;
		(w, s) = word(s);
		if(w == nil)
			break;
		eq := strchr(w, '=');
		if(eq < 0){
			id = w;
			continue;
		}
		v := w[eq + 1:];
		if(v != "" && !isdigit(v[0]))
			v = "/" + pdfname(v);
		attrs += " /" + pdfname(w[0:eq]) + " " + v;
	}
	return (typ, id, attrs);
}

# the element the content set now is in, a paragraph made for it if
# only a grouping element is open
tag_elem(): int
{
	e := tstk[tdepth - 1];
	if(grouping(selems[e].typ)){
		e = selemnew("P", nil, nil, parentfor("P"));
		tpush(e, TIMPL);
	}
	return e;
}

# in a figure or formula: lines drawn are its content
tag_drawn(): int
{
	for(i := tdepth - 1; i > 0; i--)
		case selems[tstk[i]].typ {
		"Figure" or "Formula" =>
			return 1;
		}
	return 0;
}

# in a figure, a formula or a table: set as a whole, its rows not to
# be stretched apart (vjust)
tag_rigid(): int
{
	for(i := tdepth - 1; i > 0; i--)
		case selems[tstk[i]].typ {
		"Figure" or "Formula" or "Table" =>
			return 1;
		}
	return 0;
}

# what is set next (a glyph, or if draw a line) marked as its element's
tag_content(draw: int)
{
	if(!tagged)
		return;
	if(tart > 0 || (draw && !tag_drawn())){
		if(mc_kind != MCART){
			mc_close();
			textend();
			pg += "/Artifact BMC\n";
			mc_kind = MCART;
		}
		return;
	}
	e := tag_elem();
	if(mc_kind == MCELEM && mc_elem == e)
		return;
	mc_close();
	textend();	# marked content not in a text object, nor one in it
	mcid := pg_mcn++;
	pg_mcids = e :: pg_mcids;
	selems[e].kids = ref Skid(-1, page_n, mcid, 0) :: selems[e].kids;
	pg += "/" + pdfname(selems[e].typ) + " <</MCID " + string mcid + ">> BDC\n";
	mc_kind = MCELEM;
	mc_elem = e;
}

mc_close()
{
	atextend();
	if(mc_kind == MCNONE)
		return;
	textend();
	pg += "EMC\n";
	mc_kind = MCNONE;
	mc_elem = -1;
}

# a glyph about to be set: in a link's rectangle, the link's text;
# past it, the link closed
tag_glyph(g: ref Glyph)
{
	if(!tagged)
		return;
	if(lnk_e >= 0 && tdepth > 1 && tkind[tdepth - 1] == TLINK){
		if(o_h >= lnk_h1 || o_h < lnk_h0 - 1 || o_v < lnk_v0 || o_v > lnk_v1)
			tpop();
		else if(tart == 0){
			if(lnk_endh >= 0 && o_h - lnk_endh > o_s * devres() / (72 * dev_szscale) / 5)
				lnk_text += " ";
			lnk_text += glyphtext(g.fnt, g);
			lnk_endh = o_h + font_wid(g.fnt, o_s, g.wid);
		}
	}
	tag_content(0);
}

# x X link, tagged: its annotation written when its text is known
tag_link(dict: string, hwid, vwid: int): int
{
	if(tart > 0)
		return 0;
	if(ann_n == len ann)
		return 1;
	tcloseimpl();
	p := tag_elem();
	e := selemnew("Link", nil, nil, p);
	tpush(e, TLINK);
	o_flush();
	lnk_e = e;
	lnk_ann = obj_map();
	ann[ann_n++] = lnk_ann;
	lnk_key = ptree_n++;
	selems[e].kids = ref Skid(-1, page_n, 0, lnk_ann) :: selems[e].kids;
	ptree = (lnk_key, string selems[e].obj + " 0 R") :: ptree;
	lnk_dict = dict;
	(lnk_h0, lnk_h1) = (o_h, o_h + hwid);
	(lnk_v0, lnk_v1) = (o_v, o_v + vwid);
	if(lnk_v1 < lnk_v0)
		(lnk_v0, lnk_v1) = (lnk_v1, lnk_v0);
	lnk_text = "";
	lnk_endh = -1;
	return 1;
}

# the link closed: its annotation written, described by its text
lnkdone()
{
	if(lnk_e < 0)
		return;
	t := lnk_text;
	# a contents line's leaders not read out
	while((i := dots(t)) >= 0){
		j := i;
		while(j < len t && (t[j] == '.' || t[j] == ' '))
			j++;
		t = t[0:i] + " " + t[j:];
	}
	while(t != "" && t[len t - 1] == ' ')
		t = t[0:len t - 1];
	if(t == "")
		t = "Link";
	vj_annot(lnk_ann, lnk_dict + "  /Contents " + pdftext(t) + "\n  /StructParent " + string lnk_key + "\n>>\n");
	lnk_e = -1;
}

# where three dots (as leaders set them, spaced or not) begin; -1, nowhere
dots(s: string): int
{
	n := 0;
	b := -1;
	for(i := 0; i < len s; i++){
		if(s[i] == '.'){
			if(n++ == 0)
				b = i;
			if(n == 3)
				return b;
		}else if(s[i] != ' ')
			n = 0;
	}
	return -1;
}

# a page begun: its marked content none yet
tag_pagebeg()
{
	pg_mcids = nil;
	pg_mcn = 0;
	mc_kind = MCNONE;
	mc_elem = -1;
	in_text = 0;
}

# x X text t, x X endtext: what is set between them is read as t, its
# ActualText (TeX's logo's letters, lowered and raised, as the word
# they spell), for search, copying and those who hear it read: marked
# content in its element's, or on its own in a PDF with no structure
atext := 0;

atext_begin(t: string)
{
	atextend();
	if(t == "")
		return;
	tag_content(0);
	textend();
	pg += "/Span <</ActualText " + pdftext(t) + ">> BDC\n";
	atext = 1;
}

atextend()
{
	if(!atext)
		return;
	atext = 0;
	textend();
	pg += "EMC\n";
}

# a page ending: what is open on it closed; its entries in the page
# dictionary
tag_pageend(): string
{
	if(!tagged)
		return nil;
	if(tdepth > 1 && tkind[tdepth - 1] == TLINK)
		tpop();
	mc_close();
	s := "  /Tabs /S\n";
	if(pg_mcn > 0){
		a := array[pg_mcn] of int;
		i := pg_mcn;
		for(l := pg_mcids; l != nil; l = tl l)
			a[--i] = hd l;
		v := "[";
		for(i = 0; i < pg_mcn; i++)
			v += " " + string selems[a[i]].obj + " 0 R";
		k := ptree_n++;
		ptree = (k, v + " ]") :: ptree;
		s += "  /StructParents " + string k + "\n";
	}
	return s;
}

# whether an element is written: it, or one in it, has content (a
# table's cells are, empty or not)
tag_keep(e: int): int
{
	el := selems[e];
	k := el.typ == "TD" || el.typ == "TH";
	for(l := el.kids; l != nil; l = tl l){
		kid := hd l;
		if(kid.e < 0)
			k = 1;
		else if(tag_keep(kid.e))
			k = 1;
	}
	el.keep = k;
	return k;
}

# the structure tree, its root's object; the catalogue's entries for it
tag_done(): string
{
	if(!tagged)
		return nil;
	while(tdepth > 1)
		tpop();
	if(!tag_keep(0))
		return nil;
	root := obj_map();
	ids: list of (string, int);
	for(e := 0; e < selem_n; e++){
		el := selems[e];
		if(!el.keep)
			continue;
		obj_beg(el.obj);
		s := "<<\n  /Type /StructElem\n  /S /" + pdfname(el.typ) + "\n";
		if(el.parent >= 0)
			s += "  /P " + string selems[el.parent].obj + " 0 R\n";
		else
			s += "  /P " + string root + " 0 R\n";
		if(el.typ == "Note" && el.id == nil)	# a note has one (PDF/UA-1, 7.9)
			el.id = "note" + string e;
		if(el.id != nil){
			s += "  /ID " + pdftext(el.id) + "\n";
			ids = (el.id, el.obj) :: ids;
		}
		if(el.alttext != nil)
			s += "  /Alt " + pdftext(el.alttext) + "\n";
		if(el.lang != nil)
			s += "  /Lang " + pdftext(el.lang) + "\n";
		if(el.attrs != nil){
			owner := "Layout";
			for(i := 0; i < len tableattrs; i++)
				if(contains(el.attrs + " ", tableattrs[i]))
					owner = "Table";
			s += "  /A << /O /" + owner + el.attrs + " >>\n";
		}
		s += "  /K [";
		n := 0;
		for(kl := el.kids; kl != nil; kl = tl kl)
			n++;
		kids := array[n] of ref Skid;
		for(kl = el.kids; kl != nil; kl = tl kl)
			kids[--n] = hd kl;
		for(j := 0; j < len kids; j++){
			kid := kids[j];
			if(kid.e >= 0){
				if(selems[kid.e].keep)
					s += " " + string selems[kid.e].obj + " 0 R";
			}else if(kid.page < page_n){
				pgobj := string page_id[kid.page] + " 0 R";
				if(kid.annot)
					s += "\n    << /Type /OBJR /Obj " + string kid.annot + " 0 R /Pg " + pgobj + " >>";
				else
					s += "\n    << /Type /MCR /MCID " + string kid.mcid + " /Pg " + pgobj + " >>";
			}
		}
		pdfout(s + " ]\n>>\n");
		obj_end();
	}
	# the parent tree, by its keys
	n := ptree_n;
	vals := array[n] of string;
	for(pl := ptree; pl != nil; pl = tl pl){
		(k, v) := hd pl;
		vals[k] = v;
	}
	pt := obj_beg(0);
	s := "<<\n  /Nums [";
	for(k := 0; k < n; k++)
		if(vals[k] != nil)
			s += "\n    " + string k + " " + vals[k];
	pdfout(s + " ]\n>>\n");
	obj_end();
	# the elements by their ids, in the order of their bytes
	idt := 0;
	if(ids != nil){
		ni := 0;
		for(il := ids; il != nil; il = tl il)
			ni++;
		a := array[ni] of (string, int);
		for(il = ids; il != nil; il = tl il)
			a[--ni] = hd il;
		for(i := 1; i < len a; i++)
			for(j := i; j > 0 && bytecmp(a[j].t0, a[j - 1].t0) < 0; j--)
				(a[j], a[j - 1]) = (a[j - 1], a[j]);
		idt = obj_beg(0);
		s = "<<\n  /Names [";
		for(i = 0; i < len a; i++)
			if(i == 0 || a[i].t0 != a[i - 1].t0)
				s += "\n    " + pdftext(a[i].t0) + " " + string a[i].t1 + " 0 R";
		pdfout(s + " ]\n>>\n");
		obj_end();
	}
	obj_beg(root);
	s = "<<\n  /Type /StructTreeRoot\n  /K " + string selems[0].obj + " 0 R\n" +
		"  /ParentTree " + string pt + " 0 R\n  /ParentTreeNextKey " + string n + "\n";
	if(idt)
		s += "  /IDTree " + string idt + " 0 R\n";
	pdfout(s + ">>\n");
	obj_end();
	s = "  /StructTreeRoot " + string root + " 0 R\n  /MarkInfo << /Marked true >>\n";
	s += "  /ViewerPreferences << /DisplayDocTitle true >>\n";
	if(doc_lang != nil)
		s += "  /Lang " + pdftext(doc_lang) + "\n";
	return s;
}

# s and t compared as PDF strings are, byte by byte
bytecmp(s, t: string): int
{
	a := array of byte s;
	b := array of byte t;
	for(i := 0; i < len a && i < len b; i++)
		if(a[i] != b[i])
			return int a[i] - int b[i];
	return len a - len b;
}

tableattrs := array[] of {" /ColSpan ", " /RowSpan ", " /Scope ", " /Headers "};

contains(s, t: string): int
{
	for(i := 0; i + len t <= len s; i++)
		if(s[i:i + len t] == t)
			return 1;
	return 0;
}

# the document's metadata (XMP): its title and author, its producer, and
# with -u its claim to PDF/UA-1
tag_metadata(): int
{
	x := "<?xpacket begin=\"﻿\" id=\"W5M0MpCehiHzreSzNTczkc9d\"?>\n" +
		"<x:xmpmeta xmlns:x=\"adobe:ns:meta/\">\n" +
		"<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">\n" +
		"<rdf:Description rdf:about=\"\"\n" +
		"  xmlns:dc=\"http://purl.org/dc/elements/1.1/\"\n" +
		"  xmlns:pdf=\"http://ns.adobe.com/pdf/1.3/\"\n" +
		"  xmlns:xmp=\"http://ns.adobe.com/xap/1.0/\"\n" +
		"  xmlns:pdfuaid=\"http://www.aiim.org/pdfua/ns/id/\">\n";
	x += "<dc:format>application/pdf</dc:format>\n";
	if(pdf_title != "")
		x += "<dc:title><rdf:Alt><rdf:li xml:lang=\"x-default\">" + xmltext(pdf_title) +
			"</rdf:li></rdf:Alt></dc:title>\n";
	if(pdf_author != "")
		x += "<dc:creator><rdf:Seq><rdf:li>" + xmltext(pdf_author) + "</rdf:li></rdf:Seq></dc:creator>\n";
	if(doc_lang != nil)
		x += "<dc:language><rdf:Bag><rdf:li>" + xmltext(doc_lang) + "</rdf:li></rdf:Bag></dc:language>\n";
	x += "<pdf:Producer>tr2pdf</pdf:Producer>\n<xmp:CreatorTool>Neatroff</xmp:CreatorTool>\n";
	if(pdfua)
		x += "<pdfuaid:part>1</pdfuaid:part>\n";
	x += "</rdf:Description>\n</rdf:RDF>\n</x:xmpmeta>\n<?xpacket end=\"w\"?>\n";
	b := array of byte x;
	id := obj_beg(0);
	pdfout("<<\n  /Type /Metadata\n  /Subtype /XML\n  /Length " + string len b + "\n>>\nstream\n");
	pdfmem(b);
	pdfout("\nendstream\n");
	obj_end();
	return id;
}

xmltext(s: string): string
{
	r := "";
	for(i := 0; i < len s; i++)
		case s[i] {
		'&' =>	r += "&amp;";
		'<' =>	r += "&lt;";
		'>' =>	r += "&gt;";
		'"' =>	r += "&quot;";
		* =>	r[len r] = s[i];
		}
	return r;
}
