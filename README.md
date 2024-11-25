# MarchMadnessBracketBuilder
This codebase builds an EV-maximizing March Madness bracket based on a scoring system and win probabilities. The code can accommodate several common scoring systems for March Madness bracket competitions. This work is based on the following [blog post](https://machineappreciation.wordpress.com/2022/03/18/march-madness-2022-mathematical-reflections/) of mine.

## How to use this code

This codebase has one main file, "BracketFunctions.R", containing a variety of functions. Most of these functions have been written such that they can be used for any symmetric tournament, but the wrapper function `MM_Bracket_Builder` is specific to six-round/64-team brackets, like NCAA March Madness. The wrapper function takes three inputs, `folder`, `filename`, and `scoring`. 

### Setup

Create a folder, with a file path `/.../folderName`. Inside your folder, place a CSV file, `fileName`, containing your table of probabilities. This same folder is where the output bracket will be written.

The `data.table` package must be installed and loaded.

### Running the code

To build the EV-optimal bracket relative to your data and scoring system, simply access the functions in BracketFunctions.R, and run `MM_Bracket_Builder(folder, filename, scoring)`, where:
+ `folder` is a string containing the path to your folder `/.../folderName `;
+ `filename` is the name of your CSV file;
+ `scoring` is a string designating one of four common scoring systems for bracket competitions.
More details on the CSV file and scoring system are given in the following sections.

### Data

The data must be given as a CSV file with the following columns: "r1", "r2", "r3", "r4", "r5", "r6", "team_name", "team_seed", and "team_num". Given a bracket, oriented in the standard way with sixteen-team left and right sub-brackets, each seeded downward by 1-16 two times, the team numbers are given by enumerating the left sub-bracket downward by 1-32, and the right sub-bracket downward by 33-64. 

The CSV file must have exactly 64 rows: one for each team. For team number i, The value given in each "rj" column is the probability that team i wins round j. Note that this is **not** the conditional probability that team i wins round j given it makes round j, but the raw probability. For example, the r6 value is the probability of winning the whole tournament. The Athletic currently provides this kind of data, or it can be backed into through Vegas Odds and some good old-fashioned elbow grease. 

A sample data file can be found at `SampleData.CSV`


### Scoring Systems

The code can currently accommodate four different scoring systems. Suppose you correctly guess that a team with seed s wins a game in round r. Then if the scoring system is:
+ "flat", you get 1 point. Each correct guess is worth exactly 1 point. The person with the most correct picks wins;
+ "seed", you get 1+s points. The seed value is added to the correct pick point;
+ "round", you get 2^(r-1) points. First-round games give 1 point, and each round gives twice as many points as the last;
+ "SR", you get 2^(r-1) + s points. This scoring system combines the "seed" and "round" scoring systems.



### Output

The code will write a new CSV file to your folder called "EV_bracket.csv", containing the EV-optimal bracket. The file simply gives the last round that each team wins. Consequently, it only gives data for 32 teams --- those that don't show up are exactly the teams picked to lose round 1. 

## Future work

The code works, but it's slow. On my laptop, the code takes approximately two hours to run. This is because the recursive computation as written requires re-computing the same brackets many times. A dynamic programming approach could speed this up greatly, but I haven't had the time to focus on this. I will probably get to it this March though! 

Second, outputting a picture of the bracket instead of the CSV file would be nice. 

Additionally, as discussed in my [blog post](https://machineappreciation.wordpress.com/2022/03/18/march-madness-2022-mathematical-reflections/), the bracket selection could likely be improved by moving beyond simple EV maximization. I have coded up some of these tools, but I have yet to test them. 


