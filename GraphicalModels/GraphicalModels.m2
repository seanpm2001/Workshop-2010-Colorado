-- -*- coding: utf-8 -*-

needsPackage "Graphs"

newPackage(
     "GraphicalModels",
     Version => "0.1",
     Date => "September 15, 2010",
     Authors => {
	  {Name => "Luis Garcia-Puente",
	   Email => "lgarcia@shsu.edu",
	   HomePage => "http://www.shsu.edu/~ldg005"},
	  {Name => "Mike Stillman",
	   Email => "mike@math.cornell.edu",
	   HomePage => "http://www.math.cornell.edu/~mike/"} 
	  },
     Headline => "A package for discrete and Gaussian statistical graphical models",
     DebuggingMode => true
     )

------------------------------------------
-- Algebraic Statistics in Macaulay2
-- Authors: Luis Garcia-Puente and Mike Stillman
-- Collaborators: Alex Diaz, Shaowei Lin, Augustine O'Keefe, Sonja Petrović, Amelia Taylor 
-- 
-- Routines:
--  Markov relations:
--   pairMarkovStmts (Digraph G)
--   localMarkovStmts (Digraph G)
--   globalMarkovStmts (Digraph G)
--   bayesBall (set A, set C, Digraph G)  [internal function used by globalMarkovStmts]
--
--  Removing redundant statements: 
--   equivStmts (S,T) -- [internal routine used within Markov relation routines]
--   setit (d) -- [internal routine used within Markov relation routines] 
--   under (d) -- [internal routine used within Markov relation routines]
--   sortdeps (Ds) -- [internal routine used within Markov relation routines]
--   normalizeStmt (D) -- [internal routine used within Markov relation routines]
--   minimize (Ds) -- [internal routine used within Markov relation routines]
--   removeRedundants (Ds) -- [internal routine used within Markov relation routines]
--
--  Markov Rings: 
--   markovRing (sequence d)
--   marginMap(R,i) : R --> R
--   hideMap(R,i) : R --> S
--
--  Markov Ideals:
--   markovMatrices (Ring R, Digraph G, List S)  -- S is a list of independence statements
--   markovIdeal (Ring R, Digraph G, List S)  -- S is a list of independence statements
--   cartesian -- [internal routine used in MarkovMatrices and MarkovIdeal]
--   possibleValues -- [internal routine used in MarkovMatrices and MarkovIdeal]
--   prob -- [internal routine used in MarkovMatrices and MarkovIdeal]
--   getPositionofVertices (Digraph G, list D) -- [internal routine]
--   
--  Gaussian directed acyclic graphs:
--   gaussRing (Integer n)
--   gaussRing (Digraph G)
--   covMatrix (Ring R)
--   covMatrix (Ring R, Digraph G)
--   gaussMinors (Digraph G, Matrix M, List S) -- [iternal routine]
--   gaussMatrix (Digraph G, Matrix M, List S)
--   gaussIdeal (Ring R, Digraph G, List S) 
--   gaussIdeal (Ring R, Digraph G) 
--   trekIdeal (Ring R, Digraph D)
--    
-- Gaussian mixed graphs (DAG + Bidirected)
--   pos -- [internal routine]
--   setToBinary -- [internal routine]
--   subsetsBetween -- [internal routine]
--   gaussRing (MixedGraph G)
--   covMatrix (Ring R, MixedGraph G)
--   diMatrix (Ring R, MixedGraph G)
--   biMatrix (Ring R, MixedGraph G)
--   gaussParam (Ring R, MixedGraph G)
--   identify (Ring R, MixedGraph G)
--   trekSeparation (MixedGraph G)
--   trekIdeal (Ring R, MixedGraph G, List L)
--   trekIdeal (Ring R, MixedGraph G)
--
------------------------------------------

export {pairMarkovStmts, 
        localMarkovStmts, 
	globalMarkovStmts, 
        markovRing, 
	marginMap, 
	hideMap, 
	markovMatrices, 
	markovIdeal,
        gaussRing, 
	gaussMatrix, 
	gaussIdeal, 
	trekIdeal, 
        Coefficients, 
	VariableName,
	covMatrix,
	diMatrix,
	biMatrix,
	gaussParam,
	gaussParamSimple,
        identify,
	trekSeparation} 
     
needsPackage "Graphs"




--------------------------
--   Markov relations   --
--------------------------

pairMarkovStmts = method()
pairMarkovStmts Digraph := List => (G) -> (
     -- given a digraph G, returns a list of triples {A,B,C}
     -- where A,B,C are disjoint sets, and for every vertex v
     -- and non-descendent w of v,
     -- {v, w, nondescendents(G,v) - w}
     removeRedundants flatten apply(vertices G, v -> (
	       ND := nondescendents(G,v);
	       W := ND - parents(G,v);
	       apply(toList W, w -> {set {v}, set{w}, ND - set{w}}))))


localMarkovStmts = method()			 
localMarkovStmts Digraph := List =>  (G) -> (
     -- Given a digraph G, return a list of triples {A,B,C}
     -- of the form {v, nondescendents - parents, parents}
     result := {};
     scan(vertices G, v -> (
	       ND := nondescendents(G,v);
	       P := parents(G,v);
	       if #(ND - P) > 0 then
	         result = append(result,{set{v}, ND - P, P})));
     removeRedundants result)


globalMarkovStmts = method()
globalMarkovStmts Digraph := List => (G) -> (
     -- Given a graph G, return a complete list of triples {A,B,C}
     -- so that A and B are d-separated by C (in the graph G).
     -- If G is large, this should maybe be rewritten so that
     -- one huge list of subsets is not made all at once
     V := vertices G;
     result := {};
     AX := subsets V;
     AX = drop(AX,1); -- drop the empty set
     AX = drop(AX,-1); -- drop the entire set
     scan(AX, A -> (
	       A = set A;
	       Acomplement := toList(set V - A);
	       CX := subsets Acomplement;
	       CX = drop(CX,-1); -- we don't want C to be the entire complement
	       scan(CX, C -> (
			 C = set C;
			 B := bayesBall(A,C,G);
			 if #B > 0 then (
			      B1 := {A,B,C};
			      if all(result, B2 -> not equivStmts(B1,B2))
			      then 
			          result = append(result, {A,B,C});
	       )))));
     removeRedundants result
     )

--------------------------
-- Bayes ball algorithm --
--------------------------

