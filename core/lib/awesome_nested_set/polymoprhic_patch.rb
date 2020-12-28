# https://github.com/collectiveidea/awesome_nested_set/issues/420

module PolymorphicBelongsTo
  def valid_options(options)
    valid = super + [:polymorphic, :counter_cache, :optional, :default]
    valid += [:foreign_type] if options[:polymorphic]
    valid += [:ensuring_owner_was] if options[:dependent] == :destroy_async
    valid
  end
end

if Rails::VERSION::STRING >= '6.1'
  ActiveSupport.on_load :active_record do
    ActiveRecord::Associations::Builder::BelongsTo.extend PolymorphicBelongsTo
  end
end
