//Utility predicates for the agent

//Compute how many objects the agent is currently carrying
carrying_count(N) :- .findall(O, have(O), L) & .length(L, N).
 
//Compatible
compatible(B).
compatible(Cl).
compatible(K).
compatible(Cd).
compatible(T).
compatible(Ch).
compatible(D).

//Incompatible if we carry something that is not declared compatible
incompatible(O) :- not compatible(O) & have(O).