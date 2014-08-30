require 'spec_helper'

describe Spree::Core::ControllerHelpers::Search, type: :controller do

  controller do
    include Spree::Core::ControllerHelpers::Search
  end

  describe '#build_searcher' do
    it 'returns Spree::Core::Search::Base instance' do
      controller.stub(try_spree_current_user: create(:user),
                      current_currency: 'USD')
      expect(controller.build_searcher({}).class).to eq Spree::Core::Search::Base
    end
  end
end
