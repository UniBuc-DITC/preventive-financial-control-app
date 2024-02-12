# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# TODO: should replace this with an user e-mail passed through an environment variable
admin_entra_user_id = '14ad39ca-6e68-412c-9b68-f9b71f4478d4'

admin = User.find_or_initialize_by(entra_user_id: admin_entra_user_id)

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

current_year_setting = Setting.find_or_initialize_by(key: :current_year)
current_year_setting.value = Time.zone.today.year
current_year_setting.save!

[
  'Buget', 'Finanțare complementară', 'Cercetare',
  'Spații de învățământ', 'Cămine', 'Erasmus',
  'CIVIS', 'FDI', 'Venituri',
].each do |financing_source_name|
  FinancingSource.find_or_create_by!(name: financing_source_name)
end

[
  'Proiect intern UB', 'Național', 'Proiect cu TVA',
  'Internațional', 'PNRR', 'SEE',
].each do |project_category_name|
  ProjectCategory.find_or_create_by!(name: project_category_name)
end

{
  '10.01.01': 'Salarii de bază',
  '10.01.02': 'Salarii de merit',
  '10.01.03': 'Indemnizație de conducere',
  '10.01.04': 'Spor de vechime',
}.each do |code, name|
  expenditure_article = ExpenditureArticle.find_or_initialize_by(code:)
  expenditure_article.name = name
  expenditure_article.save!
end

['Avans numerar', 'Avans virament', 'Numerar', 'Virament'].each do |payment_method_name|
  PaymentMethod.find_or_create_by!(name: payment_method_name)
end
