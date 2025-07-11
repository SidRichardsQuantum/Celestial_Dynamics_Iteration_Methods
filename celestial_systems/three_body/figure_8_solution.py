import numpy as np
from scipy.optimize import minimize

def get_initial_conditions():
    G = 1
    m = 1
    T = 2 * np.pi
    N = 5000
    dt = T / N

    def shift(n, s): return (np.arange(n) + s) % n

    def action(X_flat):
        X = X_flat.reshape((N, 2))
        body1 = X
        body2 = X[shift(N, N//3)]
        body3 = X[shift(N, 2*N//3)]
        vel = (X[shift(N, -1)] - X[shift(N, 1)]) / (2 * dt)
        K = 0.5 * m * np.sum(vel**2, axis=1) * 3
        def dist(a, b): return np.sqrt(np.sum((a - b)**2, axis=1) + 1e-12)
        U = -abs(G) * m**2 * (1 / dist(body1, body2) + 1 / dist(body1, body3) + 1 / dist(body2, body3))
        return np.sum((K - U) * dt)

    a = 0.97000436
    b = 0.24308753
    theta = np.linspace(0, T, N, endpoint=False)
    X0 = np.column_stack([a * np.sin(theta), b * np.sin(2 * theta)])
    res = minimize(action, X0.ravel(), method='L-BFGS-B', options={'maxiter': 2000})
    X_opt = res.x.reshape((N, 2))
    shift_indices = [0, N//3, 2*N//3]
    positions = [X_opt[i] for i in shift_indices]
    vel = (X_opt[shift(N, -1)] - X_opt[shift(N, 1)]) / (2 * dt)
    velocities = [vel[i] for i in shift_indices]
    
    # Return 6 vectors: pos1, pos2, pos3, vel1, vel2, vel3
    return positions[0], positions[1], positions[2], velocities[0], velocities[1], velocities[2]
