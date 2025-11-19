//beliefs of agent
pos(1,1). //agent starting position

grid_size(5,5).
carrying([]).
capacity(3).

//objects inside the environment
object(T,table).
object(Ch,chair).
object(D,door).
object(Cl,color).
object(Cd,code).
object(B,brush).
object(K,key).

//where the objects are located
at().
at().
at().
at().
at().
at().

//walls location
wall(2,2).
wall(2,1).
wall(4,4).
wall(4,5).