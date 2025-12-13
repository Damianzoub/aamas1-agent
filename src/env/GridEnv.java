package env;

import java.awt.Color;
import java.awt.Font;
import java.awt.Graphics;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;

import jason.asSyntax.ASSyntax;
import jason.asSyntax.NumberTerm;
import jason.asSyntax.Structure;
import jason.environment.Environment;
import jason.environment.grid.GridWorldModel;
import jason.environment.grid.GridWorldView;
import jason.environment.grid.Location;

/**
 * Grid environment for one agent (5x5). Objects are randomized each episode.
 * Coordinates in the problem statement are 1-based; internal model is 0-based.
 */
public class GridEnv extends Environment {

    // grid size (5x5)
    public static final int WIDTH = 5;
    public static final int HEIGHT = 5;

    // object masks (integers used by GridWorldModel)
    public static final int OBST   = 1;
    public static final int BRUSH  = 2;
    public static final int KEY    = 3;
    public static final int CODE   = 4;
    public static final int DOOR   = 5;
    public static final int CHAIR  = 6;
    public static final int COLOR  = 7;
    public static final int TABLE  = 8;

    private GridModel model;
    private GridView view;

    private final Random rnd = new Random(System.currentTimeMillis());

    // agent name used in mas file 
    private final String AG_NAME = "main_agent";

    @Override
    public void init(String[] args) {
        model = new GridModel();
        view  = new GridView(model);
        model.setView(view);
        // randomize objects at the start of each episode
        model.randomizeObjects();
        updatePercepts();
    }

    @Override
    public boolean executeAction(String agName, Structure action) {
        try {
            String fun = action.getFunctor();
            double reward = 0.0;

            if (fun.equals("noop")) {
                // no-op action -> small negative reward
                reward = -0.01;
            } else if (fun.equals("move") && action.getArity() == 2) {
                // move(X,Y) where X and Y are numbers in 1-based coordinates
                int x = (int)((NumberTerm)action.getTerm(0)).solve() - 1;
                int y = (int)((NumberTerm)action.getTerm(1)).solve() - 1;
                if (model.canMoveAgentTo(x, y)) {
                    model.setAgPos(0, x, y);
                    reward = -0.02; // cost for moving
                } else {
                    reward = -0.03; // moving into blocked or invalid cell -> incompatible
                }
            } else if (fun.equals("pick") && action.getArity() == 1) {
                String obj = action.getTerm(0).toString().replaceAll("\"", "");
                // pick object at current agent location
                if (model.pickObjectAtAgent(obj)) {
                    reward = -0.02; // picking counts as moving something
                } else {
                    reward = -0.03; // incompatible (object not present)
                }
            } else if (fun.equals("paint") && action.getArity() == 1) {
                String target = action.getTerm(0).toString().replaceAll("\"", "");
                if (model.paintTarget(target)) {
                    // painting succeeds -> reward depends on target
                    if (target.equalsIgnoreCase("table")) reward = 1.0;
                    else if (target.equalsIgnoreCase("chair")) reward = 1.0;
                    else reward = -0.03;
                } else {
                    reward = -0.03; // incompatible (missing brush/color or wrong location)
                }
            } else if (fun.equals("open") && action.getArity() == 1) {
                String targ = action.getTerm(0).toString().replaceAll("\"", "");
                if (targ.equalsIgnoreCase("door")) {
                    if (model.openDoor()) {
                        reward = 0.8;
                    } else {
                        reward = -0.03; // incompatible (missing key or code)
                    }
                } else {
                    reward = -0.03;
                }
            } else {
                // unknown action
                reward = -0.03;
            }

            // send reward percept and update world percepts
            addPercept(AG_NAME, ASSyntax.createLiteral("reward(" + reward + ")"));
            updatePercepts();

            // small delay for visualization
            try { Thread.sleep(120); } catch (Exception ignored) {}

            informAgsEnvironmentChanged();
        } catch (Exception e) {
            e.printStackTrace();
        }
        return true;
    }

