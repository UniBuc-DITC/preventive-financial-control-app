# frozen_string_literal: true

class ExpendituresController < ApplicationController
  def index
    @expenditures = Expenditure.order(id: :desc)

    relation_names = %i[financing_source project_category expenditure_article payment_method created_by_user]
    @expenditures = @expenditures.references(relation_names).includes(relation_names)

    if params[:start_date].present?
      start_date = Date.strptime(params[:start_date], '%d.%m.%Y')
      @expenditures = @expenditures.where('registration_date >= ?', start_date)
    end

    if params[:end_date].present?
      end_date = Date.strptime(params[:end_date], '%d.%m.%Y')
      @expenditures = @expenditures.where('registration_date <= ?', end_date)
    end

    if params[:financing_source_id].present?
      financing_source = FinancingSource.find(params[:financing_source_id])
      @expenditures = @expenditures.where(financing_source:)
    end

    if params[:expenditure_article_id].present?
      expenditure_article = ExpenditureArticle.find(params[:expenditure_article_id])
      @expenditures = @expenditures.where(expenditure_article:)
    end

    @paginated_expenditures = @expenditures.paginate(page: params[:page], per_page: 5)
  end

  def new
    @expenditure = Expenditure.new
    @expenditure.year = Setting.current_year
    @expenditure.registration_date = Time.zone.today
    @expenditure.created_by_user = current_user
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
      flash[:notice] = "A fost salvată cu succes cheltuiala cu numărul de înregistrare #{@expenditure.registration_number}/#{@expenditure.year}"
      redirect_to expenditures_path
    else
      flash[:alert] = 'Nu s-a putut salva noua cheltuială. Verificați erorile și încercați din nou.'
      render :new, status: :unprocessable_entity
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
        if row[1].blank? && row[2].blank?
          break
        end

        parse_expenditure row_index, row

        total_count += 1
      end
    end

    flash[:notice] = "S-au importat cu succes #{total_count} de înregistrări!"
    redirect_to expenditures_path

  rescue ImportError => e
    flash.now[:alert] = e.to_s
    return render :import
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
      :payment_method_id,
      :beneficiary,
      :invoice,
      :noncompliance,
      :remarks
    )
  end

  def parse_expenditure(row_index, row)
    expenditure = Expenditure.new

    expenditure.registration_number = row[0]

    registration_date = Date.strptime(row[1], '%d.%m.%Y')
    expenditure.registration_date = registration_date
    expenditure.year = registration_date.year

    financing_source_name = row[2]

    financing_source = nil
    case financing_source_name
    when 'venituri', 'venituri ub', 'rectorat'
      financing_source = FinancingSource.find_by(name: 'Venituri')
    when 'finantare complementara'
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
    when 'adm si afaceri', 'fac ad si afaceri', 'administratie'
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
    when 'lls'
      financing_source = FinancingSource.find_by(name: 'Facultatea de Limbi și Literaturi Străine')
    when 'lma'
      # TODO: add
      financing_source = FinancingSource.find_by(name: 'Limbi Moderne Aplicate')
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
    end

    if financing_source.nil?
      raise ImportError.new(row_index, "nu a putut fi găsită o sursă de finanțare denumită '#{financing_source_name}'")
    end

    expenditure_article_code = row[3].to_s.strip

    # TODO: what corresponds to code 61.01?

    # TODO: get this fixed, the code got saved as a decimal and the trailing zero got removed
    if expenditure_article_code == '59.4'
      # TODO: delete 59.04
      expenditure_article_code = '59.40'
    end

    expenditure_article = ExpenditureArticle.find_by(code: expenditure_article_code)
    if expenditure_article.nil?
      raise ImportError.new(row_index, "nu a putut fi găsit un articol de cheltuială cu codul '#{expenditure_article_code}'")
    end

    expenditure.expenditure_article = expenditure_article

    project_name = row[4].strip

    if row_index == 1464
      # TODO: fix upstream
      project_name = 'finantarea cercetarii'
    end

    project_category = nil
    project_details = nil
    case project_name
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
      'pr valuta',
      # TODO: check if this is the same thing
      'finantare valuta'
      # TODO: what is this category?
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
      # TODO: fix this...
      /^pnnr/, /^PNNR/
      project_details = project_name.delete_prefix('pnrr').delete_prefix('PNRR')
                                    .delete_prefix('pnnr').delete_prefix('PNNR')
                                    .delete_prefix('/')
                                    .strip
      project_category = ProjectCategory.find_by!(name: 'PNRR')
    when /^i\d/
      project_details = project_name.strip
      project_category = ProjectCategory.find_by!(name: 'PNRR')
    when 'CDI'
      project_category = ProjectCategory.find_by!(name: 'CDI')
    when /^cdi/
      project_details = project_name.delete_prefix('cdi').delete_prefix('/').strip
      project_category = ProjectCategory.find_by!(name: 'CDI')
    when /^pocu/
      project_details = project_name.delete_prefix('pocu').delete_prefix('/').strip
      project_category = ProjectCategory.find_by!(name: 'POCU')
    when /^fcs/
      project_details = project_name.delete_prefix('fcs').delete_prefix('/').strip
      project_category = ProjectCategory.find_by!(name: 'FCS')
    when /^see/, /^SEE/
      project_details = project_name.delete_prefix('see').delete_prefix('/')
                                    .delete_prefix('SEE').delete_prefix('/')
                                    .strip
      project_category = ProjectCategory.find_by!(name: 'SEE')
    when /^ctr/
      # TODO: check if this makes sense
      project_details = project_name.delete_prefix('ctr').strip
      project_category = ProjectCategory.find_by!(name: 'CTR')
    when /^purowax/, /^pr purowax/
      project_details = project_name.delete_prefix('pr')
                                    .delete_prefix('purowax').delete_prefix('/').strip
      project_category = ProjectCategory.find_by!(name: 'PUROWAX')
    when /^timss/
      project_details = project_name.strip
      project_category = ProjectCategory.find_by!(name: 'Proiecte Ministerul Educației Naționale')
      # TODO: should this really exist?
    when 'fond cercetare chifiriuc'
      project_category = ProjectCategory.find_by!(name: 'Fond cercetare Chifiriuc')
    when 'buget', 'venit trezorerie', 'venituri ub', 'ven trez', 'venit bcr', 'venituri BCR', 'venituri', 'trezorerie'
      if financing_source.name == 'Facultatea de Chimie'
        # TODO: this should be fixed upstream
        project_category = nil
      elsif financing_source.name != 'Venituri'
        raise ImportError.new(row_index, "categorie de proiect necunoscută: '#{project_name}'")
      end

      # For different kinds of revenues, store their type in the "project details" field
      project_details = project_name
      project_category = nil
    when 'finantare complementara'
      # TODO: decide whether this should stay as a project category or should be moved into financing source
      project_category = ProjectCategory.find_by!(name: 'Finanțare complementară')
    when 'editura UB'
      # TODO: check if this solution is alright
      financing_source = FinancingSource.find_by!(name: 'Editura UB')
      project_category = nil
    when 'academica'
      # TODO: check if this solution is alright
      financing_source = FinancingSource.find_by!(name: 'Casa de Oaspeți „Academica”')
      project_category = nil
    when 'casa universitarilor'
      # TODO: check if this solution is alright
      financing_source = FinancingSource.find_by!(name: 'Casa Universitarilor')
      project_category = nil
    when 'finantarea cercetarii', 'fin cercetarii', 'finantarea cercetarii stiintifice',
      # TODO: fix this typo upstream
      'finanatarea cercetarii stiintifice',
      # TODO: is this the same?
      'fond cercetare'
      # TODO: check if this solution is alright
      project_category = ProjectCategory.find_by!(name: 'Finanțarea cercetării')
    when 'icub', 'ICUB'
      # TODO: check if this solution is alright
      # Shouldn't ICUB pe a cost center?
      financing_source = FinancingSource.find_by!(name: 'ICUB')
      project_category = nil
    when 'drept universal'
      # TODO: ask if this should really be a project
      project_category = ProjectCategory.find_by!(name: 'Drept Universal')
    when 'civis cofinantare', 'cofinantare civis'
      # TODO: ask if this should really be a project
      project_category = ProjectCategory.find_by!(name: 'Cofinanțare CIVIS')
    when /^erasmus/
      # TODO: is this correct?
      project_details = project_name.delete_prefix('erasmus').delete_prefix('/').delete_prefix('+')
                                    .strip
    when /^proiect \d/, /^pr ka/
      if financing_source.name != 'Erasmus'
        raise ImportError.new(row_index, "categorie de proiect necunoscută: '#{project_name}'")
      end
      project_details = project_name
      project_category = nil
    when 'llp/erasmus'
      # TODO: is this correct? Should we instead fill in the project details field?
      project_category = ProjectCategory.find_by!(name: 'LLP/Erasmus')
    when 'progr comunitare erasmus'
      # TODO: is this correct? Should we instead fill in the project details field?
      project_category = ProjectCategory.find_by!(name: 'Programe comunitare Erasmus')
    when 'fondul rectorului'
      # TODO: check if this solution is alright
      project_category = ProjectCategory.find_by!(name: 'Fondul Rectorului')
    when 'grant doctoral'
      # TODO: check whether this shouldn't be merged into something else
      project_category = ProjectCategory.find_by!(name: 'Grant doctoral')
    when 'catedra sport'
      # TODO: check if this approach is correct
      financing_source = FinancingSource.find_by!(name: 'Departamentul de Educație Fizică și Sport')
      project_category = nil
    when 'csud'
      # TODO: check if this approach is correct
      financing_source = FinancingSource.find_by!(name: 'Consiliul Studiilor Universitare de Doctorat')
      project_category = nil
    when 'altele'
      project_category = nil
    else
      raise ImportError.new(row_index, "categorie de proiect necunoscută: '#{project_name}'")
    end

    # TODO: get rid of this workaround somehow
    if financing_source_name.downcase == 'fcs' && project_category.nil?
      project_category = ProjectCategory.find_by!(name: 'Finanțarea cercetării')
    end

    if financing_source.requires_project_category? && project_category.nil?
      raise ImportError.new(row_index, "nu a putut fi găsită un tip de proiect denumit '#{project_name}'. " +
        "Categoria de proiect nu poate fi necompletată, având în vedere că sursa de finanțare este '#{financing_source.name}'")
    end

    expenditure.financing_source = financing_source
    expenditure.project_category = project_category
    expenditure.project_details = project_details || ''

    expenditure.details = row[5]
    expenditure.procurement_type = row[6] || ''
    expenditure.ordinance_number = row[7]
    ordinance_date = row[8]
    if ordinance_date.present?
      # TODO: some rows have this date as a Float. Fix this upstream
      if row_index.in? [1661, 1663, 1664]
        ordinance_date = registration_date
      else
        ordinance_date = Date.strptime(ordinance_date, '%d.%m.%Y')
      end
    end
    expenditure.ordinance_date = ordinance_date

    # TODO: check decimal handling
    expenditure.value = row[9]

    if row_index == 673
      # TODO: fix the original row upstream
      row.insert(10, 'virament')
    end

    payment_method_name = row[10].strip

    payment_method = nil
    case payment_method_name
    when 'numerar'
      payment_method = PaymentMethod.find_by(name: 'Numerar')
    when 'virament'
      payment_method = PaymentMethod.find_by(name: 'Virament')
    when 'avans numerar'
      payment_method = PaymentMethod.find_by(name: 'Avans numerar')
    when 'avans virament'
      payment_method = PaymentMethod.find_by(name: 'Avans virament')
    end

    if payment_method.nil?
      raise ImportError.new(row_index, "nu a putut fi găsită o metodă de plată denumită '#{payment_method_name}'")
    end

    expenditure.payment_method = payment_method

    # TODO: this should be mandatory, check row 2310
    expenditure.beneficiary = row[11] || '-'

    expenditure.invoice = row[12] || ''

    expenditure.noncompliance = row[13] || ''
    expenditure.remarks = row[14] || ''

    expenditure.created_by_user = current_user
    expenditure.updated_by_user = current_user

    successfully_saved = expenditure.save

    if successfully_saved
      # TODO: decide if we really need this many audit events
      # AuditEvent.create!(
      #   timestamp: DateTime.now,
      #   user: current_user,
      #   action: :insert,
      #   target_table: :expenditures,
      #   target_object_id: "#{expenditure.registration_number}/#{expenditure.year}",
      # )
    else
      raise ImportError.new(row_index, "nu s-a putut salva înregistrarea: #{expenditure.errors.full_messages.join(', ')}.")
    end
  end
end
