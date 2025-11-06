#Packages
import numpy as np
import pandas as pd
import os
from functools import cache


####Format data####
def format_data(data, scoring = "flat"):
    #scoring should be input as one of the following strings:
        # "flat" if each correct guess is worth 1 point 
        # "seed" if each correct guess is worth 1 + seed points
        # "round" if each correct guess is worth 2^(r-1) points
        #       where r is the round number.
        # "SR" if each correct guess is worth 2^(r-1) + seed points
        #       where r is the round number. That is, picking a 14 seed
        #       to win in round 2 is worth 2^(2-1) + 14 = 16 points.
        # if no string is specified, code defaults to "flat"
        

    #Get data long
    dataLong = pd.melt(data, id_vars = ['team_name', 'team_seed', 'team_num'],
                         var_name = 'round',
                         value_name = 'prob')


    #rename round numbers
    dataLong["round_num"] = dataLong.apply(lambda x : int(x["round"][-1]) , axis = 1)

    #remove round field.
    dataLong.drop("round", axis = 1, inplace = True)


    #Get Points value for winning each round
    count_seed = 0
    count_round = 0

    if scoring == "SR" or scoring == "seed":
        count_seed = 1

    if scoring == "SR" or scoring == "round":
        count_round = 1

    dataLong["points"] = dataLong.apply( lambda x : (count_seed * x["team_seed"]) +  (2 ** (count_round * (x["round_num"] - 1))),
                                             axis = 1)
    
    return dataLong
  

####Depth First Search for bracket search####
def make_DFS(data):
    @cache
    def DFS( r : int, g : int, k : int, i : int):
        #This function computes the best choice of bracket for the subtournament 
        #   of a k round tournament crowned by game (r,g), 
        #   assuming we take team i all the way through to
        #   being the champion of the sub-tournament, via depth-first-search.
        #   Data must have been formatted via format_data
        #   before running.

        #check if r is a valid round
        if r < 0 or r > k:
            raise Exception("invalid round number")

        #check if g is a valid game in round r
        if g < 1 or g > 2**(k - r):
            raise Exception("invalid game number")

        #check if i is a valid team
        if ((i > ((2**r)*g)) or (i < ((2**r) * (g-1) + 1))):
            raise Exception("invalid team number")

        #base case:
        if r == 1:
            bracket = pd.DataFrame({"round_num" : [1], "game" : [g], "choice" : [i]})
            mask = (data["team_num"] == i) & (data["round_num"] == 1)
            idx = mask.idxmax()
            exp_tot_pts = data.at[idx,"prob"] * data.at[idx,"points"]
            res = [bracket, exp_tot_pts]
        
            return res
        
        #recursive case:
        #find half of bracket containing team i
        if((((2**r)*(g-1)+1) <= i) & (i <= ((2**(r-1))*((2*g)-1)))):
            parity = "L"
        else:
            parity = "R"

        
        #compute optimal half bracket that sends team i to the finals
        if parity == "L":
            game_num = (2*g) - 1
        elif parity == "R":
            game_num = 2*g

        half_with_i = DFS(r-1, game_num, k, i) 

        #compute optimal half bracket that sends team i's championship competator to the finals:
        if parity == "L":
            game_num = 2*g
            j_range = range((2**(r-1))*(2*g-1)+1,(2**r)*g + 1) #indices of teams that i could meet in final
        elif parity == "R":
            game_num = (2*g) - 1
            j_range = range(((2**r)*(g-1)+1) , ((2**(r-1))*((2*g)-1))) #indices of teams that i could meet in final

        half_without_i = [None,0]
        for j in j_range:
            candidate_j = DFS(r-1, game_num, k, j)
            if candidate_j[1] > half_without_i[1]:
                half_without_i = candidate_j
        
        #final game: use probabilties and points from data
        mask = (data["round_num"] == r) & (data["team_num"] == i)
        idx = mask.idxmax()
        final_game = data.at[idx, "points"] * data.at[idx, "prob"]

        #assemble output
        expected_points = final_game + half_with_i[1] + half_without_i[1]
        final_row = pd.DataFrame({"round_num" : [r], "game" : [g], "choice" : [i]})
        bracket = pd.concat([half_with_i[0], half_without_i[0], final_row],axis=0)
        return [bracket, expected_points]
            
    return DFS


####Find EV best bracket####
def make_EV_best_bracket(k, data):
    #Takes in the number of rounds (k) and tournament probability data.
    #  data must have been formatted via format_data

    DFS = make_DFS(data)
    best_bracket = [None,0]

    for j in range(1, 2**k + 1):
        candidate_bracket = DFS(k,1,k,j)
        
        if candidate_bracket[1] > best_bracket[1]:
            best_bracket = candidate_bracket
    
    return best_bracket[0]


####make bracket legible####
def make_legible(bracket, data):
    #this funciton takes the unreadable bracket and returns a readable version with team names and round win indformation
    #use the wide data, not the long data

    #build map of team_numbers to team_names:
    name_map = {}
    for idx in data.index:
        name_map[data.at[idx,"team_num"]] = data.at[idx, "team_name"]


    legible_bracket = bracket.groupby("choice")["round_num"].max().reset_index()
    legible_bracket.sort_values(by = ["choice"], inplace = True)
    legible_bracket["team"] = legible_bracket.choice.map(name_map)
    legible_bracket = legible_bracket.drop("choice", axis = 1)[["team", "round_num"]]
    legible_bracket.rename(columns = {"round_num" : "Last Round Won"}, inplace = True)

    return(legible_bracket)


#### Wrapper ####
def MM_Bracket_Builder(folder : str, filename : str, scoring : str):
    #wrapper function that runs all previous functions in the correct order.
    #    in particular, running MM_bracket_builder will take in a folder where
    #    the raw data is contained, and writes a csv file (EV_bracket.csv) to
    #    the same folder. This csv file contains a table of team names and the last round
    #    of the tournament they win. Only teams that win at least one round are reported.
    #scoring should be input as one of the following strings:
        # "flat" if each correct guess is worth 1 point 
        # "seed" if each correct guess is worth 1 + seed points
        # "round" if each correct guess is worth 2^(r-1) points
        #       where r is the round number.
        # "SR" if each correct guess is worth 2^(r-1) + seed points
        #       where r is the round number. That is, picking a 14 seed
        #       to win in round 2 is worth 2^(2-1) + 14 = 16 points.
        # if no string is specified, code defaults to "flat"

    #sanitize inputs:
    if not (scoring in {"flat", "seed", "round", "SR"}):
        raise Exception("Invalid scoring system")

    filepath = folder + "/" + filename
    if not os.path.exists(filepath):
        raise Exception("Invalid folder and filename")

    #run code:
    MMData = pd.read_csv(filepath)
    MMDataLong = format_data(MMData, scoring)
    EVbracket = make_EV_best_bracket(6, MMDataLong)
    legible_bracket = make_legible(EVbracket, MMData)

    #write legible bracket to location
    outputFile = folder + "/" + "EV_bracket.csv"
    legible_bracket.to_csv(outputFile, index = False)

