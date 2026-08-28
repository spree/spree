FactoryBot.define do
  factory :digital_asset, class: Spree::DigitalAsset do
    after(:build) do |digital_asset|
      digital_asset.attachment.attach(io: File.new("#{Spree::Core::Engine.root}/spec/fixtures/thinking-cat.jpg"),
                                      filename: 'thinking-cat.jpg')
    end

    variant
  end

  # @deprecated Use :digital_asset; removed in 6.1.
  factory :digital, parent: :digital_asset
end
