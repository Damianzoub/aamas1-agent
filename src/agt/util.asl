//the num of objects the agent can carry at most.
capacity(3).
//current number of objects the agents has 
carrying_count(0).

//not sure for the below code 
//increase the number of objects the agent is carrying by 1
+!inc_carry:
carrying_count(N) & capacity(Max) & N < Max
<- N1 = N+1;
    -carrying_count(N);
    +carrying_count(N1).

//decrease the number of objects the agent is carrying by 1
+!dec_carry:
carrying_count(N) & N > 0
<- N1 = N-1;
    -carrying_count(N);
    +carrying_count(N1).

+!pickUp_If_here(obj): at_same_cell(Obj) & free_slot & not have(Obj)

<- .print("Picking Up",Obj);
    +have(Obj);
    !inc_carry;
    -at_same_cell(Obj).

+!pickUp_If_here(obj): at_same_cell(Obj) & not free_slot <- .print("Cannot pick up ",Obj," : inventory full.").

+!drop_here(Obj): have(Obj) <-
    .print("Dropping", Obj);
    -have(Obj);
    !dec_carry;

//add rewards and penalties



//compatible
compatible(B).
compatible(Cl).
compatible(K).
compatible(Cd).
compatible(T).
compatible(Ch).
compatible(D).

//incompatible 
incompatible(O) :- not compatible(O) & carrying(O).