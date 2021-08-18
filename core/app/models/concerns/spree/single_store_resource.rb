module Spree
  module SingleStoreResource
    extend ActiveSupport::Concern

    included do
      if has_attribute?(:store_id)
        scope :for_store, ->(store) { where(store_id: store.id) }
      end
    end
  end
end
