# frozen_string_literal: true

module CodeSamplesHelper
  SDK_CLIENT_INIT = <<~JS.strip
    import { createSpreeClient } from '@spree/sdk'

    const client = createSpreeClient({
      baseUrl: 'https://your-store.com',
      publishableKey: '<api-key>',
    })
  JS

  def code_samples(*samples)
    metadata[:operation][:'x-codeSamples'] = samples.map do |sample|
      { lang: sample[:lang], label: sample[:label], source: sample[:source].strip }
    end
  end

  def sdk_example(source)
    code_samples(
      {
        lang: 'javascript',
        label: 'Spree SDK',
        source: "#{SDK_CLIENT_INIT}\n\n#{source.strip}\n"
      }
    )
  end
end

RSpec.configure do |config|
  config.extend CodeSamplesHelper, type: :request
end
