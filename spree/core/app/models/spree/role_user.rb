module Spree
  class RoleUser < Spree.base_class
    include Spree::SingleStoreResource

    #
    # Associations
    #
    belongs_to :role, class_name: 'Spree::Role', foreign_key: :role_id
    belongs_to :user, polymorphic: true
    belongs_to :resource, polymorphic: true
    belongs_to :invitation, class_name: 'Spree::Invitation', optional: true, inverse_of: :role_user

    #
    # Validations
    #
    validates :role, presence: true
    validates :user, presence: true
    validates :resource, presence: true
    validates :role_id, uniqueness: { scope: [:user_id, :resource_id, :user_type, :resource_type] }

    #
    # Delegations
    #
    delegate :name, to: :user

    #
    # Callbacks
    #
    before_validation :set_default_resource

    private

    # Set the default resource to the assignment's store (falling back to the
    # default store) if the resource is not set — this allows a graceful
    # migration from the old roles system to the new one.
    def set_default_resource
      self.resource ||= store || Spree::Store.current
    end

    # Overrides the SingleStoreResource fallback: the store binding follows
    # the resource — a store-resourced assignment applies on that store, a
    # vendor-resourced one on the vendor's store. Without this, a console or
    # seed assignment for another store would silently bind to
    # Spree::Current.store. An explicitly assigned store still wins, and
    # resources without a store keep the Current.store fallback.
    def ensure_store
      self.store ||= resource_bound_store || Spree::Current.store
    end

    def resource_bound_store
      resource.is_a?(Spree::Store) ? resource : resource.try(:store)
    end
  end
end
