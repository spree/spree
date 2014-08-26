require 'spec_helper'
require 'email_spec'

describe Spree::TestMailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let(:user) { create(:user) }

  context ":from not set explicitly" do
    it "falls back to spree config" do
      message = Spree::TestMailer.test_email('test@example.com')
      message.from.should == [Spree::Config[:mails_from]]
    end
  end

  it "confirm_email accepts a user id as an alternative to a User object" do
    lambda {
      test_email = Spree::TestMailer.test_email('test@example.com')
    }.should_not raise_error
  end
end
