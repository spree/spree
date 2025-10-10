module Spree
  module Core
    module TokenGenerator
      def generate_token(model_class = Spree::Order)
        loop do
          token = "#{random_token}#{unique_ending}"
          break token unless model_class.exists?(token: token)
        end
      end

      private

      def random_token
        SecureRandom.urlsafe_base64(nil, false)
      end

      def unique_ending
        (Time.now.to_f * 1000).to_i
      end
    end
  end
end
