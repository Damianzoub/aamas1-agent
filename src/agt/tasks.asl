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
                                  & N < Max <- do(grab(O));
                                               +have(O);
                                               -at(O,X,Y).

//Collect all objects in a list
+!collect_all([]) <- true.         //empty list: nothing to do

+!collect_all([H|T]) <- !go_to_obj(H);           // go to object H
                        !collect_object(H);      // pick it up (if capacity allows)
                        !collect_all(T).         // then collect the rest of the list

//Move to the location of object O                        
+!go_to_obj(O): at(O,X,Y) <- !go_to(X,Y). 
