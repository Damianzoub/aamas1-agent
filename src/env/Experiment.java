import java.util.Random;

import jade.core.Agent;
import jade.core.AgentState;

public class Experiment{
    private static final int NUM_EPISODES =100;
    private static final int MAX_STEPS =100;

    public static void main(String[] args) {
        double totalReward =0.0;
        Random rng = new Random();
    }

    private static double runSingleEpisode(GridEnv env, AgentState agent, Random rng){
        double episodeReward =0.0;
        for (int step=1; step<= MAX_STEPS; step++){

        }
        return episodeReward;
    }
}