require "#{File.dirname(__FILE__)}/../test_helper"

class PreferencesTest < Test::Unit::TestCase
  def setup
    @user = User.new
  end
  
  def test_should_raise_exception_if_invalid_options_specified
    assert_raise(ArgumentError) {User.preference :notifications, :invalid => true}
    assert_raise(ArgumentError) {User.preference :notifications, :boolean, :invalid => true}
  end
  
  def test_should_create_prefers_query_method
    assert @user.respond_to?(:prefers_notifications?)
  end
  
  def test_should_create_prefers_writer
    assert @user.respond_to?(:prefers_notifications=)
  end
  
  def test_should_create_preferred_reader
    assert @user.respond_to?(:preferred_notifications)
  end
  
  def test_should_create_preferred_writer
    assert @user.respond_to?(:preferred_notifications=)
  end
  
  def test_should_create_preference_definitions
    assert User.respond_to?(:preference_definitions)
  end
  
  def test_should_include_new_definitions_in_preference_definitions
    definition = User.preference :notifications
    assert_equal definition, User.preference_definitions['notifications']
  end
end

class UserByDefaultTest < Test::Unit::TestCase
  def setup
    @user = User.new
  end
  
  def test_should_not_prefer_hot_salsa
    assert_nil @user.preferred_hot_salsa
  end
  
  def test_should_prefer_dark_chocolate
    assert_equal true, @user.preferred_dark_chocolate
  end
  
  def test_should_not_have_a_preferred_color
    assert_nil @user.preferred_color
  end
  
  def test_should_not_have_a_preferred_car
    assert_nil @user.preferred_car
  end
  
  def test_should_have_a_preferred_language
    assert_equal 'English', @user.preferred_language
  end
end

class UserTest < Test::Unit::TestCase
  def setup
    @user = new_user
  end
  
  def test_should_be_able_to_change_hot_salsa_preference
    @user.prefers_hot_salsa = false
    assert_equal false, @user.prefers_hot_salsa?
    
    @user.prefers_hot_salsa = true
    assert_equal true, @user.prefers_hot_salsa?
  end
  
  def test_should_be_able_to_change_dark_chocolate_preference
    @user.prefers_dark_chocolate = false
    assert_equal false, @user.prefers_dark_chocolate?
    
    @user.prefers_dark_chocolate = true
    assert_equal true, @user.prefers_dark_chocolate?
  end
  
  def test_should_be_able_to_change_color_preference
    @user.preferred_color = 'blue'
    assert_equal 'blue', @user.preferred_color
  end
  
  def test_should_be_able_to_change_car_preference
    @user.preferred_car = 1
    assert_equal 1, @user.preferred_car
  end
  
  def test_should_be_able_to_change_language_preference
    @user.preferred_language = 'Latin'
    assert_equal 'Latin', @user.preferred_language
  end
  
  def test_should_be_able_to_use_generic_prefers_query_method
    @user.prefers_hot_salsa = true
    assert @user.prefers?(:hot_salsa)
  end
  
  def test_should_be_able_to_use_generic_preferred_method
    @user.preferred_color = 'blue'
    assert_equal 'blue', @user.preferred(:color)
  end
  
  def test_should_be_able_to_use_generic_set_preference_method
    @user.set_preference(:color, 'blue')
    assert_equal 'blue', @user.preferred(:color)
  end
  
  def test_should_still_be_new_record_after_changing_preference
    @user.preferred_color = 'blue'
    assert @user.new_record?
    assert @user.preferences.empty?
  end
end

class UserAfterBeingCreatedTest < Test::Unit::TestCase
  def setup
    @user = create_user
  end
  
  def test_should_not_have_any_preferences
    assert @user.preferences.empty?
  end
end

class UserWithoutPreferencesTest < Test::Unit::TestCase
  def setup
    @user = create_user
  end
  
  def test_should_not_prefer_hot_salsa
    assert_nil @user.preferred_hot_salsa
  end
  
  def test_should_prefer_dark_chocolate
    assert_equal true, @user.preferred_dark_chocolate
  end
  
  def test_should_not_have_a_preferred_color
    assert_nil @user.preferred_color
  end
  
  def test_should_not_have_a_preferred_car
    assert_nil @user.preferred_car
  end
  
  def test_should_have_a_preferred_language
    assert_equal 'English', @user.preferred_language
  end
  
  def test_should_not_save_record_after_changing_preference
    @user.preferred_language = 'Latin'
    
    user = User.find(@user.id)
    assert_equal 'English', user.preferred_language
    assert user.preferences.empty?
  end
end

class UserWithPreferencesTest < Test::Unit::TestCase
  def setup
    @user = create_user
    @user.preferred_language = 'Latin'
    @user.save!
  end
  
  def test_should_have_preferences
    assert_equal 1, @user.preferences.size
  end
  
  def test_should_not_remove_preference_if_set_to_default
    @user.preferred_language = 'English'
    @user.save!
    @user.reload
    assert_equal 1, @user.preferences.size
  end
  
  def test_should_not_remove_preference_if_set_to_nil
    @user.preferred_language = nil
    @user.save!
    @user.reload
    assert_equal 1, @user.preferences.size
  end
  
  def test_should_not_save_preference_if_model_is_not_saved
    @user.preferred_language = 'English'
    
    user = User.find(@user.id)
    assert_equal 'Latin', user.preferred_language
  end
  
  def test_should_modify_existing_preferences_when_saved
    @user.preferred_language = 'Spanish'
    assert @user.save
    
    @user.reload
    assert_equal 'Spanish', @user.preferred_language
    assert_equal 1, @user.preferences.size
  end
  
  def test_should_add_new_preferences_when_saved
    @user.preferred_color = 'blue'
    assert @user.save
    
    @user.reload
    assert_equal 'blue', @user.preferred_color
    assert_equal 2, @user.preferences.size
  end
end

class UserWithPreferencesForOtherModelsTest < Test::Unit::TestCase
  def setup
    @car = create_car
    
    @user = create_user
    @user.preferred_color = 'red', {:for => @car}
    @user.save!
  end
  
  def test_should_have_preferences
    assert_equal 1, @user.preferences.size
  end
  
  def test_should_not_have_preference_without_preferenced_record
    assert_nil @user.preferred_color
  end
  
  def test_should_have_preference_with_preferenced_record
    assert_equal 'red', @user.preferred_color(:for => @car)
  end
  
  def test_should_modify_existing_preferences_when_saved
    @user.preferred_color = 'blue', {:for => @car}
    assert @user.save
    
    @user.reload
    assert_equal 'blue', @user.preferred_color(:for => @car)
    assert_equal 1, @user.preferences.size
  end
  
  def test_should_be_able_to_differentiate_between_preferenced_records
    @different_car = create_car
    
    @user.preferred_color = 'blue', {:for => @different_car}
    assert @user.save
    
    @user.reload
    assert_equal 'red', @user.preferred_color(:for => @car)
    assert_equal 'blue', @user.preferred_color(:for => @different_car)
    assert_equal 2, @user.preferences.size
  end
end
