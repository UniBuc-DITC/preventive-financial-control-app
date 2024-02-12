# frozen_string_literal: true

class ProjectCategory < ApplicationRecord
  validates :name, presence: true
end
