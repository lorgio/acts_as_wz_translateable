require 'active_record'
require 'action_controller'
require 'active_record/acts/wz_translateable'
require 'action_view/helpers/wz_translateable_helpers'

ActionController::Base.send :include, ActionView::Helpers::WzTranslateableHelpers
ActionView::Base.send :include, ActionView::Helpers::WzTranslateableHelpers
ActiveRecord::Base.send :include, ActiveRecord::Acts::WzTranslateable
