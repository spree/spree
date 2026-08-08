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
          let!(:tax_rate) { create(:tax_rate, zone: default_tax_zone) }

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

          let(:default_zone) { create(:zone_with_country, default_tax: true) }
          let!(:default_vat) do
            create :tax_rate,
                   included_in_price: true,
                   zone: default_zone,
                   amount: 0.2,
                   tax_category: shipping_method.tax_category
          end

          context 'when the order does not have a tax zone' do
            before { allow(order).to receive(:tax_zone).and_return nil }

            it_behaves_like 'shipping rate matches'
          end

          context "when the order's tax zone is the default zone" do
            before { allow(order).to receive(:tax_zone).and_return(default_zone) }

            it_behaves_like 'shipping rate matches'
          end

          context "when the order's tax zone is a non-VAT zone" do
            let!(:zone_without_vat) { create(:zone_with_country) }

            before { allow(order).to receive(:tax_zone).and_return(zone_without_vat) }

            it 'deducts the default VAT from the cost' do
              delivery_rates = subject.delivery_rates(package)
              # deduct default vat: 4.00 / 1.2 = 3.33 (rounded)
              expect(delivery_rates.first.cost).to eq(3.33)
            end
          end

          context "when the order's tax zone is a zone with VAT outside the default zone" do
            let(:other_vat_zone) { create(:zone_with_country) }
            let!(:other_vat) do
              create :tax_rate,
                     included_in_price: true,
                     zone: other_vat_zone,
                     amount: 0.3,
                     tax_category: shipping_method.tax_category
            end

            before { allow(order).to receive(:tax_zone).and_return(other_vat_zone) }

            it 'deducts the default vat and applies the foreign vat to calculate the price' do
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

      # Quoting dispatches through the method's rate provider, so a carrier
      # provider replaces calculator pricing while the surrounding filtering,
      # tax and sorting behavior stays identical.
      describe 'rate provider dispatch' do
        let(:delivery_method) { create(:delivery_method) }
        let(:package) { build(:stock_package, contents: inventory_units.map { |_i| ContentItem.new(inventory_unit) }) }

        before do
          allow(package).to receive_messages(eligible_delivery_methods: [delivery_method])
        end

        it 'defaults to the Internal provider, pricing through the calculator' do
          expect(delivery_method.rate_provider_instance).to be_a(Spree::DeliveryRateProvider::Internal)

          allow(delivery_method.calculator).to receive(:compute).and_return(7.00)

          expect(subject.delivery_rates(package).first.cost).to eq(7.00)
        end

        it 'prices through a configured external provider instead of the calculator' do
          provider_class = Class.new(Spree::DeliveryRateProvider::Base) do
            def estimate(_package)
              Spree::DeliveryRateProvider::Estimate.new(cost: BigDecimal('9.99'), carrier: 'UPS')
            end
          end
          stub_const('CarrierRateProvider', provider_class)

          allow(delivery_method).to receive(:rate_provider_instance).and_return(provider_class.new(delivery_method))
          expect(delivery_method.calculator).not_to receive(:compute)

          expect(subject.delivery_rates(package).first.cost).to eq(BigDecimal('9.99'))
        end

        it 'carries the carrier metadata from the estimate onto the rate' do
          provider_class = Class.new(Spree::DeliveryRateProvider::Base) do
            def estimate(_package)
              Spree::DeliveryRateProvider::Estimate.new(
                cost: BigDecimal('9.99'),
                carrier: 'UPS',
                service_level: 'Ground',
                estimated_delivery_date: Date.new(2026, 8, 20),
                metadata: { 'quote_id' => 'rate_123' }
              )
            end
          end
          stub_const('EnrichedRateProvider', provider_class)

          allow(delivery_method).to receive(:rate_provider_instance).and_return(provider_class.new(delivery_method))

          rate = subject.delivery_rates(package).first
          expect(rate.carrier).to eq('UPS')
          expect(rate.service_level).to eq('Ground')
          expect(rate.estimated_delivery_date).to eq(Date.new(2026, 8, 20))
          expect(rate.metadata['quote_id']).to eq('rate_123')
        end

        it 'suppresses the method when the provider returns no estimate' do
          provider_class = Class.new(Spree::DeliveryRateProvider::Base) do
            def estimate(_package) = nil
          end
          stub_const('EmptyRateProvider', provider_class)

          allow(delivery_method).to receive(:rate_provider_instance).and_return(provider_class.new(delivery_method))

          expect(subject.delivery_rates(package)).to be_empty
        end
      end
    end
  end
end
