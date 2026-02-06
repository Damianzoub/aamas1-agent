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


//Walls location
wall(2,2).
wall(2,1).
wall(4,4).
wall(4,5).

//Rewards and Penalties are implemented in the java environment
//goal of agent


+!mission <- .print("### MISSION STARTED ###");
             !achieve_open(d);
             !achieve_colored(t);
             !achieve_colored(ch);
             .print("### MISSION ACCOMPLISHED ###").

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

+!pick_moving(b) <- !try_pick(b,brush).
+!pick_moving(k) <- !try_pick(k,key).
+!pick_moving(cd) <- !try_pick(cd,code).
+!pick_moving(cl) <- !try_pick(cl,color).

+!try_pick(Sym,Real) : at(Sym,X,Y) <- !go_to(X,Y);
                                      do(pick(Real)).

-!try_pick(Sym,Real)[error(action_failed)] <- !try_pick(Sym,Real).


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
