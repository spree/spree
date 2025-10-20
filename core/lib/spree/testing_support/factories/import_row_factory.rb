FactoryBot.define do
  factory :import_row, class: 'Spree::ImportRow' do
    import { create(:product_import) }
    data { { 'slug' => 'test-product', 'name' => 'Test Product', 'price' => '10.00' }.to_json }
    row_number { import.rows_count + 1 }
  end
end
