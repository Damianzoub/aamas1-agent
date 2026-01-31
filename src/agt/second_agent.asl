// === INITIAL CONFIGURATION ===
grid_size(5,5). 
max_carry(3).


// MAPPING TASKS TO OBJECTS (CRITICAL FIX)
task_item(open_door, d).
task_item(paint_table, t).
task_item(paint_chair, ch).

other_agent(main_agent).
// Note: Agent 2 does NOT have the 'priority' belief.

!start.

+!start <- 
    .print("Running Agent 2"); 
    !mission.

+!mission <- 
    .print("### AGENT 2 MISSION STARTED ###");
    !negotiate_then_maybe_do(open_door);
    !negotiate_then_maybe_do(paint_table);
    !negotiate_then_maybe_do(paint_chair);
    .print("### AGENT 2 MISSION ENDED ###").

// ===================== NEGOTIATION PROTOCOL =====================

+!negotiate_then_maybe_do(Task) <- !negotiate(Task,0); !after_negotiate(Task).

+!after_negotiate(Task) : owner(Task,me) <- !do_task(Task).
+!after_negotiate(Task) : owner(Task,other) <- .print(Task, " assigned to main_agent.").

+!negotiate(Task,N) : N < 15 <-
    !compute_utility(Task,U); 
    -+myu(Task,U);
    -otheru(Task,_); -decided(Task,_); -owner(Task,_);
    ?other_agent(OA); 
    .send(OA,tell,inform(Task,U));
    !wait_other_inform(Task); 
    ?otheru(Task,Uo);
    !after_otheru(Task,N,U,Uo).

+!negotiate(Task,N) : N >= 15 <- +owner(Task,other). // Give up if stuck

// Agent 2 only proposes if strictly greater. No priority tie-breaker.
should_propose(U,Uo) :- U > Uo.

+!after_otheru(Task,N,U,Uo) : should_propose(U,Uo) <- 
    ?other_agent(OA2); 
    .send(OA2,tell,propose(Task));
    !wait_accept_or_reject(Task,N).

+!after_otheru(Task,N,U,Uo) : not should_propose(U,Uo) <- 
    !wait_propose(Task,N).

// ===================== WAIT STATES =====================

+!wait_other_inform(Task) : otheru(Task,_) <- true.
+!wait_other_inform(Task) <- .wait(100); !wait_other_inform(Task).

+!wait_propose(Task,N) : decided(Task,me) | decided(Task,other) <- true.
+!wait_propose(Task,N) : decided(Task,restart) <- 
    -decided(Task,restart); 
    N1 = N+1; 
    !negotiate(Task,N1).
+!wait_propose(Task,N) <- .wait(100); !wait_propose(Task,N).

+!wait_accept_or_reject(Task,N) : decided(Task,me) | decided(Task,other) <- true.
+!wait_accept_or_reject(Task,N) : decided(Task,restart) <-
    -decided(Task,restart); 
    N1 = N+1; 
    !negotiate(Task,N1).
+!wait_accept_or_reject(Task,N) <- .wait(100); !wait_accept_or_reject(Task,N).

// ===================== MESSAGE HANDLERS =====================

+inform(Task,Uo)[source(Other)] : myu(Task,_) <- -+otheru(Task,Uo).
+inform(Task,Uo)[source(Other)] : not myu(Task,_) <- 
    -+otheru(Task,Uo); 
    !compute_utility(Task,U);
    -+myu(Task,U); 
    .send(Other,tell,inform(Task,U)).

+propose(Task)[source(Other)] : myu(Task,U) & otheru(Task,Uo) & (Uo >= U) <-
    .send(Other,tell,accept(Task)); 
    -+decided(Task,other); -+owner(Task,other).

+propose(Task)[source(Other)] : myu(Task,U) & otheru(Task,Uo) & not (Uo >= U) <-
    .send(Other,tell,reject(Task)); 
    -+decided(Task,restart).

+accept(Task)[source(Other)] <- -+decided(Task,me); -+owner(Task,me).
+reject(Task)[source(Other)] <- -+decided(Task,restart).

// ===================== UTILITY & EXECUTION =====================

+!do_task(open_door) <- !achieve_open(d).
+!do_task(paint_table) <- !achieve_colored(t).
+!do_task(paint_chair) <- !achieve_colored(ch).

+!compute_utility(Task,U) <- !my_utility(Task,U).

// FIXED UTILITY
+!my_utility(Task, U) 
    : task_item(Task, Obj) & at(Obj,TX,TY) & pos(X,Y) 
    <- !manhattan(X,Y,TX,TY,D); U = 100 - D.
+!my_utility(Task, 0).

+!manhattan(X1,Y1,X2,Y2,D) <- DX = X1 - X2; DY = Y1 - Y2; !abs(DX,ADX); !abs(DY,ADY); D = ADX + ADY.
+!abs(N,A) : N >= 0 <- A = N.
+!abs(N,A) : N < 0 <- A = -N.

// Action Logic (Simplified copy from main)
needs_to_paint(t ,[b,cl]). needs_to_paint(ch,[b,cl]). needs_to_open(d ,[k,cd]).
have(b) :- have(brush). have(k) :- have(key). have(cd) :- have(code). have(cl) :- have(color).

+!achieve_colored(O) : colored(O) <- true.
+!achieve_colored(O) : not colored(O) <- !paint(O).
+!paint(O) : needs_to_paint(O, Req) <- !collect_all(Req); !go_to_obj(O); do(paint(O)); +colored(O); !drop_all.
+!achieve_open(d) : door(open) <- true.
+!achieve_open(d) : not door(open) <- !open(d).
+!open(d) : needs_to_open(d, Req) <- !collect_all(Req); !go_to_obj(d); do(open(door)); +door(open); !drop_all.

+!collect_all([]) <- true.
+!collect_all([H|T]) : have(H) <- !collect_all(T).
+!collect_all([H|T]) : not have(H) <- !pick_moving(H); !collect_all(T).

+!pick_moving(H) : at(H,X,Y) <- !go_to(X,Y); do(pick(H)).
+!go_to_obj(O) : at(O,X,Y) <- !go_to(X,Y).

+!go_to(X,Y) : pos(X,Y) <- true.
+!go_to(X,Y) : pos(CX,CY) <- do(move(X,Y)); .wait(500); !go_to(X,Y).

+!drop_all <- .findall(O, have(O), L); !drop_list(L).
+!drop_list([]) <- true.
+!drop_list([H|T]) <- do(drop(H)); !drop_list(T).