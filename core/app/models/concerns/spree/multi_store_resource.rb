module Spree
  module MultiStoreResource
    extend ActiveSupport::Concern

    included do
      scope :for_store, ->(store) do
        store ||= Store.default
        joins(:stores).where(Store.table_name => { id: store.id })
      end

      validate :must_have_one_store, unless: :disable_store_presence_validation?
    end

    protected

    def must_have_one_store
      return if stores.any?

      errors.add(:stores, Spree.t(:must_have_one_store))
    end

    # this can be overriden on model basis
    def disable_store_presence_validation?
      Spree::Config[:disable_store_presence_validation]
    end
  end
end
