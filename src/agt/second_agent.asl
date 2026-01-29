+!start <- 
    .print("Running Agent2");
    !mission;
    .print("Agent2 Finished").

!start.

// --- SAME  KNOWLEDGE ---
grid_size(5,5).
max_carry(3).

object(t,table).
object(ch,chair).
object(d,door).
object(cl,color).
object(cd,code).
object(b,brush).
object(k,key).

needs_to_paint(t ,[b,cl]).
needs_to_paint(ch,[b,cl]).
needs_to_open(d ,[k,cd]).

at(b,1,5).
at(k,1,4).
at(cd,3,5).
at(cl,5,5).

at(ch,4,2).
at(d,3,1).
at(t,5,1).

wall(2,2).
wall(2,1).
wall(4,4).
wall(4,5).

// --- negotiation config ---
other_agent(main_agent).
// NO priority here -> loses ties

// ===================== MISSION =====================

+!mission <-
    .print("### AGENT2 MISSION STARTED ###");
    !negotiate_then_maybe_do(open_door);
    !negotiate_then_maybe_do(paint_table);
    !negotiate_then_maybe_do(paint_chair);
    .print("### AGENT2 MISSION ENDED ###").

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
                    !after_negotiate(Task).

+!after_negotiate(Task) : owner(Task,me) <- !do_task(Task).

+!after_negotiate(Task) : owner(Task,other) <- true.
//main negotiation loop
+! negotiate(Task,N) : N < 15 <-
                        !compute_utility(Task,U);
                        -+myu(Task,U);
                        -otheru(Task,_);
                        -decided(Task,_);
                        -owner(Task,_);
                        ?other_agent(OA);
                        .send(OA,tell,inform(Task,U));
                        !wait_other_inform(Task);
                        ?otheru(Task,Uo);
                        !after_otheru(Task,N,U,Uo).

//in case infinity loop stop
+!negotiate(Task,N) : N >= 15 <-
                        .print("Agent negotiation failed too many times for ",Task);
                        +owner(Task,other).

should_propose(U,Uo) :- U > Uo.

+!after_otheru(Task,N,U,Uo) : should_propose(U,Uo) <- 
                            ?other_agent(OA2);
                            .send(OA2,tell,propose(Task));
                            !wait_accept_or_reject(Task,N).

+!after_otheru(Task,N,U,Uo) : not should_propose(U,Uo) <- !wait_propose(Task,N).

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
+!wait_accept_or_reject(Task,N) : decided(Task,restart) <-
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

// agent2 loses if other >= me
other_should_win(U,Uo) :- Uo > U.
other_should_win(U,Uo) :- Uo == U.

+message(tell,Other,propose(Task)) : myu(Task,U) & otheru(Task,Uo) & other_should_win(U,Uo) <-
    .send(Other,tell,accept(Task));
    -decided(Task,_);
    +decided(Task,other);
    -owner(Task,_);
    +owner(Task,other).

+message(tell,Other,propose(Task)) : myu(Task,U) & otheru(Task,Uo) & not other_should_win(U,Uo) <-
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

// ===================== UTILITY =====================

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
    

// ===================== TASK -> GOAL =====================

+!do_task(open_door)   <- !achieve_open(d).
+!do_task(paint_table) <- !achieve_colored(t).
+!do_task(paint_chair) <- !achieve_colored(ch).

// ===================== SAME WORKER CODE (unchanged) =====================

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
