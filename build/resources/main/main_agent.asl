grid_size(5,5).
max_carry(3).

object(t,table). object(ch,chair). object(d,door).
object(cl,color). object(cd,code). object(b,brush). object(k,key).

needs_to_paint(t, [b, cl]).
needs_to_paint(ch, [b, cl]).
needs_to_open(d, [k, cd]).

have(b)  :- have(brush).
have(k)  :- have(key).
have(cd) :- have(code).
have(cl) :- have(color).
alias_real(t, table).
alias_real(ch, chair).
alias_real(d, door).
alias_real(k, key).
alias_real(cd, code).
alias_real(b, brush).
alias_real(cl, color).

task_item(open_door, d).
task_item(paint_table, t).
task_item(paint_chair, ch).

painting_tasks([paint_table, paint_chair]).

other_agent(second_agent).
priority.

!start.

+!start <-
    .print("Running Main Agent");
    !mission.

// ===================== EVENT-DRIVEN MISSION LOGIC =====================

+!mission <-
    .print("### MISSION STARTED ###");
    !negotiate_and_claim(open_door);

    if (not painting_assigned_to_other) {
        !negotiate_and_claim(paint_table)
    } else {
        .print("Painting assigned to other agent, my work is done")
    };

    !drop_all;
    .print("### MISSION ACCOMPLISHED ###").

// ===================== NEGOTIATION WITH TASK CLAIMING =====================

+!negotiate_and_claim(Task) <-
    !negotiate(Task, 0);
    !handle_outcome(Task).

+!handle_outcome(Task) : owner(Task, me) <-
    .print("I WON ", Task);
    ?other_agent(OA);
    .send(OA, tell, taken(Task, me));
    !execute_task_with_bundling(Task).

+!handle_outcome(Task) : owner(Task, other) <-
    .print("OTHER AGENT WON ", Task).

+!execute_task_with_bundling(Task) : painting_tasks(PaintList) & .member(Task, PaintList) <-
    .print("*** EXECUTING BUNDLED PAINTING TASKS ***");
    ?other_agent(OA);
    .send(OA, tell, taken(paint_table, me));
    .send(OA, tell, taken(paint_chair, me));
    +i_am_painter;

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

// ===================== RECEIVING TASK ASSIGNMENTS =====================

+taken(Task, Agent)[source(Agent)] <-
    .print("Received: ", Agent, " took ", Task);
    +owner(Task, other);
    if (Task == paint_table | Task == paint_chair) {
        +painting_assigned_to_other;
        .print("Painting bundle assigned to other agent, I will not negotiate paint tasks")
    }.

+done(Task)[source(Agent)] <-
    .print("Received: ", Agent, " completed ", Task);
    +task_completed(Task).

// ===================== NEGOTIATION PROTOCOL =====================

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
    .print("Negotiation timeout for ", Task, ", taking by default");
    +owner(Task, me).

+!decide_proposal(Task, N, U, Uo) : should_propose(U, Uo) <-
    ?other_agent(OA);
    .send(OA, tell, propose(Task));
    !wait_decision(Task, N).

+!decide_proposal(Task, N, U, Uo) : not should_propose(U, Uo) <-
    !wait_proposal(Task, N).

should_propose(U, Uo) :- U > Uo.
should_propose(U, Uo) :- U == Uo & priority.

// ===================== WAIT STATES =====================

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

+inform(Task, Uo)[source(Other)] : owner(Task, other) <-
    .print("Received inform for taken task ", Task, ", sending low utility");
    .send(Other, tell, inform(Task, -999)).

+inform(Task, Uo)[source(Other)] : myu(Task, _) <-
    -+otheru(Task, Uo).

+inform(Task, Uo)[source(Other)] : not myu(Task, _) <-
    -+otheru(Task, Uo);
    !compute_utility(Task, U);
    -+myu(Task, U);
    .send(Other, tell, inform(Task, U)).

+propose(Task)[source(Other)] : owner(Task, other) <-
    .print("Received proposal for taken task ", Task, ", auto-accepting");
    .send(Other, tell, accept(Task)).

+propose(Task)[source(Other)] : myu(Task, U) & otheru(Task, Uo) & (Uo > U) <-
    .send(Other, tell, accept(Task));
    -+decided(Task, other);
    -+owner(Task, other).

+propose(Task)[source(Other)] : myu(Task, U) & otheru(Task, Uo) & not (Uo > U) <-
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
<-  !manhattan(X, Y, TX, TY, D);
    U = 100 - D.

+!my_utility(Task, 0).

+!manhattan(X1, Y1, X2, Y2, D) <-
    DX = X1 - X2; DY = Y1 - Y2;
    !abs(DX, ADX); !abs(DY, ADY);
    D = ADX + ADY.

