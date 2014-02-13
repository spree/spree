require 'spec_helper'

describe 'products', :caching => true do
  let!(:product) { create(:product) }
  let!(:taxonomy) { create(:taxonomy) }
  let!(:taxon) { create(:taxon, :taxonomy => taxonomy) }

  before do
    # warm up the cache
    visit spree.root_path
    assert_written_to_cache("views/spree/products/all")
    assert_written_to_cache("views/spree/products/#{product.id}")
    assert_written_to_cache("views/spree/taxonomies/#{taxonomy.id}")
    assert_written_to_cache("views/taxons/#{taxon.updated_at.to_i}")

    clear_cache_events
  end


  it "reads from cache upon a second viewing" do
    visit spree.root_path
    expect(cache_writes.count).to eq(0)
  end

  it "busts the cache when a product is updated" do
    product.update_column(:updated_at, 1.day.from_now)
    visit spree.root_path
    assert_written_to_cache("views/spree/products/all")
    assert_written_to_cache("views/spree/products/#{product.id}")
    expect(cache_writes.count).to eq(2)
  end

  it "busts the cache when a product is deleted" do
    product.destroy
    visit spree.root_path
    assert_written_to_cache("views/spree/products/all")
    expect(cache_writes.count).to eq(1)
  end
end