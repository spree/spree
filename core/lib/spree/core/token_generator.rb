module Spree
  module Core
    module TokenGenerator
      def generate_token(model_class = Spree::Order)
        Spree::Deprecation.warn('generate_token is deprecated and will be removed in Spree 6.0. Please use Rails secure token generator: https://api.rubyonrails.org/classes/ActiveRecord/SecureToken/ClassMethods.html')
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
