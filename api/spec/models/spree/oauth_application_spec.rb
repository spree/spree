require 'spec_helper'

module Spree
  describe OauthApplication, type: :model do
    subject { build(:oauth_application) }

    it 'creates a valid oauth application' do
      expect(subject).to be_valid
    end
  end
end
