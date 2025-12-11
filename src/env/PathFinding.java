import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Objects;

import org.jgrapht.Graph;
import org.jgrapht.GraphPath;
import org.jgrapht.alg.interfaces.AStarAdmissibleHeuristic;
import org.jgrapht.alg.shortestpath.AStarShortestPath;
import org.jgrapht.graph.DefaultWeightedEdge;
import org.jgrapht.graph.SimpleWeightedGraph;


//PathFinding utility class that uses A* algorithm to find shortest paths
//in a grid-based environment with blocked and walkable cells.
 
public class PathFinding {
    
    
    //Represents a single cell in the grid with x and y coordinates.
     
    public static class Cell {
        public final int x;
        public final int y;

        public Cell(int x, int y) {
            this.x = x;
            this.y = y;
        }

        
        //Two cells are equal if they have the same x and y coordinates.
         
        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Cell)) return false;
            Cell cell = (Cell) o;
            return x == cell.x && y == cell.y;
        }


        //Hash code based on x and y coordinates for use in hash-based collections.
         
        @Override
        public int hashCode() {
            return Objects.hash(x, y);
        }

        @Override
        public String toString() {
            return "Cell(" + x + "," + y + ")";
        }
    }

    /**
     * Finds the shortest path between two cells in a grid using the A* algorithm.
     * 
     * @param startX starting cell x coordinate
     * @param startY starting cell y coordinate
     * @param goalX target cell x coordinate
     * @param goalY target cell y coordinate
     * @param blocked 2D boolean array where blocked[y][x] = true means cell is blocked
     * @return List of Cell objects representing the path from start to goal (empty if no path exists)
     */
    
    public static List<Cell> findPath(
            int startX, int startY, int goalX, int goalY, boolean[][] blocked) {
        
        // Get grid dimensions
        int rows = blocked.length;
        if (rows == 0) return Collections.emptyList();
        int cols = blocked[0].length;

        // Create a weighted graph to represent the grid
        // Each cell is a vertex, and edges connect adjacent walkable cells
        Graph<Cell, DefaultWeightedEdge> graph = new SimpleWeightedGraph<>(DefaultWeightedEdge.class);

        // Create a 2D array of Cell objects for quick lookup
        Cell[][] cells = new Cell[rows][cols];
        
        // Add all walkable cells as vertices in the graph
        for (int y = 0; y < rows; y++) {
            for (int x = 0; x < cols; x++) {
                // Only add non-blocked cells to the graph
                if (!blocked[y][x]) {
                    Cell c = new Cell(x, y);
                    cells[y][x] = c;
                    graph.addVertex(c);
                }
            }
        }

        // Add edges between adjacent walkable cells (4-directional movement: right, down, left, up)
        for (int y = 0; y < rows; y++) {
            for (int x = 0; x < cols; x++) {
                if (!blocked[y][x]) {
                    Cell current = cells[y][x];
                    
                    // Define the four cardinal directions (right, down, left, up)
                    // Each direction is represented as [dx, dy]
                    int[][] directions = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}};
                    
                    for (int[] dir : directions) {
                        int nx = x + dir[0];  // new x coordinate
                        int ny = y + dir[1];  // new y coordinate
                        
                        // Check if neighbor is within bounds and not blocked
                        if (nx >= 0 && nx < cols && ny >= 0 && ny < rows && !blocked[ny][nx]) {
                            Cell neighbor = cells[ny][nx];
                            
                            // Add bidirectional edge between current cell and neighbor
                            graph.addEdge(current, neighbor);
                            
                            // Set edge weight to 1.0 (uniform cost for movement)
                            graph.setEdgeWeight(graph.getEdge(current, neighbor), 1.0);
                        }
                    }
                }
            }
        }

        // Get start and goal cells from the cells array
        Cell start = cells[startY][startX];
        Cell goal = cells[goalY][goalX];

        // Define the heuristic function for A* algorithm
        // Uses Manhattan distance: |x1 - x2| + |y1 - y2|
        // This estimates the remaining distance to the goal
        AStarAdmissibleHeuristic<Cell> heuristic = (cell, goalCell) -> 
            Math.abs(cell.x - goalCell.x) + Math.abs(cell.y - goalCell.y);
        
        // Create A* pathfinding algorithm instance with the graph and heuristic
        AStarShortestPath<Cell, DefaultWeightedEdge> aStar =
                new AStarShortestPath<>(graph, heuristic);

        // Find the shortest path from start to goal
        GraphPath<Cell, DefaultWeightedEdge> path = aStar.getPath(start, goal);

        // Return the list of cells in the path, or an empty list if no path exists
        return path != null ? new ArrayList<>(path.getVertexList()) : Collections.emptyList();
    }
}
