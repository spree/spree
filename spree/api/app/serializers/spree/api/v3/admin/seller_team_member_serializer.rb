module Spree
  module Api
    module V3
      module Admin
        # A person who runs one of the marketplace's sellers.
        #
        # Deliberately not `AdminUserSerializer`: its `roles` attribute keeps
        # only the roles held on the current *store*, and a seller's team hold
        # theirs on the seller — so every member would read as having none. The
        # role is not worth reporting anyway, since a seller's team all hold
        # the one seeded role that carries the whole seller vocabulary.
        class SellerTeamMemberSerializer < V3::BaseSerializer
          typelize email: :string,
                   first_name: [:string, nullable: true],
                   last_name: [:string, nullable: true],
                   full_name: [:string, nullable: true],
                   avatar_url: [:string, nullable: true]

          attributes :email, :first_name, :last_name, :full_name,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :avatar_url do |user|
            image_url_for(user.avatar)
          end
        end
      end
    end
  end
end
