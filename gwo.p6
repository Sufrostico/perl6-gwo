#!/usr/bin/env perl6
use v6;

# --- Miscelaneous functions -------------------------------------------------

#`[ random: return a random number whitin a constraint range
        $lower_bound
        $upper_bound

]
sub random($lower_bound, $upper_bound){

    return  $lower_bound + (1.rand() / (1 / ($upper_bound - $lower_bound)));

}


# --- Omega wolves matrix related functions ----------------------------------

#`[ initialize_matrix: create a matrix of omega wolves which are going to 
                       serve as search agents of the algorithm

        $wolf_quantity: corresponds with the number of rows of the matrix
        $parameter_quantity: Corresponds with the number of columns of the matrix
        @lower_bounds: lower bounds for the parameters of the algorithms
        @upper_bounds: upper bounds for the parameters of the algorithms
]
sub initialize_matrix($wolf_quantity, $parameter_quantity, @lower_bounds, @upper_bounds){
    
    # Creates the matrix 
    my @matrix = [];

    # rows
    loop (my $i = 0; $i < $wolf_quantity; $i++) {

        # columns
        loop (my $j = 0; $j < $parameter_quantity; $j++) {

            # Selecciona un número random en el rango dado.
            @matrix[$i][$j] = random(@lower_bounds[$j] , @upper_bounds[$j]);
        }
    }

    return @matrix
}


#`[ fix_misplaced: Sometimes the algorithm let some wolves run just to far 
                   away from the hunting area, so you move them.

        $parameter_quantity: number of parameters for the fitness function
        $wolf_quantity: amount of search agents
        @omega_wolves: matrix with the positions of the wolves
        @lower_bounds: lower bounds for the parameters
        @upper_bounds: upper bounds for the parameters
]
sub fix_misplaced( $parameter_quantity, $wolf_quantity, @omega_wolves, @lower_bounds, @upper_bounds){

    loop (my $i = 0; $i < $wolf_quantity; $i++){

        loop (my $j = 0; $j < $parameter_quantity; $j++){

            # if the wolf leave the hunting area, just put at a random position
            # within the area.
            if @omega_wolves[$i][$j] <= @lower_bounds[$j] or @omega_wolves[$i][$j] >= @upper_bounds[$j] {
                @omega_wolves[$i][$j] = random( @lower_bounds[$j] , @upper_bounds[$j] );

            }
        }
    }
}

# --- Fitness related functios ---------------------------------------------

#`[ fitness: allow the algorithm to evaluate if a position of an omega wolf
             is better than another.

        $wolf_number
        @parameters 
]
sub fitness_libsvm($wolf_number, @parameters, ){

    my $output = Inf;

    # TODO: improve the parameter management
    # TODO: recive the name of the file as a parameter

    # The command to evalute 
    #       (libsvm as a debian package -> apt-get install libsvm)
    my $libsvm_command = "svm-train -v 2 -s 0 -t 2 -c {2**@parameters[0]} -g  {2**@parameters[1]}  training.libsvm";
    # -v 2 is a bad idea as parameter (should be between 5 and 10) but
    # is here to allow libsvm as fast as it can and for demostration purposes.

    # sent the command for execution
    my $proc = shell($libsvm_command, :out);

    # get the stdout
    my $libsvm_result = $proc.out.slurp-rest;

    # Look for the right line with the result of the training process
    if  $libsvm_result ~~ m:s/Cross Validation Accuracy \= (\d+.\d+)\%/ {
        $output = $0;
    }

    # Results 
    return @($wolf_number, Num($output.Str));

}

