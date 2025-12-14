package env;

import java.awt.Color;
import java.awt.Font;
import java.awt.Graphics;
import java.util.ArrayList;
import java.util.List;

import jason.asSyntax.ASSyntax;
import jason.asSyntax.NumberTerm;
import jason.asSyntax.Structure;
import jason.environment.Environment;
import jason.environment.grid.GridWorldModel;
import jason.environment.grid.GridWorldView;
import jason.environment.grid.Location;

/**
 * Grid environment for one agent (5x5) - FIXED layout based on the PDF + your beliefs.asl.
 *
 * IMPORTANT: Agent beliefs/actions use PDF coordinates:
 *   - 1-based
 *   - origin at bottom-left
 *
 * Jason internal model uses:
 *   - 0-based
 *   - origin at top-left
 *
 * So we flip Y when converting.
 */
public class GridEnv extends Environment {

    public static final int WIDTH  = 5;
    public static final int HEIGHT = 5;

    // Bitmask objects (powers of two)
    public static final int OBST  = 1;
    public static final int BRUSH = 2;     // B
    public static final int KEY   = 4;     // K
    public static final int CODE  = 8;     // Cd
    public static final int DOOR  = 16;    // D
    public static final int CHAIR = 32;    // Ch
    public static final int COLOR = 64;    // Cl
    public static final int TABLE = 128;   // T

    private GridModel model;
    private GridView view;

    private final String AG_NAME = "main_agent";

    @Override
    public void init(String[] args) {
        model = new GridModel();
        model.resetToPdfLayout();
        view  = new GridView(model);
        model.setView(view);
        view.repaint();
        updatePercepts();
    }

    @Override
    public boolean executeAction(String agName, Structure action) {
        try {
            String fun = action.getFunctor();
            double reward = 0.0;

            if (fun.equals("noop")) {
                reward = -0.01;
            }

            else if (fun.equals("move") && action.getArity() == 2) {
                int X = (int)((NumberTerm)action.getTerm(0)).solve(); // PDF coords
                int Y = (int)((NumberTerm)action.getTerm(1)).solve();

                int x = model.ix(X);
                int y = model.iy(Y);

                if (model.canMoveAgentTo(x, y)) {
                    model.setAgPos(0, x, y);
                    reward = -0.02;
                } else {
                    reward = -0.03;
                }
            }

            else if (fun.equals("pick") && action.getArity() == 1) {
                String tok = stripQuotes(action.getTerm(0).toString()); // accepts B/K/Cd/Cl or brush/key/code/color
                boolean ok = model.pickAtAgent(tok);
                reward = ok ? -0.02 : -0.03;
            }

            else if (fun.equals("drop") && action.getArity() == 1) {
                String tok = stripQuotes(action.getTerm(0).toString());
                boolean ok = model.dropAtAgent(tok);
                reward = ok ? -0.02 : -0.03;
            }

            else if (fun.equals("paint") && action.getArity() == 1) {
                String target = stripQuotes(action.getTerm(0).toString()); // accepts T/Ch or table/chair
                boolean ok = model.paintTarget(target);
                if (ok) {
                    // PDF: painting table/chair yields +1 (you can make it one-time if you want)
                    reward = 1.0;
                } else {
                    reward = -0.03;
                }
            }

            else if (fun.equals("open") && action.getArity() == 1) {
                String tok = stripQuotes(action.getTerm(0).toString()); // accepts D/door
                boolean ok = tok.equalsIgnoreCase("D") || tok.equalsIgnoreCase("door")
                        ? model.openDoor()
                        : false;
                reward = ok ? 0.8 : -0.03;
            }

            else if (fun.equals("reset") && action.getArity() == 0) {
                model.resetToPdfLayout();
                reward = -0.01;
            }

            else {
                reward = -0.03;
            }

            // Add state reward R(s) for carrying items (PDF style)
            reward += model.carryingReward();

            addPercept(AG_NAME, ASSyntax.createLiteral("reward(" + reward + ")"));
            updatePercepts();

            try { Thread.sleep(80); } catch (Exception ignored) {}

            informAgsEnvironmentChanged();

        } catch (Exception e) {
            e.printStackTrace();
        }
        return true;
    }

    // ------------------ Percepts (BOTTOM-LEFT PDF COORDS) ------------------

