require 'spec_helper'

RSpec.describe Spree::Admin::StockTransfersController, type: :controller do
  stub_authorization!

  let(:source_location) { create(:stock_location) }
  let(:destination_location) { create(:stock_location) }
  let(:variant) { create(:variant) }
  let(:source_stock_item) { source_location.stock_item_or_create(variant) }
  let(:destination_stock_item) { destination_location.stock_item_or_create(variant) }

  before do
    source_stock_item.update(count_on_hand: 10)
    destination_stock_item.update(count_on_hand: 0)
  end

  describe '#create' do
    context 'when stock_movements_attributes are missing' do
      it 'renders the new template with an error' do
        post :create, params: { stock_transfer: { source_location_id: source_location.id, destination_location_id: destination_location.id } }

        expect(response).to render_template(:new)
        expect(response.status).to eq(422)
        expect(assigns(:object).errors).to contain_exactly(Spree.t('stock_transfer.errors.must_have_variant'))
      end
    end

    context 'when stock_movements_attributes are present' do
      it 'creates a stock transfer from source to destination and redirects to the stock transfer path' do
        post :create, params: {
          stock_transfer: {
            source_location_id: source_location.id,
            destination_location_id: destination_location.id,
            stock_movements_attributes: {
              '0' => { variant_id: variant.id, quantity: -10, location_id: source_location.id },
              '1' => { variant_id: variant.id, quantity: 10, location_id: destination_location.id }
            }
          }
        }

        expect(response).to redirect_to(spree.admin_stock_transfer_path(assigns(:object)))
        expect(assigns(:object).stock_movements.count).to eq(2)

        expect(source_location.stock_items.find_by(variant: variant).count_on_hand).to eq(0)
        expect(destination_location.stock_items.find_by(variant: variant).count_on_hand).to eq(10)
      end
    end

    context 'when location_id is null' do
      it 'creates a stock transfer to destination and redirects to the stock transfer path' do
        post :create, params: {
          stock_transfer: {
            source_location_id: source_location.id,
            destination_location_id: destination_location.id,
            stock_movements_attributes: {
              '0' => { variant_id: variant.id, quantity: 10, location_id: destination_location.id }
            }
          }
        }

        expect(response).to redirect_to(spree.admin_stock_transfer_path(assigns(:object)))
        expect(assigns(:object).stock_movements.count).to eq(1)

        expect(source_location.stock_items.find_by(variant: variant).count_on_hand).to eq(10)
        expect(destination_location.stock_items.find_by(variant: variant).count_on_hand).to eq(10)
      end
    end
  end
end
