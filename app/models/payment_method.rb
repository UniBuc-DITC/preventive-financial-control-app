# frozen_string_literal: true

class PaymentMethod < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  has_many :expenditures, dependent: :restrict_with_error
end
