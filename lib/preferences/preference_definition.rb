module Preferences
  # Represents the definition of a preference for a particular model
  class PreferenceDefinition
    def initialize(name, *args) #:nodoc:
      options = args.extract_options!
      options.assert_valid_keys(:default)
      
      @type = args.first ? args.first.to_s : 'boolean'
      
      # Create a column that will be responsible for typecasting
      @column = ActiveRecord::ConnectionAdapters::Column.new(name.to_s, options[:default], @type == 'any' ? nil : @type)
    end
    
    # The name of the preference
    def name
      @column.name
    end
    
    # The default value to use for the preference in case none have been
    # previously defined
    def default_value
      @column.default
    end
    
    # Typecasts the value based on the type of preference that was defined.
    # This uses ActiveRecord's typecast functionality so the same rules for
    # typecasting a model's columns apply here.
    def type_cast(value)
      @type == 'any' ? value : @column.type_cast(value)
    end
    
    # Typecasts the value to true/false depending on the type of preference
    def query(value)
      if !(value = type_cast(value))
        false
      elsif @column.number?
        !value.zero?
      else
        !value.blank?
      end
    end
  end
end
