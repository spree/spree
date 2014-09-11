require 'spec_helper'

class FakesController < ApplicationController
  include Spree::Core::ControllerHelpers::SSL
  def index; render text: 'index'; end
  def create; end
  def ssl_supported?; true; end
end

describe Spree::Core::ControllerHelpers::SSL, type: :controller do

  describe 'redirect to http' do
    before { Spree::Config[:redirect_https_to_http] = true  }
    after  { Spree::Config[:redirect_https_to_http] = false }
    before { request.env['HTTPS'] = 'on' }

    describe 'allowed two actions' do
      controller(FakesController) do
        ssl_allowed :index
        ssl_allowed :foobar
      end

      it '#ssl_allowed_actions returns both' do
        expect(controller.ssl_allowed_actions).to eq [:index, :foobar]
      end

      it 'should allow https access' do
        expect(get(:index)).to be_success
      end
    end

    context 'allowed a single action' do
      controller(FakesController) do
        ssl_allowed :index
      end
      specify{ controller.ssl_allowed_actions.should == [:index] }
      specify{ get(:index).should be_success }
    end

    context 'allowed all actions' do
      controller(FakesController) do
        ssl_allowed
      end
      specify{ controller.ssl_allowed_actions.should == [] }
      specify{ get(:index).should be_success }
    end

    context 'ssl not allowed' do
      controller(FakesController) { }
      specify{ get(:index).should be_redirect }
    end

    context 'using a post returns a HTTP status 426' do
      controller(FakesController) { }
      specify do
        post(:create)
        response.body.should == "Please switch to using HTTP (rather than HTTPS) and retry this request."
        response.status.should == 426
      end
    end
  end

  describe 'redirect to https' do
    context 'required a single action' do
      controller(FakesController) do
        ssl_required :index
      end
      specify{ controller.ssl_allowed_actions.should == [:index] }
      specify{ get(:index).should be_redirect }
    end

    context 'required all actions' do
      controller(FakesController) do
        ssl_required
      end
      specify{ controller.ssl_allowed_actions.should == [] }
      specify{ get(:index).should be_redirect }
    end

    context 'not required' do
      controller(FakesController) { }
      specify{ get(:index).should be_success }
    end
  end
end
