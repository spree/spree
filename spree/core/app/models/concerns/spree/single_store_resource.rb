module Spree
  module SingleStoreResource
    extend ActiveSupport::Concern

    included do
      validate :ensure_store_association_is_not_changed

      scope :for_store, ->(store) { where(store_id: store.id) }
    end

    class_methods do
      # Opt-in: assign the current (or default) store on create when none is
      # set. Used by resources migrating off multi-store (Promotion,
      # PaymentMethod) to preserve the historic auto-assignment during the
      # nullable-FK transition. Scoped to +:create+ so it never fights
      # +ensure_store_association_is_not_changed+. Most single-store models
      # require an explicit owner and should not call this.
      def assign_default_store_on_create
        before_validation :assign_default_store, on: :create, if: -> { store.nil? }
      end
    end

    protected

    def assign_default_store
      return if Spree::Config[:disable_store_presence_validation]

      self.store ||= Spree::Current.store || Spree::Store.default
    end

    def ensure_store_association_is_not_changed
      if store_id_changed? && persisted?
        errors.add(:store, Spree.t('errors.messages.store_association_can_not_be_changed'))
      end
    end
  end
end
