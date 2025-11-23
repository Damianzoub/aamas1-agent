# Introduction to the Jason Agent-Oriented Language
*A short guide for collaborators who are new to Jason*

Jason is a programming language and platform for building **intelligent agents**.  
It is based on the **BDI model**:

- **Beliefs:** what the agent knows  
- **Desires:** what the agent wants  
- **Intentions:** the plans it commits to executing  

Agents reason using `.asl` files and interact with the world through a Java environment.

---

## 1. Core Components

### 1.1 Beliefs
Beliefs are facts about the world or the agent itself.

```asl
position(3,5).
has_key(false).
enemy(necro).
```
**Python Analogy**
```python
beliefs = {
    "position": (3, 5),
    "has_key": False,
    "enemy": "necro"
}
```

### 1.2 Goals
Two types of goals are used in Jason:
- **Achievement Goals**
  The agent tries to make something true.
  ```asl
  !go_to(5,6)
  ```
  **Python Analogy**
  ```python
  def achieve_go_to(x, y):
    go_to(x, y)
  ```
- **Test Goals**
  The agent queries its belief base.

  ```asl
  ?position(X,Y)
  ```
  **Python Analogy**
  ```python
  x, y = beliefs.get("position")
  ```

## 2. Plans
A plan tells the agent **when** to act and **how** to act.
General structure.
```asl
+trigger : context <- body.
```
**Python Analogy**
```python
if trigger_happens and context_is_true:
    run_body()
```

### 2.1 Triggers
The plan is activated when the trigger happens.
Common triggers:
- +b - belief added
- -b - belief removed
- +!g - an achievement goal is posted
- +?g - test goal is posted

  **Example**
  ```asl
  +!go_to(X,Y)
  ```
  **Python Analogy**
```python
def on_goal_go_to(x, y):
    handle_go_to(x, y)
```

### 2.2 context
A condition that must be true for the plan to run.
```asl
: not blocked(X,Y)
```
**Python Analogy**
```python
if not blocked(x, y):
    execute_plan()
```

### 2.3 Body
A sequence of actions, subgoals, or belief updates.
```asl
<- move_to(X,Y); !update_position.
```
**Python Analogy**
```python
move_to(x, y)
achieve_update_position()
```

## 3. Important Syntax (Cheat Sheet)

| Syntax | Meaning | Example |
|--------|---------|---------|
| `+b` | Belief added | `+position(3,4)` |
| `-b` | Belief removed | `-enemy(orcs)` |
| `+!g` | Achievement goal posted | `+!go_to(5,6)` |
| `+?g` | Test goal posted | `+?energy(E)` |
| `?b` | Query belief | `?position(X,Y)` |
| `:` | Context condition | `+!explore : not tired` |
| `<-` | Beginning of plan body | `+!start <- !explore.` |
| `;` | Sequence of actions | `move(X,Y); !update.` |
| `.` | End of plan | `+item(I) <- pick(I).` |
| `&` | Logical AND in context | `energy(E) & E > 0` |
| `not` | Negation in context | `: not blocked(X,Y)` |
| `.send` | Messaging between agents | `.send(follower, tell, ready)` |


## 4. Actions
Actions are implemented in the Java environment.
ASL Example:
```asl
+!move_to(X,Y) <- move(X,Y).
```
**Python Analogy**
```python
def on_goal_move_to(x, y):
    environment.move(x, y)
```
Java Exmaple:
```java
public boolean executeAction(String ag, Structure action, ...) {
    if(action.getFunctor().equals("move")){
        // action code here
    }
}
```
**Python Env Example**
```python
def execute_action(agent, action, *args):
    if action == "move":
        pass
```

## 5. Inter-Agent Communication
Agents can send messages:
```asl
.send(receiver, tell, message).
.send(receiver, achieve, goal).
```
Example:
```asl
+enemy_detected(E) <- .send(defender, tell, enemy(E)).
```



