+!start <- .print("Agent started");
    !calculate_utilities;
    !negotiate_all_jobs;
    !execute_assignments;
    .print("Agent finished").
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


// Try to move ? if blocked, try side-steps 
+!safe_move(Dir) <- do(move(Dir)).

-!safe_move(Dir)[error(action_failed)] <-
    .print("Blocked on move(",Dir,") ->yielding");
    !try_dirs([up,down,left,right]).

+!try_dirs([]) <- true.
+!try_dirs([D|Rest]) <- do(move(D)).
-try_dirs([D|Rest])[error(action_failed)] <- !try_dirs(Rest).


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

+!abs(N,A) : N >= 0 <- A = N.
+!abs(N,A) : N < 0 <- A = -N.


// Triggered once at agent initialization
+!calculate_utilities <-
    // Get current position
    ?pos(MyX, MyY);
    
    // Get object positions
    ?at(d, DoorX, DoorY);
    ?at(t, TableX, TableY);
    ?at(ch, ChairX, ChairY);
    
    // Calculate open_job utility (manhattan to door)
    DiffDoorX = MyX - DoorX;
    DiffDoorY = MyY - DoorY;
    !abs(DiffDoorX, AbsDoorX);
    !abs(DiffDoorY, AbsDoorY);
    DoorDist = AbsDoorX + AbsDoorY;
    OpenUtil = 100 - DoorDist;
    +job_utility(open_job, OpenUtil);
    
    // Calculate paint_job utility (average manhattan to table and chair)
    DiffTableX = MyX - TableX;
    DiffTableY = MyY - TableY;
    !abs(DiffTableX, AbsTableX);
    !abs(DiffTableY, AbsTableY);
    TableDist = AbsTableX + AbsTableY;
    
    DiffChairX = MyX - ChairX;
    DiffChairY = MyY - ChairY;
    !abs(DiffChairX, AbsChairX);
    !abs(DiffChairY, AbsChairY);
    ChairDist = AbsChairX + AbsChairY;
    
    SumPaintDist = (TableDist + ChairDist) / 2;
    PaintUtil = 200 - SumPaintDist;
    +job_utility(paint_job, PaintUtil);
    
    +utilities_calculated;
    .print("Utilities calculated: open_job=", OpenUtil, ", paint_job=", PaintUtil).

+!wait_for_other_agent <- .my_name(Me);
                          +ready;
                          .send(second_agent,tell,agent_ready);
                          !wait_for_ready.


+agent_ready <- +other_ready.

+!wait_for_ready : ready & other_ready <- true.
+!wait_for_ready <- .wait(50); !wait_for_ready.
+all_utilities(O,P,Who) <- +all_utilities(O,P,Who).
// ============================================
// NEGOTIATION
// ============================================
+!negotiate_all_jobs <-
    .print("Starting job negotiation");
    ?job_utility(open_job,OpenUtil);
    ?job_utility(paint_job,PaintUtil);
    .my_name(Me);
    .send(second_agent,tell,all_utilities(OpenUtil,PaintUtil,Me));
    !wait_for_all_utilities;
    !decide_all_jobs;
    +negotiation_complete;
    .print("Negotiation complete").

+!wait_for_all_utilities : all_utilities(_,_,_) <- true.
+!wait_for_all_utilities <- .wait(50); !wait_for_all_utilities.

// Decide all jobs (main_agent wins if equal or better)
+!decide_all_jobs <-  
    ?job_utility(open_job,MyOpenUtil);
    ?job_utility(paint_job,MyPaintUtil);
    ?all_utilities(OtherOpenUtil,OtherPaintUtil,OtherAgent);
    
    
        // Decide open_job
        if (OtherOpenUtil >= MyOpenUtil) {
            // I'm STRICTLY better (lower distance)
            +job_winner(open_job, main_agent);
            .print("Assigned open_job: [open_door]");
        } else {
            !assign_job_to_me(open_job);
            +job_winner(open_job, second_agent);
            .print("open_job assigned to main_agent");
        };
        
        // Decide paint_job
        if (OtherPaintUtil >= MyPaintUtil) {
            // I'm STRICTLY better (lower distance)
            +job_winner(paint_job, main_agent);
            .print("Assigned paint_job: [paint_table, paint_chair]");
        } else {
            !assign_job_to_me(paint_job);
            +job_winner(paint_job, second_agent);
            .print("paint_job assigned to main_agent");
        }.

//assign job tasks
+!assign_job_to_me(open_job) <- 
    +my_job(open_job);
    +assigned_task(open_door).

+!assign_job_to_me(paint_job) <- 
    +my_job(paint_job);
    +assigned_task(paint_table);
    +assigned_task(paint_chair).

//execution
+!execute_assignments : negotiation_complete & my_job(open_job) & my_job(paint_job) <-
    .print("Executing both jobs");
    !open(d);
    !paint(t);
    !paint(ch).

+!execute_assignments : negotiation_complete & my_job(open_job) & not my_job(paint_job) <-
    .print("Executing open_job only");
    !open(d).

+!execute_assignments : negotiation_complete & my_job(paint_job) & not my_job(open_job) <-
    .print("Executing paint_job only");
    !paint(t);
    !paint(ch).

+!execute_assignments : negotiation_complete & not my_job(_) <- 
    .print("No jobs assigned to me - standing by").

+!execute_assignments : not negotiation_complete <- 
    .print("Waiting for negotiation to complete");
    .wait(100);
    !execute_assignments.

// ============================================
// TASK EXECUTION (same as second_agent)
// ============================================
+!open(d) : needs_to_open(d, ReqList) <-
    !collect_all(ReqList);
    !go_to_obj(d);
    do(open(door));
    +door(open);
    !drop_all.

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
