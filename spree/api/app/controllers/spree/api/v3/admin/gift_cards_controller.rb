module Spree
  module Api
    module V3
      module Admin
        # Admin CRUD for `Spree::GiftCard`. Scoped to the current store via
        # the model's `SingleStoreResource` include — the base controller's
        # `scope` already applies `model_class.for_store(current_store)`.
        #
        # `store` and `created_by` are auto-stamped by `build_resource` in
        # `Spree::Api::V3::ResourceController`, so create requests only need
        # to include user-facing attributes (amount, currency, expires_at,
        # optional code, optional customer_id).
        class GiftCardsController < ResourceController
          scoped_resource :gift_cards

          request_params :gift_card do |body|
            body.attribute :amount, :decimal,
              required: true, on: :create,
              example: '25.00',
              description: 'Greater than zero.'
            body.attribute :currency, :currency,
              example: 'USD',
              description: 'ISO 4217 currency code. Defaults to the store currency.'
            body.attribute :code, :string, example: 'WELCOME50', description: 'Generated when omitted.'
            body.attribute :expires_at, :date, nullable: true, example: '2030-12-31'
            # Resolved through the caller's ability by `resolve_customer`.
            body.attribute :customer_id, :id,
              nullable: true,
              permit: false,
              example: 'cus_UkLWZg9DAJ',
              description: 'The customer the card belongs to. Needs the `read_customers` permission; null detaches it.'
          end

          before_action :resolve_customer, only: [:create, :update]

          # Locked so a checkout drawing the card down cannot commit between
          # the model's used-card check and this write.
          def update
            @resource.with_lock { super }
          end

          # Takes the card off every open cart and draft order still holding
          # it, then deletes it, all in one transaction. Holds never expire on
          # their own, so refusing instead would leave a card on an abandoned
          # guest cart undeletable. Releasing goes through
          # Spree.gift_card_remove_workflow, which voids the store credit
          # payment and restores the amount due, so nothing keeps paying from
          # a card that no longer exists. A hold in the middle of a completion
          # attempt is not released, and the model then refuses the delete.
          #
          # Holds are locked before the card, the order Spree::GiftCards::Apply
          # and Remove use, and the card is locked for the check and the delete
          # so a checkout cannot apply it in between.
          def destroy
            ApplicationRecord.transaction do
              unless release_open_holds
                render_error(
                  code: ERROR_CODES[:validation_error],
                  message: I18n.t('spree.api.cannot_delete', model: model_class.model_name.human),
                  status: :unprocessable_content
                )
                raise ActiveRecord::Rollback
              end

              @resource.with_lock { super }

              # A refused delete keeps the holds it would have released.
              raise ActiveRecord::Rollback unless response.status == 204
            end
          end

          protected

          def model_class
            Spree::GiftCard
          end

          def serializer_class
            Spree.api.admin_gift_card_serializer
          end

          def permitted_params
            params.permit(*permitted_attributes).tap do |attributes|
              attributes[:customer] = @customer if params.key?(:customer_id)
            end
          end

          private

          # @return [Boolean] false when a hold could not be released
          def release_open_holds
            holds = @resource.open_holds
            holds.group_by(&:class).each do |klass, records|
              klass.where(id: records.map(&:id)).order(:id).lock.to_a
            end

            holds.all? do |hold|
              hold.reload
              next true unless hold.gift_card_id == @resource.id
              next true if hold.completed? || claimed_for_completion?(hold)

              Spree.gift_card_remove_workflow.call(order: hold).success?
            end
          end

          # Re-read under the hold's lock: the claim may have been stamped
          # after +open_holds+ gathered the list.
          def claimed_for_completion?(hold)
            return hold.completion_claimed? if hold.is_a?(Spree::Cart)

            hold.cart&.reload&.completion_claimed? || false
          end

          # Assigning a customer embeds their record in the response, so it is
          # a read of customers: the caller must hold that permission, and the
          # customer is resolved through their ability — never a raw id the
          # model would look up across every customer.
          def resolve_customer
            return unless params.key?(:customer_id)
            return @customer = nil if params[:customer_id].blank?

            return render_missing_permission('read_customers') unless holds_permission?('read_customers')

            @customer = Spree.customer_class.
                        accessible_by(current_ability, :show).
                        find_by_prefix_id!(params[:customer_id])
          end
        end
      end
    end
  end
end
