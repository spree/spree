# Disable automatic type generation on boot — types are generated manually
# via `bundle exec rake typelizer:generate`. Set ENABLE_TYPELIZER=1 to enable.
ENV["DISABLE_TYPELIZER"] ||= "true" unless ENV["ENABLE_TYPELIZER"]

Rails.application.config.after_initialize do
  api_root = Spree::Api::Engine.root

  Typelizer.configure do |config|
    config.dirs = [api_root.join('app/serializers/spree/api/v3')]
    config.comments = true
    config.listen = false

    # Store SDK — no prefix, package provides namespace
    config.writer(:store) do |c|
      c.output_dir = api_root.join('../../packages/sdk/src/types/generated')
      c.reject_class = ->(serializer:) { serializer.name.to_s.include?('::Admin::') }
      c.serializer_name_mapper = ->(serializer) {
        serializer.name.to_s
          .sub(/\ASpree::Api::V3::/, '')
          .sub(/Serializer\z/, '')
      }
    end

    # Admin SDK — no prefix, package provides namespace
    config.writer(:admin) do |c|
      c.output_dir = api_root.join('../../packages/admin-sdk/src/types/generated')
      c.reject_class = ->(serializer:) { !serializer.name.to_s.include?('::Admin::') }
      c.serializer_name_mapper = ->(serializer) {
        serializer.name.to_s
          .sub(/\ASpree::Api::V3::Admin::/, '')
          .sub(/Serializer\z/, '')
      }
    end
  end
end
