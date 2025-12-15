package env;

import jason.asSemantics.DefaultInternalAction;
import jason.asSemantics.TransitionSystem;
import jason.asSemantics.Unifier;
import jason.asSyntax.ListTerm;
import jason.asSyntax.ListTermImpl;
import jason.asSyntax.NumberTerm;
import jason.asSyntax.Term;
import jason.asSyntax.Atom;

import java.util.List;

public class plan_path extends DefaultInternalAction {

    @Override
    public Object execute(TransitionSystem ts, Unifier un, Term[] args) throws Exception {
        // .plan_path(CX,CY,GX,GY,Path)
        int CX = (int) ((NumberTerm) args[0]).solve();
        int CY = (int) ((NumberTerm) args[1]).solve();
        int GX = (int) ((NumberTerm) args[2]).solve();
        int GY = (int) ((NumberTerm) args[3]).solve();

        GridEnv.GridModel m = GridEnv.CURRENT_MODEL;
        if (m == null) return false;

        // PDF -> internal
        int sx = m.ix(CX), sy = m.iy(CY);
        int gx = m.ix(GX), gy = m.iy(GY);

        boolean[][] blocked = m.blockedGrid();

        List<PathFinding.Cell> cells = PathFinding.findPath(sx, sy, gx, gy, blocked);
        if (cells.isEmpty()) {
            return un.unifies(args[4], new ListTermImpl());
        }

        ListTerm pathDirs = new ListTermImpl();

        // Convert consecutive cells into directions
        for (int i = 1; i < cells.size(); i++) {
            PathFinding.Cell a = cells.get(i - 1);
            PathFinding.Cell b = cells.get(i);

            String dir;
            if (b.x == a.x + 1 && b.y == a.y) dir = "right";
            else if (b.x == a.x - 1 && b.y == a.y) dir = "left";
            else if (b.x == a.x && b.y == a.y + 1) dir = "down";
            else if (b.x == a.x && b.y == a.y - 1) dir = "up";
            else continue;

            pathDirs.add(new Atom(dir));
        }

        return un.unifies(args[4], pathDirs);
    }
}
