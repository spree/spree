require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::TeamMemberSerializer do
  let!(:store) { @default_store }
  let!(:other_store) { create(:store, name: 'Unrelated Store', code: 'unrelated') }
  let(:seller) { create(:seller, store: store) }
  let(:member) { create(:admin_user) }

  subject(:payload) { described_class.new(member.reload, params: { store: store }).to_h }

  before do
    seller.add_user(member)
    # The teammate also works for an unrelated store, as staff commonly do.
    other_store.add_user(member)
  end

  it 'renders the teammate the seller needs to recognise' do
    expect(payload.keys).to match_array(
      %w[id email first_name last_name full_name avatar_url created_at]
    )
  end

  # The operator's serializer lists every store a user holds a role on, to feed
  # the marketplace store switcher. A seller must not learn the identity of
  # stores their teammate happens to work for.
  it 'does not disclose the stores a teammate works for' do
    expect(payload).not_to have_key('stores')
    expect(payload.to_s).not_to include('Unrelated Store')
    expect(payload.to_s).not_to include('unrelated')
  end

  it 'does not disclose marketplace roles' do
    expect(payload).not_to have_key('roles')
  end
end
