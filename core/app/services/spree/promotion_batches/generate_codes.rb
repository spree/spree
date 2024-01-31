module Spree
  module PromotionBatches
    class GenerateCodes
      GenerateFailedError = Class.new(StandardError)

      MAX_ATTEMPTS = 3

      def initialize(generate_code: ::Spree::PromotionBatches::GenerateCode.new)
        @generate_code = generate_code
      end

      def call(amount:, random_characters:, prefix:, suffix:)
        result = []

        amount.times do
          result << generate_next_code(result, random_characters, prefix, suffix)
        end

        result
      end

      private

      def generate_next_code(existing_codes, random_characters, prefix, suffix)
        attempts = 0

        while attempts < MAX_ATTEMPTS
          code = @generate_code.call(random_characters: random_characters, prefix: prefix, suffix: suffix)
          return code unless existing_codes.include?(code)
          attempts += 1
        end

        raise GenerateFailedError
      end
    end
  end
end
