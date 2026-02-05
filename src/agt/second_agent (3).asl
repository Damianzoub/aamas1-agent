// === INITIAL CONFIGURATION ===
grid_size(5,5). 
max_carry(3).

object(t,table). object(ch,chair). object(d,door).
object(cl,color). object(cd,code). object(b,brush). object(k,key).

// MAPPING TASKS TO OBJECTS
task_item(open_door, d).
task_item(paint_table, t).
task_item(paint_chair, ch).

// BUNDLED TASK RULE: paint_table implies paint_chair
painting_tasks([paint_table, paint_chair]).

other_agent(main_agent).
// Note: Agent 2 does NOT have the 'priority' belief.

!start.

+!start <- 
    .print("Running Agent 2"); 
    !mission.

// ===================== EVENT-DRIVEN MISSION LOGIC =====================

+!mission <- 
    .print("### AGENT 2 MISSION STARTED ###");
    !negotiate_and_claim(open_door);
    // After open_door is resolved, check if I should do painting
    if (not painting_assigned_to_other) {
        !negotiate_and_claim(paint_table)  // This will bundle paint_chair
    } else {
        .print("Painting assigned to other agent, my work is done")
    };
    !drop_all;
    .print("### AGENT 2 MISSION ENDED ###").

// ===================== NEGOTIATION WITH TASK CLAIMING =====================

+!negotiate_and_claim(Task) <-
    !negotiate(Task, 0);
    !handle_outcome(Task).

// Handle negotiation outcome
+!handle_outcome(Task) : owner(Task, me) <-
    .print(">>> I WON ", Task);
    ?other_agent(OA);
    .send(OA, tell, taken(Task, me));  // Broadcast ownership
    !execute_task_with_bundling(Task).

+!handle_outcome(Task) : owner(Task, other) <-
    .print(">>> OTHER AGENT WON ", Task).

// Execute task, bundling paint_table with paint_chair
+!execute_task_with_bundling(Task) : painting_tasks(PaintList) & .member(Task, PaintList) <-
    .print("*** EXECUTING BUNDLED PAINTING TASKS ***");
    ?other_agent(OA);
    // Claim ALL painting tasks at once
    .send(OA, tell, taken(paint_table, me));
    .send(OA, tell, taken(paint_chair, me));
    +i_am_painter;  // Mark myself as the painter
    !do_task(paint_table);
    .send(OA, tell, done(paint_table));
    !do_task(paint_chair);
    .send(OA, tell, done(paint_chair));
    .print("*** PAINTING BUNDLE COMPLETED ***").

+!execute_task_with_bundling(Task) : not (painting_tasks(PaintList) & .member(Task, PaintList)) <-
    .print("*** EXECUTING ", Task, " ***");
    !do_task(Task);
    ?other_agent(OA);
    .send(OA, tell, done(Task)).

// ===================== RECEIVING TASK ASSIGNMENTS (EVENT-DRIVEN) =====================

// When other agent takes a task, remove it from my consideration
+taken(Task, Agent)[source(Agent)] <-
    .print("Received: ", Agent, " took ", Task);
    +owner(Task, other);
    // If painting was taken, mark it
    if (Task == paint_table | Task == paint_chair) {
        +painting_assigned_to_other;
        .print(">>> Painting bundle assigned to other agent, I will not negotiate paint tasks")
    }.

// When other agent completes a task
+done(Task)[source(Agent)] <-
    .print("Received: ", Agent, " completed ", Task);
    +task_completed(Task).

// ===================== NEGOTIATION PROTOCOL (SIMPLIFIED, NO DEADLOCK) =====================

// Skip negotiation if task already taken
+!negotiate(Task, N) : owner(Task, other) <-
    .print("Task ", Task, " already taken by other, skipping negotiation").

+!negotiate(Task, N) : N < 15 <-
    !compute_utility(Task, U);
    -+myu(Task, U);
    -otheru(Task, _); -decided(Task, _);
    ?other_agent(OA);
    .send(OA, tell, inform(Task, U));
    !wait_other_inform(Task);
    ?otheru(Task, Uo);
    !decide_proposal(Task, N, U, Uo).

+!negotiate(Task, N) : N >= 15 <-
    .print("Negotiation timeout for ", Task, ", giving up");
    +owner(Task, other).

// Decision: should I propose?
+!decide_proposal(Task, N, U, Uo) : should_propose(U, Uo) <-
    ?other_agent(OA);
    .send(OA, tell, propose(Task));
    !wait_decision(Task, N).

+!decide_proposal(Task, N, U, Uo) : not should_propose(U, Uo) <-
    !wait_proposal(Task, N).

// Agent 2 only proposes if strictly greater (no priority tie-breaker)
should_propose(U, Uo) :- U > Uo.

// ===================== WAIT STATES (WITH ABORT CONDITIONS) =====================

+!wait_other_inform(Task) : otheru(Task, _) <- true.
+!wait_other_inform(Task) : owner(Task, other) <-
    .print("Task ", Task, " taken by other during wait, aborting").
+!wait_other_inform(Task) <-
    .wait(100);
    !wait_other_inform(Task).

+!wait_decision(Task, N) : decided(Task, me) | decided(Task, other) <- true.
+!wait_decision(Task, N) : owner(Task, other) <-
    .print("Task ", Task, " taken by other, aborting");
    +decided(Task, other).
+!wait_decision(Task, N) : decided(Task, restart) <-
    -decided(Task, restart);
    N1 = N + 1;
    !negotiate(Task, N1).
+!wait_decision(Task, N) <-
    .wait(100);
    !wait_decision(Task, N).

