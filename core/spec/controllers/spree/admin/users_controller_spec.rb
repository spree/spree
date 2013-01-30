require 'spec_helper'
require 'bar_ability'

describe Spree::Admin::UsersController do

  context '#authorize_admin' do
    let(:user) { create(:user) }
    let(:mock_user) { mock_model Spree.user_class }

    before do
      controller.stub :spree_current_user => user
      Spree.user_class.stub(:find).with('9').and_return(mock_user)
      Spree.user_class.stub(:new).and_return(mock_user)
      user.spree_roles.clear
    end

    it 'should grant access to users with an admin role' do
      user.spree_roles << Spree::Role.find_or_create_by_name('admin')
      spree_post :index
      response.should render_template :index
    end

    it 'should deny access to users with an bar role' do
      user.spree_roles << Spree::Role.find_or_create_by_name('bar')
      Spree::Ability.register_ability(BarAbility)
      spree_post :index
      response.should redirect_to('/unauthorized')
    end

    it 'should deny access to users with an bar role' do
      user.spree_roles << Spree::Role.find_or_create_by_name('bar')
      Spree::Ability.register_ability(BarAbility)
      spree_post :update, { :id => '9' }
      response.should redirect_to('/unauthorized')
    end

    it 'should deny access to users without an admin role' do
      user.stub :has_spree_role? => false
      spree_post :index
      response.should redirect_to('/unauthorized')
    end
  end
end
