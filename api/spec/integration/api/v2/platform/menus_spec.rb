require 'swagger_helper'

describe 'Menus API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Menu'
  options = {
    include_example: 'menu_items',
    filter_examples: [{ name: 'filter[name_eq]', example: 'Main Menu' },
                      { name: 'filter[location_eq]', example: 'header' }]
  }

  let(:id) { create(:menu, name: 'Main Menu').id }
  let(:records_list) do
    build_list(:menu, 2) do |record, i|
      if i == 0
        record.name = 'Main Menu'
        record.location = 'header'
      else
        record.name = 'Footer Menu'
        record.location = 'footer'
      end
      record.store = store
      record.locale = 'en'

      record.save!
    end

    menu_1 = Spree::Menu.first
    menu_2 = Spree::Menu.last
    create(:menu_item, menu: menu_1)
    create(:menu_item, menu: menu_1)
    create(:menu_item, menu: menu_2)
    create(:menu_item, menu: menu_2)
  end
  let(:valid_create_param_value) { build(:menu, name: 'Main Menu').attributes }
  let(:valid_update_param_value) do
    {
      name: 'Main Menu',
      location: 'header',
      locale: 'en'
    }
  end
  let(:invalid_param_value) do
    {
      name: '',
      locale: '',
      location: ''
    }
  end

  include_examples 'CRUD examples', resource_name, options
end
