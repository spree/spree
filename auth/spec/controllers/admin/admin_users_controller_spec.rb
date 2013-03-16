require 'spec_helper'
require 'bar_ability'
require 'cancan'

describe Spree::Admin::UsersController do
  context '#authorize_admin' do
    let(:user) { Spree::User.new }
    let(:mock_user) { mock_model Spree::User }

    before do
      controller.stub :current_user => user
      Spree::User.stub(:find).with('9').and_return(mock_user)
      Spree::User.stub(:new).and_return(mock_user)
    end

    after(:each) { user.roles = [] }

    it 'should grant access to users with an admin role' do
      #user.stub :has_role? => true
      user.roles = [Spree::Role.find_or_create_by_name('admin')]
      spree_post :index
      response.should render_template :index
    end

    it 'should deny access to users with an bar role' do
      user.roles = [Spree::Role.find_or_create_by_name('bar')]
      Spree::Ability.register_ability(BarAbility)
      spree_post :index
      response.should render_template 'spree/shared/unauthorized'
    end

    it 'should deny access to users with an bar role' do
      user.roles = [Spree::Role.find_or_create_by_name('bar')]
      Spree::Ability.register_ability(BarAbility)
      spree_post :update, { :id => '9' }
      response.should render_template 'spree/shared/unauthorized'
    end

    it 'should deny access to users without an admin role' do
      user.stub :has_role? => false
      spree_post :index
      response.should render_template 'spree/shared/unauthorized'
    end
  end

  describe 'resource callbacks' do
    [:create, :update].each do |action|
      describe "##{action}" do
        let(:user) { stub('User', has_role?: true).as_null_object }

        before do
          Spree::User.stub(new: user, find: user)
          subject.stub(:invoke_callbacks)
        end

        after { spree_post action, user: {}, id: 1 }

        it "invokes the 'before' callback" do
          subject.should_receive(:invoke_callbacks).with(action, :before)
        end

        context 'when the user is saved successfully' do
          before do
            user.stub(save: true)
            user.stub(update_attributes: true)
          end

          it "invokes the 'after' callback" do
            subject.should_receive(:invoke_callbacks).with(action, :after)
          end

          it "does not invoke the 'fails' callback" do
            subject.should_not_receive(:invoke_callbacks).with(action, :fails)
          end
        end

        context 'when the user is not saved successfully' do
          before do
            user.stub(save: false)
            user.stub(update_attributes: false)
          end

          it "invokes the 'fails' callback" do
            subject.should_receive(:invoke_callbacks).with(action, :fails)
          end

          it "does not invoke the 'after' callback" do
            subject.should_not_receive(:invoke_callbacks).with(action, :after)
          end
        end
      end
    end
  end
end
