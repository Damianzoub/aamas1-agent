+!start <- .print("Running Main Agent"); 
         !mission;
         .print("Main Agent Finished").
!start.

grid_size(5,5). 
max_carry(3).

// Objects and Requirements
object(t,table). object(ch,chair). object(d,door).
object(cl,color). object(cd,code). object(b,brush). object(k,key).

needs_to_paint(t ,[b,cl]).
needs_to_paint(ch, [b,cl]).
needs_to_open(d, [k,cd]).

// Navigation and Obstacle Beliefs
wall(2,2). wall(2,1). wall(4,4). wall(4,5).

// Negotiation config 
other_agent(second_agent).
priority.

+!mission <- .print("### MISSION STARTED ###");
             !negotiate_then_maybe_do(open_door);
             !negotiate_then_maybe_do(paint_table);
             !negotiate_then_maybe_do(paint_chair);
             .print("### MISSION ACCOMPLISHED ###").

// ===================== NEGOTIATION PROTOCOL =====================

+!do_task(open_door) <- !achieve_open(d).
+!do_task(paint_table) <- !achieve_colored(t).
+!do_task(paint_chair) <- !achieve_colored(ch).

+!compute_utility(Task,U) <- !my_utility(Task,U).

+!negotiate_then_maybe_do(Task) <- 
                    !negotiate(Task,0);
                    !after_negotiate(Task).

+!after_negotiate(Task) : owner(Task,me) <- !do_task(Task).
+!after_negotiate(Task) : owner(Task,other) <- true.

+!negotiate(Task,N) : N < 15 <-
                        !compute_utility(Task,U);
                        -+myu(Task,U);
                        -otheru(Task,_); -decided(Task,_); -owner(Task,_);
                        ?other_agent(OA);
                        .send(OA,tell,inform(Task,U));
                        !wait_other_inform(Task);
                        ?otheru(Task,Uo);
                        !after_otheru(Task,N,U,Uo).

+!negotiate(Task,N) : N >= 15 <- +owner(Task,me).

+!after_otheru(Task,N,U,Uo) : should_propose(U,Uo) <- 
                              ?other_agent(OA2);
                              .send(OA2,tell,propose(Task));
                              !wait_accept_or_reject(Task,N).

+!after_otheru(Task,N,U,Uo) : not should_propose(U,Uo) <- !wait_propose(Task,N).

should_propose(U,Uo) :- U > Uo.
should_propose(U,Uo) :- U == Uo & priority.

// ===================== FIXED WAIT STATES =====================

+!wait_other_inform(Task) : otheru(Task,_) <- true.
+!wait_other_inform(Task) <- .wait(100); !wait_other_inform(Task).

+!wait_propose(Task,N) : decided(Task,me) | decided(Task,other) <- true.
+!wait_propose(Task,N) : decided(Task,restart) <- 
                        -decided(Task,restart);
                        N1 = N+1; !negotiate(Task,N1).
+!wait_propose(Task,N) <- .wait(100); !wait_propose(Task,N).

+!wait_accept_or_reject(Task,N) : decided(Task,me) | decided(Task,other) <- true.
+!wait_accept_or_reject(Task,N) : decided(Task,restart)<-
                                -decided(Task,restart);
                                N1 = N+1; !negotiate(Task,N1).
+!wait_accept_or_reject(Task,N) <- .wait(100); !wait_accept_or_reject(Task,N).

// ===================== FIXED MESSAGE HANDLERS =====================

+inform(Task,Uo)[source(Other)] : myu(Task,_) <- -+otheru(Task,Uo).
+inform(Task,Uo)[source(Other)] : not myu(Task,_) <- 
                                    -+otheru(Task,Uo);
                                    !compute_utility(Task,U);
                                    -+myu(Task,U);
                                    .send(Other,tell,inform(Task,U)).

+propose(Task)[source(Other)] : myu(Task,U) & otheru(Task,Uo) & (Uo > U) <-
                                    .send(Other,tell,accept(Task));
                                    -+decided(Task,other); -+owner(Task,other).

+propose(Task)[source(Other)] : myu(Task,U) & otheru(Task,Uo) & not (Uo > U) <-
                                    .send(Other,tell,reject(Task));
                                    -+decided(Task,restart).

+accept(Task)[source(Other)] <- -+decided(Task,me); -+owner(Task,me).
+reject(Task)[source(Other)] <- -+decided(Task,restart).

// ===================== TASK EXECUTION =====================

+!achieve_colored(t) : colored(table) <- true.
+!achieve_colored(t) : not colored(table) <- !paint(t).

