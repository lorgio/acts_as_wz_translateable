module ActionView
  module Helpers
    module WzTranslateableHelpers
      #field translations, with error text if not found!
      def wztranslate(obj, field, options = {})
        translation = obj.get_field_translation(field, options)
        translation || "!#{obj.class.name}:#{field} (#{obj.get_current_language})!"
      end
  
      #shorthand 
      alias :wzt :wztranslate

      #translation with default language language fallback
      def wztranslate_with_fallback(obj, field, options = {})
        translation = obj.get_field_translation(field, options.merge({:when_missing_use_default => true}))
      end
  
      #shorthand
      alias :wztwf :wztranslate_with_fallback
    end
  end
end