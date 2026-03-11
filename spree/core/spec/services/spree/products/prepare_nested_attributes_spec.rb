require 'spec_helper'

RSpec.describe Spree::Products::PrepareNestedAttributes do
  let(:service) { described_class.new(product, store, params, ability) }
  subject(:prepared_params) { service.call }

  let(:ability) { Spree::Ability.new(nil) }
  let(:store) { @default_store }
  let(:other_store) { create(:store) }
  let(:product) { create(:product, stores: [store, other_store]) }
  let(:params) { ActionController::Parameters.new(raw_params) }
  let(:raw_params) { {} }

  before do
    ability.can :manage, :all
  end

  describe 'taxon preservation across stores' do
    let(:store_taxonomy) { create(:taxonomy, store: store) }
    let(:other_store_taxonomy) { create(:taxonomy, store: other_store) }
    let(:store_taxon) { create(:taxon, taxonomy: store_taxonomy) }
    let(:other_store_taxon) { create(:taxon, taxonomy: other_store_taxonomy) }

    context 'when editing a product with taxons from multiple stores' do
      before do
        product.taxons << [store_taxon, other_store_taxon]
      end

      context 'when updating taxon_ids from current store' do
        let(:new_store_taxon) { create(:taxon, taxonomy: store_taxonomy) }
        let(:raw_params) do
          {
            name: 'Updated Product',
            taxon_ids: [new_store_taxon.id.to_s]
          }
        end

        it 'preserves taxons from other stores' do
          expect(prepared_params[:taxon_ids]).to include(other_store_taxon.id.to_s)
        end

        it 'includes the new taxon from current store' do
          expect(prepared_params[:taxon_ids]).to include(new_store_taxon.id.to_s)
        end

        it 'removes the old taxon from current store' do
          expect(prepared_params[:taxon_ids]).not_to include(store_taxon.id.to_s)
        end

        it 'returns unique taxon IDs' do
          expect(prepared_params[:taxon_ids].uniq).to eq(prepared_params[:taxon_ids])
        end
      end

      context 'when removing all taxons from current store' do
        let(:raw_params) do
          {
            name: 'Updated Product',
            taxon_ids: []
          }
        end

        it 'preserves taxons from other stores' do
          expect(prepared_params[:taxon_ids]).to include(other_store_taxon.id.to_s)
        end

        it 'does not include taxons from current store' do
          expect(prepared_params[:taxon_ids]).not_to include(store_taxon.id.to_s)
        end
      end

      context 'when taxon_ids param is not present' do
        let(:raw_params) do
          {
            name: 'Updated Product'
          }
        end

        it 'does not add taxon_ids key' do
          expect(prepared_params).not_to have_key(:taxon_ids)
        end
      end
    end

    context 'when creating a new product' do
      let(:product) { build(:product, stores: [store]) }
      let(:raw_params) do
        {
          name: 'New Product',
          taxon_ids: [store_taxon.id.to_s]
        }
      end

      it 'does not merge taxons from other stores' do
        expect(prepared_params[:taxon_ids]).to eq([store_taxon.id.to_s])
      end

      it 'only includes submitted taxon IDs' do
        expect(prepared_params[:taxon_ids]).to contain_exactly(store_taxon.id.to_s)
      end
    end

    context 'when product has taxons from multiple other stores' do
      let(:third_store) { create(:store) }
      let(:third_store_taxonomy) { create(:taxonomy, store: third_store) }
      let(:third_store_taxon) { create(:taxon, taxonomy: third_store_taxonomy) }

      before do
        product.stores << third_store
        product.taxons << [store_taxon, other_store_taxon, third_store_taxon]
      end

      let(:new_store_taxon) { create(:taxon, taxonomy: store_taxonomy) }
      let(:raw_params) do
        {
          name: 'Updated Product',
          taxon_ids: [new_store_taxon.id.to_s]
        }
      end

      it 'preserves taxons from all other stores' do
        expect(prepared_params[:taxon_ids]).to include(other_store_taxon.id.to_s, third_store_taxon.id.to_s)
      end

      it 'includes the new taxon from current store' do
        expect(prepared_params[:taxon_ids]).to include(new_store_taxon.id.to_s)
      end

      it 'has exactly 3 taxon IDs' do
        expect(prepared_params[:taxon_ids].size).to eq(3)
      end
    end
  end

  describe 'store_ids handling' do
    context 'when store_ids is blank' do
      let(:raw_params) { { name: 'Product' } }

      it 'adds current store to store_ids' do
        expect(prepared_params[:store_ids]).to eq([store.id])
      end
    end

    context 'when store_ids is present' do
      let(:raw_params) { { name: 'Product', store_ids: [store.id, other_store.id] } }

      it 'preserves submitted store_ids' do
        expect(prepared_params[:store_ids]).to eq([store.id, other_store.id])
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
    let(:option_value) { create(:option_value, option_type: option_type) }
    let(:variant) { create(:variant, product: product) }

    context 'when variant has completed orders' do
      before do
        create(:completed_order_with_totals, variants: [variant])
      end

      context 'via variants_attributes' do
        let(:new_option_value) { create(:option_value, option_type: option_type) }
        let(:new_variant) { create(:variant, product: product) }
        let(:raw_params) do
          {
            variants_attributes: {
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

      context 'via fallback removal (no variants_attributes)' do
        let(:raw_params) { { name: 'Updated Product' } }

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

    context 'when variant has no completed orders' do
      before { variant } # ensure variant exists before service runs

      context 'via variants_attributes' do
        let(:new_option_value) { create(:option_value, option_type: option_type) }
        let(:new_variant) { create(:variant, product: product) }
        let(:raw_params) do
          {
            variants_attributes: {
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
      end

      context 'via fallback removal (no variants_attributes)' do
        let(:raw_params) { { name: 'Updated Product' } }

        it 'marks the variant for destruction' do
          removed = prepared_params[:variants_attributes].values.find { |v| v[:id] == variant.id.to_s }
          expect(removed[:_destroy]).to eq('1')
        end
      end
    end

    context 'when product has mix of variants with and without completed orders' do
      let(:variant_with_order) { create(:variant, product: product) }
      let(:variant_without_order) { create(:variant, product: product) }

      before do
        variant_without_order # ensure variant exists before service runs
        create(:completed_order_with_totals, variants: [variant_with_order])
      end

      let(:raw_params) { { name: 'Updated Product' } }

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
