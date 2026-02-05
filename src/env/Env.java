// NO PACKAGE DECLARATION (Default package)

import java.awt.Color;
import java.awt.Font;
import java.awt.Graphics;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.PriorityQueue;
import java.util.logging.Logger;

import jason.asSyntax.Literal;
import jason.asSyntax.NumberTerm;
import jason.asSyntax.Structure;
import jason.asSyntax.Term;
import jason.environment.Environment;
import jason.environment.grid.GridWorldModel;
import jason.environment.grid.GridWorldView;
import jason.environment.grid.Location;


public class Env extends Environment {

    // --- Bit Masks ---
    public static final int BRUSH  = 8;
    public static final int KEY    = 16;
    public static final int CODE   = 32;
    public static final int DOOR   = 64;
    public static final int CHAIR  = 128;
    public static final int COLOR  = 256;
    public static final int TABLE  = 512;

    
    public static final int NB_AGS = 2;
    private static final String AG0 = "main_agent";
    private static final String AG1 = "second_agent";
    private String agName(int ag) { return ag == 0 ? AG0 : AG1; }

    private MyGridModel model;
    private MyGridView  view;
    static Logger logger = Logger.getLogger(Env.class.getName());

    @Override
    public void init(String[] args) {
        model = new MyGridModel();
        view  = new MyGridView(model);
        model.setView(view);
        updatePercepts();
    }

    @Override
    public boolean executeAction(String agName, Structure action) {
        int agID = agName.equals(AG1) ? 1 : 0;

        if (action.getFunctor().equals("do")) {
            Term inner = action.getTerm(0);
            if (inner instanceof Structure) action = (Structure) inner;
        }

        boolean result = false;
        double reward = 0;
        String actFunctor = action.getFunctor();

        try {
            if (actFunctor.equals("move")) {
                if (action.getArity() == 1) {
                    String dir = action.getTerm(0).toString();
                    result = model.moveAgentByDir(dir, agID);
                } else if (action.getArity() == 2) {
                    int x = (int) ((NumberTerm) action.getTerm(0)).solve();
                    int y = (int) ((NumberTerm) action.getTerm(1)).solve();
                    result = model.moveTowards(x, y, agID);
                }
            } else if (actFunctor.equals("pick")) {
                String item = action.getTerm(0).toString();
                result = model.pickItem(item, agID);
            } else if (actFunctor.equals("paint")) {
                String target = action.getTerm(0).toString();
                result = model.paintObject(target, agID);
                if (result) reward +=1.0;
            } else if (actFunctor.equals("open")) {
                String target = action.getTerm(0).toString();
                result = model.openObject(target, agID);
                if (result) reward +=0.8;
            } else if (actFunctor.equals("drop")) {
                String item = action.getTerm(0).toString();
                result = model.dropItem(item, agID);
            }

            // Penalties
            reward -= 0.01;
            if (!model.inventory[agID].isEmpty()) reward -= (0.02 * model.inventory[agID].size());

            boolean isPainting = actFunctor.equals("paint");
            boolean isOpening  = actFunctor.equals("open");
            if (isPainting && (model.hasItem("key", agID) || model.hasItem("code", agID))) reward -= 0.03;
            if (isOpening  && (model.hasItem("brush", agID) || model.hasItem("color", agID))) reward -= 0.03;

        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }

        if (result) {
            if (actFunctor.equals("move")) {
                model.stepDynamics(); // dynamics only after movement
            }
            logger.info(agName + " doing: " + action + " | Reward: " + reward);
            if (view != null) view.repaint();
            updatePercepts();
            informAgsEnvironmentChanged();
            try { Thread.sleep(250); } catch (Exception e) {}
        }
        return result;
    }

    void updatePercepts() {
        clearPercepts();

        // per-agent percepts
        for (int ag = 0; ag < NB_AGS; ag++) {
            Location la = model.getAgPos(ag);

            // each agent sees its own position as pos(X,Y)
            addPercept(agName(ag), Literal.parseLiteral("pos(" + la.x + "," + la.y + ")"));

            // each agent sees its own inventory
            for (String item : model.inventory[ag]) {
                addPercept(agName(ag), Literal.parseLiteral("have(" + item + ")"));
            }
        }

        // global task-state percepts (same for everyone)
        if (model.tablePainted) addPercept(Literal.parseLiteral("colored(t)"));
        if (model.chairPainted) addPercept(Literal.parseLiteral("colored(ch)"));
        if (model.doorOpen)     addPercept(Literal.parseLiteral("door(open)"));

        // global object locations (same for everyone)
        for (int i = 0; i < model.getWidth(); i++) {
            for (int j = 0; j < model.getHeight(); j++) {
                int data = model.getGridData(i, j);
                if ((data & BRUSH) != 0) addPercept(Literal.parseLiteral("at(b,"  + i + "," + j + ")"));
                if ((data & KEY)   != 0) addPercept(Literal.parseLiteral("at(k,"  + i + "," + j + ")"));
                if ((data & CODE)  != 0) addPercept(Literal.parseLiteral("at(cd," + i + "," + j + ")"));
                if ((data & COLOR) != 0) addPercept(Literal.parseLiteral("at(cl," + i + "," + j + ")"));
                if ((data & TABLE) != 0) addPercept(Literal.parseLiteral("at(t,"  + i + "," + j + ")"));
                if ((data & CHAIR) != 0) addPercept(Literal.parseLiteral("at(ch," + i + "," + j + ")"));
                if ((data & DOOR)  != 0) addPercept(Literal.parseLiteral("at(d,"  + i + "," + j + ")"));
            }
        }
    }

