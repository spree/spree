module Spree
  class Current < ::ActiveSupport::CurrentAttributes
    attribute :store

    def store
      super || Spree::Store.default
    end
  end
end
