require 'spec_helper'
require 'bcrypt'

module Spree
  describe OauthApplication, type: :model do
    subject { build(:oauth_application) }

    it 'creates a valid oauth application' do
      expect(subject).to be_valid
    end

    it 'assigns client id and secret' do
      expect { subject.save! }.to change(subject, :uid).and change(subject, :secret)
    end

    it 'can access plain text secret only once after save' do
      subject.save!
      expect(subject.plaintext_secret).to be_present
      expect(described_class.last.plaintext_secret).to be_nil
    end

    it 'encrypts secret' do
      subject.save!
      expect(subject.secret).not_to eq(subject.plaintext_secret)
      expect(BCrypt::Password.new(subject.secret)).to eq(subject.plaintext_secret)
    end
  end
end
