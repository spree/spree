require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module Example
    # describe "Spec::Example::ExampleRunner", "#run", :shared => true do
    #   before(:each) do
    #     @options = ::Spec::Runner::Options.new(StringIO.new, StringIO.new)
    #     @reporter = ::Spec::Runner::Reporter.new(@options)
    #     @options.reporter = @reporter
    #     @example_group_class = Class.new(ExampleGroup) do
    #       plugin_mock_framework
    #       describe("Some Examples")
    #     end
    #   end
    # 
    #   def create_runner(example_definition)
    #     example = @example_group_class.new(example_definition)
    #     runner = ExampleGroup.new(@options, example)
    #     runner.stub!(:verify_mocks)
    #     runner.stub!(:teardown_mocks)
    #     runner
    #   end
    # end
    # 
    # describe ExampleRunner, "#run with blank passing example" do
    #   it_should_behave_like "Spec::Example::ExampleRunner#run"
    # 
    #   before do
    #     @e = @example_group_class.it("example") {}
    #     @runner = create_runner(@e)
    #   end
    #   
    #   it "should send reporter example_started" do
    #     @reporter.should_receive(:example_started).with(equal(@e))
    #     @runner.run
    #   end
    # 
    #   it "should report its name for dry run" do
    #     @options.dry_run = true
    #     @reporter.should_receive(:example_finished).with(equal(@e), nil)
    #     @runner.run
    #   end
    # 
    #   it "should report success" do
    #     @reporter.should_receive(:example_finished).with(equal(@e), nil)
    #     @runner.run
    #   end
    # end
    # 
    # describe ExampleRunner, "#run with a failing example" do
    #   predicate_matchers[:is_a] = [:is_a?]
    #   it_should_behave_like "Spec::Example::ExampleRunner#run"
    # 
    #   before do
    #     @e = @example_group_class.it("example") do
    #       (2+2).should == 5
    #     end
    #     @runner = create_runner(@e)
    #   end
    # 
    #   it "should report failure due to failure" do
    #     @reporter.should_receive(:example_finished).with(
    #       equal(@e),
    #       is_a(Spec::Expectations::ExpectationNotMetError)
    #     )
    #     @runner.run
    #   end
    # end
    # 
    # describe ExampleRunner, "#run with a erroring example" do
    #   it_should_behave_like "Spec::Example::ExampleRunner#run"
    # 
    #   before do
    #     @error = error = NonStandardError.new("in body")
    #     @example_definition = @example_group_class.it("example") do
    #       raise(error)
    #     end
    #     @runner = create_runner(@example_definition)
    #   end
    # 
    #   it "should report failure due to error" do
    #     @reporter.should_receive(:example_finished).with(
    #       equal(@example_definition),
    #       @error
    #     )
    #     @runner.run
    #   end
    # 
    #   it "should run after_each block" do
    #     @example_group_class.after(:each) do
    #       raise("in after_each")
    #     end
    #     @reporter.should_receive(:example_finished) do |example_definition, error|
    #       example_definition.should equal(@example_definition)
    #       error.message.should eql("in body")
    #     end
    #     @runner.run
    #   end      
    # end
    # 
    # describe ExampleRunner, "#run where after_each fails" do
    #   it_should_behave_like "Spec::Example::ExampleRunner#run"
    # 
    #   before do
    #     @example_ran = example_ran = false
    #     @example_definition = @example_group_class.it("should not run") do
    #       example_ran = true
    #     end
    #     @runner = create_runner(@example_definition)
    #     @example_group_class.after(:each) { raise(NonStandardError.new("in after_each")) }
    #   end
    # 
    #   it "should report failure location when in after_each" do
    #     @reporter.should_receive(:example_finished) do |example_definition, error|
    #       example_definition.should equal(@example_definition)
    #       error.message.should eql("in after_each")
    #     end
    #     @runner.run
    #   end
    # end
    # 
    # describe ExampleRunner, "#run with use cases" do
    #   predicate_matchers[:is_a] = [:is_a?]
    #   it_should_behave_like "Spec::Example::ExampleRunner#run"
    # 
    #   it "should report NO NAME when told to use generated description with --dry-run" do
    #     @options.dry_run = true
    #     example_definition = @example_group_class.it() do
    #       5.should == 5
    #     end
    #     runner = create_runner(example_definition)
    # 
    #     @reporter.should_receive(:example_finished) do |example_definition, error|
    #       example_definition.description.should == "NO NAME (Because of --dry-run)"
    #      end
    #     runner.run
    #   end
    # 
    #   it "should report given name if present with --dry-run" do
    #     @options.dry_run = true
    #     example_definition = @example_group_class.it("example name") do
    #       5.should == 5
    #     end
    #     runner = create_runner(example_definition)
    # 
    #     @reporter.should_receive(:example_finished) do |example_definition, error|
    #       example_definition.description.should == "example name"
    #      end
    #     runner.run
    #   end
    # 
    #   it "should report NO NAME when told to use generated description with no expectations" do
    #     example_definition = @example_group_class.it() {}
    #     runner = create_runner(example_definition)
    #     @reporter.should_receive(:example_finished) do |example, error|
    #       example.description.should == "NO NAME (Because there were no expectations)"
    #     end
    #     runner.run
    #   end
    # 
    #   it "should report NO NAME when told to use generated description and matcher fails" do
    #     example_definition = @example_group_class.it() do
    #       5.should "" # Has no matches? method..
    #     end
    #     runner = create_runner(example_definition)
    # 
    #     @reporter.should_receive(:example_finished) do |example, error|
    #       example_definition.description.should == "NO NAME (Because of Error raised in matcher)"
    #     end
    #     runner.run
    #   end
    # 
    #   it "should report generated description when told to and it is available" do
    #     example_definition = @example_group_class.it() {
    #       5.should == 5
    #     }
    #     runner = create_runner(example_definition)
    #     
    #     @reporter.should_receive(:example_finished) do |example_definition, error|
    #       example_definition.description.should == "should == 5"
    #     end
    #     runner.run
    #   end
    # 
    #   it "should unregister description_generated callback (lest a memory leak should build up)" do
    #     example_definition = @example_group_class.it("something")
    #     runner = create_runner(example_definition)
    # 
    #     Spec::Matchers.should_receive(:example_finished)
    #     runner.run
    #   end
    # end
  end
end
