#!/usr/bin/env python3

import random

# 100 guy names in alphabetical order
guyNames = ['Aaron', 'Adam', 'Adrian', 'Aiden', 'Alexander', 'Andrew', 'Angel', 'Anthony', 'Asher', 'Austin', 'Axel', 'Benjamin', 'Brooks', 'Caleb', 'Cameron', 'Carson', 'Carter', 'Charles', 'Christian', 'Christopher', 'Colton', 'Connor', 'Cooper', 'Daniel', 'David', 'Dominic', 'Dylan', 'Easton', 'Eli', 'Elias', 'Elijah', 'Ethan', 'Everett', 'Ezekiel', 'Ezra', 'Gabriel', 'Grayson', 'Greyson', 'Henry', 'Hudson', 'Hunter', 'Ian', 'Isaac', 'Isaiah', 'Jace', 'Jack', 'Jackson', 'Jacob', 'James', 'Jameson', 'Jaxon', 'Jaxson', 'Jayden', 'Jeremiah', 'John', 'Jonathan', 'Jordan', 'Jose', 'Joseph', 'Joshua', 'Josiah', 'Julian', 'Kai', 'Kayden', 'Landon', 'Leo', 'Leonardo', 'Levi', 'Liam', 'Lincoln', 'Logan', 'Luca', 'Lucas', 'Luke', 'Mason', 'Mateo', 'Matthew', 'Maverick', 'Michael', 'Miles', 'Nathan', 'Nicholas', 'Noah', 'Nolan', 'Oliver', 'Owen', 'Parker', 'Robert', 'Roman', 'Ryan', 'Samuel', 'Santiago', 'Sebastian', 'Silas', 'Theodore', 'Thomas', 'Wesley', 'William', 'Wyatt', 'Xavier']

# 100 gal names in alphabetical order
galNames = ['Aaliyah', 'Abigail', 'Addison', 'Adeline', 'Alice', 'Allison', 'Amelia', 'Anna', 'Aria', 'Ariana', 'Aubrey', 'Audrey', 'Aurora', 'Autumn', 'Ava', 'Avery', 'Bella', 'Brielle', 'Brooklyn', 'Camila', 'Caroline', 'Charlotte', 'Chloe', 'Claire', 'Cora', 'Delilah', 'Eleanor', 'Elena', 'Eliana', 'Elizabeth', 'Ella', 'Ellie', 'Emery', 'Emilia', 'Emily', 'Emma', 'Eva', 'Evelyn', 'Everleigh', 'Everly', 'Gabriella', 'Genesis', 'Gianna', 'Grace', 'Hailey', 'Hannah', 'Harper', 'Hazel', 'Isabella', 'Isla', 'Ivy', 'Jade', 'Josephine', 'Kennedy', 'Kinsley', 'Layla', 'Leah', 'Leilani', 'Lillian', 'Lily', 'Lucy', 'Luna', 'Lydia', 'Madeline', 'Madelyn', 'Madison', 'Maya', 'Mia', 'Mila', 'Naomi', 'Natalia', 'Natalie', 'Nevaeh', 'Nora', 'Nova', 'Olivia', 'Paisley', 'Penelope', 'Peyton', 'Piper', 'Quinn', 'Riley', 'Ruby', 'Sadie', 'Samantha', 'Sarah', 'Savannah', 'Scarlett', 'Serenity', 'Skylar', 'Sofia', 'Sophia', 'Sophie', 'Stella', 'Valentina', 'Victoria', 'Violet', 'Willow', 'Zoe', 'Zoey']

# Default values
matches = 10
episodes = 10

def setRules():
  global matches
  global episodes

  # Prompt for # matches
  try:
    matches = int(input("How many matches this season? (2-100, Default:10) "))
  except ValueError:
    print("Invalid entry - using 10 instead")
    matches = 10
  #end try

  # Prompt for # episodes
  global episodes
  try:
    episodes = int(input("How many episodes this season? (Default:10) "))
  except ValueError:
    print("Invalid entry - using 10 instead")
    episodes = 10
  #end try

  print()
  print("%d episodes, to match %d dudes with %d chicks" % (episodes, matches, matches))
  print("Every contestant stands to win $1,000,000.")
  print("That drops by $250,000 every time they get a blackout, though.")
#end setRules()

# Allow difficulty customization
setRules()

# Pick [fe]male names
random.shuffle(guyNames)
random.shuffle(galNames)
guys = guyNames[0:matches]
gals = galNames[0:matches]
guys.sort()
gals.sort()

# Play match-maker
# Index = guy, value = gal
solution = []
for x in range(0,matches):
  solution.append(x)
