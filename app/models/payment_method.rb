# frozen_string_literal: true

class PaymentMethod < ApplicationRecord
  validates :name, presence: true
end
