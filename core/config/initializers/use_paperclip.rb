Rails.application.configure do
  config.use_paperclip = ActiveModel::Type::Boolean.new.cast ENV['USE_PAPERCLIP']
end
