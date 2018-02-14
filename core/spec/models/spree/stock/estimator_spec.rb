require 'spec_helper'

module Spree
  module Stock
    describe Estimator, type: :model do
      subject { Estimator.new(order) }

      let!(:shipping_method) { create(:shipping_method) }
      let(:package) { build(:stock_package, contents: inventory_units.map { |_i| ContentItem.new(inventory_unit) }) }
      let(:order) { build(:order_with_line_items) }
      let(:inventory_units) { order.inventory_units }

      context '#shipping rates' do
        before do
          shipping_method.zones.first.members.create(zoneable: order.ship_address.country)
          allow_any_instance_of(ShippingMethod).to receive_message_chain(:calculator, :available?).and_return(true)
          allow_any_instance_of(ShippingMethod).to receive_message_chain(:calculator, :compute).and_return(4.00)
          allow_any_instance_of(ShippingMethod).to receive_message_chain(:calculator, :preferences).and_return(currency: currency)
          allow_any_instance_of(ShippingMethod).to receive_message_chain(:calculator, :marked_for_destruction?)

          allow(package).to receive_messages(shipping_methods: [shipping_method])
        end

        let(:currency) { 'USD' }

        shared_examples_for 'shipping rate matches' do
          it 'returns shipping rates' do
            shipping_rates = subject.shipping_rates(package)
            expect(shipping_rates.first.cost).to eq 4.00
          end
        end

        shared_examples_for "shipping rate doesn't match" do
          it 'does not return shipping rates' do
            shipping_rates = subject.shipping_rates(package)
            expect(shipping_rates).to eq([])
          end
        end

        context "when the order's ship address is in the same zone" do
          it_behaves_like 'shipping rate matches'
        end

        context "when the order's ship address is in a different zone" do
          before { shipping_method.zones.each { |z| z.members.delete_all } }
          it_behaves_like "shipping rate doesn't match"
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

          allow(subject).to receive(:shipping_methods).and_return(shipping_methods)

          expect(subject.shipping_rates(package).map(&:cost)).to eq %w[3.00 4.00 5.00].map(&BigDecimal.method(:new))
        end

        context 'general shipping methods' do
          let(:shipping_methods) { Array.new(2) { create(:shipping_method) } }

          it 'selects the most affordable shipping rate' do
            allow(shipping_methods[0]).to receive_message_chain(:calculator, :compute).and_return(5.00)
            allow(shipping_methods[1]).to receive_message_chain(:calculator, :compute).and_return(3.00)

            allow(subject).to receive(:shipping_methods).and_return(shipping_methods)

            expect(subject.shipping_rates(package).sort_by(&:cost).map(&:selected)).to eq [true, false]
          end

          it "selects the most affordable shipping rate and doesn't raise exception over nil cost" do
            allow(shipping_methods[0]).to receive_message_chain(:calculator, :compute).and_return(1.00)
            allow(shipping_methods[1]).to receive_message_chain(:calculator, :compute).and_return(nil)

            allow(subject).to receive(:shipping_methods).and_return(shipping_methods)

            subject.shipping_rates(package)
          end
        end

        context 'involves backend only shipping methods' do
          let(:backend_method) { create(:shipping_method, display_on: 'back_end') }
          let(:generic_method) { create(:shipping_method) }

          before do
            allow(backend_method).to receive_message_chain(:calculator, :compute).and_return(0.00)
            allow(generic_method).to receive_message_chain(:calculator, :compute).and_return(5.00)
            allow(package).to receive(:shipping_methods).and_return([backend_method, generic_method])
          end

          it 'does not return backend rates at all' do
            expect(subject.shipping_rates(package).map(&:shipping_method_id)).to eq([generic_method.id])
          end

          # regression for #3287
          it "doesn't select backend rates even if they're more affordable" do
            expect(subject.shipping_rates(package).map(&:selected)).to eq [true]
          end
        end

        context 'includes tax adjustments if applicable' do
          let!(:tax_rate) { create(:tax_rate, zone: order.tax_zone) }

          before do
            Spree::ShippingMethod.all.each do |sm|
              sm.tax_category_id = tax_rate.tax_category_id
              sm.save
            end
            package.shipping_methods.map(&:reload)
          end

          it 'links the shipping rate and the tax rate' do
            shipping_rates = subject.shipping_rates(package)
            expect(shipping_rates.first.tax_rate).to eq(tax_rate)
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
              shipping_rates = subject.shipping_rates(package)
              # deduct default vat: 4.00 / 1.2 = 3.33 (rounded)
              expect(shipping_rates.first.cost).to eq(3.33)
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
              shipping_rates = subject.shipping_rates(package)
              #
              # deduct default vat: 4.00 / 1.2 = 3.33 (rounded)
              # apply foreign vat: 3.33 * 1.3 = 4.33 (rounded)
              expect(shipping_rates.first.cost).to eq(4.33)
            end
          end
        end
      end
    end
  end
end
