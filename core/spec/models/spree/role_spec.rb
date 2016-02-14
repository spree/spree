require 'spec_helper'

describe Spree::Role, type: :model do
  describe 'Associations' do
    it { is_expected.to have_many(:role_users).class_name('Spree::RoleUser').dependent(:destroy) }
  end
end
