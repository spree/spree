module Spree
  module Api
    module V3
      module Admin
        # Self-describing discovery of every translatable resource and its
        # translatable fields (the Spree.translatable_resources registry made
        # public). Lets the dashboard render translation editors and the
        # centralized translations grid generically, with no per-model code.
        class TranslatableResourcesController < Admin::BaseController
          scoped_resource :settings

          # Public resource types with a dedicated nested read route
          # (`…/:id/translations`). Other registered types are writable via the
          # batch endpoint and readable inline (e.g. option values are returned
          # as children of an option type), so the dashboard must not GET a
          # standalone matrix for them. Keep in sync with the `:translatable`
          # route concern mounts in `spree/api/config/routes.rb`.
          READABLE_RESOURCE_TYPES = %w[product category option_type].freeze

          # GET /api/v3/admin/translatable_resources
          def index
            data = Spree::Translations.registry.map do |entry|
              entry.merge('readable' => READABLE_RESOURCE_TYPES.include?(entry['resource_type']))
            end

            render json: { data: data }
          end

          private

          def action_kind
            'read'
          end
        end
      end
    end
  end
end
