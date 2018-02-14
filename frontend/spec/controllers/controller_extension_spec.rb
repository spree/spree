require 'spec_helper'

# This test tests the functionality within
# spree/core/controller_helpers/respond_with.rb
# Rather than duck-punching the existing controllers, let's define a custom one:
class Spree::CustomController < Spree::BaseController
  def index
    respond_with(Spree::Address.new) do |format|
      format.html { render plain: 'neutral' }
    end
  end

  def create
    # Just need a model with validations
    # Address is good enough, so let's go with that
    address = Spree::Address.new(params[:address])
    respond_with(address)
  end
end

describe Spree::CustomController, type: :controller do
  after do
    Spree::CustomController.clear_overrides!
  end

  before do
    @routes = ActionDispatch::Routing::RouteSet.new.tap do |r|
      r.draw do
        get 'index', to: 'spree/custom#index'
        post 'create', to: 'spree/custom#create'
      end
    end
  end

  context 'extension testing' do
    context 'index' do
      context 'specify symbol for handler instead of Proc' do
        before do
          Spree::CustomController.class_eval do
            respond_override(index: { html: { success: :success_method } })

            private

            def success_method
              render plain: 'success!!!'
            end
          end
        end

        describe 'GET' do
          it 'has value success' do
            spree_get :index
            expect(response).to be_successful
            assert (response.body =~ /success!!!/)
          end
        end
      end

      context 'render' do
        before do
          Spree::CustomController.instance_eval do
            respond_override(index: { html: { success: -> { render(plain: 'success!!!') } } })
            respond_override(index: { html: { failure: -> { render(plain: 'failure!!!') } } })
          end
        end

        describe 'GET' do
          it 'has value success' do
            spree_get :index
            expect(response).to be_successful
            assert (response.body =~ /success!!!/)
          end
        end
      end

      context 'redirect' do
        before do
          Spree::CustomController.instance_eval do
            respond_override(index: { html: { success: -> { redirect_to('/cart') } } })
            respond_override(index: { html: { failure: -> { render(plain: 'failure!!!') } } })
          end
        end

        describe 'GET' do
          it 'has value success' do
            spree_get :index
            expect(response).to be_redirect
          end
        end
      end

      context 'validation error' do
        before do
          Spree::CustomController.instance_eval do
            respond_to :html
            respond_override(create: { html: { success: -> { render(plain: 'success!!!') } } })
            respond_override(create: { html: { failure: -> { render(plain: 'failure!!!') } } })
          end
        end

        describe 'POST' do
          it 'has value success' do
            spree_post :create
            expect(response).to be_successful
            assert (response.body =~ /success!/)
          end
        end
      end

      context 'A different controllers respond_override. Regression test for #1301' do
        before do
          Spree::CheckoutController.instance_eval do
            respond_override(index: { html: { success: -> { render(plain: 'success!!!') } } })
          end
        end

        describe 'POST' do
          it 'does not effect the wrong controller' do
            spree_get :index
            assert (response.body =~ /neutral/)
          end
        end
      end
    end
  end
end
