require 'httparty'

module Spree
  class Alert
    def self.current(host)
      params = {
        version: Spree.version,
        name: Spree::Store.current.name,
        host: host,
        rails_env: Rails.env,
        rails_version: Rails.version
      }

      HTTParty.get('http://alerts.spreecommerce.com/alerts.json', query: params).parsed_response
    rescue Errno::ETIMEDOUT
      Rails.logger.warn("Connection to alerts.spreecommerce.com couldn't be established")
    end
  end
end
