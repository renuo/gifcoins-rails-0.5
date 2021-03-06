require 'abstract_unit'
# require File.dirname(__FILE__) + '/../dev-utils/eval_debugger'
require 'fixtures/company'
require 'fixtures/developer'
require 'fixtures/project'

# Can't declare new classes in test case methods, so tests before that
bad_collection_keys = false
begin
  class Car < ActiveRecord::Base; has_many :wheels, :name => "wheels"; end
rescue ActiveRecord::ActiveRecordError
  bad_collection_keys = true
end
raise "ActiveRecord should have barked on bad collection keys" unless bad_collection_keys


class AssociationsTest < Test::Unit::TestCase
  def setup
    create_fixtures "accounts"
    create_fixtures "companies"
    create_fixtures "accounts"
    create_fixtures "developers"
    create_fixtures "projects"
    create_fixtures "developers_projects"
    
    @signals37 = Firm.find(1)
  end

  def test_has_many_find
    assert_equal 2, Firm.find_first.clients.length
  end
  
  def test_has_many_orders
    assert_equal "Summit", Firm.find_first.clients.first.name
  end

  def test_has_many_class_name
    assert_equal "Microsoft", Firm.find_first.clients_sorted_desc.first.name
  end

  def test_has_many_foreign_key
    assert_equal "Microsoft", Firm.find_first.clients_of_firm.first.name
  end
  
  def test_has_many_conditions
    assert_equal "Microsoft", Firm.find_first.clients_like_ms.first.name
  end

  def test_has_many_sql
    firm = Firm.find_first
    assert_equal "Microsoft", firm.clients_using_sql.first.name
    assert_equal 1, firm.clients_using_sql_count
    assert_equal 1, Firm.find_first.clients_using_sql_count
  end
  
  def test_has_many_queries
    assert Firm.find_first.has_clients?
    firm = Firm.find_first
    assert_equal 2, firm.clients_count # tests using class count
    firm.clients
    assert firm.has_clients?
    assert_equal 2, firm.clients_count # tests using collection length
  end

  def test_has_many_dependence
    assert_equal 2, Client.find_all.length
    Firm.find_first.destroy
    assert_equal 0, Client.find_all.length
  end

  def test_has_many_dependence_with_transaction_support_on_failure
    assert_equal 2, Client.find_all.length

    firm = Firm.find_first
    clients = firm.clients
    clients.last.instance_eval { def before_destroy() raise "Trigger rollback" end }

    firm.destroy rescue "do nothing"

    assert_equal 2, Client.find_all.length
  end
  
  def test_has_one_dependence
    firm = Firm.find(1)
    assert firm.has_account?
    firm.destroy
    assert_equal 1, Account.find_all.length
  end

  def test_has_one_dependence_with_missing_association
    Account.destroy_all
    firm = Firm.find(1)
    assert !firm.has_account?
    firm.destroy
  end

  def test_belongs_to
    assert_equal @signals37.name, Client.find(3).firm.name
    assert Client.find(3).has_firm?, "Microsoft should have a firm"
    # assert !Company.find(1).has_firm?, "37signals shouldn't have a firm"
  end
  
  def test_belongs_to_with_different_class_name
    assert_equal Company.find(1).name, Company.find(3).firm_with_other_name.name
    assert Company.find(3).has_firm_with_other_name?, "Microsoft should have a firm"
    assert !Company.find(1).has_firm_with_other_name?, "37signals shouldn't have a firm"
  end

  def test_belongs_to_with_condition
    assert_equal Company.find(1).name, Company.find(3).firm_with_condition.name
    assert Company.find(3).has_firm_with_condition?, "Microsoft should have a firm"
    assert !Company.find(1).has_firm_with_condition?, "37signals shouldn't have a firm"
  end

  
  def test_belongs_to_equality
    assert Company.find(3).firm?(Company.find(1)), "Microsoft should have 37signals as firm"
    assert_raises(RuntimeError) { !Company.find(3).firm?(Company.find(3)) } # "Summit shouldn't have itself as firm"
  end
  
  def test_has_one
    assert @signals37.account?(Account.find(1))
    assert_equal Account.find(1).credit_limit, @signals37.account.credit_limit
    assert @signals37.has_account?, "37signals should have an account"
    assert Account.find(1).firm?(@signals37), "37signals account should be able to backtrack"
    assert Account.find(1).has_firm?, "37signals account should be able to backtrack"

    assert !Account.find(2).has_firm?, "Unknown isn't linked"
    assert !Account.find(2).firm?(@signals37), "Unknown isn't linked"
  end

  def test_has_many_dependence_on_account
    assert_equal 2, Account.find_all.length
    @signals37.destroy
    assert_equal 1, Account.find_all.length
  end
  
  def test_find_in
    assert_equal Client.find(2).name, @signals37.find_in_clients(2).name
    assert_raises(ActiveRecord::RecordNotFound) { @signals37.find_in_clients(6) }
  end
  
  def test_force_reload
    firm = Firm.new
    firm.save
    
    assert firm.clients.empty?, "New firm shouldn't have client objects"
    assert !firm.has_clients?, "New firm shouldn't have clients"
    assert_equal 0, firm.clients_count, "New firm should have 0 clients"
    
    client = Client.new("firm_id" => firm.id)
    client.save

    assert firm.clients.empty?, "New firm should have cached no client objects"
    assert !firm.has_clients?, "New firm should have cached a no-clients response"
    assert_equal 0, firm.clients_count, "New firm should have cached 0 clients count"

    assert !firm.clients(true).empty?, "New firm should have reloaded client objects"
    assert firm.has_clients?(true), "New firm should have reloaded with a have-clients response"
    assert_equal 1, firm.clients_count(true), "New firm should have reloaded clients count"
  end
    
  def test_included_in_collection
    assert @signals37.clients.include?(Client.find(2))
  end

  def test_build_to_collection
    assert_equal 1, @signals37.clients_of_firm_count
    new_client = @signals37.build_to_clients_of_firm("name" => "Another Client")
    assert_equal "Another Client", new_client.name
    assert new_client.save

    assert new_client.firm?(@signals37)
    assert_equal 2, @signals37.clients_of_firm_count(true)
  end
  
  def test_create_in_collection
    assert_equal @signals37.create_in_clients_of_firm("name" => "Another Client"), @signals37.clients_of_firm(true).last
  end
  
  def test_succesful_build_association
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.save
    
    account = firm.build_account("credit_limit" => 1000)
    assert account.save
    assert_equal account, firm.account
  end
  
  def test_failing_build_association
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.save
    
    account = firm.build_account
    assert !account.save
    assert_equal "can't be empty", account.errors.on("credit_limit")
  end
  
  def test_create_association
    firm = Firm.new("name" => "GlobalMegaCorp")
    firm.save
    assert_equal firm.create_account("credit_limit" => 1000), firm.account
  end
  
  def test_has_and_belongs_to_many
    david = Developer.find(1)
    assert david.has_projects?
    assert_equal 2, david.projects_count

    active_record = Project.find(1)
    assert active_record.has_developers?
    assert_equal 2, active_record.developers_count
    assert_equal david.name, active_record.developers.first.name
  end

  def test_has_and_belongs_to_many_removing
    david = Developer.find(1)
    active_record = Project.find(1)

    david.remove_projects(active_record)
    
    assert_equal 1, david.projects_count
    assert_equal 1, active_record.developers_count    
  end

  def test_has_and_belongs_to_many_zero
    david = Developer.find(1)
    david.remove_projects(Project.find_all)
    
    assert_equal 0, david.projects_count
    assert !david.has_projects?
  end

  def test_has_and_belongs_to_many_adding
    jamis = Developer.find(2)
    action_controller = Project.find(2)

    jamis.add_projects(action_controller)
    
    assert_equal 2, jamis.projects_count
    assert_equal 2, action_controller.developers_count    
  end

  def test_has_and_belongs_to_many_adding_from_the_project
    jamis = Developer.find(2)
    action_controller = Project.find(2)

    action_controller.add_developers(jamis)
    
    assert_equal 2, jamis.projects_count
    assert_equal 2, action_controller.developers_count
  end
  
  def test_has_and_belongs_to_many_adding_a_collection
    aridridel = Developer.new("name" => "Aridridel")
    aridridel.save
    
    aridridel.add_projects([ Project.find(1), Project.find(2) ])
    assert_equal 2, aridridel.projects_count
  end
  
  def test_belongs_to_counter
    apple = Firm.create("name" => "Apple")
    assert_equal 0, apple.send(:read_attribute, "companies_count"), "No clients yet"

    final_cut = apple.create_in_clients("name" => "Final Cut")
    assert_equal 1, Firm.find(apple.id).send(:read_attribute, "companies_count"), "First client created"

    final_cut.destroy
    assert_equal 0, Firm.find(apple.id).send(:read_attribute, "companies_count"), "First client deleted"
  end
  
  def test_natural_assignment_of_has_one
    apple = Firm.create("name" => "Apple")
    citibank = Account.create("credit_limit" => 10)
    apple.account = citibank
    assert_equal apple.id, citibank.firm_id
  end
  
  def test_natural_assignment_of_belongs_to
    apple = Firm.create("name" => "Apple")
    citibank = Account.create("credit_limit" => 10)
    citibank.firm = apple
    assert_equal apple.id, citibank.firm_id
  end

  def test_natural_assignment_of_has_many
    apple = Firm.create("name" => "Apple")
    natural = Client.new("name" => "Natural Company")
    apple.clients << natural
    assert_equal apple.id, natural.firm_id
    assert_equal Client.find(natural.id), Firm.find_first("name = 'Apple'").clients.find { |c| c.name == "Natural Company" }
  end
end