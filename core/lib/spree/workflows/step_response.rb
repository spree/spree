module Spree
  module Workflows
    # Represents the result of a step execution
    class StepResponse
      attr_reader :output, :compensation_data

      # Create a new successful step response
      # @param output [Hash] the output data to pass to subsequent steps
      # @param compensation_data [Hash, nil] data to pass to compensation function on rollback
      def initialize(output, compensation_data = nil)
        @output = output.is_a?(Hash) ? output.with_indifferent_access : output
        @compensation_data = (compensation_data || output)
        @compensation_data = @compensation_data.with_indifferent_access if @compensation_data.is_a?(Hash)
      end

      def success?
        true
      end

      def failure?
        false
      end

      # Factory method for success
      # @param output [Hash] the output data
      # @param compensation_data [Hash, nil] data for compensation
      # @return [StepResponse]
      def self.success(output, compensation_data = nil)
        new(output, compensation_data)
      end

      # Factory method for failure
      # @param error [String, Exception] error message or exception
      # @param compensation_data [Hash, nil] data for compensation
      # @return [FailedStepResponse]
      def self.failure(error, compensation_data = nil)
        FailedStepResponse.new(error, compensation_data)
      end

      # Factory method for permanent failure (no retry)
      # @param error [String, Exception] error message or exception
      # @param compensation_data [Hash, nil] data for compensation
      # @return [PermanentFailureResponse]
      def self.permanent_failure(error, compensation_data = nil)
        PermanentFailureResponse.new(error, compensation_data)
      end
    end

    # Represents a failed step that may be retried
    class FailedStepResponse
      attr_reader :error, :compensation_data

      def initialize(error, compensation_data = nil)
        @error = error.is_a?(Exception) ? error.message : error.to_s
        @compensation_data = compensation_data
        @compensation_data = @compensation_data.with_indifferent_access if @compensation_data.is_a?(Hash)
      end

      def success?
        false
      end

      def failure?
        true
      end

      def output
        nil
      end
    end

    # Represents a permanent failure that should not be retried
    class PermanentFailureResponse < FailedStepResponse
      def permanent?
        true
      end
    end
  end
end
