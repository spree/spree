module Spec
  module Extensions
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
      # See Spec::Example::ExampleFactory#register for details about how to
      # register special implementations.
      #
      def describe(*args, &block)
        raise ArgumentError if args.empty?
        raise ArgumentError unless block
        args << {} unless Hash === args.last
        args.last[:spec_path] = caller(0)[1]
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
      def share_examples_for(name, &block)
        describe(name, :shared => true, &block)
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
          Object.const_set(name, share_examples_for(name, &block))
        rescue NameError => e
          raise NameError.new(e.message + "\nThe first argument to share_as must be a legal name for a constant\n")
        end
      end

    private
    
      def rspec_options
        $rspec_options ||= begin; \
          parser = ::Spec::Runner::OptionParser.new(STDERR, STDOUT); \
          parser.order!(ARGV); \
          $rspec_options = parser.options; \
        end
        $rspec_options
      end
      
      def init_rspec_options(options)
        $rspec_options = options if $rspec_options.nil?
      end
    end
  end
end

include Spec::Extensions::Main