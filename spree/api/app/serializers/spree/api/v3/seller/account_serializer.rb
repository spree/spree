module Spree
  module Api
    module V3
      module Seller
        # The signed-in person's own account, as `/me` answers it.
        #
        # Extends the team member shape rather than widening it: `selected_locale`
        # is a preference its owner sets, and the team list serializes colleagues
        # with the parent — where publishing each member's chosen language would
        # tell the whole team something none of them asked to share.
        class AccountSerializer < Seller::TeamMemberSerializer
          typelize selected_locale: [:string, nullable: true]

          attributes :selected_locale
        end
      end
    end
  end
end