+!wait_proposal(Task, N) : decided(Task, me) | decided(Task, other) <- true.
+!wait_proposal(Task, N) : owner(Task, other) <-
    .print("Task ", Task, " taken by other, aborting");
    +decided(Task, other).
+!wait_proposal(Task, N) : decided(Task, restart) <-
    -decided(Task, restart);
    N1 = N + 1;
    !negotiate(Task, N1).
+!wait_proposal(Task, N) <-
    .wait(100);
    !wait_proposal(Task, N).

// ===================== MESSAGE HANDLERS =====================

// Respond to utility requests - ALWAYS respond even if task taken
+inform(Task, Uo)[source(Other)] : owner(Task, other) <-
    .print("Received inform for taken task ", Task, ", sending low utility");
    .send(Other, tell, inform(Task, -999)).  // Signal task is unavailable

+inform(Task, Uo)[source(Other)] : myu(Task, _) <-
    -+otheru(Task, Uo).

+inform(Task, Uo)[source(Other)] : not myu(Task, _) <-
    -+otheru(Task, Uo);
    !compute_utility(Task, U);
    -+myu(Task, U);
    .send(Other, tell, inform(Task, U)).

// Respond to proposals
+propose(Task)[source(Other)] : owner(Task, other) <-
    .print("Received proposal for taken task ", Task, ", auto-accepting");
    .send(Other, tell, accept(Task)).

+propose(Task)[source(Other)] : myu(Task, U) & otheru(Task, Uo) & (Uo >= U) <-
    .send(Other, tell, accept(Task));
    -+decided(Task, other);
    -+owner(Task, other).

+propose(Task)[source(Other)] : myu(Task, U) & otheru(Task, Uo) & not (Uo >= U) <-
    .send(Other, tell, reject(Task));
    -+decided(Task, restart).

+accept(Task)[source(Other)] <-
    -+decided(Task, me);
    -+owner(Task, me).

+reject(Task)[source(Other)] <-
    -+decided(Task, restart).

// ===================== UTILITY & EXECUTION =====================

+!compute_utility(Task, U) <- !my_utility(Task, U).

+!my_utility(Task, U) 
    : task_item(Task, Obj) & at(Obj, TX, TY) & pos(X, Y) 
    <- !manhattan(X, Y, TX, TY, D); U = 100 - D.
+!my_utility(Task, 0).

+!manhattan(X1, Y1, X2, Y2, D) <- 
    DX = X1 - X2; DY = Y1 - Y2; 
    !abs(DX, ADX); !abs(DY, ADY); 
    D = ADX + ADY.

+!abs(N, A) : N >= 0 <- A = N.
+!abs(N, A) : N < 0 <- A = -N.

// Task Execution Wrappers
+!do_task(open_door) <- !achieve_open(d).
+!do_task(paint_table) <- !achieve_colored(t).
+!do_task(paint_chair) <- !achieve_colored(ch).

// Action Logic
needs_to_paint(t, [b, cl]). 
needs_to_paint(ch, [b, cl]). 
needs_to_open(d, [k, cd]).

have(b) :- have(brush). 
have(k) :- have(key). 
have(cd) :- have(code). 
have(cl) :- have(color).

+!achieve_colored(O) : colored(O) <- true.
+!achieve_colored(O) : not colored(O) <- !paint(O).

+!paint(O) : needs_to_paint(O, Req) <- 
    !collect_all(Req); 
    !go_to_obj(O);
    ?at(O, X, Y);
    ?pos(X, Y);
    do(paint(O));
    +colored(O).

-!paint(O) <- 
    .print("Paint failed. Re-aligning with ", O);
    !go_to_obj(O);
    !paint(O).

+!achieve_open(d) : door(open) <- true.
+!achieve_open(d) : not door(open) <- !open(d).

+!open(d) : needs_to_open(d, Req) <- 
    !collect_all(Req); 
    !go_to_obj(d); 
    do(open(door)); 
    +door(open); 
    !drop_all.

+!collect_all([]) <- true.
+!collect_all([H|T]) : have(H) <- !collect_all(T).
+!collect_all([H|T]) : not have(H) <- !pick_moving(H); !collect_all(T).

+!pick_moving(Alias) 
    : at(Alias, X, Y) & object(Alias, RealName) 
    <- 
    !go_to(X, Y); 
    .print("Picking ", RealName, " (alias: ", Alias, ")");
    do(pick(RealName)).

+!pick_moving(Name) 
    : at(Name, X, Y) 
    <- 
    !go_to(X, Y); 
    do(pick(Name)).

+!go_to_obj(O) : at(O, X, Y) <- !go_to(X, Y).

+!go_to(X, Y) : pos(X, Y) <- true.

+!go_to(X, Y) : pos(CX, CY) <- 
    do(move(X, Y)); 
    .wait(100); 
    !go_to(X, Y).

-!go_to(X, Y) <- 
    .print("Movement Failed, retrying...");
    .wait(200);
    !go_to(X, Y).

+!pick_moving(Alias) : object(Alias, RealName) <- 
    !go_to_obj(Alias);
    .print("Attempting to pick ", RealName);
    do(pick(RealName)).

-!pick_moving(Alias) <- 
    .print("Pick failed. Object likely moved. Re-locating...");
    .wait(1000);
    !pick_moving(Alias).

+!drop_all <- .findall(O, have(O), L); !drop_list(L).
+!drop_list([]) <- true.
+!drop_list([H|T]) <- do(drop(H)); !drop_list(T).
-!drop_list([H|T]) <- !drop_list(T).
