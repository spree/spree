# Disable automatic type generation on boot — types are generated manually
# via `bundle exec rake typelizer:generate`. Set ENABLE_TYPELIZER=1 to enable.
ENV["DISABLE_TYPELIZER"] ||= "true" unless ENV["ENABLE_TYPELIZER"]

Typelizer.configure do |config|
  api_root = Spree::Api::Engine.root

  config.dirs = [
    api_root.join('app/serializers/spree/api/v3'),
    api_root.join('app/serializers/spree/api/v3/admin')
  ]
  config.output_dir = api_root.join('../../packages/sdk/src/types/generated')
  config.comments = true

  # Type names: StoreProduct, AdminProduct, etc.
  config.serializer_name_mapper = ->(serializer) {
    name = serializer.name.to_s
      .sub(/\ASpree::Api::V3::Admin::/, 'Admin')
      .sub(/\ASpree::Api::V3::/, 'Store')
      .sub(/Serializer\z/, '')
    name
  }

  config.listen = false # https://github.com/skryukov/typelizer?tab=readme-ov-file#automatic-generation-in-development
end
