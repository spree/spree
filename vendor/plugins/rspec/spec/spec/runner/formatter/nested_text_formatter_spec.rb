require File.dirname(__FILE__) + '/../../../spec_helper.rb'
require 'spec/runner/formatter/nested_text_formatter'

module Spec
  module Runner
    module Formatter
      describe NestedTextFormatter do
        with_sandboxed_options do
          attr_reader :io, :options, :formatter, :example_group
          before(:each) do
            @io = StringIO.new
            options.stub!(:dry_run).and_return(false)
            options.stub!(:colour).and_return(false)
            @formatter = NestedTextFormatter.new(options, io)
            @example_group = ::Spec::Example::ExampleGroup.describe("ExampleGroup") do
              specify "example" do
              end
            end
          end

          describe "where ExampleGroup has no superclasss with a description" do
            before do
              add_example_group
            end

            def add_example_group
              formatter.add_example_group(example_group)
            end

            describe "#dump_summary" do
              it "should produce standard summary without pending when pending has a 0 count" do
                formatter.dump_summary(3, 2, 1, 0)
                io.string.should == <<-OUT
ExampleGroup

Finished in 3 seconds

2 examples, 1 failure
OUT
              end

              it "should produce standard summary" do
                formatter.dump_summary(3, 2, 1, 4)
                io.string.should == <<-OUT
ExampleGroup

Finished in 3 seconds

2 examples, 1 failure, 4 pending
OUT
              end
            end

            describe "#add_example_group" do
              describe "when ExampleGroup has description_args" do
                before do
                  example_group.description_args.should_not be_nil
                end

                describe "when ExampleGroup has no parents with description args" do
                  before do
                    example_group.superclass.description_args.should be_empty
                  end

                  it "should push ExampleGroup name" do
                    io.string.should eql("ExampleGroup\n")
                  end
                end

                describe "when ExampleGroup has one parent with description args" do
                  attr_reader :child_example_group
                  def add_example_group
                    example_group.description_args.should_not be_nil
                    @child_example_group = Class.new(example_group).describe("Child ExampleGroup")
                  end

                  describe "and parent ExampleGroups have not been printed" do
                    before do
                      formatter.add_example_group(child_example_group)
                    end

                    it "should push ExampleGroup name with two spaces of indentation" do
                      io.string.should == <<-OUT
ExampleGroup
  Child ExampleGroup
OUT
                    end
                  end

                  describe "and parent ExampleGroups have been printed" do
                    before do
                      formatter.add_example_group(example_group)
                      io.string = ""
                      formatter.add_example_group(child_example_group)
                    end

                    it "should print only the indented ExampleGroup" do
                      io.string.should == <<-OUT
  Child ExampleGroup
OUT
                    end
                  end
                end

                describe "when ExampleGroup has two parents with description args" do
                  attr_reader :child_example_group, :grand_child_example_group
                  def add_example_group
                    example_group.description_args.should_not be_nil
                    @child_example_group = Class.new(example_group).describe("Child ExampleGroup")
                    @grand_child_example_group = Class.new(child_example_group).describe("GrandChild ExampleGroup")
                  end

                  describe "and parent ExampleGroups have not been printed" do
                    before do
                      formatter.add_example_group(grand_child_example_group)
                    end

                    it "should print the entire nested ExampleGroup heirarchy" do
                      io.string.should == <<-OUT
ExampleGroup
  Child ExampleGroup
    GrandChild ExampleGroup
OUT
                    end
                  end

                  describe "and parent ExampleGroups have been printed" do
                    before do
                      formatter.add_example_group(child_example_group)
                      io.string = ""
                      formatter.add_example_group(grand_child_example_group)
                    end

                    it "should print only the indented ExampleGroup" do
                      io.string.should == <<-OUT
    GrandChild ExampleGroup
OUT
                    end
                  end
                end
              end

              describe "when ExampleGroup description_args is nil" do
                attr_reader :child_example_group

                describe "and parent ExampleGroups have not been printed" do
                  def add_example_group
                    @child_example_group = Class.new(example_group)
                    child_example_group.description_args.should be_empty
                    formatter.add_example_group(child_example_group)
                  end

                  it "should render only the parent ExampleGroup" do
                    io.string.should == <<-OUT
