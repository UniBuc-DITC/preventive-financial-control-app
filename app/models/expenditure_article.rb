# frozen_string_literal: true

class ExpenditureArticle < ApplicationRecord
  validates :code, presence: true
end
