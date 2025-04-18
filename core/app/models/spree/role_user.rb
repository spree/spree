module Spree
  class RoleUser < Spree.base_class
    #
    # Associations
    #
    belongs_to :role, class_name: 'Spree::Role'
    belongs_to :user, polymorphic: true
    belongs_to :resource, polymorphic: true
    belongs_to :invitation, class_name: 'Spree::Invitation', optional: true

    #
    # Delegations
    #
    delegate :name, to: :user

    #
    # Callbacks
    #
    before_validation :set_default_resource

    private

    # Set the default resource to the default store if the resource is not set
    # this will allow a graceful migration from the old roles system to the new one
    def set_default_resource
      self.resource ||= Spree::Store.default
    end
  end
end
