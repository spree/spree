require 'spec_helper'

# This test tests the functionality within
# spree/core/controller_helpers/respond_with.rb
# Rather than duck-punching the existing controllers,
# let's define a custom one:
module SpreeSpec
  class CustomController < Spree::BaseController
    def index
      respond_with(Spree::Address.new) do |format|
        format.html { render text: 'neutral' }
      end
    end

    def create
      # Just need a model with validations
      # Address is good enough, so let's go with that
      address = Spree::Address.new(params[:address])
      respond_with(address)
    end
  end # CustomController
end # SpreeSpec

describe SpreeSpec::CustomController, type: :controller do
  after do
    SpreeSpec::CustomController.clear_overrides!
  end

  context 'index' do
    context 'specify symbol for handler instead of Proc' do
      before do
        SpreeSpec::CustomController.class_eval do
          respond_override(index: { html: { success: :success_method }})

        private

          def success_method
            render(text: 'success!!!')
          end
        end
      end

      describe 'GET' do
        it 'responds successful' do
          spree_get(:index)
          expect(response).to have_http_status(200)
          expect(response.body).to include('success!!!')
        end
      end
    end

    context 'render' do
      before do
        SpreeSpec::CustomController.instance_eval do
          respond_override(index: { html: { success: -> { render(text: 'success!!!') }}})
          respond_override(index: { html: { failure: -> { render(text: 'failure!!!') }}})
        end
      end

      describe 'GET' do
        it 'responds successful' do
          spree_get(:index)
          expect(response).to have_http_status(200)
          expect(response.body).to include('success!!!')
        end
      end
    end

    context 'redirect' do
      before do
        SpreeSpec::CustomController.instance_eval do
          respond_override(index: { html: { success: -> { redirect_to('/cart') }}})
          respond_override(index: { html: { failure: -> { render(text: 'failure!!!') }}})
        end
      end

      describe 'GET' do
        it 'responds with a redirect' do
          spree_get :index
          expect(response).to have_http_status(302)
        end
      end
    end

    context 'validation error' do
      before do
        SpreeSpec::CustomController.instance_eval do
          respond_to :html
          respond_override(create: { html: { success: -> { render(text: 'success!!!') }}})
          respond_override(create: { html: { failure: -> { render(text: 'failure!!!') }}})
        end
      end

      describe 'POST' do
        it 'responds successful' do
          spree_post(:create)
          expect(response).to have_http_status(200)
          expect(response.body).to include('success!!!')
        end
      end
    end

    context 'A different controllers respond_override. Regression test for #1301' do
      before do
        Spree::CheckoutController.instance_eval do
          respond_override(index: { html: { success: -> { render(text: 'success!!!') }}})
        end
      end

      describe 'POST' do
        it 'should not effect the wrong controller' do
          spree_get(:index)
          expect(response).to have_http_status(200)
          expect(response.body).to include('neutral')
        end
      end
    end
  end
end
