require 'spec_helper'

class FakesController < ApplicationController
  include Spree::Core::ControllerHelpers::Common
end

describe Spree::Core::ControllerHelpers::Common, type: :controller do
  controller(FakesController) {}
  let!(:helper) { Spree::Core::ControllerHelpers::Common }

  describe '#title' do
    before do
      Spree::Config[:always_put_site_name_in_title] = true
      Spree::Config[:title_site_name_separator] = '-'
    end

    context 'when title with current store name is present' do
      let!(:store) { create(:store, name: 'Spree Test Store', seo_title: 'Spree - Spree Test Store') }

      it 'returns that title' do
        allow_any_instance_of(helper).to receive(:current_store).and_return(store)

        expect(controller.send(:title)).to eq store.seo_title
      end
    end

    context 'when title without current store name is present' do
      let!(:store) { create(:store, name: 'Spree Test Store', seo_title: 'Spree') }

      it 'returns title with current store name' do
        allow_any_instance_of(helper).to receive(:current_store).and_return(store)

        title = store.seo_title + ' - ' + store.name
        expect(controller.send(:title)).to eq title
      end
    end
  end
end
