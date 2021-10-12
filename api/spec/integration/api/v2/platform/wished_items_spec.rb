require 'swagger_helper'

describe 'Wished Item API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Wished Item'
  options = {
    include_example: 'variant'
  }

  let!(:user) { create(:user) }
  let!(:wishlist) { create(:wishlist) }
  let!(:variant) { create(:variant) }

  let(:id) { create(:wished_item).id }
  let(:records_list) { create_list(:wished_item, 4, wishlist: wishlist) }

  let(:valid_create_param_value) { build(:wished_item, wishlist: wishlist, variant: variant).attributes }
  let(:valid_update_param_value) do
    {
      quantity: 3
    }
  end
  let(:invalid_param_value) do
    {
      quantity: ''
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
