require 'spec_helper'

RSpec.describe Spree::Products::PrepareNestedAttributes do
  let(:service) { described_class.new(product, store, params, ability) }
  subject(:prepared_params) { service.call }

  let(:ability) { Spree::Ability.new(nil) }
  let(:store) { @default_store }
  let(:product) { create(:product, store: store) }
  let(:params) { ActionController::Parameters.new(raw_params) }
  let(:raw_params) { {} }

  before do
    ability.can :manage, :all
  end

  describe 'store_id handling' do
    context 'on a new product with no store_id' do
      let(:product) { build(:product, store: nil) }
      let(:raw_params) { { name: 'Product' } }

      it 'defaults to the current store' do
        expect(prepared_params[:store_id]).to eq(store.id)
      end
    end

    context 'when product already has a store_id' do
      let(:raw_params) { { name: 'Product' } }

      it 'does not override the existing store_id' do
        expect(prepared_params).not_to have_key(:store_id)
      end
    end

    context 'when store_id is submitted' do
      let(:raw_params) { { name: 'Product', store_id: store.id } }

      it 'preserves the submitted store_id' do
        expect(prepared_params[:store_id]).to eq(store.id)
      end
    end
  end

  describe 'prices_attributes handling' do
    let(:variant) { product.master }

    context 'when user cannot update prices' do
      before do
        ability.cannot :manage, Spree::Price
      end

      context 'with variants_attributes' do
        let(:raw_params) do
          {
            variants_attributes: {
              '0' => {
                id: variant.id,
                prices_attributes: {
                  '0' => { amount: '10.00' }
                }
              }
            }
          }
        end

        it 'removes prices_attributes from variants' do
          expect(prepared_params[:variants_attributes]['0']).not_to have_key(:prices_attributes)
        end
      end

      context 'with master_attributes' do
        let(:raw_params) do
          {
            master_attributes: {
              prices_attributes: {
                '0' => { amount: '10.00' }
              }
            }
          }
        end

        it 'removes prices_attributes from master' do
          expect(prepared_params[:master_attributes]).not_to have_key(:prices_attributes)
        end
      end
    end

    context 'when user can update prices' do
      context 'when price amount is blank' do
        let(:raw_params) do
          {
            variants_attributes: {
              '0' => {
                id: variant.id,
                prices_attributes: {
                  '0' => {
                    id: variant.price_in('USD').id,
                    amount: ''
                  }
                }
              }
            }
          }
        end

        it 'marks the price for destruction' do
          expect(prepared_params[:variants_attributes]['0'][:prices_attributes]['0']['_destroy']).to eq('1')
        end
      end
    end
  end

  describe 'variant removal handling' do
    let(:option_type) { create(:option_type) }
    let(:variant) { create(:variant, product: product) }

    let(:new_option_value) { create(:option_value, option_type: option_type) }
    let(:new_variant) { create(:variant, product: product) }
    let(:variants_attributes) do
      {
        '0' => {
          id: new_variant.id.to_s,
          options: [
            {
              id: option_type.id,
              name: option_type.name,
              position: '0',
              option_value_name: new_option_value.name,
              option_value_presentation: new_option_value.presentation
            }
          ]
        }
      }
    end

    context 'when a variant is only omitted from variants_attributes' do
      before { variant } # ensure variant exists before service runs

      let(:raw_params) { { variants_attributes: variants_attributes } }

      it 'does not mark the omitted variant for destruction' do
        removed = prepared_params[:variants_attributes].values.find { |v| v[:id] == variant.id.to_s }
        expect(removed).to be_nil
      end

      it 'does not collect the omitted variant for discontinuation' do
        prepared_params
        expect(service.variants_to_discontinue).to be_empty
      end
    end

    context 'when no variants_attributes and no removals are submitted' do
      before { variant } # ensure variant exists before service runs

      let(:raw_params) { { name: 'Updated Product' } }

      it 'leaves the variants untouched' do
        expect(prepared_params[:variants_attributes]).to be_nil
      end

      it 'does not clear the option types' do
        expect(prepared_params).not_to have_key(:option_type_ids)
      end
    end

    context 'when a variant is explicitly removed' do
      let(:raw_params) do
        {
          removed_variant_ids: [variant.id.to_s],
          variants_attributes: variants_attributes
        }
      end

      it 'marks the variant for destruction' do
        removed = prepared_params[:variants_attributes].values.find { |v| v[:id] == variant.id.to_s }
        expect(removed[:_destroy]).to eq('1')
      end

      it 'does not collect the variant for discontinuation' do
        prepared_params
        expect(service.variants_to_discontinue).not_to include(variant)
      end

      it 'consumes the removed_variant_ids param' do
        expect(prepared_params).not_to have_key(:removed_variant_ids)
      end

      context 'when the variant is also re-submitted in variants_attributes' do
        let(:raw_params) do
          {
            removed_variant_ids: [variant.id.to_s],
            variants_attributes: variants_attributes.merge(
              '1' => {
                id: variant.id.to_s,
                options: [
                  {
                    id: option_type.id,
                    name: option_type.name,
                    position: '0',
                    option_value_name: new_option_value.name,
                    option_value_presentation: new_option_value.presentation
                  }
                ]
              }
            )
          }
        end

        it 'keeps the variant' do
          removed = prepared_params[:variants_attributes].values.find { |v| v[:id] == variant.id.to_s && v[:_destroy].present? }
          expect(removed).to be_nil
        end
      end

      context 'when the user cannot destroy variants' do
        before do
          ability.cannot :destroy, Spree::Variant
        end

        it 'ignores the removals' do
          removed = prepared_params[:variants_attributes].values.find { |v| v[:id] == variant.id.to_s }
          expect(removed).to be_nil
        end
      end
    end

    context 'when a removed variant belongs to another product' do
      let(:other_variant) { create(:variant) }
      let(:raw_params) do
        {
          removed_variant_ids: [other_variant.id.to_s],
          variants_attributes: variants_attributes
        }
      end

      it 'ignores the foreign variant id' do
        removed = prepared_params[:variants_attributes].values.find { |v| v[:id] == other_variant.id.to_s }
        expect(removed).to be_nil
      end
    end

    context 'when all variants are removed without variants_attributes' do
      let(:raw_params) { { name: 'Updated Product', removed_variant_ids: [variant.id.to_s] } }

      it 'marks the variant for destruction' do
        removed = prepared_params[:variants_attributes].values.find { |v| v[:id] == variant.id.to_s }
        expect(removed[:_destroy]).to eq('1')
      end

      it 'clears the option types' do
        expect(prepared_params[:option_type_ids]).to eq([])
      end

      context 'when the user cannot destroy variants' do
        before do
          ability.cannot :destroy, Spree::Variant
        end

        it 'ignores the removals and keeps the option types' do
          expect(prepared_params[:variants_attributes]).to be_nil
          expect(prepared_params).not_to have_key(:option_type_ids)
        end
      end
    end

    context 'when only some variants are removed without variants_attributes' do
      before { new_variant } # ensure the second variant exists before service runs

      let(:raw_params) { { name: 'Updated Product', removed_variant_ids: [variant.id.to_s] } }

      it 'marks only the removed variant for destruction' do
        expect(prepared_params[:variants_attributes].values.map { |v| v[:id] }).to eq([variant.id.to_s])
      end

      it 'does not clear the option types' do
        expect(prepared_params).not_to have_key(:option_type_ids)
      end
    end

    context 'when a removed variant has completed orders' do
      before do
        create(:completed_order_with_totals, variants: [variant])
      end

      context 'via variants_attributes' do
        let(:raw_params) do
          {
            removed_variant_ids: [variant.id.to_s],
            variants_attributes: variants_attributes
          }
        end

        it 'collects the variant for discontinuation' do
          prepared_params
          expect(service.variants_to_discontinue).to include(variant)
        end

        it 'does not include the variant in removal attributes' do
          removed = prepared_params[:variants_attributes].values.find { |v| v[:id] == variant.id.to_s }
          expect(removed).to be_nil
        end
      end

      context 'without variants_attributes' do
        let(:raw_params) { { name: 'Updated Product', removed_variant_ids: [variant.id.to_s] } }

        it 'collects the variant for discontinuation' do
          prepared_params
          expect(service.variants_to_discontinue).to include(variant)
        end

        it 'does not include the variant in destruction attributes' do
          removed = prepared_params[:variants_attributes]&.values&.find { |v| v[:id] == variant.id.to_s }
          expect(removed).to be_nil
        end
      end
    end

    context 'when removing a mix of variants with and without completed orders' do
      let(:variant_with_order) { create(:variant, product: product) }
      let(:variant_without_order) { create(:variant, product: product) }

      before do
        create(:completed_order_with_totals, variants: [variant_with_order])
      end

      let(:raw_params) do
        {
          name: 'Updated Product',
          removed_variant_ids: [variant_with_order.id.to_s, variant_without_order.id.to_s]
        }
      end

      it 'collects the variant with completed orders for discontinuation' do
        prepared_params
        expect(service.variants_to_discontinue).to include(variant_with_order)
      end

      it 'does not include the collected variant in removal attributes' do
        removed = prepared_params[:variants_attributes].values.find { |v| v[:id] == variant_with_order.id.to_s }
        expect(removed).to be_nil
      end

      it 'marks the variant without completed orders for destruction' do
        removed = prepared_params[:variants_attributes].values.find { |v| v[:id] == variant_without_order.id.to_s }
        expect(removed[:_destroy]).to eq('1')
      end
    end
  end

  describe 'legacy_product_publications_attributes handling' do
    let(:channel) { create(:channel, store: store) }
    let(:raw_params) do
      {
        legacy_product_publications_attributes: {
          '0' => { channel_id: channel.id, _destroy: '0' }
        }
      }
    end

    context 'when user cannot manage publications' do
      before do
        ability.cannot :manage, Spree::ProductPublication
      end

      it 'strips the publications attributes' do
        expect(prepared_params).not_to have_key(:legacy_product_publications_attributes)
      end
    end

    context 'when user can manage publications' do
      it 'preserves the publications attributes' do
        expect(prepared_params[:legacy_product_publications_attributes]['0'][:channel_id]).to eq(channel.id)
      end
    end
  end

  describe 'stock_items_attributes handling' do
    let(:variant) { product.master }

    context 'when user cannot update stock items' do
      before do
        ability.cannot :manage, Spree::StockItem
      end

      context 'with variants_attributes' do
        let(:raw_params) do
          {
            variants_attributes: {
              '0' => {
                id: variant.id,
                stock_items_attributes: {
                  '0' => { count_on_hand: 10 }
                }
              }
            }
          }
        end

        it 'removes stock_items_attributes from variants' do
          expect(prepared_params[:variants_attributes]['0']).not_to have_key(:stock_items_attributes)
        end
      end

      context 'with master_attributes' do
        let(:raw_params) do
          {
            master_attributes: {
              stock_items_attributes: {
                '0' => { count_on_hand: 10 }
              }
            }
          }
        end

        it 'removes stock_items_attributes from master' do
          expect(prepared_params[:master_attributes]).not_to have_key(:stock_items_attributes)
        end
      end
    end
  end
end
