package env;

import java.util.ArrayList;
import java.util.List;

import jason.asSyntax.ASSyntax;
import jason.asSyntax.NumberTerm;
import jason.asSyntax.Structure;
import jason.environment.Environment;
import jason.environment.grid.GridWorldModel;
import jason.environment.grid.Location;

public class GridEnv extends Environment {

    public static final int WIDTH  = 5;
    public static final int HEIGHT = 5;

    // Bitmask objects
    public static final int OBST  = 1 << 2;

    public static final int BRUSH = 1 << 8;   // B
    public static final int KEY   = 1 << 9;   // K
    public static final int CODE  = 1 << 10;  // Cd
    public static final int DOOR  = 1 << 11;  // D
    public static final int CHAIR = 1 << 12;  // Ch
    public static final int COLOR = 1 << 13;  // Cl
    public static final int TABLE = 1 << 6;   // T

    // so .plan_path can access the current model
    public static GridModel CURRENT_MODEL;

    private GridModel model;
    private GridView view;
    public static final String AG_NAME = "main_agent";

    // ===== Experiment bookkeeping (for GUI + optional agent control) =====
    private boolean experimentMode = false;
    private int episode = 0;
    private int stepCounter = 0;
    private double totalUtility = 0.0;
    private int maxEpisodes = 100;

    @Override
    public void init(String[] args) {
        super.init(args);
        model = new GridModel();
        CURRENT_MODEL = model;

        model.resetToPdfLayout();

        view = new GridView(model);
        view.setEnvHooks(
                () -> startExperiment(100),
                () -> resetEpisode(),
                () -> startExperiment(1)
        );

        updatePercepts();
        if (view != null) view.updateFromModel(model);
        informAgsEnvironmentChanged();
    }

    @Override
    public boolean executeAction(String agName, Structure action) {
        try {
            String fun = action.getFunctor();
            double reward = 0.0;

            // count steps only when we actually execute something meaningful
            boolean countedStep = false;

            // -------- aliases to match your ASL --------
            // grab(X) == pick(X)
            if (fun.equals("grab")) fun = "pick";
            // put(X)  == drop(X)
            if (fun.equals("put"))  fun = "drop";

            if (fun.equals("noop")) {
                reward = -0.01;
                countedStep = true;
            }

            // move(dir)
            else if (fun.equals("move") && action.getArity() == 1) {
                String dir = stripQuotes(action.getTerm(0).toString());

                Location a = model.getAgPos(0);
                int nx = a.x, ny = a.y;

                if (dir.equalsIgnoreCase("up"))         ny -= 1;   // internal coords
                else if (dir.equalsIgnoreCase("down"))  ny += 1;
                else if (dir.equalsIgnoreCase("left"))  nx -= 1;
                else if (dir.equalsIgnoreCase("right")) nx += 1;
                else reward = -0.03;

                if (reward == 0.0) {
                    if (model.canMoveAgentTo(nx, ny)) {
                        model.setAgPos(0, nx, ny);
                        reward = -0.02;
                    } else reward = -0.03;
                }
                countedStep = true;
            }

            // move(X,Y) : PDF coords -> take one A* step towards it
            else if (fun.equals("move") && action.getArity() == 2) {
                int X = (int)((NumberTerm)action.getTerm(0)).solve(); // PDF coords
                int Y = (int)((NumberTerm)action.getTerm(1)).solve();

                int gx = model.ix(X);
                int gy = model.iy(Y);

                Location start = model.getAgPos(0);
                boolean[][] blocked = model.blockedGrid();

                if (blocked[gy][gx]) {
                    reward = -0.03;
                } else {
                    List<PathFinding.Cell> path = PathFinding.findPath(start.x, start.y, gx, gy, blocked);
                    if (!path.isEmpty()) {
                        if (path.size() >= 2) {
                            PathFinding.Cell next = path.get(1);
                            model.setAgPos(0, next.x, next.y);
                        }
                        reward = -0.02;
                    } else reward = -0.03;
                }
                countedStep = true;
            }

            // pick(X)
            else if (fun.equals("pick") && action.getArity() == 1) {
                String tok = stripQuotes(action.getTerm(0).toString());
                boolean ok = model.pickAtAgent(tok);
                reward = ok ? -0.02 : -0.03;
                countedStep = true;
            }

            // drop(X)
            else if (fun.equals("drop") && action.getArity() == 1) {
                String tok = stripQuotes(action.getTerm(0).toString());
                boolean ok = model.dropAtAgent(tok);
                reward = ok ? -0.02 : -0.03;
                countedStep = true;
            }

            // paint(X)
            else if (fun.equals("paint") && action.getArity() == 1) {
                String target = stripQuotes(action.getTerm(0).toString());
                boolean ok = model.paintTarget(target);
                reward = ok ? 1.0 : -0.03;
                countedStep = true;
            }

            // open(door)
            else if (fun.equals("open") && action.getArity() == 1) {
                String tok = stripQuotes(action.getTerm(0).toString());
                boolean ok = (tok.equalsIgnoreCase("D") || tok.equalsIgnoreCase("door")) && model.openDoor();
                reward = ok ? 0.8 : -0.03;
                countedStep = true;
            }

            // reset
            else if (fun.equals("reset") && action.getArity() == 0) {
                resetEpisode();
                reward = -0.01;
            }

            // next_episode (optional if you want your agent to run many episodes)
            else if (fun.equals("next_episode") && action.getArity() == 0) {
                finishEpisodeAndMaybeContinue();
                reward = -0.01;
            }

            else {
                reward = -0.03;
                countedStep = true;
            }

            // state reward
            reward += model.carryingReward();

            if (countedStep) stepCounter++;
            updatePercepts();
            addPercept(AG_NAME,ASSyntax.createLiteral("reward(" + reward + ")"));
            
            if (view != null) view.updateFromModel(model);

            informAgsEnvironmentChanged();

        } catch (Exception e) {
            e.printStackTrace();
        }
        return true;
    }

