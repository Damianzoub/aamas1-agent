//goal of agent

!mission.

+!mission <- !achieve_colored(T);
             !achieve_colored(Ch);
             !achieve_open(D);

+!achieve_colored(Obj):
    colored(Obj)<- true.

+!achieve_colored(Obj): not colored(Obj)
<- !ensure_paint_ready(Cl);
    !do_paint(Cl);

+!achieve_open(D):
not open(D) <- !ensure_open_ready(D);
                !do_open(D).        