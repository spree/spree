require 'spec_helper'

describe Spree::Core::ControllerHelpers::SSL, :type => :controller do
  before do
    @routes.draw do
      get '/anonymous/index'
    end
  end
  controller do
    include Spree::Core::ControllerHelpers::SSL
    def index; render text: 'index'; end
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
