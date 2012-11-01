module Spree
  class OldPrefs < ActiveRecord::Base
    self.table_name = "spree_preferences"
    belongs_to  :owner, :polymorphic => true
    attr_accessor :owner_klass
  end

  class PreferenceRescue
    def self.try
      OldPrefs.where(:key => nil).each do |old_pref|
        next unless owner = (old_pref.owner rescue nil)
        unless old_pref.owner_type == "Spree::Activator" || old_pref.owner_type == "Spree::Configuration"
          begin
            old_pref.key = [owner.class.name, old_pref.name, owner.id].join('::').underscore
            old_pref.value_type = owner.preference_type(old_pref.name)
            puts "Migrating Preference: #{old_pref.key}"
            old_pref.save
          rescue NoMethodError => ex
            puts ex.message
          end
        end
      end
    end
  end
end
