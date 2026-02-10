Typelizer.configure do |config|
  api_root = Spree::Api::Engine.root

  config.dirs = [
    api_root.join('app/serializers/spree/api/v3'),
    api_root.join('app/serializers/spree/api/v3/admin')
  ]
  config.output_dir = api_root.join('../../../../packages/sdk/src/types/generated')
  config.comments = true

  # Type names: StoreProduct, AdminProduct, etc.
  config.serializer_name_mapper = ->(serializer) {
    name = serializer.name.to_s
      .sub(/\ASpree::Api::V3::Admin::/, 'Admin')
      .sub(/\ASpree::Api::V3::/, 'Store')
      .sub(/Serializer\z/, '')
    name
  }
end
