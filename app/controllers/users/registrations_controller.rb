# frozen_string_literal: true

# Extends Devise's default registrations controller for one Zoomora-specific
# side effect: the "Subscribe to email marketing" checkbox on sign-up
# creates a real NewsletterSubscriber row (reusing the same model the
# footer's newsletter form writes to) rather than being a decorative field
# that silently does nothing when checked.
class Users::RegistrationsController < Devise::RegistrationsController
  private

  def sign_up(resource_name, resource)
    super
    subscribe_to_newsletter(resource) if resource.persisted? && subscribe_to_newsletter?
  end

  def subscribe_to_newsletter?
    ActiveModel::Type::Boolean.new.cast(params.dig(:user, :subscribe_to_newsletter))
  end

  def subscribe_to_newsletter(user)
    NewsletterSubscriber.find_or_create_by(email: user.email)
  end
end