random.shuffle(solution)

# Print a list, and number it for easy selections
def roster(lst):
  for x in range(0,len(lst)):
    print("".join(str(x).rjust(3)), lst[x])
  #end for
#end roster()

# Print the solutions
def spoilers():
  print("Solution:")
  for x in range(0,len(guys)):
    print("".join(guys[x].ljust(15)), "".join(gals[solution[x]]).rjust(15))
  #end for
#end spoilers()

def gossip():
  fights = [
    "%s punched %s in the face.",
    "%s hid %s's journals, and refuses to admit it.",
    "%s expresses a distate for %s's jealous behaviour.",
    "%s has second-thoughts, when %s starts talking about marriage.",
    "%s said a bunch of horrible shit, and made %s cry.",
    "%s is pissed, because %s didn't pick them for their date.",
    "%s gets passive-aggressive with %s for talking to the other cast members.",
    "%s & %s won a private date, but it didn't go well.",
    "%s & %s argue in the kitchen.",
    "%s offends %s by inviting them to Pound Town.",
    "%s tried to convert %s to their religion.  Anger ensued.",
    "%s's obsession with %s's player ways threatens the house's ability to continue.",
    "%s starts to question their relationship with %s.",
    "%s accuses %s of being abusive.  The house agrees."
  ]
  bonds = [
    "%s is preparing a romantic surprise for %s.",
    "The cast plays Spin-the-Bottle.  %s & %s connect after a kiss.",
    "%s & %s were in the boom boom room last night.",
    "%s declares love for %s, whether it's a match or not.",
    "%s & %s were in the boom boom room last night.",
    "%s snuck into %s's bedroom around 2am.",
    "At dinner, %s was getting into %s's pants under the table.",
    "%s and %s bond while cooking a meal for everyone.",
    "%s talks %s into going to Pound Town.",
    "%s was in the hottub with %s, but their swimsuits were still upstairs.",
    "%s is sick for a couple days.  %s misses them and is feeling lonely.",
    "%s and %s discover they went to the same high school.",
    "%s helps %s to overcome a fear of water.  They have an enjoyable ocean date.",
    "%s opens up to %s about being a transmasculine non-binary person.  They have sex."
  ]
  dumbSingles = [ 
    "%s has tazed one of their exes",
    "%s is notorious for hooking up with people's siblings.",
    "%s doesn't believe in God, but does believe in ghosts and spirits.",
    "%s has a restraining order because they were stalking their ex.",
    "I heard %s has peed on someone in the shower before.",
    "%s threw a wristwatch through a window.",
    "%s got really drunk, then ugly-cried and yelled at everyone.",
    "%s takes a drunk dip in the ocean, and everyone yells for him to come back.",
    "%s said something about itching, and a brownish discharge.",
    "%s has a meltdown.",
    "%s claims they could gaurantee the win, if everyone would just vote as they're told.",
    "%s is more interested in sex than finding their perfect match."
]
  dumbDoubles = [ ]

  oddsHelp = 50
  oddsHarm = 50
  oddsDumb = 20
  outOf = oddsHelp + oddsHarm + oddsDumb

  print("Perhaps unsurprisingly, drama is occurring.")
  # Print 1-3 gossips
  for x in range(0,random.randrange(1,3,1)):
    # Pick a type of gossip - Help/Hurt/Dumb
    rand = random.randrange(0,outOf,1)
    if rand < oddsHelp:
      guy = random.randrange(0,matches,1)
      gal = solution[guy]
      herrings = gals.copy()
      del herrings[gal]
      herring = random.randrange(0,matches-1,1)
      herring = gals.index(herrings[herring])
      if random.random() < 0.5:
        # A bond between matches
        print(bonds[random.randrange(0,len(bonds),1)] % (guys[guy],gals[gal]))
      else:
        # A fight with a non-match
        print(fights[random.randrange(0,len(fights),1)] % (guys[guy],gals[herring]))
      #end if
    elif rand < oddsHelp+oddsHarm:
      # Harmful gossip
      guy = random.randrange(0,matches,1)
      gal = solution[guy]
      herrings = gals.copy()
      del herrings[gal]
      herring = random.randrange(0,matches-1,1)
      herring = gals.index(herrings[herring])
      if random.random() < 0.5:
        # A bond with the wrong person
        print(bonds[random.randrange(0,len(bonds),1)] % (guys[guy],gals[herring]))
      else:
        # A fight between matches
        print(fights[random.randrange(0,len(fights),1)] % (guys[guy],gals[gal]))
      #end if
    else:
      # Pick either a single person, or 2 people from the same pool
      rando = random.randrange(0,matches,1)
      if random.random() < 0.5:
        rando = guys[rando]
      else:
        rando = gals[rando]
      #end if
      print(dumbSingles[random.randrange(0,len(dumbSingles),1)] % rando)
    #end if
  #end for
