require 'spec_helper'

RSpec.describe Spree::Policy, type: :model do
  let(:store) { Spree::Store.default }
  let(:policy) { create(:policy, owner: store) }

  describe 'Callbacks' do
    context 'after destroy destroys links in which policy is linked to' do
      let!(:page_link) { create(:page_link, linkable: policy, parent: store) }

      it 'destroys links' do
        expect(store.links).to include(page_link)
        expect { policy.destroy }.to change(Spree::PageLink, :count).by(-1)
        expect(store.links).not_to include(page_link)
      end
    end
  end
end
