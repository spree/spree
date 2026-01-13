require 'spec_helper'

describe Spree::Promotion::Rules::Product, type: :model do
  let(:rule) { Spree::Promotion::Rules::Product.new(rule_options) }
  let(:rule_options) { {} }

  describe '#eligible?(order)' do
    let(:order) { Spree::Order.new }
    let!(:products) { create_list(:product, 3) }
    let(:product1) { products.first }
    let(:product2) { products.second }
    let(:product3) { products.third }

    it 'is eligible if there are no products' do
      allow(rule).to receive_messages(eligible_product_ids: [])
      expect(rule).to be_eligible(order)
    end

    context "with 'any' match policy" do
      let(:rule_options) { super().merge(preferred_match_policy: 'any') }

      it 'is eligible if any of the products is in eligible products' do
        allow(order).to receive_messages(product_ids: [product1.id, product2.id])
        allow(rule).to receive_messages(eligible_product_ids: [product2.id, product3.id])
        expect(rule).to be_eligible(order)
      end

      context 'when none of the products are eligible products' do
        before do
          allow(order).to receive_messages(product_ids: [product1.id])
          allow(rule).to receive_messages(eligible_product_ids: [product2.id, product3.id])
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
        allow(order).to receive_messages(product_ids: [product3.id, product2.id, product1.id])
        allow(rule).to receive_messages(eligible_product_ids: [product2.id, product3.id])
        expect(rule).to be_eligible(order)
      end

      context 'when any of the eligible products is not ordered' do
        before do
          allow(order).to receive_messages(product_ids: [product1.id, product2.id])
          allow(rule).to receive_messages(eligible_product_ids: [product1.id, product2.id, product3.id])
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
        allow(order).to receive_messages(product_ids: [product1.id])
        allow(rule).to receive_messages(eligible_product_ids: [product2.id, product3.id])
        expect(rule).to be_eligible(order)
      end

      context "when any of the order's products are in eligible products" do
        before do
          allow(order).to receive_messages(product_ids: [product1.id, product2.id])
          allow(rule).to receive_messages(eligible_product_ids: [product2.id, product3.id])
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

    let(:rule_product) { create(:product) }
    let(:other_product) { create(:product) }
    let(:rule_line_item) { build(:line_item, variant: rule_product.master) }
    let(:other_line_item) { build(:line_item, variant: other_product.master) }

    before do
      allow(rule).to receive(:eligible_product_ids).and_return([rule_product.id])
    end

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

  describe '#add_products' do
    let(:promotion) { create(:promotion) }
    let(:rule) { create(:promotion_rule_product, promotion: promotion) }
    let(:products) { create_list(:product, 3) }

    it 'adds the products to the rule' do
      rule.product_ids_to_add = products.map(&:id)
      rule.save!
      expect(rule.reload.eligible_product_ids).to match_array(products.map(&:id))
    end

    it 'removes the products from the rule' do
      rule.product_ids_to_add = products.map(&:id)
      rule.save!
      rule.product_ids_to_add = []
      rule.save!
      expect(rule.reload.eligible_product_ids).to be_empty
    end

    it 'does not remove the products when nil is passed' do
      rule.product_ids_to_add = products.map(&:id)
      rule.save!
      rule.product_ids_to_add = nil
      rule.save!
      expect(rule.reload.eligible_product_ids).to match_array(products.map(&:id))
    end

    it 'touches the record to invalidate cache' do
      rule.product_ids_to_add = [products.first.id]
      rule.save!
      original_updated_at = rule.updated_at

      rule.update_column(:updated_at, 1.day.ago)
      rule.product_ids_to_add = [products.second.id]
      rule.save!

      expect(rule.reload.updated_at).to be > original_updated_at
    end
  end
end
