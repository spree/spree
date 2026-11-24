module Spree
  module Api
    module V3
      # An invitation as its invitee reads it by token, before they have an
      # account: the names an acceptance page shows.
      class CompanyInvitationDetailsSerializer < CompanyInvitationSerializer
        typelize company_name: [:string, comment: 'The company the invitation is to'],
                 store_name: [:string, comment: 'The store the company buys from']

        attribute :company_name do |invitation|
          invitation.company.name
        end

        attribute :store_name do
          current_store.name
        end
      end
    end
  end
end
