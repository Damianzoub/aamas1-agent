package env;

import jason.environment.Environment;
import jason.asSyntax.*;

public class GridEnv extends Environment{
    @Override
    public void init(String[] args){
        super.init(args);
        System.out.println("Grid Environment initialized.");
        try{
            addPercept("main",ASSyntax.createLiteral("start(grid)"));
        }catch(Exception e){
            e.printStackTrace();
        }
    }

    @Override
    public boolean executeAction(String agName,Structure action){
        System.out.println("Agent " + agName + " executed action: " + action);
        return true;
    }
}