    // ===================== Percepts (PDF coords, matching your ASL) =====================

    void updatePercepts() {
        clearPercepts();

        Location p = model.getAgPos(0);
        if (p == null){
            p = new Location(model.ix(1),model.iy(1));
        }
        // pos(X,Y)
        addPercept(AG_NAME,ASSyntax.createLiteral(
               "pos(" + model.px(p.x) + "," + model.py(p.y) + ")"
        ));

        // objects: at(Symbol,X,Y)
        addObjectPerceptIfPresent(BRUSH, "b");
        addObjectPerceptIfPresent(KEY,   "k");
        addObjectPerceptIfPresent(CODE,  "cd");
        addObjectPerceptIfPresent(COLOR, "cl");
        addObjectPerceptIfPresent(TABLE, "t");
        addObjectPerceptIfPresent(CHAIR, "ch");
        addObjectPerceptIfPresent(DOOR,  "d");


        // inventory: provide BOTH has/1 and have/1 so your old plans won’t break
        if (model.hasBrush) addPercept(AG_NAME, ASSyntax.createLiteral("have(b)"));
        if (model.hasKey)   addPercept(AG_NAME, ASSyntax.createLiteral("have(k)"));
        if (model.hasCode)  addPercept(AG_NAME, ASSyntax.createLiteral("have(cd)"));
        if (model.hasColor) addPercept(AG_NAME, ASSyntax.createLiteral("have(cl)"));


        // capacity percepts (your ASL uses these)
        addPercept( AG_NAME,ASSyntax.createLiteral("max_carry(" + GridModel.MAX_CARRY + ")"));
        addPercept( AG_NAME,ASSyntax.createLiteral("carrying_count(" + model.carriedCount() + ")"));

        // status
        if (model.tableColored){
            addPercept(AG_NAME, ASSyntax.createLiteral("colored(table)"));
        }
        if (model.chairColored){
            addPercept(AG_NAME, ASSyntax.createLiteral("colored(chair)"));
        }
        if (model.doorOpen){
            addPercept(AG_NAME, ASSyntax.createLiteral("door(open)"));
        }else{
            addPercept(AG_NAME, ASSyntax.createLiteral("door(closed)"));
        }
        // walls
        for (Location l : model.getOccupiedLocationsWithMask(OBST)) {
            addPercept(AG_NAME,ASSyntax.createLiteral(
                    "wall(" + model.px(l.x) + "," + model.py(l.y) + ")"
            ));
        }

        // episode/step/experiment
        addPercept(AG_NAME, ASSyntax.createLiteral("episode(" + episode + ")"));
        addPercept(AG_NAME, ASSyntax.createLiteral("step(" + stepCounter + ")"));
        if (experimentMode) addPercept(AG_NAME,ASSyntax.createLiteral("experiment(running)"));
    }

