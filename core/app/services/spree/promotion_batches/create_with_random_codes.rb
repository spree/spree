module Spree
  module PromotionBatches
    class CreateWithRandomCodes
      def initialize(create_with_codes: ::Spree::PromotionBatches::CreateWithCodes.new,
                     generate_codes: ::Spree::PromotionBatches::GenerateCodes.new)
        @create_with_codes = create_with_codes
        @generate_codes = generate_codes
      end

      def call(template_promotion:, amount:, random_characters:, prefix:, suffix:)
        codes = @generate_codes.call(
          amount: amount,
          random_characters: random_characters,
          prefix: prefix,
          suffix: suffix
        )

        @create_with_codes.call(template_promotion: template_promotion, codes: codes)
      end
    end
  end
end
