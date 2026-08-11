require 'spec_helper'

describe Spree::Promotion::Rules::Category, type: :model do
  let(:store) { @default_store }
  let(:promotion) { create(:promotion) }
  let(:rule) { create(:promotion_rule_taxon, promotion: promotion) }

  describe '#eligible?(order)' do
    let(:category) { create :category, name: 'first' }
    let(:category2) { create :category, name: 'second' }
    let(:order) { create :order_with_line_items, store: store }

    context 'with any match policy' do
      before do
        rule.preferred_match_policy = 'any'
      end

      it 'is eligible if order does has any preferred category' do
        order.products.first.categories << category
        rule.categories << category
        expect(rule).to be_eligible(order)
      end

      context 'when order contains items from different taxons' do
        before do
          order.products.first.categories << category
          rule.categories << category
        end

        it 'acts on a product within the eligible category' do
          expect(rule).to be_actionable(order.line_items.last)
        end

        it 'does not act on a product in another category' do
          order.line_items << create(:line_item, product: create(:product, categories: [category2]))
          expect(rule).not_to be_actionable(order.line_items.last)
        end
      end

      context 'when order does not have any preferred category' do
        before { rule.categories << category2 }

        it { expect(rule).not_to be_eligible(order) }
        it 'sets an error message' do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq 'You need to add a product from an applicable category before applying this coupon code.'
        end
      end

      context 'when a product has a category child of a category rule' do
        before do
          category.children << category2
          order.products.first.categories << category2
          rule.categories << category2
        end

        it { expect(rule).to be_eligible(order) }
      end
    end

    context 'with all match policy' do
      before do
        rule.preferred_match_policy = 'all'
      end

      it 'is eligible order has all preferred taxons' do
        order.products.first.categories << category2
        order.products.last.categories << category

        rule.taxons = [category, category2]

        expect(rule).to be_eligible(order)
      end

      context 'when order does not have all preferred taxons' do
        before { rule.categories << category }

        it { expect(rule).not_to be_eligible(order) }
        it 'sets an error message' do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq 'You need to add a product from all applicable categories before applying this coupon code.'
        end
      end

      context 'when a product has a category child of a category rule' do
        let(:category3) { create :category }

        before do
          category.children << category2
          order.products.first.categories << category2
          order.products.last.categories << category3
          rule.categories << category2
          rule.categories << category3
        end

        it { expect(rule).to be_eligible(order) }
      end
    end
  end

  describe '#add_taxons' do
    let(:promotion) { create(:promotion) }
    let(:rule) { create(:promotion_rule_taxon, promotion: promotion) }
    let(:taxons) { create_list(:category, 3) }

    it 'adds the taxons to the rule' do
      rule.taxon_ids_to_add = taxons.map(&:id)
      rule.save!
      expect(rule.taxons).to match_array(taxons)
    end

    it 'removes the taxons from the rule' do
      rule.taxon_ids_to_add = taxons.map(&:id)
      rule.save!
      rule.taxon_ids_to_add = []
      rule.save!
      expect(rule.taxons).to be_empty
    end

    it 'does not remove the taxons when nil is passed' do
      rule.taxon_ids_to_add = taxons.map(&:id)
      rule.save!
      rule.taxon_ids_to_add = nil
      rule.save!
      expect(rule.taxons).to match_array(taxons)
    end
  end
end
