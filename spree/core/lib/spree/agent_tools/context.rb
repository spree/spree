module Spree
  module AgentTools
    # Who is asking, and where. Every tool executes inside one of these, so a
    # tool can never reach data the caller could not reach through the Admin
    # API: lookups scope through {#store}, and {#permitted?} decides which
    # tools the model is even offered.
    #
    # Two kinds of caller, because the registry serves two adapters. The
    # dashboard assistant asks on behalf of a signed-in admin, so its context
    # carries a user and that user's ability. The MCP server asks on behalf of
    # a secret API key, so its context carries the key and the key's scopes.
    # Whichever it is, {#principal} is the thing that acted — which is what a
    # workflow records as the canceller or approver.
    #
    #   Context.new(store: store, user: admin)
    #   Context.new(store: store, api_key: key)
    class Context
      # @return [Spree::Store]
      attr_reader :store

      # @return [Object, nil] the signed-in admin ({Spree.admin_user_class}),
      #   or nil when a key is asking
      attr_reader :user

      # @return [Spree::ApiKey, nil] the authenticating secret key, or nil when
      #   an admin is asking
      attr_reader :api_key

      # @return [Spree::Ability, nil] the user's ability; nil for a key, whose
      #   authority is its scopes
      attr_reader :ability

      # @param store [Spree::Store]
      # @param user [Object, nil] a {Spree.admin_user_class} record
      # @param api_key [Spree::ApiKey, nil] a secret key
      # @param ability [Spree::Ability, nil] defaults to the user's ability for
      #   this store — abilities are store-scoped, so the store must be passed
      def initialize(store:, user: nil, api_key: nil, ability: nil)
        raise ArgumentError, 'Spree::AgentTools::Context needs a user or an api_key' if user.nil? && api_key.nil?

        @store = store
        @user = user
        @api_key = api_key
        @ability = ability || (Spree::Dependencies.ability_class.constantize.new(user, store: store) if user)
      end

      # Who acted, for workflows that record it (`canceler:`, `approver:`,
      # `created_by:`). An admin user or an API key — both are registered in
      # `Spree.actor_classes`, so either can be stored polymorphically.
      #
      # @return [Object]
      def principal
        user || api_key
      end
      alias actor principal

      # @return [Boolean] whether a signed-in admin is asking
      def user_principal?
        user.present?
      end

      # Narrows a relation to the records this caller may act on, the same way
      # an Admin API controller does.
      #
      # For an admin, permission keys answer "may they touch products at all";
      # they do not answer "which products". A host app that registers a
      # record-level rule (`can :read, Spree::Order, seller_id: ...`) is
      # honoured by the Admin API, and must be honoured here too.
      #
      # For a key there is no record-level filter to apply: a secret key's
      # authority is its scopes, and the store is the whole tenancy answer —
      # exactly how the Admin API treats key requests today.
      #
      # @param relation [ActiveRecord::Relation]
      # @param action [Symbol]
      # @return [ActiveRecord::Relation]
      def accessible(relation, action = :show)
        return relation unless user_principal?
        return relation unless relation.respond_to?(:accessible_by)

        relation.accessible_by(ability, action)
      end

      # Whether this caller may take an action on a specific record.
      #
      # Checked at execution rather than at proposal time: an approval card may
      # be decided minutes later, and roles can change in between. A key holds
      # no record-level rules, so its scope check is the whole answer.
      #
      # @param record [Object]
      # @param action [Symbol]
      # @return [Boolean]
      def can?(action, record)
        return true unless user_principal?

        ability.can?(action, record)
      end

      # @param permission_key [String, nil]
      # @return [Boolean] whether the caller holds this permission
      def permitted?(permission_key)
        return true if permission_key.blank?

        key = permission_key.to_s
        # An unregistered key can never be held, so a typo would silently hide a
        # tool forever. Fail loudly in development instead.
        if !Spree.permissions.key?(key) && (defined?(Rails) && Rails.env.local?)
          raise ArgumentError, "Agent tool declares unknown permission key #{key.inspect}"
        end

        permission_keys.include?(key)
      end

      # The catalog keys this caller holds, in the one currency both gates
      # speak: an admin's activated role keys, or a secret key's scopes
      # expanded the way the Admin API expands them (`write_x` implies
      # `read_x`, `read_all` and `write_all` fan out over the catalog).
      #
      # The `respond_to?` guard on the ability is house style:
      # `Spree::Dependencies.ability_class` is swappable and a custom class
      # need not implement it.
      #
      # @return [Array<String>]
      def permission_keys
        @permission_keys ||=
          if user_principal?
            ability.respond_to?(:permission_keys) ? Array(ability.permission_keys).map(&:to_s) : []
          else
            Spree.permissions.expand_keys(api_key.scopes)
          end
      end
    end
  end
end
