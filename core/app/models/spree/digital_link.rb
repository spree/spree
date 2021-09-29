module Spree
  class DigitalLink < ActiveRecord::Base
    belongs_to :digital
    validates :digital, presence: true

    belongs_to :line_item

    validates_length_of :secret, is: 30

    before_validation :set_defaults, on: :create

    # Can this link stil be used? It is valid if it's less than 24 hours old and was not accessed more than 3 times
    def authorizable?
      !(expired? || access_limit_exceeded?)
    end

    def expired?
      created_at <= Spree::DigitalConfiguration[:authorized_days].day.ago
    end

    def access_limit_exceeded?
      access_counter >= Spree::DigitalConfiguration[:authorized_clicks]
    end

    # This method should be called when a download is initiated.
    # It returns +true+ or +false+ depending on whether the authorization is granted.
    def authorize!
      authorizable? && increment!(:access_counter) ? true : false
    end

    def reset!
      update_column :access_counter, 0
      update_column :created_at, Time.now
    end

    private

    # Populating the secret automatically and zero'ing the access_counter (otherwise it might turn out to be NULL)
    def set_defaults
      self.secret = SecureRandom.hex(15)
      self.access_counter ||= 0
    end
  end
end
