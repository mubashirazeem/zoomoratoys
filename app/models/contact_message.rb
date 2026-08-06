# frozen_string_literal: true

class ContactMessage < ApplicationRecord
  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP

  validates :name, presence: true, length: { maximum: 100 }
  validates :email, presence: true, format: { with: EMAIL_FORMAT }, length: { maximum: 255 }
  validates :subject, presence: true, length: { maximum: 200 }
  validates :message, presence: true, length: { maximum: 5000 }
end