    private void addObjectPerceptIfPresent(int mask, String sym) {
        for (Location l : model.getOccupiedLocationsWithMask(mask)) {
            addPercept(AG_NAME, ASSyntax.createLiteral(
                    "at(" + sym + "," + model.px(l.x) + "," + model.py(l.y) + ")"
            ));
        }
    }

    private static String stripQuotes(String s) {
        return s.replace("\"", "");
    }

    // ===================== Experiment controls =====================
    private void runOneEpisode(){
        experimentMode = false;
        resetEpisode();
    }
    private void startExperiment(int episodes) {
        experimentMode = true;
        maxEpisodes = episodes;
        totalUtility = 0.0;
        episode = 0;
        resetEpisode();
    }

    private void resetEpisode() {
        model.resetToPdfLayout();
        stepCounter = 0;
        updatePercepts();
        if (view != null) view.updateFromModel(model);
        informAgsEnvironmentChanged();
    }

    private void finishEpisodeAndMaybeContinue() {
        int goalsAchieved = 0;
        if (model.tableColored) goalsAchieved++;
        if (model.chairColored) goalsAchieved++;
        if (model.doorOpen) goalsAchieved++;

        double utility = (100.0 * goalsAchieved) - stepCounter;
        totalUtility += utility;

        episode++;

        if (experimentMode && episode >= maxEpisodes) {
            System.out.println(">>> EXPERIMENT COMPLETE <<<");
            System.out.println("Average Utility (" + maxEpisodes + " episodes): " + (totalUtility / maxEpisodes));
            experimentMode = false;
        }

        resetEpisode();
    }

    // ===================== Model =====================

    public class GridModel extends GridWorldModel {

        static final int MAX_CARRY = 3;

        boolean hasBrush = false;
        boolean hasKey   = false;
        boolean hasCode  = false;
        boolean hasColor = false;

        boolean tableColored = false;
        boolean chairColored = false;
        boolean doorOpen     = false;

        public GridModel() {
            super(WIDTH, HEIGHT, 1);
        }

        // PDF (1-based, bottom-left) -> internal (0-based, top-left)
        int ix(int X) { return X - 1; }
        int iy(int Y) { return HEIGHT - Y; }

        // internal -> PDF
        int px(int x) { return x + 1; }
        int py(int y) { return HEIGHT - y; }

        void resetToPdfLayout() {
            clearAllObjects();

            try { setAgPos(0, ix(1), iy(1)); } catch (Exception e) { e.printStackTrace(); }

            // walls (PDF): (2,1), (2,2), (4,4), (4,5)
            add(OBST, ix(2), iy(1));
            add(OBST, ix(2), iy(2));
            add(OBST, ix(4), iy(4));
            add(OBST, ix(4), iy(5));

            // objects (fixed positions)
            add(BRUSH, ix(1), iy(5));
            add(KEY,   ix(1), iy(4));
            add(CODE,  ix(3), iy(5));
            add(COLOR, ix(5), iy(5));
            add(CHAIR, ix(4), iy(2));
            add(DOOR,  ix(3), iy(1));
            add(TABLE, ix(5), iy(1));

            hasBrush = hasKey = hasCode = hasColor = false;
            tableColored = chairColored = doorOpen = false;
        }

        boolean[][] blockedGrid() {
            boolean[][] blocked = new boolean[HEIGHT][WIDTH];
            for (int y = 0; y < HEIGHT; y++) {
                for (int x = 0; x < WIDTH; x++) {
                    blocked[y][x] = hasObject(OBST, new Location(x,y));
                }
            }
            return blocked;
        }

