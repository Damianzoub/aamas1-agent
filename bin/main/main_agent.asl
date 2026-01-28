+!start <-.print("Running Main Agent"); 
         !mission;
         .print("Main Agent Finished").
!start.

grid_size(5,5).       //5x5 grid
max_carry(3).          //agent can carry up to 3 objects

//Objects inside the environment
object(t,table).
object(ch,chair).
object(d,door).
object(cl,color).
object(cd,code).
object(b,brush).
object(k,key).

//Task requirements
//To paint T or Ch, agent needs B(brush) and Cl(color)
//To open D, agent needs K(key) and Cd(code)
needs_to_paint(t ,[b,cl]).
needs_to_paint(ch, [b,cl]).
needs_to_open(d, [k,cd]).
//Initial locations of movable objects
at(b,1,5).   // Brush
at(k,1,4).   // Key
at(cd,3,5).  // Code
at(cl,5,5).  // Color

//Initial locations of T, Ch, D (static version)
//Later, to make the system dynamic, these will come from percepts
at(ch,4,2).   //Chair
at(d,3,1).    //Door
at(t,5,1).    //Table



//Walls location
wall(2,2).
wall(2,1).
wall(4,4).
wall(4,5).

// negotiation config 
other_agent(second_agent).
priority. //Agent1 wins ties

//Rewards and Penalties are implemented in the java environment
//goal of agent


+!mission <- .print("### MISSION STARTED ###");
             !negotiate_then_maybe_do(open_door);
             !negotiate_then_maybe_do(paint_table);
             !negotiate_then_maybe_do(paint_chair);
             .print("### MISSION ACCOMPLISHED ###").


// NEGOTATION (MAIN_AGENT IS COORDINATOR)
// main_agent asks second_agent for bid, then decides
// in case of tie -> main_agent wins

// ===================== NEGOTIATION PROTOCOL (same) =====================
//map task -> actual goals
+!do_task(open_door) <- !achieve_open(d).
+!do_task(paint_table) <- !achieve_colored(t).
+!do_task(paint_chair) <- !achieve_colored(ch).


//utility wrapper so !compute_utility always exists
+!compute_utility(open_door,U) <- !my_utility(open_door,U).
+!compute_utility(paint_table,U) <- !my_utility(paint_table,U).
+!compute_utility(paint_chair,U) <- !my_utility(paint_chair,U).

//negotiation
+!negotiate_then_maybe_do(Task) <- 
                    !negotiate(Task,0);
                    owner(Task,me);
                    !do_task(Task).

//main negotiation loop
+! negotiate(Task,N) : N < 15 <-
                        !compute_utility(Task,U);
                        -+myu(Task,U);
                        -otheru(Task,_);
                        -decided(Task,_);
                        -owner(Task,_);
                        other_agent(OA);
                        .send(OA,tell,inform(Task,U));
                        !wait_other_inform(Task);
                        otheru(Task,Uo);
                        !after_otheru(Task,N,U,Uo).

//in case infinity loop stop
+!negotiate(Task,N) : N >= 15 <-
                        .print("Negotiation Failed too many times for ",Task);
                        +owner(Task,me).

+!after_otheru(Task,N,U,Uo) : should_propose(U,Uo) <- 
                              other_agent(OA2);
                              .send(OA2,tell,propose(Task));
                              !wait_accept_or_reject(Task,N).

+!after_otheru(Task,N,U,Uo) : not should_propose(U,Uo) <- !wait_propose(Task,N).

// high or tie (priority) 
should_propose(U,Uo) :- U > Uo.
should_propose(U,Uo) :- U == Uo & priority.

//wait states
+!wait_other_inform(Task) : otheru(Task,_) <- true.
+!wait_other_inform(Task) <- !wait_other_inform(Task).

+!wait_propose(Task,N) : decided(Task,me) <- true.
+!wait_propose(Task,N) : decided(Task,other) <- true.
+!wait_propose(Task,N) : decided(Task,restart) <- 
                        -decided(Task,restart);
                        N1 = N+1;
                        !negotiate(Task,N1).
+!wait_propose(Task,N) <- !wait_propose(Task,N).

+!wait_accept_or_reject(Task,N) : decided(Task,me) <- true.
+!wait_accept_or_reject(Task,N) : decided(Task,other) <- true.
+!wait_accept_or_reject(Task,N) : decided(Task,restart)<-
                                -decided(Task,restart);
                                N1 = N+1;
                                !negotiate(Task,N1).
+!wait_accept_or_reject(Task,N) <- !wait_accept_or_reject(Task,N).

//message handlers

+message(tell,Other,inform(Task,Uo)) : myu(Task,_) <- -+otheru(Task,Uo).
+message(tell,Other,inform(Task,Uo)) : not myu(Task,_) <- 
                                    -+otheru(Task,Uo);
                                    !compute_utility(Task,U);
                                    -+myu(Task,U);
                                    .send(Other,tell,inform(Task,U)).

//rule other wins only if higher
other_should_win(U,Uo) :- Uo > U.

+message(tell,Other,propose(Task)) : myu(Task,U) & otheru(Tsak,Uo) & other_should_win(U,Uo) <-
                                    .send(Other,tell,accept(Task));
                                    -decided(Task,_);
                                    +decided(Task,other);
                                    -owner(Task,_);
                                    +owner(Task,other).

+message(tell,Other,propose(Task)) : myu(Task,U) & otheru(Task,Uo) & not other_should_win(U,Uo)<-
                                    .send(Other,tell,reject(Task));
                                    -decided(Task,_);
                                    +decided(Task,restart).

