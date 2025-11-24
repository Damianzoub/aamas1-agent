do(move(up)).
do(move(down)).
do(move(left)).
do(move(right)).

do(grab(O)).
do(drop(O)).
do(open(D)).
do(paint(O)).

+!paint_obj(O):
: needs_to_paint(O,ReqList)
<- !collect_all(ReqList);
    !go_to_obj(O);
    do(paint(O)).

+!open_door: needs_to_open(door,ReqList)
<- !collect_all(ReqList);
    !go_to_obj(door);
    do(open(door)).

+!collect_object(O)
: not have(O) & at(O,X,Y) & pos(X,Y) & carrying_count(N) & capacity(Max) & N < Max
<- do(grab(O));
    +have(O);
    !inc_carry;
    -at(O,X,Y).