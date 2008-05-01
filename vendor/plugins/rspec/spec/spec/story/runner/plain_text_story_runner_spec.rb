require File.dirname(__FILE__) + '/../story_helper'

module Spec
  module Story
    module Runner
      describe PlainTextStoryRunner do
        before(:each) do
          StoryParser.stub!(:new).and_return(@parser = mock("parser"))
          @parser.stub!(:parse).and_return([])
          File.stub!(:read).with("path").and_return("this\nand that")
        end

        it "should provide access to steps" do
          runner = PlainTextStoryRunner.new("path")
          
          runner.steps do |add|
            add.given("baz") {}
          end
          
          runner.steps.find(:given, "baz").should_not be_nil
        end
        
        it "should parse a story file" do
          runner = PlainTextStoryRunner.new("path")
          
          during {
            runner.run
          }.expect {
            @parser.should_receive(:parse).with(["this", "and that"])
          }
        end
        
        it "should build up a mediator with its own steps and the singleton story_runner" do
          runner = PlainTextStoryRunner.new("path")
          Spec::Story::Runner.should_receive(:story_runner).and_return(story_runner = mock("story runner"))
          Spec::Story::Runner::StoryMediator.should_receive(:new).with(runner.steps, story_runner, {}).
            and_return(mediator = stub("mediator", :run_stories => nil))
          runner.run
        end
        
        it "should build up a parser with the mediator" do
          runner = PlainTextStoryRunner.new("path")
          Spec::Story::Runner.should_receive(:story_runner).and_return(story_runner = mock("story runner"))
          Spec::Story::Runner::StoryMediator.should_receive(:new).and_return(mediator = stub("mediator", :run_stories => nil))
          Spec::Story::Runner::StoryParser.should_receive(:new).with(mediator).and_return(@parser)
          runner.run
        end
        
        it "should tell the mediator to run the stories" do
          runner = PlainTextStoryRunner.new("path")
          mediator = mock("mediator")
          Spec::Story::Runner::StoryMediator.should_receive(:new).and_return(mediator)
          mediator.should_receive(:run_stories)
          runner.run
        end
        
        it "should accept a block instead of a path" do
          runner = PlainTextStoryRunner.new do |runner|
            runner.load("path/to/story")
          end
          File.should_receive(:read).with("path/to/story").and_return("this\nand that")
          runner.run
        end
        
        it "should tell you if you try to run with no path set" do
          runner = PlainTextStoryRunner.new
          lambda {
            runner.run
          }.should raise_error(RuntimeError, "You must set a path to the file with the story. See the RDoc.")
        end
        
        it "should pass options to the mediator" do
          runner = PlainTextStoryRunner.new("path", :foo => :bar)
          Spec::Story::Runner::StoryMediator.should_receive(:new).
            with(anything, anything, :foo => :bar).
            and_return(mediator = stub("mediator", :run_stories => nil))
          runner.run
        end
        
        it "should provide access to its options" do
          runner = PlainTextStoryRunner.new("path")
          runner[:foo] = :bar
          Spec::Story::Runner::StoryMediator.should_receive(:new).
            with(anything, anything, :foo => :bar).
            and_return(mediator = stub("mediator", :run_stories => nil))
          runner.run
        end
        
      end
    end
  end
end