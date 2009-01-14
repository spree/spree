module Spec
  module Mocks
    class Proxy
      DEFAULT_OPTIONS = {
        :null_object => false,
      }
      
      @@warn_about_expectations_on_nil = true
      
      def self.allow_message_expectations_on_nil
        @@warn_about_expectations_on_nil = false
        
        # ensure nil.rspec_verify is called even if an expectation is not set in the example
        # otherwise the allowance would effect subsequent examples
        $rspec_mocks.add(nil) unless $rspec_mocks.nil?
      end

      def initialize(target, name=nil, options={})
        @target = target
        @name = name
        @error_generator = ErrorGenerator.new target, name
        @expectation_ordering = OrderGroup.new @error_generator
        @expectations = []
        @messages_received = []
        @stubs = []
        @proxied_methods = []
        @options = options ? DEFAULT_OPTIONS.dup.merge(options) : DEFAULT_OPTIONS
      end

      def null_object?
        @options[:null_object]
      end
      
      def as_null_object
        @options[:null_object] = true
        @target
      end

      def add_message_expectation(expected_from, sym, opts={}, &block)        
        __add sym
        warn_if_nil_class sym
        if existing_stub = @stubs.detect {|s| s.sym == sym }
          expectation = existing_stub.build_child(expected_from, block_given?? block : nil, 1, opts)
        else
          expectation = MessageExpectation.new(@error_generator, @expectation_ordering, expected_from, sym, block_given? ? block : nil, 1, opts)
        end
        @expectations << expectation
        @expectations.last
      end

      def add_negative_message_expectation(expected_from, sym, &block)
        __add sym
        warn_if_nil_class sym
        @expectations << NegativeMessageExpectation.new(@error_generator, @expectation_ordering, expected_from, sym, block_given? ? block : nil)
        @expectations.last
      end

      def add_stub(expected_from, sym, opts={})
        __add sym
        @stubs.unshift MessageExpectation.new(@error_generator, @expectation_ordering, expected_from, sym, nil, :any, opts)
        @stubs.first
      end
      
      def verify #:nodoc:
        verify_expectations
      ensure
        reset
      end

      def reset
        clear_expectations
        clear_stubs
        reset_proxied_methods
        clear_proxied_methods
        reset_nil_expectations_warning
      end

      def received_message?(sym, *args, &block)
        @messages_received.any? {|array| array == [sym, args, block]}
      end

      def has_negative_expectation?(sym)
        @expectations.detect {|expectation| expectation.negative_expectation_for?(sym)}
      end

      def message_received(sym, *args, &block)
        expectation = find_matching_expectation(sym, *args)
        stub = find_matching_method_stub(sym, *args)

        if (stub && expectation && expectation.called_max_times?) || (stub && !expectation)
          if expectation = find_almost_matching_expectation(sym, *args)
            expectation.advise(args, block) unless expectation.expected_messages_received?
          end
          stub.invoke([], block)
        elsif expectation
          expectation.invoke(args, block)
        elsif expectation = find_almost_matching_expectation(sym, *args)
          expectation.advise(args, block) if null_object? unless expectation.expected_messages_received?
          raise_unexpected_message_args_error(expectation, *args) unless (has_negative_expectation?(sym) or null_object?)
        else
          @target.__send__ :method_missing, sym, *args, &block
        end
      end

      def raise_unexpected_message_args_error(expectation, *args)
        @error_generator.raise_unexpected_message_args_error expectation, *args
      end

      def raise_unexpected_message_error(sym, *args)
        @error_generator.raise_unexpected_message_error sym, *args
      end
      
    private

      def __add(sym)
        $rspec_mocks.add(@target) unless $rspec_mocks.nil?
        define_expected_method(sym)
      end
      
      def warn_if_nil_class(sym)
        if proxy_for_nil_class? && @@warn_about_expectations_on_nil          
          Kernel.warn("An expectation of :#{sym} was set on nil. Called from #{caller[2]}. Use allow_message_expectations_on_nil to disable warnings.")
        end
      end
      
      def define_expected_method(sym)
        visibility_string = "#{visibility(sym)} :#{sym}"
        unless @proxied_methods.include?(sym)
          if target_responds_to?(sym)
            munged_sym = munge(sym)
            target_metaclass.instance_eval do
              alias_method munged_sym, sym if method_defined?(sym.to_s)
            end
            @proxied_methods << sym
          end
        end

        target_metaclass.class_eval(<<-EOF, __FILE__, __LINE__)
          def #{sym}(*args, &block)
            __mock_proxy.message_received :#{sym}, *args, &block
          end
          #{visibility_string}
        EOF
      end

      def target_responds_to?(sym)
        return @target.__send__(munge(:respond_to?),sym) if @already_proxied_respond_to
        return @already_proxied_respond_to = true if sym == :respond_to?
        return @target.respond_to?(sym, true)
      end

      def visibility(sym)
        if Mock === @target
          'public'
        elsif target_metaclass.private_method_defined?(sym)
          'private'
        elsif target_metaclass.protected_method_defined?(sym)
          'protected'
        else
          'public'
        end
      end

      def munge(sym)
        "proxied_by_rspec__#{sym.to_s}".to_sym
      end

      def clear_expectations
        @expectations.clear
      end

      def clear_stubs
        @stubs.clear
      end

      def clear_proxied_methods
        @proxied_methods.clear
      end

      def target_metaclass
        class << @target; self; end
      end

      def verify_expectations
        @expectations.each do |expectation|
          expectation.verify_messages_received
        end
      end

      def reset_proxied_methods
        @proxied_methods.each do |sym|
          munged_sym = munge(sym)
          target_metaclass.instance_eval do
            if method_defined?(munged_sym.to_s)
              alias_method sym, munged_sym
              undef_method munged_sym
            else
              remove_method sym
            end
          end
        end
      end
      
      def proxy_for_nil_class?
        @target.nil?
      end
      
      def reset_nil_expectations_warning
        @@warn_about_expectations_on_nil = true if proxy_for_nil_class?
      end

      def find_matching_expectation(sym, *args)
        @expectations.find {|expectation| expectation.matches(sym, args)}
      end

      def find_almost_matching_expectation(sym, *args)
        @expectations.find {|expectation| expectation.matches_name_but_not_args(sym, args)}
      end

      def find_matching_method_stub(sym, *args)
        @stubs.find {|stub| stub.matches(sym, args)}
      end

    end
  end
end
