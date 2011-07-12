require 'spec_helper'

describe UserRegistrationsController do

  context "#create" do

    it "should fire exactly one spree.user.signup notification" do

      activator = Activator.create!(:event_name => 'spree.user.signup')

      ActiveSupport::Notifications.subscribe(/spree.user.signup/) { |*args| activator.activate }

      activator.should_receive(:activate).once

      new_user = Factory.build(:user)

      @request.env["devise.mapping"] = Devise.mappings[:user]

      post :create, {:commit=>"Create", :user => {"password" => new_user.password, "password_confirmation" => new_user.password, "email" => new_user.email}}

    end

  end
end
