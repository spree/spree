require 'spec_helper'

describe Spree::Role do
  let(:role) { create(:role) }
  let(:user) { create(:user) }

  describe 'with users' do
    before do
      user.spree_roles << role
    end

    it 'can access users through the polymorphic association' do
      expect(role.users).to include(user)
    end
  end
end
