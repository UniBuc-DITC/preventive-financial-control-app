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
    redirect_to commitments_path

  rescue ImportError => e
    flash.now[:alert] = e.to_s
    return render :import
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
    commitment = Commitment.new

    if row_index == 691
      # TODO: registration number should've been 689, but it's actually a date
      return
    end

    commitment.registration_number = row[0]

    if commitment.registration_number.in? [308, 991, 1012, 1213, 1400, 1401, 1914]
      # TODO: how to handle this? Multiple value in financing source cell
      return
    elsif commitment.registration_number.in? [383, 675, 925, 936, 1000,
                                              1004, 1005, 1006, 1007, 1008,
                                              1295, 1371, 1393, 1473,
                                              1799, 1906]
      # TODO: financing source seems to be wrong
      return
    elsif commitment.registration_number.in? [487, 488, 489, 492, 507, 508, 1310]
      # TODO: missing expenditure article code
      return
    end

    if commitment.registration_number == 467
      # TODO: missing validity
      return
    end

    if commitment.registration_number == 580
      # TODO: missing financing source
      return
    end

    if commitment.registration_number == 668
      # TODO: invalid financing source
      return
    end

    if commitment.registration_number.in? [1147, 1795]
      # TODO: ask what is this financing source, 'grant doctoral'
      return
    end

    if commitment.registration_number == 1177
      # TODO: ask what is this financing source
      return
    end

    if commitment.registration_number == 1205
      # TODO: what is this financing source
      return
    end

    if commitment.registration_number == 1208
      # TODO: what is this financing source
      return
    end

    if commitment.registration_number.in? [1263, 1264]
      # TODO: what are these?
      return
    end

    if commitment.registration_number == 1788
      # TODO: seems to have written value in place of expenditure article
      return
    end

    if commitment.registration_number == 1827
      # TODO: ask what 'microproductie' should be
      return
    end

    if commitment.registration_number.in? [1919, 1920]
      # TODO: why are they missing?
      return
    end

    if commitment.registration_number == 1948
      # TODO: why is there a person's name listed here?
      return
    end

    if commitment.registration_number == 2011
      # TODO: this one is very weird
      return
    end

    if commitment.registration_number == 2063
      # TODO: is this the right financing source?
      return
    end

    if commitment.registration_number == 2064
      # TODO: invalid expenditure article code
      return
    end

    registration_date = Date.strptime(row[1], '%d.%m.%Y')
    commitment.registration_date = registration_date
    commitment.year = registration_date.year

    commitment.document_number = row[2]
    commitment.validity = row[3]

    financing_source_name = row[4]

    if financing_source_name.nil?
      # TODO: fix this, registration number 17, 859, 860 are missing it
      return
    end

    financing_source = nil
    project_details = ''
    case financing_source_name.strip
    when 'venituri', 'venituri ub', 'rectorat', 'ub', 'ven trez', 'ven trezorerie'
      financing_source = FinancingSource.find_by(name: 'Venituri')
    when /^venit/
      project_details = financing_source_name.delete_prefix('venit').strip
      financing_source = FinancingSource.find_by(name: 'Venituri')
      # TODO: is this correct?
    when 'buget', 'trezorerie', 'BUGET'
      project_details = financing_source_name.strip
      financing_source = FinancingSource.find_by(name: 'Venituri')
      # TODO: ask it this is correct or if this should be a separate financing source
    when 'drept universal'
      project_details = financing_source_name.strip
      financing_source = FinancingSource.find_by(name: 'Venituri')
    when 'finantare complementara',
      # TODO: fix this typo
      'finantare complemnetara' # Commitment no. 467
      # TODO: decide whether this should be a financing source, or use revenues and have it be a project category
      financing_source = FinancingSource.find_by(name: 'Finanțare complementară')
    when 'cercetare',
      # TODO: fix this, line 317
      'cercetre',
      # TODO: check if this is okay
      'finantarea cercetarii',
      'finantarea cercetarii stiintifice',
      'fin cercetarii',
      'pr cu tva', 'pr nationale', 'pr internationale', 'proiecte internationale',
      'proiecte in valuta', 'pr in valuta',
      # TODO: check these to be correct
      /^pfe /, /^pfe\//, /^fcs /, /^fcs\//, /^FCS\//,
      /^fss\//, /^fss /, /^FSS\//, /^proiecte fss/,
      /^CPI\//,
      /^lifewatch/, /^timss/,
      /^proiect caipe/, /^pr growing/, /^pr employer/, /^pr ev potential/, /^pr siec/,
      /^proiect addendum/,
      # TODO: check this as well
      'fcs', 'FCS',
      # TODO: check this as well
      'fss', 'FSS',
      # TODO: check this as well
      'pfe',
      # TODO: check this as well
      'fse',
      # TODO: check this as well
      /^pr men/
      project_details = financing_source_name.strip
      financing_source = FinancingSource.find_by(name: 'Cercetare')
    when /^llp-uri/
      project_details = financing_source_name.delete_prefix('llp-uri').delete_prefix('/').strip
      # TODO: is this choice correct?
      financing_source = FinancingSource.find_by(name: 'Erasmus')
    when 'pnrr', 'PNRR',
      # TODO: get this fixed
      'pnnr'
      # TODO: should this actually be considered research?
      financing_source = FinancingSource.find_by(name: 'PNRR')
    when /^pocu/
      project_details = financing_source_name.delete_prefix('pocu').delete_prefix('/').strip
      financing_source = FinancingSource.find_by(name: 'POCU')
    when 'fdi', 'FDI'
      financing_source = FinancingSource.find_by(name: 'FDI')
    when 'camine',
      # TODO: check these as well
      'cam a1 grozavesti', 'cam st militaru', 'cam b groavesti'
      financing_source = FinancingSource.find_by(name: 'Cămine')
    when /^camine /
      project_details = financing_source_name.delete_prefix('camine').strip
      financing_source = FinancingSource.find_by(name: 'Cămine')
    when 'cantina', 'cantina ub',
      # TODO: fix this
      'cantina  ub'
      financing_source = FinancingSource.find_by(name: 'Cantine')
    when /^cantina/
      project_details = financing_source_name.delete_prefix('cantina').delete_prefix('/')
                                             .strip
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
    when 'see', 'SEE', 'grant SEE'
      financing_source = FinancingSource.find_by(name: 'SEE')
    when 'erasmus', 'ven erasmus', 'proiect de tip Erasmus'
      financing_source = FinancingSource.find_by(name: 'Erasmus')
    when /^erasmus\//
      project_details = financing_source_name.delete_prefix('erasmus').delete_prefix('/')
                                             .strip
      financing_source = FinancingSource.find_by(name: 'Erasmus')
    when 'civis', 'civis 2'
      project_details = financing_source_name.strip
      financing_source = FinancingSource.find_by(name: 'CIVIS')
    when 'gr botanica', 'gradina botanica'
      financing_source = FinancingSource.find_by(name: 'Grădina Botanică')
    when 'st sf gheorghe'
      financing_source = FinancingSource.find_by(name: 'Stațiunea de cercetări de la Sfântu Gheorghe')
    when 'st orsova', 'st. orsova'
      financing_source = FinancingSource.find_by(name: 'Stațiunea de cercetare de la Orșova')
    when 'statiunea braila', 'statiune braila', 'statiune Braila', 'st braila', 'braila'
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
    when 'csud', 'CSUD'
      financing_source = FinancingSource.find_by(name: 'Consiliul Studiilor Universitare de Doctorat')
    when 'icub', 'ICUB', 'UB icub'
      financing_source = FinancingSource.find_by(name: 'ICUB')
    when /^icub/
      project_details = financing_source_name.delete_prefix('icub').delete_prefix('-')
                                             .strip
      financing_source = FinancingSource.find_by(name: 'ICUB')
    when /^ICUB/
      project_details = financing_source_name.delete_prefix('ICUB').delete_prefix('/')
                                             .strip
      financing_source = FinancingSource.find_by(name: 'ICUB')
      ## Faculties
    when 'adm si afaceri', 'fac ad si afaceri', 'administratie si afaceri', 'admin si afaceri',
      # TODO: is this correct? Row 2374
      'administratie',
      # TODO: is this correct? Registration number 444
      'Administratie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Administrație și Afaceri')
    when 'biologie', 'fac biologie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Biologie')
    when 'fac chimie', 'chimie',
      # TODO: fix this upstream, line 2344
      'chmie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Chimie')
    when 'drept', 'fac drept'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Drept')
    when /^DREPT /
      project_details = financing_source_name.delete_prefix('DREPT').strip
      financing_source = FinancingSource.find_by(name: 'Facultatea de Drept')
    when 'filosofie', 'fac filosofie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Filosofie')
    when /filosofie /
      project_details = financing_source_name.delete_prefix('filosofie').strip
      financing_source = FinancingSource.find_by(name: 'Facultatea de Filosofie')
      # TODO: ask if this is fine
    when /catedra unesco/
      project_details = financing_source_name.strip
      financing_source = FinancingSource.find_by(name: 'Facultatea de Filosofie')
    when 'fizica', 'fac fizica'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Fizică')
    when /^fizica /
      project_details = financing_source_name.delete_prefix('fizica').strip
      financing_source = FinancingSource.find_by(name: 'Facultatea de Fizică')
    when 'istorie', 'fac istorie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Istorie')
    when 'teologie ortodoxa', 'teol ortodoxa'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Teologie Ortodoxă')
    when 'teologie baptista', 'teol baptista'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Teologie Baptistă')
    when 'teologie rom catolica', 'teol romano catolica', 'teologie romano catolica', 'teologie catolica'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Teologie Romano-Catolică')
    when 'geografie', 'geografia', 'fac geografie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Geografie')
    when 'geologie', 'fac geologie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Geologie și Geofizică')
    when /^Fac. de Geologie/
      project_details = financing_source_name.delete_prefix('Fac. de Geologie').strip
                                             .delete_prefix('-').strip
      financing_source = FinancingSource.find_by(name: 'Facultatea de Geologie și Geofizică')
    when 'litere', 'Litere', 'fac litere'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Litere')
    when 'lls', 'fac lls', 'LLS'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Limbi și Literaturi Străine')
    when 'lma'
      # TODO: add
      financing_source = FinancingSource.find_by(name: 'Limbi Moderne Aplicate')
    when 'matematica', 'fac matematica', 'Matematica'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Matematică și Informatică')
    when 'jurnalism', 'fac jurnalism'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Jurnalism')
    when 'psihologie', 'Psihologie', 'fac psihologie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Psihologie și Științele Educației')
    when /^psihologie/
      project_details = financing_source_name.delete_prefix('psihologie').strip
                                             .delete_prefix('/').strip
      financing_source = FinancingSource.find_by(name: 'Facultatea de Psihologie și Științele Educației')
    when 'stiinte politice', 'st politice', 'fac st politice'
      # TODO: fix this, line 839
      'sttinte politice'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Științe Politice')
    when 'sociologie', 'fac sociologie'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Sociologie și Asistență Socială')
    when 'tehnic', 'TEHNIC'
      financing_source = FinancingSource.find_by(name: 'Direcția Tehnică')
    when 'financiar'
      financing_source = FinancingSource.find_by(name: 'Direcția Financiar-Contabilă')
    when 'DGMA'
      financing_source = FinancingSource.find_by(name: 'Direcția Generală Management Academic')
    when 'dir relatii internationale'
      financing_source = FinancingSource.find_by(name: 'Direcția Relații Internaționale')
    when 'dir comunicare si relatii publice', 'directia comunicare si relatii publice',
      'Directia Comunicare si Relatii Publice'
      financing_source = FinancingSource.find_by(name: 'Direcția Comunicare și Relații Publice')
    when 'departamentul de sport', 'departamentul de educatie fizica', 'DEFS'
      financing_source = FinancingSource.find_by(name: 'Departamentul de Educație Fizică și Sport')
    when 'IT'
      financing_source = FinancingSource.find_by(name: 'Direcția IT&C')
    when 'social'
      financing_source = FinancingSource.find_by(name: 'Serviciul Social și Activități Studențești')
    when 'patrimoniu'
      financing_source = FinancingSource.find_by(name: 'Direcția Patrimoniu Imobiliar')
    when 'spatii invatamant'
      financing_source = FinancingSource.find_by(name: 'Serviciul Spații de Învățământ')
    when 'achizitii'
      financing_source = FinancingSource.find_by(name: 'Serviciul Achiziții Publice')
    when 'ru', 'RU'
      financing_source = FinancingSource.find_by(name: 'Direcția Resurse Umane')
    when /^pnrr/, /^PNRR/
      project_details = financing_source_name.delete_prefix('pnrr').delete_prefix('PNRR')
                                             .delete_prefix('/')
                                             .strip
      financing_source = FinancingSource.find_by(name: 'PNRR')
    when /^pnnr/, /^PNNR/
      project_details = financing_source_name.delete_prefix('pnnr').delete_prefix('PNNR')
                                             .delete_prefix('/')
                                             .strip
      financing_source = FinancingSource.find_by(name: 'PNRR')
    when /^cdi/, /^CDI/
      # TODO: is this alright?
      project_details = financing_source_name.delete_prefix('cdi').delete_prefix('CDI')
                                             .delete_prefix('/')
                                             .strip
      financing_source = FinancingSource.find_by!(name: 'CDI')
    when /^proiect cdi/
      # TODO: is this alright?
      project_details = financing_source_name.delete_prefix('proiect cdi')
                                             .strip
      financing_source = FinancingSource.find_by!(name: 'CDI')
    when /^fdi/, /^FDI/
      project_details = financing_source_name.delete_prefix('fdi').delete_prefix('FDI')
                                             .delete_prefix('/')
                                             .strip
      financing_source = FinancingSource.find_by!(name: 'FDI')
    when /^purowax/, /^pr purowax/
      project_details = financing_source_name.delete_prefix('pr')
                                             .delete_prefix('purowax').delete_prefix('/')
                                             .strip
      financing_source = FinancingSource.find_by!(name: 'PUROWAX')
    when /^Purowax/
      project_details = financing_source_name.delete_prefix('Purowax').delete_prefix('/')
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

    # TODO: check if procurement_type should be required
    commitment.procurement_type = row[7].presence || ''

    expenditure_article_code = row[8].to_s.strip

    # TODO: get this fixed, the code got saved as a decimal and the trailing zero got removed
    if expenditure_article_code == '59.4'
      # TODO: delete 59.04
      expenditure_article_code = '59.40'
    end

    if expenditure_article_code == '55.48'
      # TODO: what is this code? It doesn't exist
      return
    end

    # TODO: what corresponds to code 61.01?

    # TODO: is this correct? Entry no. 1276
    if expenditure_article_code == '71'
      return
    end

    expenditure_article = ExpenditureArticle.find_by(code: expenditure_article_code)
    if expenditure_article.nil?
      raise ImportError.new(row_index, "nu a putut fi găsit un articol de cheltuială cu codul '#{expenditure_article_code}'")
    end

    commitment.expenditure_article = expenditure_article

    commitment.remarks = row[9] || ''
    commitment.noncompliance = row[10] || ''

    commitment.created_by_user = current_user
    commitment.updated_by_user = current_user

    successfully_saved = commitment.save

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
