  def reset_spree_preferences
    config = Rails.application.config.spree.preferences
    config.reset
    yield(config) if block_given?
  end

