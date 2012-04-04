require 'spec_helper'

describe Spree::UserRegistrationsController do
  context '#create' do
    it 'should fire exactly one spree.user.signup notification' do
      activator = Spree::Activator.create!({:event_name => 'spree.user.signup'}, :without_protection => true)
      ActiveSupport::Notifications.subscribe(/spree.user.signup/) { |*args| activator.activate(args) }
      activator.should_receive(:activate).once
      new_user = Factory.build(:user)

      @request.env['devise.mapping'] = Devise.mappings[:user]

      post :create, { :commit=>'Create', :user => { 'password' => new_user.password, 'password_confirmation' => new_user.password, 'email' => new_user.email } }
    end
  end

  after do
    ActiveSupport::Notifications.unsubscribe(/spree.user.signup/)
  end
end