    // --- MODEL ---
    class MyGridModel extends GridWorldModel {

        @SuppressWarnings("unchecked")
        public List<String>[] inventory = (List<String>[]) new ArrayList[NB_AGS];

        public boolean tablePainted = false;
        public boolean chairPainted = false;
        public boolean doorOpen = false;

        private int stepCount = 0;
        private static final int DYN_PERIOD = 3;

        public MyGridModel() {
            super(5, 5, NB_AGS);

            for (int i = 0; i < NB_AGS; i++) inventory[i] = new ArrayList<>();

            try {
                setAgPos(0, 0, 4);
                // IMPORTANT: don't place agent2 on same cell as a static object
                setAgPos(1, 2, 2); // -> position (3,3)

                add(OBSTACLE, 1, 4); add(OBSTACLE, 1, 3);
                add(OBSTACLE, 3, 0); add(OBSTACLE, 3, 1);

                add(BRUSH, 0, 0);
                add(KEY,   0, 1);
                add(CODE,  2, 0);
                add(COLOR, 4, 0);

                // Put chair NOT on (3,3) because agent2 starts there.
                Location chairLoc = getRandomFreeLocation();
                add(CHAIR,chairLoc.x,chairLoc.y);
                Location doorLoc = getRandomFreeLocation();
                add(DOOR,doorLoc.x,doorLoc.y);
                Location tableLoc = getRandomFreeLocation();
                add(TABLE,tableLoc.x,tableLoc.y);

            } catch (Exception e) {
                e.printStackTrace();
            }
        } 
        
        private Location getRandomFreeLocation() throws Exception {
            List<Location> freeCells = new ArrayList<>();
        
            for (int x = 0; x < getWidth(); x++) {
                for (int y = 0; y < getHeight(); y++) {
                    // Check for Walls/Obstacles
                    if ((data[x][y] & OBSTACLE) != 0) continue;
        
                    // Check for Movable Items (Brush, Key, Code, Color)
                    if ((data[x][y] & (BRUSH | KEY | CODE | COLOR)) != 0) continue;
                    
                    // Check for already placed static objects (Chair, Door, Table)
                    if ((data[x][y] & (CHAIR | DOOR | TABLE)) != 0) continue;
        
                    // Check for Agents
                    boolean agentPresent = false;
                    for (int ag = 0; ag < NB_AGS; ag++) {
                        Location aPos = getAgPos(ag);
                        if (aPos != null && aPos.x == x && aPos.y == y) {
                            agentPresent = true;
                            break;
                        }
                    }
        
                    if (!agentPresent) {
                        freeCells.add(new Location(x, y));
                    }
                }
            }
        
            if (freeCells.isEmpty()) {
                throw new Exception("No free cells available for object placement!");
            }
        
            Collections.shuffle(freeCells);
            return freeCells.get(0);
        }

        public int getGridData(int x, int y) { return data[x][y]; }

        // --- A* ALGORITHM IMPLEMENTATION ---
        class Node {
            int x, y;
            int g, h, f;
            Node parent;
            public Node(int x, int y) { this.x = x; this.y = y; }
        }

        boolean moveTowards(int targetX, int targetY, int agID) {
            Location curr = getAgPos(agID);
            if (curr.x == targetX && curr.y == targetY) return true;

            List<Node> path = executeAStar(curr, new Location(targetX, targetY), agID);

            if (path != null && path.size() > 1) {
                Node nextStep = path.get(1);
                setAgPos(agID, nextStep.x, nextStep.y);
                return true;
            }
            return false;
        }

        void stepDynamics() {
            stepCount++;
            if (stepCount % DYN_PERIOD != 0) return;

            int[] movable = new int[] { BRUSH, KEY, CODE, COLOR };
            int tries = 6;

            while (tries-- > 0) {
                int mask = movable[(int)(Math.random() * movable.length)];
                if (moveObjectOneStepRandom(mask)) break;
            }
        }

