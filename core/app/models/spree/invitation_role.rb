module Spree
  class InvitationRole < Spree.base_class
    belongs_to :invitation, class_name: 'Spree::Invitation'
    belongs_to :role, class_name: 'Spree::Role'
  end
end
