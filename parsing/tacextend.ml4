(***********************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team    *)
(* <O___,, *        INRIA-Rocquencourt  &  LRI-CNRS-Orsay              *)
(*   \VV/  *************************************************************)
(*    //   *      This file is distributed under the terms of the      *)
(*         *       GNU Lesser General Public License Version 2.1       *)
(***********************************************************************)

(* $Id$ *)

open Genarg
open Q_util
open Q_coqast
open Argextend

let join_loc (deb1,_) (_,fin2) = (deb1,fin2)
let loc = (0,0)
let default_loc = <:expr< (0,0) >>

type grammar_tactic_production_expr =
  | TacTerm of string
  | TacNonTerm of Util.loc * Genarg.argument_type * MLast.expr * string option

let rec make_patt = function
  | [] -> <:patt< [] >>
  | TacNonTerm(loc',_,_,Some p)::l ->
      <:patt< [ $lid:p$ :: $make_patt l$ ] >>
  | _::l -> make_patt l

let rec make_when loc = function
  | [] -> <:expr< True >>
  | TacNonTerm(loc',t,_,Some p)::l ->
      let l = make_when loc l in
      let loc = join_loc loc' loc in
      let t = mlexpr_of_argtype loc' t in
      <:expr< Genarg.genarg_tag $lid:p$ = $t$ && $l$ >>
  | _::l -> make_when loc l

let rec make_let e = function
  | [] -> e
  | TacNonTerm(loc,t,_,Some p)::l ->
      let loc = join_loc loc (MLast.loc_of_expr e) in
      let e = make_let e l in
      let v = <:expr< Genarg.out_gen $make_wit loc t$ $lid:p$ >> in
      let v = 
        (* Special case for tactics which must be stored in algebraic
           form to avoid marshalling closures and to be reprinted *)
        if t = TacticArgType then
          <:expr< ($v$, Tacinterp.eval_tactic $v$) >>
        else v in
      <:expr< let $lid:p$ = $v$ in $e$ >>
  | _::l -> make_let e l

let add_clause s (_,pt,e) l =
  let p = make_patt pt in
  let w = Some (make_when (MLast.loc_of_expr e) pt) in
  (p, w, make_let e pt)::l

let rec extract_signature = function
  | [] -> []
  | TacNonTerm (_,t,_,_) :: l -> t :: extract_signature l
  | _::l -> extract_signature l

let check_unicity s l =
  let l' = List.map (fun (_,l,_) -> extract_signature l) l in
  if not (Util.list_distinct l') then
    Pp.warning_with Pp_control.err_ft
      ("Two distinct rules of tactic entry "^s^" have the same\n"^
      "non-terminals in the same order: put them in distinct tactic entries")

let make_clauses s l =
  check_unicity s l;
  let default =
    (<:patt< _ >>,None,<:expr< failwith "Tactic extension: cannot occur" >>) in
  List.fold_right (add_clause s) l [default]

let rec make_args = function
  | [] -> <:expr< [] >>
  | TacNonTerm(loc,t,_,Some p)::l ->
      <:expr< [ Genarg.in_gen $make_wit loc t$ $lid:p$ :: $make_args l$ ] >>
  | _::l -> make_args l

let rec make_eval_tactic e = function
  | [] -> e
  | TacNonTerm(loc,TacticArgType,_,Some p)::l ->
      let loc = join_loc loc (MLast.loc_of_expr e) in
      let e = make_eval_tactic e l in
        (* Special case for tactics which must be stored in algebraic
           form to avoid marshalling closures and to be reprinted *)
      <:expr< let $lid:p$ = ($lid:p$,Tacinterp.eval_tactic $lid:p$) in $e$ >>
  | _::l -> make_eval_tactic e l

let rec make_fun e = function
  | [] -> e
  | TacNonTerm(loc,_,_,Some p)::l -> 
      <:expr< fun $lid:p$ -> $make_fun e l$ >>
  | _::l -> make_fun e l

let mlexpr_of_grammar_production = function
  | TacTerm s ->
      <:expr< Egrammar.TacTerm $mlexpr_of_string s$ >>
  | TacNonTerm (loc,nt,g,sopt) ->
      <:expr< Egrammar.TacNonTerm $default_loc$ ($g$,$mlexpr_of_argtype loc nt$) $mlexpr_of_option mlexpr_of_string sopt$ >>

let mlexpr_of_semi_clause =
  mlexpr_of_pair mlexpr_of_string (mlexpr_of_list mlexpr_of_grammar_production)

let mlexpr_of_clause =
  mlexpr_of_list (fun (a,b,c) -> mlexpr_of_semi_clause (a,b))


let add_printing_clause (s,pt,e) l =
  let p = make_patt pt in
  let w = Some (make_when (MLast.loc_of_expr e) pt) in
  (p, w, mlexpr_of_semi_clause (s,pt))::l

let make_printing_rule l =
  let default =
    (<:patt< _ >>,None,<:expr< failwith "Tactic extension: cannot occur" >>) in
  List.fold_right add_printing_clause l [default]

let new_tac_ext (s,cl) =
  (String.lowercase s, List.map 
    (fun (s,l,e) ->
      (String.lowercase s, List.map
        (function TacTerm s -> TacTerm (String.lowercase s)
          | t -> t) l,
        e))
    cl)

let declare_tactic_v7 loc s cl =
  let pl = make_printing_rule cl in
  let gl = mlexpr_of_clause cl in
  let hide_tac (_,p,e) =
    (* reste a definir les fonctions cachees avec des noms frais *)
    let stac = let s = "h_"^s in s.[2] <- Char.lowercase s.[2]; s in
    let e = 
      make_fun
        <:expr<
          Refiner.abstract_extended_tactic $mlexpr_of_string s$ $make_args p$ $make_eval_tactic e p$
        >>
      p in
    <:str_item< value $lid:stac$ = $e$ >>
  in
  let se = mlexpr_of_string s in
  <:str_item<
    declare
      open Pcoq;
      Egrammar.extend_tactic_grammar $se$ $gl$;
      let pp = fun [ $list:pl$ ] in
      Pptactic.declare_extra_tactic_pprule False $se$ pp;
    end
  >>

let declare_tactic loc s cl =
  let (s',cl') = new_tac_ext (s,cl) in
  let pl' = make_printing_rule cl' in
  let gl' = mlexpr_of_clause cl' in
  let se' = mlexpr_of_string s' in
  let pl = make_printing_rule cl in
  let gl = mlexpr_of_clause cl in
  let hide_tac (_,p,e) =
    (* reste a definir les fonctions cachees avec des noms frais *)
    let stac = "h_"^s' in
    let e = 
      make_fun
        <:expr<
          Refiner.abstract_extended_tactic $mlexpr_of_string s'$ $make_args p$ $make_eval_tactic e p$
        >>
      p in
    <:str_item< value $lid:stac$ = $e$ >>
  in
  let hidden = if List.length cl = 1 then List.map hide_tac cl' else [] in
  let se = mlexpr_of_string s in
  <:str_item<
    declare
      open Pcoq;
      declare $list:hidden$ end;
      try
       Refiner.add_tactic $se'$ (fun [ $list:make_clauses s' cl'$ ])
      with e -> Pp.pp (Cerrors.explain_exn e);
      if Options.v7.val then Egrammar.extend_tactic_grammar $se'$ $gl$
      else Egrammar.extend_tactic_grammar $se'$ $gl'$;
      let pp' = fun [ $list:pl'$ ] in
      Pptactic.declare_extra_tactic_pprule True $se'$ pp';
      let pp = fun [ $list:pl$ ] in
      Pptactic.declare_extra_tactic_pprule False $se'$ pp;
    end
  >>

open Vernacexpr
open Pcoq

let rec interp_entry_name loc s =
  let l = String.length s in
  if l > 8 & String.sub s 0 3 = "ne_" & String.sub s (l-5) 5 = "_list" then
    let t, g = interp_entry_name loc (String.sub s 3 (l-8)) in
    List1ArgType t, <:expr< Gramext.Slist1 $g$ >>
  else if l > 5 & String.sub s (l-5) 5 = "_list" then
    let t, g = interp_entry_name loc (String.sub s 0 (l-5)) in
    List0ArgType t, <:expr< Gramext.Slist0 $g$ >>
  else if l > 4 & String.sub s (l-4) 4 = "_opt" then
    let t, g = interp_entry_name loc (String.sub s 0 (l-4)) in
    OptArgType t, <:expr< Gramext.Sopt $g$ >>
  else
    
    let t, se =
      match Pcoq.entry_type (Pcoq.get_univ "prim") s with
	| Some _ as x -> x, <:expr< Prim. $lid:s$ >>
	| None -> 
      match Pcoq.entry_type (Pcoq.get_univ "constr") s with
	| Some _ as x -> x, <:expr< Constr. $lid:s$ >>
	| None -> 
      match Pcoq.entry_type (Pcoq.get_univ "tactic") s with
	| Some _ as x -> x, <:expr< Tactic. $lid:s$ >>
	| None -> None, <:expr< $lid:s$ >> in
    let t =
      match t with
	| Some t -> t
	| None ->
(*	    Pp.warning_with Pp_control.err_ft
            ("Unknown primitive grammar entry: "^s);*)
	    ExtraArgType s
    in t, <:expr< Gramext.Snterm (Pcoq.Gram.Entry.obj $se$) >>

open Pcaml

EXTEND
  GLOBAL: str_item;
  str_item:
    [ [ "TACTIC"; "EXTEND"; s = [ UIDENT | LIDENT ];
        OPT "|"; l = LIST1 tacrule SEP "|";
        "END" ->
         declare_tactic loc s l
      | "V7"; "TACTIC"; "EXTEND"; s = [ UIDENT | LIDENT ];
        OPT "|"; l = LIST1 tacrule SEP "|";
        "END" ->
         declare_tactic_v7 loc s l ] ]
  ;
  tacrule:
    [ [ "["; s = STRING; l = LIST0 tacargs; "]"; "->"; "["; e = Pcaml.expr; "]"
        -> (s,l,e)
    ] ]
  ;
  tacargs:
    [ [ e = LIDENT; "("; s = LIDENT; ")" ->
        let t, g = interp_entry_name loc e in
        TacNonTerm (loc, t, g, Some s)
      | s = STRING ->
        TacTerm s
    ] ]
  ;
  END

