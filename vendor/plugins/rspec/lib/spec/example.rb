module Spec
  # == Example Groups and Code Examples
  #
  # A Code Example is an executable example of how a bit of code is expected
  # to behave.
  #
  # An Example Group is a group of code examples.
  #
  # RSpec exposes a DSL to describe groups of examples.
  #  
  #   describe Account do
  #     it "should have a balance of $0" do
  #       account = Account.new
  #       account.balance.should == Money.new(0, :dollars)
  #     end
  #   end
  #  
  # == Before and After
  #  
  # You can use the <tt>before()</tt> and <tt>after()</tt> methods to extract
  # common code within an Example Group. Both methods take an optional scope
  # argument so you can run the block before :each example or before :all
  # examples
  #  
  #   describe "..." do
  #     before :all do
  #       ...
  #     end
  #  
  #     before :each do
  #       ...
  #     end
  #  
  #     it "should do something" do
  #       ...
  #     end
  #  
  #     it "should do something else" do
  #       ...
  #     end
  #  
  #     after :each do
  #       ...
  #     end
  #  
  #     after :all do
  #       ...
  #     end
  #  
  #   end
  #  
  # The <tt>before :each</tt> block will run before each of the examples, once
  # for each example. Likewise, the <tt>after :each</tt> block will run after
  # each of the examples.
  #  
  # It is also possible to specify a <tt>before :all</tt> and <tt>after
  # :all</tt> block that will run only once for each example group, before the
  # first <code>before :each</code> and after the last <code>after
  # :each</code> respectively. The use of these is generally discouraged,
  # because it introduces dependencies between the examples. Still, it might
  # prove useful for very expensive operations if you know what you are doing.
  #  
  # == Local helper methods
  #  
  # You can include local helper methods by simply expressing them within an
  # example group:
  #  
  #   describe "..." do
  #    
  #     it "..." do
  #       helper_method
  #     end
  #  
  #     def helper_method
  #       ...
  #     end
  #  
  #   end
  #  
  # == Included helper methods
  #  
  # You can include helper methods in multiple example groups by expressing
  # them within a module, and then including that module in your example
  # groups:
  #  
  #   module AccountExampleHelperMethods
  #     def helper_method
  #       ...
  #     end
  #   end
  #  
  #   describe "A new account" do
  #     include AccountExampleHelperMethods
  #     before do
  #       @account = Account.new
  #     end
  #  
  #     it "should have a balance of $0" do
  #       helper_method
  #       @account.balance.should eql(Money.new(0, :dollars))
  #     end
  #   end
  #  
  # == Shared Example Groups
  #  
  # You can define a shared example group, that may be used on other groups
  #
  #  share_examples_for "All Editions" do
  #    it "all editions behaviour" ...
  #  end
  #
  #  describe SmallEdition do
  #    it_should_behave_like "All Editions"
  #   
  #    it "should do small edition stuff" do
  #      ...
  #    end
  #  end
  #
  # You can also assign the shared group to a module and include that
  #
  #  share_as :AllEditions do
  #    it "should do all editions stuff" ...
  #  end
  #
  #  describe SmallEdition do
  #    it_should_behave_like AllEditions
  #   
  #    it "should do small edition stuff" do
  #      ...
  #    end
  #  end
  #
  # And, for those of you who prefer to use something more like Ruby, you can
  # just include the module directly
  #
  #  describe SmallEdition do
  #    include AllEditions
  #   
  #    it "should do small edition stuff" do
  #      ...
  #    end
  #  end
  module Example
    class << self
      def args_and_options(*args) # :nodoc:
        with_options_from(args) do |options|
          return args, options
        end
      end

      def scope_from(*args) # :nodoc:
        args[0] || :each
      end

      def scope_and_options(*args) # :nodoc:
        args, options = args_and_options(*args)
        return scope_from(*args), options
      end

      def add_spec_path_to(args) # :nodoc:
        args << {} unless Hash === args.last
        args.last[:spec_path] ||= caller(0)[2]
      end

    private
    
      def with_options_from(args)
        yield Hash === args.last ? args.pop : {} if block_given?
      end
    end
  end
end

require 'timeout'
require 'spec/example/before_and_after_hooks'
require 'spec/example/pending'
require 'spec/example/module_reopening_fix'
require 'spec/example/example_group_methods'
require 'spec/example/example_methods'
require 'spec/example/example_group'
require 'spec/example/shared_example_group'
require 'spec/example/example_group_factory'
require 'spec/example/errors'
require 'spec/example/example_matcher'