+!abs(N, A) : N >= 0 <- A = N.
+!abs(N, A) : N < 0 <- A = -N.

// ===================== TASK EXECUTION =====================

+!do_task(open_door)   <- !achieve_open(d).
+!do_task(paint_table) <- !achieve_colored(t).
+!do_task(paint_chair) <- !achieve_colored(ch).



+!achieve_colored(O) : colored(O) <- true.
+!achieve_colored(O) : not colored(O) <- !paint(O).

// Low-level paint: idempotent + uses needs_to_paint
+!paint(O) : colored(O) <- true.
+!paint(O) : not colored(O) & needs_to_paint(O, Req) <- 
    !collect_all(Req); 
    !go_to_obj(O);
    do(paint(O)).      

// Negative plan: log and stop (or limit retries with a counter)
-!paint(O) : colored(O) <- true.
-!paint(O) : not colored(O) <- 
    .print("Paint failed for ", O, " giving up for now").


+!achieve_open(d) : door(open) <- true.
+!achieve_open(d) : not door(open) <- !open(d).

+!open(d) : door(open) <- true.
+!open(d) : not door(open) & needs_to_open(d, Req) <-
    !collect_all(Req);
    !go_to_obj(d);
    do(open(door));
    +door(open);
    !drop_all.
    
-!open(d) : door(open) <- true.
-!open(d) <-
    .print("Open failed. Re-trying...").

+!collect_all(Reqs) <- !collect_all(Reqs,10).
+!collect_all([]) <- true.
+!collect_all([H|T],N) : have(H) <- !collect_all(T,N).
+!collect_all([H|T]) : not have(H) & N > 0 <- !pick_moving(H,O); !collect_all(T,N).
+!collect_all([H|_], N) : not have(H) & 0 >= N <- 
    .print(" Could not collect required item ", H, ", giving up.");
    true.

// ===================== FIXED PICK (ONE PLAN ONLY) =====================
// Try to pick moving object Alias, with attempt counter K

+!pick_moving(Alias, K) 
    : K < 10 & at(Alias, X, Y) & object(Alias, RealName) 
    <- 
    !go_to(X, Y);
    .print("Picking ", RealName, " (alias: ", Alias, "), attempt ", K);
    do(pick(RealName)).

+!pick_moving(Alias, K) 
    : K < 10 & at(Alias, X, Y) 
    <- 
    !go_to(X, Y);
    .print("Picking ", Alias, " at (", X, ",", Y, "), attempt ", K);
    do(pick(Alias)).

// If the goal fails, we get here
-!pick_moving(Alias, K) : K < 10 <- 
    K1 = K + 1;
    .print("Pick failed for ", Alias, ", retrying (attempt ", K1, ")");
    .wait(500);
    !pick_moving(Alias, K1).

-!pick_moving(Alias, K) : K >= 10 <- 
    .print("Giving up on ", Alias, " after ", K, " attempts.").



// ===================== FIXED MOVEMENT (GUARDED) =====================

+!go_to_obj(O) : at(O, X, Y) <- !go_to(X, Y).

+!go_to(X, Y) : pos(X, Y) <- true.

+!go_to(X, Y) : pos(CX, CY) & not (CX == X & CY == Y) <-
    do(move(X, Y));
    .wait(120);
    !go_to(X, Y).

-!go_to(X, Y) <-
    .print("Movement failed, retrying go_to(", X, ",", Y, ")");
    .wait(200);
    !go_to(X, Y).

// ===================== LEAVE OBJECT CELL (AVOID BLOCKING) =====================

// ===================== LEAVE OBJECT CELL (DOM-safe, no 'true' step) =====================

+!leave_obj(O) : at(O, OX, OY) & pos(OX, OY) & grid_size(W, H) <-
    // Try four neighbors; each attempt is guarded so it only executes if in-bounds.
    !try_leave_step(OX, OY,  1, 0, W, H);
    !try_leave_step(OX, OY, -1, 0, W, H);
    !try_leave_step(OX, OY,  0, 1, W, H);
    !try_leave_step(OX, OY,  0,-1, W, H).

+!leave_obj(O) <- .print("leave_obj: not on object or no location; skipping").

+!try_leave_step(OX, OY, DX, DY, W, H)
    : pos(OX, OY)
    & NX = OX + DX
    & NY = OY + DY
    & NX >= 0 & NX < W
    & NY >= 0 & NY < H
<-
    do(move(NX, NY)).

+!try_leave_step(OX, OY, DX, DY, W, H) <- true.



// ===================== DROP =====================

+!drop_all <- .findall(O, have(O), L); !drop_list(L).
+!drop_list([]) <- true.
+!drop_list([H|T]) <- do(drop(H)); !drop_list(T).
-!drop_list([H|T]) <- !drop_list(T).
