module Spree
  module Api
    module V3
      # Per-resource scope check for Admin API requests authenticated via API key.
      # JWT-authenticated admin users bypass this and rely on CanCanCan abilities.
      #
      # Controllers declare their scope:
      #
      #   class Spree::Api::V3::Admin::OrdersController < ResourceController
      #     scoped_resource :orders
      #   end
      #
      # The before_action maps the action to a `read_*` (index/show) or `write_*`
      # (everything else, including custom member actions) scope and verifies the
      # API key carries it.
      #
      # See docs/plans/5.5-admin-api-key-scopes.md.
      module ScopedAuthorization
        extend ActiveSupport::Concern

        READ_ACTIONS = %w[index show].freeze

        class MissingScopedResource < StandardError
          def initialize(controller_class)
            super("#{controller_class} must declare `scoped_resource :name` " \
                  '(or `skip_scope_check!` for endpoints exempt from scope checks).')
          end
        end

        class_methods do
          def scoped_resource(name)
            self._scoped_resource = name.to_sym
            self._scope_check_skipped = false
          end

          # Opt out of scope checks — for the whole controller (auth, me,
          # tags, etc.) or for specific actions (`only: :index`) when an
          # action authorizes another way, e.g. by filtering its collection
          # per-type (exports).
          #
          # `jwt_only: true` narrows the exemption to JWT staff: secret API
          # keys still have their scope enforced. Use it for shell data a
          # signed-in staff member reads to render the dashboard (the store
          # itself) but which a scope-limited integration key has no business
          # reading outside its granted scope.
          def skip_scope_check!(only: nil, jwt_only: false)
            self._scope_check_skip_jwt_only = jwt_only

            if only
              self._scope_check_skipped_actions = Array(only).map(&:to_s)
            else
              self._scope_check_skipped = true
            end
          end
        end

        included do
          class_attribute :_scoped_resource, instance_accessor: false
          class_attribute :_scope_check_skipped, instance_accessor: false, default: false
          class_attribute :_scope_check_skipped_actions, instance_accessor: false
          class_attribute :_scope_check_skip_jwt_only, instance_accessor: false, default: false
          before_action :authorize_api_key_scope!
        end

        private

        def authorize_api_key_scope!
          # Endpoints explicitly exempt from the scope mechanism (auth, me, public
          # invitation acceptance, per-type-filtered exports, etc.) opt out first,
          # before any key resolution or enforcement. A `jwt_only` skip is the
          # exception: it exempts JWT staff but still enforces scope for secret
          # keys, so it must fall through to key resolution below.
          if scope_check_skipped_for_action? && !self.class._scope_check_skip_jwt_only
            return
          end

          # Fail CLOSED, not open. A nil `current_api_key` legitimately means a
          # non-secret-key request (JWT admin / publishable) authorized by other
          # means, which correctly skips scope checks. But it ALSO happens when
          # this guard runs before authentication resolved the key: a bare
          # `return unless current_api_key` would then skip scope enforcement for
          # an attacker-supplied secret key. So resolve the secret key in place
          # here — never rely on before_action ordering. Only truly non-secret-key
          # requests (nothing to resolve) are waved through.
          resolve_current_api_key_for_scope_check!

          unless current_api_key
            if secret_key_request?
              # A secret-key token was presented but did not resolve to a live key
              # for this store — reject rather than silently skip the scope check.
              return render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:invalid_token],
                message: 'Valid secret API key required',
                status: :unauthorized
              )
            end

            # A `jwt_only` skip exempts the JWT/publishable principal we now know
            # this is (no secret key resolved) — shell data the dashboard reads
            # without a specific scope.
            return if scope_check_skipped_for_action? && self.class._scope_check_skip_jwt_only

            # JWT staff pass through the same key gate as secret keys: their
            # roles' catalog keys play the role scopes play for keys, so both
            # principals share one enforcement contract per controller.
            return authorize_staff_permission!
          end

          resource = scoped_resource_name
          # Fail closed: a controller authenticated by API key MUST declare
          # either `scoped_resource :name`, override `scoped_resource_name`,
          # or `skip_scope_check!`.
          raise MissingScopedResource, self.class unless resource

          required = "#{action_kind}_#{resource}"
          return if current_api_key.has_scope?(required)

          render_error(
            code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:access_denied],
            message: "API key lacks scope: #{required}",
            status: :forbidden,
            details: { required_scope: required }
          )
        end

        # The JWT half of the key gate. The staffer's expanded role keys come
        # from Spree::Ability#permission_keys; a custom ability class without
        # that method falls back to plain CanCanCan `authorize!` enforcement.
        def authorize_staff_permission!
          return unless current_user

          resource = scoped_resource_name
          # Fail closed, mirroring the secret-key path: admin controllers must
          # declare their scope (or skip explicitly).
          raise MissingScopedResource, self.class unless resource

          ability = current_ability
          return unless ability.respond_to?(:permission_keys)

          required = "#{action_kind}_#{resource}"
          # Scope names outside the catalog (the exports/imports `:all`
          # fallback, host-registered types) defer to CanCanCan's `authorize!`
          # — the caller stays gated per subject, just not by key.
          return unless Spree.permissions.key?(required)
          return if ability.permission_keys.include?(required)

          Rails.logger.info do
            "[Spree] Access denied: user=#{current_user.id} required=#{required} " \
              "held=#{ability.permission_keys.join(',')}"
          end

          render_error(
            code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:access_denied],
            message: "Missing permission: #{required}",
            status: :forbidden,
            details: { required_permission: required }
          )
        end

        # Whether the current action opted out of scope checks via
        # `skip_scope_check!` (whole-controller or `only:`). Independent of the
        # `jwt_only` qualifier, which the caller weighs separately.
        def scope_check_skipped_for_action?
          self.class._scope_check_skipped ||
            self.class._scope_check_skipped_actions&.include?(action_name) || false
        end

        # Resolves the request's secret API key into `@current_api_key` if a
        # secret-key token is present and it hasn't been resolved yet, so the scope
        # check does not depend on `authenticate_admin!` having already run. Uses
        # the same memoized lookup as AdminAuthentication (the key selects the
        # request's store — see Admin::StoreContext), and is idempotent: when the
        # key is already loaded (guard runs after auth) it does nothing.
        def resolve_current_api_key_for_scope_check!
          return if @current_api_key
          return unless secret_key_request?

          @current_api_key = secret_api_key
        end

        # The resource name used in scope strings (`read_<name>` / `write_<name>`).
        # Defaults to the class-level `scoped_resource :name` declaration.
        # Override in controllers that resolve scope at request time (e.g. the
        # nested-on-many-parents `CustomFieldsController` returns the parent's
        # route segment).
        def scoped_resource_name
          self.class._scoped_resource
        end

        # Maps the action to the scope kind. Consults the controller's
        # `read_actions` (ResourceController's overridable list) when defined,
        # so declaring a custom read-only action once — e.g. `types` — fixes
        # both the CanCanCan action mapping and the required scope kind.
        # Controllers outside the ResourceController hierarchy can still
        # override `action_kind` directly (e.g. dashboard `analytics`).
        def action_kind
          read = respond_to?(:read_actions, true) ? read_actions : READ_ACTIONS
          read.include?(action_name) ? 'read' : 'write'
        end

        # True when authorization derives from the API key's scopes rather
        # than a JWT admin's CanCanCan ability. Mirrors the credential
        # precedence in AdminAuthentication#current_ability (JWT user wins).
        def scope_limited_principal?
          current_api_key.present? && current_user.blank?
        end
      end
    end
  end
end
