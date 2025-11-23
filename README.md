# Intelligent Agent Project — Jason (AAMAS 2025–2026)

This project implements a **BDI intelligent agent** using the **Jason agent-oriented programming language**, designed for the environment and scenario described in the assignment.  
The agent operates in a grid world, performs reasoning, selects goals, plans actions, interacts with objects, and aims to satisfy the final objective efficiently.

The environment and task description are based on the official exercise sheet.:contentReference[oaicite:1]{index=1}

---

# 📌 Table of Contents
1. [Overview](#overview)
2. [Environment Description](#environment-description)
3. [Final Goals & Constraints](#final-goals--constraints)
4. [Agent Architecture](#agent-architecture)
5. [Project Structure](#project-structure)
6. [How to Run](#how-to-run)
7. [Jason Syntax & Python Parallels](#jason-syntax--python-parallels)
8. [Algorithms Implemented](#algorithms-implemented)
9. [Experimental Evaluation](#experimental-evaluation)
10. [Future Extensions](#future-extensions)

---

# 🔍 Overview

This project implements a **practical reasoning agent** that must:

- Navigate through a grid with obstacles  
- Collect and manipulate objects  
- Choose the correct goals  
- Plan sequences of actions  
- Open a door, color two objects (Table & Chair), and complete all tasks

It uses the **Jason BDI model**, enabling the agent to choose goals, execute plans, communicate with the environment, and update its beliefs.

---

# 🌍 Environment Description

The environment is a 5×5 grid with:

- Obstacles  
- Objects: **Brush (B)**, **Key (K)**, **Color (Cl)**, **Code (Cd)**  
- Targets: **Table (T)**, **Chair (Ch)**, **Door (D)**  
- Agent initial position: **(1,1)**

**Symbols** (from assignment) :contentReference[oaicite:2]{index=2}:

| Symbol | Meaning |
|--------|---------|
| B | Brush |
| K | Key |
| Cl | Color |
| Cd | Code |
| T | Table |
| Ch | Chair |
| D | Door |
| Dark Cell | Obstacle |

---

# 🎯 Final Goals & Constraints

### **Final State Conditions**
The agent must achieve:

- `colored(T)`
- `colored(Ch)`
- `open(D)`

### **Action Constraints**
- To **paint** T or Ch → agent must carry: **Brush + Color**
- To **open** Door → agent must carry: **Key + Code**
- Agent capacity: **max 3 objects**

### **Rewards**  
- Small penalty per step  
- Higher penalty for carrying useless objects  
- Rewards for reaching final goals  

Based on assignment. :contentReference[oaicite:3]{index=3}

---

# 🧠 Agent Architecture

The agent follows the **BDI (Belief–Desire–Intention)** paradigm:

### **Beliefs**
- Agent location  
- Object locations  
- Inventory  
- Which objects are already colored  
- Whether the door is open  

### **Desires (Top-level goals)**
- Color the table  
- Color the chair  
- Open the door  
- Achieve final state  

### **Intentions (Plans chosen by agent)**
- Navigate  
- Pick objects  
- Drop objects  
- Paint objects  
- Open door  





