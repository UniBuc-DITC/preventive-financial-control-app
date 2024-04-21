# frozen_string_literal: true

class RegistryRecord < ApplicationRecord
  self.abstract_class = true

  validates :year, :registration_number, :registration_date, presence: true

  def full_identifier
    "#{registration_number}/#{year}"
  end

  def cancelled?
    !!cancelled
  end
end
