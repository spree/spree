require 'spec_helper'

describe Spree::StoreController do

  subject do
    request
    response.status
  end

  controller(Spree::StoreController) do
    def index
      render text: 'test'
    end
  end

  let(:request) { get :index }

  describe '#index' do
    it { should == 200 }
  end

  describe 'disabling frontend' do

    context 'when enabled' do
      it { should == 200 }
    end

    context 'when disabled' do
      before { Spree::Config[:enable_frontend] = false }
      after  { Spree::Config[:enable_frontend] = true }

      it { should == 404 }
    end
  end
end
