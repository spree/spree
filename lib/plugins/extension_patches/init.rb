#######################################################################################################
# Substantial portions of this code were adapted from the Radiant CMS project (http://radiantcms.org) #
#######################################################################################################

require 'routing_extension'
require 'mailer_hack'
require 'fixture_loading_extension' if RAILS_ENV == 'test'
require 'asset_copy'