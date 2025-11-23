import org.jgrapht.Graph;
import org.jgrapht.GraphPath;
import org.jgrapht.alg.shortestpath.AStarShortestPath;
import org.jgrapht.alg.shortestpath.AStarAdmissibleHeuristic;
import org.jgrapht.graph.DefaultWeightedEdge;
import org.jgrapht.graph.SimpleWeightedGraph;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Objects;

public class PathFinding {
    public static class Cell{
        public final int x;
        public final int y;

        public Cell(int x, int y){
            this.x = x;
            this.y = y;
        }
        @Override
        public boolean equals(Object o){
            if (this == o) return true;
            if (!(o instanceof Cell)) return false;
            Cell cell = (Cell) o;
            return x == cell.x && y == cell.y;
        }

        @Override
        public int hashCode(){
            return Objects.hash(x,y);
        }

        @Override
        public String toString(){
            return "Cell (" + x + "," + y + ")";
        }
    }   
}

public static List<Cell> findPath(
    int startX, int startY, int goalX, int goalY, boolean [][] blocked
){
    int rows = blocked.length;
    if (rows == 0) return Collections.emptyList();
    int cols = blocked[0].length;

    Graph<Cell, DefaultWeightedEdge> graph = new SimpleWeightedGraph<>(DefaultWeightedEdge.class);

    Cell[][] cells = new Cell[rows][cols];
    for (int y = 0; y <rows; y++){
        for (int x =0 ; x <cols; x++){
            if (!blocked[y][x]){
                Cell c = new Cell(x,y);
                cells[y][x]=c;
                graph.addVertex(c);
            }
        }
    }
    int[][] directions = {
        {0,1}, {1,0}, {0,-1}, {-1,0}
    };
    for (int y= 0; y<rows; y++){
        for (int x =0; x < cols; x++){
            Cell c = cells[y][x];
            if (c == null) continue;
            for (int[] dir : directions){
                int nx = x + dir[0];
                int ny = y + dir[1];
                if (nx >=0 && nx < cols && ny >=0 && ny < rows){
                    Cell neighbor = cells[ny][nx];
                    if (neighbor != null){
                        DefaultWeightedEdge edge = graph.addEdge(c, neighbor);
                        if (edge != null){
                            graph.setEdgeWeight(edge, 1.0);
                        }
                    }
                }
            }
        }
    }
    Cell start = new Cell(startX,startY);
    Cell goal = new Cell(goalX,goalY);
    if (!graph.containsVertex(start) || !graph.containsVertex(goal)){
        return Collections.emptyList();
    }

    AStarShortestPath<Cell,DefaultWeightedEdge> aStar = new AStarShortestPath<>(graph,heuristic);

    GraphPath<Cell,DefaultWeightedEdge> path = new aStar.getPath(start,goal);
    if (path == null){
        return Collections.emptyList();
    }
    return new ArrayList<>(path.getVertexList());
}
