# Disable automatic type generation on boot — types are generated manually
# via `bundle exec rake typelizer:generate`. Set ENABLE_TYPELIZER=1 to enable.
ENV["DISABLE_TYPELIZER"] ||= "true" unless ENV["ENABLE_TYPELIZER"]

Rails.application.config.after_initialize do
  api_root = Spree::Api::Engine.root

  Typelizer.configure do |config|
    config.dirs = [api_root.join('app/serializers/spree/api/v3')]
    config.comments = true
    config.listen = false

    # Teach typelizer's Alba plugin about custom Alba types (see alba.rb);
    # unmapped typed attributes crash generation.
    config.plugin_configs = {
      alba: {
        ts_mapper: Typelizer::SerializerPlugins::Alba::ALBA_TS_MAPPER.merge(
          'iso8601' => { type: :string }
        )
      }
    }

    # Serializers that exist only for Admin API or events — no Store API controller
    store_excluded = %w[
      Asset CartPromotion OrderPromotion
      StockLevel StockMovement StockTransfer
      Report Export Import ImportRow
      TaxCategory Exchange ExchangeLineItem
    ].to_set

    # Store SDK — no prefix, package provides namespace
    config.writer(:store) do |c|
      c.output_dir = api_root.join('../../packages/sdk/src/types/generated')
      c.reject_class = ->(serializer:) {
        name = serializer.name.to_s
        name.include?('::Admin::') || name.include?('::Seller::') ||
          store_excluded.include?(name.sub(/\ASpree::Api::V3::/, '').sub(/Serializer\z/, ''))
      }
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

    # Seller SDK — the seller panel's own branch.
    #
    # Emits every `::Seller::` serializer PLUS the store-level serializers a
    # seller serializer nests. Seller serializers extend store ones (a
    # seller's product renders its media, variants and categories through the
    # public shapes — those are exactly what a seller may see of their own
    # record), so the referenced types have to exist in this package too. Admin
    # avoids the same problem by shipping an admin twin of every store
    # serializer it references; the seller branch is deliberately thinner and
    # borrows the store shapes as-is.
    #
    # Store-level names are emitted only when a seller serializer reaches
    # them — the `store_nested_for_seller` set — so this package does not
    # grow into a second copy of the whole store SDK.
    store_nested_for_seller = %w[
      Address Category CustomField Media OptionType OptionValue
      Price PriceHistory Seller Variant
    ].to_set

    config.writer(:seller) do |c|
      c.output_dir = api_root.join('../../packages/seller-sdk/src/types/generated')
      c.reject_class = ->(serializer:) {
        name = serializer.name.to_s
        # Everything on the seller branch is in.
        next false if name.include?('::Seller::')
        # Nothing from the admin branch, ever.
        next true if name.include?('::Admin::')

        # A store-level serializer is in only if a seller serializer nests it.
        bare = name.sub(/\ASpree::Api::V3::/, '').sub(/Serializer\z/, '')
        !store_nested_for_seller.include?(bare)
      }
      c.serializer_name_mapper = ->(serializer) {
        serializer.name.to_s
          .sub(/\ASpree::Api::V3::Seller::/, '')
          .sub(/\ASpree::Api::V3::/, '')
          .sub(/Serializer\z/, '')
      }
    end
  end
end
