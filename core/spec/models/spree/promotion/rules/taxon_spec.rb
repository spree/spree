require 'spec_helper'

describe Spree::Promotion::Rules::Taxon do
  let(:rule){ subject }

  context '#elegible?(order)' do
    let(:taxon){ create :taxon, name: 'first' }
    let(:taxon2){ create :taxon, name: 'second'}
    let(:order){ create :order_with_line_items }

    before do
      rule.save
    end

    context 'with any match policy' do
      before do
        order.line_items << create(:line_item, product: create(:product, taxons: [create(:taxon)]))
        rule.preferred_match_policy = 'any'
      end

      it 'is eligible if order does not has any prefered taxon' do
        order.products.first.taxons << taxon
        rule.taxons << taxon
        expect(rule).to be_eligible(order)
      end

      it 'is not eligile if order does not has any prefered taxon' do
        rule.taxons << taxon2
        expect(rule).not_to be_eligible(order)
      end
    end

    context 'with any match policy' do
      before do
        rule.preferred_match_policy = 'all'
      end

      it 'is eligible order has all prefered taxons' do
        order.products.first.taxons << taxon2
        order.products.last.taxons << taxon

        rule.taxons = [taxon, taxon2]

        expect(rule).to be_eligible(order)
      end

      it 'is not eligile if order does not has all prefered taxons' do
        rule.taxons << taxon
        expect(rule).not_to be_eligible(order)
      end
    end
  end
end
