module Spree
  module Api
    module V3
      module Admin
        # Whether this store can chat at all, and with what.
        #
        # The dashboard calls this before rendering the panel: no connected
        # vendor means no panel, rather than a chat box that fails on the first
        # question.
        class AssistantController < Spree::Api::V3::Admin::Assistant::BaseController
          # GET /api/v3/admin/assistant
          def show
            resolver = Spree::Assistant::ResolveProvider.new(store: current_store)
            provider = resolver.provider_class

            render json: {
              data: {
                available: resolver.available? && can_use_assistant?,
                provider: provider&.provider_key&.to_s,
                provider_name: provider&.display_name,
                model: resolver.call&.dig(:model),
                providers: Spree.assistant_providers.map { |klass| klass.to_api_hash(current_store) }
              }
            }
          end

          private

          # Availability is per admin, not just per store: an admin without the
          # assistant permission gets no panel even on a connected store.
          def can_use_assistant?
            assistant_context.permitted?('read_assistant')
          end
        end
      end
    end
  end
end
