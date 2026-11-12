module Spree
  module Api
    module V3
      module Admin
        # A reason staff pick from: claim, refund, return and order
        # cancellation reasons all take the same body.
        class ReasonRequestSchema < Spree::Api::V3::RequestSchema
          attribute :name, :string, required: true, on: :create
          attribute :active, :boolean, description: 'Whether the reason is offered on new records.'
        end
      end
    end
  end
end
