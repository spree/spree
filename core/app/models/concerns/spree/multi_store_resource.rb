module Spree
  module MultiStoreResource
    extend ActiveSupport::Concern

    included do
      scope :for_store, ->(store) { joins(:stores).where(Store.table_name => { id: store.id }) }

      before_validation :set_default_store, if: :new_record?

      validate :must_have_one_store, unless: :disable_store_presence_validation?
    end

    protected

    def must_have_one_store
      return if stores.any?

      errors.add(:stores, Spree.t(:must_have_one_store))
    end

    def set_default_store
      return if disable_store_presence_validation?
      return if stores.any?

      stores << Spree::Store.default
    end

    # this can be overridden on model basis
    def disable_store_presence_validation?
      Spree::Config[:disable_store_presence_validation]
    end
  end
end
