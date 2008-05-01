require File.dirname(__FILE__) + '/../../spec_helper.rb'
unless [/mswin/, /java/].detect{|p| p =~ RUBY_PLATFORM}
  require 'spec/runner/heckle_runner'

  module Foo
    class Bar
      def one; end
      def two; end
    end

    class Zap
      def three; end
      def four; end
    end
  end

  describe "HeckleRunner" do
    before(:each) do
      @heckle = mock("heckle", :null_object => true)
      @heckle_class = mock("heckle_class")
    end

    it "should heckle all methods in all classes in a module" do
      @heckle_class.should_receive(:new).with("Foo::Bar", "one", rspec_options).and_return(@heckle)
      @heckle_class.should_receive(:new).with("Foo::Bar", "two", rspec_options).and_return(@heckle)
      @heckle_class.should_receive(:new).with("Foo::Zap", "three", rspec_options).and_return(@heckle)
      @heckle_class.should_receive(:new).with("Foo::Zap", "four", rspec_options).and_return(@heckle)

      heckle_runner = Spec::Runner::HeckleRunner.new("Foo", @heckle_class)
      heckle_runner.heckle_with
    end

    it "should heckle all methods in a class" do
      @heckle_class.should_receive(:new).with("Foo::Bar", "one", rspec_options).and_return(@heckle)
      @heckle_class.should_receive(:new).with("Foo::Bar", "two", rspec_options).and_return(@heckle)

      heckle_runner = Spec::Runner::HeckleRunner.new("Foo::Bar", @heckle_class)
      heckle_runner.heckle_with
    end

    it "should fail heckling when the class is not found" do
      lambda do
        heckle_runner = Spec::Runner::HeckleRunner.new("Foo::Bob", @heckle_class)
        heckle_runner.heckle_with
      end.should raise_error(StandardError, "Heckling failed - \"Foo::Bob\" is not a known class or module")
    end

    it "should heckle specific method in a class (with #)" do
      @heckle_class.should_receive(:new).with("Foo::Bar", "two", rspec_options).and_return(@heckle)

      heckle_runner = Spec::Runner::HeckleRunner.new("Foo::Bar#two", @heckle_class)
      heckle_runner.heckle_with
    end

    it "should heckle specific method in a class (with .)" do
      @heckle_class.should_receive(:new).with("Foo::Bar", "two", rspec_options).and_return(@heckle)

      heckle_runner = Spec::Runner::HeckleRunner.new("Foo::Bar.two", @heckle_class)
      heckle_runner.heckle_with
    end
  end
  
  describe "Heckler" do
    it "should say yes to tests_pass? if specs pass" do
      options = mock("options", :null_object => true)
      options.should_receive(:run_examples).and_return(true)
      heckler = Spec::Runner::Heckler.new("Foo", nil, options)
      heckler.tests_pass?.should be_true
    end

    it "should say no to tests_pass? if specs fail" do
      options = mock("options", :null_object => true)
      options.should_receive(:run_examples).and_return(false)
      heckler = Spec::Runner::Heckler.new("Foo", nil, options)
      heckler.tests_pass?.should be_false
    end
  end
end
