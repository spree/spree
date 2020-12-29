require 'spec_helper'

describe Spree::Promotion::Rules::Taxon, type: :model do
  let(:rule) { subject }

  context '#elegible?(order)' do
    let(:taxon) { create :taxon, name: 'first' }
    let(:taxon2) { create :taxon, name: 'second' }
    let(:order) { create :order_with_line_items }

    before do
      rule.save
    end

    context 'with any match policy' do
      before do
        rule.preferred_match_policy = 'any'
      end

      it 'is eligible if order does has any prefered taxon' do
        order.products.first.taxons << taxon
        rule.taxons << taxon
        expect(rule).to be_eligible(order)
      end

      context 'when order contains items from different taxons' do
        before do
          order.products.first.taxons << taxon
          rule.taxons << taxon
        end

        it 'acts on a product within the eligible taxon' do
          expect(rule).to be_actionable(order.line_items.last)
        end

        it 'does not act on a product in another taxon' do
          order.line_items << create(:line_item, product: create(:product, taxons: [taxon2]))
          expect(rule).not_to be_actionable(order.line_items.last)
        end
      end

      context 'when order does not have any prefered taxon' do
        before { rule.taxons << taxon2 }

        it { expect(rule).not_to be_eligible(order) }
        it 'sets an error message' do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq 'You need to add a product from an applicable category before applying this coupon code.'
        end
      end

      context 'when a product has a taxon child of a taxon rule' do
        before do
          taxon.children << taxon2
          order.products.first.taxons << taxon2
          rule.taxons << taxon2
        end

        it { expect(rule).to be_eligible(order) }
      end
    end

    context 'with all match policy' do
      before do
        rule.preferred_match_policy = 'all'
      end

      it 'is eligible order has all prefered taxons' do
        order.products.first.taxons << taxon2
        order.products.last.taxons << taxon

        rule.taxons = [taxon, taxon2]

        expect(rule).to be_eligible(order)
      end

      context 'when order does not have all prefered taxons' do
        before { rule.taxons << taxon }

        it { expect(rule).not_to be_eligible(order) }
        it 'sets an error message' do
          rule.eligible?(order)
          expect(rule.eligibility_errors.full_messages.first).
            to eq 'You need to add a product from all applicable categories before applying this coupon code.'
        end
      end

      context 'when a product has a taxon child of a taxon rule' do
        let(:taxon3) { create :taxon }

        before do
          taxon.children << taxon2
          order.products.first.taxons << taxon2
          order.products.last.taxons << taxon3
          rule.taxons << taxon2
          rule.taxons << taxon3
        end

        it { expect(rule).to be_eligible(order) }
      end
    end
  end
end
