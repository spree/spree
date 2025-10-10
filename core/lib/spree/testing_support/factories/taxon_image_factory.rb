FactoryBot.define do
  factory :taxon_image, class: Spree::TaxonImage do
    before(:create) do |taxon_image|
      if taxon_image.class.method_defined?(:attachment)
        taxon_image.attachment.attach(io: File.new(Spree::Core::Engine.root + 'spec/fixtures/thinking-cat.jpg'), filename: 'thinking-cat.jpg')
      end
    end
  end
end
