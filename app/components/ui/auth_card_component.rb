# frozen_string_literal: true

# Shared centered-card shell for every Devise view (sign in, sign up, edit
# account, forgot/reset password) so the five auth pages read as one
# consistent system instead of drifting from each other.
class Ui::AuthCardComponent < ViewComponent::Base
  renders_one :body

  def initialize(eyebrow:, title:, breadcrumb_label:)
    @eyebrow = eyebrow
    @title = title
    @breadcrumb_label = breadcrumb_label
  end

  attr_reader :eyebrow, :title, :breadcrumb_label
end