        private Location findObject(int mask) {
            for (int x = 0; x < getWidth(); x++) {
                for (int y = 0; y < getHeight(); y++) {
                    if (hasObject(mask, x, y)) return new Location(x, y);
                }
            }
            return null;
        }

        private boolean cellOk(int x, int y) {
            if (x < 0 || x >= getWidth() || y < 0 || y >= getHeight()) return false;

            // no obstacles
            if ((data[x][y] & OBSTACLE) != 0) return false;

            // no agents
            for (int ag = 0; ag < NB_AGS; ag++) {
                Location a = getAgPos(ag);
                if (a != null  && a.x == x && a.y == y) return false;
            }

            

            // no other movable items (keep one item per cell)
            //if ((data[x][y] & (BRUSH | KEY | CODE | COLOR)) != 0) return false;

            return true;
        }

        private boolean moveObjectOneStepRandom(int mask) {
            Location cur = findObject(mask);
            if (cur == null) return false;

            int[][] dirs = { {0,-1}, {0,1}, {-1,0}, {1,0} };
            List<int[]> options = new ArrayList<>();

            for (int[] d : dirs) {
                int nx = cur.x + d[0];
                int ny = cur.y + d[1];
                if (cellOk(nx, ny)) options.add(d);
            }

            if (options.isEmpty()) return false;

            int[] chosen = options.get((int)(Math.random() * options.size()));
            int nx = cur.x + chosen[0];
            int ny = cur.y + chosen[1];

            remove(mask, cur.x, cur.y);
            add(mask, nx, ny);
            return true;
        }

        private List<Node> executeAStar(Location start, Location goal, int agID) {
            PriorityQueue<Node> openList = new PriorityQueue<>(Comparator.comparingInt(n -> n.f));
            boolean[][] closedList = new boolean[getWidth()][getHeight()];

            Node startNode = new Node(start.x, start.y);
            startNode.g = 0;
            startNode.h = Math.abs(start.x - goal.x) + Math.abs(start.y - goal.y);
            startNode.f = startNode.g + startNode.h;

            openList.add(startNode);

            while (!openList.isEmpty()) {
                Node current = openList.poll();

                if (current.x == goal.x && current.y == goal.y) {
                    List<Node> path = new ArrayList<>();
                    while (current != null) {
                        path.add(current);
                        current = current.parent;
                    }
                    Collections.reverse(path);
                    return path;
                }

                closedList[current.x][current.y] = true;

                int[][] directions = { {0,-1}, {0,1}, {-1,0}, {1,0} };
                for (int[] dir : directions) {
                    int nx = current.x + dir[0];
                    int ny = current.y + dir[1];

                    if (nx < 0 || nx >= getWidth() || ny < 0 || ny >= getHeight()) continue;

                    // block other agents as obstacles
                    boolean onOtherAgent = false;
                    for (int ag = 0; ag < NB_AGS; ag++) {
                        if (ag == agID) continue;
                        Location o = getAgPos(ag);
                        if (o.x == nx && o.y == ny) { onOtherAgent = true; break; }
                    }
                    if (onOtherAgent) continue;

                    boolean passable = (data[nx][ny] & OBSTACLE) == 0;
                    if (!passable || closedList[nx][ny]) continue;

                    Node neighbor = new Node(nx, ny);
                    neighbor.g = current.g + 1;
                    neighbor.h = Math.abs(nx - goal.x) + Math.abs(ny - goal.y);
                    neighbor.f = neighbor.g + neighbor.h;
                    neighbor.parent = current;

                    openList.add(neighbor);
                }
            }
            return null;
        }

        boolean moveAgentByDir(String dir, int agID) {
            try {
                Location curr = getAgPos(agID);
                Location next = new Location(curr.x, curr.y);

                if (dir.equals("up")) next.y--;
                else if (dir.equals("down")) next.y++;
                else if (dir.equals("left")) next.x--;
                else if (dir.equals("right")) next.x++;

                if (!isFree(next.x, next.y)) return false;

                // cannot move onto other agent
                for (int ag = 0; ag < NB_AGS; ag++) {
                    if (ag == agID) continue;
                    Location o = getAgPos(ag);
                    if (o.x == next.x && o.y == next.y) return false;
                }

                setAgPos(agID, next);
                return true;

            } catch (Exception e) {
                return false;
            }
        }

