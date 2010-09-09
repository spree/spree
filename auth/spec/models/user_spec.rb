require 'spec_helper'

describe User do
  before(:all) { Role.create :name => "admin" }

  context "#create" do
    let(:user) { User.new(:email => "foo@bar.com", :password => "secret", :password_confirmation => "secret") }

    it "should create a token when saving" do
      user.save!
      user.persistence_token.should_not be_nil
    end

    it "should have an admin role if no admin users exist yet" do
      user.save!
      user.has_role?('admin').should be_true
    end

  end
  context "anonymous!" do
    let(:user) { User.anonymous! }

    it "should create a new user" do
      user.new_record?.should be_false
    end

    it "should be anonymous" do
      user.should be_anonymous
    end

    context "#email=" do
      it "should set anonymous to false" do
        user.email = "jobs@railsdog.com"
        user.should_not be_anonymous
      end
    end

  end
end
