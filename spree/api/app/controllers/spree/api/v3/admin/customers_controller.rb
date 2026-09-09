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

            # A staff member is making this change, so a marketing-consent flip
            # is recorded as theirs. Left unset it would stamp `account`, which
            # says the person changed their own permission — evidence of a
            # gesture they never made.
            @resource.consent_source = Spree::ConsentRecord::ADMIN

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

            # Recorded like the export beside it. The erasure itself is the
            # obligation and runs whatever happens to the record, but a
            # merchant answering an emailed request should not have to
            # remember they did — the request log is what an Art. 30 enquiry
            # reads, and an erasure that left only an event was invisible to it.
            data_request = open_erasure_record

            # Through the dependency, not the class: a host app that swaps the
            # anonymizer in — for a legal hold, or to reach its own tables —
            # must get the same erasure whoever asked for it. Naming the class
            # here would apply their override to a customer's own request and
            # skip it when staff answer the same request from the admin.
            result = Spree.customer_anonymize_workflow.call(
              customer: @resource,
              store: current_store,
              requested_by: try_spree_current_user
            )

            unless result.success?
              data_request&.update(status: 'failed', error_message: result.error.to_s.first(1000))
              return render_result_error(result)
            end

            data_request&.update(status: 'completed', completed_at: Time.current)

            render json: serialize_resource(@resource.reload)
          end

          # GET /api/v3/admin/customers/:id/export
          #
          # The customer's data as JSON, for answering a subject access request
          # the merchant received directly. Rendered inline rather than queued:
          # a staff member is waiting on it, and unlike the storefront path
          # there is no unauthenticated caller to rate-limit.
          def export
            authorize_resource!(@resource)
            return unless authorized_for_export?

            if @resource.anonymized?
              return render_error(
                code: ERROR_CODES[:validation_error],
                message: Spree.t('data_request_errors.already_anonymized'),
                status: :unprocessable_content
              )
            end

            # Its own record, never an existing one. `DataRequests::Create`
            # returns whatever request is in flight for this customer, and
            # completing that here would close their request without ever
            # delivering their file — the queued job would then refuse it as no
            # longer pending. Its `requested_by_id: nil` filter does not help:
            # it scopes to rows the customer opened, which is exactly the row
            # that must be left alone.
            data_request = Spree::DataRequest.create!(
              store: current_store,
              customer: @resource,
              kind: Spree::DataRequest::ACCESS,
              email: @resource.email,
              requested_by: try_spree_current_user
            )

            # The request row is opened first: an Art. 15 response should leave
            # the same trace whoever produced it, and building through the
            # workflow is what runs the `extend_payload` hook a host app relies
            # on to complete the document.
            payload = Spree::DataRequests::Fulfill.payload_for(data_request)
            data_request.update(status: 'completed', completed_at: Time.current)

            render json: payload
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

          # Its own row rather than one the customer has in flight, for the
          # same reason the export opens its own: completing theirs here would
          # close a request whose file was never delivered.
          #
          # @return [Spree::DataRequest, nil] nil when the record cannot be
          #   written — the erasure is the obligation and still runs
          def open_erasure_record
            Spree::DataRequest.create(
              store: current_store,
              customer: @resource,
              kind: Spree::DataRequest::ERASURE,
              email: @resource.email,
              requested_by: try_spree_current_user,
              status: 'processing'
            ).presence
          rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
            Rails.logger.warn { "[Spree] Could not record erasure request: #{e.message}" }
            nil
          end

          # A subject access export carries the customer's order history, which
          # is otherwise gated on `read_orders`. The controller's own scope only
          # covers `read_customers`, so aggregating the two behind one key would
          # hand order data to a role that was never granted it.
          #
          # @return [Boolean] false when the response has already been rendered
          # Everything the subject access response gathers, and the permission
          # that guards it elsewhere in the API. Seeing a customer's name is not
          # the same as downloading their order history, their saved cards and
          # their balances in one file, so the export asks for each of them.
          EXPORT_PERMISSIONS = %w[
            read_orders
            read_payments
            read_store_credits
            read_gift_cards
          ].freeze

          def authorized_for_export?
            missing = EXPORT_PERMISSIONS.reject { |permission| holds_permission?(permission) }
            return true if missing.empty?

            render_error(
              code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:access_denied],
              message: "Missing permission: #{missing.first}",
              status: :forbidden,
              details: { required_permission: missing.first }
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
