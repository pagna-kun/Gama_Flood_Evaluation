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
//	float step <- 5#s;
	
//	buildiing and road loading
	file building_shape <- file("../includes/buildings.shp");
	file road_shape <- file("../includes/roads.shp");

	geometry shape <- envelope(building_shape+ road_shape);
	graph road_network;
	float shelter_distance <- 300#m;
	int shelter_index <- 246;
	
	
//	Global of people
	float informed_rate <- 0.1;
	float observing_rate <- 0.1;
	float observing_distance <- 50#m;
	int num_people <- 1000;
	float walk_speed <- 7#km/#h;
	string CAR <- "Car";
	string MOTO <- "motorcycle";
	string WALK <- "walking";
	map<string, float> mobility <- [CAR::0.2, MOTO::0.7, WALK::0.1];
	
//	Extension2
	map<road, float> update_speed_car update: road as_map(each::(each.shape.perimeter)/(each.speed_rate));
	map<road, float> update_speed_moto update: road as_map(each::(each.shape.perimeter)/(each.speed_rate * 2));
	map<road, float> update_speed_walk update: road as_map(each::(each.shape.perimeter)/(each.speed_rate * 5));
	
//	Extension3
	string strategies;
	string RANDOM <- "Random";
	string CLOSEST <- "Closest";
	string FARTHEST <- "Farthest";	 
	
	
//	initialize
	init{
		create building from: building_shape;
		create road from: road_shape;
		road_network <- as_edge_graph(road);
		
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
		draw shape color: self.index = shelter_index? #darkorange : #gray;
		if (int(self) = shelter_index){
			draw circle (shelter_distance) color: #transparent border: #green width: 50;
		}
	}
}

species road{
	float capacity <- 1+shape.perimeter/30;
	int num_driver <- 0 update: length(people at_distance(1));
	float speed_rate <- 1.0 update: exp(-num_driver/capacity) min:0.1;
	
	aspect default{
		draw (shape buffer 1+ 5*(1-speed_rate)) color: #purple;
	}
}

species people skills: [moving]{

	bool is_informed <- false;	//true if informed directly  
	bool is_observing <- false;	//true if see s.o. evaculated and flip=true
	bool is_reached <- false;
	building shelter <- building[shelter_index];
	point target;
	string mobility_choice <- rnd_choice(mobility);
	

	init{
		location <- any_location_in(one_of(building));
		if mobility_choice = CAR{
			speed <- 10 * walk_speed;
		}else if mobility_choice = MOTO{
			speed <- 10 * walk_speed * 0.85;
		}else{
			speed <- walk_speed;
		}
	}
	
	action to_shelter_directly{
		if target = nil{
			target <- any_location_in(shelter);
		}
		if mobility_choice = CAR{
			do goto target: target on:road_network move_weights: update_speed_car;		
		}
		else if mobility_choice = MOTO{
			do goto target: target on:road_network move_weights: update_speed_moto;
		}else{
			do goto target: target on:road_network move_weights: update_speed_walk;
		}
//		
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
		if mobility_choice = CAR{
			do goto target: target on:road_network move_weights: update_speed_car;		
		}
		else if mobility_choice = MOTO{
			do goto target: target on:road_network move_weights: update_speed_moto;
		}else{
			do goto target: target on:road_network move_weights: update_speed_walk;
		}
		if target = location{
			target <- nil;
		}
	}


	reflex moving when: not is_reached{
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
		if mobility_choice = CAR{
			draw square(15) color: is_informed ? #cyan : #red border: is_informed?#black:#transparent;
		}
		else if mobility_choice = MOTO{
			draw triangle(20) color: is_informed ? #cyan : #red border: is_informed?#black:#transparent;
		}
		else{
			draw circle(10) color: is_informed ? #cyan : #red border: is_informed?#black:#transparent;
		}
	}
}

experiment evaluate type: gui {
	/** Insert here the definition of the input and output of the model */
	parameter "Number of People" var: num_people <- 800 min:0 max:2000 step:50 category: "Initialize";
	parameter "Informed Rate" var: informed_rate <- 0.1 min:0.1 max:1.0 step:0.05 category: "Initialize";
	parameter "Strategiy Selection" var: strategies init:"Random" among:["Random", "Closest", "Farthest"] category: "Initialize";
	parameter "Observing Rate" var: observing_rate <- 0.1 min:0.1 max:1.0 step: 0.05;
	parameter "Observing Distance" var: observing_distance <- 50#m min:0#m max:150#m step: 10#m;
	parameter "Shelter Distance" var: shelter_distance <- 250#m min:0#m max:600#m step: 10#m;
	parameter "Walk Speed" var: walk_speed <- 2#m/#s min:0#m/#s max:5#m/#s step: 0.5#m/#s;
	
	output {
		display simulation type: 2d{
			species building;
			species road;
			species people;
		}
	
	}
}

experiment evaluate_with_graph type: gui {
	/** Insert here the definition of the input and output of the model */
	parameter "Number of People" var: num_people <- 800 min:0 max:2000 step:50 category: "Initialize";
	parameter "Informed Rate" var: informed_rate <- 0.1 min:0.1 max:1.0 step:0.05 category: "Initialize";
	parameter "Strategiy Selection" var: strategies init:"Random" among:["Random", "Closest", "Farthest"] category: "Initialize";
	parameter "Observing Rate" var: observing_rate <- 0.1 min:0.1 max:1.0 step: 0.05;
	parameter "Observing Distance" var: observing_distance <- 50#m min:0#m max:150#m step: 10#m;
	parameter "Shelter Distance" var: shelter_distance <- 250#m min:0#m max:600#m step: 10#m;
	parameter "Walk Speed" var: walk_speed <- 2#m/#s min:0#m/#s max:5#m/#s step: 0.5#m/#s;
	
	output {
		display simulation type: 2d{
			species building;
			species road;
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
			chart "Shelter Reach Distribution: Informed vs Not Informed" type: pie{
				data "#Informed" value: people count(each.is_informed = true and each.is_reached=true) color: #purple; 
				data "#Not_Informed" value: people count(each.is_informed = false and each.is_reached=true) color: #green;
			}
		}
	
	}
}
