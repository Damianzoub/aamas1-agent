// not sure yet if this will work
+!goto(X,Y)
: position(X,y) <- true 

+!goto(X,Y)
: position(Cx,Cy)
<- !plan_path(Cx,Cy,X,Y,Path):
!follow_path(Path).

+!follow_path([]) <- true
+!follow_path([Step|Rest])
<- do_step(Step); !follow_path(Rest).