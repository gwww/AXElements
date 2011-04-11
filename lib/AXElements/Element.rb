module AX

##
# @abstract
#
# The abstract base class for all accessibility objects.
class Element

  # @param [AXUIElementRef] element
  def initialize element
    @ref        = element
    @attributes = AX.attrs_of_element(element)
  end

  # @return [Array<String>] cache of available attributes
  attr_reader :attributes

  # @return [Array<String>] cache of available actions
  def actions; @actions ||= AX.actions_of_element(@ref); end

  # @return [Array<String>] cache of available actions
  def param_attributes;  @param_attributes ||= AX.param_attrs_of_element(@ref); end

  # @return [Fixnum]
  def pid
    @pid ||= AX.pid_of_element( @ref )
  end

  # @param [Symbol] attr
  def get_attribute attr
    real_attribute = attribute_for attr
    raise ArgumentError, "#{attr} is not an attribute" unless real_attribute
    attribute(real_attribute)
  end

  ##
  # Ideally this method would return a reference to `self`, but since
  # this method inherently causes state change, the reference to `self`
  # may no longer be valid. An example of this would be pressing the
  # close button on a window.
  #
  # @param [String] name an action constant
  # @return [Boolean] true if successful
  def perform_action name
    action = action_for name
    raise ArgumentError, "#{name} is not an action" unless action
    AX.perform_action_of_element( @ref, action )
  end

  ##
  # @todo merge this into {#method_missing} other places once I understand
  #       it more, right now it would just add a lot of overhead
  #
  # @param [Symbol] attr
  def get_param_attribute attr, param
    attribute = param_attribute_for attr
    raise ArgumentError, "#{attr} is not a parameterized attribute" unless attribute
    AX.param_attr_of_element( @ref, attribute, param )
  end

  ##
  # We cannot make any assumptions about the state of the program after
  # you have set a value; at least not in the general case.
  #
  # @param [String] attr an attribute constant
  # @return the value that you set is returned
  def set_attribute attr, value
    attribute = attribute_for attr
    raise ArgumentError, "#{attr} is not an attribute" unless attribute
    unless AX.attr_of_element_writable?(attribute)
      raise ArgumentError, "#{attr} not writable"
    end
    AX.set_attr_of_element( @ref, attr, value )
    value
  end

  ##
  # Needed to override inherited {NSObject#description}. If you want a
  # description of the object try using {#inspect}.
  def description
    self.method_missing :description
  end

  ##
  # @todo allow regex matching when filtering string attributes
  # @todo decide whether plural or singular search before entering
  #       the main loop
  # @todo make search much faster by not wrapping child classes
  # @todo refactor searching, perhaps make an iterator
  #
  # Perform a breadth first search through the view hierarchy rooted at
  # the current element.
  #
  # See the documentation page [Searching](file/Searching.markdown)
  # on the details of how to search.
  #
  # @example Find the dock item for the Finder app
  #  AX::DOCK.search( :application_dock_item, title: 'Finder' )
  #
  # @param [Symbol,String] element_type
  # @param [Hash{Symbol=>Object}] filters
  # @return [AX::Element,nil,Array<AX::Element>,Array<>]
  def search element_type, filters = {}
    element_type   = element_type.to_s
    class_const    = element_type.camelize!
    elements       = AX.attr_of_element(@ref, KAXChildrenAttribute)
    search_results = []
    filters      ||= {}

    until elements.empty?
      element          = elements.shift
      primary_filter ||= AX.plural_const_get(class_const)

      # this can optimized significantly if needed
      if element.attributes.include?(KAXChildrenAttribute)
        elements.concat( element.get_attribute :children )
      end

      next unless element.class == primary_filter
      next if filters.find { |filter,value| element.send(filter) != value }

      return element unless element_type[-1] == 's'
      search_results << element
    end

    element_type[-1] == 's' ? search_results : nil
  end

  ##
  # @todo search param attributes
  #
  # We use {#method_missing} to dynamically handle requests to, in the
  # following order, lookup attributes, or search for elements in the
  # view hierarchy.
  #
  # Failing both lookups, this method calls `super`.
  #
  # @example Attribute lookup of an element
  #  mail   = AX::Application.application_with_bundle_identifier 'com.apple.mail'
  #  window = mail.focused_window
  # @example Attribute lookup of an element property
  #  window.title
  # @example Simple single element search
  #  window.button # => You want the first Button that is found
  # @example Simple multi-element search
  #  window.buttons # => You want all the Button objects found
  # @example Filters for a single element search
  #  window.button(title:'Log In') # => First Button with a title of 'Log In'
  # @example Contrived multi-element search with filtering
  #  window.buttons(title:'New Project', enabled?:true)
  def method_missing method, *args
    attr = attribute_for method
    return AX.attr_of_element(@ref, attr) if attr
    return search(method, args.first) if attributes.include?(KAXChildrenAttribute)
    super
  end

  ##
  # Optimized under the assumption that you will be passing a block much
  # less frequently than not.
  # @yield
  # @yieldreturn [Boolean]
  # @param [String] notif
  # @param [Float] timeout
  def wait_for_notification notif, timeout = 10
    AX.wait_for_notification( @ref, notif, timeout )
  end

  ##
  # Overriden to produce cleaner output.
  def inspect
    nice_methods = attributes.map { |name|
      name.sub(AX.prefix) { $1 }
    }
    "\#<#{self.class} @methods=#{nice_methods}>"
  end

  ##
  # @todo FINISH THIS METHOD
  #
  # A more expensive {#inspect} where we actually look up the
  # values for each attribute and format the output nicely.
  def pretty_print
    inspect
  end

  ##
  # Overriden to respond properly with regards to the dynamic
  # attribute lookups, but will return false on potential
  # search names.
  def respond_to? name
    pattern = matcher(name)
    return true if attributes.find { |meth| meth.match(pattern) }
    super
  end

  ##
  # @todo FINISH THIS METHOD
  #
  # Like {#respond_to?}, this is overriden to include attribute methods.
  def methods include_super = false, include_objc_super = false
    super
  end


  protected

  ##
  # @todo Should I provide {#action}, {#param_attribute}, etc. for the
  #       sake of consistency?
  #
  # A short path when you have the exact name of the attribute you want
  # to retrieve the value of.
  #
  # This API is exposed for the sake of making search much faster.
  #
  # @param [String] name an attribute constant
  def attribute name
    AX.attr_of_element(@ref, name)
  end

  ##
  # Make a regexp that can match against the proper attributes
  # and/or actions for an AX::Element object.
  def matcher name
    /#{name.to_s.gsub(/_|\?$/, '')}$/i
  end

  def attribute_for sym;       constant_for sym, attributes;       end
  def action_for sym;          constant_for sym, actions;          end
  def param_attribute_for sym; constant_for sym, param_attributes; end

  ##
  # Match a symbol/string as a suffix of an action constant
  # @return [String,nil]
  def constant_for sym, array
    pattern = matcher(sym)
    matches = array.find_all { |const| const.match(pattern) }
    unless matches.empty?
      matches.sort_by(&:length) if matches.size > 1
      matches.first
    end
  end

end
end