    void updatePercepts() {
        clearPercepts();

        Location p = model.getAgPos(0);

        // pos(X,Y) in PDF coordinates
        addPercept(AG_NAME, ASSyntax.createLiteral(
                "pos(" + model.px(p.x) + "," + model.py(p.y) + ")"
        ));

        // at(Symbol,X,Y) in PDF coordinates (symbols like your beliefs.asl)
        addObjectPerceptIfPresent(BRUSH, "B");
        addObjectPerceptIfPresent(KEY,   "K");
        addObjectPerceptIfPresent(CODE,  "Cd");
        addObjectPerceptIfPresent(COLOR, "Cl");
        addObjectPerceptIfPresent(TABLE, "T");
        addObjectPerceptIfPresent(CHAIR, "Ch");
        addObjectPerceptIfPresent(DOOR,  "D");

        // inventory percepts using your symbols
        if (model.hasBrush) addPercept(AG_NAME, ASSyntax.createLiteral("has(B)"));
        if (model.hasKey)   addPercept(AG_NAME, ASSyntax.createLiteral("has(K)"));
        if (model.hasCode)  addPercept(AG_NAME, ASSyntax.createLiteral("has(Cd)"));
        if (model.hasColor) addPercept(AG_NAME, ASSyntax.createLiteral("has(Cl)"));

        // status (keep your names)
        addPercept(AG_NAME, ASSyntax.createLiteral(model.tableColored ? "colored(table)" : "not_colored(table)"));
        addPercept(AG_NAME, ASSyntax.createLiteral(model.chairColored ? "colored(chair)" : "not_colored(chair)"));
        addPercept(AG_NAME, ASSyntax.createLiteral(model.doorOpen ? "door(open)" : "door(closed)"));

        // walls (use wall/2 as in your beliefs.asl)
        for (Location l : model.getOccupiedLocationsWithMask(OBST)) {
            addPercept(AG_NAME, ASSyntax.createLiteral(
                    "wall(" + model.px(l.x) + "," + model.py(l.y) + ")"
            ));
        }
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

    // ------------------ Model ------------------

    class GridModel extends GridWorldModel {

        // inventory (PDF max_carry=3)
        static final int MAX_CARRY = 3;

        boolean hasBrush = false;
        boolean hasKey   = false;
        boolean hasCode  = false;
        boolean hasColor = false;

        boolean tableColored = false;
        boolean chairColored = false;
        boolean doorOpen     = false;

        GridModel() {
            super(WIDTH, HEIGHT, 1);
        }

        // PDF (1-based, bottom-left) → Jason (0-based, top-left)
        int ix(int X) { return X - 1; }
        int iy(int Y) { return HEIGHT - Y; }

        // Jason → PDF
        int px(int x) { return x + 1; }
        int py(int y) { return HEIGHT - y; }

        void resetToPdfLayout() {
            
                clearAllObjects();
                setAgPos(0, ix(1), iy(1)); // agent at PDF (1,1)
                
                // Walls at PDF coordinates (2,1), (2,2), (4,4), (4,5)
                add(OBST, ix(2), iy(1)); // (2,1)
                add(OBST, ix(2), iy(2)); // (2,2)
                add(OBST, ix(4), iy(4)); // (4,4)
                add(OBST, ix(4), iy(5)); // (4,5)
             
                // Objects at their PDF coordinates
                add(BRUSH, ix(1), iy(5));  // (1,5)
                add(KEY,   ix(1), iy(4));  // (1,4)
                add(CODE,  ix(3), iy(5));  // (3,5)
                add(COLOR, ix(5), iy(5));  // (5,5)
                add(CHAIR, ix(4), iy(2));  // (4,2)
                add(DOOR,  ix(3), iy(1));  // (3,1)
                add(TABLE, ix(5), iy(1));  // (5,1)
         // (5,1)
        }
         
        

        private void clearAllObjects() {
            // Remove all masks everywhere (GridWorldModel has no "clear everything", so do per cell)
            for (int x = 0; x < getWidth(); x++) {
                for (int y = 0; y < getHeight(); y++) {
                    Location l = new Location(x, y);
                    // remove everything we might have placed
                    remove(OBST, l);
                    remove(BRUSH, l);
                    remove(KEY, l);
                    remove(CODE, l);
                    remove(DOOR, l);
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
            Location l = new Location(x, y);
            return !hasObject(OBST, l);
        }

        private int carriedCount() {
            int c = 0;
            if (hasBrush) c++;
            if (hasKey)   c++;
            if (hasCode)  c++;
            if (hasColor) c++;
            return c;
        }

        // Accepts: B/K/Cd/Cl or brush/key/code/color
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

            // don’t drop on walls; also avoid stacking
            if (hasObject(OBST, a)) return false;
            if (hasAnyPickupObject(a)) return false;

            add(mask, a.x, a.y);
            setInventory(mask, false);
            return true;
        }

        private boolean hasAnyPickupObject(Location l) {
            return hasObject(BRUSH, l) || hasObject(KEY, l) || hasObject(CODE, l) || hasObject(COLOR, l);
        }

        private int tokenToMask(String tok) {
            // symbols
            if (tok.equalsIgnoreCase("B"))  return BRUSH;
            if (tok.equalsIgnoreCase("K"))  return KEY;
            if (tok.equalsIgnoreCase("Cd")) return CODE;
            if (tok.equalsIgnoreCase("Cl")) return COLOR;

            // full names
            if (tok.equalsIgnoreCase("brush")) return BRUSH;
            if (tok.equalsIgnoreCase("key"))   return KEY;
            if (tok.equalsIgnoreCase("code"))  return CODE;
            if (tok.equalsIgnoreCase("color")) return COLOR;

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

        // paintTarget accepts T/Ch or table/chair
        boolean paintTarget(String targetTok) {
            Location a = getAgPos(0);

            // PDF requirement: need brush + color in inventory
            if (!hasBrush || !hasColor) return false;

            if (targetTok.equalsIgnoreCase("T") || targetTok.equalsIgnoreCase("table")) {
                if (hasObject(TABLE, a)) {
                    tableColored = true;
                    return true;
                }
                return false;
            }

            if (targetTok.equalsIgnoreCase("Ch") || targetTok.equalsIgnoreCase("chair")) {
                if (hasObject(CHAIR, a)) {
                    chairColored = true;
                    return true;
                }
                return false;
            }

            return false;
        }

        boolean openDoor() {
            // PDF: need key + code
            if (!hasKey || !hasCode) return false;

            Location a = getAgPos(0);
            Location d = getDoorLocation();
            if (d == null) return false;

            int manhattan = Math.abs(a.x - d.x) + Math.abs(a.y - d.y);
            if (manhattan != 1) return false;

            doorOpen = true;
            return true;
        }

        private Location getDoorLocation() {
            List<Location> ds = getOccupiedLocationsWithMask(DOOR);
            return ds.isEmpty() ? null : ds.get(0);
        }

        // R(s): -0.01 if empty, else -0.02 per compatible carried, -0.03 per incompatible carried.
        // With your goal (paint + open), all four items are compatible.
        double carryingReward() {
            int carried = carriedCount();
            if (carried == 0) return -0.01;

            // all carried are compatible in this task
            return carried * (-0.02);
        }
    }

    // ------------------ View (with labels) ------------------

    class GridView extends GridWorldView {

        private final int cellSizeLocal;
        private final Font defaultFontLocal;

        public GridView(GridModel model) {
            super(model, "GridEnv (PDF fixed)", 500);

            int viewSize = 500;
            this.cellSizeLocal = Math.max(8, viewSize / Math.max(WIDTH, HEIGHT));
            this.defaultFontLocal = new Font("Arial", Font.BOLD, 14);

            setVisible(true);
        }

        private void label(Graphics g, int x, int y, String text) {
            g.setColor(Color.BLACK);
            drawString(g, x, y, defaultFontLocal, text);
        }

        @Override
        public void draw(Graphics g, int x, int y, int object) {
            switch (object) {

                case OBST:
                    // ONLY walls are colored
                    int s = this.cellSizeLocal;
                    g.setColor(Color.BLACK);
                    g.fillRect(x + 2, y + 2, cellSizeLocal - 2, cellSizeLocal - 2);
                    break;

                case BRUSH:
                    label(g, x, y, "B");
                    break;

                case KEY:
                    label(g, x, y, "K");
                    break;

                case CODE:
                    label(g, x, y, "Cd");
                    break;

                case COLOR:
                    label(g, x, y, "Cl");
                    break;

                case DOOR:
                    label(g, x, y, "D");
                    break;

                case CHAIR:
                    label(g, x, y, "Ch");
                    break;

                case TABLE:
                    label(g, x, y, "T");
                    break;

                default:
                    super.draw(g, x, y, object);
            }
        }


        @Override
        public void drawAgent(Graphics g, int x, int y, Color c, int id) {
            super.drawAgent(g, x, y, c, id);
            label(g, x, y, "A");
        }
    }
}

