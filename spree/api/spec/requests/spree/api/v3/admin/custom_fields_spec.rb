require 'spec_helper'

# The parent comes from the route. A controller spec cannot show that: it
# routes every param it is given, so a `store_id` there picks the store route.
RSpec.describe 'Admin custom fields parent', type: :request do
  include_context 'API v3 Admin'

  let(:category) { create(:category) }
  let(:definition) { create(:custom_field_definition, :short_text_field, resource_type: 'Spree::Category') }

  it 'keeps the routed parent when the query string names a store' do
    post "/api/v3/admin/categories/#{category.prefixed_id}/custom_fields?store_id=#{create(:store).prefixed_id}",
         params: { custom_field_definition_id: definition.prefixed_id, value: 'summer' },
         headers: bearer_headers,
         as: :json

    expect(response).to have_http_status(:created)
    expect(category.custom_fields.pluck(:value)).to eq(['summer'])
  end
end
