module Collectible

  def self.included(collectible)
    collectible.class_eval do

      has_many :collection_items, :as => :item, :dependent => :destroy, :inverse_of => :item
      accepts_nested_attributes_for :collection_items, :allow_destroy => true
      has_many :approved_collection_items, :class_name => "CollectionItem", :as => :item,
        :conditions => ['collection_items.user_approval_status = ? AND collection_items.collection_approval_status = ?', CollectionItem::APPROVED, CollectionItem::APPROVED]

      has_many :collections, :through => :collection_items, :after_add => :set_visibility, :after_remove => :update_visibility
      has_many :approved_collections, :through => :collection_items, :source => :collection,
        :conditions => ['collection_items.user_approval_status = ? AND collection_items.collection_approval_status = ?', CollectionItem::APPROVED, CollectionItem::APPROVED]
    end
  end
  
  # add collections based on a comma-separated list of names
  def collections_to_add=(collection_names)
    names = trim_collection_names(collection_names)
    names.each do |name|
      c = Collection.find_by_name(name)
      errors.add(:base, ts("We couldn't find the collection %{name}.", :name => name)) and return if c.nil?
      errors.add(:base, ts("The collection %{name} is not currently open.", :name => name)) and return if (c.closed? && !c.user_is_maintainer?(User.current_user))
      add_to_collection(c)
    end
  end
  
  # remove collections based on an array of ids
  def collections_to_remove=(collection_ids)
    collection_ids.reject {|id| id.blank?}.map {|id| id.is_a?(String) ? id.strip : id}.each do |id|
      c = Collection.find(id) || nil
      remove_from_collection(c)
    end
  end   
  def collections_to_add; nil; end
  def collections_to_remove; nil; end

  def add_to_collection(collection)
    if collection && !self.collections.include?(collection)
      self.collections << collection
    end
  end

  def remove_from_collection(collection)
    if collection && self.collections.include?(collection)
      self.collections -= [collection]
    end
  end
  
  private
  def trim_collection_names(names)
    names.split(',').map{ |name| name.strip }.reject {|name| name.blank?}
  end

  public
  # Set ALL of an item's collections based on a list of collection names
  # Refactored to use collections_to_(add,remove) above so we only have one set of code 
  #  performing the actual add/remove actions
  # This method now just does the convenience work of getting the removed ids -- any missing collections
  # will be identified 
  # IMPORTANT: cannot delete all existing collections, or else items in closed collections
  # can't be edited
  def collection_names=(new_collection_names)
    new_names = trim_collection_names(new_collection_names)
    remove_ids = self.collections.reject {|c| new_names.include?(c.name)}.collect(&:id)
    self.collections_to_add = new_names.join(",")
    self.collections_to_remove = remove_ids
  end

  # NOTE: better to use collections_to_add/remove above instead for more consistency
  def collection_names
    @collection_names ? @collection_names : self.collections.collect(&:name).join(",")
  end
  
  
  #### UNREVEALED/ANONYMOUS

  # Set the anonymous/unrevealed status of the collectible based on its collections
  # TODO: need a better long-term fix
  # Collection items can be revealed independently of a collection, so we don't want
  # to check the collection status when those are updated, but a new work doesn't have
  # collection items yet
  def set_anon_unrevealed
    return true unless self.respond_to?(:in_anon_collection) && self.respond_to?(:in_unrevealed_collection)
    if self.new_record?
      self.in_anon_collection = !self.collections.select {|c| c.anonymous? }.empty? 
      self.in_unrevealed_collection = !self.collections.select{|c| c.unrevealed? }.empty?
    else
      self.in_anon_collection = !self.collection_items.select {|c| c.anonymous? }.empty?
      self.in_unrevealed_collection = !self.collection_items.select{|c| c.unrevealed? }.empty?
    end
    return true
  end

  # save as well
  def set_anon_unrevealed!
    set_anon_unrevealed
    save
  end

  def set_visibility(collection)
    set_anon_unrevealed
    return true
  end
  
  def update_visibility(collection)
    set_anon_unrevealed!
    return true
  end
  
  
end
