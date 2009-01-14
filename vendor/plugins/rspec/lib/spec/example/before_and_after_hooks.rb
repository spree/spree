module Spec
  module Example
    module BeforeAndAfterHooks
      class << self
        def before_suite_parts
          @before_suite_parts ||= []
        end
        
        def after_suite_parts
          @after_suite_parts ||= []
        end
      end
      
      # Registers a block to be executed before each example.
      # This method prepends +block+ to existing before blocks.
      def prepend_before(*args, &block)
        before_parts(*args).unshift(block)
      end

      # Registers a block to be executed before each example.
      # This method appends +block+ to existing before blocks.
      def append_before(*args, &block)
        before_parts(*args) << block
      end
      alias_method :before, :append_before

      # Registers a block to be executed after each example.
      # This method prepends +block+ to existing after blocks.
      def prepend_after(*args, &block)
        after_parts(*args).unshift(block)
      end
      alias_method :after, :prepend_after

      # Registers a block to be executed after each example.
      # This method appends +block+ to existing after blocks.
      def append_after(*args, &block)
        after_parts(*args) << block
      end

      # TODO - deprecate this unless there is a reason why it exists
      def remove_after(scope, &block) # :nodoc:
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
      
      def before_suite_parts
        BeforeAndAfterHooks.before_suite_parts
      end
      
      def after_suite_parts
        BeforeAndAfterHooks.after_suite_parts
      end
      
    private  
      
      def before_parts(*args)
        case Spec::Example.scope_from(*args)
        when :each; before_each_parts
        when :all; before_all_parts
        when :suite; before_suite_parts
        end
      end

      def after_parts(*args)
        case Spec::Example.scope_from(*args)
        when :each; after_each_parts
        when :all; after_all_parts
        when :suite; after_suite_parts
        end
      end

    end
  end
end