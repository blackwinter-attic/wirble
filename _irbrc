######################################################################
# _irbrc - Sample .irbrc file to enable Wirble.                      #
######################################################################

#
# Uncomment the block below if you want to load RubyGems in Irb.
#

# begin 
#   require 'rubygems'
# rescue LoadError => err
#   warn "Couldn't load RubyGems: #{err}"
# end

begin 
  # load and initialize wirble
  require 'wirble'
  Wirble.init
  
  #
  # Uncomment the line below to enable Wirble colors.
  # 

  # Wirble.colorize
rescue LoadError => err
  warn "Couldn't load Wirble: #{err}"
end
