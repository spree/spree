require 'spec_helper'

describe Spree::Core::ControllerHelpers::SSL, :type => :controller do
  before do
    @routes.draw do
      get '/anonymous/index'
      post '/anonymous/create'
    end
  end
  controller do
    include Spree::Core::ControllerHelpers::SSL
    def index; render text: 'index'; end
    def create; end
    def self.ssl_supported?; true; end
  end

  describe 'redirect to http' do
    before { Spree::Config[:redirect_https_to_http] = true  }
    after  { Spree::Config[:redirect_https_to_http] = false }
    before { request.env['HTTPS'] = 'on' }

    context 'allowed two actions' do
      controller(described_class) do
        ssl_allowed :index
        ssl_allowed :foobar
      end
      specify{ controller.ssl_allowed_actions.should == [:index, :foobar] }
      specify{ get(:index).should be_success }
    end
    context 'allowed a single action' do
      controller(described_class){ ssl_allowed :index }
      specify{ controller.ssl_allowed_actions.should == [:index] }
      specify{ get(:index).should be_success }
    end
    context 'allowed all actions' do
      controller(described_class){ ssl_allowed }
      specify{ controller.ssl_allowed_actions.should == [] }
      specify{ get(:index).should be_success }
    end
    context 'ssl not allowed' do
      controller(described_class){ }
      specify{ get(:index).should be_redirect }
    end
    context 'using a post returns a HTTP status 426' do
      controller(described_class){ }
      specify do
        post(:create)
        response.body.should == "Please switch to using HTTP (rather than HTTPS) and retry this request."
        response.status.should == 426
      end
    end
  end

  describe 'redirect to https' do
    context 'required a single action' do
      controller(described_class){ ssl_required :index }
      specify{ controller.ssl_allowed_actions.should == [:index] }
      specify{ get(:index).should be_redirect }
    end
    context 'required all actions' do
      controller(described_class){ ssl_required }
      specify{ controller.ssl_allowed_actions.should == [] }
      specify{ get(:index).should be_redirect }
    end
    context 'not required' do
      controller(described_class){ }
      specify{ get(:index).should be_success }
    end
  end
end