+message(tell,Other,accept(Task)) <-
    -decided(Task,_);
    +decided(Task,me);
    -owner(Task,_);
    +owner(Task,me).

+message(tell,Other,reject(Task)) <-
        -decided(Task,_);
        +decided(Task,restart).
        

//If Obj is already colored, do nothing
+!achieve_colored(t) : colored(table) <- true.
+!achieve_colored(t) : not colored(table) <- !paint(t).


//Goal: paint(Obj)
+!paint(t) : needs_to_paint(t, ReqList) <-
    !collect_all(ReqList);
    !go_to_obj(t);
    do(paint(table));
    +colored(table).

+!paint(ch) : needs_to_paint(ch, ReqList) <-
    !collect_all(ReqList);
    !go_to_obj(ch);
    do(paint(chair));
    +colored(chair);
    !drop_all. 

//Goal: achieve_open(D)
//If the door is already open, do nothing
+!achieve_open(_) : door(open) <- true.
+!achieve_open(d) : not door(open) <- !open(d).
+!achieve_colored(ch) : colored(chair) <- true.
+!achieve_colored(ch) : not colored(chair) <- !paint(ch).

//Goal: open(D)
+!open(d)
: needs_to_open(d, ReqList)        // check required items (key, code)
<- !collect_all(ReqList);          // collect required items
   !go_to_obj(d);                  // move to the door's location
   do(open(door));                   // update belief: door is now 
   +door(open);
   !drop_all.
//Navigation goals for the agent

//Optional high-level move goals (shortcut wrappers)
+!move_up    <- do(move(up)).
+!move_down  <- do(move(down)).
+!move_left  <- do(move(left)).
+!move_right <- do(move(right)).

//Goal: go_to(X,Y)
//Use path planning (A*) from the current position to (X,Y)


//Not there yet -> ask environment to plan a path, then follow that path step by step
+!go_to(X,Y) : pos(CX,CY) & CX == X & CY==Y<- true.

+!go_to(X,Y) : pos(CX,CY) & (CX \== X | CY \== Y) <-
    do(move(X,Y));
    !go_to(X,Y).

// Follow a path represented as a list of steps

+!follow_path([]) <- true.

+!follow_path([Dir | Rest]) <- do(move(Dir)); 
                                !follow_path(Rest).



//Collect a single object O
+!collect_object(b)  <- do(pick(brush)).
+!collect_object(k)  <- do(pick(key)).
+!collect_object(cd) <- do(pick(code)).
+!collect_object(cl) <- do(pick(color)).

//robust picking for moving objects
+!pick_moving(b) <- !try_pick(b,brush).
+!pick_moving(k) <- !try_pick(k,key).
+!pick_moving(cd) <- !try_pick(cd,code).
+!pick_moving(cl) <- !try_pick(cl,color).

+!try_pick(Sym,Real): at(Sym,X,Y)<-
    !go_to(X,Y);
    do(pick(Real)).

-try_pick(Sym,Real)[error(action_failed)]<- !try_pick(Sym,Real).

//Collect all objects in a list
+!collect_all([H|T]) : have(H) <- !collect_all(T).

+!collect_all([]) <- true.         //empty list: nothing to do


+!collect_all([H|T]): not have(H) <- 
                        !pick_moving(H);
                        !collect_all(T).         // then collect the rest of the list

//Move to the location of object O                        
+!go_to_obj(O): at(O,X,Y) <- !go_to(X,Y). 

//drop 
+!drop_all <-
    .findall(O, (have(O) & (O==b | O==k | O==cd | O==cl)), L);
    !drop_list(L).

+!drop_list([]) <- true.
+!drop_list([H|T]) <- !drop_object(H); !drop_list(T).
+!drop_object(O) : not have(O) <- true.

+!drop_object(b)  : have(b)  <- do(drop(brush)).
+!drop_object(k)  : have(k)  <- do(drop(key)).
+!drop_object(cd) : have(cd) <- do(drop(code)).
+!drop_object(cl) : have(cl) <- do(drop(color)).


//Utility predicates for the agent

+!my_utility(open_door, U) : pos(X,Y) & at(d,DX,DY) <-
    !manhattan(X,Y,DX,DY,D); 
    U = 100 - D.

+!my_utility(paint_table, U) : pos(X,Y) & at(t,TX,TY) <-
    !manhattan(X,Y,TX,TY,D); 
    U = 100 - D.

+!my_utility(paint_chair, U) : pos(X,Y) & at(ch,CX,CY) <-
    !manhattan(X,Y,CX,CY,D); 
    U = 100 - D.

+!manhattan(X1,Y1,X2,Y2,D) <-
    DX = X1 - X2; 
    DY = Y1 - Y2;
    !abs(DX,ADX);
    !abs(DY,ADY);
    D = ADX + ADY.

+!abs(N,A) : N >= 0 <- A = N.
+!abs(N,A) : N < 0 <- A = -N.


// --- ALIASES: map env inventory names -> your short symbols ---
have(b)  :- have(brush).
have(k)  :- have(key).
have(cd) :- have(code).
have(cl) :- have(color).

//Compute how many objects the agent is currently carrying
can_carry_more :- max_carry(M) & carrying_count(N) & N < M.
carrying_count(N) :- .findall(O, have(O), L) & .length(L, N).
 
//Compatible
compatible(b).
compatible(cl).
compatible(k).
compatible(cd).
compatible(t).
compatible(ch).
compatible(d).

//Incompatible if we carry something that is not declared compatible
incompatible(O) :- not compatible(O) & have(O).