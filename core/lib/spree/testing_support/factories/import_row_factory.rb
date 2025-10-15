FactoryBot.define do
  factory :import_row, class: 'Spree::ImportRow' do
    import { create(:product_import) }
    data { { 'name' => 'Product 1' }.to_json }
    row_number { 1 }
  end
end
