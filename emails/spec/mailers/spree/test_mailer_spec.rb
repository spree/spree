require 'spec_helper'
require 'email_spec'

describe Spree::TestMailer, type: :mailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let(:user) { create(:user) }

  context ':from not set explicitly' do
    it 'falls back to spree config' do
      message = Spree::TestMailer.test_email('test@example.com')
      expect(message.from).to eq([@default_store.mail_from_address])
    end
  end

  it 'confirm_email accepts a user id as an alternative to a User object' do
    expect do
      Spree::TestMailer.test_email('test@example.com')
    end.not_to raise_error
  end
end
