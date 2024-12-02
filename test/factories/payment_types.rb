# frozen_string_literal: true

FactoryBot.define do
  factory :payment_type do
    name { ['Achiziție directă', 'Contract cadru'].sample }
  end
end
