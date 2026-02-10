class Spree::Preference < Spree.base_class
  if Rails::VERSION::STRING >= '7.1.0'
    serialize :value, coder: YAML
  else
    serialize :value
  end

  validates :key, presence: true,
                  uniqueness: { case_sensitive: false, allow_blank: true, scope: spree_base_uniqueness_scope }

  if defined?(Spree::Security::Preferences)
    include Spree::Security::Preferences
  end
end
