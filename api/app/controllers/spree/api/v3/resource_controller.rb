module Spree
  module Api
    module V3
      class ResourceController < BaseController
        before_action :set_resource, only: [:show, :update, :destroy]

        # GET /api/v3/resource
        def index
          @collection = collection

          # Apply HTTP caching for guests
          return unless cache_collection(@collection)

          render json: {
            data: serialize_collection(@collection),
            meta: collection_meta(@collection)
          }
        end

        # GET /api/v3/resource/:id
        def show
          # Apply HTTP caching for guests
          return unless cache_resource(@resource)

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
          @resource = if model_class.respond_to?(:friendly)
                        model_class.friendly.find(params[:id])
                      else
                        scope.find(params[:id])
                      end

          authorize_resource!(@resource)
        end

        # Authorize resource with CanCanCan
        def authorize_resource!(resource = @resource, action = action_name.to_sym)
          authorize!(action, resource)
        end

        # Returns ransack-filtered, sorted and paginated collection
        # ar_lazy_preload handles automatic association preloading
        # @return [ActiveRecord::Relation]
        def collection
          return @collection if @collection.present?

          @search = scope.includes(collection_includes).
                    preload_associations_lazily.
                    ransack(ransack_params)
          result = @search.result(distinct: true)
          @pagy, @collection = pagy(result, limit: limit, page: page)
          @collection
        end

        def collection_includes
          []
        end

        # Ransack query parameters
        def ransack_params
          params[:q] || {}
        end

        # Pagination parameters
        def page
          params[:page]&.to_i || 1
        end

        def limit
          limit_param = params[:per_page]&.to_i || params[:limit]&.to_i || 25
          [limit_param, 100].min # Max 100 per page
        end

        # Metadata for collection responses
        def collection_meta(_collection)
          return {} unless @pagy

          {
            page: @pagy.page,
            limit: @pagy.limit,
            count: @pagy.count,
            pages: @pagy.pages,
            from: @pagy.from,
            to: @pagy.to,
            in: @pagy.in,
            previous: @pagy.previous,
            next: @pagy.next
          }
        end

        # Base scope with store and ability
        def scope
          base_scope = model_class.for_store(current_store)
          base_scope = base_scope.accessible_by(current_ability, :show)
          base_scope = base_scope.includes(scope_includes) if scope_includes.any?
          model_class.include?(Spree::TranslatableResource) ? base_scope.i18n : base_scope
        end

        # Override in subclass to eager load associations that don't work well
        # with ar_lazy_preload (e.g., prices, stock_items)
        def scope_includes
          []
        end

        # Override in subclass to define the model
        def model_class
          raise NotImplementedError, 'Subclass must implement model_class'
        end

        # Override in subclass to define the serializer class
        def serializer_class
          raise NotImplementedError, 'Subclass must implement serializer_class'
        end

        # Override in subclass to permit parameters
        def permitted_params
          raise NotImplementedError, 'Subclass must implement permitted_params'
        end
      end
    end
  end
end
