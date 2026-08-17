module Spree
  module Api
    module V3
      module Seller
        # A teammate, as their colleagues on the same seller see them.
        #
        # Deliberately not the operator's `AdminUserSerializer`. That one
        # renders every store the user holds a role on, so the marketplace's
        # own store switcher can offer them — rendered to a seller it would
        # disclose the name and code of unrelated stores their teammate happens
        # to work for. It also scopes `roles` to the current *store*, which
        # answers a question nobody asked here: what matters is the teammate's
        # standing on this seller.
        class TeamMemberSerializer < V3::BaseSerializer
          typelize email: :string,
                   first_name: [:string, nullable: true],
                   last_name: [:string, nullable: true],
                   full_name: [:string, nullable: true],
                   avatar_url: [:string, nullable: true]

          attributes :email, :first_name, :last_name, :full_name,
                     created_at: :iso8601

          attribute :avatar_url do |user|
            image_url_for(user.avatar)
          end
        end
      end
    end
  end
end