#end gossip()

def truthBooth():
  global matches

  # Pick 1 guy & 1 gal.  Match?  Y/N
  print("Which guy is going into the Truth Booth?")
  guyPick = getPerson(guys)
  print("Which gal is a perfect match with %s?" % guys[guyPick])
  galPick = getPerson(gals)

  print("%s and %s stand in the Truth Booth, excited and anxious." % (guys[guyPick],gals[galPick]))
  print("<<< Commercial break >>>")
  wait()

  if solution[guyPick] != galPick:
    print("No Match")
    return
  #end if

  # If perfect match, remove guy & gal from lists & decrement 'matches'
  print("It's a match!")
  print("%s and %s will now retire to the Honeymoon Suite." % (guys[guyPick], gals[galPick]))
  print("There are now 2 fewer contestants on the show.")
  wait()
  del guys[guyPick]
  del gals[galPick]
  matches -= 1
  print("Remaining contestants:")
  print("The guys:")
  roster(guys)
  print("The gals:")
  roster(gals)
#end truthBooth()

def getPerson(lst):
  while True:
    print("Available choices:")
    roster(lst)
    try:
      choice = input("Pick someone [0-%d]: " % (len(lst)-1))
      pid = int(choice)
    except ValueError:
      try:
        pid = lst.index(choice)
      except ValueError:
        print("That... wasn't a choice.  Try again.")
        continue
      #end try
    # end try
    if pid < 0 or pid >= len(lst):
      print("Try again, and this time keep it between 0 and %d" % (len(lst)-1))
      continue
    #end if
    break
  #end while
  return pid
#end getGuy()

def beamTime():
  global matches

  print()
  print("Time to lock in those matches!")
  print()

  guysLeft = guys.copy()
  galsLeft = gals.copy()
  guess = {}

  for x in range(0,matches-1):
    print("Which guy will approach the podium?")
    choice = getPerson(guysLeft)
    name = guysLeft[choice]
    del guysLeft[choice]
    guyPick = guys.index(name)
    print()

    print("Which gal will stand with %s?" % guys[guyPick])
    choice = getPerson(galsLeft)
    name = galsLeft[choice]
    del galsLeft[choice]
    galPick = gals.index(name)
    print()

    print("%s and %s place their hands on the podium, locking in their choice." % (guys[guyPick], gals[galPick]))
    guess[guyPick] = galPick
    wait()
  #end for

  guyPick = guys.index(guysLeft[0])
  galPick = gals.index(galsLeft[0])
  print("That leaves only %s and %s - they lock in their choice." % (guys[guyPick], gals[galPick]))
  print("The tension is palpable.")
  guess[guyPick] = galPick
  wait()

  beams = 0
  for x in range(0,matches):
    if guess[x] == solution[x]:
      beams += 1
    #end if
  #end for
  if beams == 0:
    print("All lights remain dark.  It's a blackout.")
    blackout()
  elif beams == 1:
    print("1 beam of light shines into the night.")
  elif beams >= matches-1:
    print("%d beams of light shine into eternity." % matches)
    win()
  else:
    print("%d beams of light shine into the night sky." % beams)
  #end if
  wait()
#end beamTime()

def blackout():
  global jackpot
  jackpot = jackpot - 250
  if jackpot <= 0:
    fail()
  print("The jackpot has decreased by $250,000.")
  print("The max winnings are now $%d,000." % jackpot)
#end blackout()

def fail():
  print("Everyone returns home, penniless and alone.")
  print("True love is a myth.")
  exit(1)
#end fail()

def win():
  print("Everyone wins $%d,000" % jackpot)
  print("Plus, we look forward to a 'Where are they now?' episode in 1 year.")
  exit(0)
#end win()

def wait():
  input("Press enter to continue...")
  print()
#end wait()

wait()

spoilers()
wait()

jackpot = 1000
for episode in range(0,episodes):
  print("Episode %d" % (episode+1))

  print("%d lonely guys are searching for love:" % matches)
  roster(guys)
  print("%d lonely gals hope they find it:" % matches)
  roster(gals)
  wait()

  gossip()
  wait()

  truthBooth()
  wait()

  gossip()
  wait()

  beamTime()
#end for

print("This season is over.  Enjoy your lonely lives, losers.")
fail()

