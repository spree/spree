shared_context 'custom products' do
  before do
    taxonomy = FactoryBot.create(:taxonomy, name: 'Categories')
    root = taxonomy.root
    clothing_taxon = FactoryBot.create(:taxon, name: 'Clothing', parent_id: root.id)
    trending_taxon = FactoryBot.create(:taxon, name: 'Trending')
    bags_taxon = FactoryBot.create(:taxon, name: 'Bags', parent_id: root.id)
    mugs_taxon = FactoryBot.create(:taxon, name: 'Mugs', parent_id: root.id)

    taxonomy = FactoryBot.create(:taxonomy, name: 'Brands')
    root = taxonomy.root
    apache_taxon = FactoryBot.create(:taxon, name: 'Apache', parent_id: root.id)
    rails_taxon = FactoryBot.create(:taxon, name: 'Ruby on Rails', parent_id: root.id)
    ruby_taxon = FactoryBot.create(:taxon, name: 'Ruby', parent_id: root.id)

    FactoryBot.create(:custom_product, name: 'Ruby on Rails Ringer T-Shirt', price: '159.99', taxons: [rails_taxon, clothing_taxon])
    FactoryBot.create(:custom_product, name: 'Ruby on Rails Mug', price: '55.99', taxons: [rails_taxon, mugs_taxon, trending_taxon])
    FactoryBot.create(:custom_product, name: 'Ruby on Rails Tote', price: '55.99', taxons: [rails_taxon, bags_taxon, trending_taxon])
    FactoryBot.create(:custom_product, name: 'Ruby on Rails Bag', price: '102.99', taxons: [rails_taxon, bags_taxon])
    FactoryBot.create(:custom_product, name: 'Ruby on Rails Baseball Jersey', price: '190.99', taxons: [rails_taxon, clothing_taxon])
    FactoryBot.create(:custom_product, name: 'Ruby on Rails Stein', price: '156.99', taxons: [rails_taxon, mugs_taxon])
    FactoryBot.create(:custom_product, name: 'Ruby on Rails Jr. Spaghetti', price: '190.99', taxons: [rails_taxon, clothing_taxon])
    FactoryBot.create(:custom_product, name: 'Ruby Baseball Jersey', price: '250.99', taxons: [ruby_taxon, clothing_taxon])
    FactoryBot.create(:custom_product, name: 'Apache Baseball Jersey', price: '250.99', taxons: [apache_taxon, clothing_taxon])
  end
end
