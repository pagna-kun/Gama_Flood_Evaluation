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
	file building_shape <- file("../includes/buildings.shp");
	file road_shape <- file("../includes/roads.shp");
	geometry shape <- envelope(building_shape, road_shape);
	graph road_network;
	float shelter_distance <- 300#m;
	int shelter_index <- 246;
	
//	Global of people
	float informed_rate <- 0.1;
	float observing_rate <- 0.1;
	float observing_distance <- 100#m;
	int num_people <- 1000;
	
	
//	Extension3
	string strategies;
	string RANDOM <- "Random";
	string CLOSEST <- "Closest";
	string FARTHEST <- "Farthest";
	 
	
	
	
//	initialize
	init{
		create building from: building_shape;
		create road from: road_shape;
		road_network <- as_edge_graph(road_shape);
		
		create people number: num_people;
		
		
		if strategies = RANDOM{
			ask (num_people * informed_rate) among people{
				is_informed <- true;
			}
		} else if strategies = CLOSEST {
			ask (people closest_to (building[shelter_index].shape, num_people*informed_rate)){
				is_informed <- true;
			}
		}else{
			list<people> sort_people <- people sort_by(distance_to(each.location, building[shelter_index].shape));
			ask (sort_people copy_between(num_people-(num_people*informed_rate), num_people+1)){
				is_informed <- true;
			}
		}

	}		
}


/** 
 * Species Block
 */
species building{
	aspect default{
		draw shape color: self.index = shelter_index? #orange : #gray;
		if (int(self) = shelter_index){
			draw circle (shelter_distance) color: #transparent border: #blue width: 50;
		}
	}
}

species road{
	aspect default{
		draw shape color: #red;
	}
}

species people skills: [moving]{


	float speed <- 10#km/#h;
	bool is_informed <- false;	//true if informed directly  
	bool is_observing <- false;	//true if see s.o. evaculated and flip=true
	bool is_reached <- false;
	building shelter <- building[shelter_index];
	point target;

	list<people> selected_people;
	

	init{
		location <- any_location_in(one_of(building));
	}
	
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


	reflex moving when: not is_reached{
		write(strategies);
		if is_informed{
			// go to shelter directly
			do to_shelter_directly;
		}
		else if is_observing{
			// if within shelter distances, go directly
			if location distance_to shelter.shape <= shelter_distance{
//				write("observe and go directly");
				target <- nil;
				do to_shelter_directly;
			}
			// if not go to one building randomly
			else{
//				write("observe and random search");
				do randomly_search_shelter;
				
			}
		}
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
	
	
	aspect default{
		draw circle(7) color: is_informed? #purple : #green ;
	}
}

experiment evaluate type: gui {
	/** Insert here the definition of the input and output of the model */
	parameter "Number of People" var: num_people <- 800 min:500 max:2000 step:50 category: "Initialize";
	parameter "Informed Rate" var: informed_rate <- 0.1 min:0.1 max:1.0 step:0.05 category: "Initialize";
	parameter "Strategiy Selection" var: strategies init:"Random" among:["Random", "Closest", "Farthest"] category: "Initialize";
	parameter "Observing Rate" var: observing_rate <- 0.1 min:0.1 max:1.0 step: 0.05;
	parameter "Observing Distance" var: observing_distance <- 100#m min:0#m max:150#m step: 10#m;
	parameter "Shelter Distance" var: shelter_distance <- 250#m min:0#m max:600#m step: 10#m;
	
	output {
		display simulation type: 2d{
			species road;
			species building;
			species people;
		}
		display chart type: 2d{
			chart "People Reached the Shelter" type: series{
				data "#Informed" value: people count(each.is_informed = true and each.is_reached=true) color: #purple; 
				data "#Not_Informed" value: people count(each.is_informed = false and each.is_reached=true) color: #green;
				data "#Total" value: people count(each.is_reached=true) color: #blue;
			}
		}
		display pie_chart type: 2d{
			chart "Pie chart" type: pie{
				data "#Informed" value: people count(each.is_informed = true and each.is_reached=true) color: #purple; 
				data "#Not_Informed" value: people count(each.is_informed = false and each.is_reached=true) color: #green;
			}
		}
	
	}
}
