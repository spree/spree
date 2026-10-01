module Spree
  module AgentTools
    # What the generic tools are allowed to look at.
    #
    # Not a hand-written list: the Admin API's controllers already declare
    # their model, serializer and permission scope, so the map is derived from
    # them — `spree_api` registers one entry per admin resource controller
    # after the classes load. Core owns the structure and the refusal below;
    # a resource no controller serves is not reachable by any agent.
    #
    # Permissions therefore mirror the controllers by construction rather than
    # by convention: the catalog has no `read_price_lists`, and the price-lists
    # controller rides `read_products`, so the derived entry does too.
    class ResourceMap
      # A registered resource whose model has no store scoping. Raised rather
      # than quietly leaking another store's records.
      UnscopedResourceError = Class.new(StandardError)

      Entry = Struct.new(:key, :model_name, :permission, :serializer_name,
                         :dashboard_path, :scope_name, :write_permission,
                         :writable_attributes, :create_workflow_key, :update_workflow_key,
                         keyword_init: true) do
        # Whether the generic write tools may touch this resource at all.
        # A resource written through a workflow must be written through its
        # workflow tool, so there is exactly one way to write each thing.
        #
        # @return [Boolean]
        def generic_writes?
          create_workflow_key.blank? && update_workflow_key.blank? && write_permission.present?
        end

        # The attributes the Admin API would accept on a write, so the generic
        # tools offer exactly the same surface as the endpoint.
        #
        # @return [Array<String>]
        def writable_attribute_names
          Array(writable_attributes).map(&:to_s).sort
        end
        # Where this record lives in the dashboard, so an answer links to it
        # rather than describing where to look. Store-relative — the panel
        # prefixes the current store segment.
        #
        # @param record [ActiveRecord::Base]
        # @return [String, nil]
        def dashboard_path_for(record)
          return if dashboard_path.blank?

          format(dashboard_path, id: record.prefixed_id)
        end

        # @return [Class]
        def model_class
          model_name.constantize
        end

        # Records of this kind the asking admin may see.
        #
        # Takes the context rather than the store so the ability filter cannot
        # be skipped by forgetting to apply it: store scoping answers tenancy,
        # `accessible` answers which records within that tenant — the same two
        # steps an Admin API controller takes.
        #
        # @param context [Spree::AgentTools::Context]
        # @param action [Symbol]
        # @return [ActiveRecord::Relation]
        def scope_for(context, action = :show)
          relation = model_class.for_store(context.store)

          # `Spree::Base.for_store` falls back to the bare class when a model
          # has no matching Store association, returning EVERY store's rows.
          # A model that defines its own `for_store` has made a deliberate
          # choice (customers are global by design, and Spree::Customer says
          # so); inheriting the fallback is an accident. Only the accident is
          # refused, because serving another store's records to an assistant
          # that reads them aloud is worse than a missing resource.
          if model_class.method(:for_store).owner == Spree::Base.singleton_class && relation.equal?(model_class)
            raise UnscopedResourceError, key
          end

          # A resource that is a slice of a model rather than the whole of it
          # (draft orders among orders) narrows further.
          relation = relation.public_send(scope_name) if scope_name.present?

          context.accessible(relation, action)
        end

        # Whether this resource's scoping is deliberate — either a real
        # store relation, or a model that owns its `for_store` and has decided
        # it is global.
        #
        # @return [Boolean]
        def store_scoped?
          model_class.method(:for_store).owner != Spree::Base.singleton_class ||
            !model_class.for_store(Spree::Store.new).equal?(model_class)
        rescue StandardError
          false
        end

        # @return [Class] the admin serializer for this resource
        def serializer_class
          serializer_name.constantize
        end

        # Fields the model actually allows filtering and sorting on. Reused from
        # the model's own Ransack allowlist so the assistant can never query a
        # field the API would refuse.
        #
        # @return [Array<String>]
        def filterable_fields
          model_class.ransackable_attributes.sort
        end

        # Named queries the model exposes — `in_stock`, `out_of_stock`,
        # `price_lte` and so on. These answer the questions merchants actually
        # ask ("what's out of stock?") and cannot be expressed as an attribute
        # filter, because the answer lives across stock levels rather than in a
        # column. Passed as bare keys rather than `field_predicate` pairs.
        #
        # @return [Array<String>]
        def filterable_scopes
          model_class.ransackable_scopes.map(&:to_s).sort
        end
      end


      class << self
        # How the map fills itself the first time it is read. `spree_api` sets
        # this to its controller walk; core owns only the structure, so an
        # installation without the API engine simply has an empty map.
        #
        # @return [#call, nil]
        attr_accessor :deriver

        # @return [Array<Entry>] every registered resource, in registration order
        def all
          derive!
          entries.values
        end

        # Registers one resource. Called by `spree_api` for each admin resource
        # controller; an extension with its own admin controller is picked up
        # by the same walk, so nothing registers by hand.
        #
        # Re-registering a key replaces it, because the walk runs again on every
        # code reload in development.
        #
        # @param key [String, Symbol] the resource key agents address it by
        # @param model_name [String]
        # @param permission [String] the `read_*` key gating it
        # @param serializer_name [String]
        # @param dashboard_path [String, nil] a `%<id>s` format string
        # @param scope_name [Symbol, nil] narrows the model to a slice of itself
        # @param write_permission [String, nil] the `write_*` key, absent when
        #   the controller offers no writes
        # @param writable_attributes [Array<Symbol>] what a write may set
        # @param create_workflow_key [String, nil] set when the controller
        #   declares a create workflow, which the generic write defers to
        # @param update_workflow_key [String, nil] likewise for updates
        # @return [Entry]
        def register(key:, model_name:, permission:, serializer_name:, dashboard_path: nil, scope_name: nil,
                     write_permission: nil, writable_attributes: [], create_workflow_key: nil,
                     update_workflow_key: nil)
          entry = Entry.new(key: key.to_s, model_name: model_name, permission: permission,
                            serializer_name: serializer_name, dashboard_path: dashboard_path,
                            scope_name: scope_name, write_permission: write_permission,
                            writable_attributes: writable_attributes,
                            create_workflow_key: create_workflow_key,
                            update_workflow_key: update_workflow_key)
          entries[entry.key] = entry
        end

        # Forgets every registration, so the derivation can run again from
        # scratch on a code reload.
        #
        # @return [void]
        def reset!
          @entries = {}
        end

        # @param key [String]
        # @return [Entry, nil]
        def find(key)
          derive!
          entries[key.to_s]
        end

        # Marks the map for rebuilding on its next read. Called on every code
        # reload, because a controller edited in development changes what the
        # map should say — but the rebuild itself waits for a reader.
        #
        # @return [void]
        def stale!
          @derived = false
        end

        # Fills the map once, from whatever `deriver` was registered.
        #
        # Under a mutex, because the deriver rebuilds in place — it clears the
        # map and registers each entry — so a second thread reading between
        # those two moments would see an empty map and report every resource
        # as unknown.
        #
        # The flag is cleared again if the deriver raises: the map is empty by
        # then, and leaving it marked derived would answer "unknown resource"
        # for the rest of the process, since `stale!` only runs at boot and on
        # reload. A failed derivation is retried by the next caller instead.
        #
        # @return [void]
        def derive!
          return if @derived || deriver.nil?

          derive_mutex.synchronize do
            return if @derived

            # Set before calling, so a deriver that reads the map while filling
            # it does not recurse.
            @derived = true
            begin
              deriver.call
            rescue StandardError
              @derived = false
              raise
            end
          end
        end

        # Resources this caller may read, so a tool description lists only what
        # they can actually ask about.
        #
        # @param context [Spree::AgentTools::Context]
        # @return [Array<Entry>]
        def available_for(context)
          all.select { |entry| context.permitted?(entry.permission) }
        end

        private

        def entries
          @entries ||= {}
        end

        def derive_mutex
          @derive_mutex ||= Mutex.new
        end
      end
    end
  end
end
