module Spree
  class Activator < ActiveRecord::Base
    attr_accessible :event_name, :as => :internal

    cattr_accessor :event_names

    self.event_names = [
      'spree.cart.add',
      'spree.order.contents_changed',
      'spree.user.signup'
    ]

    def self.register_event_name(name)
      self.event_names << name
    end

    scope :event_name_starts_with, lambda{ |name| where('event_name LIKE ?', "#{name}%") }
    scope :active, where('(starts_at IS NULL OR starts_at < ?) AND (expires_at IS NULL OR expires_at > ?)', Time.now, Time.now)

    def activate(payload)
    end

    def expired?
      starts_at && Time.now < starts_at ||
      expires_at && Time.now > expires_at
    end
  end
end
