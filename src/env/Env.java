// NO PACKAGE DECLARATION (Default package)

import java.awt.Color;
import java.awt.Font;
import java.awt.Graphics;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.PriorityQueue;
import java.util.Random;
import java.util.logging.Logger;

import jason.asSyntax.Literal;
import jason.asSyntax.NumberTerm;
import jason.asSyntax.Structure;
import jason.asSyntax.Term;
import jason.environment.Environment;
import jason.environment.grid.GridWorldModel;
import jason.environment.grid.GridWorldView;
import jason.environment.grid.Location;

// RENAMED CLASS TO 'Env'
public class Env extends Environment {

    // --- Bit Masks ---
    public static final int BRUSH  = 8;
    public static final int KEY    = 16;
    public static final int CODE   = 32;
    public static final int DOOR   = 64;
    public static final int CHAIR  = 128;
    public static final int COLOR  = 256;
    public static final int TABLE  = 512;

    private MyGridModel model;
    private MyGridView  view;
    static Logger logger = Logger.getLogger(Env.class.getName());

    // keep these consistent with your .mas2j agent names
    private static final String AG_MAIN   = "main_agent";
    private static final String AG_SECOND = "second_agent";

    @Override
    public void init(String[] args) {
        model = new MyGridModel();
        view  = new MyGridView(model);
        model.setView(view);
        updatePerceptsAll();
    }

    // Map agent name -> agent index in GridWorldModel
    private int agId(String agName) {
        if (AG_MAIN.equals(agName)) return 0;
        if (AG_SECOND.equals(agName)) return 1;

        // fallback: if you change names and forget here
        // return 0 so it doesn't crash
        return 0;
    }

    @Override
    public boolean executeAction(String agName, Structure action) {
        if (action.getFunctor().equals("do")) {
            Term inner = action.getTerm(0);
            if (inner instanceof Structure) action = (Structure) inner;
        }

        boolean result = false;
        double reward = 0;
        String actFunctor = action.getFunctor();
        int id = agId(agName);

        try {
            if (actFunctor.equals("move")) {
                if (action.getArity() == 1) {
                    String dir = action.getTerm(0).toString();
                    result = model.moveAgentByDir(id, dir);
                } else if (action.getArity() == 2) {
                    int x = (int)((NumberTerm)action.getTerm(0)).solve();
                    int y = (int)((NumberTerm)action.getTerm(1)).solve();
                    result = model.moveTowards(id, x, y);
                }
            }
            else if (actFunctor.equals("pick")) {
                String item = action.getTerm(0).toString();
                result = model.pickItem(id, item);
            }
            else if (actFunctor.equals("drop")) {
                String item = action.getTerm(0).toString();
                result = model.dropItem(id, item);
            }
            else if (actFunctor.equals("paint")) {
                String target = action.getTerm(0).toString();
                if (model.hasItem(id, "brush") && model.hasItem(id, "color")) {
                    result = model.paintObject(id, target);
                    if (result) reward += 1.0;
                }
            }
            else if (actFunctor.equals("open")) {
                String target = action.getTerm(0).toString();
                if (model.hasItem(id, "key") && model.hasItem(id, "code")) {
                    result = model.openObject(id, target);
                    if (result) reward += 0.8;
                }
            }

            // Penalties
            reward -= 0.01;
            if (!model.inventory[id].isEmpty()) reward -= (0.02 * model.inventory[id].size());

            boolean isPainting = actFunctor.equals("paint");
            boolean isOpening  = actFunctor.equals("open");
            if (isPainting && (model.hasItem(id, "key") || model.hasItem(id, "code"))) reward -= 0.03;
            if (isOpening && (model.hasItem(id, "brush") || model.hasItem(id, "color"))) reward -= 0.03;

        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }

        if (result) {
            // dynamics only after a MOVE (from whichever agent moved)
            if (actFunctor.equals("move")) {
                model.stepDynamics();
            }

            logger.info(agName + " doing: " + action + " | Reward: " + reward);
            if (view != null) view.repaint();

            updatePerceptsAll();

            try { Thread.sleep(250); } catch (Exception e) {}
            informAgsEnvironmentChanged();
        }

        return result;
    }

    // Update percepts for BOTH agents (each one sees its own pos/have)
    void updatePerceptsAll() {
        clearAllPercepts();

        // --- per-agent percepts ---
        updatePerceptsFor(AG_MAIN);
        updatePerceptsFor(AG_SECOND);

        // --- shared world percepts (we can add them to both) ---
        addSharedWorldPercepts(AG_MAIN);
        addSharedWorldPercepts(AG_SECOND);
    }

    private void updatePerceptsFor(String agName) {
        int id = agId(agName);

        Location l = model.getAgPos(id);
        addPercept(agName, Literal.parseLiteral("pos(" + l.x + "," + l.y + ")"));

        for (String item : model.inventory[id]) {
            addPercept(agName, Literal.parseLiteral("have(" + item + ")"));
        }

        if (model.tablePainted) addPercept(agName, Literal.parseLiteral("colored(table)"));
        if (model.chairPainted) addPercept(agName, Literal.parseLiteral("colored(chair)"));
        if (model.doorOpen)     addPercept(agName, Literal.parseLiteral("door(open)"));
    }

