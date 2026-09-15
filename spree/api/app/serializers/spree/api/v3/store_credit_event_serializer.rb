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

        attribute :display_action do |event|
          event.display_action
        end

        attribute :amount do |event|
          event.amount.to_s
        end

        attribute :display_amount do |event|
          event.display_amount.to_s
        end

        attributes created_at: :iso8601
      end
    end
  end
end
