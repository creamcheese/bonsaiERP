# encoding: utf-8
# author: Boris Barroso
# email: boriscyber@gmail.com
class IncomeExpenseModel < Account

  # module for setters and getters
  extend SettersGetters

  ########################################
  # Relationships
  belongs_to :contact
  belongs_to :project

  has_one :transaction, foreign_key: :account_id, autosave:true
  has_many :transaction_histories, foreign_key: :account_id
  has_many :ledgers, foreign_key: :account_id, class_name: 'AccountLedger'
  has_many :inventory_operations, foreign_key: :account_id

  STATES = %w(draft approved paid nulled)
  ########################################
  # Validations
  validates_presence_of :date, :contact, :contact_id
  validates :state, presence: true, inclusion: {in: STATES}

  ########################################
  # Delegations
  delegate *create_accessors(*Transaction.transaction_columns), to: :transaction
  delegate :discounted?, :delivered?, :devolution?, :total_was, 
    :creator, :approver, :nuller, to: :transaction
  delegate :attributes, to: :transaction, prefix: true

  # Define boolean methods for states
  STATES.each do |_state|
    define_method :"is_#{_state}?" do
      _state == state
    end
  end

  ########################################
  # Aliases, alias and alias_method not working
  [[:ref_number, :name], [:balance, :amount]].each do |meth|
    define_method meth.first do
      self.send(meth.last)
    end

    define_method :"#{meth.first}=" do |val|
      self.send(:"#{meth.last}=", val)
    end
  end

  def to_s
    ref_number
  end

  def set_state_by_balance!
    if balance <= 0
      self.state = 'paid'
    elsif balance != total
      self.state = 'approved'
    elsif state.blank?
      self.state = 'draft'
    end
  end

  def discount
    gross_total - total
  end

  def discount_percent
    discount/gross_total
  end

  def approve!
    if is_draft?
      self.state = 'approved'
      self.approver_id = UserSession.id
      self.approver_datetime = Time.zone.now
      self.due_date = Date.today
    end
  end

  def null!
    if can_null?
      update_attributes(state: 'nulled', nuller_id: UserSession.id, nuller_datetime: Time.zone.now)
    end
  end

  def can_null?
    total === amount && !is_nulled?
  end

  alias :old_attributes :attributes
  def attributes
    old_attributes.merge(transaction.attributes)
  end

private
  def nulling_valid?
    ['paid', 'approved'].include?(state_was) && is_nulled?
  end
end
