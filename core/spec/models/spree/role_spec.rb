require 'spec_helper'

describe Spree::Role, type: :model do
  describe 'Associations' do
    it { is_expected.to have_many(:role_users).class_name('Spree::RoleUser').dependent(:destroy) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive.allow_blank }
  end
end
