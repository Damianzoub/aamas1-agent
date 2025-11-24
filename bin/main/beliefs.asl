//beliefs of agent
pos(1,1). //agent starting position

grid_size(5,5).
capacity(3).

//objects inside the environment
object(T,table).
object(Ch,chair).
object(D,door).
object(Cl,color).
object(Cd,code).
object(B,brush).
object(K,key).

//Restrictions
needs_to_paint(table,[brush,color]).
needs_to_paint(chair,[brush,color]).
needs_to_open(door,[key,code]).
max_carry(3).


//where the objects are located
at(B,1,5).
at(K,1,4).
at(Cd,3,5).
at(Cl,5,5).


//walls location
wall(2,2).
wall(2,1).
wall(4,4).
wall(4,5).

// Rewards and Penalties in java environment