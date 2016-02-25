require 'spec_helper'

describe Spree::ReturnAuthorizationReason do
  describe 'Associations' do
    it { is_expected.to have_many(:return_authorizations).dependent(:restrict_with_error) }
  end

  describe 'Included Modules' do
    it { expect(described_class.ancestors).to include(Spree::NamedType) }
  end
end
