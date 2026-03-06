module Spree
  module Products
    class Update
      prepend Spree::ServiceModule::Base

      def call(product:, store:, params:)
        ApplicationRecord.transaction do
          run :update_product
          run :update_variants
        end
      end

      private

      def update_product(product:, store:, params:)
        params = params.to_h.with_indifferent_access
        variants_params = params.delete(:variants)
        product_params = resolve_ids(params)

        # Map tags array to tag_list
        product_params[:tag_list] = product_params.delete(:tags) if product_params.key?(:tags)

        # Preserve taxon associations from other stores
        if product_params.key?(:taxon_ids)
          other_store_taxon_ids = product.taxons
                                         .joins(:taxonomy)
                                         .where.not(spree_taxonomies: { store_id: store.id })
                                         .pluck(:id)
          product_params[:taxon_ids] = (product_params[:taxon_ids] + other_store_taxon_ids).uniq
        end

        if product.update(product_params)
          success(product: product, store: store, variants_params: variants_params)
        else
          failure(product, product.errors)
        end
      end

      def update_variants(product:, store:, variants_params:)
        return success(product: product) if variants_params.blank?

        variants_params.each do |variant_data|
          variant_data = variant_data.to_h.with_indifferent_access
          variant_id = variant_data.delete(:id)
          prices_params = variant_data.delete(:prices)
          option_type_name = variant_data.delete(:option_type)
          option_value_name = variant_data.delete(:option_value)
          total_on_hand = variant_data.delete(:total_on_hand)

          variant = if variant_id.present?
                      product.variants_including_master.find_by_prefix_id!(variant_id)
                    else
                      product.variants.build
                    end

          # Assign option value if provided
          if option_type_name.present? && option_value_name.present?
            option_type = Spree::OptionType.where(name: option_type_name.to_s.parameterize).first_or_create! do |ot|
              ot.presentation = option_type_name
            end
            product.option_types << option_type unless product.option_types.include?(option_type)

            option_value = option_type.option_values.where(name: option_value_name.to_s.parameterize).first_or_create! do |ov|
              ov.presentation = option_value_name
            end
            variant.option_values = [option_value]
          end

          variant.assign_attributes(variant_data.except(:id))

          unless variant.save
            raise ActiveRecord::Rollback
            return failure(variant, variant.errors)
          end

          # Set stock
          if total_on_hand.present?
            variant.stock_items.first&.set_count_on_hand(total_on_hand.to_i)
          end

          # Upsert prices
          upsert_prices(variant, prices_params) if prices_params.present?
        end

        success(product: product.reload)
      end

      def upsert_prices(variant, prices_params)
        now = Time.current
        currencies = []

        records = prices_params.map do |price_data|
          price_data = price_data.to_h.with_indifferent_access
          currencies << price_data[:currency]
          {
            variant_id: variant.id,
            currency: price_data[:currency],
            amount: price_data[:amount],
            compare_at_amount: price_data[:compare_at_amount],
            created_at: now,
            updated_at: now
          }
        end

        Spree::Price.where(variant_id: variant.id, price_list_id: nil)
                    .where.not(currency: currencies)
                    .update_all(deleted_at: now)

        Spree::Price.upsert_all(
          records,
          unique_by: :index_spree_prices_on_variant_id_and_currency,
          update_only: [:amount, :compare_at_amount, :updated_at]
        )
      end

      def resolve_ids(params)
        params = params.to_h.with_indifferent_access

        if params[:tax_category_id].present?
          params[:tax_category_id] = resolve_prefix_id(Spree::TaxCategory, params[:tax_category_id])
        end

        if params[:shipping_category_id].present?
          params[:shipping_category_id] = resolve_prefix_id(Spree::ShippingCategory, params[:shipping_category_id])
        end

        if params[:taxon_ids].present?
          params[:taxon_ids] = params[:taxon_ids].map { |id| resolve_prefix_id(Spree::Taxon, id) }
        end

        params
      end

      def resolve_prefix_id(klass, id)
        return id unless id.is_a?(String) && id.match?(/\A[a-z]+_/)

        klass.find_by_prefix_id!(id).id
      end
    end
  end
end
