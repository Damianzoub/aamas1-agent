# run_experiments.py
from environment import Environment
from agent import Agent

STEP_LIMIT = 500

def episode_return(env: Environment) -> float:
    """Add terminal rewards exactly like the PDF."""
    u = env.total_reward
    u += 1.0 if env.colored.get("T", False) else 0.0
    u += 1.0 if env.colored.get("Ch", False) else 0.0
    u += 0.8 if getattr(env, "door_open", False) else 0.0
    return u

def run_one_episode(seed=None, verbose=True):
    env = Environment(seed=seed) if "seed" in Environment.__init__.__code__.co_varnames else Environment()
    env.reset()

    agent = Agent(env)

    steps = 0
    while not env.is_goal() and steps < STEP_LIMIT:
        agent.step()
        steps += 1

    U = episode_return(env)
    success = env.is_goal()

    if verbose:
        print("=== One Episode ===")
        print(f"Steps: {steps}")
        print(f"Goal reached: {success}")
        print(f"Total utility: {U:.4f}")

    return U, success


def run_experiment(n_episodes=100, seed=None):
    utilities = []
    success_count = 0

    for ep in range(n_episodes):
        ep_seed = None if seed is None else seed + ep
        U, success = run_one_episode(seed=ep_seed, verbose=False)

        utilities.append(U)
        if success:
            success_count += 1

    avgU = sum(utilities) / n_episodes
    success_rate = success_count / n_episodes

    print(f"=== Experiment ({n_episodes} episodes) ===")
    print(f"Average utility: {avgU:.4f}")
    print(f"Min utility: {min(utilities):.4f}")
    print(f"Max utility: {max(utilities):.4f}")
    print(f"Goals reached: {success_count}/{n_episodes}")
    print(f"Success rate: {success_rate:.2%}")

    return utilities, success_rate


if __name__ == "__main__":
    run_one_episode(seed=42, verbose=True)
    run_experiment(n_episodes=100, seed=42)
