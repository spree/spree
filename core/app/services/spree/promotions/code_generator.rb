module Spree
  module Promotions
    class CodeGenerator
      MutuallyExclusiveInputsError = Class.new(StandardError)
      RetriesDepleted = Class.new(StandardError)

      def initialize(content: nil, affix: nil, deny_list: [], random_part_bytes: 4)
        @content = content
        @affix = affix
        @deny_list = deny_list
        @random_part_bytes = random_part_bytes
      end

      def build
        validate_inputs unless deny_list.empty?
        success = false
        result = 100.times do
          candidate = compose
          if valid?(candidate)
            success = true
            break candidate
          end
        end
        success ? result : raise(RetriesDepleted)
      end

      private

      attr_reader :content, :affix, :deny_list, :random_part_bytes

      def validate_inputs
        raise_error if inputs_invalid?
      end

      def valid?(subject)
        return true if deny_list.empty?

        violation_checks = deny_list.map do |el|
          subject.include?(el)
        end

        violation_checks.none?
      end

      def compose
        case affix
        when :prefix
          prefix_alorithm
        when :suffix
          suffix_alorithm
        else
          default_algorithm
        end
      end

      def prefix_alorithm
        content + random_code
      end

      def suffix_alorithm
        random_code + content
      end

      def default_algorithm
        random_code
      end

      def random_code
        SecureRandom.hex(random_part_bytes)
      end

      def raise_error
        raise MutuallyExclusiveInputsError, Spree.t(:mutually_exclusive_inputs)
      end

      def inputs_invalid?
        deny_list.include?(content)
      end
    end
  end
end
