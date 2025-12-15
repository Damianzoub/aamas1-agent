import random
from collections import deque

GRID_SIZE = 5
MAX_CARRY = 3

OBJECTS = ["B", "Cl", "K", "Cd", "T", "Ch", "D"]

OBSTACLES = {(1,2),(2,2), (4,4),(4,5)}  # fixed dark cells (example)

class Environment:
    def __init__(self):
        self.reset()

    def reset(self):
        self.agent_pos = (1, 1)
        self.carrying = []
        self.colored = {"T": False, "Ch": False}
        self.door_open = False
        self.obstacles = {(1,2),(2,2), (4,4),(4,5)}  # fixed dark cells
        free_cells = [
            (x, y)
            for x in range(1, 6)
            for y in range(1, 6)
            if (x, y) not in OBSTACLES and (x, y) != (1, 1)
        ]

        random.shuffle(free_cells)

        self.positions = {
            "B": free_cells.pop(),
            "Cl": free_cells.pop(),
            "K": free_cells.pop(),
            "Cd": free_cells.pop(),
            "T": free_cells.pop(),
            "Ch": free_cells.pop(),
            "D": free_cells.pop(),
        }

        self.total_reward = 0.0

    def move(self, dx, dy):
        nx = self.agent_pos[0] + dx
        ny = self.agent_pos[1] + dy
        if 1 <= nx <= 5 and 1 <= ny <= 5 and (nx, ny) not in OBSTACLES:
            self.agent_pos = (nx, ny)

    def pickup(self):
        for obj, pos in self.positions.items():
            if pos == self.agent_pos and obj not in ["T", "Ch", "D"]:
                if len(self.carrying) < MAX_CARRY:
                    self.carrying.append(obj)
                    self.positions[obj] = None

    def paint(self):
        for target in ["T", "Ch"]:
            if self.positions[target] == self.agent_pos:
                if "B" in self.carrying and "Cl" in self.carrying:
                    self.colored[target] = True

    def open_door(self):
        if self.positions["D"] == self.agent_pos:
            if "K" in self.carrying and "Cd" in self.carrying:
                self.door_open = True

    def reward(self):
        incompatible = 0
        needed = set()

        if not self.colored["T"] or not self.colored["Ch"]:
            needed |= {"B", "Cl"}
        if not self.door_open:
            needed |= {"K", "Cd"}

        for item in self.carrying:
            if item not in needed:
                incompatible += 1

        if len(self.carrying) == 0:
            step_penalty = -0.01
        else:
            step_penalty = -0.02 * len(self.carrying)

        step_penalty += -0.03 * incompatible
        self.total_reward += step_penalty
        return step_penalty

    def is_goal(self):
        return self.colored["T"] and self.colored["Ch"] and self.door_open