        boolean pickItem(String item, int agID) {
            if (inventory[agID].size() >= 3) return false;

            Location loc = getAgPos(agID);
            if (item.equals("b"))  item = "brush";
            if (item.equals("k"))  item = "key";
            if (item.equals("cd")) item = "code";
            if (item.equals("cl")) item = "color";
            int mask = 0;

            if (item.equals("brush") || item.equals("b")) mask = BRUSH;
            if (item.equals("key")   || item.equals("k")) mask = KEY;
            if (item.equals("code")  || item.equals("cd")) mask = CODE;
            if (item.equals("color") || item.equals("cl")) mask = COLOR;

            if (mask != 0 && hasObject(mask, loc.x, loc.y)) {
                remove(mask, loc.x, loc.y);
                inventory[agID].add(item);
                return true;
            }
            return false;
        }

        boolean dropItem(String item, int agID) {
            Location loc = getAgPos(agID);

            if (!inventory[agID].contains(item)) return false;

            int mask = 0;
            if (item.equals("brush")) mask = BRUSH;
            if (item.equals("key")   || item.equals("k")) mask = KEY;
            if (item.equals("code")  || item.equals("cd")) mask = CODE;
            if (item.equals("color") || item.equals("cl")) mask = COLOR;

            if (mask == 0) return false;

            add(mask, loc.x, loc.y);
            inventory[agID].remove(item);
            return true;
        }

        boolean paintObject(String obj, int agID) {
            Location loc = getAgPos(agID);
            boolean hasBrush = hasItem("brush",agID);
            boolean hasColor = hasItem("color",agID);
            if (hasBrush && hasColor){
            if (obj.equals("table") || obj.equals("t") ) {
                if (hasObject(TABLE, loc.x,loc.y)){tablePainted = true;
                return true;}
            }
            if (obj.equals("chair") || obj.equals("ch")) {
                if (hasObject(CHAIR,loc.x,loc.y)){chairPainted = true;
                return true;}
            }
        }
            return false;
        }

        boolean openObject(String obj, int agID) {
            Location loc = getAgPos(agID);
            if (!obj.equals("door"))
                return false;
        
            // optional: idempotent door
            if (doorOpen)
                return true;
        
            // require key+code here if you want
            if (!hasItem("key", agID) || !hasItem("code", agID))
                return false;
        
            if (hasObject(DOOR, loc.x, loc.y)) {
                doorOpen = true;
                return true;
            }
            return false;
        }
        

        boolean hasItem(String item, int agID) {
            if (item.equals("brush")) {
                return inventory[agID].contains("brush") || inventory[agID].contains("b");
            }
            if (item.equals("color")) {
                return inventory[agID].contains("color") || inventory[agID].contains("cl");
            }
            if (item.equals("key")) {
                return inventory[agID].contains("key") || inventory[agID].contains("k");
            }
            if (item.equals("code")) {
                return inventory[agID].contains("code") || inventory[agID].contains("cd");
            }
            return inventory[agID].contains(item);
        }
        
    }

    // --- VIEW ---
    class MyGridView extends GridWorldView {
        private int cellSize;

        public MyGridView(MyGridModel model) {
            super(model, "A* Grid Environment", 600);
            defaultFont = new Font("Arial", Font.BOLD, 14);
            this.cellSize = 600 / model.getWidth();
            setVisible(true);
            repaint();
        }

        @Override
        public void draw(Graphics g, int x, int y, int object) {
            super.draw(g, x, y, object);

            // movable items
            if ((object & BRUSH) != 0) drawIcon(g, x, y, Color.ORANGE, "Br");
            if ((object & KEY)   != 0) drawIcon(g, x, y, Color.YELLOW, "Key");
            if ((object & CODE)  != 0) drawIcon(g, x, y, Color.CYAN,   "Cd");
            if ((object & COLOR) != 0) drawIcon(g, x, y, Color.PINK,   "Col");

            MyGridModel myModel = (MyGridModel) model;

            // door/table/chair with state
            if ((object & DOOR) != 0) {
                Color c = myModel.doorOpen ? Color.GREEN : new Color(100, 50, 0);
                drawIcon(g, x, y, c, myModel.doorOpen ? "OPEN" : "DOOR");
            }
            if ((object & TABLE) != 0) {
                Color c = myModel.tablePainted ? Color.RED : Color.LIGHT_GRAY;
                drawIcon(g, x, y, c, "Tab");
            }
            if ((object & CHAIR) != 0) {
                Color c = myModel.chairPainted ? Color.RED : Color.LIGHT_GRAY;
                drawIcon(g, x, y, c, "Ch");
            }
        }

        private void drawIcon(Graphics g, int x, int y, Color c, String label) {
            g.setColor(c);
            g.fillOval(x * cellSize + 5, y * cellSize + 5, cellSize - 10, cellSize - 10);
            g.setColor(Color.BLACK);
            g.drawString(label, x * cellSize + 10, y * cellSize + (cellSize / 2) + 5);
        }
    }
}
