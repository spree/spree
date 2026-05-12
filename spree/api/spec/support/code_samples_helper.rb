# frozen_string_literal: true

module CodeSamplesHelper
  SDK_CLIENT_INIT = <<~JS.strip
    import { createClient } from '@spree/sdk'

    const client = createClient({
      baseUrl: 'https://your-store.com',
      publishableKey: '<api-key>',
    })
  JS

  ADMIN_SDK_CLIENT_INIT = <<~JS.strip
    import { createAdminClient } from '@spree/admin-sdk'

    const client = createAdminClient({
      baseUrl: 'https://your-store.com',
      secretKey: 'sk_xxx',
    })
  JS

  SDK_EXAMPLES_ROOT = File.expand_path('../../../../packages/sdk/examples', __dir__)
  ADMIN_SDK_EXAMPLES_ROOT = File.expand_path('../../../../packages/admin-sdk/examples', __dir__)

  # Match `// region:example` / `// endregion:example` markers and extract
  # the body between them. The markers can have arbitrary indentation.
  SDK_EXAMPLE_REGION = /^[ \t]*\/\/\s*region:example\s*\n(.*?)^[ \t]*\/\/\s*endregion:example/m

  EXAMPLE_CACHE = {}

  def code_samples(*samples)
    metadata[:operation][:'x-codeSamples'] = samples.map do |sample|
      { lang: sample[:lang], label: sample[:label], source: sample[:source].strip }
    end
  end

  # Renders a Store SDK code sample from a typechecked example file under
  # `packages/sdk/examples/`. The file must be a complete `.ts` module
  # (imports + `createClient` initializer) so `tsc` can verify it against
  # the live SDK types; the helper extracts only the body between
  # `// region:example` / `// endregion:example` markers and re-prepends
  # the canonical client init block so rendered docs stay consistent
  # across endpoints.
  #
  #   sdk_example 'products/list'
  #     → packages/sdk/examples/products/list.ts
  def sdk_example(name)
    source = EXAMPLE_CACHE[[:store, name]] ||= load_example_body(SDK_EXAMPLES_ROOT, name, 'Store SDK')
    code_samples(
      {
        lang: 'javascript',
        label: 'Spree SDK',
        source: "#{SDK_CLIENT_INIT}\n\n#{source}\n"
      }
    )
  end

  # Mirrors `sdk_example` for the admin SDK — examples live under
  # `packages/admin-sdk/examples/` and the canonical init block uses
  # `createAdminClient`.
  def admin_sdk_example(name)
    source = EXAMPLE_CACHE[[:admin, name]] ||= load_example_body(ADMIN_SDK_EXAMPLES_ROOT, name, 'Admin SDK')
    code_samples(
      {
        lang: 'javascript',
        label: 'Spree Admin SDK',
        source: "#{ADMIN_SDK_CLIENT_INIT}\n\n#{source}\n"
      }
    )
  end

  def load_example_body(root, name, label)
    path = File.join(root, "#{name}.ts")
    raise "#{label} example not found: #{path}" unless File.exist?(path)

    body = File.read(path).match(SDK_EXAMPLE_REGION)&.captures&.first
    raise "#{label} example #{name.inspect} has no `// region:example` marker" if body.nil?

    body.rstrip.strip_heredoc.strip
  end

  # Appends a `**Required scope:**` line to the operation description.
  # Use in admin integration specs to surface scope requirements in the
  # rendered Mintlify docs without inventing a custom OpenAPI extension.
  #
  #   admin_scope :read, :orders
  #   admin_scope :write, :customers
  def admin_scope(action, resource)
    line = "**Required scope:** `#{action}_#{resource}` (for API-key authentication)."
    existing = metadata[:operation][:description].to_s
    metadata[:operation][:description] = existing.empty? ? line : "#{existing}\n\n#{line}"
  end
end

RSpec.configure do |config|
  config.extend CodeSamplesHelper, type: :request
end
