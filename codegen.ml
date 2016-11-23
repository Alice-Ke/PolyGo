(* Code generation: translate takes a semantically checked AST and
produces LLVM IR

LLVM tutorial: Make sure to read the OCaml version of the tutorial

http://llvm.org/docs/tutorial/index.html

Detailed documentation on the OCaml LLVM library:

http://llvm.moe/
http://llvm.moe/ocaml/

*)

module L = Llvm
module A = Ast

module StringMap = Map.Make(String)

let translate (globals, functiondecl) =
  let context = L.global_context () in
  let the_module = L.create_module context "PolyGo"
  and i32_t  = L.i32_type  context
  and i8_t   = L.i8_type   context
  and i1_t   = L.i1_type   context
  and f32_t  = L.float_type context
  and void_t = L.void_type context in

  let rec ltype_of_typ = function
      A.Int -> i32_t
    | A.Float -> f32_t 
    | A.Bool -> i1_t
    | A.Void -> void_t 
    | A.String  -> L.pointer_type i8_t
  in


  let type_of_global= function
      A.Primdecl (t,s) -> (A.String,s)
    | A.Primdecl_i (t,s,primary) -> (A.String,s)
    | A.Arrdecl (t,s,i) -> (A.String,s)
    | A.Arrdecl_i (t,s,i,p_list) -> (A.String, s)
  in

  (* Declare each global variable; remember its value in a map *)
  let global_vars =
    let global_var m global =
        let (typ', s) = type_of_global global in
        let init = L.const_int (ltype_of_typ typ') 0 in 
    StringMap.add s (L.define_global s init the_module) m in
  List.fold_left global_var StringMap.empty globals in

  (* Declare printf(), which the print built-in function will call *)
  let printf_t = L.var_arg_function_type i32_t [| L.pointer_type i8_t |] in
    let printf_func = L.declare_function "printf" printf_t the_module in
  let printf_s = L.var_arg_function_type i32_t [| L.pointer_type i8_t |] in
    let printf_func_s = L.declare_function "printf" printf_s the_module in
  let printf_f = L.var_arg_function_type i32_t [| L.pointer_type i8_t |] in
    let printf_func_f = L.declare_function "printf" printf_f the_module in


  let strcat_t = L.function_type (L.pointer_type i8_t) 
    [| L.pointer_type i8_t; L.pointer_type i8_t |] in
    let strcat_func = L.declare_function "strcat" strcat_t the_module in

  let type_of_formaldecl = function
      A.Prim_f_decl (t, s) -> (A.String,s) 
    | A.Arr_f_decl (t,s) -> (A.String,s) 
  in
  (* Define each function (arguments and return type) so we can call it *)
  let function_decls =
    let function_decl m fdecl =
      let typ' = List.map type_of_formaldecl fdecl.A.formals in
      let name = fdecl.A.fname and
          formal_types = Array.of_list (List.map (fun (t,_) ->ltype_of_typ t) typ') in 
      let ftype = L.function_type (ltype_of_typ fdecl.A.ftyp) formal_types in
      StringMap.add name (L.define_function name ftype the_module, fdecl) m in
    List.fold_left function_decl StringMap.empty functiondecl 
  in
  
  (* Fill in the body of the given function *)
  let build_function_body fdecl =
    let (the_function,_) = StringMap.find fdecl.A.fname function_decls in
    let builder = L.builder_at_end context (L.entry_block the_function) in
    
    let int_format_str = L.build_global_stringptr "%d\n" "fmt" builder in
    let float_format_str = L.build_global_stringptr "%f\n" "float" builder in
    let str_format_str = L.build_global_stringptr "%s" "str" builder in
    (* Construct the function's "locals": formal arguments and locally
       declared variables.  Allocate each on the stack, initialize their
       value, if appropriate, and remember their values in the "locals" map *)


    let from_primary = function
      A.Strlit s ->  s
    in

    let type_of_unasned_locals = function
        A.Primdecl    (t,s)-> (A.String,s)
    in

    let type_of_asned_locals = function
        A.Primdecl_i  (t,s,primary) -> (A.String,s, from_primary primary )
    in

    let local_vars =
      let add_formal m (formal_typ, name) param = L.set_value_name name param;

      let local = L.build_alloca (ltype_of_typ formal_typ) name builder in
      ignore (L.build_store param local builder);
      StringMap.add name local m in



      let add_local m (local_typ, name) =
      let local_var = L.build_alloca (ltype_of_typ local_typ) name builder in
      StringMap.add name local_var m in

     (* let add_asned_local m (local_typ, name,primary) = L.set_value_name name (L.const_int i1_t 0);
      let local_asned_var = L.build_alloca (ltype_of_typ local_typ) name builder in
      ignore (L.build_store (L.const_int i1_t 0) local_asned_var builder);
      StringMap.add name local_asned_var m in*)
(*
      let add_asned_local m (name,primary) = L.set_value_name name primary;

      let local_asned_var = L.build_alloca (A.String) name builder
      ignore (L.build_store primary local_asned_var builder);
      StringMap.add name local_asned_var m in *)

      let formall      = List.map      type_of_formaldecl         fdecl.A.formals  and 
          locall       = List.map      type_of_unasned_locals     fdecl.A.locals   in
    (*      local_asned  = List.map      type_of_asned_locals       fdecl.A.locals   in*)
      let formals     = List.fold_left2 add_formal StringMap.empty 
                        formall (Array.to_list (L.params the_function))            in
      (*let locals      = List.fold_left add_local formals locall                    in *)
                        List.fold_left add_local formals locall         in

    (* Return the value for a variable or formal argument *)
    let lookup name = try StringMap.find name local_vars
                   with Not_found -> StringMap.find name global_vars
    in

    (* Construct code for an expression; return its value *)
    let rec extra = function
      A.Id s -> s
    in

    (*let primary_c builder = function
      A.Intlit i-> L.const_int i32_t i
    | A.Floatlit f -> L.const_float  f32_t f
    in*)
    
    let rec primary_ap  = function
      A.Prim_c p_c -> (match p_c with A.Intlit i -> L.const_int i32_t i
                                    | A.Floatlit f -> L.const_float  f32_t f)
                                
    in

    let rec primary builder = function
      A.Prim_ap p_ap -> primary_ap  p_ap
    | A.Boollit b -> L.const_int i1_t (if b then 1 else 0)
    | A.Strlit s -> L.build_global_stringptr
        (String.sub s 1 ((String.length s) - 2)) "" builder
    in

    

    let rec expr builder = function
      A.Asn (ex,e) ->  let e' = expr builder e in
                     ignore (L.build_store e' (lookup (extra ex)) builder); e'
      
    | A.Primary p ->  primary builder p
    | A.Call ("print", [e]) | A.Call ("printb", [e]) ->
    L.build_call printf_func [| int_format_str ; (expr builder e) |]
      "printf" builder
    | A.Call ("print_string", [e]) -> L.build_call printf_func_s 
        [| str_format_str; (expr builder e) |] "printf" builder
    | A.Call (f, act) ->
         let (fdef, fdecl) = StringMap.find f function_decls in
   let actuals = List.rev (List.map (expr builder) (List.rev act)) in
   let result = (match fdecl.A.ftyp with A.Void -> ""
                                      | _ -> f ^ "_result") in
         L.build_call fdef (Array.of_list actuals) result builder
    | A.Noexpr -> L.const_int i1_t 0
    in

    (* Invoke "f builder" if the current block doesn't already
       have a terminal (e.g., a branch). *)
    let add_terminal builder f =
      match L.block_terminator (L.insertion_block builder) with
  Some _ -> ()
      | None -> ignore (f builder) in
  
    (* Build the code for the given statement; return the builder for
       the statement's successor *)
    let rec stmt builder = function
  A.Block sl -> List.fold_left stmt builder sl
      | A.Expr e -> ignore (expr builder e); builder
      | A.Return e -> ignore (match fdecl.A.ftyp with
    A.Void -> L.build_ret_void builder
  | _ -> L.build_ret (expr builder e) builder); builder
      
    in

    (* Build the code for each statement in the function *)
    let builder = stmt builder (A.Block fdecl.A.body) in

    (* Add a return if the last block falls off the end *)
    add_terminal builder (match fdecl.A.ftyp with
        A.Void -> L.build_ret_void
      | t -> L.build_ret (L.const_int (ltype_of_typ t) 0))
  in

  List.iter build_function_body functiondecl;
  the_module