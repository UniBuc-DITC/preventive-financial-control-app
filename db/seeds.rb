# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# TODO: should replace this with an user e-mail passed through an environment variable
admin_entra_user_id = '14ad39ca-6e68-412c-9b68-f9b71f4478d4'

admin = User.find_or_initialize_by(entra_user_id: admin_entra_user_id)

unless admin.persisted?
  identity_platform_credentials = Rails.application.credentials.microsoft_identity_platform

  context = MicrosoftKiotaAuthenticationOAuth::ClientCredentialContext.new(
    identity_platform_credentials[:tenant_id],
    identity_platform_credentials[:client_id],
    identity_platform_credentials[:client_secret],
  )

  authentication_provider = MicrosoftGraphCore::Authentication::OAuthAuthenticationProvider.new(
    context,
    nil,
    ['https://graph.microsoft.com/.default']
  )

  adapter = MicrosoftGraph::GraphRequestAdapter.new(authentication_provider)
  client = MicrosoftGraph::GraphServiceClient.new(adapter)

  result = client.users.by_user_id(admin_entra_user_id).get.resume

  admin.entra_user_id = result.id
  admin.email = result.mail
  admin.first_name = result.given_name
  admin.last_name = result.surname
  admin.role = :admin

  admin.save!
end

current_year_setting = Setting.find_or_initialize_by(key: :current_year)
unless current_year_setting.persisted?
  current_year_setting.value = Time.zone.today.year
  current_year_setting.save!
end

seed_files_directory = Rails.root / 'db' / 'seeds'

csv_reader_options = {
  headers: true,
  converters: -> (f) { f&.strip }
}

puts 'Seeding financing sources...'

CSV.foreach(seed_files_directory / 'financing_sources.csv', **csv_reader_options) do |row|
  name = row[0]
  puts "Creating financing source '#{name}'"
  FinancingSource.find_or_create_by!(name:)
end

puts 'Seeding project categories...'

CSV.foreach(seed_files_directory / 'project_categories.csv', **csv_reader_options) do |row|
  name = row[0]
  puts "Creating project category '#{name}'"
  ProjectCategory.find_or_create_by!(name:)
end

puts 'Seeding expenditure articles...'

CSV.foreach(seed_files_directory / 'expenditure_articles.csv', **csv_reader_options) do |row|
  code = row[0]
  name = row[1]
  expenditure_category_code = row[2]
  commitment_category_code = row[3]
  puts "Creating expenditure article with code '#{code}', name '#{name}'"
  expenditure_article = ExpenditureArticle.find_or_initialize_by(code:)
  expenditure_article.name = name
  expenditure_article.expenditure_category_code = expenditure_category_code
  expenditure_article.commitment_category_code = commitment_category_code
  expenditure_article.save!
end

puts 'Seeding payment methods...'

['Avans numerar', 'Avans virament', 'Numerar', 'Virament'].each do |name|
  puts "Creating project category '#{name}'"
  PaymentMethod.find_or_create_by!(name:)
end
