class ModelCacheCleaner < ActiveRecord::Observer
  observe :shipping_method, :zone

  def after_save(object)
    return unless Rails.configuration.cache_classes
    #clear cache collection
    Rails.cache.delete("#{object.class}.all")

    #pre-warn cache with new data
    object.class.cached
  end

end
