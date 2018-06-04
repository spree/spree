Rails.application.configure do
  config.use_paperclip = ActiveModel::Type::Boolean.new.cast ENV['SPREE_USE_PAPERCLIP']
end
