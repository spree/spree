module Spec
  module Example
    class Configuration
      # Chooses what mock framework to use. Example:
      #
      #   Spec::Runner.configure do |config|
      #     config.mock_with :rspec, :mocha, :flexmock, or :rr
      #   end
      #
      # To use any other mock framework, you'll have to provide your own
      # adapter. This is simply a module that responds to the following
      # methods:
      #
      #   setup_mocks_for_rspec
      #   verify_mocks_for_rspec
      #   teardown_mocks_for_rspec.
      #
      # These are your hooks into the lifecycle of a given example. RSpec will
      # call setup_mocks_for_rspec before running anything else in each
      # Example. After executing the #after methods, RSpec will then call
      # verify_mocks_for_rspec and teardown_mocks_for_rspec (this is
      # guaranteed to run even if there are failures in
      # verify_mocks_for_rspec).
      #
      # Once you've defined this module, you can pass that to mock_with:
      #
      #   Spec::Runner.configure do |config|
      #     config.mock_with MyMockFrameworkAdapter
      #   end
      #
      def mock_with(mock_framework)
        @mock_framework = case mock_framework
        when Symbol
          mock_framework_path(mock_framework.to_s)
        else
          mock_framework
        end
      end
      
      def mock_framework # :nodoc:
        @mock_framework ||= mock_framework_path("rspec")
      end
      
      # :call-seq:
      #   include(Some::Helpers)
      #   include(Some::Helpers, More::Helpers)
      #   include(My::Helpers, :type => :key)
      #
      # Declares modules to be included in multiple example groups
      # (<tt>describe</tt> blocks). With no :type, the modules listed will be
      # included in all example groups. Use :type to restrict the inclusion to
      # a subset of example groups. The value assigned to :type should be a
      # key that maps to a class that is either a subclass of
      # Spec::Example::ExampleGroup or extends Spec::Example::ExampleGroupMethods
      # and includes Spec::Example::ExampleMethods
      #
      #   config.include(My::Pony, My::Horse, :type => :farm)
      #
      # Only example groups that have that type will get the modules included:
      #
      #   describe "Downtown", :type => :city do
      #     # Will *not* get My::Pony and My::Horse included
      #   end
      #
      #   describe "Old Mac Donald", :type => :farm do
      #     # *Will* get My::Pony and My::Horse included
      #   end
      #
      def include(*args)
        args << {} unless Hash === args.last
        modules, options = args_and_options(*args)
        required_example_group = get_type_from_options(options)
        required_example_group = required_example_group.to_sym if required_example_group
        modules.each do |mod|
          ExampleGroupFactory.get(required_example_group).send(:include, mod)
        end
      end

      # Defines global predicate matchers. Example:
      #
      #   config.predicate_matchers[:swim] = :can_swim?
      #
      # This makes it possible to say:
      #
      #   person.should swim # passes if person.can_swim? returns true
      #
      def predicate_matchers
        @predicate_matchers ||= {}
      end
      
      # Prepends a global <tt>before</tt> block to all example groups.
      # See #append_before for filtering semantics.
      def prepend_before(*args, &proc)
        scope, options = scope_and_options(*args)
        example_group = ExampleGroupFactory.get(
          get_type_from_options(options)
        )
        example_group.prepend_before(scope, &proc)
      end
      
      # Appends a global <tt>before</tt> block to all example groups.
      #
      # If you want to restrict the block to a subset of all the example
      # groups then specify this in a Hash as the last argument:
      #
      #   config.prepend_before(:all, :type => :farm)
      #
      # or
      #
      #   config.prepend_before(:type => :farm)
      #
      def append_before(*args, &proc)
        scope, options = scope_and_options(*args)
        example_group = ExampleGroupFactory.get(
          get_type_from_options(options)
        )
        example_group.append_before(scope, &proc)
      end
      alias_method :before, :append_before

      # Prepends a global <tt>after</tt> block to all example groups.
      # See #append_before for filtering semantics.
      def prepend_after(*args, &proc)
        scope, options = scope_and_options(*args)
        example_group = ExampleGroupFactory.get(
          get_type_from_options(options)
        )
        example_group.prepend_after(scope, &proc)
      end
      alias_method :after, :prepend_after
      
      # Appends a global <tt>after</tt> block to all example groups.
      # See #append_before for filtering semantics.
      def append_after(*args, &proc)
        scope, options = scope_and_options(*args)
        example_group = ExampleGroupFactory.get(
          get_type_from_options(options)
        )
        example_group.append_after(scope, &proc)
      end

    private

      def scope_and_options(*args)
        args, options = args_and_options(*args)
        scope = (args[0] || :each), options
      end

      def get_type_from_options(options)
        options[:type] || options[:behaviour_type]
      end
    
      def mock_framework_path(framework_name)
        File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "plugins", "mock_frameworks", framework_name))
      end
    end
  end
end
