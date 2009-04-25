require 'preferences/preference_definition'

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
# 
# == Validations
# 
# Since the generated accessors for a preference allow the preference to be
# treated just like regular ActiveRecord attributes, they can also be
# validated against in the same way.  For example,
# 
#   class User < ActiveRecord::Base
#     preference :color, :string
#     
#     validates_presence_of :preferred_color
#     validates_inclusion_of :preferred_color, :in => %w(red green blue)
#   end
#   
#   u = User.new
#   u.valid?                        # => false
#   u.errors.on(:preferred_color)   # => "can't be blank"
#   
#   u.preferred_color = 'white'
#   u.valid?                        # => false
#   u.errors.on(:preferred_color)   # => "is not included in the list"
#   
#   u.preferred_color = 'red'
#   u.valid?                        # => true
module Preferences
  module MacroMethods
    # Defines a new preference for all records in the model.  By default,
    # preferences are assumed to have a boolean data type, so all values will
    # be typecasted to true/false based on ActiveRecord rules.
    # 
    # Configuration options:
    # * <tt>:default</tt> - The default value for the preference. Default is nil.
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
    # * +stored_preferences+ - A collection of all the custom preferences
    #   specified for a record.  This will not include default preferences
    #   unless they have been explicitly set.
    # 
    # == Generated accessors
    # 
    # In addition to calling <tt>prefers?</tt> and +preferred+ on a record,
    # you can also use the shortcut accessor methods that are generated when a
    # preference is defined.  For example,
    # 
    #   class User < ActiveRecord::Base
    #     preference :notifications
    #   end
    # 
    # ...generates the following methods:
    # * <tt>prefers_notifications?</tt> - Whether a value has been specified, i.e. <tt>record.prefers?(:notifications)</tt>
    # * <tt>prefers_notifications</tt> - The actual value stored, i.e. <tt>record.prefers(:notifications)</tt>
    # * <tt>prefers_notifications=(value)</tt> - Sets a new value, i.e. <tt>record.set_preference(:notifications, value)</tt>
    # * <tt>preferred_notifications?</tt> - Whether a value has been specified, i.e. <tt>record.preferred?(:notifications)</tt>
    # * <tt>preferred_notifications</tt> - The actual value stored, i.e. <tt>record.preferred(:notifications)</tt>
    # * <tt>preferred_notifications=(value)</tt> - Sets a new value, i.e. <tt>record.set_preference(:notifications, value)</tt>
    # 
    # Notice that there are two tenses used depending on the context of the
    # preference.  Conventionally, <tt>prefers_notifications?</tt> is better
    # for accessing boolean preferences, while +preferred_color+ is better for
    # accessing non-boolean preferences.
    # 
    # Example:
    # 
    #   user = User.find(:first)
    #   user.prefers_notifications?         # => false
    #   user.prefers_notifications          # => false
    #   user.preferred_color?               # => true
    #   user.preferred_color                # => 'red'
    #   user.preferred_color = 'blue'       # => 'blue'
    #   
    #   user.prefers_notifications = true
    #   
    #   car = Car.find(:first)
    #   user.preferred_color = 'red', car   # => 'red'
    #   user.preferred_color(car)           # => 'red'
    #   user.preferred_color?(car)          # => true
    #   
    #   user.save!  # => true
    def preference(name, *args)
      unless included_modules.include?(InstanceMethods)
        class_inheritable_hash :preference_definitions
        self.preference_definitions = {}
        
        class_inheritable_hash :default_preferences
        self.default_preferences = {}
        
        has_many :stored_preferences, :as => :owner, :class_name => 'Preference'
        
        after_save :update_preferences
        
        include Preferences::InstanceMethods
      end
      
      # Create the definition
      name = name.to_s
      definition = PreferenceDefinition.new(name, *args)
      self.preference_definitions[name] = definition
      self.default_preferences[name] = definition.default_value
      
      # Create short-hand accessor methods, making sure that the name
      # is method-safe in terms of what characters are allowed
      name = name.gsub(/[^A-Za-z0-9_-]/, '').underscore
      
      # Query lookup
      define_method("preferred_#{name}?") do |*group|
        preferred?(name, group.first)
      end
      alias_method "prefers_#{name}?", "preferred_#{name}?"
      
      # Reader
      define_method("preferred_#{name}") do |*group|
        preferred(name, group.first)
      end
      alias_method "prefers_#{name}", "preferred_#{name}"
      
      # Writer
      define_method("preferred_#{name}=") do |*args|
        set_preference(*([name] + [args].flatten))
      end
      alias_method "prefers_#{name}=", "preferred_#{name}="
      
      definition
    end
  end
  
  module InstanceMethods
    def self.included(base) #:nodoc:
      base.class_eval do
        alias_method :prefs, :preferences
      end
    end
    
    # Finds all preferences, including defaults, for the current record.  If
    # any custom group preferences have been stored, then this will include
    # all default preferences within that particular group.
    # 
    # == Examples
    # 
    # A user with no stored values:
    # 
    #   user = User.find(:first)
    #   user.preferences
    #   => {"language"=>"English", "color"=>nil}
    #   
    # A user with stored values for a particular group:
    # 
    #   user.preferred_color = 'red', 'cars'
    #   user.preferences
    #   => {"language"=>"English", "color"=>nil, "cars"=>{"language=>"English", "color"=>"red"}}
    #   
    # Getting preference values *just* for the owning record (i.e. excluding groups):
    # 
    #   user.preferences(nil)
    #   => {"language"=>"English", "color"=>nil}
    #   
    # Getting preference values for a particular group:
    # 
    #   user.preferences('cars')
    #   => {"language"=>"English", "color"=>"red"}
    def preferences(*args)
      if args.empty?
        group = nil
        conditions = {}
      else
        group = args.first
        
        # Split the actual group into its different parts (id/type) in case
        # a record is passed in
        group_id, group_type = Preference.split_group(group)
        conditions = {:group_id => group_id, :group_type => group_type}
      end
      
      # Find all of the stored preferences
      stored_preferences = self.stored_preferences.find(:all, :conditions => conditions)
      
      # Hashify name -> value or group -> name -> value
      stored_preferences.inject(self.class.default_preferences.dup) do |all_preferences, preference|
        if !group && (preference_group = preference.group)
          preferences = all_preferences[preference_group] ||= self.class.default_preferences.dup
        else
          preferences = all_preferences
        end
        
        preferences[preference.name] = preference.value
        all_preferences
      end
    end
    
    # Queries whether or not a value is present for the given preference.
    # This is dependent on how the value is type-casted.
    # 
    # == Examples
    # 
    #   class User < ActiveRecord::Base
    #     preference :color, :string, :default => 'red'
    #   end
    #   
    #   user = User.create
    #   user.preferred(:color)              # => "red"
    #   user.preferred?(:color)             # => true
    #   user.preferred?(:color, 'cars')     # => true
    #   user.preferred?(:color, Car.first)  # => true
    #   
    #   user.set_preference(:color, nil)
    #   user.preferred(:color)              # => nil
    #   user.preferred?(:color)             # => false
    def preferred?(name, group = nil)
      name = name.to_s
      
      value = preferred(name, group)
      preference_definitions[name].query(value)
    end
    alias_method :prefers?, :preferred?
    
    # Gets the actual value stored for the given preference, or the default
    # value if nothing is present.
    # 
    # == Examples
    # 
    #   class User < ActiveRecord::Base
    #     preference :color, :string, :default => 'red'
    #   end
    #   
    #   user = User.create
    #   user.preferred(:color)            # => "red"
    #   user.preferred(:color, 'cars')    # => "red"
    #   user.preferred(:color, Car.first) # => "red"
    #   
    #   user.set_preference(:color, 'blue')
    #   user.preferred(:color)            # => "blue"
    def preferred(name, group = nil)
      name = name.to_s
      
      if @preference_values && @preference_values[group] && @preference_values[group].include?(name)
        # Value for this group/name has been written, but not saved yet:
        # grab from the pending values
        value = @preference_values[group][name]
      else
        # Split the group being filtered
        group_id, group_type = Preference.split_group(group)
        
        # Grab the first preference; if it doesn't exist, use the default value
        preference = stored_preferences.find(:first, :conditions => {:name => name, :group_id => group_id, :group_type => group_type})
        value = preference ? preference.value : preference_definitions[name].default_value
      end
      
      value
    end
    alias_method :prefers, :preferred
    
    # Sets a new value for the given preference.  The actual Preference record
    # is *not* created until this record is saved.  In this way, preferences
    # act *exactly* the same as attributes.  They can be written to and
    # validated against, but won't actually be written to the database until
    # the record is saved.
    # 
    # == Examples
    # 
    #   user = User.find(:first)
    #   user.set_preference(:color, 'red')              # => "red"
    #   user.save!
    #   
    #   user.set_preference(:color, 'blue', Car.first)  # => "blue"
    #   user.save!
    def set_preference(name, value, group = nil)
      name = name.to_s
      
      @preference_values ||= {}
      @preference_values[group] ||= {}
      @preference_values[group][name] = value
      
      value
    end
    
    private
      # Updates any preferences that have been changed/added since the record
      # was last saved
      def update_preferences
        if @preference_values
          @preference_values.each do |group, new_preferences|
            group_id, group_type = Preference.split_group(group)
            
            new_preferences.each do |name, value|
              attributes = {:name => name, :group_id => group_id, :group_type => group_type}
              
              # Find an existing preference or build a new one
              preference = stored_preferences.find(:first, :conditions => attributes) ||  stored_preferences.build(attributes)
              preference.value = value
              preference.save!
            end
          end
          
          @preference_values = nil
        end
      end
  end
end

ActiveRecord::Base.class_eval do
  extend Preferences::MacroMethods
end
