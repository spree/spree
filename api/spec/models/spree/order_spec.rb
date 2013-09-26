require 'spec_helper'

module Spree
  describe Order do
    let!(:country) { create(:country) }
    let!(:state) { country.states.first || create(:state, :country => country) }
    let!(:stock_location) { create(:stock_location) }

    let(:user) { stub_model(LegacyUser, :email => 'fox@mudler.com') }
    let(:shipping_method) { create(:shipping_method) }
    let(:payment_method) { create(:payment_method) }

    let(:product) { product = Spree::Product.create(:name => 'Test',
                                           :sku => 'TEST-1',
                                           :price => 33.22)
                    product.shipping_category = create(:shipping_category)
                    product.save
                    product }

    let(:variant) { variant = product.master
                    variant.stock_items.each { |si| si.update_attribute(:count_on_hand, 10) }
                    variant }

    let(:sku) { variant.sku }
    let(:variant_id) { variant.id }

    let(:line_items) {{ "0" => { :variant_id => variant.id, :quantity => 5 }}}
    let(:ship_address) {{
       :address1 => '123 Testable Way',
       :firstname => 'Fox',
       :lastname => 'Mulder',
       :city => 'Washington',
       :country_id => country.id,
       :state_id => state.id,
       :zipcode => '666',
       :phone => '666-666-6666'
    }}

    it 'can import an order number' do
      params = { number: '123-456-789' }
      order = Order.build_from_api(user, params)
      order.number.should eq '123-456-789'
    end

    it 'optionally add completed at' do
      params = { email: 'test@test.com',
                 completed_at: Time.now,
                 line_items_attributes: line_items }

      order = Order.build_from_api(user, params)
      order.should be_completed
      order.state.should eq 'complete'
    end

    it 'can build an order from API with just line items' do
      params = { :line_items_attributes => line_items }

      Order.should_receive(:ensure_variant_id_from_api)
      order = Order.build_from_api(user, params)
      order.user.should == nil
      line_item = order.line_items.first
      line_item.quantity.should == 5
      line_item.variant_id.should == variant_id
    end

    it 'handles line_item building exceptions' do
      line_items['0'][:variant_id] = 'XXX'
      params = { :line_items_attributes => line_items }

      expect {
        order = Order.build_from_api(user, params)
      }.to raise_error /XXX/
    end

    it 'can build an order from API with variant sku' do
      params = { :line_items_attributes => {
                   "0" => { :sku => sku, :quantity => 5 } }}

      order = Order.build_from_api(user, params)

      line_item = order.line_items.first
      line_item.variant_id.should == variant_id
      line_item.quantity.should == 5
    end

    it 'handles exceptions when sku is not found' do
      params = { :line_items_attributes => {
                   "0" => { :sku => 'XXX', :quantity => 5 } }}
      expect {
        order = Order.build_from_api(user, params)
      }.to raise_error /XXX/
    end

    it 'can build an order from API shipping address' do
      params = { :ship_address_attributes => ship_address,
                 :line_items_attributes => line_items }

      order = Order.build_from_api(user, params)
      order.ship_address.address1.should eq '123 Testable Way'
    end

    it 'can build an order from API with country attributes' do
      ship_address.delete(:country_id)
      ship_address[:country] = { 'iso' => 'US' }
      params = { :ship_address_attributes => ship_address,
                 :line_items_attributes => line_items }

      order = Order.build_from_api(user, params)
      order.ship_address.country.iso.should eq 'US'
    end

    it 'handles country lookup exceptions' do
      ship_address.delete(:country_id)
      ship_address[:country] = { 'iso' => 'XXX' }
      params = { :ship_address_attributes => ship_address,
                 :line_items_attributes => line_items }

      expect {
        order = Order.build_from_api(user, params)
      }.to raise_error /XXX/
    end

    it 'can build an order from API with state attributes' do
      ship_address.delete(:state_id)
      ship_address[:state] = { 'name' => 'Alabama' }
      params = { :ship_address_attributes => ship_address,
                 :line_items_attributes => line_items }

      order = Order.build_from_api(user, params)
      order.ship_address.state.name.should eq 'Alabama'
    end

    it 'handles state lookup exceptions' do
      ship_address.delete(:state_id)
      ship_address[:state] = { 'name' => 'XXX' }
      params = { :ship_address_attributes => ship_address,
                 :line_items_attributes => line_items }

      expect {
        order = Order.build_from_api(user, params)
      }.to raise_error /XXX/
    end

    context 'variant not deleted' do
      it 'ensures variant id from api' do
        hash = { sku: variant.sku }
        Order.ensure_variant_id_from_api(hash)
        expect(hash[:variant_id]).to eq variant.id
      end
    end

    context 'variant was deleted' do
      it 'raise error as variant shouldnt be found' do
        variant.product.destroy
        hash = { sku: variant.sku }
        expect {
          Order.ensure_variant_id_from_api(hash)
        }.to raise_error
      end
    end

    it 'ensures_country_id for country fields' do
      [:name, :iso, :iso_name, :iso3].each do |field|
        address = { :country => { field => country.send(field) }}
        Order.ensure_country_id_from_api(address)
        address[:country_id].should eq country.id
      end
    end

    it 'ensures_state_id for state fields' do
      [:name, :abbr].each do |field|
        address = { :state => { field => state.send(field) }}
        Order.ensure_state_id_from_api(address)
        address[:state_id].should eq state.id
      end
    end

    context "shippments" do
      let(:params) do
        { :shipments_attributes => [
            { :tracking => '123456789',
              :cost => '4.99',
              :shipping_method => shipping_method.name,
              :stock_location => stock_location.name,
              :inventory_units => [{ :sku => sku }]
            }
        ] }
      end

      it 'ensures variant exists and is not deleted' do
        Order.should_receive(:ensure_variant_id_from_api)
        order = Order.build_from_api(user, params)
      end

      it 'builds them properly' do
        order = Order.build_from_api(user, params)

        shipment = order.shipments.first
        shipment.inventory_units.first.variant_id.should eq product.master.id
        shipment.tracking.should eq '123456789'
        shipment.shipping_rates.first.cost.should eq 4.99
        shipment.stock_location.should eq stock_location
      end

      it "raises if cant find stock location" do
        params[:shipments_attributes][0][:stock_location] = "doesnt exist"
        expect {
          order = Order.build_from_api(user, params)
        }.to raise_error
      end
    end

    it 'handles shipment building exceptions' do
      params = { :shipments_attributes => [{ tracking: '123456789',
                                             cost: '4.99',
                                             shipping_method: 'XXX',
                                             inventory_units: [{ sku: sku }]
                                           }] }
      expect {
        order = Order.build_from_api(user, params)
      }.to raise_error /XXX/
    end

    it 'adds adjustments' do
      params = { :adjustments_attributes => [
          { "label" => "Shipping Discount", "amount" => "-4.99" },
          { "label" => "Promotion Discount", "amount" => "-3.00" }] }

      order = Order.build_from_api(user, params)
      order.adjustments.all?(&:finalized?).should be_true
      order.adjustments.first.label.should eq 'Shipping Discount'
      order.adjustments.first.amount.should eq -4.99
    end

    it 'handles adjustment building exceptions' do
      params = { :adjustments_attributes => [
          { "amount" => "XXX" },
          { "label" => "Promotion Discount", "amount" => "-3.00" }] }

      expect {
        order = Order.build_from_api(user, params)
      }.to raise_error /XXX/
    end

    it 'builds a payment' do
      params = { :payments_attributes => [{ amount: '4.99',
                                            payment_method: payment_method.name }] }
      order = Order.build_from_api(user, params)
      order.payments.first.amount.should eq 4.99
    end

    it 'handles payment building exceptions' do
      params = { :payments_attributes => [{ amount: '4.99',
                                            payment_method: 'XXX' }] }
      expect {
        order = Order.build_from_api(user, params)
      }.to raise_error /XXX/
    end
  end
end
