module Spree
  module AgentTools
    # Which Admin API operation runs each workflow an agent may call.
    #
    # A contract like {ResourceMap} and {MembershipMap}: core declares the
    # shape, and `spree_api` fills it by reading its own routes and
    # controllers, so a workflow that gains an endpoint is dispatched without
    # anyone editing a list.
    #
    # A workflow with no entry runs in this process instead. That is not a
    # fallback to be relied on — it means the capability has no endpoint yet,
    # and the tool is the only way to reach it.
    module WorkflowEndpoints
      # @!attribute verb
      #   @return [String] 'POST', 'PATCH'
      # @!attribute path
      #   @return [String] with `:name` segments still in it
      # @!attribute body_keys
      #   @return [Array<String>] what the operation's request body accepts,
      #     read from the generated OpenAPI document — which is where the
      #     renames live (a cancellation's `reason:` keyword is
      #     `cancel_reason_id` on the wire)
      Entry = Struct.new(:verb, :path, :body_keys, keyword_init: true) do
        # The dynamic segments, in the order the path names them.
        #
        # @return [Array<String>]
        def path_params
          @path_params ||= path.scan(/:([a-z_]+)/).flatten
        end

        # @param values [Hash] path parameter name => id
        # @return [String]
        def path_for(values)
          path.gsub(/:([a-z_]+)/) { values.fetch(Regexp.last_match(1)).to_s }
        end
      end

      class << self
        # @param key [Symbol] a `Spree::Dependencies` workflow key
        # @return [Entry, nil]
        def find(key)
          derive!
          entries[key.to_sym]
        end

        # @return [Hash{Symbol => Entry}]
        def all
          derive!
          entries
        end

        def register(key:, verb:, path:, body_keys: [])
          entries[key.to_sym] = Entry.new(verb: verb.to_s.upcase, path: path,
                                          body_keys: body_keys.map(&:to_s))
        end

        def reset!
          @entries = {}
          @derived = false
        end

        # What has been registered so far, without deriving — for the
        # deriver itself, which must not ask for what it is producing.
        #
        # @return [Hash{Symbol => Entry}]
        def registered
          entries
        end

        # Filled on first read rather than at boot: deriving it loads every
        # admin controller, which a developer who never runs an agent should
        # not pay for on each code reload.
        def derive!
          return if @derived

          @derived = true
          Spree::Api::AgentWorkflowEndpoints.install if defined?(Spree::Api::AgentWorkflowEndpoints)
        end

        private

        def entries
          @entries ||= {}
        end
      end
    end
  end
end
