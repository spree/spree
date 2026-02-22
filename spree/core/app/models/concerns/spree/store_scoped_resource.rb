module Spree
  module StoreScopedResource
    extend ActiveSupport::Concern

    included do
      scope :for_store, ->(store) { joins(:stores).where(Store.table_name => { id: store.id }) }

      before_validation :set_default_store, if: :new_record?
    end

    protected

    def set_default_store
      return if disable_store_presence_validation?
      return if stores.any?

      stores << Spree::Store.default
    end

    def disable_store_presence_validation?
      Spree::Config[:disable_store_presence_validation]
    end
  end
end
