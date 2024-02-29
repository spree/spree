module Spree
  module PromotionBatches
    class GenerateCode
      def initialize(random: SecureRandom)
        @random = random
      end

      def call(random_characters:, prefix: nil, suffix: nil)
        bytes_to_generate = random_characters - random_characters.div(2)
        [
          prefix,
          @random.hex(bytes_to_generate)[...random_characters].upcase,
          suffix
        ].join('')
      end
    end
  end
end
