# frozen_string_literal: true

FactoryBot.define do
  factory :setting do
    trait :current_year do
      key { :current_year }
      value { Time.zone.today.year }
    end
  end
end
