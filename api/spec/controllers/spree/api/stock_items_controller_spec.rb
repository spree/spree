require 'spec_helper'

module Spree
  describe Api::StockItemsController do
    render_views

    let!(:stock_location) { create(:stock_location_with_items) }
    let!(:stock_item) { stock_location.stock_items.order(:id).first }
    let!(:attributes) { [:id, :count_on_hand, :backorderable,
                         :stock_location_id, :variant_id] }

    before do
      stub_authentication!
    end

    it 'gets list of stock items' do
      api_get :index, stock_location_id: stock_location.to_param
      json_response['stock_items'].first.should have_attributes(attributes)
      json_response['stock_items'].first['variant']['sku'].should eq 'ABC'
    end

    it 'requires a stock_location_id to be passed as a parameter' do
      api_get :index
      json_response['error'].should =~ /stock_location_id parameter must be provided/
      response.status.should == 422
    end

    it 'can control the page size through a parameter' do
      api_get :index, stock_location_id: stock_location.to_param, per_page: 1
      json_response['count'].should == 1
      json_response['current_page'].should == 1
    end

    it 'can query the results through a paramter' do
      stock_item.update_column(:count_on_hand, 30)
      api_get :index, stock_location_id: stock_location.to_param, q: { count_on_hand_eq: '30' }
      json_response['count'].should == 1
      json_response['stock_items'].first['count_on_hand'].should eq 30
    end

    it 'gets a stock item' do
      api_get :show, stock_location_id: stock_location.to_param, id: stock_item.to_param
      json_response.should have_attributes(attributes)
      json_response['count_on_hand'].should eq stock_item.count_on_hand
    end

    context 'as an admin' do
      sign_in_as_admin!

      it 'can create a new stock item' do
        variant = create(:variant)
        variant.stock_items.delete_all
        params = {
          stock_location_id: stock_location.to_param,
          stock_item: {
            variant_id: variant.id,
            count_on_hand: '20'
          }
        }

        api_post :create, params
        response.status.should == 201
        json_response.should have_attributes(attributes)
      end

      it 'can update a stock item to add new inventory' do
        stock_item.count_on_hand.should == 10
        params = {
          id: stock_item.to_param,
          stock_item: {
            count_on_hand: 40,
          }
        }

        api_put :update, params
        response.status.should == 200
        json_response['count_on_hand'].should eq 50
      end

      it 'can delete a stock item' do
        api_delete :destroy, id: stock_item.to_param
        response.status.should == 204
        lambda { stock_item.reload }.should raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end

