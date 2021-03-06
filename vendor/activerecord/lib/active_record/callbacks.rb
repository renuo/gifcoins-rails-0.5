require 'observer'

module ActiveRecord
  # Callbacks are hooks into the lifecycle of an Active Record object that allows you to trigger logic
  # before or after an alteration of the object state. This can be used to make sure that associated and 
  # dependent objects are deleted when destroy is called (by overwriting before_destroy) or to massage attributes
  # before they're validated (by overwriting before_validation). As an example of the callbacks initiated, consider
  # the Base#save call:
  #
  # * (-) save
  # * (-) valid?
  # * (1) before_validation
  # * (2) before_validation_on_create
  # * (-) validate
  # * (-) validate_on_create
  # * (4) after_validation
  # * (5) after_validation_on_create 
  # * (6) before_save
  # * (7) before_create
  # * (-) create
  # * (8) after_create
  # * (9) after_save
  # 
  # That's a total of nine callbacks, which gives you immense power to react and prepare for each state in the
  # Active Record lifecyle.
  #
  # Examples:
  #   class CreditCard < ActiveRecord::Base
  #     # Strip everything but digits, so the user can specify "555 234 34" or 
  #     # "5552-3434" or both will mean "55523434"
  #     def before_validation_on_create
  #       self.number = number.gsub(/[^0-9]/, "") if attribute_present?("number")
  #     end
  #   end
  #
  #   class Subscription < ActiveRecord::Base
  #     # Automatically assign the signup date
  #     def before_create
  #       self.signed_up_on = Date.today
  #     end
  #   end
  #
  #   class Firm < ActiveRecord::Base
  #     # Destroys the associated clients and people when the firm is destroyed
  #     def before_destroy
  #       Client.destroy_all "client_of = #{id}"
  #       Person.destroy_all "firm_id = #{id}"
  #     end
  #
  # == Inheritable callback queues
  #
  # Besides the overwriteable callback methods, it's also possible to register callbacks through the use of the callback macros.
  # Their main advantage is that the macros add behavior into a callback queue that is kept intact down through an inheritance
  # hierarchy. Example:
  #
  #   class Topic < ActiveRecord::Base
  #     before_destroy :destroy_author
  #   end
  #
  #   class Reply < Topic
  #     before_destroy :destroy_readers
  #   end
  #
  # Now, when Topic#destroy is run only +destroy_author+ is called. When Reply#destroy is run both +destroy_author+ and
  # +destroy_readers+ is called. Contrast this to the situation where we've implemented the save behavior through overwriteable
  # methods:
  #
  #   class Topic < ActiveRecord::Base
  #     def before_destroy() destroy_author end
  #   end
  #
  #   class Reply < Topic
  #     def before_destroy() destroy_readers end
  #   end
  #
  # In that case, Reply#destroy would only run +destroy_readers+ and _not_ +destroy_author+. So use the callback macros when 
  # you want to ensure that a certain callback is called for the entire hierarchy and the regular overwriteable methods when you
  # want to leave it up to each descendent to decide whether they want to call +super+ and trigger the inherited callbacks.
  #
  # == Types of callbacks
  #
  # There are four types of callbacks accepted by the callback macros: Method references (symbol), callback objects, 
  # inline methods (using a proc), and inline eval methods (using a string). Method references and callback objects are the
  # recommended approaches, inline methods using a proc is some times appropriate (such as for creating mix-ins), and inline
  # eval methods are deprecated.
  #
  # The method reference callbacks work by specifying a protected or private method available in the object, like this:
  #
  #   class Topic < ActiveRecord::Base
  #     before_destroy :delete_parents
  #
  #     private
  #       def delete_parents
  #         self.class.delete_all "parent_id = #{id}"
  #       end
  #   end
  #
  # The callback objects have methods named after the callback called with the record as the only parameter, such as:
  #
  #   class BankAccount < ActiveRecord::Base
  #     before_save      EncryptionWrapper.new("credit_card_number")
  #     after_save       EncryptionWrapper.new("credit_card_number")
  #     after_initialize EncryptionWrapper.new("credit_card_number")
  #   end
  #
  #   class EncryptionWrapper
  #     def initialize(attribute)
  #       @attribute = attribute
  #     end
  #
  #     def before_save(record)
  #       record.credit_card_number = encrypt(record.credit_card_number)
  #     end
  #
  #     def after_save(record)
  #       record.credit_card_number = decrypt(record.credit_card_number)
  #     end
  #     
  #     alias_method :after_initialize, :after_save
  #
  #     private
  #       def encrypt(value)
  #         # Secrecy is committed
  #       end
  #
  #       def decrypt(value)
  #         # Secrecy is unvieled
  #       end
  #   end
  #
  # So you specify the object you want messaged on a given callback. When that callback is triggered, the object has
  # a method by the name of the callback messaged.
  #
  # The callback macros usually accept a symbol for the method they're supposed to run, but you can also pass a "method string",
  # which will then be evaluated within the binding of the callback. Example:
  #
  #   class Topic < ActiveRecord::Base
  #     before_destroy 'self.class.delete_all "parent_id = #{id}"'
  #   end
  #
  # Notice that single plings (') are used so the #{id} part isn't evaluated until the callback is triggered. Also note that these
  # inline callbacks can be stacked just like the regular ones:
  #
  #   class Topic < ActiveRecord::Base
  #     before_destroy 'self.class.delete_all "parent_id = #{id}"', 
  #                    'puts "Evaluated after parents are destroyed"'
  #   end
  #
  # == The after_find and after_initialize exceptions
  #
  # Because after_find and after_initialize is called for each object instantiated found by a finder, such as Base.find_all, we've had
  # to implement a simple performance constraint (50% more speed on a simple test case). Unlike all the other callbacks, after_find and
  # after_initialize can only be declared using an explicit implementation. So using the inheritable callback queue for after_find and
  # after_initialize won't work.
  module Callbacks
    CALLBACKS = %w( 
      after_find after_initialize before_save after_save before_create after_create before_update after_update before_validation 
      after_validation before_validation_on_create after_validation_on_create before_validation_on_update
      after_validation_on_update before_destroy after_destroy
    )

    def self.append_features(base) #:nodoc:
      super

      base.extend(ClassMethods)
      base.class_eval do
        class << self
          include Observable
          alias_method :instantiate_without_callbacks, :instantiate
          alias_method :instantiate, :instantiate_with_callbacks
        end
      end

      base.class_eval do
        alias_method :initialize_without_callbacks, :initialize
        alias_method :initialize, :initialize_with_callbacks

        alias_method :create_or_update_without_callbacks, :create_or_update
        alias_method :create_or_update, :create_or_update_with_callbacks

        alias_method :valid_without_callbacks, :valid?
        alias_method :valid?, :valid_with_callbacks

        alias_method :create_without_callbacks, :create
        alias_method :create, :create_with_callbacks

        alias_method :update_without_callbacks, :update
        alias_method :update, :update_with_callbacks

        alias_method :destroy_without_callbacks, :destroy
        alias_method :destroy, :destroy_with_callbacks
      end

      CALLBACKS.each { |cb| base.class_eval("def self.#{cb}(*methods) write_inheritable_array(\"#{cb}\", methods) end") }
    end

    module ClassMethods #:nodoc:
      def instantiate_with_callbacks(record)
        object = instantiate_without_callbacks(record)
        object.callback(:after_find) if object.respond_to?(:after_find)
        object.callback(:after_initialize) if object.respond_to?(:after_initialize)
        object
      end
    end

    # Is called when the object was instantiated by one of the finders, like Base.find.
    # def after_find() end

    # Is called after the object has been instantiated by a call to Base.new.
    # def after_initialize() end
    def initialize_with_callbacks(attributes = nil) #:nodoc:
      initialize_without_callbacks(attributes)
      yield self if block_given?
      after_initialize if respond_to?(:after_initialize)
    end
    
    # Is called _before_ Base.save (regardless of whether it's a create or update save).
    def before_save() end

    # Is called _after_ Base.save (regardless of whether it's a create or update save).
    def after_save()  end
    def create_or_update_with_callbacks #:nodoc:
      callback(:before_save)
      create_or_update_without_callbacks
      callback(:after_save)
    end

    # Is called _before_ Base.save on new objects that haven't been saved yet (no record exists).
    def before_create() end

    # Is called _after_ Base.save on new objects that haven't been saved yet (no record exists).
    def after_create() end
    def create_with_callbacks #:nodoc:
      callback(:before_create)
      create_without_callbacks
      callback(:after_create)
    end

    # Is called _before_ Base.save on existing objects that has a record.
    def before_update() end

    # Is called _after_ Base.save on existing objects that has a record.
    def after_update() end

    def update_with_callbacks #:nodoc:
      callback(:before_update)
      update_without_callbacks
      callback(:after_update)
    end

    # Is called _before_ Validations.validate (which is part of the Base.save call).
    def before_validation() end

    # Is called _after_ Validations.validate (which is part of the Base.save call).
    def after_validation() end

    # Is called _before_ Validations.validate (which is part of the Base.save call) on new objects
    # that haven't been saved yet (no record exists).
    def before_validation_on_create() end

    # Is called _after_ Validations.validate (which is part of the Base.save call) on new objects
    # that haven't been saved yet (no record exists).
    def after_validation_on_create()  end

    # Is called _before_ Validations.validate (which is part of the Base.save call) on 
    # existing objects that has a record.
    def before_validation_on_update() end

    # Is called _after_ Validations.validate (which is part of the Base.save call) on 
    # existing objects that has a record.
    def after_validation_on_update()  end

    def valid_with_callbacks #:nodoc:
      callback(:before_validation)
      if new_record? then callback(:before_validation_on_create) else callback(:before_validation_on_update) end

      result = valid_without_callbacks

      callback(:after_validation)
      if new_record? then callback(:after_validation_on_create) else callback(:after_validation_on_update) end
      
      return result
    end

    # Is called _before_ Base.destroy.
    def before_destroy() end

    # Is called _after_ Base.destroy (and all the attributes have been frozen).
    def after_destroy()  end
    def destroy_with_callbacks #:nodoc:
      callback(:before_destroy)
      destroy_without_callbacks
      callback(:after_destroy)
    end

    def callback(callback_method) #:nodoc:
      run_callbacks(callback_method)
      send(callback_method)
      notify(callback_method)
    end

    def run_callbacks(callback_method)
      filters = self.class.read_inheritable_attribute(callback_method.to_s)
      if filters.nil? then return end
      filters.each do |filter| 
        if Symbol === filter
          self.send(filter)
        elsif String === filter
          eval(filter, binding)
        elsif filter_block?(filter)
          filter.call(self)
        elsif filter_class?(filter, callback_method)
          filter.send(callback_method, self)
        else
          raise(
            ActiveRecordError, 
            "Filters need to be either a symbol, string (to be eval'ed), proc/method, or " +
            "class implementing a static filter method"
          )
        end
      end
    end
    
    def filter_block?(filter)
      filter.respond_to?("call") && (filter.arity == 1 || filter.arity == -1)
    end
    
    def filter_class?(filter, callback_method)
      filter.respond_to?(callback_method)
    end
    
    def notify(callback_method) #:nodoc:
      self.class.changed
      self.class.notify_observers(callback_method, self)
    end
  end
end