FactoryBot.define do
  factory :import_mapping, class: 'Spree::ImportMapping' do
    import { create(:product_import) }
    schema_field { 'name' }
    file_column { 'name' }
  end
end