bayesBall = (A,C,G) -> (
     -- A is a set in 1..n (n = #G)
     -- C is a set in 1..n (the "blocking set")
     -- G is a DAG
     -- Returns the subset B of 1..n which is
     --   independent of A given C.
     -- The algorithm is the Bayes Ball algorithm,
     -- as implemented by Luis Garcia-Puente, after
     -- the paper of Ross Schlacter
     --
     V := vertices G;
     -- DEVELOPMENT NOTES: 
     -- 
     visited := new MutableHashTable from apply(V, k-> k=>false);
     blocked :=  new MutableHashTable from apply(V, k-> k=>false);
     up :=  new MutableHashTable from apply(V, k-> k=>false);
     down := new MutableHashTable from apply(V, k-> k=>false);
     top :=  new MutableHashTable from apply(V, k-> k=>false);
     bottom := new MutableHashTable from apply(V, k-> k=>false);
     vqueue := toList A; -- sort toList A
     -- Now initialize vqueue, set blocked
     scan(vqueue, a -> up#a = true);
     scan(toList C, c -> blocked#c = true);
     local pa;
     local ch;
     while #vqueue > 0 do (
	  v := vqueue#-1;
	  vqueue = drop(vqueue,-1);
	  visited#v = true;
	  if not blocked#v and up#v
	  then (
	       if not top#v then (
		    top#v = true;
		    pa = toList parents(G,v);
		    scan(pa, i -> up#i = true);
		    vqueue = join(vqueue,pa);
		    );
	       if not bottom#v then (
		    bottom#v = true;
		    ch = toList children(G,v);
		    scan(ch, i -> down#i = true);
		    vqueue = join(vqueue,ch);
		    );
	       );
	  if down#v
	  then (
	       if blocked#v and not top#v then (
		    top#v = true;
		    pa = toList parents(G,v);
		    scan(pa, i -> up#i = true);
		    vqueue = join(vqueue,pa);
		    );
	       if not blocked#v and not bottom#v then (
		    bottom#v = true;
		    ch = toList children(G,v);
		    scan(ch, i -> down#i = true);
		    vqueue = join(vqueue,ch);
		    );
	       );
	  ); -- while loop
     set toList select(V, i -> not blocked#i and not bottom#i)     
     )


------------------------------------------------------------------
-- Removing redundant statements:                               --
-- called from local, global, and pairwise Markov methods.      --
------------------------------------------------------------------

-- An independent statement is a list {A,B,C}
-- where A,B,C are (disjoint) subsets of labels for nodes in the graph.
-- It should be interpreted as: A independent of B given C.
-- A dependency list is a list of dependencies.

-- We have several simple routines to remove
-- the most obvious redundant elements, 
-- but a more serious attempt to remove dependencies could be made.

-- If S and T represent exactly the same dependency, return true.
 
-- check for symmetry:
equivStmts = (S,T) -> S#2 === T#2 and set{S#0,S#1} === set{T#0,T#1} 

-- More serious removal of redundancies.  This was taken from MES's indeps.m2:
setit = (d) -> {set{d#0,d#1},d#2}

under = (d) -> (
           d01 := toList d_0;
           d0 := toList d01_0;
           d1 := toList d01_1;
           d2 := toList d_1;
           e0 := subsets d0;
           e1 := subsets d1;
           z1 := flatten apply(e0, x -> apply(e1, y -> (
      		    {set{d01_0 - set x, d01_1 - set y}, set x + set y +  d_1})));-- see comment at removeRedundants
           z2 := flatten apply(e0, x -> apply(e1, y -> (
      		    {set{d01_0 - set x, d01_1 - set y},  d_1})));-- see comment at removeRedundants
           z := join(z1,z2);
           z = select(z, z0 -> not member(set{}, z0_0));
           set z
           )

sortdeps = Ds -> (
     -- input: ds
     -- first make list where each element is {-a*b, set{A,B}, set C}
     -- sort the list
     -- remove the first element
     i := 0;
     ds := apply(Ds, d -> (x := toList d#0; i=i+1; { - #x#0 * #x#1, i, d#0, d#1}));
     ds = sort ds;
     apply(ds, d -> {d#2, d#3})
     )

normalizeStmt = (D) -> (
     -- D has the form: {set{set{A},set{B}},set{C}}
     -- output is {A,B,C}, where A,B,C are sorted in increasing order
     --  and A#0 < B#0
     D0 := sort apply(toList(D#0), x -> sort toList x);
     D1 := toList(D#1);
     {D0#0, D0#1, D1}
     )

minimize = (Ds) -> (
     -- each element of Ds should be a list {A,B,C}
     answer := {};
     -- step 1: first make the first two elements of each set a set
     Ds = Ds/setit;
     while #Ds > 0 do (
	  Ds = sortdeps Ds;
	  f := Ds_0;
	  funder := under f;
	  answer = append(answer, f);
	  Ds = set Ds - funder;
	  Ds = toList Ds;
	  );
     apply(answer, normalizeStmt))

removeRedundants = (Ds) -> (
     -- Ds is a list of triples of sets {A,B,C}
     -- test1: returns true if D1 can be removed
     -- Return a sublist of Ds which removes any 
     -- that test1 declares not necessary.
     --**CAVEAT: this works just fine when used internally, e.g. from localMarkovStmts. 
     --  However, if we export it and try to use it, there is a problem: we seem to be 
     --  attempting to add a List to a Set in 2 lines of "under".
     test1 := (D1,D2) -> (D1_2 === D2_2 and 
                          ((isSubset(D1_0, D2_0) and isSubset(D1_1, D2_1))
	               or (isSubset(D1_1, D2_0) and isSubset(D1_0, D2_1))));
     -- first remove non-unique elements, if any
     Ds = apply(Ds, d -> {set{d#0,d#1}, d#2});
     Ds = unique Ds;
     Ds = apply(Ds, d -> append(toList(d#0), d#1));
     c := toList select(0..#Ds-1, i -> (
	       a := Ds_i;
	       D0 := drop(Ds,{i,i});
	       all(D0, b -> not test1(a,b))));
     minimize(Ds_c))

-------------------
-- Markov rings ---
-------------------
markov = local markov
markovVariables = local markovVariables
     
markovRingList := new MutableHashTable;
-- the hashtable is indexed by the sequence d, the coefficient ring kk, and the variable name p.
-- in principle, we can assign different names for the ring variable. 
-- But this is still not yet fully implemented in 
-- marginMap, hideMap, and prob.
markovRing = method(Dispatch=>Thing, Options=>{Coefficients=>QQ,VariableName=>getSymbol "p"})
markovRing Sequence := Ring => opts -> d -> (
     -- d should be a sequence of integers di >= 1
     if any(d, di -> not instance(di,ZZ) or di <= 0)
     then error "useMarkovRing expected positive integers";
     kk := opts.Coefficients;
     p := opts.VariableName;
     if (not markovRingList#?(d,kk,toString p)) then (
     	  start := (#d):1;
	  vlist := start .. d;
	  R := kk(monoid [p_start .. p_d, MonomialSize=>16]);
	  markovRingList#(d,kk,toString p) = R;
	  H := new HashTable from apply(#vlist, i -> vlist#i => R_i);
	  R.markovVariables = H;
	  -- markovRingList#(d,kk,toString p) = kk(monoid [p_start .. p_d]); -- does not work
     	  markovRingList#(d,kk,toString p).markov = d;);
     markovRingList#(d,kk,toString p))

  --------------
  -- marginMap
  -- Return the ring map F : R --> R such that
  --   F p_(u1,u2,..., +, ,un) = p_(u1,u2,..., 1, ,un)
  -- and
  --   F p_(u1,u2,..., j, ,un) = p_(u1,u2,..., j, ,un), for j >= 2.
  --------------

marginMap = method()
marginMap(ZZ,Ring) := RingMap => (v,R) -> (
     -- R should be a Markov ring
     v = v-1;
     d := R.markov;
     -- CAVEAT: The following line does not work as intended, 
     -- it gives the following error
     -- no method for binary operator - applied to objects
     -- p_1,1  (of class IndexedVariable)
     -- p := R.variable;
     -- use R; -- Dan suggested to delete this line
     p := i -> R.markovVariables#i;
     F := toList apply(((#d):1) .. d, i -> (
	       if i#v > 1 then p i
	       else (
		    i0 := drop(i,1);
		    p i - sum(apply(toList(2..d#v), j -> (
			      newi := join(take(i,v), {j}, take(i,v-#d+1));
			      p newi))))));
     map(R,R,F))

 --------------
 -- hideMap
 --------------

hideMap = method()
hideMap(ZZ,Ring) := RingMap => (v,A) -> (
     -- creates a ring map inclusion F : S --> A.
     v = v-1;
     R := ring presentation A;
     p := i -> R.markovVariables#i;
     d := R.markov;
     e := drop(d, {v,v});
     S := markovRing e;
     dv := d#v;
     -- use A; -- Dan suggested to delete this line
     -- same problem with p_newi if we change the name of the ring variable
     F := toList apply(((#e):1) .. e, i -> (
	       sum(apply(toList(1..dv), j -> (
			      newi := join(take(i,v), {j}, take(i,v-#d+1));
			      p newi)))));
     map(A,S,F))

-------------------
-- Markov ideals --
-------------------

-- the following function retrieves the position of the vertices in the graph G
-- for all vertices contained in the list S
getPositionOfVertices := (G,S) -> (
     --apply(S, v -> position(sort vertices G, k-> k===v)) --sort to be left here or not??-Shaowei/Sonja (see wiki)
     apply(S, w -> position(vertices G, v -> v===w)))

markovMatrices = method()
markovMatrices(Ring,Digraph,List) := (R,G,Stmts) -> (
     -- R should be a markovRing, G a digraph 
     -- and Stmts is a list of
     -- independence statements
     d := R.markov;
     flatten apply(Stmts, stmt -> (
     	       Avals := possibleValues(d,getPositionOfVertices(G,stmt#0)); 
     	       Bvals := possibleValues(d,getPositionOfVertices(G,stmt#1)); 
     	       Cvals := possibleValues(d,getPositionOfVertices(G,stmt#2)); 
     	       apply(Cvals, c -> (
                  matrix apply(Avals, 
		       a -> apply(Bvals, b -> (
				 e := toSequence(toList a + toList b + toList c);
		      		 prob(R,e))))))))
     )

markovIdeal = method()
markovIdeal(Ring,Digraph,List) := (R,G,Stmts) -> (
     -- R should be a markovRing, G a digraph
     -- and Stmts is a list of independent statements
     -- markovIdeal computes the ideal associated to the 
     -- list of independent statements Stmts
     M := markovMatrices(R,G,Stmts);
     sum apply(M, m -> minors(2,m))
     )

-------------------------------------------------------
-- Constructing the ideal of a independence relation --/tmp/M2-1663-1___Graphical__Models.m2
-------------------------------------------------------

-- NOTE: ALL THE FUNCTIONS BELOW ARE DECLARED GLOBAL INSTEAD OF LOCAL
-- FOR THE REASON THAT LOCAL DEFINITIONS WOULD INEXPLICABLY 
-- CREATE ERRORS.
     
-- cartesian ({d_1,...,d_n}) returns the cartesian product 
-- of {0,...,d_1-1} x ... x {0,...,d_n-1}
cartesian = (L) -> (
     if #L == 1 then 
	return toList apply (L#0, e -> 1:e);
     L0 := L#0;
     Lrest := drop (L,1);
     C := cartesian Lrest;
     flatten apply (L0, s -> apply (C, c -> prepend (s,c))))

-- possibleValues ((d_1,...,d_n),A) returns the cartesian product 
-- of all d_i's such that the vertex i is a member of the list A
-- it assumes that the list A is a list of integers.
possibleValues = (d,A) ->
     cartesian (toList apply(0..#d-1, i -> 
	       if member(i,A) 
	       then toList(1..d#i) 
	       else {0}))
     
-- prob((d_1,...,d_n),(s_1,dots,s_n))
-- this function assumes that R is a markovRing
prob = (R,s) -> (
     d := R.markov;
     p := i -> R.markovVariables#i;
     L := cartesian toList apply (#d, i -> 
	   if s#i === 0 
	   then toList(1..d#i) 
	   else {s#i});
     sum apply (L, v -> p v))

-----------------------------------------
-- Gaussian directed acyclic graphs    --
-----------------------------------------

gaussVariables = local gaussVariables

-- gaussRingList still not fully implemented
gaussRingList := new MutableHashTable;

gaussRing = method(Options=>{Coefficients=>QQ, VariableName=>{getSymbol "s",getSymbol "l",getSymbol "p"}})
gaussRing ZZ :=  Ring => opts -> (n) -> (
     -- s_{1,2} is the (1,2) entry in the covariance matrix.
     -- this assumes r.v.'s are labeled by integers.
     x := if instance(opts.VariableName,Symbol) then opts.VariableName else opts.VariableName#0;
     kk := opts.Coefficients;
     w := flatten toList apply(1..n, i -> toList apply(i..n, j -> (i,j)));
     v := apply (w, ij -> x_ij);
     -- xsR := kk[v, MonomialSize=>16];
     R := kk(monoid [v, MonomialSize=>16]);
     R#gaussRing = n;
     H := new HashTable from apply(#w, i -> w#i => R_i); 
     R.gaussVariables = H;
     R
     )
     -- we want to be able to do s_{a,b} for example:

gaussRing Digraph :=  Ring => opts -> (G) -> (
     -- Luis Garcia: Who wrote the 4 lines below?
     -- I want the input to be the Digraph G, 
     -- and I am just going to read off the list of labels from the vertices.
     -- This is done to avoid any ordering confusion. 
     -- DO NOT make an option for inputting list of labels!
     x := if instance(opts.VariableName,Symbol) then opts.VariableName else opts.VariableName#0;
     kk := opts.Coefficients;
     vv := vertices G; -- sort vertices G
     w := delete(null, flatten apply(vv, i -> apply(vv, j -> if pos(vv,i)>pos(vv,j) then null else (i,j))));
     v := apply (w, ij -> x_ij);
     -- xsR := kk[v, MonomialSize=>16];
     R := kk(monoid [v, MonomialSize=>16]);
     R#gaussRing = #vv;
     H := new HashTable from apply(#w, i -> w#i => R_i); 
     R.gaussVariables = H;
     R
     )

-- Shaowei 9/15: old version of gaussRing
-- gaussRing Digraph := opts -> (G) -> (
     --I want the input to be the Digraph G, 
     --and I'm just gonna read off the list of labels from the vertices.
     -- This is done to avoid any ordering confusion. 
     -- DO NOT make an option for inputting list of labels!
--     x := opts.VariableName;
--     kk := opts.Coefficients;
--     v := flatten apply(vertices G, i -> apply(vertices G, j -> x_(i,j)));
--     R := kk[v, MonomialSize=>16];
--     R#gaussRing = #vertices G;
--     R
--     )

covMatrix = method()
covMatrix(Ring) := Matrix => (R) -> (
       n := R#gaussRing; 
       genericSymmetricMatrix(R,n))
covMatrix(Ring,Digraph) := Matrix => (R,g) -> covMatrix R

gaussMinors = method()
--gaussMinors(Matrix,List) := (M,D) -> (
--     -- DO WE LEAVE THIS? WHERE WE DO NOT FORCE THE USER TO PASS THE DIGRAPH G???
--     -- M should be an n by n symmetric matrix, D mentions variables 1..n (at most)
--     -- the list D is a statement A,B,C. 
--     -- THIS CODE BELOW ASSUMES LABLES ARE 1..N, BUT NOW THEY CAN BE else
--     rows := join(D#0, D#2); --a union c
--     rows = rows/(i -> i-1); 
--     cols := join(D#1, D#2); --b union c
--     cols = cols/(i -> i-1);
--     M1 = submatrix(M,rows,cols);
--     minors(#D#2 + 1, M1)
--     )
gaussMinors(Digraph,Matrix,List) :=  Ideal => (G,M,Stmt) -> (
     -- M should be an n by n symmetric matrix, Stmts mentions variables 1..n (at most)
     -- the list Stmt is one statement {A,B,C}.
     -- this function is NOT exported; it is called from gaussIdeal!
     -- This function does not work if called directly but it works within gaussIdeal!!!
     rows := join(getPositionOfVertices(G,Stmt#0), getPositionOfVertices(G,Stmt#2)); 
     cols := join(getPositionOfVertices(G,Stmt#1), getPositionOfVertices(G,Stmt#2));  
     M1 := submatrix(M,rows,cols);
     minors(#Stmt#2+1,M1)     
     )
///EXAMPLE:
G = digraph {{a,{b,c}}, {b,{c,d}}, {c,{}}, {d,{}}}
R = gaussRing G
describe R --is a Poly ring!!
M = covMatrix R;
peek M
submatrix(M,{0},{1})
Stmts = pairMarkovStmts G
D=Stmts_0
gaussMinors(G,M,D)
///

gaussIdeal = method()
gaussIdeal(Ring, Digraph, List) := Ideal =>  (R,G,Stmts) -> (
     -- for each statement, we take a set of minors
     -- Stmts = global markov statements of G
     -- R = gaussRing of G
     --NOTE we force the user to give us the digraph G due to flexibility in labeling!!
     if not R#?gaussRing then error "expected a ring created with gaussRing";
     M := covMatrix R;
     sum apply(Stmts, D -> gaussMinors(G,M,D))     
     )

--in case the global Stmts are not computed already :
gaussIdeal(Ring,Digraph) := Ideal =>  (R,G) -> gaussIdeal(R,G,globalMarkovStmts G)

--gaussIdeal(Ring, List) := (R,Stmts) -> (
--     -- for each statement, we take a set of minors
--     if not R#?gaussRing then error "expected a ring created with gaussRing";
--     M = genericSymmetricMatrix(R, R#gaussRing);
--     sum apply(Stmts, D -> gaussMinors(M,D))     
--     )
--gaussIdeal(Ring,Digraph) := (R,G) -> gaussIdeal(R,globalMarkovStmts G)


--in case user just wants to see the matrices we are taking minors of, here they are:
gaussMatrix = method()
gaussMatrix(Digraph,Matrix,List) := List =>  (G,M,s) -> (
     -- M should be an n by n symmetric matrix, Stmts mentions variables 1..n (at most)
     -- the list s is a statement of the form {A,B,C}.
     	       rows := join(getPositionOfVertices(G,s#0), getPositionOfVertices(G,s#2));  --see 9/17 notes @getPositionOfVertices
     	       cols := join(getPositionOfVertices(G,s#1), getPositionOfVertices(G,s#2));  --see 9/17 notes @getPositionOfVertices
     	       submatrix(M,rows,cols)
     )

-- This is Luis's take but it still does not work correctly
-- gaussMatrices = method()
-- gaussMatrices(R,Digraph,List) := List =>  (R,G,S) -> (
--        apply(S, s -> (
-- 	       M := genericSymmetricMatrix(R, R#gaussRing);
--      	       rows := join(getPositionOfVertices(G,s#0), getPositionOfVertices(G,s#2));  
--      	       cols := join(getPositionOfVertices(G,s#1), getPositionOfVertices(G,s#2));  
--      	       submatrix(M,rows,cols)))
--      )
-- gaussMatrices(Ring,Digraph) := List =>  (R,G) -> gaussMatrices(R,G,globalMarkovStmts G)


-- THE FOLLOWING NEEDS TO BE COPIED TO THE GAUSSIAN STUFF:
trekIdeal = method()
trekIdeal(Ring, Digraph) := Ideal => (R,G) -> (
     --for a Digraph, the method is faster--so we just need to overload it for a DAG. 
     --G = a Digraph (assumed DAG)
     --R = the gaussRing of G
     v := vertices G;
     n := #v; 
     P := toList apply(v, i -> toList parents(G,i));
     nv := max(P/(p->#p));
     t := local t;
     S := (coefficientRing R)[generators R,t_1 .. t_nv];
     newvars := toList apply(1..nv, i -> t_i);
     I := trim ideal(0_S);
     s := applyValues(R.gaussVariables,i->substitute(i,S));
     sp := (i,j) -> if pos(v,i) > pos(v,j) then s#(j,i) else s#(i,j);
     -- need the vertices to be sorted topologically!
     for i from 0 to n-2 do (
     	  J := ideal apply(0..i, j -> s#(v#j,v#(i+1))
     	     	              - sum apply(#P#i, k ->(print({S_(k+numgens R),promote(sp(v#j,P#i#k),S)}); print(class sp(v#j,P#i#k));t_(k+1) * sp(v#j,P#i#k))));
     	  I = eliminate(newvars, I + J);
     	  );
     substitute(I,R)
     )

------------------------------
-- Gaussian mixed graphs    --
------------------------------



-- INTERNAL FUNCTIONS --

-- returns the position in list h of  x
pos = (h, x) -> position(h, i->i===x)

-- takes a list A, and a sublist B of A, and converts the membership sequence of 0's and 1's of elements of B in A to binary
setToBinary = (A,B) -> sum(toList apply(0..#A-1, i->2^i*(if (set B)#?(A#i) then 1 else 0)))

-- returns all subsets of B which contain A
subsetsBetween = (A,B) -> apply(subsets ((set B) - A), i->toList (i+set A))


-- RINGS AND MATRICES --

-- makes a ring of parameters, l_(i,j) for all vertices i,j of a digraph G, and p_(i,j) for i<j,
-- and of the entries of the covariance matrix s_(i,j)
-- later, given the edges, we will set some of these parameters to zero
-- the reason we included all the other variables is so that it is easy to make the corresponding matrices
gaussRing MixedGraph := Ring => opts -> (g) -> (
     G := graph collateVertices g;
     dd := graph G#Digraph;
     bb := graph G#Bigraph;
     vv := vertices g;
     s := opts.VariableName#0;
     l := opts.VariableName#1;
     p := opts.VariableName#2;
     kk := opts.Coefficients;
     sL := delete(null, flatten apply(vv, x-> apply(vv, y->if pos(vv,x)>pos(vv,y) then null else s_(x,y))));
     lL := delete(null, flatten apply(vv, x-> apply(toList dd#x, y->l_(x,y))));	 
     pL := join(apply(vv, i->p_(i,i)),delete(null, flatten apply(vv, x-> apply(toList bb#x, y->if pos(vv,x)>pos(vv,y) then null else p_(x,y)))));
     m := #lL+#pL;
     R := kk[lL,pL,sL,MonomialOrder => Eliminate m];
     R#gaussRing = {#vv,s,l,p};
     R
     )

covMatrix (Ring,MixedGraph) := (R,g) -> (
     vv := vertices g;
     n := R#gaussRing#0;
     s := value R#gaussRing#1;
     SM := mutableMatrix(R,n,n);
     scan(vv,i->scan(vv, j->SM_(pos(vv,i),pos(vv,j))=if pos(vv,i)<pos(vv,j) then s_(i,j) else s_(j,i)));
     matrix SM) 

diMatrix = method()
diMatrix (Ring,MixedGraph) := Matrix =>  (R,g) -> (
     G := graph collateVertices g;
     dd := graph G#Digraph;
     vv := vertices g;
     n := R#gaussRing#0;
     l := value R#gaussRing#2;
     LM := mutableMatrix(R,n,n);
     scan(vv,i->scan(toList dd#i, j->LM_(pos(vv,i),pos(vv,j))=l_(i,j)));
     matrix LM) 

biMatrix = method()
biMatrix (Ring,MixedGraph) := Matrix =>  (R,g) -> (
     G := graph collateVertices g;
     bb := graph G#Bigraph;
     vv := vertices g;
     n := R#gaussRing#0;
     p := value R#gaussRing#3;
     PM := mutableMatrix(R,n,n);
     scan(vv,i->PM_(pos(vv,i),pos(vv,i))=p_(i,i));
     scan(vv,i->scan(toList bb#i, j->PM_(pos(vv,i),pos(vv,j))=if pos(vv,i)<pos(vv,j) then p_(i,j) else p_(j,i)));
     matrix PM) 

gaussParam = method()
gaussParam (Ring,MixedGraph) := Matrix => (R,g) -> (
     SM := covMatrix(R,g);    
     PM := biMatrix(R,g);     
     LM := diMatrix(R,g);
     
     -- equate \Sigma with (I-\Lambda)^{-T}\Phi(I-\Lambda)^{-1}
     Linv := inverse(1-matrix(LM));
     transpose(Linv)*matrix(PM)*Linv)

gaussParamSimple = method()
gaussParamSimple (Ring,MixedGraph) := Matrix => (R,g) -> (
     n := R#gaussRing#0;
     M := gaussParam(R,g);
     P := biMatrix(R,g);
     L := matrix {apply(n,i->P_(i,i)-M_(i,i)+1)};
     S := apply(n,i->P_(i,i)=>L_(0,i));
     scan(n,i->L=sub(L,S));
     sub(M,apply(n,i->P_(i,i)=>L_(0,i))))

-- IDENTIFIABILITY --

identify = method()
-- Input: a MixedGraph
-- Output: a hash table H where for each parameter t, H#t is the ideal of relations involving t and the entries of the covariance matrix.
identify (Ring,MixedGraph) := HashTable => (R,g) -> (
     -- form ideal of relations from this matrix equation
     J := ideal unique flatten entries (covMatrix(R,g)-gaussParam(R,g));
 	
     -- create hash table of relations between a particular parameter t and the entries of \Sigma 
     G := graph g;
     m := #edges(G#Digraph)+#edges(G#Bigraph)+#vertices(g);
     plvars := toList apply(0..m-1,i->(flatten entries vars R)#i);
     new HashTable from apply(plvars,t->{t,eliminate(delete(t,plvars),J)}))



-- CONDITIONAL INDEPENDENCE --

trekSeparation = method()
    -- Input: A mixed graph containing a directed graph and a bidirected graph.
    -- Output: A list L of lists {A,B,CA,CB}, where (CA,CB) trek separates A from B.
trekSeparation MixedGraph := List => (g) -> (
    G := graph collateVertices g;
    dd := graph G#Digraph;
    bb := graph G#Bigraph; 
    vv := vertices g;

    -- Construct canonical double DAG cdG associated to mixed graph G
    cdG:= digraph join(
      apply(vv,i->{(1,i),join(
        apply(toList parents(G#Digraph,i),j->(1,j)),
        {(2,i)}, apply(toList bb#i,j->(2,j)))}),
      apply(vv,i->{(2,i),apply(toList dd#i,j->(2,j))}));
    aVertices := apply(vv, i->(1,i));
    bVertices := apply(vv, i->(2,i));
    allVertices := aVertices|bVertices;
    
    statements := {};
    cdC0 := new MutableHashTable;
    cdC0#cache = new CacheTable from {};
    cdC0#graph = new MutableHashTable from apply(allVertices,i->{i,cdG#graph#i});
    cdC := new Digraph from cdC0;
    for CA in (subsets aVertices) do (
      for CB in (subsets bVertices) do (
	CAbin := setToBinary(aVertices,CA);
	CBbin := setToBinary(bVertices,CB);
	if CAbin <= CBbin then (
          C := CA|CB;
	  scan(allVertices,i->cdC#graph#i=cdG#graph#i);
          scan(C, i->scan(allVertices, j->(
			 cdC#graph#i=cdC#graph#i-{j};
			 cdC#graph#j=cdC#graph#j-{i};
			 )));
	  Alist := delete({},subsetsBetween(CA,aVertices));
          while #Alist > 0 do (
	    minA := first Alist;
	    pC := reachable(cdC,set minA);
	    A := toList ((pC*(set aVertices)) + set CA);
	    Alist = Alist - (set subsetsBetween(minA,A));
	    B := toList ((set bVertices) - pC);
	    
	    -- remove redundant statements
	    if #CA+#CB < min{#A,#B} then (
	    if not ((CAbin==CBbin) and (setToBinary(aVertices,A) > setToBinary(bVertices,B))) then (
	      nS := {apply(A,i->i#1),apply(B,i->i#1),apply(CA,i->i#1),apply(CB,i->i#1)};
	      appendnS := true;
	      statements = select(statements, cS->
		if cS#0===nS#0 and cS#1===nS#1 then (
		  if isSubset(cS#2,nS#2) and isSubset(cS#3,nS#3) then 
		    (appendnS = false; true)
		  else if isSubset(nS#2,cS#2) and isSubset(nS#3,cS#3) then 
		    false
		  else
		    true)
		else if cS#2===nS#2 and cS#3===nS#3 then (
		  if isSubset(cS#0,nS#0) and isSubset(cS#1,nS#1) then 
		    false
		  else if isSubset(nS#0,cS#0) and isSubset(nS#1,cS#1) then 
		    (appendnS = false; true)
		  else
		    true)		  
		else true		
	      );
              if appendnS then statements = append(statements, nS);
            ););
     	  );
        );
      );
    );
    statements
)

trekIdeal (Ring,MixedGraph,List) := Ideal => (R,g,Stmts) -> (
     vv := vertices g;
     SM := covMatrix(R,g);	
     sum apply(Stmts,s->minors(#s#2+#s#3+1, submatrix(SM,apply(s#0,x->pos(vv,x)),apply(s#1,x->pos(vv,x))))))

trekIdeal (Ring,MixedGraph) := Ideal => (R,g) -> trekIdeal(R,g,trekSeparation g)





----------------------
-- Parameterization --
----------------------

---- We need this for both directed and undirected graphs. 

----  parameterizations and for toric varieties the corresponding matrix. 
----  In the case of toric varieties the matrix is easy.  Here is the code, 
----  commented out to be used later when we are ready. 
---- 
----  toAMatrix = method()
----  toAMatrix List := Matrix => (M) -> (
----      if any(M,isMonomial)
----         then error "this parameterization does not correspond to a toric ideal." 
----         else (
----              Mexp := apply(M, exponents);
----              transpose matrix apply(Mexp, flatten)))
----
---- isMonomial = method()
---- isMonomial RingElement := Boolean => (m) -> (
----      termList := terms m;
----      if #termList == 1 then true else false)

---- isMonomial works well as long as m is actually a polynomial or monomial and not 
---- an element of ZZ, QQ, RR, etc.

--------------------
-- Documentation  --
--------------------

beginDocumentation()

doc ///
  Key
    GraphicalModels
  Headline
    A package for discrete and Gaussian statistical graphical models 
  Description
    Text
      This package extends Markov.m2. It is used to construct ideals corresponding to discrete graphical models,
      as described in several places, including the paper: Luis David Garcia, Michael Stillman and Bernd Sturmfels,
      "The algebraic geometry of Bayesian networks", J. Symbolic Comput., 39(3-4):331–355, 2005.
  
      The package also constructs ideals of Gaussian Bayesian networks and Gaussian graphical models 
      (graphs containing both directed and bidirected edges), as described in the papers:
      Seth Sullivant, "Algebraic geometry of Gaussian Bayesian networks", Adv. in Appl. Math. 40 (2008), no. 4, 482--513;
      Seth Sullivant, Kelli Talaska and Jan Draisma, "Trek separation for Gaussian graphical models", 
      Annals of Statistics 38 no.3 (2010) 1665--1685. 
      
      Further, the package contains procedures to solve the identifiability problem for 
      Gaussian graphical models as described in the paper: 
      Luis D. Garcia-Puente, Sarah Spielvogel and Seth Sullivant, "Identifying causal effects with computer algebra", 
      Proceedings of the $26^{th}$ Conference of Uncertainty in Artificial Intelligence.
      
      Here is a typical use of this package.  We create the ideal in 16 variables whose zero set 
      represents the probability distributions on four binary random variables which satisfy the
      conditional independence statements coming from the "diamond" graph d --> c,b --> a.
    Example
       G = digraph  {{a,{}},{b,{a}},{c,{a}},{d,{b,c}}}
       R = markovRing (2,2,2,2)
       S = globalMarkovStmts G 
       I = markovIdeal(R,G,S)
       netList pack(2,I_*)
    Text
      Sometimes an ideal can be simplified by changing variables.  Very often, 
      by using @TO marginMap@
      such ideals can be transformed to binomial ideals.  This is the case here.
    Example
       F = marginMap(1,R)
       I = F I
       netList pack(2,I_*)
    Text
      This ideal has 5 primary components.  The first component is the one that has statistical significance.
      It is the defining ideal of the variety parameterized by the 
      the factorization of the probability distributions 
      according to the graph G. The remaining components lie on the boundary of the simplex
      and are still poorly understood.
    Example  
      netList primaryDecomposition I 
    Text
      The following example illustrates the caveat below.
    Example
       H = digraph {{d,{b,a}},{c,{}},{b,{c}},{a,{c}}}
       T = globalMarkovStmts H  
       J = markovIdeal(R,H,T);
       netList pack(2,J_*)
       F = marginMap(3,R);
       J = F J;
       netList pack(2,J_*)
    Text
      Note that the graph $H$ is isomorphic to $G$, we have just relabeled the vertices. 
      Observe that the vertices of $H$ are stored
      in lexicographic order. Also note that the this graph isomorphism lifts to an isomorphism of ideals.     
  Caveat
     This package requires Graphs.m2, as a consequence it can do computations with graphs
     whose vertices are not necessarily labeled by integers. This could potentially create some confusion about what does
     $p_{i_1i_2\cdots i_n}$ mean. The package orders the vertices lexicographically, so 
     $p_{i_1i_2\cdots i_n} = p(X_1 = i_1, X_2 = i_2, \dots, X_n = i_n)$ where the labels
     $X_1,X_2,\dots,X_n$ have been ordered lexicographically. Therefore, the user is encouraged
     to label the vertices in a consistent way (all numbers, or all letters, etc).
///;


doc ///
  Key
    pairMarkovStmts
    (pairMarkovStmts,Digraph)
  Headline
    pairwise Markov statements for a directed graph
  Usage
    pairMarkovStmts G
  Inputs
    G:Digraph 
  Outputs
    L:List
      whose entries are triples {A,B,C} representing pairwise Markov  conditional independence statements of the form
      ''A is independent of B given C'' that hold for G.
  Description
    Text
      Given a directed graph G, pairwise Markov statements are statements of the form \{v,w,nondescendents(G,v)-w\} 
      for each vertex v of G. In other words, for every vertex v of G and all non-descendents w of v, 
      v is independent of w given all other non-descendents. 
      
      For example, for the digraph D on $4$ vertices with edges a-->b, a-->c, b-->c, and b-->d, 
      we get the following pairwise Markov statements:
    Example
      D = digraph {{a,{b,c}}, {b,{c,d}}, {c,{}}, {d,{}}}
      L = pairMarkovStmts D
    Text
      Note that the method displays only non-redundant statements.
  SeeAlso
    localMarkovStmts 
    globalMarkovStmts
///


doc ///
  Key
    localMarkovStmts
    (localMarkovStmts,Digraph)
  Headline
    local Markov statements for a directed graph
  Usage
    localMarkovStmts G
  Inputs
    G:Digraph 
  Outputs
    L:List
      whose entries are triples {A,B,C} representing local Markov  conditional independence statements of the form
      ''A is independent of B given C'' that hold for G.
  Description
    Text
      Given a directed graph G, local Markov statements are of the form
      \{$v$, nondescendents($v$) - parents($v$), parents($v$)\} .
      That is, 
      every vertex $v$ of G is independent of its nondescendents (excluding parents) given the parents. 
      
      For example, for the digraph D on 4 vertices with edges a-->b, a-->c, b-->c, and b-->d, 
      we get the following local Markov statements:
    Example
      D = digraph {{a,{b,c}}, {b,{c,d}}, {c,{}}, {d,{}}}
      L = localMarkovStmts D
    Text
      Note that the method displays only non-redundant statements.
  SeeAlso
    pairMarkovStmts
    globalMarkovStmts
///

doc ///
  Key
    globalMarkovStmts
    (globalMarkovStmts,Digraph)
  Headline
    global Markov statements for a directed graph
  Usage
    globalMarkovStmts G
  Inputs
    G:Digraph 
  Outputs
    L:List
      whose entries are triples {A,B,C} representing global Markov  conditional independence statements of the form
      ''A is independent of B given C'' that hold for G.
  Description
    Text
      Given a directed graph G, global Markov states that      
      A is independent of B given C for every triple of sets of vertices A, B, and C, 
      such that A and B are $d$-separated by C (in the graph G).\break

      {\bf add definition of d-separation criterion, and a reference!}\break
      
      For example, for the digraph D on 4 vertices with edges a-->b, a-->c, b-->c, and b-->d, 
      we get the following global Markov statements:
    Example
      D = digraph {{a,{b,c}}, {b,{c,d}}, {c,{}}, {d,{}}} -- L = globalMarkovStmts D --NEEDS TO BE UNCOMMENTED ONCE BAYESBALL IS FIXED!
    Text
      Note that the method displays only non-redundant statements.
  Caveat
    -- If G is large, this should maybe be rewritten so that
    -- one huge list of subsets is not made all at once
  SeeAlso
    localMarkovStmts
    pairMarkovStmts
///


doc ///
  Key
    marginMap
    (marginMap,ZZ,Ring)
  Headline
    marginalize the map on joint probabilities for discrete variables
  Usage
    phi = marginMap(i,R)
  Inputs
    i:ZZ
      the index of the variable to marginalize
    R:Ring
      a Markov ring
  Outputs
    phi:RingMap
      with coordinates....................
  Description
    Text
      Copying the description from the code:
      -- Return the ring map F : R --> R such that
      	  $ F p_{u1,u2,..., +, ,un} = p_{u1,u2,..., 1, ,un}$
       and
         $F p_{u1,u2,..., j, ,un} = p_{u1,u2,..., j, ,un}$, for $j\geq 2$.
    Example
      marginMap(2,markovRing(1,2)) --add more for example? to explain.
  SeeAlso
    hideMap
///

doc ///
  Key
    hideMap
    (hideMap,ZZ,Ring)
  Headline
    hide???marginalize the map on joint probabilities for discrete variables
  Usage
    phi = hideMap(i,R)
  Inputs
    i:ZZ
      the index of the variable to marginalize
    R:Ring
      a Markov ring
  Outputs
    phi:RingMap
      with coordinates....................
  Description
    Text
      what does this do? 
    Example
      marginMap(1,markovRing(2,2)) --add more for example? to explain.
  SeeAlso
    marginMap
///


doc ///
  Key
    markovRing
    (markovRing,Sequence)
    [markovRing, Coefficients, VariableName]
  Headline
    ring of probability distributions on several discrete random variables
  Usage
    markovRing(d) or markovRing(d,Coefficients=>Ring) or markovRing(d,Variable=>Symbol)
  Inputs
    d:Sequence
      with positive integer entries (d1,...,dr)
  Outputs
    R:Ring
      A polynomial ring with d1*d2*...*dr variables $p_{i_1,...,i_r}$,
      with each $i_j$ satisfying $1\leq i_j \leq d_j$.
  Consequences
    Item
      Information about this sequence of integers is placed into the ring, and is used 
      by other functions in this package.  Also, at most one ring for each such sequence
      is created: the results are cached.
  Description
    Text 
      The sequence $d$ represents the number of states each discrete random variable can take.
      For example, if there are four random variables with the following state space sizes
    Example
      d=(2,3,4,5)
    Text 
      the corresponding ring will have as variables all the possible joint 
      probability distributions for the four variables:
    Example
      R = markovRing d;
      numgens R
      R_0, R_1, R_119 --here are some of the variables in the ring
    Text
      If no coefficient choice is specified, the polynomial ring is created over the rationals. 
    Example
      coefficientRing R
    Text 
      If we prefer to have a different base field, the following command can be used:
    Example
      Rnew = markovRing (d,Coefficients=>CC); 
      coefficientRing Rnew
    Text
      We might prefer to give diferent names to our variables. The letter ''p'' suggests a joint probability, 
      but it might be useful to create a new ring where the variables have changed. This can easily be done
      with the following option:
    Example
      d=(1,2);
      markovRing (d,VariableName=>q);
      vars oo --here is the list of variables.
    Text
      The LIST OF FNS USING THIS FUNCTION SHOULD BE INSERTED AS WELL.
  SeeAlso
///

doc ///
  Key
    Coefficients
  Headline
    optional input to choose the base field
  Description
    Text
      Put {\tt Coefficients => r} for a choice of ring(field) r as an argument in 
      the function @TO markovRing@ or @TO gaussRing@ 
  SeeAlso
    markovRing
    gaussRing
///

doc ///
  Key
    VariableName
  Headline
    optional input to choose the letter for the variable name
  Description
    Text
      Put {\tt VariableName => s} for a choice of a symbol s as an argument in the function @TO markovRing@
  SeeAlso
    markovRing
    gaussRing
///


doc ///
  Key 
    gaussRing
    (gaussRing,ZZ)
    (gaussRing,Digraph)
    [gaussRing, Coefficients, VariableName]
  Headline
    ring of gaussian correlations on n random variables
  Usage
    R = gaussRing n or R = gaussRing G or gaussRing(d,Coefficients=>Ring) or gaussRing(d,Variable=>Symbol)
  Inputs
    n:ZZ
      the number of random variables
    G:Digraph
      an acyclic directed graph 
  Outputs
    R:Ring
      a ring with indeterminates $s_(i,j)$ for $1 \leq i \leq j \leq n$
  Description
    Text
      The routines  @TO gaussIdeal@ and @TO trekIdeal@ require that the ring      
      be created by this function.
    Example
      R = gaussRing 5;
      gens R
      covMatrix R
  SeeAlso
    gaussIdeal
    trekIdeal
///




doc ///
   Key
     gaussIdeal
     (gaussIdeal,Ring,Digraph)
     (gaussIdeal,Ring,Digraph,List)
   Headline
     correlation ideal of a Bayesian network of joint Gaussian variables
   Usage
     I = gaussIdeal(R,G) or I = gaussIdeal(R,G,S)
   Inputs
     R:Ring
       created with @TO gaussRing@
     G:Digraph
       an acyclic directed graph
     S:List
       a list of independence statements for the graph G
   Outputs
     I:Ideal
        in R, of the relations in the correlations of the random variables implied by the independence statements 
	of the graph G, or the list of independence statements G
   Description
     Text
       The ideal corresponding to a conditional independence statement {A,B,C} (where A,B,C,
       are disjoint lists of integers in the range 1..n (n is the number of random variables)
       is the #C+1 x #C+1 minors of the submatrix of the generic symmetric matrix M = (s_(i,j)), whose
       rows are in A union C, and whose columns are in B union C.  In general, this ideal need not be prime.
       
       These ideals were first written down by Seth Sullivant, in "Algebraic geometry of Gaussian Bayesian networks". 
       The routines in this package involving Gaussian variables are all based on that paper.
     Example
       R = gaussRing 5;
       G = digraph { {1,{2}}, {2,{3}}, {3,{4,5}},{4,{5}} } --(globalMarkovStmts G)/print; --J = gaussIdeal(R,G) --this is broken until globalMarkovStmts gets fixed!!!
     Text
       A list of independence statments (as for example returned by globalMarkovStmts)
       can be provided instead of a graph:
     Example
       S=pairMarkovStmts G --change to global!!!!
       I = gaussIdeal(R,G,S) --- {{{1,2},{4,5},{3}}, {{1},{2},{3,4,5}}}) ---THIS LIST OF STMTS IS AN OLD EXAMPLE. erase?
       codim I
   SeeAlso
     globalMarkovStmts
     localMarkovStmts
     gaussRing
     gaussMatrix
     trekIdeal
///

doc///
   Key
     gaussMatrix
     (gaussMatrix,Digraph,Matrix,List)
   Headline
     matrices whose minors form the ideal corresponding to a conditional independence statement s
   Usage
     mat = gaussMatrix(G,M,s)
   Inputs
     G:Digraph
       a directed acyclic graph
     M:Matrix
       an n by n symmetric matrix, where s mentions variables 1..n (at most)
     s:List
       a conditional independence statement that holds for the graph G
   Outputs
     mat:Matrix
       whose minors belong to the ideal corresponding to a conditional independence statement s.
   Description 
     Text
       In case user just wnats to see the mtces we are taking minors of, here they are:
     Example
       G = digraph { {1,{2}}, {2,{3}}, {3,{4,5}},{4,{5}} } ;
       Stmts = localMarkovStmts G;
       sta=Stmts_0 --take the first statement from the list
       R = gaussRing G; 
       M = covMatrix R;
       gaussMatrix(G,M,sta)
     Text
       In fact, we can see, at once, all matrices whose minors form the ideal @TO gaussIdeal@ of G:
     Example
       apply(Stmts, sta-> gaussMatrix(G,M,sta))
   SeeAlso
     gaussRing
     gaussIdeal
///

doc/// 
   Key
     markovIdeal
     (markovIdeal,Ring,Digraph,List) 
   Headline
     the ideal associated to the list of independence statements of the graph
   Usage
     I = markovIdeal(R,G,Statements)
   Inputs
     R:Ring
       which should a markovRing 
     G:Digraph
       directed acyclic graph
     Statements:List
       a list of independence statements that are true for the DAG G
   Outputs
     I:Ideal
       of R
   Description 
     Text
       This function computes the ideal of independence relations for the list of statements provided. 
       NEED TO INSERT THE DEFINITION OF WHAT THESE ARE !!!! 
     Example
       G = digraph { {1,{2,3}}, {2,{4}}, {3,{4}} } ;
       d = (4:2) -- we have four binary random variables
       R = markovRing d ;
       Statements = localMarkovStmts G
       I = markovIdeal ( R, G, Statements)
   SeeAlso
     markovRing
     markovMatrices
///

doc/// 
   Key
     markovMatrices
     (markovMatrices,Ring,Digraph,List) 
   Headline
     the matrices whose minors form the ideal associated to the list of independence statements of the graph
   Usage
     matrices = markovMatrices(R,G,Statements)
   Inputs
     R:Ring
       which should a markovRing 
     G:Digraph
       directed acyclic graph
     Statements:List
       a list of independence statements that are true for the DAG G
   Outputs
     matrices:List
       whose elements are instances of Matrix. Minors of these matrices form the independence ideal for statements.
   Description 
     Text
       This function gives the list of matrices whose minors form the ideal of independence relations for the list of statements provided. 
       NEED TO INSERT THE DEFINITION OF WHAT THESE ARE !!!! 
     Example
       G = digraph { {1,{2,3}}, {2,{4}}, {3,{4}} } ;
       d = (4:2) -- we have five binary random variables
       R = markovRing d ;
       Statements = localMarkovStmts G
       matrices = markovMatrices ( R, G, Statements)
   SeeAlso
     markovRing
     markovIdeal
///

doc/// 
   Key
     trekIdeal
     (trekIdeal,Ring,MixedGraph,List)
   Headline
     write me 
   Usage
     I = trekIdeal(R,G,L)
   Inputs
     R:Ring
       which should be a gaussRing???
     G:MixedGraph
       blabla
     L:List
       Independence statements that hold for G
   Outputs
     I:Ideal
       the trek separation ideal implied by statements S for the graph G
   Description 
     Text
       DEFINE THE TREK IDEAL HERE!!
     Example
       R=gaussRing 4 --- BLA BLA --- add thecall to trekIdeal to show how to use it!!
     Text
       ANOTHER COMMENT HERE!!
   SeeAlso
     trekSeparation
///

doc/// 
   Key
     trekSeparation
     (trekSeparation,MixedGraph)
   Headline
     write me 
   Usage
     trek = trekSeparation(G)
   Inputs
     G:MixedGraph
       blabla
   Outputs
     trek:List
        of lists {A,B,CA,CB}, where (CA,CB) trek separates A from B
   Description 
     Text
       DEFINE TREK SEPARATION HERE!!
     Example
       R=gaussRing 4 --- BLA BLA --- add thecall to trekIdeal to show how to use it!!
     Text
       ANOTHER COMMENT HERE!!
   SeeAlso
     trekIdeal
///





				     
--------------------------------------
--------------------------------------
end
--------------------------------------
--------------------------------------

--blank documentation node:
doc/// 
   Key
     gaussMatrix
     (gaussMatrix,Digraph,Matrix,List) 
   Headline
   Usage
   Inputs
   Outputs
   Description 
     Text
     Example
     Text
     Example
   SeeAlso
///


uninstallPackage "GraphicalModels"
restart
--installPackage("Graphs", UserMode=>true)
installPackage ("GraphicalModels", RemakeAllDocumentation => true, UserMode=>true)
viewHelp GraphicalModels
installPackage("GraphicalModels",UserMode=>true,DebuggingMode => true)




---- TESTS GO HERE! ------



--- OLD CODE THAT SHOULD BE REMOVED ----


restart
loadPackage "Markov"
installPackage "Markov"
G = makeGraph{{},{1},{1},{2,3},{2,3}}
S = globalMarkovStmts G

R = markovRing(2,2,2,2,2)
markovIdeal(R,S)

R = gaussRing(5)

M = genericSymmetricMatrix(R,5)
describe R
gaussMinors(M,S_0)
J = trim gaussIdeal(R,S)
J1 = ideal drop(flatten entries gens J,1)
res J1
support J1

globalMarkovStmts G
minimize oo

G = makeGraph{{2,3},{4},{4},{}}
G1 = makeGraph{{},{1},{1},{2,3}}
globalMarkovStmts G
globalMarkovStmts G1

G4 = {{},{1},{1},{2,3}}

restart
loadPackage "Markov"
G4 = makeGraph{{2,3},{4},{4},{}}
R = gaussRing 4
I = gaussTrekIdeal(R,G4)
J = gaussIdeal(R,G4)
I == J

G4 = makeGraph{{2,3},{4},{4,5},{},{}}

G = makeGraph{{3},{3,4},{4},{}}
R = gaussRing 4
I = gaussTrekIdeal(R,G)
J = gaussIdeal(R,G)
I == J


///
restart 
loadPackage"GraphicalModels"
G = digraph({{a,{b,c}},{b,{c,d}},{c,{}},{d,{}}})
convertToIntegers(G)
 ///   



load "/Users/mike/local/src/M2-mike/markov/dags5.m2"
D5s
D5s = apply(D5s, g -> (
	  G := reverse g;
	  G = apply(G, s -> sort apply(s, si -> 6-si));
	  G))
R = gaussRing 5
apply(D5s, g -> (
	  G := makeGraph g;
	  I := gaussTrekIdeal(R,G);
	  J := gaussIdeal(R,G);
	  if I != J then << "NOT EQUAL on " << g << endl;
	  I != J))

Gs = select(D5s, g -> (
	  G := makeGraph g;
	  I := gaussTrekIdeal(R,G);
	  J := gaussIdeal(R,G);
	  if I != J then << "NOT EQUAL on " << g << endl;
	  I != J))
Gs/print;
Gs = {
{{4}, {4}, {4, 5}, {5}, {}},
{{3, 5}, {3}, {4}, {5}, {}},
{{2, 4}, {4}, {4, 5}, {5}, {}},
{{2, 4}, {3, 5}, {4}, {5}, {}},
{{3, 5}, {3, 4}, {4}, {5}, {}},
{{2, 3, 5}, {4}, {4}, {5}, {}},
{{2, 4}, {3, 5}, {4, 5}, {5}, {}},
{{2, 3, 5}, {4}, {4, 5}, {5}, {}},
{{2, 4, 5}, {3, 5}, {4}, {5}, {}}
}

Gs/(g -> globalMarkovStmts makeGraph g)
scan(oo, s -> (s/print; print "-----------"));
G = makeGraph {{4}, {4}, {4, 5}, {5}, {}}
G = makeGraph {{3, 5}, {3}, {4}, {5}, {}}
G = makeGraph {{2, 4}, {4}, {4, 5}, {5}, {}}
G = makeGraph {{2, 4}, {3, 5}, {4}, {5}, {}}

G = makeGraph {{3, 5}, {3, 4}, {4}, {5}, {}}
G = makeGraph {{2, 3, 5}, {4}, {4}, {5}, {}}

G = makeGraph {{2, 4}, {3, 5}, {4, 5}, {5}, {}}
G = makeGraph {{2, 3, 5}, {4}, {4, 5}, {5}, {}}
G = makeGraph {{2, 4, 5}, {3, 5}, {4}, {5}, {}}

(globalMarkovStmts G)/print;
J = gaussIdeal(R,G)
I = gaussTrekIdeal(R,G)
J : I
res ideal select(flatten entries gens trim J, f -> first degree f > 1)
betti oo

i = 0
G = makeGraph D5s#i
I = gaussTrekIdeal(R,G)
J = gaussIdeal(R,G)
I == J
	  
removeNodes(G4,4)
G3 = drop(G4,-1)
G2 = drop(G3,-1)
debug Markov
G4 = makeGraph G4
parents(G4, 1)
parents(G4, 2)
parents(G4, 3)
parents(G4, 4)

-- We need a method to create all of the dags of size 6,7,8 (maybe not 8?)
- By hand let's do 6:
X = select(partitions 13, p -> #p <= 5)
X = select(X, p ->  p#0 <= 5)
X = select(X, p ->  #p <= 1 or p#1 <= 4)
X = select(X, p ->  #p <= 2 or p#2 <= 3)
X = select(X, p ->  #p <= 3 or p#3 <= 2)
X = select(X, p ->  #p <= 4 or p#4 <= 1)

X = select(partitions 11, p -> #p <= 6);
X = select(X, p ->  p#0 <= 6);
X = select(X, p ->  #p <= 1 or p#1 <= 5);
X = select(X, p ->  #p <= 2 or p#2 <= 4);
X = select(X, p ->  #p <= 3 or p#3 <= 3);
X = select(X, p ->  #p <= 4 or p#4 <= 2);
X = select(X, p ->  #p <= 5 or p#5 <= 1)

-- n=7 examples
restart
loadPackage "Markov"
load "/Users/mike/local/src/M2-mike/markov/dags5.m2"
F = lines get "dags7-part";
R = gaussRing 7


scan(F, g -> (
	  g = value g;
	  G := makeGraph g;
	  I := gaussTrekIdeal(R,G);
	  J := gaussIdeal(R,G);
	  << g;
	  if I != J then << " NOT EQUAL" << endl else << " equal" << endl;
	  ))

scan(F, g -> (
	  g = value g;
	  G := makeGraph g;
	  --I := gaussTrekIdeal(R,G);
	  J := trim gaussIdeal(R,G);
	  linears = ideal select(flatten entries gens J, f -> first degree f == 1);
	  J = trim ideal(gens J % linears);
	  << g << codim J << ", " << betti res J << endl;
	  ))

-- tests for Gaussian Mixed Graphs

restart
loadPackage "GraphicalModels"
g = digraph {{a,{b,c}}, {b,{c,d}}, {c,{}}, {d,{}}}
R = gaussRing g
M = covMatrix R
g = mixedGraph(digraph {{b,{c,d}},{c,{d}}},bigraph {{a,d}})
R = gaussRing g
M = covMatrix(R,g)
--     | s_(a,a) s_(a,b) s_(a,c) s_(a,d) |
--     | s_(a,b) s_(b,b) s_(b,c) s_(b,d) |
--     | s_(a,c) s_(b,c) s_(c,c) s_(c,d) |
--     | s_(a,d) s_(b,d) s_(c,d) s_(d,d) |
D = diMatrix(R,g)
--     | 0 0 0       0       |
--     | 0 0 l_(b,c) l_(b,d) |
--     | 0 0 0       l_(c,d) |
--     | 0 0 0       0       |
B = biMatrix(R,g)
--     | p_(a,a) 0       0       p_(a,d) |
--     | 0       p_(b,b) 0       0       |
--     | 0       0       p_(c,c) 0       |
--     | p_(a,d) 0       0       p_(d,d) |
identify(R,g)
      new HashTable from {p_(a,d) => ideal(s_(a,c),s_(a,b),p_(a,d)-s_(a,d)), p_(d,d) =>
      ideal(s_(a,c),s_(a,b),p_(d,d)*s_(b,c)^2-p_(d,d)*s_(b,b)*s_(c,c)-s_(b,d)^2*s_(c,c)+2*s_(b,c)*s_(b,d)*s_(c,d)-s_(b,b)*s_(c,d)^2-s_(b,c)^2*s_(d,d)+s_(b,
      b)*s_(c,c)*s_(d,d)), p_(c,c) => ideal(s_(a,c),s_(a,b),p_(c,c)*s_(b,b)+s_(b,c)^2-s_(b,b)*s_(c,c)), p_(b,b) => ideal(s_(a,c),s_(a,b),p_(b,b)-s_(b,b)),
      p_(a,a) => ideal(s_(a,c),s_(a,b),p_(a,a)-s_(a,a)), l_(b,c) => ideal(s_(a,c),s_(a,b),l_(b,c)*s_(b,b)-s_(b,c)), l_(b,d) =>
      ideal(s_(a,c),s_(a,b),l_(b,d)*s_(b,c)^2-l_(b,d)*s_(b,b)*s_(c,c)+s_(b,d)*s_(c,c)-s_(b,c)*s_(c,d)), l_(c,d) =>
      ideal(s_(a,c),s_(a,b),l_(c,d)*s_(b,c)^2-l_(c,d)*s_(b,b)*s_(c,c)-s_(b,c)*s_(b,d)+s_(b,b)*s_(c,d))}
stmts = trekSeparation(g)
--     {{{a}, {c, b}, {}, {}}, {{a, b}, {c, b}, {}, {b}}, {{b, c}, {a, b}, {}, {b}}, {{b, c}, {c, a}, {}, {c}}, {{b, c}, {d, a}, {}, {d}}}
trekIdeal(R,g,stmts)
--     ideal(s_(a,c),s_(a,b),s_(a,c)*s_(b,b)-s_(a,b)*s_(b,c),-s_(a,c)*s_(b,b)+s_(a,b)*s_(b,c),s_(a,c)*s_(b,c)-s_(a,b)*s_(c,c),s_(a,c)*s_(b,d)-s_(a,b)*s_(c,d))





-- Local Variables:
-- compile-command: "make -C $M2BUILDDIR/Macaulay2/packages PACKAGES=Markov pre-install"
-- End:
