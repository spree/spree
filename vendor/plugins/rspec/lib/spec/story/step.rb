module Spec
  module Story
    class Step
      PARAM_PATTERN = /([^\\]|^)(\$(?!\$)\w*)/
      PARAM_OR_GROUP_PATTERN = /(\$(?!\$)\w*)|\(.*?\)/
      
      attr_reader :name
      
      def initialize(name, &block)
        init_name(name)
        init_expression(name)
        block_given? ? init_module(name, &block) : set_pending
      end

      def perform(instance, *args)
        raise Spec::Example::ExamplePendingError.new("Not Yet Implemented") if pending?
        instance.extend(@mod)
        instance.__send__(sanitize(@name), *args)
      end

      def matches?(name)
        !(name.strip =~ @expression).nil?
      end
            
      def parse_args(name)
        name.strip.match(@expression)[1..-1]
      end

      private
      
      def sanitize(a_string_or_regexp)
        return a_string_or_regexp.source if Regexp == a_string_or_regexp
        a_string_or_regexp.to_s
      end

      def init_module(name, &block)
        sanitized_name = sanitize(name)
        @mod = Module.new do
          define_method(sanitized_name, &block)
        end
      end
    
      def set_pending
        @pending = true
      end
      
      def pending?
        @pending == true
      end
      
      def init_name(name)
        @name = name
      end
    
      def init_expression(string_or_regexp)
        if String === string_or_regexp
          expression = string_or_regexp.dup
          %w<? ( ) [ ] { } ^ !>.each {|c| expression.gsub! c, "\\#{c}"}
        elsif Regexp === string_or_regexp
          expression = string_or_regexp.source
        end
        while expression =~ PARAM_PATTERN
          expression.sub!($2, "(.*?)")
        end
        @expression = Regexp.new("\\A#{expression}\\Z", Regexp::MULTILINE)
      end

    end
  end
end
