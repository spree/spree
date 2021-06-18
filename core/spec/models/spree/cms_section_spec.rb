require 'spec_helper'

describe Spree::CmsSection, type: :model do
  let!(:store_a) { create(:store) }
  let(:homepage) { create(:cms_homepage, store: store_a) }

  it 'validates presence of name' do
    expect(described_class.new(name: nil, cms_page: homepage)).not_to be_valid
  end

  it 'validates presence of page' do
    expect(described_class.new(name: 'Got Name')).not_to be_valid
  end
end
