module Spec
  module Example

    module ExampleGroupMethods
      class << self
        def description_text(*args)
          args.inject("") do |result, arg|
            result << " " unless (result == "" || arg.to_s =~ /^(\s|\.|#)/)
            result << arg.to_s
          end
        end
      end

      attr_reader :description_text, :description_args, :description_options, :spec_path, :registration_binding_block

      def inherited(klass)
        super
        klass.register {}
        Spec::Runner.register_at_exit_hook
      end
      
      # Makes the describe/it syntax available from a class. For example:
      #
      #   class StackSpec < Spec::ExampleGroup
      #     describe Stack, "with no elements"
      #
      #     before
      #       @stack = Stack.new
      #     end
      #
      #     it "should raise on pop" do
      #       lambda{ @stack.pop }.should raise_error
      #     end
      #   end
      #
      def describe(*args, &example_group_block)
        if example_group_block
          self.subclass("Subclass") do
            describe(*args)
            module_eval(&example_group_block)
          end
        else
          set_description(*args)
          before_eval
          self
        end
      end

      # Use this to pull in examples from shared example groups.
      # See Spec::Runner for information about shared example groups.
      def it_should_behave_like(shared_example_group)
        case shared_example_group
        when SharedExampleGroup
          include shared_example_group
        else
          example_group = SharedExampleGroup.find_shared_example_group(shared_example_group)
          unless example_group
            raise RuntimeError.new("Shared Example Group '#{shared_example_group}' can not be found")
          end
          include(example_group)
        end
      end

      # :call-seq:
      #   predicate_matchers[matcher_name] = method_on_object
      #   predicate_matchers[matcher_name] = [method1_on_object, method2_on_object]
      #
      # Dynamically generates a custom matcher that will match
      # a predicate on your class. RSpec provides a couple of these
      # out of the box:
      #
      #   exist (or state expectations)
      #     File.should exist("path/to/file")
      #
      #   an_instance_of (for mock argument constraints)
      #     mock.should_receive(:message).with(an_instance_of(String))
      #
      # == Examples
      #
      #   class Fish
      #     def can_swim?
      #       true
      #     end
      #   end
      #
      #   describe Fish do
      #     predicate_matchers[:swim] = :can_swim?
      #     it "should swim" do
      #       Fish.new.should swim
      #     end
      #   end
      def predicate_matchers
        @predicate_matchers ||= {:an_instance_of => :is_a?}
      end

      # Creates an instance of Spec::Example::Example and adds
      # it to a collection of examples of the current example group.
      def it(description=nil, &implementation)
        e = new(description, &implementation)
        example_objects << e
        e
      end

      alias_method :specify, :it

      # Use this to temporarily disable an example.
      def xit(description=nil, opts={}, &block)
        Kernel.warn("Example disabled: #{description}")
      end

      def run
        examples = examples_to_run
        return true if examples.empty?
        reporter.add_example_group(self)
        return dry_run(examples) if dry_run?

        plugin_mock_framework
        define_methods_from_predicate_matchers

        success, before_all_instance_variables = run_before_all
        success, after_all_instance_variables  = execute_examples(success, before_all_instance_variables, examples)
        success                                = run_after_all(success, after_all_instance_variables)
      end

      def description
        result = ExampleGroupMethods.description_text(*description_parts)
        if result.nil? || result == ""
          return to_s
        else
          result
        end
      end

      def described_type
        description_parts.find {|part| part.is_a?(Module)}
      end

      def description_parts #:nodoc:
        parts = []
        execute_in_class_hierarchy do |example_group|
          parts << example_group.description_args
        end
        parts.flatten.compact
      end

      def set_description(*args)
        args, options = args_and_options(*args)
        @description_args = args
        @description_options = options
        @description_text = ExampleGroupMethods.description_text(*args)
        @spec_path = File.expand_path(options[:spec_path]) if options[:spec_path]
        if described_type.class == Module
          include described_type
        end
        self
      end

      def examples #:nodoc:
        examples = example_objects.dup
        add_method_examples(examples)
        rspec_options.reverse ? examples.reverse : examples
      end

      def number_of_examples #:nodoc:
        examples.length
      end

      # Registers a block to be executed before each example.
      # This method prepends +block+ to existing before blocks.
      def prepend_before(*args, &block)
        scope, options = scope_and_options(*args)
        parts = before_parts_from_scope(scope)
        parts.unshift(block)
      end

      # Registers a block to be executed before each example.
      # This method appends +block+ to existing before blocks.
      def append_before(*args, &block)
        scope, options = scope_and_options(*args)
        parts = before_parts_from_scope(scope)
        parts << block
      end
      alias_method :before, :append_before

      # Registers a block to be executed after each example.
      # This method prepends +block+ to existing after blocks.
      def prepend_after(*args, &block)
        scope, options = scope_and_options(*args)
        parts = after_parts_from_scope(scope)
        parts.unshift(block)
      end
      alias_method :after, :prepend_after

      # Registers a block to be executed after each example.
      # This method appends +block+ to existing after blocks.
      def append_after(*args, &block)
        scope, options = scope_and_options(*args)
        parts = after_parts_from_scope(scope)
        parts << block
      end

      def remove_after(scope, &block)
        after_each_parts.delete(block)
      end

      # Deprecated. Use before(:each)
      def setup(&block)
        before(:each, &block)
      end

      # Deprecated. Use after(:each)
      def teardown(&block)
        after(:each, &block)
      end

      def before_all_parts # :nodoc:
        @before_all_parts ||= []
      end

      def after_all_parts # :nodoc:
        @after_all_parts ||= []
      end

      def before_each_parts # :nodoc:
        @before_each_parts ||= []
      end

      def after_each_parts # :nodoc:
        @after_each_parts ||= []
      end

      # Only used from RSpec's own examples
      def reset # :nodoc:
        @before_all_parts = nil
        @after_all_parts = nil
        @before_each_parts = nil
        @after_each_parts = nil
      end

      def register(&registration_binding_block)
        @registration_binding_block = registration_binding_block
        rspec_options.add_example_group self
      end

      def unregister #:nodoc:
        rspec_options.remove_example_group self
      end

      def registration_backtrace
        eval("caller", registration_binding_block.binding)
      end

      def run_before_each(example)
        execute_in_class_hierarchy do |example_group|
          example.eval_each_fail_fast(example_group.before_each_parts)
        end
      end

      def run_after_each(example)
        execute_in_class_hierarchy(:superclass_first) do |example_group|
          example.eval_each_fail_slow(example_group.after_each_parts)
        end
      end

    private
      def dry_run(examples)
        examples.each do |example|
          rspec_options.reporter.example_started(example)
          rspec_options.reporter.example_finished(example)
        end
        return true
      end

      def run_before_all
        before_all = new("before(:all)")
        begin
          execute_in_class_hierarchy do |example_group|
            before_all.eval_each_fail_fast(example_group.before_all_parts)
          end
          return [true, before_all.instance_variable_hash]
        rescue Exception => e
          reporter.failure(before_all, e)
          return [false, before_all.instance_variable_hash]
        end
      end

      def execute_examples(success, instance_variables, examples)
        return [success, instance_variables] unless success

        after_all_instance_variables = instance_variables
        examples.each do |example_group_instance|
          success &= example_group_instance.execute(rspec_options, instance_variables)
          after_all_instance_variables = example_group_instance.instance_variable_hash
        end
        return [success, after_all_instance_variables]
      end

      def run_after_all(success, instance_variables)
        after_all = new("after(:all)")
        after_all.set_instance_variables_from_hash(instance_variables)
        execute_in_class_hierarchy(:superclass_first) do |example_group|
          after_all.eval_each_fail_slow(example_group.after_all_parts)
        end
        return success
      rescue Exception => e
        reporter.failure(after_all, e)
        return false
      end

      def examples_to_run
        all_examples = examples
        return all_examples unless specified_examples?
        all_examples.reject do |example|
          matcher = ExampleMatcher.new(description.to_s, example.description)
          !matcher.matches?(specified_examples)
        end
      end

      def specified_examples?
        specified_examples && !specified_examples.empty?
      end

      def specified_examples
        rspec_options.examples
      end

      def reporter
        rspec_options.reporter
      end

      def dry_run?
        rspec_options.dry_run
      end

      def example_objects
        @example_objects ||= []
      end

      def execute_in_class_hierarchy(superclass_last=false)
        classes = []
        current_class = self
        while is_example_group?(current_class)
          superclass_last ? classes << current_class : classes.unshift(current_class)
          current_class = current_class.superclass
        end
        superclass_last ? classes << ExampleMethods : classes.unshift(ExampleMethods)

        classes.each do |example_group|
          yield example_group
        end
      end

      def is_example_group?(klass)
        Module === klass && klass.kind_of?(ExampleGroupMethods)
      end

      def plugin_mock_framework
        case mock_framework = Spec::Runner.configuration.mock_framework
        when Module
          include mock_framework
        else
          require Spec::Runner.configuration.mock_framework
          include Spec::Plugins::MockFramework
        end
      end

      def define_methods_from_predicate_matchers # :nodoc:
        all_predicate_matchers = predicate_matchers.merge(
          Spec::Runner.configuration.predicate_matchers
        )
        all_predicate_matchers.each_pair do |matcher_method, method_on_object|
          define_method matcher_method do |*args|
            eval("be_#{method_on_object.to_s.gsub('?','')}(*args)")
          end
        end
      end

      def scope_and_options(*args)
        args, options = args_and_options(*args)
        scope = (args[0] || :each), options
      end

      def before_parts_from_scope(scope)
        case scope
        when :each; before_each_parts
        when :all; before_all_parts
        end
      end

      def after_parts_from_scope(scope)
        case scope
        when :each; after_each_parts
        when :all; after_all_parts
        end
      end

      def before_eval
      end

      def add_method_examples(examples)
        instance_methods.sort.each do |method_name|
          if example_method?(method_name)
            examples << new(method_name) do
              __send__(method_name)
            end
          end
        end
      end

      def example_method?(method_name)
        should_method?(method_name)
      end

      def should_method?(method_name)
        !(method_name =~ /^should(_not)?$/) &&
        method_name =~ /^should/ && (
          instance_method(method_name).arity == 0 ||
          instance_method(method_name).arity == -1
        )
      end
    end

  end
end
