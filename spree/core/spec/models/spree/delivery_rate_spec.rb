require 'spec_helper'

describe Spree::DeliveryRate, type: :model do
  let(:shipment) { create(:shipment) }
  let(:delivery_method) { create(:delivery_method) }
  let(:shipping_rate) do
    Spree::DeliveryRate.new shipment: shipment,
                            delivery_method: delivery_method,
                            cost: 10
  end

  context '#display_price' do
    context 'when tax included in price' do
      let(:default_tax_rate) do
        create :tax_rate,
               name: 'VAT',
               amount: 0.1,
               included_in_price: true,
               country: @default_country
      end

      context 'when the rate taxes the home country' do
        before { shipping_rate.tax_rate = default_tax_rate }

        it 'shows correct tax amount' do
          expect(shipping_rate.display_price.to_s).
            to eq("$10.00 (incl. $0.91 #{default_tax_rate.name})")
        end

        context 'when cost is zero' do
          before do
            shipping_rate.cost = 0
          end

          it 'shows no tax amount' do
            expect(shipping_rate.display_price.to_s).to eq('$0.00')
          end
        end
      end

      context 'when the rate taxes another country' do
        let(:non_default_tax_rate) do
          create :tax_rate,
                 name: 'VAT',
                 amount: 0.2,
                 included_in_price: true,
                 country: create(:country, iso: 'FR', name: 'France')
        end

        before { shipping_rate.tax_rate = non_default_tax_rate }

        it "deducts the other country's VAT from the calculated shipping rate" do
          expect(shipping_rate.display_price.to_s).
            to eq("$10.00 (incl. $1.67 #{non_default_tax_rate.name})")
        end

        context 'when cost is zero' do
          before do
            shipping_rate.cost = 0
          end

          it 'shows no tax amount' do
            expect(shipping_rate.display_price.to_s).to eq('$0.00')
          end
        end
      end
    end

    context 'when tax is additional to price' do
      let(:tax_rate) { create(:tax_rate, name: 'Sales Tax', amount: 0.1) }

      before { shipping_rate.tax_rate = tax_rate }

      it 'shows correct tax amount' do
        expect(shipping_rate.display_price.to_s).
          to eq("$10.00 (+ $1.00 #{tax_rate.name})")
      end

      context 'when cost is zero' do
        before do
          shipping_rate.cost = 0
        end

        it 'shows no tax amount' do
          expect(shipping_rate.display_price.to_s).to eq('$0.00')
        end
      end
    end

    context 'when the currency is JPY' do
      let(:shipping_rate) { Spree::ShippingRate.new(cost: 205) }

      before { allow(shipping_rate).to receive_messages(currency: 'JPY') }

      it 'displays the price in yen' do
        expect(shipping_rate.display_price.to_s).to eq('¥205')
      end
    end

    context 'when tax rate is not shown in label' do
      let(:tax_rate) { create(:tax_rate, name: 'Sales Tax', amount: 0.1, show_rate_in_label: false) }

      before { shipping_rate.tax_rate = tax_rate }

      it 'shows no tax amount' do
        expect(shipping_rate.display_price.to_s).to eq('$10.00')
      end
    end
  end

  # Regression test for #3829
  context '#delivery_method' do
    it 'can be retrieved' do
      expect(shipping_rate.delivery_method.reload).to eq(delivery_method)
    end

    it 'can be retrieved even when deleted' do
      delivery_method.update_column(:deleted_at, Time.current)
      shipping_rate.save
      shipping_rate.reload
      expect(shipping_rate.delivery_method).to eq(delivery_method)
    end
  end

  context '#tax_rate' do
    let!(:tax_rate) { create(:tax_rate) }

    before do
      shipping_rate.tax_rate = tax_rate
    end

    it 'can be retrieved' do
      expect(shipping_rate.tax_rate.reload).to eq(tax_rate)
    end

    it 'can be retrieved even when deleted' do
      tax_rate.update_column(:deleted_at, Time.current)
      shipping_rate.save
      shipping_rate.reload
      expect(shipping_rate.tax_rate).to eq(tax_rate)
    end
  end

  context '#tax_amount' do
    context 'without tax rate' do
      it 'returns 0.0' do
        expect(shipping_rate.tax_amount).to eq(0.0)
      end
    end
  end

  describe '#additional_tax_total' do
    context 'without tax rate' do
      it 'returns 0' do
        expect(shipping_rate.additional_tax_total).to eq(0)
      end
    end

    context 'with tax included in price' do
      let(:tax_rate) { create(:tax_rate, amount: 0.1, included_in_price: true) }

      before { shipping_rate.tax_rate = tax_rate }

      it 'returns 0' do
        expect(shipping_rate.additional_tax_total).to eq(0)
      end
    end

    context 'with tax additional to price' do
      let(:tax_rate) { create(:tax_rate, amount: 0.1, included_in_price: false) }

      before { shipping_rate.tax_rate = tax_rate }

      it 'returns the tax amount' do
        expect(shipping_rate.additional_tax_total).to eq(shipping_rate.tax_amount)
      end
    end
  end

  describe '#included_tax_total' do
    context 'without tax rate' do
      it 'returns 0' do
        expect(shipping_rate.included_tax_total).to eq(0)
      end
    end

    context 'with tax included in price' do
      let(:tax_rate) { create(:tax_rate, amount: 0.1, included_in_price: true) }

      before { shipping_rate.tax_rate = tax_rate }

      it 'returns the tax amount' do
        expect(shipping_rate.included_tax_total).to eq(shipping_rate.tax_amount)
      end
    end

    context 'with tax additional to price' do
      let(:tax_rate) { create(:tax_rate, amount: 0.1, included_in_price: false) }

      before { shipping_rate.tax_rate = tax_rate }

      it 'returns 0' do
        expect(shipping_rate.included_tax_total).to eq(0)
      end
    end
  end

  context '#final_price' do
    let(:free_shipping_promotion) { create(:free_shipping_promotion, code: 'freeship', kind: :coupon_code) }
    let(:order) { shipment.order }

    it 'returns 0 if free shipping promotion is applied' do
      order.coupon_code = free_shipping_promotion.code
      Spree::PromotionHandler::Coupon.new(order).apply
      expect(order.promotions).to include(free_shipping_promotion)
      expect(shipping_rate.final_price).to eq(0.0)
    end

    it 'returns 0 if cost is lesser than the discount amount' do
      allow_any_instance_of(Spree::ShippingRate).to receive_messages(discount_amount: -20.0)
      expect(shipping_rate.final_price).to eq(0.0)
    end

    it 'returns cost minus discount amount' do
      allow_any_instance_of(Spree::ShippingRate).to receive_messages(discount_amount: -5.0)
      expect(shipping_rate.final_price).to eq(5.0)
    end

    it 'does not return 0 when shipment is free because of selected shipping rate' do
      shipment.shipping_rates.update_all(selected: false)
      create(:shipping_rate, shipment: shipment, cost: 0, selected: true)
      shipment.reload.update_amounts

      expect(shipment.free?).to eq(true)
      expect(shipping_rate.final_price).to eq(10.0)
    end
  end

  describe '#delivery_range' do
    let(:delivery_method) { create(:delivery_method, estimated_transit_business_days_min: 1, estimated_transit_business_days_max: 2) }

    it 'returns the delivery range for the shipping method' do
      expect(shipping_rate.delivery_range).to eq('1-2')
    end
  end

  describe '#display_delivery_range' do
    let(:delivery_method) { create(:delivery_method, estimated_transit_business_days_min: 1, estimated_transit_business_days_max: 2) }

    it 'returns the display delivery range for the shipping method' do
      expect(shipping_rate.display_delivery_range).to eq('Delivery in 1-2 business days')
    end
  end

  describe '#free?' do
    subject { shipping_rate.free? }

    context 'when the shipping rate cost is 0' do
      let(:shipping_rate) { create(:shipping_rate, cost: 0) }

      it { is_expected.to be(true) }
    end

    context 'when the shipping rate cost is not 0' do
      let(:shipping_rate) { create(:shipping_rate, cost: 10) }

      let(:shipment) { shipping_rate.shipment }
      let(:order) { shipment.order }

      it { is_expected.to be(false) }

      context 'when the shipment has a free shipping promotion' do
        let(:free_shipping_promotion) { create(:free_shipping_promotion) }

        before do
          order.coupon_code = free_shipping_promotion.code
          Spree::PromotionHandler::Coupon.new(order).apply
        end

        it { is_expected.to be(true) }
      end

      context 'when the discount amount is equal to the cost' do
        before do
          allow(shipping_rate).to receive(:discount_amount).and_return(-10.0)
        end

        it { is_expected.to be(true) }
      end
    end
  end
end
