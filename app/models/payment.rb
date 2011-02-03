# encoding: utf-8
# author: Boris Barroso
# email: boriscyber@gmail.com
class Payment < ActiveRecord::Base
  acts_as_org

  attr_reader :pay_plan

  # callbacks
  after_initialize :set_defaults
  after_save :update_transaction
  after_save :update_pay_plan

  # relationships
  belongs_to :transaction
  belongs_to :account

  # validations
  validate :valid_payment_amount
  validate :valid_amount_or_interests_penalties

  # scopes
  default_scope where(:organisation_id => OrganisationSession.organisation_id)

private
  def set_defaults
    self.amount ||= 0
    self.interests_penalties ||= 0
  end

  def update_transaction
    transaction.add_payment(amount)
  end

  # Updates the related pay_plans of a transaction setting to pay
  # according to the amount and interest penalties
  def update_pay_plan
    amount_to_pay = 0
    interest_to_pay = 0
    created_pay_plan = nil
    amount_to_pay = amount
    interest_to_pay = interests_penalties

    transaction.pay_plans.unpaid.each do |pp|
      amount_to_pay += - pp.amount
      interest_to_pay += - pp.interests_penalties

      pp.update_attribute(:paid, true)

      if amount_to_pay <= 0
        @pay_plan = create_pay_plan(amount_to_pay, interest_to_pay) if amount_to_pay < 0 or interest_to_pay < 0
        break
      end
    end
  end

  # Creates a new pay_plan
  def create_pay_plan(amt, int_pen)
    amt = amt < 0 ? -1 * amt : 0
    int_pen = int_pen < 0 ? -1 * int_pen : 0
    d = Date.today + 1.day
    p = PayPlan.create(:transaction_id => transaction_id, :amount => amt, :interests_penalties => int_pen,
                    :payment_date => d, :alert_date => d )
  end

  def valid_payment_amount
    if amount > transaction.balance
      self.errors.add(:amount, "La cantidad ingresada es mayor que el saldo por pagar.")
    end
  end

  # Checks that anny of the values is set to greater than 0
  def valid_amount_or_interests_penalties
    if self.amount <= 0 and interests_penalties <= 0
      self.errors.add(:amount, "Debe ingresar una cantidad mayor a 0 para Cantidad o Intereses/Penalidades")
    end
  end
end
