module Spree
  module Api
    module V3
      module Admin
        # A signed-in session of a staff account ({Spree::RefreshToken}),
        # without its token.
        class SessionSerializer < V3::BaseSerializer
          typelize ip_address: [:string, nullable: true],
                   user_agent: [:string, nullable: true],
                   last_active_at: :string

          attributes :ip_address, :user_agent, last_active_at: :iso8601
        end
      end
    end
  end
end
