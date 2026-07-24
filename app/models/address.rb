# frozen_string_literal: true

class Address < ApplicationRecord
  belongs_to :user

  validates :full_name, :phone, :address_line1, :city, presence: true
  validates :emirate, presence: true, inclusion: { in: Order::EMIRATES }

  scope :ordered, -> { order(default_address: :desc, created_at: :desc) }

  before_save :unset_other_defaults, if: :default_address?

  def summary
    [ address_line1, address_line2, city, emirate ].reject(&:blank?).join(", ")
  end

  private

  def unset_other_defaults
    user.addresses.where.not(id: id).update_all(default_address: false)
  end
end
