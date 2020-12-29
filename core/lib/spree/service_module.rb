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
    class IncompatibleParamsPassed < StandardError; end

    Result = Struct.new(:success, :value, :error) do
      def success?
        success
      end

      def failure?
        !success
      end
    end

    ResultError = Struct.new(:value) do
      def to_s
        return value.full_messages.join(', ') if value&.respond_to?(:full_messages)

        value.to_s
      end

      def to_h
        return value.messages if value&.respond_to?(:messages)

        {}
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
        result = super
        @_passed_input = result if result.is_a? Result
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

        begin
          @_passed_input = callable.call(@_passed_input.value)
        rescue ArgumentError => e
          if e.message.include? 'missing'
            raise IncompatibleParamsPassed, "You didn't pass #{e.message} to callable '#{callable.name}'"
          else
            raise IncompatibleParamsPassed, "You passed #{e.message} to callable '#{callable.name}'"
          end
        end
      end

      def success(value)
        Result.new(true, value, nil)
      end

      def failure(value, error = nil)
        error = value.errors if error.nil? && value.respond_to?(:errors)
        Result.new(false, value, ResultError.new(error))
      end

      def enforce_data_format
        raise WrongDataPassed, "You didn't use `success` or `failure` method to return value from method." unless @_passed_input.instance_of? Result
      end
    end
  end
end
