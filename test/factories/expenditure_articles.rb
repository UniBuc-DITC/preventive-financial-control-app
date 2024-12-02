# frozen_string_literal: true

FactoryBot.define do
  factory :expenditure_article do
    code { %w[1 2 3 4 5 6 7 8 9 10].sample }
    name { ['Cheltuială', 'Factură', 'Curent electric'].sample }
  end
end
