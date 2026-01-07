module Spree
  class Current < ::ActiveSupport::CurrentAttributes
    attribute :store, :currency

    def store
      super || Spree::Store.default
    end

    def currency
      super || store&.default_currency
    end
  end
end
