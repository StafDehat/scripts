import random

# n = nothing
# p = pit
# w = wumpus
# M = me
# t = treasure

# Print a board
def display(board):
  for row in board:
    print row

def sense(row,col):
  print row,col

# Place objects in random locations around the cave
def placeThing(numThing, board, thing):
  for x in xrange(numThing):
    randRow = random.randint(0,9)
    randCol = random.randint(0,9)
    board[randRow][randCol] = thing
def placePits(numPits, board):
  placeThing(numPits, board, 'p')
def placeWumpus(numWumpus, board):
  placeThing(numWumpus, board, 'w')

# Move the wumpus
def moveWumpus(board):
  print "You hear a shuffling noise"

# Create an empty cave
board = []
coords = [0,0]
for i in xrange(0,10):
  board.append(['n'] * 10)

# Fill the cave with interesting things
placePits(5,board)
placeWumpus(1,board)


# Give the Wumpus a chance to wander
if random.randint(0,5) == 0:
  moveWumpus(board)

coords[0] = random.randint(0,9)
coords[1] = random.randint(0,9)
board[coords[0]][coords[1]] = 'M'

display( board )

