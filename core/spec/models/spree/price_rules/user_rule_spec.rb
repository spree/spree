require 'spec_helper'

describe Spree::PriceRules::UserRule, type: :model do
  let(:price_list) { create(:price_list) }
  let(:rule) { create(:user_price_rule, price_list: price_list) }
  let(:user) { create(:user) }
  let(:variant) { create(:variant) }

  describe '#applicable?' do
    context 'when user_ids preference is empty' do
      before { rule.preferred_user_ids = [] }

      it 'returns true when user is present' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', user: user)
        expect(rule.applicable?(context)).to be true
      end
    end

    context 'when user_ids preference is set' do
      before { rule.preferred_user_ids = [user.id] }

      it 'returns true when context user matches' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', user: user)
        expect(rule.applicable?(context)).to be true
      end

      it 'returns false when context user does not match' do
        other_user = create(:user)
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', user: other_user)
        expect(rule.applicable?(context)).to be false
      end

      it 'returns false when context has no user' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD')
        expect(rule.applicable?(context)).to be false
      end
    end

    context 'when user_ids preference contains strings' do
      before { rule.preferred_user_ids = [user.id.to_s] }

      it 'returns true when context user matches' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', user: user)
        expect(rule.applicable?(context)).to be true
      end

      it 'returns false when context user does not match' do
        other_user = create(:user)
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD', user: other_user)
        expect(rule.applicable?(context)).to be false
      end
    end
  end
end
