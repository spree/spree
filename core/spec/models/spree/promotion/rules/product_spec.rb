require 'spec_helper'

describe Spree::Promotion::Rules::Product, type: :model do
  let(:rule) { Spree::Promotion::Rules::Product.new(rule_options) }
  let(:rule_options) { {} }

  context '#eligible?(order)' do
    let(:order) { Spree::Order.new }

    before do
      3.times { |i| instance_variable_set("@product#{i}", mock_model(Spree::Product)) }
    end

    it 'is eligible if there are no products' do
      allow(rule).to receive_messages(eligible_products: [])
      expect(rule).to be_eligible(order)
    end

    context "with 'any' match policy" do
      let(:rule_options) { super().merge(preferred_match_policy: 'any') }

      it 'is eligible if any of the products is in eligible products' do
        allow(order).to receive_messages(products: [@product1, @product2])
        allow(rule).to receive_messages(eligible_products: [@product2, @product3])
        expect(rule).to be_eligible(order)
      end

      context 'when none of the products are eligible products' do
        before do
          allow(order).to receive_messages(products: [@product1])
          allow(rule).to receive_messages(eligible_products: [@product2, @product3])
        end

        it { expect(rule).not_to be_eligible(order) }
        it 'sets an error message' do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq 'You need to add an applicable product before applying this coupon code.'
        end
      end
    end

    context "with 'all' match policy" do
      let(:rule_options) { super().merge(preferred_match_policy: 'all') }

      it 'is eligible if all of the eligible products are ordered' do
        allow(order).to receive_messages(products: [@product3, @product2, @product1])
        allow(rule).to receive_messages(eligible_products: [@product2, @product3])
        expect(rule).to be_eligible(order)
      end

      context 'when any of the eligible products is not ordered' do
        before do
          allow(order).to receive_messages(products: [@product1, @product2])
          allow(rule).to receive_messages(eligible_products: [@product1, @product2, @product3])
        end

        it { expect(rule).not_to be_eligible(order) }
        it 'sets an error message' do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq "This coupon code can't be applied because you don't have all of the necessary products in your cart."
        end
      end
    end

    context "with 'none' match policy" do
      let(:rule_options) { super().merge(preferred_match_policy: 'none') }

      it "is eligible if none of the order's products are in eligible products" do
        allow(order).to receive_messages(products: [@product1])
        allow(rule).to receive_messages(eligible_products: [@product2, @product3])
        expect(rule).to be_eligible(order)
      end

      context "when any of the order's products are in eligible products" do
        before do
          allow(order).to receive_messages(products: [@product1, @product2])
          allow(rule).to receive_messages(eligible_products: [@product2, @product3])
        end

        it { expect(rule).not_to be_eligible(order) }
        it 'sets an error message' do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq 'Your cart contains a product that prevents this coupon code from being applied.'
        end
      end
    end
  end

  describe '#actionable?' do
    subject do
      rule.actionable?(line_item)
    end

    let(:rule_line_item) { Spree::LineItem.new(product: rule_product) }
    let(:other_line_item) { Spree::LineItem.new(product: other_product) }

    let(:rule_options) { super().merge(products: [rule_product]) }
    let(:rule_product) { mock_model(Spree::Product) }
    let(:other_product) { mock_model(Spree::Product) }

    context "with 'any' match policy" do
      let(:rule_options) { super().merge(preferred_match_policy: 'any') }

      context 'for product in rule' do
        let(:line_item) { rule_line_item }

        it { is_expected.to be_truthy }
      end

      context 'for product not in rule' do
        let(:line_item) { other_line_item }

        it { is_expected.to be_falsey }
      end
    end

    context "with 'all' match policy" do
      let(:rule_options) { super().merge(preferred_match_policy: 'all') }

      context 'for product in rule' do
        let(:line_item) { rule_line_item }

        it { is_expected.to be_truthy }
      end

      context 'for product not in rule' do
        let(:line_item) { other_line_item }

        it { is_expected.to be_falsey }
      end
    end

    context "with 'none' match policy" do
      let(:rule_options) { super().merge(preferred_match_policy: 'none') }

      context 'for product in rule' do
        let(:line_item) { rule_line_item }

        it { is_expected.to be_falsey }
      end

      context 'for product not in rule' do
        let(:line_item) { other_line_item }

        it { is_expected.to be_truthy }
      end
    end
  end
end