    /**
     * Update percepts sent to agent.
     * Percepts include:
     *  - pos(agent,X,Y)  (1-based coordinates)
     *  - at(item,X,Y)
     *  - has(item)
     *  - blocked(X,Y)
     *  - door(open) or door(closed)
     *  - colored(table) / colored(chair)
     */
    void updatePercepts() {
        clearPercepts();

        Location p = model.getAgPos(0);
        // pos uses 1-based coords for agent beliefs
        addPercept(AG_NAME, ASSyntax.createLiteral("pos(agent," + (p.x+1) + "," + (p.y+1) + ")"));

        // object percepts: at(obj,X,Y)
        addObjectPerceptIfPresent(BRUSH, "brush");
        addObjectPerceptIfPresent(KEY, "key");
        addObjectPerceptIfPresent(CODE, "code");
        addObjectPerceptIfPresent(DOOR, "door");
        addObjectPerceptIfPresent(CHAIR, "chair");
        addObjectPerceptIfPresent(COLOR, "color");
        addObjectPerceptIfPresent(TABLE, "table");

        // inventory percepts
        if (model.hasBrush) addPercept(AG_NAME, ASSyntax.createLiteral("has(brush)"));
        if (model.hasKey)   addPercept(AG_NAME, ASSyntax.createLiteral("has(key)"));
        if (model.hasCode)  addPercept(AG_NAME, ASSyntax.createLiteral("has(code)"));

        // colored / door status
        addPercept(AG_NAME, ASSyntax.createLiteral(model.tableColored ? "colored(table)" : "not_colored(table)"));
        addPercept(AG_NAME, ASSyntax.createLiteral(model.chairColored ? "colored(chair)" : "not_colored(chair)"));
        addPercept(AG_NAME, ASSyntax.createLiteral(model.doorOpen ? "door(open)" : "door(closed)"));

        // blocked cells percepts (use 1-based coords)
        for (Location l : model.getOccupiedLocationsWithMask(OBST)) {
            addPercept(AG_NAME, ASSyntax.createLiteral("blocked(" + (l.x+1) + "," + (l.y+1) + ")"));
        }
    }

    private void addObjectPerceptIfPresent(int mask, String name) {
        for (Location l : model.getOccupiedLocationsWithMask(mask)) {
            addPercept(AG_NAME, ASSyntax.createLiteral("at(" + name + "," + (l.x+1) + "," + (l.y+1) + ")"));
        }
    }

    /**
     * Inner model that extends Jason's GridWorldModel.
     */
    class GridModel extends GridWorldModel {

        // inventory and status flags
        boolean hasBrush = false;
        boolean hasKey = false;
        boolean hasCode = false;
        boolean tableColored = false;
        boolean chairColored = false;
        boolean doorOpen = false;

        GridModel() {
            super(WIDTH, HEIGHT, 1); // one agent (id 0)

            // Agent start at (1,1) -> internal (0,0)
            try {
                setAgPos(0, 0, 0);
            } catch (Exception e) {
                e.printStackTrace();
            }

            // Set fixed blocked cells (input coords are 1-based)
            add(OBST, 2-1, 1-1);
            add(OBST, 2-1, 2-1);
            add(OBST, 4-1, 4-1);
            add(OBST, 4-1, 5-1);

            // place door at fixed coordinate (3,1)
            add(DOOR, 3-1, 1-1);
        }

        /**
         * Randomize object positions each episode (except blocked cells and the door).
         * If you want exact positions instead of randomness, you can set randomize=false and
         * use the coordinates provided originally (commented below).
         */
        void randomizeObjects() {
            // clear previous object masks (brush,key,code,chair,color,table)
            removeAllMaskInstances(BRUSH);
            removeAllMaskInstances(KEY);
            removeAllMaskInstances(CODE);
            removeAllMaskInstances(CHAIR);
            removeAllMaskInstances(COLOR);
            removeAllMaskInstances(TABLE);

            // list of free locations (exclude obstacles, agent start, door)
            List<Location> free = new ArrayList<>();
            for (int x = 0; x < getWidth(); x++) {
                for (int y = 0; y < getHeight(); y++) {
                    Location l = new Location(x, y);
                    if (!hasObject(OBST, l) && !hasObject(DOOR, l) && !(x==0 && y==0)) {
                        free.add(l);
                    }
                }
            }
            Collections.shuffle(free, rnd);

            // place objects in random free cells (except door)
            int idx = 0;
            if (idx < free.size()) add(BRUSH, free.get(idx++).x, free.get(idx-1).y);
            if (idx < free.size()) add(KEY,   free.get(idx++).x, free.get(idx-1).y);
            if (idx < free.size()) add(CODE,  free.get(idx++).x, free.get(idx-1).y);
            if (idx < free.size()) add(CHAIR, free.get(idx++).x, free.get(idx-1).y);
            if (idx < free.size()) add(COLOR, free.get(idx++).x, free.get(idx-1).y);
            if (idx < free.size()) add(TABLE, free.get(idx++).x, free.get(idx-1).y);

            // reset inventory/status
            hasBrush = hasKey = hasCode = false;
            tableColored = chairColored = doorOpen = false;
        }

        /**
         * Returns list of occupied locations that have a specific mask.
         */
        List<Location> getOccupiedLocationsWithMask(int mask) {
            List<Location> out = new ArrayList<>();
            for (int x = 0; x < getWidth(); x++) {
                for (int y = 0; y < getHeight(); y++) {
                    Location l = new Location(x, y);
                    if (hasObject(mask, l)) out.add(l);
                }
            }
            return out;
        }

