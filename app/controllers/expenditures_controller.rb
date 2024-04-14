# frozen_string_literal: true

class ExpendituresController < ApplicationController
  include Filtrable

  def index
    @expenditures = Expenditure.order('year desc, registration_number desc')

    include_dependent_entities

    if cookies[:show_filter_form].present?
      @show_filter_form = ActiveRecord::Type::Boolean.new.cast(cookies[:show_filter_form])
    end

    apply_filters

    @paginated_expenditures = @expenditures.paginate(page: params[:page], per_page: 5)
  end

  def new
    @expenditure = Expenditure.new
    @expenditure.year = Setting.current_year
    @expenditure.registration_date = Time.zone.today
    @expenditure.created_by_user = current_user
  end

  def edit
    @expenditure = Expenditure.find(params[:id])
    @expenditure.updated_by_user = current_user
  end

  def create
    @expenditure = Expenditure.new expenditure_params
    @expenditure.year = Setting.current_year
    @expenditure.created_by_user = current_user
    @expenditure.updated_by_user = current_user

    successfully_saved = false
    Expenditure.transaction do
      last_registration_number = Expenditure.where(year: @expenditure.year).maximum(:registration_number)
      last_registration_number ||= 0
      @expenditure.registration_number = last_registration_number + 1

      successfully_saved = @expenditure.save

      if successfully_saved
        AuditEvent.create!(
          timestamp: DateTime.now,
          user: current_user,
          action: :insert,
          target_table: :expenditures,
          target_object_id: "#{@expenditure.registration_number}/#{@expenditure.year}",
        )
      end
    end

    if successfully_saved
      flash[:notice] = t('expenditures.create.success_message',
                         registration_number: @expenditure.registration_number,
                         year: @expenditure.year)
      redirect_to expenditures_path
    else
      flash[:alert] = t 'expenditures.create.error_message'
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @expenditure = Expenditure.find(params[:id])
    @expenditure.update expenditure_params
    @expenditure.updated_by_user = current_user

    Expenditure.transaction do
      if @expenditure.save
        AuditEvent.create!(
          timestamp: DateTime.now,
          user: current_user,
          action: :update,
          target_table: :expenditures,
          target_object_id: "#{@expenditure.registration_number}/#{@expenditure.year}",
        )

        flash[:notice] = t('expenditures.update.success_message',
                           registration_number: @expenditure.registration_number,
                           year: @expenditure.year)
        redirect_to expenditures_path
      else
        flash[:alert] = t 'expenditures.update.error_message'
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def import; end

  def import_upload
    uploaded_file = params.require(:file)
    spreadsheet = Roo::Spreadsheet.open(uploaded_file)
    sheet = spreadsheet.sheet(0)

    total_count = 0
    Expenditure.transaction do
      (2..sheet.last_row).each do |row_index|
        row = sheet.row row_index

        # We've reached the end of the filled-in table
        break if row[1].blank? && row[2].blank?

        expenditure = parse_expenditure row_index, row

        if expenditure.save
          total_count += 1
        else
          raise ImportError.new(
            row_index,
            "nu s-a putut salva înregistrarea: #{expenditure.errors.full_messages.join(', ')}."
          )
        end
      end
    end

    flash[:notice] = "S-au importat cu succes #{total_count} de înregistrări!"
    redirect_to expenditures_path

  rescue ImportError => e
    flash.now[:alert] = e.to_s
    render :import
  end

  def export_download
    @expenditures = Expenditure.order('year, registration_number')

    include_dependent_entities
    apply_filters

    date = Time.current.strftime('%Y-%m-%d')
    render xlsx: 'export', disposition: 'attachment', filename: "Export cheltuieli #{date}.xlsx"
  end

  private

  def expenditure_params
    params.require(:expenditure).permit(
      :registration_date,
      :financing_source_id,
      :project_category_id,
      :project_details,
      :expenditure_article_id,
      :details,
      :procurement_type,
      :ordinance_number,
      :ordinance_date,
      :value,
      :payment_type_id,
      :beneficiary,
      :invoice,
      :noncompliance,
      :remarks
    )
  end

  def include_dependent_entities
    relation_names = %i[
      financing_source project_category expenditure_article payment_type
      created_by_user updated_by_user
    ]
    @expenditures = @expenditures.references(relation_names).includes(relation_names)
  end

  def apply_filters
    @any_filters_applied = false

    @expenditures = apply_field_value_filter @expenditures, :registration_number
    @expenditures = apply_field_value_filter @expenditures, :year

    if params[:start_date].present?
      start_date = Date.strptime(params[:start_date], '%d.%m.%Y')
      @expenditures = @expenditures.where('registration_date >= ?', start_date)
      @any_filters_applied = true
    end

    if params[:end_date].present?
      end_date = Date.strptime(params[:end_date], '%d.%m.%Y')
      @expenditures = @expenditures.where('registration_date <= ?', end_date)
      @any_filters_applied = true
    end

    if params[:expenditure_category_code].present?
      @expenditures = @expenditures.where(
        expenditure_article: {
          expenditure_category_code: params[:expenditure_category_code]
        }
      )
      @any_filters_applied = true
    end

    @expenditures = apply_ids_filter @expenditures,
                                     :financing_source_ids,
                                     :financing_source_id

    @expenditures = apply_ids_filter @expenditures,
                                     :project_category_ids,
                                     :project_category_id

    @expenditures = apply_ids_filter @expenditures,
                                     :expenditure_article_ids,
                                     :expenditure_article_id

    @expenditures = apply_exclude_cash_receipts_filter @expenditures

    @expenditures = apply_string_field_filter @expenditures, :project_details
    @expenditures = apply_string_field_filter @expenditures, :details
    @expenditures = apply_string_field_filter @expenditures, :procurement_type
    @expenditures = apply_string_field_filter @expenditures, :ordinance_number

    if params[:ordinance_date].present?
      ordinance_date = Date.strptime(params[:ordinance_date], '%d.%m.%Y')
      @expenditures = @expenditures.where(ordinance_date:)
      @any_filters_applied = true
    end

    @expenditures = apply_value_range_filter @expenditures

    @expenditures = apply_ids_filter @expenditures,
                                     :payment_type_ids,
                                     :payment_type_id,
                                     :payment_type_ids

    @expenditures = apply_string_field_filter @expenditures, :beneficiary
    @expenditures = apply_string_field_filter @expenditures, :invoice
    @expenditures = apply_string_field_filter @expenditures, :noncompliance
    @expenditures = apply_string_field_filter @expenditures, :remarks

    @expenditures = apply_created_by_user_ids_filter @expenditures
    @expenditures = apply_updated_by_user_ids_filter @expenditures

  end

  def parse_expenditure(row_index, row)
    expenditure = Expenditure.new imported: true

    expenditure.registration_number = row[0]

    registration_date = Date.strptime(row[1], '%d.%m.%Y')
    expenditure.registration_date = registration_date
    expenditure.year = registration_date.year

    financing_source = nil
    project_category = nil
    project_details = nil

    financing_source_name = row[2].strip
    case financing_source_name
    when 'financiar'
      financing_source = FinancingSource.find_by(name: 'Direcția Financiar-Contabilă')
    when 'venituri', 'venituri ub', 'venituri BCR', 'venituri trez', 'rectorat',
      # "Budget" isn't a separate financing source; it's basically revenues coming from the state
      'buget'
      financing_source = FinancingSource.find_by(name: 'Venituri')
    when 'finantare complementara',
      # Typo
      'finantare complementare'
      financing_source = FinancingSource.find_by(name: 'Finanțare complementară')
    when 'sponsorizare'
      financing_source = FinancingSource.find_by(name: 'Sponsorizare')
    when 'drept universal'
      financing_source = FinancingSource.find_by(name: 'Venituri')
      project_category = ProjectCategory.find_by!(name: 'Drept Universal')
    when 'cercetare', 'cercetre', 'finantarea cercetarii',
      'fcs', 'FCS', 'fss', 'FSS', 'pfe', 'fse', 'pr men', 'timss'
      financing_source = FinancingSource.find_by(name: 'Cercetare')
    when 'pnrr', 'PNRR',
      # Typo
      'pnnr'
      financing_source = FinancingSource.find_by(name: 'PNRR')
    when 'pocu'
      financing_source = FinancingSource.find_by(name: 'POCU')
    when 'fdi', 'FDI'
      financing_source = FinancingSource.find_by(name: 'FDI')
    when 'proiecte in valuta'
      # This is usually a mistake; the project category has been written in the column for financing source name.
      financing_source = FinancingSource.find_by(name: 'Cercetare')
      row[4] = 'pr. cu finantare in valuta'
    when 'camine', 'camin'
      financing_source = FinancingSource.find_by(name: 'Cămine')
    when 'cam a1 grozavesti', 'cam st militaru', 'cam b groavesti'
      financing_source = FinancingSource.find_by(name: 'Cămine')
      project_details = financing_source_name
    when 'cantina', 'cantina ub',
      # Typo
      'cantina  ub'
      financing_source = FinancingSource.find_by(name: 'Cantine')
    when 'casierie'
      financing_source = FinancingSource.find_by(name: 'Casierie')
    when 'editura ub', 'editura UB', 'editura universitatii'
      financing_source = FinancingSource.find_by(name: 'Editura UB')
    when 'teren sport'
      financing_source = FinancingSource.find_by(name: 'Teren de sport')
    when 'casa universitarilor'
      financing_source = FinancingSource.find_by(name: 'Casa Universitarilor')
    when 'purowax', 'PUROWAX'
      financing_source = FinancingSource.find_by(name: 'PUROWAX')
    when 'see', 'SEE'
      financing_source = FinancingSource.find_by(name: 'SEE')
    when 'erasmus', 'valuta studii'
      financing_source = FinancingSource.find_by(name: 'Erasmus')
    when 'civis'
      financing_source = FinancingSource.find_by(name: 'CIVIS')
    when 'gr botanica', 'gradina botanica'
      financing_source = FinancingSource.find_by(name: 'Grădina Botanică')
    when 'st sf gheorghe'
      financing_source = FinancingSource.find_by(name: 'Stațiunea de cercetări de la Sfântu Gheorghe')
    when 'st orsova'
      financing_source = FinancingSource.find_by(name: 'Stațiunea de cercetare de la Orșova')
    when 'st braila', 'braila', 'statiunea braila', 'statiune braila',
      # Typo
      'statiunea braile'
      financing_source = FinancingSource.find_by(name: 'Stațiunea de Cercetări Ecologice Brăila')
    when 'statiunea sinaia', 'st sinaia'
      financing_source = FinancingSource.find_by(name: 'Stațiunea Zoologică Sinaia')
    when 'statiunea hateg'
      financing_source = FinancingSource.find_by(name: 'Geoparcul Țara Hațegului')
    when 'academica'
      financing_source = FinancingSource.find_by(name: 'Casa de Oaspeți „Academica”')
    when 'gaudeamus', 'camin gaudeamus'
      financing_source = FinancingSource.find_by(name: 'Hotel Gaudeamus')
    when 'confucius'
      financing_source = FinancingSource.find_by(name: 'Institutul Confucius')
    when 'cls'
      financing_source = FinancingSource.find_by(name: 'Centrul de Limbi Străine')
    when 'csud'
      financing_source = FinancingSource.find_by(name: 'Consiliul Studiilor Universitare de Doctorat')
    when 'icub', 'ICUB'
      financing_source = FinancingSource.find_by(name: 'ICUB')
    when 'spatii invatamant', 'sp. invatamant'
      financing_source = FinancingSource.find_by(name: 'Serviciul Spații de Învățământ')

      #### Faculties
    when 'adm si afaceri', 'fac ad si afaceri', 'administratie', 'admin si afaceri'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Administrație și Afaceri')
    when 'biologie', 'fac biologie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Biologie')
    when 'fac chimie', 'chimie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Chimie')
    when 'drept', 'fac drept'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Drept')
    when 'filosofie', 'fac filosofie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Filosofie')
    when 'fizica'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Fizică')
    when 'istorie', 'fac istorie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Istorie')
    when 'teologie ortodoxa', 'teol ortodoxa', 'TEOLOGIE ORTODOXA', 'fac teol ort', 'teol ort',
      # Typo
      'tel ortodoxa'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Teologie Ortodoxă')
    when 'teologie baptista', 'teol baptista'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Teologie Baptistă')
    when 'teologie rom catolica', 'teol romano catolica', 'teologie romano catolica'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Teologie Romano-Catolică')
    when 'geografie', 'fac geografie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Geografie')
    when 'geologie', 'fac geologie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Geologie și Geofizică')
    when 'litere', 'fac litere'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Litere')
    when 'lls', 'fac lls'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Limbi și Literaturi Străine')
    when 'lma'
      financing_source = FinancingSource.find_by(name: 'Limbi Moderne Aplicate')
    when 'matematica', 'fac matematica', 'fac mate'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Matematică și Informatică')
    when 'jurnalism', 'fac jurnalism'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Jurnalism și Științele Comunicării')
    when 'psihologie', 'fac psihologie', 'fa psihologie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Psihologie și Științele Educației')
    when 'stiinte politice', 'st politice', 'fac st politice',
      # Typo
      'sttinte politice'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Științe Politice')
    when 'sociologie', 'fac sociologie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Sociologie și Asistență Socială')
    when 'departamentul de sport', 'departamentul de educatie fizica', 'catedra sport'
      financing_source = FinancingSource.find_by(name: 'Departamentul de Educație Fizică și Sport')
    else
      raise ImportError.new(row_index, "sursă de finanțare nerecuonscută: '#{financing_source_name}'")
    end

    if financing_source.nil?
      raise ImportError.new(row_index, "nu a putut fi găsită o sursă de finanțare cunoscută asociată cu denumirea '#{financing_source_name}'")
    end

    expenditure_article_code = row[3].to_s.strip

    # To avoid issues with '59.01' being interpreted as a decimal number,
    # they sometimes write '59.01.'
    expenditure_article_code = '59.01' if expenditure_article_code == '59.01.'

    # Sometimes, article codes get saved as decimals and the trailing zero gets removed.
    expenditure_article_code = '59.40' if expenditure_article_code == '59.4'

    expenditure_article = ExpenditureArticle.find_by(code: expenditure_article_code)
    if expenditure_article.nil?
      raise ImportError.new(row_index, "nu a putut fi găsit un articol de cheltuială cu codul '#{expenditure_article_code}'")
    end

    expenditure.expenditure_article = expenditure_article

    project_name = row[4].strip

    case project_name
    when 'buget', 'BUGET', 'venituri ub',
      'venit bcr', 'venituri BCR', 'venituri',
      'trezorerie', 'venit trezorerie', 'ven trez', 'venituri trezorerie'
      # These are all mistakes from upstream, but we accept them as-is.
      if financing_source.name.in? ['Cercetare', 'Cămine', 'Facultatea de Chimie', 'Grădina Botanică']
        # Do nothing
      elsif financing_source.name != 'Venituri'
        raise ImportError.new(row_index, "categorie de proiect necunoscută: '#{project_name}'")
      end

      # For different kinds of revenues, store their type in the "project details" field
      project_details = project_name
      project_category = nil
    when 'venit trezorerie/erasmus'
      financing_source = FinancingSource.find_by!(name: 'Erasmus')
    when 'finantare complementara'
      project_category = ProjectCategory.find_by!(name: 'Finanțare complementară')
    when 'proiecte ub', 'pr ub', 'proiect UB'
      project_category = ProjectCategory.find_by!(name: 'Proiect intern UB')
    when /^pr ub/
      project_details = project_name.delete_prefix('pr ub')
                                    .delete_prefix('/')
                                    .strip
      project_category = ProjectCategory.find_by!(name: 'Proiect intern UB')
    when 'pr nationale', 'pr. national', 'pr national'
      project_category = ProjectCategory.find_by!(name: 'Național')
    when 'pr internationale', 'pr. international'
      project_category = ProjectCategory.find_by!(name: 'Internațional')
    when 'pr cu tva', 'pr tva', 'proiecte cu tva'
      project_category = ProjectCategory.find_by!(name: 'Proiect cu TVA')
    when 'pr. cu finantare in valuta',
      'pr valuta', 'proiecte in valuta'
      project_category = ProjectCategory.find_by!(name: 'Proiect cu finanțare în valută')
    when 'premiile senatului'
      project_category = ProjectCategory.find_by!(name: 'Premiile Senatului')
    when /^pfe/
      project_details = project_name.delete_prefix('pfe')
                                    .delete_prefix('/')
                                    .strip
      project_category = ProjectCategory.find_by!(name: 'PFE')
    when /^fss/, /^FSS/
      project_details = project_name.delete_prefix('fss').delete_prefix('FSS')
                                    .delete_prefix('/')
                                    .strip
      project_category = ProjectCategory.find_by!(name: 'FSS')
    when /^pr fss/
      project_details = project_name.delete_prefix('pr fss')
                                    .strip
                                    .delete_prefix('/')
                                    .strip
      project_category = ProjectCategory.find_by!(name: 'FSS')
    when /^proiecte fss/
      project_details = project_name.delete_prefix('proiecte fss')
                                    .strip
                                    .delete_prefix('/')
                                    .strip
      project_category = ProjectCategory.find_by!(name: 'FSS')
    when /^fse/, /^FSE/
      project_details = project_name.delete_prefix('fse').delete_prefix('FSE')
                                    .delete_prefix('/')
                                    .strip
      project_category = ProjectCategory.find_by!(name: 'FSE')
    when /^fdi/, /^FDI/
      project_details = project_name.delete_prefix('fdi').delete_prefix('FDI')
                                    .delete_prefix('/')
                                    .strip
      project_category = ProjectCategory.find_by!(name: 'FDI')
    when /^pnrr/, /^PNRR/,
      # Typos
      /^pnnr/, /^PNNR/
      project_details = project_name.delete_prefix('pnrr').delete_prefix('PNRR')
                                    .delete_prefix('pnnr').delete_prefix('PNNR')
                                    .delete_prefix('/')
                                    .strip
      project_category = ProjectCategory.find_by!(name: 'PNRR')
    when /^i\d/
      project_details = project_name.strip
      project_category = ProjectCategory.find_by!(name: 'PNRR')
    when 'EDIS'
      project_category = ProjectCategory.find_by!(name: 'EDIS')
    when 'CDI'
      project_category = ProjectCategory.find_by!(name: 'CDI')
    when /^cdi/
      project_details = project_name.delete_prefix('cdi').delete_prefix('/').strip
      project_category = ProjectCategory.find_by!(name: 'CDI')
    when /^CPI/
      project_details = project_name.delete_prefix('CPI').delete_prefix('/').strip
      project_category = ProjectCategory.find_by!(name: 'CPI')
    when /^grant cpi/
      project_details = project_name.delete_prefix('grant cpi').strip
      project_category = ProjectCategory.find_by!(name: 'CPI')
    when /^pocu/
      project_details = project_name.delete_prefix('pocu').delete_prefix('/').strip
      project_category = ProjectCategory.find_by!(name: 'POCU')
    when /^fcs/
      project_details = project_name.delete_prefix('fcs').delete_prefix('/').strip
      project_category = ProjectCategory.find_by!(name: 'Finanțarea cercetării științifice')
    when /^see/, /^SEE/
      project_details = project_name.delete_prefix('see').delete_prefix('/')
                                    .delete_prefix('SEE').delete_prefix('/')
                                    .strip
      project_category = ProjectCategory.find_by!(name: 'SEE')
    when /^ctr ka/
      project_details = project_name.strip
      project_category = ProjectCategory.find_by!(name: 'Erasmus')
    when /^ctr /
      if financing_source.name != 'Cercetare'
        raise ImportError.new(row_index, "categorie de proiect necunoscută: '#{project_name}'")
      end

      project_details = project_name.strip
    when /^purowax/, /^pr purowax/
      project_details = project_name.delete_prefix('pr')
                                    .delete_prefix('purowax').delete_prefix('/').strip
      project_category = ProjectCategory.find_by!(name: 'PUROWAX')
    when 'PUROWAX'
      project_category = ProjectCategory.find_by!(name: 'PUROWAX')
    when /^pr growing/, /^pr employer/, /^pr ev potential/, /^pr siec/, 'fond cercetare chifiriuc'
      project_details = project_name.delete_suffix('- fin cercetarii stiintifice').strip
      project_category = ProjectCategory.find_by!(name: 'Finanțarea cercetării științifice')
    when /^timss/
      project_details = project_name.strip
      project_category = ProjectCategory.find_by!(name: 'Proiecte Ministerul Educației Naționale')
    when /^pt timss/
      project_details = project_name.delete_prefix('pt').strip
      project_category = ProjectCategory.find_by!(name: 'Proiecte Ministerul Educației Naționale')
    when 'editura UB', 'editura ub'
      financing_source = FinancingSource.find_by!(name: 'Editura UB')
      project_category = nil
    when 'academica'
      financing_source = FinancingSource.find_by!(name: 'Casa de Oaspeți „Academica”')
      project_category = nil
    when 'casa universitarilor'
      financing_source = FinancingSource.find_by!(name: 'Casa Universitarilor')
      project_category = nil
    when 'finantarea cercetarii', 'fin cercetarii', 'finantarea cercetarii stiintifice',
      'fin cercetarii stiintifice', 'finanatarea cercetarii stiintifice',
      'fond cercetare', 'fond cercetare stiintifica'
      project_category = ProjectCategory.find_by!(name: 'Finanțarea cercetării științifice')
    when 'icub', 'ICUB'
      financing_source = FinancingSource.find_by!(name: 'ICUB')
      project_category = nil
    when 'camine'
      financing_source = FinancingSource.find_by(name: 'Cămine')
      project_category = nil
    when 'drept universal', 'dr universal'
      project_category = ProjectCategory.find_by!(name: 'Drept Universal')
    when 'civis cofinantare', 'cofinantare civis', 'co-finantare civis', 'venituri/cofinantare CIVIS'
      project_category = ProjectCategory.find_by!(name: 'Cofinanțare CIVIS')
    when 'civis', /^pr civis 2/
      project_details = project_name.delete_prefix('pr civis 2')
                                    .strip
      project_category = ProjectCategory.find_by!(name: 'CIVIS 2')
    when /^erasmus/
      project_details = project_name.delete_prefix('erasmus').delete_prefix('/').delete_prefix('+')
                                    .strip
    when /^pr erasmus/, /^pr didafe/, /^pr \d+/
      project_details = project_name
    when 'ven erasmus'
      project_category = ProjectCategory.find_by!(name: 'Erasmus')
    when /^proiect caipe/
      project_category = ProjectCategory.find_by!(name: 'CAIPE')
    when /^proiect cdi/
      project_details = project_name.delete_prefix('proiect cdi').strip
      project_category = ProjectCategory.find_by!(name: 'CDI')
    when /^proiect addendum/
      project_details = project_name.delete_prefix('proiect addendum').delete_prefix('/')
                                    .strip
      project_category = ProjectCategory.find_by!(name: 'CDI')
    when /^proiect \d/, /^pr ka/, /^pr renewteach/
      if financing_source.name != 'Erasmus'
        raise ImportError.new(row_index, "categorie de proiect necunoscută: '#{project_name}'")
      end

      project_details = project_name
      project_category = nil
    when 'llp/erasmus', 'finantare valuta'
      project_category = ProjectCategory.find_by!(name: 'LLP/Erasmus')
    when 'progr comunitare erasmus'
      # TODO: is this correct? Should this simply be Erasmus?
      project_category = ProjectCategory.find_by!(name: 'Programe comunitare Erasmus')
    when 'fondul rectorului', 'protocol rector'
      project_category = ProjectCategory.find_by!(name: 'Fondul Rectorului')
    when 'grant doctoral'
      project_category = ProjectCategory.find_by!(name: 'Grant doctoral')
    when 'catedra sport'
      financing_source = FinancingSource.find_by!(name: 'Departamentul de Educație Fizică și Sport')
      project_category = nil
    when 'csud'
      financing_source = FinancingSource.find_by!(name: 'Consiliul Studiilor Universitare de Doctorat')
      project_category = nil
    when 'st braila'
      project_category = nil
      financing_source = FinancingSource.find_by!(name: 'Stațiunea de Cercetări Ecologice Brăila')
    when 'st orsova'
      project_category = nil
      financing_source = FinancingSource.find_by!(name: 'Stațiunea de cercetare de la Orșova')
    when 'st sinaia'
      project_category = nil
      financing_source = FinancingSource.find_by!(name: 'Stațiunea Zoologică Sinaia')

      # This is for the situation where the "project" entry has been used inappropriately
    when /^global campus/, /^proiect masks/, /^pr eBelong2/, 'imobil d brandza', 'inst botanic',
      /^grozavesti/, 'poligrafie', /^pallady/, 'cam fundeni', 'cam magurele', 'cam grozavesti a1',
      /^st militaru/
      project_details = project_name
      project_category = nil
    when 'altele', 'burse'
      project_category = nil
    else
      raise ImportError.new(row_index, "categorie de proiect necunoscută: '#{project_name}'")
    end

    expenditure.financing_source = financing_source
    expenditure.project_category = project_category
    expenditure.project_details = project_details || ''

    expenditure.details = row[5]
    expenditure.procurement_type = row[6] || ''
    expenditure.ordinance_number = row[7]
    ordinance_date = row[8]
    ordinance_date = Date.strptime(ordinance_date, '%d.%m.%Y') if ordinance_date.present?
    expenditure.ordinance_date = ordinance_date

    expenditure.value = row[9]

    payment_type_name = row[10].strip

    payment_type = nil
    case payment_type_name
    when 'numerar'
      payment_type = PaymentType.find_by(name: 'Numerar')
    when 'virament'
      payment_type = PaymentType.find_by(name: 'Virament')
    when 'avans numerar'
      payment_type = PaymentType.find_by(name: 'Avans numerar')
    when 'avans virament'
      payment_type = PaymentType.find_by(name: 'Avans virament')
    end

    if payment_type.nil?
      raise ImportError.new(row_index, "nu a putut fi găsită tipul de plată denumit '#{payment_type_name}'")
    end

    expenditure.payment_type = payment_type

    expenditure.beneficiary = row[11] || ''

    expenditure.invoice = row[12] || ''

    expenditure.noncompliance = row[13] || ''
    expenditure.remarks = row[14] || ''

    expenditure.created_by_user = current_user
    expenditure.updated_by_user = current_user

    expenditure
  end
end
