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

  describe '#preferred_user_ids=' do
    it 'decodes prefixed user IDs to raw IDs' do
      rule.preferred_user_ids = [user.prefixed_id]
      expect(rule.preferred_user_ids).to eq([user.id.to_s])
    end

    it 'accepts a mix of prefixed and raw IDs' do
      other_user = create(:user)
      rule.preferred_user_ids = [user.prefixed_id, other_user.id.to_s]
      expect(rule.preferred_user_ids).to contain_exactly(user.id.to_s, other_user.id.to_s)
    end
  end

  describe '#users' do
    let(:other_user) { create(:user) }

    it 'returns the users matching the preferred IDs' do
      rule.preferred_user_ids = [user.id, other_user.id]
      expect(rule.users).to contain_exactly(user, other_user)
    end

    it 'returns an empty relation when no users are set' do
      rule.preferred_user_ids = []
      expect(rule.users).to be_empty
    end
  end
end
