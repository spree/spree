module Spree
  class TaxonIcon < Asset
    include Rails.application.config.use_paperclip ? Configuration::Paperclip : Configuration::ActiveStorage
  end
end
