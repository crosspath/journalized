class ActiveRecord::Base
  # acts_as_journalized options
  # options:
  #   watchable_columns: %w[name content user_id]
  #   after_<event>: lambda(journal)|:func_name|'func_name'
  #   diff: :column|%w[column1 column2]
  def self.acts_as_journalized(options = {})
    include Journalized
    options = options.symbolize_keys

    wc = Array.wrap(options.delete(:watchable_columns))
    @@watchable_columns = (wc.present? ? wc : column_names - [:id, :created_at, :updated_at]).map(&:to_s)
    @@events_calbacks = {}
    events = self.aasm.events.map { |x| x.name.to_sym }

    options.each do |key, v|
      if key.to_s =~ /^(after|before)_(.*)$/
        k, j = [$1, $2].map(&:to_sym)
        raise RuntimeError, "Event #{j} is not in list (see #{self.name})" unless events.include?(j)
        @@events_calbacks[k] ||= {}
        @@events_calbacks[k][j] ||= []
        @@events_calbacks[k][j] << v
        options.delete(key)
      end
    end

    @@store_column_value_as_diff = Array.wrap(options.delete(:diff))
  end
end

module Journalized
  def self.included(base)
    base.class_eval do
      has_many :journals, as: :journalized, dependent: :destroy

      attr_reader :current_journal

      after_save :create_journal, :custom_callback_after_save
      before_save :custom_callback_before_save

      after_initialize do init_journal(current_user) end

      def init_journal(user)
        @current_journal ||= Journal.new(journalized: self, user: user)
        @attributes_before_change = attributes.dup unless new_record?
        @current_journal
      end

      # Saves the changes in a Journal
      def create_journal
        return if !defined?(@current_journal) || !@current_journal
        # attributes changes
        if defined?(@attributes_before_change) && @attributes_before_change
          @@watchable_columns.each do |c|
            before = @attributes_before_change[c].to_s
            after = read_attribute(c).to_s
            next if before == after || (before.blank? && after.blank?)
            @current_journal.details << Journal::Detail.new(property: c, old_value: before, value: after)
          end
        end
        @current_journal.save! if @current_journal.details.present?
        # reset current journal
        init_journal(@current_journal.user)
      end

      protected

      def custom_callback_after_save
        f = @@events_calbacks[:after][journalized.aasm.current_event]
        custom_callback_call(f)
      end

      def custom_callback_before_save
        f = @@events_calbacks[:before][journalized.aasm.current_event]
        custom_callback_call(f)
      end

      def custom_callback_call(f)
        if f.is_a?(Proc)
          f.call(self)
        elsif f.is_a?(Symbol) || f.is_a?(String)
          journalized.send(f, self)
        end
      end
    end
  end
end
