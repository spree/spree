module Spree
  module Api
    module V3
      module Admin
        module Customers
          class AddressesController < BaseController

            # POST /api/v3/admin/customers/:customer_id/addresses
            def create
              @resource = @parent.addresses.new(address_attrs)
              authorize_resource!(@resource, :create)

              ApplicationRecord.transaction do
                if @resource.save
                  apply_default_flags(@resource)
                  render json: serialize_resource(@resource.reload), status: :created
                else
                  render_validation_error(@resource.errors)
                  raise ActiveRecord::Rollback
                end
              end
            end

            # PATCH /api/v3/admin/customers/:customer_id/addresses/:id
            def update
              authorize_resource!(@resource)

              ApplicationRecord.transaction do
                if @resource.update(address_attrs)
                  apply_default_flags(@resource)
                  render json: serialize_resource(@resource.reload)
                else
                  render_validation_error(@resource.errors)
                  raise ActiveRecord::Rollback
                end
              end
            end

            # DELETE /api/v3/admin/customers/:customer_id/addresses/:id
            def destroy
              authorize_resource!(@resource)
              @resource.destroy
              head :no_content
            end

            protected

            def parent_association
              :addresses
            end

            def model_class
              Spree::Address
            end

            def serializer_class
              Spree.api.admin_address_serializer
            end

            private

            def address_attrs
              params.permit(
                :firstname, :lastname, :first_name, :last_name,
                :address1, :address2, :city,
                :country_iso, :state_abbr, :country_id, :state_id,
                :zipcode, :postal_code, :phone, :alternative_phone,
                :state_name, :company, :label, :quick_checkout
              )
            end

            def apply_default_flags(address)
              updates = {}
              updates[:bill_address_id] = address.id if ActiveModel::Type::Boolean.new.cast(params[:is_default_billing])
              updates[:ship_address_id] = address.id if ActiveModel::Type::Boolean.new.cast(params[:is_default_shipping])
              @parent.update!(updates) if updates.any?
            end
          end
        end
      end
    end
  end
end
