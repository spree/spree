require 'spec_helper'

describe Spree::UserMethods do
  let(:test_user) { create :user }
  let(:current_store) { @default_store }

  describe '#add_role' do
    it 'adds a role to the user' do
      test_user.add_role('test')

      expect(test_user.has_spree_role?('test', current_store)).to be_truthy
    end

    context 'when a resource parameter is provided' do
      let(:resource) { create(:store) }

      before { test_user.add_role('test', resource) }

      it 'adds a role to the user for the resource' do
        expect(test_user.has_spree_role?('test', resource)).to be_truthy
      end
    end
  end

  describe '#remove_role' do
    it 'removes a role from the user' do
      test_user.add_role('test')

      test_user.remove_role('test')

      expect(test_user.has_spree_role?('test')).to be_falsy
    end

    context 'when a resource parameter is provided' do
      let(:resource) { create(:store) }

      before { test_user.add_role('test', resource) }

      it 'removes a role from the user for the resource' do
        test_user.remove_role('test', resource)

        expect(test_user.has_spree_role?('test', resource)).to be_falsy
      end
    end
  end

  describe '#has_spree_role?' do
    subject { test_user.has_spree_role? name }

    let(:role) { Spree::Role.create(name: name) }
    let(:name) { 'test' }

    context 'with a role' do
      before { test_user.spree_roles << role }

      it { is_expected.to be_truthy }
    end

    context 'without a role' do
      it { is_expected.to be_falsy }
    end

    context 'when a resource parameter is provided' do
      let(:resource) { create(:store) }

      context 'when the user has the role for the resource' do
        before { test_user.add_role(name, resource) }

        it { is_expected.to be_truthy }
      end

      context 'when the user does not have the role for the resource' do
        it { is_expected.to be_falsy }
      end
    end
  end

  describe '#spree_admin?' do
    it do
      expect(create(:admin_user).spree_admin?).to be true
      expect(create(:user).spree_admin?).to be false
    end
  end

  describe '.spree_admin_created?' do
    it 'returns true when admin exists' do
      create(:admin_user)

      expect(Spree.user_class).to be_spree_admin_created
    end

    it 'returns false when admin does not exist' do
      expect(Spree.user_class).to_not be_spree_admin_created
    end
  end
end
