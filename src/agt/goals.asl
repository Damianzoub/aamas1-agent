//goal of agent

!mission.

+!mission <- !achieve_colored(T);
             !achieve_colored(Ch);
             !achieve_open(D).

//If Obj is already colored, do nothing
+!achieve_colored(Obj): colored(Obj) <- true.

//If Obj is not colored yet, paint it
+!achieve_colored(Obj): not colored(Obj) <- !paint(Obj).

+!paint(Obj)
:  needs_to_paint(Obj, ReqList)   // check required items (brush, color)
<- !collect_all(ReqList);         // collect required items
   !go_to_obj(Obj);               // move to the object's location
   do(paint(Obj));                // perform painting action (Java env)
   +colored(Obj).                 0// update belief: Obj is now colored



+!achieve_open(D):
not open(D) <- !ensure_open_ready(D);
                !do_open(D).        