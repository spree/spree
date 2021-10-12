require 'swagger_helper'

describe 'Wishlists API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Wishlist'
  options = {
    include_example: 'wished_items',
    filter_examples: [{ name: 'filter[name_cont]', example: 'Birthday' }]
  }

  let!(:user) { create(:user) }

  let(:id) { create(:wishlist, name: 'My Wishlist', user: user).id }
  let(:records_list) do
    build_list(:wishlist, 2) do |record, i|
      record.name = if i == 0
                      'Black Friday'
                    else
                      'Birthday'
                    end
      record.store = store
      record.user = user

      record.save!
    end

    wishlist_1 = Spree::Wishlist.first
    wishlist_2 = Spree::Wishlist.last

    create(:wished_item, wishlist: wishlist_1)
    create(:wished_item, wishlist: wishlist_1)
    create(:wished_item, wishlist: wishlist_2)
    create(:wished_item, wishlist: wishlist_2)
  end
  let(:valid_create_param_value) { build(:wishlist, user: user).attributes }
  let(:valid_update_param_value) do
    {
      name: 'My Super Wishlist'
    }
  end
  let(:invalid_param_value) do
    {
      name: ''
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
