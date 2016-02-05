require "spec_helper"

module Spree
  describe VatPriceCalculation do
    let(:test_class) do
      Class.new do
        include VatPriceCalculation
        def total; 10.0; end
      end
    end

    describe "#gross_amount" do
      let(:zone) { Zone.new }
      let(:tax_category) { TaxCategory.new }
      let(:price_options) do
        {
          tax_zone: zone,
          tax_category: tax_category
        }
      end
      let(:amount) { 100 }

      subject(:gross_amount) { test_class.new.gross_amount(amount, price_options) }

      context "with no default zone set" do
        it "does not call TaxRate.included_tax_amount_for" do
          expect(TaxRate).not_to receive(:included_tax_amount_for)
          gross_amount
        end
      end

      context "with no zone given" do
        let(:zone) { nil }
        it "does not call TaxRate.included_tax_amount_for" do
          expect(TaxRate).not_to receive(:included_tax_amount_for)
          gross_amount
        end
      end

      context "with a default zone set" do
        let(:default_zone) { Spree::Zone.new }
        before do
          allow(Spree::Zone).to receive(:default_tax).and_return(default_zone)
        end

        context "and zone equal to the default zone" do
          let(:zone) { default_zone }

          it "does not call 'TaxRate.included_tax_amount_for'" do
            expect(TaxRate).not_to receive(:included_tax_amount_for)
            gross_amount
          end
        end

        context "and zone not equal to default zone" do
          let(:zone) { Spree::Zone.new }

          it "calls TaxRate.included_tax_amount_for two times" do
            expect(TaxRate).to receive(:included_tax_amount_for).twice
            gross_amount
          end
        end
      end
    end
  end
end
