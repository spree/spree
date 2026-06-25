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

          # GET /api/v3/admin/translatable_resources
          def index
            render json: { data: Spree::Translations::Matrix.registry }
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
