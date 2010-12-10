require File.join(File.dirname(__FILE__), 'abstract_unit')
require File.join(File.dirname(__FILE__), 'fixtures/page')
require 'helper'

class PagesTest < Test::Unit::TestCase
  def test_create_translation_object
    p = Page.create! :title => 'first title', :body => 'first body'
    assert p.translations
    assert(p.translations.size == 1)
  end
  
  def test_add_translation
    p = Page.create! :title => 'first title', :body => 'first body', :language => 'en'
    trans = p.translations.find_or_create_by_language('en')
    assert(p.translations.size == 1) 
    
    # now with 2 translations
    trans = p.translations.find_or_create_by_language('de')
    assert(p.translations.size == 2) 
  end
  
  def test_change_main_translation
    p = Page.create! :title => 'first title', :body => 'first body', :language => 'en'
    
    # now with 2 translations
    trans = p.translations.find_or_create_by_language('de')
    trans.title = "erster titel"
    trans.body  = "erster body"
    assert(trans.save)
    
    p.title = 'first title - 1'
    assert(p.save)
    
    trans2 = p.translations.find_or_create_by_language('en')
    assert(trans2.title == p.title)
  end
  
  def test_get_translations
    p = Page.create! :title => 'first title', :body => 'first body', :language => 'en'
    
    # now with 2 translations
    trans = p.translations.find_or_create_by_language('de')
    trans.title = "erster titel"
    trans.body  = "erster body"
    assert(trans.save)
    
    I18n.locale = :en
    assert(p.get_field_translation('title') == "first title")

    I18n.locale = :de
    assert(p.get_field_translation('title') == "erster titel")
  end
  
  def compare_pages(first, second)
    assert(first.translations.size == second.translations.size)
    first.translations.each_with_index do |translation, i|
      compare_trans = second.translations.detect {|entry| entry.language == translation.language}
      assert(compare_trans)
      assert(translation.title == compare_trans.title)
      assert(translation.body == compare_trans.body)
      assert(translation.language == compare_trans.language)
    end 
  end
  
  def test_deep_clone
    p = Page.create! :title => 'first title', :body => 'first body', :language => 'en'
    
    # now with 2 translations
    trans = p.translations.find_or_create_by_language('de')
    trans.title = "erster titel"
    trans.body  = "erster body"
    assert(trans.save)
    trans.reload
    
    newobj = p.clone
    assert(newobj)
    compare_pages(newobj, p)
  end
  
  def test_assign_translation
    p = Page.find(1)
    assert(p)
    assert(p.translations.size == 2)
    
    dummy = Page.create! :title => 'dummy title', :body => 'dummy body', :language => 'en'
    
    # now with 2 translations
    trans = dummy.translations.find_or_create_by_language('de')
    trans.title = "dummy titel"
    trans.body  = "dummy körper"
    assert(trans.save)
    
    p.reload
    
    Page.copy_translation_fields(p, dummy)
    dummy.assign_translations(p)
    
    compare_pages(dummy, p)
  end
  
end
