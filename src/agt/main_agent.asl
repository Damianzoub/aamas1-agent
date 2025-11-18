// Beliefs = what  I know: position, inventory, what's colored/open
// Goals = what I want: explore, collect items, deliver items
// Plans = how I achieve my goals: move, pick up, drop, open

//Beliefs 
position(1,1).
carrying([]).
capacity(3).

//domain objects 
object(b).
object(k).
object(d).
object(t).
object(ch).
object(cl).
object(cd).


//entry point

-	B: Brush
-	K: Key
-	D: Door
-	T: Table
-	Ch: Chair
-	Cl: Color
-	Cd: Code
