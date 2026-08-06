require 'spec_helper'

module Spree
  module Stock
    describe Estimator, type: :model do
      subject { Estimator.new(order) }

      let!(:shipping_method) { create(:shipping_method) }
      let(:package)          { build(:stock_package, contents: inventory_units.map { |_i| ContentItem.new(inventory_unit) }) }
      let(:ship_address)     { create(:ship_address) }
      let(:order)            { build(:order_with_line_items, ship_address: ship_address) }
      let(:inventory_units)  { order.inventory_units }

      context '#shipping rates' do
        before do
          allow_any_instance_of(ShippingMethod).to receive_message_chain(:calculator, :available?).and_return(true)
          allow_any_instance_of(ShippingMethod).to receive_message_chain(:calculator, :compute).and_return(4.00)
          allow_any_instance_of(ShippingMethod).to receive_message_chain(:calculator, :preferences).and_return(currency: currency)
          allow_any_instance_of(ShippingMethod).to receive_message_chain(:calculator, :marked_for_destruction?)

          allow(package).to receive_messages(eligible_delivery_methods: [shipping_method])
        end

        let(:currency) { 'USD' }

        shared_examples_for 'shipping rate matches' do
          it 'returns shipping rates' do
            delivery_rates = subject.delivery_rates(package)
            expect(delivery_rates.first.cost).to eq 4.00
          end
        end

        shared_examples_for "shipping rate doesn't match" do
          it 'does not return shipping rates' do
            delivery_rates = subject.delivery_rates(package)
            expect(delivery_rates).to eq([])
          end
        end

        context "when the order's ship address is in the same zone" do
          it_behaves_like 'shipping rate matches'
        end

        context "when the order's ship address is in a different zone" do
          before do
            other_country = create(:country, iso: 'XZ', iso3: 'XZZ', name: 'Elsewhere', iso_name: 'ELSEWHERE')
            zone = create(:delivery_zone)
            zone.members.create!(member_type: 'country', country: other_country)
            shipping_method.delivery_zones = [zone]
          end

          it_behaves_like "shipping rate doesn't match"
        end

        context 'pickup methods are gated on the package source location' do
          let(:shipping_method) { create(:pickup_delivery_method) }

          context 'when the package is sourced from a plain warehouse' do
            it_behaves_like "shipping rate doesn't match"
          end

          context 'when the package is sourced from a pickup-enabled location' do
            let(:package) do
              build(:stock_package,
                    stock_location: create(:stock_location, pickup_enabled: true),
                    contents: inventory_units.map { |_i| ContentItem.new(inventory_unit) })
            end

            it_behaves_like 'shipping rate matches'
          end

          context 'when a ship-to-store counter accepts remote stock' do
            let!(:any_policy_counter) { create(:stock_location, pickup_enabled: true, pickup_stock_policy: 'any') }

            it_behaves_like 'shipping rate matches'
          end
        end

        context 'when the calculator is not available for that order' do
          before { allow_any_instance_of(ShippingMethod).to receive_message_chain(:calculator, :available?).and_return(false) }

          it_behaves_like "shipping rate doesn't match"
        end

        context 'when the currency is nil' do
          let(:currency) { nil }

          it_behaves_like 'shipping rate matches'
        end

        context 'when the currency is an empty string' do
          let(:currency) { '' }

          it_behaves_like 'shipping rate matches'
        end

        context "when the current matches the order's currency" do
          it_behaves_like 'shipping rate matches'
        end

        context "if the currency is different than the order's currency" do
          let(:currency) { 'GBP' }

          it_behaves_like "shipping rate doesn't match"
        end

        it 'sorts shipping rates by cost' do
          shipping_methods = Array.new(3) { create(:shipping_method) }
          allow(shipping_methods[0]).to receive_message_chain(:calculator, :compute).and_return(5.00)
          allow(shipping_methods[1]).to receive_message_chain(:calculator, :compute).and_return(3.00)
          allow(shipping_methods[2]).to receive_message_chain(:calculator, :compute).and_return(4.00)

          allow(subject).to receive(:delivery_methods).and_return(shipping_methods)

          expect(subject.delivery_rates(package).map(&:cost)).to eq [3.00, 4.00, 5.00]
        end

        context 'general shipping methods' do
          let(:shipping_methods) { Array.new(2) { create(:shipping_method) } }

          it 'selects the most affordable shipping rate' do
            allow(shipping_methods[0]).to receive_message_chain(:calculator, :compute).and_return(5.00)
            allow(shipping_methods[1]).to receive_message_chain(:calculator, :compute).and_return(3.00)

            allow(subject).to receive(:delivery_methods).and_return(shipping_methods)

            expect(subject.delivery_rates(package).sort_by(&:cost).map(&:selected)).to eq [true, false]
          end

          it "selects the most affordable shipping rate and doesn't raise exception over nil cost" do
            allow(shipping_methods[0]).to receive_message_chain(:calculator, :compute).and_return(1.00)
            allow(shipping_methods[1]).to receive_message_chain(:calculator, :compute).and_return(nil)

            allow(subject).to receive(:delivery_methods).and_return(shipping_methods)

            subject.delivery_rates(package)
          end
        end

        context 'involves backend only shipping methods' do
          let(:backend_method) { create(:shipping_method, storefront_visible: false) }
          let(:generic_method) { create(:shipping_method) }

          before do
            allow(backend_method).to receive_message_chain(:calculator, :compute).and_return(0.00)
            allow(generic_method).to receive_message_chain(:calculator, :compute).and_return(5.00)
            allow(package).to receive(:eligible_delivery_methods).and_return([backend_method, generic_method])
          end

          it 'does not return backend rates at all' do
            expect(subject.delivery_rates(package).map(&:shipping_method_id)).to eq([generic_method.id])
          end

          # regression for #3287
          it "doesn't select backend rates even if they're more affordable" do
            expect(subject.delivery_rates(package).map(&:selected)).to eq [true]
          end
        end

        context 'includes tax adjustments if applicable' do
          let!(:default_tax_zone) do
            create(:zone, default_tax: true, kind: 'country').tap do |zone|
              zone.zone_members.create!(zoneable: ship_address.country)
            end
          end
          let!(:tax_rate) { create(:tax_rate, country: order.tax_address.country) }

          before do
            Spree::ShippingMethod.all.each do |sm|
              sm.tax_category_id = tax_rate.tax_category_id
              sm.save
            end
            package.shipping_methods.map(&:reload)
          end

          it 'links the shipping rate and the tax rate' do
            delivery_rates = subject.delivery_rates(package)
            expect(delivery_rates.first.tax_rate).to eq(tax_rate)
          end
        end

        context 'VAT price calculation' do
          let(:tax_category) { create :tax_category }
          let!(:shipping_method) { create(:shipping_method, tax_category: tax_category) }

          # Shipping is priced including the home country's VAT.
          let(:home_country) { order.tax_address.country }
          let!(:default_vat) do
            create :tax_rate,
                   included_in_price: true,
                   country: home_country,
                   amount: 0.2,
                   tax_category: shipping_method.tax_category
          end

          before { @default_store.default_market.update!(countries: [home_country]) }

          context 'when the order has no address to tax against' do
            before { allow(order).to receive(:tax_address).and_return nil }

            it_behaves_like 'shipping rate matches'
          end

          context 'when the order ships within the home country' do
            it_behaves_like 'shipping rate matches'
          end

          context 'when the order ships to a country with no VAT' do
            let(:country_without_vat) { create(:country, iso: 'IN', name: 'India') }

            before do
              allow(order).to receive(:tax_address).
                and_return(create(:address, country: country_without_vat, state: nil,
                                            state_name: 'Delhi', zipcode: '110001'))
            end

            it 'deducts the home VAT from the cost' do
              delivery_rates = subject.delivery_rates(package)
              # deduct default vat: 4.00 / 1.2 = 3.33 (rounded)
              expect(delivery_rates.first.cost).to eq(3.33)
            end
          end

          context 'when the order ships to another country that charges VAT' do
            let(:other_country) { create(:country, iso: 'FR', name: 'France') }
            let!(:other_vat) do
              create :tax_rate,
                     included_in_price: true,
                     country: other_country,
                     amount: 0.3,
                     tax_category: shipping_method.tax_category
            end

            before do
              allow(order).to receive(:tax_address).
                and_return(create(:address, country: other_country, state: nil,
                                            state_name: 'Paris', zipcode: '75001'))
            end

            it 'deducts the home vat and applies the foreign vat to calculate the price' do
              delivery_rates = subject.delivery_rates(package)
              #
              # deduct default vat: 4.00 / 1.2 = 3.33 (rounded)
              # apply foreign vat: 3.33 * 1.3 = 4.33 (rounded)
              expect(delivery_rates.first.cost).to eq(4.33)
            end
          end
        end
      end

      # Host apps override the eligibility seam to add their own rules. The
      # 6.0 rename must not silently skip overrides written against the old
      # name — that would quote rates the host meant to filter out.
      describe 'eligibility seam overrides' do
        let(:package) { build(:stock_package, contents: inventory_units.map { |_i| ContentItem.new(inventory_unit) }) }

        it 'still invokes a legacy #shipping_methods override' do
          called = false
          estimator = Class.new(Estimator) do
            define_method(:shipping_methods) { |_pkg, _audience| called = true; [] }
          end.new(order)

          estimator.delivery_rates(package)
          expect(called).to be true
        end

        it 'invokes a modern #delivery_methods override' do
          called = false
          estimator = Class.new(Estimator) do
            define_method(:delivery_methods) { |_pkg, _audience| called = true; [] }
          end.new(order)

          estimator.delivery_rates(package)
          expect(called).to be true
        end
      end
    end
  end
end
