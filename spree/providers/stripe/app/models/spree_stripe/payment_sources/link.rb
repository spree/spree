module SpreeStripe
  module PaymentSources
    class Link < ::Spree::PaymentSource
      def actions
        %w[credit]
      end

      def self.display_name
        'Link'
      end
    end
  end
end
