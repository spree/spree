module Spree
  module Api
    module V3
      module Admin
        class CustomersController < ResourceController
          include Spree::Api::V3::BulkOperations

          scoped_resource :customers

          def create
            @resource = Spree.user_class.new(permitted_params)
            # Admin-created customers don't pick a password upfront — they
            # claim the account via password reset later.
            # `Spree::UserMethods` exposes `skip_password_validation` so
            # Devise's `:validatable` lets a nil credential through on this
            # code path. Storefront registration never sets the flag, so
            # customer self-signup still requires a password.
            @resource.skip_password_validation = true if @resource.password.blank?
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
            Spree.user_class
          end

          def serializer_class
            Spree.api.admin_customer_serializer
          end

          def scope
            super.with_order_aggregates
          end

          def collection_includes
            [:rich_text_internal_note, taggings: :tag]
          end

          private

          # Mirrors the products controller's resource-named key so SPA toasts
          # can substitute `{customer_count}` instead of the generic
          # `{record_count}` shipped by `Spree::Api::V3::BulkOperations`.
          def bulk_record_count_key
            :customer_count
          end

          def permitted_params
            params.permit(
              :email, :first_name, :last_name, :phone,
              :password, :password_confirmation, :selected_locale,
              :avatar, :accepts_email_marketing, :internal_note,
              metadata: {}, tags: []
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
