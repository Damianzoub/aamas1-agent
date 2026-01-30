grid_size(5,5). 
max_carry(3).

// Objects and Requirements
object(t,table). object(ch,chair). object(d,door).
object(cl,color). object(cd,code). object(b,brush). object(k,key).

needs_to_paint(t ,[b,cl]).
needs_to_paint(ch, [b,cl]).
needs_to_open(d, [k,cd]).


// Negotiation config 
other_agent(second_agent).
priority.

!start.

+!start <- .print("Running Main Agent"); !mission.

+!mission <- .print("### AG1 MISSION STARTED ###");
             !negotiate_then_maybe_do(open_door);
             !negotiate_then_maybe_do(paint_table);
             !negotiate_then_maybe_do(paint_chair);
             .print("### AG1 MISSION ACCOMPLISHED ###"). 
// ===================== NEGOTIATION PROTOCOL =====================
+!negotiate_then_maybe_do(Task) <- 
                                   if (otheru(OtherTask,_) & OtherTask \== Task) { .abolish(otheru(OtherTask,_)); } 
    if (decided(OtherTask,_) & OtherTask \== Task) { .abolish(decided(OtherTask,_)); }
                                   !negotiate(Task,0);
                                   !after_negotiate(Task).

+!after_negotiate(Task) : owner(Task,me) <- !do_task(Task).
+!after_negotiate(Task) <- true.

+!negotiate(Task,N) : N < 15 <-
    .print("Negotiating ", Task, " (try ", N, ")"); // [cite: 23]
    !compute_utility(Task,U);
    -+myu(Task,U);
    .print("My Utility for ", Task, " is ", U); // [cite: 23]
    ?other_agent(Receiver);
    .send(Receiver,tell,inform(Task,U));
    !wait_other_inform(Task);
    ?otheru(Task,Uo);
    .print("Received other utility: ", Uo); // [cite: 23]
    !after_otheru(Task,N,U,Uo). 

+!after_otheru(Task,N,U,Uo) : (U > Uo | (U == Uo & priority)) <-
    .print("I won ", Task, ". Sending proposal..."); // [cite: 6]
    .send(second_agent,tell,propose(Task));
    !wait_accept_or_reject(Task,N).

+!after_otheru(Task,N,U,Uo) <- 
    .print("I lost/tied ", Task, ". Waiting for proposal..."); // [cite: 6]
    !wait_propose(Task,N).

+inform(Task,Uo)[source(OA)] <- 
    .print("Received inform for ", Task, " from ", OA, ": ", Uo); // [cite: 7]
    -otheru(Task,_); -+otheru(Task,Uo).

+propose(Task)[source(OA)] : myu(Task,U) & otheru(Task,Uo) & (Uo > U) <-
    .print("Accepting proposal for ", Task); // [cite: 7]
    .send(OA,tell,accept(Task));
    -+owner(Task,other);
    -+decided(Task,other).

+propose(Task)[source(OA)] <- 
    .print("Rejecting proposal for ", Task, " (Restarting)"); // [cite: 7]
    .send(OA,tell,reject(Task)); 
    -+decided(Task,restart).

+accept(Task) <- .print("My proposal for ", Task, " was ACCEPTED"); -+owner(Task,me); -+decided(Task,me). // [cite: 7]
+reject(Task) <- .print("My proposal for ", Task, " was REJECTED"); -+decided(Task,restart). // [cite: 7]

// FIX THE WAIT TYPOS AND ADD PRINTS
+!wait_other_inform(T) : otheru(T,_) <- true.
+!wait_other_inform(T) <- .print("...waiting for inform on ", T); .wait(150); !wait_other_inform(T). // [cite: 13]


+!do_task(open_door) <- !achieve_open(d).
+!do_task(paint_table) <- !achieve_colored(t).
+!do_task(paint_chair) <- !achieve_colored(ch).

+!compute_utility(open_door, U) : pos(X,Y) & at(k,KX,KY) <- 
    D = math.abs(X-KX) + math.abs(Y-KY); 
    U = 100 - D.

+!compute_utility(paint_table, U) : pos(X,Y) & at(b,BX,BY) <- 
    D = math.abs(X-BX) + math.abs(Y-BY); 
    U = 100 - D.

+!compute_utility(paint_chair, U) : pos(X,Y) & at(b,BX,BY) <- 
    D = math.abs(X-BX) + math.abs(Y-BY); 
    U = 100 - D.

+!achieve_colored(ObjSym) : status(ObjSym,painted) <- true.
+!achieve_colored(ObjSym) <- ?needs_to_paint(ObjSym,Reqs);
                             !collect_all(Reqs);
                             !go_to_obj(ObjSym);
                             do(paint(ObjSym));
                             !drop_all.

+!achieve_open(d) : status(door,open) <- true.
+!achieve_open(d) <-!collect_all([k,cd]);
                    !go_to_obj(d);
                    do(open(door));
                    !drop_all.

+!go_to_obj(O) : at(O,X,Y) <- !go_to(X,Y).
+!go_to(X,Y) : pos(X,Y) <- true.
+!go_to(X,Y) <- 
    ?pos(CurX,CurY);
    if (do(move(X,Y))){
        // Use a longer internal delay if .wait feels unreliable
        .wait(200); 
        !go_to(X,Y);
    } else {
        ?other_agent(Target);
        .print("Path blocked! Asking ", Target, " to yield.");
        .send(Target, tell, yield);
        // Delay longer to let the other agent actually move
        .wait(1000); 
        !go_to(X,Y);
    }.

+!collect_all([]) <- true.
+!collect_all([H|T]) : have(H) <- !collect_all(T).
+!collect_all([H|T]) <- !pick_item(H);
                        !collect_all(T).

+!pick_item(S) : at(S,X,Y) <- !go_to(X,Y);
                              ?item_name(S,N);
                              do(pick(N)).

item_name(b,brush).
item_name(cl,color).
item_name(k,key).
item_name(cd,code).

+!drop_all <- .findall(N,(have(N)),L);
              !drop_list(L).

+!drop_list([]) <- true.
+!drop_list([H|T]) <- do(drop(H));
                      !drop_list(T).
+!wait_propose(Task,N) : decided(Task,me) | decided(Task,other) <- true.
+!wait_propose(Task,N) : decided(Task,restart) <- .print("Restarting negotiation for ", Task); -decided(Task,restart); N1=N+1; !negotiate(Task,N1). // [cite: 14]
+!wait_propose(Task,N) <- .print("...waiting for proposal on ", Task); .wait(150); !wait_propose(Task,N). // [cite: 14]

+!wait_accept_or_reject(Task,N) : decided(Task,me) | decided(Task,other) <- true.
+!wait_accept_or_reject(Task,N) : decided(Task,restart) <- -decided(Task,restart); N1=N+1; !negotiate(Task,N1). // [cite: 15]
+!wait_accept_or_reject(Task,N) <- .print("...waiting for accept/reject on ", Task); .wait(150); !wait_accept_or_reject(Task,N). // [cite: 16]