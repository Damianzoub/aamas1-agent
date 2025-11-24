// actions of agent
+!move_up <- do(move(up)).
+!move_down <- do(move(down)).
+!move_left <- do(move(left)).
+!move_right <- do(move(right)).
// not sure for the grab and drop actions and open and paint actions
/**+!grab(O)
<-.print("Grabbing: ",O);
   do(grab(O));
   .add_belief(have(O));
   .del_belief(at(O,X,Y)) for at(O,X,Y);

+!drop(O) <- do(drop(O)).
+!open(D) <- do(open(D)).
+!paint(O) <- do(paint(O)).
*/
+!goto(X,Y)
: position(X,y) <- true 

+!goto(X,Y)
: position(Cx,Cy)
<- !plan_path(Cx,Cy,X,Y,Path):
!follow_path(Path).

+!follow_path([]) <- true
+!follow_path([Step|Rest])
<- do_step(Step); !follow_path(Rest).