        // helper to remove all instances of a mask
        void removeAllMaskInstances(int mask) {
            List<Location> toRemove = new ArrayList<>();
            for (Location l : getOccupiedLocationsWithMask(mask)) toRemove.add(l);
            for (Location l : toRemove) remove(mask, l);
        }

        boolean canMoveAgentTo(int x, int y) {
            if (x < 0 || y < 0 || x >= getWidth() || y >= getHeight()) return false;
            Location l = new Location(x, y);
            return !hasObject(OBST, l);
        }

        /**
         * Attempt to pick an object named objName at agent location.
         * Returns true if successful and updates inventory.
         */
        boolean pickObjectAtAgent(String objName) {
            Location a = getAgPos(0);
            if (objName.equalsIgnoreCase("brush") && hasObject(BRUSH, a)) {
                remove(BRUSH, a); hasBrush = true; return true;
            }
            if (objName.equalsIgnoreCase("key") && hasObject(KEY, a)) {
                remove(KEY, a); hasKey = true; return true;
            }
            if (objName.equalsIgnoreCase("code") && hasObject(CODE, a)) {
                remove(CODE, a); hasCode = true; return true;
            }
            // trying to pick immovable or non-present objects is incompatible
            return false;
        }

        /**
         * Attempt to paint target at agent location. Requires brush and color.
         * Returns true on success (sets flags).
         */
        boolean paintTarget(String target) {
            Location a = getAgPos(0);
            if (!hasBrush || !hasObject(COLOR, a) && !hasColorInInventory()) {
                // must have brush and color available (color object may be carried or on ground)
                return false;
            }
            // painting table/chair requires agent be at same location as target object
            if (target.equalsIgnoreCase("table") && hasObject(TABLE, a)) {
                tableColored = true;
                return true;
            }
            if (target.equalsIgnoreCase("chair") && hasObject(CHAIR, a)) {
                chairColored = true;
                return true;
            }
            return false;
        }

        private boolean hasColorInInventory() {
            // in this simple model color is only an object on ground
            return hasCode && false; // placeholder if you want color as inventory later
        }

        /**
         * Attempt to open the door (agent must be adjacent to door).
         * Requires both key and code in inventory.
         */
        boolean openDoor() {
            Location a = getAgPos(0);
            // find door location
            List<Location> doors = getOccupiedLocationsWithMask(DOOR);
            if (doors.isEmpty()) return false;
            Location d = doors.get(0);
            // check adjacency (4-neighborhood)
            int dx = Math.abs(a.x - d.x), dy = Math.abs(a.y - d.y);
            if (!((dx + dy) == 1)) return false;
            if (hasKey && hasCode) {
                doorOpen = true;
                // remove door obstacle semantics (if any). We leave DOOR mask for percepts.
                return true;
            }
            return false;
        }
    }

    /**
     * Simple visualization view (optional).
     */
    class GridView extends GridWorldView {

        // declare local cell size and font so they are always defined
        private final int cellSizeLocal;
        private final Font defaultFontLocal;

        public GridView(GridModel model) {
            super(model, "GridEnv", 500);
            // size passed to super() is 500 — compute a cell size from that value
            int viewSize = 500;
            this.cellSizeLocal = Math.max(8, viewSize / Math.max(WIDTH, HEIGHT)); // avoid zero/too small
            this.defaultFontLocal = new Font("Arial", Font.BOLD, 14);
            setVisible(true);
            repaint();
        }

        @Override
        public void draw(Graphics g, int x, int y, int object) {
            switch (object) {
                case OBST:
                    super.drawObstacle(g, x, y);
                    break;
                case BRUSH:
                    g.setColor(Color.MAGENTA); g.fillRect(x+6, y+6, cellSizeLocal-12, cellSizeLocal-12); break;
                case KEY:
                    g.setColor(Color.ORANGE); g.fillOval(x+6, y+6, cellSizeLocal-12, cellSizeLocal-12); break;
                case CODE:
                    g.setColor(Color.CYAN); g.fillRect(x+8, y+8, cellSizeLocal-16, cellSizeLocal-16); break;
                case DOOR:
                    g.setColor(Color.DARK_GRAY); g.fillRect(x+2, y+2, cellSizeLocal-4, cellSizeLocal-4); break;
                case CHAIR:
                    g.setColor(Color.LIGHT_GRAY); g.fillRect(x+4, y+6, cellSizeLocal-8, cellSizeLocal-8); break;
                case COLOR:
                    g.setColor(Color.PINK); g.fillOval(x+6, y+6, cellSizeLocal-12, cellSizeLocal-12); break;
                case TABLE:
                    g.setColor(Color.YELLOW); g.fillRect(x+4, y+4, cellSizeLocal-8, cellSizeLocal-8); break;
            }
        }

        @Override
        public void drawAgent(Graphics g, int x, int y, Color c, int id) {
            super.drawAgent(g, x, y, Color.BLUE, id);
            drawString(g, x, y, defaultFontLocal, "A");
        }
    }
}
