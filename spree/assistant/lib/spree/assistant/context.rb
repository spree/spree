module Spree
  module Assistant
    # Who is asking, and where. Every tool executes inside one of these, so a
    # tool can never reach data the signed-in admin could not reach by clicking:
    # lookups scope through {#store}, and {#permitted?} decides which tools the
    # model is even offered.
    class Context
      # @return [Spree::Store]
      attr_reader :store

      # @return [Object] the signed-in admin ({Spree.admin_user_class})
      attr_reader :user

      # @return [Spree::Ability]
      attr_reader :ability

      # @param store [Spree::Store]
      # @param user [Object] a {Spree.admin_user_class} record
      # @param ability [Spree::Ability] defaults to the user's ability for this
      #   store — abilities are store-scoped, so the store must be passed
      def initialize(store:, user:, ability: nil)
        @store = store
        @user = user
        @ability = ability || Spree::Dependencies.ability_class.constantize.new(user, store: store)
      end

      # @param permission_key [String, nil]
      # @return [Boolean] whether the asking user holds this permission
      def permitted?(permission_key)
        return true if permission_key.blank?

        key = permission_key.to_s
        # An unregistered key can never be held, so a typo would silently hide a
        # tool forever. Fail loudly in development instead.
        if !Spree.permissions.key?(key) && (defined?(Rails) && Rails.env.local?)
          raise ArgumentError, "Assistant tool declares unknown permission key #{key.inspect}"
        end

        permission_keys.include?(key)
      end

      # The catalog keys this admin activated for this store — the same currency
      # the admin key gate checks. The `respond_to?` guard is house style:
      # `Spree::Dependencies.ability_class` is swappable and a custom class need
      # not implement it.
      #
      # @return [Array<String>]
      def permission_keys
        @permission_keys ||= if ability.respond_to?(:permission_keys)
                               Array(ability.permission_keys).map(&:to_s)
                             else
                               []
                             end
      end
    end
  end
end
