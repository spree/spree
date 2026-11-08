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
              Spree.customer_class.to_s => 'read_customers'
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

          # The class name taggings store for the requested shorthand
          # (`product` → `Spree::Product`), or nil when it is not taggable.
          def taggable_type
            @taggable_type ||= Spree::Base.polymorphic_type_for(params[:taggable_type], allowed_taggable_types)
          end

          def valid_taggable_type?
            return true if taggable_type

            allowed = allowed_taggable_types.map { |type| Spree::Base.polymorphic_api_type(type) }
            render_error(
              code: 'invalid_taggable_type',
              message: "taggable_type must be one of #{allowed.join(', ')}",
              status: :unprocessable_content
            )
            false
          end

          # Tagging filter. A taggable declaring `acts_as_taggable_tenant :store_id`
          # stores the owning store on each tagging, so its vocabulary is bounded
          # to the current store with a single indexed `tenant` filter. Taggables
          # without a store tenant are not store-scoped here.
          def taggings_conditions
            conditions = { taggable_type: taggable_type, context: 'tags' }
            conditions[:tenant] = current_store.id.to_s if store_tenanted_taggable?
            conditions
          end

          def store_tenanted_taggable?
            taggable_class.try(:tenant_column).to_s == 'store_id'
          end

          # `taggable_type` is already matched against `Spree.taggable_types`,
          # so only a registered class name is ever constantized.
          def taggable_class
            taggable_type.constantize
          end

          # Per-type scope check for API-key principals: a key listing product
          # tags needs `read_products`, order tags `read_orders`, etc.
          #
          # Asked of the credential, not of its kind: an OAuth grant carries
          # no API key, so a check that began `return unless current_api_key`
          # skipped itself entirely and handed an agent every order and
          # customer tag the approver could see.
          def authorize_taggable_scope!
            return unless taggable_type

            required = self.class.scope_for_taggable_type.fetch(taggable_type, 'read_all')
            return if holds_permission?(required)

            render_error(
              code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:access_denied],
              message: "Missing permission: #{required}",
              status: :forbidden,
              details: { required_scope: required }
            )
          end

          # Sourced from `Spree.taggable_types` (registered in
          # `Spree::Core::Engine`'s after_initialize block). Apps extend the
          # list in an initializer without overriding this controller:
          #   Spree.taggable_types << 'MyApp::Seller'
          def allowed_taggable_types
            Spree.taggable_types.map(&:to_s)
          end
        end
      end
    end
  end
end
