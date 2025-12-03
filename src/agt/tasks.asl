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
                                  & N < Max                 <- do(grab(O));
                                                               +have(O);
                                                               -at(O,X,Y).
