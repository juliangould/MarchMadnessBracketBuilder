####Format data####
format_data <- function(filepath, scoring = "even"){
    #data must be appropriatly formatted as described in the readme.txt
    #scoring should be input as one of the following strings:
        # "flat" if each correct guess is worth 1 point 
        # "seed" if each correct guess is worth 1 + seed points
        # "round" if each correct guess is worth 2^(r-1) points
        #       where r is the round number. 
        # "SR" if each correct guess is worth 2^(r-1) + seed points
        #       where r is the round number. That is, picking a 14 seed
        #       to win in round 2 is worth 2^(2-1) + 14 = 16 points. 
        # if no string is specified, code defualts to "flat"
    
    #check scoring:
    if(missing(scoring)){
        scoring <- "flat"
    }

    #Data Import
    MMdata <- setDT(read.csv(filepath, stringsAsFactors = FALSE))

    #Get data long
    MMdatalong <- melt(MMdata, id.vars = c('team_name', 'team_seed', 'team_num'),
                       variable.name = "round", value.name = "prob")

    #rename round numbers
    MMdatalong[round == "r1", round_num := 1]
    MMdatalong[round == "r2", round_num := 2]
    MMdatalong[round == "r3", round_num := 3]
    MMdatalong[round == "r4", round_num := 4]
    MMdatalong[round == "r5", round_num := 5]
    MMdatalong[round == "r6", round_num := 6]

    #remove round field.
    MMdatalong[, round := NULL]

    #Get Points value for winning each round
    MMdatalong[, team_seed := as.numeric(team_seed)]
    MMdatalong[, round_num := as.numeric(round_num)]
    if(scoring == "flat"){
        MMdatalong[, points := 1]
    } else if(scoring == "seed"){
        MMdatalong[, points := 1 + team_seed]
    } else if(scoring == "round"){
        MMdatalong[, points := 2^(round_num - 1)]
    } else if (scoring == "SR"){
        MMdatalong[, points := team_seed + 2^(round_num - 1)]    
    } else {
        return("error: invalid scoring system")
    }

    return(MMdatalong)
}


#EV Bracket Calculator####

####function for making an empty k-round bracket####
new_bracket <- function(k){
    #k is number of rounds in the bracket
    rounds <- c()
    games <- c()
    for(r in 1:k){
        rounds <- c(rounds, rep(r, 2^(k-r)))
        games <- c(games, 1:2^(k-r))
    }
  
    bracket <- data.table(
        "round_num" = rounds,
        "game" = games)
  
    bracket[, round_num := as.numeric(round_num)]
    bracket[, game := as.numeric(game)]
  
    return(bracket)
}

####function for making sub-brackets####
sub_bracket <- function(r,g,k){
  #We start with a k-round bracket. We make the sub-bracket 
    #with r rounds and "final" game g 
  bracket <- new_bracket(k)
  bracket <- bracket[(round_num <= r) & 
                       (2^(r - round_num)*(g-1)+1 <= game) &
                       (game <= 2^(r - round_num)*g)]
  return(bracket)
}

####Expectation Checker (use best_bracket and MMdatalong)####
expected_points <- function(bracket,data){
    #This function takes in a bracket and probabilities (data)
        #and outputs the EV of the bracket. Note that the 
        #bracket must have gone through the formatting process
        #before it's input. In particular, this is where the 
        #scoring system is included. 
    bracket <- merge(bracket, data, 
                     by.x = c("round_num", "choice"), 
                     by.y = c("round_num", "team_num")
                     )
    return(sum(bracket[,prob*points]))
}


