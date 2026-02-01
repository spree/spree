module Spree
  module Api
    module V3
      class ResourceController < BaseController
        before_action :set_parent
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
          @resource = build_resource
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

        # Override in subclass to set parent resource (e.g., @wishlist, @order)
        # This runs before set_resource, allowing scope to use the parent
        def set_parent
          # No-op by default, override in nested resource controllers
        end

        # Sets the resource for show, update, destroy actions
        # Always uses scope to respect controller's custom scoping
        def set_resource
          @resource = find_resource
          authorize_resource!(@resource)
        end

        # Builds a new resource, using parent association when @parent is set
        def build_resource
          if @parent.present?
            @parent.send(parent_association).build(permitted_params)
          else
            model_class.new(permitted_params)
          end
        end

        # Finds a single resource within scope using prefixed ID
        def find_resource
          scope.find_by_prefix_id!(params[:id])
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
          result = @search.result(distinct: collection_distinct?)
          result = apply_collection_sort(result)
          @pagy, @collection = pagy(result, limit: limit, page: page)
          @collection
        end

        # Override in subclass to disable distinct (e.g., for custom sorting with computed columns)
        def collection_distinct?
          true
        end

        # Override in subclass to apply custom sorting
        def apply_collection_sort(collection)
          collection
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
        # When @parent is set (nested resources), uses parent association instead
        def scope
          base_scope = if @parent.present?
                         @parent.send(parent_association)
                       else
                         model_class.for_store(current_store)
                       end
          base_scope = base_scope.accessible_by(current_ability, :show) unless @parent.present?
          base_scope = base_scope.includes(scope_includes) if scope_includes.any?
          base_scope = base_scope.preload_associations_lazily
          model_class.include?(Spree::TranslatableResource) ? base_scope.i18n : base_scope
        end

        # Override to specify the association name on @parent
        # Defaults to controller_name (e.g., 'wished_items' for WishlistItemsController)
        def parent_association
          controller_name
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
