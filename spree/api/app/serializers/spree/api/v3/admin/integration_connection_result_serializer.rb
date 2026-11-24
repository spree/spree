module Spree
  module Api
    module V3
      module Admin
        # The outcome of a live connection check on an integration.
        class IntegrationConnectionResultSerializer
          include Alba::Resource
          include Typelizer::DSL

          typelize connected: :boolean,
                   error_message: [:string, nullable: true, comment: 'What the provider answered when the connection failed']

          attributes :connected, :error_message
        end
      end
    end
  end
end
