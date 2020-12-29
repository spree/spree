require 'spec_helper'

describe Spree::HomeController, type: :controller do
  context 'layout' do
    it 'renders default layout' do
      get :index
      expect(response).to render_template(layout: 'spree/layouts/spree_application')
    end

    context 'different layout specified in config' do
      before { Spree::Config.layout = 'layouts/application' }

      it 'renders specified layout' do
        get :index
        expect(response).to render_template(layout: 'layouts/application')
      end
    end
  end
end
