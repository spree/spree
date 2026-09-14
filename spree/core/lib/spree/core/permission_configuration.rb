# The permission catalog — the single grant vocabulary shared by staff roles
# and secret API keys (see docs/plans/6.0-admin-rbac.md).
#
# Code defines the vocabulary, data defines the roles: core and extensions
# register *scopes* here, and each registration yields the grantable
# `read_<scope>` / `write_<scope>` keys. Roles store keys on their row
# (`Spree::Role#permissions`); API keys store them as scopes
# (`Spree::ApiKey#scopes`). There is no code-managed role concept.
#
# @example Registering a scope from an extension
#   Spree.permissions.register_scope(:reviews, group: :catalog, resources: -> {
#     [SpreeReviews::Review]
#   })
#

require 'spree/core/permissions/scope'
require 'spree/core/permissions/entry'
require 'spree/core/permissions/default_catalog'

module Spree
  class PermissionConfiguration
    # Raised when a 5.x initializer still calls the removed permission-set API.
    class PermissionSetsRemovedError < StandardError; end

    READ_PREFIX = 'read_'.freeze
    WRITE_PREFIX = 'write_'.freeze

    # A role's audience is its owning record, lowercased — a role on a
    # `Spree::Store` is `:store`, one on a `Spree::Seller` is `:seller` (see
    # `Spree::Role#audience`).
    #
    # The store's own back office is an audience like any other — the one a
    # registration means when it names none.
    STAFF_AUDIENCE = :store

    def initialize
      @scopes = {}
      DefaultCatalog.register(self)
    end

    # Registers a catalog scope, yielding its `read_<name>` (and, unless
    # `write: false`, `write_<name>`) keys. Re-registering a name replaces it.
    #
    # @param name [Symbol, String]
    # @param group [Symbol] UI group (`:orders`, `:catalog`, `:marketing`, `:loyalty`,
    #   `:customers`, `:settings`, `:access`, `:analytics` — or your own)
    # @param resources [Proc, Array] CanCanCan resources the keys grant
    # @param write [Boolean]
    # @param audiences [Array<Symbol>] every audience whose roles may hold
    #   these keys — the whole list, with the store's own back office as
    #   `:store`. Just the store by default. Naming another audience exposes
    #   the scope to a principal outside the store's own staff, so it is a
    #   deliberate act; a list without `:store` keeps it off the staff picker
    #   and off secret keys entirely. Never open `settings`, `staff` or
    #   `api_keys`.
    # @return [Scope]
    def register_scope(name, group:, resources:, write: true, audiences: [STAFF_AUDIENCE], read_only_for: [])
      # `read_all` / `write_all` are the API-key wildcard aliases — a scope
      # named `all` would silently mint keys that grant the whole catalog.
      raise ArgumentError, "the permission scope name 'all' is reserved" if name.to_s == 'all'

      scope = Scope.new(
        name: name, group: group, resources: resources, write: write,
        audiences: audiences, read_only_for: read_only_for
      )
      @scopes[scope.name] = scope
    end

    # @param name [Symbol, String]
    # @return [Scope, nil]
    def unregister_scope(name)
      @scopes.delete(name.to_sym)
    end

    # @return [Array<Scope>] in registration order (drives UI ordering)
    def scopes
      @scopes.values
    end

    # @param name [Symbol, String]
    # @return [Scope, nil]
    def scope(name)
      @scopes[name.to_s.to_sym]
    end

    # The catalog scope whose resources cover the given model class —
    # matching by ancestry so subclasses (e.g. a Gateway under PaymentMethod)
    # resolve to their base resource's scope. Used to derive the required
    # permission for polymorphic endpoints (translations, custom fields).
    #
    # @param klass [Class]
    # @return [Scope, nil]
    def scope_for_resource(klass)
      return nil unless klass.is_a?(Class)

      scopes.find do |candidate|
        candidate.resources.any? { |resource| resource.is_a?(Class) && klass <= resource }
      end
    end

    # @return [Array<String>] every grantable key, in registration order
    def catalog_keys
      scopes.flat_map(&:keys)
    end

    # Scopes grantable to one audience. An unknown audience simply matches
    # nothing, so a panel that does not exist yet reads as granting nothing
    # rather than raising.
    #
    # @param audience [Symbol, String] `:store`, `:seller`, …
    # @return [Array<Scope>] in registration order
    def grantable_scopes(audience)
      scopes.select { |scope| scope.grantable_to?(audience) }
    end

    # @param audience [Symbol, String]
    # @return [Array<String>] every key that audience may hold, in catalog order
    def grantable_keys(audience)
      grantable_scopes(audience).flat_map { |scope| scope.keys_for(audience) }
    end

    # The grantable keys one audience may hold, with the metadata a permission
    # picker renders. Defaults to staff, which is what the Admin API's
    # discovery endpoint serves: a store role can never usefully hold a
    # seller's own keys, so offering them there is only a way to build a role
    # that refuses to save.
    #
    # @param audience [Symbol, String]
    # @return [Array<Entry>] in catalog order
    def entries(audience: STAFF_AUDIENCE)
      grantable_scopes(audience).flat_map do |scope|
        scope.keys_for(audience).map do |key|
          Entry.new(key: key, kind: key.start_with?(WRITE_PREFIX) ? :write : :read, scope: scope)
        end
      end
    end

    # @param key [String, Symbol]
    # @return [Boolean]
    def key?(key)
      !resolve_key(key).nil?
    end

    # Resolves a key into its kind and scope.
    #
    # @param key [String, Symbol]
    # @return [Array(Symbol, Scope), nil] `[:read | :write, scope]`
    def resolve_key(key)
      key = key.to_s
      if key.start_with?(WRITE_PREFIX)
        found = scope(key.delete_prefix(WRITE_PREFIX))
        [:write, found] if found&.write?
      elsif key.start_with?(READ_PREFIX)
        found = scope(key.delete_prefix(READ_PREFIX))
        [:read, found] if found
      end
    end

    # Applies one key's grants to a CanCanCan ability. Read keys grant
    # `[:read, :admin]`; write keys grant `:manage` (which covers read).
    #
    # @param ability [CanCan::Ability]
    # @param key [String, Symbol]
    # @return [Boolean] whether the key resolved and was applied
    def activate_key(ability, key)
      kind, found = resolve_key(key)
      return false unless found

      found.resources.each do |resource|
        if kind == :write
          ability.can(:manage, resource)
        else
          ability.can(%i[read admin], resource)
        end
      end
      true
    end

    # Expands a key list into the full set of keys it effectively grants:
    # `write_x` implies `read_x`, and the `read_all` / `write_all` API-key
    # aliases expand against the whole catalog. Unknown keys are dropped.
    # Result preserves catalog order.
    #
    # @param keys [Array<String, Symbol>]
    # @return [Array<String>]
    def expand_keys(keys)
      keys = Array(keys).map(&:to_s)
      # The aliases belong to secret API keys, which are a store's own
      # credential — so they expand over what staff may hold, never over
      # another audience's keys.
      staff_resources = grantable_scopes(STAFF_AUDIENCE)
      return staff_resources.flat_map(&:keys) if keys.include?('write_all')

      effective = keys.include?('read_all') ? staff_resources.map(&:read_key) : []
      effective |= keys.flat_map do |key|
        kind, found = resolve_key(key)
        next [] unless found

        kind == :write ? [found.write_key, found.read_key] : [found.read_key]
      end
      catalog_keys & effective
    end

    # Restores the catalog to core defaults. Useful for tests that register
    # extra scopes.
    def reset!
      @scopes = {}
      DefaultCatalog.register(self)
    end

    # Removed in 6.0 — roles are data now (see docs/plans/6.0-admin-rbac.md).
    # Kept only to fail loudly with directions instead of a bare NoMethodError.
    def assign(*)
      raise PermissionSetsRemovedError,
            'Permission sets were removed in Spree 6.0. Remove the permission lines from ' \
            'config/initializers/spree.rb — roles and their permissions are data now, ' \
            'managed in the dashboard (Settings → Roles), via the Admin API, or in seeds. ' \
            "Upgrade guide: https://spreecommerce.org/docs/developer/upgrades/5.6-to-6.0"
    end
  end
end