#`[ libsvm_grey_wolf_optimizer: core function of the algoritm, select the
                                best parameters based on the fitness 
                                function.

        $wolf_quantity: number of search agents
        $iteration_quantity: number of iterations

]
sub grey_wolf_optimizer($wolf_quantity, $iteration_quantity){

    # number of parameters that need to be searched
    # (this depends on the fitness function).
    my $parameter_quantity = 2;

    # initial positions for the leaders of the pack
	my $alpha_score		= -Inf;
	my @alpha_position 	= [0, 0];

	my $beta_score		= -Inf;
	my @beta_position 	= [0, 0] ;

	my $delta_score		= -Inf;
	my @delta_position 	= [0, 0] ;

    # Defining the hunting area (search space).
    # here we are using a logaritmic scale.
    my @lower_bounds= [-5, -15];
    my @upper_bounds = [15, 3];

    # The pack (search agents) that is going to partipate in the hunting.
	my @omega_wolves 		= initialize_matrix($wolf_quantity, $parameter_quantity, @lower_bounds, @upper_bounds);

    # the pack tries a finite number of times and then leave.
    loop (my $iteration = 0; $iteration < $iteration_quantity; $iteration++){
        say "ITERATION    $iteration";

        # put misplaced wolves back in the right track
        fix_misplaced( $parameter_quantity, $wolf_quantity, @omega_wolves, @lower_bounds, @upper_bounds);

        my @promises = ();
        
        # Evaluate the fitness function based on the wolves of this iteration/pack
        for 0..($wolf_quantity-1) -> $wolf_number {

            # limit the amount of threads to the number of CPU cores
            my $promise = start fitness_libsvm($wolf_number, @(@omega_wolves[$wolf_number]));
            push @promises, $promise;
        }

        # Wait for the information generated by the wolves 
        my @results = await @promises;

        my $fitness = 0;
        my $wolf_number = 0;

        # if an omega wolf finds a good spot, calls one of the leaders to his
        # position.
        for @results -> $result {

            $fitness     = $result[1];
            $wolf_number = $result[0];

            # shows 
            say "Wolf $wolf_number score [$fitness] by using C as @omega_wolves[$wolf_number][0] & Gamma as @omega_wolves[$wolf_number][1] ";

            # just to generate nice charts 
            
            # Positions by iteration
            # spurt "positions.gwo.$iteration", "@omega_wolves[$wolf_number][0],@omega_wolves[$wolf_number][1],$fitness\n", :append;
            
            # put all the positions of the wolves during the execution of the
            # algoritm
            spurt "positions.gwo", "@omega_wolves[$wolf_number][0],@omega_wolves[$wolf_number][1],$fitness\n", :append;

            if ($fitness > $alpha_score) {
                $alpha_score = $fitness;
                @alpha_position = @(@omega_wolves[$wolf_number]);

            }elsif ($fitness > $beta_score) {
                $beta_score = $fitness;
                @beta_position = @(@omega_wolves[$wolf_number]);

            }elsif ($fitness > $delta_score) {
                $delta_score = $fitness;
                @delta_position = @(@omega_wolves[$wolf_number]);
            }
        }

        say "";
        say "\tLeaders positions: Alpha[$alpha_score] Beta[$beta_score] Delta[$delta_score]";
        say "";

        # save the position of the leaders justo to generate nice charts
            # spurt "alpha-beta-delta.$iteration", "@alpha_position[0],@alpha_position[1]\n", :append;
            # spurt "alpha-beta-delta.$iteration", "@beta_position[0],@beta_position[1]\n", :append;
            # spurt "alpha-beta-delta.$iteration", "@delta_position[0],@delta_position[1]\n", :append;

        # Recalculate the value a (an integral part of the algorithm).
        my $a = Num(2 - $iteration) * Num(2 / $iteration_quantity);

        # All the omega wolves are moved to a new position by using the leader's
        # positions as a reference point
		loop (my $i = 0; $i < $wolf_quantity; $i++){

			loop (my $j = 0; $j < $parameter_quantity; $j++){

                my $d_alpha	= abs( (2*1.rand)* @alpha_position[$j] - @omega_wolves[$i][$j]);
                my $x1 		= @alpha_position[$j] - ((2.0*$a*1.rand) - 1.0) * $d_alpha;

		    	my $d_beta 	= abs((2*1.rand)*@beta_position[$j] - @omega_wolves[$i][$j]);
		    	my $x2 		= @beta_position[$j] - ((2.0*$a*1.rand) - 1.0) * $d_beta;

		    	my $d_delta	= abs(2 * 1.rand * @delta_position[$j] - @omega_wolves[$i][$j]);
		    	my $x3 		= @delta_position[$j] - ((2.0*$a*1.rand) - 1.0) * $d_delta;

		    	@omega_wolves[$i][$j] = ($x1 + $x2 + $x3) / 3.0;
			}
		}
	}

    # Hunting is done and the position of the best candidate is returned
	return @alpha_position;
}

#`[ main: Entry point ]
sub main(){

# meaning of the parameters $wolf_quantity | $cantidad_iterationes

# Diferent parameter to play with 

    # return grey_wolf_optimizer(10, 11);
    # return grey_wolf_optimizer(20, 20);
    # return grey_wolf_optimizer(4, 15);

    # TODO: get the parameters from the command line
    return grey_wolf_optimizer(4, 30);
}

# call the main :D
main();
