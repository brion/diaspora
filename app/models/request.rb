#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

class Request
  require File.join(Rails.root, 'lib/diaspora/webhooks')

  include MongoMapper::Document
  include Diaspora::Webhooks
  include ROXML

  xml_reader :sender_handle
  xml_reader :recipient_handle

  belongs_to :into, :class => Aspect
  belongs_to :from, :class => Person
  belongs_to :to,   :class => Person

  validates_presence_of :from, :to
  validate :not_already_connected_if_sent
  validate :not_already_connected_if_not_sent
  validate :no_pending_request, :if => :sent
  validate :not_friending_yourself

  scope :from, lambda { |person| 
    target = (person.is_a?(User) ? person.person : person)
    where(:from_id => target.id)
  }

  scope :to, lambda { |person| 
    target = (person.is_a?(User) ? person.person : person)
    where(:to_id => target.id)
  }


  def self.instantiate(opts = {})
    self.new(:from => opts[:from],
             :to   => opts[:to],
             :into => opts[:into],
             :sent => true)
  end

  def reverse_for accepting_user
    Request.new(
      :from => accepting_user.person,
      :to => self.from
    )
  end

  def sender_handle
    from.diaspora_handle
  end

  def sender_handle= sender_handle
    self.from = Person.first(:diaspora_handle => sender_handle)
  end

  def recipient_handle
    to.diaspora_handle
  end

  def recipient_handle= recipient_handle
    self.to = Person.first(:diaspora_handle => recipient_handle)
  end

  def diaspora_handle
    self.from.diaspora_handle
  end

  def self.hashes_for_person person
    requests = Request.to(person).all
    senders = Person.all(:id.in => requests.map{|r| r.from_id}, :fields => [:profile])
    senders_hash = {}
    senders.each{|sender| senders_hash[sender.id] = sender}
    requests.map{|r| {:request => r, :sender => senders_hash[r.from_id]}}
  end
  private
  def no_pending_request
    if Request.first(:from_id => from_id, :to_id => to_id)
      errors[:base] << 'You have already sent a request to that person'
    end
  end

  def not_already_connected_if_sent
    if self.sent
      if Contact.first(:user_id => self.from.owner_id, :person_id => self.to.id)
        errors[:base] << 'You have already connected to this person'
      end
    end
  end

  def not_already_connected_if_not_sent
    unless self.sent
      if Contact.first(:user_id => self.to.owner_id, :person_id => self.from.id)
        errors[:base] << 'You have already connected to this person'
      end
    end
  end

  def not_friending_yourself
    if self.to == self.from 
      errors[:base] << 'You can not friend yourself'
    end
  end
end
