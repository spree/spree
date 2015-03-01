require 'spec_helper'

module Spree
  describe Api::StockItemsController, :type => :controller do
    render_views

    let!(:stock_location) { create(:stock_location_with_items) }
    let!(:stock_item) { stock_location.stock_items.order(:id).first }
    let!(:attributes) { [:id, :count_on_hand, :backorderable,
                         :stock_location_id, :variant_id] }

    before do
      stub_authentication!
    end

    context "as a normal user" do
      it "cannot list stock items for a stock location" do
        api_get :index, stock_location_id: stock_location.to_param
        expect(response.status).to eq(404)
      end

      it "cannot see a stock item" do
        api_get :show, stock_location_id: stock_location.to_param, id: stock_item.to_param
        expect(response.status).to eq(404)
      end

      it "cannot create a stock item" do
        variant = create(:variant)
        params = {
          stock_location_id: stock_location.to_param,
          stock_item: {
            variant_id: variant.id,
            count_on_hand: '20'
          }
        }

        api_post :create, params
        expect(response.status).to eq(404)
      end

      it "cannot update a stock item" do
        api_put :update, stock_location_id: stock_location.to_param,
          id: stock_item.to_param
        expect(response.status).to eq(404)
      end

      it "cannot destroy a stock item" do
        api_delete :destroy, stock_location_id: stock_location.to_param,
          id: stock_item.to_param
        expect(response.status).to eq(404)
      end
    end

    context "as an admin" do
      sign_in_as_admin!

      it 'cannot list of stock items' do
        api_get :index, stock_location_id: stock_location.to_param
        expect(json_response['stock_items'].first).to have_attributes(attributes)
        expect(json_response['stock_items'].first['variant']['sku']).to include 'SKU'
      end

      it 'requires a stock_location_id to be passed as a parameter' do
        api_get :index
        expect(json_response['error']).to match(/stock_location_id parameter must be provided/)
        expect(response.status).to eq(422)
      end

      it 'can control the page size through a parameter' do
        api_get :index, stock_location_id: stock_location.to_param, per_page: 1
        expect(json_response['count']).to eq(1)
        expect(json_response['current_page']).to eq(1)
      end

      it 'can query the results through a paramter' do
        stock_item.update_column(:count_on_hand, 30)
        api_get :index, stock_location_id: stock_location.to_param, q: { count_on_hand_eq: '30' }
        expect(json_response['count']).to eq(1)
        expect(json_response['stock_items'].first['count_on_hand']).to eq 30
      end

      it 'gets a stock item' do
        api_get :show, stock_location_id: stock_location.to_param, id: stock_item.to_param
        expect(json_response).to have_attributes(attributes)
        expect(json_response['count_on_hand']).to eq stock_item.count_on_hand
      end

      it 'can create a new stock item' do
        variant = create(:variant)
        # Creating a variant also creates stock items.
        # We don't want any to exist (as they would conflict with what we're about to create)
        StockItem.delete_all
        params = {
          stock_location_id: stock_location.to_param,
          stock_item: {
            variant_id: variant.id,
            count_on_hand: '20'
          }
        }

        api_post :create, params
        expect(response.status).to eq(201)
        expect(json_response).to have_attributes(attributes)
      end

      it 'can update a stock item to add new inventory' do
        expect(stock_item.count_on_hand).to eq(10)
        params = {
          id: stock_item.to_param,
          stock_item: {
            count_on_hand: 40,
          }
        }

        api_put :update, params
        expect(response.status).to eq(200)
        expect(json_response['count_on_hand']).to eq 50
      end

      it 'can set a stock item to modify the current inventory' do
        expect(stock_item.count_on_hand).to eq(10)

        params = {
          id: stock_item.to_param,
          stock_item: {
            count_on_hand: 40,
            force: true,
          }
        }

        api_put :update, params
        expect(response.status).to eq(200)
        expect(json_response['count_on_hand']).to eq 40
      end

      it 'can delete a stock item' do
        api_delete :destroy, id: stock_item.to_param
        expect(response.status).to eq(204)
        expect { Spree::StockItem.find(stock_item.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
