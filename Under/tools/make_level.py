import random, sys  # random for the maze, sys for command line args
from collections import deque  # queue for breadth-first search

CW, CH = 24, 13  # maze size in cells (each cell becomes one open tile with walls between)
seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1337  # pass a number to get a different maze
rng = random.Random(seed)  # seeded random so the same seed gives the same maze
W, H = CW * 2 + 1, CH * 2 + 1  # size of the tile grid
g = [["#"] * W for _ in range(H)]  # start with all walls

# --- carve a perfect maze with an iterative depth-first search ---
stack = [(0, 0)]  # start at the top-left cell
seen = {(0, 0)}  # cells already carved
g[1][1] = "."  # open the first cell
while stack:  # keep going until every cell is visited
    cx, cy = stack[-1]  # look at the cell on top of the stack
    nbrs = [(cx + dx, cy + dy, dx, dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))  # four neighbours
            if 0 <= cx + dx < CW and 0 <= cy + dy < CH and (cx + dx, cy + dy) not in seen]  # that are unvisited
    if not nbrs:  # dead end
        stack.pop()  # backtrack
        continue  # try the previous cell
    nx, ny, dx, dy = rng.choice(nbrs)  # pick a random unvisited neighbour
    g[cy * 2 + 1 + dy][cx * 2 + 1 + dx] = "."  # knock out the wall between the two cells
    g[ny * 2 + 1][nx * 2 + 1] = "."  # open the new cell
    seen.add((nx, ny))  # mark it visited
    stack.append((nx, ny))  # continue from it


def open_nbrs(x, y):
    # list the open neighbour tiles of a tile
    return [(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if g[y + dy][x + dx] != "#"]


def bfs(start):
    # distance and parent of every open tile from a start tile
    dist, par = {start: 0}, {start: None}  # distance map and parent map
    q = deque([start])  # queue of tiles to expand
    while q:  # standard BFS
        t = q.popleft()  # next tile
        for n in open_nbrs(*t):  # each open neighbour
            if n not in dist:  # not seen yet
                dist[n] = dist[t] + 1  # one step further
                par[n] = t  # remember where we came from
                q.append(n)  # expand it later
    return dist, par


def path_to(par, t):
    # walk parents back to the start and return the path start -> t
    p = []  # collected tiles
    while t is not None:  # until we pass the start
        p.append(t)  # add this tile
        t = par[t]  # go to its parent
    return p[::-1]  # reverse so it starts at the start


start = (1, 1)  # player start tile
dist, par = bfs(start)  # distances from the start
cell_tiles = [(x, y) for y in range(1, H, 2) for x in range(1, W, 2)]  # tiles that are cell centres
leaves = [t for t in cell_tiles if len(open_nbrs(*t)) == 1 and t != start]  # dead ends

exit_t = max(leaves, key=lambda t: dist[t])  # exit goes in the farthest dead end
main_path = path_to(par, exit_t)  # the one and only route start -> exit

# door: a straight corridor tile about 60 percent along the route (so it is a chokepoint)
door_t = None  # chosen door tile
for i in range(int(len(main_path) * 0.6), len(main_path) - 3):  # search from 60 percent onwards
    x, y = main_path[i]  # candidate tile
    nb = open_nbrs(x, y)  # its open neighbours
    straight = len(nb) == 2 and (nb[0][0] == nb[1][0] or nb[0][1] == nb[1][1])  # exactly two, in a line
    if straight:  # good spot
        door_t = (x, y)  # take it
        break  # done
assert door_t, 'no door spot found'  # safety

# key: farthest dead end that is NOT behind the door
def behind_door(t):
    return door_t in path_to(par, t)  # true if the route to t passes the door

key_leaves = [t for t in leaves if not behind_door(t) and t != exit_t]  # reachable without the door
key_t = max(key_leaves, key=lambda t: dist[t])  # farthest of those

# watcher: a cell far from the start, not the key or exit
far = [t for t in cell_tiles if dist.get(t, 0) > max(dist.values()) * 0.55 and t not in (key_t, exit_t, door_t)]  # far cells
watcher_t = rng.choice(far)  # random far cell

g[start[1]][start[0]] = "P"  # player
g[exit_t[1]][exit_t[0]] = "E"  # exit
g[door_t[1]][door_t[0]] = "D"  # locked door
g[key_t[1]][key_t[0]] = "K"  # key
g[watcher_t[1]][watcher_t[0]] = "W"  # watcher spawn

out = "\n".join("".join(r) for r in g) + "\n"  # level as text
open(sys.argv[2] if len(sys.argv) > 2 else "levels/level1.txt", "w").write(out)  # save it
print("seed", seed, "size", W, "x", H, "route length", len(main_path), "door at", door_t, "key at", key_t)  # summary
