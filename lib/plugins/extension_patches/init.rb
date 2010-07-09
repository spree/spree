#######################################################################################################
# Substantial portions of this code were adapted from the Radiant CMS project (http://radiantcms.org) #
#######################################################################################################

require 'routing_extension'
require 'mailer_hack'
require 'fixture_loading_extension' if Rails.env == 'test'
require 'asset_copy'