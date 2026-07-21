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
          def skip_scope_check!(only: nil)
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
          before_action :authorize_api_key_scope!
        end

        private

        def authorize_api_key_scope!
          return unless current_api_key
          return if self.class._scope_check_skipped
          return if self.class._scope_check_skipped_actions&.include?(action_name)

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
