# frozen_string_literal: true

class ContactMessage < ApplicationRecord
  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP

  validates :name, presence: true
  validates :email, presence: true, format: { with: EMAIL_FORMAT }
  validates :subject, presence: true
  validates :message, presence: true
end
