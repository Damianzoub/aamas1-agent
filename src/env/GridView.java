package env;

import java.awt.Color;
import java.awt.Font;
import java.awt.Graphics;
import java.awt.BorderLayout;
import java.awt.Panel;
import java.awt.Button;

import jason.environment.grid.GridWorldView;

public class GridView extends GridWorldView {

    private final int cellSizeLocal;
    private final Font defaultFontLocal;
    private Runnable onRunOneEpisode = null;
    private Runnable onStartExperiment = null;
    private Runnable onReset = null;

    public GridView(GridEnv.GridModel model) {
        super(model, "GridEnv (PDF fixed)", 500);

        int viewSize = 500;
        this.cellSizeLocal = Math.max(8, viewSize / Math.max(GridEnv.WIDTH, GridEnv.HEIGHT));
        this.defaultFontLocal = new Font("Arial", Font.BOLD, 14);

        // Simple control panel
        Panel p = new Panel();
        Button startExp = new Button("Start Experiment (100)");
        Button oneEp = new Button("Run 1 Episode");
        Button reset    = new Button("Reset");

        startExp.addActionListener(e -> { if (onStartExperiment != null) onStartExperiment.run(); });
        reset.addActionListener(e -> { if (onReset != null) onReset.run(); });
        oneEp.addActionListener(e->{if (onRunOneEpisode != null) onRunOneEpisode.run();});
        p.add(startExp);
        p.add(reset);
        p.add(oneEp);
        add(p, BorderLayout.SOUTH);

        setVisible(true);
    }

    public void setEnvHooks(Runnable startExperiment, Runnable reset,Runnable runOneEpisode) {
        this.onStartExperiment = startExperiment;
        this.onReset = reset;
        this.onRunOneEpisode = runOneEpisode;
    }

    public void updateFromModel(GridEnv.GridModel model) {
        repaint();
    }

    private void label(Graphics g, int x, int y, String text) {
        g.setColor(Color.BLACK);
        drawString(g, x, y, defaultFontLocal, text);
    }

    @Override
    public void draw(Graphics g, int x, int y, int object) {
        super.draw(g, x, y, object);

        if ((object & GridEnv.OBST) != 0) {
            g.setColor(Color.BLACK);
            g.fillRect(x + 2, y + 2, cellSizeLocal - 2, cellSizeLocal - 2);
            return;
        }

        if ((object & GridEnv.BRUSH) != 0) label(g, x, y, "B");
        if ((object & GridEnv.KEY)   != 0) label(g, x, y, "K");
        if ((object & GridEnv.CODE)  != 0) label(g, x, y, "Cd");
        if ((object & GridEnv.COLOR) != 0) label(g, x, y, "Cl");
        if ((object & GridEnv.DOOR)  != 0) label(g, x, y, "D");
        if ((object & GridEnv.CHAIR) != 0) label(g, x, y, "Ch");
        if ((object & GridEnv.TABLE) != 0) label(g, x, y, "T");
    }

    @Override
    public void drawAgent(Graphics g, int x, int y, Color c, int id) {
        super.drawAgent(g, x, y, c, id);
        label(g, x, y, "A");
    }
}
