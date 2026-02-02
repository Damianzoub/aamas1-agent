// === INITIAL CONFIGURATION ===
grid_size(5,5). 
max_carry(3).

// Objects and Requirements
object(t,table). object(ch,chair). object(d,door).
object(cl,color). object(cd,code). object(b,brush). object(k,key).

needs_to_paint(t ,[b,cl]).
needs_to_paint(ch, [b,cl]).
needs_to_open(d, [k,cd]).

// Aliases for checking inventory (CRITICAL FOR collect_all)
have(b)  :- have(brush).
have(k)  :- have(key).
have(cd) :- have(code).
have(cl) :- have(color).

// MAPPING TASKS TO OBJECTS
task_item(open_door, d).
task_item(paint_table, t).
task_item(paint_chair, ch).

// Negotiation config 
other_agent(second_agent).
priority. // Main agent wins ties

!start.

+!start <- 
    .print("Running Main Agent"); 
    !mission.

+!mission <- 
    .print("### MISSION STARTED ###");
    !negotiate_then_maybe_do(open_door);
    !negotiate_then_maybe_do(paint_table);
    !negotiate_then_maybe_do(paint_chair);
    !drop_all;
    .print("### MISSION ACCOMPLISHED ###").

// ===================== NEGOTIATION PROTOCOL =====================

+!negotiate_then_maybe_do(Task) <- 
    !negotiate(Task,0); 
    !after_negotiate(Task).

+!after_negotiate(Task) : owner(Task,me) <- !do_task(Task).
+!after_negotiate(Task) : owner(Task,other) <- .print(Task, " assigned to other.").

// Start Negotiation
+!negotiate(Task,N) : N < 15 <-
    !compute_utility(Task,U);
    -+myu(Task,U);
    -otheru(Task,_); -decided(Task,_); -owner(Task,_);
    ?other_agent(OA);
    .send(OA,tell,inform(Task,U));
    !wait_other_inform(Task);
    ?otheru(Task,Uo);
    !after_otheru(Task,N,U,Uo).

// Force take if negotiation goes on too long
+!negotiate(Task,N) : N >= 15 <- +owner(Task,me).

// Decision Logic
+!after_otheru(Task,N,U,Uo) : should_propose(U,Uo) <- 
    ?other_agent(OA2);
    .send(OA2,tell,propose(Task));
    !wait_accept_or_reject(Task,N).

+!after_otheru(Task,N,U,Uo) : not should_propose(U,Uo) <- 
    !wait_propose(Task,N).

// TIE BREAKER LOGIC
should_propose(U,Uo) :- U > Uo.
should_propose(U,Uo) :- U == Uo & priority.

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

// Received Utility Info
+inform(Task,Uo)[source(Other)] : myu(Task,_) <- -+otheru(Task,Uo).
+inform(Task,Uo)[source(Other)] : not myu(Task,_) <- 
    -+otheru(Task,Uo);
    !compute_utility(Task,U);
    -+myu(Task,U);
    .send(Other,tell,inform(Task,U)).

// Received Proposal
+propose(Task)[source(Other)] : myu(Task,U) & otheru(Task,Uo) & (Uo > U) <-
    .send(Other,tell,accept(Task));
    -+decided(Task,other); -+owner(Task,other).

// Tie-breaker: If they propose but I have priority (or better utility), I reject
+propose(Task)[source(Other)] : myu(Task,U) & otheru(Task,Uo) & not (Uo > U) <-
    .send(Other,tell,reject(Task));
    -+decided(Task,restart).

+accept(Task)[source(Other)] <- -+decided(Task,me); -+owner(Task,me).
+reject(Task)[source(Other)] <- -+decided(Task,restart).

// ===================== UTILITY & EXECUTION =====================

+!compute_utility(Task,U) <- !my_utility(Task,U).

// UTILITY CALCULATION
+!my_utility(Task, U) 
    : task_item(Task, Obj) & at(Obj,TX,TY) & pos(X,Y) 
    <- !manhattan(X,Y,TX,TY,D); U = 100 - D.
// Fallback if we don't know where the object is
+!my_utility(Task, 0). 

+!manhattan(X1,Y1,X2,Y2,D) <- DX = X1 - X2; DY = Y1 - Y2; !abs(DX,ADX); !abs(DY,ADY); D = ADX + ADY.
+!abs(N,A) : N >= 0 <- A = N.
+!abs(N,A) : N < 0 <- A = -N.

// Task Execution Wrappers
+!do_task(open_door) <- !achieve_open(d).
+!do_task(paint_table) <- !achieve_colored(t).
+!do_task(paint_chair) <- !achieve_colored(ch).

// --- ACTION LOGIC ---

+!achieve_colored(O) : colored(O) <- true.
+!achieve_colored(O) : not colored(O) <- !paint(O).

+!paint(O) : needs_to_paint(O, Req) <- 
    !collect_all(Req); 
    !go_to_obj(O); 
    ?at(O,X,Y);
    ?pos(X,Y);
    do(paint(O)); 
    +colored(O).
-!paint(O) <- .print("Paint failed. Re-aligning with ",O);
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

// --- UPDATED PICK LOGIC (FIXED CRASH) ---
// If H is an alias (e.g., 'k'), map it to RealName (e.g., 'key')
+!pick_moving(Alias) 
    : at(Alias,X,Y) & object(Alias, RealName) 
    <- 
    !go_to(X,Y); 
    .print("Picking ", RealName, " (alias: ", Alias, ")");
    do(pick(RealName)).

// Fallback: If it's already the real name
+!pick_moving(Name) 
    : at(Name,X,Y) 
    <- 
    !go_to(X,Y); 
    do(pick(Name)).

+!go_to_obj(O) : at(O,X,Y) <- !go_to(X,Y).

// --- UPDATED MOVEMENT LOGIC (FASTER) ---
+!go_to(X,Y) : pos(X,Y) <- .print("Arrived at ", X, ",", Y).

+!go_to(X,Y) : pos(CX,CY) <- 
    do(move(X,Y)); 
    .wait(100); // Reduced wait for responsiveness
    !go_to(X,Y).

// Safety wrapper for missing position belief
+!go_to(X,Y) : not pos(_,_) <- 
    .wait(100); 
    !go_to(X,Y).

-!go_to(X,Y) <- .print("Movement Failed, retrying...");
                .wait(200);
                !go_to(X,Y).

//Improved Pick Logic
+!pick_moving(Alias) : object(Alias,RealName) <- !go_to_obj(Alias);
                                                 .print("Attempting to pick ", RealName);
                                                 do(pick(RealName)).

-!pick_moving(Alias) <- .print("Pick failed. Object likely moved. Re-locating...");
                        .wait(200);
                        !pick_moving(Alias).

+!drop_all <- .findall(O, have(O), L); !drop_list(L).
+!drop_list([]) <- true.
+!drop_list([H|T]) <- do(drop(H)); !drop_list(T).
-!drop_list([H|T]) <- .print("Skipping drop for ",H," (alias problem or already dropped)");
                      !drop_list(T).
