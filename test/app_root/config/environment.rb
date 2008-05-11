require 'config/boot'
require "#{File.dirname(__FILE__)}/../../../../plugins_plus/boot"

Rails::Initializer.run do |config|
  config.plugin_paths << '..'
  config.plugins = %w(plugins_plus preferences)
  config.cache_classes = false
  config.whiny_nils = true
end
