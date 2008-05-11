require "#{File.dirname(__FILE__)}/../test_helper"

class PreferenceByDefaultTest < Test::Unit::TestCase
  def setup
    @preference = Preference.new
  end
  
  def test_should_not_have_an_attribute
    assert @preference.attribute.blank?
  end
  
  def test_should_not_have_an_owner
    assert_nil @preference.owner_id
  end
  
  def test_should_not_have_an_owner_type
    assert @preference.owner_type.blank?
  end
  
  def test_should_not_have_a_preferenced_association
    assert_nil @preference.preferenced_id
  end
  
  def test_should_not_have_a_preferenced_type
    assert @preference.preferenced_type.nil?
  end
  
  def test_should_not_have_a_value
    assert @preference.value.blank?
  end
  
  def test_should_not_have_a_definition
    assert_nil @preference.definition
  end
end

class PreferenceTest < Test::Unit::TestCase
  def test_should_be_valid_with_a_set_of_valid_attributes
    preference = new_preference
    assert preference.valid?
  end
  
  def test_should_require_an_attribute
    preference = new_preference(:attribute => nil)
    assert !preference.valid?
    assert_equal 1, Array(preference.errors.on(:attribute)).size
  end
  
  def test_should_require_an_owner_id
    preference = new_preference(:owner => nil)
    assert !preference.valid?
    assert_equal 1, Array(preference.errors.on(:owner_id)).size
  end
  
  def test_should_require_an_owner_type
    preference = new_preference(:owner => nil)
    assert !preference.valid?
    assert_equal 1, Array(preference.errors.on(:owner_type)).size
  end
  
  def test_should_not_require_a_preferenced_id
    preference = new_preference(:preferenced => nil)
    assert preference.valid?
  end
  
  def test_should_require_a_preferenced_id_if_specified
    preference = new_preference(:preferenced => nil)
    preference.preferenced_type = 'Car'
    assert !preference.valid?
    assert_equal 1, Array(preference.errors.on(:preferenced_id)).size
  end
  
  def test_should_not_require_a_preferenced_type
    preference = new_preference(:preferenced => nil)
    assert preference.valid?
  end
  
  def test_should_require_a_preferenced_type_if_specified
    preference = new_preference(:preferenced => nil)
    preference.preferenced_id = 1
    assert !preference.valid?
    assert_equal 1, Array(preference.errors.on(:preferenced_type)).size
  end
end

class PreferenceAfterBeingCreatedTest < Test::Unit::TestCase
  def setup
    User.preference :notifications, :boolean
    
    @preference = create_preference(:attribute => 'notifications')
  end
  
  def test_should_have_an_owner
    assert_not_nil @preference.owner
  end
  
  def test_should_have_a_definition
    assert_not_nil @preference.definition
  end
  
  def test_should_have_a_value
    assert_not_nil @preference.value
  end
  
  def test_should_not_have_a_preferenced_association
    assert_nil @preference.preferenced
  end
end

class PreferenceWithPreferencedAssociationTest < Test::Unit::TestCase
  def setup
    @preference = create_preference(:preferenced => create_car)
  end
  
  def test_should_have_a_preferenced_association
    assert_not_nil @preference.preferenced
  end
end

class PreferenceWithBooleanAttributeTest < Test::Unit::TestCase
  def setup
    User.preference :notifications, :boolean
  end
  
  def test_should_type_cast_nil_values
    preference = new_preference(:attribute => 'notifications', :value => nil)
    assert_nil preference.value
  end
  
  def test_should_type_cast_numeric_values
    preference = new_preference(:attribute => 'notifications', :value => 0)
    assert_equal false, preference.value
    
    preference.value = 1
    assert_equal true, preference.value
  end
  
  def test_should_type_cast_boolean_values
    preference = new_preference(:attribute => 'notifications', :value => false)
    assert_equal false, preference.value
    
    preference.value = true
    assert_equal true, preference.value
  end
end