####recursive function for optimal subtournaments####
optimal_bracket_fun <- function(r,g,k,i,data){
    #this function computes the best choice of bracket for the subtournament 
    #   of a k round tournament crowned by game (r,g), 
    #   assuming we take team i all the way through to
    #   being the champion of the sub-tournament
    #   data must have been formatted before entering
  
    #check if i is valid team:
    if ((i > ((2^r)*g)) | (i < ((2^r) * (g-1) + 1))){
        return("Error, invalid team")
    }
  
    #data storage:
    bracket <- sub_bracket(r,g,k)
    bracket[, choice := NA]
    exp_tot_pts <- 0
  
    #base case:
    if(r == 1){
        #print("made it in")
        bracket[, choice := i]
        exp_tot_pts <- data[(team_num == i) & (round_num == 1), prob * points]
        output <- list(bracket, exp_tot_pts)
    
        return(output)
    }
  
    #recursive part:
    if(r > 1){
    
        #if team i is in first half of bracket
        if((((2^r)*(g-1)+1) <= i) & (i <= ((2^(r-1))*((2*g)-1)))){
      
            #break into first half, second half, and final game
      
            #first half: want to push team i all the way through
            first_half <- optimal_bracket_fun(r-1,2*g-1,k-1,i,data)
      
            #second half: want best possible across all j
            second_half <- list(0,0)
      
            for(j in ((2^(r-1))*(2*g-1)+1):((2^r)*g) ){
                second_half_j <- optimal_bracket_fun(r-1,2*g,k-1,j,data)
                if(second_half_j[[2]] > second_half[[2]] ){
                    second_half <- second_half_j
                }
            }
      
            #final game: use probabilties and points from data
            final_game <- data[(team_num == i) & (round_num) == r, points * prob]
      
            #assemble the outputs
            exp_tot_pts <- first_half[[2]] + second_half[[2]] + final_game
            bracket <- rbind(first_half[[1]], second_half[[1]],
                             data.table(round_num = r, game = g, choice = i))
      
        }   
    
        #if team i is in second half of bracket
        if((((2^(r-1))*(2*g-1)+1) <= i) & (i <= ((2^r)*g))){
      
            #break into second half, second half, and final game
      
            #second half: want to push team i all the way through
            second_half <- optimal_bracket_fun(r-1,2*g,k-1,i,data)
      
            #first half: want best possible across all j
            first_half <- list(0,0)
      
            for(j in (((2^r)*(g-1)+1)):(((2^(r-1))*((2*g)-1)) )){
                first_half_j <- optimal_bracket_fun(r-1,2*g-1,k-1,j,data)
                if(first_half_j[[2]] > first_half[[2]] ){
                    first_half <- first_half_j
                }
            }
      
            #final game: use probabilties and points from data
            final_game <- data[(team_num == i) & (round_num) == r, points * prob]
      
            #assemble the outputs
            exp_tot_pts <- first_half[[2]] + second_half[[2]] + final_game
            bracket <- rbind(first_half[[1]], second_half[[1]],
                             data.table(round_num = r, game = g, choice = i))
        }
    
        #output
        output <- list(bracket, exp_tot_pts)
        return(output)
    }
}


####Find Best Bracket####
make_EVbracket <- function(k,data){
    #data must be formatted
    #k is number of rounds in tournament

    max_exp_pts <- 0
    results <- data.table(team_num = 1:64, result =rep(0,(2^k)) )

    for(i in 1:(2^k)){
        print(paste("Running step ", as.character(i), " of ", as.character(2^k)))
        val <- optimal_bracket_fun(k,1,k,i,data)
        results[team_num == i, result := val[[2]], by = team_num]
        if(val[[2]] > max_exp_pts){
            max_exp_pts <- val[[2]]
            EVbest_bracket <- val[[1]]
        }
    }
    
    return(EVbest_bracket)
}



####make bracket readable####
make_readable <- function(bracket, data){
    #this funciton takes the unreadable bracket and returns a readable version with team names and round win indformation
    atlas <- data[,.(team_num, team_name)]
    bracket <- merge(atlas, bracket, by.x = "team_num", by.y = "choice")
    bracket[,max_round_num := max(round_num), by = team_name]
    bracket <- bracket[round_num == max_round_num,]
    bracket <- bracket[order(team_num)]
    bracket <- bracket[, .(team_name, round_num)]
    setnames(bracket, "round_num", "last_round_won")

    return(bracket)
}


#### Wrapper ####
MM_Bracket_Builder <- function(folder, filename, scoring){
    
    #sanitize inputs:
    if (!(scoring %in% c("flat", "seed", "round", "SR"))){
        stop("Error: invalid scoring system")
    }

    filepath = paste(folder, filename, sep = "/")
    if (!(file.exists(filepath))){
        stop("Error: invalid folder and filename")
    }

    #Run code
    MMdata <- format_data(filepath, scoring)
    EVbracket <- make_EVbracket(6, MMdata)
    readable_bracket <- make_readable(EVbracket, MMdata)
    write.csv(readable_bracket, file = paste(folder, "EV_bracket.csv", sep = "/"))
}
