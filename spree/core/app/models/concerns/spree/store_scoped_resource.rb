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
      # records built through a store's association (`store.payment_methods.build`)
      # carry their link on the join association — `stores` can't see it until save
      join_association = self.class.reflect_on_association(:stores).through_reflection.name
      return if stores.any? || send(join_association).any?

      stores << Spree::Store.default
    end

    def disable_store_presence_validation?
      Spree::Config[:disable_store_presence_validation]
    end
  end
end
