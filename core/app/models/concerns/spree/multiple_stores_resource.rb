module Spree
  module MultipleStoresResource
    extend ActiveSupport::Concern

    included do
      scope :for_store, ->(store) { joins(:stores).where(Store.table_name => { id: store.id }) }
    end
  end
end
