newPackage("SEM",
     Authors => {
	  {Name => "Luis Garcia"},
	  {Name => "Alexander Diaz"}
	  },
     DebuggingMode => false,
     Headline => "Gaussian Library Translation",
     Version => "1"
     )



export {pos, 
	identify, 
	trekSeparation, 
	trekIdeal}

needsPackage "Graphs"
needsPackage "GraphicalModels"

--returns the position in hash table h of the key x
pos(HashTable, Thing) := (h, x) -> position(keys(h), i->i===x)
getPositionOfKeys = (G,S) -> apply(S, v -> pos(G,v))


identify = method()
identify(MixedGraph) := (g) -> (
        G := graph g;
	u := G#Digraph;
	v := G#Bigraph;
	n := #u;
	
	m := #edges(u)+#edges(v)+n;
	SLP := QQ[vertices,s_(1,1)..s_(n,n), MonomialOrder => Eliminate m];
	pL := join(apply(keys(v), i->p_(i,i)),delete(null,flatten(apply(keys(v), x-> apply(toList v#x, y->if position(keys(v), i-> i===x) < position(keys(v), j-> j===y) then p_(x,y))))));
	lL := delete(null,flatten(apply(keys(u), x-> apply(toList u#x, y->l_(x,y) ))));	 
	vertices := join(pL,lL);

	SM := map(SLP^n,n,(i,j)->s_(i+1,j+1));
	
	PM := mutableMatrix(SLP,n,n);
	scan(keys(v),i->PM_(position(keys(v), x-> x===i),position(keys(v), x-> x===i))=p_(i,i));
	scan(keys(v),i->scan(toList v#i, j->   
	    if position(keys(v), x-> x===i) < position(keys(v), x-> x===j) then
	      PM_(position(keys(v), x-> x===i),position(keys(v), x-> x===j)) = p_(i,j)
	    else 
	      PM_(position(keys(v), x-> x===i),position(keys(v), x-> x===j)) = p_(j,i)
	));
	print(PM);

	LM := mutableMatrix(SLP,n,n);
    scan(keys(u),i->scan(toList u#i, j->
        LM_(position(keys(u), x-> x===i),position(keys(u), x-> x===j)) = l_(i,j)
    ));
	print(LM);

	Linv = inverse(1-matrix(LM));
	LiPL = transpose(Linv)*matrix(PM)*Linv;
	MPmLiPL := SM-LiPL;
	print(MPmLiPL);
	J := ideal(flatten(for i from 0 to n-1 list for j from i to n-1 list MPmLiPL_(i,j)));
	print(J);
	
	for t in vertices do
	(
	  Jmt := eliminate(delete(t,vertices),J);
	  
	  -- the parameter we are checking identifiability with
	  print(t);
	  
	  -- whether the image of the parameterization is dense in the probability space
	  -- non-zero if it is dense, 0 if it is not dense
	  print(min(apply(Jmt_*, q->degree(t,q))));
	  
	  -- minimum number of points in the fiber over a point in the image
	  print(min(delete(0,apply(Jmt_*, q->degree(t,q)))));
	  
	  -- ideal of equations containing s_(i,j) and the parameter q
	  print(Jmt);
	);
)


setToBinary := (A,B) -> sum(toList apply(0..#A-1, i->2^i*(if (set B)#?(A#i) then 1 else 0)))
subsetsBetween := (A,B) -> apply(subsets ((set B) - A), i->toList (i+set A))

trekSeparation = method()
trekSeparation MixedGraph := (g) -> (
    -- Input: A mixed graph containing a directed graph and a bidirected graph.
    -- Output: A list L of lists {A,B,CA,CB}, where (CA,CB) trek separates A from B.

    G := graph g;
    u := G#Digraph;
    v := G#Bigraph;
    vertices := keys u;     

    -- Construct canonical double DAG cdG associated to mixed graph G
    cdG:= digraph join(
      apply(vertices,i->{(a,i),join(
        apply(toList parents(u,i),j->(a,j)),
        {(b,i)}, apply(toList v#i,j->(b,j)))}),
      apply(vertices,i->{(b,i),apply(toList u#i,j->(b,j))}));
    aVertices := apply(vertices, i->(a,i));
    bVertices := apply(vertices, i->(b,i));
    allVertices := aVertices|bVertices;
    M := adjacencyHashTable(cdG);
    
    statements := {};
    for CA in (subsets aVertices) do (
      for CB in (subsets bVertices) do (
	CAbin := setToBinary(aVertices,CA);
	CBbin := setToBinary(bVertices,CB);
	if CAbin <= CBbin then (
          C := CA|CB;
          MC := hashTable apply(keys M,i->{i,new MutableHashTable from M#i});
          scan(C, i->scan(allVertices, j->(MC#i#j=0;MC#j#i=0;)));
	  Alist := delete({},subsetsBetween(CA,aVertices));
          while #Alist > 0 do (
	    minA := first Alist;
	    pC := reachable(MC,set minA);
	    A := toList ((pC*(set aVertices)) + set CA);
	    Alist = Alist - (set subsetsBetween(minA,A));
	    B := toList ((set bVertices) - pC);

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
	
	

trekIdeal = method()
trekIdeal(Ring, MixedGraph) := (SLP, g) -> (
	use SLP;
	G := graph g;
	u := G#Digraph;
	v := G#Bigraph;
	n := #u;
	c := trekSeparation(g);
	I := {};
  	M := map (SLP^n, n, (i,j)->if i<j then SLP_(((n-1)*i)+(i+j)) else SLP_(((n-1)*j)+(i+j)));
	for i from 1 to #c do (
		num = 1;
		if c#(i-1)#2 != {} then num = num + #c#(i-1)#2;
		if c#(i-1)#3 != {} then num = num + #c#(i-1)#3;

		if c#(i-1)#0 != {} then c1 = apply(c#(i-1)#0, l->position(keys(u), k->k===l));
		if c#(i-1)#1 != {} then c2 = apply(c#(i-1)#1, l->position(keys(u), k->k===l));
		m = submatrix(matrix M, c1, c2);
		I = append(I, flatten entries gens minors(num, m));
	);
	I = ideal flatten I;
	flatten entries gens gb I
)
	
	
