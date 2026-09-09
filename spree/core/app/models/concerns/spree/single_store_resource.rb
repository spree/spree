module Spree
  module SingleStoreResource
    extend ActiveSupport::Concern

    included do
      belongs_to :store, class_name: 'Spree::Store'

      before_validation :ensure_store, unless: :store_id?
      validate :ensure_store_association_is_not_changed

      scope :for_store, ->(store) { where(store_id: store.id) }
    end

    protected

    def ensure_store
      self.store ||= Spree::Current.store
    end

    def ensure_store_association_is_not_changed
      if store_id_changed? && persisted?
        errors.add(:store, :store_association_can_not_be_changed, message: Spree.t('errors.messages.store_association_can_not_be_changed'))
      end
    end
  end
end
