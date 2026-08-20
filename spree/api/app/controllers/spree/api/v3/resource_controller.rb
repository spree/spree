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
        #
        # A controller whose resource is written through a workflow declares it
        # with `create_workflow` and gets this action unchanged — same
        # authorization, same rendering. Without one the record saves directly.
        def create
          @resource = build_resource
          authorize_resource!(@resource, :create)

          return save_and_render(@resource, status: :created) if create_workflow.nil?

          result = create_workflow.call(**create_workflow_arguments)

          if result.success?
            @resource = result.value
            render json: serialize_resource(@resource), status: :created
          else
            render_result_error(result)
          end
        end

        # PATCH /api/v3/resource/:id
        def update
          if update_workflow.nil?
            @resource.assign_attributes(permitted_params)
            return save_and_render(@resource)
          end

          result = update_workflow.call(**update_workflow_arguments)

          if result.success?
            @resource = result.value
            render json: serialize_resource(@resource)
          else
            render_result_error(result)
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
        # The workflow that writes this resource, or nil to save the record
        # directly. Declaring one is all a controller needs to do — `create`
        # and `update` keep their authorization and rendering.
        #
        # @return [#call, nil]
        def create_workflow
          nil
        end

        # @return [#call, nil]
        def update_workflow
          nil
        end

        # Keywords passed to `create_workflow`. The default suits a workflow
        # taking `store:` and `attributes:`; override for anything else.
        #
        # @return [Hash]
        def create_workflow_arguments
          { store: current_store, attributes: permitted_params }
        end

        # Keywords passed to `update_workflow`, keyed by the resource's own
        # name — `product:`, `price_list:` — which is how the workflows in
        # app/workflows name their subject. `element` rather than `singular`,
        # which would carry the `spree_` prefix.
        #
        # @return [Hash]
        def update_workflow_arguments
          { model_class.model_name.element.to_sym => @resource, attributes: permitted_params }
        end

        def save_and_render(resource, status: :ok)
          if resource.save
            render json: serialize_resource(resource), status: status
          else
            render_errors(resource.errors)
          end
        end

        # Builds the record a create writes, through its owner's association so
        # tenancy comes from where the record was built rather than from an
        # attribute assigned afterwards.
        #
        # A workflow-written resource gets the bare scoped record: the workflow
        # assigns the payload itself, and assigning it here would only be for
        # the authorization check — which reads the record's owner, not its
        # attributes — while raising on any bulk payload the model has no
        # setter for (`product_ids`, `variants`).
        def build_resource
          resource = resource_scope.new
          resource.assign_attributes(permitted_params) if create_workflow.nil?
          resource.created_by = try_spree_current_user if resource.respond_to?(:created_by_id)
          resource
        end

        # The relation a new record is built on: a nested resource's parent
        # association, the store's own association for this model, or the
        # class itself for genuinely global data (countries, roles).
        #
        # @return [ActiveRecord::Relation, Class]
        def resource_scope
          return @parent.send(parent_association) if @parent.present?
          return model_class unless store_association

          current_store.public_send(store_association)
        end

        # The store association a new record of this model builds on, or nil
        # when there is none it can build through.
        #
        # Found by asking the reflections which association actually points at
        # this model rather than by inflecting its name, so a model whose
        # association is not the plural of its own name still resolves. Two
        # cases yield nil and build on the class instead, taking their tenancy
        # from the record they belong to: a doubly-nested has_many :through
        # (Store#prices, through variants through products) is readonly, and
        # genuinely global data (countries, roles) has no store association.
        #
        # @return [Symbol, nil]
        def store_association
          reflections = current_store.class.reflect_on_all_associations(:has_many).select do |reflection|
            !reflection.nested? && reflection.klass == model_class
          rescue NameError
            # A reflection naming a class this installation does not load.
            false
          end
          return reflections.first&.name if reflections.one?

          # More than one association reaches this model — a deprecated twin
          # such as `shipments` beside `fulfillments` — so the conventional
          # name decides which one a create belongs on.
          conventional = model_class.model_name.element.pluralize.to_sym
          reflections.find { |reflection| reflection.name == conventional }&.name
        end

        # Finds a single resource within scope using prefixed ID
        def find_resource
          scope.find_by_prefix_id!(params[:id])
        end

        # Per-record authorization hook. A no-op in the shared base: the Store
        # API's resources are reachable only through owner-scoped queries, so
        # loading one already proves the caller may act on it. The Admin API
        # overrides this with a CanCanCan check.
        def authorize_resource!(resource = @resource, action = action_name.to_sym); end

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

        # Base scope, store-scoped (or parent-scoped for nested resources).
        # Deliberately free of CanCanCan: the Store API authorizes by ownership
        # — every account controller scopes through `current_user` — while the
        # Admin API layers `accessible_by` on top in its own subclass.
        def scope
          base_scope = if @parent.present?
                         @parent.send(parent_association)
                       else
                         model_class.for_store(current_store)
                       end
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

        # Parent authorization hook for nested controllers. A no-op in the
        # shared base for the same reason as +authorize_resource!+; the Admin
        # API overrides it so a role that can only view a parent cannot mutate
        # its nested collection.
        def authorize_parent!(parent); end

        # Override to specify the association name on @parent
        # Defaults to controller_name (e.g., 'wished_items' for WishlistItemsController)
        def parent_association
          controller_name
        end

        # Override in subclass to eager load associations that don't work well
        # with ar_lazy_preload (e.g., prices, stock_levels)
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

        def permitted_params
          normalize_params(params.permit(*permitted_attributes))
        end

        # This resource's writable attributes, plus anything extensions have
        # declared on the model. Override +resource_permitted_attributes+ rather
        # than this, so the extension union is not lost.
        def permitted_attributes
          resource_permitted_attributes + model_additional_permitted_attributes
        end

        # Override in subclass to declare the resource's writable attributes.
        def resource_permitted_attributes
          raise NotImplementedError, 'Subclass must implement resource_permitted_attributes or permitted_params'
        end

        # Attributes extensions have declared on the model via
        # +Spree::Product.additional_permitted_attributes += [...]+.
        #
        # Guarded on both sides: a controller need not define +model_class+
        # (and one that does may raise NotImplementedError), and
        # `Spree.base_class` is host-overridable, so the class_attribute is not
        # guaranteed to be inherited from Spree::Base.
        def model_additional_permitted_attributes
          return [] unless respond_to?(:model_class, true)

          model = model_class
          return [] unless model.respond_to?(:additional_permitted_attributes)

          Array(model.additional_permitted_attributes)
        rescue NotImplementedError
          []
        end
      end
    end
  end
end
