module Spree
  module Api
    module V3
      module Admin
        # The acceptance link of one staff invitation, served on its own so the
        # token never travels with the invitation listing.
        class InvitationAcceptanceLinkSerializer < V3::BaseSerializer
          typelize acceptance_url: :string

          attributes :acceptance_url
        end
      end
    end
  end
end
