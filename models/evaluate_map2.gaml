/**
* Name: evaluate
* Based on the internal skeleton template. 
* Author: sopagna
* Tags: 
*/

model Evaluate

/**
 * Global Block
 * */
global {
	/** Insert the global definitions, variables and actions here */
//	About the world
	float step <- 5#s;

//	buildiing and road loading
	file building_shape <- file("../includes/building.shp");
	file road_shape <- file("../includes/road.shp");

//	file building_shape <- file("../includes/buildings.shp");
//	file road_shape <- file("../includes/roads.shp");
	geometry shape <- envelope(building_shape, road_shape);
	graph road_network;
	float shelter_distance <- 60#m;
	int shelter_index <- 27;
	
//	Global of people
	float informed_rate <- 0.01;
	float observing_rate <- 0.5;
	float observing_distance <- 10#m;
	
	
	
	
//	initialize
	init{
		create building from: building_shape;
		create road from: road_shape;
		road_network <- as_edge_graph(road_shape);
		
		create people number: 1000;
	}		
}


/** 
 * Species Block
 */
species building{
	aspect default{
		draw shape color: self.index = shelter_index? #orange : #gray ;
		if (int(self) = shelter_index) {
			draw circle (shelter_distance) color: #transparent border: #orange width: 50;
		}
	}
}

species road{
	aspect default{
		draw shape color: #red;
	}
}

species people skills: [moving]{
//	variable
	float speed <- 5#km/#h;
	bool is_informed <- false;	//true if informed directly  
	bool is_observing <- false;	//true if see s.o. evaculated and flip=true
	bool is_reached <- false;
	building shelter <- building[shelter_index];
	point target;
//  init
	init{
		location <- any_location_in(one_of(building));
//		location <- any_location_in(building[27]);
		is_informed <- flip(informed_rate);
	}
	
//	action
	action to_shelter_directly{
		if target = nil{
			target <- any_location_in(shelter);
		}
		do goto target: target on:road_network;
		if target = location{
			is_reached <- true;
		}
	}
	action randomly_search_shelter{
		// this logic work depend only 2 factors.
		// - one is the shelter distance is big, and agent roam around until go in range.
		// - two is when random selected building is the shelter itself, so when travel it gose in range of shelter distance.
		if target = nil{
			target <- any_location_in(one_of(building));
		}
		do goto target: target on:road_network;
		if target = location{
			target <- nil;
		}
	}
	
//	reflex
	reflex moving when: not is_reached{
		if is_informed{
			// go to shelter directly
			do to_shelter_directly;
		}
		else if is_observing{
			// if within shelter distances, go directly
			if location distance_to shelter.shape <= shelter_distance{
				write("observe and go directly");
				target <- nil;
				do to_shelter_directly;
			}
//			// if not go to one building randomly
			else{
				write("observe and random search");
				do randomly_search_shelter;
				
			}
		}
//		if not is_informed and not is_observing{			
		// this feature do not know how to implement, cuz can not get geometry bound.
//			do wander; // TODO: wander within the buidling if not informed and not know about evacuation.
//		}
		
		
	}
	reflex being_observe when: is_informed or is_observing{
		// This observe is related to the time step execution since and the speed of people travel.
		// if people moving to slow, the same observation people have high protial to flip their luck for next time step.  
		list<people> neighbor <- people at_distance(observing_distance);
		ask neighbor{
			if not is_observing and not is_informed{
				is_observing <- flip(observing_rate);
			}
		}
	}
	
	
//	aspect
	aspect default{
		draw circle(4) color: is_informed? #purple : #green ;
	}
	
	
}

experiment evaluate type: gui {
	/** Insert here the definition of the input and output of the model */
	output {
		display simulation type: 2d{
			species building;
			species road;
			species people;
		}

	}
}
