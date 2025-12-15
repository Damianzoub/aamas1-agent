//Βeliefs of agent

//Basic world info
pos(1,1).             //agent starting position
grid_size(5,5).       //5x5 grid
max_carry(3).          //agent can carry up to 3 objects

//Objects inside the environment
object(T,table).
object(Ch,chair).
object(D,door).
object(Cl,color).
object(Cd,code).
object(B,brush).
object(K,key).

//Task requirements
//To paint T or Ch, agent needs B(brush) and Cl(color)
//To open D, agent needs K(key) and Cd(code)
needs_to_paint(T ,[B,Cl]).
needs_to_paint(Ch, [B,Cl]).
needs_to_open(D, [K,Cd]).

//Initial locations of movable objects
at(B,1,5).   // Brush
at(K,1,4).   // Key
at(Cd,3,5).  // Code
at(Cl,5,5).  // Color

//Initial locations of T, Ch, D (static version)
//Later, to make the system dynamic, these will come from percepts
at(Ch,4,2).   //Chair
at(D,3,1).    //Door
at(T,5,1).    //Table

//Walls location
wall(2,2).
wall(2,1).
wall(4,4).
wall(4,5).

//Rewards and Penalties are implemented in the java environment
//goal of agent
+!goals_loaded <- .print("### GOALS.ASL LOADED ###").

!mission.

+!mission <- !achieve_colored(T);
             !achieve_colored(Ch);
             !achieve_open(D).

//If Obj is already colored, do nothing
+!achieve_colored(Obj): colored(Obj) <- true.

//If Obj is not colored yet, paint it
+!achieve_colored(Obj): not colored(Obj) <- !paint(Obj).

//Goal: paint(Obj)
+!paint(Obj)
:  needs_to_paint(Obj, ReqList)   // check required items (brush, color)
<- !collect_all(ReqList);         // collect required items
   !go_to_obj(Obj);               // move to the object's location
   do(paint(Obj));                // perform painting action (Java env)
   +colored(Obj).                 // update belief: Obj is now colored

//Goal: achieve_open(D)
//If the door is already open, do nothing
+!achieve_open(D) : opened(D) <- true.  

//If the door is not open yet, call open(D)
+!achieve_open(D) : not opened(D) <- !open(D).

//Goal: open(D)
+!open(D)
: needs_to_open(D, ReqList)        // check required items (key, code)
<- !collect_all(ReqList);          // collect required items
   !go_to_obj(D);                  // move to the door's location
   do(open(D));                    // perform door-opening action (Java env)
   +opened(D).                     // update belief: door is now 

//Navigation goals for the agent

//Optional high-level move goals (shortcut wrappers)
+!move_up    <- do(move(up)).
+!move_down  <- do(move(down)).
+!move_left  <- do(move(left)).
+!move_right <- do(move(right)).

//Goal: go_to(X,Y)
//Use path planning (A*) from the current position to (X,Y)


//Not there yet -> ask environment to plan a path, then follow that path step by step
+!go_to(X,Y) : pos(CX,CY) & CX==X & CY==Y <- true.

+!go_to(X,Y) : pos(CX,CY) & (CX \== X | CY \== Y) <-
    do(move(X,Y));
    !go_to(X,Y).

// Follow a path represented as a list of steps

+!follow_path([]) <- true.

+!follow_path([Dir | Rest]) <- do(move(Dir)); 
                                !follow_path(Rest).


//Low-level actions (Java environment)
do(move(up)).
do(move(down)).
do(move(left)).
do(move(right)).

do(grab(O)).
do(drop(O)).
do(open(D)).
do(paint(O)).

//Collect a single object O
+!collect_object(O) : not have(O) & at(O,X,Y)
                                  & pos(X,Y)
                                  & carrying_count(N)
                                  & max_carry(Max)
                                  & N < Max <- do(pick(O));
                                               +have(O);
                                               -at(O,X,Y).

//Collect all objects in a list
+!collect_all([]) <- true.         //empty list: nothing to do

+!collect_all([H|T]) <- !go_to_obj(H);           // go to object H
                        !collect_object(H);      // pick it up (if capacity allows)
                        !collect_all(T).         // then collect the rest of the list

//Move to the location of object O                        
+!go_to_obj(O): at(O,X,Y) <- !go_to(X,Y). 


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