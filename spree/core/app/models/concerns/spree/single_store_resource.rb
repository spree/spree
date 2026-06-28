module Spree
  module SingleStoreResource
    extend ActiveSupport::Concern

    included do
      # Single-store resources must belong to a store. The
      # +disable_store_presence_validation+ preference is the documented escape
      # hatch for data imports and the store_id backfill window.
      validates :store, presence: true, unless: -> { Spree::Config[:disable_store_presence_validation] }
      validate :ensure_store_association_is_not_changed

      scope :for_store, ->(store) { where(store_id: store.id) }
    end

    protected

    def ensure_store_association_is_not_changed
      if store_id_changed? && persisted?
        errors.add(:store, Spree.t('errors.messages.store_association_can_not_be_changed'))
      end
    end
  end
end
