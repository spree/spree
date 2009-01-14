module Spec
  module DSL
    module Main
      # Creates and returns a class that includes the ExampleGroupMethods
      # module. Which ExampleGroup type is created depends on the directory of the file
      # calling this method. For example, Spec::Rails will use different
      # classes for specs living in <tt>spec/models</tt>,
      # <tt>spec/helpers</tt>, <tt>spec/views</tt> and
      # <tt>spec/controllers</tt>.
      #
      # It is also possible to override autodiscovery of the example group
      # type with an options Hash as the last argument:
      #
      #   describe "name", :type => :something_special do ...
      #
      # The reason for using different behaviour classes is to have different
      # matcher methods available from within the <tt>describe</tt> block.
      #
      # See Spec::Example::ExampleGroupFactory#register for details about how to
      # register special implementations.
      #
      def describe(*args, &block)
        Spec::Example::add_spec_path_to(args)
        Spec::Example::ExampleGroupFactory.assign_scope(self, args)
        Spec::Example::ExampleGroupFactory.create_example_group(*args, &block)
      end
      alias :context :describe
      
      # Creates an example group that can be shared by other example groups
      #
      # == Examples
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
      def share_examples_for(*args, &block)
        Spec::Example::add_spec_path_to(args)
        Spec::Example::ExampleGroupFactory.create_shared_example_group(*args, &block)
      end
      alias :shared_examples_for :share_examples_for
      
      # Creates a Shared Example Group and assigns it to a constant
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
      # And, for those of you who prefer to use something more like Ruby, you
      # can just include the module directly
      #
      #  describe SmallEdition do
      #    include AllEditions
      #  
      #    it "should do small edition stuff" do
      #      ...
      #    end
      #  end
      def share_as(name, &block)
        begin
          args = [name]
          Spec::Example::add_spec_path_to(args)
          Object.const_set(name, Spec::Example::ExampleGroupFactory.create_shared_example_group(*args, &block))
        rescue NameError => e
          raise NameError.new(e.message + "\nThe first argument to share_as must be a legal name for a constant\n")
        end
      end
    end
  end
end

include Spec::DSL::Main
