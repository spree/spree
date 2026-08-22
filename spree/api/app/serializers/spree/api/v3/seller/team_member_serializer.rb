module Spree
  module Api
    module V3
      module Seller
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
