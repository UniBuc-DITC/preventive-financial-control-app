# frozen_string_literal: true

class CommitmentsController < ApplicationController
  include Filtrable

  before_action -> { require_permission 'Commitment.View' }, only: %i[index export_download]
  before_action -> { require_permission 'Commitment.Create' }, only: %i[new duplicate create]
  before_action -> { require_permission 'Commitment.Edit' }, only: %i[edit update]
  before_action -> { require_permission 'Commitment.Import' }, only: %i[import import_upload]

  def index
    @layout_without_container = true

    @commitments = Commitment.order('year desc, registration_number desc')

    include_dependent_entities

    if cookies[:show_filter_form].present?
      @show_filter_form = ActiveRecord::Type::Boolean.new.cast(cookies[:show_filter_form])
    end

    apply_filters

    @paginated_commitments = @commitments.paginate(
      page: params[:page],
      per_page: 10
    )
  end

  def new
    @commitment = Commitment.new
    @commitment.year = Setting.current_year
    @commitment.registration_date = Time.zone.today
    @commitment.created_by_user = current_user

    return unless params[:source_expenditure_id].present?

    @source_expenditure = Expenditure.find(params[:source_expenditure_id])

    @commitment.financing_sources << @source_expenditure.financing_source
    @commitment.expenditure_article = @source_expenditure.expenditure_article
    @commitment.procurement_type = @source_expenditure.procurement_type
    @commitment.project_details = @source_expenditure.details
    @commitment.partner = @source_expenditure.beneficiary
    @commitment.value = @source_expenditure.value
    @commitment.remarks = @source_expenditure.remarks
  end

  def edit
    @commitment = Commitment.find(params[:id])
    @commitment.updated_by_user = current_user
  end

  def duplicate
    existing_commitment = Commitment.find(params[:id])
    @commitment = existing_commitment.dup
    existing_commitment.financing_sources.each do |financing_source|
      @commitment.financing_sources << financing_source
    end
    @commitment.registration_number = nil
    @commitment.created_by_user = current_user
    @commitment.updated_by_user = current_user
  end

  def create
    @commitment = Commitment.new commitment_params
    @commitment.year = Setting.current_year
    @commitment.created_by_user = current_user
    @commitment.updated_by_user = current_user

    successfully_saved = false
    Commitment.transaction do
      last_registration_number = Commitment.where(year: @commitment.year).maximum(:registration_number)
      last_registration_number ||= 0
      @commitment.registration_number = last_registration_number + 1

      successfully_saved = @commitment.save

      if successfully_saved
        AuditEvent.create!(
          timestamp: DateTime.now,
          user: current_user,
          action: :insert,
          target_table: :commitments,
          target_object_id: "#{@commitment.registration_number}/#{@commitment.year}"
        )
      end
    end

    if successfully_saved
      flash[:notice] =
        "A fost salvat cu succes angajamentul cu numărul de înregistrare #{@commitment.registration_number}/#{@commitment.year}"
      redirect_to commitments_path
    else
      flash[:alert] = 'Nu s-a putut salva noul angajament. Verificați erorile și încercați din nou.'
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @commitment = Commitment.find(params[:id])
    @commitment.update commitment_params
    @commitment.updated_by_user = current_user

    Commitment.transaction do
      if @commitment.save
        AuditEvent.create!(
          timestamp: DateTime.now,
          user: current_user,
          action: :update,
          target_table: :commitments,
          target_object_id: "#{@commitment.registration_number}/#{@commitment.year}"
        )

        flash[:notice] =
          "A fost modificat cu succes angajamentul cu numărul de înregistrare #{@commitment.registration_number}/#{@commitment.year}"
        redirect_to commitments_path
      else
        flash[:alert] = 'Nu s-au putut salva modificările la angajament. Verificați erorile și încercați din nou.'
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def import; end

  def import_upload
    uploaded_file = params.require(:file)
    spreadsheet = Roo::Spreadsheet.open(uploaded_file)
    sheet = spreadsheet.sheet(0)

    @financing_sources = FinancingSource.with_import_code.to_a

    saved_count = 0
    error_count = 0
    @error_messages = []
    Commitment.transaction do
      (3..sheet.last_row).each do |row_index|
        row = sheet.row row_index

        # We've reached the end of the filled-in table
        break if row[1].blank? && row[2].blank?

        begin
          commitment = parse_commitment row_index, row

          commitment.created_by_user = current_user
          commitment.updated_by_user = current_user

          if commitment.save
            saved_count += 1
          else
            raise ImportError.new(
              row_index,
              "nu s-a putut salva înregistrarea: #{commitment.errors.full_messages.join(', ')}."
            )
          end
        rescue ImportError => e
          @error_messages << e.to_s
          error_count += 1
        end

        # Exit if we've already accumulated too many errors
        break if error_count > ImportError::MAX_ERRORS
      end

      # Roll back the transaction if some records couldn't be saved.
      raise ActiveRecord::Rollback if error_count.positive?
    end

    if error_count.positive?
      flash.now[:alert] = 'Nu s-au putut importa cu succes toate înregistrările din cauza unor erori.'
      render :import
    else
      flash[:notice] = "S-au importat cu succes #{saved_count} de înregistrări!"
      redirect_to commitments_path
    end
  end

  def export_download
    @commitments = Commitment.order('year, registration_number')

    include_dependent_entities
    apply_filters

    date = Time.current.strftime('%Y-%m-%d')
    render xlsx: 'export', template: 'commitments/export',
           disposition: 'attachment', filename: "Export angajamente #{date}.xlsx"
  end

  private

  def commitment_params
    params.expect(
      commitment: [
        :registration_date,
        :project_details,
        :expenditure_article_id,
        :document_number,
        :validity,
        :procurement_type,
        :partner,
        :value,
        :noncompliance,
        :remarks,
        { financing_sources_ids: [] }
      ]
    )
  end

  def include_dependent_entities
    relation_names = %i[expenditure_article created_by_user updated_by_user]
    @commitments = @commitments.references(relation_names).includes(relation_names)
    @commitments = @commitments.references(:financing_sources)
                               .includes(:financing_sources)
  end

  def apply_filters
    @any_filters_applied = false

    @commitments = apply_field_value_filter @commitments, :registration_number
    @commitments = apply_field_value_filter @commitments, :year

    if params[:start_date].present?
      start_date = Date.strptime(params[:start_date], '%d.%m.%Y')
      @commitments = @commitments.where(registration_date: start_date..)
      @any_filters_applied = true
    end

    if params[:end_date].present?
      end_date = Date.strptime(params[:end_date], '%d.%m.%Y')
      @commitments = @commitments.where(registration_date: ..end_date)
      @any_filters_applied = true
    end

    if params[:commitment_category_code].present?
      @commitments = @commitments.where(
        expenditure_article: {
          commitment_category_code: params[:commitment_category_code]
        }
      )
      @any_filters_applied = true
    end

    @commitments = apply_ids_filter @commitments,
                                    :financing_source_ids,
                                    :financing_sources

    @commitments = apply_ids_filter @commitments,
                                    :expenditure_article_ids,
                                    :expenditure_article_id

    @commitments = apply_exclude_cash_receipts_filter @commitments

    @commitments = apply_string_field_filter @commitments, :document_number
    @commitments = apply_string_field_filter @commitments, :validity
    @commitments = apply_string_field_filter @commitments, :project_details
    @commitments = apply_string_field_filter @commitments, :partner
    @commitments = apply_string_field_filter @commitments, :procurement_type
    @commitments = apply_string_field_filter @commitments, :noncompliance
    @commitments = apply_string_field_filter @commitments, :remarks

    @commitments = apply_value_range_filter @commitments

    @commitments = apply_created_by_user_ids_filter @commitments
    @commitments = apply_updated_by_user_ids_filter @commitments
  end

  # noinspection SpellCheckingInspection
  def parse_commitment(row_index, row)
    commitment = Commitment.new

    commitment.registration_number = row[0]

    registration_date = Date.strptime(row[1], '%d.%m.%Y')
    commitment.registration_date = registration_date
    commitment.year = registration_date.year

    if row[2] == 'NUMAR ANULAT'
      commitment.document_number = ''
      commitment.validity = ''
      commitment.partner = ''
      commitment.value = 0
      commitment.remarks = row[9] || ''
      commitment.noncompliance = row[10] || ''
      commitment.cancelled = true
      return commitment
    end

    commitment.document_number = row[2]
    commitment.validity = row[3].presence || ''

    financing_sources_column = row[4]&.strip&.downcase

    if financing_sources_column.blank?
      raise ImportError.new(row_index,
                            'lipsește reprezentantul UB / sursa de finanțare')
    end

    financing_sources = []
    project_details = ''
    case financing_sources_column
    when 'venituri', 'venituri ub', 'rectorat', 'ub', 'ven trez', 'ven trezorerie'
      financing_sources << FinancingSource.find_by(name: 'Venituri')
    when /^venit/
      project_details = financing_sources_column.delete_prefix('venit').strip
      financing_sources << FinancingSource.find_by(name: 'Venituri')
    when 'buget', 'trezorerie', 'drept universal'
      project_details = financing_sources_column.strip
      financing_sources << FinancingSource.find_by(name: 'Venituri')
    when 'microproductie'
      financing_sources << FinancingSource.find_by(name: 'Microproducție')
    when 'parc auto'
      financing_sources << FinancingSource.find_by(name: 'Parc auto')
    when 'finantare complementara',
      # Typo
      'finantare complemnetara'
      financing_sources << FinancingSource.find_by(name: 'Finanțare complementară')
    when 'cercetare',
      # Typo
      'cercetre',
      # Other ways of saying the same thing
      'finantarea cercetarii',
      'finantarea cercetarii stiintifice',
      'fin cercetarii',
      # Research projects
      'pr cu tva', 'pr nationale', 'pr internationale', 'proiecte internationale',
      'proiecte in valuta', 'pr in valuta',
      /^ctr\./,
      /^pfe /, %r{^pfe/}, /^fcs /, %r{^fcs/},
      %r{^fss/}, /^fss /, /^proiecte fss/,
      %r{^cpi/},
      /^lifewatch/, /^timss/,
      /^proiect caipe/, /^pr growing/, /^pr employer/, /^pr ev potential/, /^pr siec/,
      /^proiect addendum/,
      'fcs',
      'fss',
      'pfe',
      'fse',
      /^pr men/, /^ctr timss/,
      /^regie sectie/
      project_details = financing_sources_column.strip
      financing_sources << FinancingSource.find_by(name: 'Cercetare')
    when /^llp-uri/
      project_details = financing_sources_column.delete_prefix('llp-uri').delete_prefix('/').strip
      financing_sources << FinancingSource.find_by(name: 'Erasmus')
    when 'pnrr', 'PNRR',
      # Typo
      'pnnr'
      financing_sources << FinancingSource.find_by(name: 'PNRR')
    when /^pocu/
      project_details = financing_sources_column.delete_prefix('pocu').delete_prefix('/').strip
      financing_sources << FinancingSource.find_by(name: 'POCU')
    when 'fdi'
      financing_sources << FinancingSource.find_by(name: 'FDI')
    when 'camine-cantine', 'camine-cantina'
      financing_sources << FinancingSource.find_by(name: 'Direcția Cămine-Cantine și Activități Studențești')
    when 'camine', 'cam a1 grozavesti', 'cam st militaru', 'cam b groavesti'
      project_details = financing_sources_column.strip
      financing_sources << FinancingSource.find_by(name: 'Cămine')
    when /^camine /
      project_details = financing_sources_column.delete_prefix('camine').strip
      financing_sources << FinancingSource.find_by(name: 'Cămine')
    when /^ap \d+/
      project_details = financing_sources_column.strip
      financing_sources << FinancingSource.find_by(name: 'Direcția Patrimoniu Imobiliar')
    when 'cantina', 'cantina ub',
      # Typo
      'cantina  ub'
      financing_sources << FinancingSource.find_by(name: 'Cantine')
    when /^cantina/
      project_details = financing_sources_column.delete_prefix('cantina').delete_prefix('/')
                                                .strip
      financing_sources << FinancingSource.find_by(name: 'Cantine')
    when 'casierie'
      financing_sources << FinancingSource.find_by(name: 'Casierie')
    when 'editura ub', 'editura universitatii'
      financing_sources << FinancingSource.find_by!(name: 'Editura UB')
    when 'teren sport'
      financing_sources << FinancingSource.find_by(name: 'Teren de sport')
    when 'casa universitarilor'
      financing_sources << FinancingSource.find_by!(name: 'Casa Universitarilor')
    when 'purowax'
      financing_sources << FinancingSource.find_by(name: 'PUROWAX')
    when 'see', 'grant see'
      financing_sources << FinancingSource.find_by(name: 'SEE')
    when 'erasmus', 'ven erasmus', 'proiect de tip erasmus'
      financing_sources << FinancingSource.find_by(name: 'Erasmus')
    when /^trace/
      project_details = financing_sources_column.strip
      financing_sources << FinancingSource.find_by(name: 'Erasmus')
    when %r{^erasmus/}
      project_details = financing_sources_column.delete_prefix('erasmus').delete_prefix('/')
                                                .strip
      financing_sources << FinancingSource.find_by(name: 'Erasmus')
    when 'civis', 'civis 2'
      project_details = financing_sources_column.strip
      financing_sources << FinancingSource.find_by(name: 'CIVIS')
    when 'gr botanica', 'gradina botanica'
      financing_sources << FinancingSource.find_by(name: 'Grădina Botanică')
    when 'st sf gheorghe'
      financing_sources << FinancingSource.find_by(name: 'Stațiunea de cercetări de la Sfântu Gheorghe')
    when 'statiunea orsova', 'st orsova', 'st. orsova'
      financing_sources << FinancingSource.find_by(name: 'Stațiunea de cercetare de la Orșova')
    when 'statiunea braila', 'statiune braila', 'st braila', 'braila'
      financing_sources << FinancingSource.find_by(name: 'Stațiunea de Cercetări Ecologice Brăila')
    when 'statiunea sinaia'
      financing_sources << FinancingSource.find_by(name: 'Stațiunea Zoologică Sinaia')
    when 'academica'
      financing_sources << FinancingSource.find_by(name: 'Casa de Oaspeți „Academica”')
    when 'gaudeamus'
      financing_sources << FinancingSource.find_by(name: 'Hotel Gaudeamus')
    when 'confucius'
      financing_sources << FinancingSource.find_by(name: 'Institutul Confucius')
    when 'cls'
      financing_sources << FinancingSource.find_by(name: 'Centrul de Limbi Străine')
    when 'csud'
      financing_sources << FinancingSource.find_by(name: 'Consiliul Studiilor Universitare de Doctorat')
    when 'icub', 'ub icub'
      financing_sources << FinancingSource.find_by(name: 'ICUB')
    when /^icub/
      project_details = financing_sources_column.delete_prefix('icub').delete_prefix('-')
                                                .strip
      financing_sources << FinancingSource.find_by(name: 'ICUB')
      ## Faculties
    when 'adm si afaceri', 'fac ad si afaceri', 'administratie si afaceri', 'admin si afaceri',
      'administratie'
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Administrație și Afaceri')
    when 'biologie', 'fac biologie'
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Biologie')
    when 'fac chimie', 'chimie',
      # Typo
      'chmie'
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Chimie')
    when 'drept', 'fac drept'
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Drept')
    when /^drept /
      project_details = financing_sources_column.delete_prefix('drept').strip
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Drept')
    when 'filosofie', 'fac filosofie'
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Filosofie')
    when /filosofie /
      project_details = financing_sources_column.delete_prefix('filosofie').strip
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Filosofie')
    when /catedra unesco/
      project_details = financing_sources_column.strip
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Filosofie')
    when 'fizica', 'fac fizica'
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Fizică')
    when /^fizica /
      project_details = financing_sources_column.delete_prefix('fizica').strip
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Fizică')
    when 'istorie', 'fac istorie'
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Istorie')
    when 'teologie ortodoxa', 'teol ortodoxa'
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Teologie Ortodoxă')
    when 'teologie baptista', 'teol baptista'
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Teologie Baptistă')
    when 'teologie rom catolica', 'teol romano catolica', 'teologie romano catolica', 'teologie catolica'
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Teologie Romano-Catolică')
    when 'geografie', 'geografia', 'fac geografie'
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Geografie')
    when 'geologie', 'fac geologie'
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Geologie și Geofizică')
    when /^fac\. de geologie/
      project_details = financing_sources_column.delete_prefix('fac. de geologie').strip
                                                .delete_prefix('-').strip
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Geologie și Geofizică')
    when 'litere', 'fac litere'
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Litere')
    when 'lls', 'fac lls'
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Limbi și Literaturi Străine')
    when 'lma'
      financing_sources << FinancingSource.find_by(name: 'Limbi Moderne Aplicate')
    when 'matematica', 'fac matematica'
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Matematică și Informatică')
    when 'jurnalism', 'fac jurnalism'
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Jurnalism și Științele Comunicării')
    when 'psihologie', 'fac psihologie'
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Psihologie și Științele Educației')
    when /^psihologie/
      project_details = financing_sources_column.delete_prefix('psihologie').strip
                                                .delete_prefix('/').strip
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Psihologie și Științele Educației')
    when 'stiinte politice', 'st politice', 'fac st politice',
      # Typo
      'sttinte politice'
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Științe Politice')
    when 'sociologie', 'fac sociologie'
      financing_sources << FinancingSource.find_by(name: 'Facultatea de Sociologie și Asistență Socială')
    when 'tehnic'
      financing_sources << FinancingSource.find_by(name: 'Direcția Tehnică')
    when 'financiar'
      financing_sources << FinancingSource.find_by(name: 'Direcția Financiar-Contabilă')
    when 'dgma'
      financing_sources << FinancingSource.find_by(name: 'Direcția Generală Management Academic')
    when 'dir relatii internationale'
      financing_sources << FinancingSource.find_by(name: 'Direcția Relații Internaționale')
    when 'dir comunicare si relatii publice', 'directia comunicare si relatii publice'
      financing_sources << FinancingSource.find_by(name: 'Direcția Comunicare și Relații Publice')
    when 'catedra sport', 'departamentul de sport', 'departamentul de educatie fizica', 'defs'
      financing_sources << FinancingSource.find_by(name: 'Departamentul de Educație Fizică și Sport')
    when 'it'
      financing_sources << FinancingSource.find_by(name: 'Direcția IT&C')
    when 'social'
      financing_sources << FinancingSource.find_by(name: 'Serviciul Social și Activități Studențești')
    when 'patrimoniu'
      financing_sources << FinancingSource.find_by(name: 'Direcția Patrimoniu Imobiliar')
    when 'spatii invatamant'
      financing_sources << FinancingSource.find_by(name: 'Serviciul Spații de Învățământ')
    when 'achizitii'
      financing_sources << FinancingSource.find_by(name: 'Serviciul Achiziții Publice')
    when %r{^achizitii/}
      project_details = financing_sources_column.strip
      financing_sources << FinancingSource.find_by(name: 'Serviciul Achiziții Publice')
    when 'ru'
      financing_sources << FinancingSource.find_by(name: 'Direcția Resurse Umane')
    when /^pnrr/
      project_details = financing_sources_column.delete_prefix('pnrr').delete_prefix('PNRR')
                                                .delete_prefix('/')
                                                .strip
      financing_sources << FinancingSource.find_by(name: 'PNRR')
    when /^pnnr/
      project_details = financing_sources_column.delete_prefix('pnnr').delete_prefix('PNNR')
                                                .delete_prefix('/')
                                                .strip
      financing_sources << FinancingSource.find_by(name: 'PNRR')
    when /^cdi/
      project_details = financing_sources_column.delete_prefix('cdi').delete_prefix('CDI')
                                                .delete_prefix('/')
                                                .strip
      financing_sources << FinancingSource.find_by!(name: 'CDI')
    when /^proiect cdi/
      project_details = financing_sources_column.delete_prefix('proiect cdi')
                                                .strip
      financing_sources << FinancingSource.find_by!(name: 'CDI')
    when /^fdi/
      project_details = financing_sources_column.delete_prefix('fdi').delete_prefix('FDI')
                                                .delete_prefix('/')
                                                .strip
      financing_sources << FinancingSource.find_by!(name: 'FDI')
    when /^purowax/, /^pr purowax/
      project_details = financing_sources_column.delete_prefix('pr')
                                                .delete_prefix('purowax').delete_prefix('/')
                                                .strip
      financing_sources << FinancingSource.find_by!(name: 'PUROWAX')
    when /^see/
      project_details = financing_sources_column.delete_prefix('see').delete_prefix('/')
                                                .strip
      financing_sources << FinancingSource.find_by!(name: 'SEE')
      # Special handling for entries with multiple financing sources
    when 'gradina botanica/drept. stiinte politice'
      financing_sources << FinancingSource.find_by!(name: 'Grădina Botanică')
      financing_sources << FinancingSource.find_by!(name: 'Facultatea de Drept')
      financing_sources << FinancingSource.find_by!(name: 'Facultatea de Științe Politice')
    when 'statiuni braila,orsova,sinaia'
      financing_sources << FinancingSource.find_by!(name: 'Stațiunea de Cercetări Ecologice Brăila')
      financing_sources << FinancingSource.find_by!(name: 'Stațiunea de cercetare de la Orșova')
      financing_sources << FinancingSource.find_by!(name: 'Stațiunea Zoologică Sinaia')
    when 'drept/jurnalism'
      financing_sources << FinancingSource.find_by!(name: 'Facultatea de Drept')
      financing_sources << FinancingSource.find_by!(name: 'Facultatea de Jurnalism și Științele Comunicării')
    when 'cercetare si venituri'
      financing_sources << FinancingSource.find_by!(name: 'Cercetare')
      financing_sources << FinancingSource.find_by!(name: 'Venituri')
    when 'achizitii/it'
      financing_sources << FinancingSource.find_by(name: 'Serviciul Achiziții Publice')
      financing_sources << FinancingSource.find_by(name: 'Direcția IT&C')
    else
      @financing_sources.each do |fs|
        financing_sources << fs if fs.import_regexp.match(financing_sources_column)
      end
    end

    # Remove entries which weren't found
    financing_sources.filter!(&:present?)
    if financing_sources.empty?
      raise ImportError.new(row_index,
                            "nu a putut fi găsită o sursă de finanțare denumită '#{financing_sources_column}'")
    end

    commitment.financing_sources = financing_sources
    commitment.project_details = project_details

    commitment.partner = row[5]

    commitment.value = row[6]

    commitment.procurement_type = row[7].presence || ''

    expenditure_article_code = row[8].to_s.strip

    # To avoid issues with article codes such as '20.02' being interpreted as a date or a decimal number,
    # users sometimes input it as '20.02.'. Strip the trailing dot to avoid issues.
    expenditure_article_code = expenditure_article_code.delete_suffix('.')

    # Sometimes, article codes get saved as decimals and the trailing zero gets removed.
    expenditure_article_code = '59.40' if expenditure_article_code == '59.4'

    expenditure_article = ExpenditureArticle.find_by(code: expenditure_article_code)
    if expenditure_article.nil?
      raise ImportError.new(row_index,
                            "nu a putut fi găsit un articol de cheltuială cu codul '#{expenditure_article_code}'")
    end

    commitment.expenditure_article = expenditure_article

    commitment.remarks = row[9] || ''
    commitment.noncompliance = row[10] || ''

    commitment
  end
end
