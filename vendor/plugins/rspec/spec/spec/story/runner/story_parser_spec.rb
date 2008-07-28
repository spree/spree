require File.dirname(__FILE__) + '/../story_helper'

module Spec
	module Story
		module Runner
		  
			describe StoryParser do
			  before(:each) do
			    @story_mediator = mock("story_mediator")
		    	@parser = StoryParser.new(@story_mediator)
			  end

			  it "should parse no lines" do
					@parser.parse([])
			  end
			  
			  it "should ignore text before the first Story: begins" do
			    @story_mediator.should_not_receive(:create_scenario)
			    @story_mediator.should_not_receive(:create_given)
			    @story_mediator.should_not_receive(:create_when)
			    @story_mediator.should_not_receive(:create_then)
			    @story_mediator.should_receive(:create_story).with("simple addition", "")
					@parser.parse(["Here is a bunch of text", "about a calculator and all the things", "that it will do", "Story: simple addition"])
		    end
			  
			  it "should create a story" do
			    @story_mediator.should_receive(:create_story).with("simple addition", "")
					@parser.parse(["Story: simple addition"])
			  end
			  
			  it "should create a story when line has leading spaces" do
			    @story_mediator.should_receive(:create_story).with("simple addition", "")
					@parser.parse(["    Story: simple addition"])
			  end
			  
			  it "should add a one line narrative to the story" do
			    @story_mediator.should_receive(:create_story).with("simple addition","narrative")
					@parser.parse(["Story: simple addition","narrative"])
			  end
			  
			  it "should add a multi line narrative to the story" do
			    @story_mediator.should_receive(:create_story).with("simple addition","narrative line 1\nline 2\nline 3")
					@parser.parse(["Story: simple addition","narrative line 1", "line 2", "line 3"])
			  end
			  
			  it "should exclude blank lines from the narrative" do
			    @story_mediator.should_receive(:create_story).with("simple addition","narrative line 1\nline 2")
					@parser.parse(["Story: simple addition","narrative line 1", "", "line 2"])
			  end
			  
			  it "should exclude Scenario from the narrative" do
			    @story_mediator.should_receive(:create_story).with("simple addition","narrative line 1\nline 2")
			    @story_mediator.should_receive(:create_scenario)
					@parser.parse(["Story: simple addition","narrative line 1", "line 2", "Scenario: add one plus one"])
			  end
			  
			end

			describe StoryParser, "in Story state" do
			  before(:each) do
			    @story_mediator = mock("story_mediator")
		    	@parser = StoryParser.new(@story_mediator)
			    @story_mediator.stub!(:create_story)
			  end
			  
			  it "should create a second Story for Story" do
          @story_mediator.should_receive(:create_story).with("number two","")
					@parser.parse(["Story: s", "Story: number two"])
			  end
			  
			  it "should include And in the narrative" do
          @story_mediator.should_receive(:create_story).with("s","And foo")
          @story_mediator.should_receive(:create_scenario).with("bar")
					@parser.parse(["Story: s", "And foo", "Scenario: bar"])
			  end
			  
			  it "should create a Scenario for Scenario" do
          @story_mediator.should_receive(:create_scenario).with("number two")
					@parser.parse(["Story: s", "Scenario: number two"])
			  end

			  it "should include Given in the narrative" do
          @story_mediator.should_receive(:create_story).with("s","Given foo")
          @story_mediator.should_receive(:create_scenario).with("bar")
					@parser.parse(["Story: s", "Given foo", "Scenario: bar"])
			  end
			  
			  it "should include Given: in the narrative" do
          @story_mediator.should_receive(:create_story).with("s","Given: foo")
          @story_mediator.should_receive(:create_scenario).with("bar")
					@parser.parse(["Story: s", "Given: foo", "Scenario: bar"])
			  end
			  			  
			  it "should include When in the narrative" do
          @story_mediator.should_receive(:create_story).with("s","When foo")
          @story_mediator.should_receive(:create_scenario).with("bar")
					@parser.parse(["Story: s", "When foo", "Scenario: bar"])
			  end
			  			  
			  it "should include Then in the narrative" do
          @story_mediator.should_receive(:create_story).with("s","Then foo")
          @story_mediator.should_receive(:create_scenario).with("bar")
					@parser.parse(["Story: s", "Then foo", "Scenario: bar"])
			  end
			  			  
			  it "should include other in the story" do
          @story_mediator.should_receive(:create_story).with("s","narrative")
					@parser.parse(["Story: s", "narrative"])
			  end
			end
			
			describe StoryParser, "in Scenario state" do
			  before(:each) do
			    @story_mediator = mock("story_mediator")
		    	@parser = StoryParser.new(@story_mediator)
			    @story_mediator.stub!(:create_story)
			    @story_mediator.stub!(:create_scenario)
			  end
			  
			  it "should create a Story for Story" do
          @story_mediator.should_receive(:create_story).with("number two","")
					@parser.parse(["Story: s", "Scenario: s", "Story: number two"])
			  end
			  
			  it "should create a Scenario for Scenario" do
          @story_mediator.should_receive(:create_scenario).with("number two")
					@parser.parse(["Story: s", "Scenario: s", "Scenario: number two"])
			  end

			  it "should raise for And" do
			    lambda {
  					@parser.parse(["Story: s", "Scenario: s", "And second"])
			    }.should raise_error(IllegalStepError, /^Illegal attempt to create a And after a Scenario/)
			  end
			  
			  it "should create a Given for Given" do
          @story_mediator.should_receive(:create_given).with("gift")
					@parser.parse(["Story: s", "Scenario: s", "Given gift"])
			  end
			  
			  it "should create a Given for Given:" do
          @story_mediator.should_receive(:create_given).with("gift")
					@parser.parse(["Story: s", "Scenario: s", "Given: gift"])
			  end
			  
			  it "should create a GivenScenario for GivenScenario" do
          @story_mediator.should_receive(:create_given_scenario).with("previous")
					@parser.parse(["Story: s", "Scenario: s", "GivenScenario previous"])
			  end
			  
			  it "should create a GivenScenario for GivenScenario:" do
          @story_mediator.should_receive(:create_given_scenario).with("previous")
					@parser.parse(["Story: s", "Scenario: s", "GivenScenario: previous"])
			  end
			  
			  it "should transition to Given state after GivenScenario" do
          @story_mediator.stub!(:create_given_scenario)
					@parser.parse(["Story: s", "Scenario: s", "GivenScenario previous"])
					@parser.instance_eval{@state}.should be_an_instance_of(StoryParser::GivenState)
			  end
			  
			  it "should transition to Given state after GivenScenario:" do
          @story_mediator.stub!(:create_given_scenario)
					@parser.parse(["Story: s", "Scenario: s", "GivenScenario: previous"])
					@parser.instance_eval{@state}.should be_an_instance_of(StoryParser::GivenState)
			  end
			  
			  it "should create a When for When" do
          @story_mediator.should_receive(:create_when).with("ever")
					@parser.parse(["Story: s", "Scenario: s", "When ever"])
			  end
			  
			  it "should create a When for When:" do
          @story_mediator.should_receive(:create_when).with("ever")
					@parser.parse(["Story: s", "Scenario: s", "When: ever"])
			  end
			  
			  it "should create a Then for Then" do
          @story_mediator.should_receive(:create_then).with("and there")
					@parser.parse(["Story: s", "Scenario: s", "Then and there"])
			  end
			  
			  it "should create a Then for Then:" do
          @story_mediator.should_receive(:create_then).with("and there")
					@parser.parse(["Story: s", "Scenario: s", "Then: and there"])
			  end
			  
			  it "should ignore other" do
					@parser.parse(["Story: s", "Scenario: s", "this is ignored"])
			  end
			end
						
			describe StoryParser, "in Given state" do
			  before(:each) do
			    @story_mediator = mock("story_mediator")
		    	@parser = StoryParser.new(@story_mediator)
			    @story_mediator.stub!(:create_story)
			    @story_mediator.stub!(:create_scenario)
			    @story_mediator.should_receive(:create_given).with("first")
			  end
			  
			  it "should create a Story for Story" do
          @story_mediator.should_receive(:create_story).with("number two","")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "Story: number two"])
			  end
			  
			  it "should create a Scenario for Scenario" do
          @story_mediator.should_receive(:create_scenario).with("number two")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "Scenario: number two"])
			  end

			  it "should create a second Given for Given" do
          @story_mediator.should_receive(:create_given).with("second")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "Given second"])
			  end
			  
			  it "should create a second Given for And" do
          @story_mediator.should_receive(:create_given).with("second")
					@parser.parse(["Story: s", "Scenario: s", "Given: first", "And second"])
			  end
			  
			  it "should create a second Given for And:" do
          @story_mediator.should_receive(:create_given).with("second")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "And: second"])
			  end
			  
			  it "should create a When for When" do
          @story_mediator.should_receive(:create_when).with("ever")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "When ever"])
			  end
			  
			  it "should create a When for When:" do
          @story_mediator.should_receive(:create_when).with("ever")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "When: ever"])
			  end
			  
			  it "should create a Then for Then" do
          @story_mediator.should_receive(:create_then).with("and there")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "Then and there"])
			  end
			  
			  it "should create a Then for Then:" do
          @story_mediator.should_receive(:create_then).with("and there")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "Then: and there"])
			  end
			  
			  it "should ignore lines beginning with '#'" do
					@parser.parse(["Story: s", "Scenario: s", "Given first", "#this is ignored"])
			  end

			  it "should not ignore lines beginning with non-keywords" do
          @story_mediator.should_receive(:add_to_last).with("\nthis is not ignored")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "this is not ignored"])
			  end
			  
			end

			describe StoryParser, "in When state" do
			  before(:each) do
			    @story_mediator = mock("story_mediator")
		    	@parser = StoryParser.new(@story_mediator)
			    @story_mediator.stub!(:create_story)
			    @story_mediator.stub!(:create_scenario)
			    @story_mediator.should_receive(:create_given).with("first")
			    @story_mediator.should_receive(:create_when).with("else")
			  end
			  
			  it "should create a Story for Story" do
          @story_mediator.should_receive(:create_story).with("number two","")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "When: else", "Story: number two"])
			  end
			  
			  it "should create a Scenario for Scenario" do
          @story_mediator.should_receive(:create_scenario).with("number two")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "When else", "Scenario: number two"])
			  end

			  it "should create Given for Given" do
          @story_mediator.should_receive(:create_given).with("second")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "When else", "Given second"])
			  end
			  
			  it "should create Given for Given:" do
          @story_mediator.should_receive(:create_given).with("second")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "When else", "Given: second"])
			  end
			  
			  it "should create a second When for When" do
          @story_mediator.should_receive(:create_when).with("ever")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "When else", "When ever"])
			  end
			  
			  it "should create a second When for When:" do
          @story_mediator.should_receive(:create_when).with("ever")
					@parser.parse(["Story: s", "Scenario: s", "Given: first", "When: else", "When: ever"])
			  end
			  
			  it "should create a second When for And" do
          @story_mediator.should_receive(:create_when).with("ever")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "When else", "And ever"])
			  end
			  
			  it "should create a second When for And:" do
          @story_mediator.should_receive(:create_when).with("ever")
					@parser.parse(["Story: s", "Scenario: s", "Given: first", "When: else", "And: ever"])
			  end
			  
			  it "should create a Then for Then" do
          @story_mediator.should_receive(:create_then).with("and there")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "When else", "Then and there"])
			  end
			  
			  it "should create a Then for Then:" do
          @story_mediator.should_receive(:create_then).with("and there")
					@parser.parse(["Story: s", "Scenario: s", "Given: first", "When: else", "Then: and there"])
			  end
			  
			  it "should ignore lines beginning with '#'" do
					@parser.parse(["Story: s", "Scenario: s", "Given first", "When else", "#this is ignored"])
			  end

			  it "should not ignore lines beginning with non-keywords" do
          @story_mediator.should_receive(:add_to_last).with("\nthis is not ignored")
					@parser.parse(["Story: s", "Scenario: s", "Given: first", "When else", "this is not ignored"])
			  end
			end

			describe StoryParser, "in Then state" do
			  before(:each) do
			    @story_mediator = mock("story_mediator")
		    	@parser = StoryParser.new(@story_mediator)
			    @story_mediator.stub!(:create_story)
			    @story_mediator.stub!(:create_scenario)
			    @story_mediator.should_receive(:create_given).with("first")
			    @story_mediator.should_receive(:create_when).with("else")
			    @story_mediator.should_receive(:create_then).with("what")
			  end
			  
			  it "should create a Story for Story" do
          @story_mediator.should_receive(:create_story).with("number two","")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "When else", "Then what", "Story: number two"])
			  end
			  
			  it "should create a Scenario for Scenario" do
          @story_mediator.should_receive(:create_scenario).with("number two")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "When else", "Then what", "Scenario: number two"])
			  end

			  it "should create Given for Given" do
          @story_mediator.should_receive(:create_given).with("second")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "When else", "Then what", "Given second"])
			  end
			  
			  it "should create Given for Given:" do
          @story_mediator.should_receive(:create_given).with("second")
					@parser.parse(["Story: s", "Scenario: s", "Given: first", "When: else", "Then: what", "Given: second"])
			  end
			  
			  it "should create When for When" do
          @story_mediator.should_receive(:create_when).with("ever")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "When else", "Then what", "When ever"])
			  end
			  
			  it "should create When for When:" do
          @story_mediator.should_receive(:create_when).with("ever")
					@parser.parse(["Story: s", "Scenario: s", "Given: first", "When: else", "Then: what", "When: ever"])
			  end

			  it "should create a Then for Then" do
          @story_mediator.should_receive(:create_then).with("and there")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "When else", "Then what", "Then and there"])
			  end
			  
			  it "should create a Then for Then:" do
          @story_mediator.should_receive(:create_then).with("and there")
					@parser.parse(["Story: s", "Scenario: s", "Given: first", "When: else", "Then: what", "Then: and there"])
			  end

			  it "should create a second Then for And" do
          @story_mediator.should_receive(:create_then).with("ever")
					@parser.parse(["Story: s", "Scenario: s", "Given first", "When else", "Then what", "And ever"])
			  end
			  
			  it "should create a second Then for And:" do
          @story_mediator.should_receive(:create_then).with("ever")
					@parser.parse(["Story: s", "Scenario: s", "Given: first", "When: else", "Then: what", "And: ever"])
			  end

			  
			  it "should ignore lines beginning with '#'" do
					@parser.parse(["Story: s", "Scenario: s", "Given first", "When else", "Then what", "#this is ignored"])
			  end

			  it "should not ignore lines beginning with non-keywords" do
          @story_mediator.should_receive(:add_to_last).with("\nthis is not ignored")
					@parser.parse(["Story: s", "Scenario: s", "Given: first", "When else", "Then what", "this is not ignored"])
			  end
			end
		end
	end
end