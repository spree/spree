module Spree
  module Api
    module V3
      module Admin
        class TagsController < BaseController
          # The required scope depends on the requested `taggable_type`, so it's
          # resolved per request rather than via a static `scoped_resource`.
          # `authorize_taggable_scope!` enforces it for API-key principals.
          skip_scope_check!

          before_action :authorize_taggable_scope!, only: :index

          MAX_RESULTS = 50

          # Maps a taggable type to the read scope an API key must hold to
          # enumerate its tag vocabulary. Types absent from this map require
          # `read_all`.
          def self.scope_for_taggable_type
            {
              'Spree::Product' => 'read_products',
              'Spree::Order' => 'read_orders',
              Spree.user_class.to_s => 'read_customers'
            }
          end

          def index
            return unless valid_taggable_type?

            scope = ActsAsTaggableOn::Tag.
                    joins(:taggings).
                    where(ActsAsTaggableOn.taggings_table => taggings_conditions).
                    distinct.
                    order(:name).
                    limit(MAX_RESULTS)

            if params[:q].present?
              # Escape LIKE wildcards in user input so a query like "foo_" matches
              # only the literal underscore, not any single character.
              escaped = params[:q].to_s.downcase.gsub(/[\\%_]/) { |c| "\\#{c}" }
              scope = scope.where('LOWER(name) LIKE ? ESCAPE ?', "%#{escaped}%", '\\')
            end

            render json: { data: scope.pluck(:name).map { |name| { name: name } } }
          end

          private

          def taggable_type
            params[:taggable_type].to_s
          end

          def valid_taggable_type?
            return true if allowed_taggable_types.include?(taggable_type)

            render_error(
              code: 'invalid_taggable_type',
              message: "taggable_type must be one of #{allowed_taggable_types.join(', ')}",
              status: :unprocessable_content
            )
            false
          end

          # Tagging filter. `Spree::Order` carries a `tenant` (store_id) column
          # via `acts_as_taggable_tenant`, so its tag vocabulary is bounded to
          # the current store; other taggables fall back to the type filter.
          def taggings_conditions
            conditions = { taggable_type: taggable_type, context: 'tags' }
            conditions[:tenant] = current_store.id.to_s if taggable_type == 'Spree::Order'
            conditions
          end

          # Per-type scope check for API-key principals: a key listing product
          # tags needs `read_products`, order tags `read_orders`, etc. JWT
          # admins are gated by store membership + CanCanCan, not scopes.
          def authorize_taggable_scope!
            return unless current_api_key
            return unless allowed_taggable_types.include?(taggable_type)

            required = self.class.scope_for_taggable_type.fetch(taggable_type, 'read_all')
            return if current_api_key.has_scope?(required)

            render_error(
              code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:access_denied],
              message: "API key lacks scope: #{required}",
              status: :forbidden,
              details: { required_scope: required }
            )
          end

          # Sourced from `Spree.taggable_types` (registered in
          # `Spree::Core::Engine`'s after_initialize block). Apps extend the
          # list in an initializer without overriding this controller:
          #   Spree.taggable_types << 'MyApp::Vendor'
          def allowed_taggable_types
            Spree.taggable_types
          end
        end
      end
    end
  end
end