+!paint(t) : needs_to_paint(t, ReqList) <-
    !collect_all(ReqList); !go_to_obj(t);
    do(paint(table)); +colored(table).

+!achieve_open(d) : door(open) <- true.
+!achieve_open(d) : not door(open) <- !open(d).

+!open(d) : needs_to_open(d, ReqList) <- 
    !collect_all(ReqList); !go_to_obj(d);
    do(open(door)); +door(open); !drop_all.

+!go_to(X,Y) : pos(X,Y) <- true.
+!go_to(X,Y) : pos(CX,CY) <- 
    do(move(X,Y)); .wait({+pos(_, _)}); !go_to(X,Y).

+!go_to_obj(O): at(O,X,Y) <- !go_to(X,Y).

+!collect_all([]) <- true.
+!collect_all([H|T]) : have(H) <- !collect_all(T).
+!collect_all([H|T]) : not have(H) <- !pick_moving(H); !collect_all(T).

+!pick_moving(H) : at(H,X,Y) <- !go_to(X,Y); do(pick(H)).

+!drop_all <- .findall(O, (have(O) & (O==brush | O==key | O==code | O==color)), L); !drop_list(L).
+!drop_list([]) <- true.
+!drop_list([H|T]) <- do(drop(H)); !drop_list(T).

// ===================== UTILITY =====================

+!my_utility(Task, U) : pos(X,Y) & at(Obj,TX,TY) <- !manhattan(X,Y,TX,TY,D); U = 100 - D.
+!manhattan(X1,Y1,X2,Y2,D) <- DX = X1 - X2; DY = Y1 - Y2; !abs(DX,ADX); !abs(DY,ADY); D = ADX + ADY.
+!abs(N,A) : N >= 0 <- A = N.
+!abs(N,A) : N < 0 <- A = -N.

// colored
+!achieve_colored(t) : colored(table) <- true.
+!achieve_colored(t) : not colored(table) <- !paint(t).

+!achieve_colored(ch) : colored(chair) <- true.
+!achieve_colored(ch) : not colored(chair) <- !paint(ch).

// paint
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

// open
+!achieve_open(_) : door(open) <- true.
+!achieve_open(d) : not door(open) <- !open(d).

+!open(d) : needs_to_open(d, ReqList) <-
    !collect_all(ReqList);
    !go_to_obj(d);
    do(open(door));
    +door(open);
    !drop_all.

// movement wrappers
+!move_up    <- do(move(up)).
+!move_down  <- do(move(down)).
+!move_left  <- do(move(left)).
+!move_right <- do(move(right)).

// go_to
+!go_to(X,Y) : pos(CX,CY) & CX == X & CY==Y <- true.
+!go_to(X,Y) : pos(CX,CY) & (CX \== X | CY \== Y) <-
    do(move(X,Y));
    !go_to(X,Y).

+!follow_path([]) <- true.
+!follow_path([Dir|Rest]) <- do(move(Dir)); !follow_path(Rest).

// pick primitives
+!collect_object(b)  <- do(pick(brush)).
+!collect_object(k)  <- do(pick(key)).
+!collect_object(cd) <- do(pick(code)).
+!collect_object(cl) <- do(pick(color)).

// robust pick for moving items
+!pick_moving(b)  <- !try_pick(b,brush).
+!pick_moving(k)  <- !try_pick(k,key).
+!pick_moving(cd) <- !try_pick(cd,code).
+!pick_moving(cl) <- !try_pick(cl,color).

+!try_pick(Sym,Real) : at(Sym,X,Y) <-
    !go_to(X,Y);
    do(pick(Real)).

-try_pick(Sym,Real)[error(action_failed)] <-
    !try_pick(Sym,Real).

// collect_all
+!collect_all([]) <- true.
+!collect_all([H|T]) : have(H) <- !collect_all(T).
+!collect_all([H|T]) : not have(H) <-
    !pick_moving(H);
    !collect_all(T).

// go_to_obj
+!go_to_obj(O) : at(O,X,Y) <- !go_to(X,Y).

// drop
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

// aliases
have(b)  :- have(brush).
have(k)  :- have(key).
have(cd) :- have(code).
have(cl) :- have(color).

can_carry_more :- max_carry(M) & carrying_count(N) & N < M.
carrying_count(N) :- .findall(O, have(O), L) & .length(L, N).

compatible(b).
compatible(cl).
compatible(k).
compatible(cd).
compatible(t).
compatible(ch).
compatible(d).

incompatible(O) :- not compatible(O) & have(O).


