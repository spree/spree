module Spree
  module Api
    module V3
      class ResourceController < ::Spree::Api::V3::BaseController
        include Spree::Api::V3::ResourceSerializer

        before_action :set_resource, only: [:show, :update, :destroy]

        # GET /api/v3/resource
        def index
          @collection = ransack_collection

          render json: {
            data: serialize_collection(@collection),
            meta: collection_meta(@collection)
          }
        end

        # GET /api/v3/resource/:id
        def show
          render json: serialize_resource(@resource)
        end

        # POST /api/v3/resource
        def create
          @resource = model_class.new(permitted_params)
          authorize_resource!(@resource, :create)

          if @resource.save
            render json: serialize_resource(@resource), status: :created
          else
            render_errors(@resource.errors)
          end
        end

        # PATCH /api/v3/resource/:id
        def update
          if @resource.update(permitted_params)
            render json: serialize_resource(@resource)
          else
            render_errors(@resource.errors)
          end
        end

        # DELETE /api/v3/resource/:id
        def destroy
          @resource.destroy
          head :no_content
        end

        protected

        # Sets the resource for show, update, destroy actions
        def set_resource
          @resource = scope.find(params[:id])
          authorize_resource!(@resource)
        end

        # Authorize resource with CanCanCan
        def authorize_resource!(resource = @resource, action = action_name.to_sym)
          authorize!(action, resource)
        end

        # Returns ransack-filtered, sorted and paginated collection
        def ransack_collection
          @search = scope.ransack(ransack_params)
          @search.result(distinct: true).page(page).per(per_page)
        end

        # Ransack query parameters
        def ransack_params
          params[:q] || {}
        end

        # Pagination parameters
        def page
          params[:page]&.to_i || 1
        end

        def per_page
          per = params[:per_page]&.to_i || 25
          [per, 100].min # Max 100 per page
        end

        # Metadata for collection responses
        def collection_meta(collection)
          {
            total_count: collection.total_count,
            total_pages: collection.total_pages,
            current_page: collection.current_page,
            per_page: per_page
          }
        end

        # Base scope with store, ability, and includes
        def scope
          base_scope = model_class.for_store(current_store)
          base_scope = base_scope.accessible_by(current_ability, :show)
          base_scope = base_scope.includes(scope_includes) if scope_includes.any?
          model_class.include?(Spree::TranslatableResource) ? base_scope.i18n : base_scope
        end

        # Override in subclass to eager load associations
        def scope_includes
          []
        end

        # Override in subclass to define the model
        def model_class
          raise NotImplementedError, 'Subclass must implement model_class'
        end

        # Override in subclass to define the serializer
        def serializer_class
          raise NotImplementedError, 'Subclass must implement serializer_class'
        end

        # Override in subclass to permit parameters
        def permitted_params
          raise NotImplementedError, 'Subclass must implement permitted_params'
        end

        # Context passed to serializers
        def serializer_context
          {
            currency: current_currency,
            store: current_store,
            user: current_user,
            locale: current_locale,
            includes: requested_includes
          }
        end
      end
    end
  end
end
