require 'preferences/preference_definition'

module PluginAWeek #:nodoc:
  # Adds support for defining preferences on ActiveRecord models.
  # 
  # == Saving preferences
  # 
  # Preferences are not automatically saved when they are set.  You must save
  # the record that the preferences were set on.
  # 
  # For example,
  # 
  #   class User < ActiveRecord::Base
  #     preference :notifications
  #   end
  #   
  #   u = User.new(:login => 'admin', :prefers_notifications => false)
  #   u.save!
  #   
  #   u = User.find_by_login('admin')
  #   u.attributes = {:prefers_notifications => true}
  #   u.save!
  module Preferences
    def self.included(base) #:nodoc:
      base.class_eval do
        extend PluginAWeek::Preferences::MacroMethods
      end
    end
    
    module MacroMethods
      # Defines a new preference for all records in the model.  By default, preferences
      # are assumed to have a boolean data type, so all values will be typecasted
      # to true/false based on ActiveRecord rules.
      # 
      # Configuration options:
      # * +default+ - The default value for the preference. Default is nil.
      # 
      # == Examples
      # 
      # The example below shows the various ways to define a preference for a
      # particular model.
      # 
      #   class User < ActiveRecord::Base
      #     preference :notifications, :default => false
      #     preference :color, :string, :default => 'red'
      #     preference :favorite_number, :integer
      #     preference :data, :any # Allows any data type to be stored
      #   end
      # 
      # All preferences are also inherited by subclasses.
      # 
      # == Associations
      # 
      # After the first preference is defined, the following associations are
      # created for the model:
      # * +preferences+ - A collection of all the preferences specified for a record
      # 
      # == Generated shortcut methods
      # 
      # In addition to calling <tt>prefers?</tt> and +preferred+ on a record, you
      # can also use the shortcut methods that are generated when a preference is
      # defined.  For example,
      # 
      #   class User < ActiveRecord::Base
      #     preference :notifications
      #   end
      # 
      # ...generates the following methods:
      # * <tt>prefers_notifications?</tt> - The same as calling <tt>record.prefers?(:notifications)</tt>
      # * <tt>prefers_notifications=(value)</tt> - The same as calling <tt>record.set_preference(:notifications, value)</tt>
      # * <tt>preferred_notifications</tt> - The same as called <tt>record.preferred(:notifications)</tt>
      # * <tt>preferred_notifications=(value)</tt> - The same as calling <tt>record.set_preference(:notifications, value)</tt>
      # 
      # Notice that there are two tenses used depending on the context of the
      # preference.  Conventionally, <tt>prefers_notifications?</tt> is better
      # for boolean preferences, while +preferred_color+ is better for non-boolean
      # preferences.
      # 
      # Example:
      # 
      #   user = User.find(:first)
      #   user.prefers_notifications?     # => false
      #   user.prefers_color?             # => true
      #   user.preferred_color            # => 'red'
      #   user.preferred_color = 'blue'   # => 'blue'
      #   
      #   user.prefers_notifications = true
      #   
      #   car = Car.find(:first)
      #   user.preferred_color = 'red', {:for => car}   # => 'red'
      #   user.preferred_color(:for => car)             # => 'red'
      #   user.prefers_color?(:for => car)              # => true
      #   
      #   user.save!  # => true
      def preference(attribute, *args)
        unless included_modules.include?(InstanceMethods)
          class_inheritable_hash :preference_definitions
          
          has_many  :preferences,
                      :as => :owner
          
          after_save :update_preferences
          
          include PluginAWeek::Preferences::InstanceMethods
        end
        
        # Create the definition
        attribute = attribute.to_s
        definition = PreferenceDefinition.new(attribute, *args)
        self.preference_definitions = {attribute => definition}
        
        # Create short-hand helper methods, making sure that the attribute
        # is method-safe in terms of what characters are allowed
        attribute = attribute.gsub(/[^A-Za-z0-9_-]/, '').underscore
        class_eval <<-end_eval
          def prefers_#{attribute}?(options = {})
            prefers?(#{attribute.dump}, options)
          end
          
          def prefers_#{attribute}=(args)
            set_preference(*([#{attribute.dump}] + [args].flatten))
          end
          
          def preferred_#{attribute}(options = {})
            preferred(#{attribute.dump}, options)
          end
          
          alias_method :preferred_#{attribute}=, :prefers_#{attribute}=
        end_eval
        
        definition
      end
    end
    
    module InstanceMethods
      # Queries whether or not a value has been specified for the given attribute.
      # This is dependent on how the value is type-casted.
      # 
      # Configuration options:
      # * +for+ - The record being preferenced
      # 
      # == Examples
      # 
      #   user = User.find(:first)
      #   user.prefers?(:notifications)   # => true
      #   
      #   newsgroup = Newsgroup.find(:first)
      #   user.prefers?(:notifications, :for => newsgroup)  # => false
      def prefers?(attribute, options = {})
        attribute = attribute.to_s
        
        value = preferred(attribute, options)
        preference_definitions[attribute].query(value)
      end
      
      # Gets the preferred value for the given attribute.
      # 
      # Configuration options:
      # * +for+ - The record being preferenced
      # 
      # == Examples
      # 
      #   user = User.find(:first)
      #   user.preferred(:color)    # => 'red'
      #   
      #   car = Car.find(:first)
      #   user.preferred(:color, :for => car) # => 'black'
      def preferred(attribute, options = {})
        options.assert_valid_keys(:for)
        attribute = attribute.to_s
        
        if @preference_values && @preference_values[attribute] && @preference_values[attribute].include?(options[:for])
          value = @preference_values[attribute][options[:for]]
        else
          preferenced_id, preferenced_type = options[:for].id, options[:for].class.base_class.name.to_s if options[:for]
          preference = preferences.find(:first, :conditions => {:attribute => attribute, :preferenced_id => preferenced_id, :preferenced_type => preferenced_type})
          value = preference ? preference.value : preference_definitions[attribute].default_value
        end
        
        value
      end
      
      # Sets a new value for the given attribute.  The actual Preference record
      # is *not* created until the actual record is saved.
      # 
      # Configuration options:
      # * +for+ - The record being preferenced
      # 
      # == Examples
      # 
      #   user = User.find(:first)
      #   user.set_preference(:notifications, false) # => false
      #   user.save!
      #   
      #   newsgroup = Newsgroup.find(:first)
      #   user.set_preference(:notifications, true, :for => newsgroup)  # => true
      #   user.save!
      def set_preference(attribute, value, options = {})
        options.assert_valid_keys(:for)
        attribute = attribute.to_s
        
        @preference_values ||= {}
        @preference_values[attribute] ||= {}
        @preference_values[attribute][options[:for]] = value
        
        value
      end
      
      private
        # Updates any preferences that have been changed/added since the record
        # was last saved
        def update_preferences
          if @preference_values
            @preference_values.each do |attribute, preferenced_records|
              preferenced_records.each do |preferenced, value|
                preferenced_id, preferenced_type = preferenced.id, preferenced.class.base_class.name.to_s if preferenced
                attributes = {:attribute => attribute, :preferenced_id => preferenced_id, :preferenced_type => preferenced_type}
                
                # Find an existing preference or build a new one
                preference = preferences.find(:first, :conditions => attributes) ||  preferences.build(attributes)
                preference.value = value
                preference.save!
              end
            end
            
            @preference_values = nil
          end
        end
    end
  end
end

ActiveRecord::Base.class_eval do
  include PluginAWeek::Preferences
end
