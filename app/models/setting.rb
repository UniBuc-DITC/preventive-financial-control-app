# frozen_string_literal: true

class Setting < ApplicationRecord
  validates :key, :value, presence: true

  validates :key, inclusion: { in: %w(current_year) }

  def self.current_year
    find_by!(key: :current_year).value
  end
end
