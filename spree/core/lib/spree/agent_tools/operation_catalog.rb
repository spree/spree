module Spree
  module AgentTools
    # Every Admin API operation an agent may call by name, and what it takes.
    #
    # A contract like {ResourceMap}: core declares the shape, and `spree_api`
    # fills it from the Admin API's OpenAPI document — core's and every
    # extension's — and the routes behind it. An operation that gains an
    # endpoint is a tool in the same commit, with the summary, description and
    # request body its rswag spec wrote.
    #
    # See docs/plans/6.0-agent-tools-from-openapi.md.
    module OperationCatalog
      # @!attribute name
      #   @return [String] the tool name, `orders_cancel`
      # @!attribute verb
      #   @return [String] 'post', 'patch', 'put', 'delete' or 'get'
      # @!attribute path
      #   @return [String] the OpenAPI path, with `{name}` segments
      # @!attribute description
      #   @return [String] what the model reads when choosing the tool
      # @!attribute summary
      #   @return [String] the operation summary, for the confirmation line
      # @!attribute permission
      #   @return [String] the scope gating it, from the routed controller
      # @!attribute resource_key
      #   @return [String, nil] the resource-map key of the routed controller's
      #     model, so a parent segment can be read off the record
      # @!attribute path_params
      #   @return [Array<String>] the dynamic segments, in path order
      # @!attribute body_properties
      #   @return [Hash{String => Hash}] the request body's JSON Schema
      #     properties, references inlined
      # @!attribute body_required
      #   @return [Array<String>]
      # @!attribute path_descriptions
      #   @return [Hash{String => String}]
      # @!attribute listed
      #   @return [Boolean] false for a 6.0.0 name kept callable through 6.0.x
      # @!attribute legacy_parameters
      #   @return [Hash{String => String, nil}] 6.0.0 parameter => its name now
      Entry = Struct.new(:name, :verb, :path, :description, :summary, :permission, :resource_key,
                         :path_params, :body_properties, :body_required, :path_descriptions,
                         :listed, :legacy_parameters, keyword_init: true) do
        # @return [Boolean] a read opted in to the catalog
        def read?
          verb == 'get'
        end

        # @return [Boolean] whether the call changes the store
        def mutating
          !read?
        end

        # The resource each `{x_id}` segment names, read off the path itself —
        # `/orders/{order_id}/items` names `orders` — so a renamed nested
        # route still points at the right resource.
        #
        # @return [Hash{String => String}] segment => resource key
        def segment_keys
          path.scan(%r{/([a-z_]+)/\{([a-z_]+_id)\}}).to_h { |key, segment| [segment, key] }
        end

        # The segments a call may leave out, read off the record a later
        # segment names. The innermost is the record the call is about, never
        # one to read off another.
        #
        # @return [Hash{String => String}] segment => resource key
        def parent_keys
          segment_keys.except(path_params.last)
        end

        # @param values [Hash{String => String}] path segment => value
        # @return [String, nil] nil while a segment is unfilled
        def path_for(values)
          filled = path.gsub(/\{([a-z_]+)\}/) do
            value = values[Regexp.last_match(1)]
            value.present? ? ERB::Util.url_encode(value.to_s) : Regexp.last_match(0)
          end
          filled unless filled.include?('{')
        end

        # The tool's arguments as JSON Schema: the path segments and the
        # request body, side by side.
        #
        # A segment or field a 6.0.0 name still reaches is left out of
        # `required` through 6.0.x — a client validating against the schema
        # would otherwise refuse the old name before the tool could map it —
        # and so is a parent segment, which the tool can read off the record
        # the call names. The tool checks both itself.
        #
        # @return [Hash]
        def input_schema
          properties = path_params.to_h do |segment|
            [segment, { 'type' => 'string', 'description' => path_descriptions[segment] }.compact]
          end.merge(body_properties)

          aliased = legacy_parameters.values.grep(String)
          parents = parent_keys.keys
          # A 6.0.0 name no longer listed keeps the 6.0.0 contract, which
          # required nothing the operation's body now does.
          required = listed ? (path_params + body_required).uniq - aliased - parents : []

          { 'type' => 'object', 'properties' => properties, 'required' => required }
        end
      end

      class << self
        # How the catalog fills itself the first time it is read. `spree_api`
        # sets it to its walk over the document; an installation without the
        # API engine has no operations to offer.
        #
        # @return [#call, nil]
        attr_accessor :deriver

        # @return [Array<Entry>] the operations offered by name
        def all
          derive!
          entries.values
        end

        # The 6.0.0 names kept callable through 6.0.x, which no listing shows.
        #
        # @return [Array<Entry>]
        def aliases
          derive!
          alias_entries.values
        end

        # A tool by its name, including a 6.0.0 name no longer listed.
        #
        # @param name [String]
        # @return [Entry, nil]
        def find(name)
          derive!
          entries[name.to_s] || alias_entries[name.to_s]
        end

        # Registers one operation. Re-registering a name replaces it, because
        # the walk runs again after a code reload.
        #
        # @return [Entry]
        def register(**attributes)
          entry = build(listed: true, **attributes)
          entries[entry.name] = entry
        end

        # Registers a 6.0.0 name for an operation, callable but not listed.
        # A name an offered operation already has keeps that operation.
        #
        # @return [Entry, nil]
        def register_alias(**attributes)
          entry = build(**attributes, listed: false)
          alias_entries[entry.name] = entry unless entries.key?(entry.name)
        end

        # @return [void]
        def reset!
          @entries = {}
          @alias_entries = {}
        end

        # Marks the catalog for rebuilding on its next read.
        #
        # @return [void]
        def stale!
          @derived = false
        end

        # Fills the catalog once, under a mutex. The flag is set only once the
        # deriver has finished, so a second reader waits on the mutex instead
        # of reading a catalog the deriver has just emptied. Nothing the
        # deriver calls reads the catalog back, so it cannot recurse.
        #
        # @return [void]
        def derive!
          return if @derived || deriver.nil?

          derive_mutex.synchronize do
            next if @derived

            deriver.call
            @derived = true
          end
        end

        private

        def build(**attributes)
          Entry.new(legacy_parameters: {}, body_properties: {}, body_required: [], path_descriptions: {}, **attributes)
        end

        def entries
          @entries ||= {}
        end

        def alias_entries
          @alias_entries ||= {}
        end

        def derive_mutex
          @derive_mutex ||= Mutex.new
        end
      end
    end
  end
end
