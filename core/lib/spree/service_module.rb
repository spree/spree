module Spree
  module ServiceModule
    module Callable
      def call(*args)
        new.call(*args).tap do |result|
          return yield(result) if block_given?
        end
      end
    end

    class MethodNotImplemented < StandardError; end
    class WrongDataPassed < StandardError; end
    class NonCallablePassedToRun < StandardError; end
    class CallMethodNotImplemented < StandardError; end

    Result = Struct.new(:success, :value) do
      def success?
        success
      end

      def failure?
        !success
      end
    end

    module Base
      def self.prepended(base)
        class << base
          prepend Callable
        end
      end

      def call(input = nil)
        input ||= {}
        @_passed_input = Result.new(true, input)
        begin
          result = super
          @_passed_input = result if result.is_a? Result
        rescue NoMethodError
          raise CallMethodNotImplemented, 'You have to implement `call` method in your class before using it'
        end
        enforce_data_format
        @_passed_input
      end

      private

      def run(callable)
        return unless @_passed_input.success?

        if callable.instance_of? Symbol
          unless respond_to?(callable, true)
            raise MethodNotImplemented, "You didn't implement #{callable} method. Implement it before calling this class"
          end
          callable = method(callable)
        end

        unless callable.respond_to?(:call)
          raise NonCallablePassedToRun, 'You can pass only symbol with method name or instance of callable class to run method'
        end

        @_passed_input = callable.call(@_passed_input.value)
      end

      def success(value)
        Result.new(true, value)
      end

      def failure(value)
        Result.new(false, value)
      end

      def enforce_data_format
        raise WrongDataPassed, "You didn't use `success` or `failure` method to return value from method." unless @_passed_input.instance_of? Result
      end
    end
  end
end
