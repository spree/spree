module Spree
  module Emails
    # Staff and seller-panel users, as back-office emails address them.
    class UserSerializer < BaseSerializer
      attributes :email, :first_name, :last_name

      attribute :name do |user|
        user.try(:full_name).presence || user.try(:name).presence
      end
    end
  end
end
