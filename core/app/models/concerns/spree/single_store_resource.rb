module Spree
  module SingleStoreResource
    extend ActiveSupport::Concern

    included do
      scope :for_store, ->(store) { where(store_id: store.id) }
    end
  end
end
