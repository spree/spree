module Spree
  module Api
    module V3
      module Admin
        # Inventory movement between stock locations, or vendor → location
        # for receives. Pass `source_location_id` for transfers; omit it to
        # record an external receive.
        class StockTransfersController < ResourceController
          scoped_resource :stock

          def create
            authorize!(:create, model_class)

            stock_locations = Spree::StockLocation.accessible_by(current_ability, :show)
            destination = stock_locations.find_by_prefix_id!(params[:destination_location_id])
            source = params[:source_location_id].present? ?
              stock_locations.find_by_prefix_id!(params[:source_location_id]) : nil

            variants_map = build_variants_map
            if variants_map.empty?
              return render_error(
                code: 'invalid_variants',
                message: Spree.t('stock_transfer.errors.must_have_variant'),
                status: :unprocessable_content
              )
            end

            @resource = source ?
              Spree::StockTransfer.new(reference: params[:reference]).tap { |t| t.transfer(source, destination, variants_map) } :
              Spree::StockTransfer.new(reference: params[:reference]).tap { |t| t.receive(destination, variants_map) }

            if @resource.persisted?
              render json: serialize_resource(@resource), status: :created
            else
              render_validation_error(@resource.errors)
            end
          end

          protected

          def model_class
            Spree::StockTransfer
          end

          def serializer_class
            Spree.api.admin_stock_transfer_serializer
          end

          def collection_includes
            [:source_location, :destination_location]
          end

          private

          # Variants the merchant doesn't have access to are dropped silently;
          # if the resulting map is empty the action surfaces a 422
          # `invalid_variants` so callers can distinguish "nothing supplied"
          # from "all variants were rejected." A single SELECT covers any
          # number of variants instead of N round-trips.
          def build_variants_map
            entries = params.permit(variants: [:variant_id, :quantity]).fetch(:variants, [])
            quantities_by_id = entries.each_with_object({}) do |entry, hash|
              decoded = Spree::PrefixedId.decode_prefixed_id(entry[:variant_id])
              hash[decoded.to_i] = entry[:quantity].to_i if decoded
            end

            current_store.variants.accessible_by(current_ability, :update).where(id: quantities_by_id.keys).each_with_object({}) do |variant, acc|
              quantity = quantities_by_id[variant.id]
              acc[variant] = quantity if quantity&.positive?
            end
          end
        end
      end
    end
  end
end
