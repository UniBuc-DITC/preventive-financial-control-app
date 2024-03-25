# frozen_string_literal: true

class CommitmentsController < ApplicationController
  def index
    @commitments = Commitment.order(id: :desc)

    relation_names = %i[financing_source expenditure_article created_by_user]
    @commitments = @commitments.references(relation_names).includes(relation_names)

    if params[:start_date].present?
      start_date = Date.strptime(params[:start_date], '%d.%m.%Y')
      @commitments = @commitments.where('registration_date >= ?', start_date)
    end

    if params[:end_date].present?
      end_date = Date.strptime(params[:end_date], '%d.%m.%Y')
      @commitments = @commitments.where('registration_date <= ?', end_date)
    end

    if params[:commitment_category_code].present?
      @commitments = @commitments.where(
        expenditure_article: {
          commitment_category_code: params[:commitment_category_code]
        }
      )
    end

    @expenditure_article_ids = params[:expenditure_article_ids]
    if @expenditure_article_ids.present?
      @expenditure_article_ids = @expenditure_article_ids.select(&:present?)

      unless @expenditure_article_ids.empty?
        @commitments = @commitments.where(expenditure_article_id: @expenditure_article_ids)
      end
    end

    @paginated_commitments = @commitments.paginate(page: params[:page])
  end

  def new
    @commitment = Commitment.new
    @commitment.year = Setting.current_year
    @commitment.registration_date = Time.zone.today
    @commitment.created_by_user = current_user

    if params[:source_expenditure_id].present?
      @source_expenditure = Expenditure.find(params[:source_expenditure_id])

      @commitment.financing_source = @source_expenditure.financing_source
      @commitment.expenditure_article = @source_expenditure.expenditure_article
      @commitment.procurement_type = @source_expenditure.procurement_type
      @commitment.value = @source_expenditure.value
    end
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
          target_object_id: "#{@commitment.registration_number}/#{@commitment.year}",
        )
      end
    end

    if successfully_saved
      flash[:notice] = "A fost salvat cu succes angajamentul cu numărul de înregistrare #{@commitment.registration_number}/#{@commitment.year}"
      redirect_to commitments_path
    else
      flash[:alert] = 'Nu s-a putut salva noul angajament. Verificați erorile și încercați din nou.'
      render :new, status: :unprocessable_entity
    end
  end

  def import; end

  def import_upload
    uploaded_file = params.require(:file)
    spreadsheet = Roo::Spreadsheet.open(uploaded_file)
    sheet = spreadsheet.sheet(0)

    total_count = 0
    Commitment.transaction do
      (3..sheet.last_row).each do |row_index|
        row = sheet.row row_index

        # We've reached the end of the filled-in table
        break if row[1].blank? && row[2].blank?

        parse_commitment row_index, row

        total_count += 1
      end
    end

    flash[:notice] = "S-au importat cu succes #{total_count} de înregistrări!"
    redirect_to expenditures_path

    # rescue ImportError => e
    #   flash.now[:alert] = e.to_s
    #   return render :import
  end

  private

  def commitment_params
    params.require(:commitment).permit(
      :registration_date,
      :financing_source_id,
      :project_details,
      :expenditure_article_id,
      :document_number,
      :validity,
      :procurement_type,
      :partner,
      :value,
      :noncompliance,
      :remarks
    )
  end

  def parse_commitment(row_index, row)
    if row_index == 12
      # TODO: ask what should 'A' mean in the financing source field
      return
    end

    commitment = Commitment.new

    commitment.registration_number = row[0]

    registration_date = Date.strptime(row[1], '%d.%m.%Y')
    commitment.registration_date = registration_date
    commitment.year = registration_date.year

    commitment.document_number = row[2]
    commitment.validity = row[3]

    financing_source_name = row[4]

    if financing_source_name.nil?
      # TODO: fix this, registration number 17 is missing it
      return
    end

    financing_source = nil
    project_details = nil
    case financing_source_name.strip
    when 'venituri', 'venituri ub'
      financing_source = FinancingSource.find_by(name: 'Venituri')
    when /^venit/
      project_details = financing_source_name.delete_prefix('venit').strip
      financing_source = FinancingSource.find_by(name: 'Venituri')
      # TODO: is this correct?
    when 'buget'
      financing_source = FinancingSource.find_by(name: 'Buget')
    when 'trezorerie'
      # TODO: determine if this is alright
      financing_source = FinancingSource.find_by(name: 'Trezorerie')
    when 'finantare complementara'
      # TODO: decide whether this should be a financing source, or use revenues and have it be a project category
      financing_source = FinancingSource.find_by(name: 'Finanțare complementară')
    when 'cercetare',
      # TODO: fix this, line 317
      'cercetre',
      # TODO: check if this is okay
      'finantarea cercetarii',
      # TODO: check this as well
      'fcs', 'FCS',
      # TODO: check this as well
      'fss', 'FSS',
      # TODO: check this as well
      'pfe',
      # TODO: check this as well
      'fse',
      # TODO: check this as well
      'pr men'
      financing_source = FinancingSource.find_by(name: 'Cercetare')
    when 'pnrr', 'PNRR',
      # TODO: get this fixed
      'pnnr'
      # TODO: should this actually be considered research?
      financing_source = FinancingSource.find_by(name: 'PNRR')
    when 'pocu'
      financing_source = FinancingSource.find_by(name: 'POCU')
    when 'fdi', 'FDI'
      financing_source = FinancingSource.find_by(name: 'FDI')
    when 'camine',
      # TODO: check these as well
      'cam a1 grozavesti', 'cam st militaru', 'cam b groavesti'
      financing_source = FinancingSource.find_by(name: 'Cămine')
    when 'cantina', 'cantina ub',
      # TODO: fix this
      'cantina  ub'
      financing_source = FinancingSource.find_by(name: 'Cantine')
    when 'casierie'
      financing_source = FinancingSource.find_by(name: 'Casierie')
    when 'editura ub', 'editura UB', 'editura universitatii'
      financing_source = FinancingSource.find_by!(name: 'Editura UB')
    when 'teren sport'
      financing_source = FinancingSource.find_by(name: 'Teren de sport')
    when 'casa universitarilor'
      financing_source = FinancingSource.find_by!(name: 'Casa Universitarilor')
    when 'purowax'
      financing_source = FinancingSource.find_by(name: 'PUROWAX')
    when 'see', 'SEE'
      financing_source = FinancingSource.find_by(name: 'SEE')
    when 'erasmus'
      financing_source = FinancingSource.find_by(name: 'Erasmus')
    when 'civis'
      financing_source = FinancingSource.find_by(name: 'CIVIS')
    when 'gr botanica', 'gradina botanica'
      financing_source = FinancingSource.find_by(name: 'Grădina Botanică')
    when 'st sf gheorghe'
      financing_source = FinancingSource.find_by(name: 'Stațiunea de cercetări de la Sfântu Gheorghe')
    when 'st orsova'
      financing_source = FinancingSource.find_by(name: 'Stațiunea de cercetare de la Orșova')
    when 'st braila'
      financing_source = FinancingSource.find_by(name: 'Stațiunea de Cercetări Ecologice Brăila')
    when 'statiunea sinaia'
      financing_source = FinancingSource.find_by(name: 'Stațiunea Zoologică Sinaia')
    when 'academica'
      financing_source = FinancingSource.find_by(name: 'Casa de Oaspeți „Academica”')
    when 'gaudeamus'
      financing_source = FinancingSource.find_by(name: 'Hotel Gaudeamus')
    when 'confucius'
      financing_source = FinancingSource.find_by(name: 'Institutul Confucius')
    when 'cls'
      financing_source = FinancingSource.find_by(name: 'Centrul de Limbi Străine')
    when 'csud'
      financing_source = FinancingSource.find_by(name: 'Consiliul Studiilor Universitare de Doctorat')
    when 'icub', 'ICUB'
      financing_source = FinancingSource.find_by(name: 'ICUB')
      ## Faculties
    when 'adm si afaceri', 'fac ad si afaceri',
      # TODO: is this correct? Row 2374
      'administratie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Administrație și Afaceri')
    when 'biologie', 'fac biologie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Biologie')
    when 'fac chimie', 'chimie',
      # TODO: fix this upstream, line 2344
      'chmie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Chimie')
    when 'drept'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Drept')
    when 'filosofie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Filosofie')
    when 'fizica'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Fizică')
    when 'istorie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Istorie')
    when 'teologie ortodoxa', 'teol ortodoxa'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Teologie Ortodoxă')
    when 'geografie', 'fac geografie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Geografie')
    when 'geologie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Geologie și Geofizică')
    when 'litere'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Litere')
    when 'lls',
      # TODO: check and fix this, line 363
      'lma'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Limbi și Literaturi Străine')
    when 'matematica'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Matematică și Informatică')
    when 'jurnalism'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Jurnalism')
    when 'psihologie', 'fac psihologie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Psihologie și Științele Educației')
    when 'stiinte politice', 'st politice',
      # TODO: fix this, line 839
      'sttinte politice'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Științe Politice')
    when 'sociologie', 'fac sociologie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Sociologie și Asistență Socială')
      # TODO: Check if this is a proper cost center
    when 'rectorat'
      financing_source = FinancingSource.find_by(name: 'Rectorat')
    when 'tehnic'
      financing_source = FinancingSource.find_by(name: 'Serviciul Tehnic')
    when 'financiar'
      financing_source = FinancingSource.find_by(name: 'Direcția Financiar-Contabilă')
    when 'ru'
      financing_source = FinancingSource.find_by(name: 'Direcția Resurse Umane')
    when /^pnrr/, /^PNRR/
      project_details = financing_source_name.delete_prefix('pnrr').delete_prefix('PNRR')
                                             .delete_prefix('/')
                                             .strip
      financing_source = FinancingSource.find_by(name: 'PNRR')
    when /^cdi/, /^CDI/
      # TODO: is this alright?
      project_details = financing_source_name.delete_prefix('cdi').delete_prefix('CDI')
                                             .delete_prefix('/')
                                             .strip
      financing_source = FinancingSource.find_by!(name: 'CDI')
    when /^purowax/, /^pr purowax/
      project_details = financing_source_name.delete_prefix('pr')
                                             .delete_prefix('purowax').delete_prefix('/')
                                             .strip
      financing_source = FinancingSource.find_by!(name: 'PUROWAX')
    when /^see/, /^SEE/
      project_details = financing_source_name.delete_prefix('see').delete_prefix('/')
                                             .delete_prefix('SEE').delete_prefix('/')
                                             .strip
      financing_source = FinancingSource.find_by!(name: 'SEE')
    end

    if financing_source.nil?
      raise ImportError.new(row_index, "nu a putut fi găsită o sursă de finanțare denumită '#{financing_source_name}'")
    end

    commitment.financing_source = financing_source
    commitment.project_details = project_details

    commitment.partner = row[5]

    commitment.value = row[6]

    commitment.procurement_type = row[7]

    expenditure_article_code = row[8].to_s.strip

    # TODO: what corresponds to code 61.01?

    expenditure_article = ExpenditureArticle.find_by(code: expenditure_article_code)
    if expenditure_article.nil?
      raise ImportError.new(row_index, "nu a putut fi găsit un articol de cheltuială cu codul '#{expenditure_article_code}'")
    end

    commitment.expenditure_article = expenditure_article

    commitment.remarks = row[9] || ''
    commitment.noncompliance = row[10] || ''

    commitment.created_by_user = current_user
    commitment.updated_by_user = current_user

    p commitment

    # successfully_saved = commitment.save
    successfully_saved = true

    if successfully_saved
      # TODO: decide if we really need this many audit events
      # AuditEvent.create!(
      #   timestamp: DateTime.now,
      #   user: current_user,
      #   action: :insert,
      #   target_table: :commitments,
      #   target_object_id: "#{commitment.registration_number}/#{commitment.year}",
      # )
    else
      raise ImportError.new(row_index, "nu s-a putut salva înregistrarea: #{commitment.errors.full_messages.join(', ')}.")
    end
  end
end
