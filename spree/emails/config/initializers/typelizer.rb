# Generates TypeScript types for the data customer email templates receive,
# into @spree/admin-sdk as Email* types, for the dashboard's template editor.
# Runs only under `bundle exec rake typelizer:generate`.
Rails.application.config.after_initialize do
  next unless defined?(Typelizer) && ENV['ENABLE_TYPELIZER']

  emails_root = Spree::Emails::Engine.root

  # Core's email serializers cannot depend on Typelizer, and two of the
  # customer email serializers stand alone, so they get its DSL here.
  [Spree::Emails::BaseSerializer, Spree::Emails::AmountLineSerializer, Spree::Emails::FulfillmentGroupSerializer].each do |serializer|
    serializer.extend(Typelizer::DSL) unless serializer.respond_to?(:typelize)
  end

  Spree::Emails::AmountLineSerializer.typelize(label: [:string, nullable: true], amount: :string, display_amount: :string)
  Spree::Emails::FulfillmentGroupSerializer.typelize(name: [:string, nullable: true], unpriced: :boolean, cost: :string,
                                                     display_cost: :string,
                                                     seller_names: [:string, multi: true],
                                                     # Declared before Typelizer's hooks were attached, so it
                                                     # cannot tell this association is a list.
                                                     items: [:EmailParcelItem, multi: true])
  Spree::Emails::ParcelItemSerializer.typelize(
    id: :string, name: :string, quantity: :number, sku: [:string, nullable: true], options_text: [:string, nullable: true],
    price: :string, amount: :string, display_price: :string, display_amount: :string, url: [:string, nullable: true],
    image_url: [:string, nullable: true]
  )
  Spree::Emails::StoreSerializer.typelize(
    id: :string, name: :string, address: [:string, nullable: true], mail_from_address: :string, default_currency: :string,
    default_locale: :string, url: :string, support_email: :string, logo_url: [:string, nullable: true],
    logo_width: [:number, nullable: true],
    branding: '{ background_color: string; card_color: string; text_color: string; heading_color: string; ' \
              'accent_color: string | null; link_color: string; button_color: string; button_text_color: string; ' \
              'button_border: string; font: string; font_family: string; heading_font_family: string; font_url: string | null }'
  )

  # Staff emails are not editable, so their data has no type.
  staff = %w[User Invitation Import Export WebhookEndpoint].to_set

  Typelizer.configure do |config|
    config.dirs += [emails_root.join('app/serializers/spree/emails'), Spree::Core::Engine.root.join('app/serializers/spree/emails')]

    # Their own folder in the admin SDK; the Store API types they nest
    # (Payment, Address, ...) import from the admin SDK's types of that name.
    # Self-contained in their own folder: every record an email serializes has
    # an email serializer of its own, so these types describe exactly what
    # templates receive.
    config.writer(:emails, from: :admin) do |c|
      c.output_dir = emails_root.join('../../packages/admin-sdk/src/types/generated/emails')
      c.types_import_path = '.'
      c.reject_class = ->(serializer:) {
        name = serializer.name.to_s
        bare = name.delete_prefix('Spree::Emails::').delete_suffix('Serializer')
        !name.start_with?('Spree::Emails::') || staff.include?(bare) || bare == 'Base'
      }
      c.serializer_name_mapper = ->(serializer) {
        "Email#{serializer.name.to_s.delete_prefix('Spree::Emails::').delete_suffix('Serializer')}"
      }
      # Associations a request must ask for (`expand`) never reach an email.
      c.properties_transformer = ->(properties) { properties.reject(&:optional) }
    end
  end
end
