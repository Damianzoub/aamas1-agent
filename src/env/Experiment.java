package env;
import java.util.Random;
import jason.environment.grid.Location;
public class Experiment{
    private static final int NUM_EPISODES =100;
    private static final int MAX_STEPS =100; // still thinking about this to not have an infinity loop if agent stupid
    private static final Random rng = new Random();
    public static void main(String[] args) {
        double totalReward =0.0;
        
        for (int ep=1; ep<=NUM_EPISODES; ep++){
            GridEnv env = new GridEnv();
            GridEnv.GridModel model = env.new GridModel();

            model.resetToPdfLayout();
            double episodeReturn = runSingleEpisode(model);
            System.out.println("Episode "+ep+ " return = " +episodeReturn);
            totalReward += episodeReturn;
        }
        double averageReturn = totalReward/NUM_EPISODES;
        System.out.println("Average utility over "+ NUM_EPISODES+ "episodes = "+averageReturn);

    }

    private static double runSingleEpisode(GridEnv.GridModel model){
        double episodeReturn =0.0;
        for (int step=1; ; step++){
            if (model.doorOpen && model.chairColored && model.tableColored){
                episodeReturn +=1.0;
                episodeReturn +=1.0;
                episodeReturn +=0.8;
                break;
            }
            Location a = model.getAgPos(0); //if it returns the positon of agent
            int choice = rng.nextInt(4);
            double reward = 0.0;

            switch (choice){
                case 0:{
                    int[][] dirs = {{1,0},{-1,0},{0,1},{0,-1}};
                    int[] d = dirs[rng.nextInt(dirs.length)];
                    int nx = a.x +d[0];
                    int ny = a.y+d[1];
                    
                    if (model.canMoveAgentTo(nx, ny)){
                        try {
                            model.setAgPos(0, nx, ny);
                        } catch (Exception e) {
                            e.printStackTrace();
                        }
                        reward = -0.02;
                    }else{
                        reward = -0.03;
                    }
                    break;
                }
                // pick (brush/key/code)
                case 1:{
                    String[] objs = {"brush","key","code"};
                    String obj = objs[rng.nextInt(objs.length)];
                    boolean ok = model.pickAtAgent(obj);
                    reward = ok ? -0.02 : -0.03;
                    break;
                }
                // paint(table/chair)
                case 2:{
                    String[] targets = {"table","chair"};
                    String t = targets[rng.nextInt(targets.length)];
                    boolean ok = model.paintTarget(t);
                    if (ok){
                        reward=1.0;
                    }else{
                        reward=-0.03;
                    }
                    break;
                }
                //open door
                case 3:{
                    boolean ok = model.openDoor();
                    reward = ok ? 0.8 : -0.03;
                    break;
                }
            }
            episodeReturn += reward;
            double carryingReward = model.carryingReward();
            episodeReturn+=carryingReward;
        }
        return episodeReturn;
    }
}

// maybe we should also put penalties for keeping  incompaitble objects 