    private void addSharedWorldPercepts(String agName) {
        // object locations (same for both agents)
        for (int i = 0; i < model.getWidth(); i++) {
            for (int j = 0; j < model.getHeight(); j++) {
                int data = model.getGridData(i, j);
                if ((data & BRUSH) != 0) addPercept(agName, Literal.parseLiteral("at(b," + i + "," + j + ")"));
                if ((data & KEY)   != 0) addPercept(agName, Literal.parseLiteral("at(k," + i + "," + j + ")"));
                if ((data & CODE)  != 0) addPercept(agName, Literal.parseLiteral("at(cd," + i + "," + j + ")"));
                if ((data & COLOR) != 0) addPercept(agName, Literal.parseLiteral("at(cl," + i + "," + j + ")"));
                if ((data & TABLE) != 0) addPercept(agName, Literal.parseLiteral("at(t," + i + "," + j + ")"));
                if ((data & CHAIR) != 0) addPercept(agName, Literal.parseLiteral("at(ch," + i + "," + j + ")"));
                if ((data & DOOR)  != 0) addPercept(agName, Literal.parseLiteral("at(d," + i + "," + j + ")"));
            }
        }
    }

    // --- MODEL ---
    class MyGridModel extends GridWorldModel {

        // inventory per agent
        @SuppressWarnings("unchecked")
        public List<String>[] inventory = new ArrayList[] {
            new ArrayList<>(), // agent 0
            new ArrayList<>()  // agent 1
        };

        public boolean tablePainted = false;
        public boolean chairPainted = false;
        public boolean doorOpen = false;

        private int stepCount = 0;
        private final Random rnd = new Random();
        private static final int DYN_PERIOD = 3;

        public MyGridModel() {
            super(5, 5, 2); //two agents

            try {
                // place both agents (ensure they’re not on obstacles)
                setAgPos(0, 0, 4); // main_agent
                setAgPos(1, 2,2); // second_agent (pick any safe cell)

                // obstacles
                add(OBSTACLE, 1, 4); add(OBSTACLE, 1, 3);
                add(OBSTACLE, 3, 0); add(OBSTACLE, 3, 1);

                // items
                add(BRUSH, 0, 0);
                add(KEY,   0, 1);
                add(CODE,  2, 0);
                add(COLOR, 4, 0);

                // targets (random each episode)
                placeRandomTarget(DOOR);
                placeRandomTarget(CHAIR);
                placeRandomTarget(TABLE);

            } catch (Exception e) {
                e.printStackTrace();
            }
        }

        public int getGridData(int x, int y) { return data[x][y]; }

        // --- A* ALGORITHM IMPLEMENTATION ---
        class Node {
            int x, y;
            int g, h, f;
            Node parent;
            public Node(int x, int y) { this.x = x; this.y = y; }
        }

        boolean moveTowards(int ag, int targetX, int targetY) {
            Location curr = getAgPos(ag);
            if (curr.x == targetX && curr.y == targetY) return true;

            List<Node> path = executeAStar(curr, new Location(targetX, targetY));
            if (path != null && path.size() > 1) {
                Node nextStep = path.get(1);
                setAgPos(ag, nextStep.x, nextStep.y);
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
                int mask = movable[rnd.nextInt(movable.length)];
                if (moveObjectOneStepRandom(mask)) break;
            }
        }

        // randomizing putting chair,table,door
        private boolean cellFreeForTargets(int x, int y) {
            if (x < 0 || x >= getWidth() || y < 0 || y >= getHeight()) return false;

            if ((data[x][y] & OBSTACLE) != 0) return false;
            if ((data[x][y] & (BRUSH | KEY | CODE | COLOR)) != 0) return false;
            if ((data[x][y] & (DOOR | CHAIR | TABLE)) != 0) return false;

            // avoid BOTH agents
            Location a0 = getAgPos(0);
            Location a1 = getAgPos(1);
            if ((a0.x == x && a0.y == y) || (a1.x == x && a1.y == y)) return false;

            return true;
        }

        private void placeRandomTarget(int mask) {
            for (int tries = 0; tries < 200; tries++) {
                int x = rnd.nextInt(getWidth());
                int y = rnd.nextInt(getHeight());
                if (cellFreeForTargets(x, y)) {
                    add(mask, x, y);
                    return;
                }
            }
            throw new RuntimeException("Could not place target mask=" + mask);
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

            if ((data[x][y] & OBSTACLE) != 0) return false;

            // not on any agent
            Location a0 = getAgPos(0);
            Location a1 = getAgPos(1);
            if ((a0.x == x && a0.y == y) || (a1.x == x && a1.y == y)) return false;

            // not on targets
            if ((data[x][y] & DOOR)  != 0) return false;
            if ((data[x][y] & CHAIR) != 0) return false;
            if ((data[x][y] & TABLE) != 0) return false;

            // not on other moving items (so we don’t stack them)
            if ((data[x][y] & (BRUSH | KEY | CODE | COLOR)) != 0) return false;

            return true;
        }

