require File.dirname(__FILE__) + '/../../spec_helper.rb'

module Spec
  module DSL
    describe Main do
      before(:each) do
        @main = Class.new do; include Spec::DSL::Main; end
      end

      [:describe, :context].each do |method|
        describe "##{method}" do
          it "should delegate to Spec::Example::ExampleGroupFactory.create_example_group" do
            block = lambda {}
            Spec::Example::ExampleGroupFactory.should_receive(:create_example_group).with(
              "The ExampleGroup", hash_including(:spec_path), &block
            )
            @main.__send__ method, "The ExampleGroup", &block
          end
        end
      end
      
      [:share_examples_for, :shared_examples_for].each do |method|
        describe "##{method}" do
          it "should create a shared ExampleGroup" do
            block = lambda {}
            Spec::Example::ExampleGroupFactory.should_receive(:create_shared_example_group).with(
              "shared group", hash_including(:spec_path), &block
            )
            @main.__send__ method, "shared group", &block
          end
        end
      end

      describe "#describe; with RUBY_VERSION = 1.9" do
        it "includes an enclosing module into the block's scope" do
          Spec::Ruby.stub!(:version).and_return("1.9")

          module Foo; module Bar; end; end
          
          Foo::Bar.should_receive(:included).with do |*args|
            included_by = args.last
            included_by.description.should == "this example group"
          end
          
          module Foo
            module Bar
              describe("this example group") do; end
            end
          end
        end
      end

    
      describe "#share_as" do
        def self.next_group_name
          @group_number ||= 0
          @group_number += 1
          "Group#{@group_number}"
        end
        
        def group_name
          @group_name ||= self.class.next_group_name
        end
        
        it "registers a shared ExampleGroup" do
          block = lambda {}
          Spec::Example::ExampleGroupFactory.should_receive(:create_shared_example_group).with(
            group_name, hash_including(:spec_path), &block
          )
          @main.share_as group_name, &block
        end
      
        it "creates a constant that points to a Module" do
          group = @main.share_as group_name do end
          Object.const_get(group_name).should equal(group)
        end
      
        it "complains if you pass it a not-constantizable name" do
          lambda do
            @group = @main.share_as "Non Constant" do end
          end.should raise_error(NameError, /The first argument to share_as must be a legal name for a constant/)
        end
      
      end
    end
  end
end
  