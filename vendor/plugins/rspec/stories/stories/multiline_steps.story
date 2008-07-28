Story: multiline steps in plain text stories

	As a plain text story writer
	I want to write steps with multiline arguments
	
	Scenario: two lines
	
		Given I have a two line step with this text:
		  This is the first line
			# This, by the way, is just a comment
			plus this is the second line

			# This, by the way, is just a comment
			
		When I have a When with the same two lines:
		  This is the first line
			plus this is the second line
			
		Then it should match:
 	  	This is the first line
			plus this is the second line
			
			# And here is another comment
