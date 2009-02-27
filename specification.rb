
require 'prefer'
require 'spec'

module Merb
  module String
    def f
      "Merb::String#f"
    end
  end

  module Array
    def g
      "Merb::Array#g"
    end
  end
end

module Rails
  module String
    def f
      "Rails::String#f"
    end
  end

  module Array
    def g
      "Rails::Array#g"
    end
  end
end

module MerbStuff
  extend Prefer

  prefer Merb::String => String

  def string_test
    "".f
  end

  def string_test_other
    RailsStuff.string_test
  end

  extend self
end

module RailsStuff
  extend Prefer

  prefer Rails::String => String

  def string_test
    "".f
  end

  def string_test_other
    MerbStuff.string_test
  end

  extend self
end

module Cafeteria
  extend Prefer

  prefer Rails::String => String, Merb::Array => Array

  def string_test
    "".f
  end

  def array_test
    [].g
  end
end

def define_main_examples
  describe RailsStuff do
    it "should use Rails::String" do
      Object.new.extend(RailsStuff).string_test.should == "Rails::String#f"
    end
  end
  
  describe MerbStuff do
    it "should use Merb::String" do
      Object.new.extend(MerbStuff).string_test.should == "Merb::String#f"
    end
  end
  
  describe Cafeteria do
    it "should use Rails::String" do
      Object.new.extend(Cafeteria).string_test.should == "Rails::String#f"
    end
    
    it "should use Merb::Array" do
      Object.new.extend(Cafeteria).array_test.should == "Merb::Array#g"
    end
  end
end

describe "When String originally has no mixins," do
  define_main_examples
  
  describe "and when outside the scope of a module extended with Prefer" do
    it "should leave String ancestry untouched" do
      ancestors = String.ancestors.reject { |ancestor|
        ancestor.to_s =~ %r!\A(Spec|Quix)::!
      } 
      ancestors.should == [String, Enumerable, Comparable, Object, Kernel]
    end
    
    it "should not add new methods to String" do
      lambda { "".f }.should raise_error(NoMethodError)
    end
  end
end

describe "With Rails::String and Merb::String already mixed into String," do
  before :all do
    unless defined?(VISITED)
      VISITED = true
      class String
        include Rails::String
        include Merb::String
      end
    end
  end
  define_main_examples
end

describe "Calling RailsStuff from MerbStuff" do
  it "should use Rails::String" do
    MerbStuff.string_test_other.should == "Rails::String#f"
  end
end

describe "Calling MerbStuff from RailsStuff" do
  it "should use Merb::String" do
    RailsStuff.string_test_other.should == "Merb::String#f"
  end
end

