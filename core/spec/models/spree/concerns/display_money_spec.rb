require 'spec_helper'

module Spree

  describe DisplayMoney do
    let(:test_class) do
      Class.new do
        extend DisplayMoney
        def total; 10.0; end
      end
    end

    describe ".money_methods" do
      before { test_class.money_methods :total }

      context "currency is not defined" do
        it "generates a display_method that builds a Spree::Money without options" do
          expect(test_class.new.display_total).to eq Spree::Money.new(10.0)
        end
      end

      context "currency is defined" do
        before { test_class.class_eval { def currency; "USD"; end } }

        it "generates a display_* method that builds a Spree::Money with currency" do
          expect(test_class.new.display_total).to eq Spree::Money.new(10.0, currency: "USD")
        end
      end

      context "with multiple + options" do
        before do
          test_class.class_eval { def amount; 20.0; end }
          test_class.money_methods :total, amount: { no_cents: true }
        end

        it "generates a display_* method that builds a Spree::Money with the specified options" do
          expect(test_class.new.display_total).to eq Spree::Money.new(10.0)
          expect(test_class.new.display_amount).to eq Spree::Money.new(20.0, no_cents: true)
        end
      end

      context "with 10% vat" do
        before do
          test_class.class_eval do
            def included_tax_amount
              0.1
            end
          end
        end

        it "generates a display_*_adding_vat method that builds a Spree::Money that adds vat on the fly" do
          expect(test_class.new.display_total_adding_vat).to eq(Spree::Money.new(11.0))
        end
      end
    end
  end
end
