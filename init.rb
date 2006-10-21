require 'acts_as_preferenced'

ActiveRecord::Base.class_eval do
  include PluginAWeek::Acts::Preferenced
end