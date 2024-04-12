# frozen_string_literal: true

FactoryBot.define do
  factory :expenditure do
    year { 2024 }
    sequence(:registration_number)

    registration_date { Time.zone.today }

    financing_source { FinancingSource.first }
    project_category { nil }
    expenditure_article { ExpenditureArticle.first }

    details { 'detalii' }

    procurement_type { 'achiziție directă' }

    sequence(:ordinance_number)
    ordinance_date { Time.zone.today }

    value { 1250.15 }

    payment_type { PaymentType.first }

    sequence(:beneficiary) { "Beneficiar #{_1}" }

    created_by_user { User.first }
    updated_by_user { User.first }
  end
end
