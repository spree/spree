module Spree
  module Api
    module V3
      class StoreCreditEventSerializer < BaseSerializer
        typelize action: :string,
                 display_action: [:string, nullable: true],
                 amount: :string,
                 display_amount: :string,
                 authorization_code: [:string, nullable: true]

        attributes :action, :authorization_code

        attributes :display_action

        string_attributes :amount, :display_amount

        attributes created_at: :iso8601
      end
    end
  end
end
