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

        # No-op HTTP caching methods. Include Spree::Api::V3::HttpCaching
        # in specific controllers to enable HTTP caching for their actions.
        def cache_collection(_collection, **_options)
          true
        end

        def cache_resource(_resource, **_options)
          true
        end

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
          pagy_options = { limit: limit, page: page }
          result = apply_collection_sort(result)
          @pagy, @collection = pagy(result, **pagy_options)
          @collection
        end

        # Override in subclass to disable distinct (e.g., for custom sorting with computed columns)
        # @return [Boolean] whether to apply distinct to the collection
        def collection_distinct?
          true
        end

        # Override in subclass to apply custom sorting
        def apply_collection_sort(collection)
          collection
        end

        # Override in subclass to specify collection includes
        # @return [Array<Symbol>] the includes to apply to the collection
        def collection_includes
          []
        end

        # Ransack query parameters with sort translation.
        # Translates `-field` notation (JSON:API standard) to Ransack `s` format.
        # e.g., sort=-price,name → s=price desc,name asc
        def ransack_params
          rp = params[:q]&.to_unsafe_h || params[:q] || {}
          sort_value = sort_param

          if sort_value.present?
            rp = rp.dup unless rp.is_a?(Hash)
            rp['s'] = sort_value.split(',').map { |field|
              if field.start_with?('-')
                "#{field[1..]} desc"
              else
                "#{field} asc"
              end
            }.join(',')
          end

          rp
        end

        # Sort parameter from the request
        def sort_param
          params[:sort]
        end

        # Pagination parameters
        # @return [Integer] the current page number
        def page
          params[:page]&.to_i || 1
        end

        # @return [Integer] the number of items per page
        def limit
          limit_param = params[:limit]&.to_i || 25
          [limit_param, 100].min # Max 100 per page
        end

        # Metadata for collection responses
        # @return [Hash] pagination metadata
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

        # Permit flat parameters based on model class
        # Automatically infers attribute list from Spree::PermittedAttributes
        # e.g., ProductsController -> Spree::PermittedAttributes.product_attributes
        #
        # Override in subclass for custom parameter handling
        def permitted_params
          params.permit(permitted_attributes)
        end

        # Returns the permitted attributes list for the model
        # Override in subclass for custom attributes
        def permitted_attributes
          Spree::PermittedAttributes.public_send(permitted_attributes_key)
        end

        # Infers the PermittedAttributes key from model class
        # e.g., Spree::Product -> :product_attributes
        def permitted_attributes_key
          :"#{model_class.model_name.element}_attributes"
        end
      end
    end
  end
end
