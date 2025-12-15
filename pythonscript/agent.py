from pathfinding.core.grid import Grid
from pathfinding.finder.a_star import AStarFinder

GRID_SIZE = 5

def env_to_lib(pos):
    """(1..5, bottom-left) -> (0..4, top-left)"""
    x, y = pos
    return (x - 1, GRID_SIZE - y)

def lib_to_env(pos):
    """(0..4, top-left) -> (1..5, bottom-left)"""
    lx, ly = pos
    return (lx + 1, GRID_SIZE - ly)

def build_matrix(obstacles):
    """
    pathfinding matrix: 1 = walkable, 0 = blocked
    obstacles are in env coords (1..5, bottom-left)
    """
    matrix = [[1 for _ in range(GRID_SIZE)] for _ in range(GRID_SIZE)]
    for (x, y) in obstacles:
        lx, ly = env_to_lib((x, y))
        matrix[ly][lx] = 0
    return matrix

class Agent:
    def __init__(self, env):
        self.env = env

    def choose_target(self):
        """
        Returns the next target CELL (x,y) in env coords (1..5, bottom-left).
        Assumes env.positions contains positions for: B, Cl, K, Cd, T, Ch, D.
        """

        # --- 1) Painting stage: ensure both T and Ch are colored ---
        if (not self.env.colored.get("T", False)) or (not self.env.colored.get("Ch", False)):

            # Need tools first
            if "B" not in self.env.carrying:
                return self.env.positions["B"]
            if "Cl" not in self.env.carrying:
                return self.env.positions["Cl"]

            # Have tools -> go paint whichever is not colored yet
            if not self.env.colored.get("T", False):
                return self.env.positions["T"]
            else:
                return self.env.positions["Ch"]

        # --- 2) Door stage: ensure door is open ---
        if not getattr(self.env, "door_open", False):

            if "K" not in self.env.carrying:
                return self.env.positions["K"]
            if "Cd" not in self.env.carrying:
                return self.env.positions["Cd"]

            return self.env.positions["D"]

        # If everything achieved, target current position (no-op)
        return self.env.agent_pos

    def astar_path_moves(self, start_env, goal_env):
        matrix = build_matrix(self.env.obstacles)
        grid = Grid(matrix=matrix)

        sx, sy = env_to_lib(start_env)
        gx, gy = env_to_lib(goal_env)

        start = grid.node(sx, sy)
        goal  = grid.node(gx, gy)

        finder = AStarFinder()
        path, _ = finder.find_path(start, goal, grid)

        # path is list of (x,y) in lib coords. Convert to env and then to moves.
        if not path or len(path) == 1:
            return []

        env_path = [lib_to_env((x, y)) for (x, y) in path]

        moves = []
        for (x1, y1), (x2, y2) in zip(env_path, env_path[1:]):
            moves.append((x2 - x1, y2 - y1))  # (dx,dy) in env coords
        return moves

    def step(self):
        # 1) Choose target (same logic you already have)
        target = self.choose_target()  # keep your existing goal-selection logic here

        # 2) If we are already on the target cell -> INTERACT (don’t plan/move)
        if self.env.agent_pos == target:
            self.env.pickup()
            self.env.paint()
            self.env.open_door()
            self.env.reward()
            return

        # 3) Otherwise move 1 step along A* path
        moves = self.astar_path_moves(self.env.agent_pos, target)
        if moves:
            dx, dy = moves[0]
            self.env.move(dx, dy)

        # 4) After moving, also try to interact (this is important!)
        self.env.pickup()
        self.env.paint()
        self.env.open_door()

        # 5) Apply step reward
        self.env.reward()
