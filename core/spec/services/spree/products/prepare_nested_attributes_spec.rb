require 'spec_helper'

RSpec.describe Spree::Products::PrepareNestedAttributes do
  subject(:prepared_params) { described_class.new(product, store, params, ability).call }

  let(:ability) { Spree::Ability.new(nil) }
  let(:store) { create(:store) }
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

  describe 'product_properties_attributes handling' do
    context 'when product property value is blank' do
      let(:product_property) { create(:product_property, product: product) }
      let(:raw_params) do
        {
          product_properties_attributes: {
            '0' => {
              id: product_property.id,
              value: ''
            }
          }
        }
      end

      it 'marks the product property for destruction' do
        expect(prepared_params[:product_properties_attributes]['0']['_destroy']).to eq('1')
      end
    end

    context 'when product property value is present' do
      let(:product_property) { create(:product_property, product: product) }
      let(:raw_params) do
        {
          product_properties_attributes: {
            '0' => {
              id: product_property.id,
              value: 'New Value'
            }
          }
        }
      end

      it 'does not mark the product property for destruction' do
        expect(prepared_params[:product_properties_attributes]['0']['_destroy']).to be_nil
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
        let(:price) { create(:price, variant: variant) }
        let(:raw_params) do
          {
            variants_attributes: {
              '0' => {
                id: variant.id,
                prices_attributes: {
                  '0' => {
                    id: price.id,
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
