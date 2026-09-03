module Spree
  module Api
    module V3
      module Admin
        class CustomersController < ResourceController
          include Spree::Api::V3::BulkOperations

          scoped_resource :customers

          # Re-declaring a `before_action` for the same method REPLACES the
          # inherited registration rather than adding to it, so the inherited
          # actions have to be repeated here or show/update/destroy silently
          # lose their record.
          before_action :set_resource, only: [:show, :update, :destroy, :export, :anonymize]
          before_action :require_ids!, only: [:bulk_add_to_groups, :bulk_remove_from_groups]

          def create
            @resource = Spree.customer_class.new(permitted_params)
            # Admin-created customers may be created without a password; they
            # claim the account via password reset later (the model does not
            # enforce password presence).
            authorize!(:create, @resource)

            if @resource.save
              render json: serialize_resource(@resource), status: :created
            else
              render_validation_error(@resource.errors)
            end
          end

          def update
            authorize_resource!(@resource)

            if @resource.update(permitted_params)
              render json: serialize_resource(@resource.reload)
            else
              render_validation_error(@resource.errors)
            end
          end

          def destroy
            authorize_resource!(@resource)
            @resource.destroy
            head :no_content
          rescue Spree::Core::DestroyWithOrdersError => e
            render_error(
              code: 'customer_has_orders',
              message: e.message.presence || Spree.t(:error_user_destroy_with_orders),
              status: :unprocessable_content
            )
          end

          # POST /api/v3/admin/customers/:id/anonymize
          #
          # Erases the customer's personal data while leaving the financial
          # record intact. This is what a merchant runs when an erasure request
          # arrives by email — which is how most of them arrive, from people
          # who often can no longer sign in.
          #
          # Irreversible, so it is its own action rather than a flag on update.
          def anonymize
            authorize_resource!(@resource)

            result = Spree::Customers::Anonymize.call(
              customer: @resource,
              store: current_store,
              requested_by: try_spree_current_user
            )

            if result.success?
              render json: serialize_resource(@resource.reload)
            else
              render_result_error(result)
            end
          end

          # GET /api/v3/admin/customers/:id/export
          #
          # The customer's data as JSON, for answering a subject access request
          # the merchant received directly. Rendered inline rather than queued:
          # a staff member is waiting on it, and unlike the storefront path
          # there is no unauthenticated caller to rate-limit.
          def export
            authorize_resource!(@resource)
            return unless authorized_for_order_history?

            render json: Spree.customer_data_export_service.new(
              customer: @resource,
              store: current_store
            ).call
          end

          # Bulk add the given customers to the given groups. Idempotent —
          # customers already in a group are skipped at the model layer.
          def bulk_add_to_groups
            apply_groups(:add_customers)
          end

          # Bulk remove the given customers from the given groups.
          def bulk_remove_from_groups
            apply_groups(:remove_customers)
          end

          protected

          def model_class
            Spree.customer_class
          end

          def serializer_class
            Spree.api.admin_customer_serializer
          end

          def scope
            super.with_order_aggregates
          end

          # Producing the export reads the customer, so it is a read for the
          # key gate and for CanCanCan alike. The latter needs saying twice:
          # `read_actions` settles the required API-key scope, while
          # `authorize_resource!` below maps the action onto an ability a role
          # actually grants — CanCanCan's `:read` alias covers only index and
          # show, so a staffer with read access would otherwise be refused.
          def read_actions
            super + ['export']
          end

          # A subject access export carries the customer's order history, which
          # is otherwise gated on `read_orders`. The controller's own scope only
          # covers `read_customers`, so aggregating the two behind one key would
          # hand order data to a role that was never granted it.
          #
          # @return [Boolean] false when the response has already been rendered
          def authorized_for_order_history?
            return true if holds_permission?('read_orders')

            render_error(
              code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:access_denied],
              message: 'Missing permission: read_orders',
              status: :forbidden,
              details: { required_permission: 'read_orders' }
            )
            false
          end

          # Mirrors the key gate's two principals: a secret key carries scopes,
          # a signed-in staffer carries their roles' catalog keys.
          #
          # @param key [String]
          # @return [Boolean]
          def holds_permission?(key)
            return current_api_key.has_scope?(key) if scope_limited_principal?

            ability = current_ability
            return true unless ability.respond_to?(:permission_keys)

            ability.permission_keys.include?(key)
          end

          # `export` maps to `:show`; `anonymize` is a destructive write, so it
          # maps to `:destroy` rather than `:update` — a role that may correct
          # a customer's name should not thereby be able to erase their history.
          def authorize_resource!(resource = @resource, action = action_name.to_sym)
            mapped = case action
                     when :export then :show
                     when :anonymize then :destroy
                     else action
                     end

            authorize!(mapped, resource || model_class)
          end

          # `customer_groups` is preloaded because the serializer's always-on
          # `customer_group_ids` attribute reads it for every row. `companies`
          # is not: it only renders behind `?expand=companies`, where
          # ar_lazy_preload already batches it into one query for the page.
          def collection_includes
            [:customer_groups, taggings: :tag]
          end

          private

          def scope_includes
            [:customer_groups, :store_credits]
          end

          # Mirrors the products controller's resource-named key so SPA toasts
          # can substitute `{customer_count}` instead of the generic
          # `{record_count}` shipped by `Spree::Api::V3::BulkOperations`.
          def bulk_record_count_key
            :customer_count
          end

          def permitted_params
            params.permit(
              *model_additional_permitted_attributes,
              :email, :first_name, :last_name, :phone,
              :password, :password_confirmation, :selected_locale,
              :avatar, :accepts_email_marketing, :internal_note,
              metadata: {}, tags: [], customer_group_ids: []
            )
          end

          # Authorises bulk group mutation, decodes prefixed IDs, then dispatches
          # to `add_customers` / `remove_customers` per group. Returns the
          # counts of records actually affected so the UI can show a toast.
          def apply_groups(method)
            authorize! :update, model_class

            user_ids = decode_ids(params[:ids])
            group_ids = decode_ids(params[:customer_group_ids])

            scoped_user_ids = scope.where(id: user_ids).pluck(:id)
            scoped_groups = Spree::CustomerGroup.for_store(current_store).where(id: group_ids)

            scoped_groups.find_each { |group| group.public_send(method, scoped_user_ids) }

            render json: { customer_count: scoped_user_ids.size, customer_group_count: scoped_groups.size }
          end
        end
      end
    end
  end
end
