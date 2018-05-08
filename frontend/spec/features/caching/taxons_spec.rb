# require 'spec_helper'

# describe 'taxons', type: :feature, caching: true do
#   let!(:taxonomy) { create(:taxonomy) }

#   before do
#     create(:taxon, taxonomy: taxonomy)
#     # warm up the cache
#     visit spree.root_path
#     assert_written_to_cache("views/en/spree/taxonomies/#{taxonomy.id}")

#     clear_cache_events
#   end

#   it 'busts the cache when max_level_in_taxons_menu conf changes' do
#     Spree::Config[:max_level_in_taxons_menu] = 5
#     visit spree.root_path
#     assert_written_to_cache("views/en/spree/taxonomies/#{taxonomy.id}")
#     expect(cache_writes.count).to eq(1)
#   end
# end
