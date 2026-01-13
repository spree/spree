module Spree
  class Current < ::ActiveSupport::CurrentAttributes
    attribute :store, :currency, :zone

    def store
      super || Spree::Store.default
    end

    def currency
      super || store&.default_currency
    end

    def zone
      super || Spree::Zone.default_tax || store&.checkout_zone
    end
  end
end
