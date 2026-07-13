# frozen_string_literal: true

# Shared split-screen shell for every Devise view (sign in, sign up, edit
# account, forgot/reset password) — real brand photography filling one side,
# a clean unboxed form on the other. The photo panel hides on mobile (per
# the current split-screen convention: the form loads first, brand panel is
# a desktop enhancement, not something worth pushing the form below the
# fold for).
class Ui::AuthCardComponent < ViewComponent::Base
  renders_one :body

  def initialize(eyebrow:, title:)
    @eyebrow = eyebrow
    @title = title
  end

  attr_reader :eyebrow, :title
end
