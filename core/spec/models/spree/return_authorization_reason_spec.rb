require 'spec_helper'

describe Spree::ReturnAuthorizationReason do
  let!(:return_authorization_reason) { create(:return_authorization_reason, active: true) }

  describe 'Associations' do
    it { is_expected.to have_many(:return_authorizations).dependent(:restrict_with_error) }
  end

  describe 'Included Modules' do
    it { expect(described_class.ancestors).to include(Spree::NamedType) }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive.allow_blank }
  end

  describe 'Scopes' do
    let!(:return_authorization_reason2) { create(:return_authorization_reason, active: false) }

    describe 'active' do
      it { expect(described_class.active).to include(return_authorization_reason) }
      it { expect(described_class.active).not_to include(return_authorization_reason2) }
    end
  end
end
