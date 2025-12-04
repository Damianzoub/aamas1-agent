//Navigation goals for the agent


//Optional high-level move goals (shortcut wrappers)
+!move_up    <- do(move(up)).
+!move_down  <- do(move(down)).
+!move_left  <- do(move(left)).
+!move_right <- do(move(right)).

//Goal: go_to(X,Y)
//Use path planning (A*) from the current position to (X,Y)

//Already at target position -> nothing to do
+!go_to(X,Y) : pos(X,Y) <- true.

//Not there yet -> ask environment to plan a path, then follow that path step by step
+!go_to(X,Y) : pos(CX,CY) <- !plan_path(CX,CY,X,Y,Path); 
                             !follow_path(Path).

// Follow a path represented as a list of steps

+!follow_path([]) <- true.

+!follow_path([Step | Rest]) <- do_step(Step); 
                                !follow_path(Rest).