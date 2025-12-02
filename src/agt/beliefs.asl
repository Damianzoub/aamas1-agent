//Βeliefs of agent

//Basic world info
pos(1,1).             //agent starting position
grid_size(5,5).       //5x5 grid
max_carry(3).          //agent can carry up to 3 objects

//Objects inside the environment
object(T,table).
object(Ch,chair).
object(D,door).
object(Cl,color).
object(Cd,code).
object(B,brush).
object(K,key).

//Task requirements
//To paint T or Ch, agent needs B(brush) and Cl(color)
//To open D, agent needs K(key) and Cd(code)
needs_to_paint(T ,[B,Cl]).
needs_to_paint(Ch, [B,Cl]).
needs_to_open(D, [K,Cd]).

//Initial locations of movable objects
at(B,1,5).   // Brush
at(K,1,4).   // Key
at(Cd,3,5).  // Code
at(Cl,5,5).  // Color

//Initial locations of T, Ch, D (static version)
//Later, to make the system dynamic, these will come from percepts
at(Ch,2,2).   //Chair
at(D,1,1).    //Door
at(T,2,1).    //Table

//Walls location
wall(2,2).
wall(2,1).
wall(4,4).
wall(4,5).

//Rewards and Penalties are implemented in the java environment