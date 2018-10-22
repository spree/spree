require 'spec_helper'

describe 'Switching currencies in backend', type: :feature do
  before do
    create(:base_product, name: 'RoR Mug')
  end

  # Regression test for #2340
  it 'does not cause current_order to become nil', inaccessible: true, js: true do
    add_to_cart('RoR Mug')
    # Now that we have an order...
    Spree::Config[:currency] = 'AUD'
    expect { visit spree.root_path }.not_to raise_error
  end
end