        private boolean moveObjectOneStepRandom(int mask) {
            Location cur = findObject(mask);
            if (cur == null) return false;

            int[][] dirs = { {0,-1},{0,1},{-1,0},{1,0} };
            List<int[]> options = new ArrayList<>();

            for (int[] d : dirs) {
                int nx = cur.x + d[0];
                int ny = cur.y + d[1];
                if (cellOk(nx, ny)) options.add(d);
            }
            if (options.isEmpty()) return false;

            int[] chosen = options.get(rnd.nextInt(options.size()));
            int nx = cur.x + chosen[0];
            int ny = cur.y + chosen[1];

            remove(mask, cur.x, cur.y);
            add(mask, nx, ny);
            return true;
        }

        private List<Node> executeAStar(Location start, Location goal) {
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

                int[][] directions = {{0,-1}, {0,1}, {-1,0}, {1,0}};
                for (int[] dir : directions) {
                    int nx = current.x + dir[0];
                    int ny = current.y + dir[1];

                    if (nx >= 0 && nx < getWidth() && ny >= 0 && ny < getHeight()) {
                        boolean passable = isFree(nx, ny) || (nx == goal.x && ny == goal.y);
                        if (passable && !closedList[nx][ny]) {
                            Node neighbor = new Node(nx, ny);
                            neighbor.g = current.g + 1;
                            neighbor.h = Math.abs(nx - goal.x) + Math.abs(ny - goal.y);
                            neighbor.f = neighbor.g + neighbor.h;
                            neighbor.parent = current;
                            openList.add(neighbor);
                        }
                    }
                }
            }
            return null;
        }

        boolean moveAgentByDir(int ag, String dir) {
            try {
                Location curr = getAgPos(ag);
                Location next = new Location(curr.x, curr.y);

                if (dir.equals("up")) next.y--;
                else if (dir.equals("down")) next.y++;
                else if (dir.equals("left")) next.x--;
                else if (dir.equals("right")) next.x++;

                if (isFree(next.x, next.y)) {
                    setAgPos(ag, next);
                    return true;
                }
                return false;
            } catch (Exception e) {
                return false;
            }
        }

        boolean pickItem(int ag, String item) {
            if (inventory[ag].size() >= 3) return false;
            Location loc = getAgPos(ag);

            int mask = 0;
            if (item.equals("brush")) mask = BRUSH;
            if (item.equals("key"))   mask = KEY;
            if (item.equals("code"))  mask = CODE;
            if (item.equals("color")) mask = COLOR;

            if (mask != 0 && hasObject(mask, loc.x, loc.y)) {
                remove(mask, loc.x, loc.y);
                inventory[ag].add(item);
                return true;
            }
            return false;
        }

        boolean dropItem(int ag, String item) {
            Location loc = getAgPos(ag);
            if (!inventory[ag].contains(item)) return false;

            int mask = 0;
            if (item.equals("brush")) mask = BRUSH;
            if (item.equals("key"))   mask = KEY;
            if (item.equals("code"))  mask = CODE;
            if (item.equals("color")) mask = COLOR;

            if (mask == 0) return false;

            add(mask, loc.x, loc.y);
            inventory[ag].remove(item);
            return true;
        }

        boolean paintObject(int ag, String obj) {
            Location loc = getAgPos(ag);
            if (obj.equals("table") && hasObject(TABLE, loc.x, loc.y)) {
                tablePainted = true;
                return true;
            }
            if (obj.equals("chair") && hasObject(CHAIR, loc.x, loc.y)) {
                chairPainted = true;
                return true;
            }
            return false;
        }

        boolean openObject(int ag, String obj) {
            Location loc = getAgPos(ag);
            if (obj.equals("door") && hasObject(DOOR, loc.x, loc.y)) {
                doorOpen = true;
                return true;
            }
            return false;
        }

        boolean hasItem(int ag, String item) { return inventory[ag].contains(item); }
    }

    // --- VIEW ---
    class MyGridView extends GridWorldView {
        private int cellSize;

        public MyGridView(MyGridModel model) {
            super(model, "A* Grid Environment (2 agents)", 600);
            defaultFont = new Font("Arial", Font.BOLD, 14);
            this.cellSize = 600 / model.getWidth();
            setVisible(true);
            repaint();
        }

        @Override
        public void draw(Graphics g, int x, int y, int object) {
            super.draw(g, x, y, object);

            if ((object & BRUSH) != 0) drawIcon(g, x, y, Color.ORANGE, "Br");
            if ((object & KEY)   != 0) drawIcon(g, x, y, Color.YELLOW, "Key");
            if ((object & CODE)  != 0) drawIcon(g, x, y, Color.CYAN,   "Cd");
            if ((object & COLOR) != 0) drawIcon(g, x, y, Color.PINK,   "Col");

            MyGridModel myModel = (MyGridModel) model;

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
            g.drawString(label, x * cellSize + 10, y * cellSize + (cellSize/2) + 5);
        }
    }
}
