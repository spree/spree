require 'spec_helper'

module Spree
  describe Order do
    let(:user) { stub_model(LegacyUser) }
    let(:product) { create :product }
    let(:variant_id) { product.master.id }
    let(:sku) { product.master.sku }
    let(:line_items) {{ "0" => { :variant_id => variant_id, :quantity => 5 }}}
    let(:ship_address) {{
       :address1 => '123 Testable Way',
       :firstname => 'Fox',
       :lastname => 'Mulder',
       :city => 'Washington',
       :country_id => '1',
       :state_id => '1',
       :zipcode => '666',
       :phone => '666-666-6666'
     }}

    it 'can build an order from API with just line items' do
      params = { :line_items_attributes => line_items }

      order = Order.build_from_api(user, params)

      order.user.should == nil
      line_item = order.line_items.first
      line_item.quantity.should == 5
      line_item.variant_id.should == variant_id
    end

    it 'can build an order from API with variant sku' do
      params = { :line_items_attributes => {
                   "0" => { :sku => sku, :quantity => 5 } }}

      order = Order.build_from_api(user, params)

      line_item = order.line_items.first
      line_item.variant_id.should == variant_id
      line_item.quantity.should == 5
    end

    it 'can build an order from API with order attributes' do
      params = { :ship_address_attributes => ship_address,
                 :line_items_attributes => line_items }

      order = Order.build_from_api(user, params)
      order.ship_address.address1.should eq '123 Testable Way'
    end

    it 'can build an order from API with country attributes' do
      ship_address.delete(:country_id)
      ship_address[:country] = { :iso => 'US' }
      params = { :ship_address_attributes => ship_address,
                 :line_items_attributes => line_items }

      order = Order.build_from_api(user, params)
      order.ship_address.country.iso.should eq 'US'
    end

    it 'can build an order from API with state attributes' do
      ship_address.delete(:state_id)
      ship_address[:state] = { :name => 'Alabama' }
      params = { :ship_address_attributes => ship_address,
                 :line_items_attributes => line_items }

      order = Order.build_from_api(user, params)
      order.ship_address.state.name.should eq 'Alabama'
    end

    it 'ensures_country_id for country fields' do
      country = create(:country)
      [:name, :iso, :iso_name, :iso3].each do |field|
        address = { :country => { field => country.send(field) }}
        Order.ensure_country_id_from_api(address)
        address[:country_id].should eq country.id
      end
    end

    it 'ensures_state_id for state fields' do
      state = create(:state)
      [:name, :abbr].each do |field|
        address = { :state => { field => state.send(field) }}
        Order.ensure_state_id_from_api(address)
        address[:state_id].should eq state.id
      end
    end
  end
end
