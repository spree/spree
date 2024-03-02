module Spree
  module PromotionBatches
    class GenerateCode
      def initialize(random: SecureRandom)
        @random = random
      end

      def call(random_characters:, prefix: nil, suffix: nil)
        [
          prefix,
          @random.hex(random_characters).upcase,
          suffix
        ].join('')
      end
    end
  end
end