        private void clearAllObjects() {
            for (int x = 0; x < getWidth(); x++) {
                for (int y = 0; y < getHeight(); y++) {
                    Location l = new Location(x, y);
                    remove(OBST,  l);
                    remove(BRUSH, l);
                    remove(KEY,   l);
                    remove(CODE,  l);
                    remove(DOOR,  l);
                    remove(CHAIR, l);
                    remove(COLOR, l);
                    remove(TABLE, l);
                }
            }
        }

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

        boolean canMoveAgentTo(int x, int y) {
            if (x < 0 || y < 0 || x >= getWidth() || y >= getHeight()) return false;
            return !hasObject(OBST, new Location(x, y));
        }

        int carriedCount() {
            int c = 0;
            if (hasBrush) c++;
            if (hasKey)   c++;
            if (hasCode)  c++;
            if (hasColor) c++;
            return c;
        }

        boolean pickAtAgent(String tok) {
            if (carriedCount() >= MAX_CARRY) return false;

            Location a = getAgPos(0);
            int mask = tokenToMask(tok);
            if (mask == 0) return false;

            if (hasObject(mask, a)) {
                remove(mask, a);
                setInventory(mask, true);
                return true;
            }
            return false;
        }

        boolean dropAtAgent(String tok) {
            Location a = getAgPos(0);
            int mask = tokenToMask(tok);
            if (mask == 0) return false;

            if (!getInventory(mask)) return false;
            if (hasObject(OBST, a)) return false;

            // don't stack pickup items
            if (hasObject(BRUSH, a) || hasObject(KEY, a) || hasObject(CODE, a) || hasObject(COLOR, a)) return false;

            add(mask, a.x, a.y);
            setInventory(mask, false);
            return true;
        }

        private int tokenToMask(String tok) {
            if (tok.equalsIgnoreCase("b")  || tok.equalsIgnoreCase("brush")) return BRUSH;
            if (tok.equalsIgnoreCase("k")  || tok.equalsIgnoreCase("key"))   return KEY;
            if (tok.equalsIgnoreCase("cd") || tok.equalsIgnoreCase("code"))  return CODE;
            if (tok.equalsIgnoreCase("cl") || tok.equalsIgnoreCase("color")) return COLOR;
            return 0;
        }

        private void setInventory(int mask, boolean v) {
            if (mask == BRUSH) hasBrush = v;
            if (mask == KEY)   hasKey = v;
            if (mask == CODE)  hasCode = v;
            if (mask == COLOR) hasColor = v;
        }

        private boolean getInventory(int mask) {
            if (mask == BRUSH) return hasBrush;
            if (mask == KEY)   return hasKey;
            if (mask == CODE)  return hasCode;
            if (mask == COLOR) return hasColor;
            return false;
        }

        boolean paintTarget(String targetTok) {
            Location a = getAgPos(0);
            if (!hasBrush || !hasColor) return false;

            if (targetTok.equalsIgnoreCase("T") || targetTok.equalsIgnoreCase("table")) {
                if (hasObject(TABLE, a)) { tableColored = true; return true; }
                return false;
            }
            if (targetTok.equalsIgnoreCase("Ch") || targetTok.equalsIgnoreCase("chair")) {
                if (hasObject(CHAIR, a)) { chairColored = true; return true; }
                return false;
            }
            return false;
        }

        boolean openDoor() {
            if (!hasKey || !hasCode) return false;

            Location a = getAgPos(0);
            List<Location> ds = getOccupiedLocationsWithMask(DOOR);
            if (ds.isEmpty()) return false;

            Location d = ds.get(0);
            int manhattan = Math.abs(a.x - d.x) + Math.abs(a.y - d.y);
            if (manhattan != 1) return false;

            doorOpen = true;
            return true;
        }

        double carryingReward() {
            int carried = carriedCount();
            if (carried == 0) return -0.01;
            return carried * (-0.02);
        }
    }
}
