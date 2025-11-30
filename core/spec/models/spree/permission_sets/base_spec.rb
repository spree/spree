require 'spec_helper'
require 'cancan/matchers'

RSpec.describe Spree::PermissionSets::Base do
  let(:user) { build(:user) }
  let(:store) { create(:store) }
  let(:ability) { Spree::Ability.new(user, store: store) }

  describe '#initialize' do
    subject(:permission_set) { described_class.new(ability) }

    it 'stores the ability' do
      expect(permission_set.ability).to eq(ability)
    end
  end

  describe '#activate!' do
    subject(:permission_set) { described_class.new(ability) }

    it 'raises NotImplementedError' do
      expect { permission_set.activate! }.to raise_error(NotImplementedError, /must implement #activate!/)
    end
  end

  describe 'delegation methods' do
    let(:permission_set_class) do
      Class.new(described_class) do
        def activate!
          can :read, Spree::Order
          cannot :destroy, Spree::Order
        end

        def test_can?
          can?(:read, Spree::Order)
        end
      end
    end

    subject(:permission_set) { permission_set_class.new(ability) }

    before { permission_set.activate! }

    describe '#can' do
      it 'delegates to ability' do
        expect(ability.can?(:read, Spree::Order)).to be true
      end
    end

    describe '#cannot' do
      it 'delegates to ability' do
        expect(ability.can?(:destroy, Spree::Order)).to be false
      end
    end

    describe '#can?' do
      it 'delegates to ability' do
        expect(permission_set.test_can?).to be true
      end
    end

    describe '#user' do
      it 'returns the user from the ability' do
        expect(permission_set.send(:user)).to eq(user)
      end
    end

    describe '#store' do
      it 'returns the store from the ability' do
        expect(permission_set.send(:store)).to eq(store)
      end
    end
  end
end
