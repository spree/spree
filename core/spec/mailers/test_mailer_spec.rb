require 'spec_helper'
require 'email_spec'

describe Spree::TestMailer, :type => :mailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  before { create(:store) }

  let(:user) { create(:user) }

  context ":from not set explicitly" do
    it "falls back to spree config" do
      message = Spree::TestMailer.test_email('test@example.com')
      expect(message.from).to eq([Spree::Store.current.mail_from_address])
    end
  end

  it "confirm_email accepts a user id as an alternative to a User object" do
    expect {
      test_email = Spree::TestMailer.test_email('test@example.com')
    }.not_to raise_error
  end
end