ExampleGroup
OUT
                  end
                end

                describe "and parent ExampleGroups have been printed" do
                  def add_example_group
                    @child_example_group = Class.new(example_group)
                    child_example_group.description_args.should be_empty
                    formatter.add_example_group(example_group)
                    io.string = ""
                    formatter.add_example_group(child_example_group)
                  end

                  it "should not render anything" do
                    io.string.should == ""
                  end
                end
              end

              describe "when ExampleGroup description_args is empty" do
                def add_example_group
                  example_group.set_description
                  example_group.description_args.should be_empty
                  super
                end

                it "should not render anything" do
                  io.string.should == ""
                end
              end
            end

            describe "#example_failed" do
              describe "where ExampleGroup has no superclasss with a description" do
                describe "when having an error" do
                  it "should push failing spec name and failure number" do
                    formatter.example_failed(
                      example_group.it("spec"),
                      98,
                      ::Spec::Runner::Reporter::Failure.new("c s", RuntimeError.new)
                    )
                    io.string.should == <<-OUT
ExampleGroup
  spec (ERROR - 98)
OUT
                  end
                end

                describe "when having an expectation failure" do
                  it "should push failing spec name and failure number" do
                    formatter.example_failed(
                      example_group.it("spec"),
                      98,
                      ::Spec::Runner::Reporter::Failure.new("c s", Spec::Expectations::ExpectationNotMetError.new)
                    )
                    io.string.should == <<-OUT
ExampleGroup
  spec (FAILED - 98)
OUT
                  end
                end
              end

              describe "where ExampleGroup has two superclasses with a description" do
                attr_reader :child_example_group, :grand_child_example_group

                def add_example_group
                  @child_example_group = Class.new(example_group).describe("Child ExampleGroup")
                  @grand_child_example_group = Class.new(child_example_group).describe("GrandChild ExampleGroup")
                  formatter.add_example_group(grand_child_example_group)
                end

                describe "when having an error" do
                  it "should push failing spec name and failure number" do
                    formatter.example_failed(
                      grand_child_example_group.it("spec"),
                      98,
                      ::Spec::Runner::Reporter::Failure.new("c s", RuntimeError.new)
                    )
                    io.string.should == <<-OUT
ExampleGroup
  Child ExampleGroup
    GrandChild ExampleGroup
      spec (ERROR - 98)
OUT
                  end
                end

                describe "when having an expectation" do
                  it "should push failing spec name and failure number" do
                    formatter.example_failed(
                      grand_child_example_group.it("spec"),
                      98,
                      ::Spec::Runner::Reporter::Failure.new("c s", Spec::Expectations::ExpectationNotMetError.new)
                    )
                    io.string.should == <<-OUT
ExampleGroup
  Child ExampleGroup
    GrandChild ExampleGroup
      spec (FAILED - 98)
OUT
                  end
                end
              end
            end

            describe "#start" do
              it "should push nothing on start" do
                formatter.start(5)
                io.string.should == <<-OUT
ExampleGroup
OUT
              end
            end

            describe "#start_dump" do
              it "should push nothing on start dump" do
                formatter.start_dump
                io.string.should == <<-OUT
ExampleGroup
OUT
              end
            end

            describe "#example_passed" do
              it "should push passing spec name" do
                formatter.example_passed(example_group.it("spec"))
                io.string.should == <<-OUT
ExampleGroup
  spec
OUT
              end
            end

            describe "#example_pending" do
              it "should push pending example name and message" do
                formatter.example_pending(example_group.examples.first, 'reason', "#{__FILE__}:#{__LINE__}")
                io.string.should == <<-OUT
ExampleGroup
  example (PENDING: reason)
OUT
              end

              it "should dump pending" do
                formatter.example_pending(example_group.examples.first, 'reason', "#{__FILE__}:#{__LINE__}")
                io.rewind
                formatter.dump_pending
                io.string.should =~ /Pending\:\n\nExampleGroup example \(reason\)\n/
              end
            end

            def have_single_level_example_group_output(expected_output)
              expected = "ExampleGroup\n  #{expected_output}"
              ::Spec::Matchers::SimpleMatcher.new(expected) do |actual|
                actual == expected
              end
            end
          end
        end
      end
    end
  end
end