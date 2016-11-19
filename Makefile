TARFILES = Makefile scanner.mll parser.mly ast.mli ast_checker.ml

OBJS = parser.cmo scanner.cmo ast_checker.cmo

ast_checker : $(OBJS)
	ocamlc -o ast_checker $(OBJS)

scanner.ml : scanner.mll
	ocamllex scanner.mll

parser.ml parser.mli : parser.mly
	ocamlyacc parser.mly

%.cmo : %.ml
	ocamlc -c $<

%.cmi : %.mli
	ocamlc -c $<

.PHONY : clean
clean :
	rm -f ast_checker parser.ml parser.mli scanner.ml *.cmo *.cmi

# Generated by ocamldep *.ml *.mli
ast_checker.cmo: scanner.cmo parser.cmi ast.cmi 
ast_checker.cmx: scanner.cmx parser.cmx ast.cmi 
parser.cmo: ast.cmi parser.cmi 
parser.cmx: ast.cmi parser.cmi 
scanner.cmo: parser.cmi 
scanner.cmx: parser.cmx 
parser.cmi: ast.cmi 
