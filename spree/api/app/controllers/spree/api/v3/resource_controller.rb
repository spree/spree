module Spree
  module Api
    module V3
      class ResourceController < BaseController
        include Spree::Api::V3::ParamsNormalizer

        # Must run before +set_resource+: +scope+'s +accessible_by+ depends on
        # the post-authentication +current_ability+.
        before_action :authenticate_request!
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
        # Domain rules like "redeemed gift cards cannot be deleted" live on
        # the model via `can_be_deleted?` and apply to all callers (JWT and
        # API key). When `can_be_deleted?` returns false we render 422
        # (resource state forbids the request) rather than 403, since the
        # caller is authorized — it's the resource's state that's blocking
        # the operation. Models that prefer CanCan-gated destroy can opt in
        # via their ability (e.g. `can :destroy, Spree::Order, &:can_be_deleted?`),
        # which raises before the controller hook fires and yields 403.
        def destroy
          if @resource.respond_to?(:can_be_deleted?) && !@resource.can_be_deleted?
            message = Spree.t(:cannot_delete, scope: 'api', model: @resource.class.model_name.human)
            return render_error(
              code: ERROR_CODES[:validation_error],
              message: message,
              status: :unprocessable_content
            )
          end

          @resource.destroy!
          head :no_content
        rescue ActiveRecord::RecordNotDestroyed => e
          render_validation_error(e.record.errors.presence || e.message)
        end

        protected

        def authenticate_request!
          raise NotImplementedError, "#{self.class} must implement authenticate_request!"
        end

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
          resource = if @parent.present?
                       @parent.send(parent_association).build(permitted_params)
                     else
                       model_class.new(permitted_params)
                     end
          resource.store = current_store if resource.respond_to?(:store_id) && resource.store_id.blank?
          # very ugly code we need to still support for promotion/payment_method until we migrate them into single store in spree 6.0
          resource.store_ids = [current_store.id] if resource.respond_to?(:store_ids) && resource.store_ids.blank? && !resource.respond_to?(:store_id)
          resource.created_by = try_spree_current_user if resource.respond_to?(:created_by_id)
          resource
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
        # Also decodes Stripe-style prefixed IDs found in keys like `*_id_eq`,
        # `*_id_in`, `*_id_not_eq`, etc. so SPA filters can pass prefixed IDs.
        def ransack_params
          rp = params[:q]&.to_unsafe_h || params[:q] || {}
          rp = decode_prefixed_id_predicates(rp)
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

        def decode_prefixed_id_predicates(hash)
          return hash unless hash.is_a?(Hash)

          hash.each_with_object({}) do |(key, value), result|
            result[key] = if ransack_id_predicate?(key)
                            Array(value).map { |v| Spree::PrefixedId.prefixed_id?(v) ? Spree::PrefixedId.decode_prefixed_id(v) || v : v }.then { |arr|
                              value.is_a?(Array) ? arr : arr.first
                            }
                          elsif value.is_a?(Hash)
                            decode_prefixed_id_predicates(value)
                          else
                            value
                          end
          end
        end

        # Matches both prefixed-FK predicates (`product_id_in`, `tax_category_id_eq`)
        # and the bare-`id` predicates (`id_in`, `id_eq`) on the resource's
        # primary key. Without the bare-id branch, `q[id_in][]=prod_x` would
        # be passed to Ransack verbatim and never match any row.
        #
        # Requires a Ransack-predicate suffix (`_eq`, `_in`, ...) — bare
        # `_id`/`_ids` keys without a suffix are scope names, not predicates
        # (e.g. `with_option_value_ids` is a custom scope that handles its
        # own decoding). Decoding those would double-strip prefixes and
        # break downstream filter code.
        RANSACK_ID_PREDICATE_RE = /(?:\A|_)id(?:s)?_(?:eq|not_eq|in|not_in|lt|lteq|gt|gteq)\z/.freeze
        def ransack_id_predicate?(key)
          RANSACK_ID_PREDICATE_RE.match?(key.to_s)
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
          base_scope = base_scope.accessible_by(current_ability, ability_action_for_request) unless @parent.present?
          base_scope = base_scope.includes(scope_includes) if scope_includes.any?
          base_scope = base_scope.preload_associations_lazily
          model_class.include?(Spree::TranslatableResource) ? base_scope.i18n : base_scope
        end

        # Action names treated as reads. Override in subclasses with custom
        # read-only member/collection actions (e.g. add `analytics`, `types`)
        # so they map to the `:show` ability instead of a write.
        def read_actions
          %w[index show]
        end

        # Maps the current request to the CanCanCan action used to scope the
        # collection. Read actions (see +read_actions+) map to `:show`; every
        # other request maps by HTTP method. Exposed so controllers that
        # override +scope+ can keep the same `accessible_by` action as the
        # base implementation.
        def ability_action_for_request
          return :show if read_actions.include?(action_name)

          case request.method
          when 'GET', 'HEAD' then :show
          when 'POST' then :create
          when 'PATCH', 'PUT' then :update
          when 'DELETE' then :destroy
          else
            raise ActionController::MethodNotAllowed, request.method
          end
        end

        # The ability action a nested resource needs on its PARENT: read
        # actions (see +read_actions+) need only `:show`; every write needs
        # `:update`, since mutating a nested collection is an update to the
        # parent (not a create/destroy of it). Distinct from
        # +ability_action_for_request+, which maps POST/DELETE to
        # `:create`/`:destroy` for the resource itself.
        def parent_ability_action
          read_actions.include?(action_name) ? :show : :update
        end

        # Authorizes the parent resource for nested controllers: a role that
        # can view a parent can't mutate its nested collection. Call from
        # +set_parent+ after loading the parent.
        def authorize_parent!(parent)
          authorize!(parent_ability_action, parent)
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
          normalize_params(params.permit(permitted_attributes))
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
