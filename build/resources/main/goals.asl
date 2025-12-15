//goal of agent
+!goals_loaded <- .print("### GOALS.ASL LOADED ###").

!mission.

+!mission <- !achieve_colored(T);
             !achieve_colored(Ch);
             !achieve_open(D).

//If Obj is already colored, do nothing
+!achieve_colored(Obj): colored(Obj) <- true.

//If Obj is not colored yet, paint it
+!achieve_colored(Obj): not colored(Obj) <- !paint(Obj).

//Goal: paint(Obj)
+!paint(Obj)
:  needs_to_paint(Obj, ReqList)   // check required items (brush, color)
<- !collect_all(ReqList);         // collect required items
   !go_to_obj(Obj);               // move to the object's location
   do(paint(Obj));                // perform painting action (Java env)
   +colored(Obj).                 // update belief: Obj is now colored

//Goal: achieve_open(D)
//If the door is already open, do nothing
+!achieve_open(D) : opened(D) <- true.  

//If the door is not open yet, call open(D)
+!achieve_open(D) : not opened(D) <- !open(D).

//Goal: open(D)
+!open(D)
: needs_to_open(D, ReqList)        // check required items (key, code)
<- !collect_all(ReqList);          // collect required items
   !go_to_obj(D);                  // move to the door's location
   do(open(D));                    // perform door-opening action (Java env)
   +opened(D).                     // update belief: door is now open